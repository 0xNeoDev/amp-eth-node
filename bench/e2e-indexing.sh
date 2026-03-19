#!/usr/bin/env bash
set -euo pipefail

# Benchmark: End-to-end indexing latency
# Measures time from block appearing on-chain to being queryable in Amp
RESULTS_DIR="/results"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

echo "=== End-to-End Indexing Latency Benchmark ==="
echo ""

# Get current chain head from Reth
CHAIN_HEAD=$(curl -sf -X POST -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    "${RETH_HTTP_URL}" | jq -r '.result' | xargs printf '%d')

echo "Current chain head: $CHAIN_HEAD"

# Get latest indexed block from Amp
AMP_HEAD=$(curl -sf -X POST -H 'Content-Type: application/json' \
    -d '{"query":"SELECT max(number) as latest_block FROM blocks"}' \
    "${AMP_JSONL_URL}" | jq -r '.data[0].latest_block // 0')

echo "Latest Amp block:  $AMP_HEAD"

LAG=$((CHAIN_HEAD - AMP_HEAD))
echo "Block lag: $LAG blocks"
echo ""

# Now measure how long it takes for Amp to catch up by 1 block
echo "Measuring time for Amp to index next block..."
TARGET=$((AMP_HEAD + 1))
START=$(date +%s%N)
MAX_WAIT=120
ELAPSED_S=0

while [[ $ELAPSED_S -lt $MAX_WAIT ]]; do
    CURRENT=$(curl -sf -X POST -H 'Content-Type: application/json' \
        -d "{\"query\":\"SELECT max(number) as latest_block FROM blocks\"}" \
        "${AMP_JSONL_URL}" | jq -r '.data[0].latest_block // 0')

    if [[ "$CURRENT" -ge "$TARGET" ]]; then
        END=$(date +%s%N)
        LATENCY_MS=$(( (END - START) / 1000000 ))
        echo "Block $TARGET indexed in ${LATENCY_MS}ms"

        cat > "${RESULTS_DIR}/e2e_indexing_${TIMESTAMP}.json" <<EOF
{
  "benchmark": "e2e_indexing_latency",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "chain_head": $CHAIN_HEAD,
  "amp_head_before": $AMP_HEAD,
  "block_lag": $LAG,
  "target_block": $TARGET,
  "indexing_latency_ms": $LATENCY_MS
}
EOF
        echo "Results saved to ${RESULTS_DIR}/e2e_indexing_${TIMESTAMP}.json"
        exit 0
    fi

    sleep 0.5
    NOW=$(date +%s%N)
    ELAPSED_S=$(( (NOW - START) / 1000000000 ))
done

echo "Timed out waiting for block $TARGET after ${MAX_WAIT}s"
exit 1
