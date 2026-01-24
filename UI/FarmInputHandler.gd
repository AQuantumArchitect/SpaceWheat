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
## Keyboard-driven Farm UI - Minecraft-style tool/action system:
## Numbers 1-6 = Tool modes (Plant, Quantum, Economy, etc)
## Q/E/R = Context-sensitive actions (depends on active tool)
## WASD = Movement/cursor control
## TYUIOP = Quick-access location selectors

# Preloads
const GridConfig = preload("res://Core/GameState/GridConfig.gd")
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const Farm = preload("res://Core/Farm.gd")
const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")
const QuantumMill = preload("res://Core/GameMechanics/QuantumMill.gd")

# Handler modules (decomposed from FarmInputHandler monolith)
const GateActionHandler = preload("res://UI/Handlers/GateActionHandler.gd")
const MeasurementHandler = preload("res://UI/Handlers/MeasurementHandler.gd")
const LindbladHandler = preload("res://UI/Handlers/LindbladHandler.gd")
const BiomeHandler = preload("res://UI/Handlers/BiomeHandler.gd")
const IconHandler = preload("res://UI/Handlers/IconHandler.gd")
const SystemHandler = preload("res://UI/Handlers/SystemHandler.gd")

# Tool actions from shared config (single source of truth)
const TOOL_ACTIONS = ToolConfig.TOOL_ACTIONS

# Access autoload safely (avoids compile-time errors)
@onready var _verbose = get_node("/root/VerboseConfig")

var farm  # Will be injected with Farm instance (Farm.gd)
var plot_grid_display: Node = null  # Will be injected with PlotGridDisplay instance
var current_selection: Vector2i = Vector2i.ZERO
var current_tool: int = 1  # Active tool (1-4, v2 architecture)
var current_submenu: String = ""  # Active submenu name (empty = no submenu)
var _cached_submenu: Dictionary = {}  # Cached dynamic submenu during session
var grid_config: GridConfig = null  # Grid configuration (Phase 7)

# Grid dimensions (set from GridConfig)
var grid_width: int = 6  # Default, updated by inject_grid_config
var grid_height: int = 4  # Default, updated by inject_grid_config

# v2 Architecture State
var evolution_paused: bool = false  # Spacebar toggle for quantum evolution

# Mill two-stage selection state
var mill_selection_stage: int = 0  # 0=none, 1=power selected, waiting for conversion
var mill_selected_power: String = ""  # "Q", "E", or "R" for power source

# Debug: Set to true to enable verbose logging (keystroke-by-keystroke, location info, etc)
const VERBOSE = true  # Enabled for debugging keyboard issues

# Signals
signal action_performed(action: String, success: bool, message: String)
signal selection_changed(new_pos: Vector2i)
signal plot_selected(pos: Vector2i)  # Signal emitted when plot location is selected
signal tool_changed(tool_num: int, tool_info: Dictionary)
signal submenu_changed(submenu_name: String, submenu_info: Dictionary)  # Emitted when entering/exiting submenu
signal help_requested

# v2 Architecture Signals
signal mode_changed(new_mode: String)  # "play" or "build"
signal pause_toggled(is_paused: bool)  # Evolution pause state
signal tool_mode_cycled(tool_num: int, new_mode_index: int, mode_label: String)  # F-cycling

func _ready():
	_verbose.info("input", "⌨️", "FarmInputHandler initialized (Tool Mode System)")
	if VERBOSE:
		_verbose.debug("input", "📍", "Starting position: %s" % current_selection)
		_verbose.debug("input", "🛠️", "Current tool: %s" % TOOL_ACTIONS[current_tool]["name"])
	# Input is ready immediately - PlotGridDisplay is initialized before this
	# No deferred calls needed
	# CRITICAL: Enable _unhandled_input() processing (not _input()!)
	set_process_unhandled_input(true)
	_verbose.info("input", "✅", "Unhandled input processing enabled (no deferred delays)")

	# Connect to ActiveBiomeManager for biome change handling
	_connect_to_biome_manager()

	_print_help()


func _connect_to_biome_manager() -> void:
	"""Connect to ActiveBiomeManager to reset cursor on biome change"""
	var biome_mgr = get_node_or_null("/root/ActiveBiomeManager")
	if biome_mgr and biome_mgr.has_signal("active_biome_changed"):
		if not biome_mgr.active_biome_changed.is_connected(_on_active_biome_changed):
			biome_mgr.active_biome_changed.connect(_on_active_biome_changed)
			_verbose.info("input", "📡", "FarmInputHandler connected to ActiveBiomeManager")


func _on_active_biome_changed(new_biome: String, _old_biome: String) -> void:
	"""Reset cursor and selection when biome changes"""
	_verbose.debug("input", "🔄", "FarmInputHandler: Biome changed to %s - resetting cursor" % new_biome)

	# Reset cursor to first plot of new biome
	if farm and farm.has_method("get_plot_position_for_active_biome"):
		current_selection = farm.get_plot_position_for_active_biome(0)
		_verbose.debug("input", "📍", "Cursor reset to %s" % current_selection)

	# Clear any multi-select checkboxes (handled by PlotGridDisplay, but ensure it's called)
	if plot_grid_display and plot_grid_display.has_method("clear_all_selection"):
		plot_grid_display.clear_all_selection()

	# Exit any active submenu
	if current_submenu != "":
		_exit_submenu()
		_verbose.debug("input", "📋", "Exited submenu on biome change")


func _process(_delta: float) -> void:
	"""Enable input processing on first frame after initialization"""
	set_process(false)  # Stop processing frames
	set_process_unhandled_input(true)  # Enable _unhandled_input() callback
	_verbose.info("input", "✅", "Unhandled input processing enabled (UI ready)")
	if plot_grid_display and plot_grid_display.tiles:
		_verbose.debug("input", "📊", "PlotGridDisplay has %d tiles ready" % plot_grid_display.tiles.size())


func inject_grid_config(config: GridConfig) -> void:
	"""Inject GridConfig for dynamic grid-aware input handling (Phase 7)"""
	if not config:
		push_error("FarmInputHandler: Attempted to inject null GridConfig!")
		return

	grid_config = config
	# Update dimensions from config
	grid_width = config.grid_width
	grid_height = config.grid_height
	_verbose.info("input", "💉", "GridConfig injected into FarmInputHandler (%dx%d grid)" % [grid_width, grid_height])


func _unhandled_input(event: InputEvent):
	"""Handle gameplay input via InputMap actions (Layer 3 - Low Priority)

	Only processes input that PlayerShell didn't consume (modals, shell actions).
	Supports keyboard (WASD, QERT, numbers, etc) and gamepad (D-Pad, buttons, sticks)
	via Godot's InputMap system.
	"""
	if VERBOSE and event is InputEventKey and event.pressed:
		_verbose.debug("input", "🔑", "FarmInputHandler._input() received KEY: %s" % event.keycode)

	# ═══════════════════════════════════════════════════════════════
	# v2 GLOBAL CONTROLS (always processed first)
	# ═══════════════════════════════════════════════════════════════

	# Spacebar: Toggle evolution pause
	if event.is_action_pressed("pause"):
		_toggle_evolution_pause()
		get_viewport().set_input_as_handled()
		return

	# H: HARVEST - Global collapse, end level
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		_action_harvest_global()
		get_viewport().set_input_as_handled()
		return

	# Tab: Toggle BUILD/PLAY mode
	if event.is_action_pressed("toggle_mode"):
		_toggle_build_play_mode()
		get_viewport().set_input_as_handled()
		return

	# F: Cycle tool mode (for tools with F-cycling like GATES, ENTANGLE)
	# Note: If overlay is active, PlayerShell routes F to overlay first.
	# This only runs if no overlay consumed the input.
	if event.is_action_pressed("action_f"):
		_cycle_current_tool_mode()
		get_viewport().set_input_as_handled()
		return

	# NOTE: v2 overlay input routing moved to PlayerShell.OverlayStackManager
	# PlayerShell._input() routes to overlays BEFORE reaching FarmInputHandler

	# Tool selection (1-6) - Phase 7: Use InputMap actions
	for i in range(1, 7):
		if event.is_action_pressed("tool_" + str(i)):
			if VERBOSE:
				_verbose.debug("input", "🛠️", "Tool key pressed: %d" % i)
			_select_tool(i)
			get_viewport().set_input_as_handled()
			return

	# Location quick-select (dynamic from GridConfig, or default mapping) - MULTI-SELECT: Toggle plots with checkboxes
	# TYUIOP keys select plots 0-5 within the ACTIVE BIOME (determined by ActiveBiomeManager)
	if grid_config:
		for action in grid_config.keyboard_layout.get_all_actions():
			if event.is_action_pressed(action):
				if VERBOSE:
					_verbose.debug("input", "📍", "GridConfig action detected: %s" % action)
				var base_pos = grid_config.keyboard_layout.get_position_for_action(action)
				if base_pos != Vector2i(-1, -1):
					# Remap x-coordinate to active biome's row using Farm helper
					var pos = base_pos
					if farm and farm.has_method("get_plot_position_for_active_biome"):
						pos = farm.get_plot_position_for_active_biome(base_pos.x)
					if grid_config.is_position_valid(pos):
						_toggle_plot_selection(pos)
						get_viewport().set_input_as_handled()
						return
	else:
		_verbose.warn("input", "⚠️", "grid_config is NULL at input time - falling back to hardcoded actions")
		# Fallback: default 6x1 keyboard layout (single-biome view)
		# TYUIOP = 6 plots per biome (x=0-5), remapped to active biome's row
		# 7890 = biome selection (handled separately by ActiveBiomeManager)
		var default_plot_indices = {
			"select_plot_t": 0,
			"select_plot_y": 1,
			"select_plot_u": 2,
			"select_plot_i": 3,
			"select_plot_o": 4,
			"select_plot_p": 5,
		}
		for action in default_plot_indices.keys():
			if event.is_action_pressed(action):
				var plot_index = default_plot_indices[action]
				# Remap to active biome's row
				var pos = Vector2i(plot_index, 0)
				if farm and farm.has_method("get_plot_position_for_active_biome"):
					pos = farm.get_plot_position_for_active_biome(plot_index)
				if VERBOSE:
					_verbose.debug("input", "📍", "Fallback action detected: %s → %s" % [action, pos])
				_toggle_plot_selection(pos)
				get_viewport().set_input_as_handled()
				return

	# Selection management: [ = clear all, ] = select all (in active biome)
	# Check for raw keyboard events since InputMap actions don't exist for these keys
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_BRACKETLEFT:  # [ key
			_clear_all_selection()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_BRACKETRIGHT:  # ] key
			_select_all_plots()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_BACKSPACE:  # Backspace - Remove Gates (only with Tool 5)
			if current_tool == 5 and current_submenu == "":  # Only if Tool 5 is active and not in submenu
				var selected_plots: Array[Vector2i] = []
				if plot_grid_display and plot_grid_display.has_method("get_selected_plots"):
					selected_plots = plot_grid_display.get_selected_plots()
				if selected_plots.is_empty() and _is_valid_position(current_selection):
					selected_plots = [current_selection]
				if not selected_plots.is_empty():
					_action_remove_gates(selected_plots)
					get_viewport().set_input_as_handled()
					return

		# ═══════════════════════════════════════════════════════════════════════
		# BIOME SELECTION - 7890 for direct selection, ,. for cycling
		# ═══════════════════════════════════════════════════════════════════════
		var _biome_mgr = get_node_or_null("/root/ActiveBiomeManager")
		if _biome_mgr:
			# Direct biome selection (7, 8, 9, 0)
			if _biome_mgr.select_biome_by_key(event.keycode):
				get_viewport().set_input_as_handled()
				return
			# Biome cycling (, and .)
			if _biome_mgr.handle_cycle_input(event.keycode):
				get_viewport().set_input_as_handled()
				return

	# Movement (WASD or D-Pad or Left Stick) - Phase 7: Use InputMap actions
	if event.is_action_pressed("move_up"):
		_move_selection(Vector2i.UP)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("move_down"):
		_move_selection(Vector2i.DOWN)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("move_left"):
		_move_selection(Vector2i.LEFT)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("move_right"):
		_move_selection(Vector2i.RIGHT)
		get_viewport().set_input_as_handled()
		return

	# Action keys (Q/E/R or gamepad buttons A/B/X)
	# Use both InputMap actions (for gamepad) AND raw keycodes (for keyboard reliability)
	if event is InputEventKey and event.pressed:
		var key = event.keycode
		var action_key: String = ""

		# Map keycode to action
		match key:
			KEY_Q:
				action_key = "Q"
			KEY_E:
				action_key = "E"
			KEY_R:
				action_key = "R"

		if action_key != "":
			if VERBOSE:
				_verbose.debug("input", "⚡", "QER keycode detected: %s → %s" % [key, action_key])
			_execute_tool_action(action_key)
			get_viewport().set_input_as_handled()
			return

	# Also check InputMap actions for gamepad support
	if event.is_action_pressed("action_q"):
		if VERBOSE:
			_verbose.debug("input", "⚡", "action_q (InputMap) detected")
		_execute_tool_action("Q")
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("action_e"):
		if VERBOSE:
			_verbose.debug("input", "⚡", "action_e (InputMap) detected")
		_execute_tool_action("E")
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("action_r"):
		if VERBOSE:
			_verbose.debug("input", "⚡", "action_r (InputMap) detected")
		_execute_tool_action("R")
		get_viewport().set_input_as_handled()
		return

	# Debug/Help - Phase 7: Use InputMap action
	if event.is_action_pressed("toggle_help"):
		_print_help()
		get_viewport().set_input_as_handled()
		return

	# NOTE: K key for keyboard help is now handled by InputController
	# Removed backward compatibility handlers to avoid conflicts with menu system


