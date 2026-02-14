class_name CacheKey
extends RefCounted

## Cache Key Generator for Operator Caching
## Generates deterministic hash keys from Icon configurations
## Key automatically changes when Icon data changes, invalidating cache

## Generate cache key for a biome's quantum operators
## Returns 8-character hash that changes when Icon configs change
static func for_biome(biome_name: String, icon_registry) -> String:
	"""
	Generate cache key for a biome's operators.
	Key = Hash(biome structure + Icon configs used)

	The key automatically invalidates when:
	- Icon self_energy changes
	- Icon hamiltonian_couplings change
	- Icon lindblad_incoming/outgoing changes
	- Icon decay_rate/decay_target changes
	"""
	var config_data = {
		"biome_name": biome_name,
		"version": 1,  # Increment when algorithm changes
		"icons": _collect_icon_configs(biome_name, icon_registry)
	}

	return _hash_config(config_data)

## Collect all Icon data that affects this biome's operators
## Reads emojis directly from the icons Dictionary passed by callers.
static func _collect_icon_configs(_biome_name: String, icon_registry) -> Dictionary:
	var configs = {}

	if not icon_registry is Dictionary:
		push_warning("CacheKey: icon_registry is not a Dictionary — cache key will not reflect Icon configs")
		return configs

	for emoji in icon_registry.keys():
		var icon = icon_registry.get(emoji, null)
		if not icon:
			continue

		# Extract ONLY fields that affect operators
		# Changes to other fields (display_name, description, etc.) don't invalidate cache
		configs[emoji] = {
			"self_energy": icon.self_energy,
			"hamiltonian_couplings": icon.hamiltonian_couplings.duplicate(),
			"lindblad_incoming": icon.lindblad_incoming.duplicate(),
			"lindblad_outgoing": icon.lindblad_outgoing.duplicate(),
			"decay_rate": icon.decay_rate,
			"decay_target": icon.decay_target,
			"energy_couplings": icon.energy_couplings.duplicate() if icon.energy_couplings else {}
		}

	return configs

## Generate deterministic hash from config Dictionary
static func _hash_config(config: Dictionary) -> String:
	# Sort keys for deterministic JSON (Dictionary iteration order may vary)
	var json_str = JSON.stringify(config, "\t", true)  # Sort keys

	# MD5 hash, truncated to 8 characters (sufficient for uniqueness)
	return json_str.md5_text().substr(0, 8)
