class_name SubmenuManager
extends RefCounted

## SubmenuManager - Submenu state machine
##
## Manages submenu navigation, dynamic submenu generation, and caching.
## Decouples submenu logic from FarmInputHandler.

const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const QuantumMill = preload("res://Core/GameMechanics/QuantumMill.gd")

# Current submenu name (empty = not in submenu)
var current_submenu: String = ""

# Cached submenu data for dynamic menus
var _cached_submenu: Dictionary = {}

# Signals
signal submenu_changed(submenu_name: String, submenu_info: Dictionary)


## ============================================================================
## SUBMENU STATE QUERIES
## ============================================================================

func is_in_submenu() -> bool:
	"""Check if currently in a submenu."""
	return current_submenu != ""


func get_current_submenu_name() -> String:
	"""Get current submenu name."""
	return current_submenu


func get_current_submenu() -> Dictionary:
	"""Get current submenu definition (with caching for dynamic menus)."""
	if current_submenu == "":
		return {}
	if not _cached_submenu.is_empty():
		return _cached_submenu
	return ToolConfig.get_submenu(current_submenu)


func get_submenu_action(action_key: String) -> Dictionary:
	"""Get action info for key (Q/E/R) in current submenu."""
	var submenu = get_current_submenu()
	return submenu.get(action_key, {})


func is_submenu_disabled() -> bool:
	"""Check if current submenu is disabled (e.g., no vocabulary discovered)."""
	var submenu = get_current_submenu()
	return submenu.get("_disabled", false)


## ============================================================================
## SUBMENU NAVIGATION
## ============================================================================

func enter_submenu(submenu_name: String, farm, menu_position: Vector2i) -> void:
	"""Enter a submenu - QER keys now map to submenu actions.

	Args:
		submenu_name: Name of submenu to enter
		farm: Farm instance for dynamic menu generation
		menu_position: Position to use for context-aware menus
	"""
	var submenu = ToolConfig.get_submenu(submenu_name)
	if submenu.is_empty():
		push_error("Submenu '%s' not found" % submenu_name)
		return

	# Check if submenu is dynamic - generate runtime actions
	if submenu.get("dynamic", false):
		submenu = ToolConfig.get_dynamic_submenu(submenu_name, farm, menu_position)

	# Special handling for mill_power submenu: inject availability
	if submenu_name == "mill_power" and farm and farm.grid:
		submenu = submenu.duplicate(true)  # Make copy to add availability
		var biome = farm.grid.get_biome_for_plot(menu_position)
		var availability = QuantumMill.check_power_availability(biome)
		submenu["_availability"] = availability

	current_submenu = submenu_name
	_cached_submenu = submenu

	submenu_changed.emit(submenu_name, submenu)


func exit_submenu() -> void:
	"""Exit current submenu and return to tool mode."""
	if current_submenu == "":
		return

	current_submenu = ""
	_cached_submenu = {}

	submenu_changed.emit("", {})


func enter_mill_conversion_submenu(farm, menu_position: Vector2i) -> void:
	"""Enter mill conversion submenu (stage 2 of mill placement).

	Args:
		farm: Farm instance
		menu_position: Position for biome lookup
	"""
	if not farm or not farm.grid:
		return

	var biome = farm.grid.get_biome_for_plot(menu_position)
	var conv_availability = QuantumMill.check_conversion_availability(biome)

	var submenu = ToolConfig.SUBMENUS.get("mill_conversion", {}).duplicate(true)
	submenu["_availability"] = conv_availability

	current_submenu = "mill_conversion"
	_cached_submenu = submenu

	submenu_changed.emit("mill_conversion", submenu)


## ============================================================================
## DYNAMIC SUBMENU REFRESH
## ============================================================================

func refresh_dynamic_submenu(farm, menu_position: Vector2i) -> void:
	"""Refresh dynamic submenu when selection changes.

	If currently in a dynamic submenu (like plant), regenerate it based on
	the new selected plot's biome.

	Args:
		farm: Farm instance
		menu_position: New position for context
	"""
	if current_submenu == "":
		return  # Not in a submenu

	# Check if current submenu is dynamic
	var base_submenu = ToolConfig.get_submenu(current_submenu)
	if not base_submenu.get("dynamic", false):
		return  # Not a dynamic submenu

	# Regenerate dynamic submenu for new selection
	var regenerated = ToolConfig.get_dynamic_submenu(current_submenu, farm, menu_position)
	_cached_submenu = regenerated

	# Re-emit submenu_changed to update UI
	submenu_changed.emit(current_submenu, regenerated)


## ============================================================================
## ACTION EXECUTION SUPPORT
## ============================================================================

func get_action_name_for_key(action_key: String) -> String:
	"""Get action name for key in current submenu.

	Returns:
		Action name string, or empty if not found/locked
	"""
	var action_info = get_submenu_action(action_key)
	return action_info.get("action", "")


func is_action_locked(action_key: String) -> bool:
	"""Check if action for key is locked (empty action).

	Returns:
		True if action is locked/unavailable
	"""
	var action = get_action_name_for_key(action_key)
	return action == ""


func get_action_label_for_key(action_key: String) -> String:
	"""Get action label for key in current submenu."""
	var action_info = get_submenu_action(action_key)
	return action_info.get("label", "")


## ============================================================================
## UTILITY
## ============================================================================

func reset() -> void:
	"""Reset submenu state (e.g., on tool change)."""
	current_submenu = ""
	_cached_submenu = {}
