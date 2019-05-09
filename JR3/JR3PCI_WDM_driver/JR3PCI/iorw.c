/**********************************************************************
;       Copyright 2015 JR3, Inc.
;
;**********************************************************************/

#include "pch.h"
#include "version.h"

void JR3PCIWriteWord(
	DEVICE_EXTENSION * pDeviceExtension, 
	JR3PCI_WRITE_WORD_REQUEST_PARAMS * pWriteWordRequestParams, 
	JR3PCI_WRITE_WORD_RESPONSE_PARAMS * pWriteWordResponseParams)
{
//	JR3PCIDebugPrint(DBG_IO, DBG_INFO, __FUNCTION__"++");

	ASSERT(pWriteWordRequestParams->ucChannel <= pDeviceExtension->ulSupportedChannels);
	if(pWriteWordRequestParams->ucChannel > pDeviceExtension->ulSupportedChannels)
	{
		pWriteWordResponseParams->iStatus = JR3PCI_STATUS_INVALID_CHANNEL_INDEX;
		return;
	}

	// Write the WORD.
	ULONG ulChannelBarOffset = pWriteWordRequestParams->ucChannel * JR3_BAR_RANGE_PER_CH;
	USHORT * pusWriteAddress = (PUSHORT) (pDeviceExtension->pulBar0Base + (ulChannelBarOffset / 4) + JR3_DATA_OFFSET + pWriteWordRequestParams->ulOffset);
	WRITE_REGISTER_USHORT(pusWriteAddress, pWriteWordRequestParams->usData);

	pWriteWordResponseParams->iStatus = JR3PCI_STATUS_OK;

//	JR3PCIDebugPrint(DBG_IO, DBG_INFO, __FUNCTION__"--");
}

