#!/bin/bash

set -euo pipefail

TARGET_DIR="/usr/local/cpanel/base/frontend/jupiter/varnish"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../.. && pwd)"

/usr/local/cpanel/bin/manage_plugins uninstall "${REPO_ROOT}/plugins/cpanel/varnish.cpanelplugin" || true
rm -rf "${TARGET_DIR}"

echo "cPanel Varnish plugin removed."
