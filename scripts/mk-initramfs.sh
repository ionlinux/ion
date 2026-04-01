#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_DIR}/build"
BUSYBOX_BIN="${BUILD_DIR}/busybox"
INITRAMFS_DIR="${BUILD_DIR}/initramfs"
INITRAMFS_IMG="${BUILD_DIR}/initramfs.img"

if [[ ! -f "$BUSYBOX_BIN" ]]; then
    echo "Error: BusyBox not found. Run build-busybox.sh first."
    exit 1
fi

echo "Creating initramfs..."

# Clean and create directory structure
rm -rf "$INITRAMFS_DIR"
mkdir -p "$INITRAMFS_DIR"/{bin,sbin,dev,proc,sys,mnt/root,etc,tmp,run}

# Install BusyBox
cp "$BUSYBOX_BIN" "$INITRAMFS_DIR/bin/busybox"
chmod 755 "$INITRAMFS_DIR/bin/busybox"

# Create essential symlinks
cd "$INITRAMFS_DIR/bin"
for cmd in sh cat echo ls mkdir sleep; do
    ln -sf busybox "$cmd"
done

cd "$INITRAMFS_DIR/sbin"
for cmd in mount umount switch_root mdev; do
    ln -sf ../bin/busybox "$cmd"
done

# Create the init script
cat > "$INITRAMFS_DIR/init" << 'INIT_EOF'
#!/bin/sh
# Ion OS initramfs init

echo "Ion OS initramfs starting..."

# Mount virtual filesystems
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true
mount -t proc     proc     /proc
mount -t sysfs    sysfs    /sys

# Parse kernel command line for root=
ROOT_DEV=""
ROOTFSTYPE="ext4"
for param in $(cat /proc/cmdline); do
    case "$param" in
        root=*)       ROOT_DEV="${param#root=}" ;;
        rootfstype=*) ROOTFSTYPE="${param#rootfstype=}" ;;
    esac
done

if [ -z "$ROOT_DEV" ]; then
    echo "ERROR: No root= parameter on kernel command line"
    echo "Dropping to emergency shell..."
    exec /bin/sh
fi

# Wait for root device to appear
echo "Waiting for root device: $ROOT_DEV"
TRIES=0
while [ ! -b "$ROOT_DEV" ]; do
    TRIES=$((TRIES + 1))
    if [ "$TRIES" -ge 50 ]; then
        echo "ERROR: Root device $ROOT_DEV not found after 5s"
        echo "Available block devices:"
        ls -la /dev/sd* /dev/vd* /dev/nvme* 2>/dev/null || echo "  (none)"
        echo "Dropping to emergency shell..."
        exec /bin/sh
    fi
    sleep 0.1
done

echo "Found root device: $ROOT_DEV"

# Mount the real root filesystem
echo "Mounting root filesystem ($ROOTFSTYPE)..."
mount -t "$ROOTFSTYPE" -o rw "$ROOT_DEV" /mnt/root

if [ ! -d /mnt/root/usr ]; then
    echo "ERROR: Root filesystem appears empty"
    echo "Dropping to emergency shell..."
    exec /bin/sh
fi

# Verify init exists on the real root
INIT_BIN=""
if [ -x /mnt/root/sbin/init ]; then
    INIT_BIN=/sbin/init
elif [ -x /mnt/root/usr/lib/systemd/systemd ]; then
    INIT_BIN=/usr/lib/systemd/systemd
elif [ -x /mnt/root/bin/sh ]; then
    INIT_BIN=/bin/sh
fi

if [ -z "$INIT_BIN" ]; then
    echo "ERROR: No init found on root filesystem"
    echo "Dropping to emergency shell..."
    exec /bin/sh
fi

echo "Switching to real root (init=$INIT_BIN)..."

# Clean up before switch
umount /proc
umount /sys

# Switch to the real root filesystem
exec switch_root /mnt/root "$INIT_BIN"
INIT_EOF
chmod 755 "$INITRAMFS_DIR/init"

# Pack as cpio archive
echo "Packing initramfs..."
cd "$INITRAMFS_DIR"
find . -print0 | cpio --null -o -H newc --quiet 2>/dev/null | gzip -9 > "$INITRAMFS_IMG"

echo "Initramfs created: $INITRAMFS_IMG ($(du -h "$INITRAMFS_IMG" | cut -f1))"
