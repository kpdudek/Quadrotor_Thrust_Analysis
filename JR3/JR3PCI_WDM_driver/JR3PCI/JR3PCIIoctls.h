/**********************************************************************
;       Copyright 2015 JR3, Inc.
;
;**********************************************************************/

#pragma once

#pragma pack(push, 1)

#define JR3PCI_STATUS_OK					 0
#define JR3PCI_STATUS_INVALID_CHANNEL_INDEX	-1
#define JR3PCI_STATUS_INVALID_OFFSET		-2

//////////////////////////////////////////////////////////////////////////////////////////////////////
// IOCTL DEFINITIONS
//////////////////////////////////////////////////////////////////////////////////////////////////////

#define FILE_DEVICE_JR3PCI_WDM_DRIVER  0x8000

///////////////////////////////////////////////////
// IOCTL_JR3PCI_WRITE_WORD
///////////////////////////////////////////////////

#define IOCTL_JR3PCI_WRITE_WORD \
    CTL_CODE(FILE_DEVICE_JR3PCI_WDM_DRIVER, 0x800, METHOD_BUFFERED, FILE_ANY_ACCESS)

// In-data: 

typedef struct _JR3PCI_WRITE_WORD_REQUEST_PARAMS
{
	unsigned char ucChannel; // 0..1 for 1762/3112 adapter.
	unsigned long ulOffset; 
	unsigned short usData;

}JR3PCI_WRITE_WORD_REQUEST_PARAMS, *PJR3PCI_WRITE_WORD_REQUEST_PARAMS;

// Out-data:

typedef struct _PJR3PCI_WRITE_WORD_RESPONSE_PARAMS
{
	int iStatus; // Per above JR3PCI_STATUS_XXX codes.

}JR3PCI_WRITE_WORD_RESPONSE_PARAMS, *PJR3PCI_WRITE_WORD_RESPONSE_PARAMS;

///////////////////////////////////////////////////
// IOCTL_JR3PCI_READ_WORD
///////////////////////////////////////////////////

#define IOCTL_JR3PCI_READ_WORD \
    CTL_CODE(FILE_DEVICE_JR3PCI_WDM_DRIVER, 0x801, METHOD_BUFFERED, FILE_ANY_ACCESS)

// In-data: 

typedef struct _JR3PCI_READ_WORD_REQUEST_PARAMS
{
	unsigned char ucChannel; // 0..1 for 1762/3112 adapter.
	unsigned long ulOffset; 

}JR3PCI_READ_WORD_REQUEST_PARAMS, *PJR3PCI_READ_WORD_REQUEST_PARAMS;

// Out-data: 

typedef struct _JR3PCI_READ_WORD_RESPONSE_PARAMS
{
	int iStatus; // Per above JR3PCI_STATUS_XXX codes.
	unsigned short usData;

}JR3PCI_READ_WORD_RESPONSE_PARAMS, *PJR3PCI_READ_WORD_RESPONSE_PARAMS;

///////////////////////////////////////////////////
// IOCTL_JR3PCI_SUPPORTED_CHANNELS
///////////////////////////////////////////////////

#define IOCTL_JR3PCI_SUPPORTED_CHANNELS \
    CTL_CODE(FILE_DEVICE_JR3PCI_WDM_DRIVER, 0x802, METHOD_BUFFERED, FILE_ANY_ACCESS)

// In-data: None.

// Out-data: 

typedef struct _JR3PCI_SUPPORTED_CHANNELS_RESPONSE_PARAMS
{
	// This is the number of channels supported by this card.
	// Calculated as bar size / 80000h.
	ULONG ulSupportedChannels;

}JR3PCI_SUPPORTED_CHANNELS_RESPONSE_PARAMS, *PJR3PCI_SUPPORTED_CHANNELS_RESPONSE_PARAMS;

#pragma pack(pop)