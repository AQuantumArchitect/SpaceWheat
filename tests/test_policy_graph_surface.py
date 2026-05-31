from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def _read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def test_policy_graph_module_exists_with_jsonl_surface() -> None:
    src = _read("Core/AI/PolicyGraph.gd")
    assert 'class_name PolicyGraph' in src
    assert 'const DEFAULT_GRAPH_PATH := "res://Core/Config/PolicyGraph/default.jsonl"' in src
    assert "static func default_graph(" in src
    assert "static func profile_graph_path(" in src
    assert "static func load_resolved_graph(" in src
    assert "static func apply_graph_lines(" in src
    assert "static func snapshot_to_graph_lines(" in src
    assert '"action_limits"' in src
    assert "static func action_limits_for_action(" in src


def test_policy_graph_runtime_exposes_graph_and_action_limit_helpers() -> None:
    src = _read("🍄/🎛️/policy_graph_runtime.py")
    assert "DEFAULT_GRAPH_PATH = POLICY_GRAPH_ROOT / \"default.jsonl\"" in src
    assert "def profile_graph_path(" in src
    assert "def load_graph_lines(" in src
    assert "def load_resolved_graph(" in src
    assert "def action_limits_for_action_from_graph(" in src
    assert "def action_limits_for_action(" in src


def test_milk_hunt_runner_uses_shared_policy_graph_runtime() -> None:
    runner = _read("🍄/🎛️/milk_hunt_runner.py")
    assert "from policy_graph_runtime import (" in runner
    assert "runtime_policy_graph_path" in runner
    assert "action_limits_for_action_from_graph" in runner
    assert '_run_turn(turn, "policy_graph")' in runner
    assert 'effective_policy_graph_path = str(runtime_policy_graph_path(hunter_profile, "ucb"))' in runner


def test_profile_graphs_exist_for_primary_profiles() -> None:
    for profile in (
        "granary_scout",
        "arc_coldpath_explorer",
        "solar_gatekeeper",
        "village_diplomat",
        "biotic_bubble_runner",
    ):
        path = ROOT / "Core" / "Config" / "PolicyGraph" / "ucb" / f"{profile}.jsonl"
        assert path.exists(), f"missing policy graph profile: {profile}"
        text = path.read_text(encoding="utf-8")
        assert '"path":"profile_id"' in text


def test_default_policy_graph_exposes_milk_progress_weights() -> None:
    text = _read("Core/Config/PolicyGraph/default.jsonl")
    assert '"path":"action_priors.quest_cycle.milk_hint_scale"' in text
    assert '"path":"action_priors.quest_cycle.milk_distance_gain"' in text
    assert '"path":"action_priors.quest_cycle.milk_cascade_gain"' in text
    assert '"path":"action_priors.quest_cycle.prior_milk_distance_gain"' in text
    assert '"path":"action_priors.quest_cycle.prior_milk_cascade_gain"' in text


def test_game_state_and_rig_listener_persist_policy_graph() -> None:
    gs = _read("Core/GameState/GameState.gd")
    serializer = _read("Core/GameState/GameStateSerializer.gd")
    sidecar = _read("Core/GameState/SaveStore.gd")
    seed = _read("🍄/🎛️/milk_hunt_seed_save.py")
    listener = _read("Rig/rig_listener.gd")
    assert '@export var policy_graph_path: String = "res://Core/Config/PolicyGraph/default.jsonl"' in gs
    assert "@export var policy_graph_jsonl: Array[String] = []" in gs
    assert 'state.policy_graph_jsonl = pgraph.duplicate()' in serializer
    assert 'state.policy_graph_path = str(current_state.policy_graph_path)' in serializer
    assert '"policy_graph_path": state.policy_graph_path' in sidecar
    assert '"policy_graph_jsonl": state.policy_graph_jsonl' in sidecar
    assert 'payload["policy_graph_path"] = policy_graph_path_value' in seed
    assert 'payload["policy_graph_jsonl"] = policy_graph_jsonl_value' in seed
    assert 'var policy_graph_path = str(cmd.get("policy_graph_path", ""))' in listener
    assert 'gsm.current_state.policy_graph_path = policy_graph_path' in listener
    assert 'var policy_graph_jsonl = cmd.get("policy_graph_jsonl", [])' in listener
    assert 'gsm.current_state.policy_graph_jsonl = typed_lines' in listener
    assert '"known_emojis": state.get_known_emojis(),' not in sidecar


def test_snapshot_service_owns_policy_state_projection() -> None:
    snapshot = _read("Core/Instrumentation/SnapshotService.gd")
    listener = _read("Rig/rig_listener.gd")
    assert "func get_policy_snapshot(" in snapshot
    assert "func open_semantic_map_panel(" not in snapshot
    assert "func open_vocabulary_panel(" not in snapshot
    assert "func build_policy_state(cmd: Dictionary = {}) -> Dictionary:" not in snapshot
    assert "func build_policy_state_lightweight(cmd: Dictionary = {}) -> Dictionary:" not in snapshot
    assert "func _annotate_offer_discovery_affinity(offers: Array) -> Array:" not in snapshot
    assert "instrument.get_policy_snapshot(" in snapshot
    assert "func _get_policy_snapshot(include_offers: bool = true, include_grid: bool = true) -> Dictionary:" in listener
    assert "var bundled = _instrument.get_policy_snapshot(include_offers, include_grid)" in listener


def test_seed_path_and_runner_use_canonical_policy_graph() -> None:
    seed = _read("🍄/🎛️/milk_hunt_seed_save.py")
    runner = _read("🍄/🎛️/milk_hunt_runner.py")
    helper = _read("🍄/🎛️/policy_graph_runtime.py")
    assert 'from policy_graph_runtime import profile_graph_path' in seed
    assert 'payload["policy_graph_path"] = policy_graph_path_value' in seed
    assert 'from policy_graph_runtime import (' in runner
    assert "action_limits_for_action_from_graph" in runner
    assert '_run_turn(turn, "policy_graph")' in runner
    assert "def action_limits_for_action_from_graph(" in helper
    assert "DEFAULT_GRAPH_PATH = POLICY_GRAPH_ROOT / \"default.jsonl\"" in helper
    assert "def _evaluate_action_gate(" in runner
    assert "def _heuristic_best_offer_index(" in runner
    assert "fallback_python_policy" not in runner
    assert not (ROOT / "🍄" / "🎛️" / "milk_hunt_fallback_policy.py").exists()


def test_quest_runtime_no_longer_uses_solo_vocab_discovery_fallback() -> None:
    src = _read("Core/Quests/QuestManager.gd")
    assert "discover_emoji" not in src
    assert "Fallback for solo vocabulary rewards" not in src
