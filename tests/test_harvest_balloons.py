"""Playtest note 9: Strike hangs a harvest balloon; Gather pulls only those.

Player saw collapse, then the next physics frame swept the icon back into
the live sim. Gather also paid on unstruck plots because pop auto-measured.
Operator Bell weave left no mark on the qubits. The lesson is: weave, Strike
ONE plot, both balloons fill, Q pulls them.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROBE = ROOT / "Core" / "Actions" / "ProbeActions.gd"
TERM = ROOT / "Core" / "GameMechanics" / "Terminal.gd"
VAL = ROOT / "UI" / "Core" / "ActionValidator.gd"
GATES = ROOT / "Core" / "Instrumentation" / "Handlers" / "GateActionHandler.gd"
FIELD = ROOT / "Core" / "Visualization" / "QuantumField3D.gd"
ARC = ROOT / "Core" / "Quests" / "data" / "tutorial_arc.json"
PROG = ROOT / "UI" / "Core" / "UIProgression.gd"
INST = ROOT / "Core" / "Instrumentation" / "QuantumInstrument.gd"
PLOT = ROOT / "Core" / "GameMechanics" / "BasePlot.gd"


def src(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def body(path: Path, name: str) -> str:
    parts = src(path).split("func %s(" % name)
    assert len(parts) > 1, "%s() is gone from %s" % (name, path.name)
    return parts[1].split("\nfunc ")[0]


def test_gather_refuses_unstruck_plots() -> None:
    prep = body(PROBE, "_prepare_pop_result")
    assert "_auto_measure_for_pop" not in prep
    assert "Nothing to gather" in prep
    pop = body(VAL, "_can_execute_pop")
    assert "terminal.is_bound" not in pop
    assert "terminal.can_pop()" in pop
    clear = body(PROBE, "action_clear_all")
    assert "terminal.can_pop()" in clear


def test_strike_hangs_a_harvest_balloon() -> None:
    term = src(TERM)
    assert "var harvest_balloons" in term
    assert "func append_harvest_balloon(" in term
    assert "func harvest_label(" in term
    assert "func harvest_amount(" in term
    assert "func sleep_after_strike(" in term
    assert "func rebind_for_restrike(" not in term
    assert "return has_harvest()" in body(TERM, "can_pop")
    assert "return not harvest_balloons.is_empty()" in body(TERM, "has_harvest")
    pool = src(ROOT / "Core" / "GameMechanics" / "TerminalPool.gd")
    assert "var piled: bool" in pool
    assert "func release_terminal" in pool
    fin = body(PROBE, "_finalize_measurement_terminal")
    assert "append_harvest_balloon" in fin
    assert "sleep_after_strike" in fin
    assert "_fog_plot" in fin
    measure = body(PROBE, "action_measure")
    assert "rebind_for_restrike" not in measure
    assert "Explore first (F)" in measure
    assert "_stamp_partner_harvests" in measure
    prep = body(PROBE, "_prepare_pop_result")
    assert "harvest_balloons" in prep


def test_strike_sleeps_plot_frfr_stacks_q_takes_pile() -> None:
    term = src(TERM)
    sleep = body(TERM, "sleep_after_strike")
    assert "is_bound = false" in sleep
    assert "is_measured = false" in sleep
    assert "harvest_balloons" not in sleep
    bind = body(TERM, "bind_to_register")
    assert "harvest_balloons" not in bind
    clear = body(TERM, "clear_measurement")
    assert "harvest_balloons.clear()" in clear
    assert "if not is_measured:" not in clear
    expl = body(PROBE, "action_explore")
    assert "existing_terminal" in expl
    fog = body(PROBE, "_fog_plot")
    assert "unreveal_plot" in fog
    farm = src(ROOT / "Core" / "Farm.gd")
    assert "signal plot_unrevealed" in farm
    inst = body(INST, "action_explore")
    assert "existing = plot.terminal" in inst
    qii = src(ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd")
    tap = qii.split("func predict_tap_verb(")[1].split("\nfunc ")[0]
    assert "can_measure()" in tap
    assert "can_pop()" not in tap
    assert "return \"explore\"" in tap


def test_operator_bell_leaves_a_visible_mark() -> None:
    bell = body(GATES, "create_bell_pair")
    assert "_stamp_persistent_gate" in bell
    stamp = body(GATES, "_stamp_persistent_gate")
    assert "add_persistent_gate" in stamp
    assert "mark_bell_gate" in stamp
    add = body(PLOT, "add_persistent_gate")
    assert "linked_plots" in add
    field = src(FIELD)
    assert "func _draw_persistent_gates(" in field
    assert "func _tick_harvest_balloons(" in field
    assert "harvest_lbl" in field


def test_bell_partner_stamp_uses_biome_row_not_demos() -> None:
    """Hive runner: Bell on forest G+H, Strike fogs G, partner H never balloons.

    `_stamp_partner_harvests` looked up Vector2i(rid, 0) — TheDemos. Forest is
    y=2. `_bell_woven` used the same y=0, so the banner never saw the weave.
    """
    stamp = body(PROBE, "_stamp_partner_harvests")
    assert "Vector2i(int(rid), 0)" not in stamp
    assert "struck.grid_position.y" in stamp
    assert "get_plot_biome_assignments" in stamp
    qii = src(ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd")
    build = qii.split('"build_gate":')[1].split('"inspect":')[0]
    assert "_toast_player" in build
    assert "_toast_refusal" in build
    submenu = body(ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd", "_execute_build_gate")
    assert "_toast_player" in submenu
    assert "_toast_refusal" in submenu
    woven = body(PROG, "_bell_woven")
    assert "Vector2i(_focused_col(), 0)" not in woven
    assert "get_current_biome" in woven
    assert "_plot_at" in woven


def test_bell_lesson_is_weave_then_strike_one() -> None:
    import json
    arc = json.loads(src(ARC))
    step = next(s for s in arc["steps"] if s.get("tutorial_teaches") == "entanglement")
    gates = [p.get("gate") for p in step["state_predicates"]]
    assert "bell" in gates
    assert "bell_collapse" in gates
    walk = body(PROG, "_verb_line")
    assert "Strike one woven plot" in walk
    inst = body(INST, "action_measure")
    assert "bell_collapse" in inst


def test_bell_collapse_counts_weave_partners() -> None:
    measure = body(PROBE, "action_measure")
    assert "_partner_ids_from_weave" in measure
    assert "was_entangled" in measure
    assert "not partners.is_empty()" in measure


def test_bell_2q_writes_entanglement_graph() -> None:
    qc = body(ROOT / "Core" / "QuantumSubstrate" / "QuantumComputer.gd", "apply_gate_2q")
    assert "_ensure_entanglement_node(qubit_a)" in qc
    assert "entanglement_graph[qubit_a].append(qubit_b)" in qc
    stamp = body(PROBE, "_stamp_partner_harvests")
    assert "_partner_ids_from_weave" in stamp
    weave = body(PROBE, "_partner_ids_from_weave")
    assert "linked_plots" in weave
    assert "linked_registers" in weave


def test_entanglement_walk_stays_on_ace_after_weave() -> None:
    walk = body(PROG, "_verb_line")
    assert 'teaches == "entanglement" and _bell_woven()' in walk


def test_reap_mills_explore_every_qubit_then_harvests_all_bound() -> None:
    walk = body(PROG, "_verb_line")
    assert "_reap_season_walk_line" in walk
    mill = body(PROG, "_reap_season_walk_line")
    assert "_unbound_plot_count" in mill
    assert "mass_mark_walk" in mill
    assert "mass_explore_walk" in mill
    assert "reap_walk" in mill
    target = body(PROG, "objective_target")
    assert '"reap_season"' in target
    assert "_unbound_plot_count" in target
    assert '"REAP"' in target
    closed = body(PROBE, "_closed_reap_rewards")
    assert "is_register_bound" in closed
    assert "revealed_plots" not in closed
    refuse = body(PROBE, "action_reap")
    assert "no_explored" in refuse
    assert "_count_explored_registers" in refuse
    assert "revealed_plots" not in refuse


def test_gather_cashes_focused_plot_only() -> None:
    """Playtest: Q gathered every balloon on the screen.

    Singular Q cashes the focused plot. MULTI or Shift+Q walks the
    marked set. Leftover checks must not mass-gather Ace Q.
    """
    qii = src(ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd")
    exec_fn = qii.split("func _execute_action(")[1].split("\nfunc ")[0]
    pop = exec_fn.split('"pop":')[1].split('"clear_all":')[0]
    assert "_basket_well_pos" not in pop
    assert "action_pop(grid_pos)" in pop
    assert "action_clear_all" not in pop
    batch = qii.split("func _batch_this_verb(")[1].split("\nfunc ")[0]
    assert "multi_select_mode" in batch
    assert "checked_plots.is_empty()" in batch
    assert "_is_gate_action" not in batch
    assert 'if str(info.get("shift_action", "")).strip_edges() != "":' not in batch
    invoke = qii.split("func invoke_action")[1].split("func _tap_blocked_by_overlay")[0]
    assert "shift or multi_select_mode" not in invoke
    dispatch = qii.split("func _unhandled_key_input")[1].split("func _dispatch_action_key")[0]
    assert "event.is_shift_pressed() or multi_select_mode" not in dispatch
    cfg = src(ROOT / "Core" / "GameState" / "ToolConfig.gd")
    ace_q = cfg.split('"Q": {"action": "pop"')[1].split('"E":')[0]
    assert '"shift_action": "pop"' in ace_q
    assert "MULTI" in ace_q


def test_gather_flier_splits_credits_by_emoji() -> None:
    """Playtest: gather float showed one glyph with both poles mashed.

    Wallet already applies credits_by_emoji. The flier must spawn one
    float per emoji with that emoji's amount, not resource+amount.
    """
    prep = body(PROBE, "_prepare_pop_result")
    assert '"credits_by_emoji": credits_by_emoji' in prep
    flier = src(ROOT / "UI" / "Widgets" / "FloatingRewardLayer.gd")
    on_pop = flier.split('"pop":')[1].split('"measure":')[0]
    assert "_cascade_pop" in on_pop
    assert "_pop_credits" in on_pop
    assert "spawn_reward(emoji, amount" not in on_pop
    pop_credits = flier.split("func _pop_credits(")[1].split("\nfunc ")[0]
    assert "credits_by_emoji" in pop_credits
    cascade = flier.split("func _cascade_pop(")[1].split("\nfunc ")[0]
    assert "spawn_reward.bind" in cascade


def test_gather_does_not_collapse_or_blank() -> None:
    """Playtest: decoupled Gather still collapsed then fogged the Bloch.

    Q cashes harvest_balloons only. Strike is the collapse. The seat stays.
    """
    pop = body(PROBE, "action_pop")
    assert "release_terminal" not in pop
    assert "take_harvest" in pop
    assert "_project_register" not in pop
    assert "_auto_measure_for_pop" not in pop
    term = src(TERM)
    assert "func take_harvest(" in term
    assert "func is_seated(" in term
    take = body(TERM, "take_harvest")
    assert "harvest_balloons.clear()" in take
    assert "unbind(" not in take
    assert "grid_position =" not in take
    qi_pop = body(INST, "action_pop")
    assert "_detach_terminal_from_plot" not in qi_pop
    farm = src(ROOT / "Core" / "Farm.gd")
    farm_pop = farm.split('"pop":')[1].split('"reap":')[0]
    assert "terminal_released.emit" not in farm_pop
    pool = src(ROOT / "Core" / "GameMechanics" / "TerminalPool.gd")
    getu = body(ROOT / "Core" / "GameMechanics" / "TerminalPool.gd", "get_unbound_terminal")
    assert "is_seated" in getu
