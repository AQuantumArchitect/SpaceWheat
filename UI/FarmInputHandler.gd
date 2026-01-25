class_name FarmInputHandler
extends Node

## INPUT CONTRACT (Layer 2 - Tool/Action System)
## ═══════════════════════════════════════════════════════════════
## PHASE: _input() - Runs after InputController
## HANDLES: InputEventKey via input actions
## ACTIONS: tool_1-6, action_q/e/r, select_plot_*, move_*, toggle_help
## CONSUMES: Always for handled actions (via get_viewport().set_input_as_handled())
## EMITS: tool_changed, submenu_changed, action_performed
## REQUIRES: GridConfig injection for plot selection
## ═══════════════════════════════════════════════════════════════
##
## v2 REFACTORED: Uses facade pattern with handler delegation
## - SelectionManager: cursor and multi-select
## - SubmenuManager: submenu state machine
## - ActionValidator: can_execute checks
## - ActionDispatcher: action routing to handlers

# Preloads
const GridConfig = preload("res://Core/GameState/GridConfig.gd")
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const QuantumMill = preload("res://Core/GameMechanics/QuantumMill.gd")

# Manager preloads
const SelectionManager = preload("res://UI/Core/SelectionManager.gd")
const SubmenuManager = preload("res://UI/Core/SubmenuManager.gd")
const ActionValidator = preload("res://UI/Core/ActionValidator.gd")
const ActionDispatcher = preload("res://UI/Core/ActionDispatcher.gd")

# Tool actions from shared config (single source of truth)
const TOOL_ACTIONS = ToolConfig.TOOL_ACTIONS

# Access autoload safely
@onready var _verbose = get_node("/root/VerboseConfig")

# Core state
var farm  # Farm instance (untyped for dynamic script attachment)
var _plot_grid_display: Node = null  # PlotGridDisplay reference (internal)
var grid_config: GridConfig = null
var current_tool: int = 1  # Active tool (1-4)

# Property wrapper for plot_grid_display injection
var plot_grid_display: Node:
	get: return _plot_grid_display
	set(value):
		_plot_grid_display = value
		if _selection:
			_selection.inject_plot_grid_display(value)

# Managers
var _selection: SelectionManager
var _submenu: SubmenuManager
var _dispatcher: ActionDispatcher

# Mill two-stage state (passed to IndustryHandler)
var _mill_state: Dictionary = {}

# v2 Architecture State
var evolution_paused: bool = false

# Grid dimensions (fallback)
var grid_width: int = 6
var grid_height: int = 4

# Debug
const VERBOSE = true

# Signals (API compatibility maintained)
signal action_performed(action: String, success: bool, message: String)
signal selection_changed(new_pos: Vector2i)
signal plot_selected(pos: Vector2i)
signal tool_changed(tool_num: int, tool_info: Dictionary)
signal submenu_changed(submenu_name: String, submenu_info: Dictionary)
signal help_requested
signal mode_changed(new_mode: String)
signal pause_toggled(is_paused: bool)
signal tool_mode_cycled(tool_num: int, new_mode_index: int, mode_label: String)


## ============================================================================
## LIFECYCLE
## ============================================================================

func _ready():
	# Initialize managers
	_selection = SelectionManager.new()
	_submenu = SubmenuManager.new()
	_dispatcher = ActionDispatcher.new()

	# Wire manager signals
	_selection.selection_changed.connect(_on_selection_changed)
	_submenu.submenu_changed.connect(_on_submenu_changed)
	_dispatcher.action_completed.connect(_on_action_completed)

	_verbose.info("input", "⌨️", "FarmInputHandler initialized (Facade Pattern)")
	set_process_unhandled_input(true)

	_connect_to_biome_manager()
	_print_help()


