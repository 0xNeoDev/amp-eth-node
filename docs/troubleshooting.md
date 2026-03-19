# Troubleshooting

## Service Won't Start

**Check the logs first:**

```sh
just logs reth
just logs lighthouse
just logs amp
just logs postgres
```

**Check container status:**

```sh
just ps
# or:
docker compose ps
```

**Port already in use:**

If a service exits immediately, another process may be holding the port:

```sh
lsof -i :8545   # Reth HTTP
lsof -i :9000   # Lighthouse P2P
lsof -i :1602   # Amp Flight
```

Override the conflicting port in `.env.local` (see [configuration.md](configuration.md)) or stop the conflicting process.

**JWT file missing:**

```sh
ls -la jwt/jwt.hex
```

If missing, run `just setup` to regenerate it.

## IPC Socket Not Found

**Symptom:** Amp logs show `connection refused` or `no such file or directory` for `/ipc/reth.ipc`.

**Cause 1 — Reth not yet started:**

```sh
docker compose exec reth ls /ipc/
```

If the socket file isn't there, Reth hasn't created it yet. Wait for Reth to finish initializing (watch `just logs reth`). Reth creates the socket only after the database is open and the node is ready.

**Cause 2 — Volume not mounted:**

Verify both services share the `ipc-socket` volume:

```sh
docker inspect amp-eth-node-reth-1 | grep -A5 ipc-socket
docker inspect amp-eth-node-amp-1  | grep -A5 ipc-socket
```

Both should show the volume mounted. If Amp is missing the volume, check that you are using the base `docker-compose.yml` and not a stripped-down override.

**Cause 3 — Wrong path in provider config:**

Confirm `config/amp/providers/eth-mainnet.toml` has `url = "/ipc/reth.ipc"` (not an HTTP URL).

## Amp Can't Connect to Reth

**Symptom:** Amp extraction stalls or logs show repeated RPC errors.

**Not synced yet:** Reth must be at or near the chain tip before Amp can extract recent data. Check sync status:

```sh
just sync-status
```

If `eth_syncing` returns a sync object (not `false`), Reth is still catching up. On mainnet this can take days from scratch. Use checkpoint sync on Lighthouse and ensure disk I/O is not saturated.

**Provider config mismatch:** Confirm the network in the provider TOML matches `ETH_NETWORK` in `.env`. A mainnet provider pointed at a Sepolia node will return wrong data.

**Connection limit exhausted:** Under heavy extraction load, Reth may reject connections. Increase `--rpc.max-connections` in `docker-compose.yml` or lower `concurrent_request_limit` in the provider config.

## Out of Disk Space

**Check usage:**

```sh
docker system df
df -h /var/lib/docker   # or wherever Docker volumes live
```

**Prune unused images:**

```sh
docker image prune -f
```

**Find large volumes:**

```sh
docker volume ls -q | xargs -I{} docker run --rm -v {}:/vol alpine du -sh /vol 2>/dev/null
```

**Chain data growth:** Reth mainnet archive data grows continuously (~2.8 TB as of early 2025, growing ~1 GB/day). If disk is critically low, stop non-essential services first (`just down` then restart only critical ones) and extend storage before resuming.

For production, set up disk usage alerts before reaching 80% capacity.

## PostgreSQL Connection Refused

**Symptom:** Amp fails to start with `could not connect to server` or Grafana shows no data.

**Check if PostgreSQL is running:**

```sh
docker compose ps postgres
just logs postgres
```

**Healthcheck failing:**

```sh
docker compose exec postgres pg_isready -U amp -d amp
```

If this fails, PostgreSQL may still be initializing (first start) or the data directory may be corrupt. On first run, allow 30–60 seconds for initialization.

**Credential mismatch:** If `POSTGRES_USER`, `POSTGRES_PASSWORD`, or `POSTGRES_DB` were changed after the volume was created, the existing data directory won't match. Either restore matching credentials or remove the volume and let PostgreSQL reinitialize (you will lose Amp indexing state):

```sh
docker compose down
docker volume rm amp-eth-node_postgres-data
docker compose up -d
```

Amp will re-index from scratch after the volume is recreated.
