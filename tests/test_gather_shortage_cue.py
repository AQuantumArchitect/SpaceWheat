"""Issue #87 — out of the gather fee, guidance is a function of state.

Luke's playtest (2026-11-14): during the Act-0 lessons he ran out of 🧺, the
banner kept naming Explore / Strike / Gather, and the way to the Market only
showed on the toast of a refused press. After a Market visit that bought
nothing, it was gone again.

The pins:
  * Guide.next_step runs every step through `_afford`: a step whose fee the
    wallet can't pay becomes the walk to that fee, every frame the shortage
    holds, and stops once the wallet can pay;
  * a lap (explore, strike, gather) counts the basket from its first key;
  * a guaranteed staple rescue is never hidden by the "not on the ring" mark;
  * a wallet no Village trade chain can rescue (0🧺 · 3👥 · 0🌾) has the fee
    waived (StapleRescue), so there is always a free move in the loop;
  * the real game, booted headless, does all of that
    (tests/gather_shortage_cue.gd).
"""
from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
PROBE = ROOT / "tests" / "gather_shortage_cue.gd"
GUIDE = ROOT / "Core" / "Campaign" / "Guide.gd"
RESCUE = ROOT / "Core" / "GameMechanics" / "StapleRescue.gd"
ECON = ROOT / "Core" / "GameMechanics" / "FarmEconomy.gd"
FADE = ROOT / "Core" / "Campaign" / "GuideFade.gd"


def _fn(path: Path, name: str) -> str:
    return path.read_text(encoding="utf-8").split("func %s(" % name)[1].split("\nstatic func ")[0].split("\nfunc ")[0]


def test_every_guide_step_is_checked_against_the_wallet():
    body = _fn(GUIDE, "next_step")
    assert "_afford(_tutorial_step()" in body
    assert "_afford(step, q)" in body
    afford = _fn(GUIDE, "_afford")
    assert "_supply(" in afford
    # A shortage step says why it is there.
    assert "out of %s" in _fn(GUIDE, "_short_of")


def test_a_lap_counts_the_basket_from_its_first_key():
    strike = _fn(GUIDE, "_strike_once")
    assert strike.count("_lap(") >= 4  # travel, hat, strike, explore


def test_a_guaranteed_staple_rescue_is_never_ruled_out():
    body = _fn(GUIDE, "_trade_ruled_out")
    assert "_rescue_open(res)" in body
    assert body.index("_rescue_open(res)") < body.index("_no_trade_until")


def test_the_waiver_sits_on_the_one_cost_lookup():
    assert "StapleRescue.effective_cost(" in _fn(ECON, "get_action_cost")
    src = RESCUE.read_text(encoding="utf-8")
    assert 'const VERB_STAPLE := {"pop": "🧺", "measure": "👥", "explore": "🍞"}' in src


def test_a_shortage_banner_does_not_wait_to_fade_in():
    assert ".shortage" in _fn(FADE, "delay_s")


@pytest.fixture(scope="module")
def cue() -> dict:
    if shutil.which("godot") is None:
        pytest.skip("godot not on PATH — cannot boot the real game")
    proc = subprocess.run(["godot", "--headless", "--path", ".", "--script", str(PROBE)],
                          cwd=ROOT, capture_output=True, text=True, timeout=420)
    line = next((l for l in proc.stdout.splitlines()
                 if l.strip().startswith("{") and '"gather-shortage-cue"' in l), None)
    assert line, f"probe emitted no JSON.\nstdout:\n{proc.stdout[-3000:]}\nstderr:\n{proc.stderr[-3000:]}"
    return json.loads(line)


def test_the_cue_holds_while_the_shortage_does(cue):
    assert cue["fails"] == [], cue
    cues = cue["cues"]
    for tag in ("drained", "on_market", "after_market", "after_market_later"):
        assert cues[tag]["short"] == "🧺", (tag, cues[tag])
    assert cues["full"]["short"] == "" and cues["restored"]["short"] == ""


def test_a_stranded_wallet_gathers_for_free(cue):
    assert cue["stranded_pop"]["success"] is True, cue["stranded_pop"]
    assert "free" in cue["cues"]["stranded"]["text"]


def test_no_small_wallet_is_a_dead_end(cue):
    assert cue["sweep_checked"] > 0
