from conftest import ROOT, read_source as _read


def test_biome_routing_manager_no_longer_carries_dead_biome_fallback() -> None:
    src = _read("Core/GameMechanics/Grid/BiomeRoutingManager.gd")
    dead_biome = "leg" "acy_biome"
    assert "var " + dead_biome not in src
    assert "func set_" + dead_biome + "(" not in src
    assert "return " + dead_biome not in src
