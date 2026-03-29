from pathlib import Path


def test_boot_manager_attaches_registry_biomes_to_farm_tree():
    source = Path("Core/Boot/BootManager.gd").read_text(encoding="utf-8")
    assert 'if biome.get_parent() == null:' in source
    assert 'farm.add_child(biome)' in source


def test_dynamic_biomes_are_still_built_off_tree_before_attachment():
    source = Path("Core/Boot/BootManager.gd").read_text(encoding="utf-8")
    assert 'BiomeBuilder.build_from_registry(biome_name, farm.grid, {"skip_tree_add": true})' in source
