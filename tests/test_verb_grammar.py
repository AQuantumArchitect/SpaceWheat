"""VerbGrammar is the one table for QERF / MULTI / Reap.

MULTI (or Shift) swaps the dock to batch verbs. Reap is the season
button (Ctrl+Shift+Space), not a QERF shift. Toasts, chips, unlock
keys, and tests read this file.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def src(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def test_verb_grammar_is_the_qerf_table() -> None:
    g = src("UI/Core/VerbGrammar.gd")
    assert 'MASS_EXPLORE_TOAST := "SHIFT [F] to multi explore"' in g
    assert 'REAP_CHORD := "Ctrl+Shift+F"' in g
    assert 'REAP_PULSE := "REAP"' in g
    assert 'REAP_UNLOCK_KEY := "reap"' in g
    assert "func project_chip" in g
    assert "func is_reap_chord" in g
    assert "func is_multi_live" in g
    assert "func mass_explore_toast" in g


def test_ace_q_shift_is_mass_gather_not_reap() -> None:
    tools = src("Core/GameState/ToolConfig.gd")
    ace = tools.split("FRAME_ACE: {")[1].split("FRAME_OPERATOR:")[0]
    q_chip = ace.split('"Q":')[1].split('"E":')[0]
    r_chip = ace.split('"R":')[1].split('"F":')[0]
    f_chip = ace.split('"F":')[1]
    assert '"shift_action": "pop"' in q_chip
    assert '"shift_label": "Mass Gather"' in q_chip
    assert '"shift_action": "reap"' not in q_chip
    assert '"shift_action": "measure"' in r_chip
    assert '"shift_label": "Mass Strike"' in r_chip
    assert '"shift_action": "explore"' in f_chip
    assert '"shift_label": "Mass Explore"' in f_chip


def test_multi_click_arms_batch_and_toasts_shift_f() -> None:
    qii = src("UI/Core/QuantumInstrumentInput.gd")
    toast = qii.split("func set_multi_select_mode")[1].split("func _toggle_bulk_check_active_biome")[0]
    assert "VerbGrammar.mass_explore_toast()" in toast
    invoke = qii.split("func invoke_action")[1].split("func _tap_blocked_by_overlay")[0]
    assert "_dispatch_action_key(action_key, shift)" in invoke
    assert "shift or multi_select_mode" not in invoke
    dispatch = qii.split("func _unhandled_key_input")[1].split("func _dispatch_action_key")[0]
    assert "event.is_shift_pressed()" in dispatch
    assert "event.is_shift_pressed() or multi_select_mode" not in dispatch
    batch = qii.split("func _batch_this_verb(")[1].split("\nfunc ")[0]
    assert "multi_select_mode" in batch
    assert "checked_plots.is_empty()" in batch
    assert "func request_reap" in qii
    assert 'open_event_home("self")' in qii
    assert 'autosave("reap", true)' in qii


def test_qerf_swaps_instead_of_cramming() -> None:
    row = src("UI/Widgets/ActionPreviewRow.gd")
    apply = row.split("func _apply_button_projection")[1].split("func _adjust_label_for_cost")[0]
    assert "shift_hint" not in apply
    assert "%s)" % "shift" not in apply
    ctx = src("UI/Managers/UIContextController.gd")
    assert "VerbGrammar.project_chip" in ctx
    assert "VerbGrammar.is_multi_live" in ctx


def test_reap_is_the_season_button() -> None:
    btn = src("UI/Widgets/ReapButton.gd")
    assert "VerbGrammar.REAP_CHORD" in btn
    assert "signal reap_requested" in btn
    bars = src("UI/Managers/ActionBarManager.gd")
    assert "_ReapButton" in bars
    assert "func get_reap_row" in bars
    probe = src("Core/Actions/ProbeActions.gd")
    get = probe.split("func _get_active_biomes_for_reap")[1].split("func _get_reap_count")[0]
    assert "terminal_pool" not in get
    assert "evolution_paused" not in get
    save = src("Core/GameState/SaveLoadCoordinator.gd")
    assert "force: bool = false" in save.split("func autosave")[1].split("func new_game")[0]
    shell = src("UI/PlayerShell.gd")
    assert "VerbGrammar.is_reap_chord" in shell
    overlay = src("UI/Overlays/ControlsOverlay.gd")
    assert "func _build_self_last_season" in overlay


def test_unlock_keys_match_the_grammar() -> None:
    prog = src("UI/Core/UIProgression.gd")
    assert '"ace:shift+F": 3' in prog
    assert '"ace:shift+Q": 3' in prog
    assert '"ace:reap": 6' in prog
    walk = prog.split("func _mass_explore_walk_line")[1].split("func _core_loop_walk_line")[0]
    assert "VerbGrammar.mass_explore_walk()" in walk
    superpose = prog.split("func _superposition_walk_line")[1].split("func _core_loop_walk_line")[0]
    assert "VerbGrammar.mass_strike_walk()" in superpose
    assert 'return "▸ [F] Explore"' in superpose
    assert 'return "▸ [0] Druid"' in superpose
    assert superpose.index("mass_strike_walk()") < superpose.index('return "▸ [0] Druid"')
    assert superpose.index('return "▸ [F] Explore"') < superpose.index('return "▸ [0] Druid"')
    g = src("UI/Core/VerbGrammar.gd")
    assert "func mass_strike_walk" in g
    assert 'MASS_STRIKE_WALK := "▸ SHIFT [R] to multi strike"' in g
    verb = prog.split("static func _verb_line(")[1].split("static func ")[0]
    assert "_reap_season_walk_line" in verb
    mill = prog.split("func _reap_season_walk_line")[1].split("func _superposition_walk_line")[0]
    assert "VerbGrammar.mass_mark_walk()" in mill
    assert "VerbGrammar.mass_explore_walk()" in mill
    assert "VerbGrammar.reap_walk()" in mill
    assert "_unbound_plot_count" in mill
    target = prog.split("static func objective_target()")[1].split("static func _hat_key_for_frame")[0]
    assert '"REAP"' in target
    assert "_unbound_plot_count" in target
    probe = src("Core/Actions/ProbeActions.gd")
    closed = probe.split("func _closed_reap_rewards")[1].split("func _count_explored_registers")[0]
    assert "is_register_bound" in closed
    assert "revealed_plots" not in closed
    assert "explored registers" in closed
