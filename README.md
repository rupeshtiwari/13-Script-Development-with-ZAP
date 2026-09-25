# Script Development with ZAP — Demo Labs

Hands-on labs for extending [OWASP ZAP](https://www.zaproxy.org/) beyond default
scans: targeted vulnerability validation, custom scripting, and DevSecOps
automation. Every lab runs against one deliberately vulnerable **Globomantics**
training application (Python/FastAPI + PostgreSQL + MongoDB) on your own machine.

> **Authorization and scope.** All techniques in these labs target **only** the
> local Globomantics training app. Never point them at any system you are not
> explicitly authorized to test.

---

## Set up your machine (once)

```bash
./env-setup/setup-macos.sh
```

This one script checks and, where needed, installs every dependency (Homebrew,
Colima, Docker, Docker Compose, tmux, Python) and pulls the pinned ZAP image. It
prints a readiness table and writes a full transcript to `env-setup/logs/`.

---

## Labs

### Module 1 — Targeted security testing and ZAP scripting

| # | Lab | You will learn | Objectives | Links |
|---|-----|----------------|------------|-------|
| 1 | **Validate injection, XSS, and CSRF with ZAP** | Build a focused scan policy; prove SQL, NoSQL, and command injection; map reflected XSS to its three contexts; compare CSRF token states; record an alert disposition | EO1a · EO1b · EO1c | [Runbook](module1/m1-demo1-validate-injection-xss-and-csrf-with-zap/README.md) · [Scripts](module1/m1-demo1-validate-injection-xss-and-csrf-with-zap/scripts) |

*Further Module 1 and Module 2 labs are added under `module1/` and `module2/`
following the same layout.*

---

## Learning objectives

1. **Scanning techniques for specific vulnerabilities**
   - EO1a — Configure specialized scanners for injection vulnerabilities (SQL, NoSQL, command)
   - EO1b — Implement Cross-Site Scripting (XSS) validation with context-specific payloads
   - EO1c — Execute CSRF token-bypass techniques for testing anti-CSRF protections

*(Objectives for Modules 2–3 are covered by their own labs.)*

---

## Repository layout

```
env-setup/
  setup-macos.sh          One-file dependency check + install (verbose log)
scripts/
  fmt.py                  Shared colored output formatter (one palette to swap)
  lib.sh                  Shared shell helpers
  demo_up.sh / demo_down.sh / preflight_check.sh   Shared stack engine
app/                      Globomantics FastAPI app (vulnerable + remediated builds)
zap/                      ZAP container entrypoint (Webswing GUI + add-on install)
docker-compose.yaml       zap + app + postgres + mongo (bound to 127.0.0.1)
data/payloads/            Per-lab step manifests
docs/                     Gap report, preflight report, alert-disposition template
module1/
  m1-demo1-.../
    README.md             The lab runbook
    scripts/              demo_up · demo_down · demo_reset · capture_demo_output · preflight_check
    logs/                 Validation logs (git-ignored)
```

---

## Technology used

ZAP 2.17.0 (`ghcr.io/zaproxy/zaproxy:stable`, pinned by digest), the
`ascanrules` and `ascanrulesBeta` active-scan add-ons, FastAPI, PostgreSQL,
MongoDB, Docker Compose, and Colima. Each lab uses the subset its objectives
require; the coverage of the full course tech stack is tracked as more labs land.
