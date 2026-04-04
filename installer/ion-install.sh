#!/usr/bin/env bash
#
# ion-install — Ion Linux installer
#
# A simple, guided TUI installer for Ion Linux.
#
set -euo pipefail

INSTALLER_VERSION="0.1.0"

echo "======================================"
echo "  Ion Linux Installer v${INSTALLER_VERSION}"
echo "======================================"
echo ""

# ── Disk selection ──────────────────────────────────────────────
echo "Available disks:"
lsblk -dno NAME,SIZE,MODEL | grep -v loop
echo ""
read -rp "Select target disk (e.g., sda): " TARGET_DISK
TARGET="/dev/${TARGET_DISK}"

if [[ ! -b "$TARGET" ]]; then
  echo "error: ${TARGET} is not a valid block device" >&2
  exit 1
fi

echo ""
echo "WARNING: All data on ${TARGET} will be destroyed!"
read -rp "Continue? [y/N] " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

# ── Partitioning ────────────────────────────────────────────────
echo ""
echo "==> Partitioning ${TARGET}..."

parted -s "$TARGET" mklabel gpt
parted -s "$TARGET" mkpart "EFI" fat32 1MiB 512MiB
parted -s "$TARGET" set 1 esp on
parted -s "$TARGET" mkpart "root" ext4 512MiB 100%

EFI_PART="${TARGET}1"
ROOT_PART="${TARGET}2"

# Handle NVMe naming (p1, p2)
if [[ "$TARGET" == *nvme* || "$TARGET" == *mmcblk* ]]; then
  EFI_PART="${TARGET}p1"
  ROOT_PART="${TARGET}p2"
fi

echo "==> Formatting partitions..."
mkfs.fat -F32 "$EFI_PART"
mkfs.ext4 -F "$ROOT_PART"

# ── Mounting ────────────────────────────────────────────────────
echo "==> Mounting filesystems..."
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot/efi
mount "$EFI_PART" /mnt/boot/efi

# ── Base install ────────────────────────────────────────────────
echo "==> Installing base system..."
pacstrap -K /mnt base linux linux-firmware networkmanager grub efibootmgr sudo nano

# ── Fstab ───────────────────────────────────────────────────────
echo "==> Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# ── System configuration ───────────────────────────────────────
echo ""
read -rp "Hostname: " HOSTNAME
read -rp "Username: " USERNAME

arch-chroot /mnt /bin/bash <<CHROOT
set -euo pipefail

# Timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

# Locale
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Hostname
echo "${HOSTNAME}" > /etc/hostname

# Hosts
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

# Initramfs
mkinitcpio -P

# Bootloader
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ion
grub-mkconfig -o /boot/grub/grub.cfg

# User
useradd -m -G wheel -s /bin/bash ${USERNAME}
echo "Set password for ${USERNAME}:"
passwd ${USERNAME}

echo "Set root password:"
passwd

# Enable sudo for wheel
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Enable services
systemctl enable NetworkManager
CHROOT

# ── Cleanup ─────────────────────────────────────────────────────
echo "==> Unmounting..."
umount -R /mnt

echo ""
echo "======================================"
echo "  Installation complete!"
echo "  Remove the install media and reboot."
echo "======================================"
