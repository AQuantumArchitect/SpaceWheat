extends Node


## ActiveBiomeManager - Singleton tracking which biome is currently active/visible
## Note: No class_name needed - accessed via autoload singleton "ActiveBiomeManager"
##
## Manages biome switching with swipe transitions. All biomes continue to evolve
## in the background; this only controls which one is displayed.
##
## Now integrates with ObservationFrame for spindle-based navigation.
## The ObservationFrame is the source of truth for which biome is "neutral".
##
## Keyboard (per UI/Core/KEYBOARD_GRAMMAR.md):
##   TYUIOP = middle selection row (assigned biome slots)
##   GHJKL; = inner selection row (current biome plots)
##   WASD   = crawl pad (W out / S in / A,D step across)
## Direct biome selection happens via TYUIOP; - / = are reserved for
## sim-speed (no longer biome-cycle).
##
## Signals emitted for UI updates (background, tabs, plot display, quantum graph)

signal active_biome_changed(new_biome: String, old_biome: String)
signal biome_transition_requested(from_biome: String, to_biome: String, direction: int)
signal biome_order_changed(new_order: Array)
signal slot_assignment_changed(slot_idx: int, biome_name: String)

## Full biome order (for reference)
const ALL_BIOMES: Array[String] = ["StarterForest", "Village", "BioticFlux", "StellarForges", "FungalNetworks", "VolcanicWorlds"]

## Current available biomes (filtered by unlocked status - synced with ObservationFrame)
var BIOME_ORDER: Array[String] = ["StarterForest", "Village"]

## Slot assignment (index -> biome name or "")
var _slot_assignment: Array[String] = ["StarterForest", "Village", "", "", "", ""]

## Biome display info (for UI)
const BIOME_INFO: Dictionary = {
	"StarterForest": {"key": "T", "emoji": "🌲", "label": "Forest"},
	"Village": {"key": "Y", "emoji": "🏘️", "label": "Village"},
	"BioticFlux": {"key": "U", "emoji": "~", "label": "Flux"},
	"StellarForges": {"key": "I", "emoji": "*", "label": "Forge"},
	"FungalNetworks": {"key": "O", "emoji": ".", "label": "Fungal"},
	"VolcanicWorlds": {"key": "P", "emoji": "^", "label": "Volcanic"},
}

## Current active biome (default matches ObservationFrame's initial neutral_index = 0)
var active_biome: String = "StarterForest"

## Whether a transition is currently in progress (prevents rapid switching)
var _transitioning: bool = false

## Reference to ObservationFrame for spindle-based navigation
var _observation_frame: Node = null


func _ready() -> void:
	add_to_group("active_biome_manager")

	# Connect to ObservationFrame when it's ready
	call_deferred("_connect_to_observation_frame")


func _connect_to_observation_frame() -> void:
	# Connect to ObservationFrame for spindle-based biome tracking.
	_observation_frame = get_node_or_null("/root/ObservationFrame")
	if _observation_frame:
		if not _observation_frame.neutral_changed.is_connected(_on_neutral_changed):
			_observation_frame.neutral_changed.connect(_on_neutral_changed)
		if _observation_frame.has_signal("biome_order_changed") \
				and not _observation_frame.biome_order_changed.is_connected(_apply_biome_order):
			_observation_frame.biome_order_changed.connect(_apply_biome_order)
		# Sync initial state
		active_biome = _observation_frame.get_neutral_biome()
		# Sync unlocked biomes
		_apply_biome_order(_observation_frame.get_unlocked_biomes())


func _on_neutral_changed(biome: String) -> void:
	# Handle neutral biome change from ObservationFrame.
	if biome != active_biome:
		var old_biome = active_biome
		active_biome = biome
		active_biome_changed.emit(biome, old_biome)


func get_active_biome() -> String:
	# Get the currently active biome name
	return active_biome


