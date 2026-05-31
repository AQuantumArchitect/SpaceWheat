#!/bin/bash
# 🗺️  Faction Signature Gate Audit & Balance Sweep
#
# Runs the headless gate audit to report faction admission rates across all
# biomes under the new icon-pair gate. Saves a timestamped JSONL log.
#
# Usage:
#   bash 🍄/🧪/🗺️.sh                # Gate audit only
#   bash 🍄/🧪/🗺️.sh --verbose      # Verbose Godot output
#
# Output:
#   🍄/🎛️/logs/codex_checks/gate_audit_<timestamp>.txt
#
# Interpretation:
#   PASS  = gate wired and producing results
#   WARN  = biomes with 0 admitted factions (neutral zones or missing icon ownership)
#   FAIL  = hard errors (too many locked-out factions, registry broken, etc.)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

VERBOSE=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --verbose) VERBOSE=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

LOGS_DIR="$PROJECT_ROOT/🍄/🎛️/logs/codex_checks"
mkdir -p "$LOGS_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOGS_DIR/gate_audit_${TIMESTAMP}.txt"

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       🗺️  FACTION SIGNATURE GATE AUDIT                      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo "Running gate audit..."
echo "(log → $LOG_FILE)"
echo ""

OUTPUT=$(timeout 90 godot --headless --script tests/test_faction_signature_gate.gd 2>&1)
EXIT_CODE=$?

echo "$OUTPUT" | tee "$LOG_FILE"
echo ""

# Extract summary line
RESULTS=$(echo "$OUTPUT" | grep "📊 Results:" || echo "")
WARNINGS=$(echo "$OUTPUT" | grep -c "^  ⚠" || true)
ZERO_FACTION=$(echo "$OUTPUT" | grep "biomes with 0 admitted" | grep -oP '\d+' | head -1 || echo "?")
LOCKED_OUT=$(echo "$OUTPUT" | grep "factions with zero biome access" | grep -oP '\d+' | head -1 || echo "?")

echo -e "${BLUE}── Summary ──────────────────────────────────────────────────${NC}"
if [ -n "$RESULTS" ]; then
    echo "  $RESULTS"
fi
echo "  Biomes with no admitted factions: $ZERO_FACTION (neutral zones or need icon assignment)"
echo "  Locked-out factions:     $LOCKED_OUT (no owned icons in IconAtlas)"
echo ""

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ Gate audit passed${NC}"
else
    echo -e "${RED}❌ Gate audit FAILED (exit $EXIT_CODE)${NC}"
    echo ""
    echo "  Next steps:"
    echo "  1. Identify biomes with no admitted factions in the log above"
    echo "  2. For each: either assign icon ownership in Core/Factions/data/icons.json"
    echo "               or accept it as an intentional neutral-zone biome"
    echo "  3. Re-run: bash 🍄/🧪/🗺️.sh"
fi

echo ""
echo "  Full log saved: $LOG_FILE"
echo ""

exit $EXIT_CODE