## Tool System

func _select_tool(tool_num: int):
	"""Select active tool (1-4, v2 architecture)"""
	if not TOOL_ACTIONS.has(tool_num):
		_verbose.warn("input", "⚠️", "Tool %d not available" % tool_num)
		return

	# Exit any active submenu when switching tools
	if current_submenu != "":
		_exit_submenu()

	current_tool = tool_num
	var tool_info = TOOL_ACTIONS[tool_num]
	_verbose.info("input", "🛠️", "Tool switched to: %s" % tool_info["name"])
	# v2 structure: actions are nested under "actions" key
	if VERBOSE:
		var actions = tool_info.get("actions", {})
		_verbose.debug("input", "🛠️", "Q = %s" % actions.get("Q", {}).get("label", "?"))
		_verbose.debug("input", "🛠️", "E = %s" % actions.get("E", {}).get("label", "?"))
		_verbose.debug("input", "🛠️", "R = %s" % actions.get("R", {}).get("label", "?"))

	tool_changed.emit(tool_num, tool_info)


## Submenu System

func _enter_submenu(submenu_name: String):
	"""Enter a submenu - QER keys now map to submenu actions"""
	var submenu = ToolConfig.get_submenu(submenu_name)
	if submenu.is_empty():
		push_error("Submenu '%s' not found" % submenu_name)
		return

	# Get plot position for context-aware menus
	var menu_position = current_selection
	var checked_plots: Array[Vector2i] = []
	if plot_grid_display and plot_grid_display.has_method("get_selected_plots"):
		checked_plots = plot_grid_display.get_selected_plots()
	if not checked_plots.is_empty():
		menu_position = checked_plots[0]

	# Check if submenu is dynamic - generate runtime actions
	if submenu.get("dynamic", false):
		submenu = ToolConfig.get_dynamic_submenu(submenu_name, farm, menu_position)

	# Special handling for mill_power submenu: inject availability
	if submenu_name == "mill_power":
		submenu = submenu.duplicate(true)  # Make copy to add availability
		var biome = farm.grid.get_biome_for_plot(menu_position) if farm and farm.grid else null
		var availability = QuantumMill.check_power_availability(biome)
		submenu["_availability"] = availability
		mill_selection_stage = 0  # Reset mill state when entering power submenu
		mill_selected_power = ""

	current_submenu = submenu_name

	# Cache the generated submenu for this session
	_cached_submenu = submenu

	submenu_changed.emit(submenu_name, submenu)


func _exit_submenu():
	"""Exit current submenu and return to tool mode"""
	if current_submenu == "":
		return

	current_submenu = ""
	_cached_submenu = {}  # Clear cache
	submenu_changed.emit("", {})

	# Re-emit tool info to update UI
	tool_changed.emit(current_tool, TOOL_ACTIONS[current_tool])


func _refresh_dynamic_submenu():
	"""Refresh dynamic submenu when selection changes

	If currently in a dynamic submenu (like plant), regenerate it based on
	the new selected plot's biome. This ensures biome-specific menus update
	when switching between plots.
	"""
	if current_submenu == "":
		return  # Not in a submenu

	# Check if current submenu is dynamic
	var base_submenu = ToolConfig.get_submenu(current_submenu)
	if not base_submenu.get("dynamic", false):
		return  # Not a dynamic submenu

	# Determine which plot position to use for menu generation
	var menu_position = current_selection

	# If checkboxes are active, use first checked plot instead of current_selection
	var checked_plots: Array[Vector2i] = []
	if plot_grid_display and plot_grid_display.has_method("get_selected_plots"):
		checked_plots = plot_grid_display.get_selected_plots()

	if not checked_plots.is_empty():
		menu_position = checked_plots[0]

	# Regenerate dynamic submenu for new selection
	var regenerated = ToolConfig.get_dynamic_submenu(current_submenu, farm, menu_position)
	_cached_submenu = regenerated

	# Re-emit submenu_changed to update UI
	submenu_changed.emit(current_submenu, regenerated)


func _execute_submenu_action(action_key: String):
	"""Execute action from current submenu"""
	# Use cached submenu (supports dynamic generation)
	var submenu = _cached_submenu if not _cached_submenu.is_empty() else ToolConfig.get_submenu(current_submenu)

	if submenu.is_empty():
		_verbose.warn("input", "⚠️", "Current submenu '%s' not found" % current_submenu)
		_exit_submenu()
		return

	# Check if entire submenu is disabled (e.g., no vocabulary discovered)
	if submenu.get("_disabled", false):
		_verbose.warn("input", "⚠️", "Submenu disabled - grow crops to discover vocabulary")
		action_performed.emit("disabled", false, "⚠️  Discover vocabulary by growing crops")
		return

	if not submenu.has(action_key):
		_verbose.warn("input", "⚠️", "Action %s not available in submenu %s" % [action_key, current_submenu])
		return

	var action_info = submenu[action_key]
	var action = action_info["action"]
	var label = action_info["label"]

	# Check if action is empty (locked button)
	if action == "":
		_verbose.warn("input", "⚠️", "Action locked - discover more vocabulary")
		action_performed.emit("locked", false, "⚠️  Unlock by discovering vocabulary")
		return

	# Get currently selected plots
	var selected_plots: Array[Vector2i] = []
	if plot_grid_display and plot_grid_display.has_method("get_selected_plots"):
		selected_plots = plot_grid_display.get_selected_plots()

	if selected_plots.is_empty():
		if _is_valid_position(current_selection):
			selected_plots = [current_selection]
		else:
			_verbose.warn("input", "⚠️", "No plots selected!")
			action_performed.emit(action, false, "⚠️  No plots selected")
			return

	_verbose.info("input", "📂", "Submenu %s | Key %s | Action: %s | Plots: %d" % [current_submenu, action_key, label, selected_plots.size()])

	# Execute submenu-specific actions
	match action:
		# Plant submenu
		"plant_wheat":
			_action_batch_plant("wheat", selected_plots)
		"plant_mushroom":
			_action_batch_plant("mushroom", selected_plots)
		"plant_tomato":
			_action_batch_plant("tomato", selected_plots)

		# Kitchen ingredients (dynamic submenu)
		"plant_fire":
			_action_batch_plant("fire", selected_plots)
		"plant_water":
			_action_batch_plant("water", selected_plots)
		"plant_flour":
			_action_batch_plant("flour", selected_plots)

		# Forest organisms (dynamic submenu)
		"plant_vegetation":
			_action_batch_plant("vegetation", selected_plots)
		"plant_rabbit":
			_action_batch_plant("rabbit", selected_plots)
		"plant_wolf":
			_action_batch_plant("wolf", selected_plots)

		# Market commodities (dynamic submenu)
		"plant_bread":
			_action_batch_plant("bread", selected_plots)

		# Industry submenu (legacy - direct placement)
		"place_mill":
			_action_batch_build("mill", selected_plots)
		"place_market":
			_action_batch_build("market", selected_plots)
		"place_kitchen":
			_action_place_kitchen(selected_plots)

		# Mill two-stage selection: Power sources (stage 1)
		"mill_select_power_water":
			_action_mill_select_power("Q", selected_plots)
			return  # Don't exit submenu - proceed to stage 2
		"mill_select_power_wind":
			_action_mill_select_power("E", selected_plots)
			return  # Don't exit submenu - proceed to stage 2
		"mill_select_power_fire":
			_action_mill_select_power("R", selected_plots)
			return  # Don't exit submenu - proceed to stage 2

		# Mill two-stage selection: Conversions (stage 2)
		"mill_convert_flour":
			_action_mill_convert("Q", selected_plots)
		"mill_convert_lumber":
			_action_mill_convert("E", selected_plots)
		"mill_convert_energy":
			_action_mill_convert("R", selected_plots)

		# Industry building operations submenu
		"harvest_flour":
			_action_harvest_flour(selected_plots)
		"market_sell":
			_action_market_sell(selected_plots)
		"bake_bread":
			_action_bake_bread(selected_plots)

		# Single-qubit gate submenu
		"apply_pauli_x":
			_action_apply_pauli_x(selected_plots)
		"apply_hadamard":
			_action_apply_hadamard(selected_plots)
		"apply_pauli_z":
			_action_apply_pauli_z(selected_plots)

		# Phase gate submenu (NEW)
		"apply_pauli_y":
			_action_apply_pauli_y(selected_plots)
		"apply_s_gate":
			_action_apply_s_gate(selected_plots)
		"apply_t_gate":
			_action_apply_t_gate(selected_plots)
		"apply_sdg_gate":
			_action_apply_sdg_gate(selected_plots)

		# Rotation gate submenu (BUILD Tool 4 Mode 2)
		"apply_rx_gate":
			_action_apply_rx_gate(selected_plots)
		"apply_ry_gate":
			_action_apply_ry_gate(selected_plots)
		"apply_rz_gate":
			_action_apply_rz_gate(selected_plots)

		# Two-qubit gate submenu
		"apply_cnot":
			_action_apply_cnot(selected_plots)
		"apply_cz":
			_action_apply_cz(selected_plots)
		"apply_swap":
			_action_apply_swap(selected_plots)

		# Tool 6: Biome Management
		"clear_biome_assignment":
			_action_clear_biome_assignment(selected_plots)

		"inspect_plot":
			_action_inspect_plot(selected_plots)

		"pump_to_wheat":
			_action_pump_to_wheat(selected_plots)

		# NOTE: reset_to_pure/reset_to_mixed removed (2026-01) - BiomeBase methods don't exist

		# Lindblad control actions
		"lindblad_drive":
			_action_lindblad_drive(selected_plots)

		"lindblad_decay":
			_action_lindblad_decay(selected_plots)

		"lindblad_transfer":
			_action_lindblad_transfer(selected_plots)

		# Non-destructive state inspection
		"peek_state":
			_action_peek_state(selected_plots)

		# Tool 2 (Icon) - BUILD mode
		"icon_swap":
			_action_icon_swap(selected_plots)

		"icon_clear":
			_action_icon_clear(selected_plots)

		# Tool 4 (System) - BUILD mode
		"system_reset":
			_action_system_reset(selected_plots)

		"system_snapshot":
			_action_system_snapshot(selected_plots)

		"system_debug":
			_action_system_debug(selected_plots)

		_:
			# Handle dynamic actions
			# NOTE: tap_ actions removed (2026-01) - energy tap system deprecated
			if action.begins_with("assign_to_"):
				# Dynamic biome assignment
				var biome_name = action.replace("assign_to_", "")
				if farm.grid.biomes.has(biome_name):
					_action_assign_plots_to_biome(selected_plots, biome_name)
				else:
					_verbose.warn("input", "⚠️", "Biome '%s' not found in registry!" % biome_name)
			elif action.begins_with("icon_assign_"):
				# Dynamic icon/vocab assignment to biome
				var emoji = _extract_emoji_from_action(action)
				if emoji != "":
					_action_icon_assign(selected_plots, emoji)
				else:
					_verbose.warn("input", "⚠️", "Unknown icon_assign action: %s" % action)
			else:
				_verbose.warn("input", "⚠️", "Unknown submenu action: %s" % action)

	# Auto-exit submenu after executing action
	_exit_submenu()


