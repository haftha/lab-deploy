#!/usr/bin/env bash
# prepare-debian-live.sh
# Download-once, reuse-many strategy for Debian Live boot files.
# Prerequisites: wget, p7zip-full
# Usage: ./prepare-debian-live.sh

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
DEBIAN_VERSION="13.3.0"
ARCH="amd64"
FLAVOUR="standard"
ISO_NAME="debian-live-${DEBIAN_VERSION}-${ARCH}-${FLAVOUR}.iso"
ISO_URL="https://cdimage.debian.org/cdimage/release/current-live/${ARCH}/iso-hybrid/${ISO_NAME}"
CHECKSUM_URL="$(dirname "${ISO_URL}")/SHA256SUMS"

CACHE_DIR="${HOME}/.cache/lab-deploy"
ISO_CACHE="${CACHE_DIR}/${ISO_NAME}"
DEST_DIR="$(cd "$(dirname "$0")" && pwd)/debian-live-files"

VMLINUZ_PATH="live/vmlinuz"
INITRD_PATH="live/initrd.img"
# ─────────────────────────────────────────────────────────────────────────────

info()  { echo "[INFO]  $*"; }
warn()  { echo "[WARN]  $*" >&2; }
error() { echo "[ERROR] $*" >&2; exit 1; }

check_prereqs() {
    local missing=()
    for cmd in wget 7z; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required tools: ${missing[*]}\nInstall with: sudo apt install wget p7zip-full"
    fi
}

verify_checksum() {
    local iso="$1"
    info "Fetching checksum from ${CHECKSUM_URL} …"
    local expected
    expected=$(wget -qO- "${CHECKSUM_URL}" | awk -v iso="${ISO_NAME}" '$2 == iso {print $1}')
    info "Verifying SHA256 checksum …"
    local actual
    actual=$(sha256sum "${iso}" | awk '{print $1}')
    if [[ "${expected}" != "${actual}" ]]; then
        warn "Checksum mismatch — removing corrupt file."
        rm -f "${iso}"
        return 1
    fi
    info "Checksum OK."
    return 0
}

download_iso() {
    mkdir -p "${CACHE_DIR}"
    info "Downloading ${ISO_NAME} …"
    wget --show-progress -O "${ISO_CACHE}.tmp" "${ISO_URL}"
    mv "${ISO_CACHE}.tmp" "${ISO_CACHE}"
}

extract_boot_files() {
    mkdir -p "${DEST_DIR}"
    info "Extracting boot files from ISO …"
    7z e "${ISO_CACHE}" "${VMLINUZ_PATH}" "${INITRD_PATH}" -o"${DEST_DIR}" -y
    [[ -f "${DEST_DIR}/vmlinuz" ]]   || error "vmlinuz not found after extraction."
    [[ -f "${DEST_DIR}/initrd.img" ]] || error "initrd.img not found after extraction."
    info "Boot files extracted to ${DEST_DIR}/"
}

# ── Main ─────────────────────────────────────────────────────────────────────
check_prereqs

VMLINUZ_EXISTS=false
INITRD_EXISTS=false
[[ -f "${DEST_DIR}/vmlinuz" ]]    && VMLINUZ_EXISTS=true
[[ -f "${DEST_DIR}/initrd.img" ]] && INITRD_EXISTS=true

if $VMLINUZ_EXISTS && $INITRD_EXISTS; then
    info "Boot files already present in ${DEST_DIR}/ — nothing to do."
    exit 0
fi

# Ensure a valid ISO is cached
if [[ -f "${ISO_CACHE}" ]]; then
    info "ISO found in cache: ${ISO_CACHE}"
    verify_checksum "${ISO_CACHE}" || { download_iso && verify_checksum "${ISO_CACHE}"; }
else
    download_iso
    verify_checksum "${ISO_CACHE}" || error "Downloaded ISO failed checksum — aborting."
fi

extract_boot_files
info "Done. Run 'vagrant up lab-deploy-server' to start the deploy server."
