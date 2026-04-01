#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_DIR}/build"
BUSYBOX_VER="1.36.1"
BUSYBOX_TAR="busybox-${BUSYBOX_VER}.tar.bz2"
BUSYBOX_URL="https://busybox.net/downloads/${BUSYBOX_TAR}"
BUSYBOX_DIR="${BUILD_DIR}/busybox-${BUSYBOX_VER}"
BUSYBOX_BIN="${BUILD_DIR}/busybox"

# Skip if already built
if [[ -f "$BUSYBOX_BIN" ]]; then
    echo "BusyBox already built: $BUSYBOX_BIN"
    exit 0
fi

mkdir -p "$BUILD_DIR"

# Download if needed
if [[ ! -f "${BUILD_DIR}/${BUSYBOX_TAR}" ]]; then
    echo "Downloading BusyBox ${BUSYBOX_VER}..."
    curl -L -o "${BUILD_DIR}/${BUSYBOX_TAR}" "$BUSYBOX_URL"
fi

# Extract
if [[ ! -d "$BUSYBOX_DIR" ]]; then
    echo "Extracting BusyBox..."
    tar -xjf "${BUILD_DIR}/${BUSYBOX_TAR}" -C "$BUILD_DIR"
fi

cd "$BUSYBOX_DIR"

# Configure with defaults, then enable static linking and disable broken features
echo "Configuring BusyBox..."
make defconfig KCONFIG_ALLCONFIG=/dev/null > /dev/null 2>&1 || make defconfig > /dev/null 2>&1

sed -i \
    -e 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' \
    -e 's/CONFIG_FEATURE_INETD_RPC=y/# CONFIG_FEATURE_INETD_RPC is not set/' \
    -e 's/CONFIG_FEATURE_HAVE_RPC=y/# CONFIG_FEATURE_HAVE_RPC is not set/' \
    -e 's/CONFIG_TC=y/# CONFIG_TC is not set/' \
    .config

# Regenerate config silently
yes "" 2>/dev/null | make oldconfig > /dev/null 2>&1 || true

# Build
echo "Building BusyBox (static)..."
make -j"$(nproc)" > "${BUILD_DIR}/busybox-build.log" 2>&1
tail -3 "${BUILD_DIR}/busybox-build.log"

# Copy binary
cp busybox "$BUSYBOX_BIN"
echo "BusyBox built: $BUSYBOX_BIN ($(du -h "$BUSYBOX_BIN" | cut -f1))"
