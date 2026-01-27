extends Node

## ObservationFrame - Manages the spindle (which biome is neutral in the fractal address)
##
## The observation frame determines the reference point for fractal navigation:
## - NEUTRAL (UIOP row): Current biome at neutral_index
## - UP (7890 row): Parent biome at neutral_index - 1
## - DOWN (JKL; row): Child biome at neutral_index + 1
##
## Selecting plots in UP or DOWN rows shifts the spindle, making that biome
## the new neutral reference point.

## Biome order for the fractal hierarchy
const BIOME_ORDER: Array[String] = ["BioticFlux", "StellarForges", "FungalNetworks", "VolcanicWorlds"]

## Current neutral index in BIOME_ORDER
var neutral_index: int = 0

## Signals
signal frame_shifted(old_biome: String, new_biome: String, direction: int)
signal neutral_changed(biome: String)


func _ready() -> void:
	add_to_group("observation_frame")


## Get the current neutral biome
func get_neutral_biome() -> String:
	return BIOME_ORDER[neutral_index]


## Get biome at a given offset from neutral
## offset: -1 = DOWN (JKL; row), 0 = NEUTRAL (UIOP row), +1 = UP (7890 row)
func get_biome_at_offset(offset: int) -> String:
	# UP (+1) means we go to earlier index, DOWN (-1) means later index
	# This creates the hierarchical parent/child relationship
	var idx = (neutral_index - offset) % BIOME_ORDER.size()
	if idx < 0:
		idx += BIOME_ORDER.size()
	return BIOME_ORDER[idx]


## Shift the observation frame
## direction: -1 = shift DOWN (selected child becomes neutral)
##            +1 = shift UP (selected parent becomes neutral)
func shift(direction: int) -> void:
	if direction == 0:
		return

	var old_biome = get_neutral_biome()

	# Shift the neutral index
	# When selecting UP (+1), we shift neutral_index down (-1) so that biome becomes new neutral
	# When selecting DOWN (-1), we shift neutral_index up (+1) so that biome becomes new neutral
	neutral_index = (neutral_index - direction) % BIOME_ORDER.size()
	if neutral_index < 0:
		neutral_index += BIOME_ORDER.size()

	var new_biome = get_neutral_biome()

	frame_shifted.emit(old_biome, new_biome, direction)
	neutral_changed.emit(new_biome)


## Set the neutral biome directly by name
func set_neutral_biome(biome_name: String) -> void:
	var idx = BIOME_ORDER.find(biome_name)
	if idx >= 0 and idx != neutral_index:
		var old_biome = get_neutral_biome()
		neutral_index = idx
		frame_shifted.emit(old_biome, biome_name, 0)
		neutral_changed.emit(biome_name)


## Get the direction to shift from current neutral to reach target biome
func get_direction_to(target_biome: String) -> int:
	var target_idx = BIOME_ORDER.find(target_biome)
	if target_idx < 0:
		return 0

	if target_idx == neutral_index:
		return 0

	# Calculate shortest path direction
	var forward_dist = (target_idx - neutral_index + BIOME_ORDER.size()) % BIOME_ORDER.size()
	var backward_dist = (neutral_index - target_idx + BIOME_ORDER.size()) % BIOME_ORDER.size()

	if forward_dist <= backward_dist:
		return -1  # DOWN direction gets us there
	else:
		return 1   # UP direction gets us there


## Get index of a biome in BIOME_ORDER
func get_biome_index(biome_name: String) -> int:
	return BIOME_ORDER.find(biome_name)


## Get biome at a specific index
func get_biome_at_index(index: int) -> String:
	if index >= 0 and index < BIOME_ORDER.size():
		return BIOME_ORDER[index]
	return ""


## Get total number of biomes
func get_biome_count() -> int:
	return BIOME_ORDER.size()


## Check if a biome is currently the neutral reference
func is_neutral(biome_name: String) -> bool:
	return biome_name == get_neutral_biome()


## Get the current neutral index
func get_neutral_index() -> int:
	return neutral_index


## Reset to initial state (for dev restart)
func reset() -> void:
	neutral_index = 0
