#!/bin/bash
set -euo pipefail

# 🖥️🌾 - SpaceWheat headed runtime probe

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="${1:-$PROJECT_ROOT/🍄/🎛️/.godot_tmp/headed_runtime_$(date +%Y%m%d_%H%M%S)}"

echo "🖥️🌾 headed runtime probe"
echo "output: $OUT_DIR"

bash "$PROJECT_ROOT/scripts/profile_headed_runtime.sh" "$OUT_DIR"