func get_current_actions() -> Dictionary:
	"""Get current QER actions (from submenu or tool)

	Used by UI to display correct action labels.
	"""
	if current_submenu != "":
		var submenu = ToolConfig.get_submenu(current_submenu)
		return {
			"Q": submenu.get("Q", {}),
			"E": submenu.get("E", {}),
			"R": submenu.get("R", {}),
			"is_submenu": true,
			"submenu_name": current_submenu,
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


func execute_action(action_key: String) -> void:
	"""PUBLIC: Execute the action mapped to Q/E/R for current tool

	NOTE: This is now primarily used by test files. In production, ActionPreviewRow
	connects directly to _execute_tool_action() for the unified signal path.
	"""
	_execute_tool_action(action_key)


func _execute_tool_action(action_key: String):
	"""Execute the action mapped to Q/E/R for current tool or submenu

	Supports submenu navigation and multi-select.
	Called by BOTH keyboard (_unhandled_input) and touch (ActionPreviewRow signal).
	"""
	if not farm:
		push_error("Farm not set on FarmInputHandler!")
		return

	# Check if we're in a submenu first
	if current_submenu != "":
		_execute_submenu_action(action_key)
		return

	# Use ToolConfig API to get action (handles F-cycling and nested structure)
	var action_info = ToolConfig.get_action(current_tool, action_key)
	if action_info.is_empty():
		_verbose.warn("input", "⚠️", "Action %s not available for tool %d" % [action_key, current_tool])
		return

	var action = action_info.get("action", "")
	var label = action_info.get("label", "")

	if action == "":
		_verbose.warn("input", "⚠️", "Action %s has no action defined for tool %d" % [action_key, current_tool])
		return

	# Check if this action opens a submenu
	if action_info.has("submenu"):
		var submenu_name = action_info["submenu"]
		_enter_submenu(submenu_name)
		return

	# Get currently selected plots
	var selected_plots: Array[Vector2i] = []
	if plot_grid_display and plot_grid_display.has_method("get_selected_plots"):
		selected_plots = plot_grid_display.get_selected_plots()

	# FALLBACK: If no plots selected in UI, use current selection (for auto-play/testing)
	if selected_plots.is_empty():
		if _is_valid_position(current_selection):
			selected_plots = [current_selection]
			if VERBOSE:
				_verbose.debug("input", "📍", "No multi-select; using current selection: %s" % current_selection)
		else:
			_verbose.warn("input", "⚠️", "No plots selected! Use T/Y/U/I/O/P to toggle selections.")
			action_performed.emit(action, false, "⚠️  No plots selected")
			return

	var tool_name = ToolConfig.get_tool_name(current_tool)
	_verbose.info("input", "⚡", "Tool %d (%s) | Key %s | Action: %s | Plots: %d selected" % [current_tool, tool_name, action_key, label, selected_plots.size()])

	# Execute the action based on type (now with multi-select support)
	match action:
		# Tool 1: PROBE - v2 EXPLORE/MEASURE/POP (Quantum Tomography Paradigm)
		"explore":
			_action_explore()
		"measure":
			_action_measure(selected_plots)
		"pop":
			_action_pop(selected_plots)

		# Tool 2: QUANTUM - Persistent gate infrastructure
		"cluster":
			_action_cluster(selected_plots)
		"measure_trigger":
			_action_measure_trigger(selected_plots)
		"remove_gates":
			_action_remove_gates(selected_plots)

		# Tool 3: INDUSTRY - Economy & automation
		"place_mill":
			_action_batch_build("mill", selected_plots)
		"place_market":
			_action_batch_build("market", selected_plots)
		"place_kitchen":
			_action_place_kitchen(selected_plots)

		# Tool 3: INDUSTRY - Quantum building operations
		"harvest_flour":
			_action_harvest_flour(selected_plots)
		"market_sell":
			_action_market_sell(selected_plots)
		"bake_bread":
			_action_bake_bread(selected_plots)

		# NOTE: place_energy_tap removed (2026-01) - energy tap system deprecated

		# Tool 2: GATES (1-qubit) - Probability control
		"apply_pauli_x":
			_action_apply_pauli_x(selected_plots)
		"apply_hadamard":
			_action_apply_hadamard(selected_plots)
		"apply_pauli_z":
			_action_apply_pauli_z(selected_plots)
		"apply_ry":
			_action_apply_ry_gate(selected_plots)

		# Tool 3: ENTANGLE (2-qubit) - Entanglement gates
		"apply_cnot":
			_action_apply_cnot(selected_plots)
		"apply_swap":
			_action_apply_swap(selected_plots)
		"apply_cz":
			_action_apply_cz(selected_plots)
		"create_bell_pair":
			_action_create_bell_pair(selected_plots)
		"disentangle":
			_action_disentangle(selected_plots)
		"inspect_entanglement":
			_action_inspect_entanglement(selected_plots)

		# ═══════════════════════════════════════════════════════════════
		# BUILD MODE ACTIONS (Tab to switch)
		# ═══════════════════════════════════════════════════════════════

		# BUILD Tool 1: BIOME - Assign/Clear biome, Inspect
		"clear_biome_assignment":
			_action_clear_biome_assignment(selected_plots)
		"inspect_plot":
			_action_inspect_plot(selected_plots)

		# BUILD Tool 2: ICON - Swap/Clear icons
		"icon_swap":
			_action_icon_swap(selected_plots)
		"icon_clear":
			_action_icon_clear(selected_plots)

		# BUILD Tool 3: LINDBLAD - Dissipation control
		"lindblad_drive":
			_action_lindblad_drive(selected_plots)
		"lindblad_decay":
			_action_lindblad_decay(selected_plots)
		"lindblad_transfer":
			_action_lindblad_transfer(selected_plots)

		# BUILD Tool 4: QUANTUM (system mode) - System control
		"system_reset":
			_action_system_reset(selected_plots)
		"system_snapshot":
			_action_system_snapshot(selected_plots)
		"system_debug":
			_action_system_debug(selected_plots)

		# BUILD Tool 4: QUANTUM (phase mode) - Phase gates
		"apply_s_gate":
			_action_apply_s_gate(selected_plots)
		"apply_t_gate":
			_action_apply_t_gate(selected_plots)
		"apply_sdg_gate":
			_action_apply_sdg_gate(selected_plots)

		# BUILD Tool 4: QUANTUM (rotation mode) - Rotation gates
		"apply_rx_gate":
			_action_apply_rx_gate(selected_plots)
		"apply_ry_gate":
			_action_apply_ry_gate(selected_plots)
		"apply_rz_gate":
			_action_apply_rz_gate(selected_plots)

		_:
			_verbose.warn("input", "⚠️", "Unknown action: %s" % action)


## Selection Management

func _move_selection(direction: Vector2i):
	"""Move selection in given direction (WASD)"""
	var new_pos = current_selection + direction
	if _is_valid_position(new_pos):
		current_selection = new_pos
		selection_changed.emit(current_selection)

		# If in a dynamic submenu, regenerate it for the new selection
		_refresh_dynamic_submenu()

		if VERBOSE:
			_verbose.debug("input", "📍", "Moved to: %s" % current_selection)
	else:
		if VERBOSE:
			_verbose.debug("input", "⚠️", "Cannot move to: %s (out of bounds)" % new_pos)


func _is_valid_position(pos: Vector2i) -> bool:
	"""Check if position is within grid bounds"""
	if grid_config:
		return grid_config.is_position_valid(pos)
	# Fallback for backward compatibility
	return pos.x >= 0 and pos.x < grid_width and \
	       pos.y >= 0 and pos.y < grid_height


## Multi-Select Management (NEW)

func _toggle_plot_selection(pos: Vector2i):
	"""Toggle a plot's selection state (for T/Y/U/I/O/P keys)"""
	if not plot_grid_display:
		_verbose.error("input", "❌", "ERROR: PlotGridDisplay not wired to FarmInputHandler!")
		_verbose.error("input", "❌", "Refactor incomplete or wiring failed")
		return

	if not _is_valid_position(pos):
		_verbose.warn("input", "⚠️", "Invalid position: %s" % pos)
		return

	_verbose.debug("input", "⌨️", "Toggle plot %s" % pos)
	plot_grid_display.toggle_plot_selection(pos)


func _clear_all_selection():
	"""Clear all selected plots ([ key)"""
	if not plot_grid_display:
		_verbose.error("input", "❌", "ERROR: PlotGridDisplay not wired to FarmInputHandler!")
		return

	plot_grid_display.clear_all_selection()


func _select_all_plots():
	"""Select all plots in the active biome (] key)"""
	if not plot_grid_display:
		_verbose.error("input", "❌", "ERROR: PlotGridDisplay not wired to FarmInputHandler!")
		return

	plot_grid_display.select_all_plots()


## Action Implementations - Batch Operations (NEW)

func _action_batch_plant(plant_type: String, positions: Array[Vector2i]):
	"""Plant multiple plots with the given plant type (PARAMETRIC - Phase 3)

	Queries biome capabilities for validation and cost checking.
	Groups plots by biome to handle different capabilities.
	"""
	if not farm:
		action_performed.emit("plant_%s" % plant_type, false, "⚠️  Farm not loaded yet")
		_verbose.error("farm", "❌", "PLANT FAILED: Farm not loaded")
		return

	if not farm.grid:
		action_performed.emit("plant_%s" % plant_type, false, "⚠️  Farm grid not ready")
		_verbose.error("farm", "❌", "PLANT FAILED: Farm grid not ready")
		return

	# Group plots by biome (different biomes may have different capabilities)
	var plots_by_biome = {}
	for pos in positions:
		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome:
			_verbose.warn("farm", "⚠️", "Plot %s has no biome - skipping" % pos)
			continue

		var biome_type = biome.get_biome_type()
		if not plots_by_biome.has(biome_type):
			plots_by_biome[biome_type] = {
				"biome": biome,
				"positions": []
			}
		plots_by_biome[biome_type].positions.append(pos)

	# Plant in each biome group
	var total_success = 0
	var total_failed = 0
	var first_capability = null  # For display emoji

	for biome_type in plots_by_biome.keys():
		var biome_data = plots_by_biome[biome_type]
		var biome = biome_data.biome
		var biome_positions = biome_data.positions

		# Find capability for this plant_type in this biome (PARAMETRIC!)
		var capability = null
		for cap in biome.get_plantable_capabilities():
			if cap.plant_type == plant_type:
				capability = cap
				break

		# Track first capability for display
		if not first_capability and capability:
			first_capability = capability

		# Validate biome supports this plant type
		if not capability:
			_verbose.warn("farm", "❌", "%s biome doesn't support %s - skipping %d plots" % [
				biome_type, plant_type, biome_positions.size()])
			total_failed += biome_positions.size()
			continue

		# Plant each plot in this biome group
		for pos in biome_positions:
			# PARAMETRIC (Phase 6): farm.build() queries biome capabilities
			if farm.build(pos, plant_type):
				total_success += 1
			else:
				total_failed += 1

	# Report results
	var emoji = first_capability.emoji_pair.north if first_capability else "❓"
	var display_name = first_capability.display_name if first_capability else plant_type

	if total_success > 0:
		_verbose.info("farm", "🌱", "Planted %d × %s %s" % [total_success, emoji, display_name])
		action_performed.emit("plant_%s" % plant_type, true,
			"✅ Planted %d %s plots" % [total_success, display_name])
	else:
		_verbose.error("farm", "❌", "Failed to plant any %s (tried %d plots)" % [display_name, positions.size()])
		action_performed.emit("plant_%s" % plant_type, false,
			"❌ Failed to plant %s (%d plots)" % [display_name, total_failed])




func _action_batch_build(build_type: String, positions: Array[Vector2i]):
	"""Build structures (mill, market) on multiple plots"""
	if not farm:
		action_performed.emit("build_%s" % build_type, false, "⚠️  Farm not loaded yet")
		_verbose.error("farm", "❌", "BUILD FAILED: Farm not loaded")
		return

	_verbose.info("farm", "🏗️", "Batch building %s at %d plots: %s" % [build_type, positions.size(), positions])

	# Check if farm has batch method
	if farm.has_method("batch_build"):
		var result = farm.batch_build(positions, build_type)
		var success = result.get("success", false)
		var count = result.get("count", 0)
		action_performed.emit("build_%s" % build_type, success,
			"%s Built %d %s structures" % ["✅" if success else "❌", count, build_type])
	else:
		# Fallback: execute individually
		var success_count = 0
		for pos in positions:
			if farm.build(pos, build_type):
				success_count += 1
		var success = success_count > 0
		action_performed.emit("build_%s" % build_type, success,
			"%s Built %d/%d %s structures" % ["✅" if success else "❌", success_count, positions.size(), build_type])


func _action_place_kitchen(positions: Array[Vector2i]):
	"""Place kitchen using triplet entanglement (requires exactly 3 plots)"""
	if not farm or not farm.grid:
		action_performed.emit("place_kitchen", false, "⚠️  Farm not loaded yet")
		return

	_verbose.info("farm", "🍳", "Placing kitchen with %d selected plots..." % positions.size())

	# Kitchen requires exactly 3 plots for triplet entanglement
	if positions.size() != 3:
		action_performed.emit("place_kitchen", false, "⚠️  Kitchen requires exactly 3 plots selected (got %d)" % positions.size())
		_verbose.warn("farm", "❌", "Kitchen needs exactly 3 plots for triplet entanglement")
		return

	# Create triplet entanglement (determines Bell state by spatial pattern)
	var pos_a = positions[0]
	var pos_b = positions[1]
	var pos_c = positions[2]

	var success = farm.grid.create_triplet_entanglement(pos_a, pos_b, pos_c)

	if success:
		_verbose.info("farm", "🍳", "Kitchen triplet created: %s ↔ %s ↔ %s" % [pos_a, pos_b, pos_c])
		action_performed.emit("place_kitchen", true, "✅ Kitchen created with triplet entanglement")
	else:
		_verbose.error("farm", "❌", "Failed to create kitchen triplet")
		action_performed.emit("place_kitchen", false, "❌ Failed to create kitchen (plots may need to be planted first)")


## ═══════════════════════════════════════════════════════════════════════════
## QUANTUM BUILDING ACTIONS - Mill Harvest, Market Sell, Kitchen Bake
## ═══════════════════════════════════════════════════════════════════════════

func _action_harvest_flour(positions: Array[Vector2i]):
	"""Harvest flour from mill when P(💨) is high.

	Mill creates 💨 ↔ 🌾 Hamiltonian coupling - populations oscillate.
	Player harvests when P(💨) is high to maximize flour yield.
	Flour probability determines harvest amount.
	"""
	if not farm or not farm.grid:
		action_performed.emit("harvest_flour", false, "⚠️  Farm not loaded yet")
		return

	if positions.is_empty():
		action_performed.emit("harvest_flour", false, "⚠️  No plots selected")
		return

	_verbose.info("farm", "🏭", "Harvesting flour from %d positions..." % positions.size())

	var total_flour = 0
	var harvested_count = 0

	for pos in positions:
		# Check if there's a mill at this position
		var mill = farm.grid.quantum_mills.get(pos)
		if not mill or not mill.is_active:
			_verbose.debug("farm", "⚠️", "No active mill at %s" % pos)
			continue

		# Get flour probability from biome
		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome or not biome.quantum_computer:
			continue

		var flour_prob = biome.quantum_computer.get_emoji_probability("💨")

		# Harvest based on probability (threshold: 30%)
		if flour_prob > 0.3:
			var yield_amount = int(flour_prob * 100)
			total_flour += yield_amount
			harvested_count += 1

			# Add to economy
			if farm.economy:
				farm.economy.add_resource("💨", yield_amount, "mill_harvest")

			_verbose.info("farm", "💨", "Mill at %s: P(💨)=%.2f → %d flour" % [pos, flour_prob, yield_amount])
		else:
			_verbose.debug("farm", "⏳", "Mill at %s: P(💨)=%.2f (too low, wait)" % [pos, flour_prob])

	if harvested_count > 0:
		action_performed.emit("harvest_flour", true, "💨 Harvested %d flour from %d mills" % [total_flour, harvested_count])
	else:
		action_performed.emit("harvest_flour", false, "⏳ P(💨) too low - wait for oscillation")


func _action_market_sell(positions: Array[Vector2i]):
	"""Sell resources via market's quantum X ↔ 💰 pairing.

	Market pairs a target emoji with 💰 in superposition.
	Measurement collapses to determine credits:
	  - Collapse to 💰: Full sale
	  - Collapse to X: Partial sale
	"""
	if not farm or not farm.grid:
		action_performed.emit("market_sell", false, "⚠️  Farm not loaded yet")
		return

	if positions.is_empty():
		action_performed.emit("market_sell", false, "⚠️  No plots selected")
		return

	_verbose.info("farm", "🏪", "Selling at %d market positions..." % positions.size())

	var total_credits = 0
	var sold_count = 0
	var outcomes: Array[String] = []

	for pos in positions:
		# Check if there's a market at this position
		var market = farm.grid.quantum_markets.get(pos)
		if not market or not market.is_active:
			_verbose.debug("farm", "⚠️", "No active market at %s" % pos)
			continue

		# Perform quantum sale
		var result = market.measure_for_sale()
		if result.success:
			total_credits += result.credits
			sold_count += 1

			if result.got_money:
				outcomes.append("💰%d" % result.credits)
			else:
				outcomes.append("📦%d" % result.credits)

			# Add credits to economy
			if farm.economy:
				farm.economy.add_resource("💰", result.credits, "market_sale")

	if sold_count > 0:
		var outcome_str = ", ".join(outcomes) if outcomes.size() <= 3 else "%d sales" % sold_count
		action_performed.emit("market_sell", true, "🏪 Sold %s (+%d💰)" % [outcome_str, total_credits])
	else:
		action_performed.emit("market_sell", false, "⚠️  No active markets at selected positions")


func _action_bake_bread(positions: Array[Vector2i]):
	"""Bake bread using kitchen triplet entanglement.

	Requires 3 plots with 💧 (water), 🔥 (fire), 💨 (flour).
	Uses GHZ triplet state - measurement collapses to bread or ingredients.
	High coherence → bread, decoherence → ingredients returned.
	"""
	if not farm or not farm.grid:
		action_performed.emit("bake_bread", false, "⚠️  Farm not loaded yet")
		return

	if positions.size() != 3:
		action_performed.emit("bake_bread", false, "⚠️  Select 3 kitchen plots (💧🔥💨)")
		return

	_verbose.info("farm", "🍳", "Attempting to bake bread with triplet at %s..." % [positions])

	# Validate required ingredients
	var has_water = false
	var has_fire = false
	var has_flour = false

	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if not plot or not plot.is_planted:
			action_performed.emit("bake_bread", false, "⚠️  Plot %s not planted" % pos)
			return

		match plot.north_emoji:
			"💧": has_water = true
			"🔥": has_fire = true
			"💨": has_flour = true

	if not (has_water and has_fire and has_flour):
		action_performed.emit("bake_bread", false, "⚠️  Need 💧+🔥+💨 (got %s%s%s)" % [
			"💧" if has_water else "?",
			"🔥" if has_fire else "?",
			"💨" if has_flour else "?"
		])
		return

	# Get biome and check bread probability
	var biome = farm.grid.get_biome_for_plot(positions[0])
	if not biome or not biome.quantum_computer:
		action_performed.emit("bake_bread", false, "⚠️  No quantum system in biome")
		return

	# Get P(🍞) if bread axis exists, otherwise use coherence (Model C)
	var bread_prob = 0.5
	if biome.quantum_computer.register_map.has("🍞"):
		bread_prob = biome.quantum_computer.get_population("🍞")
	else:
		# Use overall coherence as proxy
		bread_prob = biome.quantum_computer.get_purity()

	# Attempt baking (Born rule)
	if randf() < bread_prob:
		var bread_yield = int(bread_prob * 100)

		if farm.economy:
			farm.economy.add_resource("🍞", bread_yield, "kitchen_bake")

		_verbose.info("farm", "🍞", "BREAD BAKED! P(🍞)=%.2f → %d bread" % [bread_prob, bread_yield])
		action_performed.emit("bake_bread", true, "🍞 Baked bread! (+%d🍞)" % bread_yield)
	else:
		_verbose.info("farm", "📦", "Collapsed to ingredients. P(🍞)=%.2f" % bread_prob)
		action_performed.emit("bake_bread", false, "📦 Collapsed to ingredients (try again)")


# ============================================================================
# MILL TWO-STAGE SELECTION (Coupling Injector)
# ============================================================================

func _action_mill_select_power(power_key: String, positions: Array[Vector2i]):
	"""Handle power source selection (mill stage 1).

	Saves selected power and transitions to stage 2 (conversion selection).
	"""
	if positions.is_empty():
		action_performed.emit("mill_power", false, "⚠️ Select a plot first")
		return

	var biome = farm.grid.get_biome_for_plot(positions[0])
	if not biome:
		action_performed.emit("mill_power", false, "⚠️ No biome at selected position")
		return

	# Verify power is available
	var availability = QuantumMill.check_power_availability(biome)
	if not availability.get(power_key, false):
		var power_info = QuantumMill.POWER_SOURCES.get(power_key, {})
		var emoji = power_info.get("emoji", "?")
		action_performed.emit("mill_power", false, "⚠️ %s not available in biome" % emoji)
		return

	# Save selection and move to stage 2
	mill_selected_power = power_key
	mill_selection_stage = 1

	var power_info = QuantumMill.POWER_SOURCES.get(power_key, {})
	_verbose.info("mill", "⚡", "Mill power selected: %s %s" % [
		power_info.get("emoji", "?"), power_info.get("label", "?")])

	# Get conversion availability for stage 2
	var conv_availability = QuantumMill.check_conversion_availability(biome)

	# Enter conversion submenu with availability
	var submenu = ToolConfig.SUBMENUS.get("mill_conversion", {}).duplicate(true)
	submenu["_availability"] = conv_availability
	current_submenu = "mill_conversion"
	_cached_submenu = submenu
	submenu_changed.emit("mill_conversion", submenu)


func _action_mill_convert(conversion_key: String, positions: Array[Vector2i]):
	"""Handle conversion selection (mill stage 2) and place the mill.

	Completes two-stage selection and creates the mill with coupling.
	"""
	if positions.is_empty():
		action_performed.emit("mill_place", false, "⚠️ Select a plot first")
		_reset_mill_state()
		return

	if mill_selection_stage != 1:
		action_performed.emit("mill_place", false, "⚠️ Select power source first")
		_reset_mill_state()
		return

	var pos = positions[0]
	var biome = farm.grid.get_biome_for_plot(pos)
	if not biome:
		action_performed.emit("mill_place", false, "⚠️ No biome at selected position")
		_reset_mill_state()
		return

	# Verify conversion is available
	var conv_availability = QuantumMill.check_conversion_availability(biome)
	if not conv_availability.get(conversion_key, false):
		var conv_info = QuantumMill.CONVERSIONS.get(conversion_key, {})
		var source = conv_info.get("source", "?")
		var product = conv_info.get("product", "?")
		action_performed.emit("mill_place", false, "⚠️ %s→%s not available (need both emojis in biome)" % [source, product])
		_reset_mill_state()
		return

	# Create and configure mill
	var mill = QuantumMill.new()
	mill.grid_position = pos
	farm.grid.add_child(mill)

	var result = mill.configure(biome, mill_selected_power, conversion_key)

	if result.success:
		farm.grid.quantum_mills[pos] = mill
		action_performed.emit("mill_place", true, "🏭 %s" % mill.get_status())
		_verbose.info("mill", "🏭", "Mill placed: %s" % mill.get_status())
	else:
		mill.queue_free()
		action_performed.emit("mill_place", false, "⚠️ Mill failed: %s" % result.get("error", "unknown"))

	# Reset mill state
	_reset_mill_state()


func _reset_mill_state():
	"""Reset mill selection state."""
	mill_selection_stage = 0
	mill_selected_power = ""


## V2 Tool 1 (PROBE) Actions - Quantum Tomography Paradigm

func _action_explore():
	"""EXPLORE: Probe the quantum soup to discover registers.

	Uses probability-weighted selection from the density matrix.
	Binds terminals to registers for ALL selected plots.
	Creates a bubble at each selected plot position.
	"""
	if not farm or not farm.plot_pool:
		action_performed.emit("explore", false, "⚠️  Farm not ready")
		return

	# Get selected plots (checkbox system) or fall back to current_selection
	var selected_plots: Array[Vector2i] = []
	if plot_grid_display and plot_grid_display.has_method("get_selected_plots"):
		selected_plots = plot_grid_display.get_selected_plots()
	if selected_plots.is_empty():
		selected_plots.append(current_selection)

	var success_count = 0
	var last_emoji = ""

	# EXPLORE for each selected plot
	for plot_pos in selected_plots:
		var biome = farm.grid.get_biome_for_plot(plot_pos)
		if not biome:
			continue

		# Execute EXPLORE via ProbeActions
		var result = ProbeActions.action_explore(farm.plot_pool, biome)

		if result.success:
			var terminal = result.terminal
			var emoji = result.emoji_pair.get("north", "?")
			last_emoji = emoji

			# Link terminal to grid position for bubble tap lookup
			terminal.grid_position = plot_pos

			# Emit terminal_bound signal for visualization (bubble spawn)
			farm.terminal_bound.emit(plot_pos, terminal.terminal_id, result.emoji_pair)

			_verbose.info("action", "🔍", "EXPLORE: Bound terminal %s to register %d (%s) at %s" % [
				terminal.terminal_id, result.register_id, emoji, plot_pos
			])
			success_count += 1

	if success_count > 0:
		action_performed.emit("explore", true, "🔍 Discovered %d registers" % success_count)
	else:
		action_performed.emit("explore", false, "⚠️  No terminals available or all registers bound")


func _action_measure(positions: Array[Vector2i]):
	"""MEASURE: Collapse explored registers via Born rule (BATCH operation).

	V2.2 Architecture: Processes ALL active terminals at selected positions.
	This enables measuring multiple terminals with a single keypress.
	"""
	if not farm or not farm.plot_pool:
		action_performed.emit("measure", false, "⚠️  Farm not ready")
		return

	# Get positions to measure - use current selection if no explicit positions
	if positions.is_empty():
		positions.append(current_selection)

	var measured_count = 0
	var total_probability = 0.0
	var outcomes: Array[String] = []

	# Process each selected position
	for pos in positions:
		var terminal = farm.plot_pool.get_terminal_at_grid_pos(pos)
		if not terminal or not terminal.can_measure():
			continue

		var biome = terminal.bound_biome
		if not biome:
			continue

		# Execute MEASURE via ProbeActions
		var result = ProbeActions.action_measure(terminal, biome)

		if result.success:
			measured_count += 1
			total_probability += result.recorded_probability
			outcomes.append(result.outcome)

			# Emit terminal_measured signal for this terminal
			farm.terminal_measured.emit(pos, terminal.terminal_id, result.outcome, result.recorded_probability)

			_verbose.info("action", "📏", "MEASURE: Terminal %s at %s collapsed to %s (p=%.0f%%)" % [
				terminal.terminal_id, pos, result.outcome, result.recorded_probability * 100
			])

	if measured_count > 0:
		var outcome_str = ", ".join(outcomes) if measured_count <= 3 else "%d terminals" % measured_count
		action_performed.emit("measure", true, "📏 Measured %s (total p=%.0f%%)" % [outcome_str, total_probability * 100])
	else:
		action_performed.emit("measure", false, "⚠️  No terminals to measure at selected positions. EXPLORE first.")


func _action_pop(positions: Array[Vector2i]):
	"""POP: Harvest measured terminals and free them for reuse (BATCH operation).

	V2.2 Architecture: Processes ALL measured terminals at selected positions.
	This enables harvesting multiple terminals with a single keypress.
	"""
	if not farm or not farm.plot_pool:
		action_performed.emit("pop", false, "⚠️  Farm not ready")
		return

	# Get positions to pop - use current selection if no explicit positions
	if positions.is_empty():
		positions.append(current_selection)

	var popped_count = 0
	var total_credits = 0
	var resources: Array[String] = []

	# Process each selected position
	for pos in positions:
		var terminal = farm.plot_pool.get_terminal_at_grid_pos(pos)
		if not terminal or not terminal.can_pop():
			continue

		# Save grid position and terminal_id before unbind clears them
		var grid_pos = terminal.grid_position
		var terminal_id = terminal.terminal_id

		# Execute POP via ProbeActions
		var result = ProbeActions.action_pop(terminal, farm.plot_pool, farm.economy)

		if result.success:
			popped_count += 1
			var credits = result.get("credits", 0)
			total_credits += credits
			resources.append(result.resource)

			# Emit terminal_released signal for this terminal
			farm.terminal_released.emit(grid_pos, terminal_id, credits)

			_verbose.info("action", "💰", "POP: Harvested %s from terminal %s at %s (+%d credits)" % [
				result.resource, terminal_id, grid_pos, credits
			])

	if popped_count > 0:
		var resource_str = ", ".join(resources) if popped_count <= 3 else "%d terminals" % popped_count
		action_performed.emit("pop", true, "💰 Harvested %s (+%d💰)" % [resource_str, total_credits])
	else:
		action_performed.emit("pop", false, "⚠️  No measured terminals to harvest at selected positions. MEASURE first.")


func _action_harvest_global():
	"""HARVEST: Global collapse of biome, end level.

	Ensemble Model: True projective measurement that collapses the
	entire quantum system and converts all probability to credits.
	This is the "end of turn" action.
	"""
	if not farm or not farm.plot_pool:
		action_performed.emit("harvest_global", false, "⚠️  Farm not ready")
		return

	# Get biome for current selection
	var biome = farm.grid.get_biome_for_plot(current_selection) if farm.grid else null
	if not biome:
		action_performed.emit("harvest_global", false, "⚠️  No biome at current selection")
		return

	# Execute HARVEST via ProbeActions
	var result = ProbeActions.action_harvest_global(biome, farm.plot_pool, farm.economy)

	if result.success:
		var total = result.total_credits
		var count = result.harvested.size()

		action_performed.emit("harvest_global", true, "🌾 HARVESTED: %.0f credits from %d registers!" % [total, count])
		_verbose.info("action", "🌾", "GLOBAL HARVEST: %.1f credits from %d registers" % [total, count])

		# Signal level complete
		if farm.has_signal("level_complete"):
			farm.level_complete.emit(result)
	else:
		var msg = result.get("message", "Harvest failed")
		action_performed.emit("harvest_global", false, "⚠️  %s" % msg)


## NEW Tool 2 (QUANTUM) Actions - PERSISTENT INFRASTRUCTURE

func _action_cluster(positions: Array[Vector2i]):
	"""Build entanglement cluster between terminals at selected positions."""
	var result = GateActionHandler.cluster(farm, positions)
	var msg = "Built cluster with %d entanglements (%d terminals)" % [result.entanglement_count, result.terminal_count] if result.success else result.get("message", "Cluster failed")
	action_performed.emit("cluster", result.success, msg)


func _action_measure_trigger(positions: Array[Vector2i]):
	"""Build measure trigger (Model B - Gate Infrastructure)

	Creates conditional measurement infrastructure for controlled collapse.
	First plot in selection is trigger, remaining are targets.
	Uses BiomeBase.set_measurement_trigger() for setup.
	"""
	if not farm or not farm.grid:
		action_performed.emit("measure_trigger", false, "⚠️  Farm not loaded yet")
		return

	if positions.size() < 2:
		action_performed.emit("measure_trigger", false, "⚠️  Need trigger + at least 1 target plot")
		return

	_verbose.info("quantum", "🎯", "Setting up measure trigger with %d plots..." % positions.size())

	# Get biome from first plot
	var biome = farm.grid.get_biome_for_plot(positions[0])
	if not biome:
		action_performed.emit("measure_trigger", false, "⚠️  Could not access biome")
		return

	# First plot is trigger, rest are targets
	var trigger_pos = positions[0]
	var target_positions = positions.slice(1, positions.size())

	# Set measurement trigger
	var success = biome.set_measurement_trigger(trigger_pos, target_positions)

	action_performed.emit("measure_trigger", success,
		"%s Set trigger at %s with %d targets" % ["✅" if success else "❌", trigger_pos, target_positions.size()])


func _action_remove_gates(positions: Array[Vector2i]):
	"""Remove gate infrastructure."""
	var result = MeasurementHandler.remove_gates(farm, positions)
	var msg = "Removed %d gate configs" % result.removed_count if result.success else result.get("message", "No gates removed")
	action_performed.emit("remove_gates", result.success, msg)


# NOTE: _action_place_energy_tap removed (2026-01) - energy tap system deprecated


## NEW Tool 5 (GATES) Actions - INSTANTANEOUS SINGLE-QUBIT

func _action_apply_pauli_x(positions: Array[Vector2i]):
	"""Apply Pauli-X gate (bit flip) to selected plots - INSTANTANEOUS."""
	var result = GateActionHandler.apply_pauli_x(farm, positions)
	var msg = "✅ Applied Pauli-X to %d qubits" % result.applied_count if result.success else "❌ No gates applied"
	action_performed.emit("apply_pauli_x", result.success, msg)


func _action_apply_hadamard(positions: Array[Vector2i]):
	"""Apply Hadamard gate (superposition) to selected plots - INSTANTANEOUS."""
	var result = GateActionHandler.apply_hadamard(farm, positions)
	var msg = "✅ Applied Hadamard to %d qubits" % result.applied_count if result.success else "❌ No gates applied"
	action_performed.emit("apply_hadamard", result.success, msg)


func _action_apply_pauli_z(positions: Array[Vector2i]):
	"""Apply Pauli-Z gate (phase flip) to selected plots - INSTANTANEOUS."""
	var result = GateActionHandler.apply_pauli_z(farm, positions)
	var msg = "✅ Applied Pauli-Z to %d qubits" % result.applied_count if result.success else "❌ No gates applied"
	action_performed.emit("apply_pauli_z", result.success, msg)


func _action_apply_pauli_y(positions: Array[Vector2i]):
	"""Apply Pauli-Y gate to selected plots - INSTANTANEOUS."""
	var result = GateActionHandler.apply_pauli_y(farm, positions)
	var msg = "✅ Applied Pauli-Y to %d qubits" % result.applied_count if result.success else "❌ No gates applied"
	action_performed.emit("apply_pauli_y", result.success, msg)


func _action_apply_s_gate(positions: Array[Vector2i]):
	"""Apply S gate (pi/2 phase) to selected plots - INSTANTANEOUS."""
	var result = GateActionHandler.apply_s_gate(farm, positions)
	var msg = "✅ Applied S-gate to %d qubits" % result.applied_count if result.success else "❌ No gates applied"
	action_performed.emit("apply_s_gate", result.success, msg)


func _action_apply_t_gate(positions: Array[Vector2i]):
	"""Apply T gate (pi/4 phase) to selected plots - INSTANTANEOUS."""
	var result = GateActionHandler.apply_t_gate(farm, positions)
	var msg = "✅ Applied T-gate to %d qubits" % result.applied_count if result.success else "❌ No gates applied"
	action_performed.emit("apply_t_gate", result.success, msg)


func _action_apply_sdg_gate(positions: Array[Vector2i]):
	"""Apply S-dagger gate (-pi/2 phase) to selected plots - INSTANTANEOUS."""
	var result = GateActionHandler.apply_sdg_gate(farm, positions)
	var msg = "✅ Applied S-dagger to %d qubits" % result.applied_count if result.success else "❌ No gates applied"
	action_performed.emit("apply_sdg_gate", result.success, msg)


func _action_apply_rx_gate(positions: Array[Vector2i]):
	"""Apply Rx rotation gate to selected plots."""
	var result = GateActionHandler.apply_rx_gate(farm, positions)
	var msg = "✅ Applied Rx-gate to %d qubits" % result.applied_count if result.success else "❌ No gates applied"
	action_performed.emit("apply_rx_gate", result.success, msg)


func _action_apply_ry_gate(positions: Array[Vector2i]):
	"""Apply Ry rotation gate to selected plots."""
	var result = GateActionHandler.apply_ry_gate(farm, positions)
	var msg = "✅ Applied Ry-gate to %d qubits" % result.applied_count if result.success else "❌ No gates applied"
	action_performed.emit("apply_ry_gate", result.success, msg)


func _action_apply_rz_gate(positions: Array[Vector2i]):
	"""Apply Rz rotation gate to selected plots."""
	var result = GateActionHandler.apply_rz_gate(farm, positions)
	var msg = "✅ Applied Rz-gate to %d qubits" % result.applied_count if result.success else "❌ No gates applied"
	action_performed.emit("apply_rz_gate", result.success, msg)


# NOTE: _action_place_energy_tap_for removed (2026-01) - energy tap system deprecated


## NEW Tool 5 (GATES) - Two-Qubit Gates

func _action_apply_cnot(positions: Array[Vector2i]):
	"""Apply CNOT gate via GateActionHandler."""
	var result = GateActionHandler.apply_cnot(farm, positions)
	var msg = "✅ Applied CNOT to %d qubit pairs" % result.pair_count if result.success else "❌ No gates applied"
	action_performed.emit("apply_cnot", result.success, msg)


func _action_apply_cz(positions: Array[Vector2i]):
	"""Apply CZ gate via GateActionHandler."""
	var result = GateActionHandler.apply_cz(farm, positions)
	var msg = "✅ Applied CZ to %d qubit pairs" % result.pair_count if result.success else "❌ No gates applied"
	action_performed.emit("apply_cz", result.success, msg)


func _action_apply_swap(positions: Array[Vector2i]):
	"""Apply SWAP gate via GateActionHandler."""
	var result = GateActionHandler.apply_swap(farm, positions)
	var msg = "✅ Applied SWAP to %d qubit pairs" % result.pair_count if result.success else "❌ No gates applied"
	action_performed.emit("apply_swap", result.success, msg)


func _action_create_bell_pair(positions: Array[Vector2i]):
	"""Create Bell pair (H + CNOT) - maximally entangled state."""
	var result = GateActionHandler.create_bell_pair(farm, positions)
	var msg = "💑 Created Bell pair |Phi+>" if result.success else result.get("message", "❌ Failed to create Bell pair")
	action_performed.emit("create_bell_pair", result.success, msg)


func _action_disentangle(positions: Array[Vector2i]):
	"""Break entanglement between qubits by measuring and resetting."""
	var result = GateActionHandler.disentangle(farm, positions)
	var msg = "✂️ Disentangled %d qubits via measurement" % result.disentangled_count if result.success else "❌ No qubits disentangled"
	action_performed.emit("disentangle", result.success, msg)


func _action_inspect_entanglement(positions: Array[Vector2i]):
	"""Show entanglement information for selected qubits."""
	var result = GateActionHandler.inspect_entanglement(farm, positions)
	var msg = "No entanglement info"
	if result.success and result.entanglement_info.size() > 0:
		var info = result.entanglement_info[0]
		if info.is_entangled:
			msg = "🔍 Plot %s: entangled with registers %s" % [info.position, info.entangled_with]
		else:
			msg = "🔍 Plot %s: not entangled" % info.position
	action_performed.emit("inspect_entanglement", result.success, msg)


func _extract_emoji_from_action(action: String) -> String:
	"""Extract target emoji from dynamic tap action

	Looks up emoji from cached submenu based on action name.
	This allows dynamic emoji targets beyond hardcoded wheat/mushroom/tomato.

	Args:
		action: Action string like "tap_wheat" or "tap_emoji_12345"

	Returns:
		Emoji string, or empty if not found
	"""
	# Search cached submenu for matching action
	for key in ["Q", "E", "R"]:
		if _cached_submenu.has(key):
			var action_info = _cached_submenu[key]
			if action_info.get("action", "") == action:
				return action_info.get("emoji", "")

	# Fallback: Parse from hardcoded action names
	match action:
		"tap_wheat": return "🌾"
		"tap_mushroom": return "🍄"
		"tap_tomato": return "🍅"
		"tap_fire": return "🔥"
		"tap_water": return "💧"
		"tap_flour": return "💨"
		_: return ""


## Help System

func _print_help():
	"""Print keyboard help to console"""
	var line = ""
	for i in range(60):
		line += "="

	_verbose.info("input", "⌨️", "\n" + line)
	_verbose.info("input", "⌨️", "FARM KEYBOARD CONTROLS (Tool Mode System)")
	_verbose.info("input", "⌨️", line)

	_verbose.info("input", "🛠️", "\nTOOL SELECTION (Numbers 1-4):")
	for tool_num in range(1, 5):
		if TOOL_ACTIONS.has(tool_num):
			var tool = TOOL_ACTIONS[tool_num]
			_verbose.info("input", "🛠️", "  %d = %s" % [tool_num, tool["name"]])

	_verbose.info("input", "⚡", "\nACTIONS (Q/E/R - Context-sensitive):")
	if TOOL_ACTIONS.has(current_tool):
		var tool = TOOL_ACTIONS[current_tool]
		_verbose.info("input", "⚡", "  Current Tool: %s" % tool.get("name", "Unknown"))

		# Get actions for current tool (handle both simple and mode-based tools)
		var tool_actions = null
		if tool.has("actions"):
			tool_actions = tool["actions"]

		if tool_actions and tool_actions.has("Q"):
			_verbose.info("input", "⚡", "  Q = %s" % tool_actions["Q"].get("label", "Action"))
			_verbose.info("input", "⚡", "  E = %s" % tool_actions["E"].get("label", "Action"))
			_verbose.info("input", "⚡", "  R = %s" % tool_actions["R"].get("label", "Action"))
	else:
		_verbose.info("input", "⚡", "  (No tool currently selected)")

	_verbose.info("input", "📍", "\nMULTI-SELECT PLOTS:")
	_verbose.info("input", "📍", "  T/Y/U/I/O/P = Toggle checkbox on plots 1-6")
	_verbose.info("input", "📍", "  [ = Deselect all plots")
	_verbose.info("input", "📍", "  ] = Select all plots (in active biome)")
	_verbose.info("input", "📍", "  Q/E/R = Apply current tool action to ALL selected plots")

	_verbose.info("input", "🎮", "\nMOVEMENT (Legacy - for focus/cursor):")
	_verbose.info("input", "🎮", "  WASD = Move cursor (up/left/down/right)")

	_verbose.info("input", "📋", "\nDEBUG:")
	_verbose.info("input", "📋", "  ? = Show this help")
	_verbose.info("input", "📋", "  I = Toggle info panel")

	_verbose.info("input", "⌨️", line + "\n")


## Tool 6: Biome Management Actions

func _action_assign_plots_to_biome(plots: Array[Vector2i], biome_name: String):
	"""Reassign selected plots to target biome."""
	var result = BiomeHandler.assign_plots_to_biome(farm, plots, biome_name)
	var msg = "%d plots -> %s" % [result.assigned_count, biome_name] if result.success else result.get("message", "Assignment failed")
	action_performed.emit("assign_plots_to_biome", result.success, msg)


func _action_clear_biome_assignment(plots: Array[Vector2i]):
	"""Remove biome assignment from selected plots."""
	var result = BiomeHandler.clear_biome_assignment(farm, plots)
	var msg = "Cleared %d plots" % result.cleared_count if result.success else result.get("message", "Clear failed")
	action_performed.emit("clear_biome_assignment", result.success, msg)


func _action_inspect_plot(plots: Array[Vector2i]):
	"""Show detailed metadata for selected plot(s)

	Displays:
	- Current biome assignment
	- Quantum state (if planted)
	- Entanglement links
	- Bath projection info

	Also opens the biome inspector overlay for the first selected plot
	"""
	if plots.is_empty():
		_verbose.warn("farm", "⚠️", "No plots selected to inspect")
		action_performed.emit("inspect_plot", false, "No plots")
		return

	_verbose.info("farm", "🔍", "PLOT INSPECTION")
	_verbose.info("farm", "🔍", "──────────────────────────────────────────────────────────────────────")

	var inspected_count = 0
	var first_biome_name = ""

	for pos in plots:
		_verbose.info("farm", "📍", "\nPlot %s:" % pos)

		# Biome assignment
		var biome_name = farm.grid.plot_biome_assignments.get(pos, "(unassigned)")
		_verbose.info("farm", "🌍", "   Biome: %s" % biome_name)

		if inspected_count == 0:
			first_biome_name = biome_name

		# Get plot instance
		var plot = farm.grid.get_plot(pos)
		if not plot:
			_verbose.error("farm", "❌", "   Plot not found in grid!")
			continue

		# Plant status
		if plot.is_planted:
			# Get planted crop emojis
			var emojis = plot.get_plot_emojis()
			var planted_emoji = "%s↔%s" % [emojis.get("north", "?"), emojis.get("south", "?")]
			_verbose.info("farm", "🌱", "   Planted: %s" % planted_emoji)
			_verbose.debug("farm", "🌱", "      Has been measured: %s" % ("YES" if plot.has_been_measured else "NO"))

			# Quantum state info (Model C)
			if plot.parent_biome and plot.register_id >= 0:
				var north = plot.north_emoji
				var south = plot.south_emoji
				# Get purity from quantum_computer
				var biome = plot.parent_biome
				var purity = 0.5
				if biome.quantum_computer:
					purity = biome.quantum_computer.get_purity()
				_verbose.debug("quantum", "⚛️", "      State: %s ↔ %s | Purity: %.3f" % [north, south, purity])
		else:
			_verbose.info("farm", "🌱", "   Planted: NO")

		# Entanglement links
		if biome_name != "(unassigned)":
			var biome = farm.grid.biomes.get(biome_name)
			if biome and biome.bell_gates:
				var is_entangled = false
				for gate in biome.bell_gates:
					if pos in gate:
						is_entangled = true
						_verbose.debug("quantum", "🔗", "   Entangled with: %s" % gate)
						break

				if not is_entangled:
					_verbose.debug("quantum", "🔗", "   Entangled: NO")

		# Bath projection (if plot is in a biome)
		if biome_name != "(unassigned)":
			var biome = farm.grid.biomes.get(biome_name)
			if biome and biome.active_projections.has(pos):
				var projection = biome.active_projections[pos]
				_verbose.debug("quantum", "🛁", "   Bath Projection: Active")
				if projection.has("north") and projection.has("south"):
					_verbose.debug("quantum", "🛁", "      North: %s | South: %s" % [projection.north, projection.south])

		inspected_count += 1

	_verbose.info("farm", "🔍", "\n──────────────────────────────────────────────────────────────────────")
	_verbose.info("farm", "✅", "Inspected %d plot(s)" % inspected_count)

	# Open biome inspector overlay for first plot's biome
	if first_biome_name != "" and first_biome_name != "(unassigned)":
		# Get biome inspector overlay from OverlayManager
		var overlay_manager = _get_overlay_manager()
		if overlay_manager and overlay_manager.biome_inspector:
			overlay_manager.biome_inspector.inspect_plot_biome(plots[0], farm)
			_verbose.info("farm", "🌍", "Opened biome inspector for plot %s's biome: %s" % [plots[0], first_biome_name])

	action_performed.emit("inspect_plot", true,
		"Inspected %d plots" % inspected_count)


func _get_overlay_manager():
	"""Navigate scene tree to find OverlayManager

	Hierarchy: FarmInputHandler → FarmUI → FarmView → PlayerShell → OverlayManager
	"""
	# Navigate up the tree to find PlayerShell
	var current = self
	while current:
		if current.has_method("get_class"):
			var node_class = current.get_class()
			# Check if it's PlayerShell (or has overlay_manager property)
			if current.has_node("OverlayManager") or current.get("overlay_manager"):
				return current.get("overlay_manager")

		# Try by node name
		if current.name == "PlayerShell" or current.name.contains("Shell"):
			if current.has_node("OverlayManager"):
				return current.get_node("OverlayManager")
			elif current.get("overlay_manager"):
				return current.get("overlay_manager")

		current = current.get_parent()

	push_warning("_get_overlay_manager: Could not find OverlayManager in scene tree")
	return null

## ═══════════════════════════════════════════════════════════════════════════
## Phase 4 UI: Pump & Reset Operations (Gozinta Channels)
## ═══════════════════════════════════════════════════════════════════════════

func _action_pump_to_wheat(plots: Array[Vector2i]):
	"""Pump population to wheat (Model B - Lindblad Operations)."""
	var result = LindbladHandler.pump_to_wheat(farm, plots)
	var summary = ""
	for pair in result.get("pumped_pairs", {}).keys():
		summary += "%s×%d " % [pair, result.pumped_pairs[pair]]
	var msg = "%s Pumped wheat on %d plots | %s" % ["✅" if result.success else "❌", result.pump_count, summary]
	action_performed.emit("pump_to_wheat", result.success, msg)


# NOTE: _action_reset_to_pure/_action_reset_to_mixed removed (2026-01)


## ═══════════════════════════════════════════════════════════════════════════
## Lindblad Control Operations (Direct Quantum Computer Access)
## ═══════════════════════════════════════════════════════════════════════════

func _action_lindblad_drive(plots: Array[Vector2i]):
	"""Apply Lindblad drive to increase population on selected plots."""
	var result = LindbladHandler.lindblad_drive(farm, plots)
	var summary = ""
	for emoji in result.get("driven_emojis", {}).keys():
		summary += "%s×%d " % [emoji, result.driven_emojis[emoji]]
	var msg = "%s Drive on %d plots | %s" % ["✅" if result.success else "❌", result.driven_count, summary]
	action_performed.emit("lindblad_drive", result.success, msg)


func _action_lindblad_decay(plots: Array[Vector2i]):
	"""Apply Lindblad decay to decrease population on selected plots."""
	var result = LindbladHandler.lindblad_decay(farm, plots)
	var summary = ""
	for emoji in result.get("decayed_emojis", {}).keys():
		summary += "%s×%d " % [emoji, result.decayed_emojis[emoji]]
	var msg = "%s Decay on %d plots | %s" % ["✅" if result.success else "❌", result.decayed_count, summary]
	action_performed.emit("lindblad_decay", result.success, msg)


func _action_lindblad_transfer(plots: Array[Vector2i]):
	"""Transfer population between two selected plots."""
	var result = LindbladHandler.lindblad_transfer(farm, plots)
	var msg = result.get("message", "")
	if result.success:
		msg = "✅ Transfer: %s -> %s (%.0f%%)" % [result.from_emoji, result.to_emoji, result.transfer_amount * 100]
	else:
		msg = result.get("message", "❌ Transfer failed")
	action_performed.emit("lindblad_transfer", result.success, msg)


func _action_peek_state(plots: Array[Vector2i]):
	"""Non-destructive peek at quantum state probabilities."""
	var result = SystemHandler.peek_state(farm, plots)
	if not result.success:
		action_performed.emit("peek_state", false, result.get("message", "No quantum states found"))
		return
	var peek_strings: Array[String] = []
	for peek in result.peek_results:
		var north_pct = peek.north_probability * 100.0
		var south_pct = peek.south_probability * 100.0
		peek_strings.append("%s: up%.0f%% down%.0f%%" % [peek.emoji, north_pct, south_pct])
	var summary = " | ".join(peek_strings)
	action_performed.emit("peek_state", true, "Peek: %s" % summary)


# ============================================================================
# ACTION VALIDATION - Check if actions can succeed without executing
# ============================================================================

func can_execute_action(action_key: String) -> bool:
	"""Check if action for given key can succeed with current selection

	Called by ActionPreviewRow to determine button highlighting.
	Uses any-valid strategy: returns true if at least 1 plot can succeed.

	Args:
		action_key: "Q", "E", or "R"

	Returns:
		bool: true if action would succeed on at least one selected plot
	"""
	if current_submenu != "":
		return _can_execute_submenu_action(action_key)
	else:
		return _can_execute_tool_action(action_key)


func _can_execute_tool_action(action_key: String) -> bool:
	"""Check if tool action can succeed (not in submenu)"""
	var selected_plots = plot_grid_display.get_selected_plots() if plot_grid_display else []

	if selected_plots.is_empty():
		return false

	# Use ToolConfig API to properly resolve action name
	var action = ToolConfig.get_action_name(current_tool, action_key)

	# Route to specific validation based on action type
	match action:
		# ═══════════════════════════════════════════════════════════════
		# v2 PROBE Tool (Tool 1) - Core gameplay loop
		# ═══════════════════════════════════════════════════════════════
		"explore":
			return _can_execute_explore()
		"measure":
			return _can_execute_measure(selected_plots)  # Pass selected plots for Issue #4 fix
		"pop":
			return _can_execute_pop(selected_plots)  # Pass selected plots for Issue #4 fix

		# ═══════════════════════════════════════════════════════════════
		# v2 GATES Tool (Tool 2) - 1-qubit gates
		# ═══════════════════════════════════════════════════════════════
		"apply_pauli_x", "apply_hadamard", "apply_pauli_z", "apply_ry":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# v2 ENTANGLE Tool (Tool 3) - 2-qubit gates
		# ═══════════════════════════════════════════════════════════════
		"apply_cnot", "apply_swap", "apply_cz":
			return selected_plots.size() >= 2  # Need 2 plots for 2-qubit gates
		"create_bell_pair":
			return selected_plots.size() >= 2  # Need 2 plots for Bell pair
		"disentangle", "inspect_entanglement":
			return true  # Available if any plots selected

		# Entanglement cluster operations
		"cluster", "measure_trigger", "remove_gates":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# v2 INDUSTRY Tool (Tool 4)
		# ═══════════════════════════════════════════════════════════════
		"place_mill", "place_market", "place_kitchen":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# BUILD MODE - Tool 1 (BIOME)
		# ═══════════════════════════════════════════════════════════════
		"submenu_biome_assign":
			return true  # Opens submenu
		"clear_biome_assignment", "inspect_plot":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# BUILD MODE - Tool 2 (ICON)
		# ═══════════════════════════════════════════════════════════════
		"submenu_icon_assign":
			return true  # Opens submenu
		"icon_swap", "icon_clear":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# BUILD MODE - Tool 3 (LINDBLAD)
		# ═══════════════════════════════════════════════════════════════
		"lindblad_drive", "lindblad_decay", "lindblad_transfer":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# BUILD MODE - Tool 4 (QUANTUM) with F-cycling
		# System mode (F=0)
		# ═══════════════════════════════════════════════════════════════
		"system_reset", "system_snapshot", "system_debug":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# BUILD MODE - Tool 4 (QUANTUM) with F-cycling
		# Phase mode (F=1)
		# ═══════════════════════════════════════════════════════════════
		"apply_s_gate", "apply_t_gate", "apply_sdg_gate":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# BUILD MODE - Tool 4 (QUANTUM) with F-cycling
		# Rotation mode (F=2)
		# ═══════════════════════════════════════════════════════════════
		"apply_rx_gate", "apply_ry_gate", "apply_rz_gate":
			return true  # Available if plots selected

		_:
			return false


func _can_execute_explore() -> bool:
	"""Check if EXPLORE action is available (v2 PROBE Tool 1)

	EXPLORE binds an unbound terminal to a register in the current biome.
	Available when: unbound terminals exist AND biome has unbound registers.
	"""
	if not farm or not farm.plot_pool:
		return false

	# Need unbound terminals
	if farm.plot_pool.get_unbound_count() == 0:
		return false

	# Get biome from current selection
	var biome = _get_current_biome()
	if not biome:
		return false

	# Must have unbound registers
	var probabilities = biome.get_register_probabilities()
	return not probabilities.is_empty()


func _can_execute_measure(selected_plots: Array[Vector2i] = []) -> bool:
	"""Check if MEASURE action is available (v2 PROBE Tool 1)

	MEASURE collapses an active terminal (bound but not measured).
	Available when: active terminal exists in selected biome.
	Uses selected_plots[0] to match execution behavior (Issue #4 fix).
	"""
	if not farm or not farm.plot_pool:
		return false

	# Use selected plots if available, otherwise fall back to current_selection
	var target_pos = selected_plots[0] if not selected_plots.is_empty() else current_selection
	var biome = farm.grid.get_biome_for_plot(target_pos) if farm.grid else null
	if not biome:
		return false

	# Must have active terminal (bound but not measured) in this biome
	for terminal in farm.plot_pool.get_active_terminals():
		if terminal.bound_biome == biome:  # Object identity instead of string comparison (Issue #5)
			return true
	return false


func _can_execute_pop(selected_plots: Array[Vector2i] = []) -> bool:
	"""Check if POP action is available (v2 PROBE Tool 1)

	POP harvests a measured terminal and unbinds it.
	Available when: measured terminal exists in selected biome.
	Uses selected_plots[0] to match execution behavior (Issue #4 fix).
	"""
	if not farm or not farm.plot_pool:
		return false

	# Use selected plots if available, otherwise fall back to current_selection
	var target_pos = selected_plots[0] if not selected_plots.is_empty() else current_selection
	var biome = farm.grid.get_biome_for_plot(target_pos) if farm.grid else null
	if not biome:
		return false

	# Must have measured terminal in this biome
	for terminal in farm.plot_pool.get_measured_terminals():
		if terminal.bound_biome == biome:  # Object identity instead of string comparison (Issue #5)
			return true
	return false


func _get_current_biome():
	"""Get biome for current selection (helper for availability checks)"""
	if not farm or not farm.grid:
		return null
	return farm.grid.get_biome_for_plot(current_selection)


func _can_execute_submenu_action(action_key: String) -> bool:
	"""Check if submenu action can succeed"""
	var selected_plots = plot_grid_display.get_selected_plots() if plot_grid_display else []

	if selected_plots.is_empty():
		return false

	var submenu = _cached_submenu if not _cached_submenu.is_empty() else ToolConfig.get_submenu(current_submenu)

	# Check if entire submenu disabled
	if submenu.get("_disabled", false):
		return false

	var action_info = submenu.get(action_key, {})
	var action = action_info.get("action", "")

	# Empty action = locked slot
	if action == "":
		return false

	# Route to specific validation
	match action:
		"plant_wheat":
			return _can_plant_type("wheat", selected_plots)
		"plant_mushroom":
			return _can_plant_type("mushroom", selected_plots)
		"plant_tomato":
			return _can_plant_type("tomato", selected_plots)
		"plant_fire":
			return _can_plant_type("fire", selected_plots)
		"plant_water":
			return _can_plant_type("water", selected_plots)
		"plant_flour":
			return _can_plant_type("flour", selected_plots)
		"plant_ice":
			return _can_plant_type("ice", selected_plots)
		"plant_desert":
			return _can_plant_type("desert", selected_plots)
		_:
			return false


func _can_plant_type(plant_type: String, plots: Array[Vector2i]) -> bool:
	"""Check if we can plant this specific type on any selected plot

	PARAMETRIC (Phase 6): Queries biome capabilities instead of BUILD_CONFIGS.
	Follows same pattern as Farm.build() for cost determination.
	"""
	if not farm or plots.is_empty():
		return false

	# PARAMETRIC: Determine cost based on type
	var cost = {}
	var biome_required = ""

	# Check infrastructure buildings
	if Farm.INFRASTRUCTURE_COSTS.has(plant_type):
		cost = Farm.INFRASTRUCTURE_COSTS[plant_type]

	# Check gather actions
	elif Farm.GATHER_ACTIONS.has(plant_type):
		var gather_config = Farm.GATHER_ACTIONS[plant_type]
		cost = gather_config.get("cost", {})
		biome_required = gather_config.get("biome_required", "")

	# Otherwise, query biome capabilities for plant cost
	else:
		# Check first plot's biome for capability
		var first_pos = plots[0]
		var plot_biome = farm.grid.get_biome_for_plot(first_pos)
		if not plot_biome:
			return false

		# Find capability for this plant type
		var capability = null
		for cap in plot_biome.get_plantable_capabilities():
			if cap.plant_type == plant_type:
				capability = cap
				break

		if not capability:
			return false

		cost = capability.cost
		biome_required = plot_biome.name if capability.requires_biome else ""

	# Check if we can afford it
	if not farm.economy.can_afford_cost(cost):
		return false

	# Check at least ONE plot is valid (any-valid strategy)
	for pos in plots:
		var plot = farm.grid.get_plot(pos)
		if not plot:
			continue

		# Must be empty
		if plot.is_planted:
			continue

		# Check biome requirement if specified
		if biome_required != "":
			var plot_biome_name = farm.grid.plot_biome_assignments.get(pos, "")
			if plot_biome_name != biome_required:
				continue

		# Found at least one valid plot!
		return true

	return false


# ═══════════════════════════════════════════════════════════════════════════
# v2 ARCHITECTURE: GLOBAL CONTROLS
# ═══════════════════════════════════════════════════════════════════════════

func _toggle_evolution_pause() -> void:
	"""Toggle quantum evolution pause state (Spacebar)

	When paused:
	- Quantum evolution stops (density matrix doesn't evolve)
	- Actions (EXPLORE, MEASURE, POP, gates) still work
	- Visual indicator shows paused state
	"""
	evolution_paused = not evolution_paused

	# Notify biomes to pause/resume evolution
	if farm and farm.grid and farm.grid.biomes:
		for biome_name in farm.grid.biomes:
			var biome = farm.grid.biomes[biome_name]
			if biome and biome.has_method("set_evolution_paused"):
				biome.set_evolution_paused(evolution_paused)

	var status = "PAUSED" if evolution_paused else "RUNNING"
	_verbose.info("input", "⏸️" if evolution_paused else "▶️",
		"Evolution %s (Spacebar to toggle)" % status)

	pause_toggled.emit(evolution_paused)
	action_performed.emit("toggle_pause", true, "Evolution %s" % status.to_lower())


func _toggle_build_play_mode() -> void:
	"""Toggle between BUILD and PLAY modes (Tab)

	PLAY mode (default):
	- Tool 1: PROBE (Explore/Measure/Pop)
	- Tool 2: GATES (with F-cycling)
	- Tool 3: ENTANGLE (with F-cycling)
	- Tool 4: INJECT

	BUILD mode:
	- Tool 1: BIOME (assign plots to biomes)
	- Tool 2: ICON (configure icons)
	- Tool 3: LINDBLAD (dissipation control)
	- Tool 4: SYSTEM (global config)
	"""
	var new_mode = ToolConfig.toggle_mode()

	# Reset to tool 1 when switching modes
	current_tool = 1
	current_submenu = ""
	_cached_submenu = {}

	# BUILD MODE PAUSE: Pause quantum evolution when entering BUILD mode
	# This allows safe modification of biome structure (adding qubits, etc.)
	var is_build_mode = (new_mode == "build")
	_set_all_biomes_paused(is_build_mode)

	_verbose.info("input", "🔧" if new_mode == "build" else "🎮",
		"Switched to %s MODE (Tab to toggle)" % new_mode.to_upper())

	mode_changed.emit(new_mode)

	# Emit tool_changed with new tool info
	var tool_info = ToolConfig.get_tool(current_tool)
	tool_changed.emit(current_tool, tool_info)

	action_performed.emit("toggle_mode", true, "%s mode" % new_mode.capitalize())


func _cycle_current_tool_mode() -> void:
	"""Cycle F-mode for current tool (F key)

	Only works for tools with F-cycling enabled:
	- Tool 2 (GATES): Basic → Phase → 2-Qubit
	- Tool 3 (ENTANGLE): Bell → Cluster → Manipulate
	"""
	if not ToolConfig.has_f_cycling(current_tool):
		_verbose.debug("input", "🔄", "Tool %d doesn't support F-cycling" % current_tool)
		action_performed.emit("cycle_mode", false, "This tool doesn't have modes")
		return

	var new_index = ToolConfig.cycle_tool_mode(current_tool)
	if new_index < 0:
		return

	var mode_label = ToolConfig.get_tool_mode_label(current_tool)
	var tool_name = ToolConfig.get_tool_name(current_tool)

	_verbose.info("input", "🔄",
		"%s mode: %s (F to cycle)" % [tool_name, mode_label])

	tool_mode_cycled.emit(current_tool, new_index, mode_label)

	# Update action preview by re-emitting tool_changed
	var tool_info = ToolConfig.get_tool(current_tool)
	tool_changed.emit(current_tool, tool_info)

	action_performed.emit("cycle_mode", true, "%s: %s" % [tool_name, mode_label])


func is_evolution_paused() -> bool:
	"""Get current pause state"""
	return evolution_paused


func get_current_game_mode() -> String:
	"""Get current game mode (play or build)"""
	return ToolConfig.get_mode()


func _set_all_biomes_paused(paused: bool) -> void:
	"""Pause or resume quantum evolution on all biomes.

	Called when switching between PLAY and BUILD modes.
	BUILD mode pauses evolution to allow safe biome modification.
	"""
	if not farm or not farm.grid or not farm.grid.biomes:
		return

	for biome_name in farm.grid.biomes:
		var biome = farm.grid.biomes[biome_name]
		if biome and biome.has_method("set_evolution_paused"):
			biome.set_evolution_paused(paused)


# ═══════════════════════════════════════════════════════════════════════════════
# BUILD MODE: Tool 2 (Icon) - Icon Management Actions
# ═══════════════════════════════════════════════════════════════════════════════

func _action_icon_assign(plots: Array[Vector2i], emoji: String):
	"""Assign a vocabulary emoji to the biome's quantum system."""
	var gsm = get_node_or_null("/root/GameStateManager")
	var result = IconHandler.icon_assign(farm, plots, emoji, gsm)
	var msg = "Added %s/%s to quantum system" % [result.get("north_emoji", "?"), result.get("south_emoji", "?")] if result.success else result.get("message", "Failed")
	action_performed.emit("icon_assign", result.success, msg)


func _action_icon_swap(plots: Array[Vector2i]):
	"""Swap north/south emojis on selected plot(s)."""
	var result = IconHandler.icon_swap(farm, plots)
	var msg = "Swapped icons on %d plots" % result.swap_count if result.success else "No planted plots to swap"
	action_performed.emit("icon_swap", result.success, msg)


func _action_icon_clear(plots: Array[Vector2i]):
	"""Clear icon assignment from selected plot(s)."""
	var result = IconHandler.icon_clear(farm, plots)
	var msg = "Cleared icons on %d plots" % result.clear_count if result.success else "No plots to clear"
	action_performed.emit("icon_clear", result.success, msg)


# ═══════════════════════════════════════════════════════════════════════════════
# BUILD MODE: Tool 4 (System) - System Control Actions
# ═══════════════════════════════════════════════════════════════════════════════

func _action_system_reset(plots: Array[Vector2i]):
	"""Reset quantum bath to initial/thermal state."""
	var result = SystemHandler.system_reset(farm, plots, current_selection)
	var msg = "Reset %s to ground state" % result.biome_name if result.success else result.get("message", "Reset failed")
	action_performed.emit("system_reset", result.success, msg)


func _action_system_snapshot(plots: Array[Vector2i]):
	"""Save current quantum state snapshot."""
	var result = SystemHandler.system_snapshot(farm, plots, current_selection)
	var msg = "Snapshot: %s (dim=%d)" % [result.biome_name, result.dimension] if result.success else result.get("message", "Snapshot failed")
	action_performed.emit("system_snapshot", result.success, msg)


func _action_system_debug(plots: Array[Vector2i]):
	"""Toggle debug visualization mode.

	Enables/disables verbose quantum state logging and debug overlays.
	"""
	# Toggle verbose debug mode
	var new_state := false

	if _verbose:
		# Toggle quantum category between info and debug levels
		var current_level = _verbose.get_category_level("quantum") if _verbose.has_method("get_category_level") else 1
		if current_level >= 2:  # Already debug
			_verbose.set_category_level("quantum", 1)  # Back to info
			new_state = false
		else:
			_verbose.set_category_level("quantum", 2)  # Enable debug
			new_state = true

		_verbose.info("system", "🐛", "Debug mode: %s" % ("ON" if new_state else "OFF"))

	# Also toggle any debug overlays
	var overlay_manager = _get_overlay_manager()
	if overlay_manager and overlay_manager.has_method("toggle_debug_mode"):
		overlay_manager.toggle_debug_mode()

	action_performed.emit("system_debug", true,
		"🐛 Debug mode: %s" % ("ON" if new_state else "OFF"))

