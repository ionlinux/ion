#!/usr/bin/env bash
#
# build-iso.sh — Build the Ion Linux live/install ISO
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WORK_DIR="${PROJECT_ROOT}/build"
OUT_DIR="${PROJECT_ROOT}/out"

if [[ $EUID -ne 0 ]]; then
  echo "error: this script must be run as root" >&2
  exit 1
fi

echo "==> Building Ion Linux ISO"
echo "    Work directory: ${WORK_DIR}"
echo "    Output directory: ${OUT_DIR}"

mkdir -p "${WORK_DIR}" "${OUT_DIR}"

# Make local repo available (for calamares, etc.)
# Build calamares first if the repo doesn't exist yet
REPO_DIR="${OUT_DIR}/repo"

# Build AUR packages into local repo if any are missing
build_aur_packages() {
  mkdir -p "$REPO_DIR"
  chown "${SUDO_USER:-nobody}:${SUDO_USER:-nobody}" "$REPO_DIR"

  local need_build=false
  for pkg in calamares-git paru waypaper-git wlogout sours-icon-theme-git sweet-gtk-theme bibata-cursor-theme-bin; do
    if ! ls "$REPO_DIR"/${pkg}-*.pkg.tar.zst &>/dev/null; then
      need_build=true
      break
    fi
  done

  if [[ "$need_build" == "true" ]]; then
    echo "==> Building missing AUR packages..."
    ls "$REPO_DIR"/calamares-git-*.pkg.tar.zst &>/dev/null || sudo -u "${SUDO_USER:-nobody}" "${SCRIPT_DIR}/build-calamares.sh"
    ls "$REPO_DIR"/paru-*.pkg.tar.zst &>/dev/null          || sudo -u "${SUDO_USER:-nobody}" "${SCRIPT_DIR}/build-paru.sh"
    ls "$REPO_DIR"/waypaper-git-*.pkg.tar.zst &>/dev/null   || sudo -u "${SUDO_USER:-nobody}" "${SCRIPT_DIR}/build-waypaper.sh"
    ls "$REPO_DIR"/wlogout-*.pkg.tar.zst &>/dev/null        || sudo -u "${SUDO_USER:-nobody}" "${SCRIPT_DIR}/build-wlogout.sh"
    ls "$REPO_DIR"/sours-icon-theme-git-*.pkg.tar.zst &>/dev/null || sudo -u "${SUDO_USER:-nobody}" "${SCRIPT_DIR}/build-themes.sh"
    ls "$REPO_DIR"/sweet-gtk-theme-*.pkg.tar.zst &>/dev/null      || sudo -u "${SUDO_USER:-nobody}" "${SCRIPT_DIR}/build-themes.sh"
    ls "$REPO_DIR"/bibata-cursor-theme-bin-*.pkg.tar.zst &>/dev/null || sudo -u "${SUDO_USER:-nobody}" "${SCRIPT_DIR}/build-bibata.sh"
  fi
}
build_aur_packages

echo "==> Copying local repo to /tmp/ion-repo..."
mkdir -p /tmp/ion-repo
cp -f "$REPO_DIR"/* /tmp/ion-repo/

# Clone LazyVim starter into skel for neovim setup
NVIM_SKEL="${PROJECT_ROOT}/iso/airootfs/etc/skel/.config/nvim"
if [[ ! -d "$NVIM_SKEL/.git" ]]; then
  echo "==> Cloning LazyVim starter into skel..."
  rm -rf "$NVIM_SKEL"
  sudo -u "${SUDO_USER:-nobody}" git clone https://github.com/LazyVim/starter.git "$NVIM_SKEL"
fi

# Use mkarchiso (from archiso package) as the base build tool.
# Ion customizes the profile in iso/.
mkarchiso -v \
  -w "${WORK_DIR}" \
  -o "${OUT_DIR}" \
  "${PROJECT_ROOT}/iso"

echo "==> ISO build complete. Output:"
ls -lh "${OUT_DIR}"/*.iso 2>/dev/null || echo "    (no ISO found — check build logs)"

# Create a "latest" symlink for convenience
LATEST_ISO=$(ls -t "${OUT_DIR}"/*.iso 2>/dev/null | head -1)
if [[ -n "$LATEST_ISO" ]]; then
  ln -sf "$(basename "$LATEST_ISO")" "${OUT_DIR}/ionlinux-latest-x86_64.iso"
  echo "    Symlink: ionlinux-latest-x86_64.iso -> $(basename "$LATEST_ISO")"
fi
