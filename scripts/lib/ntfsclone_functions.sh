#!/usr/bin/env bash
# ntfsclone_functions.sh — Helpers for ntfsclone-based NTFS imaging.
# Sourced by save_image.sh when ntfsclone is preferred over partclone.

# ntfsclone_save PARTITION OUTPUT_FILE
ntfsclone_save() {
    local part="$1"
    local outfile="$2"
    echo "ntfsclone: capturing ${part} → ${outfile} …"
    ntfsclone --save-image -O - "${part}" | gzip > "${outfile}"
}

# ntfsclone_restore INPUT_FILE PARTITION
ntfsclone_restore() {
    local infile="$1"
    local part="$2"
    echo "ntfsclone: restoring ${infile} → ${part} …"
    zcat "${infile}" | ntfsclone --restore-image -O "${part}" -
}
