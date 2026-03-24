#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== amp-eth-node setup ==="
echo ""

# Platform detection
OS="$(uname -s)"
ARCH="$(uname -m)"
echo "Platform: $OS / $ARCH"

case "$OS" in
    Darwin) echo "  Detected macOS — dev mode recommended (just up-dev)" ;;
    Linux)  echo "  Detected Linux — prod mode available (just up-prod)" ;;
    *)      echo "  Warning: untested platform ($OS)" ;;
esac
echo ""

# Docker version check
if ! command -v docker &>/dev/null; then
    echo "ERROR: docker is not installed or not in PATH"
    exit 1
fi

DOCKER_VERSION="$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")"
echo "Docker version: $DOCKER_VERSION"

if ! docker compose version &>/dev/null; then
    echo "ERROR: 'docker compose' (v2) is required but not available"
    echo "  Install: https://docs.docker.com/compose/install/"
    exit 1
fi

COMPOSE_VERSION="$(docker compose version --short 2>/dev/null || echo "unknown")"
echo "Docker Compose version: $COMPOSE_VERSION"
echo ""

# just check (optional)
if command -v just &>/dev/null; then
    echo "just: $(just --version)"
else
    echo "Warning: 'just' not found — install it for the best experience"
    echo "  macOS: brew install just"
    echo "  Linux: cargo install just"
fi
echo ""

# Disk space check
echo "--- Disk Space ---"
AVAIL_KB=$(df -k "$PROJECT_DIR" | tail -1 | awk '{print $4}')
AVAIL_GB=$((AVAIL_KB / 1024 / 1024))
echo "Available disk: ${AVAIL_GB}GB"
if [[ $AVAIL_GB -lt 50 ]]; then
    echo "  WARNING: Less than 50GB free. Sepolia needs ~50GB, mainnet needs 2TB+."
fi
echo ""

# Generate JWT secret
echo "--- JWT Secret ---"
bash "$SCRIPT_DIR/generate-jwt.sh"
echo ""

# Copy .env.local if not present
if [[ ! -f "$PROJECT_DIR/.env.local" ]]; then
    cp "$PROJECT_DIR/.env.local.example" "$PROJECT_DIR/.env.local"
    echo "Created .env.local from template — edit as needed"
else
    echo ".env.local already exists"
fi
echo ""

# Copy JWT into Docker volume (will be available on first up)
echo "--- Docker Volume Setup ---"
echo "JWT secret will be loaded into the jwt-secret volume on first 'docker compose up'"
echo ""

# Pre-pull images
echo "--- Pre-pulling images ---"
echo "This may take a while on first run..."
source "$PROJECT_DIR/.env"
[ -f "$PROJECT_DIR/.env.local" ] && source "$PROJECT_DIR/.env.local"

IMAGES=(
    "ghcr.io/paradigmxyz/reth:${RETH_VERSION}"
    "sigp/lighthouse:${LIGHTHOUSE_VERSION}"
    "offchainlabs/nitro-node:${NITRO_L2_VERSION}"
    "offchainlabs/nitro-node:${NITRO_ORBIT_VERSION}"
    "postgres:${POSTGRES_VERSION}"
    "ghcr.io/edgeandnode/amp:${AMP_VERSION}"
    "prom/prometheus:${PROMETHEUS_VERSION}"
    "grafana/grafana:${GRAFANA_VERSION}"
    "otel/opentelemetry-collector-contrib:${OTEL_COLLECTOR_VERSION}"
)

for img in "${IMAGES[@]}"; do
    echo "  Pulling $img ..."
    docker pull "$img" --quiet || echo "  Warning: failed to pull $img (may not exist yet)"
done
echo ""

echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  L1 Development (Sepolia):   just up-dev"
echo "  L1 Production (Mainnet):    just up-prod"
echo "  Orbit Development:          just up-orbit-dev"
echo "  Orbit Production:           just up-orbit-prod"
echo "  Full Stack (L1 + Orbit):    just up-full"
echo "  Check status:               just status"
echo ""
echo "For Orbit mode, set NITRO_PARENT_CHAIN_URL in .env.local first."
