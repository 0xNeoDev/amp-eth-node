# amp-eth-node

Reference implementation for running [Amp](https://thegraph.com/amp) (The Graph's blockchain-native database) across the full Ethereum → Arbitrum → Orbit stack. Self-host L1, L2, and L3 nodes with zero external RPC dependencies, or run any layer independently.

## Architecture

```
┌─── L1 (Ethereum) ──────────────────────────────────────────────────────────┐
│                                                                            │
│  Ethereum P2P → Lighthouse ──Engine API (JWT)──→ Reth ──IPC──→ Amp L1     │
│                                                    │             │         │
│                                                    │        Flight :1602   │
│                                                    │        JSONL  :1603   │
│                                                    │        Admin  :1610   │
└────────────────────────────────────────────────────┼─────────────┼─────────┘
                                                     │             │
┌─── L2 (Arbitrum One) ─────────────────────────┐    │             │
│                                                │    │             │
│  Nitro L2 ◄── parent-chain RPC (Reth) ────────┼────┘             │
│     │    ◄── beacon (Lighthouse)               │                 │
│     │                                          │                 │
│     └────────HTTP──────────→ Amp L2            │                 │
│                                │               │                 │
│                           Flight :1622         │                 │
│                           JSONL  :1623         │                 │
│                           Admin  :1630         │                 │
└────────────────┬───────────────┼───────────────┘                 │
                 │               │                                 │
┌─── L3 (Orbit) ┼───────────────┼─────────────────────────────────┼─────────┐
│                │               │                                 │         │
│  Nitro Orbit ◄─┘               │                                 │         │
│     │                          │                                 │         │
│     └────────HTTP──────────→ Amp Orbit                           │         │
│                                │                                 │         │
│                           Flight :1612                           │         │
│                           JSONL  :1613                           │         │
│                           Admin  :1620                           │         │
└────────────────────────────────┼─────────────────────────────────┼─────────┘
                                 │                                 │
                                 ▼                                 ▼
                            Prometheus                        PostgreSQL
                                 │
                                 ▼
                             Grafana :3000
```

The stack supports flexible deployment — run any combination of layers:

| Mode | Command | What runs |
|------|---------|-----------|
| **L1 only** | `just up` | Reth + Lighthouse + Amp (Ethereum) |
| **L1 + L2** | `just up-l2` | Above + Nitro L2 + Amp L2 (Arbitrum One) |
| **L1 + L2 + L3** | `just up-full` | Full self-hosted stack — no external RPCs |
| **L3 with external L2** | `just up-orbit` | Nitro Orbit + Amp Orbit (set `NITRO_PARENT_CHAIN_URL` to external RPC) |

**Key design**: On L1, Reth and Amp share an IPC socket (~18K vs ~8K ops/sec over HTTP). On L2/L3, Amp connects to Nitro via HTTP (Nitro has no IPC). The L2 Nitro node derives state from the co-located Reth (execution) and Lighthouse (beacon) — no external L1 RPC needed. The L3 Orbit Nitro derives from the local L2 Nitro via `NITRO_PARENT_CHAIN_URL=http://nitro-l2:8547`, completing a fully self-hosted chain of trust.

## Services

| Service | Image | Ports | Layer | Role |
|---------|-------|-------|-------|------|
| Reth | `ghcr.io/paradigmxyz/reth` | 8545, 8546, 30303, 9001 | L1 | Ethereum execution client |
| Lighthouse | `sigp/lighthouse` | 9000, 5052, 5054 | L1 | Ethereum consensus client |
| Amp | `ghcr.io/edgeandnode/amp` | 1602, 1603, 1610 | L1 | ETL + query engine (L1) |
| Nitro L2 | `offchainlabs/nitro-node` | 8549, 8550, 6071 | L2 | Arbitrum One execution client |
| Amp L2 | `ghcr.io/edgeandnode/amp` | 1622, 1623, 1630 | L2 | ETL + query engine (L2) |
| Nitro Orbit | `offchainlabs/nitro-node` | 8547, 8548, 6070 | L3 | Orbit L3 execution client |
| Amp Orbit | `ghcr.io/edgeandnode/amp` | 1612, 1613, 1620 | L3 | ETL + query engine (L3) |
| PostgreSQL | `postgres:16-alpine` | 5432 | Shared | Amp metadata storage |
| OTel Collector | `otel/opentelemetry-collector-contrib` | 4317, 4318 | Shared | Telemetry pipeline |
| Prometheus | `prom/prometheus` | 9090 | Shared | Metrics storage |
| Grafana | `grafana/grafana` | 3000 | Shared | Dashboards |

## Quick Start

### Prerequisites

- Docker with Compose v2
- [just](https://github.com/casey/just) command runner (recommended)
- 16GB+ RAM (L1 dev), 32GB+ RAM (L1 prod), 64GB+ RAM (full L1 + L2 + L3 stack)

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

### Arbitrum One L2

Run an Arbitrum One node alongside L1 — derives state from the local Reth and Lighthouse:

```bash
just setup
just up-l2            # L1 + Nitro L2 + Amp L2
just l2-sync-status   # Check Nitro L2 sync progress
```

> **Note**: On first startup, Nitro L2 downloads a ~300GB pruned snapshot from the Arbitrum Foundation. This can take a while.

### Full Stack (L1 + L2 + L3)

Run the entire self-hosted stack with no external RPC dependencies:

```bash
just setup
# Set the L3 parent chain to the local L2 in .env.local:
#   NITRO_PARENT_CHAIN_URL=http://nitro-l2:8547
just up-full          # L1 + L2 + L3 — fully self-hosted
just up-full-prod     # Production mode for all layers
```

Or run L3 with an external L2 RPC instead:

```bash
# Set an external Arbitrum One RPC in .env.local:
#   NITRO_PARENT_CHAIN_URL=https://arb-mainnet.g.alchemy.com/v2/<key>
just up-orbit         # L3 Orbit only (uses external L2 RPC)
```

### First Query

Once Amp has indexed some blocks:

```bash
# L1 (Ethereum)
just amp-query "SELECT number, hash, gas_used FROM blocks ORDER BY number DESC LIMIT 5"

# L2 (Arbitrum One)
just amp-l2-query "SELECT number, hash, gas_used FROM blocks ORDER BY number DESC LIMIT 5"

# L3 (Orbit)
just amp-orbit-query "SELECT number, hash, gas_used FROM blocks ORDER BY number DESC LIMIT 5"
```

## Commands

| Command | Description |
|---------|-------------|
| `just setup` | One-time setup: JWT, dirs, image pull |
| `just up` | Start L1 services (mainnet) |
| `just up-dev` | Start L1 in dev mode (Sepolia, adminer) |
| `just up-prod` | Start L1 in production mode |
| `just up-l2` | Start L1 + L2 (Arbitrum One) |
| `just up-l2-prod` | Start L1 + L2 in production mode |
| `just up-orbit` | Start L3 Orbit (external L2 RPC) |
| `just up-orbit-dev` | Start L3 Orbit in dev mode (testnet) |
| `just up-orbit-prod` | Start L3 Orbit in production mode |
| `just up-full` | Start L1 + L2 + L3 (fully self-hosted) |
| `just up-full-prod` | Start full stack in production mode |
| `just down` | Stop all services |
| `just status` | Health check all services |
| `just logs [service]` | Follow logs |
| `just ps` | Show running containers |
| `just versions` | Show pinned image versions |
| `just upgrade <component> <version>` | Rolling upgrade with rollback |
| `just amp-query "<SQL>"` | Run Amp L1 query |
| `just amp-l2-query "<SQL>"` | Run Amp L2 query |
| `just amp-orbit-query "<SQL>"` | Run Amp L3 Orbit query |
| `just sync-status` | Reth L1 sync progress |
| `just l2-sync-status` | Nitro L2 sync progress |
| `just l2-block-number` | Nitro L2 chain head block |
| `just orbit-sync-status` | Nitro L3 sync progress |
| `just orbit-block-number` | Nitro L3 chain head block |
| `just grafana` | Open Grafana dashboards |
| `just bench` | Run all benchmarks |
| `just bench-transport` | IPC vs HTTP comparison |
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
