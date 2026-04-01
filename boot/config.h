#ifndef ION_BOOT_CONFIG_H
#define ION_BOOT_CONFIG_H

#define KERNEL_PATH      L"\\vmlinuz"
#define INITRD_PATH      L"\\initramfs.img"
#define CMDLINE_DEFAULT  "console=ttyS0 earlyprintk=serial root=/dev/sda2 rootfstype=ext4 rootwait"
#define BOOTLOADER_NAME  L"Ion Boot Loader v0.1"
#define LOADER_TYPE_ID   0xFF

#endif /* ION_BOOT_CONFIG_H */