func _connect_to_biome_manager() -> void:
	"""Connect to ActiveBiomeManager for biome change handling."""
	var biome_mgr = get_node_or_null("/root/ActiveBiomeManager")
	if biome_mgr and biome_mgr.has_signal("active_biome_changed"):
		if not biome_mgr.active_biome_changed.is_connected(_on_active_biome_changed):
			biome_mgr.active_biome_changed.connect(_on_active_biome_changed)


func _on_active_biome_changed(new_biome: String, _old_biome: String) -> void:
	"""Reset cursor and selection when biome changes."""
	_selection.on_biome_changed(farm)
	if _submenu.is_in_submenu():
		_submenu.exit_submenu()


## ============================================================================
## INJECTION
## ============================================================================

func inject_grid_config(config: GridConfig) -> void:
	"""Inject GridConfig for dynamic grid-aware input handling."""
	if not config:
		push_error("FarmInputHandler: Attempted to inject null GridConfig!")
		return

	grid_config = config
	grid_width = config.grid_width
	grid_height = config.grid_height

	_selection.inject_grid_config(config)
	_verbose.info("input", "💉", "GridConfig injected (%dx%d)" % [grid_width, grid_height])


## ============================================================================
## MANAGER SIGNAL HANDLERS
## ============================================================================

func _on_selection_changed(new_pos: Vector2i) -> void:
	"""Forward selection change from manager."""
	selection_changed.emit(new_pos)
	_submenu.refresh_dynamic_submenu(farm, new_pos)


func _on_submenu_changed(name: String, info: Dictionary) -> void:
	"""Forward submenu change from manager."""
	submenu_changed.emit(name, info)
	if name == "":
		# Exited submenu, re-emit tool info
		tool_changed.emit(current_tool, TOOL_ACTIONS[current_tool])


func _on_action_completed(action: String, success: bool, message: String, _result: Dictionary) -> void:
	"""Forward action completion from dispatcher."""
	action_performed.emit(action, success, message)


## ============================================================================
## INPUT HANDLING
## ============================================================================

func _unhandled_input(event: InputEvent):
	"""Handle gameplay input via InputMap actions (Layer 3 - Low Priority)."""
	if VERBOSE and event is InputEventKey and event.pressed:
		_verbose.debug("input", "🔑", "KEY: %s" % event.keycode)

	# v2 GLOBAL CONTROLS
	if event.is_action_pressed("pause"):
		_toggle_evolution_pause()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		_execute_action("harvest_global")
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("toggle_mode"):
		_toggle_build_play_mode()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("action_f"):
		_cycle_current_tool_mode()
		get_viewport().set_input_as_handled()
		return

	# Tool selection (1-6)
	for i in range(1, 7):
		if event.is_action_pressed("tool_" + str(i)):
			_select_tool(i)
			get_viewport().set_input_as_handled()
			return

	# Location quick-select
	if grid_config:
		for action in grid_config.keyboard_layout.get_all_actions():
			if event.is_action_pressed(action):
				var base_pos = grid_config.keyboard_layout.get_position_for_action(action)
				if base_pos != Vector2i(-1, -1):
					var pos = base_pos
					if farm and farm.has_method("get_plot_position_for_active_biome"):
						pos = farm.get_plot_position_for_active_biome(base_pos.x)
					if grid_config.is_position_valid(pos):
						_selection.toggle_plot_selection(pos)
						get_viewport().set_input_as_handled()
						return
	else:
		var default_plot_indices = {
			"select_plot_t": 0, "select_plot_y": 1, "select_plot_u": 2,
			"select_plot_i": 3, "select_plot_o": 4, "select_plot_p": 5,
		}
		for action in default_plot_indices.keys():
			if event.is_action_pressed(action):
				var plot_index = default_plot_indices[action]
				var pos = Vector2i(plot_index, 0)
				if farm and farm.has_method("get_plot_position_for_active_biome"):
					pos = farm.get_plot_position_for_active_biome(plot_index)
				_selection.toggle_plot_selection(pos)
				get_viewport().set_input_as_handled()
				return

	# Selection management: [ = clear, ] = select all
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_BRACKETLEFT:
			_selection.clear_all_selection()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_BRACKETRIGHT:
			_selection.select_all_plots()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_BACKSPACE:
			if current_tool == 5 and not _submenu.is_in_submenu():
				_execute_action("remove_gates")
				get_viewport().set_input_as_handled()
				return

		# Biome selection (7890, ,.)
		var biome_mgr = get_node_or_null("/root/ActiveBiomeManager")
		if biome_mgr:
			if biome_mgr.select_biome_by_key(event.keycode):
				get_viewport().set_input_as_handled()
				return
			if biome_mgr.handle_cycle_input(event.keycode):
				get_viewport().set_input_as_handled()
				return

	# Movement (WASD)
	if event.is_action_pressed("move_up"):
		_selection.move_selection(Vector2i.UP)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("move_down"):
		_selection.move_selection(Vector2i.DOWN)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("move_left"):
		_selection.move_selection(Vector2i.LEFT)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("move_right"):
		_selection.move_selection(Vector2i.RIGHT)
		get_viewport().set_input_as_handled()
		return

	# Action keys (Q/E/R)
	if event is InputEventKey and event.pressed:
		var action_key = ""
		match event.keycode:
			KEY_Q: action_key = "Q"
			KEY_E: action_key = "E"
			KEY_R: action_key = "R"
		if action_key != "":
			_execute_tool_action(action_key)
			get_viewport().set_input_as_handled()
			return

	# Gamepad support
	if event.is_action_pressed("action_q"):
		_execute_tool_action("Q")
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("action_e"):
		_execute_tool_action("E")
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("action_r"):
		_execute_tool_action("R")
		get_viewport().set_input_as_handled()
		return

	# Help
	if event.is_action_pressed("toggle_help"):
		_print_help()
		get_viewport().set_input_as_handled()
		return


