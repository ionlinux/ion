#ifndef ION_BOOT_CONSOLE_H
#define ION_BOOT_CONSOLE_H

#include <efi.h>

EFI_STATUS console_init(EFI_SYSTEM_TABLE *systab);
VOID print(CHAR16 *msg);
VOID print_status(CHAR16 *prefix, EFI_STATUS status);
VOID print_hex(CHAR16 *prefix, UINT64 value);
VOID print_banner(VOID);
VOID wait_for_key(CHAR16 *prompt);

#endif /* ION_BOOT_CONSOLE_H */
