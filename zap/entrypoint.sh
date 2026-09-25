#!/bin/bash
# Start ZAP with the Webswing GUI, boot the ZAP core so its API/proxy is
# available, then install and verify the ascanrulesBeta add-on (rule 40033).
#
# The Webswing GUI only launches the ZAP core when a browser attaches. We kick
# that with an in-container headless Firefox; the ZAP core then keeps running
# (sessionMode CONTINUE_FOR_USER) after the kick browser exits, and the author
# can attach their own browser to the GUI at any time.
set -euo pipefail

API_KEY="${ZAP_API_KEY:?ZAP_API_KEY must be set}"
GUI_PORT=8080
API_PORT=8090

# ZAP core options applied when the GUI launches the core:
#  - fixed API key and open API addresses (author tooling reaches it via 8090)
#  - suppress the first-run "persist session?" dialog that otherwise blocks boot
#  - skip update/add-on-update checks at startup for a deterministic boot
export ZAP_WEBSWING_OPTS="-host 0.0.0.0 -port ${API_PORT} \
-config api.key=${API_KEY} \
-config api.addrs.addr.name=.* -config api.addrs.addr.regex=true \
-config database.newsessionprompt=false \
-config start.checkForUpdates=false \
-config start.checkAddonUpdates=false \
-config connection.dnsTtlSuccessfulQueries=-1"

# Persist the ZAP core after the kick browser disconnects.
sed -i 's/CONTINUE_FOR_BROWSER/CONTINUE_FOR_USER/' /zap/webswing/webswing.config

echo "[zap-entrypoint] starting Webswing GUI..."
zap-webswing.sh &
WEBSWING_PID=$!

echo "[zap-entrypoint] waiting for Webswing GUI on :${GUI_PORT}..."
for _ in $(seq 1 60); do
    if [ "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${GUI_PORT}/zap/")" = "200" ]; then
        break
    fi
    sleep 2
done

echo "[zap-entrypoint] kicking the ZAP core via headless browser..."
KICK_PROFILE="$(mktemp -d)"
firefox-esr --headless --no-remote --profile "${KICK_PROFILE}" \
    "http://localhost:${GUI_PORT}/zap/" >/tmp/zap-kick.log 2>&1 &
KICK_PID=$!

echo "[zap-entrypoint] waiting for the ZAP API on :${API_PORT}..."
API_UP=""
for _ in $(seq 1 90); do
    code="$(curl -s -o /dev/null -w '%{http_code}' \
        "http://localhost:${API_PORT}/JSON/core/view/version/?apikey=${API_KEY}")"
    if [ "${code}" = "200" ]; then
        API_UP=1
        break
    fi
    sleep 2
done
if [ -z "${API_UP}" ]; then
    echo "[zap-entrypoint] ERROR: ZAP API did not come up" >&2
    exit 1
fi
echo "[zap-entrypoint] ZAP core is up: $(curl -s "http://localhost:${API_PORT}/JSON/core/view/version/?apikey=${API_KEY}")"

# The kick browser has served its purpose; the core persists without it.
kill "${KICK_PID}" >/dev/null 2>&1 || true

api() {
    curl -s "http://localhost:${API_PORT}/JSON/$1/?apikey=${API_KEY}&${2:-}"
}

# Install ascanrulesBeta (provides NoSQL MongoDB rule 40033) unless already present.
if api ascan/view/scanners "scanId=40033" | grep -q '"id":"40033"'; then
    echo "[zap-entrypoint] ascanrulesBeta already present (rule 40033 found)."
else
    echo "[zap-entrypoint] installing ascanrulesBeta from the marketplace..."
    api autoupdate/action/installAddon "id=ascanrulesBeta" >/dev/null
    for _ in $(seq 1 60); do
        if api autoupdate/view/installedAddons | grep -q '"ascanrulesBeta"'; then
            break
        fi
        sleep 2
    done
fi

# Verify the add-on and rule 40033.
INSTALLED="$(api autoupdate/view/installedAddons)"
BETA_VER="$(echo "${INSTALLED}" | tr ',{}' '\n\n\n' | grep -A2 '"ascanrulesBeta"' | grep -oE '"version":"[0-9.]+"' | grep -oE '[0-9.]+' | head -1)"
if ! echo "${INSTALLED}" | grep -q '"ascanrulesBeta"'; then
    echo "[zap-entrypoint] ERROR: ascanrulesBeta not installed" >&2
    exit 1
fi
if ! api ascan/view/scanners "scanId=40033" | grep -q '"id":"40033"'; then
    echo "[zap-entrypoint] ERROR: NoSQL rule 40033 not available after install" >&2
    exit 1
fi
BETA_MAJOR="${BETA_VER%%.*}"
if [ -n "${BETA_MAJOR}" ] && [ "${BETA_MAJOR}" -lt 66 ] 2>/dev/null; then
    echo "[zap-entrypoint] WARNING: ascanrulesBeta version ${BETA_VER} is below v66" >&2
fi
echo "[zap-entrypoint] ascanrulesBeta v${BETA_VER} installed; NoSQL rule 40033 available."

touch /tmp/zap-ready
echo "[zap-entrypoint] READY. GUI: http://localhost:${GUI_PORT}/zap/  API/proxy: :${API_PORT}"

# Hand back to Webswing in the foreground so the container stays up.
wait "${WEBSWING_PID}"
