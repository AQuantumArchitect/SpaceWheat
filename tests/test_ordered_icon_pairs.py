"""Ordered icon pairs: both words of a duplicated pair, one per orientation.

Owner ruling 2026-11-16: an icon is an ORDERED pole pair and the south pole
(pole_1) is what the word provides. Seven pole pairs carry two words, A/B and
B/A, each with its own name, owner and physics. When the inverse orientation is
not a word of its own, B/A is the same word read the other way round (old
saves, campaign teachings such as 🏭/⚙ for Factory ⚙/🏭, planted axes).

tests/ordered_icon_pairs_probe.gd builds the registries headless; see its header.
"""
import json
import os
import shutil
import subprocess

import pytest

from conftest import ROOT

PROBE = "tests/ordered_icon_pairs_probe.gd"

# (pole_0, pole_1) -> (name, owner, what the south pole provides)
WORDS = {
    ("⚖", "💰"): ("Commerce", "Carrion Throne"),
    ("💰", "⚖"): ("Levy", "Ledger Bailiffs"),
    ("⛓", "👥"): ("Unleash", "Fencebreakers"),
    ("👥", "⛓"): ("Processing", "Void Serfs"),
    ("🪢", "🪡"): ("Knot", "Loom Priests"),
    ("🪡", "🪢"): ("Splice", "Seamstress Syndicate"),
    ("👥", "🍞"): ("Labor", "Millwright's Union"),
    ("🍞", "👥"): ("Bread", "Hearth Keepers"),
    ("🌾", "🌱"): ("Pollination", "Pollinator Guild"),
    ("🌱", "🌾"): ("Cultivation", "Seedvault Curators"),
    ("🌱", "🌿"): ("Seedling", "Verdant Pulse"),
    ("🌿", "🌱"): ("Renewal", "Wildfire"),
    ("🍂", "🌿"): ("Humus", "Verdant Pulse"),
    ("🌿", "🍂"): ("EuPhotobloom", "Sunlit Canopy"),
}

# What every biome that seats one of the seven booted before this change
# (measured on origin/main ff69ce01). Physics is unchanged; only
# RevolutionSquare's word is now called Unleash (it was shown as Liberation).
BOOT = {
    "BloodLedger": ("Commerce", "⚖", "💰"),
    "Ledger Bailiffs": ("Levy", "💰", "⚖"),
    "RevolutionSquare": ("Unleash", "⛓", "👥"),
    "Void Serfs": ("Processing", "👥", "⛓"),
    "Loom Priests": ("Knot", "🪢", "🪡"),
    "Millwright's Union": ("Labor", "👥", "🍞"),
    "Village": ("Labor", "👥", "🍞"),
    "HearthKeepers": ("Bread", "🍞", "👥"),
    "Verdant Pulse": ("Seedling", "🌱", "🌿"),
    "Wildfire": ("Renewal", "🌿", "🌱"),
    "StarterForest": ("Humus", "🍂", "🌿"),
    "Wildwood": ("Humus", "🍂", "🌿"),
    "EukaryoticEucharist": ("EuPhotobloom", "🌿", "🍂"),
}


def _icons_json():
    return json.loads((ROOT / "Core/Factions/data/icons.json").read_text(encoding="utf-8"))


def _factions_json():
    return json.loads((ROOT / "Core/Factions/data/factions.json").read_text(encoding="utf-8"))


@pytest.fixture(scope="module")
def trace(tmp_path_factory):
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    tmp = tmp_path_factory.mktemp("ordered_pairs_probe")
    env = dict(os.environ)
    env["APPDATA"] = str(tmp)
    env["XDG_DATA_HOME"] = str(tmp)
    result = subprocess.run(["godot", "--headless", "--script", PROBE], cwd=ROOT,
                            capture_output=True, text=True, encoding="utf-8",
                            timeout=300, env=env)
    out = result.stdout + result.stderr
    assert result.returncode == 0, f"{PROBE} failed:\n{out[-3000:]}"
    assert "SCRIPT ERROR" not in out and "Parse Error" not in out, out[-3000:]
    rows = [json.loads(l[len("PAIRS_TRACE "):]) for l in result.stdout.splitlines()
            if l.startswith("PAIRS_TRACE ")]
    assert rows, out[-3000:]
    return rows[0]


# ---------------------------------------------------------------- data, no Godot

