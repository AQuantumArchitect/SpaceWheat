"""Known words glow everywhere, and the glow is the payout (#105).

Luke's playtest, 2026-11-14: a plot whose word you have incorporated glows in
every biome. The rule is the vocabulary (ProbeActions.word_known over
farm.incorporated_icons), not a Demos special case; the same check pays the
strike multiplier, and a strike on a glowing plot shows the bonus it paid.
The campaign teaches it on the beat after the Millwright vocabulary charge
(first_breath follows village_stirs), and after the first incorporate the
guide sends the player to the word just learned (spiral_breaks' lead
objective, Guide.known_word_col newest-first).

tests/known_word_probe.gd boots the real game headless; see its header.
"""
import json
import os
import shutil
import subprocess

import pytest

from conftest import ROOT, read_source

PROBE = "tests/known_word_probe.gd"


def _godot_env(tmp):
    env = dict(os.environ)
    env["APPDATA"] = str(tmp)
    env["XDG_DATA_HOME"] = str(tmp)
    env["SW_PROBE_USER_DIR_PREFIX"] = str(tmp)
    env["RIG_UNLOCK_ALL"] = "1"
    return env


@pytest.fixture(scope="module")
def phases(tmp_path_factory):
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    tmp = tmp_path_factory.mktemp("known_word_probe")
    result = subprocess.run(["godot", "--headless", "--script", PROBE], cwd=ROOT,
                            capture_output=True, text=True, encoding="utf-8",
                            timeout=400, env=_godot_env(tmp))
    out = result.stdout + result.stderr
    assert result.returncode == 0, f"{PROBE} failed:\n{out[-3000:]}"
    assert "SCRIPT ERROR" not in out and "Parse Error" not in out, out[-3000:]
    rows = [json.loads(l[len("KNOWN_TRACE "):]) for l in result.stdout.splitlines()
            if l.startswith("KNOWN_TRACE ")]
    return {r["phase"]: r for r in rows}


def test_an_empty_ledger_still_knows_the_demos_own_words(phases):
    # The vocabulary is the home biome's axes + the ledger: with nothing
    # incorporated the Demos glows fully; no other biome's word is known.
    b = phases["before"]
    assert b["ledger"] == 0, b
    assert b["lit"]["TheDemos"], b
    assert all(t == "icon" for t in b["tiers"]["TheDemos"]), b
    for biome, regs in b["lit"].items():
        if biome != "TheDemos":
            assert regs == [], (biome, b)


def test_the_glow_is_derived_from_the_vocabulary_in_every_loaded_biome(phases):
    led = phases["ledger"]
    known = [tuple(led["word"]), ("🌾", "👥"), ("🔥", "❄")]
    demos = [tuple(a) for a in led["axes"]["TheDemos"]]
    known += demos
    for biome, axes in led["axes"].items():
        expect = [q for q, (n, s) in enumerate(axes)
                  if (n, s) in known or (s, n) in known]
        assert led["lit"][biome] == expect, (biome, led)
    # The Demos' 👥/🌾 lights from a 🌾/👥 entry: an icon is its axis.
    assert 0 in led["lit"]["TheDemos"]
    assert led["lit"]["Village"] and led["lit"]["StarterForest"]


def test_the_tiers_pay_exactly_1_2_and_6(phases):
    led = phases["ledger"]
    want = {"none": 1.0, "emoji": 2.0, "icon": 6.0}
    seen = set()
    for biome, ts in led["tiers"].items():
        lit = set(led["lit"][biome])
        for q, t in enumerate(ts):
            seen.add(t)
            assert led["mult"][biome][q] == want[t], (biome, q, t, led["mult"][biome][q])
            assert (q in lit) == (t == "icon"), (biome, q, t)
    assert {"emoji", "icon"} <= seen, seen   # the world has a ×2 and a ×6 plot


def test_the_3d_field_draws_a_halo_on_every_known_plot(phases):
    f = phases["field"]
    assert f["has_field"] and f["halos"], f
    for biome, regs in f["halos"].items():
        assert regs == phases["ledger"]["lit"][biome], (biome, f)
    # The subtle highlight: exactly the emoji-tier plots, never a known one.
    assert f["shared_halos"], f
    for biome, regs in f["shared_halos"].items():
        want = [q for q, t in enumerate(phases["ledger"]["tiers"][biome]) if t == "emoji"]
        assert regs == want, (biome, f)
        assert not set(regs) & set(f["halos"][biome]), (biome, f)


