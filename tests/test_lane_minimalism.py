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


def test_unpayable_fill_does_not_mill_abandon():
    """have*2 < need is a chip, not gold. Unsigned Arc outranks Abandon."""
    board = src(BOARD)
    short = board.split("func fill_shortfall_cue")[1].split("\nfunc ")[0]
    assert "[Q] Abandon" in short
    cue = board.split("func board_walk_cue")[1].split("\nfunc ")[0]
    assert "ESC closes — stall" in cue
    assert 'return "▸ [%s] then [Q] Abandon"' not in cue
    walk = src(PROG).split("static func _board_walk_line")[1].split("static func ")[0]
    assert "Abandon" in walk
    assert "_waiting_arc_line" in walk
    waiting = src(PROG).split("static func _waiting_arc_line")[1].split("static func ")[0]
    assert 'is_event_home_open("arc")' in waiting
    assert "_story_surface_open" in waiting
    assert "_waiting_arc_row_key" in waiting
    assert "row_item_cue" in waiting
    assert "func _waiting_arc_row_key" in src(PROG)
    row_key = src(PROG).split("static func _waiting_arc_row_key")[1].split("static func ")[0]
    assert "doors_ahead" in row_key
    assert "source_flag" in row_key
    assert "body" in row_key
    intro = src(INTRO)
    ahead = intro.split("static func doors_ahead")[1].split("static func remembered_count")[0]
    assert "_catalog_rank" in ahead
    assert "sort_custom" in ahead
    best_u = intro.split("static func _best_unsigned_offer")[1].split("static func ")[0]
    assert "_catalog_rank" in best_u
    assert "blocking" in intro.split("static func _catalog_rank_tables")[1].split("static func ")[0]
    obj = src(PROG).split("static func objective_text")[1].split("static func waiting_arc_offer")[0]
    assert "_story_surface_open" in obj
    dump = src(ROOT / "🍄" / "🧪" / "hive" / "dump_checkpoint.py")
    assert "banner_abandon" in dump
    grind = src(ROOT / "🍄" / "🧪" / "hive" / "grind_follow.py")
    assert 'if "abandon" in low:' in grind
    assert "OFF_WALL_FLAGS" in grind


