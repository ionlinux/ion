#!/usr/bin/env bash
#
# build-elephant-desktopapplications.sh — Build elephant-desktopapplications from AUR into a local pacman repo
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPO_DIR="${PROJECT_ROOT}/out/repo"
BUILD_DIR="/tmp/ion-elephant-desktopapplications-build"

echo "==> Building elephant-desktopapplications from AUR"

mkdir -p "$REPO_DIR" "$BUILD_DIR"

if [[ -d "${BUILD_DIR}/elephant-desktopapplications" ]]; then
  cd "${BUILD_DIR}/elephant-desktopapplications"
  git pull
else
  git clone https://aur.archlinux.org/elephant-desktopapplications.git "${BUILD_DIR}/elephant-desktopapplications"
  cd "${BUILD_DIR}/elephant-desktopapplications"
fi

echo "==> Building package..."
makepkg -sfC --noconfirm

echo "==> Adding package to local repo..."
cp -f ./*.pkg.tar.zst "$REPO_DIR/"

cd "$REPO_DIR"
repo-add ion-local.db.tar.gz ./*.pkg.tar.zst

echo ""
echo "==> elephant-desktopapplications package built and added to ${REPO_DIR}"
