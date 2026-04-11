#!/usr/bin/env bash
#
# build-elephant.sh — Build elephant from AUR into a local pacman repo
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPO_DIR="${PROJECT_ROOT}/out/repo"
BUILD_DIR="/tmp/ion-elephant-build"

echo "==> Building elephant from AUR"

mkdir -p "$REPO_DIR" "$BUILD_DIR"

if [[ -d "${BUILD_DIR}/elephant" ]]; then
  cd "${BUILD_DIR}/elephant"
  git pull
else
  git clone https://aur.archlinux.org/elephant.git "${BUILD_DIR}/elephant"
  cd "${BUILD_DIR}/elephant"
fi

echo "==> Building package..."
makepkg -sfC --noconfirm

echo "==> Adding package to local repo..."
cp -f ./*.pkg.tar.zst "$REPO_DIR/"

cd "$REPO_DIR"
repo-add ion-local.db.tar.gz ./*.pkg.tar.zst

echo ""
echo "==> elephant package built and added to ${REPO_DIR}"
