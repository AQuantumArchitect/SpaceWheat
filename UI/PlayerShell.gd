## PlayerShell - Player-level UI layer
## Handles:
## - Overlay/menu system (ESC menu, V vocabulary, C contracts, etc)
## - Player inventory/resource panel
## - Keyboard help, settings
## - Farm loading/switching (when implemented)
##
## This layer STAYS when farm changes

class_name PlayerShell
extends Control

# Access autoload safely (avoids compile-time errors)
@onready var _verbose = InstrumentLocator.resolve_verbose_config(self)

const OverlayManager = preload("res://UI/Managers/OverlayManager.gd")
const OverlayStackManager = preload("res://UI/Managers/OverlayStackManager.gd")
const UIContextController = preload("res://UI/Managers/UIContextController.gd")
const MenuRegistry = preload("res://UI/Core/MenuRegistry.gd")
const QuestManager = preload("res://Core/Quests/QuestManager.gd")
const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")
const LoggerConfigPanel = preload("res://UI/Overlays/LoggerConfigPanel.gd")
const InstrumentLocator = preload("res://Core/Instrumentation/InstrumentLocator.gd")
# QuantumHUDPanel REMOVED - content merged into InspectorOverlay (N key)
const QuantumModeStatusIndicator = preload("res://UI/Widgets/QuantumModeStatusIndicator.gd")
const BiomeSelectionRowClass = preload("res://UI/Widgets/BiomeSelectionRow.gd")

var current_farm_ui = null  # FarmUI instance (from scene)
var overlay_manager = null
var quest_manager: QuestManager = null
var farm: Node = null
var farm_ui_container: Control = null
var action_bar_manager = null  # ActionBarManager - manages bottom toolbars
var ui_context_controller: UIContextController = null
var layout_manager: Node = null  # UILayoutManager
var logger_config_panel = null  # Logger configuration UI
var snapshot_service = null  # Snapshot/diagnostics node (set by BootManager)
var quantum_instrument = null  # Unified action interface (set by BootManager)
var input_handler = null  # Projection of current_farm_ui.input_handler for diagnostics/tests
var advanced_mode_enabled: bool = false
# quantum_hud_panel REMOVED - content merged into InspectorOverlay (N key)
var quantum_mode_indicator: QuantumModeStatusIndicator = null  # Current quantum mode display
var biome_tab_bar: BiomeSelectionRowClass = null  # Top bar for biome selection
var _quest_biome_connected: bool = false
var _overlay_open_frame: Dictionary = {}  # overlay_name -> Engine frame opened

## Unified Overlay Stack Management (replaces modal_stack)
var overlay_stack: OverlayStackManager = null


func _input(event: InputEvent) -> void:
	"""Layer 1: High-priority input routing (overlays + shell actions)"""
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	var stack_size = overlay_stack.size() if overlay_stack else 0
	_verbose.debug("input", "⌨️", "PlayerShell._input() KEY: %s, overlay_stack: %d" % [event.keycode, stack_size])

	# LAYER 1: Overlay input (highest priority) - uses unified OverlayStackManager
	if overlay_stack and not overlay_stack.is_empty():
		var top_overlay = overlay_stack.get_top()
		_verbose.debug("input", "→", "Routing to overlay: %s" % top_overlay.name)
		var consumed = overlay_stack.route_input(event)
		_verbose.debug("input", "→", "Overlay consumed: %s" % consumed)
		if consumed:
			_mark_input_handled()
			return

	# LAYER 2: Shell actions
	if _handle_shell_action(event):
		_mark_input_handled()
		return

	# LAYER 3: Fall through to Farm._unhandled_input()


func _mark_input_handled() -> void:
	# During restart PlayerShell can receive input while not in tree.
	if not is_inside_tree():
		return
	var vp := get_viewport()
	if vp:
		vp.set_input_as_handled()


