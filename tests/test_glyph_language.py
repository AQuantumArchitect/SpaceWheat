"""Pins the grammar of SpaceWheat's glyph language (docs/GLYPH_LANGUAGE.md).

Three layers:
  1. tests/glyph_language_smoke.gd drives Core/Story/GlyphLanguage.gd and
     Core/Story/FactionChatter.gd headless. The composed sentences are pinned here
     verbatim; scope tags are recomputed with hashlib; asks are recomputed from
     the draws and the binary entropy; every faction and between line FactionChatter
     emitted over mock biomes is parsed.
  2. An independent reference parser (written here, not shared with the module)
     reads every sentence back and checks the invariants the doc states.
  3. A headless boot of the real game (tests/glyph_chatter_ingame_probe.gd) reads the
     chatter and faction lines it produced and checks they parse and agree with
     their own events.
"""
import hashlib
import json
import math
import os
import re
import shutil
import subprocess

import pytest

from conftest import ROOT, read_source

SMOKE = "tests/glyph_language_smoke.gd"
PROBE = "tests/glyph_chatter_ingame_probe.gd"

# --- reference grammar --------------------------------------------------------
#   line      := scope { "  " clause }                    (inside a scope)
#              | dark { " " dark }                         (no scope: undefined)
#   clause    := ket "  " pops | darks | asks              (in that order, each once)
#   scope     := ("spacewheat" | "faction") "/" Name { "⊗" Name } "@" hex4
#   ket       := "|" glyph+ "⟩"
#   pops      := "[" num "]" glyph { " " … }               (spell the ket, in order)
#   darks     := glyphs "?" { " " … }                      (a pole, or a pole pair)
#   asks      := "⟨" glyph "|" { " " … }                   (each a ket glyph)
#   num       := "0" | "1" | "." digit [digit]             (no trailing zero)
#   between   := scope "  " verb " " pop sub " " pop sub   (product scope only)
NUM = r"(?:0|1|\.\d?[1-9])"
POP_RE = re.compile(r"^\[(" + NUM + r")\](.+)$")
DARK_RE = re.compile(r"^(.+)\?$")
KET_RE = re.compile(r"^\|(.+)⟩$")
BRA_RE = re.compile(r"^⟨(.+)\|$")
SCOPE_RE = re.compile(r"^(spacewheat|faction)/([^@]+)@([0-9a-f]{4})$")
SUB_RE = re.compile(r"^\[(" + NUM + r")\](.+?)([₀-₉]+)$")
NOT_CANONICAL = re.compile("[️︎\U0001F3FB-\U0001F3FF]")
VERBS_BETWEEN = {"⚠", "🟰"}


def num_value(n: str) -> float:
    return float("0" + n) if n.startswith(".") else float(n)


def parse(sentence: str) -> dict:
    """Parse one line. Raises ValueError on anything off-grammar."""
    empty = {"scope": "", "ket": [], "pops": [], "darks": [], "asks": []}
    if sentence == "":
        return empty
    if NOT_CANONICAL.search(sentence):
        raise ValueError("non-canonical glyph (variation selector or skin tone)")
    clauses = sentence.split("  ")
    if len(clauses) == 1 and not SCOPE_RE.match(clauses[0]):
        darks = []
        for tok in clauses[0].split(" "):
            m = DARK_RE.match(tok)
            if not m:
                raise ValueError(f"unscoped line may only be dark: {tok!r}")
            darks.append(m.group(1))
        return {**empty, "darks": darks}
    scope = clauses[0]
    if not SCOPE_RE.match(scope):
        raise ValueError(f"bad scope {scope!r}")
    out = {**empty, "scope": scope}
    rest = clauses[1:]
    if not rest:
        raise ValueError("a scope with nothing said")
    if rest[0].startswith("|"):
        km = KET_RE.match(rest[0])
        if not km or len(rest) < 2:
            raise ValueError(f"bad ket {rest[0]!r}")
        for tok in rest[1].split(" "):
            m = POP_RE.match(tok)
            if not m:
                raise ValueError(f"bad population {tok!r}")
            out["pops"].append((m.group(2), m.group(1)))
        out["ket"] = [g for g, _ in out["pops"]]
        if "".join(out["ket"]) != km.group(1):
            raise ValueError("populations do not spell the ket, glyph for glyph")
        rest = rest[2:]
    if rest and rest[0].endswith("?"):
        for tok in rest[0].split(" "):
            m = DARK_RE.match(tok)
            if not m:
                raise ValueError(f"bad dark {tok!r}")
            out["darks"].append(m.group(1))
        rest = rest[1:]
    if rest and rest[0].startswith("⟨"):
        for tok in rest[0].split(" "):
            m = BRA_RE.match(tok)
            if not m:
                raise ValueError(f"bad ask {tok!r}")
            if m.group(1) not in out["ket"]:
                raise ValueError(f"asks about {m.group(1)!r}, which the line did not bring up")
            out["asks"].append(m.group(1))
        rest = rest[1:]
    if rest:
        raise ValueError(f"unexpected clauses {rest!r}")
    return out


