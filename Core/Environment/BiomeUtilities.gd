class_name BiomeUtilities
extends Object

## Utility functions for common biome operations
## Static helpers - no state, pure functions



static func create_status_dict(base_params: Dictionary) -> Dictionary:
	# Template for status reporting

	# Ensures consistent status dictionary format across all biomes.
	var status = {
		"timestamp": Time.get_ticks_msec(),
		"time_elapsed": 0.0
	}
	status.merge(base_params)
	return status
