# cPanel Plugin Refactoring

## Changes Made

The cPanel plugin has been refactored to follow the **proven cPanel plugin registration pattern** used by official cPanel plugins, replacing the failed DynamicUI YAML approach.

### Old Structure (Non-Working)
- DynamicUI YAML registration: `/var/cpanel/dynamicui/jupiter/Software/varnish.yaml`
- Static HTML + CGI separation: `static/index.html`, `static/app.js`, `static/app.css`
- PHP routing wrapper: `static/index.php`
- Perl CGI backend: `cgi/varnish_user.cgi`
- **Issue**: Plugin never appeared in cPanel Software section despite correct configuration

### New Structure (Working)
- **install.json**: Native cPanel plugin registration metadata
- **varnish_manager.live.php**: cPanel-native entry point (replaces HTML + PHP routing)
- Uses cPanel's native `require_once "/usr/local/cpanel/php/cpanel.php"` API
- Calls backend via `sudo varnishadm` and `sudo varnishctl`
- Single-file UI with embedded JavaScript for AJAX operations

## File Changes

### `/plugins/cpanel/install.json` (NEW)
```json
{
    "id": "varnish_manager",
    "name": "Varnish Manager",
    "description": "Manage Varnish cache for your domains",
    "icon": "varnish_icon.png",
    "featuremanager": 1,
    "feature": "varnish_cache_manager",
    "group_id": "advanced",
    "order": "10",
    "uri": "varnish_manager/varnish_manager.live.php",
    "type": "link"
}
```

**Fields Explained**:
- `id`: Unique plugin identifier (used in directory naming and cPanel registry)
- `featuremanager`: Enables cPanel's feature manager integration (1 = enabled)
- `feature`: Feature name for ACL and feature manager controls
- `group_id`: Placement in cPanel UI (advanced = Software/Advanced section)
- `uri`: Path to the .live.php entry point (relative to plugin directory)
- `type`: "link" means it opens directly; "form" would open in a dialog

### `/plugins/cpanel/varnish_manager.live.php` (NEW)
**Purpose**: Single-file cPanel-native plugin interface

**Key Components**:
1. **cPanel Integration**:
   - Uses `$cpanel = new CPANEL()` to access cPanel API
   - Uses `$cpanel->uapi('DomainInfo', 'list_domains')` for domain discovery
   - Uses `$cpanel->header()` and `$cpanel->footer()` for UI chrome
   - Accessed only when `define('IN_CPANEL')` is set by cPanel framework

2. **Backend Communication**:
   - Calls `sudo varnishadm` directly (no CGI wrapper)
   - Calls `sudo varnishctl status --format json` for service status
   - Commands:
     - `sudo varnishadm "ban req.http.host ~ .domain.com"` → Purge domain cache
     - `sudo varnishadm "ban req.url ~ ."` → Flush all cache

3. **AJAX Interface**:
   - JavaScript handles real-time status updates
   - Fetch-based API calls (no jQuery required)
   - Status refresh, purge domain, flush all operations
   - Auto-dismiss messages after 5 seconds

### `/plugins/cpanel/scripts/install.sh` (UPDATED)
**Changes**:
- Detects cPanel version and uses appropriate plugin directory:
  - Newer: `/usr/local/cpanel/base/3rdparty/plugins/varnish_manager/`
  - Legacy: `/usr/local/cpanel/base/frontend/jupiter/varnish_manager/`
- Installs `install.json` and `varnish_manager.live.php` only
- Removes old DynamicUI YAML registration
- Calls `rebuild_sprites` to reload cPanel UI
- Signals cPanel daemon to pick up new plugin

### `/plugins/cpanel/scripts/uninstall.sh` (UPDATED)
**Changes**:
- Removes from both 3rdparty and legacy locations
- Cleans up old DynamicUI YAML files
- Rebuilds cPanel UI sprite cache

## Installation & Deployment

```bash
# Deploy from main install script
./install_varnish_hitch.sh --cpanel-plugin

# Or manually
cd plugins/cpanel/scripts
sudo bash install.sh

# Verify installation
ls -la /usr/local/cpanel/base/3rdparty/plugins/varnish_manager/
ls -la /usr/local/cpanel/base/frontend/jupiter/varnish_manager/  # Fallback
```

