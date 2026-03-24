# amp-eth-node — developer interface
# Run `just` to see all available recipes

set dotenv-load

# Default: show available recipes
default:
    @just --list

# One-time setup: generate JWT, create dirs, pull images
setup:
    bash scripts/setup.sh

# Start all services (mainnet, default config)
up:
    docker compose up -d

# Start in development mode (Sepolia, lower resources, adminer)
up-dev:
    docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Start in production mode (host networking, NVMe bind mounts)
up-prod:
    docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Start Arbitrum One L2 (Nitro L2 + Amp L2, derives from local L1)
up-l2:
    docker compose -f docker-compose.yml -f docker-compose.arbitrum.yml up -d

# Start Arbitrum One L2 in production mode
up-l2-prod:
    docker compose -f docker-compose.yml -f docker-compose.arbitrum.yml -f docker-compose.prod.yml -f docker-compose.arbitrum-prod.yml up -d

# Start Orbit L3 chain (Nitro Orbit + Amp Orbit, set NITRO_PARENT_CHAIN_URL)
up-orbit:
    docker compose -f docker-compose.yml -f docker-compose.orbit.yml up -d

# Start Orbit L3 in development mode (testnet, lower resources)
up-orbit-dev:
    docker compose -f docker-compose.yml -f docker-compose.orbit.yml -f docker-compose.orbit-dev.yml up -d

# Start Orbit L3 in production mode (host networking, NVMe, hardened)
up-orbit-prod:
    docker compose -f docker-compose.yml -f docker-compose.orbit.yml -f docker-compose.orbit-prod.yml up -d

# Start full self-hosted stack: L1 + L2 + L3 (no external RPCs)
up-full:
    docker compose -f docker-compose.yml -f docker-compose.arbitrum.yml -f docker-compose.orbit.yml up -d

# Start full stack in production mode
up-full-prod:
    docker compose -f docker-compose.yml -f docker-compose.arbitrum.yml -f docker-compose.orbit.yml -f docker-compose.prod.yml -f docker-compose.arbitrum-prod.yml -f docker-compose.orbit-prod.yml up -d

# Stop all services
down:
    docker compose down

# Stop and remove all volumes (WARNING: deletes chain data)
down-volumes:
    docker compose down -v

# View logs (optionally for a specific service)
logs *SERVICE:
    docker compose logs -f --tail=100 {{ SERVICE }}

# Show service health status
status:
    bash scripts/health.sh

# Show running containers
ps:
    docker compose ps

# Show pinned versions
versions:
    @echo "Reth:           ${RETH_VERSION}"
    @echo "Lighthouse:     ${LIGHTHOUSE_VERSION}"
    @echo "Nitro L2:       ${NITRO_L2_VERSION}"
    @echo "Nitro Orbit:    ${NITRO_ORBIT_VERSION}"
    @echo "Amp:            ${AMP_VERSION}"
    @echo "PostgreSQL:     ${POSTGRES_VERSION}"
    @echo "Grafana:        ${GRAFANA_VERSION}"
    @echo "Prometheus:     ${PROMETHEUS_VERSION}"
    @echo "OTel Collector: ${OTEL_COLLECTOR_VERSION}"

# Upgrade a component: just upgrade reth v1.12.0
upgrade COMPONENT VERSION:
    bash scripts/upgrade.sh {{ COMPONENT }} {{ VERSION }}

# Run an Amp query via JSONL HTTP API
amp-query QUERY:
    curl -sf -X POST -H 'Content-Type: application/json' -d '{"query":"{{ QUERY }}"}' http://localhost:${AMP_JSONL_PORT:-1603} | jq .

# Run an Amp L2 query via JSONL HTTP API
amp-l2-query QUERY:
    curl -sf -X POST -H 'Content-Type: application/json' -d '{"query":"{{ QUERY }}"}' http://localhost:${AMP_L2_JSONL_PORT:-1623} | jq .

# Run an Amp Orbit L3 query via JSONL HTTP API
amp-orbit-query QUERY:
    curl -sf -X POST -H 'Content-Type: application/json' -d '{"query":"{{ QUERY }}"}' http://localhost:${AMP_ORBIT_JSONL_PORT:-1613} | jq .

# Show Nitro L2 (Arbitrum One) sync status
l2-sync-status:
    @curl -sf -X POST -H 'Content-Type: application/json' \
        -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
        http://localhost:${NITRO_L2_HTTP_PORT:-8549} | jq .

