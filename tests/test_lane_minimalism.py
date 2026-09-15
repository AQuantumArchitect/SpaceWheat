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
    assert "waiting on the Arc" in offer
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
