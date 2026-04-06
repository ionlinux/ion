#!/usr/bin/env bash
#
# build-iso.sh — Build the Ion Linux live/install ISO
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WORK_DIR="${PROJECT_ROOT}/build"
OUT_DIR="${PROJECT_ROOT}/out"

if [[ $EUID -ne 0 ]]; then
  echo "error: this script must be run as root" >&2
  exit 1
fi

echo "==> Building Ion Linux ISO"
echo "    Work directory: ${WORK_DIR}"
echo "    Output directory: ${OUT_DIR}"

mkdir -p "${WORK_DIR}" "${OUT_DIR}"

# Make local repo available (for calamares, etc.)
# Build calamares first if the repo doesn't exist yet
REPO_DIR="${OUT_DIR}/repo"
if [[ ! -d "$REPO_DIR" || ! -f "$REPO_DIR/ion-local.db.tar.gz" ]]; then
  echo "==> Local repo not found — building Calamares first..."
  # Ensure out/repo is writable by the unprivileged user for makepkg
  mkdir -p "$REPO_DIR"
  chown "${SUDO_USER:-nobody}:${SUDO_USER:-nobody}" "$REPO_DIR"
  sudo -u "${SUDO_USER:-nobody}" "${SCRIPT_DIR}/build-calamares.sh"
fi

echo "==> Copying local repo to /tmp/ion-repo..."
mkdir -p /tmp/ion-repo
cp -f "$REPO_DIR"/* /tmp/ion-repo/

# Use mkarchiso (from archiso package) as the base build tool.
# Ion customizes the profile in iso/.
mkarchiso -v \
  -w "${WORK_DIR}" \
  -o "${OUT_DIR}" \
  "${PROJECT_ROOT}/iso"

echo "==> ISO build complete. Output:"
ls -lh "${OUT_DIR}"/*.iso 2>/dev/null || echo "    (no ISO found — check build logs)"
