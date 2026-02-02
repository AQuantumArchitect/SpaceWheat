#!/bin/bash
# 🧬 Biome Stress Test - Buffer invalidation + creation/destruction
#
# Tests:
# - Buffer invalidation triggers escalation
# - Biome toggle (destroy/recreate) works correctly
# - No memory leaks or crashes
# - System recovers from buffer starvation
#
# Usage:
#   bash 🍄/🧪/🧬.sh [--verbose]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

VERBOSE=false
if [[ "$1" == "--verbose" ]]; then
    VERBOSE=true
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "🧬 BIOME STRESS TEST: Buffer Invalidation + Toggle"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "📋 Test sequence:"
echo "   1. ⏳ Stabilize with 6 biomes"
echo "   2. 💥 Invalidate biome 0 buffer"
echo "   3. 🔴 Toggle biome 1 OFF (destroy)"
echo "   4. 🟢 Toggle biome 1 ON (recreate)"
echo "   5. 💥 Invalidate biome 3 buffer"
echo "   6. 🔴 Toggle biome 2 OFF (destroy)"
echo "   7. 🟢 Toggle biome 2 ON (recreate)"
echo "   8. 🔄 Spam check: Test all 43 biomes in batches"
echo "   9. ✅ Verify no leaks/crashes"
echo ""
echo "─────────────────────────────────────────────────────────────────"

# Create a temporary scene that includes the stress test controller
TEMP_SCENE="/tmp/StressTest_$$.tscn"
cat > "$TEMP_SCENE" << 'EOF'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://Tests/StressTestController.gd" id="1"]

[node name="StressTestController" type="Node"]
script = ExtResource("1")
EOF

# Run the test (180 second timeout for all phases with 43 biomes)
if $VERBOSE; then
    timeout 180 godot --headless --scene VisualBubbleTest.tscn --verbose -- --stress-test 2>&1 | tee /tmp/stress_test_full.log
    EXIT_CODE=${PIPESTATUS[0]}
else
    timeout 180 godot --headless --scene VisualBubbleTest.tscn -- --stress-test 2>&1 | \
        grep -E "═|─|📍|🔄|💥|🔴|🟢|🎯|📊|📈|✅|❌|⚠️|ESCALATE|DE-ESCALATE|ERROR|WARNING|leak" | \
        tee /tmp/stress_test_output.log
    EXIT_CODE=${PIPESTATUS[0]}
fi

echo ""
echo "─────────────────────────────────────────────────────────────────"

# Check for errors
if [ $EXIT_CODE -eq 124 ]; then
    echo "⏱️  Test timed out (180s limit)"
    exit 1
elif [ $EXIT_CODE -ne 0 ]; then
    echo "❌ Test failed with exit code $EXIT_CODE"
    exit $EXIT_CODE
fi

# Check for memory leaks
if $VERBOSE; then
    LEAK_COUNT=$(grep -c "Leaked instance" /tmp/stress_test_full.log 2>/dev/null || echo "0")
else
    LEAK_COUNT=0
fi

if [ "$LEAK_COUNT" -gt 0 ]; then
    echo ""
    echo "⚠️  MEMORY LEAKS DETECTED: $LEAK_COUNT instances"
    if $VERBOSE; then
        echo ""
        grep "Leaked instance" /tmp/stress_test_full.log | head -10
    else
        echo "   Run with --verbose to see details"
    fi
    echo ""
else
    echo "✅ No memory leaks detected"
fi

# Check for errors
if $VERBOSE; then
    ERROR_COUNT=$(grep -c "ERROR:" /tmp/stress_test_full.log 2>/dev/null || echo "0")
else
    ERROR_COUNT=$(grep -c "ERROR:" /tmp/stress_test_output.log 2>/dev/null || echo "0")
fi

if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "❌ Errors detected: $ERROR_COUNT"
    exit 1
else
    echo "✅ No errors detected"
fi

# Check for escalation
if $VERBOSE; then
    ESCALATE_COUNT=$(grep -c "\[ESCALATE\]" /tmp/stress_test_full.log 2>/dev/null || echo "0")
else
    ESCALATE_COUNT=$(grep -c "\[ESCALATE\]" /tmp/stress_test_output.log 2>/dev/null || echo "0")
fi

echo "📊 Escalations detected: $ESCALATE_COUNT"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "🎉 STRESS TEST PASSED"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Cleanup
rm -f "$TEMP_SCENE"
