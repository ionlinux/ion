#!/usr/bin/env bash
#
# run-qemu.sh — Boot the Ion Linux ISO in QEMU with serial console
#
# Exit with Ctrl-a x
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ISO="$(ls -t "${PROJECT_ROOT}"/out/ionlinux-*.iso 2>/dev/null | head -1)"
EXTRACT_DIR="/tmp/ion-qemu-boot"

if [[ -z "$ISO" ]]; then
  echo "error: no ISO found in out/. Run ./scripts/build-iso.sh first." >&2
  exit 1
fi

# Extract kernel and initrd from the ISO
mkdir -p "$EXTRACT_DIR"
KERNEL="${EXTRACT_DIR}/vmlinuz-linux"
INITRD="${EXTRACT_DIR}/initramfs-linux.img"

if [[ ! -f "$KERNEL" || ! -f "$INITRD" ]]; then
  echo "==> Extracting kernel and initrd from ${ISO}..."
  bsdtar -xf "$ISO" -C "$EXTRACT_DIR" \
    ion/boot/x86_64/vmlinuz-linux \
    ion/boot/x86_64/initramfs-linux.img
  mv "$EXTRACT_DIR"/ion/boot/x86_64/vmlinuz-linux "$KERNEL"
  mv "$EXTRACT_DIR"/ion/boot/x86_64/initramfs-linux.img "$INITRD"
  rm -rf "$EXTRACT_DIR"/ion
fi

echo "==> Booting ${ISO}"
echo "    Exit with Ctrl-a x"

exec qemu-system-x86_64 \
  -cdrom "$ISO" \
  -m 2G \
  -enable-kvm \
  -nographic \
  -nic user,model=virtio-net-pci \
  -append "console=ttyS0 archisobasedir=ion archisolabel=ION" \
  -kernel "$KERNEL" \
  -initrd "$INITRD"
