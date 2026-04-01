#include <efi.h>
#include <efilib.h>
#include "loader.h"
#include "console.h"

static EFI_LOADED_IMAGE *gLoadedImage;

EFI_STATUS loader_init_with_image(EFI_LOADED_IMAGE *loaded_image)
{
    gLoadedImage = loaded_image;

    if (gLoadedImage->DeviceHandle == NULL) {
        print(L"ERROR: DeviceHandle is NULL\r\n");
        return EFI_NOT_FOUND;
    }

    return EFI_SUCCESS;
}

EFI_STATUS load_file(CHAR16 *path, VOID **buffer, UINTN *size)
{
    EFI_STATUS status;
    EFI_FILE_HANDLE root;
    EFI_FILE_HANDLE file;
    EFI_FILE_INFO *file_info;
    UINTN file_size;
    UINTN pages;
    EFI_PHYSICAL_ADDRESS buf_addr;

    /* Use gnu-efi's LibOpenRoot to open the ESP filesystem */
    root = LibOpenRoot(gLoadedImage->DeviceHandle);
    if (root == NULL) {
        print(L"ERROR: Failed to open root volume\r\n");
        return EFI_NOT_FOUND;
    }

    /* Open the target file */
    status = uefi_call_wrapper(root->Open, 5,
        root, &file, path, EFI_FILE_MODE_READ, 0);

    if (EFI_ERROR(status)) {
        print(L"ERROR: Failed to open file: ");
        print(path);
        print(L"\r\n");
        uefi_call_wrapper(root->Close, 1, root);
        return status;
    }

    /* Get file info to determine size */
    file_info = LibFileInfo(file);
    if (file_info == NULL) {
        print(L"ERROR: Failed to get file info\r\n");
        uefi_call_wrapper(file->Close, 1, file);
        uefi_call_wrapper(root->Close, 1, root);
        return EFI_NOT_FOUND;
    }

    file_size = file_info->FileSize;
    FreePool(file_info);

    /* Allocate page-aligned buffer for the file contents */
    pages = (file_size + 4095) / 4096;
    status = uefi_call_wrapper(BS->AllocatePages, 4,
        AllocateAnyPages, EfiLoaderData, pages, &buf_addr);

    if (EFI_ERROR(status)) {
        print(L"ERROR: Failed to allocate memory for file\r\n");
        uefi_call_wrapper(file->Close, 1, file);
        uefi_call_wrapper(root->Close, 1, root);
        return status;
    }

    /* Read the file */
    status = uefi_call_wrapper(file->Read, 3,
        file, &file_size, (VOID *)buf_addr);

    uefi_call_wrapper(file->Close, 1, file);
    uefi_call_wrapper(root->Close, 1, root);

    if (EFI_ERROR(status)) {
        print(L"ERROR: Failed to read file\r\n");
        uefi_call_wrapper(BS->FreePages, 2, buf_addr, pages);
        return status;
    }

    *buffer = (VOID *)buf_addr;
    *size = file_size;
    return EFI_SUCCESS;
}

VOID loader_free(VOID *buffer, UINTN size)
{
    UINTN pages = (size + 4095) / 4096;
    uefi_call_wrapper(BS->FreePages, 2,
        (EFI_PHYSICAL_ADDRESS)(UINTN)buffer, pages);
}
