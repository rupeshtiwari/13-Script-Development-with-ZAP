#!/bin/bash
# Preflight for M1 Clip 3 — "Validate injection, XSS, and CSRF with ZAP".
#
# Drives the running ZAP (via its API) to prove that, on the VULNERABLE build,
# each demo finding is real, and that on the REMEDIATED build the fixes hold.
#
# For every HTTP call we assert the status code (never a bare `curl -s`), and
# the injection probes are sent through the ZAP proxy so ZAP sees the traffic.
#
# Exit code is non-zero if any check fails.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# ---- endpoints (as seen from ZAP, inside the compose network) --------------
APP_INTERNAL="http://app:8000"          # how ZAP reaches the app
APP_LOCAL="http://localhost:8000"       # how this script reaches the app
ZAP="http://localhost:8090"             # ZAP API + proxy (same port)
PROXY="http://localhost:8090"
K="${ZAP_API_KEY:?ZAP_API_KEY must be set}"

# Scan policy: ONLY the SQL-injection family, NoSQL 40033, and command
# injection 90020/90037. (40024/SQLite is absent from this ZAP build.)
POLICY="m1clip3"
SQLI_FAMILY="40018 40019 40020 40021 40022 40027"
POLICY_IDS="${SQLI_FAMILY} 40033 90020 90037"

PASS=0
FAIL=0
declare -a RESULTS

pass() { echo "${C_GREEN}PASS${C_RST} $*"; PASS=$((PASS+1)); RESULTS+=("PASS $*"); }
fail() { echo "${C_RED}FAIL${C_RST} $*"; FAIL=$((FAIL+1)); RESULTS+=("FAIL $*"); }

enc() { python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=""))' "$1"; }

# zap_api <path> <query> — call the ZAP API, assert HTTP 200, return the body.
zap_api() {
    local path="$1" query="${2:-}" body code
    body="$(curl -s -o /tmp/.zap_body -w '%{http_code}' \
        "${ZAP}/JSON/${path}/?apikey=${K}&${query}")"
    code="${body}"
    if [ "${code}" != "200" ]; then
        echo "  (ZAP API ${path} returned HTTP ${code})" >&2
        return 1
    fi
    cat /tmp/.zap_body
}

json_get() { python3 -c 'import json,sys;d=json.load(sys.stdin);ks=sys.argv[1].split(".");[d:=d[k] for k in ks];print(d)' "$1"; }

# --------------------------------------------------------------------------
# ZAP readiness + add-on assertions
# --------------------------------------------------------------------------
check_zap_ready() {
    log "Checking ZAP is up and rule 40033 is installed..."
    local ver
    ver="$(zap_api core/view/version)" || { fail "ZAP API not reachable"; return; }
    if echo "${ver}" | grep -q '"version"'; then
        pass "ZAP API reachable ($(echo "${ver}" | tr -d '{}\"'))"
    else
        fail "ZAP API version unexpected: ${ver}"
    fi
    if zap_api autoupdate/view/installedAddons | grep -q '"ascanrulesBeta"'; then
        pass "ascanrulesBeta add-on installed"
    else
        fail "ascanrulesBeta add-on NOT installed"
    fi
    if zap_api ascan/view/scanners | grep -q '"id":"40033"'; then
        pass "NoSQL active-scan rule 40033 available"
    else
        fail "NoSQL active-scan rule 40033 NOT available"
    fi
}

# --------------------------------------------------------------------------
# Build the scoped scan policy
# --------------------------------------------------------------------------
build_policy() {
    log "Building scoped scan policy '${POLICY}' (SQLi family + 40033 + 90020/90037)..."
    zap_api ascan/action/removeScanPolicy "scanPolicyName=${POLICY}" >/dev/null 2>&1 || true
    zap_api ascan/action/addScanPolicy "scanPolicyName=${POLICY}" >/dev/null || true
    zap_api ascan/action/disableAllScanners "scanPolicyName=${POLICY}" >/dev/null || true
    local id
    for id in ${POLICY_IDS}; do
        zap_api ascan/action/enableScanners "ids=${id}&scanPolicyName=${POLICY}" >/dev/null \
            || warn "could not enable scanner ${id}"
    done
    local enabled
    enabled="$(zap_api ascan/view/scanners "scanPolicyName=${POLICY}" \
        | python3 -c 'import json,sys;print(" ".join(sorted(s["id"] for s in json.load(sys.stdin)["scanners"] if s["enabled"]=="true")))')"
    log "Policy enabled scanners: ${enabled}"
    local expected ok=1
    expected="$(echo "${POLICY_IDS}" | tr ' ' '\n' | sort | tr '\n' ' ')"
    for id in ${POLICY_IDS}; do
        echo " ${enabled} " | grep -q " ${id} " || ok=0
    done
    # ensure NOTHING outside the intended set is enabled
    local extra
    extra="$(python3 - "${enabled}" "${POLICY_IDS}" <<'PY'
import sys
enabled=set(sys.argv[1].split())
allowed=set(sys.argv[2].split())
print(" ".join(sorted(enabled-allowed)))
PY
)"
    if [ "${ok}" = "1" ] && [ -z "${extra}" ]; then
        pass "Scan policy contains exactly the intended rules"
    else
        fail "Scan policy mismatch (extra: '${extra}')"
    fi
}

