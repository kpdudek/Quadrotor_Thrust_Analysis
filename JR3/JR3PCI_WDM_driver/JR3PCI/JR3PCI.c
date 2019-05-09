/**********************************************************************
;       Copyright 2015 JR3, Inc.
;
;**********************************************************************/

#include "pch.h"
#include "jr3pci3.idm"

// We use global data instead of a driver extension.
JR3PCI_DATA g_Data;

ULONG VirtualToPhysicalAddress(PVOID pVirtualAddress)
{
	PHYSICAL_ADDRESS pa = MmGetPhysicalAddress(pVirtualAddress);
	return pa.u.LowPart;
}

PVOID PhysicalToVirtualAddress(ULONG ulPhysicalAddress)
{
	PHYSICAL_ADDRESS pa;
	pa.u.HighPart = 0;
	pa.u.LowPart = ulPhysicalAddress;

	return MmGetVirtualForPhysical(pa);
}

NTSTATUS CompleteIRP(PIRP pIrp, NTSTATUS status, ULONG ulBytesTransferred)
{
    pIrp->IoStatus.Status = status;
	pIrp->IoStatus.Information = ulBytesTransferred;
    IoCompleteRequest (pIrp, IO_DISK_INCREMENT);

	return status;
}

PVOID AllocateNonCachedDmaBuffer(DWORD dwSize)
{
	PHYSICAL_ADDRESS  paLowestAcceptableAddress;
	PHYSICAL_ADDRESS  paHighestAcceptableAddress;
	PHYSICAL_ADDRESS  paBoundaryAddressMultiple;

	paLowestAcceptableAddress.QuadPart = 0;
	paHighestAcceptableAddress.QuadPart = MAXULONG;
	paBoundaryAddressMultiple.QuadPart = 4096; 

	void * pMemory = NULL;

	if(dwSize > 0)
	{
		pMemory = MmAllocateContiguousMemorySpecifyCache(
			dwSize,
			paLowestAcceptableAddress,
			paHighestAcceptableAddress,
			paBoundaryAddressMultiple,
			MmNonCached);
		ASSERT(pMemory);
	}

	return pMemory;
}

PVOID AllocateAlignedBuffer(DWORD dwSize)
{
	PHYSICAL_ADDRESS  paHighestAcceptableAddress;

	void * pMemory = NULL;

	if(dwSize > 0)
	{
		paHighestAcceptableAddress.QuadPart = MAXULONG;

		pMemory = MmAllocateContiguousMemory(
			dwSize,
			paHighestAcceptableAddress);
		ASSERT(pMemory);
	}

	return pMemory;
}

void LoadDsp(DEVICE_EXTENSION * pDeviceExtension, unsigned char ucChannel)
{
	ULONG ulChannelBarOffset = ucChannel * JR3_BAR_RANGE_PER_CH;
	int index = 0;

	/* The fist line is a line count */
	int count = dsp[index++];

	/* Read in file while the count is no 0xffff */
	while (count != 0xffff)
	{
		int addr;

		/* After the count is the address */
		addr = dsp[index++];
		JR3PCIDebugPrint(DBG_INIT, DBG_INFO, "addr: %4.4x cnt: %d\n", addr, count);
		
		/* loop count times and write the data to the dsp memory */
		while (count > 0)
		{
			/* Check to see if this is data memory or program memory */
			if (addr & 0x4000)
			{
				/* Data memory is 16 bits and is on one line */
				int data = dsp[index++];
				count--;

				// Write and read back for verification.
				WRITE_REGISTER_ULONG(pDeviceExtension->pulBar0Base + (ulChannelBarOffset / 4) + addr, data);
				int rddata = READ_REGISTER_ULONG(pDeviceExtension->pulBar0Base + (ulChannelBarOffset / 4) + addr);
				
				if (data!=rddata)
				{
					 JR3PCIDebugPrint(DBG_INIT, DBG_ERR, "data addr: %4.4x out: %4.4x in: %4.4x\n", addr, data, rddata);
				}
			}
			else
			{
				/* Program memory is 24 bits and is on two line */
				int data = dsp[index++];
				int data2 = dsp[index++];
				count -= 2;

				/////////////////////////////////////////
				// Write and read back for verification.
				/////////////////////////////////////////

				WRITE_REGISTER_USHORT((unsigned short *)(pDeviceExtension->pulBar0Base + (ulChannelBarOffset / 4) + addr), (USHORT) data);
				WRITE_REGISTER_USHORT((unsigned short *)(pDeviceExtension->pulBar0Base + (ulChannelBarOffset / 4) + addr + (JR3_LO_DSP_BYTE_OFFSET / 4)), (USHORT) data2);
				
				int rddatahi = READ_REGISTER_USHORT((unsigned short *)(pDeviceExtension->pulBar0Base + (ulChannelBarOffset / 4) + addr)) ;
				int rddatalo = READ_REGISTER_UCHAR((unsigned char *)(pDeviceExtension->pulBar0Base + (ulChannelBarOffset / 4) + addr + (JR3_LO_DSP_BYTE_OFFSET / 4)));
				int data3 = (rddatahi << 8) | rddatalo;

				/* Verify the write */
				if( ((data << 8) | (data2 & 0xff)) != data3)
				{
					JR3PCIDebugPrint(DBG_INIT, DBG_ERR, "pro addr: %4.4x out: %6.6x in: %6.6x\n", addr, ((data << 8)|(data2 & 0xff)), data3);
				}
			}
			addr++;
		} 
		count = dsp[index++];
	}
}

