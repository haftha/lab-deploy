#!/usr/bin/env bash
# save_image.sh — Capture a disk image from the golden client via partclone.
# Usage: sudo save_image.sh <image-name>
#
# The golden client must be booted into Debian Live and listening on the
# deploy server's network. The image is stored under /srv/images/<image-name>/.

set -euo pipefail

IMAGES_DIR="${IMAGES_DIR:-/srv/images}"
LIB_DIR="/usr/local/lib/lab-deploy"

# shellcheck source=/dev/null
source "${LIB_DIR}/partclone_functions.sh"

usage() {
    echo "Usage: $(basename "$0") <image-name>"
    echo "       sudo $(basename "$0") my-lab-image"
    exit 1
}

[[ $# -lt 1 ]] && usage
[[ $EUID -ne 0 ]] && { echo "Run as root (sudo)."; exit 1; }

IMAGE_NAME="$1"
IMAGE_DIR="${IMAGES_DIR}/${IMAGE_NAME}"

mkdir -p "${IMAGE_DIR}"

echo "[save_image] Starting image capture → ${IMAGE_DIR}"
partclone_save "${IMAGE_DIR}"
echo "[save_image] Image saved successfully to ${IMAGE_DIR}"
