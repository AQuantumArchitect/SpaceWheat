"""The icon vocabulary: one name per word, the same in every file, and physics
for every word (2026-11-16).

Invariants, from tools/vocab/vocab_report.py:
  * no name is shared by two ordered pairs (faction listings + icons.json);
  * every faction listing's name equals icons.json's name for the same pair,
    and two listings of one pair agree;
  * every registered word (faction, biome or icons.json; axis-only pairs
    excluded) has an icons.json entry in its own orientation;
  * factions.json and icons.json match tools/vocab/renames.json;
  * docs/vocab/VOCAB_REPORT.md's counts are the live counts.

Godot-driven (skipped without godot on PATH):
  * the campaign's boot biomes keep their loadout and spectrum: the new
    physics only reaches biomes that booted a physics-less word;
  * an old save (pairs, no names) loads, and its pairs resolve to the new
    names and to physics.
"""
import json
import os
import re
import shutil
import subprocess
import sys

import pytest

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools" / "vocab"))
import vocab_report as V  # noqa: E402


@pytest.fixture(scope="module")
def report():
    return V.analyse(V.load(ROOT))


def test_names_are_unique(report):
    assert report["collisions"] == {}, report["collisions"]


def test_names_agree_across_files(report):
    assert report["mismatches"] == [], report["mismatches"]
    assert report["listing_disagree"] == {}, report["listing_disagree"]


def test_every_registered_word_has_physics(report):
    assert report["physicsless"] == [], report["physicsless"]
    assert report["registered_no_physics"] == [], report["registered_no_physics"]
    assert report["reversed_only"] == [], report["reversed_only"]
    assert report["dup_physics"] == [], report["dup_physics"]


def test_every_word_is_owned_and_every_atom_has_an_icon(report):
    assert report["unowned_physics"] == []
    assert report["atoms_no_icon"] == []


def test_renames_are_applied():
    r = subprocess.run([sys.executable, str(ROOT / "tools/vocab/apply_names.py"), "--check"],
                       capture_output=True, text=True, encoding="utf-8")
    assert r.returncode == 0, r.stdout + r.stderr


def test_report_doc_counts_are_live(report):
    doc = (ROOT / "docs/vocab/VOCAB_REPORT.md").read_text(encoding="utf-8")
    for key, value in V.summary(report).items():
        m = re.search(r"^\| %s \| (\d+) \|$" % re.escape(key), doc, re.M)
        assert m, "docs/vocab/VOCAB_REPORT.md has no row for %s" % key
        assert int(m.group(1)) == value, \
            "%s is %d, doc says %s: run python tools/vocab/vocab_report.py --markdown docs/vocab/VOCAB_REPORT.md" % (
                key, value, m.group(1))


def test_new_words_can_ripen():
    """The 19 words given physics on 2026-11-16 all carry a transverse term."""
    icons = json.loads((ROOT / "Core/Factions/data/icons.json").read_text(encoding="utf-8"))
    new = {"Suture", "Woodcutting", "Judgment", "Rainfall", "Irrigation", "Density", "Anchorage",
           "Usury", "Tally", "Graze", "Flight", "Leavings", "Geode", "Kiln", "Ore", "Above",
           "Freight", "Sluice", "Search"}
    seen = {e["name"]: e for e in icons if e["name"] in new}
    assert set(seen) == new
    for name, e in seen.items():
        assert e["rabi_coupling"] > 0, name
        assert len(e["hamiltonian_couplings"]) <= 4, name


# --------------------------------------------------------------- Godot lane

def _godot(script, env_extra=None, tag=None, tmp=None):
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    env = dict(os.environ)
    if tmp is not None:
        env["APPDATA"] = str(tmp)
        env["XDG_DATA_HOME"] = str(tmp)
    env.update(env_extra or {})
    r = subprocess.run(["godot", "--headless", "--script", script], cwd=ROOT, capture_output=True,
                       text=True, encoding="utf-8", timeout=600, env=env)
    out = r.stdout + r.stderr
    assert r.returncode == 0, out[-3000:]
    return [json.loads(line.split(tag + " ", 1)[1]) for line in out.splitlines()
            if line.startswith(tag + " ")]


