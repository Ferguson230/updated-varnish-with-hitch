.PHONY: provision render-config whm-install whm-uninstall cpanel-install cpanel-uninstall bootstrap uninstall clean

SHELL := /bin/bash
SERVICE_BIN := service/bin
WHM_SCRIPTS := plugins/whm/scripts
CP_SCRIPTS := plugins/cpanel/scripts

# Ensure execution bits are present on helper scripts (idempotent).
bootstrap:
	chmod +x install_varnish_hitch.sh update_hitch_certs.sh || true
	chmod +x $(SERVICE_BIN)/*.sh || true
	chmod +x plugins/whm/cgi/*.cgi || true
	chmod +x $(WHM_SCRIPTS)/*.sh || true
	chmod +x plugins/cpanel/cgi/*.cgi || true
	chmod +x $(CP_SCRIPTS)/*.sh || true

# Run the full provisioning workflow defined in service/bin/provision.sh
provision: bootstrap
	sudo $(SERVICE_BIN)/provision.sh

# Re-render default.vcl and reload Varnish without touching packages/services
render-config: bootstrap
	sudo $(SERVICE_BIN)/provision.sh --render-config

# Install the WHM management interface
whm-install: bootstrap
	sudo bash $(WHM_SCRIPTS)/install.sh

# Remove the WHM interface and helper binaries
whm-uninstall:
	sudo bash $(WHM_SCRIPTS)/uninstall.sh

# Install the cPanel end-user plugin (Jupiter theme)
cpanel-install: bootstrap
	sudo bash $(CP_SCRIPTS)/install.sh

# Uninstall the cPanel plugin
cpanel-uninstall:
	sudo bash $(CP_SCRIPTS)/uninstall.sh

# Convenience target to tear down services and packages
uninstall:
	sudo systemctl stop varnish || true
	sudo systemctl stop hitch || true
	sudo bash $(WHM_SCRIPTS)/uninstall.sh || true
	sudo bash $(CP_SCRIPTS)/uninstall.sh || true
	sudo dnf remove -y varnish hitch || true
	sudo systemctl daemon-reload || true
	sudo systemctl restart httpd || true

clean:
	@echo "Nothing to clean; workspace-only project."