func _handle_shell_action(event: InputEvent) -> bool:
	"""Handle shell-level actions (overlay toggles, menu)

	All menus are mutually exclusive - opening one closes others.

	Shell menus (Z, X, M, ESC): system-level panels
	Game overlays (C, V, B, N): game content overlays
	TAB: current-tool mode-cycle alias (only when no menu active)
	"""
	var keycode = event.keycode

	# ESC - closes any menu, or opens escape menu if nothing open
	if keycode == KEY_ESCAPE:
		if _any_menu_open():
			_close_all_menus()
			return true
		else:
			_open_escape_menu()
			return true

	var menu_entry = MenuRegistry.get_menu_for_keycode(keycode)
	if not menu_entry.is_empty():
		var overlay_name = str(menu_entry.get("overlay_name", ""))
		var menu_group = str(menu_entry.get("menu_group", ""))
		if menu_group == "game":
			_toggle_farm_overlay(overlay_name)
		else:
			_toggle_shell_menu(overlay_name)
		return true

	# TAB only works when no menu is active
	if _any_menu_open():
		return false

	if keycode == KEY_TAB:
		_cycle_current_tool_mode_alias()
		return true

	return false


# =============================================================================
# MENU MANAGEMENT (unified for all menus)
# =============================================================================

func _any_menu_open() -> bool:
	"""Check if any menu (shell or farm) is currently open."""
	if overlay_stack and not overlay_stack.is_empty():
		return true
	if overlay_manager and overlay_manager.quantum_config_ui and overlay_manager.quantum_config_ui.visible:
		return true
	return false


func _close_all_menus() -> void:
	"""Close all open menus (shell and farm)."""
	if overlay_manager:
		overlay_manager.close_all_overlays()
		if overlay_manager.quantum_config_ui and overlay_manager.quantum_config_ui.visible:
			overlay_manager.quantum_config_ui.visible = false


func _open_escape_menu() -> void:
	"""Open escape menu (closes other menus first)."""
	_close_all_menus()
	if overlay_manager:
		overlay_manager.open_overlay("escape_menu")


func _toggle_shell_menu(menu_name: String) -> void:
	"""Toggle a shell menu (Z=controls, X=system, M=workbench).

	Shell menus close all other menus when opening.
	"""
	if not overlay_manager:
		return

	match menu_name:
		"escape_menu":
			overlay_manager.toggle_overlay("escape_menu")

		"balance_workbench":
			advanced_mode_enabled = _resolve_advanced_mode()
			if overlay_manager.has_overlay("balance_workbench"):
				var wb = overlay_manager.get_overlay("balance_workbench")
				if wb and wb.has_method("set_advanced_mode"):
					wb.set_advanced_mode(advanced_mode_enabled)
				if wb and wb.has_method("set_snapshot_service"):
					wb.set_snapshot_service(snapshot_service)
				if wb and wb.has_method("set_quantum_instrument"):
					wb.set_quantum_instrument(quantum_instrument)
			overlay_manager.toggle_overlay("balance_workbench")

		"controls":
			overlay_manager.toggle_overlay("controls")


func _toggle_farm_overlay(overlay_name: String) -> void:
	"""Toggle a farm overlay (C, V, B, N keys).

	Farm overlays close all other menus when opening.
	"""
	if not overlay_manager:
		return

	var overlay = overlay_manager.get_overlay(overlay_name) if overlay_manager.has_overlay(overlay_name) else null
	if overlay and overlay_stack and overlay_stack.has_overlay(overlay):
		var opened_frame = int(_overlay_open_frame.get(overlay_name, -999999))
		var frame_delta = Engine.get_process_frames() - opened_frame
		# Guard against duplicate key/touch events causing open-then-instant-close flash.
		if frame_delta <= 1:
			_verbose.debug("ui", "⏱️", "Ignoring rapid re-toggle for '%s' (frame delta=%d)" % [overlay_name, frame_delta])
			return

	overlay_manager.toggle_overlay(overlay_name)
	if overlay and overlay_stack and overlay_stack.has_overlay(overlay):
		_overlay_open_frame[overlay_name] = Engine.get_process_frames()
	else:
		_overlay_open_frame.erase(overlay_name)

