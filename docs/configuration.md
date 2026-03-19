# Configuration Reference

## `.env` Variables

All version pins and runtime settings live in `.env`. This file is tracked by git and serves as the single source of truth for image tags.

| Variable | Default | Description |
|---|---|---|
| `RETH_VERSION` | `v1.11.3` | Reth Docker image tag |
| `LIGHTHOUSE_VERSION` | `latest-modern` | Lighthouse Docker image tag |
| `AMP_VERSION` | `latest` | Amp Docker image tag |
| `POSTGRES_VERSION` | `16-alpine` | PostgreSQL Docker image tag |
| `GRAFANA_VERSION` | `11.4.0` | Grafana Docker image tag |
| `PROMETHEUS_VERSION` | `v3.1.0` | Prometheus Docker image tag |
| `OTEL_COLLECTOR_VERSION` | `0.115.1` | OpenTelemetry Collector image tag |
| `ETH_NETWORK` | `mainnet` | Ethereum network (`mainnet` or `sepolia`) |
| `RETH_HTTP_PORT` | `8545` | Reth JSON-RPC HTTP port |
| `RETH_WS_PORT` | `8546` | Reth JSON-RPC WebSocket port |
| `RETH_AUTH_PORT` | `8551` | Reth Engine API (JWT) port |
| `RETH_P2P_PORT` | `30303` | Reth P2P TCP/UDP port |
| `RETH_METRICS_PORT` | `9001` | Reth Prometheus metrics port |
| `LIGHTHOUSE_P2P_PORT` | `9000` | Lighthouse P2P TCP/UDP port |
| `LIGHTHOUSE_HTTP_PORT` | `5052` | Lighthouse Beacon API HTTP port |
| `LIGHTHOUSE_METRICS_PORT` | `5054` | Lighthouse Prometheus metrics port |
| `LIGHTHOUSE_CHECKPOINT_SYNC_URL` | `https://mainnet.checkpoint.sigp.io` | Checkpoint sync endpoint |
| `AMP_FLIGHT_PORT` | `1602` | Amp Arrow Flight gRPC port |
| `AMP_JSONL_PORT` | `1603` | Amp JSONL HTTP query port |
| `AMP_ADMIN_PORT` | `1610` | Amp admin/management port |
| `POSTGRES_USER` | `amp` | PostgreSQL username |
| `POSTGRES_PASSWORD` | `amp` | PostgreSQL password (change in production) |
| `POSTGRES_DB` | `amp` | PostgreSQL database name |
| `GRAFANA_ADMIN_USER` | `admin` | Grafana admin username |
| `GRAFANA_ADMIN_PASSWORD` | `admin` | Grafana admin password (change in production) |

## `.env.local` Overrides

Create `.env.local` from the example to override settings locally without modifying the tracked `.env`:

```sh
cp .env.local.example .env.local
```

`.env.local` is not tracked by git (listed in `.gitignore`). Docker Compose loads it automatically and it takes precedence over `.env`.

Common overrides:

```dotenv
# Use Sepolia for development
ETH_NETWORK=sepolia
LIGHTHOUSE_CHECKPOINT_SYNC_URL=https://sepolia.beaconstate.info

# Production credentials
POSTGRES_PASSWORD=a-strong-random-password
GRAFANA_ADMIN_PASSWORD=a-strong-random-password

# NVMe bind mount paths (used in docker-compose.prod.yml)
RETH_DATA_DIR=/mnt/nvme0/reth
LIGHTHOUSE_DATA_DIR=/mnt/nvme0/lighthouse
AMP_DATA_DIR=/mnt/nvme0/amp
POSTGRES_DATA_DIR=/mnt/nvme0/postgres
```

## Amp `config.toml`

Located at `config/amp/config.toml`. This file is mounted read-only into the Amp container at `/config/config.toml`.

| Section | Key | Description |
|---|---|---|
| `[metadata]` | `database_url` | PostgreSQL connection string. Overridden at runtime by the `AMP_METADATA_DB_URL` environment variable |
| `[data]` | `dir` | Container path where Amp writes indexed data |
| `[server]` | `flight_addr` | Listen address for Arrow Flight (default `0.0.0.0:1602`) |
| `[server]` | `jsonl_addr` | Listen address for JSONL HTTP (default `0.0.0.0:1603`) |
| `[admin]` | `addr` | Listen address for the admin API (default `0.0.0.0:1610`) |
| `[telemetry]` | `otlp_endpoint` | OTLP gRPC endpoint for trace/metric export |

## Provider Config

Provider files live in `config/amp/providers/`. Each file defines one data source.

**`eth-mainnet.toml`** (and equivalent for Sepolia):

| Key | Description |
|---|---|
| `kind` | Provider type — `evm-rpc` for Ethereum JSON-RPC |
| `network` | Logical network name (`mainnet`, `sepolia`) |
| `url` | RPC endpoint. Use `/ipc/reth.ipc` for IPC (fastest) or `http://reth:8545` for HTTP |
| `concurrent_request_limit` | Maximum in-flight RPC requests (default `64`) |
| `rpc_batch_size` | Number of calls to batch per request (default `100`) |
| `timeout` | Per-request timeout in seconds (default `30`) |

Using the IPC socket (`/ipc/reth.ipc`) is strongly recommended over HTTP — it yields roughly 2x throughput. See [architecture.md](architecture.md) for details.

## Reth Tuning

Reth is configured via command-line flags in `docker-compose.yml`. Key flags:

| Flag | Default | Notes |
|---|---|---|
| `--http.api` | `eth,net,web3,debug,trace,txpool` | Expose `debug` and `trace` if Amp manifests require traces |
| `--ipcpath` | `/ipc/reth.ipc` | Must match the provider `url` in Amp's provider config |
| `--authrpc.jwtsecret` | `/jwt/jwt.hex` | Must match Lighthouse's `--execution-jwt` |
| `--metrics` | `0.0.0.0:9001` | Prometheus scrape endpoint |

For production, consider adding:
- `--full` — full node mode (no archive); reduces disk usage by ~60% but disables historical `debug_traceTransaction`
- `--db.log-level=silent` — reduces log noise under heavy load
- `--rpc.max-connections=500` — raise if Amp saturates the default connection pool
