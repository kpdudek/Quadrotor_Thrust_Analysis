// JR3PCI_Test_App.cpp : Defines the entry point for the console application.
//

#include "stdafx.h"
#include <windows.h>
#include <crtdbg.h>

#include "..\JR3PCI_WDM_driver\JR3PCI\JR3PCIIoctls.h"
#pragma pack(1)
#include "jr3pci_ft.h"

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
	////////////////////////////////////////////////////////////////////////////////////////////////////
	// Enumerate device instances 1 to 4. Note: Multiple PCI Adapters are opened by incrementing the suffix.
	// For example; "\\\\.\\JR3PCI1", "\\\\.\\JR3PCI2", "\\\\.\\JR3PCI3" for a three-adapter setup.
	////////////////////////////////////////////////////////////////////////////////////////////////////

	char szDeviceName[30];

	for(int iDeviceIndex = 1; iDeviceIndex <= 4; iDeviceIndex++)
	{
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

		if(hJr3PciDevice == INVALID_HANDLE_VALUE)
		{
			printf("Failed to open a handle to device '%s'.\r\n", szDeviceName);
			continue;
		}
		printf("Handle to device '%s' opened successfully.\r\n", szDeviceName);

		//////////////////////////////////////////////////////////////////////
		// Read the number of channels supported by this card (1 or 2).
		/////////////////////////////////////////////////////////////////////

		ULONG ulSupportedChannels = GetSupportedChannels(hJr3PciDevice);
		printf("This device supports %d DSP channel(s).\r\n", ulSupportedChannels);

		//////////////////////////////////////////////////////////////////////
		// Read in the complete 'force sensor data' structure, word by word.
		// Note: We read the sensor data from all available channels (max 2).
		/////////////////////////////////////////////////////////////////////

		force_sensor_data vfsd[4]; // Max 4 channels on any JR3 card.
		ULONG ulNumWords = sizeof(vfsd[0]) / sizeof(short);

		for(ULONG ulChannelIndex = 0; ulChannelIndex < ulSupportedChannels; ulChannelIndex++)
		{
			short * pusForceSensorData = (short *) &vfsd[ulChannelIndex];
			
			for(ULONG ulOffset=0; ulOffset<ulNumWords; ulOffset++)
			{
				pusForceSensorData[ulOffset] = ReadWord(hJr3PciDevice, (UCHAR) ulChannelIndex, ulOffset);
			}

			////////////////////////////////////////////////////////////////////////
			// Manually confirm that we have a good copyright string in the buffer.
			////////////////////////////////////////////////////////////////////////

			char * pszCopyright = (char*) vfsd[ulChannelIndex].copyright;
			char szGoodCopyrightString[] = " C o p y r i g h t   J R 3   1 9 9 3 - 2 0 0 0";

			// Check Channel copyright string.
			bool bSuccess = memcmp(pszCopyright, szGoodCopyrightString, sizeof(szGoodCopyrightString)) == 0;
			_ASSERTE(bSuccess);

			if(!bSuccess)
			{
				printf("Failed to read copyright string from channel %d!\r\n", ulChannelIndex);
				getchar();
				return -2;
			}
			printf("Successfully read copyright string from channel %d\r\n", ulChannelIndex);

			//////////////////////////////////////////////////////////////////////
			// To test the Write functionality, we write incremental data to the
			// six 'Offsets' variables @ position 88h and read the data back. 
			// See JR3 PCI manual pages 2 & 10.
			/////////////////////////////////////////////////////////////////////
			
			for(int i=0; i<6; i++)
			{
				ULONG ulOffset = 0x88 + i;
				USHORT usWrData = ((i+1) << 8) | (i+1); // 0x0101, 0x0202 etc.
				USHORT usRdData = 0;

				// WRC
				WriteWord(hJr3PciDevice, (UCHAR) ulChannelIndex, ulOffset, usWrData);
				usRdData = ReadWord(hJr3PciDevice, (UCHAR)ulChannelIndex, ulOffset);
				_ASSERTE(usRdData == usWrData);

				if(usRdData != usWrData)
				{
					printf("Write / Read / Compare failed on channel %d!\r\n", ulChannelIndex);
					getchar();
					return -3;
				}
			}

			printf("Write / Read / Compare succeeded on channel %d.\r\n", ulChannelIndex);
		}

		printf("\r\n");
	}

	printf("Test completed successfully.\r\n");
	getchar();
	return 0;
}

