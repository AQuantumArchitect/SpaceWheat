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


def test_policy_projector_exists_with_shared_candidate_and_reward_logic() -> None:
    src = _read("Core/AI/PolicyStateProjector.gd")
    assert "class_name PolicyStateProjector" in src
    assert "static func build_candidates(" in src
    assert "static func compute_reward_components(" in src
    assert "static func quest_pressure(" in src
    assert "static func choose_channel_drain_target(" in src
    assert "static func _offer_milk_metrics(" in src
    assert "static func webway_offer_value(" in src
    assert "milk_distance_gain" in src
    assert "milk_cascade_gain" in src
    assert "webway_gain" in src
    assert "max_rerolls" in src
    assert "milk_corridor_weight" in src


def test_both_policy_engines_use_shared_projector_and_graph() -> None:
    qfp = _read("Core/AI/QuantumFiberPolicy.gd")
    pqr = _read("Core/AI/PolicyQuantumRegister.gd")
    for src in (qfp, pqr):
        assert 'const PolicyGraph = preload("res://Core/AI/PolicyGraph.gd")' in src
        assert 'const PolicyStateProjector = preload("res://Core/AI/PolicyStateProjector.gd")' in src
        assert "PolicyGraph.load_resolved_graph(" in src
        assert "PolicyStateProjector.build_candidates(" in src
        assert "PolicyStateProjector.compute_reward_components(" in src
        assert "func get_policy_graph()" in src
        assert "func apply_policy_graph_lines(" in src


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
    assert '"path":"action_priors.lock_offer.milk_distance_gain"' in text
    assert '"path":"action_priors.lock_offer.milk_cascade_gain"' in text


def test_game_state_and_rig_listener_persist_policy_graph() -> None:
    gs = _read("Core/GameState/GameState.gd")
    serializer = _read("Core/GameState/GameStateSerializer.gd")
    sidecar = _read("Core/GameState/SaveStore.gd")
    listener = _read("Tests/rig_listener.gd")
    assert '@export var policy_graph_path: String = "res://Core/Config/PolicyGraph/default.jsonl"' in gs
    assert "@export var policy_graph_jsonl: Array[String] = []" in gs
    assert 'state.policy_graph_jsonl = pgraph.duplicate()' in serializer
    assert 'state.policy_graph_path = str(current_state.policy_graph_path)' in serializer
    assert '"policy_graph_path": state.policy_graph_path' in sidecar
    assert '"policy_graph_jsonl": state.policy_graph_jsonl' in sidecar
    assert 'gsm.current_state.policy_graph_jsonl = PolicyGraph.snapshot_to_graph_lines(graph_snapshot)' in listener
    assert "policy.apply_policy_graph_lines(graph_lines)" in listener


def test_snapshot_service_owns_policy_state_projection() -> None:
    snapshot = _read("Core/Instrumentation/SnapshotService.gd")
    listener = _read("Tests/rig_listener.gd")
    assert "func build_policy_state(cmd: Dictionary = {}) -> Dictionary:" in snapshot
    assert "func build_policy_state_lightweight(cmd: Dictionary = {}) -> Dictionary:" in snapshot
    assert "_annotate_offer_discovery_affinity(offers)" in snapshot
    assert "_snapshot_service.build_policy_state_lightweight(cmd)" in listener


def test_seed_path_and_runner_lock_policy_use_canonical_policy_graph() -> None:
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
    assert 'get_cfg_bool(cfg, "profile_lock_strategy")' not in runner
    assert "MILK_HUNT_PROFILE_LOCK_STRATEGY" not in runner
    assert "--profile-lock-strategy" not in runner
    assert "--lock-offer-gate" in runner
    assert "action_gate_policies" in runner
    assert "action_gate_lock_offer_actions" in runner
    assert "def _evaluate_action_gate(" in runner
    assert "def _heuristic_best_offer_index(" in runner
    assert "fallback_python_policy" not in runner
    assert not (ROOT / "🍄" / "🎛️" / "milk_hunt_fallback_policy.py").exists()


def test_quantum_register_policy_uses_parametric_policy_graph() -> None:
    src = _read("Core/AI/PolicyQuantumRegister.gd")
    ppg = _read("Core/AI/ParametricPolicyGraph.gd")
    assert 'const ParametricPolicyGraph = preload("res://Core/AI/ParametricPolicyGraph.gd")' in src
    assert "_ppg = ParametricPolicyGraph.new()" in src
    assert "_ppg.observe_outcome(action_name, reward_components)" in src
    assert "_ppg.resolve_graph(_policy_graph)" in src
    assert "class_name ParametricPolicyGraph" in ppg
    assert "func resolve_graph(raw_graph: Dictionary) -> Dictionary:" in ppg
    assert "func observe_outcome(action_name: String, reward_components: Dictionary) -> void:" in ppg
    assert "func export_state() -> Dictionary:" in ppg
    assert "func load_state(state: Dictionary) -> void:" in ppg
