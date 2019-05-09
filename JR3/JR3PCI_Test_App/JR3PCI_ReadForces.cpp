// JR3PCI_ReadForces.cpp : Opens the JR3 Device and reads the force/torque data
//

#include "stdafx.h"
#include <windows.h>
#include <crtdbg.h>

#include "..\JR3PCI_WDM_driver\JR3PCI\JR3PCIIoctls.h"
#pragma pack(1)
#include "jr3pci_ft.h"
#include "iostream"

ULONG GetSupportedChannels(HANDLE hJr3PciDevice)
{
	JR3PCI_SUPPORTED_CHANNELS_RESPONSE_PARAMS SupportedChannelsResponseParams;

	DWORD dwBytesReturned = 0;
	BOOL bSuccess = DeviceIoControl(
		hJr3PciDevice,					// handle to device
		IOCTL_JR3PCI_SUPPORTED_CHANNELS,					// operation
		NULL,				// input data buffer
		0,  // size of input data buffer
		&SupportedChannelsResponseParams,				// output data buffer
		sizeof(JR3PCI_SUPPORTED_CHANNELS_RESPONSE_PARAMS), // size of output data buffer
		&dwBytesReturned,						// byte count
		NULL);									// overlapped information

	_ASSERTE(bSuccess && (dwBytesReturned == sizeof(JR3PCI_SUPPORTED_CHANNELS_RESPONSE_PARAMS)));

	return SupportedChannelsResponseParams.ulSupportedChannels;
}

void WriteWord(HANDLE hJr3PciDevice, UCHAR ucChannel, ULONG ulOffset, USHORT usData)
{
	JR3PCI_WRITE_WORD_REQUEST_PARAMS WriteWordRequestParams;
	WriteWordRequestParams.ucChannel = ucChannel;
	WriteWordRequestParams.ulOffset = ulOffset;
	WriteWordRequestParams.usData = usData;

	JR3PCI_WRITE_WORD_RESPONSE_PARAMS WriteWordResponseParams;

	DWORD dwBytesReturned = 0;
	BOOL bSuccess = DeviceIoControl(
		hJr3PciDevice,					// handle to device
		IOCTL_JR3PCI_WRITE_WORD,					// operation
		&WriteWordRequestParams,				// input data buffer
		sizeof(JR3PCI_WRITE_WORD_REQUEST_PARAMS),  // size of input data buffer
		&WriteWordResponseParams,				// output data buffer
		sizeof(JR3PCI_WRITE_WORD_RESPONSE_PARAMS), // size of output data buffer
		&dwBytesReturned,						// byte count
		NULL);									// overlapped information

	_ASSERTE(bSuccess && (dwBytesReturned == sizeof(JR3PCI_WRITE_WORD_RESPONSE_PARAMS)));
	_ASSERTE(WriteWordResponseParams.iStatus == JR3PCI_STATUS_OK);
}

WORD ReadWord(HANDLE hJr3PciDevice, UCHAR ucChannel, ULONG ulOffset)
{
	JR3PCI_READ_WORD_REQUEST_PARAMS ReadWordRequestParams;
	ReadWordRequestParams.ucChannel = ucChannel;
	ReadWordRequestParams.ulOffset = ulOffset;

	JR3PCI_READ_WORD_RESPONSE_PARAMS ReadWordResponseParams;

	DWORD dwBytesReturned = 0;
	BOOL bSuccess = DeviceIoControl(
		hJr3PciDevice,					// handle to device
		IOCTL_JR3PCI_READ_WORD,					// operation
		&ReadWordRequestParams,				// input data buffer
		sizeof(JR3PCI_READ_WORD_REQUEST_PARAMS),  // size of input data buffer
		&ReadWordResponseParams,				// output data buffer
		sizeof(JR3PCI_READ_WORD_RESPONSE_PARAMS), // size of output data buffer
		&dwBytesReturned,						// byte count
		NULL);									// overlapped information

	_ASSERTE(bSuccess && (dwBytesReturned == sizeof(JR3PCI_READ_WORD_RESPONSE_PARAMS)));
	_ASSERTE(ReadWordResponseParams.iStatus == JR3PCI_STATUS_OK);

	return ReadWordResponseParams.usData;
}

int _tmain(int argc, _TCHAR* argv[])
{
	char szDeviceName[30];
	int iDeviceIndex = 1;

	sprintf(szDeviceName, "\\\\.\\JR3PCI%d", iDeviceIndex);

	////////////////////////////////////
	// Open a handle to the device. 
	////////////////////////////////////

	HANDLE hJr3PciDevice = CreateFile(
		szDeviceName,					// file name
		GENERIC_READ | GENERIC_WRITE,   // access mode
		0,								// share mode
		NULL,							// SD
		OPEN_EXISTING,					// how to create
		0,								// file attributes
		NULL);							// handle to template file

	if (hJr3PciDevice == INVALID_HANDLE_VALUE)
	{
		printf("Failed to open a handle to device '%s'.\r\n", szDeviceName);
		//continue;
	}
	printf("Handle to device '%s' opened successfully.\r\n", szDeviceName);


	//////////////////////////////////////////////////////////////////////
	// Read in the complete 'force sensor data' structure, word by word.
	// Note: We read the sensor data from all available channels (max 2).
	/////////////////////////////////////////////////////////////////////
	force_sensor_data vfsd; // Max 4 channels on any JR3 card.
	ULONG ulNumWords = sizeof(vfsd) / sizeof(short);
	ULONG ulChannelIndex = 0;

	switch(vfsd.units)
	{
		case lbs_in_lbs_mils: std::cout << "1\n";   break;
  		case N_dNm_mmX10: std::cout << "2\n";   break;
  		case kgF_kgFcm_mmX10: std::cout << "3\n";   break;
  		case klbs_kin_lbs_mils: std::cout << "4\n";   break;
  		case reserved_units_4: std::cout << "5\n";   break;
  		case reserved_units_5: std::cout << "6\n";   break;
  		case reserved_units_6: std::cout << "7\n";   break;
  		case reserved_units_7: std::cout << "8\n";   break;
	}

	getchar();

	while(1)
	{
		// Read data from sensor
		short * pusForceSensorData = (short *)&vfsd;
		for (ULONG ulOffset = 0; ulOffset < ulNumWords; ulOffset++)
		{
			pusForceSensorData[ulOffset] = ReadWord(hJr3PciDevice, (UCHAR)ulChannelIndex, ulOffset);
		}
		

		// Print force and torque data from the unfiltered and decoupled data
		printf("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n");
		printf("\nData:\n");
		printf("Fx: %d\n", vfsd.filter0.fx);
		printf("Fy: %d\n", vfsd.filter0.fy);
		printf("Fz: %d\n", vfsd.filter0.fz);
		printf("Mx: %d\n", vfsd.filter0.mx);
		printf("My: %d\n", vfsd.filter0.my);
		printf("Mz: %d\n", vfsd.filter0.mz);
		printf("\n");
	}
	
	return 0;
}

