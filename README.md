# Ion Boot Loader

## Project structure:

```text
ion-os/
├── Makefile              # Top-level build (make boot/disk/run/clean)
├── boot/
│   ├── Makefile          # gnu-efi build: GCC → ELF → objcopy → PE32+
│   ├── config.h          # Kernel path, command line, bootloader name
│   ├── main.c            # EFI entry point, orchestrates boot sequence
│   ├── console.c/h       # UEFI console output, banner, hex printing
│   ├── loader.c/h        # File loading from ESP via UEFI protocols
│   ├── linux.c/h         # Kernel loading via LoadImage/StartImage
│   └── memory.c/h        # Memory map helpers (for future use)
└── scripts/
    ├── mkdisk.sh         # Creates GPT+FAT32 disk image
    └── run-qemu.sh       # Launches QEMU with OVMF firmware
```

## Boot flow:

1. UEFI firmware loads `\EFI\BOOT\BOOTX64.EFI` from the ESP
2. Ion bootloader displays banner, loads `\vmlinuz` from the ESP
3. Registers kernel as UEFI image via `BS->LoadImage()`
4. Passes command line via `LoadOptions`
5. Executes kernel via `BS->StartImage()` -- kernel's EFI stub handles the rest

How to test:

```shell
# Build bootloader
make boot

# Create disk image
./scripts/mkdisk.sh --kernel /boot/arch/vmlinuz-linux

# Boot in QEMU
./scripts/run-qemu.sh
```

## Build and boot into VM:

Full boot chain:

  - UEFI bootloader -> kernel + initramfs (LoadFile2) -> initramfs mounts ext4 -> switch_root -> systemd -> BusyBox login  -> root shell

Commands:

  - make run -- build everything and boot (requires sudo for disk image)
  - make clean -- clean all build artifacts                                                                                
  - Login: root / root

## Next steps

- Build an initramfs
- Build a root filesystem
