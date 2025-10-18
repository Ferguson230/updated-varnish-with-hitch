# Varnish + Hitch Accelerator for WHM & cPanel (RHEL / AlmaLinux 8)

This project packages a battle-tested Varnish Cache 7.5 + Hitch TLS proxy stack for EasyApache 4 servers together with a full WHM provisioning plugin and a cPanel end-user control panel. The implementation follows the operational checklist in `installation guide` and expands it with automation, service orchestration, and modern UIs derived from the preview mock-ups.

## Quick Start

1. Clone the repository and change into it:
    ```bash
    git clone https://github.com/Ferguson230/updated-varnish-with-hitch.git
    cd updated-varnish-with-hitch
    ```
2. Run the consolidated installer (provisions the stack + deploys both plugins):
    ```bash
    sudo ./install.sh
    ```
    Use `./install.sh --help` for options such as skipping plugins or running the provisioning engine only.

## Prerequisites

- AlmaLinux 8 / Rocky 8 / RHEL 8 with WHM & cPanel installed.
- Root shell access (SSH) with `dnf` and `systemctl` available.
- `python3` available on the host (present by default on EL8) for template rendering.
- Apache must be moved off the default 80/443 ports *before* provisioning:
    1. WHM → **Server Configuration** → **Tweak Settings** → search for "Apache".
    2. Set **Apache non-SSL IP/port** to `0.0.0.0:8080`.
    3. Set **Apache SSL port** to `0.0.0.0:8443`.
    4. Save and restart Apache. Expect a brief site outage while the stack is deployed.
- Ensure recent backups of the server configuration and hosted sites.

## Project Layout

- `service/bin/` – Operational scripts (provisioning, service control, certificate sync).
- `service/config/default.vcl` – Optimised VCL template (WordPress/WooCommerce aware, static asset caching, X-Forwarded-Proto handling).
- `plugins/whm/` – WHM plugin (CGI backend, HTML/CSS/JS front-end, installer scripts).
- `plugins/cpanel/` – Jupiter theme plugin for end-users (domain aware purge controls, metrics).
- `install_varnish_hitch.sh` – Thin wrapper that defers to `service/bin/provision.sh`.
- `installation guide` – Narrative walkthrough respected by the automation.

## Provisioning the Stack

The consolidated installer wraps `service/bin/provision.sh`, but you can invoke the provisioning workflow directly when needed:

```bash
sudo ./install_varnish_hitch.sh
```

This script will:
- Update the OS with `dnf update -y`.
- Add the `varnish75` packagecloud repository.
- Install Varnish Cache 7.5 and Hitch.
- Copy and adjust `varnish.service` so Varnish listens on `:80` and Hitch on `127.0.0.1:4443`, applying high-performance thread pool and HTTP/2 parameters.
- Render `/etc/varnish/default.vcl` from the template, binding the detected server IP and injecting optional security headers.
- Harvest `SSLCertificate` paths from EasyApache and populate `/etc/hitch/hitch.conf`.
- Enable, start, and sanity-check Varnish + Hitch (logs go to `/var/log/varnish-whm-manager.log`).

Optional: rerun certificate sync as needed (`sudo /usr/local/bin/update_hitch_certs.sh`).

## Installing the WHM Plugin

Run `sudo ./install.sh --whm-only` to deploy just the WHM interface. The underlying script `sudo bash plugins/whm/scripts/install.sh` remains available if you prefer to call it directly.

- Installs assets into `/usr/local/cpanel/whostmgr/docroot/cgi/varnish/`.
- Deploys service helpers to `/opt/varnish-whm-manager/bin/` (`provision.sh`, `varnishctl.sh`, `update_certs.sh`).
- Symlinks helper commands into `/usr/local/bin/` for convenience.
- After install, the interface appears in WHM → **Plugins → Varnish + Hitch Accelerator**.

The WHM UI exposes stack status, metrics (via `varnishstat`), provisioning, service controls, cache flushing, certificate resync from Hitch, and a security headers panel to toggle HSTS + best-practice response headers with a single click. Preferences persist in `/opt/varnish-whm-manager/config/settings.json` and are re-applied whenever the VCL template renders.

## Installing the cPanel Plugin (Jupiter Theme)

Run `sudo ./install.sh --cpanel-only` to deploy only the end-user plugin. Alternately, execute `sudo bash plugins/cpanel/scripts/install.sh` directly.

**Plugin Registration & Architecture:**
The cPanel plugin follows the **native cPanel plugin registration pattern** (proven working with official cPanel and third-party plugins):

- **install.json** – Plugin metadata for cPanel's feature manager (id, name, description, feature, uri, etc.)
- **varnish_manager.live.php** – Single-file cPanel-native entry point using `require_once "/usr/local/cpanel/php/cpanel.php"`
- Detects and deploys to the correct location:
  - Newer cPanel: `/usr/local/cpanel/base/3rdparty/plugins/varnish_manager/`
  - Legacy cPanel: `/usr/local/cpanel/base/frontend/jupiter/varnish_manager/`