# --------------------------------------------------------------------------
# Active-scan one endpoint and assert an expected alert id fired on it
# --------------------------------------------------------------------------
# active_scan_expect <url> <param-desc> <alertid>[,<alertid>...]
active_scan_expect() {
    local url="$1" desc="$2" wanted="$3"
    local eu sid st
    eu="$(enc "${url}")"
    # Seed the endpoint into ZAP's site tree, asserting the app answers.
    zap_api core/action/accessUrl "url=${eu}&followRedirects=false" >/dev/null \
        || { fail "could not access ${url} via ZAP"; return; }
    sid="$(zap_api ascan/action/scan "url=${eu}&recurse=false&scanPolicyName=${POLICY}" | json_get scan)"
    if ! [[ "${sid}" =~ ^[0-9]+$ ]]; then fail "active scan did not start for ${url}"; return; fi
    local waited=0
    while :; do
        st="$(zap_api ascan/view/status "scanId=${sid}" | json_get status)"
        [ "${st}" = "100" ] && break
        sleep 3; waited=$((waited+3))
        [ "${waited}" -gt 600 ] && { fail "active scan timed out for ${url}"; return; }
    done
    # Alerts are raised on the *payload* URL (e.g. ?q=Router'), so filter by the
    # path-only base, not the seeded query string.
    local found base
    base="$(enc "${url%%\?*}")"
    found="$(zap_api core/view/alerts "baseurl=${base}" \
        | python3 -c 'import json,sys;print(" ".join(sorted({a["pluginId"] for a in json.load(sys.stdin)["alerts"]})))')"
    local hit=""
    local id
    for id in ${wanted//,/ }; do
        echo " ${found} " | grep -q " ${id} " && hit="${id}"
    done
    if [ -n "${hit}" ]; then
        pass "active scan of ${desc}: alert ${hit} raised (wanted ${wanted})"
    else
        fail "active scan of ${desc}: none of [${wanted}] raised (saw: ${found:-none})"
    fi
}

# --------------------------------------------------------------------------
# XSS: assert reflected/encoded behaviour in the 3 contexts (through the proxy)
# --------------------------------------------------------------------------
# check_xss <mode: reflected|encoded>
check_xss() {
    local mode="$1" marker='zzXSS<">zz' body
    body="$(curl -s -x "${PROXY}" -o /tmp/.xss -w '%{http_code}' \
        "${APP_INTERNAL}/greet?name=$(enc "${marker}")")"
    if [ "${body}" != "200" ]; then fail "XSS probe returned HTTP ${body}"; return; fi
    body="$(cat /tmp/.xss)"
    if [ "${mode}" = "reflected" ]; then
        # The raw marker (with '<' and an unescaped '"') must survive verbatim
        # in each of the three sink contexts.
        grep -qF '<p>Hello zzXSS<">zz</p>' <<<"${body}" \
            && pass "XSS context 1 (HTML body) reflects unescaped input" \
            || fail "XSS context 1 (HTML body) not reflected"
        grep -qF 'value="zzXSS<">zz"' <<<"${body}" \
            && pass "XSS context 2 (HTML attribute) reflects unescaped input" \
            || fail "XSS context 2 (HTML attribute) not reflected"
        grep -qF 'var greeting = "zzXSS<">zz"' <<<"${body}" \
            && pass "XSS context 3 (JS string) reflects unescaped input" \
            || fail "XSS context 3 (JS string) not reflected"
    else
        grep -qF '<p>Hello zzXSS&lt;&quot;&gt;zz</p>' <<<"${body}" \
            && pass "XSS context 1 (HTML body) is HTML-encoded" \
            || fail "XSS context 1 (HTML body) not encoded"
        grep -qF 'value="zzXSS&lt;&quot;&gt;zz"' <<<"${body}" \
            && pass "XSS context 2 (HTML attribute) is HTML-encoded" \
            || fail "XSS context 2 (HTML attribute) not encoded"
        # The '"' must be escaped so the marker cannot break out of the JS string.
        if ! grep -qF 'zzXSS<">zz' <<<"${body}" && grep -qF 'var greeting = "zzXSS<\">zz"' <<<"${body}"; then
            pass "XSS context 3 (JS string) is JS-encoded"
        else
            fail "XSS context 3 (JS string) not encoded"
        fi
    fi
}

# --------------------------------------------------------------------------
# CSRF: exercise the 5 scenarios through the proxy and assert the codes
# --------------------------------------------------------------------------
# check_csrf "<valid> <missing> <invalid> <reused> <cross>"
check_csrf() {
    local expect=($1)
    local ca=/tmp/.csrf_a cb=/tmp/.csrf_b
    rm -f "${ca}" "${cb}"
    local sc
    # POST helper through the proxy that asserts we actually reached the app.
    csrf_post() { # <cookiejar> <data>
        curl -s -x "${PROXY}" -o /dev/null -w '%{http_code}' \
            -b "$1" -X POST --data "$2" "${APP_INTERNAL}/account/email"
    }
    # Session A
    curl -s -x "${PROXY}" -o /dev/null -c "${ca}" -X POST --data 'username=alice' \
        "${APP_INTERNAL}/login" >/dev/null
    local tokA
    tokA="$(curl -s -x "${PROXY}" -b "${ca}" "${APP_INTERNAL}/account/email" \
        | grep -o '[a-f0-9]\{32\}' | head -1)"
    [ -n "${tokA}" ] || { fail "CSRF: could not obtain a token for session A"; return; }

    sc="$(csrf_post "${ca}" "email=new@globomantics.example&csrf_token=${tokA}")"
    [ "${sc}" = "${expect[0]}" ] && pass "CSRF valid token -> ${sc}" \
        || fail "CSRF valid token -> ${sc} (expected ${expect[0]})"

    sc="$(csrf_post "${ca}" "email=new@globomantics.example")"
    [ "${sc}" = "${expect[1]}" ] && pass "CSRF missing token -> ${sc}" \
        || fail "CSRF missing token -> ${sc} (expected ${expect[1]})"

    sc="$(csrf_post "${ca}" "email=new@globomantics.example&csrf_token=deadbeefdeadbeefdeadbeefdeadbeef")"
    [ "${sc}" = "${expect[2]}" ] && pass "CSRF invalid token -> ${sc}" \
        || fail "CSRF invalid token -> ${sc} (expected ${expect[2]})"

    # Reuse token A a second time (a fresh token is needed after the valid use).
    local tokReuse
    tokReuse="$(curl -s -x "${PROXY}" -b "${ca}" "${APP_INTERNAL}/account/email" \
        | grep -o '[a-f0-9]\{32\}' | head -1)"
    csrf_post "${ca}" "email=first@globomantics.example&csrf_token=${tokReuse}" >/dev/null
    sc="$(csrf_post "${ca}" "email=again@globomantics.example&csrf_token=${tokReuse}")"
    [ "${sc}" = "${expect[3]}" ] && pass "CSRF reused token -> ${sc}" \
        || fail "CSRF reused token -> ${sc} (expected ${expect[3]})"

    # Session B cookie with a token minted for session A.
    curl -s -x "${PROXY}" -o /dev/null -c "${cb}" -X POST --data 'username=bob' \
        "${APP_INTERNAL}/login" >/dev/null
    local tokCross
    tokCross="$(curl -s -x "${PROXY}" -b "${ca}" "${APP_INTERNAL}/account/email" \
        | grep -o '[a-f0-9]\{32\}' | head -1)"
    sc="$(csrf_post "${cb}" "email=cross@globomantics.example&csrf_token=${tokCross}")"
    [ "${sc}" = "${expect[4]}" ] && pass "CSRF session-A token + session-B cookie -> ${sc}" \
        || fail "CSRF session-A token + session-B cookie -> ${sc} (expected ${expect[4]})"
}

# --------------------------------------------------------------------------
# Switch the app build in place and wait for it to be healthy
# --------------------------------------------------------------------------
set_build() {
    local build="$1"
    log "Switching app to APP_BUILD=${build}..."
    ( cd "${REPO_ROOT}" && APP_BUILD="${build}" ${COMPOSE} up -d --build app >/dev/null 2>&1 )
    local cid deadline
    cid="$(cd "${REPO_ROOT}" && ${COMPOSE} ps -q app)"
    deadline=$(( $(date +%s) + 120 ))
    while :; do
        [ "$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "${cid}")" = "healthy" ] && break
        [ "$(date +%s)" -ge "${deadline}" ] && { fail "app did not become healthy on build ${build}"; return 1; }
        sleep 3
    done
    # Confirm the reported build via the health endpoint (asserted status).
    local reported
    reported="$(http_get "${APP_LOCAL}/health" 200 | python3 -c 'import json,sys;print(json.load(sys.stdin)["build"])')" \
        || { fail "health check failed after switching to ${build}"; return 1; }
    if [ "${reported}" = "${build}" ]; then
        pass "app is running the ${build} build"
    else
        fail "app reports build '${reported}', expected '${build}'"
    fi
}

# --------------------------------------------------------------------------
run_build_checks() {
    local build="$1"
    echo
    echo "=================================================================="
    echo " BUILD: ${build}"
    echo "=================================================================="
    zap_api core/action/deleteAllAlerts >/dev/null || true

    if [ "${build}" = "vulnerable" ]; then
        active_scan_expect "${APP_INTERNAL}/search?q=Router"          "SQLi /search (q)"        "40018,40022"
        active_scan_expect "${APP_INTERNAL}/api/account?username=alice" "NoSQL /api/account (username)" "40033"
        active_scan_expect "${APP_INTERNAL}/admin/ping?host=127.0.0.1"  "Cmd inj /admin/ping (host)"    "90020,90037"
        check_xss reflected
        check_csrf "200 403 403 200 200"
    else
        # On the remediated build the same active scans must raise NOTHING.
        remediated_scan_clean "${APP_INTERNAL}/search?q=Router"           "SQLi /search"
        remediated_scan_clean "${APP_INTERNAL}/api/account?username=alice" "NoSQL /api/account"
        remediated_scan_clean "${APP_INTERNAL}/admin/ping?host=127.0.0.1"  "Cmd inj /admin/ping"
        check_xss encoded
        check_csrf "200 403 403 403 403"
    fi
}

# remediated_scan_clean <url> <desc> — scan and assert NO in-scope injection alert
remediated_scan_clean() {
    local url="$1" desc="$2" eu sid st found
    eu="$(enc "${url}")"
    zap_api core/action/accessUrl "url=${eu}&followRedirects=false" >/dev/null || true
    sid="$(zap_api ascan/action/scan "url=${eu}&recurse=false&scanPolicyName=${POLICY}" | json_get scan)"
    if ! [[ "${sid}" =~ ^[0-9]+$ ]]; then fail "scan did not start for ${url}"; return; fi
    local waited=0
    while :; do
        st="$(zap_api ascan/view/status "scanId=${sid}" | json_get status)"
        [ "${st}" = "100" ] && break
        sleep 3; waited=$((waited+3)); [ "${waited}" -gt 600 ] && break
    done
    # Only our in-policy rule ids count (ignore always-on passive header alerts).
    local base
    base="$(enc "${url%%\?*}")"
    found="$(zap_api core/view/alerts "baseurl=${base}" \
        | python3 -c 'import json,sys;print(" ".join(sorted({a["pluginId"] for a in json.load(sys.stdin)["alerts"]})))')"
    local bad="" id
    for id in ${POLICY_IDS}; do
        echo " ${found} " | grep -q " ${id} " && bad="${bad} ${id}"
    done
    if [ -z "${bad}" ]; then
        pass "remediated ${desc}: no injection alert (clean)"
    else
        fail "remediated ${desc}: still raising${bad}"
    fi
}

# ==========================================================================
main() {
    cd "${REPO_ROOT}"
    log "Preflight starting. ZAP=${ZAP} app(internal)=${APP_INTERNAL}"

    check_zap_ready
    build_policy

    set_build vulnerable && run_build_checks vulnerable
    set_build remediated && run_build_checks remediated

    # Leave the stack on the vulnerable build (the demo's default starting point).
    set_build vulnerable >/dev/null 2>&1 || true

    echo
    echo "=================================================================="
    echo " SUMMARY: ${PASS} passed, ${FAIL} failed"
    echo "=================================================================="
    if [ "${FAIL}" -gt 0 ]; then
        printf '%s\n' "${RESULTS[@]}" | grep '^FAIL' >&2
        exit 1
    fi
    echo "${C_GREEN}All preflight checks passed for both builds.${C_RST}"
}

main "$@"
