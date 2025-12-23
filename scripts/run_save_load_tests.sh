#!/bin/bash

## Save/Load Test Suite Runner
## Runs modular save/load tests and collects results

set -e

GODOT="${GODOT_PATH:-godot}"
PROJECT_DIR="/home/tehcr33d/ws/SpaceWheat"
RESULTS_DIR="$PROJECT_DIR/test_results"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create results directory
mkdir -p "$RESULTS_DIR"

echo ""
echo "=========================================="
echo "🧪 SPACEWHEAT SAVE/LOAD TEST SUITE"
echo "=========================================="
echo ""

# Test 1: Quick Boot
echo -e "${BLUE}▶ Test 1: Quick Boot${NC}"
echo "  Testing game initialization and core systems..."
if timeout 30 "$GODOT" --headless -s "$PROJECT_DIR/tests/test_quick_boot.gd" &> "$RESULTS_DIR/boot_test.log"; then
	echo -e "${GREEN}✓ Boot test passed${NC}"
	BOOT_PASS=true
else
	echo -e "${RED}✗ Boot test failed${NC}"
	BOOT_PASS=false
	echo "  Log:"
	tail -20 "$RESULTS_DIR/boot_test.log" | sed 's/^/    /'
fi
echo ""

# Test 2: Game Loop Validation
echo -e "${BLUE}▶ Test 2: Game Loop Validation${NC}"
echo "  Testing plant → advance → measure → harvest cycle..."
if timeout 60 "$GODOT" --headless -s "$PROJECT_DIR/tests/test_game_loop_validation.gd" &> "$RESULTS_DIR/game_loop_test.log"; then
	echo -e "${GREEN}✓ Game loop test passed${NC}"
	LOOP_PASS=true
else
	echo -e "${RED}✗ Game loop test failed${NC}"
	LOOP_PASS=false
	echo "  Log:"
	tail -20 "$RESULTS_DIR/game_loop_test.log" | sed 's/^/    /'
fi
echo ""

# Test 3: Complete Save/Load Cycle
echo -e "${BLUE}▶ Test 3: Complete Save/Load Cycle${NC}"
echo "  Testing: boot → setup → save → new game → load → verify..."
if timeout 120 "$GODOT" --headless -s "$PROJECT_DIR/test_runner_save_load.gd" &> "$RESULTS_DIR/save_load_test.log"; then
	echo -e "${GREEN}✓ Save/load test passed${NC}"
	SAVELOAD_PASS=true
else
	echo -e "${RED}✗ Save/load test failed${NC}"
	SAVELOAD_PASS=false
	echo "  Log:"
	tail -30 "$RESULTS_DIR/save_load_test.log" | sed 's/^/    /'
fi
echo ""

# Summary
echo "=========================================="
echo "📊 TEST SUMMARY"
echo "=========================================="
echo -e "Boot Test:       $([ "$BOOT_PASS" = true ] && echo -e "${GREEN}✓ PASS${NC}" || echo -e "${RED}✗ FAIL${NC}")"
echo -e "Game Loop Test:  $([ "$LOOP_PASS" = true ] && echo -e "${GREEN}✓ PASS${NC}" || echo -e "${RED}✗ FAIL${NC}")"
echo -e "Save/Load Test:  $([ "$SAVELOAD_PASS" = true ] && echo -e "${GREEN}✓ PASS${NC}" || echo -e "${RED}✗ FAIL${NC}")"
echo ""

if [ "$BOOT_PASS" = true ] && [ "$LOOP_PASS" = true ] && [ "$SAVELOAD_PASS" = true ]; then
	echo -e "${GREEN}✅ ALL TESTS PASSED${NC}"
	echo ""
	echo "📁 Test artifacts:"
	echo "  - Boot test log:     $RESULTS_DIR/boot_test.log"
	echo "  - Game loop log:     $RESULTS_DIR/game_loop_test.log"
	echo "  - Save/load log:     $RESULTS_DIR/save_load_test.log"
	echo ""
	exit 0
else
	echo -e "${RED}❌ SOME TESTS FAILED${NC}"
	echo ""
	echo "📁 Test artifacts:"
	echo "  - Boot test log:     $RESULTS_DIR/boot_test.log"
	echo "  - Game loop log:     $RESULTS_DIR/game_loop_test.log"
	echo "  - Save/load log:     $RESULTS_DIR/save_load_test.log"
	echo ""
	exit 1
fi
