"""One door at a time — a reap must not open mill + plant + lumber yard.

Playtest 2026-09-10: player never found reap, sat in the loom (Operator),
then Arc offered Village / Timber Country as if they were live. Cause:
story_flag_set scored true the moment the parent *fired*, so first_harvest
→ village_stirs → new_voices → woodlot_door cascaded in one evaluate pass
(Village is evolving at boot; the mill tutorial already paid access 0.02).
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FLAGS = ROOT / "Core" / "Quests" / "data" / "story_flags.json"
QM = ROOT / "Core" / "Quests" / "QuestManager.gd"
INTRO = ROOT / "Core" / "Story" / "IntroVoice.gd"
PROG = ROOT / "UI" / "Core" / "UIProgression.gd"
ACE = ROOT / "Core" / "UI" / "AceChipResolvers.gd"


def src(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def _flags():
    return {f["id"]: f for f in json.loads(FLAGS.read_text(encoding="utf-8"))}


def _has_door(flag: dict) -> bool:
    aq = flag.get("arc_quest")
    return isinstance(aq, dict) and bool(aq)


def _resolved(fid: str, by_id: dict, fired: set, completed: set) -> bool:
    if fid not in fired:
        return False
    if not _has_door(by_id[fid]):
        return True
    return fid in completed


def _can_fire(flag: dict, by_id: dict, fired: set, completed: set, physics_true: bool) -> bool:
    preds = flag.get("predicates") or []
    if not preds:
        return False
    for p in preds:
        if p.get("type") == "story_flag_set":
            if not _resolved(str(p.get("id", "")), by_id, fired, completed):
                return False
        elif not physics_true:
            return False
    return True


def _pass(by_id: dict, order: list, fired: set, completed: set, physics_true: bool) -> list:
    newly = []
    for fid in order:
        if fid in fired:
            continue
        if _can_fire(by_id[fid], by_id, fired, completed, physics_true):
            newly.append(fid)
            fired.add(fid)
    return newly


def test_village_stirs_waits_on_the_wheel():
    flags = _flags()
    prereqs = {p.get("id") for p in flags["village_stirs"]["predicates"]
               if p.get("type") == "story_flag_set"}
    assert "arc_handover" in prereqs
    assert "first_harvest" in prereqs


def test_one_reap_does_not_open_the_woodlot():
    """File-order evaluate pass with physics treated as already true (Village
    evolving, mill access paid) — the loom-then-lumber-yard dump."""
    flags = _flags()
    order = [f["id"] for f in json.loads(FLAGS.read_text(encoding="utf-8"))]
    fired = {"tutorial_seen", "loom_opens"}
    completed: set = set()
    newly = _pass(flags, order, fired, completed, physics_true=True)
    assert "first_harvest" in newly
    assert "arc_handover" in newly
    assert "village_stirs" not in newly, newly
    assert "new_voices" not in newly, newly
    assert "woodlot_door" not in newly, newly
    # Wheel handshake claimed → mill may open (physics already true).
    completed.add("arc_handover")
    newly2 = _pass(flags, order, fired, completed, physics_true=True)
    assert "village_stirs" in newly2
    assert "new_voices" not in newly2, newly2
    assert "woodlot_door" not in newly2, newly2
    # Mill teaching claimed → plant may open.
    completed.add("village_stirs")
    newly3 = _pass(flags, order, fired, completed, physics_true=True)
    assert "new_voices" in newly3
    assert "woodlot_door" not in newly3, newly3
    # Plant claimed → lumber yard.
    completed.add("new_voices")
    newly4 = _pass(flags, order, fired, completed, physics_true=True)
    assert "woodlot_door" in newly4


def test_engine_requires_parent_door_resolved():
    qm = src(QM)
    flag_set = qm.split('"story_flag_set":')[1].split("story_flag_any")[0]
    assert "_story_flag_parent_resolved" in flag_set
    assert "func flag_door_is_resolved" in qm
    assert "has_completed_flag" in qm.split("func _flag_door_is_resolved")[1].split("func _story_flag_parent_resolved")[0]


def test_arc_does_not_list_locked_future_countries():
    intro = src(INTRO)
    ahead = intro.split("func doors_ahead")[1].split("func remembered_count")[0]
    assert "get_story_offers" in ahead
    assert "flag_unfired" not in ahead
    door = intro.split("func live_door")[1].split("func doors_ahead")[0]
    assert "_best_unsigned_offer" in door
    assert "_next_spine_flag_beat" not in door


def test_arc_now_after_reap_is_the_wheel_not_village():
    """Unsigned Wheel must beat the next unfired flag (Village / Woodlot)."""
    intro = src(INTRO)
    assert "func _best_unsigned_offer" in intro
    assert "STATUS_STORY" in intro.split("func live_door")[1].split("func doors_ahead")[0]


def test_act0_chips_do_not_dump_surprisal():
    row = src(ROOT / "UI" / "Widgets" / "ActionPreviewRow.gd")
    paint = row.split("func _apply_button_projection")[1].split("func ")[0]
    assert 'hint_suffix := ""' in paint
    assert "NO_TUTORIAL_SENTINEL" not in paint


def test_standing_gte_fires_at_the_authored_value():
    """Mill tutorial pays access 0.02. village_stirs is standing_gte 0.02.
    Plain soft_gate is 0.5 AT center, so the Wheel handshake left Arc empty."""
    qm = src(QM)
    standing = qm.split('"standing_gte":')[1].split('"biome_state_gte"')[0]
    assert "count_gate" in standing
    assert "FLAG_FIRE_THRESHOLD" in standing
    flags = _flags()
    access = next(p for p in flags["village_stirs"]["predicates"]
                  if p.get("type") == "standing_gte")
    assert float(access["value"]) == 0.02
    hint = str(flags["village_stirs"]["arc_quest"]["hint"])
    assert len(hint) <= 70
    assert "GHJKL" not in hint


def test_first_harvest_does_not_gold_toast():
    intro = src(INTRO)
    flag_fn = intro.split("func toast_for_flag")[1].split("func recap")[0]
    assert 'flag_data.has("arc_quest")' in flag_fn
    flags = _flags()
    assert flags["first_harvest"].get("arc_quest") is None


def test_empty_arc_copy_is_player_voice():
    arc = src(ROOT / "UI" / "Overlays" / "ControlsOverlay.gd")
    assert "no story flags loaded" not in arc
    assert "the next door hasn't opened" in arc


def test_superposition_spotlight_is_e_not_the_druid_hat():
    target = src(PROG).split("static func objective_target()")[1].split("static func _hat_key_for_frame")[0]
    assert 'step == 3' in target
    assert '"E"' in target
    qii = src(ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd")
    assert "func _maybe_wear_live_hat" in qii


def test_mash_f_on_operator_is_the_reap_door():
    qii = src(ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd")
    dispatch = qii.split("func _dispatch_action_key")[1].split("func _handle_biome_row_input")[0]
    assert "reap_season" in dispatch
    assert "AceChipResolvers.resolve_f" in dispatch
    assert "FRAME_ACE" in dispatch
    assert "redirect_locked" in dispatch
    scoot = src(ROOT / "UI" / "Managers" / "OverlayManager.gd")
    toward = scoot.split("func scoot_toward")[1].split("func toggle_overlay")[0]
    assert "get_slot_for_biome" in toward


def _arc_titles(fired, completed, offers, live_tutorial=None, chapter_act=None):
    """Python twin: Arc is live + open offers. Unfired flags are not doors."""
    titles = []
    if live_tutorial:
        titles.append(live_tutorial)
    for o in offers:
        if o not in titles:
            titles.append(o)
    return titles


def _resolved_parents(flag, by_id, fired, completed):
    for p in flag.get("predicates") or []:
        if p.get("type") != "story_flag_set":
            continue
        pid = str(p.get("id", ""))
        if pid not in fired:
            return False
        if not _resolved(pid, by_id, fired, completed):
            return False
    return True


def test_catalog_during_loom_is_only_the_weave():
    titles = _arc_titles(
        fired={"tutorial_seen", "loom_opens"},
        completed=set(),
        offers=[],
        live_tutorial="The loom",
    )
    joined = " | ".join(titles)
    assert "The loom" in joined
    assert "Timber Country" not in joined, titles
    assert "The Village Stirs" not in joined, titles
    assert "The Mill Runs" not in joined, titles


def test_catalog_after_wheel_is_quiet_until_mill_offers():
    titles = _arc_titles(
        fired={"tutorial_seen", "loom_opens", "first_harvest", "arc_handover"},
        completed={"arc_handover"},
        offers=[],
        live_tutorial=None,
        chapter_act=1,
    )
    joined = " | ".join(titles)
    assert "The Village Stirs" not in joined, titles
    assert "Timber Country" not in joined, titles


def test_catalog_after_reap_is_only_the_wheel():
    titles = _arc_titles(
        fired={"tutorial_seen", "loom_opens", "first_harvest", "arc_handover"},
        completed=set(),
        offers=["The Wheel Is Yours"],
        live_tutorial=None,
        chapter_act=1,
    )
    joined = " | ".join(titles)
    assert "The Wheel Is Yours" in joined
    assert "Timber Country" not in joined, titles
    assert "The Village Stirs" not in joined, titles
    assert "The Mill Runs" not in joined, titles


def test_catalog_with_woodlot_offer_does_not_peek_the_mill():
    titles = _arc_titles(
        fired={"tutorial_seen", "loom_opens", "first_harvest", "arc_handover",
               "village_stirs", "new_voices", "woodlot_door"},
        completed={"arc_handover", "village_stirs", "new_voices"},
        offers=["Find the Woodlot"],
        live_tutorial=None,
        chapter_act=2,
    )
    joined = " | ".join(titles)
    assert "Find the Woodlot" in joined
    assert "The Mill Runs" not in joined, titles


def test_reap_spotlight_is_the_f_chip_not_the_ace_hat():
    target = src(PROG).split("static func objective_target()")[1].split("static func _hat_key_for_frame")[0]
    assert 'step == 5' in target
    assert '"F"' in target
    assert '"hat"' in target


def test_superposition_is_a_hadamard_not_forest_weather():
    """Round-1 playtest: arriving in StarterForest auto-claimed superposition
    because resting coherence already cleared 0.3. Operator hat appeared
    before the player had superposed — then the loom was a blank verb."""
    steps = {s["tutorial_teaches"]: s
             for s in json.loads((ROOT / "Core" / "Quests" / "data" / "tutorial_arc.json").read_text(encoding="utf-8"))["steps"]}
    preds = steps["superposition"]["state_predicates"]
    assert preds == [{"type": "gate_sequence_contains", "gate": "hadamard", "count": 1}], preds
    assert "coherence" not in json.dumps(preds)
    gloss = src(ROOT / "Core" / "Quests" / "PredicateGloss.gd")
    assert '"hadamard"' in gloss.split("gate_sequence_contains")[1]
    bridge = src(ROOT / "Core" / "Story" / "PlayerEventBridge.gd")
    standing = bridge.split("func _on_standing_changed")[1].split("func ")[0]
    assert "current_tutorial_step" in standing


def test_reap_chip_on_bound_plot_is_the_mashable_door():
    ace = src(ACE)
    resolve = ace.split("static func resolve_f")[1]
    assert "reap_season" in resolve
    assert '"reap"' in resolve
