#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_DIR}/build"
ROOTFS_DIR="${BUILD_DIR}/rootfs"
SQUASHFS_IMG="${BUILD_DIR}/rootfs.squashfs"

if [[ ! -d "$ROOTFS_DIR" ]]; then
    echo "Error: rootfs not found at $ROOTFS_DIR. Run 'make rootfs' first."
    exit 1
fi

echo "Creating squashfs image..."
mksquashfs "$ROOTFS_DIR" "$SQUASHFS_IMG" \
    -comp zstd \
    -Xcompression-level 19 \
    -noappend \
    -no-xattrs \
    -quiet

echo "Squashfs created: $SQUASHFS_IMG ($(du -h "$SQUASHFS_IMG" | cut -f1))"
