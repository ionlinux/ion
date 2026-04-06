#!/bin/bash
# Remove archiso mkinitcpio config, regenerate initramfs, install bootloader
set -e

# ── Fix initramfs ──────────────────────────────────────────────
rm -f /etc/mkinitcpio.conf.d/archiso.conf

KVER=$(ls /usr/lib/modules/ | head -1)

cat > /etc/mkinitcpio.d/linux.preset << PRESET
PRESETS=(default fallback)

ALL_kver=/usr/lib/modules/${KVER}/vmlinuz

default_image=/boot/initramfs-linux.img

fallback_image=/boot/initramfs-linux-fallback.img
fallback_options="-S autodetect"
PRESET

mkinitcpio -p linux

# ── Copy kernel to ESP ─────────────────────────────────────────
cp "/usr/lib/modules/${KVER}/vmlinuz" /boot/vmlinuz-linux

# ── Install systemd-boot ───────────────────────────────────────
bootctl install --no-variables

# ── Create loader entries ──────────────────────────────────────
ROOT_UUID=$(findmnt -no UUID /)
ROOT_FSTYPE=$(findmnt -no FSTYPE /)
ROOT_OPTS="root=UUID=${ROOT_UUID} rw"

# Add btrfs subvolume option if needed
if [[ "$ROOT_FSTYPE" == "btrfs" ]]; then
  ROOT_SUBVOL=$(findmnt -no OPTIONS / | grep -oP 'subvol=\K[^,]+')
  if [[ -n "$ROOT_SUBVOL" ]]; then
    ROOT_OPTS="${ROOT_OPTS} rootflags=subvol=${ROOT_SUBVOL}"
  fi
fi

mkdir -p /boot/loader/entries

cat > /boot/loader/loader.conf << LOADER
default ion.conf
timeout 5
LOADER

cat > /boot/loader/entries/ion.conf << ENTRY
title   Ion Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options ${ROOT_OPTS}
ENTRY

# ── Remove live-only configs ──────────────────────────────────
# Remove liveuser
userdel -rf liveuser 2>/dev/null || true
rm -f /etc/sudoers.d/liveuser

# Remove tty1 root autologin (live-only)
rm -rf /etc/systemd/system/getty@tty1.service.d

# Enable ly display manager and remove live autologin
systemctl enable ly@tty2
sed -i '/^auto_login_user/d; /^auto_login_session/d; /^auto_login_service/d' /etc/ly/config.ini


# ── Hyprland config ───────────────────────────────────────────
mkdir -p /etc/skel/.config/hypr
cp /etc/calamares/hyprland.conf /etc/skel/.config/hypr/hyprland.conf

# Copy to existing user home directories (users module runs before shellprocess)
for userdir in /home/*/; do
    username=$(basename "$userdir")
    if id "$username" &>/dev/null; then
        mkdir -p "${userdir}.config/hypr"
        cp /etc/skel/.config/hypr/hyprland.conf "${userdir}.config/hypr/hyprland.conf"
        chown -R "$username:$username" "${userdir}.config/hypr"
    fi
done

# ── Neovim: set up LazyVim starter if installed ───────────────
if pacman -Q neovim &>/dev/null; then
    git clone https://github.com/LazyVim/starter.git /etc/skel/.config/nvim 2>/dev/null || true
    for userdir in /home/*/; do
        username=$(basename "$userdir")
        if id "$username" &>/dev/null; then
            mkdir -p "${userdir}.config/nvim"
            cp -rn /etc/skel/.config/nvim/. "${userdir}.config/nvim/"
            chown -R "$username:$username" "${userdir}.config"
        fi
    done
fi

# ── Clean up live-only artifacts ──────────────────────────────
# Remove liveuser setup service
rm -f /etc/systemd/system/liveuser-setup.service
rm -f /etc/systemd/system/multi-user.target.wants/liveuser-setup.service

# Remove Calamares autostart and desktop entry
rm -f /etc/xdg/autostart/ion-install-gui.desktop
rm -f /usr/share/applications/ion-install-gui.desktop

# Remove Calamares and its configs
rm -rf /etc/calamares
pacman -Rns --noconfirm calamares-git 2>/dev/null || true

# Remove pacman-keyring-init service (one-shot, already ran)
rm -f /etc/systemd/system/pacman-keyring-init.service
rm -f /etc/systemd/system/multi-user.target.wants/pacman-keyring-init.service

# Remove systemd-firstboot mask
rm -f /etc/systemd/system/systemd-firstboot.service

# Remove live ISO bash profile message
rm -f /root/.bash_profile
