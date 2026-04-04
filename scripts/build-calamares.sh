#!/usr/bin/env bash
#
# build-calamares.sh — Build Calamares from AUR into a local pacman repo
#
# Run this before build-iso.sh to make calamares available to the ISO build.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPO_DIR="${PROJECT_ROOT}/out/repo"
BUILD_DIR="/tmp/ion-calamares-build"

echo "==> Building Calamares from AUR"

mkdir -p "$REPO_DIR" "$BUILD_DIR"

# Clone or update the AUR package
if [[ -d "${BUILD_DIR}/calamares-git" ]]; then
  echo "==> Updating existing AUR checkout..."
  cd "${BUILD_DIR}/calamares-git"
  git pull
else
  echo "==> Cloning calamares-git from AUR..."
  git clone https://aur.archlinux.org/calamares-git.git "${BUILD_DIR}/calamares-git"
  cd "${BUILD_DIR}/calamares-git"
fi

# Build the package
# Use system Python, not any local/uv-managed Python
echo "==> Building package (this may take a while)..."
export PATH="/usr/bin:${PATH}"
export DPython_ROOT=/usr
makepkg -sfC --noconfirm

# Copy built package to local repo
echo "==> Adding package to local repo..."
cp -f ./*.pkg.tar.zst "$REPO_DIR/"

# Build the repo database
cd "$REPO_DIR"
repo-add ion-local.db.tar.gz ./*.pkg.tar.zst

echo ""
echo "==> Calamares package built and added to ${REPO_DIR}"
echo "    Run sudo ./scripts/build-iso.sh to build the ISO"
