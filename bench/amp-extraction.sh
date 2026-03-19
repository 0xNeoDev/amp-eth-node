#!/usr/bin/env bash
set -euo pipefail

# Benchmark: Amp block extraction rate
# Measures how fast Amp extracts blocks from Reth
RESULTS_DIR="/results"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

echo "=== Amp Block Extraction Rate Benchmark ==="
echo ""

# Get initial block count
INITIAL=$(curl -sf -X POST -H 'Content-Type: application/json' \
    -d '{"query":"SELECT max(number) as latest_block FROM blocks"}' \
    "${AMP_JSONL_URL}" | jq -r '.data[0].latest_block // 0')

echo "Initial latest block: $INITIAL"
echo "Waiting 60 seconds to measure extraction rate..."
sleep 60

FINAL=$(curl -sf -X POST -H 'Content-Type: application/json' \
    -d '{"query":"SELECT max(number) as latest_block FROM blocks"}' \
    "${AMP_JSONL_URL}" | jq -r '.data[0].latest_block // 0')

echo "Final latest block: $FINAL"

BLOCKS_EXTRACTED=$((FINAL - INITIAL))
RATE=$(echo "scale=2; $BLOCKS_EXTRACTED / 60" | bc)

echo ""
echo "Blocks extracted: $BLOCKS_EXTRACTED in 60s"
echo "Extraction rate: $RATE blocks/sec"

# Save results
cat > "${RESULTS_DIR}/extraction_${TIMESTAMP}.json" <<EOF
{
  "benchmark": "amp_extraction_rate",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "initial_block": $INITIAL,
  "final_block": $FINAL,
  "blocks_extracted": $BLOCKS_EXTRACTED,
  "duration_seconds": 60,
  "rate_blocks_per_second": $RATE
}
EOF

echo "Results saved to ${RESULTS_DIR}/extraction_${TIMESTAMP}.json"
