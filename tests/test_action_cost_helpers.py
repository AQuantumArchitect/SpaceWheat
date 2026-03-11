from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
PROBE_ACTIONS = PROJECT_ROOT / "Core" / "Actions" / "ProbeActions.gd"
LINDBLAD_HANDLER = PROJECT_ROOT / "UI" / "Handlers" / "LindbladHandler.gd"
ACTION_VALIDATOR = PROJECT_ROOT / "UI" / "Core" / "ActionValidator.gd"
BIOME_HANDLER = PROJECT_ROOT / "UI" / "Handlers" / "BiomeHandler.gd"
QUANTUM_INSTRUMENT = PROJECT_ROOT / "Core" / "Instrumentation" / "QuantumInstrument.gd"
ICON_HANDLER = PROJECT_ROOT / "UI" / "Handlers" / "IconHandler.gd"
BASE_SUBMENU = PROJECT_ROOT / "UI" / "Core" / "Submenus" / "BaseSubmenu.gd"
FARM = PROJECT_ROOT / "Core" / "Farm.gd"
ACTION_COST_RUNTIME = PROJECT_ROOT / "Core" / "GameMechanics" / "ActionCostRuntime.gd"
VOCAB_PAIR_UTILS = PROJECT_ROOT / "Core" / "Gameplay" / "VocabPairUtils.gd"


def test_probe_actions_uses_cost_helpers() -> None:
    src = PROBE_ACTIONS.read_text(encoding="utf-8")
    assert '_preflight_action(economy, "explore")' in src
    assert '_preflight_action(economy, "measure")' in src
    assert '_preflight_action(economy, "pop")' in src
    assert "_preflight_cost(economy, reap_cost)" in src
    assert '_commit_cost(economy, explore_cost, "explore")' in src
    assert '_commit_cost(economy, measure_cost, "measure")' in src
    assert '_commit_cost(economy, reap_cost, "reap")' in src
    assert "ActionCostRuntime.preflight_action(" in src
    assert "ActionCostRuntime.preflight_cost(" in src
    assert "ActionCostRuntime.commit_cost(" in src
    assert "EconomyConstants.preflight_action(" not in src
    assert "EconomyConstants.preflight_cost(" not in src
    assert "EconomyConstants.commit_cost(" not in src


def test_lindblad_handler_uses_cost_helpers() -> None:
    src = LINDBLAD_HANDLER.read_text(encoding="utf-8")
    assert "ActionCostRuntime.preflight_cost(farm.economy, cost)" in src
    assert 'ActionCostRuntime.commit_cost(farm.economy, cost, "lindblad_drain")' in src
    assert "EconomyConstants.preflight_cost(" not in src
    assert "EconomyConstants.commit_cost(" not in src


def test_action_validator_uses_shared_runtime_helper() -> None:
    src = ACTION_VALIDATOR.read_text(encoding="utf-8")
    assert "ActionCostRuntime.preflight_action(" in src
    assert "ActionCostRuntime.get_max_biome_qubits(" in src
    assert "const EconomyConstants" not in src


def test_biome_handler_uses_shared_runtime_helper() -> None:
    src = BIOME_HANDLER.read_text(encoding="utf-8")
    assert "ActionCostRuntime.preflight_action(" in src
    assert "ActionCostRuntime.commit_cost(" in src
    assert "ActionCostRuntime.get_max_biome_qubits(" in src


def test_quantum_instrument_uses_shared_runtime_helper() -> None:
    src = QUANTUM_INSTRUMENT.read_text(encoding="utf-8")
    assert "ActionCostRuntime.get_action_cost(" in src
    assert "ActionCostRuntime.preflight_action(" in src
    assert "ActionCostRuntime.preflight_cost(" in src
    assert "ActionCostRuntime.commit_action(" in src
    assert "func _resolve_economy()" not in src
    assert "farm.economy" not in src


def test_icon_handler_uses_shared_runtime_helper_for_qubit_cap() -> None:
    src = ICON_HANDLER.read_text(encoding="utf-8")
    assert "ActionCostRuntime.get_max_biome_qubits(" in src
    assert "const EconomyConstants" not in src


def test_base_submenu_prefers_preflight_cost_surface() -> None:
    src = BASE_SUBMENU.read_text(encoding="utf-8")
    assert 'if economy.has_method("preflight_cost")' in src
    assert "economy.preflight_cost(cost)" in src


def test_farm_biome_explore_uses_action_cost_runtime() -> None:
    src = FARM.read_text(encoding="utf-8")
    assert 'ActionCostRuntime.preflight_action(economy, "explore_biome")' in src
    assert 'ActionCostRuntime.commit_action(economy, "explore_biome")' in src


def test_no_direct_cost_preflight_commit_calls_in_runtime_surfaces() -> None:
    files = [
        PROJECT_ROOT / "Core" / "Actions" / "ProbeActions.gd",
        PROJECT_ROOT / "Core" / "Instrumentation" / "QuantumInstrument.gd",
        PROJECT_ROOT / "UI" / "Widgets" / "ActionPreviewRow.gd",
        PROJECT_ROOT / "UI" / "Overlays" / "QuestBoard.gd",
        PROJECT_ROOT / "UI" / "Core" / "Submenus" / "VocabInjectionSubmenu.gd",
        PROJECT_ROOT / "UI" / "Core" / "ActionValidator.gd",
        PROJECT_ROOT / "UI" / "Handlers" / "BiomeHandler.gd",
        PROJECT_ROOT / "UI" / "Handlers" / "LindbladHandler.gd",
        PROJECT_ROOT / "UI" / "Handlers" / "IconHandler.gd",
        PROJECT_ROOT / "Core" / "Farm.gd",
    ]
    forbidden = [
        "EconomyConstants.preflight_action(",
        "EconomyConstants.preflight_cost(",
        "EconomyConstants.commit_cost(",
        "EconomyConstants.commit_action(",
    ]
    for path in files:
        src = path.read_text(encoding="utf-8")
        for marker in forbidden:
            assert marker not in src, f"{path.name} should route through runtime helper: {marker}"


def test_action_cost_runtime_has_type_safe_economy_resolution() -> None:
    src = ACTION_COST_RUNTIME.read_text(encoding="utf-8")
    assert "if source is Object:" in src
    assert "elif source is Dictionary:" in src


def test_vocab_pair_utils_exists_with_shared_collectors() -> None:
    src = VOCAB_PAIR_UTILS.read_text(encoding="utf-8")
    assert "static func collect_known_pairs(" in src
    assert "static func collect_injectable_pairs(" in src
    assert "static func biome_has_emoji(" in src


def test_vocab_injection_paths_use_shared_vocab_pair_utils() -> None:
    q_src = QUANTUM_INSTRUMENT.read_text(encoding="utf-8")
    a_src = ACTION_VALIDATOR.read_text(encoding="utf-8")
    v_src = (PROJECT_ROOT / "UI" / "Core" / "Submenus" / "VocabInjectionSubmenu.gd").read_text(encoding="utf-8")
    assert "VocabPairUtils.collect_injectable_pairs(" in q_src
    assert "VocabPairUtils.collect_injectable_pairs(" in a_src
    assert "VocabPairUtils.collect_injectable_pairs(" in v_src
