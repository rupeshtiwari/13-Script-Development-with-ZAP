# M1 Clip 3 – Gap Report

Demo: *Validate injection, XSS, and CSRF with ZAP*
Branch: `m1-clip3-demo` · Date: 2026-09-25

## What exists

| Item | State |
|---|---|
| Repository | Two commits, a single `README.md` containing only a heading |
| Host tooling | Colima 0.10.3 (aarch64, 4 CPU / 8 GiB), Docker 29.8.1, Docker Compose 5.5.1 |
| ZAP image | `ghcr.io/zaproxy/zaproxy:stable` already pulled locally, digest `sha256:781a2bda…5081ef` (ZAP 2.17.0) |
| Running containers | None |
| App / DB / scripts / docs | None |

## What is needed

| Area | Needed | Status |
|---|---|---|
| Compose stack | `docker-compose.yaml` with `zap`, `app`, `postgres`, `mongo`; arm64; healthchecks on all 4 | Missing |
| ZAP | Webswing GUI (`zap-webswing.sh`), GUI + proxy ports published to macOS, pinned digest, `ascanrulesBeta` ≥ v66 installed at start (rule 40033), API key for author tooling | Missing |
| App | FastAPI, `APP_BUILD=vulnerable\|remediated`; SQLi (Postgres), NoSQLi (Mongo), command injection, XSS in 3 contexts, login + CSRF-protected email-change form | Missing |
| Seed data | Globomantics data in Postgres and Mongo | Missing |
| Scripts | `demo_up.sh`, `demo_down.sh`, `preflight_check.sh` | Missing |
| Docs | Student README, `alert-disposition-template.md`, preflight report | Missing |

## Known deviations up front

- Colima 0.10.3 installed; outline specifies 0.10.4. Not expected to matter for this demo.

## Build plan

1. Compose stack + seed data → 2. App (both builds) → 3. ZAP start-up with add-on install →
4. Up/down scripts → 5. Preflight via ZAP API → 6. Iterate until green on both builds, then rerun from a clean stack.
