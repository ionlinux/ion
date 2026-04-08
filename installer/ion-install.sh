#!/usr/bin/env bash
#
# ion-install — Ion Linux installer
#
# A simple, guided TUI installer for Ion Linux.
#
set -euo pipefail

INSTALLER_VERSION="0.4.0"

# ── Helpers ────────────────────────────────────────────────────
part_device() {
  local disk="$1" num="$2"
  if [[ "$disk" == *nvme* || "$disk" == *mmcblk* ]]; then
    echo "${disk}p${num}"
  else
    echo "${disk}${num}"
  fi
}

show_partition_plan() {
  echo ""
  echo "  #   Size         FS       Mount"
  echo "  ──────────────────────────────────────"
  for i in "${!PART_SIZE[@]}"; do
    printf "  %-3s %-12s %-8s %s\n" \
      "$((i+1))" "${PART_SIZE[$i]}" "${PART_FS[$i]}" "${PART_MOUNT[$i]}"
  done
  echo ""
}

# ── Main ───────────────────────────────────────────────────────
echo "======================================"
echo "  Ion Linux Installer v${INSTALLER_VERSION}"
echo "======================================"
echo ""

# ── Disk selection ──────────────────────────────────────────────
echo "Available disks:"
lsblk -dno NAME,SIZE,MODEL | grep -v loop
echo ""
read -rp "Select target disk (e.g., vda): " TARGET_DISK
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

# ── Partition editor ───────────────────────────────────────────
echo ""
echo "==> Partition editor for ${TARGET}"
echo "    Disk size: $(lsblk -dno SIZE "$TARGET" | tr -d ' ')"
echo ""
echo "Filesystem types: fat32, ext4, btrfs, xfs, swap"
echo ""

PART_SIZE=()
PART_FS=()
PART_MOUNT=()

