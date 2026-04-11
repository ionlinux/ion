#!/usr/bin/env bash
#
# build-walker.sh — Build walker from AUR into a local pacman repo
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPO_DIR="${PROJECT_ROOT}/out/repo"
BUILD_DIR="/tmp/ion-walker-build"

echo "==> Building walker from AUR"

mkdir -p "$REPO_DIR" "$BUILD_DIR"

if [[ -d "${BUILD_DIR}/walker" ]]; then
  cd "${BUILD_DIR}/walker"
  git pull
else
  git clone https://aur.archlinux.org/walker.git "${BUILD_DIR}/walker"
  cd "${BUILD_DIR}/walker"
fi

echo "==> Building package..."
makepkg -sfC --noconfirm

echo "==> Adding package to local repo..."
cp -f ./*.pkg.tar.zst "$REPO_DIR/"

cd "$REPO_DIR"
repo-add ion-local.db.tar.gz ./*.pkg.tar.zst

echo ""
echo "==> walker package built and added to ${REPO_DIR}"
