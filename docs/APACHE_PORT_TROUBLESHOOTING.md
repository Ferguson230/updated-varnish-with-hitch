# Apache Port Configuration - Troubleshooting Guide

## The Problem

If Varnish and Hitch fail to start, it's likely because Apache is still listening on ports 80 and 443, which are needed for the Varnish + Hitch stack.

### Symptom 1: Installation Fails
```
ERROR: Provisioning Varnish + Hitch
ERROR: Failed to start hitch or varnish - port conflict
```

### Symptom 2: Services Won't Start
```
systemctl start hitch  # Fails
systemctl start varnish  # Fails
```

### Symptom 3: Port Already in Use
```
netstat -tuln | grep -E ":(80|443)"
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN
tcp        0      0 0.0.0.0:443             0.0.0.0:*               LISTEN
```

---

## Root Cause

The installation script tries to detect if Apache is using ports 80/443, but the cPanel configuration wasn't automatically updated. This happens when:

1. **Manual Setup**: You manually changed Apache ports in WHM UI but didn't restart services properly
2. **Configuration Mismatch**: `/var/cpanel/cpanel.config` still shows `apache_port=0.0.0.0:80`
3. **Service Not Restarted**: Apache configuration wasn't rebuilt after changing ports

---

## Quick Fix (For Live Servers)

### Step 1: Check Current Port Usage

```bash
# Show all listening ports
netstat -tuln | grep -E ":(80|443|8080|8443)"

# Or use ss command (newer)
ss -tuln | grep -E ":(80|443|8080|8443)"
```

**Expected output** (before fix):
```
tcp  0  0 0.0.0.0:80    0.0.0.0:*  LISTEN
tcp  0  0 0.0.0.0:443   0.0.0.0:*  LISTEN
```

### Step 2: Update cPanel Configuration

```bash
# Verify current cPanel config
grep -E "apache_(port|ssl_port)" /var/cpanel/cpanel.config

# Update the configuration
sed -i 's/^apache_port=0\.0\.0\.0:80$/apache_port=0.0.0.0:8080/' /var/cpanel/cpanel.config
sed -i 's/^apache_ssl_port=0\.0\.0\.0:443$/apache_ssl_port=0.0.0.0:8443/' /var/cpanel/cpanel.config

# Verify changes
grep -E "apache_(port|ssl_port)" /var/cpanel/cpanel.config
```

**Expected output** (after fix):
```
apache_port=0.0.0.0:8080
apache_ssl_port=0.0.0.0:8443
```

### Step 3: Rebuild Apache Configuration

```bash
# Rebuild httpd.conf from cPanel config
/scripts/rebuildhttpdconf

# Restart Apache
systemctl restart httpd
```

### Step 4: Restart cPanel

```bash
systemctl restart cpanel
```

### Step 5: Verify Port Changes

```bash
# Check that Apache moved to new ports
netstat -tuln | grep -E ":(80|443|8080|8443)"
```

**Expected output** (after fix):
```
tcp  0  0 0.0.0.0:8080  0.0.0.0:*  LISTEN
tcp  0  0 0.0.0.0:8443  0.0.0.0:*  LISTEN
```

### Step 6: Start Varnish and Hitch

```bash
# Start services
systemctl start varnish
systemctl start hitch

# Verify they're running
systemctl status varnish hitch

# Check port usage
netstat -tuln | grep -E ":(80|443|8080|8443)"
```

**Expected output** (final):
```
tcp  0  0 0.0.0.0:80    0.0.0.0:*  LISTEN    ← Varnish
tcp  0  0 0.0.0.0:443   0.0.0.0:*  LISTEN    ← Hitch
tcp  0  0 0.0.0.0:8080  0.0.0.0:*  LISTEN    ← Apache
tcp  0  0 0.0.0.0:8443  0.0.0.0:*  LISTEN    ← Apache
```

---

## Automated Recovery Script

