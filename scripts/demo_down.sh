#!/bin/bash
# Tear the demo stack down, with a forced cleanup fallback.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
cd "${REPO_ROOT}"

log "Stopping demo stack..."
if ${COMPOSE} down --remove-orphans --volumes --timeout 20; then
    log "Stack stopped cleanly."
else
    warn "compose down failed; forcing cleanup of demo containers."
    # Fallback: remove any lingering containers created from this project.
    project="$(basename "${REPO_ROOT}" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')"
    ids="$(docker ps -aq --filter "label=com.docker.compose.project=${project}")"
    if [ -n "${ids}" ]; then
        # shellcheck disable=SC2086
        docker rm -f ${ids} || true
    fi
    ${COMPOSE} down --volumes --remove-orphans || true
fi

log "Done."
