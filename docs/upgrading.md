# Upgrading

## Version Pinning Strategy

All image tags are pinned in `.env`. Never use floating tags like `latest` in production — pin to an explicit version so upgrades are deliberate and rollback is possible.

```dotenv
# .env
RETH_VERSION=v1.11.3
LIGHTHOUSE_VERSION=v6.0.1
AMP_VERSION=v2.4.0
```

Check for new releases:
- Reth: https://github.com/paradigmxyz/reth/releases
- Lighthouse: https://github.com/sigp/lighthouse/releases
- Amp: https://github.com/edgeandnode/amp/releases

## Rolling Upgrade

Use the `upgrade` recipe to update a single component without restarting the entire stack:

```sh
just upgrade reth v1.12.0
just upgrade lighthouse v6.1.0
just upgrade amp v2.5.0
```

The `upgrade` script (`scripts/upgrade.sh`) updates the variable in `.env`, pulls the new image, and restarts only the affected service.

To upgrade manually:

```sh
# 1. Update the pin in .env
sed -i 's/RETH_VERSION=.*/RETH_VERSION=v1.12.0/' .env

# 2. Pull the new image
docker compose pull reth

# 3. Restart the service
docker compose up -d --no-deps reth
```

Check that the service comes back healthy after each upgrade before proceeding to the next component.

## Amp Migrations

When upgrading Amp across minor versions, database migrations may run automatically on startup. Watch the logs:

```sh
just logs amp
```

Look for lines like `Running migration 0042_add_trace_index`. Migrations are applied in order and are not reversible without a restore. Always snapshot the PostgreSQL volume before a major Amp upgrade:

```sh
docker run --rm \
  -v amp-eth-node_postgres-data:/data:ro \
  -v $(pwd):/backup \
  alpine tar czf /backup/postgres-backup-$(date +%Y%m%d).tar.gz /data
```

## Rollback Procedure

If a service fails to start or behaves incorrectly after an upgrade:

```sh
# Revert the version pin
just upgrade reth v1.11.3   # or edit .env manually

# Restart the service
docker compose up -d --no-deps reth
```

If Amp's database schema is incompatible after a rollback, restore from the snapshot taken before the upgrade, then restart:

```sh
docker compose stop amp postgres

# Restore snapshot (replace filename)
docker run --rm \
  -v amp-eth-node_postgres-data:/data \
  -v $(pwd):/backup \
  alpine sh -c "rm -rf /data/* && tar xzf /backup/postgres-backup-20250101.tar.gz -C /"

docker compose up -d postgres amp
```

## Blue-Green Deployment (Advanced)

For production environments where downtime is not acceptable, run two stacks side by side and switch traffic at the load balancer.

1. Clone the repo to a second directory (e.g., `amp-eth-node-green`).
2. Override ports in `amp-eth-node-green/.env.local` so they don't collide with the blue stack:
   ```dotenv
   AMP_FLIGHT_PORT=1612
   AMP_JSONL_PORT=1613
   RETH_HTTP_PORT=8555
   ```
3. Start the green stack and let it sync (or point it at a shared read-only Reth IPC socket).
4. Verify the green stack is healthy and data is current.
5. Update your load balancer or service discovery to route traffic to the green ports.
6. Tear down the blue stack.

Note: Reth and Lighthouse require exclusive access to their data directories. Both stacks must use separate volumes or bind-mount paths. Sharing the IPC socket between stacks is safe (read-only access from Amp).
