#!/bin/bash

set -euo pipefail

LOG_FILE="/var/log/update_hitch_certs.log"
HITCH_CONF="/etc/hitch/hitch.conf"
HTTPD_CONF="/etc/apache2/conf/httpd.conf"

log() {
    printf '%s %s\n' "$(date '+%F %T')" "$*" >> "${LOG_FILE}"
}

collect_certs() {
    grep -h "SSLCertificate" "${HTTPD_CONF}" /etc/apache2/conf.d/*.conf 2>/dev/null | awk '{print $2}' | sort -u
}

write_config() {
    cat > "${HITCH_CONF}" <<'EOF'
frontend = "[*]:443"
backend = "[127.0.0.1]:4443"
workers = 4
write-proxy-v2 = on
user = "hitch"

keepalive = 3600
daemon = on
quiet = off
EOF
}

main() {
    log "Starting certificate refresh"
    local certs
    certs=$(collect_certs)
    [[ -z "${certs}" ]] && {
        log "No certificates found";
        exit 1
    }

    write_config
    while IFS= read -r cert; do
        if [[ -f "${cert}" ]]; then
            printf 'pem-file = "%s"\n' "${cert}" >> "${HITCH_CONF}"
            log "Added ${cert}"
        else
            log "Missing ${cert}"
        fi
    done <<< "${certs}"
    printf '# pem-dir = "/etc/pki/tls/private"\n' >> "${HITCH_CONF}"

    systemctl reload hitch || systemctl restart hitch
    log "Hitch reloaded"
}

main "$@"

