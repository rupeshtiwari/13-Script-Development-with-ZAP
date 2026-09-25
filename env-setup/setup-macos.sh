#!/bin/bash
# =============================================================================
# One-file environment setup for the Globomantics ZAP demos (macOS, Apple Silicon)
# =============================================================================
# Run this ONCE before any demo:
#
#     ./env-setup/setup-macos.sh
#
# It checks every dependency the demos need, installs whatever is missing, and
# writes a full verbose transcript to env-setup/logs/. When it finishes it
# prints a readiness table so you can see, at a glance, whether the machine is
# ready. If anything is not ready it prints the exact command to fix it.
#
# Nothing here touches the demo application or ZAP itself; it only prepares the
# tools the demos rely on.
# =============================================================================
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${REPO_ROOT}/env-setup/logs"
mkdir -p "${LOG_DIR}"
LOG="${LOG_DIR}/setup-$(date +%Y%m%d-%H%M%S).log"

# Mirror everything to the log as well as the screen.
exec > >(tee -a "${LOG}") 2>&1

# --- versions the demos are built against ------------------------------------
COLIMA_TARGET="0.10.4"        # outline baseline (0.10.3 also works)
ZAP_IMAGE="ghcr.io/zaproxy/zaproxy:stable@sha256:781a2bdaea47324e7bab583e2263f21d257b0aee61ed51521a5be45f5f5081ef"

C_H=$'\033[38;5;45m'; C_OK=$'\033[38;5;42m'; C_NO=$'\033[38;5;196m'
C_FIX=$'\033[38;5;214m'; C_MUT=$'\033[38;5;240m'; C_RST=$'\033[0m'
[ -t 1 ] || { C_H=""; C_OK=""; C_NO=""; C_FIX=""; C_MUT=""; C_RST=""; }

declare -a REPORT     # "name|status|detail|fix"
ready=1

step()  { echo; echo "${C_H}=== $* ===${C_RST}"; }
record(){ REPORT+=("$1|$2|$3|${4:-}"); [ "$2" = "READY" ] || ready=0; }

echo "${C_H}Globomantics ZAP demo — environment setup${C_RST}"
echo "${C_MUT}host: $(uname -mrs)    date: $(date)    log: ${LOG}${C_RST}"

# --- 1. Homebrew -------------------------------------------------------------
step "Homebrew"
if command -v brew >/dev/null 2>&1; then
    echo "brew found: $(brew --version | head -1)"
    record "Homebrew" "READY" "$(brew --version | head -1)"
else
    echo "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
        && record "Homebrew" "READY" "installed just now" \
        || record "Homebrew" "MISSING" "install failed" \
                  'run the Homebrew installer from https://brew.sh, then re-run this script'
fi

# helper: ensure a brew formula is installed, capture its version
ensure_brew() { # <formula> <version-cmd> <label>
    local formula="$1" vcmd="$2" label="$3" ver
    step "${label}"
    if command -v "${formula}" >/dev/null 2>&1; then
        ver="$(eval "${vcmd}" 2>/dev/null | head -1)"
        echo "${formula} found: ${ver}"
        record "${label}" "READY" "${ver}"
    else
        echo "${formula} not found. Installing with Homebrew..."
        if brew install "${formula}"; then
            ver="$(eval "${vcmd}" 2>/dev/null | head -1)"
            record "${label}" "READY" "${ver:-installed}"
        else
            record "${label}" "MISSING" "brew install ${formula} failed" \
                   "brew install ${formula}"
        fi
    fi
}

ensure_brew colima "colima version"          "Colima"
ensure_brew docker "docker --version"        "Docker CLI"
ensure_brew tmux   "tmux -V"                 "tmux"
ensure_brew python3 "python3 --version"      "Python 3"

# docker compose is a plugin, checked separately
step "Docker Compose plugin"
if docker compose version >/dev/null 2>&1; then
    echo "compose found: $(docker compose version)"
    record "Docker Compose" "READY" "$(docker compose version | head -1)"
