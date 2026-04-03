#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ISO="${PROJECT_DIR}/ion-os.iso"
EFI_FILE=""
KERNEL_FILE=""
INITRD_FILE=""
SQUASHFS_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --efi)      EFI_FILE="$2"; shift 2 ;;
        --kernel)   KERNEL_FILE="$2"; shift 2 ;;
        --initrd)   INITRD_FILE="$2"; shift 2 ;;
        --squashfs) SQUASHFS_FILE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

for f in "$EFI_FILE" "$KERNEL_FILE" "$INITRD_FILE" "$SQUASHFS_FILE"; do
    if [[ ! -f "$f" ]]; then
        echo "Error: $f not found."
        exit 1
    fi
done

echo "Creating ISO image: $ISO"

# ============================================================
# Create FAT32 EFI boot image (bootloader + kernel + initramfs)
# ============================================================
KERNEL_SIZE=$(stat -c%s "$KERNEL_FILE")
INITRD_SIZE=$(stat -c%s "$INITRD_FILE")
EFI_SIZE=$(stat -c%s "$EFI_FILE")
# FAT32 minimum is ~33MB; size to fit contents + 2MB overhead
FAT_SIZE_MB=$(( (KERNEL_SIZE + INITRD_SIZE + EFI_SIZE + 2*1024*1024) / (1024*1024) ))
# Ensure minimum FAT32 size
[[ "$FAT_SIZE_MB" -lt 34 ]] && FAT_SIZE_MB=34

FAT_IMG=$(mktemp /tmp/ion-efi-XXXXXX.img)
STAGING=$(mktemp -d /tmp/ion-iso-XXXXXX)
trap "rm -f $FAT_IMG; rm -rf $STAGING" EXIT

echo "  Creating EFI boot image (${FAT_SIZE_MB}MB)..."
dd if=/dev/zero of="$FAT_IMG" bs=1M count="$FAT_SIZE_MB" status=none
mkfs.fat -F 32 -n "ION-EFI" "$FAT_IMG" >/dev/null

export MTOOLS_SKIP_CHECK=1
mmd -i "$FAT_IMG" ::/EFI
mmd -i "$FAT_IMG" ::/EFI/BOOT
mcopy -i "$FAT_IMG" "$EFI_FILE" ::/EFI/BOOT/BOOTX64.EFI
mcopy -i "$FAT_IMG" "$KERNEL_FILE" ::/vmlinuz
mcopy -i "$FAT_IMG" "$INITRD_FILE" ::/initramfs.img

echo "  EFI boot image: bootloader + kernel + initramfs"

# ============================================================
# Stage ISO contents
# ============================================================
mkdir -p "$STAGING"
cp "$SQUASHFS_FILE" "$STAGING/rootfs.squashfs"

echo "  Squashfs: $(du -h "$SQUASHFS_FILE" | cut -f1)"

# ============================================================
# Create ISO with xorriso
# ============================================================
echo "  Running xorriso..."
xorriso -as mkisofs \
    -o "$ISO" \
    -V "ION-ISO" \
    -iso-level 3 \
    -J -joliet-long \
    -append_partition 2 0xef "$FAT_IMG" \
    -e --interval:appended_partition_2:all:: \
    -no-emul-boot \
    -partition_offset 16 \
    -isohybrid-gpt-basdat \
    "$STAGING" 2>/dev/null

echo "ISO created: $ISO ($(du -h "$ISO" | cut -f1))"
echo "  Boot: UEFI via El Torito EFI boot image"
echo "  Root: squashfs + overlayfs (live mode)"
echo "  USB:  dd if=$ISO of=/dev/sdX bs=4M"
