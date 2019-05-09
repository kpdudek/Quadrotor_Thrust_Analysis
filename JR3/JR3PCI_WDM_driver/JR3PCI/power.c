/**********************************************************************
;       Copyright 2015 JR3, Inc.
;
;**********************************************************************/

#include "pch.h"

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIPowerDispatch 
//      Dispatch routine for IRPs of IRP_MJ_POWER type
//
//  Arguments:
//      IN  DeviceObject
//              Device object for our driver
//
//      IN  Irp
//              The power IRP to handle
//
//  Return Value:
//      Status
//
NTSTATUS JR3PCIPowerDispatch(
    IN  PDEVICE_OBJECT  DeviceObject,
    IN  PIRP            Irp
    )
{
    PDEVICE_EXTENSION    deviceExtension;
    NTSTATUS                        status;
    PIO_STACK_LOCATION              irpStack;

    JR3PCIDebugPrint(DBG_POWER, DBG_TRACE, __FUNCTION__"++. IRP %p", Irp);

    JR3PCIDumpIrp(Irp);

    // Get our current IRP stack location
    irpStack = IoGetCurrentIrpStackLocation(Irp);

    // Get our device extension
    deviceExtension = (PDEVICE_EXTENSION)DeviceObject->DeviceExtension;

    // check if device has been removed
    if (!JR3PCIAcquireRemoveLock(deviceExtension))
    {
        status = STATUS_NO_SUCH_DEVICE;

        PoStartNextPowerIrp(Irp);
        Irp->IoStatus.Status = status;
        IoCompleteRequest(Irp, IO_NO_INCREMENT);

        JR3PCIDebugPrint(DBG_POWER, DBG_WARN, __FUNCTION__"--. IRP %p STATUS %x", Irp, status);

        return status;
    }

    // If our device has not been started, we just pass the 
    // power requests down the stack
    if (deviceExtension->PnpState == PnpStateNotStarted) 
    {
        PoStartNextPowerIrp(Irp);
        IoSkipCurrentIrpStackLocation(Irp);

        status = PoCallDriver(deviceExtension->LowerDeviceObject, Irp);

        // Release Remove Lock
        JR3PCIReleaseRemoveLock(deviceExtension);

        JR3PCIDebugPrint(DBG_POWER, DBG_WARN, __FUNCTION__"--. IRP %p STATUS %x", Irp, status);

        return status;
    }

    // Determine the power IRP type
    switch(irpStack->MinorFunction)
    {
    case IRP_MN_QUERY_POWER:
    case IRP_MN_SET_POWER:
    case IRP_MN_WAIT_WAKE:
    case IRP_MN_POWER_SEQUENCE:
    default:
        // default case, just send the IRP down and let other drivers
        // in the stack handle it

        // Let the power manager know we can handle another
        // power IRP of this type
        PoStartNextPowerIrp(Irp);

        // send the IRP down the stack
        IoSkipCurrentIrpStackLocation(Irp);

        // Drivers must use PoCallDriver, rather than IoCallDriver,
        // to pass power IRPs. PoCallDriver allows the Power Manager
        // to ensure that power IRPs are properly synchronized throughout
        // the system.
        status = PoCallDriver(deviceExtension->LowerDeviceObject, Irp);

        // Adjust our IRP count
        JR3PCIReleaseRemoveLock(deviceExtension);

        break;
    }

    JR3PCIDebugPrint(DBG_POWER, DBG_TRACE, __FUNCTION__"--. IRP %p STATUS %x", Irp, status);
    return status;
}
