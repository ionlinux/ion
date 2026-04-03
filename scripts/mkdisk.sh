#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_DIR}/build"
IMG="${PROJECT_DIR}/ion-os.img"
EFI_FILE="${PROJECT_DIR}/boot/bootx64.efi"
KERNEL_FILE=""
INITRD_FILE=""
ROOTFS_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --kernel) KERNEL_FILE="$2"; shift 2 ;;
        --initrd) INITRD_FILE="$2"; shift 2 ;;
        --rootfs) ROOTFS_DIR="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ ! -f "$EFI_FILE" ]]; then
    echo "Error: $EFI_FILE not found. Run 'make boot' first."
    exit 1
fi

# Determine image size based on whether we have a rootfs
if [[ -n "$ROOTFS_DIR" && -d "$ROOTFS_DIR" ]]; then
    IMG_SIZE_MB=768
    ESP_END_MIB=65
    ROOT_END_MIB=767
    HAS_ROOTFS=1
else
    IMG_SIZE_MB=64
    ESP_END_MIB=63
    HAS_ROOTFS=0
fi

echo "Creating disk image: $IMG (${IMG_SIZE_MB}MB)"

# Create disk image
dd if=/dev/zero of="$IMG" bs=1M count="$IMG_SIZE_MB" status=none

# Create GPT partition table
if [[ "$HAS_ROOTFS" == "1" ]]; then
    parted -s "$IMG" \
        mklabel gpt \
        mkpart ESP fat32 1MiB "${ESP_END_MIB}MiB" \
        set 1 esp on \
        mkpart root ext4 "${ESP_END_MIB}MiB" "${ROOT_END_MIB}MiB"
else
    parted -s "$IMG" \
        mklabel gpt \
        mkpart ESP fat32 1MiB "${ESP_END_MIB}MiB" \
        set 1 esp on
fi

# ============================================================
# Create and populate ESP (FAT32)
# ============================================================
ESP_SIZE_MB=$((ESP_END_MIB - 1))
FAT_IMG=$(mktemp /tmp/ion-esp-XXXXXX.img)
CLEANUP_FILES="$FAT_IMG"
trap "rm -f $CLEANUP_FILES" EXIT

dd if=/dev/zero of="$FAT_IMG" bs=1M count="$ESP_SIZE_MB" status=none
mkfs.fat -F 32 -n "ION-ESP" "$FAT_IMG" >/dev/null

export MTOOLS_SKIP_CHECK=1
mmd -i "$FAT_IMG" ::/EFI
mmd -i "$FAT_IMG" ::/EFI/BOOT
mcopy -i "$FAT_IMG" "$EFI_FILE" ::/EFI/BOOT/BOOTX64.EFI

if [[ -n "$KERNEL_FILE" && -f "$KERNEL_FILE" ]]; then
    echo "  Including kernel: $(basename "$KERNEL_FILE")"
    mcopy -i "$FAT_IMG" "$KERNEL_FILE" ::/vmlinuz
fi

if [[ -n "$INITRD_FILE" && -f "$INITRD_FILE" ]]; then
    echo "  Including initrd: $(basename "$INITRD_FILE") ($(du -h "$INITRD_FILE" | cut -f1))"
    mcopy -i "$FAT_IMG" "$INITRD_FILE" ::/initramfs.img
fi

# Write ESP into disk image at partition 1 offset (1 MiB)
dd if="$FAT_IMG" of="$IMG" bs=1M seek=1 conv=notrunc status=none

# ============================================================
# Create and populate ext4 root partition (if rootfs provided)
# ============================================================
if [[ "$HAS_ROOTFS" == "1" ]]; then
    ROOT_SIZE_MB=$((ROOT_END_MIB - ESP_END_MIB))
    ROOT_IMG=$(mktemp /tmp/ion-root-XXXXXX.img)
    CLEANUP_FILES="$CLEANUP_FILES $ROOT_IMG"

    echo "  Creating ext4 root partition (${ROOT_SIZE_MB}MB)..."
    dd if=/dev/zero of="$ROOT_IMG" bs=1M count="$ROOT_SIZE_MB" status=none
    mkfs.ext4 -q -L "ION-ROOT" "$ROOT_IMG"

    echo "  Populating root filesystem (requires sudo for loop mount)..."
    MOUNT_DIR=$(mktemp -d /tmp/ion-mount-XXXXXX)

    sudo mount -o loop "$ROOT_IMG" "$MOUNT_DIR"
    # Copy files, forcing root ownership for everything
    sudo rsync -a --chown=0:0 "$ROOTFS_DIR/" "$MOUNT_DIR/"
    # Shadow file needs restricted permissions
    sudo chmod 640 "$MOUNT_DIR/etc/shadow"
    # unix_chkpwd must be setuid root for PAM password authentication
    sudo chmod 6755 "$MOUNT_DIR/usr/bin/unix_chkpwd"
    # Ensure all binaries and libs are executable
    sudo chmod -R a+rX "$MOUNT_DIR/usr/bin" "$MOUNT_DIR/usr/sbin" "$MOUNT_DIR/usr/lib"
    # Run ldconfig inside the rootfs to generate ld.so.cache
    if [[ -x "$MOUNT_DIR/usr/sbin/ldconfig" ]]; then
        sudo chroot "$MOUNT_DIR" /usr/sbin/ldconfig 2>/dev/null || true
    fi
    sudo umount "$MOUNT_DIR"
    rmdir "$MOUNT_DIR"

    # Write root partition into disk image
    dd if="$ROOT_IMG" of="$IMG" bs=1M seek="$ESP_END_MIB" conv=notrunc status=none
fi

# Ensure the disk image is owned by the calling user, not root
if [[ -n "${SUDO_USER:-}" ]]; then
    chown "${SUDO_UID:-$(id -u "$SUDO_USER")}:${SUDO_GID:-$(id -g "$SUDO_USER")}" "$IMG"
fi

echo "Disk image created: $IMG"
echo "  Partition 1 (ESP):  /EFI/BOOT/BOOTX64.EFI"
[[ -n "$KERNEL_FILE" ]] && echo "                      /vmlinuz"
[[ -n "$INITRD_FILE" ]] && echo "                      /initramfs.img"
[[ "$HAS_ROOTFS" == "1" ]] && echo "  Partition 2 (ext4): root filesystem (systemd + Arch packages)"
echo "Done."
