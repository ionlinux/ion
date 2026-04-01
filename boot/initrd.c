#include <efi.h>
#include <efilib.h>
#include "initrd.h"
#include "loader.h"
#include "console.h"

/*
 * LINUX_EFI_INITRD_MEDIA_GUID -- used by the kernel's EFI stub to
 * discover the initrd via a LoadFile2 protocol on a vendor media
 * device path.
 */
static EFI_GUID LinuxEfiInitrdMediaGuid = {
    0x5568e427, 0x68fc, 0x4f3d,
    {0xac, 0x74, 0xca, 0x55, 0x52, 0x31, 0xcc, 0x68}
};

static EFI_GUID LoadFile2ProtocolGuid = {
    0x4006c0c1, 0xfcb3, 0x4137,
    {0x81, 0x57, 0xc5, 0x28, 0xc3, 0x6b, 0xe8, 0x67}
};

static EFI_GUID DevicePathProtocolGuid = DEVICE_PATH_PROTOCOL;

/* The vendor media device path the kernel looks for */
struct initrd_dev_path {
    VENDOR_DEVICE_PATH vendor;
    EFI_DEVICE_PATH    end;
} __attribute__((packed));

static struct initrd_dev_path initrd_dp = {
    .vendor = {
        .Header = {
            .Type    = MEDIA_DEVICE_PATH,      /* 0x04 */
            .SubType = MEDIA_VENDOR_DP,         /* 0x03 */
            .Length  = { sizeof(VENDOR_DEVICE_PATH), 0 }
        },
        /* GUID filled at runtime to avoid static init issues */
    },
    .end = {
        .Type    = END_DEVICE_PATH_TYPE,        /* 0x7F */
        .SubType = END_ENTIRE_DEVICE_PATH_SUBTYPE, /* 0xFF */
        .Length  = { sizeof(EFI_DEVICE_PATH), 0 }
    }
};

/* Initrd data loaded into memory */
static VOID *initrd_data;
static UINTN initrd_size;
static EFI_HANDLE initrd_handle;

/*
 * LoadFile2 callback -- the kernel's EFI stub calls this to get the initrd.
 */
static EFI_STATUS EFIAPI
initrd_load_file2(
    EFI_LOAD_FILE2_PROTOCOL *this __attribute__((unused)),
    EFI_DEVICE_PATH *file_path __attribute__((unused)),
    BOOLEAN boot_policy,
    UINTN *buffer_size,
    VOID *buffer)
{
    if (boot_policy)
        return EFI_UNSUPPORTED;

    if (buffer == NULL || *buffer_size < initrd_size) {
        *buffer_size = initrd_size;
        return EFI_BUFFER_TOO_SMALL;
    }

    CopyMem(buffer, initrd_data, initrd_size);
    *buffer_size = initrd_size;
    return EFI_SUCCESS;
}

/* Protocol instance */
static EFI_LOAD_FILE2_PROTOCOL initrd_lf2 = {
    .LoadFile = initrd_load_file2
};

EFI_STATUS initrd_register(CHAR16 *initrd_path)
{
    EFI_STATUS status;

    if (initrd_path == NULL)
        return EFI_SUCCESS;

    /* Load the initrd file from the ESP */
    print(L"Loading initrd: ");
    print(initrd_path);
    print(L"\r\n");

    status = load_file(initrd_path, &initrd_data, &initrd_size);
    if (EFI_ERROR(status)) {
        print(L"WARNING: Failed to load initrd\r\n");
        print_status(L"  Status", status);
        return status;
    }

    print_hex(L"Initrd size", initrd_size);

    /* Fill the device path GUID at runtime */
    CopyMem(&initrd_dp.vendor.Guid, &LinuxEfiInitrdMediaGuid, sizeof(EFI_GUID));

    /*
     * Install LoadFile2 protocol on a new handle with our device path.
     * The kernel's EFI stub searches for this exact device path GUID.
     */
    initrd_handle = NULL;
    status = uefi_call_wrapper(BS->InstallMultipleProtocolInterfaces, 7,
        &initrd_handle,
        &DevicePathProtocolGuid, &initrd_dp,
        &LoadFile2ProtocolGuid,  &initrd_lf2,
        NULL);

    if (EFI_ERROR(status)) {
        print(L"ERROR: Failed to install initrd LoadFile2 protocol\r\n");
        print_status(L"  Status", status);
        loader_free(initrd_data, initrd_size);
        initrd_data = NULL;
        return status;
    }

    print(L"Initrd LoadFile2 protocol registered\r\n");
    return EFI_SUCCESS;
}

VOID initrd_unregister(VOID)
{
    if (initrd_handle != NULL) {
        uefi_call_wrapper(BS->UninstallMultipleProtocolInterfaces, 5,
            initrd_handle,
            &DevicePathProtocolGuid, &initrd_dp,
            &LoadFile2ProtocolGuid,  &initrd_lf2,
            NULL);
        initrd_handle = NULL;
    }

    if (initrd_data != NULL) {
        loader_free(initrd_data, initrd_size);
        initrd_data = NULL;
    }
}
