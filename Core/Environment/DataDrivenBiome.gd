class_name DataDrivenBiome
extends "res://Core/Environment/BiomeBase.gd"

## DataDrivenBiome
## Generic biome that builds its quantum system from BiomeRegistry data.
## Used for dynamically discovered biomes that don't have bespoke scripts.

const BiomeRegistry = preload("res://Core/Biomes/BiomeRegistry.gd")
const BiomeBuilder = preload("res://Core/Biomes/BiomeBuilder.gd")

var _biome_data = null
var _emoji_pairs: Array = []


func _ready() -> void:
	# Let BiomeBase initialize and call _initialize_bath().
	super._ready()

	# Register emoji pairs with the resource registry (gameplay layer).
	for pair in _emoji_pairs:
		var north = pair.get("north", "")
		var south = pair.get("south", "")
		if north != "" and south != "":
			register_emoji_pair(north, south)

	# Basic visual label (can be overridden by biome data later).
	if visual_label == "":
		visual_label = name


func _initialize_bath() -> void:
	"""Build quantum computer from biome JSON data."""
	var registry = BiomeRegistry.new()
	_biome_data = registry.get_by_name(name)
	if not _biome_data:
		push_error("DataDrivenBiome: Biome not found in registry: %s" % name)
		return

	# Build emoji pairs from ordered emoji list (pairs are [0,1], [2,3], ...)
	_emoji_pairs = BiomeBuilder._group_emojis_into_pairs(_biome_data.emojis)
	if _emoji_pairs.is_empty():
		push_error("DataDrivenBiome: No emoji pairs for biome %s" % name)
		return

	# Build Lindblad spec from biome icon_components
	var lindblad_spec = BiomeBuilder._build_lindblad_spec_from_biome(_biome_data)

	# Build quantum system using unified builder (H from factions, L from biome)
	var result = BiomeBuilder.build_biome_quantum_system(
		name,
		_emoji_pairs,
		{},  # Faction standings default to full strength
		lindblad_spec
	)

	if not result.success:
		push_error("DataDrivenBiome: Failed to build quantum system for %s: %s" % [name, result.error])
		return

	quantum_computer = result.quantum_computer
