#!/bin/bash
# Service orchestration helper for the Varnish + Hitch stack.

set -euo pipefail

SUPPORTED_SERVICES=(varnish hitch httpd)

usage() {
    cat <<'EOF'
Usage: varnishctl.sh <command> [options]

Commands:
  status              Show service status summary
  start               Start varnish + hitch
  stop                Stop varnish + hitch
  restart             Restart varnish + hitch
  reload              Reload varnish configuration (via varnishadm)
  enable              Enable services at boot
  disable             Disable services at boot
  purge <url>         Purge a specific URL using varnishadm ban
  flush               Flush all cached objects (ban everything)

Options:
  --format json       Emit status information as JSON (status command only)
EOF
}

is_active() {
    local unit="$1"
    systemctl is-active --quiet "${unit}"
}

service_action() {
    local action="$1"; shift
    for svc in "${SUPPORTED_SERVICES[@]}"; do
        case "${svc}" in
            httpd)
                systemctl "${action}" httpd
                ;;
            *)
                systemctl "${action}" "${svc}"
                ;;
        esac
    done
}

emit_status_text() {
    for svc in "${SUPPORTED_SERVICES[@]}"; do
        local state
        state=$(systemctl is-active "${svc}" || true)
        printf '%-8s : %s\n' "${svc}" "${state}"
    done
    if command -v varnishstat >/dev/null 2>&1; then
        varnishstat -1 -f MAIN.cache_hit,MAIN.cache_miss,MAIN.uptime 2>/dev/null | awk '{printf "%s = %s\n", $1, $2}'
    fi
}

emit_status_json() {
    local first="true"
    printf '{"services":{'
    for svc in "${SUPPORTED_SERVICES[@]}"; do
        [[ "${first}" == "true" ]] && first="false" || printf ','
        local state
        state=$(systemctl is-active "${svc}" 2>/dev/null || echo "unknown")
        printf '"%s":"%s"' "${svc}" "${state}"
    done
    printf '}'
    if command -v varnishstat >/dev/null 2>&1; then
        local hits misses uptime
        hits=$(varnishstat -1 -f MAIN.cache_hit 2>/dev/null | awk '{print $2}' || echo 0)
        misses=$(varnishstat -1 -f MAIN.cache_miss 2>/dev/null | awk '{print $2}' || echo 0)
        uptime=$(varnishstat -1 -f MAIN.uptime 2>/dev/null | awk '{print $2}' || echo 0)
        printf ',"metrics":{"cache_hit":%s,"cache_miss":%s,"uptime":%s}' "${hits}" "${misses}" "${uptime}"
    fi
    printf '}'
}

purge_url() {
    local target="$1"
    command -v varnishadm >/dev/null 2>&1 || {
        echo "varnishadm command not available" >&2
        exit 1
    }
    varnishadm "ban req.url == ${target}"
}

ban_everything() {
    command -v varnishadm >/dev/null 2>&1 || {
        echo "varnishadm command not available" >&2
        exit 1
    }
    varnishadm "ban req.url ~ ."
}

reload_varnish() {
    command -v systemctl >/dev/null 2>&1 || return 1
    systemctl reload varnish || systemctl restart varnish
}

main() {
    local cmd format="text"
    [[ $# -lt 1 ]] && { usage; exit 1; }
    cmd="$1"; shift

    case "${cmd}" in
        status)
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --format)
                        format="$2"; shift 2;;
                    --format=json)
                        format="json"; shift;;
                    --format=*)
                        format="${1#*=}"; shift;;
                    *)
                        usage; exit 1;;
                esac
            done
            if [[ "${format}" == "json" ]]; then
                emit_status_json
            else
                emit_status_text
            fi
            ;;
        start|stop|restart)
            service_action "${cmd}"
            ;;
        reload)
            reload_varnish
            ;;
        enable|disable)
            for svc in "${SUPPORTED_SERVICES[@]}"; do
                systemctl "${cmd}" "${svc}"
            done
            ;;
        purge)
            [[ $# -lt 1 ]] && { echo "Missing URL" >&2; exit 1; }
            purge_url "$1"
            ;;
        flush)
            ban_everything
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
