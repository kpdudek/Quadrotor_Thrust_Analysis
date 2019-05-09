/**********************************************************************
;       Copyright 2015 JR3, Inc.
;
;**********************************************************************/

#include "pch.h"

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIPnpDispatch
//      Dispatch routine to handle PnP requests
//
//  Arguments:
//      IN  DeviceObject
//              pointer to our device object
//
//      IN  Irp
//              pointer to the PnP IRP
//
//  Return Value:
//      NT status code
//
NTSTATUS JR3PCIPnpDispatch(
    IN PDEVICE_OBJECT   DeviceObject,
    IN PIRP             Irp
    )
{
    PDEVICE_EXTENSION    deviceExtension;
    PIO_STACK_LOCATION              irpStack;
    NTSTATUS                        status;
    PDEVICE_CAPABILITIES            deviceCapabilities;
    ULONG                           requestCount;
    ULONG                           index;
    PPNP_DEVICE_STATE               deviceState;
    UNICODE_STRING                  win32Name;

    JR3PCIDebugPrint(DBG_PNP, DBG_TRACE, __FUNCTION__"++. IRP %p", Irp);

    JR3PCIDumpIrp(Irp);

    // Get our device extension from the device object
    deviceExtension = (PDEVICE_EXTENSION)DeviceObject->DeviceExtension;

    // Get our current IRP stack location
    irpStack = IoGetCurrentIrpStackLocation(Irp);

    // Make sure we can accept IRPs
    if (!JR3PCIAcquireRemoveLock(deviceExtension))
    {
        status = STATUS_NO_SUCH_DEVICE;

        Irp->IoStatus.Status = status;
        IoCompleteRequest(Irp, IO_NO_INCREMENT);

        JR3PCIDebugPrint(DBG_PNP, DBG_WARN, __FUNCTION__"--. IRP %p STATUS %x", Irp, status);

        return status;
    }

    switch (irpStack->MinorFunction) 
    {
    case IRP_MN_START_DEVICE:

        // The device stack must be started from the bottom up.  
        // So, we send the IRP down the stack and wait so that 
        // all devices below ours have started before we process 
        // this IRP and start ourselves.
        status = JR3PCISubmitIrpSync(deviceExtension->LowerDeviceObject, Irp);
        if (!NT_SUCCESS(status))
        {
            // Someone below us failed to start, so just complete with error
            break;
        }

        // Lower drivers have finished their start operation, so now
        // we process ours.

        status = JR3PCIStartDevice(deviceExtension, Irp);
        if (!NT_SUCCESS(status))
        {
            JR3PCIFreeResources(deviceExtension);
            break;
        }

        // Update our PnP state
        deviceExtension->PnpState = PnpStateStarted;

        // restart any stalled queues
        JR3PCIRestartQueues(deviceExtension);
        break;

    case IRP_MN_QUERY_STOP_DEVICE:

        if (JR3PCIIsStoppable(deviceExtension)) 
        {
            // Device is stoppable.

            // pause io request processing
            JR3PCIStallQueues(deviceExtension);

            // Update our PnP state
            deviceExtension->PreviousPnpState = deviceExtension->PnpState;
            deviceExtension->PnpState = PnpStateStopPending;

            // We must set Irp->IoStatus.Status to STATUS_SUCCESS before
            // passing it down.
            Irp->IoStatus.Status = STATUS_SUCCESS;
            IoSkipCurrentIrpStackLocation (Irp);
            status = IoCallDriver(deviceExtension->LowerDeviceObject, Irp);

            // Decrement the active I/O count
            JR3PCIReleaseRemoveLock(deviceExtension);

            JR3PCIDebugPrint(DBG_PNP, DBG_TRACE, __FUNCTION__"--. IRP %p STATUS %x", Irp, status);

            return status;
        }
        else
        {
            // device is not currently stoppable, fail the request
            status = STATUS_UNSUCCESSFUL;
        }

        break;

   case IRP_MN_CANCEL_STOP_DEVICE:

        // Send this IRP down and wait for it to come back,
        // restart our stall fifo,
        // and process all the previously queued up IRPs.

        // First check to see whether we received a query before this
        // cancel. This could happen if someone above us failed a query
        // and passed down the subsequent cancel.
        if (deviceExtension->PnpState == PnpStateStopPending) 
        {
            status = JR3PCISubmitIrpSync(deviceExtension->LowerDeviceObject,Irp);
            if (NT_SUCCESS(status))
            {
                // restore previous pnp state
                deviceExtension->PnpState = deviceExtension->PreviousPnpState;

                // restart the queues
                JR3PCIRestartQueues(deviceExtension);
            } 
            else 
            {
                // Somebody below us failed the cancel
                // this is a fatal error.
                ASSERTMSG("Cancel stop failed!", FALSE);
                JR3PCIDebugPrint(DBG_PNP, DBG_ERR, __FUNCTION__"--. IRP %p STATUS %x", Irp, status);
            }
        } 
        else 
        {
            // Spurious cancel so we just complete the request.
            status = STATUS_SUCCESS;
        }

        break;

    case IRP_MN_STOP_DEVICE:
        // Mark the device as stopped.
        deviceExtension->PnpState = PnpStateStopped;

        // release our resources
        JR3PCIFreeResources(deviceExtension);

        // send the request down, and we are done
        Irp->IoStatus.Status = STATUS_SUCCESS;
        IoSkipCurrentIrpStackLocation (Irp);
        status = IoCallDriver(deviceExtension->LowerDeviceObject, Irp);

        JR3PCIReleaseRemoveLock(deviceExtension);

        JR3PCIDebugPrint(DBG_PNP, DBG_TRACE, __FUNCTION__"--. IRP %p STATUS %x", Irp, status);

        return status;

    case IRP_MN_QUERY_REMOVE_DEVICE:

        if (JR3PCIIsRemovable(deviceExtension)) 
        {
            // pause io request processing
            JR3PCIStallQueues(deviceExtension);

            // Update our PnP state
            deviceExtension->PreviousPnpState = deviceExtension->PnpState;
            deviceExtension->PnpState = PnpStateRemovePending;

            // Now just send the request down and we are done
            Irp->IoStatus.Status = STATUS_SUCCESS;
            IoSkipCurrentIrpStackLocation (Irp);

            status = IoCallDriver(deviceExtension->LowerDeviceObject, Irp);

            // decrement the I/O count
            JR3PCIReleaseRemoveLock(deviceExtension);

            JR3PCIDebugPrint(DBG_PNP, DBG_TRACE, __FUNCTION__"--. IRP %p STATUS %x", Irp, status);

            return status;
        }
        else
        {
            // Our device is not removable, just fail the request
            status = STATUS_UNSUCCESSFUL;
        }

        break;

    case IRP_MN_CANCEL_REMOVE_DEVICE:

        // First check to see whether we have received a prior query
        // remove request. It could happen that we did not if
        // someone above us failed a query remove and passed down the
        // subsequent cancel remove request.
        if (PnpStateRemovePending == deviceExtension->PnpState)
        {
            status = JR3PCISubmitIrpSync(deviceExtension->LowerDeviceObject, Irp);

            if (NT_SUCCESS(status))
            {
                // restore pnp state, since remove was canceled
                deviceExtension->PnpState = deviceExtension->PreviousPnpState;

                // restart the queues
                JR3PCIRestartQueues(deviceExtension);
            }
            else
            {
                // Nobody can fail this IRP. This is a fatal error.
                ASSERTMSG("IRP_MN_CANCEL_REMOVE_DEVICE failed. Fatal error!", FALSE);

                JR3PCIDebugPrint(DBG_PNP, DBG_TRACE, __FUNCTION__"--. IRP %p STATUS %x", Irp, status);
            }
        }
        else
        {
            // Spurious cancel remove request so we just complete it
            status = STATUS_SUCCESS;
        }

        break;

   case IRP_MN_SURPRISE_REMOVAL:

        // The device has been unexpectedly removed from the machine
        // and is no longer available for I/O.
        // We must return device and memory resources,
        // disable interfaces. We will defer failing any outstanding
        // request to IRP_MN_REMOVE.

        // stall all the queues
        JR3PCIStallQueues(deviceExtension);

        // flush pending io list
        JR3PCIInvalidateIo(&deviceExtension->IoLock, STATUS_NO_SUCH_DEVICE);

        // update pnp state
        deviceExtension->PnpState = PnpStateSurpriseRemoved;

		// Return any resources acquired during device startup.
        JR3PCIFreeResources(deviceExtension);

        // We must set Irp->IoStatus.Status to STATUS_SUCCESS before
        // passing it down.
        Irp->IoStatus.Status = STATUS_SUCCESS;
        IoSkipCurrentIrpStackLocation (Irp);
        
        status = IoCallDriver(deviceExtension->LowerDeviceObject, Irp);

        // Adjust the active I/O count
        JR3PCIReleaseRemoveLock(deviceExtension);

        JR3PCIDebugPrint(DBG_PNP, DBG_TRACE, __FUNCTION__"--. IRP %p STATUS %x", Irp, status);

        return status;

   case IRP_MN_REMOVE_DEVICE:

        // The Plug & Play system has dictated the removal of this device.  We
        // have no choice but to detach and delete the device object.

        if (deviceExtension->PnpState != PnpStateSurpriseRemoved)
        {
            // flush pending io list
            JR3PCIInvalidateIo(&deviceExtension->IoLock, STATUS_NO_SUCH_DEVICE);

            JR3PCIFreeResources(deviceExtension);
        }

        // Update our PnP state
        deviceExtension->PnpState = PnpStateRemoved;

        JR3PCIReleaseRemoveLock(deviceExtension);
        JR3PCIWaitForSafeRemove(deviceExtension);

        // Send the remove IRP down the stack.
        Irp->IoStatus.Status = STATUS_SUCCESS;
        IoSkipCurrentIrpStackLocation (Irp);
        status = IoCallDriver (deviceExtension->LowerDeviceObject, Irp);

        // Detach our device object from the device stack
        IoDetachDevice(deviceExtension->LowerDeviceObject);
        
        RtlInitUnicodeString(&win32Name, L"\\??\\JR3PCI1");
        IoDeleteSymbolicLink(&win32Name);

        // attempt to delete our device object
        IoDeleteDevice(deviceExtension->pDeviceObject);

        JR3PCIDebugPrint(DBG_PNP, DBG_TRACE, __FUNCTION__"--. IRP %p STATUS %x", Irp, status);

        return status;

    case IRP_MN_QUERY_CAPABILITIES:

        // Check the device capabilities struct
        deviceCapabilities = 
            irpStack->Parameters.DeviceCapabilities.Capabilities;

        if (deviceCapabilities->Version != 1 ||
            deviceCapabilities->Size < sizeof(DEVICE_CAPABILITIES))
        {
            // We don't support this version. Fail the request
            break;
        }

        // Pass the IRP down
        status = JR3PCISubmitIrpSync(deviceExtension->LowerDeviceObject, Irp);

        // Lower drivers have finished their operation, so now
        // we can finish ours.
        if (NT_SUCCESS(status)) 
        {
            //*****************************************************************
            //*****************************************************************
            // TODO: Override the device capabilities 
            //       set by the underlying drivers here.
            //*****************************************************************
            //*****************************************************************
        }

        break;

    default:
        // Pass down any unknown requests.
        IoSkipCurrentIrpStackLocation(Irp);
        status = IoCallDriver(deviceExtension->LowerDeviceObject, Irp);

        // Adjust our active I/O count
        JR3PCIReleaseRemoveLock(deviceExtension);

        JR3PCIDebugPrint(DBG_PNP, DBG_TRACE, __FUNCTION__"--. IRP %p STATUS %x", Irp, status);

        return status;
    }

    Irp->IoStatus.Status = status;
    IoCompleteRequest (Irp, IO_NO_INCREMENT);

    // Adjust the active I/O count
    JR3PCIReleaseRemoveLock(deviceExtension);

    JR3PCIDebugPrint(DBG_PNP, DBG_TRACE, __FUNCTION__"--. IRP %p STATUS %x", Irp, status);

    return status;
}
