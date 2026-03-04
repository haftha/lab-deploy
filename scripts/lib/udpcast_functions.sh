#!/usr/bin/env bash
# udpcast_functions.sh — Helpers wrapping udp-sender / udp-receiver for
#                        multicast image deployment.
# Sourced by multicast_deploy.sh.

UDPCAST_INTERFACE="${UDPCAST_INTERFACE:-eth1}"
UDPCAST_PORT="${UDPCAST_PORT:-9000}"

# udpcast_send IMAGE_DIR NUM_RECEIVERS
# Sends all partition image files in IMAGE_DIR via udp-sender.
udpcast_send() {
    local image_dir="$1"
    local num_receivers="$2"
    local port="${UDPCAST_PORT}"

    for imgfile in "${image_dir}"/part*.img.gz; do
        [[ -f "${imgfile}" ]] || continue
        echo "udp-sender: sending ${imgfile} on port ${port} (waiting for ${num_receivers} receiver(s)) …"
        udp-sender \
            --interface "${UDPCAST_INTERFACE}" \
            --portbase  "${port}" \
            --min-receivers "${num_receivers}" \
            --file       "${imgfile}"
        port=$((port + 2))
    done
}

# udpcast_receive IMAGE_DIR
# Receives all partition image files from an udp-sender into IMAGE_DIR.
udpcast_receive() {
    local image_dir="$1"
    local sender_ip="$2"
    local port="${UDPCAST_PORT}"

    mkdir -p "${image_dir}"
    local idx=0
    while true; do
        local outfile="${image_dir}/part${idx}.img.gz"
        echo "udp-receiver: receiving → ${outfile} from ${sender_ip}:${port} …"
        udp-receiver \
            --interface "${UDPCAST_INTERFACE}" \
            --portbase  "${port}" \
            --file      "${outfile}" || break
        idx=$((idx + 1))
        port=$((port + 2))
    done
}
