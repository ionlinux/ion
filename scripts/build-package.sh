#!/usr/bin/env bash
#
# build-package.sh — Build an Ion Linux package from an IONBUILD file
#
# Usage: ./scripts/build-package.sh <package-dir>
#
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <package-dir>" >&2
  echo "  e.g. $0 packages/base" >&2
  exit 1
fi

PKG_DIR="$(realpath "$1")"
IONBUILD="${PKG_DIR}/IONBUILD"

if [[ ! -f "$IONBUILD" ]]; then
  echo "error: no IONBUILD found in ${PKG_DIR}" >&2
  exit 1
fi

echo "==> Building package from ${IONBUILD}"

# IONBUILD files are PKGBUILD-compatible — use makepkg
cd "$PKG_DIR"

# Symlink IONBUILD as PKGBUILD for makepkg compatibility
if [[ ! -f PKGBUILD ]]; then
  ln -sf IONBUILD PKGBUILD
fi

makepkg -sf --config "$(dirname "$(dirname "$PKG_DIR")")/configs/makepkg/makepkg.conf"

echo "==> Package built successfully"
ls -lh "$PKG_DIR"/*.pkg.tar.zst 2>/dev/null
