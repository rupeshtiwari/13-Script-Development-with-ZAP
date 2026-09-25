#!/bin/bash
# Bring the demo stack up and wait for all four services to be healthy.
#   APP_BUILD=vulnerable|remediated ./scripts/demo_up.sh
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
cd "${REPO_ROOT}"

BUILD="${APP_BUILD:-vulnerable}"
log "Starting demo stack (APP_BUILD=${BUILD})..."
APP_BUILD="${BUILD}" ${COMPOSE} up -d --build

SERVICES="postgres mongo app zap"
log "Waiting for services to become healthy: ${SERVICES}"

deadline=$(( $(date +%s) + 300 ))
while :; do
    all_ok=1
    for svc in ${SERVICES}; do
        cid="$(${COMPOSE} ps -q "${svc}")"
        if [ -z "${cid}" ]; then all_ok=0; break; fi
        health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${cid}")"
        if [ "${health}" != "healthy" ]; then all_ok=0; break; fi
    done
    if [ "${all_ok}" = "1" ]; then break; fi
    if [ "$(date +%s)" -ge "${deadline}" ]; then
        warn "Timed out waiting for health. Current status:"
        ${COMPOSE} ps
        die "Stack did not become healthy in time."
    fi
    sleep 3
done

echo
log "All services healthy."
echo "  App (Globomantics):   http://localhost:8000/"
echo "  App health:           http://localhost:8000/health"
echo "  ZAP GUI (Webswing):   http://localhost:8080/zap/"
echo "  ZAP API / proxy:      http://localhost:8090  (proxy on the same port)"
echo "  Postgres:             localhost:5432"
echo "  Mongo:                localhost:27017"
echo
echo "Up"