## ============================================================================
## TOOL MANAGEMENT
## ============================================================================

func _select_tool(tool_num: int):
	"""Select active tool (1-4)."""
	if not TOOL_ACTIONS.has(tool_num):
		return

	if _submenu.is_in_submenu():
		_submenu.exit_submenu()

	current_tool = tool_num
	var tool_info = TOOL_ACTIONS[tool_num]
	_verbose.info("input", "🛠️", "Tool: %s" % tool_info["name"])
	tool_changed.emit(tool_num, tool_info)


## ============================================================================
## ACTION EXECUTION
## ============================================================================

func _execute_tool_action(action_key: String):
	"""Execute the action mapped to Q/E/R for current tool or submenu."""
	if not farm:
		push_error("Farm not set!")
		return

	# Handle submenu actions
	if _submenu.is_in_submenu():
		_execute_submenu_action(action_key)
		return

	# Get action info
	var action_info = ToolConfig.get_action(current_tool, action_key)
	if action_info.is_empty():
		return

	var action = action_info.get("action", "")
	if action == "":
		return

	# Check if opens submenu
	if action_info.has("submenu"):
		var menu_pos = _selection.get_selected_plots()[0] if _selection.get_selection_count() > 0 else _selection.get_cursor_position()
		_submenu.enter_submenu(action_info["submenu"], farm, menu_pos)
		return

	# Execute action
	_execute_action(action)


