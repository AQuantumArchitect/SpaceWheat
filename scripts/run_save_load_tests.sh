#!/bin/bash

## Save/Load Test Suite Runner
## Runs modular save/load tests and collects results

set -e

GODOT="${GODOT_PATH:-godot}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
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
if timeout 90 "$GODOT" --headless --log-file "$RESULTS_DIR/godot_boot.log" -s "$PROJECT_DIR/tests/test_boot_tree.gd" &> "$RESULTS_DIR/boot_test.log"; then
	echo -e "${GREEN}✓ Boot test passed${NC}"
	BOOT_PASS=true
else
	echo -e "${RED}✗ Boot test failed${NC}"
	BOOT_PASS=false
	echo "  Log:"
	tail -20 "$RESULTS_DIR/boot_test.log" | sed 's/^/    /'
fi
echo ""

# Test 2: Strict Scenario/Save Boot State
echo -e "${BLUE}▶ Test 2: Strict Boot State${NC}"
echo "  Testing that boot refuses missing or invalid scenario biome state..."
if timeout 90 "$GODOT" --headless --log-file "$RESULTS_DIR/godot_strict_boot.log" -s "$PROJECT_DIR/tests/test_strict_boot_state.gd" &> "$RESULTS_DIR/strict_boot_test.log"; then
	echo -e "${GREEN}✓ Strict boot state test passed${NC}"
	STRICT_PASS=true
else
	echo -e "${RED}✗ Strict boot state test failed${NC}"
	STRICT_PASS=false
	echo "  Log:"
	tail -20 "$RESULTS_DIR/strict_boot_test.log" | sed 's/^/    /'
fi
echo ""

# Test 3: Game Loop Validation
echo -e "${BLUE}▶ Test 3: Game Loop Validation${NC}"
echo "  Testing plant → advance → measure → harvest cycle..."
if [ ! -f "$PROJECT_DIR/tests/test_game_loop_validation.gd" ]; then
	echo -e "${YELLOW}⚠ Game loop test skipped (missing tests/test_game_loop_validation.gd)${NC}"
	LOOP_PASS=skip
elif timeout 60 "$GODOT" --headless --log-file "$RESULTS_DIR/godot_game_loop.log" -s "$PROJECT_DIR/tests/test_game_loop_validation.gd" &> "$RESULTS_DIR/game_loop_test.log"; then
	echo -e "${GREEN}✓ Game loop test passed${NC}"
	LOOP_PASS=true
else
	echo -e "${RED}✗ Game loop test failed${NC}"
	LOOP_PASS=false
	echo "  Log:"
	tail -20 "$RESULTS_DIR/game_loop_test.log" | sed 's/^/    /'
fi
echo ""

# Test 4: Complete Save/Load Cycle
echo -e "${BLUE}▶ Test 4: Complete Save/Load Cycle${NC}"
echo "  Testing: boot → setup → save → new game → load → verify..."
if [ ! -f "$PROJECT_DIR/test_runner_save_load.gd" ]; then
	echo -e "${YELLOW}⚠ Save/load test skipped (missing test_runner_save_load.gd)${NC}"
	SAVELOAD_PASS=skip
elif timeout 120 "$GODOT" --headless --log-file "$RESULTS_DIR/godot_save_load.log" -s "$PROJECT_DIR/test_runner_save_load.gd" &> "$RESULTS_DIR/save_load_test.log"; then
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
echo -e "Strict Boot:     $([ "$STRICT_PASS" = true ] && echo -e "${GREEN}✓ PASS${NC}" || echo -e "${RED}✗ FAIL${NC}")"
echo -e "Game Loop Test:  $([ "$LOOP_PASS" = true ] && echo -e "${GREEN}✓ PASS${NC}" || ([ "$LOOP_PASS" = skip ] && echo -e "${YELLOW}⚠ SKIP${NC}" || echo -e "${RED}✗ FAIL${NC}"))"
echo -e "Save/Load Test:  $([ "$SAVELOAD_PASS" = true ] && echo -e "${GREEN}✓ PASS${NC}" || ([ "$SAVELOAD_PASS" = skip ] && echo -e "${YELLOW}⚠ SKIP${NC}" || echo -e "${RED}✗ FAIL${NC}"))"
echo ""

if [ "$BOOT_PASS" = true ] && [ "$STRICT_PASS" = true ] && { [ "$LOOP_PASS" = true ] || [ "$LOOP_PASS" = skip ]; } && { [ "$SAVELOAD_PASS" = true ] || [ "$SAVELOAD_PASS" = skip ]; }; then
	echo -e "${GREEN}✅ TEST SUITE COMPLETE${NC}"
	echo ""
	echo "📁 Test artifacts:"
	echo "  - Boot test log:     $RESULTS_DIR/boot_test.log"
	echo "  - Strict boot log:   $RESULTS_DIR/strict_boot_test.log"
	echo "  - Game loop log:     $RESULTS_DIR/game_loop_test.log"
	echo "  - Save/load log:     $RESULTS_DIR/save_load_test.log"
	echo ""
	exit 0
else
	echo -e "${RED}❌ SOME TESTS FAILED${NC}"
	echo ""
	echo "📁 Test artifacts:"
	echo "  - Boot test log:     $RESULTS_DIR/boot_test.log"
	echo "  - Strict boot log:   $RESULTS_DIR/strict_boot_test.log"
	echo "  - Game loop log:     $RESULTS_DIR/game_loop_test.log"
	echo "  - Save/load log:     $RESULTS_DIR/save_load_test.log"
	echo ""
	exit 1
fi
