# Quick Start

## Prerequisites

- Docker 24+ with the Compose plugin (`docker compose version`)
- Docker Compose v2 (bundled with Docker Desktop; on Linux: `apt install docker-compose-plugin`)
- [`just`](https://github.com/casey/just) — optional but recommended (`brew install just` / `cargo install just`)
- 16 GB RAM minimum (Reth + Lighthouse are memory-hungry during initial sync)
- 100 GB free disk for Sepolia; 4 TB+ for mainnet archive

## Steps

### 1. Clone the repository

```sh
git clone https://github.com/your-org/amp-eth-node.git
cd amp-eth-node
```

### 2. Run setup

```sh
just setup
# or without just:
bash scripts/setup.sh
```

This generates a JWT secret in `jwt/jwt.hex`, creates required directories, and pulls all Docker images.

### 3. Configure for Sepolia (development)

Create a local override file:

```sh
cp .env.local.example .env.local
```

Edit `.env.local` and uncomment:

```
ETH_NETWORK=sepolia
LIGHTHOUSE_CHECKPOINT_SYNC_URL=https://sepolia.beaconstate.info
```

### 4. Start services

```sh
just up-dev
# or without just:
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

The dev compose overlay sets Sepolia as the network and reduces resource limits.

### 5. Check status

```sh
just status
# or:
bash scripts/health.sh
```

Watch the logs to confirm services come up:

```sh
just logs reth
just logs lighthouse
just logs amp
```

Lighthouse will checkpoint-sync first (usually a few minutes). Reth follows execution sync. Expect 10–30 minutes before Amp starts extracting on Sepolia.

### 6. Run your first query

Once Amp is healthy, run a test query:

```sh
just amp-query "SELECT number, hash, timestamp FROM blocks ORDER BY number DESC LIMIT 5"
```

Open Grafana to see sync progress and extraction metrics:

```sh
just grafana   # opens http://localhost:3000 (admin / admin)
```

## Common First-Time Issues

**Reth exits immediately on start**
Check that the JWT file exists: `ls -la jwt/jwt.hex`. If missing, re-run `just setup`.

**Lighthouse fails to connect to Reth**
Lighthouse depends on Reth being healthy. Wait for Reth's healthcheck to pass (`just ps`). The auth port (8551) must not be blocked by a firewall.

**Checkpoint sync URL returns an error**
Some public checkpoint endpoints are intermittently unavailable. Try an alternative:
- Mainnet: `https://sync-mainnet.beaconcha.in`
- Sepolia: `https://checkpoint-sync.sepolia.ethpandaops.io`

**Amp reports "IPC socket not found"**
Reth has not yet created the socket. Wait for Reth to be fully started and check: `docker compose exec reth ls /ipc/`. See [troubleshooting.md](troubleshooting.md).

**Port conflict on startup**
If ports 8545, 9000, or 1602 are already in use, override them in `.env.local`. See [configuration.md](configuration.md).
