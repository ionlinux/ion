# Ion OS

A Linux distribution built from scratch.

## Project Structure

```text
ion-os/
├── Makefile                 # Top-level build (make run/clean/boot/busybox/initramfs/rootfs/disk)
├── .gitignore
│
├── boot/                    # UEFI bootloader (C + gnu-efi)
│   ├── Makefile             #   GCC → ELF → objcopy → PE32+ EFI application
│   ├── config.h             #   Kernel/initrd paths, command line
│   ├── main.c               #   EFI entry point (efi_main)
│   ├── console.c/h          #   UEFI text output, banner, hex printing
│   ├── loader.c/h           #   File loading from ESP (SimpleFileSystem protocol)
│   ├── linux.c/h            #   Kernel boot via LoadImage/StartImage + boot_params structs
│   ├── initrd.c/h           #   Initrd passing via LINUX_EFI_INITRD_MEDIA_GUID LoadFile2
│   └── memory.c/h           #   Memory map helpers (for future use)
│
├── scripts/
│   ├── build-busybox.sh     #   Download + build BusyBox 1.36.1 static
│   ├── mk-initramfs.sh      #   Create cpio.gz initramfs (BusyBox + /init script)
│   ├── mk-rootfs.sh         #   Create rootfs tree (BusyBox + systemd from Arch pkgs)
│   ├── mkdisk.sh            #   Create 768MB GPT image (ESP + ext4 root)
│   └── run-qemu.sh          #   Launch QEMU with OVMF firmware
│
└── build/                   # Build artifacts (gitignored)
    ├── busybox              #   Static BusyBox binary (2.3MB)
    ├── busybox-1.36.1/      #   BusyBox source tree
    ├── initramfs/           #   Initramfs directory tree
    ├── initramfs.img        #   Packed initramfs (1.2MB)
    └── rootfs/              #   Root filesystem tree (~98MB, BusyBox + systemd)
```

## Boot Flow

1. **UEFI firmware** loads `\EFI\BOOT\BOOTX64.EFI` from the ESP
2. **Ion bootloader** loads kernel + registers initrd via LoadFile2 protocol
3. **Linux kernel** boots, discovers initrd through LINUX_EFI_INITRD_MEDIA_GUID
4. **Initramfs /init** mounts devtmpfs/proc/sysfs, mounts ext4 root, switch_roots
5. **systemd** starts as PID 1, reaches multi-user.target
6. **BusyBox login** presents login prompt on serial console

## Build and Run

```shell
make run       # Build everything and boot in QEMU (requires sudo for disk image)
make clean     # Clean all build artifacts
```

Login: **root** / **root**

### Individual Build Targets

```shell
make boot       # Build UEFI bootloader
make busybox    # Download and build BusyBox static binary
make initramfs  # Create initramfs cpio archive
make rootfs     # Create root filesystem (extracts Arch packages, may need sudo)
make disk       # Create disk image (requires sudo for ext4 loop mount)
make run        # Boot in QEMU with OVMF
```

## Requirements

- GCC, GNU ld, objcopy
- gnu-efi (headers + libraries)
- QEMU with OVMF firmware (edk2-ovmf)
- mtools (mformat, mmd, mcopy)
- parted, e2fsprogs (mkfs.ext4)
- sudo (for disk image creation)
