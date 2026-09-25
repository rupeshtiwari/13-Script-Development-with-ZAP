# M1 Clip 3 — Preflight Report

Demo: *Validate injection, XSS, and CSRF with ZAP*
Branch: `m1-clip3-demo` · Date: 2026-09-25

**Result: 29/29 preflight checks passed on both the vulnerable and the
remediated build. Verified twice, each time from a clean stack.**

## Versions and image digest

| Component | Version |
|-----------|---------|
| Colima | 0.10.3 *(outline specifies 0.10.4 — see deviations)* |
| Docker | 29.8.1 (build 4a63305d74) |
| Docker Compose | 5.5.1 |
| ZAP core | 2.17.0 |
| ZAP add-on `ascanrulesBeta` | 66.0.0 (provides NoSQL rule 40033; ≥ v66 as required) |
| App base | `python:3.12-slim` (FastAPI) |
| Databases | `postgres:16-alpine`, `mongo:7` |

**Pinned ZAP image (digest verified in the running container):**

```
ghcr.io/zaproxy/zaproxy:stable@sha256:781a2bdaea47324e7bab583e2263f21d257b0aee61ed51521a5be45f5f5081ef
```

## Ports (verified from the running containers)

| Service | Container port | Published on macOS | Notes |
|---------|----------------|--------------------|-------|
| ZAP Webswing GUI | 8080 | `127.0.0.1:8080` | open `http://localhost:8080/zap/` in a browser |
| ZAP API + proxy | 8090 | `127.0.0.1:8090` | HTTP proxy and API share this port |
| ZAP Webswing HTTPS | 8443 | *(not published)* | listens inside the container only |
| App (FastAPI) | 8000 | `127.0.0.1:8000` | |
| PostgreSQL | 5432 | `127.0.0.1:5432` | |
| MongoDB | 27017 | `127.0.0.1:27017` | |

All ports bind to `127.0.0.1` only. ZAP was pointed **only** at the local
training app (`http://app:8000`), never at any external host.

## Endpoints and alert IDs raised (vulnerable build)

| Endpoint | Weakness | Scan / check | Alert ID raised |
|----------|----------|--------------|-----------------|
| `GET /search?q=` | SQL injection (PostgreSQL, string-concatenated) | active scan | **40018** (SQL Injection – PostgreSQL) *(policy also allows 40022)* |
| `GET /api/account?username=` | NoSQL injection (MongoDB operator injection via `username[$ne]` / `[$regex]` / `[$gt]`) | active scan | **40033** (NoSQL Injection – MongoDB) |
| `GET /admin/ping?host=` | OS command injection (`shell=True`) | active scan | **90037** (Remote OS Command Injection, Time Based) *(90020 also detects this endpoint; policy allows either)* |
| `GET /greet?name=` | Reflected XSS (3 contexts) | reflection check | HTML body, HTML attribute, and JS string all reflect the raw marker |
| `POST /account/email` | CSRF | status-code check | see CSRF table |

The scan policy contained exactly: SQL-injection family
`40018 40019 40020 40021 40022 40027`, NoSQL `40033`, and command injection
`90020 90037`. (`40024`/SQLite is absent from this ZAP build and was correctly
skipped.)

## CSRF status codes per build

| Scenario | Vulnerable | Remediated |
|----------|-----------|-----------|
| Valid token | 200 | 200 |
| Missing token | 403 | 403 |
| Invalid token | 403 | 403 |
| Token reused after first use | **200** | **403** |
| Session-A token with session-B cookie | **200** | **403** |

Matches the specification exactly: both builds reject missing/invalid tokens,
and the remediated build additionally enforces single-use, session-bound tokens.

## Remediated build

The same active scans raised **no** in-scope injection alert against the
remediated build, XSS output was context-encoded in all three sinks, and the
last two CSRF scenarios returned 403.

## Deviations

1. **Colima 0.10.3** is installed; the outline specifies 0.10.4. No functional
   impact observed — the full stack builds, runs, and passes preflight.
