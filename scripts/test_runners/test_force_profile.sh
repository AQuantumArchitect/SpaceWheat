#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${1:-/tmp/spacewheat_force_profile_$(date +%Y%m%d_%H%M%S)}"

echo "========================================================================="
echo "FORCE / RUNTIME PROFILE TEST"
echo "========================================================================="
echo
echo "This wrapper profiles live force-graph workload cases."
echo

PROFILE_WARMUP_FRAMES="${PROFILE_WARMUP_FRAMES:-45}" \
PROFILE_SAMPLE_FRAMES="${PROFILE_SAMPLE_FRAMES:-90}" \
PROFILE_WORKLOAD_CASES="${PROFILE_WORKLOAD_CASES:-01_single 03_dense_4 07_multi_4}" \
bash "$ROOT_DIR/scripts/profile-render-workload.sh" "$OUT_DIR"