while true; do
  show_partition_plan

  echo "  [a] Add partition"
  if [[ ${#PART_SIZE[@]} -gt 0 ]]; then
    echo "  [d] Delete partition"
    echo "  [c] Confirm and apply"
  fi
  echo "  [q] Quit"
  echo ""
  read -rp "  Action: " ACTION

  case "$ACTION" in
    a)
      echo ""
      echo "  Size examples: 512MiB, 4GiB, 100% (rest of disk)"
      read -rp "  Size: " NEW_SIZE
      read -rp "  Filesystem (fat32/ext4/btrfs/xfs/swap): " NEW_FS
      read -rp "  Mount point (e.g., /boot, /, /home, swap): " NEW_MOUNT

      if [[ -z "$NEW_SIZE" || -z "$NEW_FS" || -z "$NEW_MOUNT" ]]; then
        echo "  error: all fields are required"
        continue
      fi

      PART_SIZE+=("$NEW_SIZE")
      PART_FS+=("$NEW_FS")
      PART_MOUNT+=("$NEW_MOUNT")
      ;;
    d)
      [[ ${#PART_SIZE[@]} -eq 0 ]] && continue
      read -rp "  Delete partition #: " DEL_NUM
      DEL_IDX=$((DEL_NUM - 1))
      if [[ $DEL_IDX -ge 0 && $DEL_IDX -lt ${#PART_SIZE[@]} ]]; then
        unset 'PART_SIZE[$DEL_IDX]' 'PART_FS[$DEL_IDX]' 'PART_MOUNT[$DEL_IDX]'
        PART_SIZE=("${PART_SIZE[@]}")
        PART_FS=("${PART_FS[@]}")
        PART_MOUNT=("${PART_MOUNT[@]}")
      else
        echo "  error: invalid partition number"
      fi
      ;;
    c)
      [[ ${#PART_SIZE[@]} -eq 0 ]] && echo "  error: no partitions defined" && continue

      # Validate: need a /boot and / mount point
      HAS_BOOT=false
      HAS_ROOT=false
      for m in "${PART_MOUNT[@]}"; do
        [[ "$m" == "/boot" ]] && HAS_BOOT=true
        [[ "$m" == "/" ]] && HAS_ROOT=true
      done

      if ! $HAS_BOOT; then
        echo "  error: no partition mounted at /boot (required for EFI)"
        continue
      fi
      if ! $HAS_ROOT; then
        echo "  error: no partition mounted at / (required for root)"
        continue
      fi

      echo ""
      echo "  Final layout:"
      show_partition_plan
      read -rp "  Apply this layout? [y/N] " APPLY
      if [[ "$APPLY" == "y" || "$APPLY" == "Y" ]]; then
        break
      fi
      ;;
    q)
      echo "Aborted."
      exit 0
      ;;
    *)
      echo "  error: invalid action"
      ;;
  esac
done

# ── Apply partitioning ─────────────────────────────────────────
echo ""
echo "==> Partitioning ${TARGET}..."
parted -s "$TARGET" mklabel gpt

OFFSET="1MiB"
EFI_PART_NUM=""
ROOT_PART_NUM=""

for i in "${!PART_SIZE[@]}"; do
  PART_NUM=$((i + 1))
  SIZE="${PART_SIZE[$i]}"
  FS="${PART_FS[$i]}"
  MOUNT="${PART_MOUNT[$i]}"

  if [[ "$SIZE" == "100%" ]]; then
    END="100%"
  else
    OFFSET_MIB="${OFFSET%MiB}"
    if [[ "$SIZE" == *GiB ]]; then
      SIZE_MIB=$(( ${SIZE%GiB} * 1024 ))
    elif [[ "$SIZE" == *MiB ]]; then
      SIZE_MIB="${SIZE%MiB}"
    else
      echo "error: invalid size '${SIZE}' (use MiB, GiB, or 100%)" >&2
      exit 1
    fi
    END="$(( OFFSET_MIB + SIZE_MIB ))MiB"
  fi

  PARTED_FS="$FS"
  [[ "$FS" == "swap" ]] && PARTED_FS="linux-swap"
  [[ "$FS" == "btrfs" || "$FS" == "xfs" ]] && PARTED_FS="ext2"

  parted -s "$TARGET" mkpart "$MOUNT" "$PARTED_FS" "$OFFSET" "$END"

  if [[ "$MOUNT" == "/boot" ]]; then
    parted -s "$TARGET" set "$PART_NUM" esp on
    EFI_PART_NUM="$PART_NUM"
  fi
  [[ "$MOUNT" == "/" ]] && ROOT_PART_NUM="$PART_NUM"

  [[ "$END" != "100%" ]] && OFFSET="$END"
done

# ── Formatting ─────────────────────────────────────────────────
echo "==> Formatting partitions..."
for i in "${!PART_SIZE[@]}"; do
  PART_NUM=$((i + 1))
  DEV="$(part_device "$TARGET" "$PART_NUM")"
  FS="${PART_FS[$i]}"

  case "$FS" in
    fat32)  mkfs.fat -F32 "$DEV" ;;
    ext4)   mkfs.ext4 -F "$DEV" ;;
    btrfs)  mkfs.btrfs -f "$DEV" ;;
    xfs)    mkfs.xfs -f "$DEV" ;;
    swap)   mkswap "$DEV" ;;
  esac
done

# ── Mounting ────────────────────────────────────────────────────
echo "==> Mounting filesystems..."

# Mount root first
ROOT_DEV="$(part_device "$TARGET" "$ROOT_PART_NUM")"
mount "$ROOT_DEV" /mnt

# Mount remaining partitions (sorted by mount point depth)
for i in "${!PART_SIZE[@]}"; do
  PART_NUM=$((i + 1))
  MOUNT="${PART_MOUNT[$i]}"
  DEV="$(part_device "$TARGET" "$PART_NUM")"

  [[ "$MOUNT" == "/" ]] && continue

  if [[ "$MOUNT" == "swap" ]]; then
    swapon "$DEV"
  else
    mkdir -p "/mnt${MOUNT}"
    mount "$DEV" "/mnt${MOUNT}"
  fi
done

# ── Desktop environment ────────────────────────────────────────
echo ""
echo "Desktop environment:"
echo "  1) GNOME"
echo "  2) KDE Plasma"
echo "  3) None (minimal)"
echo ""
read -rp "Select [1-3]: " DE_CHOICE

DE_PACKAGES=""
DE_SERVICES=""
case "$DE_CHOICE" in
  1)
    DE_PACKAGES="gnome gnome-tweaks"
    DE_SERVICES="gdm"
    echo "==> GNOME selected"
    ;;
  2)
    DE_PACKAGES="plasma-meta sddm konsole dolphin"
    DE_SERVICES="sddm"
    echo "==> KDE Plasma selected"
    ;;
  3|"")
    echo "==> No desktop environment"
    ;;
  *)
    echo "error: invalid selection" >&2
    exit 1
    ;;
esac

# ── Pre-install configuration ──────────────────────────────────
echo ""
read -rp "Keymap [us]: " KEYMAP
KEYMAP="${KEYMAP:-us}"
mkdir -p /mnt/etc
echo "KEYMAP=${KEYMAP}" > /mnt/etc/vconsole.conf

# ── Base install ────────────────────────────────────────────────
echo "==> Installing base system..."
pacstrap -K /mnt base linux linux-firmware networkmanager efibootmgr sudo nano neovim git fastfetch pavucontrol blueman \
  $DE_PACKAGES

# ── Fstab ───────────────────────────────────────────────────────
echo "==> Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# ── System configuration ───────────────────────────────────────
echo ""
read -rp "Hostname: " HOSTNAME
read -rp "Username: " USERNAME

