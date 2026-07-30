import json
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
UMWELT_VIZ_CACHE = PROJECT_ROOT / "Core" / "Visualization" / "UmweltVizCache.gd"
FORECAST_FIELD = PROJECT_ROOT / "Core" / "Visualization" / "CognifoldForecastField.gd"
CHORUS_DEMO_FIXTURE = PROJECT_ROOT / "Core" / "Visualization" / "cognifold_manifold_chorus_demo.json"
MANIFOLD_WEB_FIXTURE = PROJECT_ROOT / "Core" / "Visualization" / "cognifold_manifold_web.json"


def test_umwelt_viz_cache_exposes_manifold_clusters_and_constellation() -> None:
    src = UMWELT_VIZ_CACHE.read_text(encoding="utf-8")
    assert "func get_manifold_clusters() -> Array:" in src
    assert '"constellation": r.get("constellation", null)' in src
    assert 'd.get("manifold", {})' in src


def test_forecast_field_renders_manifold_and_degrades_cleanly() -> None:
    src = FORECAST_FIELD.read_text(encoding="utf-8")
    assert "func _update_manifold() -> void:" in src
    assert "_update_manifold()" in src.split("func _update_manifold")[0]  # wired into _update_vectors
    assert 'vc.has_method("get_manifold_clusters")' in src
    assert "if pts.size() < 2:" in src   # a lone belief draws nothing
    assert "CHORUS_COL" in src and "CONSPIRACY_COL" in src and "FLAT_COL" in src


def test_chorus_demo_fixture_carries_a_real_bound_constellation() -> None:
    """This fixture is a genuine umwelt `_manifold_clusters()` output (a classical-GHZ dense
    cluster, tests/test_higher_order.py's canonical chorus example) — not a hand-typed grain."""
    trace = json.loads(CHORUS_DEMO_FIXTURE.read_text(encoding="utf-8"))
    clusters = trace["manifold"]["clusters"]
    assert len(clusters) == 1
    cl = clusters[0]
    assert cl["grain"] == "chorus" and cl["tier"] == "exact" and cl["n"] == 3
    assert cl["constellations"] == [["grain", "bread", "folk"]]
    assert [r["constellation"] for r in trace["registers"]] == [0, 0, 0]


def test_forecast_ladder_grades_by_persistence_relative_skill() -> None:
    """Honesty pass: rung boldness must come from skill_vs_persistence, never raw skill —
    raw skill reads ~1.0 on any quiet belief ("predict it stays put" is near-optimal), so
    grading by it would flatter a frozen field. Entries without svp stay at the dim floor."""
    src = FORECAST_FIELD.read_text(encoding="utf-8")
    fc = src.split("func _draw_forecasts")[1].split("\nfunc ")[0]
    assert 'e.get("skill_vs_persistence", null)' in fc
    assert 'e.get("skill", null)' not in fc  # raw skill no longer drives boldness


def test_manifold_loops_grade_by_backend_tier() -> None:
    """Honesty pass: only the dense-exact backend can SIGN a grain; proxy/gated readings
    must desaturate toward flat and cap brightness rather than present as signed."""
    src = FORECAST_FIELD.read_text(encoding="utf-8")
    mf = src.split("func _update_manifold")[1]
    assert '"tier"' in mf and '!= "exact"' in mf
    assert "col.lerp(FLAT_COL" in mf


def test_manifold_web_fixture_carries_svp_and_tier() -> None:
    """The flagship real-world fixture must carry the honest grade (svp) on every forecast
    entry and a backend tier on every cluster — the fields the honesty pass renders."""
    trace = json.loads(MANIFOLD_WEB_FIXTURE.read_text(encoding="utf-8"))
    entries = [e for r in trace["registers"] for e in r.get("forecast", [])]
    assert entries, "flagship fixture must carry a forecast ladder"
    assert all("skill_vs_persistence" in e for e in entries)
    assert all("tier" in cl for cl in trace["manifold"]["clusters"])


def test_manifold_web_fixture_is_no_longer_stale() -> None:
    """Regression guard: this fixture predated the manifold/constellation section entirely
    (silently missing it is exactly the gap this channel closed)."""
    trace = json.loads(MANIFOLD_WEB_FIXTURE.read_text(encoding="utf-8"))
    assert "manifold" in trace and "clusters" in trace["manifold"]
    assert all("constellation" in r for r in trace["registers"])