If you have failures during installation, use the recovery script (only on Linux):

```bash
# Run the emergency recovery script
sudo bash service/bin/recover_ports.sh
```

**What it does:**
1. Backs up `/var/cpanel/cpanel.config`
2. Updates Apache port configuration
3. Rebuilds Apache httpd.conf
4. Stops and restarts Apache services
5. Verifies ports 80/443 are free
6. Provides next steps

---

## Manual Step-by-Step (Complete Procedure)

If the quick fix doesn't work, follow this complete procedure:

### Phase 1: Preparation

```bash
# 1. Check current state
echo "=== Current Port Status ==="
netstat -tuln | grep -E ":(80|443|8080|8443)" || echo "No conflicts found"

echo "=== Current cPanel Config ==="
grep -E "apache_(port|ssl_port)" /var/cpanel/cpanel.config

echo "=== Apache Process Status ==="
systemctl status httpd --no-pager | head -10
```

### Phase 2: Stop Services

```bash
# Stop services in order (safest to least safe)
systemctl stop hitch 2>/dev/null || true
systemctl stop varnish 2>/dev/null || true
systemctl stop httpd

# Wait for graceful shutdown
sleep 3

# Verify they're stopped
netstat -tuln | grep -E ":(80|443)" && echo "ERROR: Services still running" || echo "OK: Ports freed"
```

### Phase 3: Update Configuration

```bash
# Backup cPanel config (just in case)
cp /var/cpanel/cpanel.config /var/cpanel/cpanel.config.backup-$(date +%s)

# Update port configuration
sed -i 's/^apache_port=0\.0\.0\.0:80$/apache_port=0.0.0.0:8080/' /var/cpanel/cpanel.config
sed -i 's/^apache_ssl_port=0\.0\.0\.0:443$/apache_ssl_port=0.0.0.0:8443/' /var/cpanel/cpanel.config

# Verify
echo "=== Updated cPanel Config ==="
grep -E "apache_(port|ssl_port)" /var/cpanel/cpanel.config
```

### Phase 4: Rebuild Apache

```bash
# Run the cPanel script to rebuild Apache config
echo "Rebuilding Apache configuration..."
/scripts/rebuildhttpdconf

# Verify httpd.conf was updated
echo "=== Verify Listen Directives ==="
grep -E "Listen " /etc/apache2/conf/httpd.conf | head -5
```

### Phase 5: Restart Services

```bash
# Restart cPanel first
echo "Restarting cPanel..."
systemctl restart cpanel
sleep 3

# Start Apache
echo "Starting Apache..."
systemctl start httpd
sleep 3

# Verify ports changed
echo "=== Port Status After Apache Restart ==="
netstat -tuln | grep -E ":(80|443|8080|8443)"
```

### Phase 6: Start Varnish & Hitch

```bash
# Start Varnish
echo "Starting Varnish..."
systemctl start varnish
sleep 2
systemctl status varnish --no-pager | head -5

# Start Hitch
echo "Starting Hitch..."
systemctl start hitch
sleep 2
systemctl status hitch --no-pager | head -5

# Final verification
echo "=== Final Port Status ==="
netstat -tuln | grep -E ":(80|443|8080|8443)"
```

### Phase 7: Validation

```bash
# Check service status
echo "=== Service Status ==="
systemctl is-active varnish hitch httpd

# Check logs for errors
echo "=== Varnish Log ==="
journalctl -u varnish -n 10 --no-pager

echo "=== Hitch Log ==="
journalctl -u hitch -n 10 --no-pager

echo "=== Apache Error Log ==="
tail -20 /var/log/apache2/error_log
```

---

## Testing After Fix

### Test 1: Port Usage

```bash
netstat -tuln | grep -E ":(80|443|8080|8443)"
```

Expected:
- `:80` and `:443` = Varnish/Hitch
- `:8080` and `:8443` = Apache

### Test 2: Service Status

