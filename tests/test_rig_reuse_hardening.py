from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RIG_LISTENER = PROJECT_ROOT / "🍄" / "🎛️" / "rig_listener.gd"
RIG_CLIENT = PROJECT_ROOT / "🍄" / "🎛️" / "rig_client.py"


def test_rig_listener_primes_queue_cursor_on_ready() -> None:
    src = RIG_LISTENER.read_text(encoding="utf-8")
    assert "func _prime_queue_cursor_to_end()" in src
    assert "_prime_queue_cursor_to_end()" in src


def test_rig_listener_echoes_request_id_in_results() -> None:
    src = RIG_LISTENER.read_text(encoding="utf-8")
    assert 'var request_id = str(cmd.get("request_id", ""))' in src
    assert 'result["request_id"] = request_id' in src


def test_rig_client_turn_roundtrip_uses_request_id() -> None:
    src = RIG_CLIENT.read_text(encoding="utf-8")
    assert 'payload["request_id"] = request_id' in src
    assert "request_id=request_id" in src
    assert "self._results_by_request" in src


def test_rig_listener_routes_read_actions_through_policy_snapshot() -> None:
    src = RIG_LISTENER.read_text(encoding="utf-8")
    assert 'result["resources"] = _instrument.get_resource_snapshot()' in src
    assert 'result["grid"] = _instrument.get_grid_snapshot()' in src
    assert 'result["quests"] = active if full else _slim_active_quests(active)' in src
    assert 'result["icons"] = icons if icons is Array else []' in src


def test_quest_board_accepts_quest_payload_refresh_signal() -> None:
    src = (PROJECT_ROOT / "UI" / "Overlays" / "QuestBoard.gd").read_text(encoding="utf-8")
    assert "func _on_quest_pool_changed(_quest: Dictionary = {}) -> void:" in src


def test_rig_listener_routes_load_game_path_through_save_load_coordinator() -> None:
    src = RIG_LISTENER.read_text(encoding="utf-8")
    assert 'gsm.save_load.load_and_apply_path(path)' in src


def test_loaded_state_refreshes_live_runtime_bindings() -> None:
    src = (PROJECT_ROOT / "Core" / "GameState" / "GameStateManager.gd").read_text(encoding="utf-8")
    assert "func _refresh_runtime_bindings() -> void:" in src
    assert "shell.quantum_instrument.setup(farm)" in src
    assert "snapshot_service.setup(farm, shell)" in src
    assert "Re-assert the loaded signature after runtime/UI rebinding" in src


def test_farm_boot_prefers_loaded_signature_over_starter_default() -> None:
    src = (PROJECT_ROOT / "Core" / "Farm.gd").read_text(encoding="utf-8")
    assert 'if gsm and "current_state" in gsm and gsm.current_state and "known_icons" in gsm.current_state:' in src
    assert "set_known_icons(state_icons)" in src


def test_path_load_boots_initial_biomes_before_apply() -> None:
    src = (PROJECT_ROOT / "Core" / "GameState" / "SaveLoadCoordinator.gd").read_text(encoding="utf-8")
    assert "var tree = Engine.get_main_loop() if Engine.get_main_loop() is SceneTree else null" in src
    assert 'var boot_mgr = tree.root.get_node_or_null("/root/BootManager") if tree and tree.root else null' in src
    assert "await _gsm.session_lifecycle.await_farm_ready(_gsm.active_farm)" in src
    assert 'boot_mgr.boot_initial_biomes(_gsm.active_farm, state)' in src
    assert 'await _gsm._apply_loaded_state_deferred(state)' in src
    assert '_gsm.active_farm.set_known_icons(state.known_icons)' in src


def test_farm_physics_skips_non_running_restore_phase() -> None:
    src = (PROJECT_ROOT / "Core" / "Farm.gd").read_text(encoding="utf-8")
    assert "SessionLifecycle.SessionPhase.RUNNING" in src
    assert "if gsm and \"phase\" in gsm" in src


def test_physics_drift_compare_runs_after_full_biome_restore() -> None:
    src = (PROJECT_ROOT / "Core" / "GameState" / "GameStateSerializer.gd").read_text(encoding="utf-8")
    assert "func _warn_for_physics_drift(farm: Node, biome_states: Dictionary) -> void:" in src
    assert "_warn_for_physics_drift(farm, biome_states)" in src


def test_biome_batcher_startup_warning_waits_for_engine_state() -> None:
    src = (PROJECT_ROOT / "Core" / "Environment" / "BiomeEvolutionBatcher.gd").read_text(encoding="utf-8")
    assert 'elif not _engine_ready:' in src
    assert 'C++ lookahead awaiting engine initialization' in src
