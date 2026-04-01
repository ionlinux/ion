#ifndef ION_BOOT_INITRD_H
#define ION_BOOT_INITRD_H

#include <efi.h>

EFI_STATUS initrd_register(CHAR16 *initrd_path);
VOID initrd_unregister(VOID);

#endif /* ION_BOOT_INITRD_H */
