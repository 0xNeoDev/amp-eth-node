# Hardware Recommendations

## Development (Sepolia)

| Resource | Minimum |
|---|---|
| CPU | 4 cores |
| RAM | 16 GB |
| Disk | 100 GB SSD |
| Network | 10 Mbps |

A modern laptop or a small cloud VM (e.g., 4 vCPU / 16 GB) is sufficient for Sepolia. The full stack (Reth + Lighthouse + Amp + observability) fits comfortably in 8–12 GB RAM on Sepolia with swap available for peaks.

## Production (Mainnet, Full Node)

| Resource | Recommended |
|---|---|
| CPU | 8+ cores (16 preferred) |
| RAM | 32 GB minimum, 64 GB recommended |
| Disk | 2 TB+ NVMe (see storage details below) |
| Network | 100 Mbps+ symmetric, uncapped |

CPU: Reth is multi-threaded and benefits from many cores during initial sync and EVM execution. Lighthouse is lighter but appreciates dedicated cores for validator duties if running any.

RAM: Reth's in-memory cache and Lighthouse's state cache together consume 16–24 GB under load. Amp adds another 2–4 GB. Leave headroom for the OS page cache — fast disk reads depend on it.

Network: Ethereum P2P is bandwidth-intensive during initial sync (tens of GB/day). A 100 Mbps unmetered connection is the practical minimum. More bandwidth = faster initial sync.

## Storage Details

### Mainnet Archive Node (~2.8 TB as of early 2025)

| Component | Approximate Size | Growth Rate |
|---|---|---|
| Reth chain data (archive) | ~2.5 TB | ~1–2 GB/day |
| Lighthouse beacon data | ~150 GB | ~100 MB/day |
| Amp indexed data | ~50–200 GB | depends on manifests |
| PostgreSQL metadata | ~5–20 GB | slow growth |

**Total: ~2.8–3 TB today, plan for 4 TB+ to avoid running out.**

### Mainnet Full Node (no archive)

Running Reth with `--full` disables historical trace/state access and keeps only recent state. This reduces Reth's disk footprint to roughly 1.0–1.2 TB, growing more slowly. Amp manifests that require `debug_traceTransaction` will not work against a full node.

### Storage Class

NVMe is strongly recommended. Reth performs millions of small random reads and writes during sync and normal operation. SATA SSD works but sync is noticeably slower. Spinning disk is not viable.

For Docker deployments, bind-mount NVMe paths using `docker-compose.prod.yml` and set `RETH_DATA_DIR`, `LIGHTHOUSE_DATA_DIR`, etc. in `.env.local`. See [configuration.md](configuration.md).

## Cloud Instances

Tested configurations:

| Provider | Instance | Notes |
|---|---|---|
| AWS | `r6i.2xlarge` (8 vCPU / 64 GB) + 4 TB `gp3` | Adequate; use `io2` for faster sync |
| GCP | `n2-highmem-8` (8 vCPU / 64 GB) + 4 TB Hyperdisk | Good balance of cost and performance |
| Hetzner | `AX102` dedicated (AMD EPYC, 256 GB, 2× 3.84 TB NVMe) | Best value for self-hosted production |

Avoid burstable instance types (T-series on AWS, B-series on Azure) — sustained I/O during sync will exhaust CPU credits immediately.
