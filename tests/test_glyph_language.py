"""Pins the grammar of SpaceWheat's glyph-language chatter (docs/GLYPH_LANGUAGE.md).

Three layers:
  1. tests/glyph_language_smoke.gd drives Core/Story/GlyphLanguage.gd headless and
     prints every composed case; the exact sentences are pinned here verbatim.
  2. An independent reference parser (written here, not shared with the module)
     reads every sentence back and checks the invariants the doc states.
  3. A headless boot of the real game (tests/glyph_chatter_ingame_probe.gd) reads
     the chatter it produced and checks each event carries a sentence that parses and
     agrees with the event's own emojis and marginals.
"""
import json
import os
import re
import shutil
import subprocess

import pytest

from conftest import ROOT, read_source

SMOKE = "tests/glyph_language_smoke.gd"

# --- reference grammar --------------------------------------------------------
#   sentence  := scope "  " ket "  " pops [ "  " ask ]     (inside a scope)
#              | dark { " " dark }                         (no scope: undefined)
#   scope     := "spacewheat/" Name
#   ket       := "|" glyph+ "⟩"
#   pops      := pop { " " pop }
#   pop       := "[" num "]" glyph  |  glyph "?"
#   num       := "0" | "1" | "." digit [digit]   (no trailing zero)
#   ask       := "⟨" glyph "|"
NUM = r"(?:0|1|\.\d?[1-9])"
POP_RE = re.compile(r"^\[(" + NUM + r")\](.+)$")
DARK_RE = re.compile(r"^(.+)\?$")
KET_RE = re.compile(r"^\|(.+)⟩$")
BRA_RE = re.compile(r"^⟨(.+)\|$")
SCOPE_RE = re.compile(r"^spacewheat/[A-Za-z][A-Za-z0-9_]*$")
NOT_CANONICAL = re.compile("[\ufe0f\ufe0e\U0001F3FB-\U0001F3FF]")


def parse(sentence: str) -> dict:
    """Parse one chatter sentence. Raises ValueError on anything off-grammar."""
    if sentence == "":
        return {"scope": "", "ket": [], "pops": [], "ask": ""}
    if NOT_CANONICAL.search(sentence):
        raise ValueError("non-canonical glyph (variation selector or skin tone)")
    clauses = sentence.split("  ")
    if len(clauses) == 1:
        pops = []
        for tok in clauses[0].split(" "):
            m = DARK_RE.match(tok)
            if not m:
                raise ValueError(f"unscoped sentence may only be dark: {tok!r}")
            pops.append((m.group(1), None))
        return {"scope": "", "ket": [], "pops": pops, "ask": ""}
    if len(clauses) not in (3, 4):
        raise ValueError(f"expected 3 or 4 clauses, got {len(clauses)}")
    scope, ket, pop_clause = clauses[:3]
    if not SCOPE_RE.match(scope):
        raise ValueError(f"bad scope {scope!r}")
    km = KET_RE.match(ket)
    if not km:
        raise ValueError(f"bad ket {ket!r}")
    pops = []
    for tok in pop_clause.split(" "):
        m = POP_RE.match(tok)
        if m:
            pops.append((m.group(2), m.group(1)))
            continue
        m = DARK_RE.match(tok)
        if not m:
            raise ValueError(f"bad population {tok!r}")
        pops.append((m.group(1), None))
    if "".join(g for g, _ in pops) != km.group(1):
        raise ValueError("populations do not spell the ket, glyph for glyph")
    ask = ""
    if len(clauses) == 4:
        bm = BRA_RE.match(clauses[3])
        if not bm:
            raise ValueError(f"bad ask {clauses[3]!r}")
        ask = bm.group(1)
    return {"scope": scope, "ket": [g for g, _ in pops], "pops": pops, "ask": ask}


def render(parsed: dict) -> str:
    """Inverse of parse: the round trip must reproduce the sentence exactly."""
    pops = [f"[{n}]{g}" if n is not None else f"{g}?" for g, n in parsed["pops"]]
    if not parsed["scope"]:
        return " ".join(pops)
    clauses = [parsed["scope"], "|" + "".join(parsed["ket"]) + "⟩", " ".join(pops)]
    if parsed["ask"]:
        clauses.append(f"⟨{parsed['ask']}|")
    return "  ".join(clauses)


