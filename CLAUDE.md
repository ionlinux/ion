# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ion OS is a minimal Linux distribution built from scratch. It includes a custom UEFI bootloader (C with gnu-efi), a systemd-based initramfs, and a root filesystem assembled from Arch Linux packages (systemd, coreutils, bash, etc.). Target architecture is x86_64 only.

## Build Commands

```shell
make run          # Build everything and boot in QEMU (requires sudo)
make boot         # Compile UEFI bootloader only (C → ELF → PE32+ EFI)
make initramfs    # Create systemd-based initramfs (extracts Arch packages)
make rootfs       # Create root filesystem (extracts Arch packages, may need sudo)
make disk         # Create 768MB GPT disk image (requires sudo)
make iso          # Create bootable ISO image (no sudo needed)
make run-iso      # Build ISO and boot in QEMU as CD-ROM
make clean        # Remove all build artifacts (may need sudo)
```

The kernel is external: `KERNEL ?= /home/mattmoore/source/torvalds/linux/arch/x86/boot/bzImage`. Override with `make disk KERNEL=/path/to/bzImage`.

There are no tests or linting configured.

## Architecture

**Boot flow (disk):** UEFI firmware → Ion bootloader (`boot/bootx64.efi`) → Linux kernel (EFI stub) → systemd in initrd (initrd.target → mount root at /sysroot → switch_root) → systemd on real root

**Boot flow (ISO):** Same as disk, but uses `boot/bootx64-iso.efi` (cmdline has `ion.live` instead of `root=/dev/sda2`). The initramfs `ion-live-mount.service` finds the ISO by label, mounts the squashfs rootfs, and layers a tmpfs overlay for writes.

**Bootloader (`boot/`):** C code using gnu-efi. Compiled with `-ffreestanding`, MS ABI calling convention, no libc. Key UEFI protocols: SimpleFileSystem (load files from ESP), LoadFile2 (register initrd via `LINUX_EFI_INITRD_MEDIA_GUID`), LoadedImageProtocol. All functions return `EFI_STATUS`, checked with `EFI_ERROR()`. The `boot_params` struct must be exactly 4096 bytes (enforced by `static_assert`).

**Build scripts (`scripts/`):** Bash scripts for each build phase. `mkdisk.sh` creates a GPT image with ESP (FAT32) + ext4 root partition. `mkiso.sh` creates a UEFI-bootable ISO with squashfs rootfs. `mk-initramfs.sh` creates a systemd-based initramfs by extracting Arch packages, copying systemd binaries/units/libraries, and packing as cpio.gz. `mk-rootfs.sh` extracts Arch Linux pacman packages (zstd-compressed) for systemd, coreutils, bash, and other userspace tools. `mk-squashfs.sh` compresses the rootfs into a squashfs image for ISO boot. `run-qemu.sh` and `run-qemu-iso.sh` launch QEMU with OVMF firmware.

**Bootloader config (`boot/config.h`):** Kernel path, initrd path, default cmdline, and loader type ID. The kernel cmdline defaults to serial console output with `/dev/sda2` as root.

## Key Constraints

- **Sudo required** for `make disk`, `make rootfs`, `make run`, and `make clean` (loop mounts, ext4 formatting)
- **gnu-efi** headers and libs must be installed at `/usr/include/efi` and `/usr/lib`
- **OVMF firmware** path is hard-coded to `/usr/share/edk2/x64/` (Arch Linux layout)
- **Merged /usr layout**: `bin`, `sbin`, `lib`, `lib64` are symlinks into `usr/`
- Bootloader binary is PE32+ (UEFI), not a standard ELF executable