func set_active_biome(biome_name: String, direction: int = 0) -> void:
	# Set the active biome with optional transition direction
	#
	# Args:
	# biome_name: Name of biome to switch to
	# direction: -1 = slide left, 0 = instant, 1 = slide right
	if biome_name == active_biome:
		return

	if not biome_name in BIOME_ORDER:
		push_warning("ActiveBiomeManager: Unknown biome '%s'" % biome_name)
		return

	if _transitioning:
		return  # Ignore if already transitioning

	var old_biome = active_biome
	active_biome = biome_name

	# Sync with ObservationFrame if available
	if _observation_frame and _observation_frame.get_neutral_biome() != biome_name:
		_observation_frame.set_neutral_biome(biome_name)

	# Emit transition request (for animated transitions)
	if direction != 0:
		biome_transition_requested.emit(old_biome, biome_name, direction)

	# Emit change notification (for immediate updates)
	active_biome_changed.emit(biome_name, old_biome)


func cycle_next() -> void:
	# Cycle to the next biome (slide right animation)
	var idx = BIOME_ORDER.find(active_biome)
	var next_idx = (idx + 1) % BIOME_ORDER.size()
	set_active_biome(BIOME_ORDER[next_idx], 1)  # direction = 1 (right)


func cycle_prev() -> void:
	# Cycle to the previous biome (slide left animation)
	var idx = BIOME_ORDER.find(active_biome)
	var prev_idx = (idx - 1 + BIOME_ORDER.size()) % BIOME_ORDER.size()
	set_active_biome(BIOME_ORDER[prev_idx], -1)  # direction = -1 (left)


func select_biome_by_key(keycode: int) -> bool:
	# Handle direct biome selection by the shared TYUIOP row.
	#
	# Returns: true if key was handled, false otherwise
	for slot_idx in range(InputBindingRegistry.get_biome_keys().size()):
		if InputBindingRegistry.get_keycode_for_label(get_slot_key(slot_idx)) != keycode:
			continue

		var biome_name = get_biome_for_slot(slot_idx)
		if biome_name == "":
			return true  # Slot is unassigned, consume the key
		var direction = _get_direction_to(biome_name)
		set_active_biome(biome_name, direction)
		return true

	return false


func _get_direction_to(target_biome: String) -> int:
	# Calculate slide direction from current to target biome
	var current_idx = BIOME_ORDER.find(active_biome)
	var target_idx = BIOME_ORDER.find(target_biome)

	if target_idx > current_idx:
		return 1  # Slide right
	elif target_idx < current_idx:
		return -1  # Slide left
	return 0  # Same biome


func set_transitioning(value: bool) -> void:
	# Called by BiomeBackground when transition starts/ends
	_transitioning = value


func get_biome_index(biome_name: String) -> int:
	# Get the index of a biome in BIOME_ORDER
	return BIOME_ORDER.find(biome_name)


func get_biome_at_index(index: int) -> String:
	# Get biome name at index
	if index >= 0 and index < BIOME_ORDER.size():
		return BIOME_ORDER[index]
	return ""


func get_biome_count() -> int:
	# Get total number of biomes
	return BIOME_ORDER.size()


func get_biome_for_slot(slot_idx: int) -> String:
	# Get the biome assigned to a key slot (T/Y/U/I/O/P).
	if slot_idx < 0:
		return ""
	if slot_idx >= _slot_assignment.size():
		return ""
	return _slot_assignment[slot_idx]


func get_slot_key(slot_idx: int) -> String:
	# Get the key label for a slot index.
	var slot_keys = InputBindingRegistry.get_biome_keys()
	if slot_idx < 0 or slot_idx >= slot_keys.size():
		return ""
	return slot_keys[slot_idx]


func get_slot_count() -> int:
	# Total number of biome slots (TYUIOP row).
	return InputBindingRegistry.get_biome_keys().size()


func get_open_slot_count() -> int:
	# Number of unassigned biome slots available.
	if _slot_assignment.size() != InputBindingRegistry.get_biome_keys().size():
		_rebuild_slot_assignment()
	var open_count = 0
	for slot in _slot_assignment:
		if slot == "":
			open_count += 1
	return open_count


func has_open_biome_slot() -> bool:
	# True if there is at least one unassigned biome slot.
	return get_open_slot_count() > 0


func get_biome_order() -> Array[String]:
	# Get the current unlocked biome order.
	return BIOME_ORDER.duplicate()


