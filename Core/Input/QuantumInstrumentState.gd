class_name QuantumInstrumentState
extends RefCounted

## Headless quantum instrument state machine
## No UI dependencies - can be used for:
## - UI (QuantumInstrumentInput)
## - Headless tests
## - AI players
## - Automation scripts
## - Network server

# ============================================================================
# STATE
# ============================================================================

## Selection state
var current_biome: String = ""
var current_plot_idx: int = -1
var current_subspace_idx: int = -1  # Reserved for future subspace navigation
var last_selected_position: Vector2i = Vector2i(-1, -1)
var checked_plots: Array[Vector2i] = []  # Multi-select

## Submenu state
var current_submenu_name: String = ""
var current_submenu_data: Dictionary = {}
var submenu_page: int = 0

## Tool state
var current_tool_group: int = 3
var tool_mode_indices: Dictionary = {}  # Per-tool mode tracking

# ============================================================================
# ACTION EXECUTION
# ============================================================================

func handle_action_key(key: String, context: Dictionary) -> Dictionary:
	"""Execute action for key (Q/E/R) in current context.

	Args:
		key: Action key ("Q", "E", "R")
		context: {farm, biome, position, economy, ...}

	Returns:
		{
			"success": bool,
			"action": String,
			"message": String,
			"invalidates_buffer": bool,
			"submenu_changed": bool,
			"selection_changed": bool
		}
	"""
	if is_in_submenu():
		return _execute_submenu_action(key, context)
	else:
		return _execute_tool_action(key, context)


# ============================================================================
# SUBMENU MANAGEMENT
# ============================================================================

func enter_submenu(name: String, context: Dictionary) -> Dictionary:
	"""Enter a submenu, generating its content.

	Args:
		name: Submenu identifier ("vocab_injection", "gate_selection")
		context: {farm, biome, position, selection}

	Returns:
		Submenu data dict with Q/E/R actions
	"""
	submenu_page = 0
	current_submenu_name = name

	# Generate submenu using headless generators
	if name == "vocab_injection":
		var VocabInjectionSubmenu = load("res://UI/Core/Submenus/VocabInjectionSubmenu.gd")
		current_submenu_data = VocabInjectionSubmenu.generate_submenu(
			context.biome, context.farm, submenu_page
		)
	elif name == "gate_selection":
		var GateSelectionSubmenu = load("res://UI/Core/Submenus/GateSelectionSubmenu.gd")
		current_submenu_data = GateSelectionSubmenu.generate_submenu(
			context.biome, context.farm, checked_plots, submenu_page
		)
	else:
		push_error("Unknown submenu: %s" % name)
		return {}

	return current_submenu_data


func exit_submenu() -> void:
	"""Exit current submenu."""
	current_submenu_name = ""
	current_submenu_data = {}
	submenu_page = 0


func cycle_submenu_page(context: Dictionary) -> Dictionary:
	"""Cycle to next page (F key), regenerate submenu.

	Returns:
		{
			"submenu_changed": true,
			"submenu_name": String,
			"submenu_data": Dictionary,
			"page": int,
			"max_pages": int
		}
	"""
	submenu_page += 1
	var submenu_data = enter_submenu(current_submenu_name, context)

	return {
		"submenu_changed": true,
		"submenu_name": current_submenu_name,
		"submenu_data": submenu_data,
		"page": submenu_page,
		"max_pages": submenu_data.get("max_pages", 1)
	}


func is_in_submenu() -> bool:
	return current_submenu_name != ""


# ============================================================================
# SELECTION MANAGEMENT
# ============================================================================

func select_plot(plot_idx: int, biome_name: String, position: Vector2i) -> Dictionary:
	"""Select a plot, updating state.

	Returns:
		{selection_changed: bool, old_idx, new_idx, old_biome, new_biome, position}
	"""
	var old_idx = current_plot_idx
	var old_biome = current_biome

	current_plot_idx = plot_idx
	current_biome = biome_name
	last_selected_position = position

	return {
		"selection_changed": old_idx != plot_idx or old_biome != biome_name,
		"old_idx": old_idx,
		"new_idx": plot_idx,
		"old_biome": old_biome,
		"new_biome": biome_name,
		"position": position
	}


