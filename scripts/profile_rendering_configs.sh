#!/bin/bash
# Frame cost profiling across rendering configurations
# Captures detailed breakdown of where frame time is spent

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

OUTPUT_DIR="/tmp/rendering_profile_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"

echo "========================================================================="
echo "RENDERING CONFIGURATION PROFILER"
echo "========================================================================="
echo ""
echo "Output directory: $OUTPUT_DIR"
echo ""
echo "Testing configurations:"
echo "  1. forward_mobile + Zink + GPU compute"
echo "  2. gl_compatibility + Zink + Native C++"
echo "  3. gl_compatibility + OpenGL + Native C++"
echo "  4. forward_mobile + OpenGL + Native C++"
echo ""
echo "Each test runs for ~600 frames (~25 seconds at 24 FPS)"
echo "Profile reports generated at frames 300 and 600"
echo ""
echo "========================================================================="
echo ""

run_test() {
    local config_name="$1"
    local driver="$2"
    local method="$3"
    local mesa_override="$4"
    local libgl_override="$5"

    echo ""
    echo "========================================================================="
    echo "TEST: $config_name"
    echo "========================================================================="
    echo "Driver:  $driver"
    echo "Method:  $method"
    echo "Mesa:    $mesa_override"
    echo "LibGL:   $libgl_override"
    echo ""

    local log_file="$OUTPUT_DIR/${config_name}.log"

    # Set environment
    export DISPLAY=:0
    if [ -n "$mesa_override" ]; then
        export MESA_LOADER_DRIVER_OVERRIDE="$mesa_override"
    else
        unset MESA_LOADER_DRIVER_OVERRIDE
    fi
    if [ -n "$libgl_override" ]; then
        export LIBGL_ALWAYS_SOFTWARE="$libgl_override"
    else
        unset LIBGL_ALWAYS_SOFTWARE
    fi

    # Run godot, timeout after 35 seconds
    timeout 35 godot \
        --rendering-driver "$driver" \
        --rendering-method "$method" \
        VisualBubbleTest.tscn \
        2>&1 | tee "$log_file"

    local exit_code=$?

    # Extract summary
    echo ""
    echo "--- SUMMARY: $config_name ---"
    grep -E "ComputeSelector.*Selected:|FPS|PERFORMANCE BREAKDOWN|FRAME TIME BREAKDOWN|untracked|Top GDScript|ACTUAL:" "$log_file" | tail -20
    echo ""

    return $exit_code
}

# Test 1: forward_mobile + Zink (GPU compute)
run_test "01_forward_mobile_zink_gpu" \
    "vulkan" \
    "forward_mobile" \
    "zink" \
    ""

# Test 2: gl_compatibility + Zink (Native C++)
run_test "02_gl_compat_zink_native" \
    "opengl3" \
    "gl_compatibility" \
    "zink" \
    ""

# Test 3: gl_compatibility + native OpenGL (Native C++)
run_test "03_gl_compat_opengl_native" \
    "opengl3" \
    "gl_compatibility" \
    "" \
    "1"

# Test 4: forward_mobile + OpenGL (Native C++)
run_test "04_forward_mobile_opengl_native" \
    "vulkan" \
    "forward_mobile" \
    "" \
    "1"

echo ""
echo "========================================================================="
echo "PROFILING COMPLETE"
echo "========================================================================="
echo ""
echo "Generating comparison report..."
echo ""

# Generate comparison report
REPORT="$OUTPUT_DIR/COMPARISON_REPORT.txt"

cat > "$REPORT" << 'EOF'
========================================================================
RENDERING CONFIGURATION COMPARISON
========================================================================

Configuration Performance Summary:

EOF

for log in "$OUTPUT_DIR"/*.log; do
    if [ -f "$log" ]; then
        config_name=$(basename "$log" .log)
        echo "--- $config_name ---" >> "$REPORT"

        # Extract key metrics
        grep "ComputeSelector.*Selected:" "$log" | head -1 >> "$REPORT"
        grep "ACTUAL:" "$log" | tail -2 >> "$REPORT"
        grep "untracked:" "$log" | tail -2 >> "$REPORT"
        grep -A 3 "Top GDScript costs:" "$log" | tail -4 >> "$REPORT"

        echo "" >> "$REPORT"
    fi
done

cat >> "$REPORT" << EOF

========================================================================
ANALYSIS
========================================================================

Key Metrics to Compare:
- FPS (frames per second) - higher is better
- Frame time (ms) - lower is better
- Untracked time (ms) - rendering pipeline overhead
- Top GDScript costs - where tracked time is spent

Rendering Pipeline Efficiency:
- Lower untracked time = more efficient rendering pipeline
- gl_compatibility typically has lower overhead than forward_mobile
- Zink translation can optimize OpenGL->Vulkan for llvmpipe

Compute Backend:
- GPU_COMPUTE: Vulkan compute shaders (requires RenderingDevice)
- NATIVE_CPU: C++ GDExtension (always available)
- GDSCRIPT_CPU: Pure GDScript fallback

========================================================================
EOF

cat "$REPORT"

echo ""
echo "Full logs saved to: $OUTPUT_DIR/"
echo "Comparison report: $REPORT"
echo ""
