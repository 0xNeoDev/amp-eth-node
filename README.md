# amp-eth-node

Reference implementation for running [Amp](https://thegraph.com/amp) (The Graph's blockchain-native database) with a co-located Ethereum full node. Optimized for performance via IPC transport between Reth and Amp.

## Architecture

```
Ethereum P2P → Lighthouse ──Engine API (JWT)──→ Reth ──IPC socket──→ Amp ──→ Arrow Flight :1602
                                                  │                    │      JSONL HTTP :1603
                                                  │                    │      Admin API :1610
                                                  ▼                    ▼
                                             Prometheus           PostgreSQL
                                                  │
                                                  ▼
                                              Grafana :3000
```

**Key design**: Reth and Amp share a Docker named volume (`ipc-socket`) where Reth writes its Unix domain socket. Amp reads directly from this socket — no network stack overhead. IPC delivers ~18K ops/sec vs ~8K ops/sec over HTTP.

## Services

| Service | Image | Ports | Role |
|---------|-------|-------|------|
| Reth | `ghcr.io/paradigmxyz/reth` | 8545, 8546, 30303, 9001 | Ethereum execution client |
| Lighthouse | `sigp/lighthouse` | 9000, 5052, 5054 | Ethereum consensus client |
| PostgreSQL | `postgres:16-alpine` | 5432 | Amp metadata storage |
| Amp | `ghcr.io/edgeandnode/amp` | 1602, 1603, 1610 | ETL + query engine |
| OTel Collector | `otel/opentelemetry-collector-contrib` | 4317, 4318 | Telemetry pipeline |
| Prometheus | `prom/prometheus` | 9090 | Metrics storage |
| Grafana | `grafana/grafana` | 3000 | Dashboards |

## Quick Start

### Prerequisites

- Docker with Compose v2
- [just](https://github.com/casey/just) command runner (recommended)
- 16GB+ RAM (dev), 32GB+ RAM (prod)

### Development (Sepolia testnet)

```bash
git clone https://github.com/edgeandnode/amp-eth-node.git
cd amp-eth-node
just setup      # Generate JWT, pull images
just up-dev     # Start with Sepolia testnet
just status     # Check service health
```

### Production (Mainnet)

```bash
just setup
# Edit .env.local with NVMe paths and strong passwords
just preflight  # Validate credentials, disk, memory, ports
just up-prod
```

### First Query

Once Amp has indexed some blocks:

```bash
just amp-query "SELECT count(*) FROM blocks"
just amp-query "SELECT number, hash, gas_used FROM blocks ORDER BY number DESC LIMIT 5"
```

## Commands

| Command | Description |
|---------|-------------|
| `just setup` | One-time setup: JWT, dirs, image pull |
| `just up` | Start all services (mainnet) |
| `just up-dev` | Start in dev mode (Sepolia, adminer) |
| `just up-prod` | Start in production mode |
| `just down` | Stop all services |
| `just status` | Health check all services |
| `just logs [service]` | Follow logs |
| `just ps` | Show running containers |
| `just versions` | Show pinned image versions |
| `just upgrade <component> <version>` | Rolling upgrade with rollback |
| `just amp-query "<SQL>"` | Run Amp query |
| `just grafana` | Open Grafana dashboards |
| `just bench` | Run all benchmarks |
| `just bench-transport` | IPC vs HTTP comparison |
| `just sync-status` | Reth sync progress |
| `just preflight` | Pre-flight checks for production |
| `just backup <component> <dir>` | Backup PostgreSQL or config |
| `just restore postgres <file>` | Restore PostgreSQL from backup |
| `just validate` | Validate all compose files |

## Configuration

All image versions are pinned in `.env`. Override locally in `.env.local` (not tracked by git).

See [docs/configuration.md](docs/configuration.md) for the full reference.

## Benchmarks

```bash
just bench-transport    # IPC vs HTTP (headline number)
just bench-rpc          # Reth RPC throughput
just bench-extraction   # Amp block extraction rate
just bench-query        # Amp query latency
just bench              # Run all benchmarks
```

Expected baseline numbers (mainnet, NVMe):

| Benchmark | Result |
|-----------|--------|
| IPC throughput | ~18,000 ops/sec |
| HTTP throughput | ~8,000 ops/sec |
| IPC speedup | ~2x faster |

## Security

See [SECURITY.md](SECURITY.md) for the security policy and hardening details.

Key production defaults:
- RPC APIs restricted to `eth,net,web3` (no `debug`/`trace`)
- No CORS wildcards — dev overlay adds them explicitly
- PostgreSQL bound to `127.0.0.1` only
- `no-new-privileges` on all containers in prod
- Prometheus alerting rules for service health, sync stalls, and resource usage
- Pre-flight validation of credentials, disk, memory before deployment

## Documentation

- [Architecture](docs/architecture.md)
- [Quick Start](docs/quickstart.md)
- [Configuration](docs/configuration.md)
- [Benchmarking](docs/benchmarking.md)
- [Upgrading](docs/upgrading.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Hardware Requirements](docs/hardware.md)
- [Systemd Service](docs/systemd.md) (Linux production)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
