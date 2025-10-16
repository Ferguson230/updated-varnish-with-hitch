#!/bin/bash
# Convenience installer that provisions Varnish + Hitch and deploys the WHM/cPanel plugins.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}"
PROVISIONER="${REPO_ROOT}/service/bin/provision.sh"
WHM_INSTALLER="${REPO_ROOT}/plugins/whm/scripts/install.sh"
CPANEL_INSTALLER="${REPO_ROOT}/plugins/cpanel/scripts/install.sh"

INSTALL_PROVISION=true
INSTALL_WHM=true
INSTALL_CPANEL=true
PROVISION_ARGS=()

usage() {
    cat <<'EOF'
Usage: sudo ./install.sh [options] [-- <provisioner args>]

Options:
  --skip-provision   Skip the Varnish + Hitch provisioning step.
  --skip-plugins     Skip installing both WHM and cPanel plugins.
  --skip-whm         Skip installing the WHM plugin.
  --skip-cpanel      Skip installing the cPanel plugin.
  --whm-only         Only install the WHM plugin (implies --skip-cpanel).
  --cpanel-only      Only install the cPanel plugin (implies --skip-whm).
  -h, --help         Show this help message.

Any arguments after "--" are passed directly to service/bin/provision.sh.
Examples:
  sudo ./install.sh
  sudo ./install.sh --skip-plugins
  sudo ./install.sh -- --render-config
EOF
}

log() {
    printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

require_root() {
    if [[ ${EUID} -ne 0 ]]; then
        echo "This installer must be run as root (try sudo)." >&2
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

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-provision)
            INSTALL_PROVISION=false
            shift
            ;;
        --skip-plugins)
            INSTALL_WHM=false
            INSTALL_CPANEL=false
            shift
            ;;
        --skip-whm)
            INSTALL_WHM=false
            shift
            ;;
        --skip-cpanel)
            INSTALL_CPANEL=false
            shift
            ;;
        --whm-only)
            INSTALL_WHM=true
            INSTALL_CPANEL=false
            shift
            ;;
        --cpanel-only)
            INSTALL_CPANEL=true
            INSTALL_WHM=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            PROVISION_ARGS=("$@")
            break
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
ensure_executable "${PROVISIONER}"
ensure_executable "${WHM_INSTALLER}"
ensure_executable "${CPANEL_INSTALLER}"

if ${INSTALL_PROVISION}; then
    run_step "Provisioning Varnish + Hitch" "${PROVISIONER}" "${PROVISION_ARGS[@]}"
else
    log "Skipping provisioning as requested"
fi

if ${INSTALL_WHM}; then
    run_step "Installing WHM plugin" bash "${WHM_INSTALLER}"
else
    log "Skipping WHM plugin install"
fi

if ${INSTALL_CPANEL}; then
    run_step "Installing cPanel plugin" bash "${CPANEL_INSTALLER}"
    # Ensure sudoers reflect current cPanel users automatically
    if [[ -x "${REPO_ROOT}/service/bin/update_sudoers.sh" ]]; then
        run_step "Updating sudoers for cPanel users" bash "${REPO_ROOT}/service/bin/update_sudoers.sh"
    fi
else
    log "Skipping cPanel plugin install"
fi

log "Installation workflow complete."
