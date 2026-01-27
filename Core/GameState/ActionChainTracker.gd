extends Node

## ActionChainTracker - Tracks observation history with fractal addresses
##
## Records player actions to build a chain of observations through the
## quantum state space. Each entry includes:
## - key: The key pressed
## - plot_idx: Which plot (0-3) was selected
## - biome: Which biome the plot belongs to
## - direction: -1 (DOWN), 0 (NEUTRAL), +1 (UP)
## - timestamp: When the action occurred
## - tool_group: Which tool group was active
## - address: Current fractal address path

## The observation chain
var chain: Array[Dictionary] = []

## Index of the latest entry
var latest_index: int = -1

## Maximum chain length (to prevent unbounded growth)
const MAX_CHAIN_LENGTH: int = 1000

## Signals
signal latest_changed(entry: Dictionary)
signal chain_extended(chain: Array)
signal address_changed(address: Array)


func _ready() -> void:
	add_to_group("action_chain_tracker")


## Record a new observation in the chain
func record_observation(key: String, plot_idx: int, biome: String, direction: int) -> void:
	var entry = {
		"key": key,
		"plot_idx": plot_idx,
		"biome": biome,
		"direction": direction,
		"timestamp": Time.get_ticks_msec(),
		"tool_group": _get_current_tool_group(),
		"address": _compute_address()
	}

	chain.append(entry)
	latest_index = chain.size() - 1

	# Trim chain if it exceeds max length
	if chain.size() > MAX_CHAIN_LENGTH:
		chain = chain.slice(chain.size() - MAX_CHAIN_LENGTH)
		latest_index = chain.size() - 1

	latest_changed.emit(entry)
	chain_extended.emit(chain)


## Get the latest observation entry
func get_latest() -> Dictionary:
	if latest_index < 0 or latest_index >= chain.size():
		return {}
	return chain[latest_index]


## Get the current fractal address path
func get_address() -> Array:
	return _compute_address()


## Get the full chain
func get_chain() -> Array[Dictionary]:
	return chain


## Get recent entries (last N)
func get_recent(count: int) -> Array[Dictionary]:
	if chain.is_empty():
		return []
	var start_idx = max(0, chain.size() - count)
	var result: Array[Dictionary] = []
	for i in range(start_idx, chain.size()):
		result.append(chain[i])
	return result


## Clear the chain
func clear() -> void:
	chain.clear()
	latest_index = -1


## Reset to initial state (for dev restart)
func reset() -> void:
	clear()


## Compute the current fractal address from observation history
func _compute_address() -> Array:
	# Build address from recent direction shifts
	# This creates a path through the biome hierarchy
	var address: Array = []

	# Start from the end of the chain and work backwards to build the address
	var current_biome = ""
	var observation_frame = get_node_or_null("/root/ObservationFrame")
	if observation_frame:
		current_biome = observation_frame.get_neutral_biome()

	# Add current neutral as the base
	if current_biome:
		address.append({"biome": current_biome, "direction": 0})

	# Add recent movements to build the path
	for entry in get_recent(10):
		if entry.direction != 0:
			address.append({
				"biome": entry.biome,
				"direction": entry.direction,
				"plot_idx": entry.plot_idx
			})

	return address


## Get the current tool group from ToolConfig (new time scale system)
func _get_current_tool_group() -> int:
	# Access via the ToolConfig singleton pattern
	var tool_config_script = load("res://Core/GameState/ToolConfig.gd")
	if tool_config_script:
		return tool_config_script.current_group
	return 1


## Get statistics about the chain
func get_stats() -> Dictionary:
	if chain.is_empty():
		return {
			"total_observations": 0,
			"unique_biomes": 0,
			"direction_counts": {-1: 0, 0: 0, 1: 0}
		}

	var biomes_visited: Dictionary = {}
	var direction_counts: Dictionary = {-1: 0, 0: 0, 1: 0}

	for entry in chain:
		biomes_visited[entry.biome] = true
		direction_counts[entry.direction] += 1

	return {
		"total_observations": chain.size(),
		"unique_biomes": biomes_visited.size(),
		"direction_counts": direction_counts,
		"first_timestamp": chain[0].timestamp,
		"last_timestamp": chain[chain.size() - 1].timestamp
	}
