#!/usr/bin/env bash
#
# run-qemu.sh — Boot the Ion Linux ISO in QEMU (UEFI) with serial console
#
# Exit with Ctrl-a x
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ISO="$(ls -t "${PROJECT_ROOT}"/out/ionlinux-*.iso 2>/dev/null | head -1)"

if [[ -z "$ISO" ]]; then
  echo "error: no ISO found in out/. Run ./scripts/build-iso.sh first." >&2
  exit 1
fi

OVMF_CODE="/usr/share/edk2/x64/OVMF_CODE.4m.fd"
OVMF_VARS="/usr/share/edk2/x64/OVMF_VARS.4m.fd"
OVMF_VARS_COPY="/tmp/ion-qemu-efivars.fd"
DISK="/tmp/ion-qemu-disk.qcow2"
EXTRACT_DIR="/tmp/ion-qemu-boot"

if [[ ! -f "$OVMF_CODE" ]]; then
  echo "error: OVMF not found. Install edk2-ovmf." >&2
  exit 1
fi

# Each VM gets its own writable copy of VARS
cp -f "$OVMF_VARS" "$OVMF_VARS_COPY"

# Create a virtual disk for installation testing if it doesn't exist
if [[ ! -f "$DISK" ]]; then
  echo "==> Creating 20G virtual disk at ${DISK}"
  qemu-img create -f qcow2 "$DISK" 20G
fi

# Extract kernel and initrd from the ISO for direct boot with serial console
KERNEL="${EXTRACT_DIR}/vmlinuz-linux"
INITRD="${EXTRACT_DIR}/initramfs-linux.img"

if [[ ! -f "$KERNEL" || ! -f "$INITRD" || "$ISO" -nt "$KERNEL" ]]; then
  echo "==> Extracting kernel and initrd from ${ISO}..."
  mkdir -p "$EXTRACT_DIR"
  bsdtar -xf "$ISO" -C "$EXTRACT_DIR" \
    ion/boot/x86_64/vmlinuz-linux \
    ion/boot/x86_64/initramfs-linux.img
  mv "$EXTRACT_DIR"/ion/boot/x86_64/vmlinuz-linux "$KERNEL"
  mv "$EXTRACT_DIR"/ion/boot/x86_64/initramfs-linux.img "$INITRD"
  rm -rf "$EXTRACT_DIR"/ion
fi

echo "==> Booting ${ISO} (UEFI, serial console)"
echo "    Exit with Ctrl-a x"

exec qemu-system-x86_64 \
  -machine q35,accel=kvm \
  -cpu host \
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
  -drive if=pflash,format=raw,file="$OVMF_VARS_COPY" \
  -device ide-cd,drive=cd0,bus=ide.0 \
  -drive id=cd0,if=none,format=raw,media=cdrom,readonly=on,file="$ISO" \
  -drive file="$DISK",format=qcow2,if=virtio \
  -kernel "$KERNEL" \
  -initrd "$INITRD" \
  -append "archisobasedir=ion archisolabel=ION console=ttyS0,115200" \
  -m 2G \
  -nographic \
  -nic user,model=virtio-net-pci