int LoadDspCode(DEVICE_EXTENSION * pDeviceExtension)
{
	// Reset the board.
	WRITE_REGISTER_ULONG(pDeviceExtension->pulBar0Base + JR3_RESET_ADDR, 0);

	// Load the DSP code, one channel at a time.
	for(UCHAR ucChannel=0; ucChannel<pDeviceExtension->ulSupportedChannels; ucChannel++)
	{
		LoadDsp(pDeviceExtension, ucChannel);
	}

	return JR3PCI_STATUS_OK;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  DriverEntry 
//      Installable driver initialization entry point.
//      This entry point is called directly by the I/O system.
//
//  Arguments:
//      IN  DriverObject
//              pointer to the driver object
//
//      IN  RegistryPath
//              pointer to a unicode string representing the path,
//              to driver-specific key in the registry.
//
//  Return Value:
//      Status
//
NTSTATUS DriverEntry(
    IN  PDRIVER_OBJECT  DriverObject,
    IN  PUNICODE_STRING RegistryPath
    )
{
    NTSTATUS    status;

    JR3PCIDebugPrint(DBG_INIT, DBG_TRACE, __FUNCTION__"++");
    JR3PCIDebugPrint(DBG_INIT, DBG_INFO, "Compiled at %s on %s", __TIME__, __DATE__);

#ifdef DBG
    DbgBreakPoint();
#endif

#ifdef JR3PCI_WMI_TRACE 
    WPP_INIT_TRACING(DriverObject, RegistryPath);
#endif

    status = STATUS_SUCCESS;

    RtlZeroMemory(&g_Data, sizeof(JR3PCI_DATA));

    // save registry path for wmi
    g_Data.RegistryPath.Length = RegistryPath->Length;
    g_Data.RegistryPath.MaximumLength = RegistryPath->Length + sizeof(UNICODE_NULL);
    g_Data.RegistryPath.Buffer = (PWCHAR)ExAllocatePoolWithTag(
                                            PagedPool,
                                            g_Data.RegistryPath.MaximumLength,
                                            JR3PCI_POOL_TAG
                                            );

    if (g_Data.RegistryPath.Buffer == NULL)
    {
        status = STATUS_INSUFFICIENT_RESOURCES;

        JR3PCIDebugPrint(DBG_INIT, DBG_ERR, __FUNCTION__": Failed to allocate memory for RegistryPath");

        return status;
    }

    RtlCopyUnicodeString(&g_Data.RegistryPath, RegistryPath);

    // detect current operating system
    if (IoIsWdmVersionAvailable(1, 0x30))
    {
        g_Data.WdmVersion = 0x0130;
    }
    else if (IoIsWdmVersionAvailable(1, 0x20))
    {
        g_Data.WdmVersion = 0x0120;
    }
    else if (IoIsWdmVersionAvailable(1, 0x10))
    {
        g_Data.WdmVersion = 0x0110;
    }
    else if (IoIsWdmVersionAvailable(1, 0x05))
    {
        g_Data.WdmVersion = 0x0105;
    }
    else
    {
        g_Data.WdmVersion = 0x0100;
    }

    // Setup our dispatch function table in the driver object
    DriverObject->MajorFunction[IRP_MJ_PNP] = JR3PCIPnpDispatch;
    DriverObject->MajorFunction[IRP_MJ_POWER] = JR3PCIPowerDispatch;
    DriverObject->MajorFunction[IRP_MJ_CREATE] = JR3PCICreateDispatch;
    DriverObject->MajorFunction[IRP_MJ_CLOSE] = JR3PCICloseDispatch;
    DriverObject->MajorFunction[IRP_MJ_DEVICE_CONTROL] = JR3PCIDeviceIoControlDispatch;
    DriverObject->MajorFunction[IRP_MJ_CLEANUP] = JR3PCICleanupDispatch;
    DriverObject->MajorFunction[IRP_MJ_SYSTEM_CONTROL] = JR3PCISystemControlDispatch;

    DriverObject->DriverExtension->AddDevice = JR3PCIAddDevice;
    DriverObject->DriverUnload = JR3PCIUnload;

    JR3PCIDebugPrint(DBG_INIT, DBG_TRACE, __FUNCTION__"--. STATUS %x", status);

    return status;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIAddDevice 
//      The PnP manager new device callback
//
//  Arguments:
//      IN  DeviceObject
//              pointer to a device object.
//
//      IN  PhysicalDeviceObject
//              pointer to a device object created by the
//              underlying bus driver.
//
//  Return Value:
//      Status
//
NTSTATUS JR3PCIAddDevice(
    IN PDRIVER_OBJECT   DriverObject,
    IN PDEVICE_OBJECT   PhysicalDeviceObject
    )
{
    NTSTATUS			status;
    PDEVICE_OBJECT      deviceObject;
    PDEVICE_EXTENSION   deviceExtension;

    JR3PCIDebugPrint(DBG_INIT, DBG_TRACE, __FUNCTION__"++: PDO %p", PhysicalDeviceObject);

	// Find the lowest available device index by searching the device index bit map.
	ULONG ulDeviceIndex = 0;
	for(int i=0; i<32; i++)
	{
		if((g_Data.ulDeviceIndexMap & (1<<i)) == 0)
		{
			g_Data.ulDeviceIndexMap |= (1<<i);
			ulDeviceIndex = i;
			break;
		}
	}

	// Initialize the unicode strings used below.
	WCHAR ntNameBuffer[64] = L"";
	UNICODE_STRING ntName = {0, 64, ntNameBuffer};
	RtlAppendUnicodeToString(&ntName, L"\\Device\\JR3PCI");

	WCHAR win32NameBuffer[64] = L"";
	UNICODE_STRING win32Name = {0, 64, win32NameBuffer};
	RtlAppendUnicodeToString(&win32Name, L"\\??\\JR3PCI");

	WCHAR IndexBuffer[4];
	UNICODE_STRING Index = {0, 4, IndexBuffer};

	// Dynamically initialize the device object name unicode string.
	RtlIntegerToUnicodeString(ulDeviceIndex, 10, &Index);
	RtlAppendUnicodeStringToString(&ntName, &Index);		// The first Device Object is named "\\Device\\JR3PCI0".

	// Dynamically initialize the symbolic link name unicode string.
	RtlIntegerToUnicodeString(ulDeviceIndex+1, 10, &Index);
	RtlAppendUnicodeStringToString(&win32Name, &Index);		// The first symbolic link is named "\\??\\JR3PCI1".

    // Create our function device object.
    status = IoCreateDevice(
                DriverObject,
                sizeof (DEVICE_EXTENSION),
                &ntName,
                FILE_DEVICE_UNKNOWN,
                FILE_DEVICE_SECURE_OPEN, // Do not use if binary intended for 9x
                FALSE,
                &deviceObject
                );

    if (!NT_SUCCESS(status)) 
    {
        JR3PCIDebugPrint(DBG_INIT, DBG_ERR, __FUNCTION__"--. IoCreateDevice STATUS %x", status);

        return status;
    }

    JR3PCIDebugPrint(DBG_INIT, DBG_INFO, __FUNCTION__": Created FDO %p", deviceObject);

    // Initialize the device extension.
    deviceExtension = (PDEVICE_EXTENSION)deviceObject->DeviceExtension;

    // Zero the memory
    RtlZeroMemory(deviceExtension, sizeof(DEVICE_EXTENSION));

	// Remember our device index (needed when device is removed).
	deviceExtension->ulDeviceIndex = ulDeviceIndex;

	// save the PDO pointer
    deviceExtension->PhysicalDeviceObject = PhysicalDeviceObject;

    // save our device object
    deviceExtension->pDeviceObject = deviceObject;

    // set RemoveCount to 1. Transition to zero
    // means IRP_MN_REMOVE_DEVICE was received
    deviceExtension->RemoveCount = 1;

    // Initialize Remove event
    KeInitializeEvent(&deviceExtension->RemoveEvent, NotificationEvent, FALSE);

    // initialize io lock
    JR3PCIInitializeIoLock(&deviceExtension->IoLock, deviceObject);

    deviceExtension->PnpState = PnpStateNotStarted;
    deviceExtension->PreviousPnpState = PnpStateNotStarted;

    // Initialize the device object flags

    // All WDM drivers are supposed to set this flag.  Devices
    // requiring a large amount of current at statup set the 
    // DO_POWER_INRUSH flag instead.  These flags are mutually
    // exclusive.
    if (PhysicalDeviceObject->Flags & DO_POWER_PAGABLE) 
    {
        deviceObject->Flags |= DO_POWER_PAGABLE;
    }

    // This flag sets the buffering method for reads and writes
    // to METHOD_BUFFERED.  IOCTLs are handled by IO control codes
    // independent of the value of this flag.
    deviceObject->Flags |= DO_BUFFERED_IO;

    // Attach our device to the device stack and get the device object to 
    // which we send down IRPs to.
    deviceExtension->LowerDeviceObject = IoAttachDeviceToDeviceStack(
                                            deviceObject,
                                            PhysicalDeviceObject
                                            );

    if (deviceExtension->LowerDeviceObject == NULL) 
    {
        JR3PCIDebugPrint(DBG_INIT, DBG_ERR, __FUNCTION__"--. IoAttachDeviceToDeviceStack failed");

        IoDeleteDevice(deviceObject);
        return STATUS_DEVICE_REMOVED;
    }

    status = IoCreateSymbolicLink(&win32Name, &ntName);
    if (!NT_SUCCESS(status))
    {
        JR3PCIDebugPrint(DBG_INIT, DBG_ERR, __FUNCTION__"--. IoCreateSymbolicLink failed STATUS %x", status);

        IoDetachDevice(deviceExtension->LowerDeviceObject);
        IoDeleteDevice(deviceObject);
        return status;
    }

	// Save a copy of the symbolic link in the device extension so we can delete it when the driver is removed.
	deviceExtension->SymbolicLinkName.Length = win32Name.Length;
	deviceExtension->SymbolicLinkName.MaximumLength = win32Name.Length;
	deviceExtension->SymbolicLinkName.Buffer = (PWCH) ExAllocatePool(NonPagedPool, win32Name.Length);
	RtlCopyMemory(deviceExtension->SymbolicLinkName.Buffer, win32NameBuffer, win32Name.Length);

    // We are all done, so we need to clear the
    // DO_DEVICE_INITIALIZING flag.  This must be our
    // last action in AddDevice
    deviceObject->Flags &= ~DO_DEVICE_INITIALIZING;

    JR3PCIDebugPrint(DBG_INIT, DBG_TRACE, __FUNCTION__"--. STATUS %x, pDevExt=%x", status, deviceExtension);

    return status;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIStartDevice
//      Start device handler, sets up resources
//
//  Arguments:
//      IN  DeviceExtension
//              our device extension
//
//      IN  Irp
//              pointer to the Start IRP
//
//  Return Value:
//      NT status code
//
NTSTATUS JR3PCIStartDevice(
    IN  PDEVICE_EXTENSION    pDeviceExtension,
    IN  PIRP                        pIrp
    )
{
    NTSTATUS                        status = STATUS_SUCCESS;
    PCM_PARTIAL_RESOURCE_DESCRIPTOR resourceTrans;
    PCM_PARTIAL_RESOURCE_LIST       partialResourceListTranslated;
    PIO_STACK_LOCATION              irpStack;
    POWER_STATE                     powerState;
    ULONG                           ii;

    JR3PCIDebugPrint(DBG_PNP, DBG_TRACE, __FUNCTION__"++. IRP %p", pIrp);

    // Get our current IRP stack location
    irpStack = IoGetCurrentIrpStackLocation(pIrp);

    // Do whatever initialization needed when starting the device:
    // gather information about it,  update the registry, etc.
    // At this point, the lower level drivers completed the IRP
    if (irpStack->Parameters.StartDevice.AllocatedResourcesTranslated != NULL) 
    {
        // Parameters.StartDevice.AllocatedResourcesTranslated points
        // to a CM_RESOURCE_LIST describing the hardware resources that
        // the PnP Manager assigned to the device. This list contains
        // the resources in translated form. Use the translated resources
        // to connect the interrupt vector, map I/O space, and map memory.

        partialResourceListTranslated =
            &irpStack->Parameters.StartDevice.AllocatedResourcesTranslated->List[0].PartialResourceList;

        resourceTrans = &partialResourceListTranslated->PartialDescriptors[0];

        // search the resources
        for (ii = 0;
             ii < partialResourceListTranslated->Count;
             ++ii, ++resourceTrans) 
        {

            switch (resourceTrans->Type) 
            {
				case CmResourceTypeMemory:
					JR3PCIDebugPrint(DBG_PNP, DBG_TRACE, "Resource Type Memory");
					JR3PCIDebugPrint(DBG_PNP, DBG_TRACE, "Memory.Start %I64x", resourceTrans->u.Memory.Start.QuadPart);
					JR3PCIDebugPrint(DBG_PNP, DBG_TRACE, "Memory.Length %x", resourceTrans->u.Memory.Length);

//					if(pDeviceExtension->pulBar0Base == NULL)
					{
						// BAR0
						pDeviceExtension->pulBar0Length = resourceTrans->u.Memory.Length;

						// Map the physical address into kernel virtual address space.
						pDeviceExtension->pulBar0Base = (PULONG) MmMapIoSpace(
							resourceTrans->u.Memory.Start, 
							resourceTrans->u.Memory.Length, 
							MmNonCached);
					}

					// Calculate the number of channels supported by this card.
					// Each channel takes up 80000h bytes in the BAR0 range.
					pDeviceExtension->ulSupportedChannels = pDeviceExtension->pulBar0Length / JR3_BAR_RANGE_PER_CH;

					break;

				default:
					JR3PCIDebugPrint(DBG_PNP, DBG_TRACE, "Unknown Resource Type %x", resourceTrans->Type);
					break;
            }
        }
    }

    //*****************************************************************
    //*****************************************************************
    // Check that all required resources have been allocated
    //*****************************************************************
    //*****************************************************************

	ASSERT(pDeviceExtension->pulBar0Base);

    if (!pDeviceExtension->pulBar0Base)
    {
        return STATUS_INSUFFICIENT_RESOURCES;
    }

	// Load the DSP code.
	if(LoadDspCode(pDeviceExtension) != JR3PCI_STATUS_OK)
	{
		return STATUS_UNSUCCESSFUL;
	}


    JR3PCIDebugPrint(DBG_PNP, DBG_TRACE, __FUNCTION__"--. IRP %p STATUS %x", pIrp, status);

	return status;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIFreeResources
//      This routine returns all the resources acquired during
//      device startup.  Here we disconnect from any interrupt, 
//      unmap any I/O ports that are mapped in StartDevice, and 
//      disable any device interfaces or symbolic links.  
//      Before disconnecting an interrupt, be sure the device can
//      no longer generate interrupts.
//
//  Arguments:
//      IN  DeviceExtension
//              our device extension
//
//  Return Value:
//      NT status code
//
NTSTATUS JR3PCIFreeResources(
    IN  PDEVICE_EXTENSION pDeviceExtension
    )
{
    JR3PCIDebugPrint(DBG_PNP, DBG_TRACE, __FUNCTION__"++");

	// Delete the Symbolic link for the device.
	NTSTATUS status = IoDeleteSymbolicLink(&pDeviceExtension->SymbolicLinkName);
	ASSERT(status == STATUS_SUCCESS);
	
	// Clean up after the symbolic link.
	ExFreePool(pDeviceExtension->SymbolicLinkName.Buffer);
	g_Data.ulDeviceIndexMap &= ~(1<<pDeviceExtension->ulDeviceIndex);

	// If no resources have been allocated we don't do anything.
    if (pDeviceExtension->pulBar0Base != NULL)
    {
		// Reset the board.
		WRITE_REGISTER_ULONG(pDeviceExtension->pulBar0Base + JR3_RESET_ADDR, 0);

		// Unmap the physical address from kernel virtual address space.
		MmUnmapIoSpace(pDeviceExtension->pulBar0Base, pDeviceExtension->pulBar0Length);
        pDeviceExtension->pulBar0Base = NULL;
    }

    JR3PCIDebugPrint(DBG_PNP, DBG_TRACE, __FUNCTION__"--");

    return STATUS_SUCCESS;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCICreateDispatch
//      Dispatch routine for IRP_MJ_CREATE requests.
//
//  Arguments:
//      IN  DeviceObject
//              pointer to the device object for our device
//
//      IN  Irp
//              the create IRP
//
//  Return Value:
//      NT status code.
//
NTSTATUS JR3PCICreateDispatch(
    IN  PDEVICE_OBJECT  DeviceObject,
    IN  PIRP            Irp
    )
{
    PDEVICE_EXTENSION    deviceExtension;
    NTSTATUS                status;

    JR3PCIDebugPrint(DBG_CREATECLOSE, DBG_TRACE, __FUNCTION__": IRP %p", Irp);

    deviceExtension = (PDEVICE_EXTENSION)DeviceObject->DeviceExtension;

    if (!JR3PCIAcquireRemoveLock(deviceExtension))
    {
        status = STATUS_NO_SUCH_DEVICE;

        Irp->IoStatus.Status = status;
        IoCompleteRequest(Irp, IO_NO_INCREMENT);

        JR3PCIDebugPrint(DBG_CREATECLOSE, DBG_WARN, __FUNCTION__"$$--. IRP %p, STATUS %x", Irp, status);

        return status;
    }

    // Increment open count.
    InterlockedIncrement(&deviceExtension->OpenHandleCount);
	JR3PCIDebugPrint(DBG_IO, DBG_TRACE, "OpenHandleCount: %d", deviceExtension->OpenHandleCount);

    status = STATUS_SUCCESS;
    Irp->IoStatus.Information = 0;
    Irp->IoStatus.Status = status;
    IoCompleteRequest(Irp, IO_NO_INCREMENT);

    JR3PCIReleaseRemoveLock(deviceExtension);

    JR3PCIDebugPrint(DBG_CREATECLOSE, DBG_TRACE, __FUNCTION__"--. IRP %p, STATUS %x", Irp, status);

    return status;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCICloseDispatch
//      Dispatch routine for IRP_MJ_CLOSE requests.
//
//  Arguments:
//      IN  DeviceObject
//              pointer to the device object for our device
//
//      IN  Irp
//              the close IRP
//
//  Return Value:
//      NT status code.
//
NTSTATUS JR3PCICloseDispatch(
    IN  PDEVICE_OBJECT  DeviceObject,
    IN  PIRP            Irp
    )
{
    PDEVICE_EXTENSION    deviceExtension;
    NTSTATUS                status;

    JR3PCIDebugPrint(DBG_CREATECLOSE, DBG_TRACE, __FUNCTION__"++. IRP %p", Irp);

    deviceExtension = (PDEVICE_EXTENSION)DeviceObject->DeviceExtension;

    status = STATUS_SUCCESS;
    Irp->IoStatus.Information = 0;
    Irp->IoStatus.Status = status;
    IoCompleteRequest (Irp, IO_NO_INCREMENT);

    // Increment open count.
    InterlockedDecrement(&deviceExtension->OpenHandleCount);
	JR3PCIDebugPrint(DBG_IO, DBG_TRACE, "OpenHandleCount: %d", deviceExtension->OpenHandleCount);


    JR3PCIDebugPrint(DBG_CREATECLOSE, DBG_TRACE, __FUNCTION__"--. IRP %p, STATUS %x", Irp, status);

    return status;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCICleanupDispatch
//      Dispatch routine for IRP_MJ_CLEANUP requests.
//
//  Arguments:
//      IN  DeviceObject
//              pointer to the device object for our device
//
//      IN  Irp
//              the cleanup IRP
//
//  Return Value:
//      NT status code.
//
NTSTATUS JR3PCICleanupDispatch(
    IN  PDEVICE_OBJECT  pDeviceObject,
    IN  PIRP            pIrp
    )
{
    JR3PCIDebugPrint(DBG_CREATECLOSE, DBG_TRACE, __FUNCTION__"++. IRP %p", pIrp);

    PDEVICE_EXTENSION pDeviceExtension = (PDEVICE_EXTENSION)pDeviceObject->DeviceExtension;

	// Get our current IRP stack location
    IO_STACK_LOCATION * pOurIoStackLocation = IoGetCurrentIrpStackLocation(pIrp);

	// Get the file object that the closed device handle is associated with.
	FILE_OBJECT * pOurFileObject = pOurIoStackLocation->FileObject;

	// Complete the Cleanup IRP itself.
    pIrp->IoStatus.Information = 0;
    pIrp->IoStatus.Status = STATUS_SUCCESS;
    IoCompleteRequest(pIrp, IO_NO_INCREMENT);

    JR3PCIDebugPrint(DBG_CREATECLOSE, DBG_TRACE, __FUNCTION__"--. IRP %p STATUS %x", pIrp, STATUS_SUCCESS);

    return STATUS_SUCCESS;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIUnload
//      Driver Unload routine.
//
//  Arguments:
//      IN  DriverObject
//              pointer to the driver object
//
//  Return Value:
//      none
//
VOID JR3PCIUnload(
    IN  PDRIVER_OBJECT  DriverObject
    )
{
    JR3PCIDebugPrint(DBG_UNLOAD, DBG_TRACE, __FUNCTION__"++");

    // The device object(s) should be NULL now
    // (since we unload, all the devices objects associated with this
    // driver must be deleted.
    ASSERT(DriverObject->DeviceObject == NULL);

    // release memory block allocated for registry path
    if (g_Data.RegistryPath.Buffer != NULL)
    {
        ExFreePool(g_Data.RegistryPath.Buffer);
        g_Data.RegistryPath.Buffer = NULL;
    }

    JR3PCIDebugPrint(DBG_UNLOAD, DBG_TRACE, __FUNCTION__"--");

#ifdef JR3PCI_WMI_TRACE
    WPP_CLEANUP(DriverObject);
#endif

    return;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIIsStoppable
//      This routine determines whether the device can be safely stopped. 
//      In our particular case, we'll assume we can always stop the device.
//      A device might fail the request if it doesn't have a queue for the
//      requests that might come or if it was notified that it is in the 
//      paging path.
//
//  Arguments:
//      IN  DeviceExtension
//              our device extension
//
//  Return Value:
//      returns TRUE if the device is stoppable, FALSE otherwise
//
BOOLEAN JR3PCIIsStoppable(
    IN  PDEVICE_EXTENSION    DeviceExtension
    )
{
    return TRUE;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIIsRemovable
//      This routine determines whether the device can be safely removed. 
//      A device shouldn't be removed if, for example, it has open handles or
//      removing the device could result in losing data (plus the reasons
//      mentioned in the JR3PCIIsStoppable function comments). The PnP manager on 
//      Windows 2000 fails on its own any attempt to remove, if there any 
//      open handles to the device.  However on Win9x, the driver must keep 
//      count of open handles and fail QueryRemove if there are any open 
//      handles.
//
//  Arguments:
//      IN  DeviceExtension
//              our device extension
//
//  Return Value:
//      returns TRUE if the device is stoppable, FALSE otherwise
//
BOOLEAN JR3PCIIsRemovable(
    IN  PDEVICE_EXTENSION    DeviceExtension
    )
{
    return TRUE;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCISubmitIrpSyncComplete
//      Completion routine for sync IRP requests.
//
//  Arguments:
//      IN  DeviceObject
//              pointer to our device object
//
//      IN  Irp
//              pointer to the PnP IRP
//
//      IN  Context
//              our event used to signal IRP completion
//
//  Return Value:
//      STATUS_MORE_PROCESSING_REQUIRED
//
NTSTATUS  JR3PCISubmitIrpSyncComplete(
    IN  PDEVICE_OBJECT  DeviceObject,
    IN  PIRP            Irp,
    IN  PVOID           Context
    )
{
    PKEVENT event = (PKEVENT)Context;

    // If the lower driver didn't return STATUS_PENDING, we don't need to 
    // set the event because we won't be waiting on it. 
    if (Irp->PendingReturned) 
    {
        KeSetEvent(event, IO_NO_INCREMENT, FALSE);
    }

    return STATUS_MORE_PROCESSING_REQUIRED;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCISubmitIrpSync
//      Sends the given IRP down the stack to the next lower driver and 
//      waits in a synchronous fashion for the IRP to complete
//
//  Arguments:
//      IN  DeviceObject
//              Pointer to device object for our device
//
//      IN  Irp
//              IRP to send down
//
//  Return Value:
//      NT status code
//
NTSTATUS JR3PCISubmitIrpSync(
    IN  PDEVICE_OBJECT  DeviceObject,
    IN  PIRP            Irp
    )
{
    KEVENT   event;
    NTSTATUS status;

    KeInitializeEvent(&event, NotificationEvent, FALSE);

    IoCopyCurrentIrpStackLocationToNext(Irp);

    IoSetCompletionRoutine(
        Irp,
        JR3PCISubmitIrpSyncComplete,
        &event,
        TRUE,
        TRUE,
        TRUE
        );

    status = IoCallDriver(DeviceObject, Irp);

    // Wait for lower drivers to be done with the Irp.
    // Important thing to note here is when you allocate
    // memory for an event in the stack you must do a
    // KernelMode wait instead of UserMode to prevent
    // the stack from getting paged out.

    if (status == STATUS_PENDING) 
    {
       KeWaitForSingleObject(
           &event,
           Executive,
           KernelMode,
           FALSE,
           NULL
           );

       status = Irp->IoStatus.Status;
    }

    return status;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIAcquireRemoveLock
//      Acquires remove lock.
//
//  Arguments:
//      IN  DeviceExtension
//              our device extension
//
//  Return Value:
//      FALSE if remove device pending, TRUE otherwise.
//
BOOLEAN JR3PCIAcquireRemoveLock(
    IN  PDEVICE_EXTENSION    DeviceExtension
    )
{
    LONG    count;

    count = InterlockedIncrement(&DeviceExtension->RemoveCount);

    ASSERT(count > 0);

    if (DeviceExtension->PnpState == PnpStateRemoved)
    {
        JR3PCIReleaseRemoveLock(DeviceExtension);

        return FALSE;
    }

    return TRUE;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIReleaseRemoveLock
//      Releases remove lock.
//
//  Arguments:
//      IN  DeviceExtension
//              our device extension
//
//  Return Value:
//      None.
//
VOID JR3PCIReleaseRemoveLock(
    IN  PDEVICE_EXTENSION    DeviceExtension
    )
{
    LONG    count;

    count = InterlockedDecrement(&DeviceExtension->RemoveCount);

    ASSERT(count >= 0);

    if (count == 0)
    {
        KeSetEvent(&DeviceExtension->RemoveEvent, IO_NO_INCREMENT, FALSE);
    }

    return;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIWaitForSafeRemove
//      Waits for all remove locks to be released
//
//  Arguments:
//      IN  DeviceExtension
//              our device extension
//
//  Return Value:
//      None.
//
//  Comment:
//      This routine should be called with no remove locks held 
//      by the calling thread
//
VOID JR3PCIWaitForSafeRemove(
    IN  PDEVICE_EXTENSION    DeviceExtension
    )
{
    DeviceExtension->PnpState = PnpStateRemoved;
    JR3PCIReleaseRemoveLock(DeviceExtension);

    KeWaitForSingleObject(
        &DeviceExtension->RemoveEvent, 
        Executive, 
        KernelMode, 
        FALSE, 
        NULL
        );

    return;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIStallQueues
//      Pauses all of the queues, and waits for them to get to paused state.
//
//  Arguments:
//      IN  DeviceExtension
//              our device extension
//
//  Return Value:
//      none
//
VOID JR3PCIStallQueues(
    IN  PDEVICE_EXTENSION DeviceExtension
    )
{
    ULONG   index;

    JR3PCIDebugPrint(DBG_IO, DBG_TRACE, __FUNCTION__"++");
/*
	JG: Commented out since causes a lockup when unloading the driver after I/Os have been made.

    // stall IRP processing
    JR3PCILockIo(&DeviceExtension->IoLock);

    JR3PCIWaitForStopIo(&DeviceExtension->IoLock);
*/
    JR3PCIDebugPrint(DBG_IO, DBG_TRACE, __FUNCTION__"--");

    return;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIRestartQueues
//      Restarts all paused queues.
//
//  Arguments:
//      IN  DeviceExtension
//              our device extension
//
//  Return Value:
//      none
//
VOID JR3PCIRestartQueues(
    IN  PDEVICE_EXTENSION   DeviceExtension
    )
{
    ULONG   index;

    JR3PCIDebugPrint(DBG_IO, DBG_TRACE, __FUNCTION__"++");

    JR3PCIUnlockIo(&DeviceExtension->IoLock);

    JR3PCIDebugPrint(DBG_IO, DBG_TRACE, __FUNCTION__"--");

    return;
}
///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIFlushQueues
//      Flush oustanding IRPs for closed file object.
//
//  Arguments:
//      IN  DeviceExtension
//              our device extension
//
//      IN  FileObject
//              about to be closed file object
//
//  Return Value:
//      none
//
VOID JR3PCIFlushQueues(
    IN  PDEVICE_EXTENSION   DeviceExtension,
    IN  PFILE_OBJECT            FileObject
    )
{
    ULONG   index;

    JR3PCIDebugPrint(DBG_IO, DBG_TRACE, __FUNCTION__"++");

    JR3PCIFlushPendingIo(&DeviceExtension->IoLock, FileObject);

    JR3PCIDebugPrint(DBG_IO, DBG_TRACE, __FUNCTION__"--");

    return;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//  JR3PCIAccessConfigSpace
//      Read or Write PCI configuration space
//
//  Arguments:
//      IN  DeviceExtension
//              our device extension
//
//      IN  IsRead
//              TRUE for reads, FALSE for writes
//
//      IN  Buffer
//              Buffer to read to or write from
//
//      IN  Offset
//              starting offset in PCI configuration space
//
//      IN  Length
//              Buffer size
//
//      IN  ReadWrittenSize
//              count of bytes read or written
//
//  Return Value:
//      Status
//
NTSTATUS JR3PCIAccessConfigSpace(
    IN  PDEVICE_EXTENSION DeviceExtension,
    IN  BOOLEAN                 IsRead,
    IN OUT PVOID                Buffer,
    IN  ULONG                   Offset,
    IN  ULONG                   Length,
    OUT PULONG                  ReadWrittenSize
    )
{
    NTSTATUS            status;
    PDEVICE_OBJECT      topDeviceObject;
    PIRP                irp;
    PIO_STACK_LOCATION  irpStack;
    KEVENT              event;
    IO_STATUS_BLOCK     ioStatus;

    JR3PCIDebugPrint(DBG_IO, DBG_TRACE, __FUNCTION__"++");

    KeInitializeEvent(&event, NotificationEvent, FALSE);

    topDeviceObject = IoGetAttachedDeviceReference(DeviceExtension->pDeviceObject);

    irp = IoBuildSynchronousFsdRequest(
            IRP_MJ_PNP,
            topDeviceObject,
            NULL,
            0,
            NULL,
            &event,
            &ioStatus
            );

    if (irp != NULL)
    {
        irpStack = IoGetNextIrpStackLocation(irp);

        irpStack->MinorFunction = IsRead ? IRP_MN_READ_CONFIG : IRP_MN_WRITE_CONFIG;

        irpStack->Parameters.ReadWriteConfig.WhichSpace = PCI_WHICHSPACE_CONFIG;
        irpStack->Parameters.ReadWriteConfig.Buffer = Buffer;
        irpStack->Parameters.ReadWriteConfig.Offset = Offset;
        irpStack->Parameters.ReadWriteConfig.Length = Length;
        
        irp->IoStatus.Status = STATUS_NOT_SUPPORTED;
        
        status = IoCallDriver(topDeviceObject, irp);
        if (status == STATUS_PENDING)
        {
            KeWaitForSingleObject(&event, Executive, KernelMode, FALSE, NULL);
            status = ioStatus.Status;
        }

        *ReadWrittenSize = (ULONG)ioStatus.Information;
    }
    else
    {
        status = STATUS_INSUFFICIENT_RESOURCES;
    }

    ObDereferenceObject(topDeviceObject);

    JR3PCIDebugPrint(DBG_IO, DBG_TRACE, __FUNCTION__"--. STATUS %x", status);

    return status;
}
