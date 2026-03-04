#!/usr/bin/env bash
# multicast_deploy.sh — Deploy a disk image to lab clients via udpcast multicast.
# Usage: sudo multicast_deploy.sh <no_of_clients> <image-name>
#
# Clients must already be waiting in the PXE boot menu (deploy mode) before
# this script is run. udpcast will start transmission once <no_of_clients>
# receivers have connected.

set -euo pipefail

IMAGES_DIR="${IMAGES_DIR:-/srv/images}"
LIB_DIR="/usr/local/lib/lab-deploy"

# shellcheck source=/dev/null
source "${LIB_DIR}/udpcast_functions.sh"
# shellcheck source=/dev/null
source "${LIB_DIR}/partclone_functions.sh"

usage() {
    echo "Usage: $(basename "$0") <no_of_clients> <image-name>"
    echo "       sudo $(basename "$0") 20 debian13-lab"
    exit 1
}

[[ $# -lt 2 ]] && usage
[[ $EUID -ne 0 ]] && { echo "Run as root (sudo)."; exit 1; }

NUM_CLIENTS="$1"
IMAGE_NAME="$2"
IMAGE_DIR="${IMAGES_DIR}/${IMAGE_NAME}"

[[ -d "${IMAGE_DIR}" ]] || { echo "Image not found: ${IMAGE_DIR}"; exit 1; }

echo "[multicast_deploy] Deploying '${IMAGE_NAME}' to ${NUM_CLIENTS} client(s) …"
udpcast_send "${IMAGE_DIR}" "${NUM_CLIENTS}"
echo "[multicast_deploy] Deployment complete."
