#!/usr/bin/env bash
set -euo pipefail

# Pre-flight checks for production deployment
# Run this before `just up-prod` to validate the environment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
ERRORS=0

pass() { printf "  ${GREEN}PASS${NC}  %s\n" "$1"; }
warn() { printf "  ${YELLOW}WARN${NC}  %s\n" "$1"; }
fail() { printf "  ${RED}FAIL${NC}  %s\n" "$1"; ERRORS=$((ERRORS + 1)); }

echo "=== Pre-flight checks ==="
echo ""

source "$PROJECT_DIR/.env"
[ -f "$PROJECT_DIR/.env.local" ] && source "$PROJECT_DIR/.env.local"

# --- Docker ---
if docker info &>/dev/null; then
    pass "Docker daemon is running"
else
    fail "Docker daemon is not running or not accessible"
fi

# --- Disk space ---
# Need at least 100GB free for initial sync
AVAIL_KB=$(df -k "$PROJECT_DIR" | tail -1 | awk '{print $4}')
AVAIL_GB=$((AVAIL_KB / 1024 / 1024))
if [[ $AVAIL_GB -ge 100 ]]; then
    pass "Disk space: ${AVAIL_GB}GB available"
elif [[ $AVAIL_GB -ge 50 ]]; then
    warn "Disk space: ${AVAIL_GB}GB available (100GB+ recommended)"
else
    fail "Disk space: only ${AVAIL_GB}GB available (need 100GB+)"
fi

# --- Memory ---
if [[ "$(uname -s)" == "Linux" ]]; then
    TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_MEM_GB=$((TOTAL_MEM_KB / 1024 / 1024))
elif [[ "$(uname -s)" == "Darwin" ]]; then
    TOTAL_MEM_BYTES=$(sysctl -n hw.memsize)
    TOTAL_MEM_GB=$((TOTAL_MEM_BYTES / 1024 / 1024 / 1024))
else
    TOTAL_MEM_GB=0
fi

if [[ $TOTAL_MEM_GB -ge 32 ]]; then
    pass "Memory: ${TOTAL_MEM_GB}GB total"
elif [[ $TOTAL_MEM_GB -ge 16 ]]; then
    warn "Memory: ${TOTAL_MEM_GB}GB total (32GB+ recommended for mainnet)"
elif [[ $TOTAL_MEM_GB -gt 0 ]]; then
    fail "Memory: ${TOTAL_MEM_GB}GB total (32GB+ required for mainnet)"
fi

# --- JWT ---
JWT_FILE="$PROJECT_DIR/jwt/jwt.hex"
if [[ -f "$JWT_FILE" ]]; then
    PERMS=$(stat -f "%Lp" "$JWT_FILE" 2>/dev/null || stat -c "%a" "$JWT_FILE" 2>/dev/null)
    if [[ "$PERMS" == "600" ]]; then
        pass "JWT secret exists with correct permissions (600)"
    else
        warn "JWT secret exists but permissions are $PERMS (should be 600)"
    fi
else
    fail "JWT secret not found — run 'just setup' first"
fi

# --- Version pins ---
if [[ "$LIGHTHOUSE_VERSION" == "latest"* ]]; then
    warn "LIGHTHOUSE_VERSION is a floating tag: $LIGHTHOUSE_VERSION"
fi
if [[ "$AMP_VERSION" == "latest"* ]]; then
    warn "AMP_VERSION is a floating tag: $AMP_VERSION"
fi
if [[ "$RETH_VERSION" == v* ]]; then
    pass "RETH_VERSION is pinned: $RETH_VERSION"
fi

# --- Credentials ---
if [[ "${POSTGRES_PASSWORD:-amp}" == "amp" ]]; then
    fail "POSTGRES_PASSWORD is the default 'amp' — set a strong password in .env.local"
fi
if [[ "${GRAFANA_ADMIN_PASSWORD:-admin}" == "admin" ]]; then
    warn "GRAFANA_ADMIN_PASSWORD is the default 'admin'"
fi

# --- NVMe bind mounts (prod) ---
if [[ -n "${RETH_DATA_DIR:-}" ]]; then
    if [[ -d "$RETH_DATA_DIR" ]]; then
        pass "RETH_DATA_DIR exists: $RETH_DATA_DIR"
    else
        fail "RETH_DATA_DIR does not exist: $RETH_DATA_DIR"
    fi
else
    warn "RETH_DATA_DIR not set — will use Docker named volume"
fi

# --- Port conflicts ---
for port in "${RETH_HTTP_PORT:-8545}" "${RETH_P2P_PORT:-30303}" "${LIGHTHOUSE_P2P_PORT:-9000}" 5432 9090 3000; do
    if lsof -i ":$port" &>/dev/null 2>&1; then
        warn "Port $port is already in use"
    fi
done

echo ""
if [[ $ERRORS -gt 0 ]]; then
    echo -e "${RED}Pre-flight failed with $ERRORS error(s).${NC} Fix the issues above before deploying."
    exit 1
else
    echo -e "${GREEN}All pre-flight checks passed.${NC}"
fi
