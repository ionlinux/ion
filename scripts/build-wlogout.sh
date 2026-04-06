#!/usr/bin/env bash
#
# build-wlogout.sh — Build wlogout from AUR into a local pacman repo
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPO_DIR="${PROJECT_ROOT}/out/repo"
BUILD_DIR="/tmp/ion-wlogout-build"

echo "==> Building wlogout from AUR"

mkdir -p "$REPO_DIR" "$BUILD_DIR"

if [[ -d "${BUILD_DIR}/wlogout" ]]; then
  cd "${BUILD_DIR}/wlogout"
  git pull
else
  git clone https://aur.archlinux.org/wlogout.git "${BUILD_DIR}/wlogout"
  cd "${BUILD_DIR}/wlogout"
fi

echo "==> Building package..."
makepkg -sfC --noconfirm

echo "==> Adding package to local repo..."
cp -f ./*.pkg.tar.zst "$REPO_DIR/"

cd "$REPO_DIR"
repo-add ion-local.db.tar.gz ./*.pkg.tar.zst

echo ""
echo "==> wlogout package built and added to ${REPO_DIR}"
