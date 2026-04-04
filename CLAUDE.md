# Ion Linux

Arch Linux-inspired rolling release distribution. KISS philosophy: minimal, user-centric, source-transparent.

## Project layout

- `iso/` — Archiso profile for building the live/install ISO (profiledef.sh, packages.x86_64, airootfs overlay, bootloader configs)
- `packages/` — IONBUILD files (PKGBUILD-compatible) for Ion-specific packages (base, filesystem, ion-keyring, ion-mirrorlist)
- `configs/` — Default system configs (pacman.conf, makepkg.conf, mkinitcpio.conf) applied to installed systems
- `installer/` — `ion-install.sh` guided TUI installer
- `scripts/` — Build/dev scripts (build-iso.sh, build-package.sh, run-qemu.sh)
- `buildtools/` — `ionbuild` wrapper (symlinks IONBUILD→PKGBUILD, delegates to makepkg)
- `repos/` — Repository category stubs (core, extra, community) — not yet populated
- `branding/` — Logos and assets (empty)
- `build/` and `out/` — Generated artifacts (gitignored)

## Build commands

```bash
# Build the ISO (requires root, archiso installed)
sudo ./scripts/build-iso.sh

# Build a single package
cd packages/<name> && ionbuild
# or: ./scripts/build-package.sh packages/<name>

# Test ISO in QEMU (boots latest ISO from out/)
./scripts/run-qemu.sh
```

## Key conventions

- **IONBUILD, not PKGBUILD**: Package definitions use IONBUILD filename. The build system symlinks to PKGBUILD for makepkg compatibility. PKGBUILD is gitignored.
- **Arch tooling**: Uses archiso (mkarchiso), makepkg, pacstrap, pacman. No custom package manager.
- **Two config tiers**: `configs/` = installed system defaults; `iso/` = live environment overrides.
- **ISO bootstraps from Arch repos**: `iso/pacman.conf` points to Arch Linux repos since Ion repos are not yet live. The Ion-specific packages (ion-keyring, ion-mirrorlist) are commented out in `iso/packages.x86_64`.
- **Dual boot**: ISO supports both BIOS (syslinux) and UEFI (GRUB).
- **Archiso label**: `archisobasedir=ion archisolabel=ION` — these must stay consistent across grub.cfg, syslinux.cfg, profiledef.sh, and run-qemu.sh.
- **No BusyBox**: Rootfs uses full Arch packages (coreutils, bash, shadow, etc). Initramfs is systemd-based. PAM login requires the full dependency chain (pam_unix → libnsl, krb5, libldap, libsasl, etc).
- **Security-hardened builds**: makepkg.conf uses FORTIFY_SOURCE=3, stack clash protection, CFI, full RELRO, frame pointers.

## Shell script style

- All scripts use `#!/usr/bin/env bash` with `set -euo pipefail`
- Functions are lowercase with underscores
- User-facing output uses ANSI color codes via `echo -e`
- Scripts are short and focused (under ~130 lines each)
