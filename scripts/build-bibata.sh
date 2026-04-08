#!/usr/bin/env bash
#
# build-bibata.sh — Build Bibata cursor theme into the local pacman repo
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPO_DIR="${PROJECT_ROOT}/out/repo"
BUILD_DIR="/tmp/ion-bibata-build"

mkdir -p "$REPO_DIR" "$BUILD_DIR"

echo "==> Building bibata-cursor-theme-bin from AUR"
cd "$BUILD_DIR"
rm -rf bibata-cursor-theme-bin
git clone https://aur.archlinux.org/bibata-cursor-theme-bin.git
cd bibata-cursor-theme-bin
makepkg -sfC --noconfirm

cp -f ./*.pkg.tar.zst "$REPO_DIR/"
cd "$REPO_DIR"
repo-add ion-local.db.tar.gz ./*.pkg.tar.zst

echo ""
echo "==> Bibata cursor theme built and added to ${REPO_DIR}"
