"""Pins for the first test-orchestrator wave's folds (2026-11-12).

Live proof in the hive ledger: to_earnest_4 (1🌱) pressing the Village's
💨/🔨 icon now toasts where sprouts come from.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def test_an_unaffordable_option_names_where_the_resource_comes_from():
    qii = _read("UI/Core/QuantumInstrumentInput.gd")
    assert "func _short_resource_sources(cost) -> String:" in qii
    helper = qii.split("func _short_resource_sources(", 1)[1].split("\nfunc ", 1)[0]
    assert "CampaignRuntime.resource(" in helper
    assert '"gather %s in %s"' in helper and '"buy it at the %s market"' in helper
    disabled = qii.split('if not action_data.get("enabled", true):', 1)[1].split("return  # Stay in submenu", 1)[0]
    assert '_short_resource_sources(action_data.get("cost", {}))' in disabled


def test_the_cull_choice_says_what_letting_go_costs():
    cull = _read("Core/Campaign/Guide.gd").split("static func _cull(", 1)[1].split("\nstatic func ", 1)[0]
    assert "pick one to let go (its stock is paid out, and you can find it again)" in cull


def _fn(src: str, name: str) -> str:
    return src.split("static func %s(" % name, 1)[1].split("\nstatic func ", 1)[0]


def test_gray_only_where_something_grays():
    # Opening Lanternfall builds no Lindblad operator (every atom term targets
    # a glyph off its register), so its purity holds at 1.0; the walk waited
    # "the Bath is graying Lanternfall" for 33 min (wave 2, to_strict7_end).
    guide = _read("Core/Campaign/Guide.gd")
    assert "lindblad_operators" in _fn(guide, "_biome_has_bath")
    assert "_biome_has_bath(nm)" in _fn(guide, "_gray")


def test_a_fade_waits_for_the_bath_instead_of_spinning():
    # Watch It Fade: coherence_fell + purity_at_most. Druid spins stirred the
    # color back (to_dist_2, 40 presses, 0 flags); hands-off it drained.
    guide = _read("Core/Campaign/Guide.gd")
    still = _fn(guide, "_still")
    assert still.index("_fade(q)") < still.index("spin it toward its nearer pole")
    fade = _fn(guide, "_fade")
    assert '"purity_at_most"' in fade and "_coherence_watermark" in fade
    assert "hands off, wait" in fade
