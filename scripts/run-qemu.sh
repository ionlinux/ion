#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMG="${PROJECT_DIR}/ion-os.img"

# OVMF firmware paths (Arch Linux edk2-ovmf package)
OVMF_CODE="/usr/share/edk2/x64/OVMF_CODE.4m.fd"
OVMF_VARS="/usr/share/edk2/x64/OVMF_VARS.4m.fd"

# Create a writable copy of VARS
VARS_COPY=$(mktemp /tmp/ion-ovmf-vars-XXXXXX.fd)
trap "rm -f $VARS_COPY" EXIT
cp "$OVMF_VARS" "$VARS_COPY"

if [[ ! -f "$IMG" ]]; then
    echo "Error: $IMG not found. Run 'make disk' first."
    exit 1
fi

echo "Starting QEMU with OVMF..."

qemu-system-x86_64 \
    -machine q35 \
    -cpu qemu64 \
    -m 512M \
    -drive if=pflash,format=raw,unit=0,file="$OVMF_CODE",readonly=on \
    -drive if=pflash,format=raw,unit=1,file="$VARS_COPY" \
    -drive format=raw,file="$IMG" \
    -serial stdio \
    -display none \
    -no-reboot \
    "$@"