def render(p: dict) -> str:
    """Inverse of parse: the round trip must reproduce the line exactly."""
    darks = " ".join(f"{d}?" for d in p["darks"])
    if not p["scope"]:
        return darks
    clauses = [p["scope"]]
    if p["ket"]:
        clauses += ["|" + "".join(p["ket"]) + "⟩", " ".join(f"[{n}]{g}" for g, n in p["pops"])]
    if p["darks"]:
        clauses.append(darks)
    if p["asks"]:
        clauses.append(" ".join(f"⟨{a}|" for a in p["asks"]))
    return "  ".join(clauses)


def parse_between(sentence: str) -> dict:
    scope, _, body = sentence.partition("  ")
    m = SCOPE_RE.match(scope)
    if not m or m.group(1) != "spacewheat" or "⊗" not in m.group(2):
        raise ValueError(f"between lines live in a product scope: {scope!r}")
    verb, *ops = body.split(" ")
    if verb not in VERBS_BETWEEN or len(ops) < 2:
        raise ValueError(f"bad between body {body!r}")
    readings = []
    for i, tok in enumerate(ops, start=1):
        sm = SUB_RE.match(tok)
        if not sm or sm.group(3) != "".join("₀₁₂₃₄₅₆₇₈₉"[int(c)] for c in str(i)):
            raise ValueError(f"bad reading {tok!r}")
        readings.append((sm.group(2), num_value(sm.group(1))))
    if len({g for g, _ in readings}) != 1:
        raise ValueError("a between line compares one register")
    a, b = readings[0][1] - 0.5, readings[1][1] - 0.5
    want = "🟰" if a * b > 0 else "⚠"
    # Rounded numbers can sit exactly on the pole: accept either verb there.
    if a * b != 0 and verb != want:
        raise ValueError(f"{verb} but the readings lean {'same' if a * b > 0 else 'apart'}")
    return {"scope": scope, "verb": verb, "readings": readings}


def check_line(sentence: str) -> dict:
    p = parse(sentence)
    assert render(p) == sentence, "round trip changed the line"
    return p


def scope_tag(pairs_text: str) -> str:
    return hashlib.sha256(pairs_text.encode("utf-8")).hexdigest()[:4]


def entropy_bits(p: float) -> float:
    if p <= 0 or p >= 1:
        return 0.0
    return -(p * math.log(p) + (1 - p) * math.log(1 - p)) / math.log(2)


# --- 1. the module, headless --------------------------------------------------
GOLDEN = {
    "village": "spacewheat/Village@4ed9  |🔥👥⚙⟩  [.82]🔥 [.61]👥 [.97]⚙  ⟨👥| ⟨⚙|",
    "village_no_draws": "spacewheat/Village@4ed9  |🔥👥⚙⟩  [.82]🔥 [.61]👥 [.97]⚙",
    "partly_dark": "spacewheat/BioticFlux@0000  |☀⟩  [.9]☀  🌾? 🍄?  ⟨☀|",
    "no_scope": "🌾? 👥?",
    "selector": "spacewheat/StellarForges@0000  |⚙🔧⟩  [1]⚙ [.25]🔧  ⟨🔧|",
    "empty": "",
    "faction": "faction/Swift Herd@9985  |🦌🌿⟩  [.71]🦌 [.88]🌿  🐇🦌?  ⟨🦌|",
    "faction_all_dark": "faction/The Demos@c9ec  👥🌾?",
    "between": "spacewheat/BioticFlux⊗StarterForest@408a  ⚠ [.82]☀₁ [.31]☀₂",
    "sampler": "spacewheat/TheDemos@0000  |🌾👥⟩  [.9]🌾 [.65]👥  ⟨👥|",
}


def _godot(script, env=None, timeout=300):
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    return subprocess.run(["godot", "--headless", "--script", script], cwd=ROOT,
                          capture_output=True, text=True, encoding="utf-8", timeout=timeout, env=env)


def _rows(stdout: str, prefix: str):
    return [json.loads(l[len(prefix) + 1:]) for l in stdout.splitlines() if l.startswith(prefix + " ")]


