class_name UIContextController
extends Node

## UIContextController
##
## Single authority for bottom-bar context projection.
## It watches the live gameplay/tool state plus the overlay stack and decides
## what the tool row and action row should display.

const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")
const ActionCostRuntime = preload("res://Core/GameMechanics/ActionCostRuntime.gd")
const GridSentinel = preload("res://Core/GameState/GridSentinel.gd")

var action_bar_manager = null
var overlay_stack = null
var overlay_manager = null
var quantum_input = null
var current_farm_ui: Control = null
var current_tool: int = ToolConfig.get_current_group()
var current_submenu_name: String = ""
var current_submenu_actions: Dictionary = {}
var _observed_overlays: Array = []
const ACTION_KEYS = ["Q", "E", "R", "F"]


func setup(action_bar_mgr, stack_mgr, overlay_mgr = null) -> void:
	action_bar_manager = action_bar_mgr
	overlay_stack = stack_mgr
	if overlay_stack and overlay_stack.has_signal("stack_changed"):
		if not overlay_stack.stack_changed.is_connected(refresh):
			overlay_stack.stack_changed.connect(refresh)

	_connect_toolbar_inputs()
	if overlay_mgr:
		bind_overlay_manager(overlay_mgr)

	refresh()


func reset() -> void:
	"""Reset runtime UI context references for shutdown or restart."""
	if overlay_stack and overlay_stack.has_signal("stack_changed") and overlay_stack.stack_changed.is_connected(refresh):
		overlay_stack.stack_changed.disconnect(refresh)
	action_bar_manager = null
	overlay_stack = null
	overlay_manager = null
	quantum_input = null
	current_farm_ui = null
	current_tool = ToolConfig.get_current_group()
	current_submenu_name = ""
	current_submenu_actions.clear()
	_observed_overlays.clear()


func bind_overlay_manager(manager) -> void:
	overlay_manager = manager
	if not overlay_manager or not overlay_manager.has_method("get_registered_overlays"):
		return

	for overlay_name in overlay_manager.get_registered_overlays():
		_observe_overlay(overlay_manager.get_overlay(overlay_name))


func bind_quantum_input(input_handler) -> void:
	if quantum_input == input_handler or not input_handler:
		return

	quantum_input = input_handler
	current_tool = _resolve_current_tool()

	if quantum_input.has_signal("tool_group_changed"):
		if not quantum_input.tool_group_changed.is_connected(_on_tool_group_changed):
			quantum_input.tool_group_changed.connect(_on_tool_group_changed)

	if quantum_input.has_signal("mode_cycled"):
		if not quantum_input.mode_cycled.is_connected(_on_mode_cycled):
			quantum_input.mode_cycled.connect(_on_mode_cycled)

	if quantum_input.has_signal("submenu_changed"):
		if not quantum_input.submenu_changed.is_connected(_on_submenu_changed):
			quantum_input.submenu_changed.connect(_on_submenu_changed)

	if quantum_input.has_signal("action_performed"):
		if not quantum_input.action_performed.is_connected(_on_action_performed):
			quantum_input.action_performed.connect(_on_action_performed)

	refresh()


func bind_farm_ui(farm_ui: Control) -> void:
	current_farm_ui = farm_ui
	if not current_farm_ui or not action_bar_manager:
		return

	var farm = current_farm_ui.farm if "farm" in current_farm_ui else null
	var plot_grid = current_farm_ui.plot_grid_display if "plot_grid_display" in current_farm_ui else null

	if plot_grid and plot_grid.has_signal("selection_count_changed"):
		if not plot_grid.selection_count_changed.is_connected(_on_selection_count_changed):
			plot_grid.selection_count_changed.connect(_on_selection_count_changed)

	if farm and farm.economy and farm.economy.has_signal("resource_changed"):
		if not farm.economy.resource_changed.is_connected(_on_resource_changed):
			farm.economy.resource_changed.connect(_on_resource_changed)

	refresh()


func refresh() -> void:
	if not action_bar_manager:
		return

	action_bar_manager.select_tool(current_tool)
	action_bar_manager.render_action_projection(_build_action_projection())


