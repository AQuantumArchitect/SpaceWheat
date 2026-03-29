from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def _read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def test_biome_routing_manager_no_longer_carries_dead_legacy_biome_fallback() -> None:
    src = _read("Core/GameMechanics/Grid/BiomeRoutingManager.gd")
    assert "var legacy_biome" not in src
    assert "func set_legacy_biome(" not in src
    assert "return legacy_biome" not in src
