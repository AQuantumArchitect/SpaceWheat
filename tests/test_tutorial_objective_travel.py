"""The Act-0 objective line must name a key, and must change when you obey it.

Found by running the literalist and the lost-lamb through a fresh Act 0 on the
same day: both walled at tutorial step 1, independently, for two halves of one
defect.

  - The step's mechanic happens in StarterForest, and the hint opened with
    "Cross to StarterForest." Once the player HAD crossed, the banner still
    said it — so the literalist read a standing order it had already obeyed,
    and the lost-lamb (which re-derives the objective every single turn and
    holds no memory of having crossed) reported LOOPING.
  - `objective_target()` already knew better: it pulses the biome tab before
    the verb chip. Only the TEXT was state-blind. Two halves of one guidance
    system, one of them lying.

The repair moves travel out of authored prose and onto the step's own `biome`
field, which both channels now read. These tests pin that the prose does not
grow the duplicate back.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ARC = ROOT / "Core/Quests/data/tutorial_arc.json"
PROGRESSION = ROOT / "UI/Core/UIProgression.gd"
QII = ROOT / "UI/Core/QuantumInstrumentInput.gd"

BIOME_NAMES = ("TheDemos", "StarterForest", "Village")


def steps() -> list:
    return json.loads(ARC.read_text(encoding="utf-8"))["steps"]


def max_chars() -> int:
    m = re.search(r"OBJECTIVE_MAX_CHARS\s*:=\s*(\d+)", PROGRESSION.read_text(encoding="utf-8"))
    assert m, "OBJECTIVE_MAX_CHARS moved — this test reads it rather than hardcoding"
    return int(m.group(1))


def test_travel_is_derived_from_the_step_biome_not_written_into_prose() -> None:
    src = PROGRESSION.read_text(encoding="utf-8")
    assert "func _travel_line(" in src, (
        "the banner must lead with 'cross to <biome>' when the step's mechanic "
        "is somewhere the player isn't"
    )
    body = src.split("static func _travel_line(")[1].split("\nstatic func ")[0]
    assert 'get("biome"' in body, "travel must read the step's own biome field"
    assert "get_active_biome()" in body, (
        "and compare it against where the player actually stands, or the line "
        "never changes — which is the LOOPING defect this fixes"
    )
    assert '"TUTORIAL"' in body, (
        "scoped to TUTORIAL: arc quests carry biomes per-predicate and already "
        "resolve targets through PredicateGloss. A second, coarser travel rule "
        "for them would be the parallel authority UIProgression exists to avoid."
    )
    assert "tap %s's orb" not in src, (
        "travel must name the key, not 'tap the orb' — keyboard players "
        "could not follow that (wave 4 mill-chip class)"
    )
    assert "[%s] crosses to %s" in src
    assert 'return "▸ ESC closes"' in src, (
        "while a menu is open name ONLY ESC — do not also print [U] "
        "(wave 7: 'ESC then [U]' still left [U] COMMITMENTS as a second job)"
    )
    assert "player_shell" in src, (
        "menu-open must find PlayerShell via its group — find_child(OverlayManager) "
        "misses the runtime instance (wave 5 literalist still saw dual-[U])"
    )


def test_superpose_and_bell_name_the_verb_key() -> None:
    """Wave 5: Superpose named no key. Wave 6: `[E] Superpose` while Ace
    still labels `[E] Pause` is the dual-key wall.

    Name the hat first (`[0] Druid` / `[9] Operator`). After they wear it,
    name the verb (`[E]` Superpose). Bell is a walk: mark two plots, then
    `[R] Gate` (the chip), then `[Q] Bell` (submenu Q, not R — R is CZ).
    Authored tutorial_hint stays English.
    """
    src = PROGRESSION.read_text(encoding="utf-8")
    assert "func _verb_line(" in src, (
        "after travel, the banner must name Superpose/Bell"
    )
    body = src.split("static func _verb_line(")[1].split("\nstatic func ")[0]
    assert "tutorial_step" in body
    assert "step != 3" in body and "step != 4" in body
    assert "step != 5" in body or "Shift+F" in body
    assert "get_current_frame" in body, (
        "must read the worn hat — naming [E] on Ace collides with Pause"
    )
    assert "HAT_KEY_TO_FRAME" in body
    assert "[%s] %s" in body
    assert "[Q] Bell" in body, "once Gate is open, Bell is on Q — not R"
    assert "[R] Gate" in body, "Operator R is Gate, never Weave"
    assert "Shift+G then Shift+H" in body, "name the mark before Gate"
    assert "[R] Weave" not in body
    hints = {int(s["tutorial_step"]): s.get("tutorial_hint", "") for s in steps()}
    assert hints[3] == "Superpose a forest plot."
    assert "E" not in hints[3] and "[0]" not in hints[3]
    assert hints[4] == "Weave two plots into one Bell pair."
    assert "[R]" not in hints[4]


def test_ace_never_does_druid_things() -> None:
    """No back doors: Ace E pauses. Superpose is Druid E. The banner names
    the hat, then the verb — the player walks it."""
    qii = (ROOT / "UI/Core/QuantumInstrumentInput.gd").read_text(encoding="utf-8")
    assert "_maybe_wear_live_hat" not in qii
    ace = (ROOT / "Core/UI/AceChipResolvers.gd").read_text(encoding="utf-8")
    assert "func resolve_e" not in ace
    assert "reap_season" not in ace
    druid = (ROOT / "Core/GameState/ToolConfig.gd").read_text(encoding="utf-8")
    assert '"label": "Superpose"' in druid
    assert '"label": "H-Gate"' not in druid
    assert '"label": "Pause"' in druid
    # Operator R is Gate, always. Do not relabel it Weave (that would be a
    # lying advertisement — R opens a picker, Q applies Bell).
    assert '"label": "Gate"' in druid
    assert '"label": "Weave"' not in druid


def test_marking_a_plot_speaks() -> None:
    """Wave 7 lost-lamb looped Shift+G: check had no screen_text. Toast the
    mark. Refresh Gate if it is already open so Bell appears on Q."""
    qii = QII.read_text(encoding="utf-8")
    body = qii.split("func toggle_check(")[1].split("\nfunc ")[0]
    assert "_toast_player" in body
    assert "marked" in body
    assert "_refresh_gate_submenu_if_open" in body
    assert "_refresh_objective_chrome" in body
    assert "enter_submenu" in qii.split("func _refresh_gate_submenu_if_open")[1].split("\nfunc ")[0]
    chrome = qii.split("func _refresh_objective_chrome")[1].split("\nfunc ")[0]
    assert "objective_chrome" in chrome
    assert "force_refresh" in chrome
    filament = (ROOT / "UI/Widgets/ActFilament.gd").read_text(encoding="utf-8")
    assert "func force_refresh" in filament
    assert 'add_to_group("objective_chrome")' in filament


def test_gate_empty_chip_names_how_to_check_two_plots() -> None:
    """Wave 6: Gate UI Q said 'Select 2+ qubits' but Q is disabled.
    The mark is Shift-click / Shift+G H. Name that, not a fake Q verb.
    """
    gate = (ROOT / "UI/Core/Submenus/GateSelectionSubmenu.gd").read_text(
        encoding="utf-8"
    )
    assert "Select 2+ qubits" not in gate, (
        "Q must not look like the select verb"
    )
    assert "Shift+G H" in gate
    assert "Shift-click" in gate


def test_opening_a_menu_flattens_field_toasts() -> None:
	"""w37: Market [R] Accept vs sticky 'R plants'. Overlay open → flatten."""
	om = (ROOT / "UI/Managers/OverlayManager.gd").read_text(encoding="utf-8")
	open_fn = om.split("overlay_changed.emit")[1].split("return true")[0]
	assert "flatten_all_toasts" in open_fn
	shell = (ROOT / "UI/PlayerShell.gd").read_text(encoding="utf-8")
	assert "func flatten_all_toasts" in shell


def test_wandered_off_banner_names_the_door_back() -> None:
    """Toast/banner must not dump the in-room recipe while the player is
    looking at the wrong menu. Name ESC (or the hat, or the rail) first."""
    src = PROGRESSION.read_text(encoding="utf-8")
    assert "func _wrong_room_line(" in src
    empty = src.split("static func _empty_plot_key(")[1].split("\nstatic func ")[0]
    assert "_plot_bound" in empty, (
        "w51: empty-plot key named J while Village J was a live qubit — "
        "Plant refused, Track first (F) was the chip"
    )
    plant = src.split("static func _plant_walk_line(")[1].split("\nstatic func ")[0]
    assert "_wrong_room_line" in plant
    assert '"▸ [5] Icon"' in plant or "▸ [5] Icon" in plant
    assert "action_cue" in plant
    assert "FRAME_ICON" in plant
    assert "empty plot, [R]" not in plant
    assert "_cross_to" in plant
    assert "_plant_target_biome" in plant
    assert "_plant_atom_seated" in plant
    assert "[X] then Arc [I]" in plant
    assert "Ace to free a plot" in plant
    assert "gather to empty a plot" in plant
    empty = src.split("static func _empty_plot_key(")[1].split("\nstatic func ")[0]
    assert "fallback >= 6" in empty
    ask = src.split("static func _is_plant_ask(")[1].split("\nstatic func ")[0]
    assert "atom_in_biome" in ask
    verb = src.split("static func _verb_line(")[1].split("\nstatic func ")[0]
    assert "_wrong_room_line" in verb
    eagle = src.split("static func _eagle_gather_line(")[1].split("\nstatic func ")[0]
    assert "lantern_well_live" in eagle.split("var have")[0], (
        "eagle walk named Forest before 🧺 — Forest↔Village ping-pong"
    )
    assert eagle.find("_plot_measured") < eagle.find("ace_f_would_explore"), (
        "w157: measured 🦅 named [F] Explore; F cleared the strike"
    )
    assert 'want = "H"' in eagle
    assert "pick a sleeping" not in eagle
    assert "[Q] clear" in eagle
    assert "hold_lamp_live" in src
    assert "_hold_lamp_walk_line" in src
    assert "lantern_bridge_live" in src
    assert "teaching_claim_live" in src
    assert "_sig_has" in src
    assert "_bridge_seated" in src
    assert "knot_live" in src
    assert "_is_spinor_ask" in src
    assert "sixteen_live" in src
    assert "[2] 🪞" in src
    assert "stay-home on" in src
    assert "_horn_walk_line" in src
    disc = src.split("static func _discover_walk_line(")[1].split("\nstatic func ")[0]
    assert "is_hat_visible" in disc
    ace_f = src.split("static func ace_f_would_explore(")[1].split("\nstatic func ")[0]
    assert "_is_horn_ask" in ace_f
    gate = (ROOT / "Core/Instrumentation/Handlers/GateActionHandler.gd").read_text(encoding="utf-8")
    apply = gate.split("func _apply_single_qubit_gate(")[1].split("\nfunc ")[0]
    assert "stale_biome" in apply
    assert "is_inside_tree" in apply
    batcher = (ROOT / "Core/Environment/BiomeEvolutionBatcher.gd").read_text(encoding="utf-8")
    inv = batcher.split("func invalidate_biome_buffer(")[1].split("\nfunc ")[0]
    assert "_prime_single_biome_frozen" in inv
    assert "refill_mi_after_two_qubit" in batcher
    qii = (ROOT / "UI/Core/QuantumInstrumentInput.gd").read_text(encoding="utf-8")
    assert "_deferred_hadamard" in qii
    assert "_select_frame_hat_now" in qii
    assert "_select_biome_now" in qii
    assert 'call_deferred("_toggle_check_at_plot_idx"' in qii or "call_deferred(\"_toggle_check_at_plot_idx\"" in qii
    farm_src3 = (ROOT / "Core/Farm.gd").read_text(encoding="utf-8")
    assert "last_removed_biome" in farm_src3
    cull = farm_src3.split("func first_cull_candidate(")[1].split("\nfunc ")[0]
    assert 'biome_name == "BloodLedger"' in cull
    rem = farm_src3.split("func remove_biome(")[1].split("\nfunc ")[0]
    assert "biome.queue_free" not in rem
    assert "call_deferred" not in rem
    assert "biome.visible = false" in rem
    can = farm_src3.split("func can_remove_biome(")[1].split("\nfunc ")[0]
    assert "BloodLedger" in can
    pump = farm_src3.split("func _pump_for_icon(")[1].split("\nfunc ")[0]
    assert "str(owner)" not in pump
    assert "lex == null" in pump
    inc = (ROOT / "Core/Instrumentation/QuantumInstrument.gd").read_text(encoding="utf-8")
    track = (ROOT / "UI/Core/QuantumInstrumentInput.gd").read_text(encoding="utf-8")
    tog = track.split("func _execute_toggle_berry_track(")[1].split("\nfunc ")[0]
    assert "Shift+F drops the loop" in tog
    assert "loop is ripe — R Incorporate" in tog
    body = inc.split("func action_incorporate(")[1].split("\nfunc ")[0]
    assert body.find("berry_register.consume") < body.find("discover_icon(north, south)")
    assert "north_taken" in body
    assert body.find("north_taken") < body.find("berry_register.consume")
    discov = farm_src3.split("func discover_biome(")[1].split("func remove_biome(")[0]
    assert "if not pool.is_empty():" not in discov
    assert "Just culled that country" in discov
    press = src.split("static func _pressured_discover_name(")[1].split("\nstatic func ")[0]
    assert "last_removed_biome" in press
    spinor_fn = src.split("static func _spinor_walk_line(")[1].split("\nstatic func ")[0]
    assert "home_q < 0" in spinor_fn
    qb = (ROOT / "UI/Overlays/QuestBoard.gd").read_text(encoding="utf-8")
    short = qb.split("func fill_shortfall_cue(")[1].split("\nfunc ")[0]
    assert "have < need" in short
    assert "VERB_ABANDON" not in short or "gather" in short
    sixteen = src.split("static func _sixteen_walk_line(")[1].split("\nstatic func ")[0]
    assert "_ledger_walk_line" in sixteen
    assert "BloodLedger" in sixteen
    assert "_cull_walk_line()" not in sixteen
    assert "_eagle_gather_line" not in sixteen
    spinor = src.split("static func _spinor_walk_line(")[1].split("\nstatic func ")[0]
    assert '_overlay_open("quests")' in spinor
    assert "_claim_walk_line" in spinor
    assert "traveler" in spinor
    assert "get_mirror_reference" in spinor
    assert "register_id" in spinor
    assert "[X] then Arc [I]" in spinor
    sixteen = src.split("static func sixteen_live(")[1].split("\nstatic func ")[0]
    assert "_is_spinor_ask" in sixteen
    farm_src2 = (ROOT / "Core/Farm.gd").read_text(encoding="utf-8")
    assert "func _reseat_unslotted_lanternfall(" in farm_src2
    assert "_reseat_unslotted_lanternfall()" in farm_src2.split("func discover_biome(")[1].split("\nfunc ")[0]
    farm_src = (ROOT / "Core/Farm.gd").read_text(encoding="utf-8")
    cull = farm_src.split("func first_cull_candidate(")[1].split("\nfunc ")[0]
    assert 'biome_name == "Lanternfall"' in cull
    qii = (ROOT / "UI/Core/QuantumInstrumentInput.gd").read_text(encoding="utf-8")
    struck = qii.split("Find Lanternfall: struck")[0]
    assert "if UIProgression.lantern_well_live()" in struck[-600:]
    knot_fn = src.split("static func knot_live(")[1].split("\nstatic func ")[0]
    assert "_is_knot_ask" in knot_fn
    assert "the_span" in knot_fn
    detail = src.split("static func objective_detail(")[1].split("\nstatic func ")[0]
    assert "knot_live" in detail
    bridge = src.split("static func lantern_bridge_live(")[1].split("\nstatic func ")[0]
    assert "return _flag_fired(\"lantern_teaching\") and not _bridge_seated()" in bridge
    lamp = src.split("static func _hold_lamp_walk_line(")[1].split("\nstatic func ")[0]
    assert "[F] Explore" in lamp
    assert lamp.find("_plot_bound") < lamp.find("[E] Superpose")
    assert "_claim_walk_line" in lamp
    well = src.split("static func lantern_well_live(")[1].split("\nstatic func ")[0]
    assert 'chain_ends' in well
    mill = json.loads((ROOT / "Core/Quests/data/story_flags.json").read_text(encoding="utf-8"))
    wakes = next(f for f in mill if f.get("id") == "mill_wakes")
    atoms = [p.get("atom") for p in wakes.get("arc_quest", {}).get("state_predicates", []) if p.get("type") == "biome_state_gte"]
    assert "💨" in atoms
    assert "⚙" not in atoms
    attr = [p.get("emoji") for p in wakes.get("arc_quest", {}).get("state_predicates", []) if p.get("type") == "biome_attractor_emoji_gte"]
    assert "💨" in attr
    assert "⚙" not in attr
    qm_src = (ROOT / "Core/Quests/QuestManager.gd").read_text(encoding="utf-8")
    gte = qm_src.split('"biome_state_gte":')[1].split('"biome_state_lte"')[0]
    assert "export_bloch_packet" in gte
    assert "psum" in gte
    qc = (ROOT / "Core/QuantumSubstrate/QuantumComputer.gd").read_text(encoding="utf-8")
    attr_fn = qc.split("func get_attractor_state(")[1].split("\nfunc ")[0]
    assert 'out.has("💨")' in attr_fn
    assert 'out["⚙"]' in attr_fn
    gte_attr = qm_src.split('"biome_attractor_emoji_gte":')[1].split('"biome_eigenvalue_gap_gte"')[0]
    assert 'emoji_a == "⚙"' in gte_attr
    obj = src.split("static func objective_text()")[1].split("static func ")[0]
    assert obj.find("hold_lamp_live") < obj.find("_eagle_gather_line"), (
        "w160-r2: Hold the Lamp drowned in 🦅 18/21 after chain_ends minted"
    )
    detail = src.split("static func objective_detail(")[1].split("\nstatic func ")[0]
    assert "_is_discover_ask" in detail
    assert "_biome_has_atoms" in src
    disc = src.split("static func _is_discover_ask")[1].split("static func ")[0]
    assert "_biome_has_atoms" in disc
    atoms = src.split("static func _biome_has_atoms")[1].split("static func ")[0]
    assert "atom_count_in" in atoms
    assert "num_qubits" not in atoms
    assert "lantern_well_live" in detail
    waiting = src.split("static func _unsigned_arc_waiting(")[1].split("\nstatic func ")[0]
    assert "_unsigned_discover_offer" in waiting
    decorate = src.split("static func _decorate_objective(")[1].split("\nstatic func ")[0]
    story = decorate.split("Quest.STATUS_STORY")[1].split("if status == \"ready\"")[0]
    assert "_discover_walk_line" in story
    disc = src.split("static func _discover_walk_line(")[1].split("\nstatic func ")[0]
    assert "_wrong_room_line" in disc
    assert '"▸ [7] Captain"' in disc or "▸ [7] Captain" in disc
    assert "_cull_walk_line" in disc
    assert "_pressured_discover_name" in disc
    assert "Add Biome —" in disc
    cull = src.split("static func _cull_walk_line(")[1].split("\nstatic func ")[0]
    assert "has_open_biome_slot" in cull
    assert "first_cull_candidate" in cull
    assert "[Q] cull" in cull
    assert "slots full" in cull
    assert "_cross_to" in cull
    assert "Forest not in TYUIOP" in src
    ot = src.split("static func objective_text(")[1].split("static func ")[0]
    assert "lantern_well_live" in ot
    assert "lantern_door_fired" in ot
    assert "_eagle_short" in ot
    fil = (ROOT / "UI/Widgets/ActFilament.gd").read_text(encoding="utf-8")
    assert "is_overlay_active" not in fil.split("func _process")[1].split("func ")[0]
    assert "not in TYUIOP" in src.split("static func _cross_to(")[1].split("\nstatic func ")[0]
    gloss = (ROOT / "Core/Quests/PredicateGloss.gd").read_text(encoding="utf-8")
    evolving = gloss.split('"biome_evolving":')[2].split('"active_biome_is":')[0]
    returns = [ln for ln in evolving.splitlines() if "return " in ln]
    assert returns, evolving
    spoken = "\n".join(returns)
    assert "[7]" not in spoken
    assert "Add Biome" not in spoken
    assert "still dark" in spoken
    assert "has_pending_confirm" in cull
    assert "[F] confirm" in cull
    assert "func _instrument_input(" in src
    farm_src = (ROOT / "Core/Farm.gd").read_text(encoding="utf-8")
    assert "func first_cull_candidate(" in farm_src
    assert "cull %s first" in farm_src
    assert "first_pressured" in farm_src.split("func discover_biome(")[1].split("func remove_biome(")[0]
    chips = (ROOT / "UI/Managers/UIContextController.gd").read_text(encoding="utf-8")
    assert "cull first" in chips
    assert "discover_biome" in chips.split("func _build_frame_actions")[1].split("func _build_submenu_actions")[0]
    forecast = (ROOT / "Core/Gameplay/BiomeDiscoveryForecastService.gd").read_text(encoding="utf-8")
    assert "flag_door_is_resolved" in forecast
    assert "story_offers" in forecast
    assert "func _quest_biome(" in forecast
    assert "func first_pressured(" in forecast
    pressure = forecast.split("static func _biomes_under_pressure")[1].split("static func _quest_biome")[0]
    assert "flag_door_is_resolved" in pressure
    assert "if src != \"\" and fired.has(src):" not in pressure
    assert "BloodLedger" in forecast.split("static func _biomes_under_pressure")[1].split("static func first_pressured")[0]
    sixteen = src.split("static func _sixteen_walk_line(")[1].split("\nstatic func ")[0]
    assert "Add Biome — %s" in sixteen or "Add Biome —" in sixteen
    assert "_cull_walk_line()" not in sixteen
    ledger = src.split("static func _ledger_walk_line(")[1].split("\nstatic func ")[0]
    assert "BloodLedger" in ledger
    assert "[R] Incorporate" in ledger
    disc = src.split("static func _discover_walk_line(")[1].split("\nstatic func ")[0]
    assert "_ledger_walk_line" in disc
    obj = src.split("static func objective_text(")[1].split("\nstatic func ")[0]
    assert "_ledger_walk_line" in obj
    assert "_overlay_stack_open()" in obj.split("if hold_lamp_live")[0]
    om = (ROOT / "UI/Managers/OverlayManager.gd").read_text(encoding="utf-8")
    assert "call_deferred(\"_close_overlay_now\")" in om or 'call_deferred("_close_overlay_now")' in om
    assert "call_deferred(\"_close_all_overlays_now\")" in om or 'call_deferred("_close_all_overlays_now")' in om
    berry = src.split("static func _berry_walk_line(")[1].split("\nstatic func ")[0]
    assert "_cross_to" in berry
    assert "[5] Icon" in berry
    assert "[F] tracks" in berry
    berry_ask = src.split("static func _is_berry_ask(")[1].split("\nstatic func ")[0]
    assert "berry_total_phase_gte" in berry_ask
    plant_ask = src.split("static func _is_plant_ask(")[1].split("\nstatic func ")[0]
    assert "mill_wakes" in plant_ask
    flags = json.loads((ROOT / "Core/Quests/data/story_flags.json").read_text(encoding="utf-8"))
    spiral = next(f for f in flags if f.get("id") == "spiral_breaks")
    spreds = [str(p.get("type")) for p in (spiral.get("predicates") or [])]
    assert "berry_consumed_count_gte" not in spreds, (
        "spiral_breaks FLAG required a second berry to mint the quest that "
        "asks for that berry — Arc stayed empty after First Breath"
    )
    listener = next(f for f in flags if f.get("id") == "forest_listener")
    lpreds = [str(p.get("type")) for p in (listener.get("predicates") or [])]
    assert "berry_consumed_count_gte" not in lpreds, (
        "forest_listener FLAG required berry 3 to mint the quest that asks "
        "for berry 3 — Arc emptied after Spiral Breaks claim"
    )
    communion = next(f for f in flags if f.get("id") == "forest_communion")
    cpreds = [str(p.get("type")) for p in (communion.get("predicates") or [])]
    assert "berry_consumed_count_gte" not in cpreds
    loop = next(f for f in flags if f.get("id") == "loop_remembers")
    rpreds = [str(p.get("type")) for p in (loop.get("predicates") or [])]
    assert "berry_consumed_count_gte" not in rpreds
    loop_hint = str((loop.get("arc_quest") or {}).get("hint", ""))
    loop_first = re.split(r"(?<=[.!?])\s", loop_hint)[0]
    assert "[5]" in loop_first and "[F]" in loop_first and "[R]" in loop_first, loop_first
    assert len(loop_first) <= max_chars(), loop_first
    mill = next(f for f in flags if f.get("id") == "mill_wakes")
    mill_hint = str((mill.get("arc_quest") or {}).get("hint", ""))
    mill_first = re.split(r"(?<=[.!?])\s", mill_hint)[0]
    assert "[5]" in mill_first and "Village" in mill_first, mill_first
    assert "Market" not in mill_first
    assert len(mill_first) <= max_chars(), mill_first
    lantern = next(f for f in flags if f.get("id") == "lantern_door")
    lantern_hint = str((lantern.get("arc_quest") or {}).get("hint", ""))
    lantern_first = re.split(r"(?<=[.!?])\s", lantern_hint)[0]
    assert "F reads" not in lantern_hint
    assert "[F]" not in lantern_first
    # w72: authored Captain [7][R] sat in front of the gold 🧺 walk.
    assert "[7]" not in lantern_hint
    assert "🧺" in lantern_hint
    assert "🦅" in lantern_hint
    assert "Forest" in lantern_hint
    assert len(lantern_hint) <= max_chars(), lantern_hint
    assert len(lantern_first) <= max_chars(), lantern_first
    chain = next(f for f in flags if f.get("id") == "chain_ends")
    cpreds = [str(p.get("type")) for p in (chain.get("predicates") or [])]
    assert "berry_consumed_count_gte" not in cpreds, (
        "chain_ends FLAG required a Lanternfall berry to mint Hold the Lamp — "
        "Arc stayed empty after Find Lanternfall claimed"
    )
    assert "biome_evolving" not in cpreds
    wakes = next(f for f in flags if f.get("id") == "spring_wakes")
    wpreds = [str(p.get("type")) for p in (wakes.get("predicates") or [])]
    assert "atom_in_biome" not in wpreds, (
        "w40: spring_wakes FLAG required 💧 already in the spring to mint "
        "Couple the Spring (plant 💧 in Village) — earnest never saw the door"
    )
    lwakes = next(f for f in flags if f.get("id") == "lantern_wakes")
    lwpreds = [str(p.get("type")) for p in (lwakes.get("predicates") or [])]
    assert "atom_in_biome" not in lwpreds, (
        "w53: lantern_wakes FLAG required 🌉 already in Lanternfall to mint "
        "Light the Bridge — Arc emptied after Teaching claim"
    )
    cross = src.split("static func _cross_to(")[1].split("\nstatic func ")[0]
    assert "biome [%s]" in cross
    assert 'key == "Y"' in cross
    assert "func _is_knot_ask(" in src
    assert "func _knot_walk_line(" in src
    knot = src.split("static func _knot_walk_line(")[1].split("\nstatic func ")[0]
    assert "[X] then Arc [I]" in knot
    assert "[5] Icon" in knot
    assert "[0] Druid" not in knot
    compass = src.split("static func _compass_walk_line(")[1].split("\nstatic func ")[0]
    assert "_cross_to" in compass
    assert "_claim_walk_line" in compass
    assert "[P] Graph" not in compass
    assert "[M] Map" not in compass
    assert "ESC then" not in compass


def test_no_hint_hardcodes_a_journey() -> None:
    for s in steps():
        hint = str(s.get("tutorial_hint", ""))
        assert not re.search(r"\bCross to\b", hint, re.I), (
            "step %s still writes the journey into its prose; the banner "
            "derives it from `biome` now, and two copies drift: %r"
            % (s.get("tutorial_step"), hint)
        )


def test_a_hint_never_names_a_biome_other_than_its_own() -> None:
    """Step 5 declared biome=StarterForest while instructing the player to
    gather 'on TheDemos'. The spotlight reads `biome`, so the cue pointed at
    one country while the words named another."""
    for s in steps():
        own = str(s.get("biome", ""))
        hint = str(s.get("tutorial_hint", ""))
        for name in BIOME_NAMES:
            if name in hint:
                assert name == own, (
                    "step %s says %r in its hint but declares biome=%r — the "
                    "spotlight would pulse one tab while the text names another"
                    % (s.get("tutorial_step"), name, own)
                )


def test_every_hint_leads_with_a_sentence_the_banner_can_show_whole() -> None:
    """The banner truncates at OBJECTIVE_MAX_CHARS, cutting at a sentence
    boundary when one exists. So the FIRST sentence must fit and must stand on
    its own — otherwise the one line a player actually reads is a stump."""
    limit = max_chars()
    for s in steps():
        hint = str(s.get("tutorial_hint", "")).strip()
        if hint == "":
            continue
        first = re.split(r"(?<=[.!?])\s", hint)[0]
        assert len(first) <= limit, (
            "step %s's first sentence is %d chars, over the %d-char banner: "
            "it will be cut mid-clause and read as a broken instruction. %r"
            % (s.get("tutorial_step"), len(first), limit, first)
        )


def test_focusing_empty_ground_is_not_silent() -> None:
    """The other half of the same stall. Act 0 says "Pick a plot with G H J K L ;"
    while the starting biome has ONE register, so H..; move the cursor onto
    register-less ground. Under the 3D renderer that move is invisible: no orb
    exists there, and PlotGridDisplay — which would have drawn the selected tile
    — is hidden (visible == false), so set_selected_plot() paints nothing. The
    state really changed (F would explore the new plot), and the screen did not."""
    body = QII.read_text(encoding="utf-8").split("func _focus_plot(")[1].split("\nfunc ")[0]
    assert "_get_active_biome_register_count()" in body, (
        "_focus_plot must know whether the plot it just focused has a live "
        "register — that is what decides if anything is visible there"
    )
    assert "RefusalVoice" in body, (
        "a focus move onto empty ground must SPEAK. It lands with zero on-screen "
        "change otherwise, and a silent state change is what the anti-gating law "
        "exists to forbid."
    )


def test_act0_teaches_no_berry_ritual() -> None:
    """The 2026-08-17 reorder: berry phase is mid-game content ('we're not
    trying to teach a physics class' — owner). Act 0 must contain no track/
    incorporate step, and no tutorial gate may ask for signature growth —
    both walls the 2026-08-10 playtest personas hit in the first two minutes."""
    for s in steps():
        assert str(s.get("tutorial_teaches", "")) not in ("vocabulary", "vocab_escape"), (
            "the berry/vocabulary steps moved to the act-3 chapter "
            "(first_breath, story_flags.json) — they must not regrow here"
        )
        for p in s.get("state_predicates", []) or []:
            assert str(p.get("type", "")) not in (
                "signature_size_gte", "signature_growth_gte",
                "berry_consumed_count_gte", "berry_total_phase_gte",
            ), (
                "step %s gates on the berry/signature ritual — that is mid-game "
                "content now" % s.get("tutorial_step")
            )


def test_the_incorporation_teaching_survives_the_banner_and_names_the_wait() -> None:
    """Incorporating an icon is press-5 → F → WAIT → R. The wait is the part a
    player cannot guess, and the original hint omitted it entirely, so both
    personas fell back on the explore/strike verbs they already knew and got
    nowhere. The teaching now lives on the act-3 beat `first_breath`
    (story_flags.json) — same banner physics apply: the first sentence is what
    a player actually reads (arc hints sentence-cut at OBJECTIVE_MAX_CHARS),
    and it must name the hat, the tracking verb, and the honest wait."""
    flags = json.loads((ROOT / "Core/Quests/data/story_flags.json").read_text(encoding="utf-8"))
    fb = next((f for f in flags if f.get("id") == "first_breath"), None)
    assert fb is not None, "first_breath (the incorporation teaching) is missing"
    flag_preds = [str(p.get("type")) for p in (fb.get("predicates") or [])]
    assert "berry_consumed_count_gte" not in flag_preds, (
        "w37: first_breath's FLAG required a berry to mint the quest that "
        "asks for a berry — Arc stayed empty after the spring chapter"
    )
    assert int(fb.get("act", -1)) >= 3, (
        "first_breath is the berry chapter's opener — mid-game (act 3+), never "
        "the on-ramp (the 2026-08-17 reorder)"
    )
    hint = str((fb.get("arc_quest") or {}).get("hint", ""))
    first = re.split(r"(?<=[.!?])\s", hint)[0]
    assert len(first) <= max_chars(), (
        "first_breath's hint lead is %d chars, over the %d-char banner — the one "
        "line a player reads would be a stump" % (len(first), max_chars())
    )
    assert "5" in first, "the lead must name the Icon hat key"
    assert re.search(r"\bF\b", first), "the lead must name the tracking verb F"
    assert re.search(r"\bR\b", hint), "the hint must name R (incorporate)"
    assert re.search(r"wait|orbit|ripe|clock|⏩", hint, re.I), (
        "must name the TIME beat — the loop ripens in real time, and that is the "
        "only step of the ritual that isn't a key press."
    )
    assert "90" in hint, (
        "must carry the honest duration: two legs measured ~90s at ×1, and the "
        "old authored '~30s'/'half a minute' was simply wrong"
    )