func _connect_toolbar_inputs() -> void:
	if not action_bar_manager:
		return

	var tool_row = action_bar_manager.get_tool_row()
	if tool_row and tool_row.has_signal("tool_selected"):
		if not tool_row.tool_selected.is_connected(_on_tool_selected):
			tool_row.tool_selected.connect(_on_tool_selected)

	var action_row = action_bar_manager.get_action_row()
	if action_row and action_row.has_signal("action_pressed"):
		if not action_row.action_pressed.is_connected(_on_action_pressed):
			action_row.action_pressed.connect(_on_action_pressed)


func _observe_overlay(overlay) -> void:
	if not overlay or overlay in _observed_overlays:
		return

	_observed_overlays.append(overlay)

	if overlay.has_signal("selection_changed"):
		if not overlay.selection_changed.is_connected(_refresh_from_overlay_signal):
			overlay.selection_changed.connect(_refresh_from_overlay_signal)

	if overlay.has_signal("action_performed"):
		if not overlay.action_performed.is_connected(_refresh_from_overlay_signal):
			overlay.action_performed.connect(_refresh_from_overlay_signal)

	if overlay.has_signal("slot_selection_changed"):
		if not overlay.slot_selection_changed.is_connected(_refresh_from_overlay_signal):
			overlay.slot_selection_changed.connect(_refresh_from_overlay_signal)


func _refresh_action_availability() -> void:
	refresh()


func _resolve_current_tool() -> int:
	if quantum_input and quantum_input.has_method("get_current_tool_group"):
		return quantum_input.get_current_tool_group()
	return ToolConfig.get_current_group()


func _on_tool_selected(tool_num: int) -> void:
	ToolConfig.select_group(tool_num)
	current_tool = tool_num

	if current_farm_ui and current_farm_ui.has_method("_on_tool_selected"):
		current_farm_ui._on_tool_selected(tool_num)

	if quantum_input and quantum_input.has_signal("tool_group_changed"):
		quantum_input.tool_group_changed.emit(tool_num)
	else:
		current_submenu_name = ""
		current_submenu_actions = {}
		refresh()


func _on_action_pressed(action_key: String) -> void:
	if not quantum_input:
		return

	if action_key == "F":
		if quantum_input.has_method("_cycle_submenu_page") and quantum_input.is_in_submenu():
			quantum_input._cycle_submenu_page()
		elif quantum_input.has_method("_cycle_mode"):
			quantum_input._cycle_mode()
		elif quantum_input.has_method("_perform_action"):
			quantum_input._perform_action(action_key)
		return

	if quantum_input.has_method("_perform_action"):
		quantum_input._perform_action(action_key)


func _on_tool_group_changed(group: int) -> void:
	current_tool = group
	current_submenu_name = ""
	current_submenu_actions = {}
	refresh()


func _on_mode_cycled(_group: int, _mode_idx: int, _mode_label: String) -> void:
	current_tool = _resolve_current_tool()
	refresh()


func _on_submenu_changed(submenu_name: String, submenu_actions: Dictionary) -> void:
	current_submenu_name = submenu_name
	current_submenu_actions = submenu_actions
	refresh()


func _on_action_performed(_action: String, _result: Dictionary) -> void:
	refresh()


func _on_selection_count_changed(_count: int) -> void:
	_refresh_action_availability()


func _on_resource_changed(_emoji, _amount) -> void:
	_refresh_action_availability()


func _refresh_from_overlay_signal(_a = null, _b = null) -> void:
	refresh()


func _build_action_projection() -> Dictionary:
	var projection := {
		"context": "tool",
		"tool": current_tool,
		"submenu_name": "",
		"actions": {}
	}

	var top_overlay = overlay_stack.get_top() if overlay_stack else null
	if top_overlay:
		projection.context = "overlay"
		projection.actions = _build_overlay_actions(top_overlay)
		return projection

	if current_submenu_name != "":
		projection.context = "submenu"
		projection.submenu_name = current_submenu_name
		projection.actions = _build_submenu_actions()
		return projection

	projection.actions = _build_tool_actions(current_tool)
	return projection


func _build_tool_actions(tool_num: int) -> Dictionary:
	var actions: Dictionary = {}
	for action_key in ACTION_KEYS:
		var action_info = ToolConfig.get_action(tool_num, action_key)
		actions[action_key] = _project_action_info(action_info)

	if tool_num == 3 and ToolConfig.get_group_mode_name(tool_num) == "probe":
		_apply_probe_preview(actions)

	_apply_runtime_state(actions)
	return actions


