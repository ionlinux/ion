#include <efi.h>
#include <efilib.h>
#include "linux.h"
#include "loader.h"
#include "console.h"
#include "initrd.h"
#include "config.h"

static UINTN strlen_a(CHAR8 *s)
{
    UINTN len = 0;
    while (s[len]) len++;
    return len;
}

/*
 * Convert ASCII command line to UCS-2 for UEFI LoadOptions.
 * Returns allocated CHAR16 buffer and sets *out_size to size in bytes.
 */
static CHAR16 *cmdline_to_ucs2(CHAR8 *cmdline, UINTN *out_size)
{
    UINTN len = strlen_a(cmdline);
    UINTN size = (len + 1) * sizeof(CHAR16);
    CHAR16 *buf;
    EFI_STATUS status;

    status = uefi_call_wrapper(BS->AllocatePool, 3,
        EfiLoaderData, size, (VOID **)&buf);
    if (EFI_ERROR(status))
        return NULL;

    for (UINTN i = 0; i < len; i++)
        buf[i] = (CHAR16)cmdline[i];
    buf[len] = L'\0';

    *out_size = size;
    return buf;
}

EFI_STATUS linux_load_and_boot(
    EFI_HANDLE image_handle,
    EFI_SYSTEM_TABLE *systab __attribute__((unused)),
    CHAR16 *kernel_path,
    CHAR16 *initrd_path,
    CHAR8  *cmdline)
{
    EFI_STATUS status;
    VOID *kernel_buf = NULL;
    UINTN kernel_size = 0;
    EFI_HANDLE kernel_handle = NULL;
    EFI_LOADED_IMAGE *kernel_image = NULL;
    EFI_GUID lip_guid = LOADED_IMAGE_PROTOCOL;
    CHAR16 *cmdline_ucs2 = NULL;
    UINTN cmdline_ucs2_size = 0;
    EFI_DEVICE_PATH *kernel_path_dp = NULL;

    /* Step 1: Load the kernel file into memory */
    status = load_file(kernel_path, &kernel_buf, &kernel_size);
    if (EFI_ERROR(status))
        return status;

    print_hex(L"Kernel size", kernel_size);

    /* Verify this looks like a Linux bzImage */
    if (kernel_size > 0x202 + 4) {
        UINT32 *magic = (UINT32 *)((UINT8 *)kernel_buf + 0x202);
        if (*magic != 0x53726448) { /* "HdrS" */
            print(L"WARNING: No Linux boot header found\r\n");
        } else {
            UINT16 *version = (UINT16 *)((UINT8 *)kernel_buf + 0x206);
            print_hex(L"Boot protocol version", *version);
        }
    }

    /*
     * Step 2: Use UEFI LoadImage to register the kernel as an EFI image.
     *
     * The Linux kernel's EFI stub makes it a valid PE32+ executable.
     * LoadImage with SourceBuffer loads directly from memory.
     */
    print(L"Loading kernel as EFI image...\r\n");

    status = uefi_call_wrapper(BS->LoadImage, 6,
        FALSE,              /* BootPolicy */
        image_handle,       /* ParentImageHandle */
        kernel_path_dp,     /* DevicePath (NULL when using SourceBuffer) */
        kernel_buf,         /* SourceBuffer */
        kernel_size,        /* SourceSize */
        &kernel_handle);    /* ImageHandle */

    /* Free the raw kernel buffer -- LoadImage made its own copy */
    loader_free(kernel_buf, kernel_size);

    if (EFI_ERROR(status)) {
        print(L"ERROR: LoadImage failed\r\n");
        print_status(L"  Status", status);
        return status;
    }

    print(L"Kernel loaded as EFI image\r\n");

    /*
     * Step 3: Set the command line via LoadOptions.
     *
     * The kernel's EFI stub reads the command line from
     * LoadedImage->LoadOptions (UCS-2 string).
     */
    status = uefi_call_wrapper(BS->HandleProtocol, 3,
        kernel_handle,
        &lip_guid,
        (VOID **)&kernel_image);

    if (EFI_ERROR(status)) {
        print(L"ERROR: Failed to get kernel LoadedImage\r\n");
        uefi_call_wrapper(BS->UnloadImage, 1, kernel_handle);
        return status;
    }

    /*
     * Set the kernel's DeviceHandle to the bootloader's ESP device.
     * LoadImage with SourceBuffer leaves DeviceHandle NULL, which
     * prevents the kernel's EFI stub from accessing the filesystem
     * (needed for initrd= cmdline loading).
     */
    {
        EFI_LOADED_IMAGE *boot_image = NULL;
        status = uefi_call_wrapper(BS->HandleProtocol, 3,
            image_handle, &lip_guid, (VOID **)&boot_image);
        if (!EFI_ERROR(status) && boot_image != NULL) {
            kernel_image->DeviceHandle = boot_image->DeviceHandle;
        }
    }

    cmdline_ucs2 = cmdline_to_ucs2(cmdline, &cmdline_ucs2_size);
    if (cmdline_ucs2 != NULL) {
        kernel_image->LoadOptions = cmdline_ucs2;
        kernel_image->LoadOptionsSize = (UINT32)cmdline_ucs2_size;

        print(L"Command line: ");
        print(cmdline_ucs2);
        print(L"\r\n");
    }

    /*
     * Step 4: Register initrd via LoadFile2 protocol.
     * The kernel's EFI stub discovers the initrd through this.
     */
    if (initrd_path != NULL) {
        status = initrd_register(initrd_path);
        if (EFI_ERROR(status))
            print(L"WARNING: Continuing without initrd\r\n");
    }

    /*
     * Step 5: Start the kernel.
     *
     * The kernel's EFI stub will:
     *   - Parse the command line
     *   - Set up boot_params
     *   - Handle the memory map
     *   - Call ExitBootServices
     *   - Decompress and jump to the real kernel
     */
    print(L"Starting kernel...\r\n");

    status = uefi_call_wrapper(BS->StartImage, 3,
        kernel_handle,
        NULL,       /* ExitDataSize */
        NULL);      /* ExitData */

    /* If StartImage returns, the kernel exited or failed */
    print(L"ERROR: Kernel returned from StartImage\r\n");
    print_status(L"  Status", status);

    initrd_unregister();

    if (cmdline_ucs2)
        FreePool(cmdline_ucs2);

    return status;
}