func toggle_plot_check(position: Vector2i) -> Dictionary:
	"""Toggle multi-select checkbox for plot.

	Returns:
		{is_checked: bool, position: Vector2i, checked_count: int}
	"""
	var idx = checked_plots.find(position)
	if idx >= 0:
		checked_plots.remove_at(idx)
		return {
			"is_checked": false,
			"position": position,
			"checked_count": checked_plots.size()
		}
	else:
		checked_plots.append(position)
		return {
			"is_checked": true,
			"position": position,
			"checked_count": checked_plots.size()
		}


func clear_checked_plots() -> void:
	"""Clear all checked plots."""
	checked_plots.clear()


# ============================================================================
# TOOL MANAGEMENT
# ============================================================================

func set_tool_group(group: int) -> Dictionary:
	"""Switch to tool group (1-4).

	Returns:
		{group: int, changed: bool}
	"""
	var old_group = current_tool_group
	current_tool_group = group
	return {"group": group, "changed": old_group != group}


func cycle_tool_mode(context: Dictionary) -> Dictionary:
	"""Cycle mode within current tool (F key when not in submenu).

	Returns:
		{
			"mode_cycled": true,
			"group": int,
			"mode_index": int,
			"mode_label": String
		}
	"""
	var ToolConfig = load("res://Core/GameState/ToolConfig.gd")
	var new_index = ToolConfig.cycle_group_mode(current_tool_group)
	var mode_label = ToolConfig.get_group_mode_label(current_tool_group)

	return {
		"mode_cycled": true,
		"group": current_tool_group,
		"mode_index": new_index,
		"mode_label": mode_label
	}


# ============================================================================
# QUERY INTERFACE (for AI/automation)
# ============================================================================

func get_available_actions(context: Dictionary) -> Array:
	"""Get list of all available actions in current state.

	Used by:
	- AI players (to choose actions)
	- UI (to show enabled/disabled buttons)
	- Tests (to validate state)

	Returns:
		Array of {key: String, action: String, enabled: bool, cost: Dictionary}
	"""
	var actions: Array = []

	if is_in_submenu():
		# Return Q/E/R from submenu
		for key in ["Q", "E", "R"]:
			if current_submenu_data.get("actions", {}).has(key):
				var action_data = current_submenu_data["actions"][key]
				actions.append({
					"key": key,
					"action": action_data.get("action", ""),
					"enabled": action_data.get("enabled", true),
					"cost": action_data.get("cost", {}),
					"label": action_data.get("label", "")
				})
	else:
		# Return tool actions (Q/E/R based on current tool)
		var ToolConfig = load("res://Core/GameState/ToolConfig.gd")
		var tool_group = ToolConfig.get_group(current_tool_group)
		var mode_index = ToolConfig.get_group_mode_index(current_tool_group)
		var modes = tool_group.get("modes", [[]])

		# Ensure mode_index is valid
		if mode_index < 0 or mode_index >= modes.size():
			return actions  # No actions available

		var tool_actions = modes[mode_index]

		# Tool actions can be either Array or String
		if tool_actions is String:
			# Single action - map to Q key
			actions.append({
				"key": "Q",
				"action": tool_actions,
				"enabled": true,
				"cost": {},
				"label": tool_actions
			})
		elif tool_actions is Array:
			# Multiple actions - map to Q/E/R
			for i in range(min(3, tool_actions.size())):
				var action_key = ["Q", "E", "R"][i]
				var action_name = tool_actions[i]
				actions.append({
					"key": action_key,
					"action": action_name,
					"enabled": true,  # TODO: Check affordability via ActionValidator
					"cost": {},       # TODO: Get from EconomyConstants
					"label": action_name
				})

	return actions