func _build_submenu_actions() -> Dictionary:
	var actions: Dictionary = {}
	var submenu_disabled = current_submenu_actions.get("_disabled", false)
	var submenu_availability = current_submenu_actions.get("_availability", {})

	for action_key in ACTION_KEYS:
		var action_info = current_submenu_actions.get(action_key, {})
		var projected = _project_action_info(action_info)
		var action_name = str(projected.get("action", ""))
		var available = submenu_availability.get(action_key, true)
		projected.disabled = bool(projected.get("disabled", false)) or submenu_disabled or action_name == "" or not available
		actions[action_key] = projected

	_apply_runtime_state(actions)
	return actions


func _build_overlay_actions(overlay: Control) -> Dictionary:
	var actions: Dictionary = {}
	for action_key in ACTION_KEYS:
		var info: Dictionary = {}
		if overlay.has_method("get_action_info"):
			info = overlay.get_action_info(action_key)
		elif overlay.has_method("get_action_labels"):
			var labels = overlay.get_action_labels()
			info = {
				"label": str(labels.get(action_key, "-")),
				"emoji": "",
				"icon": "",
				"disabled": false,
				"action": ""
			}
		actions[action_key] = _project_action_info(info)
		actions[action_key].available = not bool(actions[action_key].get("disabled", false))
	return actions


func _project_action_info(action_info: Dictionary) -> Dictionary:
	return {
		"action": str(action_info.get("action", "")),
		"label": str(action_info.get("label", "-")),
		"emoji": str(action_info.get("emoji", "")),
		"icon": str(action_info.get("icon", "")),
		"disabled": bool(action_info.get("disabled", false)),
		"available": false,
		"cost": {},
		"shift_label": str(action_info.get("shift_label", "")),
		"shift_action": str(action_info.get("shift_action", "")),
		"vocab_pair": action_info.get("vocab_pair", {}),
	}


func _apply_runtime_state(actions: Dictionary) -> void:
	var runtime_availability = _resolve_runtime_availability()
	for action_key in ACTION_KEYS:
		if not actions.has(action_key):
			continue
		var action_info: Dictionary = actions[action_key]
		if bool(action_info.get("disabled", false)):
			action_info.available = false
			action_info.cost = {}
			continue

		if action_key == "F":
			action_info.available = true
		else:
			action_info.available = runtime_availability.get(action_key, false)
		action_info.cost = _get_cost_for_action(action_info)
		actions[action_key] = action_info


func _resolve_runtime_availability() -> Dictionary:
	var availability := {"Q": false, "E": false, "R": false, "F": true}
	if quantum_input and quantum_input.has_method("can_execute_action"):
		availability.Q = quantum_input.can_execute_action("Q")
		availability.E = quantum_input.can_execute_action("E")
		availability.R = quantum_input.can_execute_action("R")
		return availability

	if quantum_input and quantum_input.has_method("get_current_selection"):
		var selection = quantum_input.get_current_selection()
		var has_selection = int(selection.get("plot_idx", -1)) >= 0
		availability.Q = has_selection
		availability.E = has_selection
		availability.R = has_selection
		return availability

	return availability


func _apply_probe_preview(actions: Dictionary) -> void:
	var farm = _get_farm()
	var plot_grid = _get_plot_grid()
	if not farm or not farm.terminal_pool or not plot_grid or not plot_grid.has_method("get_selected_plots"):
		return

	var selected = plot_grid.get_selected_plots()
	if selected.is_empty() or not farm.grid:
		return

	var biome = farm.grid.get_biome_for_plot(selected[0])
	if not biome:
		return

	var explore_preview = ProbeActions.get_explore_preview(farm.terminal_pool, biome)
	if explore_preview.can_explore and not explore_preview.top_probabilities.is_empty() and actions.has("Q"):
		var top = explore_preview.top_probabilities[0]
		actions["Q"].label = "Explore (%s %.0f%%)" % [top.get("emoji", "?"), top.get("probability", 0.0) * 100.0]
		actions["Q"].emoji = "🔍"
		actions["Q"].icon = ""

	var biome_name = biome.get_biome_type() if biome.has_method("get_biome_type") else ""
	var active_terminals = []
	for terminal in farm.terminal_pool.get_active_terminals():
		if terminal.bound_biome_name == biome_name:
			active_terminals.append(terminal)
	if not active_terminals.is_empty() and actions.has("E"):
		var active_terminal = active_terminals[0]
		actions["E"].label = "Measure (%s)" % str(active_terminal.north_emoji if active_terminal.north_emoji else "?")
		actions["E"].emoji = "👁️"
		actions["E"].icon = ""

	var measured_terminals = []
	for terminal in farm.terminal_pool.get_measured_terminals():
		if terminal.bound_biome_name == biome_name:
			measured_terminals.append(terminal)
	if not measured_terminals.is_empty() and actions.has("R"):
		var measured_terminal = measured_terminals[0]
		actions["R"].label = "Pop (%s)" % str(measured_terminal.measured_outcome if measured_terminal.measured_outcome else "?")
		actions["R"].emoji = "✂️"
		actions["R"].icon = ""


