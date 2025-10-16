#!/bin/bash

set -euo pipefail

TARGET_DIR="/usr/local/cpanel/whostmgr/docroot/cgi/varnish"
SERVICE_ROOT="/opt/varnish-whm-manager"
APPCONF_DIR="/usr/local/cpanel/etc/appconfig"
APPCONF_BIN="/usr/local/cpanel/bin"
NEW_APP_NAME="varnish_whm_manager"
LEGACY_APP_NAME="varnish_cache_manager"

rm -f /usr/local/bin/varnish-provision /usr/local/bin/varnishctl /usr/local/bin/update_hitch_certs.sh
rm -f "${TARGET_DIR}/whm_varnish_manager.cgi"
rm -rf "${TARGET_DIR}"
rm -rf "${SERVICE_ROOT}"

if [[ -x "${APPCONF_BIN}/unregister_appconfig" ]]; then
	"${APPCONF_BIN}/unregister_appconfig" "${NEW_APP_NAME}" || true
fi
rm -f "${APPCONF_DIR}/${NEW_APP_NAME}.conf"

if [[ -x "${APPCONF_BIN}/unregister_appconfig" ]]; then
	"${APPCONF_BIN}/unregister_appconfig" "${LEGACY_APP_NAME}" || true
fi
rm -f "${APPCONF_DIR}/${LEGACY_APP_NAME}.conf"

echo "WHM Varnish Cache Manager removed."
