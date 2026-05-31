#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${1:-/tmp/spacewheat_runtime_benchmark_$(date +%Y%m%d_%H%M%S)}"

echo "========================================================================="
echo "RUNTIME WORKLOAD BENCHMARK TEST"
echo "========================================================================="
echo
echo "This wrapper now profiles the production runtime workload ladder."
echo "The old integrated compute benchmark path no longer exists."
echo

PROFILE_WARMUP_FRAMES="${PROFILE_WARMUP_FRAMES:-60}" \
PROFILE_SAMPLE_FRAMES="${PROFILE_SAMPLE_FRAMES:-120}" \
PROFILE_WORKLOAD_CASES="${PROFILE_WORKLOAD_CASES:-00_dormant 01_single 03_dense_4 07_multi_4}" \
bash "$ROOT_DIR/scripts/profile-render-workload.sh" "$OUT_DIR"
