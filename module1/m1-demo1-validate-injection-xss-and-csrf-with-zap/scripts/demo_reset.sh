#!/bin/bash
# Reset the demo to a clean, known starting state.
#
# Use this between run-throughs: it tears the stack down (removing all seeded
# data and any ZAP session state), then brings it back up on the VULNERABLE
# build, which is where every run of this demo begins.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

echo "[reset] tearing the stack down (clean slate)..."
"${REPO_ROOT}/scripts/demo_down.sh"

echo "[reset] bringing the stack up on the vulnerable build..."
APP_BUILD=vulnerable "${REPO_ROOT}/scripts/demo_up.sh"

echo "[reset] clean starting state is ready (vulnerable build)."
