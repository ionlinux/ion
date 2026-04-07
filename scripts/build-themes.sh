#!/usr/bin/env bash
#
# build-themes.sh — Build Sours icon theme and Sweet GTK theme into a local pacman repo
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPO_DIR="${PROJECT_ROOT}/out/repo"
BUILD_DIR="/tmp/ion-themes-build"

mkdir -p "$REPO_DIR" "$BUILD_DIR"

# Build a package from an IONBUILD in packages/
build_ionbuild() {
  local pkg="$1"
  local pkg_dir="$2"
  echo "==> Building ${pkg} from IONBUILD"

  mkdir -p "${BUILD_DIR}/${pkg}"
  cp "${pkg_dir}/IONBUILD" "${BUILD_DIR}/${pkg}/PKGBUILD"
  cd "${BUILD_DIR}/${pkg}"

  makepkg -sfC --noconfirm
  cp -f ./*.pkg.tar.zst "$REPO_DIR/"
}

build_ionbuild sours-icon-theme-git "${PROJECT_ROOT}/packages/sours-icon-theme"
build_ionbuild sweet-gtk-theme "${PROJECT_ROOT}/packages/sweet-gtk-theme"

cd "$REPO_DIR"
repo-add ion-local.db.tar.gz ./*.pkg.tar.zst

echo ""
echo "==> Sours icon theme and Sweet GTK theme built and added to ${REPO_DIR}"
