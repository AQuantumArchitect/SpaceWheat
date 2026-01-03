#!/bin/bash
# Live Touch Input Test
# Boots the game with enough time to fully initialize
# Then provides instructions for manual clicking to observe debug patterns

set -e

TEST_LOG="/tmp/touch_input_live.log"

echo "═══════════════════════════════════════════════"
echo "LIVE TOUCH INPUT TEST"
echo "═══════════════════════════════════════════════"
echo ""
echo "This test will:"
echo "  1. Boot the game fully (10 second timeout)"
echo "  2. Show initialization status"
echo "  3. Provide clear instructions for manual testing"
echo ""

# Boot the game with longer timeout for full initialization
echo "Booting game (10 seconds to allow full initialization)..."
echo ""
timeout 10 godot --path /home/tehcr33d/ws/SpaceWheat 2>&1 | tee "$TEST_LOG" || true

echo ""
echo "═══════════════════════════════════════════════"
echo "INITIALIZATION ANALYSIS"
echo "═══════════════════════════════════════════════"
echo ""

# Check key initialization milestones
if grep -q "Quantum visualization initialized with layout_calculator" "$TEST_LOG"; then
    echo "✅ Quantum visualization initialized"
else
    echo "❌ Quantum visualization initialization FAILED"
fi

if grep -q "Touch: Tap-to-measure connected" "$TEST_LOG" && grep -q "Touch: Swipe-to-entangle connected" "$TEST_LOG"; then
    echo "✅ Touch gesture signals connected"
else
    echo "❌ Touch gesture signals NOT connected"
fi

if grep -q "Shared BiomeLayoutCalculator injected into PlotGridDisplay" "$TEST_LOG"; then
    echo "✅ Layout calculator shared between systems"
else
    echo "⚠️  Layout calculator injection not confirmed (may have timed out)"
fi

if grep -q "📍 Tile grid" "$TEST_LOG"; then
    echo "✅ Plot tiles created and positioned"
    echo ""
    echo "Sample tile positions:"
    grep "📍 Tile grid" "$TEST_LOG" | head -3
else
    echo "⚠️  Plot tiles not created (may have timed out)"
fi

echo ""
echo "═══════════════════════════════════════════════"
echo "BIOME OVAL LAYOUT"
echo "═══════════════════════════════════════════════"
echo ""
if grep -q "🟢 BiomeLayoutCalculator" "$TEST_LOG"; then
    grep "🟢 BiomeLayoutCalculator" "$TEST_LOG" -A3
else
    echo "❌ No biome layout output found"
fi

echo ""
echo "═══════════════════════════════════════════════"
echo "PLOT POSITIONING (ParametricPlotPositioner)"
echo "═══════════════════════════════════════════════"
echo ""
if grep -q "🔵 Biome" "$TEST_LOG"; then
    grep "🔵 Biome" "$TEST_LOG" -A3
else
    echo "⚠️  No plot positioning output found (may not have been created yet)"
fi

echo ""
echo "═══════════════════════════════════════════════"
echo "🎯 MANUAL TEST INSTRUCTIONS"
echo "═══════════════════════════════════════════════"
echo ""
echo "The automated test is complete. Now you need to:"
echo ""
echo "1. Run the game interactively:"
echo "   godot --path /home/tehcr33d/ws/SpaceWheat"
echo ""
echo "2. Wait for the game to fully load"
echo ""
echo "3. Click in different areas:"
echo "   a) Click on empty space (should show all 3 debug levels)"
echo "   b) Click on a quantum bubble (if visible)"
echo "   c) Click on a plot tile"
echo ""
echo "4. Observe the console output - you should see:"
echo ""
echo "   🎯 PlotGridDisplay._input: Mouse click at (x, y)"
echo "      Plot at position: (x, y) or (-1, -1)"
echo ""
echo "   📍 FarmView._unhandled_input: Mouse click at (x, y), pressed=true"
echo "      quantum_viz exists: true"
echo "      quantum_viz.graph exists: true"
echo ""
echo "   🖱️  QuantumForceGraph._unhandled_input: Mouse click at (x, y), pressed=true"
echo "      Local mouse pos: (x, y)"
echo "      Clicked node: <QuantumNode> or null"
echo ""
echo "5. Report which messages you see:"
echo ""
echo "   Pattern A: ALL THREE (🎯 📍 🖱️)"
echo "   → Input chain works! Problem is bubble detection or signal handling"
echo ""
echo "   Pattern B: ONLY 🎯"
echo "   → PlotGridDisplay is consuming input - needs Fix #1 (early return)"
echo ""
echo "   Pattern C: 🎯 and 📍 BUT NOT 🖱️"
echo "   → Input forwarding broken - needs Fix #2 (direct bubble check)"
echo ""
echo "   Pattern D: NO DEBUG OUTPUT"
echo "   → Something else consuming input before PlotGridDisplay"
echo ""

echo "Full initialization log: $TEST_LOG"
echo ""