def num_value(n: str) -> float:
    return float("0" + n) if n.startswith(".") else float(n)


def expected_ask(pops) -> str:
    """Least sure = nearest one half; first wins a tie; none if all dark."""
    best, best_d = "", None
    for g, n in pops:
        if n is None:
            continue
        d = abs(num_value(n) - 0.5)
        if best_d is None or d < best_d - 1e-9:
            best, best_d = g, d
    return best


def check_sentence(sentence: str) -> dict:
    p = parse(sentence)
    assert render(p) == sentence, "round trip changed the sentence"
    assert p["ask"] == expected_ask(p["pops"]), f"ask is not the least-sure register: {sentence}"
    if p["ask"]:
        assert p["ask"] in p["ket"]
    return p


# --- 1. pinned cases from the real module -------------------------------------
GOLDEN = {
    "village": "spacewheat/Village  |🔥👥⚙💰⟩  [.82]🔥 [.61]👥 [.5]⚙ [.97]💰  ⟨⚙|",
    "demos_tie": "spacewheat/TheDemos  |👥🌾⟩  [.7]👥 [.3]🌾  ⟨👥|",
    "partly_dark": "spacewheat/BioticFlux  |☀🌾🍄⟩  [.9]☀ 🌾? 🍄?  ⟨☀|",
    "no_scope": "🌾? 👥?",
    "selector": "spacewheat/StellarForges  |⚙🔧⟩  [1]⚙ [.25]🔧  ⟨🔧|",
    "all_dark": "spacewheat/StarterForest  |🐺🦅⟩  🐺? 🦅?",
    "empty": "",
    "sampler": "spacewheat/TheDemos  |🌾👥⟩  [.9]🌾 [.65]👥  ⟨👥|",
}
SHORT = {
    "village": "|🔥👥⚙💰⟩ ⟨⚙|",
    "no_scope": "🌾? 👥?",
    "all_dark": "|🐺🦅⟩",
}


@pytest.fixture(scope="module")
def smoke_cases():
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    result = subprocess.run(
        ["godot", "--headless", "--script", SMOKE],
        cwd=ROOT, capture_output=True, text=True, encoding="utf-8", timeout=300,
    )
    tail = (result.stdout + result.stderr)[-3000:]
    assert result.returncode == 0, f"glyph smoke failed:\n{tail}"
    assert "Glyph language smoke:" in result.stdout and " 0 failed" in result.stdout, tail
    assert "SCRIPT ERROR" not in result.stdout + result.stderr, tail
    cases = {}
    for line in result.stdout.splitlines():
        if line.startswith("GLYPH_CASE "):
            row = json.loads(line[len("GLYPH_CASE "):])
            cases[row["name"]] = row
    return cases


def test_every_pinned_case_is_composed_verbatim(smoke_cases):
    assert set(smoke_cases) == set(GOLDEN)
    for name, sentence in GOLDEN.items():
        assert smoke_cases[name]["out"]["sentence"] == sentence, name
    for name, short in SHORT.items():
        assert smoke_cases[name]["out"]["short"] == short, name


def test_every_composed_sentence_parses_and_round_trips(smoke_cases):
    for name, row in smoke_cases.items():
        out = row["out"]
        p = check_sentence(out["sentence"])
        assert p["scope"] == out["scope"] or (not out["sentence"]), name
        if out["ask"]:
            assert out["ask"] == f"⟨{p['ask']}|", name


def test_reference_parser_refuses_off_grammar_sentences():
    bad = [
        "spacewheat/Village  |🔥👥⟩  [0.82]🔥 [.61]👥",     # leading zero
        "spacewheat/Village  |🔥👥⟩  [.80]🔥 [.61]👥",      # trailing zero
        "spacewheat/Village  |🔥👥⟩  [.8]🔥",               # pops don't spell the ket
        "spacewheat/Village  |⚙️🔧⟩  [1]⚙️ [.25]🔧",        # variation selector
        "|🔥👥⟩ ⟨🔥|",                                      # a ket with no scope
        "spacewheat/Village  🔥👥  [.8]🔥 [.6]👥",          # unbracketed ket
    ]
    for s in bad:
        with pytest.raises(ValueError):
            parse(s)
    # A wrong ask parses but breaks the least-sure invariant.
    with pytest.raises(AssertionError):
        check_sentence("spacewheat/Village  |🔥👥⟩  [.9]🔥 [.55]👥  ⟨🔥|")