# Show Nitro L2 chain head block number
l2-block-number:
    @curl -sf -X POST -H 'Content-Type: application/json' \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        http://localhost:${NITRO_L2_HTTP_PORT:-8549} | jq -r '.result' | xargs printf "%d\n"

# Show Nitro Orbit L3 sync status
orbit-sync-status:
    @curl -sf -X POST -H 'Content-Type: application/json' \
        -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
        http://localhost:${NITRO_HTTP_PORT:-8547} | jq .

# Show Nitro Orbit L3 chain head block number
orbit-block-number:
    @curl -sf -X POST -H 'Content-Type: application/json' \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        http://localhost:${NITRO_HTTP_PORT:-8547} | jq -r '.result' | xargs printf "%d\n"

# Open Grafana in browser
grafana:
    open http://localhost:3000 2>/dev/null || xdg-open http://localhost:3000 2>/dev/null || echo "Open http://localhost:3000"

# Open Adminer in browser (dev mode only)
adminer:
    open http://localhost:8080 2>/dev/null || xdg-open http://localhost:8080 2>/dev/null || echo "Open http://localhost:8080"

# Run all benchmarks
bench:
    docker compose -f docker-compose.yml -f docker-compose.bench.yml run --rm bench-runner /bench/rpc-throughput.sh
    docker compose -f docker-compose.yml -f docker-compose.bench.yml run --rm bench-runner /bench/amp-extraction.sh
    docker compose -f docker-compose.yml -f docker-compose.bench.yml run --rm bench-runner /bench/amp-query-latency.sh
    docker compose -f docker-compose.yml -f docker-compose.bench.yml run --rm bench-runner /bench/e2e-indexing.sh
    docker compose -f docker-compose.yml -f docker-compose.bench.yml run --rm bench-runner /bench/ipc-vs-http.sh

# Benchmark: Reth RPC throughput
bench-rpc:
    docker compose -f docker-compose.yml -f docker-compose.bench.yml run --rm bench-runner /bench/rpc-throughput.sh

# Benchmark: Amp block extraction rate
bench-extraction:
    docker compose -f docker-compose.yml -f docker-compose.bench.yml run --rm bench-runner /bench/amp-extraction.sh

# Benchmark: Amp query latency (Flight + JSONL)
bench-query:
    docker compose -f docker-compose.yml -f docker-compose.bench.yml run --rm bench-runner /bench/amp-query-latency.sh

# Benchmark: IPC vs HTTP vs WebSocket transport comparison
bench-transport:
    docker compose -f docker-compose.yml -f docker-compose.bench.yml run --rm bench-runner /bench/ipc-vs-http.sh

# Pre-flight checks for production deployment
preflight:
    bash scripts/preflight.sh

# Backup PostgreSQL and/or config: just backup postgres /backups
backup COMPONENT OUTPUT_DIR:
    bash scripts/backup.sh {{ COMPONENT }} {{ OUTPUT_DIR }}

# Restore PostgreSQL from backup: just restore postgres /backups/amp-postgres-*.sql.gz
restore COMPONENT BACKUP_FILE:
    bash scripts/restore.sh {{ COMPONENT }} {{ BACKUP_FILE }}

# Restart a specific service
restart SERVICE:
    docker compose restart {{ SERVICE }}

# Pull latest images for all services
pull:
    docker compose pull

# Show Reth sync status
sync-status:
    @curl -sf -X POST -H 'Content-Type: application/json' \
        -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
        http://localhost:${RETH_HTTP_PORT:-8545} | jq .

# Validate all compose files
validate:
    docker compose -f docker-compose.yml config --quiet
    docker compose -f docker-compose.yml -f docker-compose.dev.yml config --quiet
    docker compose -f docker-compose.yml -f docker-compose.prod.yml config --quiet
    docker compose -f docker-compose.yml -f docker-compose.bench.yml config --quiet
    docker compose -f docker-compose.yml -f docker-compose.arbitrum.yml config --quiet
    docker compose -f docker-compose.yml -f docker-compose.arbitrum.yml -f docker-compose.arbitrum-prod.yml config --quiet
    docker compose -f docker-compose.yml -f docker-compose.orbit.yml config --quiet
    docker compose -f docker-compose.yml -f docker-compose.orbit.yml -f docker-compose.orbit-dev.yml config --quiet
    docker compose -f docker-compose.yml -f docker-compose.orbit.yml -f docker-compose.orbit-prod.yml config --quiet
    docker compose -f docker-compose.yml -f docker-compose.arbitrum.yml -f docker-compose.orbit.yml config --quiet
    @echo "All compose files are valid."
