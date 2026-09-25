#!/bin/bash
# Capture the full output of every demo step to a single log file.
#
# This runs the same step-by-step validator as preflight_check.sh (so the
# commands and the order can never drift from the runbook) and keeps a copy of
# the plain-text transcript as capture-<timestamp>.log in logs/.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$(cd "${HERE}/.." && pwd)/logs"

"${HERE}/preflight_check.sh"
rc=$?

latest="$(ls -t "${LOG_DIR}"/preflight-*.log 2>/dev/null | grep -v '\.ansi\.log$' | head -1)"
if [ -n "${latest}" ]; then
    out="${LOG_DIR}/capture-$(date +%Y%m%d-%H%M%S).log"
    cp "${latest}" "${out}"
    echo "captured demo output: ${out}"
fi
exit "${rc}"
