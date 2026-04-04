# Ion Linux

A Linux distribution inspired by Arch Linux, emphasizing simplicity, modernity, and user-centricity.

## Project Structure

```
.
├── iso/                  # ISO build files (live environment)
│   ├── airootfs/         # Root filesystem overlay for the live ISO
│   ├── syslinux/         # BIOS bootloader config
│   ├── efiboot/          # UEFI boot config
│   └── grub/             # GRUB bootloader config
├── packages/             # Core package build definitions (IONBUILDs)
│   ├── base/             # Base metapackage
│   ├── ion-keyring/      # Pacman keyring for Ion repos
│   ├── ion-mirrorlist/   # Default mirror list
│   └── filesystem/       # Base filesystem layout
├── buildtools/           # Build system scripts and tooling
├── configs/              # Default system configuration templates
│   ├── pacman/           # Package manager config
│   ├── makepkg/          # Package build config
│   └── mkinitcpio/       # Initramfs generation config
├── installer/            # Ion installer
├── scripts/              # Development and CI/CD scripts
├── branding/             # Logos, wallpapers, and branding assets
└── repos/                # Repository structure definitions
    ├── core/             # Essential system packages
    ├── extra/            # Additional packages
    └── community/        # Community-maintained packages
```

## Building

### Prerequisites

- A working Linux system (Arch-based recommended)
- `base-devel` packages
- `squashfs-tools`, `libisoburn`, `mtools`, `dosfstools`

### Build the ISO

```bash
sudo ./scripts/build-iso.sh
```

### Build a package

```bash
cd packages/<package-name>
ionbuild
```

## Philosophy

Ion Linux follows the KISS (Keep It Simple, Stupid) principle:

- **Rolling release** — always up to date
- **User-centric** — the user decides what the system becomes
- **Minimal by default** — install only what you need
- **Source-transparent** — build scripts are readable and simple

## License

Ion Linux is free and open source software. See [LICENSE](LICENSE) for details.
