#ifndef ION_BOOT_LOADER_H
#define ION_BOOT_LOADER_H

#include <efi.h>

EFI_STATUS loader_init_with_image(EFI_LOADED_IMAGE *loaded_image);
EFI_STATUS load_file(CHAR16 *path, VOID **buffer, UINTN *size);
VOID loader_free(VOID *buffer, UINTN size);

#endif /* ION_BOOT_LOADER_H */
