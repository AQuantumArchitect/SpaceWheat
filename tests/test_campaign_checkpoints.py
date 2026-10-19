"""Campaign assert gate: per-act states survive a save/load roundtrip.

This used to replay minted checkpoint saves (🍄/🧪/checkpoints/act*_complete,
endrun_*). Those were banked from a pre-restructure graph by a driver that ran
RIG_UNLOCK_ALL=1 with injected resources, so they asserted nothing about the
current campaign. The states now come from `start_at_beat` fixtures
(Core/Campaign/CampaignFixture.gd), built from the spec on a fresh boot.

Two claims per spine beat (one per act of the main campaign, plus the
post-game openers):
  1. A save written at the moment the beat opens loads back in the current
     build (save-migration canary).
  2. Every flag fired and every arc door claimed before the save is still
     fired / claimed after the load — the "post-load state loss" bug family
     (quest ledger, berry credit, offer regeneration have each independently
     lost state on load before) keeps a standing per-act tripwire.

Plus one fire_flag consequence test: forcing a flag through the REAL
_fire_story_flag path must land it in story_flags_fired, append its beat to the
story log, and put its arc_quest on the offer board.

Skip with SW_SKIP_LONG=1 (also skipped without godot on PATH).
"""

import os
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "campaign"))
import fixture_order as FO  # noqa: E402

LONG = pytest.mark.skipif(os.environ.get("SW_SKIP_LONG") == "1",
                          reason="SW_SKIP_LONG=1 — headless campaign gate skipped")

# act 1 · act 2 · act 3 · act 4 hub · post-game openers
SPINE = ["village_stirs", "woodlot_contact", "forest_listener", "village_identity",
         "lantern_door", "braid_order"]


def _boot(rig_boot, name):
    return rig_boot(prefix="sw_campaign_gate_%s_" % name, scenario_id="demos_normal",
                    display_mode="headless", allow_resource_injection=False,
                    listener_stdout="null", rig_log_profile="quiet",
                    sentinel_timeout_s=240.0)


@LONG
@pytest.mark.parametrize("beat", SPINE)
def test_fixture_state_survives_save_and_load(rig_boot, tmp_path, beat):
    rig, _proc = _boot(rig_boot, beat)
    r = rig.run_turn(1, "start_at_beat", id=beat, timeout_s=240)
    assert r.get("ok") and r.get("fired"), "fixture did not open %s: %r" % (beat, r)
    before = set(rig.run_turn(2, "story_flags", timeout_s=60).get("flags_fired", {}))
    assert set(FO.ancestors(beat)) | {beat} <= before

    path = tmp_path / ("gate_%s.tres" % beat)
    saved = rig.run_turn(3, "save_game_path", path=str(path), timeout_s=120)
    assert saved.get("saved"), saved
    loaded = rig.run_turn(4, "load_game_path", path=str(path), timeout_s=240)
    assert loaded.get("loaded", False), "fixture save failed to load: %r" % loaded

    after = set(rig.run_turn(5, "story_flags", timeout_s=60).get("flags_fired", {}))
    missing = sorted(before - after)
    assert not missing, "%s: %d flag(s) fired before save are gone after load: %s" % (
        beat, len(missing), missing)
    ledger = rig.run_turn(6, "quest_ledger", timeout_s=60)
    claimed = {q.get("source_flag") for q in ledger.get("completed", [])}
    lost = [d for d in FO.plan(beat)["doors"] if d not in claimed]
    assert not lost, "%s: claimed doors lost on load: %s" % (beat, lost)


@LONG
def test_fire_flag_consequences_react(rig_boot):
    """spring_door forced through the real path: fired + logged + offered."""
    rig, proc = rig_boot(prefix="sw_campaign_gate_fireflag_",
                         scenario_id="demos_normal", display_mode="headless")
    before = rig.run_turn(1, "story_flags", timeout_s=45)
    assert "spring_door" not in before.get("flags_fired", {}), \
        "spring_door already fired at fresh boot — premise broken"
    log_before = len(before.get("story_log", []))

    fired = rig.run_turn(2, "fire_flag", id="spring_door", timeout_s=60)
    assert fired.get("fired", False), "fire_flag did not fire: %r" % fired

    after = rig.run_turn(3, "story_flags", timeout_s=45)
    assert "spring_door" in after.get("flags_fired", {})
    log_after = after.get("story_log", [])
    assert len(log_after) > log_before, "story log did not grow on flag fire"
    assert any(e.get("id") == "spring_door" for e in log_after), \
        "spring_door beat missing from story log"

    offers = rig.run_turn(4, "story_offers", timeout_s=45)
    offer_flags = {str(o.get("source_flag", ""))
                   for o in offers.get("story_offers", []) if isinstance(o, dict)}
    assert "spring_door" in offer_flags, \
        "arc quest for spring_door not on the offer board: %r" % offers
