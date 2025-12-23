class_name BiomeUtilities
extends Object

## Utility functions for common biome operations
## Static helpers - no state, pure functions

const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")


static func create_qubit(north: String, south: String, theta: float = PI/2.0, radius: float = 1.0) -> DualEmojiQubit:
	"""Standard qubit initialization pattern

	Creates a DualEmojiQubit with consistent initialization across all biomes.
	Eliminates duplicated initialization code in 8 biome files.
	"""
	var qubit = DualEmojiQubit.new(north, south, theta)
	qubit.phi = 0.0
	qubit.radius = radius
	return qubit


static func create_status_dict(base_params: Dictionary) -> Dictionary:
	"""Template for status reporting

	Ensures consistent status dictionary format across all biomes.
	"""
	var status = {
		"timestamp": Time.get_ticks_msec(),
		"time_elapsed": 0.0
	}
	status.merge(base_params)
	return status


static func format_debug_info(biome_name: String, params: Dictionary) -> String:
	"""Standard debug output formatting

	Formats biome debug information consistently.
	"""
	var output = "[%s Biome]\n" % biome_name
	for key in params.keys():
		output += "  %s: %s\n" % [key, params[key]]
	return output
