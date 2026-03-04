#!/usr/bin/env bash
# wake_up_machines.sh — Send Wake-on-LAN magic packets to all lab machines.
# Usage: sudo wake_up_machines.sh [machines_yml]
#
# Reads machine definitions from config/machines.yml (or the path passed as
# the first argument). Requires 'etherwake' and 'python3-yaml'.

set -euo pipefail

CONFIG_FILE="${1:-/vagrant/config/machines.yml}"
[[ $EUID -ne 0 ]] && { echo "Run as root (sudo)."; exit 1; }
[[ -f "${CONFIG_FILE}" ]] || { echo "machines.yml not found: ${CONFIG_FILE}"; exit 1; }

command -v etherwake &>/dev/null || { echo "etherwake not installed."; exit 1; }
command -v python3   &>/dev/null || { echo "python3 not installed.";  exit 1; }

MACS=$(python3 - <<EOF
import yaml, sys
with open("${CONFIG_FILE}") as f:
    data = yaml.safe_load(f)
for m in data.get("machines", []):
    print(m["mac"])
EOF
)

if [[ -z "${MACS}" ]]; then
    echo "No machines found in ${CONFIG_FILE}."
    exit 0
fi

while IFS= read -r mac; do
    echo "Waking ${mac} …"
    etherwake "${mac}" || true
    sleep 0.2
done <<< "${MACS}"

echo "Wake-on-LAN packets sent."
