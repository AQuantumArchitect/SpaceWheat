from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
PROBE_ACTIONS = PROJECT_ROOT / "Core" / "Actions" / "ProbeActions.gd"
LINDBLAD_HANDLER = PROJECT_ROOT / "Core" / "Instrumentation" / "Handlers" / "LindbladHandler.gd"
ACTION_VALIDATOR = PROJECT_ROOT / "UI" / "Core" / "ActionValidator.gd"
QUANTUM_INSTRUMENT = PROJECT_ROOT / "Core" / "Instrumentation" / "QuantumInstrument.gd"
BASE_SUBMENU = PROJECT_ROOT / "UI" / "Core" / "Submenus" / "BaseSubmenu.gd"
FARM = PROJECT_ROOT / "Core" / "Farm.gd"
ACTION_COST_RUNTIME = PROJECT_ROOT / "Core" / "GameMechanics" / "ActionCostRuntime.gd"
ICON_LOADOUT_INDUCER = PROJECT_ROOT / "Core" / "Factions" / "IconLoadoutInducer.gd"
ICON_SUBMENU = PROJECT_ROOT / "UI" / "Core" / "Submenus" / "IconInjectionSubmenu.gd"


def test_probe_actions_uses_cost_helpers() -> None:
    src = PROBE_ACTIONS.read_text(encoding="utf-8")
    assert '_preflight_action(economy, "explore")' in src
    # Strike is FLAT since 2026-08-25 (owner: "only costing 1👥") — the cost
    # goes straight from ActionCostRuntime to the preflight with no scaler
    # in between, which is what makes the chip badge and the wallet agree.
    assert "_preflight_cost(economy, measure_cost)" in src
    assert "scale_measure_cost" not in src
    # Gather (pop) went flat in the same ruling — scale_pop_cost is gone too,
    # so its preflight reads the plain cost as well.
    assert "_preflight_cost(economy, pop_cost)" in src
    assert "PhysicsCostScaling" not in src
    assert "_preflight_cost(economy, reap_cost)" in src
    assert '_commit_cost(economy, explore_cost, "explore")' in src
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


def test_action_validator_uses_icon_runtime_helpers() -> None:
    src = ACTION_VALIDATOR.read_text(encoding="utf-8")
    assert "ActionCostRuntime.preflight_action(" in src
    assert "ActionCostRuntime.get_max_biome_qubits(" in src
    assert '"inject_icon"' in src
    assert '"remove_icon"' in src
    assert "_collect_known_icons(" in src
    assert "_collect_injectable_icons(" in src
    assert "const EconomyConstants" not in src


def test_quantum_instrument_uses_shared_runtime_helper() -> None:
    src = QUANTUM_INSTRUMENT.read_text(encoding="utf-8")
    assert "ActionCostRuntime.get_action_cost(" in src
    assert "ActionCostRuntime.preflight_action(" in src
    assert "ActionCostRuntime.preflight_cost(" in src
    assert "ActionCostRuntime.commit_action(" in src
    assert "func get_policy_snapshot(" in src
    assert '"known_icons": known_icons' in src
    assert "func _resolve_economy()" not in src
    assert "farm.economy" not in src


def test_icon_loadout_inducer_exposes_key_collectors() -> None:
    src = ICON_LOADOUT_INDUCER.read_text(encoding="utf-8")
    assert "func _icon_key(" in src
    assert "func _build_icon_key_set(" in src


def test_icon_submenu_uses_icon_collectors() -> None:
    src = ICON_SUBMENU.read_text(encoding="utf-8")
    assert "_collect_known_icons(" in src
    assert "_collect_injectable_icons(" in src
    assert '"action": "inject_icon"' in src
    assert "ActionCostRuntime.get_action_cost(" in src


def test_base_submenu_prefers_preflight_cost_surface() -> None:
    src = BASE_SUBMENU.read_text(encoding="utf-8")
    assert 'if economy.has_method("preflight_cost")' in src
    assert "economy.preflight_cost(cost)" in src


def test_farm_biome_explore_uses_action_cost_runtime() -> None:
    src = FARM.read_text(encoding="utf-8")
    assert 'ActionCostRuntime.preflight_action(economy, "discover_biome")' in src
    assert 'ActionCostRuntime.commit_action(economy, "discover_biome")' in src


def test_no_direct_cost_preflight_commit_calls_in_runtime_surfaces() -> None:
    files = [
        PROJECT_ROOT / "Core" / "Actions" / "ProbeActions.gd",
        PROJECT_ROOT / "Core" / "Instrumentation" / "QuantumInstrument.gd",
        PROJECT_ROOT / "UI" / "Widgets" / "ActionPreviewRow.gd",
        PROJECT_ROOT / "UI" / "Overlays" / "QuestBoard.gd",
        PROJECT_ROOT / "UI" / "Core" / "Submenus" / "IconInjectionSubmenu.gd",
        PROJECT_ROOT / "UI" / "Core" / "ActionValidator.gd",
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
