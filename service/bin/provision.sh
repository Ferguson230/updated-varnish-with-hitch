#!/bin/bash
# Provision Varnish Cache 7.5 + Hitch TLS proxy on AlmaLinux/RHEL 8 with cPanel/WHM.
# The script follows the documented manual procedure from the installation guide.

set -euo pipefail

ROOT_UID=0
VARNISH_REPO_SCRIPT="https://packagecloud.io/install/repositories/varnishcache/varnish75/script.rpm.sh"
VARNISH_SERVICE_FILE="/etc/systemd/system/varnish.service"
VARNISH_DEFAULT_VCL="/etc/varnish/default.vcl"
HITCH_CONF="/etc/hitch/hitch.conf"
HTTPD_CONF="/etc/apache2/conf/httpd.conf"
BACKUP_SUFFIX="$(date +%Y%m%d%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR%/bin}/config"
TEMPLATE_VCL="${CONFIG_DIR}/default.vcl"
SETTINGS_FILE="${CONFIG_DIR}/settings.json"
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
    [[ "${EUID}" -eq "${ROOT_UID}" ]] || abort "This script must be run as root."
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

require_python() {
    command_exists python3 || abort "python3 is required for templating; install python3 and retry."
}

system_ip() {
    ip -4 addr show scope global | awk '/inet / {print $2}' | cut -d'/' -f1 | head -n1
}

ensure_port_reassignment_done() {
    local http_port https_port
    http_port=$(awk '/^\s*Listen/ && $2 ~ /:80$/ {print $2}' "${HTTPD_CONF}" | sed 's/.*://') || http_port=""
    https_port=$(awk '/^\s*Listen/ && $2 ~ /:443$/ {print $2}' "${HTTPD_CONF}" | sed 's/.*://') || https_port=""
    if [[ "${http_port}" == "80" || "${https_port}" == "443" ]]; then
        log "WARN" "Apache still listens on 80/443. Update WHM > Tweak Settings so Apache uses 8080/8443 before provisioning."
    fi
}

run_or_warn() {
    local desc="$1"; shift
    log "INFO" "${desc}"
    if ! "$@"; then
        abort "${desc} failed"
    fi
}

backup_file() {
    local file="$1"
    if [[ -f "${file}" ]]; then
        cp -a "${file}" "${file}.${BACKUP_SUFFIX}"
        log "INFO" "Backup created for ${file} -> ${file}.${BACKUP_SUFFIX}"
    fi
}

configure_varnish_service() {
    backup_file "${VARNISH_SERVICE_FILE}"
    cp /usr/lib/systemd/system/varnish.service "${VARNISH_SERVICE_FILE}"
    sed -i "s#ExecStart=.*#ExecStart=/usr/sbin/varnishd -a :80 -a 127.0.0.1:4443,proxy -f ${VARNISH_DEFAULT_VCL} -s malloc,1G -p feature=+http2 -p workspace_backend=256k -p workspace_client=256k -p http_resp_hdr_len=65536 -p http_resp_size=98304 -p thread_pool_min=100 -p thread_pool_max=4000 -p thread_pools=4 -p vcc_allow_inline_c=on#g" "${VARNISH_SERVICE_FILE}"
    sed -i 's/^#\?LimitNOFILE.*/LimitNOFILE=131072/' "${VARNISH_SERVICE_FILE}"
    systemctl daemon-reload
}

ensure_settings_file() {
    install -d -m 0755 "$(dirname "${SETTINGS_FILE}")"
    if [[ ! -f "${SETTINGS_FILE}" ]]; then
        cat > "${SETTINGS_FILE}" <<'EOF'
{
  "security_headers": {
    "enabled": false,
    "max_age": 31536000,
    "include_subdomains": true,
    "preload": false,
    "frame_options": "SAMEORIGIN",
    "referrer_policy": "strict-origin-when-cross-origin",
    "permissions_policy": "geolocation=()",
    "content_type_options": "nosniff",
    "xss_protection": "1; mode=block"
  }
}
EOF
        chmod 0644 "${SETTINGS_FILE}"
    fi
}

