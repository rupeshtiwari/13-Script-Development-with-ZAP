#!/bin/bash
# Shared helpers for the demo scripts. Sourced, not executed.

# Resolve repo root regardless of where the script is called from.
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${LIB_DIR}/.." && pwd)"

# Load .env so compose variables and the ZAP API key are available to scripts.
if [ -f "${REPO_ROOT}/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    . "${REPO_ROOT}/.env"
    set +a
fi

COMPOSE="docker compose"

# ANSI colours (fall back to empty if not a tty).
if [ -t 1 ]; then
    C_GREEN=$'\033[32m'; C_RED=$'\033[31m'; C_YEL=$'\033[33m'; C_RST=$'\033[0m'
else
    C_GREEN=""; C_RED=""; C_YEL=""; C_RST=""
fi

log()  { echo "[$(date +%H:%M:%S)] $*"; }
warn() { echo "${C_YEL}[warn]${C_RST} $*" >&2; }
die()  { echo "${C_RED}[fatal]${C_RST} $*" >&2; exit 1; }

# HTTP GET that asserts the status code. Never a bare `curl -s`.
#   http_get <url> [expected_code]
# Prints the response body to stdout; returns non-zero on mismatch.
http_get() {
    local url="$1" expected="${2:-200}" body code
    body="$(curl -s -o /tmp/.hg_body -w '%{http_code}' "${url}")"
    code="${body}"
    cat /tmp/.hg_body
    if [ "${code}" != "${expected}" ]; then
        echo "  (expected HTTP ${expected}, got ${code} for ${url})" >&2
        return 1
    fi
    return 0
}

# Return just the status code for a request (through an optional proxy).
#   status_code <url> [proxy]
status_code() {
    local url="$1" proxy="${2:-}"
    if [ -n "${proxy}" ]; then
        curl -s -o /dev/null -w '%{http_code}' -x "${proxy}" "${url}"
    else
        curl -s -o /dev/null -w '%{http_code}' "${url}"
    fi
}
