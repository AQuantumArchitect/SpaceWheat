"""d1-04 wave-2: the standings `sig` column is SIGNATURE progress, not cloud.

Locked vocabulary (Core/Documentation/glossary/signature.md): signature = a faction's set of
ICONS (2-emoji axes); cloud = its set of atoms (emojis). The wave-1 glossary
sentence promised signature-incorporation while the grid counted cloud atoms
against get_known_emojis() — false for the 7/99 factions whose icon poles are
not a subset of their cloud. These pins hold three surfaces to the law:

  1. the data fixture the referee used (Millwright's Union / Carrion Throne)
     keeps diverging, so the semantic distinction stays testable;
  2. ControlsOverlay._render_faction_standings_grid computes sig from the
     faction's icons via IconRegistry's VS16-normalized pair keys, never from
     the cloud;
  3. the glossary describes the rendered row plainly (8 cells) and never
     reaches for the retired word "vocabulary".

The behavioral half (sig_known moves when Lumber 🪓/🪵 is incorporated) lives
in tests/standings_lifecycle.gd test 10, which runs the real IconRegistry.
"""
import json
import re
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
FACTIONS_JSON = PROJECT_ROOT / "Core" / "Factions" / "data" / "factions.json"
CONTROLS_OVERLAY = PROJECT_ROOT / "UI" / "Overlays" / "ControlsOverlay.gd"
QUANTUM_INSTRUMENT = PROJECT_ROOT / "Core" / "Instrumentation" / "QuantumInstrument.gd"
STANDING_MD = PROJECT_ROOT / "Core" / "Documentation" / "glossary" / "standing.md"


def _norm(emoji: str) -> str:
    # IconRegistry.norm_emoji: emoji identity ignores U+FE0F (VS16).
    return emoji.replace("️", "")


def _faction(name: str) -> dict:
    rows = json.loads(FACTIONS_JSON.read_text(encoding="utf-8"))
    if isinstance(rows, dict):
        rows = rows["factions"]
    return next(r for r in rows if r.get("name") == name)


def _grid_func_src() -> str:
    src = CONTROLS_OVERLAY.read_text(encoding="utf-8")
    match = re.search(
        r"func _render_faction_standings_grid.*?(?=\nfunc )", src, re.DOTALL
    )
    assert match, "_render_faction_standings_grid not found in ControlsOverlay.gd"
    # Strip comment lines — we pin what the code DOES, not what it narrates
    # (the function's own comment names the old defect for the archaeologists).
    lines = [
        ln for ln in match.group(0).splitlines()
        if not ln.lstrip().startswith("#")
    ]
    return "\n".join(lines)


def test_millwright_fixture_still_diverges() -> None:
    # The shipped counterexample: 4-icon signature including Lumber 🪓/🪵,
    # 6-atom cloud that contains NEITHER pole. If this drifts, the sig-column
    # semantics stop being distinguishable and these pins go vacuous.
    mill = _faction("Millwright's Union")
    icons = mill.get("icons", [])
    assert len(icons) == 4
    pairs = {frozenset((_norm(i["pole_0"]), _norm(i["pole_1"]))) for i in icons}
    assert frozenset(("🪓", "🪵")) in pairs
    cloud = {_norm(e) for e in mill["cloud"]}
    assert len(cloud) == 6
    assert "🪓" not in cloud and "🪵" not in cloud


def test_carrion_throne_fixture_still_diverges() -> None:
    # Cloud holds 👥 (also an emoji of the boot icon 🌾/👥), but the signature
    # holds no 🌾/👥 icon — cloud-counting read 1/8 at boot with zero of their
    # icons incorporated; signature-counting must read 0/4.
    ct = _faction("Carrion Throne")
    icons = ct.get("icons", [])
    assert len(icons) == 4
    pairs = {frozenset((_norm(i["pole_0"]), _norm(i["pole_1"]))) for i in icons}
    assert frozenset(("🌾", "👥")) not in pairs
    assert "👥" in {_norm(e) for e in ct["cloud"]}


def test_sig_column_reads_signature_not_cloud() -> None:
    fn = _grid_func_src()
    # Signature authority: the faction's icon list + the player's incorporated
    # icons, matched through IconRegistry's normalized pair keys. Since the
    # fable push the autoload is resolved by node path (bare identifiers fail
    # headless-harness compiles), so the calls go through `icon_registry`.
    assert '"/root/IconRegistry"' in fn
    assert "icon_registry.get_icons_for_faction(" in fn
    assert "icon_registry.discovered_set_from_icons(" in fn
    assert "icon_registry.is_icon_discovered(" in fn
    assert "known_icons" in fn
    # The defect: cloud atoms counted against recognized emojis.
    assert ".cloud" not in fn
    assert "get_known_emojis" not in fn
    # Rendered format unchanged: "K/N".
    assert '"%d/%d" % [int(row.sig_known), int(row.sig_total)]' in fn


def test_inject_refusal_speaks_quantities_not_dictionaries() -> None:
    src = QUANTUM_INSTRUMENT.read_text(encoding="utf-8")
    # The old refusal stringified a raw GDScript Dictionary at the player.
    assert 'injection (%s)" % [gate.get("cost", {})]' not in src
    # The honest grammar (mirrors QuantumInstrumentInput._cost_shortfall_words).
    assert "_cost_shortfall_message(" in src
    assert '(you hold %d)' in src


def test_standing_glossary_speaks_the_locked_vocabulary() -> None:
    doc = STANDING_MD.read_text(encoding="utf-8")
    # "vocabulary" is a retired term (signature.md) — it muddles cloud/signature.
    assert "vocabulary" not in doc.lower()
    # The rendered row is 8 cells: faction name + 6 channels + sig.
    assert "eight cells" in doc
    assert "sig_known/sig_total" in doc