def test_each_of_the_fourteen_words_is_written_once_in_its_own_orientation():
    by_pair = {(e["pole_0"], e["pole_1"]): e["name"] for e in _icons_json()}
    for pair, (name, _owner) in WORDS.items():
        assert by_pair.get(pair) == name, (pair, by_pair.get(pair), name)


def test_faction_listings_name_each_word_as_icons_json_does():
    seen = {}
    for f in _factions_json():
        for ic in f.get("icons", []):
            pair = (ic["pole_0"], ic["pole_1"])
            if pair in WORDS:
                seen[pair] = (ic["name"], f["name"])
    assert seen == WORDS


def test_the_new_names_are_unique():
    # Unleash, Splice and Pollination replaced Liberation (also 👥/💀),
    # Knot (twice) and Harvest (also 🌾/🍂 and others).
    names = {}
    for f in _factions_json():
        for ic in f.get("icons", []):
            names.setdefault(ic["name"], set()).add((ic["pole_0"], ic["pole_1"]))
    for e in _icons_json():
        names.setdefault(e["name"], set()).add((e["pole_0"], e["pole_1"]))
    for word in ("Levy", "Unleash", "Processing", "Knot", "Splice", "Bread", "Pollination",
                 "Cultivation", "Seedling", "Renewal", "Humus", "EuPhotobloom"):
        assert len(names[word]) == 1, (word, names[word])


# ---------------------------------------------------------------- live registry

def test_both_orientations_register_as_distinct_words(trace):
    got = {(w["pole_0"], w["pole_1"]): w for w in trace["words"]}
    names = set()
    for pair, (name, owner) in WORDS.items():
        w = got[pair]
        assert (w["rec_pole_0"], w["rec_pole_1"]) == pair, w
        assert w["name"] == name, w
        assert w["owners"] == [owner], w
        assert w["inverse"] is True, w
        names.add(w["name"])
    assert len(names) == 14


def test_each_word_runs_its_own_physics(trace):
    phys = {(e["pole_0"], e["pole_1"]): e for e in _icons_json()}
    for w in trace["words"]:
        e = phys[(w["pole_0"], w["pole_1"])]
        assert w["se0"] == pytest.approx(e.get("self_energy_0", 0.0)), w
        assert w["se1"] == pytest.approx(e.get("self_energy_1", 0.0)), w
        assert w["rabi"] == pytest.approx(e.get("rabi_coupling", 0.0)), w
        assert sorted(w["hc"]) == sorted(e.get("hamiltonian_couplings", {}).keys()), w


def test_word_identity_is_ordered_only_where_the_inverse_is_a_word(trace):
    s = trace["same"]
    assert s["labor_vs_labor"] is True
    assert s["labor_vs_bread"] is False
    assert s["probe_same_word"] is False
    assert s["discovered_labor_has_bread"] is False
    # Factory ⚙/🏭 has no inverse word: the campaign teaches it as 🏭/⚙ and
    # that still means Factory.
    assert s["factory_has_inverse"] is False
    assert s["factory_inverted"] is True
    assert s["discovered_factory_inverted"] is True


def test_an_old_format_save_loads_and_keeps_its_words(trace):
    led = trace["ledger"]
    assert led["save_err"] == 0 and led["loaded"] and led["ledger_size"] == 2, led
    # The stored 👥/🍞 is Labor, the word that was incorporated; it no longer
    # also pays for Bread (🍞/👥), which shares its atoms (×2, not ×6).
    assert led["labor"] == "icon"
    assert led["bread"] == "emoji"
    # A single word stored inverted is still that word, both ways round.
    assert led["factory"] == "icon"
    assert led["factory_inverted"] == "icon"


def test_no_biome_boots_a_different_word_or_hamiltonian(trace):
    phys = {(e["pole_0"], e["pole_1"]): e for e in _icons_json()}
    got = {}
    for biome, rows in trace["boot"].items():
        assert len(rows) == 1, (biome, rows)  # never both orientations
        r = rows[0]
        got[biome] = (r["name"], r["pole_0"], r["pole_1"])
        e = phys[(r["pole_0"], r["pole_1"])]
        assert r["se0"] == pytest.approx(e.get("self_energy_0", 0.0)), (biome, r)
        assert r["se1"] == pytest.approx(e.get("self_energy_1", 0.0)), (biome, r)
        assert r["rabi"] == pytest.approx(e.get("rabi_coupling", 0.0)), (biome, r)
    assert got == BOOT
