#!/bin/bash
# Installer for the cPanel user-facing Varnish Manager plugin.
# This follows the native cPanel plugin structure with install.json + .live.php

set -euo pipefail
umask 022

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../.. && pwd)"

# Plugin directory - using 3rdparty structure (newer cPanel versions)
PLUGIN_BASE_DIR="/usr/local/cpanel/base/3rdparty/plugins/varnish_manager"
PLUGIN_LEGACY_DIR="/usr/local/cpanel/base/frontend/jupiter/varnish_manager"

# Try 3rdparty first (newer cPanel), fall back to frontend (older cPanel)
if [[ -d /usr/local/cpanel/base/3rdparty/plugins ]]; then
    PLUGIN_DIR="${PLUGIN_BASE_DIR}"
    echo "Using 3rdparty plugin directory: ${PLUGIN_DIR}"
else
    PLUGIN_DIR="${PLUGIN_LEGACY_DIR}"
    echo "Using legacy frontend directory: ${PLUGIN_DIR}"
fi

# Create plugin directory
install -d -m 0755 "${PLUGIN_DIR}"

# Copy install.json (required for cPanel plugin registration)
cp "${REPO_ROOT}/plugins/cpanel/install.json" "${PLUGIN_DIR}/install.json"

# Copy main .live.php file (cPanel native entry point)
cp "${REPO_ROOT}/plugins/cpanel/varnish_manager.live.php" "${PLUGIN_DIR}/varnish_manager.live.php"

# Set correct permissions
chmod 0644 "${PLUGIN_DIR}/install.json"
chmod 0644 "${PLUGIN_DIR}/varnish_manager.live.php"

# Remove old DynamicUI registration if it exists
if [[ -f /var/cpanel/dynamicui/jupiter/Software/varnish.yaml ]]; then
    rm -f /var/cpanel/dynamicui/jupiter/Software/varnish.yaml
    echo "Removed legacy DynamicUI registration"
fi

# For backwards compatibility, also install to legacy location if needed
if [[ "${PLUGIN_DIR}" == "${PLUGIN_BASE_DIR}" ]] && [[ -d /usr/local/cpanel/base/frontend/jupiter ]]; then
    install -d -m 0755 "${PLUGIN_LEGACY_DIR}"
    cp "${REPO_ROOT}/plugins/cpanel/install.json" "${PLUGIN_LEGACY_DIR}/install.json"
    cp "${REPO_ROOT}/plugins/cpanel/varnish_manager.live.php" "${PLUGIN_LEGACY_DIR}/varnish_manager.live.php"
    chmod 0644 "${PLUGIN_LEGACY_DIR}/install.json"
    chmod 0644 "${PLUGIN_LEGACY_DIR}/varnish_manager.live.php"
fi

# Signal cPanel to reload plugin registry
if [[ -x /usr/local/cpanel/bin/rebuild_sprites ]]; then
    /usr/local/cpanel/bin/rebuild_sprites --all >/dev/null 2>&1 || true
fi

# Restart cPanel daemon to pick up new plugin
if [[ -x /usr/local/cpanel/bin/checkfilesystem ]]; then
    /usr/local/cpanel/bin/checkfilesystem >/dev/null 2>&1 || true
fi

cat <<'EOF'
✓ cPanel Varnish Manager plugin installed successfully!

Installation Details:
  - Plugin ID: varnish_manager
  - Entry Point: varnish_manager.live.php (cPanel native format)
  - Registration: install.json (feature manager compatible)

Access the plugin:
  - In cPanel: Software > Advanced > Varnish Manager
  - Direct URL: https://your-server:2083/frontend/jupiter/varnish_manager/varnish_manager.live.php

Next Steps:
  1. If your account is newly created, you may need to log out and log back into cPanel
  2. The plugin uses cPanel's native UAPI to discover your domains
  3. Cache operations require proper sudoers configuration (see main installation guide)

For debugging:
  - Check cPanel error log: tail -f /usr/local/cpanel/logs/error_log
  - Verify plugin file: ls -la "${PLUGIN_DIR}"
  - Test sudoers access: sudo /usr/local/bin/varnishctl status
EOF

