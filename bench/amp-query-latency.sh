#!/usr/bin/env bash
set -euo pipefail

# Benchmark: Amp query latency for JSONL HTTP API
ITERATIONS="${ITERATIONS:-100}"
RESULTS_DIR="/results"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

echo "=== Amp Query Latency Benchmark ==="
echo "Iterations: $ITERATIONS"
echo ""

# Simple count query
echo "--- SELECT count(*) FROM blocks ---"
TIMES=()
for _i in $(seq 1 "$ITERATIONS"); do
    START=$(date +%s%N)
    curl -sf -X POST -H 'Content-Type: application/json' \
        -d '{"query":"SELECT count(*) FROM blocks"}' \
        "${AMP_JSONL_URL}" > /dev/null
    END=$(date +%s%N)
    ELAPSED=$(( (END - START) / 1000000 ))
    TIMES+=("$ELAPSED")
done

# Calculate stats
mapfile -t SORTED < <(printf '%s\n' "${TIMES[@]}" | sort -n)
COUNT=${#SORTED[@]}
P50=${SORTED[$((COUNT * 50 / 100))]}
P95=${SORTED[$((COUNT * 95 / 100))]}
P99=${SORTED[$((COUNT * 99 / 100))]}
MIN=${SORTED[0]}
MAX=${SORTED[$((COUNT - 1))]}

SUM=0
for t in "${TIMES[@]}"; do SUM=$((SUM + t)); done
AVG=$((SUM / COUNT))

echo "  Min: ${MIN}ms | Avg: ${AVG}ms | P50: ${P50}ms | P95: ${P95}ms | P99: ${P99}ms | Max: ${MAX}ms"

cat > "${RESULTS_DIR}/query_latency_${TIMESTAMP}.json" <<EOF
{
  "benchmark": "amp_query_latency",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "query": "SELECT count(*) FROM blocks",
  "iterations": $ITERATIONS,
  "latency_ms": {
    "min": $MIN,
    "avg": $AVG,
    "p50": $P50,
    "p95": $P95,
    "p99": $P99,
    "max": $MAX
  }
}
EOF

echo ""
echo "Results saved to ${RESULTS_DIR}/query_latency_${TIMESTAMP}.json"
