# Installation Failure Resolution - Summary

## Problem
Installation fails because Apache is still listening on ports 80 and 443, which are required by Varnish and Hitch respectively.

**Error Message:**
```
Job for varnish.service failed because the control process exited with error code.
```

**Root Cause:** Port 80 is already in use (Apache), preventing Varnish from binding.

---

## Solution Overview

The issue has been addressed with multiple layers of fixes:

### 1. **Enhanced Automatic Port Reassignment** ✅
- **File:** `service/bin/provision.sh`
- **What it does:** Automatically detects if Apache is holding ports 80/443 and moves it to 8080/8443
- **When:** Runs automatically at the START of the installation script
- **Improvements:**
  - Uses actual `netstat` to detect running services (not just config files)
  - More flexible sed patterns to match any config format
  - Explicit stop/start of Apache (not just restart)
  - Verification with status indicators
  - Better error messages and abort conditions

### 2. **Emergency Recovery Script** ✅
- **File:** `service/bin/recover_ports.sh`
- **What it does:** Manual recovery script for after-deployment port conflicts
- **Usage:** `sudo bash service/bin/recover_ports.sh`
- **When to use:** If automatic fix fails or conflicts occur post-installation

### 3. **Updated Documentation** ✅

**File:** `installation guide`
- Added "IMPORTANT: Pre-Installation Port Configuration" section
- Provided 3 configuration options:
  - Automatic (script handles it)
  - Manual CLI commands
  - WHM GUI method
- Added verification steps
- Added troubleshooting section

**File:** `docs/QUICK_PORT_FIX.md` (NEW)
- Quick reference with 3 fix options
- Verification commands
- Troubleshooting FAQ

**File:** `docs/APACHE_PORT_TROUBLESHOOTING.md` (EXISTING)
- Comprehensive 7-phase manual procedure
- Deep debugging guide
- Rollback instructions

---

## What to Do Now

### Before Running Installation

**Option 1: Let the Script Handle It (Recommended)**
```bash
sudo ./install.sh
```
The script will automatically detect and fix Apache port bindings.

**Option 2: Pre-Fix Manually (For Extra Safety)**
```bash
# Update cPanel configuration
sudo sed -i 's/^apache_port=.*/apache_port=0.0.0.0:8080/' /var/cpanel/cpanel.config
sudo sed -i 's/^apache_ssl_port=.*/apache_ssl_port=0.0.0.0:8443/' /var/cpanel/cpanel.config

# Rebuild Apache config
sudo /scripts/rebuildhttpdconf

# Restart services
sudo systemctl stop httpd
sudo systemctl restart cpanel
sudo systemctl start httpd

# Verify
sleep 3
netstat -tuln | grep -E ":(8080|8443)"

# Then run installation
sudo ./install.sh
```

### If Installation Still Fails

1. **Check port status:**
   ```bash
   netstat -tuln | grep -E ":(80|443|8080|8443)"
   ```

2. **Run emergency recovery:**
   ```bash
   sudo bash service/bin/recover_ports.sh
   ```

3. **Retry installation:**
   ```bash
   sudo ./install.sh
   ```

---

## Changes Made to Codebase

| File | Changes |
|------|---------|
| `service/bin/provision.sh` | Enhanced port detection using netstat; flexible sed patterns; explicit stop/start; verification output |
| `service/bin/recover_ports.sh` | Emergency recovery script (existing, now documented) |
| `installation guide` | Added pre-installation port config section; added troubleshooting section |
| `docs/QUICK_PORT_FIX.md` | New quick reference guide |
| `docs/APACHE_PORT_TROUBLESHOOTING.md` | Existing comprehensive guide |

---

## Technical Details

### Port Mapping After Installation
```
Port 80   → Varnish (external HTTP requests)
Port 443  → Hitch (external HTTPS requests)
Port 8080 → Apache (backend)
Port 8443 → Apache (backend SSL)
Port 4443 → Varnish internal proxy (for Hitch)
```

### Service Startup Order
1. Rebuild Apache httpd.conf from cPanel config
2. Stop Apache (releases ports 80/443)
3. Restart cPanel daemon
4. Start Apache on ports 8080/8443
5. Start Varnish on port 80
6. Start Hitch on port 443

### Key Functions in provision.sh

**`ensure_port_reassignment_done()`**
- Called at START of script
- Checks if ports 80/443 are in use
- Calls `reassign_cpanel_ports()` if needed
- Aborts if ports cannot be freed

**`reassign_cpanel_ports()`**
- Updates `/var/cpanel/cpanel.config`
- Runs `/scripts/rebuildhttpdconf`
- Stops/starts Apache explicitly
- Shows port status verification

**`verify_port_reassignment()`**
- Called before starting Varnish/Hitch
- Final validation that ports 80/443 are free
- Last-ditch attempt to resolve conflicts

---

## Git Commits

| Commit | Message |
|--------|---------|
| 6de0a66 | docs: update installation guide with critical port configuration section |
| affe942 | docs: add quick Apache port fix reference guide |
| 4fd2cff | improve: enhance Apache port reassignment with better detection and logging |
| e558091 | fix: correct bash syntax error in provision.sh |
| 0227f62 | fix: automatic Apache port reassignment to prevent Varnish/Hitch conflicts |

---

## For Server Administrators

### Quick Troubleshooting Flowchart

```
Installation fails?
    ↓
Check port usage:
    sudo netstat -tuln | grep -E ":(80|443)"
    ↓
If 80/443 in use:
    ├─ Option 1: Run recovery script
    │   sudo bash service/bin/recover_ports.sh
    │   sudo ./install.sh
    │
    ├─ Option 2: Run manual fix (docs/QUICK_PORT_FIX.md)
    │   Follow "Option 2: Manual Quick Fix"
    │   sudo ./install.sh
    │
    └─ Option 3: Use WHM GUI (docs/QUICK_PORT_FIX.md)
        Follow "Option 3: GUI Fix in WHM"
        sudo ./install.sh

If 80/443 still in use after fix:
    → See docs/APACHE_PORT_TROUBLESHOOTING.md
    → Check: lsof -i :80 and lsof -i :443
    → May need manual intervention

If installation succeeds:
    → Verify: sudo systemctl status varnish hitch httpd
    → Test: curl -I http://localhost/ (check Varnish headers)
```

---

## Prevention

To prevent this issue:

1. **Before any installation,** always configure Apache on 8080/8443 first
2. Use the installation guide section: "Pre-Installation Port Configuration"
3. Verify ports are correct: `netstat -tuln | grep -E ":(8080|8443)"`
4. Only then run `sudo ./install.sh`

---

## Support Resources

- **Quick fixes:** `docs/QUICK_PORT_FIX.md`
- **Comprehensive guide:** `docs/APACHE_PORT_TROUBLESHOOTING.md`
- **Emergency recovery:** `service/bin/recover_ports.sh`
- **Installation guide:** `installation guide` (now with port configuration section)
- **Script logs:** `/var/log/varnish-whm-manager.log`
- **Service logs:** `journalctl -u varnish`, `journalctl -u hitch`

---

**Status:** ✅ Automatic port reassignment implemented and tested  
**Last Updated:** October 18, 2025  
**Tested On:** AlmaLinux 9.6 with cPanel/WHM, Varnish 7.5.0, Hitch 1.7.2
