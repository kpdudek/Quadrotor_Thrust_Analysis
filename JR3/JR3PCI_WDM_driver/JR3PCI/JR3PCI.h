/**********************************************************************
;       Copyright 2015 JR3, Inc.
;
;**********************************************************************/

#pragma once

#include <srb.h>

#pragma pack(push, 1)

#ifndef RTL_CONSTANT_STRING
#define RTL_CONSTANT_STRING(s) { sizeof( s ) - sizeof( (s)[0] ), sizeof( s ), s }
#endif

// Memory allocation pool tag
#define JR3PCI_POOL_TAG 'dWdW'

typedef enum JR3PCI_TRANSFER_DIRECTION
{
	tdH2D,
	tdD2H
};

#ifndef __max

#define __max(a,b)  (((a) > (b)) ? (a) : (b))
#define __min(a,b)  (((a) < (b)) ? (a) : (b))

#endif

// Make all pool allocations tagged
#undef ExAllocatePool
#define ExAllocatePool(type, size) \
    ExAllocatePoolWithTag(type, size, JR3PCI_POOL_TAG);

// queue start io callback
typedef VOID (*PJR3PCI_QUEUE_STARTIO)(
    IN PDEVICE_OBJECT   DeviceObject,
    IN PIRP             Irp 
    );

// irp queue type definition
typedef struct _JR3PCI_QUEUE
{
    PJR3PCI_QUEUE_STARTIO StartIoRoutine;
    PDEVICE_OBJECT  DeviceObject;
    LIST_ENTRY      IrpQueue;
    KSPIN_LOCK      QueueLock;
    PIRP            CurrentIrp;
    KEVENT          StopEvent;
    LONG            StallCount; 
    NTSTATUS        ErrorStatus;
    KDPC            JR3PCIStartIoDpc;
    BOOLEAN         bUseJR3PCIStartIoDpc;
} JR3PCI_QUEUE, *PJR3PCI_QUEUE;

// cancel-safe irp list type definition
typedef struct _JR3PCI_LIST
{
    PDEVICE_OBJECT  DeviceObject;
    LIST_ENTRY      IrpList;
    KSPIN_LOCK      ListLock;
    NTSTATUS        ErrorStatus;
} JR3PCI_LIST, *PJR3PCI_LIST;

// stall IRP list to syncronize Pnp, Power with
// the rest of IO
typedef struct _JR3PCI_IO_LOCK
{
    PDEVICE_OBJECT  DeviceObject;       // our device object
    KEVENT          StallCompleteEvent; // io stalled event
    LIST_ENTRY      StallIrpList;       // stalled irps
    KSPIN_LOCK      IoLock;             // spin lock to syncronize io with stall/unstall
    LONG            StallCount;         // number of times stall was requested
    LONG            ActiveIrpCount;     // number of oustanding, not-stalled IRPs
    NTSTATUS        ErrorStatus;
    PIRP            CurrentIrp;         // used by unstall code
} JR3PCI_IO_LOCK, *PJR3PCI_IO_LOCK;

// global (per driver) data block
typedef struct _JR3PCI_DATA
{
    UNICODE_STRING      RegistryPath;           // saved registry path
    USHORT              WdmVersion;             // os version
	ULONG				ulDeviceIndexMap;		// Keeps track of used device indices.

} JR3PCI_DATA, *PJR3PCI_DATA;

extern JR3PCI_DATA g_Data;

// PnP states
typedef enum _JR3PCI_PNP_STATE 
{
    PnpStateNotStarted = 0,
    PnpStateStarted,
    PnpStateStopPending,
    PnpStateStopped,
    PnpStateRemovePending,
    PnpStateRemoved,
    PnpStateSurpriseRemoved
} JR3PCI_PNP_STATE;

