#!/bin/bash

# 🌾 - SpaceWheat Headless Bubble Test (GPU Atlas Verification)
# Rapid performance profiling without display overhead
# Validates emoji atlas & GPU batching in headless mode (80+ seconds)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

run_test_with_log "VisualBubbleTest.tscn" "80" "Headless Bubble Test" "true"
exit $?
