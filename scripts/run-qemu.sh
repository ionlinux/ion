#!/usr/bin/env bash
#
# run-qemu.sh — Boot the Ion Linux ISO in QEMU (UEFI)
#
# Usage:
#   ./scripts/run-qemu.sh          # GUI mode (SPICE, copy/paste support)
#   ./scripts/run-qemu.sh serial   # Serial console mode (exit with Ctrl-a x)
#
set -euo pipefail

MODE="${1:-gui}"

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

COMMON_ARGS=(
  -machine q35,accel=kvm
  -cpu host
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE"
  -drive if=pflash,format=raw,file="$OVMF_VARS_COPY"
  -device ide-cd,drive=cd0,bus=ide.0
  -drive id=cd0,if=none,format=raw,media=cdrom,readonly=on,file="$ISO"
  -drive file="$DISK",format=qcow2,if=virtio
  -m 4G
  -nic user,model=virtio-net-pci
)

if [[ "$MODE" == "serial" ]]; then
  EXTRACT_DIR="/tmp/ion-qemu-boot"
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
    "${COMMON_ARGS[@]}" \
    -kernel "$KERNEL" \
    -initrd "$INITRD" \
    -append "archisobasedir=ion archisolabel=ION console=ttyS0,115200" \
    -nographic
else
  echo "==> Booting ${ISO} (UEFI, GUI with SPICE)"
  echo "    Connect with: spicy -h localhost -p 5930"

  exec qemu-system-x86_64 \
    "${COMMON_ARGS[@]}" \
    -vga qxl \
    -device virtio-serial-pci \
    -chardev spicevmc,id=vdagent,debug=0,name=vdagent \
    -device virtserialport,chardev=vdagent,name=com.redhat.spice.0 \
    -spice port=5930,disable-ticketing=on
fi
