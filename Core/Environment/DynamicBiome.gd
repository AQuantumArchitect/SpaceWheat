class_name DynamicBiome
extends "res://Core/Environment/BiomeBase.gd"

## DynamicBiome - A BiomeBase with configurable biome_type
## Used by TestBootManager for JSON-built biomes.

var _biome_type: String = "Dynamic"

func set_biome_type(_type: String) -> void:
	_biome_type = _type

func get_biome_type() -> String:
	return _biome_type
