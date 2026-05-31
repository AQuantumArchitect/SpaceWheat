#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${1:-/tmp/spacewheat_backend_selection_$(date +%Y%m%d_%H%M%S)}"

echo "========================================================================="
echo "RUNTIME RENDERER SELECTION TEST"
echo "========================================================================="
echo
echo "This wrapper now profiles the live runtime renderer lanes."
echo "The archived ComputeBackendSelector / VisualBubbleTest path is gone."
echo

bash "$ROOT_DIR/scripts/compare_headed_renderers.sh" "$OUT_DIR"
