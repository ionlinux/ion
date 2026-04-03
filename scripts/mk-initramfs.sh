#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_DIR}/build"
STAGING="${BUILD_DIR}/initramfs-staging"
INITRAMFS_DIR="${BUILD_DIR}/initramfs"
INITRAMFS_IMG="${BUILD_DIR}/initramfs.img"
PKG_CACHE="/var/cache/pacman/pkg"

echo "Creating systemd-based initramfs..."

# ============================================================
# Phase 1: Extract Arch packages into staging area
# ============================================================
PACKAGES=(
    systemd
    systemd-libs
    glibc
    gcc-libs
    util-linux
    util-linux-libs
    libcap
    libgcrypt
    libgpg-error
    openssl
    libxcrypt
    bash
    readline
    ncurses
    acl
    attr
    kmod
    pcre2
    lz4
    xz
    zstd
    libseccomp
    audit
    libcap-ng
    pam
    zlib
)

echo "Downloading packages for initramfs..."
MISSING_PKGS=()
for pkg in "${PACKAGES[@]}"; do
    if ! ls "${PKG_CACHE}/${pkg}-"[0-9]*.pkg.tar.zst >/dev/null 2>&1; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
    echo "Downloading missing packages: ${MISSING_PKGS[*]}"
    sudo pacman -Sw --noconfirm "${MISSING_PKGS[@]}" 2>&1 | tail -3
else
    echo "All packages already cached"
fi

echo "Extracting packages into staging..."
rm -rf "$STAGING"
mkdir -p "$STAGING"

for pkg in "${PACKAGES[@]}"; do
    PKG_FILE=$(ls "${PKG_CACHE}/${pkg}-"[0-9]*.pkg.tar.zst 2>/dev/null | sort -V | tail -1 || true)
    if [[ -z "$PKG_FILE" || ! -f "$PKG_FILE" ]]; then
        echo "  WARNING: Package $pkg not found in cache, skipping"
        continue
    fi
    echo "  Extracting: $(basename "$PKG_FILE")"
    bsdtar -xf "$PKG_FILE" -C "$STAGING" 2>/dev/null || true
done

# ============================================================
# Phase 2: Create initramfs directory structure
# ============================================================
echo "Creating initramfs directory structure..."
rm -rf "$INITRAMFS_DIR"
mkdir -p "$INITRAMFS_DIR"/{usr/{bin,sbin,lib/systemd/system-generators},etc,dev,proc,sys,sysroot,run,tmp}

# Merged /usr symlinks
cd "$INITRAMFS_DIR"
ln -sf usr/bin  bin
ln -sf usr/sbin sbin
ln -sf usr/lib  lib
ln -sf usr/lib  lib64

# ============================================================
# Phase 3: Copy binaries from staging
# ============================================================
echo "Copying binaries..."

# systemd binaries
SYSTEMD_BINARIES=(
    usr/lib/systemd/systemd
    usr/lib/systemd/systemd-executor
    usr/lib/systemd/systemd-shutdown
    usr/lib/systemd/systemd-sulogin-shell
    usr/lib/systemd/systemd-journald
    usr/lib/systemd/systemd-remount-fs
    usr/lib/systemd/systemd-modules-load
    usr/lib/systemd/systemd-sysroot-fstab-check
    usr/lib/systemd/system-generators/systemd-fstab-generator
)

# User-facing binaries
USER_BINARIES=(
    usr/bin/systemctl
    usr/bin/mount
    usr/bin/umount
    usr/bin/sulogin
    usr/bin/bash
    usr/bin/systemd-tmpfiles
    usr/bin/udevadm
    usr/bin/kmod
)

for bin in "${SYSTEMD_BINARIES[@]}" "${USER_BINARIES[@]}"; do
    if [[ -e "$STAGING/$bin" ]]; then
        mkdir -p "$INITRAMFS_DIR/$(dirname "$bin")"
        cp -a "$STAGING/$bin" "$INITRAMFS_DIR/$bin"
        echo "  $bin"
    else
        echo "  WARNING: $bin not found in staging"
    fi