func _cycle_current_tool_mode_alias() -> void:
	"""Cycle the current tool group from TAB.

	TAB is kept as a keyboard alias because Godot focus handling intercepts it
	before the gameplay input layer sees it.
	"""
	const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")

	var group = ToolConfig.get_current_group()
	var new_mode_idx = ToolConfig.cycle_group_mode(group)
	var new_mode = ToolConfig.get_group_mode_name(group)
	_verbose.info("input", "⇥",
		"TAB alias cycled tool %d to %s" % [group, new_mode])

	# QuantumInstrumentInput handles mode changes for gameplay


func _on_restart_pressed() -> void:
	"""Handle R or Shift+R - reload the most recently saved or loaded game.

	Delegates to GameStateManager.request_restart(), which sets pending_restart_slot
	and triggers reload_current_scene(). FarmView picks up the slot on next _ready().
	"""
	_verbose.info("ui", "🔄", "Restart - requesting reload of last active save")

	# Reset music before the scene goes away
	var music = InstrumentLocator.resolve_music_manager(self)
	if music and music.has_method("reset"):
		music.reset()

	var gsm = InstrumentLocator.resolve_game_state_manager(self)
	if gsm and gsm.has_method("request_restart"):
		gsm.request_restart()
	else:
		# Fallback: plain scene change (no save context)
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/FarmView.tscn")


func _on_dev_restart_pressed() -> void:
	# Dev restart is handled entirely by OverlayManager (hard reset path)
	pass


func _ready() -> void:
	"""Initialize player shell UI - children defined in scene"""
	_verbose.info("boot", "🎪", "PlayerShell initializing...")
	advanced_mode_enabled = _resolve_advanced_mode()

	# Add to group so overlay buttons can find us
	add_to_group("player_shell")

	# CRITICAL: Ensure PlayerShell fills its parent (FarmView)
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Process input even when game is paused (for ESC menu, etc.)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Create unified overlay stack manager (before any overlays)
	overlay_stack = OverlayStackManager.new()
	add_child(overlay_stack)
	_verbose.info("ui", "✅", "OverlayStackManager created")

	# Get reference to containers from scene
	farm_ui_container = get_node("FarmUIContainer")
	var overlay_layer = get_node("OverlayLayer")
	var action_bar_layer = get_node("ActionBarLayer")

	# CRITICAL: FarmUIContainer must pass input through to PlotGridDisplay/QuantumForceGraph
	farm_ui_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_verbose.info("ui", "✅", "FarmUIContainer mouse_filter set to IGNORE for plot/bubble input")

	# CRITICAL: ActionBarLayer needs explicit size for ActionBarManager to work
	# It has full anchors (0,0,1,1) which will maintain this size, but during _ready()
	# the anchors haven't taken effect yet. Set size to viewport size (what anchors will do).
	# Use set_deferred to avoid warning about opposite anchors.
	var viewport_size = get_viewport_rect().size
	action_bar_layer.set_deferred("size", viewport_size)
	_verbose.info("ui", "✅", "ActionBarLayer sized for action bar creation: %.0f × %.0f" % [viewport_size.x, viewport_size.y])

	# Create and initialize UILayoutManager
	const UILayoutManager = preload("res://UI/Managers/UILayoutManager.gd")
	layout_manager = UILayoutManager.new()
	add_child(layout_manager)

	# Create quest manager (before overlays, since overlays need it)
	quest_manager = QuestManager.new()
	add_child(quest_manager)
	_verbose.info("ui", "✅", "Quest manager created")

	# ═══════════════════════════════════════════════════════════════
	# CREATE ACTION BARS DIRECTLY IN ActionBarLayer
	# ═══════════════════════════════════════════════════════════════
	const ActionBarManager = preload("res://UI/Managers/ActionBarManager.gd")
	action_bar_manager = ActionBarManager.new()
	action_bar_manager.set_layout_manager(layout_manager)
	action_bar_manager.create_action_bars(action_bar_layer)

	_verbose.info("ui", "✅", "Action bars created")
	# ═══════════════════════════════════════════════════════════════

	# Create overlay manager and add to overlay layer
	overlay_manager = OverlayManager.new()
	overlay_layer.add_child(overlay_manager)

	# Setup overlay manager with proper dependencies
	overlay_manager.setup(layout_manager, null, null, null, quest_manager)

	# Connect overlay stack and overlay manager bidirectionally
	if overlay_stack:
		overlay_manager.set_overlay_stack(overlay_stack)

	# Initialize overlays (ZXCVBNM top-level menus; ESC opens/closes system menu)
	overlay_manager.create_overlays(overlay_layer)

	# Create logger config panel (debug tool, currently unbound from top-level keys)
	logger_config_panel = LoggerConfigPanel.new()
	overlay_layer.add_child(logger_config_panel)
	overlay_manager.register_overlay("logger", logger_config_panel)
	_verbose.info("ui", "✅", "Logger config panel created (unbound debug overlay)")

	# Create UI context controller after all bars/overlays are present.
	ui_context_controller = UIContextController.new()
	add_child(ui_context_controller)
	ui_context_controller.setup(action_bar_manager, overlay_stack, overlay_manager)

	# QuantumHUDPanel REMOVED - content merged into InspectorOverlay (N key)

	# Create quantum mode status indicator (top-right corner)
	quantum_mode_indicator = QuantumModeStatusIndicator.new()
	quantum_mode_indicator.name = "QuantumModeIndicator"
	overlay_layer.add_child(quantum_mode_indicator)
	_verbose.info("ui", "✅", "Quantum mode indicator created")

	# Create biome selection row (top-center for biome selection)
	biome_tab_bar = BiomeSelectionRowClass.new()
	biome_tab_bar.name = "BiomeSelectionRow"
	overlay_layer.add_child(biome_tab_bar)
	_verbose.info("ui", "✅", "Biome tab bar created")
	_apply_top_strip_layout()
	if layout_manager and layout_manager.has_signal("layout_changed"):
		if not layout_manager.layout_changed.is_connected(_on_layout_changed):
			layout_manager.layout_changed.connect(_on_layout_changed)

	# Connect overlay signals
	_connect_overlay_signals()

	_verbose.info("ui", "✅", "Overlay manager created")
	_verbose.info("boot", "✅", "PlayerShell ready")


