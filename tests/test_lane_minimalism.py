"""One job per surface — the 1D lane, no dual gold, no keymap-wall hints.

Playtest 2026-09-09: squeeze then re-inflate. These pins are the compiler
for the cut that should stop that cycle.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INTRO = ROOT / "Core" / "Story" / "IntroVoice.gd"
PROG = ROOT / "UI" / "Core" / "UIProgression.gd"
BANNER = ROOT / "UI" / "Widgets" / "ActFilament.gd"
ARC = ROOT / "UI" / "Overlays" / "ControlsOverlay.gd"
BOARD = ROOT / "UI" / "Overlays" / "QuestBoard.gd"
QM = ROOT / "Core" / "Quests" / "QuestManager.gd"
TUTORIAL = ROOT / "Core" / "Quests" / "data" / "tutorial_arc.json"
HANDOVER = ROOT / "Core" / "Quests" / "data" / "story_flags.json"


def src(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def test_lane_auto_accepts_all_tutorial_including_the_mill():
    text = src(QM)
    accepts = text.split("func _tutorial_auto_accepts")[1].split("\nfunc ")[0]
    assert '== "TUTORIAL"' in accepts
    claims = text.split("func _tutorial_auto_advances")[1].split("\nfunc ")[0]
    assert "state_predicates" in claims
    offer = text.split("func offer_tutorial_quest")[1].split("func _tutorial_auto_accepts")[0]
    assert "_tutorial_auto_accepts(q)" in offer


def test_auto_tutorial_has_no_toast():
    offer = src(INTRO).split("func toast_for_offer")[1].split("func flag_postcard")[0]
    assert "return {}" in offer.split("is_auto_tutorial")[1]
    assert "[X] then Arc [I]" in offer
    flag_fn = src(INTRO).split("func toast_for_flag")[1].split("func recap")[0]
    assert 'flag_data.has("arc_quest")' in flag_fn


def test_story_beats_do_not_stack_parallel_gold_cards():
    """Parallel-dev leftover: one door minted flag + offer + standing + Act-N
    + a boot keymap. One beat, one card (or a silent grant)."""
    intro = src(INTRO)
    flag_fn = intro.split("func toast_for_flag")[1].split("func recap")[0]
    assert "arc_quest" in flag_fn and "return {}" in flag_fn
    assert 'flag_data.has("predicates")' in flag_fn
    engine = src(ROOT / "Core" / "Story" / "StoryEngine.gd")
    grants = engine.split('flag_data.get("standing_grants"')[1].split("Arc quest")[0]
    assert "apply_standing_deltas" in grants and ", false)" in grants
    bridge = src(ROOT / "Core" / "Story" / "PlayerEventBridge.gd")
    assert "🎬" not in bridge
    assert "_maybe_announce_act_entry" not in bridge
    assert "_announced_offer_ids.clear()" in bridge
    assert "silent_auto_claims" in bridge
    qm = src(QM)
    assert "func silent_auto_claims" in qm
    assert "func _handshake_auto_claims" in qm
    assert "func flag_door_is_resolved" in qm
    assert "_handshake_auto_claims(quest_data)" in qm.split("func accept_quest")[1].split("func _finalize_quest_completion")[0]
    world = src(ROOT / "Core" / "Boot" / "WorldBuilder.gd")
    assert "top chips open the doors" not in world
    assert "show_hint" not in world.split("PostcardCapture.maybe_attach")[1].split("func ")[0]
    mount = src(ROOT / "Core" / "Boot" / "RuntimeMount.gd")
    assert 'show_hint("📮 Act' not in mount
    assert 'cap.capture("📮 Act' in mount


def test_banner_links_only_for_fill():
    prog = src(PROG)
    assert "static func banner_home" in prog
    home = prog.split("static func banner_home")[1].split("static func ")[0]
    assert '"commitments"' in home
    assert "open_controls_on_arc" not in home
    filament = src(BANNER)
    assert "open_board_on_commitments" in filament
    assert "has_scoot = false" in filament
    setup = filament.split("func setup")[1].split("func _process")[0]
    assert "open_controls_on_arc" not in setup


def test_act0_hints_are_the_ask_not_a_keymap():
    steps = json.loads(TUTORIAL.read_text(encoding="utf-8"))["steps"]
    by_teach = {s["tutorial_teaches"]: s for s in steps}
    assert by_teach["core_loop"]["tutorial_hint"] == "Strike a sleeping plot."
    assert by_teach["contracts"]["tutorial_hint"] == "Deliver 2× 🌾 to the mill."
    assert "StarterForest" in by_teach["wayfinding"]["tutorial_hint"]
    for s in steps:
        hint = s["tutorial_hint"]
        assert "GHJKL" not in hint
        assert "gold banner" not in hint
        assert "Ace hat" not in hint
        assert "number row" not in hint
        assert len(hint) <= 70


def test_handover_does_not_send_you_through_the_banner():
    flags = json.loads(HANDOVER.read_text(encoding="utf-8"))
    wheel = next(f for f in flags if f.get("id") == "arc_handover")
    hint = str(wheel.get("arc_quest", {}).get("hint", ""))
    assert "gold banner" not in hint
    assert "Arc" in hint
    assert len(hint) <= 70


def test_mill_apprentice_names_the_board_key():
    """Wave 8/9b: first post-intro door said 'Keep mill deliveries' with no
    key. Name [C] and Market [Y]. Do not accept or fill for them."""
    flags = json.loads(HANDOVER.read_text(encoding="utf-8"))
    mill = next(f for f in flags if f.get("id") == "village_stirs")
    hint = str(mill.get("arc_quest", {}).get("hint", ""))
    assert "[C]" in hint
    assert "[Y]" in hint
    assert len(hint) <= 70
    prog = src(PROG)
    assert "func _is_board_ask" in prog
    assert "standing_gte" in prog.split("func _is_board_ask")[1].split("func ")[0]
    assert "func _board_walk_line" in prog
    assert "func _board_ask_biome" in prog
    assert '"Village"' in prog.split("func _board_ask_biome")[1].split("func ")[0]
    assert "board_walk_cue" in prog
    assert "_live_board_faction" in src(BOARD)
    assert "func propose_faction_offers" in src(ROOT / "Core" / "Markets" / "MarketLattice.gd")
    assert "func fill_shortfall_cue" in src(BOARD)
    assert "[Q] Abandon" in src(BOARD)
    assert "func _claim_walk_line" in src(PROG)
    assert "func claim_walk_cue" in src(BOARD)
    assert "_offer_is_keepable" in src(BOARD)
    lattice = src(ROOT / "Core" / "Markets" / "MarketLattice.gd")
    assert "mini(amt, 8)" in lattice
    board = src(BOARD)
    assert "func _is_fill_stall" in board
    assert "func board_walk_cue" in board
    market = board.split("func _market_rows")[1].split("\nfunc ")[0]
    assert "_is_fill_stall" in market
    assert "[E] Refresh" in board
    cue = board.split("func board_walk_cue")[1].split("\nfunc ")[0]
    assert "_selected_index" in cue
    assert 'return "▸ [R] %s"' in cue


def test_commerce_walk_names_the_market_key():
    """mill_wakes Hold Commerce: banner named Village Icon [5] plant, not
    Market. Unsigned commerce still paints. Do not plant for them."""
    prog = src(PROG)
    assert "func _unsigned_board_offer" in prog
    assert "func _preds_still_open" in prog
    board = prog.split("func _is_board_ask")[1].split("\nstatic func ")[0]
    assert "biome_attractor_emoji_gte" in board
    assert "⚙" in board
    assert "biome_state_gte" in board
    text_fn = prog.split("static func objective_text()")[1].split("static func ")[0]
    assert "_is_board_ask(best)" in text_fn
    assert "_board_walk_line(best)" in text_fn
    banner = prog.split("static func _banner_quest()")[1].split("static func ")[0]
    assert "_unsigned_board_offer()" in banner
    assert banner.index("_unsigned_board_offer") < banner.index("_unsigned_plant_offer")
    target = prog.split("static func objective_target()")[1].split("static func ")[0]
    assert "_is_board_ask(best)" in target
    intro = src(INTRO)
    assert "func _unsigned_still_open" in intro
    best_fn = intro.split("func _best_unsigned_offer")[1].split("\nstatic func ")[0]
    assert "_unsigned_still_open" in best_fn
    flags = json.loads(HANDOVER.read_text(encoding="utf-8"))
    mill = next(f for f in flags if f.get("id") == "mill_wakes")
    aq = mill.get("arc_quest", {})
    hint = str(aq.get("hint", ""))
    assert "[C]" in hint
    assert "[Y]" in hint
    assert "⚙" in hint
    assert "[5]" not in hint
    assert "[R]" not in hint
    assert "plant" not in hint.lower()
    assert len(hint) <= 70
    assert "Millwright" in str(aq.get("faction", ""))
    walk = prog.split("func _board_walk_line")[1].split("\nstatic func ")[0]
    assert "Market [Y]" in walk


def test_berry_walk_names_one_first_breath_key():
    """first_breath live door: Farm/System/Story/Board + QERF named no key.
    Unsigned berry still paints. One next key, not a paragraph of F/=/R/X."""
    prog = src(PROG)
    assert "func _is_berry_ask" in prog
    assert "func _berry_walk_line" in prog
    assert "func _unsigned_berry_offer" in prog
    berry = prog.split("func _berry_walk_line")[1].split("\nstatic func ")[0]
    assert "[5]" in berry
    assert "[F] Track" in berry
    assert "[R] Incorporate" in berry
    assert "[G]" in berry
    assert "wait" in berry
    assert "⏩" not in berry
    assert "[=]" not in berry
    assert "[X]" not in berry
    text_fn = prog.split("static func objective_text()")[1].split("static func ")[0]
    assert "_is_berry_ask(best)" in text_fn
    assert "_berry_walk_line()" in text_fn
    home = prog.split("static func banner_home()")[1].split("static func ")[0]
    assert "_is_berry_ask(best)" in home
    banner = prog.split("static func _banner_quest()")[1].split("static func ")[0]
    assert "_unsigned_berry_offer()" in banner
    flags = json.loads(HANDOVER.read_text(encoding="utf-8"))
    breath = next(f for f in flags if f.get("id") == "first_breath")
    hint = str(breath.get("arc_quest", {}).get("hint", ""))
    assert "[5]" in hint
    assert "[F]" in hint
    assert "[R]" in hint
    assert "90" in hint
    assert len(hint) <= 70
    assert "⏩" not in hint


def test_plant_walk_names_the_icon_hat_key():
    """Wave 11: 'Icon hat (5)' named no bracketed key. Derive [5] then [R].
    Do not plant for them. Unaffordable picker axes name the cost."""
    prog = src(PROG)
    assert "func _is_plant_ask" in prog
    assert "func _plant_walk_line" in prog
    plant = prog.split("func _plant_walk_line")[1].split("\nstatic func ")[0]
    assert "[5]" in plant
    assert "[R]" in plant
    assert "_empty_plot_key" in prog
    assert "_sprout_gather_line" in prog
    assert "StarterForest" in prog
    assert "never call that a" in prog or "🐺" in prog
    assert "[8] Ace" in prog
    assert "[Q] gather" in prog
    assert "_sprout_short" in prog
    assert "ace_f_would_explore" in prog
    assert "_plot_bound" in prog
    toast = src(ROOT / "UI" / "Widgets" / "HintToast.gd")
    owns = toast.split("func owns_f")[1].split("\nfunc ")[0]
    assert "ace_f_would_explore" in owns
    qii = src(ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd")
    disabled = qii.split("if not action_data.get(\"enabled\"")[1].split("\nfunc ")[0]
    assert "can_afford" in disabled
    assert "cost_display" in disabled
    assert "not available" in disabled


def test_plant_short_does_not_advertise_c_or_icon_first():
    """Wave 18-22: PLANT ×1 + [C] opens the board + Icon 5 while 🌱×3.
    Forest is the live beat until 🌱×5. Do not plant for them."""
    prog = src(PROG)
    target = prog.split("static func objective_target()")[1].split("static func ")[0]
    assert '_is_plant_ask(best) and _sprout_short()' in target
    assert '"StarterForest"' in target
    home = prog.split("static func banner_home()")[1].split("static func ")[0]
    assert "_banner_quest()" in home
    assert "_is_plant_ask(best)" in home
    gather = prog.split("static func _sprout_gather_line()")[1].split("\nstatic func ")[0]
    assert "_measured_glyph" in gather
    assert '[Q] take %s' in gather
    chip = src(ROOT / "UI" / "Widgets" / "ContractChip.gd")
    assert "Board does not plant" in chip
    assert "func _row_is_plant" in chip
    intro = src(INTRO)
    offer = intro.split("func toast_for_offer")[1].split("func flag_postcard")[0]
    assert "_offer_is_plant" in offer
    assert "_sprouts_are_short" in offer
    flags = json.loads(HANDOVER.read_text(encoding="utf-8"))
    voices = next(f for f in flags if f.get("id") == "new_voices")
    hint = str(voices.get("arc_quest", {}).get("hint", ""))
    assert "Forest" in hint
    assert "🌱" in hint
    assert "[5]" in hint
    assert "[R]" in hint
    assert "GHJKL" not in hint
    assert len(hint) <= 70
    gloss = src(ROOT / "Core" / "Quests" / "PredicateGloss.gd")
    assert "need 🌱×5 from Forest" in gloss
    assert '"plant": "icon"' in gloss
    voices_pred = voices.get("arc_quest", {}).get("state_predicates", [{}])[0]
    assert voices_pred.get("gate") == "inject_icon"
    inst = src(ROOT / "Core" / "Instrumentation" / "QuantumInstrument.gd")
    inject = inst.split("func action_inject_icon_pair")[1].split("\nfunc ")[0]
    assert '_notify_quest_projection("inject_icon"' in inject
    assert "Ace Rabi is also named" in inject
    gather = prog.split("static func _sprout_gather_line()")[1].split("\nstatic func ")[0]
    assert "ace_f_would_explore()" in gather
    assert "[0] Druid" in gather
    assert "_already_superposed" in gather
    assert "FRAME_DRUID" in gather
    plant_ask = prog.split("static func _is_plant_ask")[1].split("\nstatic func ")[0]
    assert "inject_icon" in plant_ask
    assert "func _is_discover_ask" in prog
    assert "func _discover_walk_line" in prog
    assert "func _eagle_gather_line" in prog
    assert "[7] Captain" in prog
    disc = prog.split("static func _discover_walk_line()")[1].split("\nstatic func ")[0]
    assert "_eagle_short" in disc
    assert "[R] Add Biome" in disc
    wood = next(f for f in flags if f.get("id") == "woodlot_door")
    whint = str(wood.get("arc_quest", {}).get("hint", ""))
    assert "🦅" in whint
    assert "Forest" in whint
    assert "[7]" in whint
    assert "[R]" in whint
    assert "F reads" not in whint
    assert len(whint) <= 70
    contact = next(f for f in flags if f.get("id") == "woodlot_contact")
    chint = str(contact.get("arc_quest", {}).get("hint", ""))
    assert "[C]" in chint and "[Y]" in chint
    assert len(chint) <= 70
    teach = next(f for f in flags if f.get("id") == "lumber_flows")
    thint = str(teach.get("arc_quest", {}).get("hint", ""))
    assert "[C]" in thint and "[Y]" in thint
    assert "[X]" in thint
    assert len(thint) <= 70
    obj = prog.split("static func objective_text()")[1].split("static func ")[0]
    assert "if _is_plant_ask(best):" in obj
    assert "return _plant_walk_line()" in obj
    shell = src(ROOT / "UI" / "PlayerShell.gd")
    peek = shell.split("if event.keycode == KEY_E:")[1].split("elif event.keycode == KEY_F:")[0]
    assert "hat_e_is_verb" in peek
    assert "not hat_e_is_verb" in peek
    gather = prog.split("static func _sprout_gather_line()")[1].split("\nstatic func ")[0]
    assert "_sim_paused" in gather
    assert "[F] Play" in gather


def test_arc_row_never_accepts_it_shunts_to_the_puzzle():
    """Arc is a catalog. Aggressive clicking tunnels to C or the field."""
    arc = src(ARC)
    select = arc.split("func _select_arc_row")[1].split("\nfunc ")[0]
    assert "_on_action_r()" not in select
    assert "accept_quest" not in select
    assert "_tunnel_from_arc" in select
    tunnel = arc.split("func _tunnel_from_arc")[1].split("\nfunc ")[0]
    assert "accept_quest" not in tunnel
    assert "open_board_on_commitments" in tunnel
    assert "_scoot_from_arc" in tunnel
    shunt = arc.split("func _arc_shunt_kind")[1].split("\nfunc ")[0]
    assert 'kind == "arc_quest"' in shunt
    assert 'return ""' in shunt
    prog = src(PROG)
    home = prog.split("static func puzzle_home")[1].split("static func ")[0]
    assert '"commitments"' in home
    assert '"field"' in home
    assert "STATUS_STORY" in home
    board = src(BOARD)
    complete = board.split("func _complete_selected")[1].split("\nfunc _scoot_held")[0]
    assert "_scoot_held(quest)" in complete
    assert "deliver needs" in complete
    assert "reward_north" in complete
    assert "taught" in complete
