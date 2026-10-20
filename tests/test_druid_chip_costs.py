"""Druid chips must show and charge the action_costs board.

Playtest: cull looked free, then Druid Q/E/R displayed free too. Superpose
(hadamard) was only ever priced on gate_costs, a table no gameplay path
charges; Spin ± already lived on action_costs. Disabled chips also wiped
the badge, so a grey Druid bar looked unpriced. MULTI Superpose skipped
the wallet entirely.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JSONL = ROOT / "Core/Config/FarmVariableGraph/default.jsonl"
QII = ROOT / "UI/Core/QuantumInstrumentInput.gd"
UIC = ROOT / "UI/Managers/UIContextController.gd"
QI = ROOT / "Core/Instrumentation/QuantumInstrument.gd"
REGISTRY = ROOT / "Core/UI/ChipResolverRegistry.gd"


def src(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def _action_costs() -> dict:
    costs: dict = {}
    for line in JSONL.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if '"path":"action_costs.' not in line:
            continue
        # cheap parse: path and value sit in the JSONL row
        path = line.split('"path":"')[1].split('"')[0]
        value = line.rsplit('"value":', 1)[-1].strip().rstrip("}")
        costs[path] = int(float(value))
    return costs


def test_druid_verbs_are_priced_on_the_charging_board() -> None:
    """Spin ± and Superpose must live on action_costs, the table _cost_action
    actually spends. gate_costs.hadamard was a lying row (zero callers)."""
    costs = _action_costs()
    assert costs.get("action_costs.rotate_up.⛰") == 1
    assert costs.get("action_costs.rotate_down.🏜") == 1
    assert costs.get("action_costs.hadamard.🔥") == 1
    graph = JSONL.read_text(encoding="utf-8")
    assert "gate_costs.hadamard" not in graph


def test_singular_druid_path_charges_action_costs() -> None:
    qi = src(QI)
    cost_action = qi.split("func _cost_action(")[1].split("\nfunc ")[0]
    assert "preflight_action_cost(action_name" in cost_action
    assert "commit_action_cost(action_name" in cost_action
    rotate = qi.split("func action_rotate(")[1].split("\nfunc ")[0]
    assert '_cost_action(action_name' in rotate
    had = qi.split("func action_hadamard(")[1].split("\nfunc ")[0]
    assert '_cost_action("hadamard"' in had


def test_chip_annotation_reads_the_same_board() -> None:
    registry = src(REGISTRY)
    ann = registry.split("static func annotate_cost(")[1].split("\nstatic func ")[0]
    assert "ActionCostRuntime.get_action_cost(ctx.farm, action_name" in ann
    assert "if cost.is_empty():" in ann


def test_disabled_chips_keep_their_price_badge() -> None:
    """Zeroing cost on disabled made locked/grey chips look free."""
    uic = src(UIC)
    apply = uic.split("func _apply_runtime_state(")[1].split("\nfunc ")[0]
    disabled = apply.split("if bool(action_info.get(\"disabled\"")[1].split("if action_key")[0]
    assert "action_info.cost = {}" not in disabled
    get_cost = uic.split("func _get_cost_for_action(")[1].split("\nfunc ")[0]
    assert 'action_info.get("shift_action"' not in get_cost


def test_multi_druid_batch_charges_the_board() -> None:
    qii = src(QII)
    batch = qii.split("func _run_shift_batch(")[1].split("\nfunc ")[0]
    assert "ActionCostRuntime.preflight_action(farm, action_name)" in batch
    assert "ActionCostRuntime.commit_action(farm, action_name" in batch
    sig = qii.split("func _perform_batch_gate_action(")[1].split("\n")[0]
    assert "-> Dictionary" in sig


def test_multi_superpose_records_hadamard() -> None:
    """MULTI/Shift Superpose must write the same gate ledger as singular E.

    Playtest: Superpose in MULTI did not advance Act-0 superposition
    (gate_sequence_contains hadamard ×1) because _perform_batch_gate_action
    injected H without record_projection_action("gate_inject:hadamard").
    """
    qii = src(QII)
    batch = qii.split("func _perform_batch_gate_action(")[1].split("\nfunc ")[0]
    assert 'record_projection_action("gate_inject:hadamard"' in batch
    had = src(QI).split("func action_hadamard(")[1].split("\nfunc ")[0]
    assert '_notify_quest_projection("gate_inject:hadamard"' in had


def test_multi_e_superpose_batches_and_applies_now() -> None:
    """MULTI-marked E Superpose must batch like Shift+E and apply H now.

    Playtest: MULTI + E charged fire then left the Bloch still. Shift+E
    worked. Singular E used to call_deferred hadamard, then _run_action
    invalidated the lookahead before H landed. Hadamard applies in the
    same frame as the charge. Leftover checks with MULTI off stay on
    the focused plot — E must not equal Shift+E.
    """
    qii = src(QII)
    dispatch = qii.split("func _dispatch_action_key(")[1].split("\nfunc ")[0]
    assert "elif shift or _batch_this_verb(key):" in dispatch
    assert "_dispatch_shift_verb(key)" in dispatch
    exec_fn = qii.split("func _execute_action(")[1].split("\nfunc ")[0]
    had = exec_fn.split('"hadamard":')[1].split('"spark_north":')[0]
    assert "_apply_hadamard_now(positions)" in had
    assert "call_deferred" not in had
    apply = qii.split("func _apply_hadamard_now(")[1].split("\nfunc ")[0]
    assert "action_hadamard(typed)" in apply
    assert "_refresh_plot_tiles(typed)" in apply
    deferred = qii.split("func _deferred_hadamard(")[1].split("\nfunc ")[0]
    assert "_apply_hadamard_now(positions)" in deferred
    batch = qii.split("func _batch_this_verb(")[1].split("\nfunc ")[0]
    assert "multi_select_mode" in batch
    assert "checked_plots.is_empty()" in batch
    assert "_is_gate_action" not in batch
    select = qii.split("func _select_plot(")[1].split("\nfunc ")[0]
    assert "if multi_select_mode:" in select
    assert "toggle_check(target_grid_pos)" in select
    highlighted = select.split("if was_highlighted:")[1]
    assert "toggle_check" not in highlighted
    uip = src(ROOT / "UI/Core/UIProgression.gd")
    assert '"druid:shift+E": 4' in uip