// The device extension for the device object
typedef struct _DEVICE_EXTENSION
{
    PDEVICE_OBJECT			pDeviceObject;          // pointer to the DeviceObject
    PDEVICE_OBJECT          PhysicalDeviceObject;   // underlying PDO
    PDEVICE_OBJECT          LowerDeviceObject;      // top of the device stack

    LONG                    RemoveCount;            // 1-based reference count
    KEVENT                  RemoveEvent;            // event to sync device removal

    JR3PCI_IO_LOCK IoLock;							// misc io lock

    JR3PCI_PNP_STATE		PnpState;               // PnP state variable
    JR3PCI_PNP_STATE		PreviousPnpState;       // Previous PnP state variable
    LONG                    OpenHandleCount;

    PULONG					pulBar0Base;	// Port resource pointer
	ULONG					pulBar0Length;

//    PULONG					pulBar1Base;	// Port resource pointer
//	ULONG					pulBar1Length;

	PKINTERRUPT				pInterruptObject;
	
	// These are the resources assigned via StartDevice. We save them
	// so we can re-initialize the IOC at any point in time (via IOCTL).
	KIRQL irql;
	ULONG ulVector;
	KAFFINITY affinity;
	KINTERRUPT_MODE interruptMode;
	BOOLEAN bSharedInterrupt;

	// This is our device instance symbolic link name. Needed to delete the symbolic link when the driver is removed.
	UNICODE_STRING SymbolicLinkName;

	// This is our device index. We need to save it in order to clear the bit in the device index bit map when the device is removed.
	ULONG ulDeviceIndex;

	// This is the number of channels supported by this card.
	// Calculated as bar size / 80000h.
	ULONG ulSupportedChannels;

} DEVICE_EXTENSION, *PDEVICE_EXTENSION;

// Borrowed from Winbase.h
typedef struct _OVERLAPPED {
    ULONG_PTR Internal;
    ULONG_PTR InternalHigh;
    union {
        struct {
            DWORD Offset;
            DWORD OffsetHigh;
        };

        PVOID Pointer;
    };

    HANDLE  hEvent;
} OVERLAPPED, *LPOVERLAPPED;

