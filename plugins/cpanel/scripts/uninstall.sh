#!/bin/bash

set -euo pipefail

TARGET_DIR="/usr/local/cpanel/base/frontend/jupiter/varnish"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../.. && pwd)"

if [[ -x /usr/local/cpanel/bin/unregister_cpanelplugin ]]; then
	/usr/local/cpanel/bin/unregister_cpanelplugin "${REPO_ROOT}/plugins/cpanel/varnish.cpanelplugin" || true
elif [[ -x /usr/local/cpanel/bin/manage_plugins ]]; then
	/usr/local/cpanel/bin/manage_plugins uninstall "${REPO_ROOT}/plugins/cpanel/varnish.cpanelplugin" || true
fi
rm -rf "${TARGET_DIR}"

echo "cPanel Varnish plugin removed."