done

# Create essential symlinks
ln -sf usr/lib/systemd/systemd "$INITRAMFS_DIR/init"
ln -sf bash "$INITRAMFS_DIR/usr/bin/sh"

# systemd-udevd is a symlink to udevadm
if [[ ! -e "$INITRAMFS_DIR/usr/lib/systemd/systemd-udevd" ]]; then
    ln -sf ../../bin/udevadm "$INITRAMFS_DIR/usr/lib/systemd/systemd-udevd"
fi

# kmod symlinks for modprobe, insmod, etc.
for cmd in modprobe insmod rmmod lsmod depmod; do
    ln -sf kmod "$INITRAMFS_DIR/usr/bin/$cmd"
done

# ============================================================
# Phase 4: Copy systemd unit files
# ============================================================
echo "Copying systemd unit files..."
mkdir -p "$INITRAMFS_DIR/usr/lib/systemd/system"

UNIT_FILES=(
    # Core targets
    initrd.target
    initrd-fs.target
    initrd-root-device.target
    initrd-root-fs.target
    initrd-switch-root.target
    initrd-usr-fs.target
    basic.target
    sysinit.target
    local-fs.target
    local-fs-pre.target
    paths.target
    slices.target
    sockets.target
    timers.target
    emergency.target
    rescue.target
    shutdown.target
    umount.target
    final.target
    ctrl-alt-del.target

    # Core services
    initrd-switch-root.service
    initrd-cleanup.service
    initrd-parse-etc.service
    initrd-udevadm-cleanup-db.service
    emergency.service
    rescue.service

    # journald (needed for switch-root)
    systemd-journald.service
    systemd-journald.socket
    systemd-journald-dev-log.socket
    systemd-journald-audit.socket

    # tmpfiles
    systemd-tmpfiles-setup.service
    systemd-tmpfiles-setup-dev-early.service
    systemd-tmpfiles-setup-dev.service

    # udev (device discovery)
    systemd-udevd.service
    systemd-udevd-control.socket
    systemd-udevd-kernel.socket
    systemd-udev-trigger.service

    # Other needed units
    systemd-sysctl.service
    systemd-modules-load.service
    kmod-static-nodes.service

    # Slices
    system.slice
    -.slice
)

for unit in "${UNIT_FILES[@]}"; do
    if [[ -e "$STAGING/usr/lib/systemd/system/$unit" ]]; then
        cp -a "$STAGING/usr/lib/systemd/system/$unit" "$INITRAMFS_DIR/usr/lib/systemd/system/"
    fi
done

# Copy .wants directories
for wants_dir in \
    sysinit.target.wants \
    sockets.target.wants \
    local-fs.target.wants \
    initrd.target.wants \
    initrd-root-device.target.wants \
    initrd-root-fs.target.wants \
    initrd-switch-root.target.wants \
    timers.target.wants; do
    if [[ -d "$STAGING/usr/lib/systemd/system/$wants_dir" ]]; then
        cp -a "$STAGING/usr/lib/systemd/system/$wants_dir" \
              "$INITRAMFS_DIR/usr/lib/systemd/system/"
    fi
done

# Prune broken symlinks in .wants directories (units we didn't include)
find "$INITRAMFS_DIR/usr/lib/systemd/system" -type l | while read -r link; do
    if [[ ! -e "$link" ]]; then
        rm -f "$link"
    fi
done

# Copy initrd preset files
if [[ -d "$STAGING/usr/lib/systemd/initrd-preset" ]]; then
    mkdir -p "$INITRAMFS_DIR/usr/lib/systemd/initrd-preset"
    cp -a "$STAGING/usr/lib/systemd/initrd-preset/"* "$INITRAMFS_DIR/usr/lib/systemd/initrd-preset/" 2>/dev/null || true
