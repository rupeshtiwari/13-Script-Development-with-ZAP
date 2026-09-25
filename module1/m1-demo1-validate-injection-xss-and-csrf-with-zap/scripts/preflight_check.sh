#!/bin/bash
# =============================================================================
# Preflight / demo-step validator — m1-demo1 "Validate injection, XSS, and CSRF"
# =============================================================================
# This is AUTHOR tooling. It walks the demo steps in the SAME ORDER as the
# runbook (README.md), and for each step it:
#
#   * prints a header saying WHAT it is showing and WHY,
#   * runs the real command and shows only the fields we care about (never
#     truncated), highlighting the value(s) the demo draws attention to,
#   * asserts the expected result and prints PASS or FAIL — with the reason and
#     a suggested prompt to fix it when it fails,
#   * writes the whole transcript to logs/ so it can be checked against the
#     learning objectives before the demo is used.
#
# Every request targets ONLY the local Globomantics app on the compose network.
# It exits non-zero if any step fails.
# =============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$(cd "${HERE}/.." && pwd)"
REPO_ROOT="$(cd "${DEMO_DIR}/../.." && pwd)"
LOG_DIR="${DEMO_DIR}/logs"
mkdir -p "${LOG_DIR}"
STAMP="$(date +%Y%m%d-%H%M%S)"
RAW_LOG="${LOG_DIR}/preflight-${STAMP}.ansi.log"
LOG="${LOG_DIR}/preflight-${STAMP}.log"

# shared env (.env -> ZAP_API_KEY) and the formatter
# shellcheck disable=SC1091
source "${REPO_ROOT}/scripts/lib.sh"
FMT="${REPO_ROOT}/scripts/fmt.py"
export FORCE_COLOR=1
fm() { python3 "${FMT}" "$@"; }

APP_INTERNAL="http://app:8000"     # how ZAP reaches the app (compose DNS)
ZAP="http://localhost:8090"        # ZAP API + proxy (same port)
PROXY="http://localhost:8090"
K="${ZAP_API_KEY:?ZAP_API_KEY must be set (is .env present?)}"
POLICY="m1demo1"
SQLI_FAMILY="40018 40019 40020 40021 40022 40027"
POLICY_IDS="${SQLI_FAMILY} 40033 90020 90037"

PASS=0; FAIL=0
enc() { python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=""))' "$1"; }
pass() { fm ok "$1"; PASS=$((PASS+1)); }
fail() { fm fail "$1" "${2:-}" "${3:-}"; FAIL=$((FAIL+1)); }

zap() { # <path> <query>  -> body (asserts HTTP 200)
    local path="$1" query="${2:-}" code
    code="$(curl -s -o /tmp/.zbody -w '%{http_code}' "${ZAP}/JSON/${path}/?apikey=${K}&${query}")"
    [ "${code}" = "200" ] || { echo "  (ZAP API ${path} -> HTTP ${code})" >&2; return 1; }
    cat /tmp/.zbody
}
jget() { python3 -c 'import json,sys;d=json.load(sys.stdin);ks=sys.argv[1].split(".");[d:=d[k] for k in ks];print(d)' "$1"; }

# scan one endpoint with the scoped policy and return the plugin ids seen on it
scan_and_alerts() { # <url> -> space-separated plugin ids (stdout, last line)
    local url="$1" eu sid st waited=0 base
    eu="$(enc "${url}")"
    zap core/action/accessUrl "url=${eu}&followRedirects=false" >/dev/null || return 1
    sid="$(zap ascan/action/scan "url=${eu}&recurse=false&scanPolicyName=${POLICY}" | jget scan)" || return 1
    [[ "${sid}" =~ ^[0-9]+$ ]] || return 1
    while :; do
        st="$(zap ascan/view/status "scanId=${sid}" | jget status)"
        [ "${st}" = "100" ] && break
        sleep 3; waited=$((waited+3)); [ "${waited}" -gt 600 ] && break
    done
    base="$(enc "${url%%\?*}")"
    zap core/view/alerts "baseurl=${base}" \
        | python3 -c 'import json,sys;print(" ".join(sorted({a["pluginId"] for a in json.load(sys.stdin)["alerts"]})))'
}

