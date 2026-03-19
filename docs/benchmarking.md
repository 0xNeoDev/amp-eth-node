# Benchmarking

## Available Benchmarks

| Script | What it measures |
|---|---|
| `bench/rpc-throughput.sh` | Raw Reth RPC call rate (requests/sec) over IPC, HTTP, and WebSocket |
| `bench/amp-extraction.sh` | Amp block extraction rate (blocks/sec) from the tip of the chain |
| `bench/amp-query-latency.sh` | p50/p95/p99 query latency for Arrow Flight and JSONL HTTP |
| `bench/ipc-vs-http.sh` | Direct IPC vs HTTP transport comparison at varying concurrency levels |
| `bench/e2e-indexing.sh` | End-to-end time from block finalization to query availability |

Results are written to `bench/results/` as plain text files.

## Running Benchmarks

Benchmarks run inside a Docker container (`bench/Dockerfile`) with access to the live services. All services must be running and healthy before starting.

**Run all benchmarks:**

```sh
just bench
```

**Run individual benchmarks:**

```sh
just bench-rpc          # Reth RPC throughput
just bench-extraction   # Amp extraction rate
just bench-query        # Amp query latency
just bench-transport    # IPC vs HTTP comparison
```

**Run manually without `just`:**

```sh
docker compose -f docker-compose.yml -f docker-compose.bench.yml \
  run --rm bench-runner /bench/rpc-throughput.sh
```

## Reading Results

Each script prints a summary to stdout and exits 0 on success. The format is intentionally plain text so it can be diffed between runs.

Example output from `ipc-vs-http.sh`:

```
transport=ipc  concurrency=1   ops_per_sec=18243
transport=ipc  concurrency=8   ops_per_sec=17891
transport=ipc  concurrency=64  ops_per_sec=16102
transport=http concurrency=1   ops_per_sec=8441
transport=http concurrency=8   ops_per_sec=7983
transport=http concurrency=64  ops_per_sec=6204
```

To compare two runs:

```sh
diff bench/results/ipc-vs-http.txt bench/results/ipc-vs-http-previous.txt
```

## Expected Baseline Numbers

These numbers were measured on a machine with NVMe storage, 32 GB RAM, and an 8-core CPU. Your results will vary based on hardware, network sync status, and chain height.

| Benchmark | Expected |
|---|---|
| IPC throughput (single connection) | ~18,000 ops/sec |
| HTTP throughput (single connection) | ~8,000 ops/sec |
| Amp extraction rate (Sepolia, synced) | ~500–1,000 blocks/sec |
| Arrow Flight query latency p50 | <5 ms |
| JSONL HTTP query latency p50 | <15 ms |
| End-to-end block-to-query latency | <2 seconds |

**IPC degradation warning:** If IPC throughput drops below 10K ops/sec, check that both Reth and Amp are on the same Docker volume (not bind mounts to different disks). IPC is only fast when the socket file lives on a tmpfs or the same physical device.

## CI Benchmarks

The benchmark workflow (`.github/workflows/bench.yml`) runs on `workflow_dispatch` against the self-hosted runner. Results are uploaded as GitHub Actions artifacts with 90-day retention. Trigger it from the Actions tab when you want to validate a version upgrade or configuration change.
