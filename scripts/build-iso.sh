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

# Make local repo available if it exists (for calamares, etc.)
REPO_DIR="${OUT_DIR}/repo"
HAVE_CALAMARES=false
if [[ -d "$REPO_DIR" && -f "$REPO_DIR/ion-local.db.tar.gz" ]]; then
  echo "==> Copying local repo to /tmp/ion-repo..."
  mkdir -p /tmp/ion-repo
  cp -f "$REPO_DIR"/* /tmp/ion-repo/
  HAVE_CALAMARES=true
else
  echo "==> Warning: No local repo found at ${REPO_DIR}"
  echo "    Calamares will not be available. Run ./scripts/build-calamares.sh first."
  # Create an empty repo so pacman.conf's [ion-local] doesn't cause a sync failure
  mkdir -p /tmp/ion-repo
  repo-add /tmp/ion-repo/ion-local.db.tar.gz
fi

# Build a working copy of the profile so we can modify packages if needed
PROFILE_DIR="${PROJECT_ROOT}/iso"
if [[ "$HAVE_CALAMARES" == false ]]; then
  echo "==> Stripping calamares packages from build profile..."
  PROFILE_DIR="$(mktemp -d)"
  cp -a "${PROJECT_ROOT}/iso/." "$PROFILE_DIR/"
  # Remove calamares-git (only available from local repo)
  sed -i '/^calamares-git$/d' "$PROFILE_DIR/packages.x86_64"
fi

# Use mkarchiso (from archiso package) as the base build tool.
# Ion customizes the profile in iso/.
mkarchiso -v \
  -w "${WORK_DIR}" \
  -o "${OUT_DIR}" \
  "$PROFILE_DIR"

# Clean up temp profile if created
if [[ "$PROFILE_DIR" != "${PROJECT_ROOT}/iso" ]]; then
  rm -rf "$PROFILE_DIR"
fi

echo "==> ISO build complete. Output:"
ls -lh "${OUT_DIR}"/*.iso 2>/dev/null || echo "    (no ISO found — check build logs)"
