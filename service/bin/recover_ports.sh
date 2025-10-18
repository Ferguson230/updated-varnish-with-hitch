#!/bin/bash
# Emergency port reassignment and recovery script
# This script fixes Apache port configuration conflicts with Varnish/Hitch
# Run this if Varnish/Hitch startup fails due to port conflicts

set -euo pipefail

LOG_FILE="/var/log/varnish-whm-manager.log"

log() {
    local level="$1"; shift
    printf '%s [%s] %s\n' "$(date '+%F %T')" "${level}" "$*" | tee -a "${LOG_FILE}"
}

abort() {
    log "ERROR" "$*"
    exit 1
}

require_root() {
    [[ ${EUID} -eq 0 ]] || abort "This script must be run as root."
}

emergency_port_recovery() {
    log "WARN" "=== EMERGENCY PORT RECOVERY ==="
    
    require_root
    
    # Check current port usage
    log "INFO" "Checking current port usage..."
    netstat -tuln 2>/dev/null | grep -E ":(80|443) " && log "INFO" "Found services on 80/443" || log "INFO" "Ports 80/443 appear to be free"
    
    # Step 1: Update cPanel configuration
    log "INFO" "Step 1: Updating cPanel port configuration..."
    if [[ -f /var/cpanel/cpanel.config ]]; then
        cp -a /var/cpanel/cpanel.config /var/cpanel/cpanel.config.emergency-$(date +%s)
        sed -i 's/^apache_port=0\.0\.0\.0:80$/apache_port=0.0.0.0:8080/' /var/cpanel/cpanel.config
        sed -i 's/^apache_ssl_port=0\.0\.0\.0:443$/apache_ssl_port=0.0.0.0:8443/' /var/cpanel/cpanel.config
        log "INFO" "cPanel configuration updated"
    else
        abort "/var/cpanel/cpanel.config not found"
    fi
    
    # Step 2: Rebuild Apache httpd.conf
    log "INFO" "Step 2: Rebuilding Apache configuration..."
    if command -v /scripts/rebuildhttpdconf >/dev/null 2>&1; then
        /scripts/rebuildhttpdconf >/dev/null 2>&1 || log "WARN" "rebuildhttpdconf completed with warnings"
        log "INFO" "Apache configuration rebuilt"
    else
        log "WARN" "/scripts/rebuildhttpdconf not found - skipping"
    fi
    
    # Step 3: Stop Apache services
    log "INFO" "Step 3: Stopping Apache services..."
    systemctl stop httpd >/dev/null 2>&1 || log "WARN" "httpd stop returned non-zero (may already be stopped)"
    sleep 2
    
    # Step 4: Restart cPanel services
    log "INFO" "Step 4: Restarting cPanel services..."
    systemctl restart cpanel || log "WARN" "cpanel restart completed with issues"
    sleep 3
    
    # Step 5: Start Apache on new ports
    log "INFO" "Step 5: Starting Apache on new ports..."
    systemctl start httpd >/dev/null 2>&1 || abort "Failed to start Apache"
    sleep 2
    
    # Step 6: Verify port configuration
    log "INFO" "Step 6: Verifying port configuration..."
    local http_check=$(netstat -tuln 2>/dev/null | grep ":8080 " || echo "")
    local https_check=$(netstat -tuln 2>/dev/null | grep ":8443 " || echo "")
    
    if [[ -n "${http_check}" ]] && [[ -n "${https_check}" ]]; then
        log "INFO" "✓ Apache is now listening on ports 8080 and 8443"
    else
        log "WARN" "Apache port verification inconclusive - checking manually..."
        netstat -tuln | grep -E ":(8080|8443)"
    fi
    
    # Step 7: Check if 80/443 are now free
    log "INFO" "Step 7: Verifying ports 80/443 are free..."
    if ! netstat -tuln 2>/dev/null | grep -q -E ":(80|443) "; then
        log "INFO" "✓ Ports 80/443 are now free for Varnish/Hitch"
    else
        log "WARN" "Ports 80/443 still in use - manual investigation needed"
        netstat -tuln | grep -E ":(80|443)"
        abort "Port conflict not resolved - see above for details"
    fi
    
    log "INFO" "=== EMERGENCY RECOVERY COMPLETE ==="
    log "INFO" "You can now run: sudo ./install.sh or sudo systemctl restart varnish hitch"
}

usage() {
    cat <<'EOF'
Emergency Port Recovery Script

Usage: sudo bash recover_ports.sh

This script will:
1. Update /var/cpanel/cpanel.config to use ports 8080/8443
2. Rebuild Apache httpd.conf
3. Stop and restart Apache services
4. Verify ports 80/443 are free for Varnish/Hitch

Use this if Varnish/Hitch failed to start due to Apache using ports 80/443.

EOF
}

if [[ $# -gt 0 ]]; then
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
fi

emergency_port_recovery

log "INFO" "Recovery script completed successfully"
echo ""
echo "Next steps:"
echo "1. Restart Varnish and Hitch:"
echo "   sudo systemctl restart varnish hitch"
echo ""
echo "2. Verify they are running:"
echo "   sudo systemctl status varnish hitch"
echo ""
echo "3. Test connectivity:"
echo "   curl -v https://your-domain.com"
echo ""