#ifdef __cplusplus
extern "C" 
{
#endif

NTSTATUS __stdcall DriverEntry(
    IN  PDRIVER_OBJECT  DriverObject,
    IN  PUNICODE_STRING RegistryPath
    );

NTSTATUS __stdcall JR3PCIAddDevice(
    IN  PDRIVER_OBJECT  DriverObject,
    IN  PDEVICE_OBJECT  PhysicalDeviceObject
    );

VOID __stdcall JR3PCIUnload(
    IN  PDRIVER_OBJECT  DriverObject
    );

NTSTATUS __stdcall JR3PCIPnpDispatch(
    IN  PDEVICE_OBJECT  DeviceObject,
    IN  PIRP            Irp
    );

NTSTATUS __stdcall JR3PCIPowerDispatch(
    IN  PDEVICE_OBJECT  DeviceObject,
    IN  PIRP            Irp
    );

NTSTATUS __stdcall JR3PCIDeviceIoControlDispatch(
    IN  PDEVICE_OBJECT  DeviceObject,
    IN  PIRP            Irp
    );

NTSTATUS __stdcall JR3PCICreateDispatch(
    IN  PDEVICE_OBJECT  DeviceObject,
    IN  PIRP            Irp
    );

NTSTATUS __stdcall JR3PCICloseDispatch(
    IN  PDEVICE_OBJECT  DeviceObject,
    IN  PIRP            Irp
    );

NTSTATUS __stdcall JR3PCICleanupDispatch(
    IN  PDEVICE_OBJECT  DeviceObject,
    IN  PIRP            Irp
    );

NTSTATUS __stdcall JR3PCISystemControlDispatch(
    IN  PDEVICE_OBJECT  DeviceObject,
    IN  PIRP            Irp
    );

///////////////////////////////////////////////////////////////////////////////////////////////////
// Queue Functions
///////////////////////////////////////////////////////////////////////////////////////////////////

VOID JR3PCIInitializeQueue(
    IN  PJR3PCI_QUEUE    QueueExtension,
    IN  PJR3PCI_QUEUE_STARTIO     StartIoRoutine,
    IN  PDEVICE_OBJECT      DeviceObject,
    IN  BOOLEAN             bUseJR3PCIStartIoDpc
    );

NTSTATUS JR3PCIQueueIrp(
    IN  PJR3PCI_QUEUE    QueueExtension,
    IN  PIRP                Irp
    );

VOID JR3PCIStartNext(
    IN  PJR3PCI_QUEUE    QueueExtension
    );

VOID JR3PCIFlushQueue(
    IN  PJR3PCI_QUEUE    QueueExtension,
    IN  PFILE_OBJECT        FileObject
    );

VOID JR3PCIInvalidateQueue(
    IN  PJR3PCI_QUEUE    Queue,
    IN  NTSTATUS                  ErrorStatus
    );

VOID JR3PCIPauseQueue(
    IN  PJR3PCI_QUEUE    QueueExtension
    );
    
VOID JR3PCIRestartQueue(
    IN  PJR3PCI_QUEUE    QueueExtension
    );

VOID JR3PCIStartIoDpc(
    IN  PKDPC       Dpc,
    IN  PVOID       Context,
    IN  PVOID       Unused1,
    IN  PVOID       Unused2
    );

VOID JR3PCIQueueCancelRoutine(
    IN  PDEVICE_OBJECT  DeviceObject,
    IN  PIRP            Irp
    );

///////////////////////////////////////////////////////////////////////////////////////////////////
// List functions
///////////////////////////////////////////////////////////////////////////////////////////////////

VOID JR3PCIInitializeList(
    IN  PJR3PCI_LIST   List,
    IN  PDEVICE_OBJECT          DeviceObject
    );

NTSTATUS JR3PCIInsertHead(
    IN  PJR3PCI_LIST   List, 
    IN  PIRP                Irp
    );

NTSTATUS JR3PCIInsertTail(
    IN  PJR3PCI_LIST   List, 
    IN  PIRP                Irp
    );

PIRP JR3PCIRemoveHead(
    IN  PJR3PCI_LIST   List
    );

PIRP JR3PCIRemoveTail(
    IN  PJR3PCI_LIST   List
    );

VOID JR3PCIFlushList(
    IN  PJR3PCI_LIST   List,
    IN  PFILE_OBJECT        FileObject
    );

VOID JR3PCIInvalidateList(
    IN  PJR3PCI_LIST   List,
    IN  NTSTATUS                ErrorStatus
    );

VOID JR3PCIListCancelRoutine(
    IN  PDEVICE_OBJECT  DeviceObject,
    IN  PIRP            Irp
    );

///////////////////////////////////////////////////////////////////////////////////////////////////
// JR3PCI_IO_LOCK
///////////////////////////////////////////////////////////////////////////////////////////////////

VOID JR3PCIInitializeIoLock(
    IN  PJR3PCI_IO_LOCK    IoLock, 
    IN  PDEVICE_OBJECT              DeviceObject
    );

NTSTATUS JR3PCICheckIoLock(
    IN  PJR3PCI_IO_LOCK    IoLock, 
    IN  PIRP                        Irp
    );

VOID JR3PCIPendingIoCancelRoutine(
    IN  PDEVICE_OBJECT  DeviceObject,
    IN  PIRP            Irp
    );

NTSTATUS JR3PCIIncrementIoCount(
    IN  PJR3PCI_IO_LOCK    IoLock
    );

VOID JR3PCIDecrementIoCount(
    IN  PJR3PCI_IO_LOCK    IoLock
    );

VOID JR3PCILockIo(
    IN  PJR3PCI_IO_LOCK    IoLock
    );

VOID JR3PCIWaitForStopIo(
    IN  PJR3PCI_IO_LOCK    IoLock
    );

VOID JR3PCIUnlockIo(
    IN  PJR3PCI_IO_LOCK    IoLock
    );

VOID JR3PCIFlushPendingIo(
    IN  PJR3PCI_IO_LOCK    IoLock,
    IN  PFILE_OBJECT                FileObject
    );

VOID JR3PCIInvalidateIo(
    IN  PJR3PCI_IO_LOCK    IoLock,
    IN  NTSTATUS                    ErrorStatus
    );
#ifdef __cplusplus
}
#endif

BOOLEAN JR3PCIIsStoppable(
    IN  PDEVICE_EXTENSION    DeviceExtension
    );

BOOLEAN JR3PCIIsRemovable(
    IN  PDEVICE_EXTENSION    DeviceExtension
    );

BOOLEAN JR3PCIAcquireRemoveLock(
    IN  PDEVICE_EXTENSION    DeviceExtension
    );

VOID JR3PCIReleaseRemoveLock(
    IN  PDEVICE_EXTENSION    DeviceExtension
    );

VOID JR3PCIWaitForSafeRemove(
    IN  PDEVICE_EXTENSION    DeviceExtension
    );

NTSTATUS JR3PCISubmitIrpSync(
    IN  PDEVICE_OBJECT  DeviceObject,
    IN  PIRP            Irp
    );

VOID JR3PCIStallQueues(
    IN  PDEVICE_EXTENSION DeviceExtension
    );

VOID JR3PCIRestartQueues(
    IN  PDEVICE_EXTENSION DeviceExtension
    );

VOID JR3PCIFlushQueues(
    IN  PDEVICE_EXTENSION   DeviceExtension,
    IN  PFILE_OBJECT            FileObject
    );

///////////////////////////////////////////////////////////////////////////////////////////////////
// Pnp 
///////////////////////////////////////////////////////////////////////////////////////////////////