# --- 2. the wiring --------------------------------------------------------------
def test_chatter_events_carry_the_glyph_sentence():
    cluster = read_source("Core/Story/SocialiteCluster.gd")
    assert 'preload("res://Core/Story/GlyphLanguage.gd")' in cluster
    assert '"glyph": GlyphLanguage.compose_chatter(emojis, marginals, biome_label)' in cluster
    # The emoji line stays as it was: the sentence is an added reading, not a rewrite.
    assert '"line": " ".join(emojis)' in cluster


def test_murmur_bubbles_and_inspect_panel_render_the_sentence():
    overlay = read_source("UI/Overlays/ControlsOverlay.gd")
    bubble = overlay.split("func _make_chatter_bubble(")[1].split("\nfunc ")[0]
    assert 'glyph_ev.get("short", "")' in bubble
    inspect = overlay.split("func _make_story_inspect_panel(")[1].split("\nfunc ")[0]
    assert '_make_kv_row("glyph", glyph_sentence)' in inspect


def test_the_module_is_pure():
    src = read_source("Core/Story/GlyphLanguage.gd")
    assert src.startswith("extends RefCounted")
    for forbidden in ("get_node", "/root/", "randf", "randi", "Engine.", "signal "):
        assert forbidden not in src, forbidden
    assert "\nvar " not in src, "no module state"


# --- 3. in game -------------------------------------------------------------------
PROBE = "tests/glyph_chatter_ingame_probe.gd"


@pytest.mark.skipif(os.environ.get("SW_SKIP_LONG") == "1",
                    reason="SW_SKIP_LONG=1 — in-game chatter boot skipped")
def test_in_game_chatter_speaks_the_glyph_language(tmp_path):
    """Boot the real game headless (the rig's AppRoot path), let the StoryEngine tick,
    and read back the chatter it produced. user:// is redirected into tmp_path and the
    probe refuses to boot if the redirect did not take."""
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    env = dict(os.environ)
    env["APPDATA"] = str(tmp_path)          # Windows: user:// lives under %APPDATA%
    env["XDG_DATA_HOME"] = str(tmp_path)    # Linux / macOS
    env["SW_PROBE_USER_DIR_PREFIX"] = str(tmp_path)
    result = subprocess.run(
        ["godot", "--headless", "--script", PROBE],
        cwd=ROOT, capture_output=True, text=True, encoding="utf-8", timeout=300, env=env,
    )
    tail = (result.stdout + result.stderr)[-3000:]
    assert result.returncode == 0, f"probe failed:\n{tail}"
    chatter = [json.loads(line[len("GLYPH_CHATTER "):])
               for line in result.stdout.splitlines() if line.startswith("GLYPH_CHATTER ")]
    assert chatter, f"no chatter in a minute of play:\n{tail}"
    scoped = 0
    for ev in chatter:
        glyph = ev.get("glyph")
        assert isinstance(glyph, dict), ev
        p = check_sentence(glyph["sentence"])
        canon = [re.sub("[\ufe0f\ufe0e]", "", str(e)) for e in ev.get("emojis", [])]
        if ev.get("biome"):
            scoped += 1
            assert p["scope"] == f"spacewheat/{ev['biome']}"
            assert p["ket"] == canon, (ev, glyph)
            marg = ev.get("marginals", [])
            for j, (_g, n) in enumerate(p["pops"]):
                if n is not None:
                    assert abs(num_value(n) - float(marg[j])) <= 0.005 + 1e-9, (ev, glyph)
        else:
            assert p["scope"] == "" and [g for g, _ in p["pops"]] == canon
    assert scoped > 0, "every chatter line was unscoped: no biome was measured"