def test_ready_claim_outranks_leftover_arc_accept():
    """Gear-Bench timber_rhythm READY is already accepted. Board-ask Abandon
    must not mill leftover unsigned Arc Accept on that row."""
    obj = src(PROG).split("static func objective_text")[1].split(
        "static func waiting_arc_offer"
    )[0]
    assert obj.index("_live_atom_plant_line") < obj.index('== "ready"')
    assert obj.index('== "ready"') < obj.index("_is_board_ask")
    assert obj.index("_claim_walk_line") < obj.index("_waiting_arc_line")
    prog = src(PROG)
    assert "func _live_atom_plant_line" in prog
    assert "func _is_coast_field_ask" in prog
    assert "func _coast_field_walk_line" in prog
    assert "func _standing_wet_country_line" in prog
    assert obj.index("_is_discover_ask") < obj.index("_is_coast_field_ask")
    assert "_standing_wet_country_line" in obj
    coast = src(PROG).split("static func _coast_field_walk_line")[1].split("static func ")[0]
    assert "[0] Druid" in coast
    assert "[E] Superpose" in coast
    assert "Never cull Woodlot" in obj or "keep Woodlot" in src(PROG)
    cull = src(PROG).split("static func _cull_walk_line")[1].split("static func ")[0]
    assert 'want == "Woodlot"' in cull
    assert "keep Woodlot" in cull
    assert 'return "▸ [C] Contracts"' not in cull
    farm_src = src(ROOT / "Core" / "Farm.gd")
    gate = farm_src.split("func _cull_gate_for(")[1].split("\nfunc ")[0]
    assert 'biome_name == "Woodlot"' in gate
    assert "never cull Woodlot" in gate
    grind = src(ROOT / "🍄" / "🧪" / "hive" / "grind_follow.py")
    assert "banner_c_esc_pong" in grind
    assert '"jolt" in blob.lower()' in grind
    assert "def farm_gold" in grind
    assert "opens the arc" in grind
    dump = src(ROOT / "🍄" / "🧪" / "hive" / "dump_checkpoint.py")
    assert "lantern_hunt" in dump
    assert '"cull" not in farm_blob.lower()' in dump
    intro = src(ROOT / "Core" / "Story" / "IntroVoice.gd")
    beat = intro.split("static func beat_from_quest")[1].split("\nstatic func ")[0]
    assert 'tense == "live"' in beat
    assert 'kind = "live_tutorial"' in beat
    assert '"claim" not in blob.lower()' in grind
    wait = src(PROG).split("static func waiting_arc_offer")[1].split("static func _waiting_arc_line")[0]
    assert "fired.has(src)" in wait
    assert "flag_door_is_resolved" in wait
    assert 'camp == "loom"' in wait
    assert "leftover" in wait
    coast = src(PROG).split("static func _coast_field_walk_line")[1].split("static func ")[0]
    standing = src(PROG).split("static func _standing_wet_country_line")[1].split("static func ")[0]
    fade = src(PROG).split("static func _wait_for_fade_line")[1].split("static func ")[0]
    fade_walk = src(PROG).split("static func _fade_walk_line")[1].split("static func ")[0]
    wet = src(PROG).split("static func _wet_workpiece_key")[1].split("static func ")[0]
    assert "[0] Druid" in coast
    assert "[E] Superpose" in coast
    assert "H²=I" in coast
    assert "[F] Fast-Fwd" in coast
    assert "ShrineOfAshes" in coast
    assert "the_basin" in coast
    assert "STATUS_STORY" in coast
    assert "_waiting_arc_line" in coast
    assert "Lanternfall" in coast
    assert '_named_atom_plant_line("Lanternfall", "🌉")' in coast
    assert '_empty_plot_exists("Lanternfall")' in coast
    grind_ff = src(ROOT / "🍄" / "🧪" / "hive" / "grind_follow.py")
    assert '"fast-fwd" in blob.lower()' not in grind_ff.split("freeze_at = budget")[1].split("else 8")[0] or "the urn fills" in grind_ff
    assert "the bridge holds" in grind_ff
    assert "the urn fills" in grind_ff
    disc = src(PROG).split("static func _discover_walk_line")[1].split("static func ")[0]
    assert "STATUS_STORY" in disc
    assert "_waiting_arc_line" in disc
    assert "_col_is_pole" in coast
    assert "current_biome" in coast
    assert "the urn" in coast
    assert "_bloch_known" in coast
    assert coast.index("[E] Superpose") < coast.index("the urn fills")
    keep_ff = src(PROG).split("static func ace_f_keeps_fast_fwd")[1].split("static func ")[0]
    assert "the_basin" in keep_ff
    assert "ShrineOfAshes" in keep_ff
    assert "_berry_tracking" in keep_ff
    assert "the_chain_tested" in keep_ff
    assert "Lanternfall" in keep_ff
    ace_chip = src(ROOT / "Core" / "UI" / "AceChipResolvers.gd")
    assert "ace_f_keeps_fast_fwd" in ace_chip
    toast = src(ROOT / "UI" / "Widgets" / "HintToast.gd")
    owns = toast.split("func owns_f()")[1].split("\nfunc ")[0]
    assert "ace_f_keeps_fast_fwd" in owns
    qc = src(ROOT / "Core" / "QuantumSubstrate" / "QuantumComputer.gd")
    assert "@export var regime_override" in qc
    story = src(ROOT / "Core" / "Story" / "StoryEngine.gd")
    assert "_reapply_spec_regimes_after_load" in story
    reapply = story.split("func _reapply_world_changes_after_load")[1].split("\nfunc ")[0]
    assert "_reapply_spec_regimes_after_load" in reapply
    spec_reg = story.split("func _reapply_spec_regimes_after_load")[1].split("\nfunc ")[0]
    assert "spec.regime" in spec_reg
    atoms = src(ROOT / "Core" / "Environment" / "BiomeBase.gd")
    get_atoms = atoms.split("func _get_atom_components")[1].split("\nfunc ")[0]
    assert "live.atom_components" in get_atoms
    gated = atoms.split("func get_gated_lindblad_channels")[1].split("\nfunc ")[0]
    assert "not _gated_channels_cache.is_empty()" in gated
    kraus = src(ROOT / "Core" / "QuantumSubstrate" / "QuantumComputer.gd")
    apply_1q = kraus.split("func _apply_lindblad_1q")[1].split("\nfunc ")[0]
    assert "sqrt_1mp if bit_i == from_pole" in apply_1q
    assert "1.0 if bit_i == from_pole else sqrt_1mp" not in apply_1q
    grind = src(ROOT / "🍄" / "🧪" / "hive" / "grind_follow.py")
    assert '"urn" in blob.lower()' in grind
    assert '"e" in presses' in grind
    assert "def accept_row_key" in grind
    assert "keys[1]" in grind
    assert "accept_row_key(blob)" in grind
    assert "Fast-Fwd" in fade
    assert "[8] Ace" in fade
    assert "STATUS_STORY" in fade_walk
    assert fade_walk.index("STATUS_STORY") < fade_walk.index("ESC closes")
    assert fade_walk.index("_named_atom_plant_line") < fade_walk.index("ESC closes")
    assert "_wet_workpiece_key" in fade_walk
    assert "_fade_has_drunk" in fade_walk
    assert "_berry_walk_line" in fade_walk
    assert "Strike" in fade_walk
    assert "collapse the rose" in fade_walk
    assert "_already_superposed" in fade_walk
    assert "_col_is_pole" in fade_walk
    assert "_register_plot_key" in fade_walk
    assert "pole then Superpose" not in fade_walk
    assert "_named_atom_plant_line" in fade_walk
    assert "_atom_in_biome" in fade_walk
    col_pole = src(PROG).split("static func _col_is_pole")[1].split("static func ")[0]
    assert "_bloch_known" in col_pole
    assert "0.25" in col_pole
    assert "_fade_saw_equator" in fade_walk
    already = src(PROG).split("static func _already_superposed")[1].split("static func ")[0]
    assert "0.5" in already
    assert "Dawn kick" in already or "0.35" in already
    assert wet.index("🌹") < wet.index("🎭")
    assert "func _off_pole" in src(PROG)
    assert "func _pole_plot_key" in src(PROG)
    assert "func _equator_plot_key" in src(PROG)
    assert "func _fade_plant_atom" in src(PROG)
    assert '_atom_in_biome("GildedRot", "🌉")' in fade_walk
    assert "func _spark_walk_line" in src(PROG)
    assert "func _is_spark_ask" in src(PROG)
    spark_walk = src(PROG).split("static func _spark_walk_line")[1].split("static func ")[0]
    assert "[4] Spark" in spark_walk
    assert "[R] jolt north" in spark_walk
    assert "current_plot_idx" in spark_walk
    assert "_plot_bound" not in spark_walk
    obj_fn = src(PROG).split("static func objective_text")[1].split("static func waiting_arc_offer")[0]
    assert "_spark_walk_line" in obj_fn
    farm_cull = src(ROOT / "Core" / "Farm.gd").split("func named_cull_target")[1].split("func _cull_gate_for")[0]
    assert "_biome_is_wet" in farm_cull
    assert "wet_fallback" in farm_cull
    assert "_glyph_plot_key(\"🌉\", \"GildedRot\", false)" in wet or '_glyph_plot_key("🌉", "GildedRot", false)' in wet
    assert "_register_plot_key" in wet
    assert "scout: bool = true" in src(PROG)
    assert "func _register_plot_key" in src(PROG)
    qii = src(ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd")
    assert "ACE_FAST_FORWARD_PHRAMES := 120" in qii
    qsps = src(ROOT / "Core" / "Quests" / "QuestStateProjectionService.gd")
    assert "func _max_qubit_equator" in qsps
    assert "get_marginal_density_matrix" in qsps
    assert "_last_qubit_coherence" in qsps
    obs_fn = qsps.split("func observe_biome")[1].split("func serialize_receipts")[0]
    assert "_max_qubit_equator" in obs_fn
    assert "peak" in obs_fn
    rec = src(QM).split("func record_quantum_action")[1].split("\nfunc ")[0]
    assert "time_skip" in rec
    assert "observe_biome" in rec
    gilded = src(ROOT / "Core" / "Biomes" / "data" / "biomes.json")
    rot = gilded.split('"name": "GildedRot"')[1].split('"name": "BroadcastTower"')[0]
    rose_atom = rot.split('"atom_components"')[1].split('"🌹"')[1].split('"🎭"')[0]
    assert "dephasing" in rose_atom
    rot_atoms = rot.split('"atom_components"')[1].split('"native_factions"')[0]
    assert '"🌉"' in rot_atoms
    lantern_atom = rot_atoms.split('"🌉"')[1].split("}")[0]
    assert "dephasing" in lantern_atom
    assert "H²=I" in src(PROG).split("static func _wait_for_fade_line")[1].split("static func ")[0] or "H²=I" in src(PROG)
    assert "_wait_for_fade_line" in standing
    obj = src(PROG).split("static func objective_text")[1].split(
        "static func waiting_arc_offer"
    )[0]
    assert "_is_fade_ask" in obj
    assert obj.index("_is_fade_ask") < obj.index("_is_berry_ask")
    banner = src(PROG).split("static func _banner_quest")[1].split("static func ")[0]
    assert banner.index("fade_first") < banner.index("_best_objective")
    assert "_unsigned_fade_offer" in banner
    assert "_accepted_fade_quest" in banner
    assert "func _accepted_fade_quest" in src(PROG)
    acc = src(PROG).split("static func _accepted_fade_quest")[1].split("static func ")[0]
    assert "active_quests.values()" in acc
    handshake = src(QM).split("func _handshake_auto_claims")[1].split("\nfunc ")[0]
    assert 'source_flag' in handshake
    assert '"the_gray"' in handshake
    qm = src(QM)
    offers = qm.split("func get_story_offers")[1].split("\nfunc ")[0]
    assert "_sweep_spent_arc_offers" in offers
    assert "func _arc_offer_is_spent" in qm
    dump = src(ROOT / "🍄" / "🧪" / "hive" / "dump_checkpoint.py")
    camp_fn = dump.split("def campaign_progress")[1].split("\ndef ")[0]
    assert "opens_after" in camp_fn
    assert "postgame" in camp_fn
    grind = src(ROOT / "🍄" / "🧪" / "hive" / "grind_follow.py")
    assert "fast-fwd" in grind
    named = src(PROG).split("static func _named_atom_plant_line")[1].split("static func ")[0]
    assert "[F] Track" not in named
    assert "[R] plant" in named
    assert "_blank_plant_key" in named
    assert "_live_plot_key" in named


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
    # mill_wakes' ONE objective includes 💨 in the Village (it always did,
    # silently, as a flag predicate) — the hint names the plant honestly.
    assert "💨" in hint
    assert len(hint) <= 70
    assert "Millwright" in str(aq.get("faction", ""))
    walk = prog.split("func _board_walk_line")[1].split("\nstatic func ")[0]
    assert "Market [Y]" in walk


def test_eagle_short_names_gather_key():
    """lantern_door: 21 eagles from Forest, Captain [R] Add Biome, no gather
    key. Origin next-key was Forest with a blank chip. Name Forest rail,
    [8] Ace, then [R]/[Q]. Do not discover for them."""
    prog = src(PROG)
    assert "func _eagle_gather_target" in prog
    assert "func eagle_short_refusal" in prog
    target = prog.split("static func objective_target()")[1].split("static func ")[0]
    assert "_eagle_short()" in target
    assert "_eagle_gather_target()" in target
    assert '{"key": "", "biome": "StarterForest"}' not in target.split("_eagle_short()")[1].split("if _is_discover_ask")[0]
    gather = prog.split("static func _eagle_gather_target()")[1].split("\nstatic func ")[0]
    assert '"8"' in gather or "hat_key_for_frame" in gather or "ace" in gather
    assert '"R"' in gather
    assert '"Q"' in gather
    assert "StarterForest" in gather
    detail = prog.split("static func objective_detail()")[1].split("static func ")[0]
    assert "_eagle_short()" in detail
    disc = prog.split("static func _discover_walk_line()")[1].split("\nstatic func ")[0]
    assert "_eagle_short" in disc
    assert "_eagle_gather_line" in disc
    qii = src(ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd")
    disc_arm = qii.split('"discover_biome":')[1].split('"remove_biome":')[0]
    assert "eagle_short_refusal" in disc_arm
    assert disc_arm.index("eagle_short_refusal") < disc_arm.index("slots_full_refusal")
    flags = json.loads(HANDOVER.read_text(encoding="utf-8"))
    lantern = next(f for f in flags if f.get("id") == "lantern_door")
    hint = str(lantern.get("arc_quest", {}).get("hint", ""))
    # Captain Chart: the authored hint names the 🦅 source and the chart key;
    # the gather/cull choreography lives in the banner walk, not the hint.
    assert "Forest" in hint
    assert "🦅" in hint
    assert "[7]" in hint
    assert "[R] Chart Lanternfall" in hint
    assert "F reads" not in hint
    assert len(hint) <= 70


def test_basket_short_walks_the_village_trade_not_a_plot():
    """No register mints 🧺 — the Village has no 🧺 plot, so the old walk
    ("Village 🧺 [Q] pays a basket") steered a broke player into a dead end.
    The 🧺 walk is now the data-driven supply walk: the standing 🧺 trade on
    the Village board, from the campaign resources table. Strike costs 👥
    and does not mint 🧺; refusals speak when Strike/Explore/Q cannot. Do
    not gather or trade for them."""
    prog = src(PROG)
    for fn in ("_basket_short", "_basket_pay_line", "_basket_pay_target",
               "basket_short_refusal", "_supply_short", "_supply_walk_line",
               "_supply_target", "supply_refusal", "supply_route_line", "_supply_step"):
        assert "static func %s(" % fn in prog, fn
    # The 🧺 helpers are thin instances of the generic, table-keyed walk.
    basket = prog.split("static func _basket_pay_line()")[1].split("\nstatic func ")[0]
    assert '_supply_walk_line("🧺")' in basket
    assert "[Q] gather 🧺" not in basket
    assert "[R] Strike" not in basket
    pay_t = prog.split("static func _basket_pay_target()")[1].split("\nstatic func ")[0]
    assert '_supply_target("🧺")' in pay_t
    short = prog.split("static func _basket_short()")[1].split("\nstatic func ")[0]
    assert '_supply_short("🧺"' in short
    # The walk reads the table, not a hard-coded country or price.
    step = prog.split("static func _supply_step(")[1].split("\nstatic func ")[0]
    assert "CampaignRuntime.rescue_trade" in step
    sup_short = prog.split("static func _supply_short(")[1].split("\nstatic func ")[0]
    assert "CampaignRuntime.low_water" in sup_short
    walk = prog.split("static func _supply_walk_line(")[1].split("\nstatic func ")[0]
    assert "supply_walk_cue" in walk
    assert "[C] opens the board" in walk
    assert "_cross_to(biome)" in walk
    # Gather walks restock BEFORE the last basket: sprout and eagle both.
    sprout = prog.split("static func _sprout_gather_line()")[1].split("\nstatic func ")[0]
    assert "_basket_short()" in sprout and "_basket_pay_line()" in sprout
    gather = prog.split("static func _eagle_gather_line()")[1].split("\nstatic func ")[0]
    assert "_basket_short" in gather
    assert "_basket_pay_line" in gather
    target = prog.split("static func _eagle_gather_target()")[1].split("\nstatic func ")[0]
    assert "_basket_short" in target
    assert "_basket_pay_target" in target
    eagle_ref = prog.split("static func eagle_short_refusal()")[1].split("\nstatic func ")[0]
    assert "supply_refusal(\"🧺\", gather_price(), true)" in eagle_ref
    # The board answers the walk with one next key.
    board = src(BOARD)
    cue = board.split("func supply_walk_cue(")[1].split("\nfunc _market_rows")[0]
    assert "Market [Y]" in cue
    assert "[R] %s" in cue
    # Refusals: strict (a low wallet is not why Strike failed).
    qii = src(ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd")
    block = qii.split("func _block_reason_for_player")[1].split("func _tracked_elsewhere_hint")[0]
    assert block.count('supply_refusal("🧺", UIProgression.gather_price(), true)') == 3
    assert "Explore does not pay" in block
    assert "Strike does not pay" in block
    probe = src(ROOT / "Core" / "Actions" / "ProbeActions.gd")
    assert 'CampaignRuntime.supply_route_words("🧺"' in probe
    # The dead path is gone everywhere it was spoken.
    for rel in ("Core/Actions/ProbeActions.gd", "UI/Core/UIProgression.gd",
                "UI/Core/QuantumInstrumentInput.gd", "UI/Overlays/QuestBoard.gd",
                "Core/Quests/data/story_flags.json", "Core/Campaign/campaign.json"):
        text = src(ROOT / rel)
        assert "Village 🧺 [Q] pays a basket" not in text, rel
        assert "Village 🧺 plot" not in text, rel
        assert "sleeping 🧺 plot" not in text, rel
    flags = json.loads(HANDOVER.read_text(encoding="utf-8"))
    lantern = next(f for f in flags if f.get("id") == "lantern_door")
    hint = str(lantern.get("arc_quest", {}).get("hint", ""))
    # Captain Chart hint: 🦅 source + chart key (the 🧺 walk is the banner's).
    assert "Forest" in hint
    assert "🦅" in hint
    assert "[7]" in hint
    assert "[R] Chart Lanternfall" in hint
    assert "F reads" not in hint
    assert len(hint) <= 70


def test_unreadable_wallet_fails_toward_village_basket():
    """lantern_door: empty/unreadable wallet, [R] Find Lanternfall does not
    pay 🧺. Origin _eagle_short/_basket_short returned false when economy
    was missing or mute, so discover walk kept compass prose. Mute wallet
    is 0; fail toward the Village 🧺 trade. Do not discover for them."""
    prog = src(PROG)
    eagle = prog.split("static func _eagle_short()")[1].split("\nstatic func ")[0]
    assert "farm == null" in eagle
    assert "_eagle_have()" in eagle
    assert eagle.count("return false") == 1
    assert 'has_method("get_resource")' not in eagle
    assert 'not ("economy" in farm)' not in eagle
    # No farm is not a wallet; a mute economy reads 0 (via _wallet) → short.
    sup = prog.split("static func _supply_short(")[1].split("\nstatic func ")[0]
    assert "farm == null" in sup
    assert "_wallet(emoji)" in sup
    assert sup.split("var have")[0].count("return false") == 1
    assert 'has_method("get_resource")' not in sup
    assert 'not ("economy" in farm)' not in sup
    wallet = prog.split("static func _wallet(")[1].split("\nstatic func ")[0]
    assert "return 0.0" in wallet
    disc = prog.split("static func _discover_walk_line()")[1].split("\nstatic func ")[0]
    assert "_eagle_short" in disc
    assert "_eagle_gather_line" in disc
    gather = prog.split("static func _eagle_gather_line()")[1].split("\nstatic func ")[0]
    assert "_basket_short" in gather
    assert "_basket_pay_line" in gather
    eagle_ref = prog.split("static func eagle_short_refusal()")[1].split("\nstatic func ")[0]
    assert "supply_refusal(\"🧺\", gather_price(), true)" in eagle_ref
    qii = src(ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd")
    disc_arm = qii.split('"discover_biome":')[1].split('"remove_biome":')[0]
    assert "eagle_short_refusal" in disc_arm


def test_eagle_after_strike_names_q_not_explore():
    """lantern_door: after 🧺, [R] Strike then [F] Explore; 🦅 stuck, [Q]
    not the next key. Strike releases is_bound; Ace F named Explore and
    wiped the measure. Name [Q] until the eagle lands. Do not Explore."""
    prog = src(PROG)
    ace = prog.split("static func ace_f_would_explore()")[1].split("\nstatic func ")[0]
    assert "_plot_measured(col)" in ace
    gather = prog.split("static func _eagle_gather_line()")[1].split("\nstatic func ")[0]
    assert "_plot_measured(focused)" in gather
    assert gather.index("_plot_measured(focused)") < gather.index("ace_f_would_explore()")
    assert "[Q] gather 🦅" in gather.split("_plot_measured(focused)")[1].split("if not _plot_bound")[0]
    target = prog.split("static func _eagle_gather_target()")[1].split("\nstatic func ")[0]
    assert target.index("_plot_measured(focused)") < target.index("ace_f_would_explore()")
    assert '"Q"' in target.split("_plot_measured(focused)")[1].split("if not _plot_bound")[0]
    term = prog.split("static func _plot_terminal(")[1].split("\nstatic func ")[0]
    assert "get_terminal_at_grid_pos" in term
    pool = src(ROOT / "Core" / "GameMechanics" / "TerminalPool.gd")
    free = pool.split("func get_unbound_terminal()")[1].split("\nfunc ")[0]
    assert "is_measured" in free
    assert "func get_measured_terminal_for_register" in pool
    probe = src(ROOT / "Core" / "Actions" / "ProbeActions.gd")
    explore = probe.split("static func action_explore")[1].split("static func _first_unbound_register")[0]
    assert "get_measured_terminal_for_register" in explore
    assert "Already measured — Q harvests it." in explore
    can = src(ROOT / "Core" / "GameMechanics" / "Terminal.gd")
    expl = can.split("func can_explore()")[1].split("\nfunc ")[0]
    assert "is_measured" in expl
    qii = src(ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd")
    ctx = qii.split("func build_chip_context()")[1].split("\nfunc ")[0]
    assert "is_measured" in ctx
    block = qii.split("func _block_reason_for_player")[1].split("func _tracked_elsewhere_hint")[0]
    assert "Explore does not harvest" in block
    assert "Already measured — Q harvests it." in block


def test_lantern_teaching_names_one_next_key():
    """lantern_teaching: toast R-holds-reference / E-compares vs action bar
    Track-first / Loops, Ace [8] vs Icon [5]. Origin ask_line dumped the
    paragraph. One next key: Arc accept, rail, [0] Druid, [E], then [C].
    Do not dump the paragraph. Do not mill leftover first_breath."""
    prog = src(PROG)
    assert "func _is_teaching_ask" in prog
    assert "func _teaching_walk_line" in prog
    assert "func _teaching_target" in prog
    assert "func _unsigned_teaching_offer" in prog
    assert "func teaching_wrong_hat_refusal" in prog
    ask = prog.split("static func _is_teaching_ask")[1].split("\nstatic func ")[0]
    assert "lantern_teaching" in ask
    assert "biome_state_gte" in ask
    assert "🪔" in ask
    assert "biome_evolving" not in ask
    walk = prog.split("static func _teaching_walk_line()")[1].split("\nstatic func ")[0]
    assert "[X] Arc" in walk
    assert "[R] Accept" in walk
    assert "_cross_to" in walk
    assert "Lanternfall" in walk
    assert "[0] Druid" in walk
    assert "[E] Superpose" in walk
    assert "_claim_walk_line" in walk
    assert "ask_line" not in walk
    target = prog.split("static func _teaching_target()")[1].split("\nstatic func ")[0]
    assert '"X"' in target
    assert '"0"' in target or "druid" in target
    assert '"E"' in target
    assert '"C"' in target
    assert "Lanternfall" in target
    text_fn = prog.split("static func objective_text()")[1].split("static func ")[0]
    assert "_is_teaching_ask(best)" in text_fn
    assert "_teaching_walk_line()" in text_fn
    banner = prog.split("static func _banner_quest()")[1].split("static func ")[0]
    assert "_unsigned_teaching_offer()" in banner
    assert banner.index("_unsigned_teaching_offer") < banner.index("_unsigned_berry_offer")
    obj_t = prog.split("static func objective_target()")[1].split("static func ")[0]
    assert "_teaching_target()" in obj_t
    detail = prog.split("static func objective_detail()")[1].split("static func ")[0]
    assert "_is_teaching_ask(best)" in detail
    qii = src(ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd")
    assert "teaching_wrong_hat_refusal" in qii
    tracked = qii.split("func _tracked_elsewhere_hint()")[1].split("\nfunc ")[0]
    assert "teaching_wrong_hat_refusal" in tracked
    assert "return teach" in tracked
    rest = tracked.split("return teach", 1)[1]
    assert "Icon hat (5)" in rest
    chips = src(ROOT / "Core" / "UI" / "IconChipResolvers.gd")
    resolve = chips.split("static func resolve_r")[1].split("\nstatic func ")[0]
    assert "teaching_wrong_hat_refusal" in resolve
    assert "[0] Druid" in resolve
    flags = json.loads(HANDOVER.read_text(encoding="utf-8"))
    teach = next(f for f in flags if f.get("id") == "lantern_teaching")
    hint = str(teach.get("arc_quest", {}).get("hint", ""))
    assert "Lanternfall" in hint
    assert "[0]" in hint
    assert "[E]" in hint
    assert "🪔" in hint
    assert "[C]" in hint
    assert "[X]" in hint
    assert "Druid" in hint
    assert len(hint) <= 70
    assert "Icon hat (5)" not in hint
    assert "holds a reference" not in hint
    assert "Track first" not in hint
    assert "Commitments tab" not in hint


def test_lantern_wakes_names_unseat_then_plant():
    """lantern_wakes: Lanternfall ring full; banner named empty J; Icon R
    Track-first; next beat Middle Cannot Hold. Authored 🌉 in the biome
    must not skip the plant. Name [Q] unseat, then plant. Do not mill leftover."""
    prog = src(PROG)
    assert "func _empty_plot_exists" in prog
    assert "func _plant_ask_biome" in prog
    assert "func plant_full_refusal" in prog
    walk = prog.split("static func _plant_walk_line()")[1].split("\nstatic func ")[0]
    assert "_empty_plot_exists" in walk
    assert "[Q] unseats" in walk
    assert "_cross_to" in walk
    target = prog.split("static func objective_target()")[1].split("static func ")[0]
    assert "_empty_plot_exists" in target
    assert '"Q"' in target
    assert "_plant_ask_biome" in target
    detail = prog.split("static func objective_detail()")[1].split("static func ")[0]
    assert "_empty_plot_exists" in detail
    chips = src(ROOT / "Core" / "UI" / "IconChipResolvers.gd")
    resolve = chips.split("static func resolve_r")[1].split("\nstatic func ")[0]
    assert "plant_full_refusal" in resolve
    assert "[Q] unseats" in resolve
    qii = src(ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd")
    assert "plant_full_refusal" in qii
    proj = src(ROOT / "Core" / "Quests" / "QuestStateProjectionService.gd")
    assert 'action_name == "inject_icon"' in proj
    assert 'predicate.get("biome"' in proj
    inst = src(ROOT / "Core" / "Instrumentation" / "QuantumInstrument.gd")
    assert 'result["biome"] = biome_name' in inst
    flags = json.loads(HANDOVER.read_text(encoding="utf-8"))
    wakes = next(f for f in flags if f.get("id") == "lantern_wakes")
    # One objective per beat: the ask lives on the arc quest, the flag opens
    # on its requires alone (campaign spec).
    preds = (wakes.get("arc_quest") or {}).get("state_predicates") or []
    assert any(p.get("type") == "gate_sequence_contains" and p.get("gate") == "inject_icon"
               and p.get("biome") == "Lanternfall" for p in preds)
    assert not any(p.get("type") == "atom_in_biome" for p in preds)
    aq = wakes.get("arc_quest") or {}
    sp = aq.get("state_predicates") or []
    assert any(p.get("type") == "gate_sequence_contains" and p.get("gate") == "inject_icon"
               and p.get("biome") == "Lanternfall" for p in sp)
    hint = str(aq.get("hint", ""))
    assert "[5]" in hint
    assert "[R]" in hint
    assert "[Q]" in hint
    assert "Lanternfall" in hint
    assert "unseat" in hint.lower()
    assert len(hint) <= 70
    assert "Icon hat (5)" not in hint
    assert "Track first" not in hint
    assert "Middle Cannot Hold" not in hint


def test_eagle_overhead_track_keeps_sticky_focus():
    """eagle_overhead: Village G focused; Icon 5; F said Track needs a focused
    plot; farm toast lagged. Sticky last-selected is the workpiece. F/R and
    the berry banner must use it. Do not mill leftover."""
    qii = src(ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd")
    assert "func _sticky_qubit_id" in qii
    toggle = qii.split("func _execute_toggle_berry_track")[1].split("\nfunc ")[0]
    assert "_sticky_qubit_id" in toggle
    inc = qii.split("func _execute_incorporate_icon")[1].split("\nfunc ")[0]
    assert "_sticky_qubit_id" in inc
    mode = qii.split("func _on_mode_changed")[1].split("\nfunc ")[0]
    assert "last_selected_position = GridSentinel.INVALID_POSITION" not in mode
    prog = src(PROG)
    focused = prog.split("static func _focused_col()")[1].split("static func ")[0]
    assert "last_selected_position" in focused
    inst = src(ROOT / "Core" / "Instrumentation" / "QuantumInstrument.gd")
    incorporate = inst.split("func action_incorporate")[1].split("\nfunc ")[0]
    assert "last_selected_position" in incorporate
    flags = json.loads(HANDOVER.read_text(encoding="utf-8"))
    eagle = next(f for f in flags if f.get("id") == "eagle_overhead")
    aq = eagle.get("arc_quest") or {}
    sp = aq.get("state_predicates") or []
    assert any(
        p.get("type") == "berry_consumed_count_gte" and p.get("biome") == "Village"
        and int(p.get("value", 0)) == 9
        for p in sp
    )
    walk = prog.split("static func _berry_walk_line")[1].split("static func ")[0]
    assert "[F] Track" in walk
    assert "[R] Incorporate" in walk
    assert "[F] Fast-Fwd" in walk
    assert "wait — loop ripens" not in walk


def test_braid_order_refreshes_mi_after_gate():
    """braid_order: Two Chores Bell scores 0 because gate invalidate
    clears lookahead MI and frozen refill leaves the cache empty/stale.
    Refresh MI from the live ρ after the gate. Do not mill leftover."""
    qc = src(ROOT / "Core" / "QuantumSubstrate" / "QuantumComputer.gd")
    assert "func refresh_cached_mi" in qc
    assert "compute_all_mutual_information" in qc.split("func refresh_cached_mi")[1].split("\nfunc ")[0]
    inj = src(ROOT / "Core" / "QuantumSubstrate" / "GateInjector.gd")
    inv = inj.split("static func _invalidate_lookahead")[1].split("static func ")[0]
    assert "refresh_cached_mi" in inv
    qsps = src(ROOT / "Core" / "Quests" / "QuestStateProjectionService.gd")
    mi = qsps.split('"mutual_information_at_least"')[1].split("\n\t\t\"")[0]
    assert "get_cached_max_mutual_information" in mi
    flags = json.loads(HANDOVER.read_text(encoding="utf-8"))
    braid = next(f for f in flags if f.get("id") == "braid_order")
    aq = braid.get("arc_quest") or {}
    sp = aq.get("state_predicates") or []
    assert any(p.get("type") == "mutual_information_at_least" for p in sp)
    assert any(p.get("type") == "gate_order" for p in sp)


def test_braid_order_operator_after_hadamard_names_cnot():
    """braid_order: [9] after honest Druid Hadamard killed the seat
    because PlayerShell set_cursor_layer then QII._select_frame_hat
    interleaved. Hat layer write lives in _select_frame_hat. Name CNOT
    (E in Gate), not Bell-on-Q. Do not mill leftover."""
    shell = src(ROOT / "UI" / "PlayerShell.gd")
    hat_anchor = shell.split(
        "if kc in [KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B, KEY_N, KEY_M]:"
    )[1].split("elif kc in [KEY_T")[0]
    assert "instrument_input.set_cursor_layer(1" not in hat_anchor
    assert "elif kc in [KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]:" not in shell
    qii = src(ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd")
    select = qii.split("func _select_frame_hat")[1].split("\nfunc ")[0]
    assert "set_cursor_layer(1, true)" in select
    assert "set_frame" in select
    assert "is_instance_valid(_instrument)" in select
    assert "func _mark_key_handled" in qii
    hat_keys = qii.split("if ToolConfig.HAT_KEY_TO_FRAME.has(key):")[1].split(
        "\n\t# Direct sub-mode"
    )[0]
    assert "_mark_key_handled()" in hat_keys
    assert "get_viewport().set_input_as_handled()" not in hat_keys
    prog = src(PROG)
    assert "func _is_braid_ask" in prog
    assert "func _braid_walk_line" in prog
    decorate = prog.split("static func _decorate_objective")[1].split("static func ")[0]
    assert "_is_braid_ask(q)" in decorate
    assert "_braid_walk_line()" in decorate
    target = prog.split("static func objective_target()")[1].split("static func ")[0]
    assert "_is_braid_ask(best)" in target
    assert "_braid_target()" in target
    walk = prog.split("func _braid_walk_line")[1].split("\nstatic func ")[0]
    assert "[E] CNOT" in walk
    assert "[R] Gate" in walk
    assert "] Operator" in walk
    assert "[Q] Bell" not in walk
    flags = json.loads(HANDOVER.read_text(encoding="utf-8"))
    braid = next(f for f in flags if f.get("id") == "braid_order")
    aq = braid.get("arc_quest") or {}
    sp = aq.get("state_predicates") or []
    assert any(
        p.get("type") == "gate_order"
        and "cnot" in [str(g).lower() for g in (p.get("gates") or [])]
        for p in sp
    )


def test_slots_full_names_cull_target_and_q():
    """lantern_door: biome slots full; ▸ still [R]; no named cull target.
    Refusal names the cull and the one key that does it. Do not cull for them."""
    prog = src(PROG)
    assert "func _slots_full" in prog
    assert "func _named_cull_target" in prog
    assert "func _cull_walk_line" in prog
    assert "func slots_full_refusal" in prog
    disc = prog.split("static func _discover_walk_line()")[1].split("\nstatic func ")[0]
    assert "_slots_full" in disc
    assert "_cull_walk_line" in disc
    cull = prog.split("func _cull_walk_line")[1].split("\nstatic func ")[0]
    assert "[Q] culls" in cull
    assert "[F] confirms cull" in cull
    assert "_cull_confirm_pending" in cull
    assert "[7] Captain" in cull
    assert "[R] Add Biome" not in cull
    assert "_waiting_arc_line" in cull
    assert 'want == "Woodlot"' in cull
    assert "keep Woodlot" in cull
    assert 'return "▸ [C] Contracts"' not in cull
    target = prog.split("static func objective_target()")[1].split("static func ")[0]
    assert "_slots_full()" in target
    assert '"Q"' in target
    farm = src(ROOT / "Core" / "Farm.gd")
    assert "func named_cull_target()" in farm
    assert "func _cull_gate_for(" in farm
    can = farm.split("func can_remove_biome()")[1].split("\nfunc ")[0]
    assert "_cull_gate_for(" in can
    qii = src(ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd")
    disc_arm = qii.split('"discover_biome":')[1].split('"remove_biome":')[0]
    assert "Biome slots full" in disc_arm
    assert "slots_full_refusal" in disc_arm
    flags = json.loads(HANDOVER.read_text(encoding="utf-8"))
    lantern = next(f for f in flags if f.get("id") == "lantern_door")
    hint = str(lantern.get("arc_quest", {}).get("hint", ""))
    # Captain Chart hint names [7] then [R] Chart; the cull is the banner's.
    assert "[7]" in hint
    assert "[R] Chart" in hint
    assert "F reads" not in hint
    assert len(hint) <= 70


def test_paid_eagles_name_lanternfall_and_the_chart_key():
    """lantern_door: eagles paid, slots open, Captain [R] Add Biome landed
    GildedRot and the banner named no coast. Captain R now CHARTS the open
    door's biome (no draw); the live ask names it and the one key that
    charts it. Compass leans the coast. Pressure reads the arc quest, not
    only flag predicates. Do not chart for them."""
    prog = src(PROG)
    assert "func _named_discover_target" in prog
    disc = prog.split("static func _discover_walk_line()")[1].split("\nstatic func ")[0]
    assert "_named_discover_target" in disc
    assert "_chart_target_biome()" in disc
    assert "[7] Captain, then [R] Chart %s" in disc
    assert "[R] Chart %s" in disc
    assert "[R] Add Biome —" in disc  # no open door: random draw
    named = prog.split("static func _named_discover_target()")[1].split("\nstatic func ")[0]
    assert "biome_evolving" in named
    assert "biome_state_gte" in named
    assert "_biome_unlocked" in named
    disc_ask = prog.split("static func _is_discover_ask")[1].split("\nstatic func ")[0]
    assert "biome_evolving" in disc_ask
    assert "biome_state_gte" in disc_ask
    target = prog.split("static func objective_target()")[1].split("static func ")[0]
    paid = target.split("if _slots_full():")[1]
    assert "_named_discover_target()" in paid
    assert '"R"' in paid
    forecast = src(ROOT / "Core" / "Gameplay" / "BiomeDiscoveryForecastService.gd")
    assert "LIVE_DISCOVER_BOOST" in forecast
    assert "arc_quest" in forecast.split("static func _biomes_under_pressure")[1].split("static func _biome_alignment")[0]
    assert "story_offers" in forecast
    assert "func _live_discover_biomes" in forecast
    assert "flag_door_is_resolved" in forecast
    qii = src(ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd")
    compass = qii.split("func _execute_discovery_forecast")[1].split("\nfunc ")[0]
    assert "_named_discover_target" in compass
    assert "leans" in compass
    flags = json.loads(HANDOVER.read_text(encoding="utf-8"))
    lantern = next(f for f in flags if f.get("id") == "lantern_door")
    hint = str(lantern.get("arc_quest", {}).get("hint", ""))
    preds = lantern.get("predicates") or []
    assert not any(p.get("biome") for p in preds)
    arc_preds = (lantern.get("arc_quest") or {}).get("state_predicates") or []
    assert any(p.get("biome") == "Lanternfall" for p in arc_preds)
    assert "Lanternfall" in hint
    assert "Forest" in hint
    assert "🦅" in hint
    assert "[7]" in hint
    assert "[R] Chart Lanternfall" in hint
    assert "F reads" not in hint
    assert len(hint) <= 70


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
    assert "[F] Fast-Fwd" in berry
    assert "wait — loop ripens" not in berry
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
