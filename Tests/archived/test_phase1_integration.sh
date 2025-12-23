#!/bin/bash

##############################################################################
## PHASE 1 INTEGRATION TEST - Biome System
## Tests the Biome, Icon Hamiltonians, and Dissipation Integration
##############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_SCENE="res://Tests/test_phase1_biome.gd"

echo "=========================================="
echo "🧪 PHASE 1 INTEGRATION TEST SUITE"
echo "=========================================="
echo ""
echo "Project Root: $PROJECT_ROOT"
echo "Test Scene: $TEST_SCENE"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check test output
check_test_output() {
    local output_file="$1"
    local test_name="$2"

    # Check for critical test markers
    if grep -q "🎉 ALL TESTS PASSED!" "$output_file"; then
        echo -e "${GREEN}✅ ALL TESTS PASSED${NC}"
        return 0
    elif grep -q "❌ FAIL" "$output_file"; then
        echo -e "${RED}❌ TESTS FAILED${NC}"
        echo ""
        echo "Failed tests:"
        grep "❌ FAIL" "$output_file" || true
        return 1
    elif grep -q "Error" "$output_file" || grep -q "error" "$output_file"; then
        echo -e "${RED}❌ ERRORS DETECTED${NC}"
        grep -i "error" "$output_file" | head -20 || true
        return 1
    else
        echo -e "${YELLOW}⚠️  UNKNOWN TEST STATUS${NC}"
        return 1
    fi
}

# Run the Biome test
echo "Running Biome System Tests..."
echo ""

TEMP_OUTPUT="/tmp/phase1_test_output.txt"

# Run godot headless with the test scene
timeout 30 godot --headless --script "$SCRIPT_DIR/test_phase1_biome.gd" > "$TEMP_OUTPUT" 2>&1 || {
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 124 ]; then
        echo -e "${YELLOW}⚠️  Test timeout (30s)${NC}"
    else
        echo -e "${RED}❌ Godot execution failed (exit code: $EXIT_CODE)${NC}"
    fi
    echo ""
    echo "Output:"
    cat "$TEMP_OUTPUT"
    exit 1
}

# Display the output
echo "Test Output:"
echo "---"
cat "$TEMP_OUTPUT"
echo "---"
echo ""

# Analyze results
if check_test_output "$TEMP_OUTPUT" "Biome Tests"; then
    echo ""
    echo "=========================================="
    echo -e "${GREEN}✅ PHASE 1 TESTS PASSED${NC}"
    echo "=========================================="
    exit 0
else
    echo ""
    echo "=========================================="
    echo -e "${RED}❌ PHASE 1 TESTS FAILED${NC}"
    echo "=========================================="
    exit 1
fi
