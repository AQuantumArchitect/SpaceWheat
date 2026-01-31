#!/bin/bash

# 🌾 - SpaceWheat Visual Bubble Test with GPU Emoji Atlas Verification
# Watch quantum bubbles evolve and interact
# Verifies that emoji rendering is GPU-accelerated via atlas batching

# Source shared test library for DRY utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# Run visual bubble test with emoji atlas validation
run_test_scene "VisualBubbleTest.tscn" 20 "🌾 Visual Bubble Test - GPU Emoji Verification"
EXIT_CODE=$?

# Additional GPU offload analysis
BUBBLE_OUTPUT=$(timeout 20 godot --scene VisualBubbleTest.tscn 2>&1 || true)
verify_gpu_offload "$BUBBLE_OUTPUT"

exit $EXIT_CODE
