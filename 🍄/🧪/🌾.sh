#!/bin/bash
set -euo pipefail

# 🌾 - SpaceWheat headless runtime probe

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="${1:-$PROJECT_ROOT/🍄/🎛️/.godot_tmp/headless_runtime_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$OUT_DIR"

PROFILE_MODE="${PROFILE_MODE:-single}"
PROFILE_OUTPUT="$OUT_DIR/${PROFILE_MODE}.json"

source "$SCRIPT_DIR/lib.sh"
prepare_godot_user_dir
sw_prepare_runtime_env "headless"

echo "🌾 headless runtime probe"
echo "mode: $PROFILE_MODE"
echo "output: $PROFILE_OUTPUT"

sw_godot \
  --headless \
  --path "$PROJECT_ROOT" \
  -- \
  --runtime-profile-mode="$PROFILE_MODE" \
  --runtime-profile-output="$PROFILE_OUTPUT" \
  --runtime-profile-warmup="${PROFILE_WARMUP_FRAMES:-60}" \
  --runtime-profile-frames="${PROFILE_SAMPLE_FRAMES:-120}"
