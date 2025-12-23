#!/bin/bash
## Automated Play Test: Network Overlay Initialization
## Tests that the game launches and systems initialize correctly

cd /home/tehcr33d/ws/SpaceWheat

echo "═══════════════════════════════════════════════════════"
echo "   AUTOMATED PLAY TEST: Network Initialization"
echo "═══════════════════════════════════════════════════════"
echo ""

# Test 1: Game launches without crashes
echo "TEST 1: Game Launch (5 second run)"
echo "─────────────────────────────────────────"
timeout 5 godot --headless --quit 2>&1 > /tmp/playtest_output.txt

if grep -q "✅ FarmView ready!" /tmp/playtest_output.txt; then
    echo "✅ Game launched successfully"
else
    echo "❌ Game failed to launch"
    cat /tmp/playtest_output.txt | grep "ERROR"
fi
echo ""

# Test 2: Conspiracy network initializes
echo "TEST 2: Conspiracy Network Initialization"
echo "─────────────────────────────────────────"
if grep -q "TomatoConspiracyNetwork initialized" /tmp/playtest_output.txt; then
    echo "✅ Conspiracy network initialized"
    grep "TomatoConspiracyNetwork" /tmp/playtest_output.txt
else
    echo "❌ Conspiracy network did not initialize"
fi
echo ""

# Test 3: Network overlay created
echo "TEST 3: Network Overlay Creation"
echo "─────────────────────────────────────────"
if grep -q "ConspiracyNetworkOverlay ready" /tmp/playtest_output.txt; then
    echo "✅ Network overlay created"
    grep "ConspiracyNetworkOverlay" /tmp/playtest_output.txt
else
    echo "❌ Network overlay not created"
fi
echo ""

# Test 4: Icons initialized
echo "TEST 4: Icon System Initialization"
echo "─────────────────────────────────────────"
icon_count=$(grep -c "Icon initialized" /tmp/playtest_output.txt)
if [ "$icon_count" -ge 2 ]; then
    echo "✅ Icons initialized ($icon_count found)"
    grep "Icon initialized" /tmp/playtest_output.txt
else
    echo "❌ Icons not properly initialized"
fi
echo ""

# Test 5: Check for errors
echo "TEST 5: Error Check"
echo "─────────────────────────────────────────"
error_count=$(grep -c "ERROR:" /tmp/playtest_output.txt)
if [ "$error_count" -eq 0 ]; then
    echo "✅ No errors detected"
else
    echo "⚠️  $error_count errors found:"
    grep "ERROR:" /tmp/playtest_output.txt | head -5
fi
echo ""

# Test 6: Check for warnings
echo "TEST 6: Warning Check"
echo "─────────────────────────────────────────"
warning_count=$(grep -c "WARNING:" /tmp/playtest_output.txt)
if [ "$warning_count" -eq 0 ]; then
    echo "✅ No warnings"
else
    echo "⚠️  $warning_count warnings found:"
    grep "WARNING:" /tmp/playtest_output.txt | head -5
fi
echo ""

# Summary
echo "═══════════════════════════════════════════════════════"
echo "   TEST SUMMARY"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "Initialization Status:"
grep "initialized\|ready\|created" /tmp/playtest_output.txt | grep "✅\|🍅\|📊\|🧬\|🌾\|💰\|🎯"
echo ""
echo "Full output saved to: /tmp/playtest_output.txt"
echo ""
echo "═══════════════════════════════════════════════════════"
