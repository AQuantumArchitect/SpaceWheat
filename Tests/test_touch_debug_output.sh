#!/bin/bash
# Test Touch Input Debug Output
# Boots the game and verifies debug instrumentation is in place

set -e

TEST_LOG="/tmp/touch_debug_test.log"

echo "═══════════════════════════════════════════════"
echo "TOUCH INPUT DEBUG VERIFICATION TEST"
echo "═══════════════════════════════════════════════"
echo ""
echo "This test verifies that debug output is correctly"
echo "instrumented at all three levels of the input chain:"
echo "  🎯 PlotGridDisplay._input"
echo "  📍 FarmView._unhandled_input"
echo "  🖱️  QuantumForceGraph._unhandled_input"
echo ""

# Boot the game with a short timeout to capture initialization
echo "1. Booting game to capture initialization output..."
echo ""
timeout 5 godot --path /home/tehcr33d/ws/SpaceWheat 2>&1 | tee "$TEST_LOG" || true

echo ""
echo "═══════════════════════════════════════════════"
echo "2. Analyzing debug output..."
echo "═══════════════════════════════════════════════"
echo ""

# Check if game booted successfully
if grep -q "FarmView ready - game started!" "$TEST_LOG"; then
    echo "✅ Game initialization completed successfully"
else
    echo "⚠️  Game initialization may have issues"
fi
echo ""

# Check if quantum visualization was created
if grep -q "Quantum visualization initialized" "$TEST_LOG"; then
    echo "✅ Quantum visualization created"
else
    echo "❌ Quantum visualization NOT created"
fi
echo ""

# Check if touch signal connections succeeded
if grep -q "Touch: Tap-to-measure connected" "$TEST_LOG"; then
    echo "✅ node_clicked signal connected (tap gesture)"
else
    echo "❌ node_clicked signal NOT connected"
fi

if grep -q "Touch: Swipe-to-entangle connected" "$TEST_LOG"; then
    echo "✅ node_swiped_to signal connected (swipe gesture)"
else
    echo "❌ node_swiped_to signal NOT connected"
fi
echo ""

# Check if input processing was enabled
if grep -q "set_process_unhandled_input" "$TEST_LOG" || grep -q "Touch controls enabled" "$TEST_LOG"; then
    echo "✅ Input processing enabled"
else
    echo "⚠️  Input processing status unclear"
fi
echo ""

echo "═══════════════════════════════════════════════"
echo "3. Debug Instrumentation Check"
echo "═══════════════════════════════════════════════"
echo ""
echo "The following debug messages should appear when you CLICK:"
echo ""
echo "Expected Pattern (if working correctly):"
echo "  🎯 PlotGridDisplay._input: Mouse click at ..."
echo "     Plot at position: (-1, -1)  [if not over a plot]"
echo "  📍 FarmView._unhandled_input: Mouse click at ..."
echo "     quantum_viz exists: true"
echo "     quantum_viz.graph exists: true"
echo "  🖱️  QuantumForceGraph._unhandled_input: Mouse click at ..."
echo "     Local mouse pos: ..."
echo "     Clicked node: <QuantumNode> or null"
echo ""

echo "═══════════════════════════════════════════════"
echo "4. MANUAL TEST REQUIRED"
echo "═══════════════════════════════════════════════"
echo ""
echo "To complete the test:"
echo ""
echo "  1. Run: godot --path /home/tehcr33d/ws/SpaceWheat"
echo ""
echo "  2. Click anywhere in the game window"
echo ""
echo "  3. Observe which debug messages appear in the console"
echo ""
echo "  4. Report the pattern:"
echo ""
echo "     Pattern A: All 3 messages (🎯 📍 🖱️) → Input reaches graph!"
echo "     Pattern B: Only 🎯 → PlotGridDisplay blocking (Fix #1)"
echo "     Pattern C: 🎯 and 📍 only → Forwarding broken (Fix #2)"
echo "     Pattern D: No messages → Hidden input blocker"
echo ""

echo "Full log saved to: $TEST_LOG"
echo ""
echo "Ready for manual testing!"
