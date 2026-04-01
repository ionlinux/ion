#include <efi.h>
#include <efilib.h>
#include "config.h"
#include "console.h"
#include "loader.h"
#include "linux.h"

EFI_STATUS
efi_main(EFI_HANDLE image_handle, EFI_SYSTEM_TABLE *systab)
{
    EFI_STATUS status;
    EFI_LOADED_IMAGE *loaded_image = NULL;
    EFI_GUID lip_guid = LOADED_IMAGE_PROTOCOL;

    /* Initialize gnu-efi library (sets up ST, BS, RT globals) */
    InitializeLib(image_handle, systab);

    /* Initialize console and display banner */
    status = console_init(systab);
    if (EFI_ERROR(status))
        return status;

    print_banner();

    /* Get LoadedImageProtocol to find the ESP device */
    status = uefi_call_wrapper(systab->BootServices->HandleProtocol, 3,
        image_handle,
        &lip_guid,
        (VOID **)&loaded_image);

    if (EFI_ERROR(status)) {
        print(L"ERROR: Failed to get LoadedImageProtocol\r\n");
        print_status(L"  Status", status);
        wait_for_key(L"Press any key to reboot...\r\n");
        return status;
    }

    /* Initialize file loader with the loaded image */
    status = loader_init_with_image(loaded_image);
    if (EFI_ERROR(status)) {
        print(L"ERROR: Failed to initialize loader\r\n");
        print_status(L"Status", status);
        wait_for_key(L"Press any key to reboot...\r\n");
        return status;
    }

    print(L"Loading kernel: " KERNEL_PATH L"\r\n");

    /* Load and boot the Linux kernel -- does not return on success */
    status = linux_load_and_boot(
        image_handle,
        systab,
        KERNEL_PATH,
        INITRD_PATH,
        (CHAR8 *)CMDLINE_DEFAULT
    );

    /* If we reach here, boot failed */
    print(L"FATAL: Boot failed!\r\n");
    print_status(L"Status", status);
    wait_for_key(L"Press any key to reboot...\r\n");

    return status;
}
