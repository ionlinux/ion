#ifndef ION_BOOT_LINUX_H
#define ION_BOOT_LINUX_H

#include <efi.h>

#define LINUX_BOOT_HEADER_MAGIC  0x53726448  /* "HdrS" */
#define LINUX_BOOT_FLAG          0xAA55

#define LOADED_HIGH     (1 << 0)
#define CAN_USE_HEAP    (1 << 7)
#define QUIET_FLAG      (1 << 5)
#define KEEP_SEGMENTS   (1 << 6)

#define XLF_KERNEL_64                (1 << 0)
#define XLF_CAN_BE_LOADED_ABOVE_4G  (1 << 1)
#define XLF_EFI_HANDOVER_64         (1 << 3)

/* E820 memory types */
#define E820_RAM       1
#define E820_RESERVED  2
#define E820_ACPI      3
#define E820_NVS       4
#define E820_UNUSABLE  5

#define E820_MAX_ENTRIES 128

struct setup_header {
    UINT8   setup_sects;          /* 0x1F1 */
    UINT16  root_flags;           /* 0x1F2 */
    UINT32  syssize;              /* 0x1F4 */
    UINT16  ram_size;             /* 0x1F8 */
    UINT16  vid_mode;             /* 0x1FA */
    UINT16  root_dev;             /* 0x1FC */
    UINT16  boot_flag;            /* 0x1FE -- must be 0xAA55 */
    UINT16  jump;                 /* 0x200 */
    UINT32  header;               /* 0x202 -- must be "HdrS" */
    UINT16  version;              /* 0x206 */
    UINT32  realmode_swtch;       /* 0x208 */
    UINT16  start_sys_seg;        /* 0x20C */
    UINT16  kernel_version;       /* 0x20E */
    UINT8   type_of_loader;       /* 0x210 */
    UINT8   loadflags;            /* 0x211 */
    UINT16  setup_move_size;      /* 0x212 */
    UINT32  code32_start;         /* 0x214 */
    UINT32  ramdisk_image;        /* 0x218 */
    UINT32  ramdisk_size;         /* 0x21C */
    UINT32  bootsect_kludge;      /* 0x220 */
    UINT16  heap_end_ptr;         /* 0x224 */
    UINT8   ext_loader_ver;       /* 0x226 */
    UINT8   ext_loader_type;      /* 0x227 */
    UINT32  cmd_line_ptr;         /* 0x228 */
    UINT32  initrd_addr_max;      /* 0x22C */
    UINT32  kernel_alignment;     /* 0x230 */
    UINT8   relocatable_kernel;   /* 0x234 */
    UINT8   min_alignment;        /* 0x235 */
    UINT16  xloadflags;           /* 0x236 */
    UINT32  cmdline_size;         /* 0x238 */
    UINT32  hardware_subarch;     /* 0x23C */
    UINT64  hardware_subarch_data;/* 0x240 */
    UINT32  payload_offset;       /* 0x248 */
    UINT32  payload_length;       /* 0x24C */
    UINT64  setup_data;           /* 0x250 */
    UINT64  pref_address;         /* 0x258 */
    UINT32  init_size;            /* 0x260 */
    UINT32  handover_offset;      /* 0x264 */
} __attribute__((packed));

struct efi_info {
    UINT32  efi_loader_signature; /* 0x1C0 -- "EL64" for 64-bit */
    UINT32  efi_systab;           /* 0x1C4 */
    UINT32  efi_memdesc_size;     /* 0x1C8 */
    UINT32  efi_memdesc_version;  /* 0x1CC */
    UINT32  efi_memmap;           /* 0x1D0 */
    UINT32  efi_memmap_size;      /* 0x1D4 */
    UINT32  efi_systab_hi;        /* 0x1D8 */
    UINT32  efi_memmap_hi;        /* 0x1DC */
} __attribute__((packed));

struct e820_entry {
    UINT64  addr;
    UINT64  size;
    UINT32  type;
} __attribute__((packed));

