#!/bin/bash

set -euo pipefail

TARGET_DIR="/usr/local/cpanel/whostmgr/docroot/cgi/varnish"
SERVICE_ROOT="/opt/varnish-whm-manager"

rm -f /usr/local/bin/varnish-provision /usr/local/bin/varnishctl /usr/local/bin/update_hitch_certs.sh
rm -rf "${TARGET_DIR}"
rm -rf "${SERVICE_ROOT}"

echo "WHM Varnish Cache Manager removed."
