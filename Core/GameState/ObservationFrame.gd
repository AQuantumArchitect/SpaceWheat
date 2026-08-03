extends Node

## ObservationFrame - Manages the spindle reference point in the fractal address
##
## The observation frame determines the reference point for fractal navigation:
## - ACTIVE SLOT ROW (TYUIOP): assigned spindle biomes anchored around neutral_index
## - UP CONTEXT (+1): parent/reference biome at neutral_index - 1
## - DOWN CONTEXT (-1): child/next biome at neutral_index + 1
##
## Selecting a biome or shifting context moves the spindle and changes the
## neutral reference point.

## Full biome order (loadable biomes from registry + icon build)
var ALL_BIOMES: Array[String] = []

## Current available biomes (filtered by unlocked status from GameState)
## Starts with ["StarterForest", "Village"], grows as player explores
var BIOME_ORDER: Array[String] = ["StarterForest", "Village"]

## Current neutral index in BIOME_ORDER
var neutral_index: int = 0


var _biome_registry: BiomeRegistry = null

## Signals
signal frame_shifted(old_biome: String, new_biome: String, direction: int)
signal neutral_changed(biome: String)
signal biome_order_changed(new_order: Array)


func _ready() -> void:
	add_to_group("observation_frame")
	# Initialize from GameState synchronously so Farm._ready() sees the correct biome order
	_load_unlocked_biomes()


## Get the current neutral biome
func get_neutral_biome() -> String:
	return BIOME_ORDER[neutral_index]


## Get biome at a given spindle offset
## offset: -1 = child/next context, 0 = active spindle slot, +1 = parent/reference context
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


## Replace the unlocked-biome order. SINGLE AUTHORITY (slop-patrol Tier 3):
## ObservationFrame owns BIOME_ORDER; ActiveBiomeManager mirrors it via the
## biome_order_changed signal. Writers (WorldBuilder, GameStateSerializer,
## rig) should call this — never poke BIOME_ORDER fields directly.
func set_biome_order(new_order: Array) -> void:
	var normalized: Array[String] = []
	for biome_name in new_order:
		var biome_text := str(biome_name)
		if biome_text == "":
			continue
		normalized.append(biome_text)
	BIOME_ORDER = normalized
	if neutral_index >= BIOME_ORDER.size():
		neutral_index = 0
	biome_order_changed.emit(BIOME_ORDER.duplicate())


## Check if a biome is currently the neutral reference
func is_neutral(biome_name: String) -> bool:
	return biome_name == get_neutral_biome()


## Get the current neutral index
func get_neutral_index() -> int:
	return neutral_index


func _load_unlocked_biomes() -> void:
	# Load unlocked biomes from GameState
	_refresh_loadable_biomes()
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.current_state and "unlocked_biomes" in gsm.current_state:
		var unlocked = gsm.current_state.unlocked_biomes
		# Clamp unlocked biomes to loadable list (keeps save data sane)
		unlocked = unlocked.filter(func(b): return b in ALL_BIOMES)
		if unlocked.size() > 0:
			BIOME_ORDER = unlocked.duplicate()
			# Clamp neutral_index to valid range
			if neutral_index >= BIOME_ORDER.size():
				neutral_index = 0
			biome_order_changed.emit(BIOME_ORDER.duplicate())

	# Refresh unexplored pool against loadable list. Biomes flagged
	# `discoverable=false` are skipped — they're loadable but cannot appear in
	# the captain-hat draw (used today only for opt-out; default is true).
	if gsm and gsm.current_state and "unexplored_biome_pool" in gsm.current_state:
		var pool = gsm.current_state.unexplored_biome_pool
		var refreshed: Array[String] = []
		# Preserve existing order where possible — but drop entries that are no
		# longer discoverable (defensive against JSON edits between sessions).
		for biome_name in pool:
			if (
				biome_name in ALL_BIOMES
				and biome_name not in BIOME_ORDER
				and biome_name not in refreshed
				and _is_biome_discoverable(biome_name)
			):
				refreshed.append(biome_name)
		# A CURATED pool (non-empty) is authoritative — the scenario hand-picked which
		# biomes this campaign can discover (e.g. "The Demos" → its island subset). Only
		# auto-fill the full catalog when the pool came up empty (sandbox / uncurated),
		# so curation isn't silently buried under all ~150 loadable biomes.
		if refreshed.is_empty():
			for biome_name in ALL_BIOMES:
				if (
					biome_name not in BIOME_ORDER
					and biome_name not in refreshed
					and _is_biome_discoverable(biome_name)
				):
					refreshed.append(biome_name)
		gsm.current_state.unexplored_biome_pool = refreshed