void JR3PCIReadWord(
	DEVICE_EXTENSION * pDeviceExtension, 
	JR3PCI_READ_WORD_REQUEST_PARAMS * pReadWordRequestParams, 
	JR3PCI_READ_WORD_RESPONSE_PARAMS * pReadWordResponseParams)
{
//	JR3PCIDebugPrint(DBG_IO, DBG_INFO, __FUNCTION__"++");

	ASSERT(pReadWordRequestParams->ucChannel <= pDeviceExtension->ulSupportedChannels);
	if(pReadWordRequestParams->ucChannel > pDeviceExtension->ulSupportedChannels)
	{
		pReadWordResponseParams->iStatus = JR3PCI_STATUS_INVALID_CHANNEL_INDEX;
		return;
	}

	// Read the WORD.
	ULONG ulChannelBarOffset = pReadWordRequestParams->ucChannel * JR3_BAR_RANGE_PER_CH;
	USHORT * pusReadAddress = (PUSHORT) (pDeviceExtension->pulBar0Base + (ulChannelBarOffset / 4) + JR3_DATA_OFFSET + pReadWordRequestParams->ulOffset);
	pReadWordResponseParams->usData = READ_REGISTER_USHORT(pusReadAddress);

	pReadWordResponseParams->iStatus = JR3PCI_STATUS_OK;

//	JR3PCIDebugPrint(DBG_IO, DBG_INFO, __FUNCTION__"--");
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIDeviceIoControlDispatch
//      Handled incoming IOCTL requests
//
//  Arguments:
//      IN  DeviceObject
//              Device object for our device
//
//      IN  Irp
//              The IOCTL IRP to handle
//
//  Return Value:
//      NT status code
//
NTSTATUS JR3PCIDeviceIoControlDispatch(
    IN  PDEVICE_OBJECT  DeviceObject,
    IN  PIRP            Irp
    )
{
    PIO_STACK_LOCATION              irpStack;
    NTSTATUS                        status;
    PDEVICE_EXTENSION		pDeviceExtension;
    ULONG                           inputLength;
    ULONG                           outputLength;
	PULONG							pulInValue;
	PULONG							pulOutValue;

//    JR3PCIDebugPrint(DBG_IO, DBG_TRACE, __FUNCTION__"++. IRP %p", Irp);

    pDeviceExtension = (PDEVICE_EXTENSION)DeviceObject->DeviceExtension;

    // Get our IRP stack location
    irpStack = IoGetCurrentIrpStackLocation(Irp);

    // Get the buffer lengths
    inputLength = irpStack->Parameters.DeviceIoControl.InputBufferLength;
    outputLength = irpStack->Parameters.DeviceIoControl.OutputBufferLength;

	status = JR3PCICheckIoLock(&pDeviceExtension->IoLock, Irp);
	if (!NT_SUCCESS(status) || (status == STATUS_PENDING))
	{
		JR3PCIDebugPrint(DBG_IO, DBG_WARN, __FUNCTION__"--. IRP %p STATUS %x", Irp, status);

		return status;
	}

	ULONG ulIoControlCode = irpStack->Parameters.DeviceIoControl.IoControlCode;
    switch (ulIoControlCode) 
    {
		case IOCTL_JR3PCI_WRITE_WORD:
			{
//				JR3PCIDebugPrint(DBG_IO, DBG_INFO, __FUNCTION__": IOCTL_JR3PCI_WRITE_WORD");

				BOOLEAN bInputLenOk = (inputLength >= sizeof(JR3PCI_WRITE_WORD_REQUEST_PARAMS));
				BOOLEAN bOutputLenOk = (outputLength >= sizeof(JR3PCI_WRITE_WORD_RESPONSE_PARAMS));

				ASSERT(bInputLenOk && bOutputLenOk);
				if(!bInputLenOk || !bOutputLenOk)
				{
					JR3PCIDebugPrint(DBG_IO, DBG_TRACE, __FUNCTION__"-- (STATUS_BUFFER_TOO_SMALL). IRP %p", Irp);
					return CompleteIRP(Irp, STATUS_BUFFER_TOO_SMALL, 0);
				}

				JR3PCI_WRITE_WORD_REQUEST_PARAMS * pWriteWordRequestParams = (JR3PCI_WRITE_WORD_REQUEST_PARAMS*) Irp->AssociatedIrp.SystemBuffer;
				JR3PCI_WRITE_WORD_RESPONSE_PARAMS * pWriteWordResponseParams = (JR3PCI_WRITE_WORD_RESPONSE_PARAMS*) Irp->AssociatedIrp.SystemBuffer;

				JR3PCIWriteWord(pDeviceExtension, pWriteWordRequestParams, pWriteWordResponseParams);

				//////////////////////////////////////
				// Complete the IRP.
				//////////////////////////////////////

//				JR3PCIDebugPrint(DBG_IO, DBG_TRACE, __FUNCTION__"-- (STATUS_SUCCESS). IRP %p", Irp);

				return CompleteIRP(Irp, STATUS_SUCCESS, sizeof(JR3PCI_WRITE_WORD_RESPONSE_PARAMS));
			}		
			break;

		case IOCTL_JR3PCI_READ_WORD:
			{
//				JR3PCIDebugPrint(DBG_IO, DBG_INFO, __FUNCTION__": IOCTL_JR3PCI_READ_WORD");

				BOOLEAN bInputLenOk = (inputLength >= sizeof(JR3PCI_READ_WORD_REQUEST_PARAMS));
				BOOLEAN bOutputLenOk = (outputLength >= sizeof(JR3PCI_READ_WORD_RESPONSE_PARAMS));

				ASSERT(bInputLenOk && bOutputLenOk);
				if(!bInputLenOk || !bOutputLenOk)
				{
					JR3PCIDebugPrint(DBG_IO, DBG_TRACE, __FUNCTION__"-- (STATUS_BUFFER_TOO_SMALL). IRP %p", Irp);
					return CompleteIRP(Irp, STATUS_BUFFER_TOO_SMALL, 0);
				}

				JR3PCI_READ_WORD_REQUEST_PARAMS * pReadWordRequestParams = (JR3PCI_READ_WORD_REQUEST_PARAMS*) Irp->AssociatedIrp.SystemBuffer;
				JR3PCI_READ_WORD_RESPONSE_PARAMS * pReadWordResponseParams = (JR3PCI_READ_WORD_RESPONSE_PARAMS*) Irp->AssociatedIrp.SystemBuffer;

				JR3PCIReadWord(pDeviceExtension, pReadWordRequestParams, pReadWordResponseParams);

				//////////////////////////////////////
				// Complete the IRP.
				//////////////////////////////////////

//				JR3PCIDebugPrint(DBG_IO, DBG_TRACE, __FUNCTION__"-- (STATUS_SUCCESS). IRP %p", Irp);

				return CompleteIRP(Irp, STATUS_SUCCESS, sizeof(JR3PCI_READ_WORD_RESPONSE_PARAMS));
			}		
			break;

		case IOCTL_JR3PCI_SUPPORTED_CHANNELS:
			{
//				JR3PCIDebugPrint(DBG_IO, DBG_INFO, __FUNCTION__": IOCTL_JR3PCI_SUPPORTED_CHANNELS");

				BOOLEAN bOutputLenOk = (outputLength >= sizeof(JR3PCI_SUPPORTED_CHANNELS_RESPONSE_PARAMS));

				ASSERT(bOutputLenOk);
				if(!bOutputLenOk)
				{
					JR3PCIDebugPrint(DBG_IO, DBG_TRACE, __FUNCTION__"-- (STATUS_BUFFER_TOO_SMALL). IRP %p", Irp);
					return CompleteIRP(Irp, STATUS_BUFFER_TOO_SMALL, 0);
				}

				JR3PCI_SUPPORTED_CHANNELS_RESPONSE_PARAMS * pSupportedChannelsResponseParams = 
					(JR3PCI_SUPPORTED_CHANNELS_RESPONSE_PARAMS*) Irp->AssociatedIrp.SystemBuffer;

				pSupportedChannelsResponseParams->ulSupportedChannels = pDeviceExtension->ulSupportedChannels;

				//////////////////////////////////////
				// Complete the IRP.
				//////////////////////////////////////

//				JR3PCIDebugPrint(DBG_IO, DBG_TRACE, __FUNCTION__"-- (STATUS_SUCCESS). IRP %p", Irp);

				return CompleteIRP(Irp, STATUS_SUCCESS, sizeof(JR3PCI_SUPPORTED_CHANNELS_RESPONSE_PARAMS));
			}		
			break;

		default:
			break;
    }

    status = STATUS_SUCCESS;
    Irp->IoStatus.Status = status;
	Irp->IoStatus.Information = 4;
    IoCompleteRequest (Irp, IO_NO_INCREMENT);

//    JR3PCIDebugPrint(DBG_IO, DBG_TRACE, __FUNCTION__"--. IRP %p STATUS %x", Irp, status);

    return status;
}
