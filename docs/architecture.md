# Architecture

## System Diagram

```
                         ┌─────────────────────────────────────────────────────────┐
                         │                   Docker Compose Network                │
                         │                                                         │
  Ethereum P2P           │  ┌─────────────┐   Engine API (JWT)  ┌──────────────┐  │
  ───────────►  :9000    │  │ Lighthouse  │ ──────────────────► │    Reth      │  │
                         │  │ (consensus) │                     │ (execution)  │  │
                         │  └─────────────┘                     └──────┬───────┘  │
                         │                                             │          │
                         │                                    IPC socket          │
                         │                                    /ipc/reth.ipc       │
                         │                                    (shared volume)     │
                         │                                             │          │
                         │                                      ┌──────▼───────┐  │
                         │                                      │     Amp      │  │
                         │                                      │  (extractor) │  │
                         │                                      └──────┬───────┘  │
                         │                                             │          │
                         │                              ┌──────────────┴───────┐  │
                         │                              │                      │  │
                         │                     Arrow Flight :1602     JSONL HTTP :1603
                         │                              │                      │  │
                         │  ┌──────────────────────────────────────────────┐   │  │
                         │  │  Observability: Prometheus + Grafana + OTel  │   │  │
                         │  └──────────────────────────────────────────────┘   │  │
                         └─────────────────────────────────────────────────────┘  │
                                                                                   │
                          Clients ◄─────────────────────────────────────────────┘
```

## IPC Socket Design

The `ipc-socket` Docker volume is the most critical performance decision in this stack.

Reth writes its Unix domain socket (`/ipc/reth.ipc`) into the `ipc-socket` volume. Amp mounts the same volume read-only and connects via the socket path instead of HTTP. This eliminates TCP overhead and HTTP framing entirely.

**Measured impact:** ~18K ops/sec over IPC vs ~8K ops/sec over HTTP (same host, same Reth instance). For high-throughput block extraction this difference is significant — Amp can drain the RPC queue roughly 2x faster.

The volume is declared in `docker-compose.yml` and mounted by both services:
- `reth`: `ipc-socket:/ipc` (read-write, Reth creates the socket here)
- `amp`: `ipc-socket:/ipc:ro` (read-only mount is sufficient for socket access)

The provider is configured in `config/amp/providers/eth-mainnet.toml` with `url = "/ipc/reth.ipc"`.

## Services

| Service | Image | Role |
|---|---|---|
| `reth` | `ghcr.io/paradigmxyz/reth` | Execution layer. Syncs the EVM chain, exposes HTTP/WS RPC and IPC socket |
| `lighthouse` | `sigp/lighthouse` | Consensus layer. Drives Reth via Engine API over JWT-authenticated HTTP |
| `amp` | `ghcr.io/edgeandnode/amp` | Extracts and indexes on-chain data, serves queries via Arrow Flight and JSONL |
| `postgres` | `postgres` | Amp metadata store (indexing state, schema, cursors) |
| `otel-collector` | `otel/opentelemetry-collector-contrib` | Receives OTLP telemetry from Amp and forwards to Prometheus |
| `prometheus` | `prom/prometheus` | Scrapes metrics from Reth, Lighthouse, and Amp |
| `grafana` | `grafana/grafana` | Dashboards for sync progress, extraction rates, and query latency |

## Data Flow

```
1. P2P         Lighthouse gossips with the Ethereum beacon network on :9000,
               receiving new beacon blocks from peers.

2. Consensus   Lighthouse calls Reth's Engine API (port 8551, JWT auth) to
               deliver execution payloads and drive the fork-choice update.

3. Execution   Reth applies the execution payload, updates the EVM state, and
               makes the block available via RPC. It exposes the IPC socket at
               /ipc/reth.ipc and HTTP at :8545.

4. Extraction  Amp reads blocks from Reth via the IPC socket, decodes EVM data,
               and writes structured records (blocks, transactions, logs, traces)
               to its local data directory and metadata to PostgreSQL.

5. Transform   Amp applies manifest-defined schemas (see config/amp/manifests/)
               to transform raw chain data into queryable datasets.

6. Serve       Clients query Amp over Arrow Flight (:1602) for high-throughput
               columnar reads or over JSONL HTTP (:1603) for ad-hoc queries.
```
