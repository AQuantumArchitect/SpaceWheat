#!/bin/bash
# Run Godot with built-in profiling enabled

OUTPUT_LOG="/tmp/godot_profile_$(date +%s).log"

echo "==========================================="
echo "Godot Profiler Run"
echo "==========================================="
echo "Duration: 60 seconds"
echo "Output: $OUTPUT_LOG"
echo

# Run with profiling enabled
timeout 60s godot --headless --profiling 2>&1 | tee "$OUTPUT_LOG"

echo
echo "✅ Profiling complete!"
echo
echo "==========================================="
echo "PROFILER DATA"
echo "==========================================="
echo

# Extract profiling data
echo "📊 Function timing (top 30 slowest):"
echo "---"
grep -E "Time:|Function:|ms|μs" "$OUTPUT_LOG" | head -60

echo
echo "📄 Full log saved to: $OUTPUT_LOG"
echo "   View with: less $OUTPUT_LOG"