func _resolve_advanced_mode() -> bool:
	var env_mode = OS.get_environment("SPACEWHEAT_ADVANCED_MODE").strip_edges().to_lower()
	if env_mode in ["1", "true", "yes", "on"]:
		return true
	if env_mode in ["0", "false", "no", "off"]:
		return false
	var gsm = InstrumentLocator.resolve_game_state_manager(self)
	if gsm and "current_state" in gsm and gsm.current_state:
		if "advanced_mode_enabled" in gsm.current_state:
			return bool(gsm.current_state.advanced_mode_enabled)
	return OS.is_debug_build()


func _on_layout_changed(_layout: Dictionary) -> void:
	_apply_top_strip_layout()


func _apply_top_strip_layout() -> void:
	if not quantum_mode_indicator or not biome_tab_bar:
		return

	var top_offset = 54.0
	var tab_height = 40.0
	var side_inset = 200.0
	var indicator_size = Vector2(200, 40)

	if layout_manager:
		if layout_manager.has_method("get_resource_bar_height") and layout_manager.has_method("get_top_strip_gap"):
			top_offset = layout_manager.get_resource_bar_height() + layout_manager.get_top_strip_gap()
		if layout_manager.has_method("get_biome_tab_height"):
			tab_height = layout_manager.get_biome_tab_height()
		if layout_manager.has_method("get_top_strip_side_inset"):
			side_inset = layout_manager.get_top_strip_side_inset()
		if layout_manager.has_method("get_quantum_indicator_size"):
			indicator_size = layout_manager.get_quantum_indicator_size()

	quantum_mode_indicator.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	quantum_mode_indicator.offset_left = -side_inset
	quantum_mode_indicator.offset_top = top_offset
	quantum_mode_indicator.custom_minimum_size = indicator_size

	biome_tab_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	biome_tab_bar.offset_top = top_offset
	biome_tab_bar.offset_bottom = top_offset + tab_height
	biome_tab_bar.offset_left = side_inset
	biome_tab_bar.offset_right = -side_inset


