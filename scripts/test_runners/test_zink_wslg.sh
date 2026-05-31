#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${1:-/tmp/spacewheat_zink_wslg_$(date +%Y%m%d_%H%M%S)}"

echo "========================================================================="
echo "WSLG ZINK RENDERER PROBE"
echo "========================================================================="
echo
echo "This wrapper probes the live runtime on WSLg with zink requested."
echo

SW_WSL_MESA_DRIVER_OVERRIDE="${SW_WSL_MESA_DRIVER_OVERRIDE:-zink}" \
bash "$ROOT_DIR/scripts/compare_headed_renderers.sh" "$OUT_DIR"
