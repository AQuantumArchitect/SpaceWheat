#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${1:-/tmp/spacewheat_zink_probe_$(date +%Y%m%d_%H%M%S)}"

echo "========================================================================="
echo "ZINK RENDERER PROBE"
echo "========================================================================="
echo
echo "There is no live dedicated GPU-compute runtime path right now."
echo "This wrapper probes the current runtime under zink for presentation"
echo "and renderer-path comparison only."
echo

SW_WSL_MESA_DRIVER_OVERRIDE="${SW_WSL_MESA_DRIVER_OVERRIDE:-zink}" \
bash "$ROOT_DIR/scripts/compare_headed_renderers.sh" "$OUT_DIR"
