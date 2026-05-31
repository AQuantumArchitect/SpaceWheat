#!/bin/bash

# 🍄 Test Library - Shared utilities for test scripts
# DRY principle: All test runners source this for common functionality

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"
source "${PROJECT_ROOT}/scripts/lib/godot_runtime_env.sh"
APPLICATION_NAME="${APPLICATION_NAME:-SpaceWheat - Quantum Farm}"

LOG_ROOT="${PROJECT_ROOT}/logs"

prepare_godot_user_dir() {
	local xdg_root="${XDG_ROOT:-${PROJECT_ROOT}/.godot}"
	export XDG_DATA_HOME="${XDG_DATA_HOME:-${xdg_root}}"
	export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${xdg_root}}"
	export APPLICATION_NAME
	export GODOT_USER_DIR="${GODOT_USER_DIR:-${XDG_DATA_HOME}/godot/app_userdata/${APPLICATION_NAME}}"
	mkdir -p "${GODOT_USER_DIR}/logs" "${GODOT_USER_DIR}/rig" "${GODOT_USER_DIR}/saves"
}

sanitize_log_name() {
	local name="$1"
	local normalized
	normalized=$(printf "%s" "$name" | tr '[:upper:]' '[:lower:]' | \
		sed -E 's/[^a-z0-9]+/_/g' | sed -E 's/^_+//;s/_+$//')
	printf "%s" "$normalized"
}

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# EMOJI ATLAS VALIDATION
# =============================================================================

# Capture and analyze emoji atlas building during test
validate_emoji_atlas() {
    local test_output="$1"
    local test_name="${2:-Test}"

    echo ""
    echo -e "${BLUE}=== 🎨 EMOJI ATLAS VERIFICATION ===${NC}"

    # Check if atlas was built
    if echo "$test_output" | grep -q "Atlas built.*emojis"; then
        local atlas_line=$(echo "$test_output" | grep "Atlas built")
        echo -e "${GREEN}✓ Atlas building: $atlas_line${NC}"

        # Extract emoji count
        local emoji_count=$(echo "$atlas_line" | grep -oP '\d+(?= emojis)')
        if [ -z "$emoji_count" ]; then
            emoji_count=$(echo "$atlas_line" | grep -oP '\(\d+' | grep -oP '\d+')
        fi

        if [ ! -z "$emoji_count" ]; then
            echo -e "${GREEN}✓ Emojis in atlas: $emoji_count${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ No atlas building detected${NC}"
    fi

    # Check if GPU batching is being used
    if echo "$test_output" | grep -q "Using pre-built emoji atlas"; then
        echo -e "${GREEN}✓ GPU batching ENABLED - emoji atlas in use${NC}"
    elif echo "$test_output" | grep -q "emoji atlas"; then
        echo -e "${YELLOW}⚠ Atlas mentioned but GPU batching status unclear${NC}"
    else
        echo -e "${YELLOW}⚠ GPU batching status unknown${NC}"
    fi

    # Check for missing emoji warnings (bad sign)
    local missing_count=$(echo "$test_output" | grep -c "Missing emoji:" 2>/dev/null || echo "0")
    missing_count=$(echo "$missing_count" | tr -d ' \t\n')  # Strip whitespace
    if [ ! -z "$missing_count" ] && [ "$missing_count" -gt 0 ] 2>/dev/null; then
        echo -e "${RED}✗ Missing emoji warnings detected: $missing_count${NC}"
    else
        echo -e "${GREEN}✓ No missing emoji warnings${NC}"
    fi

    echo ""
}

# =============================================================================
# TEST RUNNER UTILITIES
# =============================================================================

