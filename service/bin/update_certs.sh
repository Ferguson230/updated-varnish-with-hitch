#!/bin/bash
# Proxy script to refresh Hitch certificates.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
PRIMARY="${ROOT_DIR%/service}/update_hitch_certs.sh"
FALLBACK="/usr/local/bin/update_hitch_certs.sh"

if [[ -x "${PRIMARY}" ]]; then
    exec "${PRIMARY}" "$@"
elif [[ -x "${FALLBACK}" ]]; then
    exec "${FALLBACK}" "$@"
else
    echo "update_hitch_certs.sh not found" >&2
    exit 1
fi