func _get_cost_for_action(action_info: Dictionary) -> Dictionary:
	var action_name = str(action_info.get("action", ""))
	if action_name == "":
		return {}

	var shift_action = str(action_info.get("shift_action", ""))
	if shift_action != "":
		return _get_cost_for_action_name(shift_action, action_info)
	return _get_cost_for_action_name(action_name, action_info)


func _get_cost_for_action_name(action_name: String, action_info: Dictionary) -> Dictionary:
	match action_name:
		"inject_vocabulary":
			var pair = action_info.get("vocab_pair", {})
			return _get_runtime_action_cost(action_name, {"south_emoji": pair.get("south", "")})
		"drain", "pump":
			var pair = _resolve_selected_axis_pair()
			if pair.is_empty():
				return {}
			var normalized = "lindblad_drain" if action_name == "drain" else "lindblad_pump"
			return _get_runtime_action_cost(normalized, {
				"north_emoji": str(pair.get("north", "")),
				"south_emoji": str(pair.get("south", ""))
			})
		_:
			return _get_runtime_action_cost(action_name)


func _get_runtime_action_cost(action_name: String, context: Dictionary = {}) -> Dictionary:
	var instrument = quantum_input._instrument if quantum_input and "_instrument" in quantum_input else null
	if instrument and instrument.has_method("get_action_cost"):
		return instrument.get_action_cost(action_name, context)
	var farm = _get_farm()
	return ActionCostRuntime.get_action_cost(farm, action_name, context)


func _resolve_selected_axis_pair() -> Dictionary:
	var farm = _get_farm()
	var plot_grid = _get_plot_grid()
	if not farm:
		return {}

	var selected: Array = []
	if plot_grid and plot_grid.has_method("get_selected_plots"):
		selected = plot_grid.get_selected_plots()

	var pos := GridSentinel.INVALID_POSITION
	if selected.is_empty():
		if quantum_input and quantum_input.has_method("get_current_selection") and farm.has_method("get_biome_row"):
			var selection = quantum_input.get_current_selection()
			var plot_idx = int(selection.get("plot_idx", -1))
			var biome_name = str(selection.get("biome", ""))
			if plot_idx >= 0:
				pos = Vector2i(plot_idx, farm.get_biome_row(biome_name))
	else:
		pos = selected[0]

	if pos.x < 0 or not farm.grid:
		return {}

	var plot = farm.grid.get_plot(pos)
	if plot and plot.is_active():
		var north = str(plot.north_emoji if plot.north_emoji else "")
		if north == "":
			return {}
		var south = str(plot.south_emoji if plot.south_emoji else "")
		if south == "":
			var biome = farm.grid.get_biome_for_plot(pos)
			if biome and biome.viz_cache and biome.viz_cache.has_metadata():
				var q = biome.viz_cache.get_qubit(north)
				if q >= 0:
					var axis = biome.viz_cache.get_axis(q)
					if axis is Dictionary:
						south = str(axis.get("south", ""))
		return {"north": north, "south": south}

	return {}


func _get_farm():
	return current_farm_ui.farm if current_farm_ui and "farm" in current_farm_ui else null


func _get_plot_grid():
	return current_farm_ui.plot_grid_display if current_farm_ui and "plot_grid_display" in current_farm_ui else null
