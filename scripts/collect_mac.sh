#!/usr/bin/env bash
# collect_mac.sh — ARP-scan the lab subnet and write discovered machines to
#                  config/machines.yml on the deploy server.
# Usage: sudo collect_mac.sh [subnet]
#
# Default subnet: 192.168.1.0/24
# Requires: arp-scan, python3-yaml

set -euo pipefail

SUBNET="${1:-192.168.1.0/24}"
OUTPUT_FILE="${OUTPUT_FILE:-/vagrant/config/machines.yml}"
IP_START=101
[[ $EUID -ne 0 ]] && { echo "Run as root (sudo)."; exit 1; }

command -v arp-scan &>/dev/null || { echo "arp-scan not installed."; exit 1; }

echo "Scanning ${SUBNET} …"
SCAN=$(arp-scan "${SUBNET}" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' || true)

if [[ -z "${SCAN}" ]]; then
    echo "No hosts discovered."
    exit 0
fi

echo "Discovered hosts:"
echo "${SCAN}"

python3 - <<EOF
import re, yaml, sys

scan = """${SCAN}"""
machines = []
index = ${IP_START}
for line in scan.strip().splitlines():
    parts = line.split()
    if len(parts) >= 2:
        ip, mac = parts[0], parts[1]
        name = f"client{index - ${IP_START} + 1:02d}"
        machines.append({"name": name, "mac": mac, "ip": ip})
        index += 1

with open("${OUTPUT_FILE}", "w") as f:
    yaml.dump({"machines": machines}, f, default_flow_style=False)

print(f"Written {len(machines)} machine(s) to ${OUTPUT_FILE}")
EOF