# Measured on origin/main 13788d61, before the renames and the new physics.
CAMPAIGN_BOOT = {
    "TheDemos": ([["👥", "🌾"]], 1.58521291945278),
    "Village": ([["👥", "🍞"], ["🔥", "❄"], ["💰", "⚙"]], 0.210825055982725),
    "StarterForest": ([["🐺", "🦌"], ["🦅", "🐇"], ["💀", "🌱"], ["☀", "🌙"], ["🍂", "🌿"]], 0.20640654326485),
    "BloodLedger": ([["🦅", "🩸"], ["🏰", "📜"], ["⚜", "👥"], ["⚖", "💰"]], 0.956377168855639),
    "FreshwaterSpring": ([["🔥", "💧"], ["🫧", "🌿"]], 0.457320595563667),
    "Woodlot": ([["🔥", "🍂"], ["🌱", "🌲"]], 0.304138126514911),
}
# The only biomes whose boot H changes: each booted a word that had no physics.
CHANGED = {"VolcanicWorlds", "ScrapYard", "Harbor", "QuayRooks", "Flesh Architects",
           "The Gilded Legacy", "Volcanic Foundry"}
NEW_PAIRS = ["🩸|🧵", "👥|🪓", "⚖|🌱", "💧|🌧", "🪣|🌾", "🐝|🐇", "🚢|⚓", "💰|🪝", "🛶|📋",
             "🦌|🌿", "🐇|🌿", "🧤|🗑", "🪨|💎", "🌫|✨", "💎|⛏", "🦋|🕷", "🧂|🛶", "💧|⛓", "🔓|🔍"]


@pytest.fixture(scope="module")
def boot():
    rows = _godot("tests/vocab_boot_probe.gd", {"SW_VOCAB_ZERO": ",".join(NEW_PAIRS)}, "VOCAB_BOOT")
    return {r["biome"]: r for r in rows}


def test_campaign_boot_biomes_unchanged(boot):
    for name, (axes, gap) in CAMPAIGN_BOOT.items():
        row = boot[name]
        assert [l[1:] for l in row["loadout"]] == axes, name
        assert row["gap"] == pytest.approx(gap, abs=1e-9), name
        assert row["dh"] == pytest.approx(0.0, abs=1e-12), name


def test_new_physics_reaches_only_the_biomes_that_booted_it(boot):
    changed = {b for b, r in boot.items() if r.get("dh", 0.0) > 1e-9}
    assert changed == CHANGED
    for b in CHANGED:
        # With the new words' physics stripped, H is what it was before: a
        # physics-less qubit made the spectrum exactly degenerate (gap 0)
        # in every one of these except Flesh Architects and QuayRooks.
        assert boot[b]["gap"] > 0.05, b


def test_old_save_loads_and_resolves_to_new_names(tmp_path):
    rows = _godot("tests/vocab_old_save_probe.gd", tag="OLD_SAVE", tmp=tmp_path)
    assert len(rows) == 1
    out = rows[0]
    assert out["save_err"] == 0 and out["loaded"]
    known = {e["pair"]: e for e in out["known"]}
    assert known["🧺/💰"]["name"] == "Market"
    assert known["📜/⚖"]["name"] == "Decree"
    assert known["👥/🪓"]["name"] == "Woodcutting" and known["👥/🪓"]["rabi"] > 0
    inc = {e["pair"]: e for e in out["incorporated"]}
    assert inc["🪣/🌾"]["name"] == "Irrigation" and inc["🪣/🌾"]["couplings"] == 3
    harbor = {e["pair"]: e for e in out["harbor"]}
    assert harbor["🪣/🌾"]["name"] == "Irrigation"
    assert harbor["🪣/🌾"]["rabi"] == pytest.approx(0.4)
