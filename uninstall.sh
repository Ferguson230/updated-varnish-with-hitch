#!/bin/bash
# Convenience uninstaller to remove plugins and optionally the Varnish + Hitch stack.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}"
WHM_UNINSTALLER="${REPO_ROOT}/plugins/whm/scripts/uninstall.sh"
CPANEL_UNINSTALLER="${REPO_ROOT}/plugins/cpanel/scripts/uninstall.sh"

REMOVE_PACKAGES=true
RUN_WHM=true
RUN_CPANEL=true
STOP_SERVICES=true
RESTART_HTTPD=true

usage() {
    cat <<'EOF'
Usage: sudo ./uninstall.sh [options]

Options:
  --keep-packages       Do not remove varnish/hitch packages.
  --skip-services       Do not stop or disable systemd services.
  --skip-httpd-restart  Do not restart Apache after teardown.
  --skip-plugins        Skip both WHM and cPanel plugin removal.
  --skip-whm            Skip WHM plugin removal.
  --skip-cpanel         Skip cPanel plugin removal.
  --whm-only            Only remove the WHM plugin.
  --cpanel-only         Only remove the cPanel plugin.
  -h, --help            Show this help message.

This script does not revert Apache back to ports 80/443; adjust via WHM Tweak Settings when finished.
EOF
}

log() {
    printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

require_root() {
    if [[ ${EUID} -ne 0 ]]; then
        echo "This uninstaller must be run as root (try sudo)." >&2
        exit 1
    fi
}

ensure_executable() {
    local path="$1"
    if [[ ! -f "${path}" ]]; then
        echo "Required script missing: ${path}" >&2
        exit 1
    fi
    if [[ ! -x "${path}" ]]; then
        chmod +x "${path}"
    fi
}

run_step() {
    local description="$1"
    shift
    log "${description}"
    "$@"
    log "Completed: ${description}"
}

run_step_soft() {
    local description="$1"
    shift
    log "${description}"
    if "$@"; then
        log "Completed: ${description}"
    else
        log "Warning: ${description} failed but continuing"
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --keep-packages)
            REMOVE_PACKAGES=false
            shift
            ;;
        --skip-services)
            STOP_SERVICES=false
            shift
            ;;
        --skip-httpd-restart)
            RESTART_HTTPD=false
            shift
            ;;
        --skip-plugins)
            RUN_WHM=false
            RUN_CPANEL=false
            shift
            ;;
        --skip-whm)
            RUN_WHM=false
            shift
            ;;
        --skip-cpanel)
            RUN_CPANEL=false
            shift
            ;;
        --whm-only)
            RUN_WHM=true
            RUN_CPANEL=false
            shift
            ;;
        --cpanel-only)
            RUN_CPANEL=true
            RUN_WHM=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
    shift
done

require_root
if ${RUN_WHM}; then
    ensure_executable "${WHM_UNINSTALLER}"
fi
if ${RUN_CPANEL}; then
    ensure_executable "${CPANEL_UNINSTALLER}"
fi

if ${STOP_SERVICES}; then
    run_step_soft "Stopping varnish" systemctl stop varnish
    run_step_soft "Stopping hitch" systemctl stop hitch
    run_step_soft "Disabling varnish" systemctl disable varnish
    run_step_soft "Disabling hitch" systemctl disable hitch
else
    log "Skipping service stop/disable"
fi

if ${RUN_WHM}; then
    run_step "Removing WHM plugin" bash "${WHM_UNINSTALLER}"
else
    log "Skipping WHM plugin removal"
fi

if ${RUN_CPANEL}; then
    run_step "Removing cPanel plugin" bash "${CPANEL_UNINSTALLER}"
    # Clean up generated sudoers file
    run_step_soft "Removing generated sudoers entries" rm -f /etc/sudoers.d/varnish-cpanel-users
else
    log "Skipping cPanel plugin removal"
fi

if ${REMOVE_PACKAGES}; then
    run_step_soft "Removing varnish/hitch packages" dnf -y remove varnish hitch
else
    log "Leaving varnish/hitch packages installed"
fi

run_step_soft "Reloading systemd" systemctl daemon-reload

if ${RESTART_HTTPD}; then
    run_step_soft "Restarting Apache" systemctl restart httpd
else
    log "Skipping Apache restart"
fi

log "Uninstall workflow complete."