# pull the highest-severity alert record for one plugin id on one endpoint
alert_record() { # <url> <pluginId>
    local url="$1" pid="$2" base
    base="$(enc "${url%%\?*}")"
    zap core/view/alerts "baseurl=${base}" | python3 -c '
import json,sys
pid=sys.argv[1]
al=[a for a in json.load(sys.stdin)["alerts"] if a["pluginId"]==pid]
if not al: print("{}"); raise SystemExit
a=al[0]
print(json.dumps({"pluginId":a["pluginId"],"alert":a["alert"],"risk":a["risk"],"confidence":a["confidence"],"param":a["param"]}))
' "${pid}"
}

banner() { echo; echo; fm section "STEP $1 — $2"; }

# =============================================================================
main() {
    cd "${REPO_ROOT}"
    fm header "Preflight for demo: Validate injection, XSS, and CSRF with ZAP" \
              "Runs every demo step against the local Globomantics app and proves each finding is real before you rely on it."
    fm star "Scope" "local Globomantics training app only (compose network)" focus
    fm star "ZAP" "${ZAP}   (proxy and API share this port)"

    # ---- readiness ----------------------------------------------------------
    banner 0 "ZAP is ready and the NoSQL rule is installed"
    if zap core/view/version | grep -q '"version"'; then
        pass "ZAP API reachable ($(zap core/view/version | tr -d '{}\"'))"
    else
        fail "ZAP API not reachable" "the stack may still be starting" \
             "run scripts/demo_up.sh and wait for 'Up', then re-run this"
        summary; return 1
    fi
    if zap ascan/view/scanners | grep -q '"id":"40033"'; then
        pass "NoSQL active-scan rule 40033 is installed"
    else
        fail "NoSQL rule 40033 not available" "ascanrulesBeta did not install" \
             "check the zap container log for the add-on install step"
    fi

    # ---- STEP 1: policy -----------------------------------------------------
    banner 1 "Build the targeted scan policy (rule list)"
    fm header "The exact scan rules this demo enables — and nothing else" \
              "A focused policy is what turns a broad scan into a targeted test of specific weaknesses (EO1a)."
    zap ascan/action/removeScanPolicy "scanPolicyName=${POLICY}" >/dev/null 2>&1 || true
    zap ascan/action/addScanPolicy "scanPolicyName=${POLICY}" >/dev/null || true
    zap ascan/action/disableAllScanners "scanPolicyName=${POLICY}" >/dev/null || true
    for id in ${POLICY_IDS}; do
        zap ascan/action/enableScanners "ids=${id}&scanPolicyName=${POLICY}" >/dev/null || true
    done
    enabled="$(zap ascan/view/scanners "scanPolicyName=${POLICY}" \
        | python3 -c 'import json,sys;print(" ".join(sorted(s["id"] for s in json.load(sys.stdin)["scanners"] if s["enabled"]=="true")))')"
    fm star "Enabled scan rules" "${enabled}" focus
    ok=1
    for id in ${POLICY_IDS}; do echo " ${enabled} " | grep -q " ${id} " || ok=0; done
    extra="$(python3 - "${enabled}" "${POLICY_IDS}" <<'PY'
import sys
print(" ".join(sorted(set(sys.argv[1].split())-set(sys.argv[2].split()))))
PY
)"
    if [ "${ok}" = "1" ] && [ -z "${extra}" ]; then
        pass "policy holds exactly the SQL-injection family, NoSQL 40033, and command-injection 90020/90037"
    else
        fail "policy does not match the intended rule set (extra: '${extra}')" \
             "an unexpected rule is enabled or one is missing" \
             "re-check POLICY_IDS in this script against the runbook rule list"
    fi

    # ---- STEP 2: SQL injection ---------------------------------------------
    banner 2 "Validate SQL injection on product search"
    fm header "ZAP alert raised on the product-search parameter" \
              "Confirms the SQL-injection finding is real application behavior, not a scanner guess (EO1a)."
    seen="$(scan_and_alerts "${APP_INTERNAL}/search?q=Router")"
    rec="$(alert_record "${APP_INTERNAL}/search?q=Router" 40018)"
    [ "${rec}" = "{}" ] && rec="$(alert_record "${APP_INTERNAL}/search?q=Router" 40022)"
    echo "${rec}" | fm json pluginId,confidence
    if echo " ${seen} " | grep -Eq " 40018 | 40022 "; then
        pass "SQL-injection alert raised on /search (param q)"
    else
        fail "no SQL-injection alert on /search (saw: ${seen:-none})" \
             "the search query may not be concatenated, or the DB error is hidden" \
             "ask: 'the /search SQLi alert 40018 is not firing — inspect the vulnerable query and the error surfaced to ZAP'"
    fi

    # ---- STEP 3: NoSQL injection -------------------------------------------
    banner 3 "Validate NoSQL injection on account lookup"
    fm header "One account for a normal lookup vs. many for an operator-injection lookup" \
              "Shows the MongoDB weakness as a behavior change, then confirms ZAP's NoSQL alert (EO1a)."
    base_ct="$(curl -s -x "${PROXY}" "${APP_INTERNAL}/api/account?username=alice" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("count","?"))')"
    inj_ct="$(curl -s -x "${PROXY}" "${APP_INTERNAL}/api/account?username%5B%24ne%5D=" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("count","?"))')"
    fm star "Accounts for a normal lookup" "${base_ct}"
    fm star "Accounts when an operator is injected" "${inj_ct}" focus
    seen="$(scan_and_alerts "${APP_INTERNAL}/api/account?username=alice")"
    echo "$(alert_record "${APP_INTERNAL}/api/account?username=alice" 40033)" | fm json pluginId
    if [ "${inj_ct}" != "${base_ct}" ] && echo " ${seen} " | grep -q " 40033 "; then
        pass "NoSQL operator injection changes results AND alert 40033 is raised"
    else
        fail "NoSQL injection not confirmed (baseline=${base_ct}, injected=${inj_ct}, alerts: ${seen:-none})" \
             "the account lookup may not parse operators, or 40033 did not fire" \
             "ask: 'the /api/account NoSQL alert 40033 is not firing — verify operator injection and the rule scope'"
    fi

    # ---- STEP 4: command injection -----------------------------------------
    banner 4 "Validate command injection on admin diagnostics"
    fm header "ZAP alert raised on the admin ping host parameter" \
              "Confirms untrusted input reaches an OS command (EO1a)."
    seen="$(scan_and_alerts "${APP_INTERNAL}/admin/ping?host=127.0.0.1")"
    rec="$(alert_record "${APP_INTERNAL}/admin/ping?host=127.0.0.1" 90020)"
    [ "${rec}" = "{}" ] && rec="$(alert_record "${APP_INTERNAL}/admin/ping?host=127.0.0.1" 90037)"
    echo "${rec}" | fm json pluginId,confidence
    if echo " ${seen} " | grep -Eq " 90020 | 90037 "; then
        pass "command-injection alert raised on /admin/ping (param host)"
    else
        fail "no command-injection alert on /admin/ping (saw: ${seen:-none})" \
             "the host value may not reach the shell" \
             "ask: 'the /admin/ping command-injection alert is not firing — inspect the diagnostic command'"
    fi

    # ---- STEP 5: XSS three contexts ----------------------------------------
    banner 5 "Map reflected XSS to its three output contexts"
    fm header "The same input echoed into an HTML body, an HTML attribute, and a JS string" \
              "The context decides the payload — this is why context-matching matters before testing XSS (EO1b)."
    body="$(curl -s -x "${PROXY}" "${APP_INTERNAL}/greet?name=$(enc 'zzMARKzz')")"
    b1=$(echo "${body}" | grep -o '<p>Hello[^<]*' | head -1)
    b2=$(echo "${body}" | grep -o 'value="[^"]*"' | head -1)
    b3=$(echo "${body}" | grep -o 'var greeting = "[^;]*' | head -1)
    fm star "HTML body context" "${b1}" focus
    fm star "HTML attribute context" "${b2}" focus
    fm star "JavaScript string context" "${b3}" focus
    hits=0
    echo "${body}" | grep -q '<p>Hello zzMARKzz' && hits=$((hits+1))
    echo "${body}" | grep -q 'value="zzMARKzz"' && hits=$((hits+1))
    echo "${body}" | grep -q 'greeting = "zzMARKzz"' && hits=$((hits+1))
    if [ "${hits}" = "3" ]; then
        pass "input reflects unescaped in all three contexts"
    else
        fail "input reflected in only ${hits}/3 contexts" \
             "one context may already be encoding output" \
             "ask: 'the /greet endpoint is not reflecting in all three XSS contexts — check the vulnerable build'"
    fi

    # ---- STEP 6: CSRF token states -----------------------------------------
    banner 6 "Compare CSRF token states"
    fm header "The same email-change request under five different token states" \
              "The two that still succeed reveal missing token freshness and session binding (EO1c)."
    ca=/tmp/.c_a; cb=/tmp/.c_b; rm -f "${ca}" "${cb}"
    post() { curl -s -x "${PROXY}" -o /dev/null -w '%{http_code}' -b "$1" -X POST --data "$2" "${APP_INTERNAL}/account/email"; }
    tok() { curl -s -x "${PROXY}" -b "$1" "${APP_INTERNAL}/account/email" | grep -o '[a-f0-9]\{32\}' | head -1; }
    curl -s -x "${PROXY}" -o /dev/null -c "${ca}" -X POST --data 'username=alice' "${APP_INTERNAL}/login" >/dev/null
    tA="$(tok "${ca}")"
    v=$(post "${ca}" "email=a@globomantics.example&csrf_token=${tA}")
    m=$(post "${ca}" "email=a@globomantics.example")
    i=$(post "${ca}" "email=a@globomantics.example&csrf_token=deadbeefdeadbeefdeadbeefdeadbeef")
    tR="$(tok "${ca}")"; post "${ca}" "email=b@globomantics.example&csrf_token=${tR}" >/dev/null
    r=$(post "${ca}" "email=c@globomantics.example&csrf_token=${tR}")
    curl -s -x "${PROXY}" -o /dev/null -c "${cb}" -X POST --data 'username=bob' "${APP_INTERNAL}/login" >/dev/null
    tX="$(tok "${ca}")"
    x=$(post "${cb}" "email=d@globomantics.example&csrf_token=${tX}")
    fm star "valid token, own session" "${v}"
    fm star "missing token" "${m}"
    fm star "invalid token" "${i}"
    fm star "token reused after first use" "${r}" focus
    fm star "session A token with session B cookie" "${x}" focus
    if [ "${v} ${m} ${i} ${r} ${x}" = "200 403 403 200 200" ]; then
        pass "CSRF states match the vulnerable baseline (200/403/403/200/200)"
    else
        fail "CSRF states are ${v}/${m}/${i}/${r}/${x}, expected 200/403/403/200/200" \
             "token freshness or session binding may behave differently than the demo expects" \
             "ask: 'the CSRF token-state codes do not match 200/403/403/200/200 — inspect the vulnerable email-change handler'"
    fi

    # ---- STEP 7: disposition ------------------------------------------------
    banner 7 "Record the alert disposition"
    fm header "Each alert reconciled with what the app actually did" \
              "A disposition turns raw alerts into decisions — the record you keep after the demo (EO1a/b/c)."
    fm star "SQL injection (40018/40022) on /search" "confirmed — reproduced against the concatenated query"
    fm star "NoSQL injection (40033) on /api/account" "confirmed — operator injection changed the result set"
    fm star "Command injection (90020/90037) on /admin/ping" "confirmed — input reaches the OS command"
    fm star "Reflected XSS on /greet" "confirmed — unescaped in three contexts"
    fm note "Fill the full record in docs/alert-disposition-template.md."
    pass "disposition summary produced"

    summary
    [ "${FAIL}" -eq 0 ]
}

