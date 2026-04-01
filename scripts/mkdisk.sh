#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMG="${PROJECT_DIR}/ion-os.img"
EFI_FILE="${PROJECT_DIR}/boot/bootx64.efi"
KERNEL_FILE=""
INITRD_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --kernel) KERNEL_FILE="$2"; shift 2 ;;
        --initrd) INITRD_FILE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ ! -f "$EFI_FILE" ]]; then
    echo "Error: $EFI_FILE not found. Run 'make boot' first."
    exit 1
fi

echo "Creating disk image: $IMG"

# Create a 64MB disk image
dd if=/dev/zero of="$IMG" bs=1M count=64 status=none

# Create GPT partition table with an EFI System Partition
parted -s "$IMG" \
    mklabel gpt \
    mkpart ESP fat32 1MiB 63MiB \
    set 1 esp on

# Create a temporary FAT32 image for the partition
PART_OFFSET=$((1 * 1024 * 1024))
FAT_IMG=$(mktemp /tmp/ion-esp-XXXXXX.img)
trap "rm -f $FAT_IMG" EXIT

dd if=/dev/zero of="$FAT_IMG" bs=1M count=62 status=none
mkfs.fat -F 32 -n "ION-ESP" "$FAT_IMG" >/dev/null

# Create directory structure and copy files using mtools
export MTOOLS_SKIP_CHECK=1
mmd -i "$FAT_IMG" ::/EFI
mmd -i "$FAT_IMG" ::/EFI/BOOT
mcopy -i "$FAT_IMG" "$EFI_FILE" ::/EFI/BOOT/BOOTX64.EFI

# Copy kernel if provided
if [[ -n "$KERNEL_FILE" && -f "$KERNEL_FILE" ]]; then
    echo "Including kernel: $KERNEL_FILE"
    mcopy -i "$FAT_IMG" "$KERNEL_FILE" ::/vmlinuz
fi

# Copy initrd if provided
if [[ -n "$INITRD_FILE" && -f "$INITRD_FILE" ]]; then
    echo "Including initrd: $INITRD_FILE"
    mcopy -i "$FAT_IMG" "$INITRD_FILE" ::/initramfs.img
fi

# Write FAT image into the partition area of the disk image
dd if="$FAT_IMG" of="$IMG" bs=1 seek=$PART_OFFSET conv=notrunc status=none

echo "Disk image created: $IMG"
echo "  EFI bootloader: /EFI/BOOT/BOOTX64.EFI"
[[ -n "$KERNEL_FILE" ]] && echo "  Kernel:          /vmlinuz"
[[ -n "$INITRD_FILE" ]] && echo "  Initrd:          /initramfs.img"
echo "Done."
