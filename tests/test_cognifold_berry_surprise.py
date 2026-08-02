from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
UMWELT_VIZ_CACHE = PROJECT_ROOT / "Core" / "Visualization" / "UmweltVizCache.gd"
FORECAST_FIELD = PROJECT_ROOT / "Core" / "Visualization" / "CognifoldForecastField.gd"


def test_gauge_passes_berry_phase_and_surprise_through() -> None:
    src = UMWELT_VIZ_CACHE.read_text(encoding="utf-8")
    assert '"berry_phase": r.get("berry_phase", null)' in src
    assert '"surprise": r.get("surprise", null)' in src


def test_berry_odometer_channel_wired_and_honestly_absent() -> None:
    """The odometer draws γ mod 2π with winding-deepened tint, and draws NOTHING when the
    trace carries no berry_phase (null → continue, matching every other channel)."""
    src = FORECAST_FIELD.read_text(encoding="utf-8")
    assert "func _update_berry() -> void:" in src
    assert "_update_berry()" in src.split("func _update_berry")[0]  # wired into _update_vectors
    berry = src.split("func _update_berry")[1]
    assert 'gauge.get("berry_phase", null)' in berry
    assert "fmod(gamma, TAU)" in berry
    assert "BERRY_COL.lerp(BERRY_DEEP" in berry  # winding count deepens the tint


def test_surprise_flare_lives_on_the_trust_core() -> None:
    """innov_ema is the un-clipped sibling of reliability (same trust struct), so the flare
    heats the SAME core reliability sizes — null surprise keeps the base tint, no fake calm."""
    src = FORECAST_FIELD.read_text(encoding="utf-8")
    cores = src.split("func _update_trust_cores")[1].split("\nfunc ")[0]
    assert 'gauge.get("surprise", null)' in cores
    assert "if sup != null else 0.0" in cores
