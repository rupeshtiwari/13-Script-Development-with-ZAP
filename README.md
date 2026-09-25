# Validate Injection, XSS, and CSRF with ZAP

A small, self-contained lab for practising vulnerability validation with
[OWASP ZAP](https://www.zaproxy.org/). It runs a deliberately vulnerable
"Globomantics" web app alongside ZAP, so you can confirm real findings and then
watch them disappear once the app is fixed.

> **Safety:** every service binds to `127.0.0.1` only. Point ZAP **only** at the
> training app in this project. Never aim it at any host you do not own.

## What's inside

| Service | Role |
|---------|------|
| `app` | Globomantics web app (FastAPI). Toggle between a **vulnerable** and a **remediated** build with `APP_BUILD`. |
| `postgres` | Product catalog (used by the SQL-injection search). |
| `mongo` | Account store (used by the NoSQL account lookup). |
| `zap` | OWASP ZAP with the Webswing GUI and the `ascanrulesBeta` add-on. |

### The vulnerable endpoints

| Endpoint | Weakness |
|----------|----------|
| `GET /search?q=` | SQL injection (string-concatenated PostgreSQL query) |
| `GET /api/account?username=` | NoSQL injection (MongoDB operator injection) |
| `GET /admin/ping?host=` | OS command injection (`shell=True`) |
| `GET /greet?name=` | Reflected XSS in three contexts: HTML body, HTML attribute, JS string |
| `POST /account/email` | CSRF-protected email change (login sets a session cookie) |

## Prerequisites

- Docker with Docker Compose, on an arm64 (Apple Silicon) host.
- The pinned ZAP image is pulled automatically on first start.

## Quick start

```bash
# Bring the whole stack up (defaults to the vulnerable build)
./scripts/demo_up.sh

# ... work through the lab ...

# Tear everything down
./scripts/demo_down.sh
```

`demo_up.sh` waits until all four services are healthy and prints their URLs:

| What | URL |
|------|-----|
| Globomantics app | http://localhost:8000/ |
| App health | http://localhost:8000/health |
| ZAP GUI (Webswing, open in a browser) | http://localhost:8080/zap/ |
| ZAP API / proxy | http://localhost:8090 |

Configure your browser (or ZAP) to use `localhost:8090` as the HTTP proxy to
route traffic through ZAP.

## Switching between the vulnerable and remediated app

The same code base ships both behaviours; pick one with `APP_BUILD`:

```bash
# Vulnerable (default)
APP_BUILD=vulnerable ./scripts/demo_up.sh

# Remediated — the fixes are in place
APP_BUILD=remediated docker compose up -d --build app
```

In the remediated build the SQL query is parameterized, the Mongo lookup treats
`username` as a plain string, the ping command validates its input and drops
`shell=True`, XSS output is context-encoded, and CSRF tokens are single-use and
bound to the session.

## Checking your work

`scripts/preflight_check.sh` drives ZAP end to end: it builds a scoped scan
policy (SQL-injection family, NoSQL `40033`, command-injection `90020`/`90037`),
active-scans each injection endpoint, and verifies the XSS reflections and the
CSRF behaviour — first against the vulnerable build, then against the remediated
one.

```bash
./scripts/preflight_check.sh
```

It prints `PASS`/`FAIL` per check and exits non-zero if anything fails.

## Recording your findings

Use `docs/alert-disposition-template.md` to log each alert, its endpoint, your
triage decision, and the evidence behind it.
