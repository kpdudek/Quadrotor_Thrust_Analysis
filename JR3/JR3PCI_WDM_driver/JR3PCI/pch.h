/**********************************************************************
;       Copyright 2015 JR3, Inc.
;
;**********************************************************************/
	
#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

#pragma warning(disable:4200)   // nonstandard extension used : zero-sized array in struct/union
#pragma warning(disable:4201)   // nonstandard extension used : nameless struct/union

#include <ntdef.h>
#include <stdarg.h>
#include <stdio.h>
#include <stddef.h>
#include <initguid.h>
#include <ntddk.h>
#include <wdm.h>
#include <wmilib.h>
#include <wmistr.h>
#define NTSTRSAFE_LIB
#include <ntstrsafe.h>

#include "JR3PCIIoctls.h"
#include "JR3PCI.h"

#ifdef __cplusplus
}
#endif // __cplusplus