func get_state_snapshot() -> Dictionary:
	"""Get complete state for serialization/debugging.

	Returns:
		Dictionary with all state fields
	"""
	return {
		"current_biome": current_biome,
		"current_plot_idx": current_plot_idx,
		"last_selected_position": last_selected_position,
		"checked_plots": checked_plots.duplicate(),
		"current_submenu_name": current_submenu_name,
		"submenu_page": submenu_page,
		"current_tool_group": current_tool_group,
		"tool_mode_indices": tool_mode_indices.duplicate()
	}


func restore_state(snapshot: Dictionary) -> void:
	"""Restore state from snapshot."""
	current_biome = snapshot.get("current_biome", "")
	current_plot_idx = snapshot.get("current_plot_idx", -1)
	last_selected_position = snapshot.get("last_selected_position", Vector2i(-1, -1))
	checked_plots = snapshot.get("checked_plots", []).duplicate()
	current_submenu_name = snapshot.get("current_submenu_name", "")
	submenu_page = snapshot.get("submenu_page", 0)
	current_tool_group = snapshot.get("current_tool_group", 3)
	tool_mode_indices = snapshot.get("tool_mode_indices", {}).duplicate()


# ============================================================================
# PRIVATE HELPERS
# ============================================================================

func _execute_tool_action(key: String, context: Dictionary) -> Dictionary:
	"""Execute tool action (Q/E/R) based on current tool group.

	This will delegate to existing handlers in QuantumInstrumentInput
	for now. In a future phase, we can move handler logic here.
	"""
	# For now, return minimal result - QuantumInstrumentInput will handle execution
	var ToolConfig = load("res://Core/GameState/ToolConfig.gd")
	var tool_group = ToolConfig.get_group(current_tool_group)
	var mode_index = ToolConfig.get_group_mode_index(current_tool_group)
	var tool_actions = tool_group.get("modes", [[]])[mode_index]

	var action_idx = ["Q", "E", "R"].find(key)
	if action_idx < 0 or action_idx >= tool_actions.size():
		return {
			"success": false,
			"message": "No action mapped to key %s" % key,
			"action": ""
		}

	var action_name = tool_actions[action_idx]

	return {
		"success": true,
		"action": action_name,
		"message": "Tool action: %s" % action_name,
		"key": key,
		"tool_group": current_tool_group,
		"mode_index": mode_index,
		"invalidates_buffer": _is_buffer_invalidating_action(action_name)
	}


func _execute_submenu_action(key: String, context: Dictionary) -> Dictionary:
	"""Execute submenu action (Q/E/R) from current submenu.

	Returns action data for QuantumInstrumentInput to execute.
	"""
	var actions = current_submenu_data.get("actions", {})
	if not actions.has(key):
		return {
			"success": false,
			"message": "No action for key %s in submenu" % key,
			"action": ""
		}

	var action_data = actions[key]
	var action_name = action_data.get("action", "")

	if not action_data.get("enabled", true):
		return {
			"success": false,
			"message": "Action %s is disabled" % action_name,
			"action": action_name
		}

	return {
		"success": true,
		"action": action_name,
		"message": "Submenu action: %s" % action_name,
		"key": key,
		"submenu": current_submenu_name,
		"action_data": action_data,
		"invalidates_buffer": _is_buffer_invalidating_action(action_name)
	}


func _is_buffer_invalidating_action(action_name: String) -> bool:
	"""Check if action requires lookahead buffer invalidation."""
	const BUFFER_INVALIDATING_ACTIONS: Array[String] = [
		# Tool 1: Unitary gates
		"rotate_up", "rotate_down", "hadamard",
		# Tool 2: Lindbladian
		"drain", "transfer", "pump",
		# Tool 3: Measure
		"measure", "build_gate", "remove_gates",
		# Tool 4: Meta
		"inject_vocabulary", "remove_vocabulary", "vocab_inject"
	]

	return action_name in BUFFER_INVALIDATING_ACTIONS
