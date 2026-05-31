#!/bin/bash
set -euo pipefail

# 🧬 Biome stress workload runner

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="${1:-$PROJECT_ROOT/🍄/🎛️/.godot_tmp/biome_stress_$(date +%Y%m%d_%H%M%S)}"

echo "🧬 biome stress workload runner"
echo "output: $OUT_DIR"
echo "cases: ${PROFILE_WORKLOAD_CASES:-09_expanded_2x1 10_expanded_3x1 11_expanded_4x1 12_expanded_4x2 13_expanded_6x2}"

PROFILE_WARMUP_FRAMES="${PROFILE_WARMUP_FRAMES:-60}" \
PROFILE_SAMPLE_FRAMES="${PROFILE_SAMPLE_FRAMES:-150}" \
PROFILE_WORKLOAD_CASES="${PROFILE_WORKLOAD_CASES:-09_expanded_2x1 10_expanded_3x1 11_expanded_4x1 12_expanded_4x2 13_expanded_6x2}" \
bash "$PROJECT_ROOT/scripts/profile-render-workload.sh" "$OUT_DIR"
