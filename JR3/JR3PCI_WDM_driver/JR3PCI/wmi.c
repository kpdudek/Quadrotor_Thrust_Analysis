/**********************************************************************
;       Copyright 2015 JR3, Inc.
;
;**********************************************************************/

#include "pch.h"

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCISystemControlDispatch
//      Dispatch routine for IRP_MJ_SYSTEM_CONTROL requests.
//
//  Arguments:
//      IN  DeviceObject
//              pointer to the device object for our device
//
//      IN  Irp
//              the IRP_MJ_SYSTEM_CONTROL IRP
//
//  Return Value:
//      NT status code.
//
NTSTATUS JR3PCISystemControlDispatch(
    IN  PDEVICE_OBJECT  DeviceObject,
    IN  PIRP            Irp
    )
{
    PDEVICE_EXTENSION    deviceExtension;
    NTSTATUS                        status;
    PIO_STACK_LOCATION              stack;

    JR3PCIDebugPrint(DBG_WMI, DBG_TRACE, __FUNCTION__"++. IRP %p", Irp);

    JR3PCIDumpIrp(Irp);

    deviceExtension = (PDEVICE_EXTENSION)DeviceObject->DeviceExtension;

    // protect againt IRP_MN_REMOVE_DEVICE
    if (!JR3PCIAcquireRemoveLock(deviceExtension))
    {
        status = STATUS_DELETE_PENDING;

        Irp->IoStatus.Status = status;
        IoCompleteRequest (Irp, IO_NO_INCREMENT);

        JR3PCIDebugPrint(DBG_WMI, DBG_WARN, __FUNCTION__"--. IRP %p, STATUS %x", Irp, status);

        return status;
    }

    // just pass it through
    IoSkipCurrentIrpStackLocation(Irp);
    status = IoCallDriver(deviceExtension->LowerDeviceObject, Irp);

    JR3PCIReleaseRemoveLock(deviceExtension);

    JR3PCIDebugPrint(DBG_WMI, DBG_TRACE, __FUNCTION__"--. IRP %p, STATUS %x", Irp, status);

    return status;
}
