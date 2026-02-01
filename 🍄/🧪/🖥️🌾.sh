#!/bin/bash

# 🖥️🌾 - SpaceWheat Visual Bubble Test (Full Display Mode)
# Watch quantum bubbles evolve with real FPS metrics
# Validates emoji atlas & GPU batching with visual feedback (80+ seconds)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

run_test_with_log "VisualBubbleTest.tscn" "80" "Visual Bubble Test" "false"
exit $?