fi

# Copy minimal tmpfiles.d configs
mkdir -p "$INITRAMFS_DIR/usr/lib/tmpfiles.d"
for conf in systemd.conf systemd-tmp.conf tmp.conf journal-nocow.conf; do
    if [[ -f "$STAGING/usr/lib/tmpfiles.d/$conf" ]]; then
        cp "$STAGING/usr/lib/tmpfiles.d/$conf" "$INITRAMFS_DIR/usr/lib/tmpfiles.d/"
    fi
done

# ============================================================
# Phase 5: Resolve and copy shared library dependencies
# ============================================================
echo "Resolving shared library dependencies..."

# Copy the dynamic linker first
if [[ -e "$STAGING/usr/lib/ld-linux-x86-64.so.2" ]]; then
    cp -a "$STAGING/usr/lib/ld-linux-x86-64.so.2" "$INITRAMFS_DIR/usr/lib/"
    # If it's a symlink, also copy the target
    if [[ -L "$STAGING/usr/lib/ld-linux-x86-64.so.2" ]]; then
        target=$(readlink "$STAGING/usr/lib/ld-linux-x86-64.so.2")
        if [[ -f "$STAGING/usr/lib/$target" ]]; then
            cp -a "$STAGING/usr/lib/$target" "$INITRAMFS_DIR/usr/lib/"
        fi
    fi
fi

# Resolve all NEEDED libraries recursively
declare -A SEEN_LIBS=()

resolve_lib() {
    local libname="$1"

    # Skip if already processed
    [[ -n "${SEEN_LIBS[$libname]+x}" ]] && return
    SEEN_LIBS["$libname"]=1

    # Search for the library in staging
    local found=""
    for search_dir in "$STAGING/usr/lib/systemd" "$STAGING/usr/lib"; do
        if [[ -e "$search_dir/$libname" ]]; then
            found="$search_dir/$libname"
            break
        fi
    done

    if [[ -z "$found" ]]; then
        # Try the dynamic linker name
        if [[ "$libname" == "ld-linux-x86-64.so.2" ]]; then
            return  # Already copied above
        fi
        echo "  WARNING: Library $libname not found in staging"
        return
    fi

    # Determine destination
    local dest_dir="$INITRAMFS_DIR/usr/lib"
    if [[ "$found" == *"/usr/lib/systemd/"* ]]; then
        dest_dir="$INITRAMFS_DIR/usr/lib/systemd"
    fi
    mkdir -p "$dest_dir"

    # Copy the library (and symlink target if applicable)
    if [[ -L "$found" ]]; then
        cp -a "$found" "$dest_dir/"
        local target
        target=$(readlink "$found")
        local source_dir
        source_dir=$(dirname "$found")
        if [[ -f "$source_dir/$target" ]]; then
            cp -a "$source_dir/$target" "$dest_dir/"
            # Recurse into the real file's dependencies
            local deps
            deps=$(readelf -d "$source_dir/$target" 2>/dev/null | grep 'NEEDED' | sed 's/.*\[\(.*\)\]/\1/' || true)
            for dep in $deps; do
                resolve_lib "$dep"
            done
        fi
    else
        cp -a "$found" "$dest_dir/"
        # Recurse into this file's dependencies
        local deps
        deps=$(readelf -d "$found" 2>/dev/null | grep 'NEEDED' | sed 's/.*\[\(.*\)\]/\1/' || true)
        for dep in $deps; do
            resolve_lib "$dep"
        done
    fi
}

# Scan all ELF binaries in the initramfs for NEEDED libraries
while IFS= read -r -d '' elf; do
    deps=$(readelf -d "$elf" 2>/dev/null | grep 'NEEDED' | sed 's/.*\[\(.*\)\]/\1/' || true)
    for dep in $deps; do
        resolve_lib "$dep"
    done
