"""Beat fixtures: `start_at_beat {id}` builds the state a player holds when a
beat OPENS, from the spec alone (Core/Campaign/CampaignFixture.gd), so any beat
of any campaign is one rig verb away — no minted saves, no injected economy.

Fast half (no Godot): tools/campaign/fixture_order.py agrees with the spec.
Slow half (headless Godot, one boot per beat): for one beat per chapter across
all three campaigns, start_at_beat then assert
  * the GDScript ancestor walk is the spec's (same beats, same order),
  * every ancestor door was claimed through the real claim path,
  * the beat itself opened on QuestManager's own evaluator (never forced) and
    its arc offer is on the board (auto beats: the flag fired),
  * the hats / menus / overlays the spec unlocks are visible per UIProgression,
  * the charted ancestor biomes the fixture promises are loaded.

Skip the slow half with SW_SKIP_LONG=1 (it also skips itself without godot).
"""
import os
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "campaign"))
import fixture_order as FO  # noqa: E402
import spec as S  # noqa: E402

LONG = pytest.mark.skipif(os.environ.get("SW_SKIP_LONG") == "1",
                          reason="SW_SKIP_LONG=1 — headless campaign fixtures skipped")

BEATS = FO.representative_beats()


# --------------------------------------------------------------- fast (spec only)

def test_one_fixture_beat_per_chapter_in_every_campaign():
    spec = S.load()
    chapters = {(c["id"], a["act"], ch["id"]) for c, a, ch, _b in S.iter_beats(spec)
                if ch.get("kind") != "tutorial"}
    idx = S.beats_by_id(spec)
    covered = {(idx[b][0]["id"], idx[b][1]["act"], idx[b][2]["id"]) for b in BEATS}
    assert covered == chapters
    assert {idx[b][0]["id"] for b in BEATS} == {c["id"] for c in spec["campaigns"]}


@pytest.mark.parametrize("beat", [b["id"] for _c, _a, _ch, b in S.iter_beats(S.load())])
def test_fixture_ancestors_are_a_topological_requires_closure(beat):
    spec = S.load()
    idx = S.beats_by_id(spec)
    anc = FO.ancestors(beat, spec)
    pos = {b: i for i, b in enumerate(anc)}
    assert beat not in pos
    assert len(pos) == len(anc), "an ancestor is listed twice"
    for b in anc + [beat]:
        for r in idx[b][3].get("requires", []):
            assert r in pos, "%s requires %s, missing from %s's fixture" % (b, r, beat)
            if b != beat:
                assert pos[r] < pos[b], "%s listed before its parent %s" % (b, r)


def test_fixture_plan_keeps_charted_biomes_within_the_slot_row():
    for _c, _a, _ch, b in S.iter_beats(S.load()):
        p = FO.plan(b["id"])
        assert len(p["expected_loaded"]) <= FO.BIOME_SLOTS - len(FO.SEED_BIOMES)
        for need in p["reads_biomes"]:
            if need in p["charted"]:
                assert need in p["expected_loaded"], (
                    "%s reads %s (charted by an ancestor) but the fixture would not load it"
                    % (b["id"], need))


# --------------------------------------------------------------- slow (headless)

def _boot(rig_boot, beat):
    return rig_boot(prefix="sw_fixture_%s_" % beat, scenario_id="demos_normal",
                    display_mode="headless", allow_resource_injection=False,
                    listener_stdout="null", rig_log_profile="quiet",
                    extra_env={"RIG_UNLOCK_ALL": "0", "RIG_QUEUE_POLL_MS": "60"},
                    sentinel_timeout_s=240.0)


@LONG
@pytest.mark.parametrize("beat", BEATS)
def test_start_at_beat_opens_the_beat(rig_boot, beat):
    plan = FO.plan(beat)
    rig, _proc = _boot(rig_boot, beat)
    r = rig.run_turn(1, "start_at_beat", id=beat, wait_frames=300, timeout_s=240)
    assert r.get("ok"), r
    rep = r["report"]
    assert rep["ancestors"] == plan["ancestors"], "GDScript and spec.py disagree on the ancestor walk"
    assert rep["requires_resolved"], rep
    assert sorted(rep["doors"]) == sorted(plan["doors"]), (
        "doors not claimed: %s" % sorted(set(plan["doors"]) - set(rep["doors"])))
    assert not r["forced"]
    assert r["fired"], "%s did not open on its own evaluator (score %.3f)" % (beat, r.get("score", 0))
    if not plan["auto"]:
        assert r["offer_present"], "%s fired but its arc offer is not on the board" % beat
        offers = rig.run_turn(2, "story_offers", timeout_s=60).get("story_offers", [])
        assert any(o.get("source_flag") == beat for o in offers), offers

    ui = rig.run_turn(3, "ui_unlocks", timeout_s=60)
    for kind in ("hats", "menus", "viz"):
        for name in plan[kind]:
            assert ui[kind].get(name), "%s: spec unlocks %s %r but UIProgression hides it" % (
                beat, kind, name)
    assert ui["tutorial_step"] == 999, "Act 0 still live after the fixture"

    loaded = set(r.get("loaded_biomes", []))
    for b in plan["expected_loaded"]:
        assert b in loaded, "%s: charted ancestor biome %s not loaded (%s)" % (beat, b, sorted(loaded))