```bash
systemctl status varnish hitch httpd -l
```

Expected: All three should be `active (running)`

### Test 3: HTTP Request

```bash
# Direct to Varnish (port 80)
curl -v http://localhost/

# Direct to Hitch (port 443)
curl -v https://localhost/ --insecure

# Direct to Apache (port 8080)
curl -v http://localhost:8080/
```

Expected: All three should respond with valid HTTP

### Test 4: Domain Test

```bash
# Test with actual domain (replace with your domain)
curl -v https://yourdomain.com/ --insecure

# Check cache headers
curl -I https://yourdomain.com/ --insecure | grep -E "(X-Varnish|X-Cache|Age)"
```

Expected: Should see Varnish cache headers

---

## Rollback Procedure

If something goes wrong, rollback to previous state:

```bash
# 1. Stop all services
systemctl stop varnish hitch httpd

# 2. Restore cPanel config backup
cp /var/cpanel/cpanel.config.backup-* /var/cpanel/cpanel.config

# 3. Rebuild Apache config from restored settings
/scripts/rebuildhttpdconf

# 4. Restart services
systemctl start httpd cpanel

# 5. Verify state
grep -E "apache_(port|ssl_port)" /var/cpanel/cpanel.config
netstat -tuln | grep -E ":(80|443)"
```

---

## Persistent Issues - Deep Debugging

If the problem persists, investigate further:

### Check Process Holding Port

```bash
# Find what's listening on port 80
lsof -i :80

# Or
fuser 80/tcp -v

# Or
ss -tpln | grep :80
```

### Check cPanel Service Status

```bash
# Check cPanel daemon
systemctl status cpanel

# Check cPanel configuration server
/usr/local/cpanel/bin/cpconf --check

# Check for configuration errors
/usr/local/cpanel/bin/cpupdateconf
```

### Check Apache Configuration

```bash
# Verify Apache config is syntactically correct
apache2ctl configtest

# Check for conflicting Listen directives
grep -n "Listen " /etc/apache2/conf/httpd.conf /etc/apache2/conf.d/*.conf 2>/dev/null | grep -E ":(80|443)"

# Show all Listen directives
grep -h "^Listen " /etc/apache2/conf/httpd.conf /etc/apache2/conf.d/*.conf 2>/dev/null
```

### Check Firewall Rules

```bash
# Show firewall rules for HTTP/HTTPS
firewall-cmd --list-all | grep -E "(80|443|8080|8443)"

# Or check iptables
iptables -L -n | grep -E "(80|443|8080|8443)"
```

### Check System Logs

```bash
# Apache error log
tail -50 /var/log/apache2/error_log

# Apache access log
tail -50 /var/log/apache2/access_log

# System messages
tail -50 /var/log/messages

# All services
journalctl -e | tail -100
```

---

## Prevention - Before Installation

### Pre-Installation Checklist

- [ ] Log into WHM
- [ ] Go to **Server Configuration** → **Tweak Settings**
- [ ] Search for "Apache" in the Find box
- [ ] Change **Apache non-SSL IP/port** to `0.0.0.0:8080`
- [ ] Change **Apache SSL port** to `0.0.0.0:8443`
- [ ] Click **Save**
- [ ] Wait for Apache to restart (may see brief outage)
- [ ] Verify in terminal: `grep -E "apache_(port|ssl_port)" /var/cpanel/cpanel.config`
- [ ] Only then run: `sudo ./install.sh`

---

## Support Resources

- **Varnish Documentation**: https://docs.varnish-software.com/
- **cPanel Documentation**: https://docs.cpanel.net/
- **Installation Guide**: See `installation guide` in repository
- **Project README**: See `README.md` for troubleshooting section
- **Recovery Script**: See `service/bin/recover_ports.sh`

---

**Last Updated:** October 2024  
**Applies To:** Varnish Cache 7.5 + Hitch + cPanel/WHM on AlmaLinux 8+
