#!/usr/bin/env bash
set -euo pipefail

# Health check all services and display a summary table

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$PROJECT_DIR/.env"
[ -f "$PROJECT_DIR/.env.local" ] && source "$PROJECT_DIR/.env.local"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

FAILURES=0

check_service() {
    local name="$1"
    local url="$2"
    local method="${3:-GET}"
    local data="${4:-}"

    local status
    if [[ "$method" == "POST" ]]; then
        status=$(curl -sf -o /dev/null -w "%{http_code}" --max-time 5 -X POST \
            -H 'Content-Type: application/json' \
            -d "$data" "$url" 2>/dev/null) || status="000"
    else
        status=$(curl -sf -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null) || status="000"
    fi

    if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
        printf "  %-18s ${GREEN}%-8s${NC} %s\n" "$name" "healthy" "$url"
    elif [[ "$status" == "000" ]]; then
        printf "  %-18s ${RED}%-8s${NC} %s\n" "$name" "down" "$url"
        FAILURES=$((FAILURES + 1))
    else
        printf "  %-18s ${YELLOW}%-8s${NC} %s (HTTP %s)\n" "$name" "degraded" "$url" "$status"
    fi
}

echo ""
echo "  Service            Status   Endpoint"
echo "  ─────────────────  ───────  ────────────────────────────────"

check_service "Reth RPC" "http://localhost:${RETH_HTTP_PORT:-8545}" "POST" \
    '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}'

check_service "Lighthouse" "http://localhost:${LIGHTHOUSE_HTTP_PORT:-5052}/eth/v1/node/health"

# PostgreSQL uses pg_isready via docker exec (not HTTP)
if docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T postgres \
    pg_isready -U "${POSTGRES_USER:-amp}" -d "${POSTGRES_DB:-amp}" &>/dev/null; then
    printf "  %-18s ${GREEN}%-8s${NC} %s\n" "PostgreSQL" "healthy" "localhost:5432"
else
    printf "  %-18s ${RED}%-8s${NC} %s\n" "PostgreSQL" "down" "localhost:5432"
    FAILURES=$((FAILURES + 1))
fi

check_service "Amp JSONL" "http://localhost:${AMP_JSONL_PORT:-1603}" "POST" '{"query":"SELECT 1"}'
check_service "Amp Admin" "http://localhost:${AMP_ADMIN_PORT:-1610}"

check_service "OTel Collector" "http://localhost:13133/health"
check_service "Prometheus" "http://localhost:9090/api/v1/status/config"
check_service "Grafana" "http://localhost:3000/api/health"

echo ""

# Reth sync status
echo "  --- Reth Sync Status ---"
SYNC_RESULT=$(curl -sf --max-time 5 -X POST -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
    "http://localhost:${RETH_HTTP_PORT:-8545}" 2>/dev/null) || SYNC_RESULT=""

if [[ -n "$SYNC_RESULT" ]]; then
    if echo "$SYNC_RESULT" | grep -q '"result":false'; then
        echo "  Reth: fully synced"
    else
        echo "  Reth: syncing — $SYNC_RESULT"
    fi
else
    echo "  Reth: unavailable"
fi

echo ""

# Exit with failure if any service is down (useful for CI/scripts)
if [[ $FAILURES -gt 0 ]]; then
    exit 1
fi