# Generic test runner with output logging and analysis
run_test_with_log() {
    local scene_path="$1"
    local timeout_secs="${2:-20}"
    local test_name="${3:-Test}"
    local headless="${4:-false}"

    echo "$test_name"
    echo "==========================="

    # Create timestamped log file
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local slug
    slug=$(sanitize_log_name "$test_name")
    if [ -z "$slug" ]; then
        slug="test"
    fi
    local log_dir="${LOG_ROOT}/visual_bubble"
    mkdir -p "$log_dir"
    local log_file="${log_dir}/${slug}_${timestamp}.log"

    echo "Running test for ${timeout_secs} seconds..."
    echo "Output will be saved to: $log_file"
    echo ""

    prepare_godot_user_dir
    if [ "$headless" = "true" ]; then
        sw_prepare_runtime_env "headless"
    else
        sw_prepare_runtime_env "interactive"
    fi

    # Build godot command
    local godot_cmd=(sw_godot)
    if [ "$headless" = "true" ]; then
        godot_cmd+=(--headless)
    fi
    godot_cmd+=(--scene "$scene_path")

    # Run test and tee to both console and log
    timeout "$timeout_secs" "${godot_cmd[@]}" 2>&1 | tee "$log_file"
    local exit_code=${PIPESTATUS[0]}

    # Analyze results
    echo ""
    echo "================================================================"
    if [ $exit_code -eq 124 ]; then
        echo -e "${GREEN}✅ Test completed (timeout after ${timeout_secs}s)${NC}"
    elif [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✅ Test completed successfully${NC}"
    else
        echo -e "${YELLOW}⚠️  Test exited with code: $exit_code${NC}"
    fi
    echo "📝 Full log saved to: $log_file"
    echo "================================================================"
    echo ""

    # Read log file for analysis
    local output=$(cat "$log_file")

    # Validate emoji atlas
    validate_emoji_atlas "$output" "$test_name"

    # Verify GPU offload
    verify_gpu_offload "$output" "$headless"

    return $exit_code
}

# Run a Godot test scene with timeout (uses the generic runner)
run_test_scene() {
    local scene_path="$1"
    local timeout_secs="${2:-20}"
    local test_name="${3:-Test}"

    run_test_with_log "$scene_path" "$timeout_secs" "$test_name" "false"
}

# =============================================================================
# CPU/GPU OFFLOAD VERIFICATION
# =============================================================================

# Check if emoji rendering is GPU-accelerated
verify_gpu_offload() {
    local test_output="$1"
    local headless_mode="${2:-false}"

    echo ""
    echo -e "${BLUE}=== 💻 GPU OFFLOAD ANALYSIS ===${NC}"

    if echo "$test_output" | grep -Eiq "llvmpipe|lavapipe|swiftshader|software rendering detected"; then
        echo -e "${YELLOW}ℹ Software renderer detected; GPU claims are non-representative${NC}"
    fi
    if [ "$headless_mode" = "true" ]; then
        echo -e "${YELLOW}ℹ Headless mode: render-path FPS/GPU claims are not authoritative${NC}"
    fi

    # Check for GPU-accelerated bubble rendering (atlas priority)
    # With new optimization: Native C++ not instantiated when using atlas
    if echo "$test_output" | grep -q "Using pre-built bubble atlas"; then
        echo -e "${GREEN}✓ Bubble rendering: GPU-accelerated (atlas, C++ bypassed)${NC}"
    elif echo "$test_output" | grep -q "Native renderer available"; then
        echo -e "${GREEN}✓ Bubble rendering: GPU-accelerated (native C++)${NC}"
    else
        echo -e "${YELLOW}⚠ Bubble rendering: script-side path${NC}"
    fi

    # Check for batched emoji rendering
    if echo "$test_output" | grep -q "Using pre-built emoji atlas"; then
        echo -e "${GREEN}✓ Emoji rendering: GPU batched (1 draw call)${NC}"
    else
        echo -e "${YELLOW}⚠ Emoji rendering: Individual/fallback path${NC}"
    fi

    if [ "$headless_mode" = "true" ]; then
        echo -e "${BLUE}ℹ Headless mode validates the live project runtime, not the archived compute-selector lane${NC}"
    fi

    echo ""
}

export -f validate_emoji_atlas
export -f run_test_with_log
export -f run_test_scene
export -f verify_gpu_offload
export -f prepare_godot_user_dir
