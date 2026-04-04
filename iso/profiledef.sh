#!/usr/bin/env bash
# Ion Linux ISO profile definition

iso_name="ionlinux"
iso_label="ION"
iso_publisher="Ion Linux <https://ionlinux.org>"
iso_application="Ion Linux Live/Install ISO"
iso_version="$(date +%Y.%m.%d)"
install_dir="ion"
buildmodes=('iso')
bootmodes=(
  'bios.syslinux'
  'uefi.grub'
)
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
)
