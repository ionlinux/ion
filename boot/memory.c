#include <efi.h>
#include <efilib.h>
#include "memory.h"
#include "console.h"

static UINT32 efi_mem_type_to_e820(UINT32 efi_type)
{
    switch (efi_type) {
    case EfiConventionalMemory:
    case EfiLoaderCode:
    case EfiLoaderData:
    case EfiBootServicesCode:
    case EfiBootServicesData:
        return E820_RAM;
    case EfiACPIReclaimMemory:
        return E820_ACPI;
    case EfiACPIMemoryNVS:
        return E820_NVS;
    case EfiUnusableMemory:
        return E820_UNUSABLE;
    default:
        return E820_RESERVED;
    }
}

static void build_e820_map(
    EFI_MEMORY_DESCRIPTOR *mmap,
    UINTN map_size,
    UINTN desc_size,
    struct boot_params *bp)
{
    UINTN offset;
    UINT8 count = 0;

    for (offset = 0; offset < map_size && count < E820_MAX_ENTRIES;
         offset += desc_size)
    {
        EFI_MEMORY_DESCRIPTOR *desc =
            (EFI_MEMORY_DESCRIPTOR *)((UINT8 *)mmap + offset);

        UINT64 addr = desc->PhysicalStart;
        UINT64 size = desc->NumberOfPages * 4096;
        UINT32 type = efi_mem_type_to_e820(desc->Type);

        if (size == 0)
            continue;

        /* Coalesce with previous entry if same type and contiguous */
        if (count > 0 &&
            bp->e820_table[count - 1].type == type &&
            bp->e820_table[count - 1].addr +
            bp->e820_table[count - 1].size == addr)
        {
            bp->e820_table[count - 1].size += size;
        } else {
            bp->e820_table[count].addr = addr;
            bp->e820_table[count].size = size;
            bp->e820_table[count].type = type;
            count++;
        }
    }

    bp->e820_entries = count;
}

EFI_STATUS get_memory_map_and_exit(
    EFI_HANDLE image_handle,
    struct boot_params *bp)
{
    EFI_STATUS status;
    UINTN map_size = 0;
    UINTN map_key;
    UINTN desc_size;
    UINT32 desc_version;
    EFI_MEMORY_DESCRIPTOR *mmap = NULL;

    /* First call to get required buffer size */
    status = uefi_call_wrapper(BS->GetMemoryMap, 5,
        &map_size, NULL, &map_key, &desc_size, &desc_version);

    if (status != EFI_BUFFER_TOO_SMALL)
        return EFI_LOAD_ERROR;

    /* Allocate with headroom (AllocatePool may add a map entry) */
    map_size += 2 * desc_size;

    status = uefi_call_wrapper(BS->AllocatePool, 3,
        EfiLoaderData, map_size, (VOID **)&mmap);
    if (EFI_ERROR(status))
        return status;

    /* Get the actual memory map */
    status = uefi_call_wrapper(BS->GetMemoryMap, 5,
        &map_size, mmap, &map_key, &desc_size, &desc_version);
    if (EFI_ERROR(status)) {
        uefi_call_wrapper(BS->FreePool, 1, mmap);
        return status;
    }

    /* Fill EFI memory map info in boot_params */
    bp->efi_info.efi_memmap       = (UINT32)((UINT64)(UINTN)mmap & 0xFFFFFFFF);
    bp->efi_info.efi_memmap_hi    = (UINT32)((UINT64)(UINTN)mmap >> 32);
    bp->efi_info.efi_memmap_size  = (UINT32)map_size;
    bp->efi_info.efi_memdesc_size = (UINT32)desc_size;
    bp->efi_info.efi_memdesc_version = desc_version;

    /* Build E820 map for the zero page */
    build_e820_map(mmap, map_size, desc_size, bp);

    /* Exit boot services */
    status = uefi_call_wrapper(BS->ExitBootServices, 2,
        image_handle, map_key);

    if (EFI_ERROR(status)) {
        /*
         * Map key was stale. Per UEFI spec, retry: get the map again
         * (reusing the same buffer -- no allocation allowed now) and
         * immediately call ExitBootServices.
         */
        map_size = 0;
        uefi_call_wrapper(BS->GetMemoryMap, 5,
            &map_size, NULL, &map_key, &desc_size, &desc_version);

        /* If our buffer is still large enough, reuse it */
        status = uefi_call_wrapper(BS->GetMemoryMap, 5,
            &map_size, mmap, &map_key, &desc_size, &desc_version);
        if (EFI_ERROR(status))
            return status;

        /* Update EFI info and E820 with fresh map */
        bp->efi_info.efi_memmap_size = (UINT32)map_size;
        bp->efi_info.efi_memdesc_size = (UINT32)desc_size;
        bp->efi_info.efi_memdesc_version = desc_version;
        build_e820_map(mmap, map_size, desc_size, bp);

        status = uefi_call_wrapper(BS->ExitBootServices, 2,
            image_handle, map_key);

        if (EFI_ERROR(status))
            return status;
    }

    /* Boot services are now terminated. No UEFI calls allowed. */
    return EFI_SUCCESS;
}
