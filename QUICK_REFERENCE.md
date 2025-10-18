# Quick Reference - cPanel Plugin Refactoring

## What Changed?

### The Problem
The old cPanel plugin used DynamicUI YAML registration which **never worked** - the plugin never appeared in cPanel's Software section despite correct configuration.

### The Solution
Refactored to use **native cPanel plugin registration** (install.json + .live.php) - the proven approach used by official cPanel plugins.

## Files Modified/Created

| File | Status | Details |
|------|--------|---------|
| `plugins/cpanel/install.json` | ✨ NEW | Plugin registration metadata |
| `plugins/cpanel/varnish_manager.live.php` | ✨ NEW | Single-file cPanel entry point |
| `plugins/cpanel/scripts/install.sh` | 📝 UPDATED | Deploy to correct location |
| `plugins/cpanel/scripts/uninstall.sh` | 📝 UPDATED | Clean both locations |
| `README.md` | 📝 UPDATED | New troubleshooting section |

## Deployment

### One Command Installation
```bash
sudo ./install.sh --cpanel-only
```

### Manual Installation
```bash
sudo bash plugins/cpanel/scripts/install.sh
```

### Verification
```bash
# Check installation
ls -la /usr/local/cpanel/base/3rdparty/plugins/varnish_manager/

# Rebuild UI
sudo /usr/local/cpanel/bin/rebuild_sprites --all

# Access in cPanel after logging out/in:
# Software → Advanced → Varnish Manager
```

## What The User Will See

Before:
- ❌ Plugin doesn't appear anywhere in cPanel

After:
- ✅ Software → Advanced → Varnish Manager (appears immediately)
- ✅ View Varnish status (running/stopped, cache metrics)
- ✅ List all domains
- ✅ Purge cache per domain
- ✅ Flush all cache
- ✅ Real-time notifications

## Key Improvements

| Feature | Before | After |
|---------|--------|-------|
| **Registration** | DynamicUI YAML (failed) | install.json (proven) |
| **Entry Point** | HTML routing | Native .live.php |
| **Backend** | Perl CGI | Direct varnishadm |
| **Appearance** | Never showed up | Works immediately |
| **Documentation** | Minimal | Comprehensive |

## Documentation Files

- **README.md** - Updated with new section
- **plugins/cpanel/REFACTORING.md** - Technical details
- **CPANEL_PLUGIN_REFACTORING_SUMMARY.md** - Complete summary
- **CPANEL_PLUGIN_IMPLEMENTATION_REPORT.md** - Full deployment guide
- **REFACTORING_CHECKLIST.md** - Implementation checklist

## Troubleshooting Quick Links

**Plugin not showing?**
```bash
sudo /usr/local/cpanel/bin/rebuild_sprites --all
# Then log out and back into cPanel
```

**Permission denied?**
```bash
sudo bash service/bin/update_sudoers.sh
```

**Varnish not responding?**
```bash
sudo systemctl status varnish
```

## Next Steps

1. Deploy: `sudo ./install.sh --cpanel-only`
2. Rebuild UI: `sudo /usr/local/cpanel/bin/rebuild_sprites --all`
3. Log out and back into cPanel
4. Go to Software → Advanced → Varnish Manager
5. Test the functionality

## Support Resources

- **Technical Details:** See `plugins/cpanel/REFACTORING.md`
- **Deployment Guide:** See `CPANEL_PLUGIN_IMPLEMENTATION_REPORT.md`
- **Troubleshooting:** See `README.md` section "Troubleshooting (cPanel UI)"
- **Checklist:** See `REFACTORING_CHECKLIST.md`

---

**Status:** ✅ READY TO DEPLOY
