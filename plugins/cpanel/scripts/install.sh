#!/bin/bash
# Installer for the cPanel user-facing Varnish plugin.

set -euo pipefail
umask 022

TARGET_DIR="/usr/local/cpanel/base/frontend/jupiter/varnish"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../.. && pwd)"

install -d -m 0755 "${TARGET_DIR}"

cp "${REPO_ROOT}/plugins/cpanel/static/index.live.php" "${TARGET_DIR}/index.live.php"
cp "${REPO_ROOT}/plugins/cpanel/static/index.html" "${TARGET_DIR}/index.html"
cp "${REPO_ROOT}/plugins/cpanel/static/app.css" "${TARGET_DIR}/app.css"
cp "${REPO_ROOT}/plugins/cpanel/static/app.js" "${TARGET_DIR}/app.js"
cp "${REPO_ROOT}/plugins/cpanel/cgi/varnish_user.cgi" "${TARGET_DIR}/varnish_user.cgi"

chmod 0644 "${TARGET_DIR}/index.live.php" "${TARGET_DIR}/index.html" "${TARGET_DIR}/app.css" "${TARGET_DIR}/app.js"
chmod 0755 "${TARGET_DIR}/varnish_user.cgi"

/usr/local/cpanel/bin/manage_plugins install "${REPO_ROOT}/plugins/cpanel/varnish.cpanelplugin"

cat <<'EOF'
cPanel Varnish plugin installed.
Users will find "Varnish Edge Accelerator" inside the Software section of Jupiter.
Ensure sudoers entries exist to allow varnishctl purge/flush from user accounts.
EOF
