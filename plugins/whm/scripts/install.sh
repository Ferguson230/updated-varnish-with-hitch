#!/bin/bash
# Installer for the WHM Varnish Cache Manager plugin.

set -euo pipefail
umask 022

TARGET_DIR="/usr/local/cpanel/whostmgr/docroot/cgi/varnish"
SERVICE_ROOT="/opt/varnish-whm-manager"
SERVICE_BIN="${SERVICE_ROOT}/bin"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_PATH}/../../.." && pwd)"
APPCONF_DIR="/usr/local/cpanel/etc/appconfig/apps"
APPCONF_BIN="/usr/local/cpanel/bin"
NEW_APP_NAME="varnish_whm_manager"
NEW_APPCONF_SRC="${REPO_ROOT}/plugins/whm/${NEW_APP_NAME}.conf"
NEW_APPCONF_DST="${APPCONF_DIR}/${NEW_APP_NAME}.conf"

install -d -m 0755 "${TARGET_DIR}"
install -d -m 0755 "${TARGET_DIR}/assets"
install -d -m 0755 "${SERVICE_ROOT}"
install -d -m 0755 "${SERVICE_ROOT}/bin"
install -d -m 0755 "${SERVICE_ROOT}/config"
install -d -m 0755 "${SERVICE_ROOT}/config/snippets"

cp "${REPO_ROOT}/plugins/whm/cgi/index.cgi" "${TARGET_DIR}/index.cgi"
cp "${REPO_ROOT}/plugins/whm/cgi/varnish_manager.cgi" "${TARGET_DIR}/varnish_manager.cgi"
chmod 0755 "${TARGET_DIR}/index.cgi" "${TARGET_DIR}/varnish_manager.cgi"

# Backwards compatibility with legacy entry points
ln -sf "${TARGET_DIR}/varnish_manager.cgi" "${TARGET_DIR}/whm_varnish_manager.cgi"

cp "${REPO_ROOT}/plugins/whm/static/index.html" "${TARGET_DIR}/index.html"
cp "${REPO_ROOT}/plugins/whm/static/app.css" "${TARGET_DIR}/assets/app.css"
cp "${REPO_ROOT}/plugins/whm/static/app.js" "${TARGET_DIR}/assets/app.js"
chmod 0644 "${TARGET_DIR}/index.html" "${TARGET_DIR}/assets/app.css" "${TARGET_DIR}/assets/app.js"

cp "${REPO_ROOT}/service/bin/"*.sh "${SERVICE_BIN}/"
chmod 0755 "${SERVICE_BIN}"/*.sh

cp "${REPO_ROOT}/service/config/default.vcl" "${SERVICE_ROOT}/config/default.vcl"
cp "${REPO_ROOT}/service/config/snippets/"*.vcl "${SERVICE_ROOT}/config/snippets/"
if [[ ! -f "${SERVICE_ROOT}/config/settings.json" ]]; then
  cp "${REPO_ROOT}/service/config/settings.json" "${SERVICE_ROOT}/config/settings.json"
fi
chmod 0644 "${SERVICE_ROOT}/config/default.vcl"
chmod 0644 "${SERVICE_ROOT}/config/snippets/"*.vcl
chmod 0644 "${SERVICE_ROOT}/config/settings.json"

ln -sf "${SERVICE_BIN}/provision.sh" /usr/local/bin/varnish-provision
ln -sf "${SERVICE_BIN}/varnishctl.sh" /usr/local/bin/varnishctl
ln -sf "${REPO_ROOT}/update_hitch_certs.sh" /usr/local/bin/update_hitch_certs.sh

# Refresh WHM plugin registration with new AppConfig
install -d -m 0755 "${APPCONF_DIR}"
if [[ -f "${NEW_APPCONF_SRC}" ]]; then
  install -m 0644 "${NEW_APPCONF_SRC}" "${NEW_APPCONF_DST}"
  sed -i 's/\r$//' "${NEW_APPCONF_DST}" || true
  if [[ -x "${APPCONF_BIN}/register_appconfig" ]]; then
    "${APPCONF_BIN}/register_appconfig" "${NEW_APPCONF_DST}"
  fi
fi

cat <<'EOF'
WHM Varnish Cache Manager installed.
Next steps:
  1. Configure sudoers so cPanel users can call varnishctl flush/purge if desired.
  2. Visit WHM > Plugins > Varnish + Hitch Accelerator to use the interface.
EOF
