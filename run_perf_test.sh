#!/bin/bash

## Performance Test Script
## Runs the game for 50 seconds with automated exploration
## Captures and analyzes performance data

cd "$(dirname "$0")" || exit 1

LOGFILE="/tmp/perf_test_$(date +%s).log"
DURATION=55  # Slightly longer than the test's 50 seconds

echo "========================================="
echo "Performance Test - Automated Exploration"
echo "========================================="
echo "Duration: ${DURATION} seconds"
echo "Output: $LOGFILE"
echo ""

# Run game with 55 second timeout and auto-test enabled
export AUTO_TEST=1
timeout ${DURATION} godot scenes/FarmView.tscn > "$LOGFILE" 2>&1

echo "✅ Test complete!"
echo ""
echo "========================================="
echo "PERFORMANCE DATA SUMMARY"
echo "========================================="
echo ""

# Extract PERF_HUD data
echo "📊 Performance Samples (PERF_HUD):"
echo "---"
grep "PERF_HUD" "$LOGFILE" | grep -E "Frame|FPS|ENGINE|Total:|Batches" | tail -20
echo ""

# Batch analysis
echo "📦 Batch State Analysis:"
echo "---"
grep "PERF_HUD.*Batches:" "$LOGFILE" | sed 's/.*Batches: //' | sort | uniq -c | sort -rn
echo ""

# UI component analysis
echo "⚙️ UI Component Performance (if tracked):"
echo "---"
grep "PERF_HUD.*:" "$LOGFILE" | grep -v "Frame\|ENGINE\|Total\|Graph\|Rendering\|Bottleneck\|===" | tail -10
echo ""

# Bottleneck summary
echo "🚨 Bottlenecks Detected:"
echo "---"
grep "BOTTLENECK" "$LOGFILE" | sed 's/.*BOTTLENECK//' | sort | uniq -c | sort -rn | head -5
echo ""

# UIPerformanceTracker debug
echo "🔍 UIPerformanceTracker Status:"
echo "---"
if grep -q "UIPerformanceTracker.*Started tracking" "$LOGFILE"; then
	echo "✅ UIPerformanceTracker is active"
	grep "UIPerformanceTracker.*Started tracking" "$LOGFILE" | sort | uniq
else
	echo "❌ UIPerformanceTracker not active - UI components not being tracked!"
fi
echo ""

# Frame time statistics
echo "📈 Frame Time Statistics:"
echo "---"
FRAME_TIMES=$(grep "PERF_HUD.*FPS:" "$LOGFILE" | grep -oE "FPS: [0-9]+" | grep -oE "[0-9]+")
if [ -n "$FRAME_TIMES" ]; then
	MIN_FPS=$(echo "$FRAME_TIMES" | sort -n | head -1)
	MAX_FPS=$(echo "$FRAME_TIMES" | sort -n | tail -1)
	AVG_FPS=$(echo "$FRAME_TIMES" | awk '{sum+=$1; count++} END {print int(sum/count)}')
	echo "FPS Range: $MIN_FPS - $MAX_FPS (Avg: $AVG_FPS)"
else
	echo "No FPS data found"
fi
echo ""

# Full log location
echo "📄 Full log saved to: $LOGFILE"
echo "   View with: tail -100 $LOGFILE"
echo "   Search PERF_HUD: grep PERF_HUD $LOGFILE"
echo ""
