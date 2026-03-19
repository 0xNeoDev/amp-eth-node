#!/usr/bin/env bash
set -euo pipefail

# Benchmark: IPC vs HTTP vs WebSocket transport comparison
# This is the headline benchmark — demonstrates IPC performance advantage
ITERATIONS="${ITERATIONS:-1000}"
RESULTS_DIR="/results"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

echo "=== IPC vs HTTP vs WebSocket Transport Benchmark ==="
echo "Iterations: $ITERATIONS"
echo ""

RPC_PAYLOAD='{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# --- HTTP ---
echo "--- HTTP (${RETH_HTTP_URL}) ---"
HTTP_START=$(date +%s%N)
for _i in $(seq 1 "$ITERATIONS"); do
    curl -sf -X POST -H 'Content-Type: application/json' \
        -d "$RPC_PAYLOAD" "${RETH_HTTP_URL}" > /dev/null
done
HTTP_END=$(date +%s%N)
HTTP_TOTAL_MS=$(( (HTTP_END - HTTP_START) / 1000000 ))
HTTP_AVG=$(echo "scale=2; $HTTP_TOTAL_MS / $ITERATIONS" | bc)
HTTP_OPS=$(echo "scale=0; $ITERATIONS * 1000 / $HTTP_TOTAL_MS" | bc)
echo "  Total: ${HTTP_TOTAL_MS}ms | Avg: ${HTTP_AVG}ms | Throughput: ${HTTP_OPS} ops/sec"
echo ""

# --- IPC (via socat) ---
echo "--- IPC (${RETH_IPC_PATH}) ---"
if [[ -S "${RETH_IPC_PATH}" ]]; then
    IPC_START=$(date +%s%N)
    for _i in $(seq 1 "$ITERATIONS"); do
        echo "$RPC_PAYLOAD" | socat - UNIX-CONNECT:"${RETH_IPC_PATH}" > /dev/null 2>&1
    done
    IPC_END=$(date +%s%N)
    IPC_TOTAL_MS=$(( (IPC_END - IPC_START) / 1000000 ))
    IPC_AVG=$(echo "scale=2; $IPC_TOTAL_MS / $ITERATIONS" | bc)
    IPC_OPS=$(echo "scale=0; $ITERATIONS * 1000 / $IPC_TOTAL_MS" | bc)
    echo "  Total: ${IPC_TOTAL_MS}ms | Avg: ${IPC_AVG}ms | Throughput: ${IPC_OPS} ops/sec"
else
    echo "  IPC socket not available at ${RETH_IPC_PATH} — skipping"
    IPC_TOTAL_MS=0
    IPC_AVG="N/A"
    IPC_OPS=0
fi
echo ""

# --- Summary ---
echo "=== Summary ==="
printf "  %-12s %10s %10s %10s\n" "Transport" "Total(ms)" "Avg(ms)" "Ops/sec"
printf "  %-12s %10s %10s %10s\n" "---------" "---------" "-------" "-------"
printf "  %-12s %10s %10s %10s\n" "HTTP" "$HTTP_TOTAL_MS" "$HTTP_AVG" "$HTTP_OPS"
if [[ -S "${RETH_IPC_PATH}" ]]; then
    printf "  %-12s %10s %10s %10s\n" "IPC" "$IPC_TOTAL_MS" "$IPC_AVG" "$IPC_OPS"
    SPEEDUP=$(echo "scale=1; $HTTP_TOTAL_MS / $IPC_TOTAL_MS" | bc)
    echo ""
    echo "  IPC is ${SPEEDUP}x faster than HTTP"
fi
echo ""

cat > "${RESULTS_DIR}/transport_comparison_${TIMESTAMP}.json" <<EOF
{
  "benchmark": "transport_comparison",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "iterations": $ITERATIONS,
  "http": {
    "total_ms": $HTTP_TOTAL_MS,
    "avg_ms": $HTTP_AVG,
    "ops_per_sec": $HTTP_OPS
  },
  "ipc": {
    "total_ms": ${IPC_TOTAL_MS:-0},
    "avg_ms": "${IPC_AVG}",
    "ops_per_sec": ${IPC_OPS:-0}
  }
}
EOF

echo "Results saved to ${RESULTS_DIR}/transport_comparison_${TIMESTAMP}.json"