func _execute_submenu_action(action_key: String):
	"""Execute action from current submenu."""
	if _submenu.is_submenu_disabled():
		action_performed.emit("disabled", false, "Submenu disabled")
		return

	if _submenu.is_action_locked(action_key):
		action_performed.emit("locked", false, "Action locked")
		return

	var action = _submenu.get_action_name_for_key(action_key)
	var selected_plots = _selection.get_selected_plots()

	if selected_plots.is_empty():
		action_performed.emit(action, false, "No plots selected")
		return

	# Route based on action type
	if action.begins_with("plant_"):
		var plant_type = action.replace("plant_", "")
		_dispatcher.execute_plant(farm, plant_type, selected_plots)
	elif action.begins_with("place_"):
		var build_type = action.replace("place_", "")
		if build_type == "kitchen":
			_dispatcher.execute("place_kitchen", farm, selected_plots, {})
		else:
			_dispatcher.execute_build(farm, build_type, selected_plots)
	elif action.begins_with("assign_to_"):
		var biome_name = action.replace("assign_to_", "")
		_dispatcher.execute_assign_biome(farm, biome_name, selected_plots)
	elif action.begins_with("icon_assign_"):
		var emoji = _extract_emoji_from_submenu(action)
		var gsm = get_node_or_null("/root/GameStateManager")
		_dispatcher.execute_icon_assign(farm, emoji, selected_plots, gsm)
	elif action.begins_with("mill_select_power_"):
		var power_key = _get_power_key_from_action(action)
		var result = _dispatcher.execute_mill_select_power(farm, power_key, selected_plots, _mill_state)
		if result.success:
			_submenu.enter_mill_conversion_submenu(farm, selected_plots[0])
			return  # Don't exit submenu
	elif action.begins_with("mill_convert_"):
		var conv_key = _get_conversion_key_from_action(action)
		_dispatcher.execute_mill_convert(farm, conv_key, selected_plots, _mill_state)
	else:
		# Standard dispatch table action
		_execute_action(action)

	# Exit submenu after action (unless mill stage 1)
	_submenu.exit_submenu()


func _execute_action(action: String):
	"""Execute action via dispatcher."""
	var selected_plots = _selection.get_selected_plots()
	var extra = {
		"current_selection": _selection.get_cursor_position(),
		"mill_state": _mill_state,
		"game_state_manager": get_node_or_null("/root/GameStateManager")
	}

	# Special handling for probe actions that need terminal signals
	match action:
		"explore":
			_execute_explore(selected_plots)
		"measure":
			_execute_measure(selected_plots)
		"pop":
			_execute_pop(selected_plots)
		"harvest_global":
			_execute_harvest_global()
		"inspect_plot":
			_execute_inspect_plot(selected_plots)
		_:
			_dispatcher.execute(action, farm, selected_plots, extra)


## ============================================================================
## PROBE ACTIONS (with signal emission)
## ============================================================================

func _execute_explore(positions: Array[Vector2i]):
	"""Execute EXPLORE with terminal signal emission."""
	if not farm or not farm.plot_pool:
		action_performed.emit("explore", false, "Farm not ready")
		return

	const ProbeHandler = preload("res://UI/Handlers/ProbeHandler.gd")
	var result = ProbeHandler.explore(farm, farm.plot_pool, positions)

	if result.success:
		for r in result.results:
			farm.terminal_bound.emit(r.position, r.terminal_id, r.emoji_pair)
		action_performed.emit("explore", true, "Discovered %d registers" % result.explored_count)
	else:
		action_performed.emit("explore", false, result.get("message", "No terminals available"))


func _execute_measure(positions: Array[Vector2i]):
	"""Execute MEASURE with terminal signal emission."""
	if not farm or not farm.plot_pool:
		action_performed.emit("measure", false, "Farm not ready")
		return

	const ProbeHandler = preload("res://UI/Handlers/ProbeHandler.gd")
	var result = ProbeHandler.measure(farm, farm.plot_pool, positions)

	if result.success:
		for r in result.results:
			farm.terminal_measured.emit(r.position, r.terminal_id, r.outcome, r.probability)
		var outcomes_str = ", ".join(result.outcomes) if result.measured_count <= 3 else "%d terminals" % result.measured_count
		action_performed.emit("measure", true, "Measured %s" % outcomes_str)
	else:
		action_performed.emit("measure", false, "No terminals to measure")