## True iff the biome's spec has `discoverable: true` (default true when the
## field is absent — preserves pre-cutover behavior for bare biomes).
func _is_biome_discoverable(biome_name: String) -> bool:
	if _biome_registry == null:
		_biome_registry = BiomeRegistry.get_shared()
	if _biome_registry == null:
		return true
	var spec = _biome_registry.get_by_name(biome_name)
	if spec == null:
		return true
	if "discoverable" in spec:
		return bool(spec.discoverable)
	return true


func unlock_biome(biome_name: String) -> bool:
	# Add a biome to the unlocked list
	#
	# Returns true if biome was newly unlocked, false if already unlocked
	if biome_name in BIOME_ORDER:
		return false  # Already unlocked

	if biome_name not in ALL_BIOMES:
		push_warning("ObservationFrame: Unknown biome '%s'" % biome_name)
		return false

	BIOME_ORDER.append(biome_name)
	biome_order_changed.emit(BIOME_ORDER.duplicate())

	# Persist to GameState
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.current_state:
		gsm.current_state.unlocked_biomes = BIOME_ORDER.duplicate()
		# Remove from unexplored pool
		if "unexplored_biome_pool" in gsm.current_state:
			var pool = gsm.current_state.unexplored_biome_pool
			var idx = pool.find(biome_name)
			if idx >= 0:
				pool.remove_at(idx)

	return true


func lock_biome(biome_name: String) -> bool:
	# Remove a biome from the unlocked list and return it to the unexplored pool.
	if biome_name == "" or biome_name not in BIOME_ORDER:
		return false
	if biome_name == "StarterForest" or biome_name == "Village":
		return false

	var removed_index := BIOME_ORDER.find(biome_name)
	if removed_index < 0:
		return false

	BIOME_ORDER.remove_at(removed_index)
	if BIOME_ORDER.is_empty():
		BIOME_ORDER = ["StarterForest", "Village"]

	if neutral_index >= BIOME_ORDER.size():
		neutral_index = max(0, BIOME_ORDER.size() - 1)
	elif removed_index <= neutral_index:
		neutral_index = max(0, neutral_index - 1)

	biome_order_changed.emit(BIOME_ORDER.duplicate())

	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.current_state:
		gsm.current_state.unlocked_biomes = BIOME_ORDER.duplicate()
		var pool: Array[String] = []
		if "unexplored_biome_pool" in gsm.current_state:
			for candidate in gsm.current_state.unexplored_biome_pool:
				var biome_text := str(candidate)
				if biome_text != "" and biome_text not in pool and biome_text not in BIOME_ORDER:
					pool.append(biome_text)
		if biome_name not in pool:
			pool.append(biome_name)
		gsm.current_state.unexplored_biome_pool = pool

	neutral_changed.emit(get_neutral_biome())
	return true


func get_unlocked_biomes() -> Array[String]:
	# Get list of unlocked biomes
	return BIOME_ORDER.duplicate()


func get_explored_biomes() -> Array[String]:
	# Alias for unlocked biomes (preferred terminology).
	return get_unlocked_biomes()


func get_loadable_biomes() -> Array[String]:
	# Get biomes that are valid/loadable (icon build succeeded).
	_refresh_loadable_biomes()
	return ALL_BIOMES.duplicate()


func get_unexplored_biomes() -> Array[String]:
	# Biomes available to the captain-hat draw. A CURATED pool (the scenario's
	# hand-picked subset, e.g. "The Demos" → its island) is authoritative; only fall
	# back to the full catalog when no pool is curated (sandbox). Previously this always
	# returned ALL_BIOMES − unlocked, so curation was ignored and the campaign's required
	# biomes were 2 needles in ~150.
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.current_state and "unexplored_biome_pool" in gsm.current_state:
		var pool = gsm.current_state.unexplored_biome_pool
		if pool != null and not pool.is_empty():
			var curated: Array[String] = []
			for entry in pool:
				var bn := str(entry)
				if bn in ALL_BIOMES and bn not in BIOME_ORDER and bn not in curated:
					curated.append(bn)
			if not curated.is_empty():
				return curated
	var unexplored: Array[String] = []
	for biome in ALL_BIOMES:
		if biome not in BIOME_ORDER:
			unexplored.append(biome)
	return unexplored


## Reset to initial state (for dev restart)
func reset() -> void:
	BIOME_ORDER = ["StarterForest", "Village"]
	neutral_index = 0
	biome_order_changed.emit(BIOME_ORDER.duplicate())


func _refresh_loadable_biomes() -> void:
	# Build icon sets for biomes and refresh the loadable biome list.
	if _biome_registry == null:
		_biome_registry = BiomeRegistry.get_shared()

	var loadable: Array[String] = []
	for biome in _biome_registry.get_all():
		if not biome:
			continue
		var _name = biome.name
		if _name.begins_with("_"):
			continue  # Skip internal/debug biomes (e.g. _orphan_lindblads)
		loadable.append(_name)

	ALL_BIOMES = loadable
