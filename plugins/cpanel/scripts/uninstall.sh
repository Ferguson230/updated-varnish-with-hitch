#!/bin/bash
# Uninstaller for the cPanel Varnish Manager plugin.

set -euo pipefail

# Plugin directories (same as install.sh)
PLUGIN_BASE_DIR="/usr/local/cpanel/base/3rdparty/plugins/varnish_manager"
PLUGIN_LEGACY_DIR="/usr/local/cpanel/base/frontend/jupiter/varnish_manager"

# Remove legacy DynamicUI registration if it exists
if [[ -f /var/cpanel/dynamicui/jupiter/Software/varnish.yaml ]]; then
    rm -f /var/cpanel/dynamicui/jupiter/Software/varnish.yaml
    echo "Removed legacy DynamicUI registration"
fi

# Remove from 3rdparty location
if [[ -d "${PLUGIN_BASE_DIR}" ]]; then
    rm -rf "${PLUGIN_BASE_DIR}"
    echo "Removed plugin from: ${PLUGIN_BASE_DIR}"
fi

# Remove from legacy location
if [[ -d "${PLUGIN_LEGACY_DIR}" ]]; then
    rm -rf "${PLUGIN_LEGACY_DIR}"
    echo "Removed plugin from: ${PLUGIN_LEGACY_DIR}"
fi

# Rebuild cPanel UI
if [[ -x /usr/local/cpanel/bin/rebuild_sprites ]]; then
    /usr/local/cpanel/bin/rebuild_sprites --all >/dev/null 2>&1 || true
fi

cat <<'EOF'
✓ cPanel Varnish Manager plugin uninstalled successfully!

The plugin has been removed from all possible locations:
  - /usr/local/cpanel/base/3rdparty/plugins/varnish_manager
  - /usr/local/cpanel/base/frontend/jupiter/varnish_manager
  - /var/cpanel/dynamicui/jupiter/Software/varnish.yaml

Note: The backend Varnish service and WHM plugin are NOT affected by this uninstallation.
EOF

