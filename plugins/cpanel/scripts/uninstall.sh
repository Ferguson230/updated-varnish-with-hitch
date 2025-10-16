#!/bin/bash
# Uninstaller for the cPanel user-facing Varnish plugin.

set -euo pipefail

TARGET_DIR="/usr/local/cpanel/base/frontend/jupiter/varnish"
DYNAMICUI_FILE="/var/cpanel/dynamicui/jupiter/Software/varnish.yaml"

# Remove dynamic UI entry
if [[ -f "${DYNAMICUI_FILE}" ]]; then
	rm -f "${DYNAMICUI_FILE}"
	if [[ -x /usr/local/cpanel/bin/rebuild_sprites ]]; then
		/usr/local/cpanel/bin/rebuild_sprites --all >/dev/null 2>&1 || true
	fi
fi

# Remove plugin files
if [[ -d "${TARGET_DIR}" ]]; then
	rm -rf "${TARGET_DIR}"
fi

echo "cPanel Varnish plugin uninstalled."