@pytest.fixture(scope="module")
def smoke():
    result = _godot(SMOKE)
    tail = (result.stdout + result.stderr)[-3000:]
    assert result.returncode == 0, f"glyph smoke failed:\n{tail}"
    assert "Glyph language smoke:" in result.stdout and " 0 failed" in result.stdout, tail
    assert "SCRIPT ERROR" not in result.stdout + result.stderr, tail
    return {
        "cases": {r["name"]: r for r in _rows(result.stdout, "GLYPH_CASE")},
        "tags": _rows(result.stdout, "GLYPH_TAG"),
        "voices": _rows(result.stdout, "GLYPH_VOICE"),
    }


def test_every_pinned_case_is_composed_verbatim(smoke):
    assert set(smoke["cases"]) == set(GOLDEN)
    for name, sentence in GOLDEN.items():
        assert smoke["cases"][name]["out"]["sentence"] == sentence, name


def test_scope_tags_are_sha256_of_the_pole_pairs(smoke):
    assert smoke["tags"]
    for row in smoke["tags"]:
        assert row["tag"] == scope_tag(row["text"]), row
    # Normalisation reaches the tag: ⚙️ and ⚙ declare the same scope.
    assert any(r["text"] == "⚙/🔧" for r in smoke["tags"])
    assert GOLDEN["village"].split("  ")[0].endswith("@" + scope_tag("🔥/❄,👥/🍞,⚙/💨"))


def test_asks_follow_the_draws_and_the_binary_entropy(smoke):
    case = smoke["cases"]["village"]
    glyphs = ["🔥", "👥", "⚙"]
    want = [g for g, p, d in zip(glyphs, case["in"]["marginals"], case["in"]["draws"]) if d < entropy_bits(p)]
    assert check_line(case["out"]["sentence"])["asks"] == want


def test_every_composed_line_parses_and_round_trips(smoke):
    for name, row in smoke["cases"].items():
        sentence = row["out"]["sentence"]
        if name == "between":
            parse_between(sentence)
        else:
            check_line(sentence)


def test_every_faction_voice_line_parses(smoke):
    voices = smoke["voices"]
    assert any(v["kind"] == "faction_line" for v in voices)
    assert any(v["kind"] == "between" for v in voices)
    for v in voices:
        if v["kind"] == "between":
            parse_between(v["glyph"]["sentence"])
            continue
        p = check_line(v["glyph"]["sentence"])
        m = SCOPE_RE.match(p["scope"])
        assert m and m.group(1) == "faction" and m.group(2) == v["faction"], v
        assert p["ket"] == v["emojis"], v
        assert p["darks"] == v["darks"], v
        for (_g, n), marg in zip(p["pops"], v["marginals"]):
            assert abs(num_value(n) - marg) <= 0.005 + 1e-9, v


def test_reference_parser_refuses_off_grammar_lines():
    bad = [
        "spacewheat/Village@4ed9  |🔥👥⟩  [0.82]🔥 [.61]👥",      # leading zero
        "spacewheat/Village@4ed9  |🔥👥⟩  [.80]🔥 [.61]👥",       # trailing zero
        "spacewheat/Village@4ed9  |🔥👥⟩  [.8]🔥",                # pops don't spell the ket
        "spacewheat/Village@4ed9  |⚙️🔧⟩  [1]⚙️ [.25]🔧",         # variation selector
        "spacewheat/Village  |🔥⟩  [.8]🔥",                        # scope without a tag
        "spacewheat/Village@4ed9  |🔥⟩  [.8]🔥  ⟨👥|",             # asks about the unsaid
        "spacewheat/Village@4ed9  |🔥⟩  [.8]🔥  ⟨🔥|  🌾?",       # clauses out of order
        "|🔥👥⟩ ⟨🔥|",                                              # a ket with no scope
    ]
    for s in bad:
        with pytest.raises(ValueError):
            parse(s)
    for s in [
        "faction/X@0000  ⚠ [.8]☀₁ [.3]☀₂",                         # not a product scope
        "spacewheat/A⊗B@0000  🟰 [.8]☀₁ [.3]☀₂",                    # lean apart, says agree
        "spacewheat/A⊗B@0000  ⚠ [.8]☀₁ [.3]🌙₂",                    # two registers
    ]:
        with pytest.raises(ValueError):
            parse_between(s)


