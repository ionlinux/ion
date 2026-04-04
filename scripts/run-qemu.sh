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

if [[ ! -f "$OVMF_CODE" ]]; then
  echo "error: OVMF not found. Install edk2-ovmf." >&2
  exit 1
fi

# Each VM gets its own writable copy of VARS
cp -f "$OVMF_VARS" "$OVMF_VARS_COPY"

echo "==> Booting ${ISO} (UEFI)"
echo "    Exit with Ctrl-a x"

exec qemu-system-x86_64 \
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
  -drive if=pflash,format=raw,file="$OVMF_VARS_COPY" \
  -cdrom "$ISO" \
  -m 2G \
  -enable-kvm \
  -nographic \
  -nic user,model=virtio-net-pci
