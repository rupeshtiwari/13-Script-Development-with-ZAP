#!/bin/bash
# Tear the Globomantics stack down for this demo.
# Thin wrapper over the shared teardown so each demo has its own entry point.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
exec "${REPO_ROOT}/scripts/demo_down.sh" "$@"
