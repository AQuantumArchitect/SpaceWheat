"""Issue #123, milk endgame part 2: plant a 🍼 icon at home to win the demo.

tests/milk_win_probe.gd boots a new game headless, fast-forwards to the
"Milk at Home" beat, injects Birth (🍼/✨) into StarterForest (a Demos home
biome) and checks the win fires, the EndingOverlay spawn rule opens the
demo-won ceremony, and reap then succeeds with no 🍼 in the wallet. The
source pins below run without Godot.
"""
import json
import os
import shutil
import subprocess

import pytest

from conftest import ROOT

PROBE = "tests/milk_win_probe.gd"
SR = ROOT / "Core" / "GameMechanics" / "StapleRescue.gd"


def _fn(text: str, name: str) -> str:
    return text.split("func %s(" % name)[1].split("\nfunc ")[0].split("\nstatic func ")[0]


@pytest.fixture(scope="module")
def checks(tmp_path_factory):
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    tmp = tmp_path_factory.mktemp("milk_win_probe")
    env = dict(os.environ)
    env["APPDATA"] = str(tmp)
    env["XDG_DATA_HOME"] = str(tmp)
    env["SW_PROBE_USER_DIR_PREFIX"] = str(tmp)
    result = subprocess.run(
        ["godot", "--headless", "--audio-driver", "Dummy", "--fixed-fps", "10", "--script", PROBE],
        cwd=ROOT, capture_output=True, text=True, encoding="utf-8", timeout=600, env=env)
    out = result.stdout + result.stderr
    assert result.returncode == 0, out[-3000:]
    assert "SCRIPT ERROR" not in out and "Parse Error" not in out, out[-3000:]
    rows = {}
    for line in result.stdout.splitlines():
        if line.startswith("MILK "):
            row = json.loads(line[len("MILK "):])
            rows[row["check"]] = row
    return rows


def test_before_planting_no_win_and_reap_is_refused(checks):
    c = checks["before"]
    assert c["fixture_ok"] and c["requires_resolved"]
    assert c["homes"] == ["StarterForest", "Village"]
    assert c["at_home"] is False and c["win_fired"] is False
    assert c["reap_ok"] is False and c["reap_error"] == "insufficient_resources"


def test_injecting_milk_at_home_wins_and_opens_the_overlay(checks):
    assert checks["inject"]["ok"], checks["inject"]
    assert checks["inject"]["home"] == "StarterForest"
    w = checks["win"]
    assert w["fired"] and w["signal"] and w["is_win"]
    assert w["overlay"] and w["won_demo"]
    assert w["title"][0] == "You've won the demo."


def test_reap_then_succeeds_without_milk_in_the_wallet(checks):
    r = checks["reap"]
    assert r["short_before"] is False, "🍼 at home: the wallet is never short"
    assert r["ok"], r
    assert r["short_after"] is False


# ---- source pins (no Godot needed) ----

def test_win_beat_is_compiled_with_the_home_predicate():
    flags = {f["id"]: f for f in json.loads(
        (ROOT / "Core/Quests/data/story_flags.json").read_text(encoding="utf-8"))}
    f = flags["milk_at_home"]
    assert f["win"] is True and f["campaign"] == "demos"
    assert {"type": "story_flag_set", "id": "find_the_milk"} in f["predicates"]
    assert {"type": "home_biome_has_emoji", "emoji": "🍼"} in f["predicates"]


def test_home_milk_is_read_from_the_registers_and_covers_the_reap():
    src = SR.read_text(encoding="utf-8")
    assert "governing_biome_slots" in _fn(src, "home_biomes")
    assert "register_map" in _fn(src, "home_biome_with")
    assert "milk_at_home(farm)" in _fn(src, "milk_short")
    assert 'add_resource(MILK, short, "home_milk", home)' in _fn(src, "draw_home_milk")
    probe = (ROOT / "Core/Actions/ProbeActions.gd").read_text(encoding="utf-8")
    body = _fn(probe, "action_reap")
    assert body.index("StapleRescue.draw_home_milk(farm, reap_cost)") < body.index("_preflight_cost(economy, reap_cost)")


def test_runtime_mount_uses_the_one_spawn_rule():
    rm = (ROOT / "Core/Boot/RuntimeMount.gd").read_text(encoding="utf-8")
    assert "EndingOverlay.spawn_for_flag(flag, overlay_layer_ref, farm_ref, shell_ref)" in rm
    eo = (ROOT / "UI/Overlays/EndingOverlay.gd").read_text(encoding="utf-8")
    rule = _fn(eo, "spawn_for_flag")
    assert "is_win(flag)" in rule and "CampaignFixture.replaying" in rule