# --- 2. the wiring --------------------------------------------------------------
def test_verbs_null_is_the_antimatter_pole_and_the_others_left_the_atoms():
    src = read_source("Core/Story/GlyphLanguage.gd")
    verbs = dict(re.findall(r'"(\w+)": "([^"]+)"', src.split("const VERBS := {")[1].split("}")[0]))
    assert verbs["null"] == "⚫" and verbs["creation"] == "✨"
    icons = json.loads((ROOT / "Core/Factions/data/icons.json").read_text(encoding="utf-8-sig"))
    antimatter = next(i for i in icons if i["name"] == "Antimatter")
    assert {antimatter["pole_0"], antimatter["pole_1"]} == {"⚫", "✨"}
    # The non-Strand verbs are not atoms (creation/null are, on purpose).
    atoms = set()
    for i in icons:
        atoms.update(NOT_CANONICAL.sub("", i.get(k, "")) for k in ("pole_0", "pole_1"))
    for b in json.loads((ROOT / "Core/Biomes/data/biomes.json").read_text(encoding="utf-8-sig")):
        atoms.update(NOT_CANONICAL.sub("", e) for e in b.get("emojis", []))
    for name in ("observe", "attend", "verify", "commit", "possibility", "resonance",
                 "tension", "reflect", "trace", "strand", "braid"):
        assert verbs[name] not in atoms, (name, verbs[name])


def test_surfaces_read_their_own_speakers():
    engine = read_source("Core/Story/StoryEngine.gd")
    assert "func story_chatter(" in engine and "func faction_lines_for_biome(" in engine
    assert "func between_chatter(" in engine
    # B uses the market's connection rule.
    b_query = engine.split("func faction_lines_for_biome(")[1].split("\nfunc ")[0]
    assert "FactionBiomeMap.factions_for_biome_by_signature(biome)" in b_query
    assert "FactionBiomeMap.factions_for_biome_by_signature" in read_source("Core/Markets/MarketLattice.gd")
    b = read_source("UI/Overlays/BiomeInspectorOverlay.gd")
    assert "engine.faction_lines_for_biome(_active_biome" in b
    n = read_source("UI/Overlays/InspectorOverlay.gd")
    assert "se.between_chatter(" in n and 'entry["glyph_sentence"]' in n
    x = read_source("UI/Overlays/ControlsOverlay.gd")
    assert "engine.story_chatter(6)" in x
    assert "engine.recent_chatter(6)" not in x.replace("return engine.recent_chatter(6)", "")


def test_the_language_module_is_pure():
    src = read_source("Core/Story/GlyphLanguage.gd")
    assert src.startswith("extends RefCounted")
    for forbidden in ("get_node", "/root/", "randf", "randi", "Engine.", "signal "):
        assert forbidden not in src, forbidden
    assert "\nvar " not in src, "no module state"


# --- 3. in game -------------------------------------------------------------------
@pytest.mark.skipif(os.environ.get("SW_SKIP_LONG") == "1",
                    reason="SW_SKIP_LONG=1 — in-game chatter boot skipped")
def test_in_game_chatter_speaks_the_glyph_language(tmp_path):
    """Boot the real game headless (the rig's AppRoot path), let the StoryEngine tick,
    and read back what it said. user:// is redirected into tmp_path and the probe
    refuses to boot if the redirect did not take."""
    env = dict(os.environ)
    env["APPDATA"] = str(tmp_path)          # Windows: user:// lives under %APPDATA%
    env["XDG_DATA_HOME"] = str(tmp_path)    # Linux / macOS
    env["SW_PROBE_USER_DIR_PREFIX"] = str(tmp_path)
    result = _godot(PROBE, env=env)
    tail = (result.stdout + result.stderr)[-3000:]
    assert result.returncode == 0, f"probe failed:\n{tail}"
    assert "SCRIPT ERROR" not in result.stdout + result.stderr, tail
    chatter = _rows(result.stdout, "GLYPH_CHATTER")
    lines = _rows(result.stdout, "GLYPH_LINE")
    assert chatter, f"no biome chatter in a minute of play:\n{tail}"
    assert lines, f"no faction spoke in a minute of play:\n{tail}"
    for ev in chatter:
        p = check_line(ev["glyph"]["sentence"])
        if ev.get("biome"):
            m = SCOPE_RE.match(p["scope"])
            assert m and m.group(1) == "spacewheat" and m.group(2) == ev["biome"], ev
    speakers = set()
    for ev in lines:
        if ev["kind"] == "between":
            parse_between(ev["glyph"]["sentence"])
            continue
        p = check_line(ev["glyph"]["sentence"])
        assert p["ket"] == ev["emojis"] and p["darks"] == ev["darks"], ev
        speakers.add(ev["faction"])
    assert "orphaned_icons" not in speakers
    assert any(ev.get("story") for ev in lines), "the Story room heard nobody"
    assert re.search(r"^GLYPH_B \S+ [1-9]", result.stdout, re.M), "B found no connected faction's line"
