#!/bin/bash
# 🔬 Quantum Composer Test Suite — Full quantum physics verification
#
# Runs all quantum verification test suites:
#   1. Gate verification (102 tests)     — every gate against known states
#   2. Entanglement verification (82)    — Bell, GHZ, MI, collapse
#   3. Measurement verification (52)     — projection, Born rule, collapse
#   4. Biome quantum coverage (16)       — exportable biomes valid
#
# Usage:
#   bash 🍄/🧪/🔬.sh [--verbose] [--suite NAME]
#
# Examples:
#   bash 🍄/🧪/🔬.sh                     # Run all suites
#   bash 🍄/🧪/🔬.sh --suite gates       # Just gate tests
#   bash 🍄/🧪/🔬.sh --suite entangle    # Just entanglement tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

VERBOSE=false
SUITE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --verbose) VERBOSE=true; shift ;;
        --suite) SUITE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ── Colors ──────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ── Suite definitions ───────────────────────────────────────────────────
declare -A SUITES
SUITES[gates]="Tests/test_quantum_gate_verification.gd"
SUITES[entangle]="Tests/test_quantum_entanglement_verification.gd"
SUITES[measure]="Tests/test_quantum_measurement_verification.gd"
SUITES[biomes]="Tests/test_biome_quantum_coverage.gd"

SUITE_ORDER=(gates entangle measure biomes)

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          🔬 QUANTUM COMPOSER TEST RUNNER                   ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SUITES=0
FAILED_SUITES=()

run_suite() {
    local name="$1"
    local script="${SUITES[$name]}"

    if [ ! -f "$script" ]; then
        echo -e "${RED}❌ Suite '$name': script not found: $script${NC}"
        FAILED_SUITES+=("$name")
        return 1
    fi

    echo -e "${BLUE}── Running: $name ──${NC}"
    TOTAL_SUITES=$((TOTAL_SUITES + 1))

    local output
    output=$(timeout 60 godot --headless --script "$script" 2>&1)
    local exit_code=$?

    # Extract results line
    local results_line
    results_line=$(echo "$output" | grep "📊 Results:" | tail -1)

    if [ -z "$results_line" ]; then
        echo -e "${RED}❌ $name: No results line found${NC}"
        if $VERBOSE; then
            echo "$output"
        fi
        FAILED_SUITES+=("$name")
        return 1
    fi

    # Parse pass/fail counts
    local passed failed
    passed=$(echo "$results_line" | grep -oP '\d+(?=/\d+ passed)')
    failed=$(echo "$results_line" | grep -oP '\d+ failed' | grep -oP '\d+')

    if [ -z "$passed" ]; then passed=0; fi
    if [ -z "$failed" ]; then failed=0; fi

    TOTAL_PASS=$((TOTAL_PASS + passed))
    TOTAL_FAIL=$((TOTAL_FAIL + failed))

    if [ "$failed" -eq 0 ]; then
        echo -e "  ${GREEN}✅ $name: $passed passed${NC}"
    else
        echo -e "  ${RED}❌ $name: $passed passed, $failed FAILED${NC}"
        FAILED_SUITES+=("$name")
        if $VERBOSE; then
            echo "$output" | grep "❌"
        fi
    fi

    return 0
}

# ── Run suites ──────────────────────────────────────────────────────────

if [ -n "$SUITE" ]; then
    if [ -z "${SUITES[$SUITE]}" ]; then
        echo -e "${RED}Unknown suite: $SUITE${NC}"
        echo "Available: ${SUITE_ORDER[*]}"
        exit 1
    fi
    run_suite "$SUITE"
else
    for suite_name in "${SUITE_ORDER[@]}"; do
        run_suite "$suite_name"
    done
fi

# ── Summary ─────────────────────────────────────────────────────────────

echo ""
echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
echo -e "  📊 Total: $TOTAL_PASS passed, $TOTAL_FAIL failed across $TOTAL_SUITES suites"

if [ ${#FAILED_SUITES[@]} -eq 0 ]; then
    echo -e "  ${GREEN}✅ ALL QUANTUM TESTS PASSED${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
    exit 0
else
    echo -e "  ${RED}❌ Failed suites: ${FAILED_SUITES[*]}${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
    exit 1
fi
