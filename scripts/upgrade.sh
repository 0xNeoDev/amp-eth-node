#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

usage() {
    echo "Usage: $0 <component> <version>"
    echo ""
    echo "Components: reth, lighthouse, amp, postgres, grafana, prometheus, otel-collector"
    echo ""
    echo "Example: $0 reth v1.12.0"
    exit 1
}

[[ $# -ne 2 ]] && usage

COMPONENT="$1"
VERSION="$2"

# Map component to env var and docker service
case "$COMPONENT" in
    reth)           ENV_VAR="RETH_VERSION"; SERVICE="reth" ;;
    lighthouse)     ENV_VAR="LIGHTHOUSE_VERSION"; SERVICE="lighthouse" ;;
    amp)            ENV_VAR="AMP_VERSION"; SERVICE="amp" ;;
    postgres)       ENV_VAR="POSTGRES_VERSION"; SERVICE="postgres" ;;
    grafana)        ENV_VAR="GRAFANA_VERSION"; SERVICE="grafana" ;;
    prometheus)     ENV_VAR="PROMETHEUS_VERSION"; SERVICE="prometheus" ;;
    otel-collector) ENV_VAR="OTEL_COLLECTOR_VERSION"; SERVICE="otel-collector" ;;
    *)              echo "Unknown component: $COMPONENT"; usage ;;
esac

ENV_FILE="$PROJECT_DIR/.env"

# Read current version
CURRENT_VERSION=$(grep "^${ENV_VAR}=" "$ENV_FILE" | cut -d'=' -f2)
echo "Upgrading $COMPONENT: $CURRENT_VERSION → $VERSION"

# Backup current .env
cp "$ENV_FILE" "$ENV_FILE.bak"

# Update version in .env (portable sed across macOS and Linux)
if [[ "$(uname -s)" == "Darwin" ]]; then
    sed -i '' "s/^${ENV_VAR}=.*/${ENV_VAR}=${VERSION}/" "$ENV_FILE"
else
    sed -i "s/^${ENV_VAR}=.*/${ENV_VAR}=${VERSION}/" "$ENV_FILE"
fi

echo "Updated $ENV_FILE"

# Pull new image (validates that the tag exists)
echo "Pulling new image..."
cd "$PROJECT_DIR"
if ! docker compose pull "$SERVICE"; then
    echo "ERROR: Failed to pull image for $SERVICE with version $VERSION"
    echo "The image tag may not exist. Rolling back .env..."
    cp "$ENV_FILE.bak" "$ENV_FILE"
    rm -f "$ENV_FILE.bak"
    exit 1
fi

# Amp migration step
if [[ "$COMPONENT" == "amp" ]]; then
    echo "Running Amp migration..."
    docker compose stop amp
    docker compose run --rm amp ampd migrate || {
        echo "Migration failed — rolling back"
        cp "$ENV_FILE.bak" "$ENV_FILE"
        docker compose up -d amp
        exit 1
    }
fi

# Rolling restart
echo "Restarting $SERVICE..."
docker compose up -d --no-deps "$SERVICE"

# Health gate: poll for up to 5 minutes
echo "Waiting for $SERVICE to become healthy..."
MAX_WAIT=300
ELAPSED=0
INTERVAL=10

while [[ $ELAPSED -lt $MAX_WAIT ]]; do
    HEALTH=$(docker compose ps --format json "$SERVICE" 2>/dev/null | grep -o '"Health":"[^"]*"' | cut -d'"' -f4 || echo "unknown")

    if [[ "$HEALTH" == "healthy" ]]; then
        echo "$SERVICE is healthy after ${ELAPSED}s"
        rm -f "$ENV_FILE.bak"
        echo "Upgrade complete: $COMPONENT → $VERSION"
        exit 0
    fi

    echo "  Status: $HEALTH (${ELAPSED}s / ${MAX_WAIT}s)"
    sleep "$INTERVAL"
    ELAPSED=$((ELAPSED + INTERVAL))
done

# Rollback on timeout
echo "ERROR: $SERVICE did not become healthy within ${MAX_WAIT}s"
echo "Rolling back to $CURRENT_VERSION..."
cp "$ENV_FILE.bak" "$ENV_FILE"
docker compose pull "$SERVICE"
docker compose up -d --no-deps "$SERVICE"
echo "Rolled back $COMPONENT to $CURRENT_VERSION"
exit 1
