"""Tutorial-arc data lint (2026-08-17 campaign reorder).

Two drift classes this reorder made possible, each of which failed silently
before:

  (a) `tutorial_step` fields drifting from array position — the loader welds
      chain_unlocks by ARRAY ORDER while UIProgression's verb/menu tables key
      on the `tutorial_step` NUMBER; if the two disagree, locked keys point at
      the wrong step and the redirect toast teaches the wrong lesson.
  (b) `unlock_flags` naming a flag that no longer exists in story_flags.json —
      the old `forest_listener` handoff moved to the act-3 chapter, and a
      dangling handoff would strand the Operator hat under player-parity
      enforcement (Break #2) with no error anywhere.

Plus the reorder's own contract: the unlock tables in UIProgression.gd may
only name real story-flag ids (any-of arrays included) — these tables fail
CLOSED against a live farm, so a typo'd flag is a permanently lost hat.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARC = ROOT / "Core" / "Quests" / "data" / "tutorial_arc.json"
STORY_FLAGS = ROOT / "Core" / "Quests" / "data" / "story_flags.json"
PROGRESSION = ROOT / "UI" / "Core" / "UIProgression.gd"


def _steps():
    return json.loads(ARC.read_text(encoding="utf-8"))["steps"]


def _flag_ids():
    return {str(f["id"]) for f in json.loads(STORY_FLAGS.read_text(encoding="utf-8"))}


def test_tutorial_step_numbers_match_array_position():
    for i, s in enumerate(_steps()):
        assert int(s.get("tutorial_step", -1)) == i, (
            "step at array index %d carries tutorial_step=%s — the loader chains "
            "by array order, UIProgression gates by the number; they must agree"
            % (i, s.get("tutorial_step"))
        )


def test_exactly_one_unlock_flags_handoff_and_it_resolves():
    steps = _steps()
    known = _flag_ids()
    handoffs = [(s["tutorial_step"], list(s["unlock_flags"]))
                for s in steps if s.get("unlock_flags")]
    assert len(handoffs) == 1, (
        "the tutorial hands the spine forward exactly once (Break #2 — the "
        "superposition step unlocks the Operator hat); found %r" % (handoffs,)
    )
    for step, flag_list in handoffs:
        for fid in flag_list:
            assert str(fid) in known, (
                "step %s unlock_flags names %r — not a story_flags.json id; a "
                "dangling handoff silently strands the Operator hat" % (step, fid)
            )


def test_unlock_tables_name_real_flags():
    src = PROGRESSION.read_text(encoding="utf-8")
    known = _flag_ids()
    for table in ("HAT_UNLOCK_FLAGS", "MENU_UNLOCK_FLAGS", "VIZ_UNLOCK_FLAGS"):
        m = re.search(r"const %s\s*:\s*Dictionary\s*=\s*\{(.*?)\n\}" % table, src, re.S)
        assert m, "%s moved — update this test's extraction" % table
        body = re.sub(r"#[^\n]*", "", m.group(1))  # strip comments before reading values
        # Values are either "flag" strings or ["new", "legacy"] any-of arrays;
        # keys (menu/frame ids) sit left of ':' — take only right-hand strings.
        for rhs in re.findall(r':\s*("[^"]*"|\[[^\]]*\])', body):
            for fid in re.findall(r'"([^"]*)"', rhs):
                if fid == "":
                    continue  # "" = always unlocked
                assert fid in known, (
                    "%s names %r — not a story_flags.json id. These tables fail "
                    "CLOSED with a live farm: a phantom flag is a permanently "
                    "lost surface." % (table, fid)
                )


def test_reap_capstone_is_last_and_funded():
    """The reap capstone contract (2026-08-17): reap is once-affordable early
    (Fibonacci 🍼 costs, wallet floor 1) and reaps EVERY biome at once, so it
    must be the LAST Act-0 step — landed on a field the player actually built
    — and some earlier step must grant >= 1 🍼 so the capstone is always
    solvent, even on a degenerate save that lost the session floor."""
    steps = _steps()
    assert steps, "tutorial arc is empty"
    assert str(steps[-1].get("tutorial_teaches", "")) == "reap_season", (
        "reap_season must be the Act-0 capstone (last step) — it is "
        "once-affordable early and lands biggest on a developed field; found "
        "%r last" % steps[-1].get("tutorial_teaches")
    )
    milk = 0
    for s in steps[:-1]:
        rewards = s.get("reward_resources") or {}
        milk += int(rewards.get("🍼", 0))
    assert milk >= 1, (
        "no earlier step grants 🍼 — the capstone reap costs 1 🍼 and the "
        "starting wallet holds exactly 1; without a granted bottle a wasted "
        "or missing floor bricks Act 0"
    )


def test_act0_has_a_fireable_spine_beat():
    """StoryAtlas.current_act walks a contiguous fired prefix over acts present.
    Act 0 must therefore keep at least one beat a fresh player actually fires
    (non-empty predicates) — first_harvest, fired by the reap step. loom_opens
    deliberately has NO predicates (handoff-only) and does not count."""
    flags = json.loads(STORY_FLAGS.read_text(encoding="utf-8"))
    act0_fireable = [f for f in flags
                     if int(f.get("act", -1)) == 0 and (f.get("predicates") or [])]
    assert act0_fireable, (
        "no act-0 beat with predicates — current_act could never leave 0 on a "
        "fresh road and the tutorial would never retire"
    )