**Installation Details:**
- Installs `install.json` and `varnish_manager.live.php` to the plugin directory.
- Removes legacy DynamicUI YAML registration (no longer needed).
- Calls `rebuild_sprites` to refresh the cPanel UI.
- After install, **Varnish Manager** appears in cPanel → **Software** → **Advanced**.

**Access:**
- **cPanel UI:** Software → Advanced → Varnish Manager
- **Direct URL:** https://your-server:2083/frontend/jupiter/varnish_manager/varnish_manager.live.php

**Features:**
- View real-time Varnish service status (running/stopped, cache hits/misses, uptime).
- List all your domains (discovered via cPanel UAPI).
- Purge cache for individual domains.
- Flush all cache at once.
- AJAX-powered interface with auto-dismissing notifications.

See `plugins/cpanel/REFACTORING.md` for detailed technical documentation on the architecture changes and migration path from the previous implementation.

### cPanel sudoers configuration

The installer auto-generates `/etc/sudoers.d/varnish-cpanel-users` by scanning `/home/*` for existing cPanel users and granting them NOPASSWD access to varnishadm commands.

- Re-run `sudo ./install.sh --cpanel-only` to refresh sudoers after adding/removing accounts.
- Validate syntax any time with `visudo -c`.

### Troubleshooting (cPanel UI)

- **Plugin not appearing in Software section:**
  1. Verify installation:
     ```bash
     test -d /usr/local/cpanel/base/3rdparty/plugins/varnish_manager && echo "3rdparty OK" || echo "3rdparty MISSING"
     test -d /usr/local/cpanel/base/frontend/jupiter/varnish_manager && echo "legacy OK" || echo "legacy MISSING"
     ```
  2. Check install.json syntax:
     ```bash
     cat /usr/local/cpanel/base/3rdparty/plugins/varnish_manager/install.json | python3 -m json.tool
     ```
  3. Rebuild cPanel UI and log out/in:
     ```bash
     sudo /usr/local/cpanel/bin/rebuild_sprites --all
     ```

- **"Permission denied" or sudo errors when clicking buttons:**
  1. Verify sudoers configuration:
     ```bash
     sudo visudo -c  # Should print "sudoers file parsed successfully"
     ```
  2. Test varnishadm access:
     ```bash
     sudo su - cpanel_user
     sudo varnishadm "ban req.url ~ ."
     ```

- **Operations show empty responses:**
  1. Check cPanel error log:
     ```bash
     tail -f /usr/local/cpanel/logs/error_log
     ```
  2. Verify varnishctl is at the expected path:
     ```bash
     ls -la /usr/local/bin/varnishctl
     ```
  3. Check Varnish is running:
     ```bash
     sudo systemctl status varnish
     ```

## Command Reference

- `sudo varnish-provision` – Re-apply provisioning (idempotent).
- `sudo varnish-provision --render-config` – Refresh only the VCL + security headers from the template, then reload Varnish.
- `sudo varnishctl status --format json` – JSON service snapshot (used by both plugins).
- `sudo varnishctl restart|start|stop` – Control services.
- `sudo varnishctl purge https://example.com/page` – Ban a specific object.
- `sudo varnishctl flush` – Global cache flush (Varnish ban). Use carefully.

Makefile shortcuts are available when working in the repository:

- `make bootstrap` – Fix execute bits on all helper scripts (safe to run multiple times).
- `make install` – Run the consolidated installer (`sudo ./install.sh`).
- `make provision` – Run the full provisioning workflow (wraps `service/bin/provision.sh`).
- `make render-config` – Only re-render `default.vcl` from the template and reload Varnish (honours security header state).
- `make whm-install` / `make cpanel-install` – Deploy the WHM or cPanel plugins.
- `make uninstall` – Invoke the consolidated uninstaller (`sudo ./uninstall.sh`).

## WordPress / App Notes

- For WordPress, ensure `wp-config.php` forces HTTPS when behind the proxy:
    ```php
    if (!empty($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
            $_SERVER['HTTPS'] = 'on';
    }
    ```
- WooCommerce, OpenCart, Magento, Laravel, Node.js, Express.js, and generic static sites inherit safe defaults from the VCL template (path bypass list, cookie awareness, static asset caching, protocol hash variance).
- Additional app-specific VCL snippets can be dropped into `/etc/varnish/default.vcl` as required; remember to reload with `sudo varnishctl reload`.
- Re-usable snippets for WordPress, Node.js/Express upstreams, and static sites live under `service/config/snippets/`.

## Uninstalling

```bash
sudo ./uninstall.sh
```

Run `./uninstall.sh --help` to discover options such as keeping packages or skipping service stops. After teardown, revert Apache to ports 80/443 via WHM → **Tweak Settings**.

## Credits

Special thanks to @guillaume, @neutrinou (Varnish Cache Discord) and Andy Baugh (cPanel Forums) for foundational guidance.
