"""The first Icon lesson after the Village is fire and ice (#125).

Luke (2026-11-14): First Breath, the beat that teaches Incorporate right after
the Village apprenticeship, has the player track and incorporate 🔥/❄, because
the Druid spends 🔥 on Superpose. The objective is any Village loop
(berry_consumed_count_gte Village ≥ 1) with `prefer` [🔥, ❄]: the Guide's berry
walk sends the player to that plot (Guide._prefer_cols), and when the word is
not on the field, or stands still, it falls back to the first trackable plot.

The live check boots the real game, builds first_breath's opening state with
the spec fixture, and lets the strict banner follower (🍄/🧪/banner_follow.py)
press only the keys the banner names. It must claim the beat, with 🔥/❄ as the
newest word on the incorporation ledger, which is the word spiral_breaks' strike
then points at (Guide.known_word_col, newest first).
"""
import json
import os
import shutil
import sys
import tempfile
import time
from pathlib import Path

import pytest

from conftest import ROOT, read_source

sys.path.insert(0, str(ROOT / "🍄" / "🧪"))
sys.path.insert(0, str(ROOT / "🍄" / "🎛️"))

FIRE_ICE = {"🔥", "❄"}
# Strict follower, from Accept to Claim. Measured 2026-11-15 on this runner:
# see the PR. The bound leaves room for a slower CI machine.
FOLLOW_SECONDS_MAX = 240


def _beats():
    spec = json.loads(read_source("Core/Campaign/campaign.json"))
    out = {}
    for act in spec["campaigns"][0]["acts"]:
        for ch in act["chapters"]:
            for b in ch.get("beats", []):
                out[b["id"]] = b
    return out


def test_first_breath_counts_a_village_loop_and_prefers_fire_and_ice():
    fb = _beats()["first_breath"]
    assert fb["requires"] == ["village_stirs"]
    objs = fb["objective"]
    assert [o["type"] for o in objs] == ["berry_consumed_count_gte"], objs
    assert objs[0]["biome"] == "Village"
    assert set(objs[0]["prefer"]) == FIRE_ICE
    # The prefer word must be spelled as the Village's register spells it.
    biomes = json.loads(read_source("Core/Biomes/data/biomes.json"))
    rows = biomes if isinstance(biomes, list) else biomes.get("biomes", list(biomes.values()))
    village = next(b for b in rows if isinstance(b, dict) and b.get("name") == "Village")
    assert FIRE_ICE <= set(village["emojis"])
    for text in (fb["beat"], fb["offer"]["body"], fb["offer"]["hint"]):
        assert "🔥" in text and "❄" in text, text
    assert "Village" in fb["offer"]["hint"]


def test_the_berry_walk_reads_prefer_and_falls_back():
    guide = read_source("Core/Campaign/Guide.gd")
    assert '"berry":\n\t\t\treturn _berry(q, _prefer_cols(pred))' in guide
    pc = guide.split("static func _prefer_cols(")[1].split("\nstatic func ")[0]
    assert "_axis_cols(" in pc and "qubit_has_transverse_term" in pc
    # _berry with an empty `only` is the procedural pick: the fallback.
    berry = guide.split("static func _berry(")[1].split("\nstatic func ")[0]
    assert "not only.is_empty() and not (col in only)" in berry


def test_spiral_breaks_takes_its_word_from_the_forest_after_the_village():
    spec = json.loads(read_source("Core/Campaign/campaign.json"))
    assert spec["params"]["berry"]["first_breath"] == 1
    assert spec["params"]["berry"]["spiral"] == 1
    sb = _beats()["spiral_breaks"]
    berry = [o for o in sb["objective"] if o["type"] == "berry_consumed_count_gte"]
    assert berry and berry[0]["biome"] == "StarterForest"


@pytest.fixture(scope="module")
def follow():
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    import banner_follow as BF
    from rig_client import RigClient
    xdg = Path(tempfile.mkdtemp(prefix="sw_fire_ice_"))
    rig = RigClient(xdg=xdg, root_from_file=ROOT / "🍄" / "🎛️" / "milk_hunt_runner.py")
    rig.clear_rig_files()
    proc = rig.start_listener(scenario_id="demos_normal", display_mode="headless",
                              allow_resource_injection=False, listener_stdout="null",
                              rig_log_profile="quiet",
                              extra_env={"RIG_UNLOCK_ALL": "0", "RIG_QUEUE_POLL_MS": "60"})
    try:
        assert RigClient.wait_for_bridge_sentinel(timeout_s=240, xdg=rig.xdg_root), "rig did not boot"
        rep = BF.follow(rig, "first_breath")
        f = BF.Follower(rig)
        f.n = 10000
        rep["ledger"] = f.t("known_icons").get("incorporated", [])
        rep["village_berries"] = f.t("berry_state", biome="Village").get("consumed_count", -1)
        # Keep following until the banner names the strike (spiral_breaks is
        # offered on the claim, so its Accept comes first).
        rep["lines_after"] = []
        for _ in range(12):
            line = (f.banner() or [""])[0]
            rep["lines_after"].append(line)
            if "Strike" in line or not BF.parse_keys(line):
                break
            for key, shift in BF.parse_keys(line):
                f.t("press_key", key=key, shift=shift, settle_frames=12)
            time.sleep(0.15)
        return rep
    finally:
        RigClient.terminate_listener(proc, timeout_s=5.0)
        shutil.rmtree(xdg, ignore_errors=True)


def test_a_strict_follower_ripens_and_incorporates_fire_and_ice(follow):
    print("FIRE_ICE_FOLLOW", json.dumps({k: follow.get(k) for k in (
        "outcome", "presses", "waits", "follow_seconds", "moved_by", "ledger", "village_berries")},
        ensure_ascii=False))
    assert follow["outcome"] == "moved", follow
    assert follow["moved_by"]["beat_claimed"], follow
    assert follow["village_berries"] >= 1, follow
    newest = follow["ledger"][-1] if follow["ledger"] else {}
    assert {str(newest.get("north")), str(newest.get("south"))} == FIRE_ICE, follow["ledger"]
    assert follow["follow_seconds"] <= FOLLOW_SECONDS_MAX, follow


def test_after_the_lesson_the_guide_points_at_fire_and_ice(follow):
    """spiral_breaks opens on the claim; its lead objective is the strike on
    the word just learned, so the banner names the glowing 🔥/❄ plot."""
    print("FIRE_ICE_AFTER", json.dumps(follow["lines_after"], ensure_ascii=False))
    strike = [ln for ln in follow["lines_after"] if "Strike" in ln]
    assert strike and "🔥/❄" in strike[0], follow["lines_after"]
