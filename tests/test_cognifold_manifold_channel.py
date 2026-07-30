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


def test_manifold_web_fixture_is_no_longer_stale() -> None:
    """Regression guard: this fixture predated the manifold/constellation section entirely
    (silently missing it is exactly the gap this channel closed)."""
    trace = json.loads(MANIFOLD_WEB_FIXTURE.read_text(encoding="utf-8"))
    assert "manifold" in trace and "clusters" in trace["manifold"]
    assert all("constellation" in r for r in trace["registers"])