else
    echo "compose plugin not found. Installing docker-compose..."
    brew install docker-compose
    mkdir -p ~/.docker
    if [ ! -f ~/.docker/config.json ]; then
        echo '{ "cliPluginsExtraDirs": ["/opt/homebrew/lib/docker/cli-plugins"] }' > ~/.docker/config.json
    fi
    if docker compose version >/dev/null 2>&1; then
        record "Docker Compose" "READY" "$(docker compose version | head -1)"
    else
        record "Docker Compose" "MISSING" "plugin not on Docker's path" \
               'add "cliPluginsExtraDirs":["/opt/homebrew/lib/docker/cli-plugins"] to ~/.docker/config.json'
    fi
fi

# --- Colima version note (target vs installed) -------------------------------
if command -v colima >/dev/null 2>&1; then
    cver="$(colima version 2>/dev/null | awk '/colima version/{print $3}')"
    if [ "${cver}" != "${COLIMA_TARGET}" ]; then
        echo "${C_MUT}note: Colima ${cver} installed; outline baseline is ${COLIMA_TARGET} (functionally equivalent).${C_RST}"
    fi
fi

# --- 2. Colima VM running ----------------------------------------------------
step "Colima virtual machine"
if colima status >/dev/null 2>&1; then
    echo "Colima is running:"; colima status 2>&1 | sed 's/^/  /'
    record "Colima VM" "READY" "running"
else
    echo "Starting Colima (4 CPU / 8 GiB / aarch64)..."
    if colima start --cpu 4 --memory 8 --arch aarch64; then
        record "Colima VM" "READY" "started just now"
    else
        record "Colima VM" "MISSING" "colima start failed" \
               "colima start --cpu 4 --memory 8 --arch aarch64"
    fi
fi

# --- 3. Docker daemon reachable ---------------------------------------------
step "Docker daemon"
if docker info >/dev/null 2>&1; then
    echo "Docker daemon reachable: $(docker info --format '{{.ServerVersion}}' 2>/dev/null)"
    record "Docker daemon" "READY" "server $(docker info --format '{{.ServerVersion}}' 2>/dev/null)"
else
    record "Docker daemon" "MISSING" "cannot reach the Docker daemon" \
           "colima start   (then re-run this script)"
fi

# --- 4. Pinned ZAP image -----------------------------------------------------
step "Pinned ZAP image"
if docker image inspect "${ZAP_IMAGE}" >/dev/null 2>&1; then
    echo "ZAP image already present locally."
    record "ZAP image" "READY" "present (pinned digest)"
elif docker info >/dev/null 2>&1; then
    echo "Pulling the pinned ZAP image (first run only; this can take a few minutes)..."
    if docker pull "${ZAP_IMAGE}"; then
        record "ZAP image" "READY" "pulled just now"
    else
        record "ZAP image" "MISSING" "docker pull failed" \
               "docker pull ${ZAP_IMAGE}"
    fi
else
    record "ZAP image" "MISSING" "Docker daemon not reachable" \
           "start Colima, then: docker pull ${ZAP_IMAGE}"
fi

# =============================================================================
# Readiness table
# =============================================================================
step "Readiness summary"
printf "%-18s %-9s %s\n" "COMPONENT" "STATUS" "DETAIL"
printf "%-18s %-9s %s\n" "------------------" "---------" "----------------------------------------"
for row in "${REPORT[@]}"; do
    IFS='|' read -r name status detail fix <<<"${row}"
    if [ "${status}" = "READY" ]; then
        printf "%-18s ${C_OK}%-9s${C_RST} %s\n" "${name}" "READY" "${detail}"
    else
        printf "%-18s ${C_NO}%-9s${C_RST} %s\n" "${name}" "${status}" "${detail}"
    fi
done

echo
if [ "${ready}" = "1" ]; then
    echo "${C_OK}All components are READY. You can start the demo:${C_RST}"
    echo "    ./module1/m1-demo1-validate-injection-xss-and-csrf-with-zap/scripts/demo_up.sh"
    echo
    echo "${C_MUT}Full transcript: ${LOG}${C_RST}"
    exit 0
fi

echo "${C_NO}Some components are not ready. Fix these, then re-run this script:${C_RST}"
for row in "${REPORT[@]}"; do
    IFS='|' read -r name status detail fix <<<"${row}"
    [ "${status}" = "READY" ] && continue
    echo "  ${C_NO}${name}:${C_RST} ${detail}"
    [ -n "${fix}" ] && echo "      ${C_FIX}fix:${C_RST} ${fix}"
done
echo
echo "${C_MUT}Full transcript: ${LOG}${C_RST}"
exit 1
