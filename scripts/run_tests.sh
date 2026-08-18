#!/bin/bash
# run_tests.sh — headless GDScript smoke-test runner for SpaceWheat.
#
# Runs every green SceneTree smoke test under tests/ so they can't rot
# silently outside a runner again (facade_parity/principal_mode/
# story_icon_cutover were dead for months before 68ebd80e resurrected them).
#
# Godot resolution goes through the canonical scripts/lib/godot_runtime_env.sh
# resolver, so GODOT_BIN / SW_GODOT_BIN are honored (slop-patrol Tier 5 #24).
# Save/load boot tests live in scripts/run_save_load_tests.sh.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/lib/godot_runtime_env.sh"

GODOT="$(sw_godot_bin)"
if ! command -v "$GODOT" &> /dev/null; then
    # Legacy fallback from the pre-lib version of this script.
    if command -v godot4 &> /dev/null; then
        GODOT="godot4"
    else
        echo "❌ Godot not found: $GODOT"
        echo "Install Godot 4.3+, add it to PATH, or set GODOT_BIN."
        exit 1
    fi
fi

echo "======================================="
echo "SpaceWheat headless smoke tests"
echo "======================================="
echo "Godot: $GODOT ($($GODOT --version 2>&1 | head -1))"
echo ""

# Every entry runs as: godot --headless --path . -s tests/<name>.gd
# and reports via exit code (tests/smoke_test_base.gd convention, or the
# fail-fast quit(1) style used by facade_parity/principal_mode).
SMOKE_TESTS=(
    facade_parity
    principal_mode
    story_icon_cutover_smoke
    biome_registry_load_shape
    chatter_liveliness_smoke
    ending_overlay_smoke
    escape_menu_run_smoke
    quest_board_paging_smoke
    test_glossary_registry
    objective_blackout_smoke
    story_atlas_smoke
    predicate_target_smoke
    spectral_preview_smoke
    plant_continuity_probe
    faction_icon_adoption_smoke
    registry_shared_mutator_smoke
    semantica_explorer_load_proof
    sun_qubit_renderer_smoke
    tool_config_strict_frame_smoke
    test_icon_relations
    test_faction_signature_gate
    test_complex_matrix_empty_serialization
    test_closed_system
    test_advanced_quantum_states
    test_gate_exact_states
    test_gate_application_integration
    test_2q_gate_embed
    test_drain_qubit
    test_evolve_parity
    test_degenerate_rho
    test_hermitian_eigen_path
    test_witness_field
    test_submenu_dry
    test_submenu_integration
    bare_biome_realization_smoke
    bubble_rendering_cleanup_smoke
    save_floor_smoke
    test_cn_handoff_runtime
    test_v_surface_runtime
    test_m_surface_runtime
    test_surface_headless_smoke
    test_vantage_strike
    batcher_budget_smoke
    native_async_methods_smoke
    native_async_compute_smoke
    native_async_lane_smoke
    loop_card_smoke
    hint_toast_lifecycle_smoke
    menu_row_progression_smoke
    arc_tab_verbs_smoke
    gate_ledger_smoke
)
# Known-red / not wired: NONE (2026-08-03 fable push — the #429 leftovers all
# closed: m_surface's phantom KEY_2 sort chord replaced with the real
# pinned-faction derivation; surface_headless_smoke's hang was one bare
# IconRegistry identifier in BiomeInspectorOverlay (fixed, plus a watchdog so
# an uncaught error can never hang the runner again); vantage_strike rewritten
# to the live explore-first contract from a933613d). If a test goes red, fix or
# document it here — never drop it from the array silently.

FAILED_TESTS=()
for name in "${SMOKE_TESTS[@]}"; do
    printf '%-45s' "tests/${name}.gd"
    if timeout 180 "$GODOT" --headless --path "$PROJECT_DIR" -s "tests/${name}.gd" > /tmp/sw_run_tests_last.log 2>&1; then
        echo "PASS"
    else
        echo "FAIL"
        FAILED_TESTS+=("$name")
        tail -20 /tmp/sw_run_tests_last.log | sed 's/^/    /'
    fi
done

echo ""
echo "======================================="
if [ "${#FAILED_TESTS[@]}" -eq 0 ]; then
    echo "All ${#SMOKE_TESTS[@]} smoke tests passed."
    exit 0
fi
echo "${#FAILED_TESTS[@]} of ${#SMOKE_TESTS[@]} smoke tests FAILED:"
printf '  %s\n' "${FAILED_TESTS[@]}"
exit 1
