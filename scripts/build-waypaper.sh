#!/usr/bin/env bash
#
# build-waypaper.sh — Build waypaper-git and its AUR dependencies into a local pacman repo
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPO_DIR="${PROJECT_ROOT}/out/repo"
BUILD_DIR="/tmp/ion-waypaper-build"

mkdir -p "$REPO_DIR" "$BUILD_DIR"

build_aur_package() {
  local pkg="$1"
  echo "==> Building ${pkg} from AUR"

  if [[ -d "${BUILD_DIR}/${pkg}" ]]; then
    cd "${BUILD_DIR}/${pkg}"
    git pull
  else
    git clone "https://aur.archlinux.org/${pkg}.git" "${BUILD_DIR}/${pkg}"
    cd "${BUILD_DIR}/${pkg}"
  fi

  makepkg -sfC --noconfirm
  cp -f ./*.pkg.tar.zst "$REPO_DIR/"
}

# Build AUR dependencies first
build_aur_package python-imageio-ffmpeg
build_aur_package python-screeninfo

# Update repo database so waypaper-git can resolve its dependencies
cd "$REPO_DIR"
repo-add ion-local.db.tar.gz ./*.pkg.tar.zst

# Install dependencies locally so makepkg can resolve them for waypaper-git
sudo pacman -U --noconfirm "$REPO_DIR"/python-imageio-ffmpeg-*.pkg.tar.zst "$REPO_DIR"/python-screeninfo-*.pkg.tar.zst 2>/dev/null || true

# Build waypaper-git
build_aur_package waypaper-git

# Rebuild repo database with all packages
cd "$REPO_DIR"
repo-add ion-local.db.tar.gz ./*.pkg.tar.zst

echo ""
echo "==> waypaper-git and dependencies built and added to ${REPO_DIR}"
