#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_DIR}/build"
ROOTFS_DIR="${BUILD_DIR}/rootfs"
PKG_CACHE="/var/cache/pacman/pkg"

echo "Creating root filesystem..."

# Clean and create merged /usr directory structure
rm -rf "$ROOTFS_DIR"
mkdir -p "$ROOTFS_DIR"/{usr/{bin,sbin,lib},etc/{systemd/system/getty.target.wants,pam.d,dbus-1},var/{log/journal,tmp},tmp,run,dev,proc,sys,root,home,boot/efi,mnt}

# Create merged /usr symlinks
cd "$ROOTFS_DIR"
ln -sf usr/bin  bin
ln -sf usr/sbin sbin
ln -sf usr/lib  lib
ln -sf usr/lib  lib64

# ============================================================
# Extract system packages from Arch Linux
# ============================================================
echo "Downloading system packages..."

PACKAGES=(
    # Core system
    systemd
    systemd-libs
    dbus
    expat
    glibc
    gcc-libs
    util-linux-libs
    util-linux
    libcap
    libgcrypt
    libgpg-error
    lz4
    xz
    zstd
    pcre2
    libseccomp
    openssl
    acl
    attr
    kmod
    pam
    audit
    libcap-ng
    libxcrypt
    # Userspace tools (replaces BusyBox)
    coreutils
    bash
    shadow
    grep
    sed
    gawk
    procps-ng
    findutils
    # Dependencies for the above
    readline
    ncurses
    gmp
    mpfr
    # kmod dependency (compressed kernel modules)
    zlib
    # pam_unix.so dependencies (NIS/RPC support compiled in by Arch)
    libnsl
    libtirpc
    krb5
    keyutils
    e2fsprogs
    openldap
    cyrus-sasl
)

# Check which packages need downloading
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

echo "Extracting packages into rootfs..."
for pkg in "${PACKAGES[@]}"; do
    # Find the package file in cache (get latest version)
    PKG_FILE=$(ls "${PKG_CACHE}/${pkg}-"[0-9]*.pkg.tar.zst 2>/dev/null | sort -V | tail -1 || true)
    if [[ -z "$PKG_FILE" || ! -f "$PKG_FILE" ]]; then
        echo "  WARNING: Package $pkg not found in cache, skipping"
        continue
    fi
    echo "  Extracting: $(basename "$PKG_FILE")"
    bsdtar -xf "$PKG_FILE" -C "$ROOTFS_DIR" 2>/dev/null || true
done

# Copy libgcc_s if not extracted from packages (gcc-libs package may be split)
if [[ ! -f "$ROOTFS_DIR/usr/lib/libgcc_s.so.1" ]]; then
    echo "  Copying libgcc_s.so.1 from host..."
    cp /usr/lib/libgcc_s.so.1 "$ROOTFS_DIR/usr/lib/"
fi

# Remove unnecessary files to save space
echo "Cleaning up extracted files..."
rm -rf "$ROOTFS_DIR/usr/share/man"
rm -rf "$ROOTFS_DIR/usr/share/doc"
rm -rf "$ROOTFS_DIR/usr/share/info"
rm -rf "$ROOTFS_DIR/usr/share/locale"
rm -rf "$ROOTFS_DIR/usr/share/i18n"
rm -rf "$ROOTFS_DIR/usr/share/zoneinfo"
rm -rf "$ROOTFS_DIR/usr/share/gtk-doc"
rm -rf "$ROOTFS_DIR/usr/include"
rm -rf "$ROOTFS_DIR/usr/share/pkgconfig"
rm -rf "$ROOTFS_DIR/usr/lib/pkgconfig"
rm -rf "$ROOTFS_DIR/.BUILDINFO" "$ROOTFS_DIR/.MTREE" "$ROOTFS_DIR/.PKGINFO" "$ROOTFS_DIR/.INSTALL"

# ============================================================
# Install kernel modules
# ============================================================
if [[ -n "${KERNEL:-}" ]]; then
    KERNEL_SRC="${KERNEL%/arch/x86/boot/bzImage}"
    if [[ -d "$KERNEL_SRC" && -f "$KERNEL_SRC/Makefile" ]]; then
        echo "Installing kernel modules..."
        make -C "$KERNEL_SRC" modules_install \
            INSTALL_MOD_PATH="$ROOTFS_DIR" \
            INSTALL_MOD_STRIP=1 2>&1 | tail -5
        # Remove build/source symlinks (point back to host kernel tree)
        rm -f "$ROOTFS_DIR"/lib/modules/*/build
        rm -f "$ROOTFS_DIR"/lib/modules/*/source
    else
        echo "WARNING: Kernel source not found at $KERNEL_SRC, skipping modules"
    fi
fi

# ============================================================
# Create /sbin/init symlink to systemd
# ============================================================
echo "Configuring systemd..."
rm -f "$ROOTFS_DIR/usr/sbin/init"
ln -sf ../lib/systemd/systemd "$ROOTFS_DIR/usr/sbin/init"

# Set default target to multi-user
ln -sf /usr/lib/systemd/system/multi-user.target "$ROOTFS_DIR/etc/systemd/system/default.target"