def test_a_strike_on_a_glowing_plot_shows_the_bonus_it_paid(phases):
    s = phases["strike"]
    known = [r for r in s["strikes"] if r["register_id"] == s["known_reg"]]
    stranger = [r for r in s["strikes"] if r["register_id"] != s["known_reg"]]
    assert known and known[0]["known"] and known[0]["known_multiplier"] == 6.0, s
    assert stranger and not stranger[0]["known"], s
    assert stranger[0]["known_multiplier"] in (1.0, 2.0), s   # ×2 when it shares an emoji
    assert s["has_layer"], s
    want = "+%d  ×6 known word" % known[0]["amount"]
    assert want in s["layer_text"], (want, s)
    assert s["sample_text"] == "+12  ×6 known word", s
    assert s["sample_emoji_text"] == "+12  ×2 shared emoji", s


def test_the_guide_points_at_the_newest_word_on_the_biome(phases):
    g = phases["guide"]
    assert g["first_pick"]["col"] == g["first_reg"], g
    assert g["second_reg"] >= 0 and g["newest_pick"]["col"] == g["second_reg"], g


# ------------------------------------------------------------- campaign + wiring

def _beats():
    spec = json.loads(read_source("Core/Campaign/campaign.json"))
    out = {}
    for act in spec["campaigns"][0]["acts"]:
        for ch in act["chapters"]:
            for b in ch.get("beats", []):
                out[b["id"]] = b
    return out


def test_the_glow_is_taught_on_the_beat_after_the_millwright_vocabulary():
    beats = _beats()
    assert beats["village_stirs"]["offer"]["teaches"] == ["💨", "🔨"]
    fb = beats["first_breath"]
    # its arc (First Breath) waits on the Wheel arc, which holds the mill (#94)
    arcs = {a["id"]: a for ch in (c for act in json.loads(read_source("Core/Campaign/campaign.json"))["campaigns"][0]["acts"]
                                  for c in act["chapters"]) for a in ch.get("arcs", [])}
    assert "village_stirs" in arcs[arcs["breath"]["requires"][0]]["charges"]
    assert "first_breath" in arcs["breath"]["charges"]
    for text in (fb["beat"], fb["offer"]["body"]):  # body + hint are the E-inspect text
        assert "glow" in text, text
    assert "×6" in fb["beat"] and "×2" in fb["beat"]
    assert "×6" in fb["offer"]["body"] and "×2" in fb["offer"]["body"]
    assert "glows" in fb["done"]


def test_spiral_breaks_leads_with_the_strike_on_the_word_just_learned():
    sb = _beats()["spiral_breaks"]
    first = sb["objective"][0]
    assert (first["type"], first.get("gate"), first.get("lead")) == (
        "gate_sequence_contains", "strike_known", True)
    assert "glow" in sb["offer"]["hint"].split(".")[0]
    guide = read_source("Core/Campaign/Guide.gd")
    across = guide.split("static func _across(")[1].split("\nstatic func ")[0]
    assert 'get("lead", false)' in across
    strike = guide.split("static func _strike_known(")[1].split("\nstatic func ")[0]
    assert "known_word_col(" in strike


def test_one_check_feeds_the_glow_the_payout_and_the_strike_ledger():
    probe = read_source("Core/Actions/ProbeActions.gd")
    mult = probe.split("static func _incorporation_reward_multiplier(")[1].split("\nstatic func ")[0]
    assert "vocabulary_tier(" in mult and "signature_r_bonus" not in mult
    assert "vocabulary_tier(" in read_source("Core/Visualization/QuantumField3D.gd")
    assert "ProbeActions.vocabulary_tier(" in read_source("UI/PlotGridDisplay.gd")


def test_the_tier_rule_is_one_function_with_exact_numbers():
    probe = read_source("Core/Actions/ProbeActions.gd")
    assert "const MULT_EMOJI := 2.0" in probe and "const MULT_ICON_ON_TOP := 3.0" in probe
    tier = probe.split("static func vocabulary_tier(")[1].split("\nstatic func ")[0]
    assert "MULT_EMOJI * MULT_ICON_ON_TOP" in tier and "bloch" not in tier
    vocab = probe.split("static func vocabulary_words(")[1].split("\nstatic func ")[0]
    assert "HOME_BIOME" in vocab and "incorporated_icons" in vocab and "known_icons" not in vocab
    assert "vocabulary_tier(" in read_source("UI/PlotGridDisplay.gd")
    assert "vocabulary_tier(" in read_source("Core/Visualization/QuantumField3D.gd")