2. **Command injection alert:** the preflight asserts `90020` **or** `90037`
   (as specified) and observed `90037`. Both rules detect this endpoint; the
   check passes on either.
3. **ZAP GUI boot:** the Webswing GUI only starts the ZAP core when a browser
   attaches, so the container's entrypoint kicks it with an in-container
   headless Firefox and switches the Webswing session mode to
   `CONTINUE_FOR_USER` so the core persists. The author can still open the GUI
   at `http://localhost:8080/zap/` at any time.

## Files changed (branch `m1-clip3-demo`)

```
.env                                 (new)  APP_BUILD default, ZAP API key, pinned image, DB creds
.gitignore                           (new)
README.md                            student lab guide (no production/recording references)
app/Dockerfile                       (new)  FastAPI image + iputils-ping
app/requirements.txt                 (new)
app/main.py                          (new)  vulnerable/remediated endpoints
app/seed.py                          (new)  idempotent Globomantics seed for PG + Mongo
docker-compose.yaml                  (new)  zap, app, postgres, mongo; arm64; healthchecks
docs/alert-disposition-template.md   (new)
docs/m1-clip3-gap-report.md          (new)
docs/m1-clip3-preflight-report.md    (new,  this file)
scripts/demo_up.sh                   (new)
scripts/demo_down.sh                 (new)
scripts/lib.sh                       (new)  shared helpers (status-asserting HTTP)
scripts/preflight_check.sh           (new)  ZAP-API-driven preflight
zap/entrypoint.sh                    (new)  Webswing boot + ascanrulesBeta install/verify
```

## Full output of the last preflight run (clean stack)

```
[13:17:49] Preflight starting. ZAP=http://localhost:8090 app(internal)=http://app:8000
[13:17:49] Checking ZAP is up and rule 40033 is installed...
PASS ZAP API reachable (version:2.17.0)
PASS ascanrulesBeta add-on installed
PASS NoSQL active-scan rule 40033 available
[13:17:49] Building scoped scan policy 'm1clip3' (SQLi family + 40033 + 90020/90037)...
[13:17:49] Policy enabled scanners: 40018 40019 40020 40021 40022 40027 40033 90020 90037
PASS Scan policy contains exactly the intended rules
[13:17:49] Switching app to APP_BUILD=vulnerable...
PASS app is running the vulnerable build

==================================================================
 BUILD: vulnerable
==================================================================
PASS active scan of SQLi /search (q): alert 40018 raised (wanted 40018,40022)
PASS active scan of NoSQL /api/account (username): alert 40033 raised (wanted 40033)
PASS active scan of Cmd inj /admin/ping (host): alert 90037 raised (wanted 90020,90037)
PASS XSS context 1 (HTML body) reflects unescaped input
PASS XSS context 2 (HTML attribute) reflects unescaped input
PASS XSS context 3 (JS string) reflects unescaped input
PASS CSRF valid token -> 200
PASS CSRF missing token -> 403
PASS CSRF invalid token -> 403
PASS CSRF reused token -> 200
PASS CSRF session-A token + session-B cookie -> 200
[13:18:30] Switching app to APP_BUILD=remediated...
PASS app is running the remediated build

==================================================================
 BUILD: remediated
==================================================================
PASS remediated SQLi /search: no injection alert (clean)
PASS remediated NoSQL /api/account: no injection alert (clean)
PASS remediated Cmd inj /admin/ping: no injection alert (clean)
PASS XSS context 1 (HTML body) is HTML-encoded
PASS XSS context 2 (HTML attribute) is HTML-encoded
PASS XSS context 3 (JS string) is JS-encoded
PASS CSRF valid token -> 200
PASS CSRF missing token -> 403
PASS CSRF invalid token -> 403
PASS CSRF reused token -> 403
PASS CSRF session-A token + session-B cookie -> 403

==================================================================
 SUMMARY: 29 passed, 0 failed
==================================================================
All preflight checks passed for both builds.
```
