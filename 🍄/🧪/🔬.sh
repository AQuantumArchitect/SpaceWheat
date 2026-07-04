#!/bin/bash
# 🔬 Quantum Composer Test Suite — Full quantum physics verification
#
# Runs the quantum verification test suites (same set as run_quantum_gate_tests.sh):
#   1. gates       (29 tests) — exact density-matrix elements after each gate
#   2. advanced    (28 tests) — advanced quantum state preparation
#   3. integration (22 tests) — gate application through the real biome pipeline
#   4. embed       (63 tests) — 2-qubit gate embedding (CNOT/CZ/SWAP orderings)
#   5. drain       (18 tests) — weak-measurement drain invariants (trace, purity, T2)
#
# Usage:
#   bash 🍄/🧪/🔬.sh [--verbose] [--suite NAME]
#
# Examples:
#   bash 🍄/🧪/🔬.sh                     # Run all suites
#   bash 🍄/🧪/🔬.sh --suite gates       # Just exact-state gate tests
#   bash 🍄/🧪/🔬.sh --suite embed       # Just 2-qubit embedding tests

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
SUITES[gates]="tests/test_gate_exact_states.gd"
SUITES[advanced]="tests/test_advanced_quantum_states.gd"
SUITES[integration]="tests/test_gate_application_integration.gd"
SUITES[embed]="tests/test_2q_gate_embed.gd"
SUITES[drain]="tests/test_drain_qubit.gd"

SUITE_ORDER=(gates advanced integration embed drain)

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
    # `|| true`: a failing suite must not abort the runner (set -e) before the summary
    output=$(timeout 60 godot --headless --script "$script" 2>&1 || true)

    # Extract results line — suites print "RESULTS: N passed, M failed"
    local results_line
    results_line=$(echo "$output" | grep "RESULTS:" | tail -1)

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
    passed=$(echo "$results_line" | grep -oP '\d+(?= passed)')
    failed=$(echo "$results_line" | grep -oP '\d+(?= failed)')

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