func _connect_overlay_signals() -> void:
	"""Connect non-toolbar overlay signals that still matter at the shell layer."""
	var quest_board = overlay_manager.get("quest_board")
	if quest_board:
		_verbose.info("ui", "✅", "Quest board signals connected")

	if overlay_manager.escape_menu:
		overlay_manager.escape_menu.quantum_settings_pressed.connect(func():
			if overlay_manager.quantum_config_ui:
				overlay_manager.toggle_quantum_config_ui()
		)
		overlay_manager.escape_menu.restart_pressed.connect(func():
			_on_restart_pressed()
		)
		overlay_manager.escape_menu.dev_restart_pressed.connect(func():
			_on_dev_restart_pressed()
		)
		_verbose.info("ui", "✅", "Escape menu signals connected")


func get_farm_ui():
	"""Get the currently loaded FarmUI instance"""
	return current_farm_ui


func load_farm_ui(farm_ui: Control) -> void:
	"""Load an already-instantiated FarmUI into the farm container.

	Called by BootManager.boot() in Stage 3C to add the FarmUI.
	Action bars are already created in _ready(), so no reparenting needed.
	"""
	# Store reference
	current_farm_ui = farm_ui

	# Add to container
	if farm_ui_container:
		farm_ui_container.add_child(farm_ui)
		_verbose.info("ui", "✔", "FarmUI mounted in container")
		if layout_manager and farm_ui.has_method("inject_layout_manager"):
			farm_ui.inject_layout_manager(layout_manager)

	# Note: farm_setup_complete fires before input_handler is created.
	# The actual connection is done by BootManager calling connect_to_quantum_input() later.
	# We don't connect here anymore to avoid the "input_handler not ready" warning.
	if not farm_ui.has_signal("farm_setup_complete"):
		push_error("FarmUI missing farm_setup_complete signal!")
	else:
		_verbose.info("ui", "⏳", "Waiting for BootManager to create QuantumInstrumentInput...")

func connect_to_quantum_input() -> void:
	"""Connect to QuantumInstrumentInput after it's created.

	Called by BootManager after input_handler is created and injected into farm_ui.
	Wires the Musical Spindle input system to the UI components.
	"""
	var farm_ui = current_farm_ui
	if not farm_ui or not farm_ui.input_handler:
		push_warning("connect_to_quantum_input called but input_handler not ready!")
		return

	var input_handler = farm_ui.input_handler
	self.input_handler = input_handler

	# Connect quest_manager to economy (CRITICAL for quest completion!)
	if quest_manager and farm_ui.farm and farm_ui.farm.economy:
		quest_manager.connect_to_economy(farm_ui.farm.economy)
		_verbose.info("ui", "✅", "QuestManager connected to economy")
		_connect_quest_manager_to_biomes(farm_ui)

	if ui_context_controller:
		ui_context_controller.bind_quantum_input(input_handler)
		ui_context_controller.bind_farm_ui(farm_ui)
		_verbose.info("ui", "✔", "UIContextController bound to QuantumInstrumentInput")


func _connect_quest_manager_to_biomes(farm_ui: Control) -> void:
	if _quest_biome_connected:
		return
	if not quest_manager or not farm_ui or not farm_ui.farm:
		return

	var input_handler = farm_ui.input_handler
	if not input_handler:
		push_warning("_connect_quest_manager_to_biomes called before QuantumInstrumentInput ready")
		return

	var farm_ref = farm_ui.farm
	var abm = InstrumentLocator.resolve_active_biome_manager(self)

	if abm and abm.has_signal("active_biome_changed"):
		var biome_callable = Callable(self, "_handle_active_biome_change").bind(farm_ref)
		if not abm.active_biome_changed.is_connected(biome_callable):
			abm.active_biome_changed.connect(biome_callable)
		var active_biome = abm.get_active_biome() if abm.has_method("get_active_biome") else "StarterForest"
		biome_callable.call(active_biome, "")
	else:
		_handle_active_biome_change("StarterForest", "", farm_ref)

	_quest_biome_connected = true


func _handle_active_biome_change(biome_name: String, _old_biome: String, farm_ref: Node) -> void:
	if not quest_manager or not farm_ref or not farm_ref.grid or not farm_ref.grid.has_biomes() or biome_name == "":
		return

	var biome = farm_ref.grid.get_biome(biome_name)
	if biome:
		quest_manager.connect_to_biome(biome)