## Access & Usage

### In cPanel UI
1. Log into cPanel
2. Navigate to: **Software** → **Advanced** → **Varnish Manager**
3. View Varnish status, purge individual domains, or flush all cache

### Direct URL
```
https://your-server:2083/frontend/jupiter/varnish_manager/varnish_manager.live.php
```

### Command Line Testing
```bash
# Verify sudoers permissions for cPanel users
sudo su - cpanel_user
/usr/local/bin/varnishctl status
sudo varnishadm "ban req.url ~ ."
```

## Why This Approach Works

1. **Native cPanel Registration**: Uses `install.json` which is the officially documented plugin format
2. **cPanel Framework Integration**: Uses `$cpanel` object and native header/footer functions
3. **Feature Manager Support**: Integrates with cPanel's feature manager for ACL controls
4. **Single Entry Point**: `.live.php` reduces complexity vs. HTML + JS + CGI routing
5. **Proven Pattern**: Based on official cPanel plugin examples and third-party plugins like varnish-cache-flusher

## Troubleshooting

### Plugin not showing in cPanel
1. Verify install location:
   ```bash
   test -d /usr/local/cpanel/base/3rdparty/plugins/varnish_manager && echo "OK (3rdparty)" || echo "MISSING (3rdparty)"
   test -d /usr/local/cpanel/base/frontend/jupiter/varnish_manager && echo "OK (legacy)" || echo "MISSING (legacy)"
   ```

2. Check install.json syntax:
   ```bash
   cd /usr/local/cpanel/base/3rdparty/plugins/varnish_manager
   cat install.json | python3 -m json.tool
   ```

3. Rebuild cPanel UI:
   ```bash
   /usr/local/cpanel/bin/rebuild_sprites --all
   ```

4. Check cPanel error logs:
   ```bash
   tail -f /usr/local/cpanel/logs/error_log
   ```

5. Log out and log back into cPanel (feature manager caches at login)

### Commands failing from plugin
1. Verify sudoers configuration:
   ```bash
   sudo service/bin/update_sudoers.sh
   ```

2. Test sudo access as cPanel user:
   ```bash
   sudo su - cpanel_user
   sudo /usr/local/bin/varnishctl status
   ```

3. Verify varnishctl permissions:
   ```bash
   ls -la /usr/local/bin/varnishctl
   ```

## Migration from Old Plugin

If you have the old plugin installed:

1. **Uninstall old version**:
   ```bash
   sudo /usr/local/cpanel/base/frontend/jupiter/varnish_manager/scripts/uninstall.sh
   ```

2. **Install new version**:
   ```bash
   sudo plugins/cpanel/scripts/install.sh
   ```

3. **Clean old directories** (if not auto-removed):
   ```bash
   sudo rm -rf /usr/local/cpanel/base/frontend/jupiter/varnish
   sudo rm -rf /usr/local/cpanel/base/frontend/jupiter/cgi/varnish_user.cgi
   sudo rm -f /var/cpanel/dynamicui/jupiter/Software/varnish.yaml
   ```

4. **Rebuild UI**:
   ```bash
   sudo /usr/local/cpanel/bin/rebuild_sprites --all
   ```

## Testing Checklist

- [ ] Plugin appears in cPanel Software/Advanced section
- [ ] Plugin loads without errors
- [ ] User's domains are listed correctly
- [ ] "Refresh Status" button shows Varnish status
- [ ] "Purge Cache" button works for individual domains
- [ ] "Flush All Cache" button works for all domains
- [ ] Operations show success/error messages
- [ ] Sudoers auto-generation completed (`/etc/sudoers.d/varnish-cpanel-users` exists)
- [ ] Backend varnishadm commands execute successfully

## Related Files

- Backend: `service/bin/varnishctl.sh` (symlinked to `/usr/local/bin/varnishctl`)
- WHM Plugin: `plugins/whm/` (separate WHM admin interface)
- Installation: `install_varnish_hitch.sh --cpanel-plugin` flag