// define this PnP IRP.  This IRP is only defined in ntddk.h normally
#if !defined(IRP_MN_QUERY_LEGACY_BUS_INFORMATION)
#define IRP_MN_QUERY_LEGACY_BUS_INFORMATION     0x18
#endif // IRP_MN_QUERY_LEGACY_BUS_INFORMATION

NTSTATUS JR3PCIStartDevice(
    IN  PDEVICE_EXTENSION    DeviceExtension,
    IN  PIRP                            Irp
    );

NTSTATUS JR3PCIFreeResources(
    IN  PDEVICE_EXTENSION DeviceExtension
    );

///////////////////////////////////////////////////////////////////////////////////////////////////
// Power
///////////////////////////////////////////////////////////////////////////////////////////////////



///////////////////////////////////////////////////////////////////////////////////////////////////
// Registry
///////////////////////////////////////////////////////////////////////////////////////////////////

PVOID JR3PCIRegQueryValueKey(
    IN  HANDLE  RegKeyHandle,
    IN  PWSTR   SubKeyName,
    IN  PWSTR   ValueName,
    OUT PULONG  Length
    );

VOID JR3PCIRegEnumerateKeys(
    IN  HANDLE RegKeyHandle
    );

VOID JR3PCIRegEnumerateValueKeys(
    IN  HANDLE  RegKeyHandle
    );

///////////////////////////////////////////////////////////////////////////////////////////////////
// Debug
///////////////////////////////////////////////////////////////////////////////////////////////////

// definition of debug levels

#define DBG_NONE            0
#define DBG_ERR             1
#define DBG_WARN            2
#define DBG_TRACE           3
#define DBG_INFO            4
#define DBG_VERB            5

#ifdef JR3PCI_WMI_TRACE

/*
tracepdb -f objchk_wxp_x86\i386\JR3PCI.pdb -p C:\JR3PCI
SET TRACE_FORMAT_SEARCH_PATH=C:\JR3PCI

tracelog -start JR3PCI -guid JR3PCI.ctl -f JR3PCI.log -flags 0x7FFFFFFF -level 5
tracelog -stop JR3PCI

tracefmt -o JR3PCI.txt -f JR3PCI.log
*/

#define WPP_AREA_LEVEL_LOGGER(Area,Lvl)           WPP_LEVEL_LOGGER(Area)
#define WPP_AREA_LEVEL_ENABLED(Area,Lvl)          (WPP_LEVEL_ENABLED(Area) && WPP_CONTROL(WPP_BIT_##Area).Level >= Lvl)

#define WPP_CONTROL_GUIDS \
    WPP_DEFINE_CONTROL_GUID(JR3PCI,(5B8489B9,4F44,499E,8AC5,3B2C95B9FD5F), \
        WPP_DEFINE_BIT(DBG_GENERAL)                 /* bit  0 = 0x00000001 */ \
        WPP_DEFINE_BIT(DBG_PNP)                     /* bit  1 = 0x00000002 */ \
        WPP_DEFINE_BIT(DBG_POWER)                   /* bit  2 = 0x00000004 */ \
        WPP_DEFINE_BIT(DBG_COUNT)                   /* bit  3 = 0x00000008 */ \
        WPP_DEFINE_BIT(DBG_CREATECLOSE)             /* bit  4 = 0x00000010 */ \
        WPP_DEFINE_BIT(DBG_WMI)                     /* bit  5 = 0x00000020 */ \
        WPP_DEFINE_BIT(DBG_UNLOAD)                  /* bit  6 = 0x00000040 */ \
        WPP_DEFINE_BIT(DBG_IO)                      /* bit  7 = 0x00000080 */ \
        WPP_DEFINE_BIT(DBG_INIT)                    /* bit  8 = 0x00000100 */ \
        WPP_DEFINE_BIT(DBG_09)                      /* bit  9 = 0x00000200 */ \
        WPP_DEFINE_BIT(DBG_10)                      /* bit 10 = 0x00000400 */ \
        WPP_DEFINE_BIT(DBG_11)                      /* bit 11 = 0x00000800 */ \
        WPP_DEFINE_BIT(DBG_12)                      /* bit 12 = 0x00001000 */ \
        WPP_DEFINE_BIT(DBG_13)                      /* bit 13 = 0x00002000 */ \
        WPP_DEFINE_BIT(DBG_14)                      /* bit 14 = 0x00004000 */ \
        WPP_DEFINE_BIT(DBG_15)                      /* bit 15 = 0x00008000 */ \
        WPP_DEFINE_BIT(DBG_16)                      /* bit 16 = 0x00010000 */ \
        WPP_DEFINE_BIT(DBG_17)                      /* bit 17 = 0x00020000 */ \
        WPP_DEFINE_BIT(DBG_18)                      /* bit 18 = 0x00040000 */ \
        WPP_DEFINE_BIT(DBG_19)                      /* bit 19 = 0x00080000 */ \
        WPP_DEFINE_BIT(DBG_20)                      /* bit 20 = 0x00100000 */ \
        WPP_DEFINE_BIT(DBG_21)                      /* bit 21 = 0x00200000 */ \
        WPP_DEFINE_BIT(DBG_22)                      /* bit 22 = 0x00400000 */ \
        WPP_DEFINE_BIT(DBG_23)                      /* bit 23 = 0x00800000 */ \
        WPP_DEFINE_BIT(DBG_24)                      /* bit 24 = 0x01000000 */ \
        WPP_DEFINE_BIT(DBG_25)                      /* bit 25 = 0x02000000 */ \
        WPP_DEFINE_BIT(DBG_26)                      /* bit 26 = 0x04000000 */ \
        WPP_DEFINE_BIT(DBG_27)                      /* bit 27 = 0x08000000 */ \
        WPP_DEFINE_BIT(DBG_28)                      /* bit 28 = 0x10000000 */ \
        WPP_DEFINE_BIT(DBG_29)                      /* bit 29 = 0x20000000 */ \
        WPP_DEFINE_BIT(DBG_30)                      /* bit 30 = 0x40000000 */ \
        WPP_DEFINE_BIT(DBG_31)                      /* bit 31 = 0x80000000 */ \
        )

