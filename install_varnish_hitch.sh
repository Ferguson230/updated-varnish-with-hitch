#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVISIONER="${SCRIPT_DIR}/service/bin/provision.sh"

if [[ ! -x "${PROVISIONER}" ]]; then
    echo "Provisioner script not found or not executable: ${PROVISIONER}" >&2
    exit 1
fi

exec "${PROVISIONER}" "$@"
