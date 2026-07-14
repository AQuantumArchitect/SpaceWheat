"""The Witness (Core/Witness) — surface contracts.

1. PARITY LINT (the law made mechanical, umwelt's vocabulary-lint move):
   the Witness's sensor membrane may only touch player-visible SIGNALS.
   Core/Witness source must never reference ground-truth quantum reads —
   if a banned token appears, the fog-of-war membrane has a hole.
2. BOOT LANES: WitnessBridge must rewire off GameStateManager.farm_ready,
   which is emitted on BOTH the full-boot lane (complete_session_boot) and
   the path-load lane (_apply_loaded_state_deferred, fix 32fc633e). Four
   prior P0s came from organs wired on only one lane.
3. ANTI-GATING: nothing outside Core/Witness + the projection consumers
   (rig listener, serializer) may READ the Witness — it is advisory, never
   an input to mechanics.
4. The GDScript physics battery (weak observe / dissipative law / gauge /
   serialize / graph schema) runs headless as part of this suite.
"""
import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
WITNESS_DIR = PROJECT_ROOT / "Core" / "Witness"

# Ground-truth reads the membrane must never make. Player-visible metadata
# (plot measurement memory, plot→biome assignments, wallet events) is legal;
# live ρ, viz caches, and biome quantum internals are not.
BANNED_IN_WITNESS = {
    "get_density_matrix": "live ρ read — the Witness must not see ground truth",
    "export_bloch_packet": "per-qubit ground-truth Bloch read",
    "QuantumVizCache": "renderer cache — not a player surface",
    "viz_cache": "renderer cache — not a player surface",
    "quantum_computer": "biome quantum internals",
    "get_all_populations": "ground-truth populations",
    "get_cached_mutual_information": "ground-truth MI",
    "MultiBiomeLookaheadEngine": "game lookahead — forecasts must roll the BELIEF field only",
    "time_skip": "dev verb, not a player observation",
}


def _witness_sources() -> dict:
    return {p.name: p.read_text(encoding="utf-8")
            for p in sorted(WITNESS_DIR.glob("*.gd"))}


def test_witness_membrane_reads_no_ground_truth() -> None:
    sources = _witness_sources()
    assert sources, "Core/Witness has no GDScript sources?"
    holes = []
    for fname, src in sources.items():
        for token, why in BANNED_IN_WITNESS.items():
            if token in src:
                holes.append(f"{fname}: {token} ({why})")
    assert not holes, (
        "Parity hole(s) in the Witness membrane — it may only consume "
        "player-visible signals:\n  " + "\n  ".join(holes)
    )


def test_witness_bridge_wired_on_farm_ready() -> None:
    bridge = (WITNESS_DIR / "WitnessBridge.gd").read_text(encoding="utf-8")
    assert "farm_ready.connect" in bridge, (
        "WitnessBridge must subscribe to GameStateManager.farm_ready"
    )
    assert "farm == _farm" in bridge, (
        "WitnessBridge must rewire on EVERY new farm (PlayerEventBridge "
        "pattern), not one-shot"
    )
    # farm_ready itself must keep firing on both lanes — the path-load lane
    # emit is fix 32fc633e in GameStateManager._apply_loaded_state_deferred.
    gsm = (PROJECT_ROOT / "Core" / "GameState" / "GameStateManager.gd").read_text(encoding="utf-8")
    deferred = gsm.split("func _apply_loaded_state_deferred", 1)[1].split("\nfunc ", 1)[0]
    assert "farm_ready.emit" in deferred, (
        "GameStateManager._apply_loaded_state_deferred no longer emits "
        "farm_ready — the path-load lane would leave the Witness (and every "
        "other farm_ready listener) bound to the previous farm"
    )


def test_witness_is_advisory_never_read_by_mechanics() -> None:
    # The only files allowed to READ WitnessOrgan are its own organ dir, the
    # projection transports (rig listener, player seat), the serializer
    # (persistence), project.godot (autoload), and tests/probes.
    allowed_parents = {"Witness", "🎛️", "🧪", "tests"}
    allowed_names = {"project.godot", "GameStateSerializer.gd"}
    offenders = []
    for root in ("Core", "UI", "scenes"):
        for p in (PROJECT_ROOT / root).rglob("*.gd"):
            if p.parent.name in allowed_parents or p.name in allowed_names:
                continue
            if "WitnessOrgan" in p.read_text(encoding="utf-8"):
                offenders.append(str(p.relative_to(PROJECT_ROOT)))
    assert not offenders, (
        "The Witness is ADVISORY (anti-gating law): these files read it "
        "from mechanics/UI code:\n  " + "\n  ".join(offenders)
    )


def test_witness_field_physics_battery() -> None:
    # The GDScript battery: weak-observe theorems, dissipative-role law,
    # spec validation, gauge diff-stability, serialize round-trip, graph v1.
    result = subprocess.run(
        ["godot", "--headless", "--script", "tests/test_witness_field.gd"],
        cwd=PROJECT_ROOT, capture_output=True, text=True, timeout=180,
    )
    tail = (result.stdout + result.stderr)[-2000:]
    assert result.returncode == 0, f"witness field battery failed:\n{tail}"
    assert "0 failed" in result.stdout, f"witness field battery reported failures:\n{tail}"
