#ifndef ION_BOOT_MEMORY_H
#define ION_BOOT_MEMORY_H

#include <efi.h>
#include "linux.h"

EFI_STATUS get_memory_map_and_exit(
    EFI_HANDLE image_handle,
    struct boot_params *bp
);

#endif /* ION_BOOT_MEMORY_H */