done < <(find "$INITRAMFS_DIR" -type f -executable -print0)

# Manually include NSS module (loaded via dlopen, not in NEEDED)
if [[ -f "$STAGING/usr/lib/libnss_files.so.2" ]]; then
    cp -a "$STAGING/usr/lib/libnss_files.so.2" "$INITRAMFS_DIR/usr/lib/"
    echo "  Included libnss_files.so.2 (dlopen'd)"
elif [[ -L "$STAGING/usr/lib/libnss_files.so.2" ]]; then
    cp -a "$STAGING/usr/lib/libnss_files.so.2" "$INITRAMFS_DIR/usr/lib/"
    target=$(readlink "$STAGING/usr/lib/libnss_files.so.2")
    if [[ -f "$STAGING/usr/lib/$target" ]]; then
        cp -a "$STAGING/usr/lib/$target" "$INITRAMFS_DIR/usr/lib/"
    fi
    echo "  Included libnss_files.so.2 (dlopen'd)"
fi

# Also include PAM modules needed by sulogin
if [[ -d "$STAGING/usr/lib/security" ]]; then
    mkdir -p "$INITRAMFS_DIR/usr/lib/security"
    for mod in pam_unix.so pam_deny.so pam_permit.so pam_nologin.so pam_rootok.so; do
        if [[ -f "$STAGING/usr/lib/security/$mod" ]]; then
            cp -a "$STAGING/usr/lib/security/$mod" "$INITRAMFS_DIR/usr/lib/security/"
        fi
    done
fi

echo "  Total libraries: ${#SEEN_LIBS[@]}"

# ============================================================
# Phase 6: Configuration files
# ============================================================
echo "Writing initramfs configuration..."

# /etc/initrd-release tells systemd it's running in initrd mode
cat > "$INITRAMFS_DIR/etc/initrd-release" << 'EOF'
ID=ion
VERSION_ID=0.1
EOF

# Do NOT create /etc/os-release or /etc/machine-id — their absence
# (combined with /etc/initrd-release) is how systemd detects initrd mode

# Minimal nsswitch.conf for user lookups (sulogin needs this)
cat > "$INITRAMFS_DIR/etc/nsswitch.conf" << 'EOF'
passwd: files
group:  files
shadow: files
EOF

# Minimal passwd/group for systemd service users
cat > "$INITRAMFS_DIR/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/sh
nobody:x:65534:65534:Nobody:/:/usr/bin/nologin
EOF

cat > "$INITRAMFS_DIR/etc/group" << 'EOF'
root:x:0:
tty:x:5:
kmem:x:9:
nobody:x:65534:
EOF

# Minimal PAM config for sulogin emergency shell
mkdir -p "$INITRAMFS_DIR/etc/pam.d"
cat > "$INITRAMFS_DIR/etc/pam.d/other" << 'EOF'
auth     sufficient pam_rootok.so
auth     sufficient pam_unix.so
account  sufficient pam_unix.so
session  sufficient pam_unix.so
EOF

# ============================================================
# Phase 7: Clean up staging and pack as cpio archive
# ============================================================
echo "Cleaning up staging..."
rm -rf "$STAGING"

# Remove pacman metadata files that leaked in
rm -f "$INITRAMFS_DIR/.BUILDINFO" "$INITRAMFS_DIR/.MTREE" "$INITRAMFS_DIR/.PKGINFO" "$INITRAMFS_DIR/.INSTALL"

echo "Packing initramfs..."
cd "$INITRAMFS_DIR"
find . -print0 | cpio --null -o -H newc --quiet 2>/dev/null | gzip -9 > "$INITRAMFS_IMG"

echo "Initramfs created: $INITRAMFS_IMG ($(du -h "$INITRAMFS_IMG" | cut -f1))"
echo "  Uncompressed: $(du -sh "$INITRAMFS_DIR" | cut -f1)"