func set_biome_order(new_order: Array) -> void:
	# Replace the current unlocked biome order and notify listeners.
	#
	# ObservationFrame is the single authority for BIOME_ORDER (slop-patrol
	# Tier 3); this manager only mirrors it. Apply locally first (covers
	# headless setups with no ObservationFrame autoload), then push through
	# the authority — its biome_order_changed signal re-applies here
	# idempotently, and keeps any other mirror in sync.
	_apply_biome_order(new_order)
	if _observation_frame == null:
		_observation_frame = get_node_or_null("/root/ObservationFrame")
	if _observation_frame and _observation_frame.has_method("set_biome_order"):
		if _observation_frame.get_unlocked_biomes() != BIOME_ORDER:
			_observation_frame.set_biome_order(new_order)


func _apply_biome_order(new_order: Array) -> void:
	# Mirror-apply an order pushed by ObservationFrame (or a direct caller
	# when no ObservationFrame exists). Does NOT write back to the authority.
	var normalized: Array[String] = []
	for biome_name in new_order:
		var biome_text := str(biome_name)
		if biome_text == "":
			continue
		normalized.append(biome_text)
	BIOME_ORDER = normalized
	if not active_biome in BIOME_ORDER and BIOME_ORDER.size() > 0:
		active_biome = BIOME_ORDER[0]
	_rebuild_slot_assignment()
	biome_order_changed.emit(BIOME_ORDER.duplicate())


func get_biome_info(biome_name: String) -> Dictionary:
	# Get display info for a biome
	return BIOME_INFO.get(biome_name, {})


func reset() -> void:
	# Reset to initial state (for dev restart).
	active_biome = "StarterForest"
	# Local mirror only — SessionLifecycle resets ObservationFrame itself;
	# writing back to the authority here would fight that reset ordering.
	_apply_biome_order(["StarterForest", "Village"])
	_transitioning = false
	_observation_frame = null


## Bind a biome to a TYUIOP slot. Returns true on success.
##
## Constraints:
##   - slot_idx must be in [0, slot_count)
##   - biome_name must be unlocked (in BIOME_ORDER), or "" to clear
##   - if biome_name is already bound to a different slot, that slot is
##     cleared first (a biome lives on at most one TYUIOP slot)
##
## Emits slot_assignment_changed for every slot whose binding changed.
func set_slot_assignment(slot_idx: int, biome_name: String) -> bool:
	if slot_idx < 0 or slot_idx >= _slot_assignment.size():
		return false
	if biome_name != "" and not biome_name in BIOME_ORDER:
		return false
	# Same value already? Nothing to do.
	if _slot_assignment[slot_idx] == biome_name:
		return true
	# If this biome already lives in another slot, clear that slot first
	# so a biome appears on at most one TYUIOP key.
	if biome_name != "":
		for i in range(_slot_assignment.size()):
			if i == slot_idx:
				continue
			if _slot_assignment[i] == biome_name:
				_slot_assignment[i] = ""
				slot_assignment_changed.emit(i, "")
	_slot_assignment[slot_idx] = biome_name
	slot_assignment_changed.emit(slot_idx, biome_name)
	return true


func clear_slot(slot_idx: int) -> bool:
	# Empty the named slot (frees its TYUIOP key for any biome).
	return set_slot_assignment(slot_idx, "")


func get_slot_for_biome(biome_name: String) -> int:
	# Return the slot a biome is currently bound to, or -1 if unbound.
	for i in range(_slot_assignment.size()):
		if _slot_assignment[i] == biome_name:
			return i
	return -1


func _rebuild_slot_assignment() -> void:
	# Slots follow BIOME_ORDER (the scenario's authored unlock order) onto
	# TYUIOP, first six. No biome is pinned to a key — the order is content
	# (owner: identity → story location → extraction zones), not code.
	_slot_assignment = ["", "", "", "", "", ""]
	var slot_idx = 0
	for biome_name in BIOME_ORDER:
		if slot_idx >= _slot_assignment.size():
			break
		_slot_assignment[slot_idx] = biome_name
		slot_idx += 1
