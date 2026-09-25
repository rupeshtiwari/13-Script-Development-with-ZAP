#!/bin/bash
# Start the Globomantics stack for this demo (vulnerable build by default).
# Thin wrapper over the shared stack launcher so each demo has its own entry
# point. Prints the URLs you need and waits until all four services are healthy.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
exec "${REPO_ROOT}/scripts/demo_up.sh" "$@"