# Create dbus.service (Arch's dbus package doesn't ship one; dbus-broker does,
# but we use dbus-daemon directly to avoid the extra dependency)
cat > "$ROOTFS_DIR/usr/lib/systemd/system/dbus.service" << 'EOF'
[Unit]
Description=D-Bus System Message Bus
Documentation=man:dbus-daemon(1)
DefaultDependencies=false
After=dbus.socket
Before=basic.target shutdown.target
Requires=dbus.socket
Conflicts=shutdown.target

[Service]
Type=notify
Sockets=dbus.socket
RuntimeDirectory=dbus
OOMScoreAdjust=-900
LimitNOFILE=16384
ProtectSystem=full
PrivateTmp=true
PrivateDevices=true
ExecStart=/usr/bin/dbus-daemon --system --address=systemd: --nofork --nopidfile --systemd-activation
ExecReload=/usr/bin/dbus-send --print-reply --system --type=method_call --dest=org.freedesktop.DBus / org.freedesktop.DBus.ReloadConfig
EOF

# Ensure /run/dbus exists before the socket tries to bind
cat >> "$ROOTFS_DIR/usr/lib/tmpfiles.d/dbus.conf" << 'EOF'
d /run/dbus 0755 dbus dbus -
EOF

# Enable serial console getty
ln -sf /usr/lib/systemd/system/serial-getty@.service \
    "$ROOTFS_DIR/etc/systemd/system/getty.target.wants/serial-getty@ttyS0.service"


# ============================================================
# Configuration files
# ============================================================
echo "Writing configuration files..."

cat > "$ROOTFS_DIR/etc/fstab" << 'EOF'
# <device>    <mountpoint>  <type>    <options>         <dump> <pass>
/dev/sda2     /             ext4      defaults,noatime   0      1
proc          /proc         proc      defaults           0      0
sysfs         /sys          sysfs     defaults           0      0
devtmpfs      /dev          devtmpfs  defaults           0      0
tmpfs         /tmp          tmpfs     defaults           0      0
tmpfs         /run          tmpfs     defaults           0      0
EOF

cat > "$ROOTFS_DIR/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/bash
nobody:x:65534:65534:Nobody:/:/usr/bin/nologin
systemd-journal:x:190:190:systemd Journal:/:/usr/bin/nologin
systemd-network:x:192:192:systemd Network Management:/:/usr/bin/nologin
systemd-resolve:x:193:193:systemd Resolver:/:/usr/bin/nologin
systemd-timesync:x:194:194:systemd Time Sync:/:/usr/bin/nologin
dbus:x:81:81:System Message Bus:/:/usr/bin/nologin
EOF

cat > "$ROOTFS_DIR/etc/group" << 'EOF'
root:x:0:
tty:x:5:
kmem:x:9:
wheel:x:10:
utmp:x:20:
input:x:97:
systemd-journal:x:190:
systemd-network:x:192:
systemd-resolve:x:193:
systemd-timesync:x:194:
dbus:x:81:
nobody:x:65534:
EOF

# Root password is "root" (SHA-512 hash)
ROOT_HASH=$(openssl passwd -6 "root")
cat > "$ROOTFS_DIR/etc/shadow" << EOF
root:${ROOT_HASH}:19814:0:99999:7:::
nobody:!:19814:0:99999:7:::
systemd-journal:!:19814::::::
systemd-network:!:19814::::::
systemd-resolve:!:19814::::::
systemd-timesync:!:19814::::::
dbus:!:19814::::::
EOF
chmod 600 "$ROOTFS_DIR/etc/shadow"

echo "ion" > "$ROOTFS_DIR/etc/hostname"

cat > "$ROOTFS_DIR/etc/os-release" << 'EOF'
NAME="Ion OS"
ID=ion
VERSION_ID=0.1
PRETTY_NAME="Ion OS 0.1"
HOME_URL="https://github.com/mattmoore/ion-os"
EOF

# Empty machine-id (systemd populates on first boot)
touch "$ROOTFS_DIR/etc/machine-id"

cat > "$ROOTFS_DIR/etc/nsswitch.conf" << 'EOF'
passwd: files
group:  files
shadow: files
hosts:  files dns
EOF

cat > "$ROOTFS_DIR/etc/shells" << 'EOF'
/bin/sh
/bin/bash
EOF

# Clean up package-installed PAM configs and securetty to start fresh
rm -rf "$ROOTFS_DIR/etc/pam.d"
rm -f "$ROOTFS_DIR/etc/securetty"

# Minimal PAM config
mkdir -p "$ROOTFS_DIR/etc/pam.d"
cat > "$ROOTFS_DIR/etc/pam.d/other" << 'EOF'
auth     required pam_unix.so nullok
account  required pam_unix.so
password required pam_unix.so nullok
session  required pam_unix.so
EOF

# All PAM service names that login/agetty may reference
for svc in login system-auth system-local-login system-login system-remote-login; do
    cp "$ROOTFS_DIR/etc/pam.d/other" "$ROOTFS_DIR/etc/pam.d/$svc"
done

# ============================================================
# Dynamic linker cache
# ============================================================
echo "Setting up dynamic linker..."
# Ensure ld.so.conf exists
cat > "$ROOTFS_DIR/etc/ld.so.conf" << 'EOF'
/usr/lib
EOF

echo "Root filesystem created: $ROOTFS_DIR"
echo "  Size: $(du -sh "$ROOTFS_DIR" | cut -f1)"
