# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ion OS is a minimal Linux distribution built from scratch. It includes a custom UEFI bootloader (C with gnu-efi), initramfs, and a root filesystem assembled from BusyBox + systemd (via Arch packages). Target architecture is x86_64 only.

## Build Commands

```shell
make run          # Build everything and boot in QEMU (requires sudo)
make boot         # Compile UEFI bootloader only (C → ELF → PE32+ EFI)
make busybox      # Download and build BusyBox 1.36.1 static
make initramfs    # Create initramfs cpio archive (depends on busybox)
make rootfs       # Create root filesystem (depends on busybox, may need sudo)
make disk         # Create 768MB GPT disk image (requires sudo)
make clean        # Remove all build artifacts (may need sudo)
```

The kernel is external: `KERNEL ?= /home/mattmoore/source/torvalds/linux/arch/x86/boot/bzImage`. Override with `make disk KERNEL=/path/to/bzImage`.

There are no tests or linting configured.

## Architecture

**Boot flow:** UEFI firmware → Ion bootloader (`boot/bootx64.efi`) → Linux kernel (EFI stub) → initramfs `/init` → switch_root → systemd

**Bootloader (`boot/`):** C code using gnu-efi. Compiled with `-ffreestanding`, MS ABI calling convention, no libc. Key UEFI protocols: SimpleFileSystem (load files from ESP), LoadFile2 (register initrd via `LINUX_EFI_INITRD_MEDIA_GUID`), LoadedImageProtocol. All functions return `EFI_STATUS`, checked with `EFI_ERROR()`. The `boot_params` struct must be exactly 4096 bytes (enforced by `static_assert`).

**Build scripts (`scripts/`):** Bash scripts for each build phase. `mkdisk.sh` creates a GPT image with ESP (FAT32) + ext4 root partition. `mk-initramfs.sh` creates a cpio.gz with a shell `/init` that mounts root and calls `switch_root`. `mk-rootfs.sh` extracts Arch Linux pacman packages (zstd-compressed) for systemd/dbus. `run-qemu.sh` launches QEMU with OVMF firmware.

**Bootloader config (`boot/config.h`):** Kernel path, initrd path, default cmdline, and loader type ID. The kernel cmdline defaults to serial console output with `/dev/sda2` as root.

## Key Constraints

- **Sudo required** for `make disk`, `make rootfs`, `make run`, and `make clean` (loop mounts, ext4 formatting)
- **gnu-efi** headers and libs must be installed at `/usr/include/efi` and `/usr/lib`
- **OVMF firmware** path is hard-coded to `/usr/share/edk2/x64/` (Arch Linux layout)
- **Merged /usr layout**: `bin`, `sbin`, `lib`, `lib64` are symlinks into `usr/`
- Bootloader binary is PE32+ (UEFI), not a standard ELF executable
