from conftest import ROOT, read_source as _read


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
    assert "func get_policy_snapshot(" in src
    assert "func open_icon_panel(" in src
    assert "func build_policy_state(" not in src
    assert "func build_policy_state_lightweight(" not in src
    assert "func open_semantic_map_panel(" not in src
    assert "func open_vocabulary_panel(" not in src
    assert '"quest_board"' in src
    assert '"quest_panel"' not in src


def test_rig_listener_is_thinner_and_uses_quantum_instrument_input() -> None:
    src = _read("🍄/🎛️/rig_listener.gd")
    assert "func _press_key(" in src
    assert "func _select_biome_via_input(" in src
    assert "func _select_plot_via_input(" in src
    assert "func _open_quest_board_via_input(" in src
    assert "PlayerInputMacroRunner removed" in src


def test_quantum_instrument_input_exists_next_to_ui_input_layer() -> None:
    src = _read("UI/Core/QuantumInstrumentInput.gd")
    assert "class_name QuantumInstrumentInput" in src
    assert "func _unhandled_key_input(" in src
    assert "func inject_instrument(" in src
    assert "func set_checked_plots(" in src
    assert "PlayerInputMacroRunner" not in src


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


def test_headed_rig_launcher_defaults_to_opengl3_on_wsl() -> None:
    launcher = _read("🍄/🎛️/🟢.sh")
    assert 'RIG_RENDERING_DRIVER="${RIG_RENDERING_DRIVER:-}"' in launcher
    assert 'if [ -z "$RIG_RENDERING_DRIVER" ] && sw_is_wsl; then' in launcher
    assert 'RIG_RENDERING_DRIVER="opengl3"' in launcher
    assert '--rendering-driver "$RIG_RENDERING_DRIVER"' in launcher


def test_policy_weights_terms_are_removed_from_mushroom_layer() -> None:
    profiles = _read("🍄/🎛️/profiles.py")
    assert "POLICY_WEIGHTS_DIR" not in profiles
    assert "def load_policy_weights(" not in profiles
