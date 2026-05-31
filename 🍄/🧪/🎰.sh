#!/bin/bash
# 🎰 Market Lab — per-biome MarketLattice behavior readout
#
# Iterates every biome in biomes.json, asks MarketLattice.propose_offers for
# its axial position, and prints a summary (or detail block) per biome.
#
# Usage:
#   bash 🍄/🧪/🎰.sh                    # one-line summary per biome
#   bash 🍄/🧪/🎰.sh --detail           # full detail block per biome
#   bash 🍄/🧪/🎰.sh --biome StarterForest  # single biome, full detail
#   bash 🍄/🧪/🎰.sh --csv              # also dump biome × top-offer CSV
#
# Output is both echoed to stdout and saved to logs/market_lab/<timestamp>.log.
# CSV (when --csv passed) goes to logs/market_lab/<timestamp>.csv.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

LOG_DIR="$PROJECT_ROOT/logs/market_lab"
mkdir -p "$LOG_DIR"
STAMP="$(date +"%Y%m%d_%H%M%S")"
LOG_FILE="$LOG_DIR/market_lab_${STAMP}.log"
CSV_FILE="$LOG_DIR/market_lab_${STAMP}.csv"

# Pass through user args; --csv triggers our CSV path
GODOT_ARGS=()
EMIT_CSV=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --csv)        EMIT_CSV=1; shift ;;
    --detail)     GODOT_ARGS+=(--detail); shift ;;
    --biome)      GODOT_ARGS+=(--biome "$2"); shift 2 ;;
    --top)        GODOT_ARGS+=(--top "$2"); shift 2 ;;
    *)            echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
if [[ $EMIT_CSV -eq 1 ]]; then
  GODOT_ARGS+=(--csv "$CSV_FILE")
fi

echo "[market-lab] $(date -Is) start" | tee "$LOG_FILE"

# DEPRECATED: the standalone all-biomes scan (tests/market_lab_biomes.gd) was
# deleted, and standalone --script labs can no longer build biomes (a custom
# SceneTree gets no project autoloads, and BiomeBuilder resolves IconRegistry via
# absolute /root paths that throw outside the active tree). Use the rig-driven
# lab instead — it boots fully and reads live per-biome entropy / kT / price.
echo "[market-lab] ⚠️  standalone market lab is deprecated — delegating to the rig lab" | tee -a "$LOG_FILE"
echo "[market-lab]     (run directly: bash 🍄/🧪/🌡️.sh [scenario])" | tee -a "$LOG_FILE"
bash "$SCRIPT_DIR/🌡️.sh" 2>&1 | tee -a "$LOG_FILE"

echo "[market-lab] log → $LOG_FILE"
