from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def _read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def test_milk_hunt_paths_allocates_private_lane_root() -> None:
    src = _read("🍄/🎛️/milk_hunt_paths.py")
    assert "_DEFAULT_XDG_BASE = \"/tmp/sw_godot_milk_hunt\"" in src
    assert "def _lane_token()" in src
    assert 'os.environ["SW_RIG_LANE"] = token' in src
    assert 'os.environ["XDG_ROOT"] = str(private_root)' in src
    assert "def lane_env(" in src


def test_run_executor_is_shared_lane_aware_execution_core() -> None:
    src = _read("🍄/🎛️/run_executor.py")
    assert "class RigLane" in src
    assert "def ensure_lane(" in src
    assert "def run_cli(" in src
    assert "def run_runner(" in src
    assert "def run_seed(" in src
    assert "def run_batch(" in src


def test_snapshot_service_owns_ui_snapshot_registry() -> None:
    src = _read("Core/Instrumentation/SnapshotService.gd")
    assert "func get_overlay_snapshot(" in src
    assert "func get_widget_snapshot(" in src
    assert "func get_hud_snapshot(" in src
    assert "func get_full_ui_snapshot(" in src
    assert "func build_policy_state_lightweight(" in src


def test_rig_listener_is_thinner_and_uses_player_input_macro_runner() -> None:
    src = _read("Tests/rig_listener.gd")
    assert 'const PlayerInputMacroRunner = preload("res://UI/Core/PlayerInputMacroRunner.gd")' in src
    assert "_ensure_player_input_macro_runner()" in src
    assert "return await runner.execute(decision)" in src
    assert "func _resolve_widget(" not in src
    assert "func _resolve_hud(" not in src


def test_player_input_macro_runner_exists_next_to_ui_input_layer() -> None:
    src = _read("UI/Core/PlayerInputMacroRunner.gd")
    assert "class_name PlayerInputMacroRunner" in src
    assert "func execute(decision: Dictionary) -> Dictionary:" in src
    assert 'return _direct_fallback(decision)' in src


def test_runner_summary_surface_is_extracted_into_helper_module() -> None:
    helper = _read("🍄/🎛️/milk_hunt_summary.py")
    runner = _read("🍄/🎛️/milk_hunt_runner.py")
    assert "def policy_action_breakdown(" in helper
    assert "def build_common_summary_fields(" in helper
    assert "def apply_profile_metrics(" in helper
    assert "def add_milk_pair_index(" in helper
    assert "from milk_hunt_summary import (" in runner
    assert "build_common_summary_fields(" in runner
    assert "policy_action_breakdown(" in runner
    assert "apply_profile_metrics(summary, profile_metrics, len(final_pairs))" in runner


def test_policy_weights_terms_are_removed_from_mushroom_layer() -> None:
    profiles = _read("🍄/🎛️/profiles.py")
    arena = _read("🍄/🎛️/arena.py")
    assert "POLICY_WEIGHTS_DIR" not in profiles
    assert "def load_policy_weights(" not in profiles
    assert "load_policy_weights" not in arena