security_headers_block() {
    python3 - "$SETTINGS_FILE" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    with open(path, 'r', encoding='utf-8') as fh:
        data = json.load(fh)
except FileNotFoundError:
    data = {}
sec = data.get('security_headers', {})
enabled = bool(sec.get('enabled'))
if not enabled:
    print('    # Security headers disabled; manage via WHM plugin.')
    sys.exit(0)

max_age = int(sec.get('max_age', 31536000))
include = bool(sec.get('include_subdomains', True))
preload = bool(sec.get('preload', False))
def sanitize(value, default=''):
    if value is None:
        value = default
    text = str(value).strip()
    return text.replace('"', '\\"')

frame = sanitize(sec.get('frame_options'), 'SAMEORIGIN')
referrer = sanitize(sec.get('referrer_policy'), 'strict-origin-when-cross-origin')
permissions = sanitize(sec.get('permissions_policy'), 'geolocation=()')
content_type = sanitize(sec.get('content_type_options'), 'nosniff')
xss = sanitize(sec.get('xss_protection'), '1; mode=block')

strict = f"max-age={max_age}"
if include:
    strict += '; includeSubDomains'
if preload:
    strict += '; preload'

lines = []
lines.append('    if (req.http.X-Forwarded-Proto == "https") {')
lines.append(f'        set resp.http.Strict-Transport-Security = "{strict}";')
lines.append('    }')
if frame:
    lines.append(f'    set resp.http.X-Frame-Options = "{frame}";')
if content_type:
    lines.append(f'    set resp.http.X-Content-Type-Options = "{content_type}";')
if xss:
    lines.append(f'    set resp.http.X-XSS-Protection = "{xss}";')
if referrer:
    lines.append(f'    set resp.http.Referrer-Policy = "{referrer}";')
if permissions:
    lines.append(f'    set resp.http.Permissions-Policy = "{permissions}";')

print('\n'.join(lines))
PY
}

apply_security_headers() {
    local target="$1"
    local block
    block="$(security_headers_block)"
    python3 - "$target" <<'PY'
import sys

path = sys.argv[1]
block = sys.stdin.read().rstrip()
with open(path, 'r', encoding='utf-8') as fh:
    contents = fh.read()
contents = contents.replace('__SECURITY_HEADERS__', block)
with open(path, 'w', encoding='utf-8') as fh:
    fh.write(contents)
PY
}

configure_default_vcl() {
    local ip
    ip="$1"
    [[ -z "${ip}" ]] && abort "Unable to determine server IP for VCL template"
    backup_file "${VARNISH_DEFAULT_VCL}"
    install -d -m 0755 "$(dirname "${VARNISH_DEFAULT_VCL}")"
    ensure_settings_file
    sed -e "s/__BACKEND_HOST__/${ip}/g" -e "s/__SERVER_IP__/${ip}/g" "${TEMPLATE_VCL}" > "${VARNISH_DEFAULT_VCL}"
    apply_security_headers "${VARNISH_DEFAULT_VCL}"
    chmod 0644 "${VARNISH_DEFAULT_VCL}"
    log "INFO" "Wrote optimised default.vcl"
}

configure_hitch() {
    local certs
    backup_file "${HITCH_CONF}"
    install -d -m 0755 "$(dirname "${HITCH_CONF}")"
    certs=$(grep -h "SSLCertificate" "${HTTPD_CONF}" /etc/apache2/conf.d/*.conf 2>/dev/null | awk '{print $2}' | sort -u)
    cat > "${HITCH_CONF}" <<'EOF'
frontend = "[*]:443"
backend = "[127.0.0.1]:4443"
workers = 4
write-proxy-v2 = on
user = "hitch"
group = "hitch"
keepalive = 3600
daemon = on
quiet = off
EOF
    if [[ -n "${certs}" ]]; then
        while IFS= read -r cert; do
            [[ -f "${cert}" ]] && printf 'pem-file = "%s"\n' "${cert}" >> "${HITCH_CONF}"
        done <<< "${certs}"
    fi
    printf '# pem-dir = "/etc/pki/tls/private"\n' >> "${HITCH_CONF}"
    chmod 0640 "${HITCH_CONF}"
    log "INFO" "Wrote Hitch configuration with detected certificates"
}

reload_services() {
    systemctl enable --now varnish
    systemctl enable --now hitch
    systemctl restart httpd
}

main() {
    local mode="full"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --render-config)
                mode="config"
                ;;
            *)
                abort "Unknown argument: $1"
                ;;
        esac
        shift
    done
    require_root

    if [[ "${mode}" == "config" ]]; then
        local ip
        ip=$(system_ip)
        [[ -z "${ip}" ]] && abort "Unable to determine primary IPv4 address"
        require_python
        configure_default_vcl "${ip}"
        systemctl reload varnish || systemctl restart varnish
        log "INFO" "Configuration applied and Varnish reloaded"
        return 0
    fi

    command_exists dnf || abort "dnf command not found"
    require_python
    ensure_port_reassignment_done

    run_or_warn "Updating system packages" dnf -y update

    if [[ ! -f /etc/yum.repos.d/varnishcache_varnish75.repo ]]; then
        run_or_warn "Adding Varnish Cache 7.5 repository" bash -c "curl -fsSL ${VARNISH_REPO_SCRIPT} | bash"
    else
        log "INFO" "Varnish 7.5 repository already present"
    fi

    run_or_warn "Installing Varnish Cache" dnf -y install varnish
    run_or_warn "Installing Hitch" dnf -y install hitch

    local ip
    ip=$(system_ip)
    [[ -z "${ip}" ]] && abort "Unable to determine primary IPv4 address"

    configure_varnish_service
    configure_default_vcl "${ip}"
    configure_hitch

    reload_services

    run_or_warn "Testing Hitch configuration" hitch --config="${HITCH_CONF}" --test
    systemctl restart hitch
    systemctl restart varnish

    log "INFO" "Provisioning completed successfully"
}

main "$@"
