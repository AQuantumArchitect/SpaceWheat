"""The discover rule (2026-11-16).

Farm.discover_icon no longer refuses a word whose north is already a pole of
a known word. The owner's ruling: that was a helper for the randomizer, not a
rule of the game. Both words of a pair can be known, and the same word in its
other spelling is still "already known". tests/inverted_seat_probe.gd prints
the LEARN line this reads.
"""
import json
import os
import shutil
import subprocess

import pytest

from conftest import ROOT

PROBE = "tests/inverted_seat_probe.gd"


@pytest.fixture(scope="module")
def learn(tmp_path_factory):
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    tmp = tmp_path_factory.mktemp("discover_rule_probe")
    env = dict(os.environ, APPDATA=str(tmp), XDG_DATA_HOME=str(tmp))
    r = subprocess.run(["godot", "--headless", "--script", PROBE], cwd=ROOT, capture_output=True,
                       text=True, encoding="utf-8", timeout=300, env=env)
    out = r.stdout + r.stderr
    assert r.returncode == 0, out[-3000:]
    for line in out.splitlines():
        if line.startswith("LEARN "):
            return json.loads(line[len("LEARN "):])
    pytest.fail("no LEARN line:\n" + out[-3000:])


def test_discover_learns_both_words_and_overlapping_norths(learn):
    assert learn["predation_after_raptor"] is True     # north 🦅 is Raptor's pole
    assert learn["bread_after_labor"] is True          # the other word of 👥/🍞
    assert learn["factory_inverted"] is True
    assert learn["labor_again"] is False                # already known
    assert learn["factory_own_after_inverted"] is False  # same word, other spelling
    assert learn["subsistence_own_after_starter"] is False
    assert learn["same_poles"] is False
    assert learn["size"] == 6


def test_no_mirror_keeps_the_pole_overlap_rule():
    farm = (ROOT / "Core/Farm.gd").read_text(encoding="utf-8")
    body = farm.split("func discover_icon(")[1].split("\nfunc ")[0]
    assert "existing_north" not in body and "same_word" in body
    guide = (ROOT / "Core/Campaign/Guide.gd").read_text(encoding="utf-8")
    cols = guide.split("static func _unknown_cols(")[1].split("\nstatic func ")[0]
    assert "anchored" not in cols and "same_word" in cols
    val = (ROOT / "tools/campaign/validate.py").read_text(encoding="utf-8")
    learn_src = val.split("def learn(p):")[1].split("\n        for p in known:")[0]
    assert "poles" not in learn_src
    qii = (ROOT / "UI/Core/QuantumInstrumentInput.gd").read_text(encoding="utf-8")
    assert "already anchors one of your words" not in qii
