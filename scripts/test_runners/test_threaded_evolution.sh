#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${1:-/tmp/spacewheat_evolution_runtime_$(date +%Y%m%d_%H%M%S)}"

echo "========================================================================="
echo "EVOLUTION RUNTIME TEST"
echo "========================================================================="
echo
echo "This wrapper measures the live batcher/runtime cadence instead of the"
echo "archived threaded VisualBubbleTest lane."
echo

PROFILE_WARMUP_FRAMES="${PROFILE_WARMUP_FRAMES:-60}" \
PROFILE_SAMPLE_FRAMES="${PROFILE_SAMPLE_FRAMES:-120}" \
PROFILE_WORKLOAD_CASES="${PROFILE_WORKLOAD_CASES:-01_single 03_dense_4 12_expanded_4x2}" \
bash "$ROOT_DIR/scripts/profile-render-workload.sh" "$OUT_DIR"
