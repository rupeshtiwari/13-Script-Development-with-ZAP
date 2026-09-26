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

| Module | Title | Objectives | Labs |
|--------|-------|------------|------|
| [Module 1](module1/README.md) | Targeted security testing and ZAP scripting | EO1a–c · EO2a–c | 1 ready, 2 to come |
| [Module 2](module2/README.md) | Automated ZAP security gates in DevSecOps pipelines | EO3a–c | 3 planned |

### Module 1 — Targeted security testing and ZAP scripting

| # | Lab | You will learn | Objectives | Links |
|---|-----|----------------|------------|-------|
| 1 | **Validate injection, XSS, and CSRF with ZAP** | Build a focused scan policy; prove SQL, NoSQL, and command injection; map reflected XSS to its three contexts; compare CSRF token states; record an alert disposition | EO1a · EO1b · EO1c | [Runbook](module1/m1-demo1-validate-injection-xss-and-csrf-with-zap/README.md) · [Scripts](module1/m1-demo1-validate-injection-xss-and-csrf-with-zap/scripts) |
| 2 | Write a JavaScript security script in ZAP | Extend ZAP with an HTTP Sender script | EO2a | Coming next |
| 3 | Write Python scan and authentication scripts in ZAP | Custom Python scan rule and scripted login | EO2b · EO2c | Planned |

### Module 2 — Automated ZAP security gates in DevSecOps pipelines

| # | Lab | You will learn | Objectives | Links |
|---|-----|----------------|------------|-------|
| 1 | Run authenticated ZAP scripts in GitHub Actions | Headless ZAP running your scripts in a pipeline | EO3a | Planned |
| 2 | Query the ZAP API and inspect scan evidence | Programmatic scan status, alerts, and reports | EO3b | Planned |
| 3 | Enforce ZAP quality gates in GitHub Actions | Alert filters and exit-code gates | EO3c | Planned |

---

## Learning objectives

1. **Scanning techniques for specific vulnerabilities**
   - EO1a — Configure specialized scanners for injection vulnerabilities (SQL, NoSQL, command)
   - EO1b — Implement Cross-Site Scripting (XSS) validation with context-specific payloads
   - EO1c — Execute CSRF token-bypass techniques for testing anti-CSRF protections
2. **Utilize ZAP scripting for custom security tests**
   - EO2a — Develop JavaScript scripts to extend ZAP functionality
   - EO2b — Implement Python scripts for custom scanning rules
   - EO2c — Apply scripting for authentication sequence automation
3. **Integrate ZAP with DevSecOps pipelines**
   - EO3a — Configure ZAP for headless execution in CI/CD environments
   - EO3b — Implement ZAP API for programmatic security testing
   - EO3c — Apply threshold-based quality gates for security findings in build pipelines

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
  README.md               Module 1 overview: objectives and labs
  m1-demo1-.../
    README.md             The lab runbook
    scripts/              demo_up · demo_down · demo_reset · capture_demo_output · preflight_check
    logs/                 Validation logs (git-ignored)
module2/
  README.md               Module 2 overview: objectives and labs
```

---

## Technology used

ZAP 2.17.0 (`ghcr.io/zaproxy/zaproxy:stable`, pinned by digest), the
`ascanrules` and `ascanrulesBeta` active-scan add-ons, FastAPI, PostgreSQL,
MongoDB, Docker Compose, and Colima. Each lab uses the subset its objectives
require; the coverage of the full course tech stack is tracked as more labs land.