while true; do
  read -srp "Password for ${USERNAME}: " USER_PASS
  echo ""
  read -srp "Confirm password: " USER_PASS_CONFIRM
  echo ""
  if [[ "$USER_PASS" == "$USER_PASS_CONFIRM" ]]; then
    break
  fi
  echo "Passwords do not match. Try again."
done

read -rp "Use the same password for root? [Y/n] " SAME_PASS
if [[ "$SAME_PASS" == "n" || "$SAME_PASS" == "N" ]]; then
  while true; do
    read -srp "Root password: " ROOT_PASS
    echo ""
    read -srp "Confirm root password: " ROOT_PASS_CONFIRM
    echo ""
    if [[ "$ROOT_PASS" == "$ROOT_PASS_CONFIRM" ]]; then
      break
    fi
    echo "Passwords do not match. Try again."
  done
else
  ROOT_PASS="$USER_PASS"
fi

# Get root partition UUID for boot entry
ROOT_UUID="$(blkid -s UUID -o value "$ROOT_DEV")"

arch-chroot /mnt /bin/bash <<CHROOT
set -euo pipefail

# Timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

# Locale
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Ion branding
cat > /etc/os-release <<EOF
NAME="Ion Linux"
PRETTY_NAME="Ion Linux"
ID=ion
ID_LIKE=arch
BUILD_ID=rolling
ANSI_COLOR="38;2;23;147;209"
HOME_URL="https://ionlinux.org/"
DOCUMENTATION_URL="https://wiki.ionlinux.org/"
SUPPORT_URL="https://forum.ionlinux.org/"
BUG_REPORT_URL="https://bugs.ionlinux.org/"
LOGO=ion-logo
EOF

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

# Bootloader (systemd-boot)
bootctl install

cat > /boot/loader/loader.conf <<EOF
default ion.conf
timeout 5
EOF

cat > /boot/loader/entries/ion.conf <<EOF
title   Ion Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=${ROOT_UUID} rw
EOF

# User
useradd -m -G wheel -s /bin/bash ${USERNAME}
echo "${USERNAME}:${USER_PASS}" | chpasswd
echo "root:${ROOT_PASS}" | chpasswd

# Enable sudo for wheel
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Enable services
systemctl enable NetworkManager
if [[ -n "${DE_SERVICES}" ]]; then
  systemctl enable ${DE_SERVICES}
fi
CHROOT

# ── Branding ───────────────────────────────────────────────────
# Icon-only logo for About screen (LOGO=ion-logo in os-release)
cp /usr/share/pixmaps/ion-logo.svg /mnt/usr/share/pixmaps/ion-logo.svg 2>/dev/null || true
# Text logo replaces Arch logos used by GDM login screen
cp /usr/share/pixmaps/ion-logo-text.svg /mnt/usr/share/pixmaps/ion-logo-text.svg 2>/dev/null || true
cp /usr/share/pixmaps/ion-logo-text-dark.svg /mnt/usr/share/pixmaps/ion-logo-text-dark.svg 2>/dev/null || true
cp /usr/share/pixmaps/ion-logo.svg /mnt/usr/share/pixmaps/archlinux-logo.svg 2>/dev/null || true
cp /usr/share/pixmaps/ion-logo-text-dark.svg /mnt/usr/share/pixmaps/archlinux-logo-text.svg 2>/dev/null || true
cp /usr/share/pixmaps/ion-logo-text.svg /mnt/usr/share/pixmaps/archlinux-logo-text-dark.svg 2>/dev/null || true
# Fastfetch branding
mkdir -p /mnt/usr/share/fastfetch/logos /mnt/etc/fastfetch
cp /usr/share/fastfetch/logos/ion.txt /mnt/usr/share/fastfetch/logos/ion.txt 2>/dev/null || true
cp /etc/fastfetch/config.jsonc /mnt/etc/fastfetch/config.jsonc 2>/dev/null || true

# ── EFI boot entry ─────────────────────────────────────────────
# Create the UEFI boot entry from the live environment where
# EFI variables are directly accessible (not possible from a chroot).
echo "==> Creating EFI boot entry..."

# Ensure efivarfs is mounted and writable
if ! mountpoint -q /sys/firmware/efi/efivars; then
  mount -t efivarfs efivarfs /sys/firmware/efi/efivars
fi

efibootmgr --create --disk "$TARGET" --part "$EFI_PART_NUM" \
  --loader '\EFI\systemd\systemd-bootx64.efi' \
  --label "Ion Linux" --verbose

# ── Cleanup ─────────────────────────────────────────────────────
echo "==> Unmounting..."
umount -R /mnt

echo ""
echo "======================================"
echo "  Installation complete!"
echo "  Remove the install media and reboot."
echo "======================================"
