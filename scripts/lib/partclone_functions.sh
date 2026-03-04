#!/usr/bin/env bash
# partclone_functions.sh — Shared helpers for partclone-based disk imaging.
# Sourced by save_image.sh and multicast_deploy.sh.

PARTCLONE_OPTS="-z -c"   # compress + checksum

# partclone_save IMAGE_DIR
# Detects disk/partitions on the golden client and captures them.
partclone_save() {
    local image_dir="$1"
    local disk
    disk=$(lsblk -dpno NAME,TYPE | awk '$2=="disk"{print $1; exit}')
    [[ -z "${disk}" ]] && { echo "No disk found."; return 1; }

    echo "Capturing ${disk} → ${image_dir} …"
    local idx=0
    for part in $(lsblk -pno NAME "${disk}" | tail -n +2); do
        local fstype
        fstype=$(lsblk -no FSTYPE "${part}" 2>/dev/null || echo "")
        local outfile="${image_dir}/part${idx}.img.gz"
        case "${fstype}" in
            ext2|ext3|ext4)
                partclone.ext4 ${PARTCLONE_OPTS} -s "${part}" | gzip > "${outfile}"
                ;;
            ntfs)
                partclone.ntfs ${PARTCLONE_OPTS} -s "${part}" | gzip > "${outfile}"
                ;;
            vfat|fat32)
                partclone.fat32 ${PARTCLONE_OPTS} -s "${part}" | gzip > "${outfile}"
                ;;
            *)
                partclone.dd ${PARTCLONE_OPTS} -s "${part}" | gzip > "${outfile}"
                ;;
        esac
        echo "  Saved ${part} → ${outfile}"
        idx=$((idx + 1))
    done

    # Save partition table
    sfdisk --dump "${disk}" > "${image_dir}/partition_table.sfdisk"
    echo "  Saved partition table → ${image_dir}/partition_table.sfdisk"
}

# partclone_restore IMAGE_DIR DISK
# Restores a captured image to the target disk.
partclone_restore() {
    local image_dir="$1"
    local disk="$2"

    [[ -d "${image_dir}" ]] || { echo "Image directory not found: ${image_dir}"; return 1; }
    [[ -b "${disk}" ]]      || { echo "Target disk not found: ${disk}";           return 1; }

    echo "Restoring partition table to ${disk} …"
    sfdisk "${disk}" < "${image_dir}/partition_table.sfdisk"
    partprobe "${disk}"
    sleep 2

    local idx=0
    for part in $(lsblk -pno NAME "${disk}" | tail -n +2); do
        local imgfile="${image_dir}/part${idx}.img.gz"
        [[ -f "${imgfile}" ]] || continue
        echo "  Restoring ${imgfile} → ${part} …"
        local fstype
        fstype=$(zcat "${imgfile}" | head -c 1048576 | partclone.info -s - 2>/dev/null | awk '/^File system/{print $NF}' || echo "dd")
        case "${fstype}" in
            ext2|ext3|ext4) zcat "${imgfile}" | partclone.ext4  -r -s - -o "${part}" ;;
            NTFS|ntfs)      zcat "${imgfile}" | partclone.ntfs  -r -s - -o "${part}" ;;
            FAT|vfat)       zcat "${imgfile}" | partclone.fat32 -r -s - -o "${part}" ;;
            *)              zcat "${imgfile}" | partclone.dd    -r -s - -o "${part}" ;;
        esac
        idx=$((idx + 1))
    done
    echo "Restore complete."
}