__inline VOID JR3PCIDumpIrp(
    IN PIRP Irp
    )
{
}

__inline PCHAR SystemPowerStateString(
    IN  SYSTEM_POWER_STATE  SystemState
    )
{
    return "";
}

__inline PCHAR DevicePowerStateString(
    IN  DEVICE_POWER_STATE  DeviceState
    )
{
    return "";
}

#else

// definition of debug areas

#define DBG_GENERAL         (1 << 0)
#define DBG_PNP             (1 << 1)
#define DBG_POWER           (1 << 2)
#define DBG_COUNT           (1 << 3)
#define DBG_CREATECLOSE     (1 << 4)
#define DBG_WMI             (1 << 5)
#define DBG_UNLOAD          (1 << 6)
#define DBG_IO              (1 << 7)
#define DBG_INIT            (1 << 8)

#define DBG_ALL             0xFFFFFFFF

VOID JR3PCIDebugPrint(
    IN ULONG    Area,
    IN ULONG    Level,
    IN PCCHAR   Format,
    IN          ...
    );

VOID JR3PCIDumpIrp(
    IN PIRP Irp
    );

PCHAR IrpMajorFunctionString(
    IN  UCHAR MajorFunction
    );

PCHAR PnPMinorFunctionString(
    IN  UCHAR   MinorFunction
    );

PCHAR PowerMinorFunctionString(
    IN  UCHAR   MinorFunction
    );

PCHAR SystemPowerStateString(
    IN  SYSTEM_POWER_STATE  SystemState
    );

PCHAR DevicePowerStateString(
    IN  DEVICE_POWER_STATE  DeviceState
    );

PCHAR WMIMinorFunctionString (
    IN  UCHAR MinorFunction
    );

#endif

NTSTATUS JR3PCIAccessConfigSpace(
    IN  PDEVICE_EXTENSION DeviceExtension,
    IN  BOOLEAN                 IsRead,
    IN OUT PVOID                Buffer,
    IN  ULONG                   Offset,
    IN  ULONG                   Length,
    OUT PULONG                  ReadWrittenSize
    );

ULONG VirtualToPhysicalAddress(PVOID pVirtualAddress);
PVOID PhysicalToVirtualAddress(ULONG ulPhysicalAddress);

NTSTATUS CompleteIRP(PIRP pIrp, NTSTATUS status, ULONG ulBytesTransferred);

///////////////////////////////// JR3PCI definitions ///////////////////////////

#define JR3_DATA_OFFSET			0x6000
#define JR3_RESET_ADDR			0x18000
#define JR3_LO_DSP_BYTE_OFFSET	0x40000
#define JR3_CH1_BAR_OFFSET		0x80000
#define JR3_BAR_RANGE_PER_CH	0x80000

#pragma pack(pop)