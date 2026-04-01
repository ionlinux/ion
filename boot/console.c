#include <efi.h>
#include <efilib.h>
#include "console.h"
#include "config.h"

/*
 * gnu-efi's InitializeLib() sets the global ST (aliased as gST).
 * We use ST directly throughout -- no local copy needed.
 */

EFI_STATUS console_init(EFI_SYSTEM_TABLE *systab __attribute__((unused)))
{
    EFI_STATUS status;

    status = uefi_call_wrapper(ST->ConOut->Reset, 2, ST->ConOut, FALSE);
    if (EFI_ERROR(status))
        return status;

    uefi_call_wrapper(ST->ConOut->SetAttribute, 2,
        ST->ConOut, EFI_WHITE | EFI_BACKGROUND_BLACK);
    uefi_call_wrapper(ST->ConOut->ClearScreen, 1, ST->ConOut);

    return EFI_SUCCESS;
}

VOID print(CHAR16 *msg)
{
    if (ST && ST->ConOut)
        uefi_call_wrapper(ST->ConOut->OutputString, 2, ST->ConOut, msg);
}

VOID print_status(CHAR16 *prefix, EFI_STATUS status)
{
    CHAR16 buf[64];

    print(prefix);
    print(L": ");
    StatusToString(buf, status);
    print(buf);
    print(L"\r\n");
}

VOID print_hex(CHAR16 *prefix, UINT64 value)
{
    CHAR16 buf[19];
    CHAR16 *hex = L"0123456789ABCDEF";
    int i;

    print(prefix);
    print(L": 0x");

    if (value == 0) {
        print(L"0");
    } else {
        i = 0;
        int started = 0;
        for (int shift = 60; shift >= 0; shift -= 4) {
            UINT8 nibble = (value >> shift) & 0xF;
            if (nibble != 0 || started) {
                buf[i++] = hex[nibble];
                started = 1;
            }
        }
        buf[i] = L'\0';
        print(buf);
    }
    print(L"\r\n");
}

VOID print_banner(VOID)
{
    print(L"\r\n");
    print(L"==========================================\r\n");
    print(L"  ");
    print(BOOTLOADER_NAME);
    print(L"\r\n");
    print(L"  Architecture: x86_64 UEFI\r\n");
    print(L"==========================================\r\n");
    print(L"\r\n");
}

VOID wait_for_key(CHAR16 *prompt)
{
    EFI_INPUT_KEY key;
    UINTN index;

    print(prompt);
    uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &index);
    uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, &key);
}