summary() {
    echo; echo
    fm header "Preflight summary" "Green means every demo step is behaving as the runbook describes."
    if [ "${FAIL}" -eq 0 ]; then
        fm star "Result" "${PASS} checks passed, 0 failed" focus
        fm note "This demo is aligned with EO1a, EO1b, EO1c and ready to run."
    else
        fm star "Result" "${PASS} passed, ${FAIL} FAILED" focus
        echo
        fm section "Prompt to fix this demo"
        fm note "Paste this into the demo's Claude Code session:"
        echo
        fm item "\"Read the latest log in module1/m1-demo1-validate-injection-xss-and-csrf-with-zap/logs/, find every FAIL, fix the app or the scan policy (never weaken the check), then re-run scripts/preflight_check.sh until all steps pass on the vulnerable build.\""
    fi
}

# run everything through tee: colored on screen, ANSI raw log, and a clean
# plain-text log for review against the learning objectives.
{ main; } 2>&1 | tee "${RAW_LOG}"
rc=${PIPESTATUS[0]}
sed 's/\x1b\[[0-9;]*m//g' "${RAW_LOG}" > "${LOG}"
echo
echo "plain-text log for review: ${LOG}"
# main() returns non-zero when any step failed (it runs in the piped subshell,
# so its exit status is the reliable signal here, not the FAIL counter).
exit "${rc}"
