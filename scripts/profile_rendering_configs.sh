#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-/tmp/rendering_profile_$(date +%Y%m%d_%H%M%S)}"

echo "========================================================================="
echo "RENDERING CONFIGURATION PROFILER"
echo "========================================================================="
echo
echo "This entrypoint now profiles the live game runtime rather than"
echo "the archived VisualBubbleTest / compute-selector path."
echo
echo "Output directory: $OUTPUT_DIR"
echo

bash "$ROOT_DIR/scripts/compare_headed_renderers.sh" "$OUTPUT_DIR"