struct screen_info {
    UINT8   orig_x;               /* 0x00 */
    UINT8   orig_y;               /* 0x01 */
    UINT16  ext_mem_k;            /* 0x02 */
    UINT16  orig_video_page;      /* 0x04 */
    UINT8   orig_video_mode;      /* 0x06 */
    UINT8   orig_video_cols;      /* 0x07 */
    UINT8   flags;                /* 0x08 */
    UINT8   unused2;              /* 0x09 */
    UINT16  orig_video_ega_bx;    /* 0x0A */
    UINT16  unused3;              /* 0x0C */
    UINT8   orig_video_lines;     /* 0x0E */
    UINT8   orig_video_isVGA;     /* 0x0F */
    UINT16  orig_video_points;    /* 0x10 */
    UINT16  lfb_width;            /* 0x12 */
    UINT16  lfb_height;           /* 0x14 */
    UINT16  lfb_depth;            /* 0x16 */
    UINT32  lfb_base;             /* 0x18 */
    UINT32  lfb_size;             /* 0x1C */
    UINT16  cl_magic;             /* 0x20 */
    UINT16  cl_offset;            /* 0x22 */
    UINT16  lfb_linelength;       /* 0x24 */
    UINT8   red_size;             /* 0x26 */
    UINT8   red_pos;              /* 0x27 */
    UINT8   green_size;           /* 0x28 */
    UINT8   green_pos;            /* 0x29 */
    UINT8   blue_size;            /* 0x2A */
    UINT8   blue_pos;             /* 0x2B */
    UINT8   rsvd_size;            /* 0x2C */
    UINT8   rsvd_pos;             /* 0x2D */
    UINT16  vesapm_seg;           /* 0x2E */
    UINT16  vesapm_off;           /* 0x30 */
    UINT16  pages;                /* 0x32 */
    UINT16  vesa_attributes;      /* 0x34 */
    UINT32  capabilities;         /* 0x36 */
    UINT8   _reserved[6];         /* 0x3A */
} __attribute__((packed));

/*
 * The "zero page" -- struct boot_params.
 * Total size must be exactly 4096 bytes.
 */
struct boot_params {
    struct screen_info  screen_info;        /* 0x000 */
    UINT8   _pad1[0x040 - sizeof(struct screen_info)];
    UINT8   apm_bios_info[0x14];            /* 0x040 */
    UINT8   _pad2[4];                       /* 0x054 */
    UINT64  tboot_addr;                     /* 0x058 */
    UINT8   ist_info[0x10];                 /* 0x060 */
    UINT64  acpi_rsdp_addr;                 /* 0x070 */
    UINT8   _pad3[8];                       /* 0x078 */
    UINT8   hd0_info[16];                   /* 0x080 */
    UINT8   hd1_info[16];                   /* 0x090 */
    UINT8   sys_desc_table[16];             /* 0x0A0 */
    UINT8   olpc_ofw_header[16];            /* 0x0B0 */
    UINT32  ext_ramdisk_image;              /* 0x0C0 */
    UINT32  ext_ramdisk_size;               /* 0x0C4 */
    UINT32  ext_cmd_line_ptr;               /* 0x0C8 */
    UINT8   _pad4[0x13C - 0x0CC];
    UINT32  cc_blob_address;                /* 0x13C */
    UINT8   edid_info[128];                 /* 0x140 */
    struct efi_info efi_info;               /* 0x1C0 */
    UINT32  alt_mem_k;                      /* 0x1E0 */
    UINT32  scratch;                        /* 0x1E4 */
    UINT8   e820_entries;                   /* 0x1E8 */
    UINT8   eddbuf_entries;                 /* 0x1E9 */
    UINT8   edd_mbr_sig_buf_entries;        /* 0x1EA */
    UINT8   kbd_status;                     /* 0x1EB */
    UINT8   secure_boot;                    /* 0x1EC */
    UINT8   _pad5[2];                       /* 0x1ED */
    UINT8   sentinel;                       /* 0x1EF */
    UINT8   _pad6[1];                       /* 0x1F0 */
    struct setup_header hdr;                /* 0x1F1 */
    UINT8   _pad7[0x290 - 0x1F1 - sizeof(struct setup_header)];
    UINT8   edd_mbr_sig_buffer[64];         /* 0x290 */
    struct e820_entry e820_table[E820_MAX_ENTRIES]; /* 0x2D0 */
    UINT8   _pad8[48];                      /* 0xCD0 */
    UINT8   eddbuf[0xEEC - 0xD00];          /* 0xD00 */
    UINT8   _pad9[276];                     /* 0xEEC */
} __attribute__((packed));

_Static_assert(sizeof(struct boot_params) == 4096,
    "boot_params must be exactly 4096 bytes");

EFI_STATUS linux_load_and_boot(
    EFI_HANDLE image_handle,
    EFI_SYSTEM_TABLE *systab,
    CHAR16 *kernel_path,
    CHAR16 *initrd_path,
    CHAR8  *cmdline
);

#endif /* ION_BOOT_LINUX_H */
