# Script Development with ZAP (Pluralsight course)

Author: Rupesh Tiwari. The approved course outline is the source of truth for all
content in this repo: see [docs/course-outline.md](docs/course-outline.md).

Key constraints from the outline:
- Storyline: Globomantics security engineer Maya Chen; all testing targets only the
  Globomantics training app (Python/FastAPI + PostgreSQL + MongoDB) under written authorization.
- Baseline: ZAP 2.17.0, `ghcr.io/zaproxy/zaproxy:stable`, Colima 0.10.4, GitHub Actions `ubuntu-24.04`.
- ZAP Python scripts are Jython 2.7.2 (Python 2.7 syntax); host-side automation uses CPython.
- Python Scripting (jython) and Active scanner rules (beta) v66 (NoSQL Injection - MongoDB, alert 40033)
  must be installed explicitly in the ZAP container.
- Two modules, ~45 min total: Module 1 (targeted testing + JS/Python/auth scripts, 23 min),
  Module 2 (Automation Framework, ZAP API, alertFilter/exitStatus gates in GitHub Actions, 22 min).
- Each demo clip lists named on-screen proof artifacts; demo assets should produce exactly those.

## Commit attribution (owner's rule)

- All commits are authored and committed by **Rupesh Tiwari <roopkt@gmail.com>** only.
- Do NOT add `Co-Authored-By:` or `Claude-Session:` trailers, or any AI attribution,
  to commit messages. The repository history shows the owner alone.
- Work on `main`; no per-demo branches; do not rewrite history unless explicitly asked.