func _execute_pop(positions: Array[Vector2i]):
	"""Execute POP with terminal signal emission."""
	if not farm or not farm.plot_pool:
		action_performed.emit("pop", false, "Farm not ready")
		return

	const ProbeHandler = preload("res://UI/Handlers/ProbeHandler.gd")
	var result = ProbeHandler.pop(farm, farm.plot_pool, farm.economy, positions)

	if result.success:
		for r in result.results:
			farm.terminal_released.emit(r.position, r.terminal_id, r.credits)
		var resources_str = ", ".join(result.resources) if result.popped_count <= 3 else "%d terminals" % result.popped_count
		action_performed.emit("pop", true, "Harvested %s (+%d credits)" % [resources_str, int(result.total_credits)])
	else:
		action_performed.emit("pop", false, "No terminals to harvest")


func _execute_harvest_global():
	"""Execute HARVEST with level complete signal."""
	if not farm or not farm.plot_pool:
		action_performed.emit("harvest_global", false, "Farm not ready")
		return

	const ProbeHandler = preload("res://UI/Handlers/ProbeHandler.gd")
	var result = ProbeHandler.harvest_global(farm, _selection.get_cursor_position())

	if result.success:
		action_performed.emit("harvest_global", true, "HARVESTED: %.0f credits!" % result.total_credits)
		if farm.has_signal("level_complete"):
			farm.level_complete.emit(result)
	else:
		action_performed.emit("harvest_global", false, result.get("message", "Harvest failed"))


func _execute_inspect_plot(positions: Array[Vector2i]):
	"""Execute INSPECT with overlay opening."""
	const BiomeHandler = preload("res://UI/Handlers/BiomeHandler.gd")
	var result = BiomeHandler.inspect_plot(farm, positions)

	if result.success and not positions.is_empty():
		var biome_name = farm.grid.plot_biome_assignments.get(positions[0], "")
		if biome_name != "" and biome_name != "(unassigned)":
			var overlay_manager = _get_overlay_manager()
			if overlay_manager and overlay_manager.biome_inspector:
				overlay_manager.biome_inspector.inspect_plot_biome(positions[0], farm)

	action_performed.emit("inspect_plot", result.success, "Inspected %d plots" % result.count)


## ============================================================================
## VALIDATION (PUBLIC API)
## ============================================================================

func can_execute_action(action_key: String) -> bool:
	"""Check if action can succeed with current selection."""
	var selected_plots = _selection.get_selected_plots()
	return ActionValidator.can_execute_action(
		action_key,
		current_tool,
		_submenu.get_current_submenu_name(),
		_submenu.get_current_submenu(),
		farm,
		selected_plots,
		_selection.get_cursor_position()
	)


## ============================================================================
## PUBLIC API (backward compatibility)
## ============================================================================

var current_selection: Vector2i:
	get: return _selection.get_cursor_position() if _selection else Vector2i.ZERO
	set(value):
		if _selection:
			_selection.set_selection(value)

var current_submenu: String:
	get: return _submenu.get_current_submenu_name() if _submenu else ""

func execute_action(action_key: String) -> void:
	"""PUBLIC: Execute action for key."""
	_execute_tool_action(action_key)

func get_current_actions() -> Dictionary:
	"""Get current QER actions (from submenu or tool)."""
	if _submenu and _submenu.is_in_submenu():
		var submenu = _submenu.get_current_submenu()
		return {
			"Q": submenu.get("Q", {}),
			"E": submenu.get("E", {}),
			"R": submenu.get("R", {}),
			"is_submenu": true,
			"submenu_name": _submenu.get_current_submenu_name(),
		}
	else:
		var tool = TOOL_ACTIONS.get(current_tool, {})
		return {
			"Q": tool.get("Q", {}),
			"E": tool.get("E", {}),
			"R": tool.get("R", {}),
			"is_submenu": false,
			"tool_name": tool.get("name", ""),
		}


## ============================================================================
## v2 GLOBAL CONTROLS
## ============================================================================

