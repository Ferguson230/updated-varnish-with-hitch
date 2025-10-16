#!/bin/bash
# Installer for the cPanel user-facing Varnish plugin.

set -euo pipefail
umask 022

TARGET_DIR="/usr/local/cpanel/base/frontend/jupiter/varnish"
CGI_DIR="/usr/local/cpanel/base/frontend/jupiter/cgi"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../.. && pwd)"

install -d -m 0755 "${TARGET_DIR}"
install -d -m 0755 "${CGI_DIR}"

cp "${REPO_ROOT}/plugins/cpanel/static/index.php" "${TARGET_DIR}/index.php"
cp "${REPO_ROOT}/plugins/cpanel/static/index.html" "${TARGET_DIR}/index.html"
cp "${REPO_ROOT}/plugins/cpanel/static/app.css" "${TARGET_DIR}/app.css"
cp "${REPO_ROOT}/plugins/cpanel/static/app.js" "${TARGET_DIR}/app.js"
cp "${REPO_ROOT}/plugins/cpanel/cgi/varnish_user.cgi" "${CGI_DIR}/varnish_user.cgi"

chmod 0644 "${TARGET_DIR}/index.php" "${TARGET_DIR}/index.html" "${TARGET_DIR}/app.css" "${TARGET_DIR}/app.js"
chmod 0755 "${CGI_DIR}/varnish_user.cgi"

# Create a simple dynamic icon list entry for cPanel
DYNAMICUI_DIR="/var/cpanel/dynamicui/jupiter/Software"
install -d -m 0755 "${DYNAMICUI_DIR}"

cat > "${DYNAMICUI_DIR}/varnish.yaml" <<'DYNAMICUI'
---
id: varnish_edge_accelerator
name: Varnish Edge Accelerator
description: Manage Varnish cache for your website
url: varnish/index.html
icon: data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI0OCIgaGVpZ2h0PSI0OCI+PHBhdGggZmlsbD0iIzAwNzNhYSIgZD0iTTI0IDRMMCA0MCA0OCA0MHoiLz48L3N2Zz4=
order: 50
DYNAMICUI

chmod 0644 "${DYNAMICUI_DIR}/varnish.yaml"

# Rebuild the dynamicui cache
if [[ -x /usr/local/cpanel/bin/rebuild_sprites ]]; then
	/usr/local/cpanel/bin/rebuild_sprites --all >/dev/null 2>&1 || true
fi

cat <<'EOF'
cPanel Varnish plugin installed.
Users can access "Varnish Edge Accelerator" in the Software section of cPanel.
Direct URL: https://your-server:2083/frontend/jupiter/varnish/index.live.php

Next steps:
  1. Configure sudoers so cPanel users can call varnishctl flush/purge if desired.
  2. Users may need to refresh cPanel or log out/in to see the new plugin.
EOF
