#!/usr/bin/env bash
set -euo pipefail

# Benchmark: Reth RPC throughput using vegeta HTTP load tester
DURATION="${DURATION:-30s}"
RATE="${RATE:-500}"
RESULTS_DIR="/results"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

echo "=== Reth RPC Throughput Benchmark ==="
echo "Duration: $DURATION | Rate: $RATE req/s"
echo ""

# eth_blockNumber — lightweight call
echo "--- eth_blockNumber (lightweight) ---"
echo "POST ${RETH_HTTP_URL}" | vegeta attack \
    -duration="$DURATION" \
    -rate="$RATE" \
    -header="Content-Type: application/json" \
    -body=<(echo '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}') \
    | tee "${RESULTS_DIR}/rpc_blockNumber_${TIMESTAMP}.bin" \
    | vegeta report -type=text

echo ""

# eth_getBlockByNumber — heavier call
echo "--- eth_getBlockByNumber (medium) ---"
echo "POST ${RETH_HTTP_URL}" | vegeta attack \
    -duration="$DURATION" \
    -rate="${RATE}" \
    -header="Content-Type: application/json" \
    -body=<(echo '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest",false],"id":1}') \
    | tee "${RESULTS_DIR}/rpc_getBlock_${TIMESTAMP}.bin" \
    | vegeta report -type=text

echo ""
echo "Results saved to ${RESULTS_DIR}/"

# JSON summary
vegeta report -type=json < "${RESULTS_DIR}/rpc_blockNumber_${TIMESTAMP}.bin" > "${RESULTS_DIR}/rpc_blockNumber_${TIMESTAMP}.json"
vegeta report -type=json < "${RESULTS_DIR}/rpc_getBlock_${TIMESTAMP}.bin" > "${RESULTS_DIR}/rpc_getBlock_${TIMESTAMP}.json"
