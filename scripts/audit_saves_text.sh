#!/bin/bash

## Simple text-based audit of save files and scenarios

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo ""
echo "=========================================================================="
echo "🔍 SAVE FILE & SCENARIO AUDIT (Text-based)"
echo "=========================================================================="
echo ""

# Function to analyze a file
analyze_file() {
	local path="$1"
	local label="$2"

	if [ ! -f "$path" ]; then
		echo "  ❌ File not found: $path"
		return
	fi

	echo "📄 $label: $(basename "$path")"

	# Check file size
	local size=$(stat -f%z "$path" 2>/dev/null || stat -c%s "$path" 2>/dev/null)
	echo "  📊 Size: $size bytes"

	# Extract key fields
	echo "  🔍 Contents:"

	# Get scenario_id
	if grep -q "scenario_id" "$path"; then
		local scenario=$(grep "scenario_id" "$path" | head -1 | sed 's/.*scenario_id = "\([^"]*\)".*/\1/')
		echo "    - scenario_id: $scenario"
	fi

	# Get grid dimensions
	if grep -q "grid_width" "$path"; then
		local grid_w=$(grep "grid_width" "$path" | head -1 | sed 's/.*grid_width = \([0-9]*\).*/\1/')
		echo "    - grid_width: $grid_w"
	fi
	if grep -q "grid_height" "$path"; then
		local grid_h=$(grep "grid_height" "$path" | head -1 | sed 's/.*grid_height = \([0-9]*\).*/\1/')
		echo "    - grid_height: $grid_h"
	fi

	# Get credits
	if grep -q "^credits" "$path"; then
		local credits=$(grep "^credits" "$path" | sed 's/.*credits = \([0-9]*\).*/\1/')
		echo "    - credits: $credits"
	fi

	# Check for removed fields
	echo "  ⚠️  Field check:"

	if grep -q '"theta"' "$path"; then
		echo "    - ❌ Has 'theta' (OBSOLETE - should regenerate from biome)"
	fi
	if grep -q '"phi"' "$path"; then
		echo "    - ❌ Has 'phi' (OBSOLETE - should regenerate from biome)"
	fi
	if grep -q '"growth_progress"' "$path"; then
		echo "    - ❌ Has 'growth_progress' (OBSOLETE)"
	fi
	if grep -q '"is_mature"' "$path"; then
		echo "    - ❌ Has 'is_mature' (OBSOLETE)"
	fi

	if grep -q '"theta_frozen"' "$path"; then
		echo "    - ✅ Has 'theta_frozen' (correct)"
	else
		echo "    - ⚠️  Missing 'theta_frozen' (should be present)"
	fi

	# Count plots
	local plot_count=$(grep -o '"position":' "$path" | wc -l)
	echo "    - Plots: $plot_count"

	echo ""
}

# Audit scenarios
echo "▶ PHASE 1: SCENARIO FILES"
echo "----------------------------------------------------------------------"
analyze_file "$REPO_ROOT/Scenarios/default.tres" "SCENARIO"

# Audit saves
echo ""
echo "▶ PHASE 2: SAVE FILES"
echo "----------------------------------------------------------------------"

SAVE_DIR="/root/.local/share/godot/app_userdata/SpaceWheat_-_Quantum_Farm/saves"
if [ ! -d "$SAVE_DIR" ]; then
	# Try alternative paths
	SAVE_DIR=$(find ~  -path "*/app_userdata/SpaceWheat*" -type d 2>/dev/null | head -1)
	if [ -z "$SAVE_DIR" ]; then
		echo "⚠️  No save directory found. Checking user:// path..."
		SAVE_DIR="."
	fi
fi

if [ "$SAVE_DIR" = "." ]; then
	# Just note that we couldn't find it
	echo "No persistent save directory found (normal for new installs)"
else
	for save_file in "$SAVE_DIR"/save_slot_*.tres; do
		if [ -f "$save_file" ]; then
			analyze_file "$save_file" "SAVE"
		fi
	done
fi

echo "=========================================================================="
echo "✅ AUDIT COMPLETE"
echo "=========================================================================="
echo ""
