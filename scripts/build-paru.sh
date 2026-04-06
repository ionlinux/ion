#!/usr/bin/env bash
#
# build-paru.sh — Build paru from AUR into a local pacman repo
#
# Run this before build-iso.sh to make paru available to the ISO build.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPO_DIR="${PROJECT_ROOT}/out/repo"
BUILD_DIR="/tmp/ion-paru-build"

echo "==> Building paru from AUR"

mkdir -p "$REPO_DIR" "$BUILD_DIR"

# Clone or update the AUR package
if [[ -d "${BUILD_DIR}/paru" ]]; then
  echo "==> Updating existing AUR checkout..."
  cd "${BUILD_DIR}/paru"
  git pull
else
  echo "==> Cloning paru from AUR..."
  git clone https://aur.archlinux.org/paru.git "${BUILD_DIR}/paru"
  cd "${BUILD_DIR}/paru"
fi

# Build the package
echo "==> Building package..."
makepkg -sfC --noconfirm

# Copy built package to local repo
echo "==> Adding package to local repo..."
cp -f ./*.pkg.tar.zst "$REPO_DIR/"

# Rebuild the repo database
cd "$REPO_DIR"
repo-add ion-local.db.tar.gz ./*.pkg.tar.zst

echo ""
echo "==> paru package built and added to ${REPO_DIR}"
