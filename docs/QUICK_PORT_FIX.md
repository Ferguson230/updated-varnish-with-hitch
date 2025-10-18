# Quick Apache Port Fix

If the installation fails because Apache hasn't released ports 80/443, use these commands on your server:

## Option 1: Automatic Fix (Run This First)

```bash
sudo bash /root/updated-varnish-with-hitch/service/bin/recover_ports.sh
```

Then retry installation:
```bash
sudo ./install.sh
```

---

## Option 2: Manual Quick Fix (If Automatic Fails)

Run these commands in order on your server:

```bash
# Step 1: Check current port usage
netstat -tuln | grep -E ":(80|443|8080|8443)"

# Step 2: Update cPanel configuration
sudo sed -i 's/^apache_port=.*/apache_port=0.0.0.0:8080/' /var/cpanel/cpanel.config
sudo sed -i 's/^apache_ssl_port=.*/apache_ssl_port=0.0.0.0:8443/' /var/cpanel/cpanel.config

# Step 3: Verify the changes
grep -E "apache_(port|ssl_port)" /var/cpanel/cpanel.config

# Step 4: Rebuild Apache configuration
sudo /scripts/rebuildhttpdconf

# Step 5: Stop Apache
sudo systemctl stop httpd

# Step 6: Restart cPanel
sudo systemctl restart cpanel

# Step 7: Start Apache on new ports
sudo systemctl start httpd

# Step 8: Wait and verify
sleep 3
netstat -tuln | grep -E ":(80|443|8080|8443)"

# Expected output:
# Port 80: FREE (for Varnish)
# Port 443: FREE (for Hitch)
# Port 8080: Apache listening
# Port 8443: Apache listening
```

---

## Option 3: GUI Fix in WHM

1. Login to WHM (WebHost Manager)
2. Go to: **Server Configuration** → **Tweak Settings**
3. Search for "apache" in the search box
4. Find and update:
   - **Apache non-SSL IP/port**: Change from `0.0.0.0:80` to `0.0.0.0:8080`
   - **Apache SSL port**: Change from `0.0.0.0:443` to `0.0.0.0:8443`
5. Click **Save**
6. Wait for Apache to restart (may see brief site outage)
7. Verify: Open terminal and run:
   ```bash
   netstat -tuln | grep -E ":(8080|8443)"
   ```
8. Retry installation:
   ```bash
   sudo ./install.sh
   ```

---

## Verification

After applying any of the above fixes, verify the ports are correct:

```bash
# Check port usage
netstat -tuln | grep -E ":(80|443|8080|8443)"

# Should show:
# - Port 80: LISTEN (will be Varnish after install)
# - Port 443: LISTEN (will be Hitch after install)
# - Port 8080: LISTEN (Apache)
# - Port 8443: LISTEN (Apache)

# If you see Apache on 80/443, the fix didn't work
# If you see nothing on 80/443, they're free and ready

# Check cPanel config
grep -E "apache_(port|ssl_port)" /var/cpanel/cpanel.config

# Should show:
# apache_port=0.0.0.0:8080
# apache_ssl_port=0.0.0.0:8443
```

---

## What to Do If Still Failing

1. **Check Apache is actually running:**
   ```bash
   systemctl status httpd
   ```

2. **Check for other processes on those ports:**
   ```bash
   lsof -i :80
   lsof -i :443
   ```

3. **Check cPanel daemon is running:**
   ```bash
   systemctl status cpanel
   ```

4. **Manually kill processes on 80/443 (last resort):**
   ```bash
   sudo fuser -k 80/tcp
   sudo fuser -k 443/tcp
   ```

5. **Then restart everything:**
   ```bash
   sudo systemctl restart httpd cpanel varnish hitch
   ```

---

## Troubleshooting

**Q: Installation still says "Address already in use" on port 80**
- A: Apache is still listening on 80. Verify: `sudo netstat -tuln | grep :80`
- Run Option 2 or Option 3 above to fix

**Q: Apache won't start after changing ports**
- A: Check Apache config syntax: `sudo apache2ctl configtest`
- Rebuild config: `sudo /scripts/rebuildhttpdconf`

**Q: Can't find /scripts/rebuildhttpdconf**
- A: This is a cPanel script. Verify you're on cPanel/WHM: `which cpconf`

**Q: Varnish still fails after ports are freed**
- A: Check if something else is binding: `sudo lsof -i :80`
- Force a full service restart: `sudo systemctl restart httpd cpanel varnish hitch`

---

See also: `docs/APACHE_PORT_TROUBLESHOOTING.md` for comprehensive troubleshooting.
