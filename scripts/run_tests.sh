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
)
# Known-red / not wired (2026-08-03, #429 slop pass) — fix before adding, don't
# delete silently:
#   test_m_surface_runtime  — the "visible" parse-error rot is FIXED (23/24
#     pass now); one genuine pre-existing gap remains: pressing "2" on the
#     Eigenstate frame is expected to flip eigen_sort_mode to "Subject" (a
#     faction-pin chord) but UI/Overlays/MapMetaOverlay.gd never wires KEY_2
#     to anything — eigen_sort_mode is derived solely from whether a faction
#     is already pinned (line ~1696). Either the chord was never implemented
#     or was removed; needs an owner call on the intended key, not a rename.
#   test_surface_headless_smoke — NOT a deadlock: at line 156
#     `BiomeInspectorOverlay.new()` throws "Nonexistent function 'new' in
#     base 'GDScript'" (i.e. BiomeInspectorOverlay.gd itself fails to
#     compile in this specific headless SceneTree-script timing — a
#     standalone `--check-only` on that file reports "Identifier not found:
#     IconRegistry" even though IconRegistry is a registered autoload
#     (project.godot:28) that resolves fine in normal gameplay boot). The
#     script's error handling doesn't call quit()/_finish() on this failure,
#     so BiomeBase._process's "unclaimed" warning then repeats forever —
#     that's the "hang". Root cause is autoload-vs-script-compile ordering
#     in the `-s script.gd` harness, not the warning loop itself; needs
#     someone who can reproduce Godot's exact autoload init timing to fix
#     correctly, not a guess.

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
