# Ion OS

A Linux distribution built from scratch.

## Project Structure

```text
ion-os/
├── Makefile                 # Top-level build (make run/clean/boot/initramfs/rootfs/disk/iso)
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
│   ├── mk-initramfs.sh      #   Create systemd-based initramfs from Arch packages
│   ├── mk-rootfs.sh         #   Create rootfs tree from Arch packages (systemd + coreutils + bash)
│   ├── mk-squashfs.sh       #   Compress rootfs into squashfs for ISO boot
│   ├── mkdisk.sh            #   Create 768MB GPT image (ESP + ext4 root)
│   ├── mkiso.sh             #   Create UEFI-bootable ISO image (squashfs + overlayfs live)
│   ├── run-qemu.sh          #   Launch QEMU with OVMF firmware (disk)
│   └── run-qemu-iso.sh      #   Launch QEMU with OVMF firmware (ISO CD-ROM)
│
└── build/                   # Build artifacts (gitignored)
    ├── initramfs/           #   Initramfs directory tree (systemd-based)
    ├── initramfs.img        #   Packed initramfs (~9MB compressed)
    ├── rootfs/              #   Root filesystem tree (~130MB, Arch packages)
    └── rootfs.squashfs      #   Compressed rootfs for ISO boot (~50-80MB)
```

## Boot Flow

1. **UEFI firmware** loads `\EFI\BOOT\BOOTX64.EFI` from the ESP
2. **Ion bootloader** loads kernel + registers initrd via LoadFile2 protocol
3. **Linux kernel** boots, discovers initrd through LINUX_EFI_INITRD_MEDIA_GUID
4. **systemd in initrd** runs as PID 1, mounts root at /sysroot, performs switch_root
5. **systemd** restarts as PID 1 on the real root, reaches multi-user.target
6. **login** presents login prompt on serial console

## Build and Run

```shell
make run       # Build disk image and boot in QEMU (requires sudo)
make run-iso   # Build ISO and boot in QEMU as CD-ROM (no sudo)
make clean     # Clean all build artifacts
```

Login: **root** / **root**

### Individual Build Targets

```shell
make boot       # Build UEFI bootloader
make initramfs  # Create systemd-based initramfs from Arch packages
make rootfs     # Create root filesystem from Arch packages (may need sudo)
make disk       # Create disk image (requires sudo for ext4 loop mount)
make run        # Boot disk image in QEMU with OVMF
make iso        # Create bootable ISO (squashfs + overlayfs live, no sudo)
make run-iso    # Boot ISO in QEMU as CD-ROM
```

## Requirements

- GCC, GNU ld, objcopy
- gnu-efi (headers + libraries)
- QEMU with OVMF firmware (edk2-ovmf)
- mtools (mformat, mmd, mcopy)
- parted, e2fsprogs (mkfs.ext4)
- sudo (for disk image creation)
- xorriso, squashfs-tools (for ISO image creation)
