/**********************************************************************
;       Copyright 2015 JR3, Inc.
;
;**********************************************************************/

#include "pch.h"

///////////////////////////////////////////////////////////////////////////////////////////////////
// Cancel Safe Driver Managed IRP Queue
///////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIInitializeQueue 
//      Sets up a driver managed IRP queue.
//
//  Arguments:
//      IN  Queue
//              An instance of our queue structure
//
//      IN  StartIoRoutine
//              Routine where queue IRPs are sent to be processed
//
//      IN  DeviceObject
//              Device object for our driver
//
//      IN  bUseJR3PCIStartIoDpc
//              Flag to indicate that the queue should use queue a DPC for 
//              calling StartIo if StartIo recursion is possible
//
//  Return Value:
//      none
//
VOID JR3PCIInitializeQueue(
    IN  PJR3PCI_QUEUE          Queue,
    IN  PJR3PCI_QUEUE_STARTIO     StartIoRoutine,
    IN  PDEVICE_OBJECT          DeviceObject,
    IN  BOOLEAN                 bUseJR3PCIStartIoDpc
    )
{
    // must provide StartIo routine
    ASSERT(StartIoRoutine != NULL);

    // save off the user info
    Queue->StartIoRoutine = StartIoRoutine;
    Queue->DeviceObject = DeviceObject;
    Queue->bUseJR3PCIStartIoDpc = bUseJR3PCIStartIoDpc;

    // queues are created in a stalled state
    // Start device will unstall them
    Queue->StallCount = 1;

    // initialize our queue lock
    KeInitializeSpinLock(&Queue->QueueLock);

    // initialize our IRP list
    InitializeListHead(&Queue->IrpQueue);

    // initialize our JR3PCIStartIoDpc
    if (bUseJR3PCIStartIoDpc)
    {
        KeInitializeDpc(&Queue->JR3PCIStartIoDpc, JR3PCIStartIoDpc, Queue);
    }    

    // initialize stop event
    KeInitializeEvent(&Queue->StopEvent, NotificationEvent, FALSE);

    Queue->ErrorStatus = STATUS_SUCCESS;

    return;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIQueueIrp
//      Inserts an IRP into the queue if the queue is busy, or sends IRP
//      to StartIo routine if the queue is not busy.
//
//  Arguments:
//      IN  Queue
//              An instance of our queue structure
//
//      IN  Irp
//              The IRP to add to the queue
//
//  Return Value:
//      Status
//
NTSTATUS JR3PCIQueueIrp(
    IN  PJR3PCI_QUEUE    Queue,
    IN  PIRP            Irp
    )
{
    NTSTATUS            status;
    KIRQL               oldIrql;
    PDEVICE_EXTENSION   deviceExtension;

    deviceExtension = (PDEVICE_EXTENSION)Queue->DeviceObject->DeviceExtension;

    // grab the queue protection
    KeAcquireSpinLock(&Queue->QueueLock, &oldIrql);

    // If the queue has been invalidated, complete the IRP
    if (Queue->ErrorStatus != STATUS_SUCCESS)
    {
        status = Queue->ErrorStatus;

        // drop the queue protection
        KeReleaseSpinLock(&Queue->QueueLock, oldIrql);

        Irp->IoStatus.Status = status;
        Irp->IoStatus.Information = 0;

        IoCompleteRequest(Irp, IO_NO_INCREMENT);

        return status;
    }

    // see if the queue is busy
    if ((Queue->CurrentIrp == NULL) && (Queue->StallCount == 0))
    {
        // mark irp pending since STATUS_PENDING is returned
        IoMarkIrpPending(Irp);
        status = STATUS_PENDING;

        // set the current IRP
        Queue->CurrentIrp = Irp;

        // drop the queue protection
        // raise our IRQL before calling StartIo
        KeReleaseSpinLockFromDpcLevel(&Queue->QueueLock);

        // call the user's StartIo routine
        Queue->StartIoRoutine(Queue->DeviceObject, Queue->CurrentIrp);

        // drop our IRQL back
        KeLowerIrql(oldIrql);

        return status;
    }

    // put our queue pointer into the IRP
    Irp->Tail.Overlay.DriverContext[0] = Queue;

    // queue the IRP
    InsertTailList(&Queue->IrpQueue, &Irp->Tail.Overlay.ListEntry);

    // insert our queue cancel routine into the IRP
    IoSetCancelRoutine(Irp, JR3PCIQueueCancelRoutine);

    // Make sure the IRP was not cancelled before 
    // we inserted our cancel routine
    if (Irp->Cancel)
    {
        // If the IRP was cancelled after we put in our cancel routine we
        // will get back NULL here and we will let the cancel routine handle
        // the IRP.  If NULL is not returned here then we know the IRP was 
        // cancelled before we inserted the queue cancel routine, and we
        // need to call our cancel routine to handle the IRP.
        if (IoSetCancelRoutine(Irp, NULL) != NULL)
        {
            RemoveEntryList(&Irp->Tail.Overlay.ListEntry);

            // drop the queue protection
            KeReleaseSpinLock(&Queue->QueueLock, oldIrql);

            // cancel the IRP
            status = STATUS_CANCELLED;
            Irp->IoStatus.Status = status;
            Irp->IoStatus.Information = 0;
            IoCompleteRequest(Irp, IO_NO_INCREMENT);

            return status;
        }
    }

    // mark irp pending since STATUS_PENDING is returned
    IoMarkIrpPending(Irp);
    status = STATUS_PENDING;

    // drop the queue protection
    KeReleaseSpinLock(&Queue->QueueLock, oldIrql);

    return status;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIStartNext
//      Pulls the next available IRP from the queue and sends it to 
//      StartIo for processing.
//
//  Arguments:
//      IN  Queue
//              An instance of our queue structure
//
//  Return Value:
//      none
//
VOID JR3PCIStartNext(
    IN  PJR3PCI_QUEUE    Queue
    )
{
    KIRQL       oldIrql;
    PLIST_ENTRY entry;

    // grab the queue protection
    KeAcquireSpinLock(&Queue->QueueLock, &oldIrql);

    // set the current IRP pointer to NULL
    Queue->CurrentIrp = NULL;

    // check if there are entries in the queue
    if (IsListEmpty(&Queue->IrpQueue) || (Queue->StallCount > 0) || (Queue->ErrorStatus != STATUS_SUCCESS))
    {
        // set event that queue is stalled
        KeSetEvent(&Queue->StopEvent, IO_NO_INCREMENT, FALSE);
        KeReleaseSpinLock(&Queue->QueueLock, oldIrql);

        return;
    }

    // get a new IRP from the queue
    for (entry = Queue->IrpQueue.Flink; entry != &Queue->IrpQueue; entry = entry->Flink)
    {
        // get the IRP from the list entry
        Queue->CurrentIrp = CONTAINING_RECORD(entry, IRP, Tail.Overlay.ListEntry);

        ASSERT(Queue->CurrentIrp->Type == IO_TYPE_IRP);

        // if we found an IRP, pull the queue cancel routine out of it
        // See if the IRP is canceled
        if (IoSetCancelRoutine(Queue->CurrentIrp, NULL) == NULL)
        {
            // cancel routine already has a hold on this IRP, 
            // just go on to the next one
            Queue->CurrentIrp = NULL;
        }
        else
        {
            // Found a usable IRP, pull the entry out of the list
            RemoveEntryList(entry);
            break;
        }
    }

    if (Queue->CurrentIrp == NULL)
    {
        // set event that queue is stalled
        KeSetEvent(&Queue->StopEvent, IO_NO_INCREMENT, FALSE);
        KeReleaseSpinLock(&Queue->QueueLock, oldIrql);
        return;
    }

    // found an IRP call StartIo

    // Determine if we need to queue a DPC or not.
    // We only use the DPC if the user specified to protect 
    // against StartIo recursion (bUseJR3PCIStartIoDpc), and the 
    // queue has multiple entries. If there are not multiple 
    // entries in the queue we won't recurse anyway.
    if (Queue->bUseJR3PCIStartIoDpc && !IsListEmpty(&Queue->IrpQueue))
    {
        // drop the queue protection
        KeReleaseSpinLock(&Queue->QueueLock, oldIrql);

        // queue our StartIo DPC to prevent StartIo recursion
        KeInsertQueueDpc(&Queue->JR3PCIStartIoDpc, NULL, NULL);
    }
    else
    {
        // drop the queue protection
        // raise our IRQL before calling StartIo
        KeReleaseSpinLockFromDpcLevel(&Queue->QueueLock);

        // call the user's StartIo routine
        Queue->StartIoRoutine(Queue->DeviceObject, Queue->CurrentIrp);

        // drop our IRQL back
        KeLowerIrql(oldIrql);
    }

    return;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIFlushQueue
//      Cancels all IRPs in the queue, or all IRPs in the queue related to a 
//      particular open handle.
//
//  Arguments:
//      IN  Queue
//              An instance of our queue structure
//
//      IN  FileObject
//              If NULL all IRPs in queue are cancelled, if non-NULL then all
//              IRPs related to this file object are cancelled.
//
//  Return Value:
//      none
//
VOID JR3PCIFlushQueue(
    IN  PJR3PCI_QUEUE    Queue,
    IN  PFILE_OBJECT        FileObject
    )
{
    PLIST_ENTRY         entry;
    PLIST_ENTRY         nextEntry;
    PIRP                irp;
    PIO_STACK_LOCATION  irpStack;
    KIRQL               oldIrql;
    LIST_ENTRY          cancelList;

    // initialize our cancel list
    InitializeListHead(&cancelList);

    // grab the queue protection
    KeAcquireSpinLock(&Queue->QueueLock, &oldIrql);

    // Look at the first entry in the queue
    entry = Queue->IrpQueue.Flink;
    while (entry != &Queue->IrpQueue)
    {
        // get the next list entry
        nextEntry = entry->Flink;

        // Get the IRP from the entry
        irp = CONTAINING_RECORD(entry, IRP, Tail.Overlay.ListEntry);

        ASSERT(irp->Type == IO_TYPE_IRP);

        // Determine if we need to pull out of queue
        if (FileObject != NULL)
        {
            // get the current IRP stack location from the IRP
            irpStack = IoGetCurrentIrpStackLocation(irp);

            if (irpStack->FileObject != FileObject)
            {
                // go to the next entry
                entry = nextEntry;

                // We are not flushing this IRP
                continue;
            }
        }

        // Attempt to cancel the IRP
        if (IoSetCancelRoutine(irp, NULL) == NULL)
        {
            // go to the next entry
            entry = nextEntry;

            // cancel routine already has this IRP,
            // just go on
            continue;
        }

        // pull the IRP from the queue
        RemoveEntryList(entry);

        InsertTailList(&cancelList, entry);

        // go to the next entry
        entry = nextEntry;
    }

    // drop the queue protection
    KeReleaseSpinLock(&Queue->QueueLock, oldIrql);

    // Now clear out our cancel list
    while (!IsListEmpty(&cancelList))
    {
        // Get the first entry on the list
        entry = RemoveHeadList(&cancelList);

        // Get the IRP for that entry
        irp = CONTAINING_RECORD(entry, IRP, Tail.Overlay.ListEntry);

        // Cancel the IRP
        irp->IoStatus.Status = STATUS_CANCELLED;
        irp->IoStatus.Information = 0;
        IoCompleteRequest(irp, IO_NO_INCREMENT);
    }

    return;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIInvalidateQueue
//      Stops queue from receiving anymore IRPs, all IRPs are completed upon
//      receipt
//
//  Arguments:
//      IN  Queue
//              An instance of our queue structure
//
//  Return Value:
//      none
//
VOID JR3PCIInvalidateQueue(
    IN  PJR3PCI_QUEUE    Queue,
    IN  NTSTATUS                  ErrorStatus   
    )
{
    // indicate the queue is shutdown
    Queue->ErrorStatus = TRUE;

    // flush all requests from the queue
    JR3PCIFlushQueue(Queue, NULL);

    return;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIPauseQueue
//      Stops queue from sending anymore IRPs to StartIo to be processed
//
//  Arguments:
//      IN  Queue
//              An instance of our queue structure
//
//  Return Value:
//      none
//
VOID JR3PCIPauseQueue(
    IN  PJR3PCI_QUEUE    Queue
    )
{
    KIRQL   oldIrql;
    BOOLEAN bBusy;

    KeAcquireSpinLock(&Queue->QueueLock, &oldIrql);

    // indicate the queue is paused
    InterlockedIncrement(&Queue->StallCount);

    bBusy = Queue->CurrentIrp != NULL;
    if (bBusy)
    {
        // reset stop event
        KeClearEvent(&Queue->StopEvent);
    }

    KeReleaseSpinLock(&Queue->QueueLock, oldIrql);

    if (bBusy)
    {
        KeWaitForSingleObject(&Queue->StopEvent, Executive, KernelMode, FALSE, NULL);
    }

    return;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIRestartQueue
//      Restarts IRP processing for a queue that was paused 
//      using JR3PCIPauseQueue()
//      or invalidated using JR3PCIInvalidateQueue()
//
//  Arguments:
//      IN  Queue
//              An instance of our queue structure
//
//  Return Value:
//      none
//
VOID JR3PCIRestartQueue(
    IN  PJR3PCI_QUEUE    Queue
    )
{
    // if the queue is stalled or invalid, restart it
    if (InterlockedDecrement(&Queue->StallCount) == 0)
    {
        JR3PCIStartNext(Queue);
    }

    return;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIStartIoDpc
//      DPC routine used to call StartIo, if bUseJR3PCIStartIoDpc is specified and
//      StartIo recursion is possible.
//
//  Arguments:
//      IN  Dpc
//              DPC object
//
//      IN  Context
//              An instance of our queue structure
//
//      IN  Unused1
//              Not used
//
//      IN  Unused2
//              Not used
//
//  Return Value:
//      none
//
VOID JR3PCIStartIoDpc(
    IN  PKDPC   Dpc,
    IN  PVOID   Context,
    IN  PVOID   Unused1,
    IN  PVOID   Unused2
    )
{
    PJR3PCI_QUEUE  queue;

    queue = (PJR3PCI_QUEUE)Context;

    // call the user's StartIo routine
    queue->StartIoRoutine(queue->DeviceObject, queue->CurrentIrp);

    return;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIQueueCancelRoutine
//      Cancel routine used for queue IRPs while in the queue
//
//  Arguments:
//      IN  DeviceObject
//              Device object for our device
//
//      IN  Irp
//              IRP to be cancelled
//
//  Return Value:
//      none
//
VOID JR3PCIQueueCancelRoutine(
    IN  PDEVICE_OBJECT  DeviceObject,
    IN  PIRP            Irp
    )
{
    KIRQL           oldIrql;
    PJR3PCI_QUEUE  queue;

    // release the system cancel spinlock
    oldIrql = Irp->CancelIrql;
    IoReleaseCancelSpinLock(DISPATCH_LEVEL);

    // get our queue from the IRP
    queue = (PJR3PCI_QUEUE)Irp->Tail.Overlay.DriverContext[0];

    ASSERT(queue != NULL);

    // grab the queue protection
    KeAcquireSpinLockAtDpcLevel(&queue->QueueLock);

    // remove our IRP from the queue
    RemoveEntryList(&Irp->Tail.Overlay.ListEntry);

    // drop the queue protection
    KeReleaseSpinLock(&queue->QueueLock, oldIrql);

    // cancel the IRP
    Irp->IoStatus.Status = STATUS_CANCELLED;
    Irp->IoStatus.Information = 0;
    IoCompleteRequest(Irp, IO_NO_INCREMENT);

    return;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// Cancel Safe IRP List
///////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIInitializeList
//      Sets up a cancel safe IRP list.
//
//  Arguments:
//      IN  List
//              An instance of our list structure
//
//      IN  DeviceObject
//              Device object for our driver
//
//  Return Value:
//      none
//
VOID JR3PCIInitializeList(
    IN  PJR3PCI_LIST List,
    IN  PDEVICE_OBJECT  DeviceObject
    )
{
    // save off the user info
    List->DeviceObject = DeviceObject;

    // initialize our queue lock
    KeInitializeSpinLock(&List->ListLock);

    // initialize our IRP list
    InitializeListHead(&List->IrpList);

    List->ErrorStatus = STATUS_SUCCESS;

    return;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIInsertHead
//      Puts Irp entry at head of list
//
//  Arguments:
//      IN  List
//              An instance of our list structure
//
//      IN  Irp
//              IRP to be put in list
//
//  Return Value:
//      Status
//
NTSTATUS JR3PCIInsertHead(
    IN  PJR3PCI_LIST List,
    IN  PIRP            Irp
    )
{
    NTSTATUS                status;
    KIRQL                   oldIrql;
    PDEVICE_EXTENSION   deviceExtension;

    deviceExtension = (PDEVICE_EXTENSION)List->DeviceObject->DeviceExtension;

    // Grab the list protection
    KeAcquireSpinLock(&List->ListLock, &oldIrql);

    if (List->ErrorStatus != STATUS_SUCCESS)
    {
        status = List->ErrorStatus;

        // drop the queue protection
        KeReleaseSpinLock(&List->ListLock, oldIrql);

        Irp->IoStatus.Status = status;
        Irp->IoStatus.Information = 0;

        IoCompleteRequest(Irp, IO_NO_INCREMENT);

        return status;
    }

    // put our list pointer into the IRP
    Irp->Tail.Overlay.DriverContext[0] = List;

    // put the entry at the head of the list
    InsertHeadList(&List->IrpList, &Irp->Tail.Overlay.ListEntry);

    // set cancel routine
    IoSetCancelRoutine(Irp, JR3PCIListCancelRoutine);

    // Make sure the IRP was not cancelled before 
    // we inserted our cancel routine
    if (Irp->Cancel)
    {
        // If the IRP was cancelled after we put in our cancel routine we
        // will get back NULL here and we will let the cancel routine handle
        // the IRP.  If NULL is not returned here then we know the IRP was 
        // cancelled before we inserted the cancel routine, and we
        // need to cancel the IRP
        if (IoSetCancelRoutine(Irp, NULL) != NULL)
        {
            RemoveEntryList(&Irp->Tail.Overlay.ListEntry);

            // drop the list protection
            KeReleaseSpinLock(&List->ListLock, oldIrql);

            // cancel the IRP
            status = STATUS_CANCELLED;
            Irp->IoStatus.Status = status;
            Irp->IoStatus.Information = 0;
            IoCompleteRequest(Irp, IO_NO_INCREMENT);

            return status;
        }
    }

    // mark irp pending since STATUS_PENDING is returned
    IoMarkIrpPending(Irp);
    status = STATUS_PENDING;

    // drop the list protection
    KeReleaseSpinLock(&List->ListLock, oldIrql);

    return status;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIInsertTail
//      Puts Irp entry at end of list
//
//  Arguments:
//      IN  List
//              An instance of our list structure
//
//      IN  Irp
//              IRP to be put in list
//
//  Return Value:
//      Status
//
NTSTATUS JR3PCIInsertTail(
    IN  PJR3PCI_LIST   List,
    IN  PIRP            Irp
    )
{
    NTSTATUS                status;
    KIRQL                   oldIrql;
    PDEVICE_EXTENSION   deviceExtension;

    deviceExtension = (PDEVICE_EXTENSION)List->DeviceObject->DeviceExtension;

    // Grab the list protection
    KeAcquireSpinLock(&List->ListLock, &oldIrql);

    if (List->ErrorStatus != STATUS_SUCCESS)
    {
        status = List->ErrorStatus;

        // drop the queue protection
        KeReleaseSpinLock(&List->ListLock, oldIrql);

        Irp->IoStatus.Status = status;
        Irp->IoStatus.Information = 0;

        IoCompleteRequest(Irp, IO_NO_INCREMENT);

        return status;
    }

    // put our list pointer into the IRP
    Irp->Tail.Overlay.DriverContext[0] = (PVOID)List;

    // put the entry at the head of the list
    InsertHeadList(&List->IrpList, &Irp->Tail.Overlay.ListEntry);

    // set cancel routine
    IoSetCancelRoutine(Irp, JR3PCIListCancelRoutine);

    // Make sure the IRP was not cancelled before 
    // we inserted our cancel routine
    if (Irp->Cancel)
    {
        // If the IRP was cancelled after we put in our cancel routine we
        // will get back NULL here and we will let the cancel routine handle
        // the IRP.  If NULL is not returned here then we know the IRP was 
        // cancelled before we inserted the cancel routine, and we
        // need to cancel the IRP
        if (IoSetCancelRoutine(Irp, NULL) != NULL)
        {
            RemoveEntryList(&Irp->Tail.Overlay.ListEntry);

            // drop the list protection
            KeReleaseSpinLock(&List->ListLock, oldIrql);

            // cancel the IRP
            status = STATUS_CANCELLED;
            Irp->IoStatus.Status = status;
            Irp->IoStatus.Information = 0;
            IoCompleteRequest(Irp, IO_NO_INCREMENT);

            return status;
        }
    }

    // mark irp pending since STATUS_PENDING is returned
    IoMarkIrpPending(Irp);
    status = STATUS_PENDING;

    // drop the list protection
    KeReleaseSpinLock(&List->ListLock, oldIrql);

    return status;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIRemoveHead
//      Removes an Irp entry from the head of list
//
//  Arguments:
//      IN  List
//              An instance of our list structure
//
//  Return Value:
//      IRP removed from head of list
//
PIRP JR3PCIRemoveHead(
    IN  PJR3PCI_LIST   List
    )
{
    PLIST_ENTRY entry;
    PIRP        irp;
    KIRQL       oldIrql;

    // Grab the list protection
    KeAcquireSpinLock(&List->ListLock, &oldIrql);

    // Make sure there are entries in the list
    if (IsListEmpty(&List->IrpList))
    {
        // drop the list protection
        KeReleaseSpinLock(&List->ListLock, oldIrql);

        return NULL;
    }

    // get a new IRP from the queue
    for (entry = List->IrpList.Flink; entry != &List->IrpList; entry = entry->Flink)
    {
        // get our IRP from the entry
        irp = CONTAINING_RECORD(entry, IRP, Tail.Overlay.ListEntry);

        ASSERT(irp->Type == IO_TYPE_IRP);

        // if we found an IRP, pull the queue cancel routine out of it
        // See if the IRP is canceled
        if (IoSetCancelRoutine(irp, NULL) == NULL)
        {
            // cancel routine already has a hold on this IRP, 
            // just go on to the next one
            irp = NULL;
        }
        else
        {
            // Found a usable IRP, pull the entry out of the list
            RemoveEntryList(entry);
            break;
        }
    }

    // drop the list protection
    KeReleaseSpinLock(&List->ListLock, oldIrql);

    return irp;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIRemoveTail
//      Removes an Irp entry from the tail of list
//
//  Arguments:
//      IN  List
//              An instance of our list structure
//
//  Return Value:
//      IRP removed from end of list
//
PIRP JR3PCIRemoveTail(
    IN  PJR3PCI_LIST   List
    )
{
    PLIST_ENTRY entry;
    PIRP        irp;
    KIRQL       oldIrql;

    // Grab the list protection
    KeAcquireSpinLock(&List->ListLock, &oldIrql);

    // Make sure there are entries in the list
    if (IsListEmpty(&List->IrpList))
    {
        // drop the list protection
        KeReleaseSpinLock(&List->ListLock, oldIrql);

        return NULL;
    }

    // get a new IRP from the queue
    for (entry = List->IrpList.Blink; entry != &List->IrpList; entry = entry->Blink)
    {
        // get our IRP from the entry
        irp = CONTAINING_RECORD(entry, IRP, Tail.Overlay.ListEntry);

        ASSERT(irp->Type == IO_TYPE_IRP);

        // if we found an IRP, pull the queue cancel routine out of it
        // See if the IRP is canceled
        if (IoSetCancelRoutine(irp, NULL) == NULL)
        {
            // cancel routine already has a hold on this IRP, 
            // just go on to the next one
            irp = NULL;
        }
        else
        {
            // Found a usable IRP, pull the entry out of the list
            RemoveEntryList(entry);
            break;
        }
    }

    // drop the list protection
    KeReleaseSpinLock(&List->ListLock, oldIrql);

    return irp;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIFlushList
//      Cancels all IRPs in the list, or all IRPs in the list related to a 
//      particular open handle.
//
//  Arguments:
//      IN  List
//              An instance of our list structure
//
//      IN  FileObject
//              If NULL all IRPs in list are cancelled, if non-NULL then all
//              IRPs related to this file object are cancelled.
//
//  Return Value:
//      none
//
VOID JR3PCIFlushList(
    IN  PJR3PCI_LIST   List,
    IN  PFILE_OBJECT        FileObject
    )
{
    PLIST_ENTRY         entry;
    PLIST_ENTRY         nextEntry;
    PIRP                irp;
    PIO_STACK_LOCATION  irpStack;
    KIRQL               oldIrql;
    LIST_ENTRY          cancelList;

    // initialize our cancel list
    InitializeListHead(&cancelList);

    // grab the list protection
    KeAcquireSpinLock(&List->ListLock, &oldIrql);

    // Look at the first entry in the list
    entry = List->IrpList.Flink;
    while (entry != &List->IrpList)
    {
        // get the next list entry
        nextEntry = entry->Flink;

        // Get the IRP from the entry
        irp = CONTAINING_RECORD(entry, IRP, Tail.Overlay.ListEntry);

        ASSERT(irp->Type == IO_TYPE_IRP);

        // Determine if we need to pull out of list
        if (FileObject != NULL)
        {
            // get the current IRP stack location from the IRP
            irpStack = IoGetCurrentIrpStackLocation(irp);

            if (irpStack->FileObject != FileObject)
            {
                // go to the next entry
                entry = nextEntry;

                // We are not flushing this IRP
                continue;
            }
        }

        // Attempt to cancel the IRP
        if (IoSetCancelRoutine(irp, NULL) == NULL)
        {
            // go to the next entry
            entry = nextEntry;

            // cancel routine already has this IRP,
            // just go on
            continue;
        }

        // pull the IRP from the list
        RemoveEntryList(entry);

        InsertTailList(&cancelList, entry);

        // go to the next entry
        entry = nextEntry;
    }

    // drop the list protection
    KeReleaseSpinLock(&List->ListLock, oldIrql);

    // Now clear out our cancel list
    while (!IsListEmpty(&cancelList))
    {
        // Get the first entry on the list
        entry = RemoveHeadList(&cancelList);

        // Get the IRP for that entry
        irp = CONTAINING_RECORD(entry, IRP, Tail.Overlay.ListEntry);

        // Cancel the IRP
        irp->IoStatus.Status = STATUS_CANCELLED;
        irp->IoStatus.Information = 0;
        IoCompleteRequest(irp, IO_NO_INCREMENT);
    }

    return;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIInvalidateList
//      Stops list from receiving anymore IRPs, all IRPs are completed upon
//      receipt
//
//  Arguments:
//      IN  List
//              An instance of our list structure
//
//  Return Value:
//      none
//
VOID JR3PCIInvalidateList(
    IN  PJR3PCI_LIST   List,
    IN  NTSTATUS                ErrorStatus
    )
{
    // indicate the list is shutdown
    List->ErrorStatus = ErrorStatus;

    // flush all requests from the list
    JR3PCIFlushList(List, NULL);

    return;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIListCancelRoutine
//      Cancel routine used for our cancel safe IRP list
//
//  Arguments:
//      IN  DeviceObject
//              Device object for our device
//
//      IN  Irp
//              IRP to be cancelled
//
//  Return Value:
//      none
//
VOID JR3PCIListCancelRoutine(
    IN  PDEVICE_OBJECT  DeviceObject,
    IN  PIRP            Irp
    )
{
    KIRQL           oldIrql;
    PJR3PCI_LIST   list;

    oldIrql = Irp->CancelIrql;

    // release the system cancel spinlock
    IoReleaseCancelSpinLock(DISPATCH_LEVEL);

    // get our list context from the IRP
    list = (PJR3PCI_LIST)Irp->Tail.Overlay.DriverContext[0];

    // grab the list protection
    KeAcquireSpinLockAtDpcLevel(&list->ListLock);

    // remove our IRP from the list
    RemoveEntryList(&Irp->Tail.Overlay.ListEntry);

    // drop the list protection
    KeReleaseSpinLock(&list->ListLock, oldIrql);

    // cancel the IRP
    Irp->IoStatus.Status = STATUS_CANCELLED;
    Irp->IoStatus.Information = 0;

    IoCompleteRequest(Irp, IO_NO_INCREMENT);

    return;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// JR3PCI_IO_LOCK
///////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIInitializeIoLock
//      Initializes io lock structure.
//
//  Arguments:
//      IN  IoLock
//              io lock to initialize
//
//      IN  DeviceObject
//              device object 
//
//  Return Value:
//      none
//
VOID JR3PCIInitializeIoLock(
    IN  PJR3PCI_IO_LOCK    IoLock, 
    IN  PDEVICE_OBJECT              DeviceObject
    )
{
    IoLock->DeviceObject = DeviceObject;
    KeInitializeEvent(&IoLock->StallCompleteEvent, NotificationEvent, FALSE);
    InitializeListHead(&IoLock->StallIrpList);
    KeInitializeSpinLock(&IoLock->IoLock);
    IoLock->StallCount = 1;
    IoLock->ActiveIrpCount = 0;
    IoLock->ErrorStatus = STATUS_SUCCESS;
    IoLock->CurrentIrp = NULL;

    return;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCICheckIoLock
//      checks if IRP is allowed to proceed.
//
//  Arguments:
//      IN  IoLock
//              io lock for our device
//
//      IN  Irp
//              new IRP
//
//  Return Value:
//      Status
//
NTSTATUS JR3PCICheckIoLock(
    IN  PJR3PCI_IO_LOCK    IoLock, 
    IN  PIRP                        Irp
    )
{
    NTSTATUS            status;
    KIRQL               oldIrql;
    PDEVICE_EXTENSION   deviceExtension;

    deviceExtension = (PDEVICE_EXTENSION)IoLock->DeviceObject->DeviceExtension;

    KeAcquireSpinLock(&IoLock->IoLock, &oldIrql);

    // check if device has been removed
    if (IoLock->ErrorStatus != STATUS_SUCCESS)
    {
        status = IoLock->ErrorStatus;
        KeReleaseSpinLock(&IoLock->IoLock, oldIrql);

        Irp->IoStatus.Status = status;
        IoCompleteRequest(Irp, IO_NO_INCREMENT);

        return status;
    }

    // check if io is stalled
    if (IoLock->StallCount > 0)
    {
        // check if Irp is not the one sent by JR3PCIUnlockIo
        if (IoLock->CurrentIrp != Irp)
        {
            // save device extension into the IRP
            Irp->Tail.Overlay.DriverContext[0] = IoLock;

            // stall the IRP
            InsertTailList(&IoLock->StallIrpList, &Irp->Tail.Overlay.ListEntry);

            // insert our queue cancel routine into the IRP
            IoSetCancelRoutine(Irp, JR3PCIPendingIoCancelRoutine);

            // see if IRP was canceled
            if (Irp->Cancel && (IoSetCancelRoutine(Irp, NULL) != NULL))
            {
                // IRP was canceled
                RemoveEntryList(&Irp->Tail.Overlay.ListEntry);

                // drop the lock
                KeReleaseSpinLock(&IoLock->IoLock, oldIrql);

                // cancel the IRP
                status = STATUS_CANCELLED;
                Irp->IoStatus.Status = status;
                IoCompleteRequest(Irp, IO_NO_INCREMENT);

                return status;
            }

            // mark irp pending since STATUS_PENDING is returned
            IoMarkIrpPending(Irp);
            status = STATUS_PENDING;

            // drop the lock
            KeReleaseSpinLock(&IoLock->IoLock, oldIrql);

            return status;
        }
        else
        {
            IoLock->CurrentIrp = NULL;
        }
    }

    // increment active io count
    ++IoLock->ActiveIrpCount;

    // drop the lock
    KeReleaseSpinLock(&IoLock->IoLock, oldIrql);

    status = STATUS_SUCCESS;
    return status;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIPendingIoCancelRoutine
//      Cancel routine for stalled IRPs.
//
//  Arguments:
//      IN  DeviceObject
//              our device object
//
//      IN  Irp
//              IRP to be canceled
//
//  Return Value:
//      None
//
VOID JR3PCIPendingIoCancelRoutine(
    IN  PDEVICE_OBJECT  DeviceObject,
    IN  PIRP            Irp
    )
{
    KIRQL           oldIrql;
    PJR3PCI_IO_LOCK  ioLock;

    // release the system cancel spinlock
    oldIrql = Irp->CancelIrql;
    IoReleaseCancelSpinLock(DISPATCH_LEVEL);

    // get our queue from the IRP
    ioLock = (PJR3PCI_IO_LOCK)Irp->Tail.Overlay.DriverContext[0];

    // grab the queue protection
    KeAcquireSpinLockAtDpcLevel(&ioLock->IoLock);

    // remove our IRP from the queue
    RemoveEntryList(&Irp->Tail.Overlay.ListEntry);

    // drop the queue protection
    KeReleaseSpinLock(&ioLock->IoLock, oldIrql);

    // cancel the IRP
    Irp->IoStatus.Status = STATUS_CANCELLED;
    IoCompleteRequest(Irp, IO_NO_INCREMENT);

    return;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIIncrementIoCount
//      increment active io count.
//
//  Arguments:
//      IN  IoLock
//              io lock for our device
//
//  Return Value:
//      Status
//
NTSTATUS JR3PCIIncrementIoCount(
    IN  PJR3PCI_IO_LOCK    IoLock
    )
{
    KIRQL       oldIrql;
    NTSTATUS    status;

    KeAcquireSpinLock(&IoLock->IoLock, &oldIrql);

    if (IoLock->ErrorStatus != STATUS_SUCCESS)
    {
        status = IoLock->ErrorStatus;
    }
    else if (IoLock->StallCount > 0)
    {
        status = STATUS_DEVICE_BUSY;
    }
    else
    {
        ++IoLock->ActiveIrpCount;
        status = STATUS_SUCCESS;
    }

    KeReleaseSpinLock(&IoLock->IoLock, oldIrql);

    return status;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIDecrementIoCount
//      decrements active io count.
//
//  Arguments:
//      IN  IoLock
//              io lock for our device
//
//  Return Value:
//      None
//
VOID JR3PCIDecrementIoCount(
    IN  PJR3PCI_IO_LOCK    IoLock
    )
{
    KIRQL       oldIrql;

    KeAcquireSpinLock(&IoLock->IoLock, &oldIrql);

    if (--IoLock->ActiveIrpCount == 0)
    {
        KeSetEvent(&IoLock->StallCompleteEvent, IO_NO_INCREMENT, FALSE);
    }

    KeReleaseSpinLock(&IoLock->IoLock, oldIrql);

    return;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCILockIo
//      Locks new IRP processing.
//
//  Arguments:
//      IN  IoLock
//              io lock for our device
//
//  Return Value:
//      None
//
VOID JR3PCILockIo(
    IN  PJR3PCI_IO_LOCK    IoLock
    )
{
    KIRQL       oldIrql;

    KeAcquireSpinLock(&IoLock->IoLock, &oldIrql);

    // increment stall count
    ++IoLock->StallCount;

    KeReleaseSpinLock(&IoLock->IoLock, oldIrql);

    return;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIWaitForStopIo
//      Waits for all active io to complete.
//
//  Arguments:
//      IN  IoLock
//              io lock for our device
//
//  Return Value:
//      None
//
VOID JR3PCIWaitForStopIo(
    IN  PJR3PCI_IO_LOCK    IoLock
    )
{
    KIRQL       oldIrql;
    BOOLEAN     bWait;

    KeAcquireSpinLock(&IoLock->IoLock, &oldIrql);

    // clear stall completed event
    KeClearEvent(&IoLock->StallCompleteEvent);

    // check if we need to wait for some IRPs to finish
    bWait = (IoLock->ActiveIrpCount != 0);

    KeReleaseSpinLock(&IoLock->IoLock, oldIrql);

    if (bWait)
    {
        // wait for outstanding IRPs to complete
        KeWaitForSingleObject(&IoLock->StallCompleteEvent, Executive, KernelMode, FALSE, NULL);
    }

    return;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIUnlockIo
//      Locks new IRP processing.
//
//  Arguments:
//      IN  IoLock
//              io lock for our device
//
//  Return Value:
//      None
//
VOID JR3PCIUnlockIo(
    IN  PJR3PCI_IO_LOCK    IoLock
    )
{
    PLIST_ENTRY         entry;
    PIRP                irp;
    KIRQL               oldIrql;
    PIO_STACK_LOCATION  irpStack;

    // Grab the list protection
    KeAcquireSpinLock(&IoLock->IoLock, &oldIrql);

    // if StallCount is 1 then we need to flush all pending IRPs
    while ((IoLock->StallCount == 1) && (!IsListEmpty(&IoLock->StallIrpList)))
    {
        entry = RemoveHeadList(&IoLock->StallIrpList);
        irp = CONTAINING_RECORD(entry, IRP, Tail.Overlay.ListEntry);

        if (IoSetCancelRoutine(irp, NULL) == NULL)
        {
            // irp was canceled
            // let cancel routine deal with it.
            // we need to initialize IRP's list entry, since
            // our cancel routine expects the IRP to be in a list
            InitializeListHead(&irp->Tail.Overlay.ListEntry);
        }
        else
        {
            IoLock->CurrentIrp = irp;
            KeReleaseSpinLock(&IoLock->IoLock, oldIrql);

            // call DriverDispatch
            irpStack = IoGetCurrentIrpStackLocation(irp);
            IoLock->DeviceObject->DriverObject->MajorFunction[irpStack->MajorFunction](
                IoLock->DeviceObject,
                irp
                );

            KeAcquireSpinLock(&IoLock->IoLock, &oldIrql);
        }
    }

    --IoLock->StallCount;
    KeReleaseSpinLock(&IoLock->IoLock, oldIrql);

    return;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIFlushPendingIo
//      Cancels stalled IRPs for a particular file object.
//
//  Arguments:
//      IN  IoLock
//              io lock for our device
//
//      IN  FileObject
//              file object for about to be closed handle
//
//  Return Value:
//      None
//
VOID JR3PCIFlushPendingIo(
    IN  PJR3PCI_IO_LOCK    IoLock,
    IN  PFILE_OBJECT                FileObject
    )
{
    PLIST_ENTRY         entry;
    PLIST_ENTRY         nextEntry;
    PIRP                irp;
    PIO_STACK_LOCATION  irpStack;
    KIRQL               oldIrql;
    LIST_ENTRY          cancelList;

    // initialize our cancel list
    InitializeListHead(&cancelList);

    // grab the list protection
    KeAcquireSpinLock(&IoLock->IoLock, &oldIrql);

    // Look at the first entry in the list
    entry = IoLock->StallIrpList.Flink;
    while (entry != &IoLock->StallIrpList)
    {
        // get the next list entry
        nextEntry = entry->Flink;

        // Get the IRP from the entry
        irp = CONTAINING_RECORD(entry, IRP, Tail.Overlay.ListEntry);

        ASSERT(irp->Type == IO_TYPE_IRP);

        // Determine if we need to pull out of list
        if (FileObject != NULL)
        {
            // get the current IRP stack location from the IRP
            irpStack = IoGetCurrentIrpStackLocation(irp);

            if (irpStack->FileObject != FileObject)
            {
                // go to the next entry
                entry = nextEntry;

                // We are not flushing this IRP
                continue;
            }
        }

        // Attempt to cancel the IRP
        if (IoSetCancelRoutine(irp, NULL) == NULL)
        {
            // go to the next entry
            entry = nextEntry;

            // cancel routine already has this IRP,
            // just go on
            continue;
        }

        // pull the IRP from the list
        RemoveEntryList(entry);

        InsertTailList(&cancelList, entry);

        // go to the next entry
        entry = nextEntry;
    }

    // drop the list protection
    KeReleaseSpinLock(&IoLock->IoLock, oldIrql);

    // Now clear out our cancel list
    while (!IsListEmpty(&cancelList))
    {
        // Get the first entry on the list
        entry = RemoveHeadList(&cancelList);

        // Get the IRP for that entry
        irp = CONTAINING_RECORD(entry, IRP, Tail.Overlay.ListEntry);

        // Cancel the IRP
        irp->IoStatus.Status = STATUS_CANCELLED;
        irp->IoStatus.Information = 0;
        IoCompleteRequest(irp, IO_NO_INCREMENT);
    }

    return;
}

VOID JR3PCIInvalidateIo(
    IN  PJR3PCI_IO_LOCK    IoLock,
    IN  NTSTATUS                    ErrorStatus
    )
{
    // indicate the list is shutdown
    IoLock->ErrorStatus = ErrorStatus;

    // flush all requests from the list
    JR3PCIFlushPendingIo(IoLock, NULL);

    return;
}
