#!/bin/bash

# 🏋️‍♀️ - Performance & Frame Budget Analysis with GPU Offload Verification
# Detailed performance metrics and stress testing with emoji atlas GPU verification

# Source shared test library for DRY utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

echo "🏋️‍♀️ Frame Budget Profiler"
echo "=========================="
echo "Measuring physics vs visual processing..."
echo "This will take ~40 seconds (warmup + 2 measurement phases)"
echo ""

# Run frame budget profiler and capture output
PROFILER_OUTPUT=$(godot --scene Tests/FrameBudgetProfilerScene.tscn 2>&1 || true)
EXIT_CODE=$?

# Display relevant performance data
echo "$PROFILER_OUTPUT" | grep -E "fps|ms|budget|offload|atlas" || true

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Performance analysis completed${NC}"
else
    echo ""
    echo -e "${YELLOW}⚠️  Analysis exited with code: $EXIT_CODE${NC}"
fi

# Validate GPU offload (emoji atlas and native renderer)
verify_gpu_offload "$PROFILER_OUTPUT"

exit $EXIT_CODE
