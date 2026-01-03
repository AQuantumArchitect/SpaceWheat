#!/bin/bash
# Run Automated Tap Test
# This test loads the game and injects fake mouse clicks to verify input routing

set -e

TEST_LOG="/tmp/automated_tap_test.log"

echo "═══════════════════════════════════════════════"
echo "AUTOMATED TAP TEST - Running..."
echo "═══════════════════════════════════════════════"
echo ""
echo "This test will:"
echo "  1. Load the full game"
echo "  2. Wait for initialization"
echo "  3. Inject fake mouse clicks at 4 positions"
echo "  4. Monitor which debug messages appear"
echo "  5. Report the input routing pattern"
echo ""
echo "Running test (15 second timeout)..."
echo ""

# Run the test scene with timeout
timeout 15 godot --path /home/tehcr33d/ws/SpaceWheat res://Tests/automated_tap_test.tscn 2>&1 | tee "$TEST_LOG"

echo ""
echo "═══════════════════════════════════════════════"
echo "ANALYZING RESULTS..."
echo "═══════════════════════════════════════════════"
echo ""

# Count how many times each debug message appeared
PLOTGRID_COUNT=$(grep -c "🎯 PlotGridDisplay._input" "$TEST_LOG" || echo "0")
FARMVIEW_COUNT=$(grep -c "📍 FarmView._unhandled_input" "$TEST_LOG" || echo "0")
QUANTUMGRAPH_COUNT=$(grep -c "🖱️  QuantumForceGraph._unhandled_input" "$TEST_LOG" || echo "0")
BUBBLE_TAP_COUNT=$(grep -c "🎯🎯🎯 BUBBLE TAP HANDLER CALLED" "$TEST_LOG" || echo "0")

echo "Debug message counts (should see ~4 of each for 4 test clicks):"
echo "  🎯 PlotGridDisplay._input:              $PLOTGRID_COUNT"
echo "  📍 FarmView._unhandled_input:           $FARMVIEW_COUNT"
echo "  🖱️  QuantumForceGraph._unhandled_input: $QUANTUMGRAPH_COUNT"
echo "  🎯🎯🎯 BUBBLE TAP HANDLER:                $BUBBLE_TAP_COUNT"
echo ""

# Determine pattern
if [ "$PLOTGRID_COUNT" -gt 0 ] && [ "$FARMVIEW_COUNT" -gt 0 ] && [ "$QUANTUMGRAPH_COUNT" -gt 0 ]; then
    echo "✅ PATTERN A: ALL THREE DEBUG LEVELS RESPOND"
    echo ""
    echo "Input chain is working correctly!"
    echo "Input reaches: PlotGridDisplay → FarmView → QuantumForceGraph"
    echo ""
    if [ "$BUBBLE_TAP_COUNT" -gt 0 ]; then
        echo "✅ BUBBLE TAP HANDLER CALLED!"
        echo "Touch controls should be working!"
    else
        echo "⚠️  Bubble tap handler NOT called"
        echo "Possible issues:"
        echo "  - No bubbles at test positions (need to plant wheat first)"
        echo "  - Bubble detection broken (get_node_at_position)"
        echo "  - Signal not emitted from QuantumForceGraph"
        echo "  - Signal not connected to FarmView handler"
    fi
elif [ "$PLOTGRID_COUNT" -gt 0 ] && [ "$FARMVIEW_COUNT" -gt 0 ] && [ "$QUANTUMGRAPH_COUNT" -eq 0 ]; then
    echo "⚠️  PATTERN C: FARMVIEW RECEIVES INPUT BUT QUANTUMGRAPH DOESN'T"
    echo ""
    echo "Input forwarding from FarmView to QuantumForceGraph is broken!"
    echo ""
    echo "Fix required:"
    echo "  File: UI/FarmView.gd lines 268-270"
    echo "  Replace input forwarding with direct bubble check"
    echo ""
    echo "Apply Fix #2 from ready_for_manual_test.md"
elif [ "$PLOTGRID_COUNT" -gt 0 ] && [ "$FARMVIEW_COUNT" -eq 0 ]; then
    echo "⚠️  PATTERN B: ONLY PLOTGRIDDISPLAY RECEIVES INPUT"
    echo ""
    echo "PlotGridDisplay is consuming input before it reaches _unhandled_input!"
    echo ""
    echo "Fix required:"
    echo "  File: UI/PlotGridDisplay.gd line ~673"
    echo "  Add early return when click is not over a plot"
    echo ""
    echo "Apply Fix #1 from ready_for_manual_test.md"
elif [ "$PLOTGRID_COUNT" -eq 0 ]; then
    echo "❌ PATTERN D: NO DEBUG OUTPUT AT ALL"
    echo ""
    echo "Something is consuming ALL input before PlotGridDisplay!"
    echo ""
    echo "Investigation needed:"
    echo "  Search for hidden _input handlers:"
    echo "  grep -r 'func _input\\|func _gui_input' UI/ --include='*.gd'"
else
    echo "❓ UNEXPECTED PATTERN"
    echo ""
    echo "Debug message counts don't match expected patterns."
    echo "Check the full log at: $TEST_LOG"
fi

echo ""
echo "Full log saved to: $TEST_LOG"
echo ""
