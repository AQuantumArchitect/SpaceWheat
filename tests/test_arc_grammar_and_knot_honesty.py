"""Copy + Arc feeding pins from overnight hunter (w240–w242).

Contracts must not send players to Guide [I]. Keyboard X lands Arc [Y].
Diagnostic winding with an open lift must not complete Wind Twice.
Leftover Plant the Mill must not sit on Arc NOW after The Knot memoir.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def src(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def test_contracts_name_arc_y_not_guide_i() -> None:
    board = src("UI/Overlays/QuestBoard.gd")
    gloss = src("Core/Quests/PredicateGloss.gd")
    rooms = src("UI/Core/SurfaceRooms.gd")
    assert "[X→I]" not in board
    assert "Arc X→I" not in gloss
    assert "SurfaceRooms.walk_open_offers" in board
    assert 'return "▸ [X] then Arc [%s]" % KEY_OFFERS' in rooms
    assert 'KEY_OFFERS := "Y"' in rooms
    assert 'KEY_INFO := "I"' in rooms


def test_keyboard_x_lands_arc() -> None:
    overlay = src("UI/Overlays/ControlsOverlay.gd")
    activate = overlay.split("func _on_activated()")[1].split("\nfunc ")[0]
    assert "_current_tab = Tab.ARC" in activate
    assert "Tab.SELF" not in activate


def test_ace_f_fast_fwd_when_berry_tracked() -> None:
    prog = src("UI/Core/UIProgression.gd")
    explore = prog.split("static func ace_f_would_explore()")[1].split("\nstatic func ")[0]
    assert "_berry_tracking()" in explore
    berry = prog.split("static func _berry_walk_line(")[1].split("\nstatic func ")[0]
    assert "[F] Fast-Fwd" in berry
    assert "wait — loop ripens" not in berry
    knot = prog.split("static func _knot_walk_line(")[1].split("\nstatic func ")[0]
    assert "[F] Fast-Fwd" in knot
    assert "past first ripe" in knot
    assert "[R] Incorporate" not in knot
    knot_live = src("UI/Core/UIProgression.gd").split("static func knot_live(")[1].split("\nstatic func ")[0]
    assert "var door: Dictionary = IntroVoice.live_door()" not in knot_live
    assert "_knot_predicates_open" in knot_live
    text = src("UI/Core/UIProgression.gd").split("static func objective_text()")[1].split("static func ")[0]
    assert "knot_live() or sixteen_live()" in text
    assert "_knot_chapter_live()" in text
    assert "_ready_knot_quest" in text
    banner = src("UI/Core/UIProgression.gd").split("static func _banner_quest()")[1].split("static func ")[0]
    assert "_knot_chapter_live()" in banner
    claim = src("UI/Core/UIProgression.gd").split("static func _claim_walk_line(")[1].split("static func ")[0]
    assert "Charge [U]" in claim
    assert "_is_knot_ask" in claim
    target = src("UI/Core/UIProgression.gd").split("static func objective_target()")[1].split("static func _hat_key_for_frame")[0]
    assert 'FRAME_ICON' in target
    assert "_hat_key_for_frame(\"druid\")" not in target.split("if knot_live()")[1].split("var best")[0]
    knot_walk = src("UI/Core/UIProgression.gd").split("static func _knot_walk_line(")[1].split("\nstatic func ")[0]
    assert "IntroVoice.live_door()" not in knot_walk
    assert "_knot_predicates_open" in knot_walk
    sixteen = src("UI/Core/UIProgression.gd").split("static func sixteen_live(")[1].split("\nstatic func ")[0]
    assert "_knot_predicates_open" in sixteen
    charge = src("Core/Quests/QuestManager.gd").split("func charge_quests(")[1].split("\nfunc ")[0]
    assert "_furthest_fired_story_act" in charge


def test_loops_linked_needs_closed_lifts() -> None:
    qm = src("Core/Quests/QuestManager.gd")
    block = qm.split('"biome_loops_linked":')[1].split('"biome_betti_gte":')[0]
    assert "closed_upstairs" in block
    assert "max_mutual_winding" in block
    assert "upstairs.size() < 2" in block


def test_unsigned_arc_now_prefers_later_act() -> None:
    intro = src("Core/Story/IntroVoice.gd")
    best = intro.split("static func _best_unsigned_offer(")[1].split("\nstatic func ")[0]
    assert "_campaign_past_tutorial()" in best
    assert "10000 -" in best
    assert "_furthest_fired_act" in best
    assert "_arc_behind_furthest" in best
    assert 'str(q.get("status", "")) != "story"' in best
    still = intro.split("static func _unsigned_still_open(")[1].split("\nstatic func ")[0]
    assert 'str(q.get("status", "")) == "story"' in still
    ahead = intro.split("static func doors_ahead(")[1].split("\nstatic func ")[0]
    assert "_arc_behind_furthest" in ahead
    live = intro.split("static func live_quest(")[1].split("\nstatic func ")[0]
    assert "_arc_behind_furthest" in live
    rank = intro.split("static func _quest_rank(")[1].split("\nstatic func ")[0]
    assert "_arc_behind_furthest" in rank
    hint = src("Core/Quests/data/story_flags.json")
    assert "Ace [F] Fast-Fwd" in hint
    assert "F tracks a fresh plot, ⏩ hurries" not in hint


def test_knot_save_reoffers_when_lifts_still_open() -> None:
    engine = src("Core/Story/StoryEngine.gd")
    try_fn = engine.split("func _try_offer_pair_less(")[1].split("\nfunc ")[0]
    assert "retract_completed_flag" in try_fn
    assert "_pair_less_still_open" in try_fn
    assert 'flag_id == "the_knot"' not in try_fn
    qm = src("Core/Quests/QuestManager.gd")
    assert "func retract_completed_flag" in qm
    loops = src("UI/Overlays/LoopCard.gd")
    assert "Ace [F] Fast-Fwd" in loops
    assert "a lift is still open upstairs (NAN, not failure)" not in loops


def test_hint_toast_stays_on_screen() -> None:
    shell = src("UI/PlayerShell.gd")
    toast = shell.split('_hint_toast_stack.name = "HintToastStack"')[1].split(
        "overlay_layer.add_child(_hint_toast_stack)", 1)[0]
    assert "-180.0" not in toast
    assert "_place_objective_column" in toast or "toast_column_bottom_offset" in shell
    filament = src("UI/Widgets/ActFilament.gd")
    assert "static func banner_bottom_offset" in filament
    assert "static func toast_column_bottom_offset" in filament
    assert "VIEWPORT_BOTTOM_FRACTION" in filament
    mount = src("Core/Boot/RuntimeMount.gd")
    assert "banner_bottom_offset" in mount
    assert "_place_objective_column" in mount


def test_accepted_arc_is_now_not_open() -> None:
    intro = src("Core/Story/IntroVoice.gd")
    beat = intro.split("static func beat_from_quest(")[1].split("\nstatic func ")[0]
    assert 'kind := "arc_quest" if unsigned else "live_tutorial"' in beat
    berry = src("Core/QuantumSubstrate/BerryPhaseRegister.gd")
    freeze = berry.split("var holonomy: float = omega * 0.5")[1].split("func frozen_loops")[0]
    assert "fiber_defect >= LIFT_CLOSE_EPS" in freeze
    overlay = src("UI/Overlays/ControlsOverlay.gd")
    acc = overlay.split("func _accept_arc_now(")[1].split("\nfunc ")[0]
    assert "active_quests.has(qid)" in acc


def test_knot_accept_is_not_a_handshake() -> None:
    hs = src("Core/Quests/QuestManager.gd").split("func _handshake_auto_claims(")[1].split("\nfunc ")[0]
    assert '"biome_loops_linked": true' in hs
    board = src("UI/Overlays/QuestBoard.gd")
    assert "func _mouse_hits_row" in board
    row_tap = board.split("func _on_row_gui_input(")[1].split("\nfunc ")[0]
    assert "_on_action_r()" in row_tap
    assert "and _row_confirm_armed" not in row_tap
    berry = src("Core/QuantumSubstrate/BerryPhaseRegister.gd")
    assert "Tracked stays tracked" in berry
    assert "dropped tracking at FPS 1). Tracked stays tracked.\n\t\t\t\tpass" in berry.replace("\r\n", "\n")
    assert "fiber_defect >= KnotRegister" not in berry
    assert "defect < KnotRegister" not in berry
    assert "const LIFT_CLOSE_EPS" in berry


def test_reap_cost_quiet_before_economy() -> None:
    bal = src("Core/GameMechanics/BalanceService.gd")
    getv = bal.split("static func get_tuning_value(")[1].split("\nstatic func ")[0]
    assert "economy == null" in getv
    seq = bal.split("static func get_reap_cost_sequence(")[1].split("\nstatic func ")[0]
    assert "sequence == null" in seq
    reap = src("UI/Widgets/ReapButton.gd")
    refresh = reap.split("func _refresh_cost(")[1].split("\nfunc ")[0]
    assert 'farm.economy == null' in refresh
