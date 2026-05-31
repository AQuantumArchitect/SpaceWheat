from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RIG_LISTENER = PROJECT_ROOT / "Rig" / "rig_listener.gd"
SNAPSHOT_SERVICE = PROJECT_ROOT / "Core" / "Instrumentation" / "SnapshotService.gd"
QUANTUM_INSTRUMENT = PROJECT_ROOT / "Core" / "Instrumentation" / "QuantumInstrument.gd"


def test_rig_listener_does_not_use_snapshot_for_mutations() -> None:
    src = RIG_LISTENER.read_text(encoding="utf-8")
    forbidden_calls = [
        "_snapshot_service.add_resource(",
        "_snapshot_service.set_resource(",
        "_snapshot_service.accept_quest_data(",
        "_snapshot_service.accept_quest_by_id(",
        "_snapshot_service.complete_quest(",
        "_snapshot_service.complete_or_claim_quest(",
        "_snapshot_service.claim_quest(",
        "_snapshot_service.configure_economy(",
        "_snapshot_service.patch_balance(",
        "_snapshot_service.reset_balance_to_default(",
        "_snapshot_service.export_balance_profile(",
        "_snapshot_service.load_balance_profile(",
        "_snapshot_service.apply_farm_variable_graph(",
        "_snapshot_service.load_farm_variable_graph_file(",
        "_snapshot_service.apply_policy_graph_lines(",
    ]
    for pattern in forbidden_calls:
        assert pattern not in src, f"mutation call should not route through SnapshotService: {pattern}"


def test_snapshot_service_has_no_mutation_api_methods() -> None:
    src = SNAPSHOT_SERVICE.read_text(encoding="utf-8")
    forbidden_method_defs = [
        "func add_resource(",
        "func set_resource(",
        "func accept_quest_data(",
        "func accept_quest_by_id(",
        "func complete_quest(",
        "func complete_or_claim_quest(",
        "func claim_quest(",
        "func gate_inject(",
        "func lindblad_pump(",
        "func lindblad_drain(",
        "func time_skip(",
        "func set_biome_stride(",
        "func set_biome_resolution(",
        "func set_timescale_objective(",
        "func clear_timescale_objective(",
        "func configure_economy(",
        "func patch_balance(",
        "func reset_balance_to_default(",
        "func export_balance_profile(",
        "func load_balance_profile(",
        "func apply_farm_variable_graph(",
        "func load_farm_variable_graph_file(",
        "func apply_policy_graph_lines(",
    ]
    for pattern in forbidden_method_defs:
        assert pattern not in src, f"SnapshotService should stay read-only: {pattern}"


def test_snapshot_service_exposes_ui_snapshot_read_api() -> None:
    src = SNAPSHOT_SERVICE.read_text(encoding="utf-8")
    assert "func get_overlay_snapshot(" in src
    assert "func get_full_ui_snapshot(" in src
    assert "open_icon_panel()" in src


def test_rig_listener_has_quantum_instrument_guard() -> None:
    src = RIG_LISTENER.read_text(encoding="utf-8")
    assert '"error": "no_quantum_instrument"' in src


def test_quantum_instrument_exposes_policy_snapshot_bundle() -> None:
    src = QUANTUM_INSTRUMENT.read_text(encoding="utf-8")
    assert "func get_policy_snapshot(" in src
    assert '"known_icons": known_icons' in src


def test_rig_listener_exposes_policy_graph_actions() -> None:
    src = RIG_LISTENER.read_text(encoding="utf-8")
    assert '"policy_snapshot"' in src


def test_rig_listener_uses_discover_biome_only_and_exposes_quest_reroll_feedback() -> None:
    src = RIG_LISTENER.read_text(encoding="utf-8")
    assert '"discover_biome"' in src
    assert '"explore_biome"' not in src
    assert '"offer_quests"' in src
    assert '"accept_offer"' in src
    assert '"complete_quest"' in src
    assert '"complete_or_claim"' in src
    assert '"claim_quest"' in src
    assert '"vocabulary"|"semantic_map"' not in src


def test_policy_snapshot_bundle_has_expected_keys() -> None:
    src = QUANTUM_INSTRUMENT.read_text(encoding="utf-8")
    assert '"resources": resources' in src
    assert '"known_icons": known_icons' in src
    assert '"offers": offers' in src
    assert '"active_quests": active_quests' in src
    assert '"story_offers": story_offers' in src


def test_rig_listener_uses_policy_snapshot_bundle_for_policy_state() -> None:
    listener = RIG_LISTENER.read_text(encoding="utf-8")
    assert "func _get_policy_snapshot(include_offers: bool = true, include_grid: bool = true) -> Dictionary:" in listener
    assert "var bundled = _instrument.get_policy_snapshot(include_offers, include_grid)" in listener


def test_seed_state_mutation_can_set_policy_graph_path() -> None:
    listener = RIG_LISTENER.read_text(encoding="utf-8")
    instrument = QUANTUM_INSTRUMENT.read_text(encoding="utf-8")
    assert 'var policy_graph_path = str(cmd.get("policy_graph_path", ""))' in listener
    assert 'gsm.current_state.policy_graph_path = policy_graph_path' in listener
    assert 'var policy_graph_path = str(cmd.get("policy_graph_path", ""))' in instrument
    assert 'gsm.current_state.policy_graph_path = policy_graph_path' in instrument