func _toggle_evolution_pause() -> void:
	"""Toggle quantum evolution pause state."""
	evolution_paused = not evolution_paused
	if farm and farm.grid and farm.grid.biomes:
		for biome_name in farm.grid.biomes:
			var biome = farm.grid.biomes[biome_name]
			if biome and biome.has_method("set_evolution_paused"):
				biome.set_evolution_paused(evolution_paused)

	var status = "PAUSED" if evolution_paused else "RUNNING"
	pause_toggled.emit(evolution_paused)
	action_performed.emit("toggle_pause", true, "Evolution %s" % status.to_lower())


func _toggle_build_play_mode() -> void:
	"""Toggle between BUILD and PLAY modes."""
	var new_mode = ToolConfig.toggle_mode()
	current_tool = 1
	_submenu.reset()

	var is_build_mode = (new_mode == "build")
	_set_all_biomes_paused(is_build_mode)

	mode_changed.emit(new_mode)
	var tool_info = ToolConfig.get_tool(current_tool)
	tool_changed.emit(current_tool, tool_info)
	action_performed.emit("toggle_mode", true, "%s mode" % new_mode.capitalize())


func _cycle_current_tool_mode() -> void:
	"""Cycle F-mode for current tool."""
	if not ToolConfig.has_f_cycling(current_tool):
		action_performed.emit("cycle_mode", false, "No modes")
		return

	var new_index = ToolConfig.cycle_tool_mode(current_tool)
	if new_index < 0:
		return

	var mode_label = ToolConfig.get_tool_mode_label(current_tool)
	var tool_name = ToolConfig.get_tool_name(current_tool)

	tool_mode_cycled.emit(current_tool, new_index, mode_label)
	var tool_info = ToolConfig.get_tool(current_tool)
	tool_changed.emit(current_tool, tool_info)
	action_performed.emit("cycle_mode", true, "%s: %s" % [tool_name, mode_label])


func is_evolution_paused() -> bool:
	return evolution_paused

func get_current_game_mode() -> String:
	return ToolConfig.get_mode()

func _set_all_biomes_paused(paused: bool) -> void:
	if not farm or not farm.grid or not farm.grid.biomes:
		return
	for biome_name in farm.grid.biomes:
		var biome = farm.grid.biomes[biome_name]
		if biome and biome.has_method("set_evolution_paused"):
			biome.set_evolution_paused(paused)


## ============================================================================
## HELPERS
## ============================================================================

func _extract_emoji_from_submenu(action: String) -> String:
	"""Extract emoji from cached submenu action."""
	var submenu = _submenu.get_current_submenu()
	for key in ["Q", "E", "R"]:
		if submenu.has(key):
			var info = submenu[key]
			if info.get("action", "") == action:
				return info.get("emoji", "")
	return ""


func _get_power_key_from_action(action: String) -> String:
	if action.ends_with("water"): return "Q"
	if action.ends_with("wind"): return "E"
	if action.ends_with("fire"): return "R"
	return ""


func _get_conversion_key_from_action(action: String) -> String:
	if action.ends_with("flour"): return "Q"
	if action.ends_with("lumber"): return "E"
	if action.ends_with("energy"): return "R"
	return ""


func _get_overlay_manager():
	"""Navigate scene tree to find OverlayManager."""
	var current = self
	while current:
		if current.name == "PlayerShell" or current.name.contains("Shell"):
			if current.has_node("OverlayManager"):
				return current.get_node("OverlayManager")
			elif current.get("overlay_manager"):
				return current.get("overlay_manager")
		current = current.get_parent()
	return null


func _print_help():
	"""Print keyboard help."""
	var line = "=".repeat(60)
	_verbose.info("input", "⌨️", "\n" + line)
	_verbose.info("input", "⌨️", "FARM KEYBOARD CONTROLS")
	_verbose.info("input", "⌨️", line)
	_verbose.info("input", "🛠️", "1-4 = Tools | Q/E/R = Actions")
	_verbose.info("input", "📍", "T-P = Toggle plots | [ = Clear | ] = Select all")
	_verbose.info("input", "🎮", "WASD = Move | Tab = Mode | Space = Pause")
	_verbose.info("input", "⌨️", line + "\n")
