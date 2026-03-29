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
@onready var _verbose = get_node("/root/VerboseConfig")

const OverlayManager = preload("res://UI/Managers/OverlayManager.gd")
const OverlayStackManager = preload("res://UI/Managers/OverlayStackManager.gd")
const QuestManager = preload("res://Core/Quests/QuestManager.gd")
const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")
const LoggerConfigPanel = preload("res://UI/Overlays/LoggerConfigPanel.gd")
# QuantumHUDPanel REMOVED - content merged into InspectorOverlay (N key)
const QuantumModeStatusIndicator = preload("res://UI/Widgets/QuantumModeStatusIndicator.gd")
const BiomeSelectionRowClass = preload("res://UI/Widgets/BiomeSelectionRow.gd")

## Farm overlay keys (CVBN) - game content overlays
## These close each other but not shell menus
const FARM_OVERLAY_KEYS = {
	KEY_C: "quests",
	KEY_V: "semantic_map",
	KEY_B: "biome_detail",
	KEY_N: "inspector",
}

## Shell menu keys (ZX) - system-level panels
## These close each other AND close farm overlays
const SHELL_MENU_KEYS = [KEY_Z, KEY_X]

var current_farm_ui = null  # FarmUI instance (from scene)
var overlay_manager = null
var quest_manager: QuestManager = null
var farm: Node = null
var farm_ui_container: Control = null
var action_bar_manager = null  # ActionBarManager - manages bottom toolbars
var action_preview_row: Control = null  # Cached reference from ActionBarManager
var layout_manager: Node = null  # UILayoutManager
var logger_config_panel = null  # Logger configuration UI
var snapshot_service = null  # Snapshot/diagnostics node (set by BootManager)
var quantum_instrument = null  # Unified action interface (set by BootManager)
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

	Shell menus (Z, X, ESC): System-level panels
	Farm overlays (C, V, B, N): Game content overlays
	TAB: Build/Play mode toggle (only when no menu active)
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

	# Shell menu keys (Z, X)
	if keycode == KEY_B and event.shift_pressed:
		_toggle_shell_menu("balance_workbench")
		return true
	if keycode == KEY_Z:
		_toggle_shell_menu("controls")
		return true
	if keycode == KEY_X:
		_toggle_shell_menu("logger")
		return true

	# Farm overlay keys (C, V, B, N)
	if FARM_OVERLAY_KEYS.has(keycode):
		if keycode == KEY_C and overlay_manager and overlay_manager.quest_board and overlay_manager.quest_board.visible:
			overlay_manager.open_quest_board_faction_browser()
			return true
		_toggle_farm_overlay(FARM_OVERLAY_KEYS[keycode])
		return true

	# TAB only works when no menu is active
	if _any_menu_open():
		return false

	if keycode == KEY_TAB:
		_toggle_build_play_mode()
		return true

	return false


# =============================================================================
# MENU MANAGEMENT (unified for all menus)
# =============================================================================

func _any_menu_open() -> bool:
	"""Check if any menu (shell or farm) is currently open."""
	if overlay_stack and not overlay_stack.is_empty():
		return true

	# Check escape menu (via stack or visibility)
	if overlay_manager and overlay_manager.escape_menu:
		if overlay_stack and overlay_stack.has_overlay(overlay_manager.escape_menu):
			return true
		elif overlay_manager.escape_menu.visible:
			return true
	# Check controls overlay (shell menu, but in v2 system)
	if overlay_manager and overlay_manager.v2_overlays.has("controls"):
		var controls = overlay_manager.v2_overlays["controls"]
		if controls.visible:
			return true
	# Check farm overlays
	if overlay_manager:
		for name in FARM_OVERLAY_KEYS.values():
			if overlay_manager.v2_overlays.has(name):
				var overlay = overlay_manager.v2_overlays[name]
				if overlay.visible:
					return true
	return false


func _close_all_menus() -> void:
	"""Close all open menus (shell and farm)."""
	# Close escape menu via overlay stack (if on stack)
	if overlay_manager and overlay_manager.escape_menu and overlay_stack:
		if overlay_stack.has_overlay(overlay_manager.escape_menu):
			overlay_stack.pop_overlay(overlay_manager.escape_menu)
		elif overlay_manager.escape_menu.visible:
			overlay_manager.escape_menu.deactivate()
	# Close all v2 overlays (includes controls + logger + farm overlays)
	if overlay_manager:
		overlay_manager.close_all_v2_overlays()


func _open_escape_menu() -> void:
	"""Open escape menu (closes other menus first)."""
	_close_all_menus()
	if overlay_manager and overlay_manager.escape_menu and overlay_stack:
		overlay_stack.push(overlay_manager.escape_menu)


func _toggle_shell_menu(menu_name: String) -> void:
	"""Toggle a shell menu (Z=controls, X=logger).

	Shell menus close all other menus when opening.
	"""
	match menu_name:
		"balance_workbench":
			advanced_mode_enabled = _resolve_advanced_mode()
			if overlay_manager and overlay_manager.v2_overlays.has("balance_workbench"):
				var wb = overlay_manager.v2_overlays["balance_workbench"]
				if wb and wb.has_method("set_advanced_mode"):
					wb.set_advanced_mode(advanced_mode_enabled)
				if wb and wb.has_method("set_snapshot_service"):
					wb.set_snapshot_service(snapshot_service)
				if wb and wb.has_method("set_quantum_instrument"):
					wb.set_quantum_instrument(quantum_instrument)
				if wb.visible:
					wb.deactivate()
					return
			_close_all_menus()
			if overlay_manager:
				overlay_manager.open_v2_overlay("balance_workbench")

		"controls":
			# Check if controls is already open
			if overlay_manager and overlay_manager.v2_overlays.has("controls"):
				var controls = overlay_manager.v2_overlays["controls"]
				if controls.visible:
					controls.deactivate()
					return
			# Close everything and open controls
			_close_all_menus()
			if overlay_manager:
				overlay_manager.open_v2_overlay("controls")

		"logger":
			# Logger is registered as a v2 overlay — toggle via OverlayManager
			if overlay_manager:
				overlay_manager.toggle_v2_overlay("logger")


func _toggle_farm_overlay(overlay_name: String) -> void:
	"""Toggle a farm overlay (C, V, B, N keys).

	Farm overlays close all other menus when opening.
	"""
	if not overlay_manager:
		return

	# Check if this overlay is already open
	if overlay_manager.v2_overlays.has(overlay_name):
		var overlay = overlay_manager.v2_overlays[overlay_name]
		if overlay.visible:
			var opened_frame = int(_overlay_open_frame.get(overlay_name, -999999))
			var frame_delta = Engine.get_process_frames() - opened_frame
			# Guard against duplicate key/touch events causing open-then-instant-close flash.
			if frame_delta <= 1:
				_verbose.debug("ui", "⏱️", "Ignoring rapid re-toggle for '%s' (frame delta=%d)" % [overlay_name, frame_delta])
				return
			overlay.deactivate()
			_overlay_open_frame.erase(overlay_name)
			return

	# Close everything and open the requested overlay
	_close_all_menus()
	if overlay_manager.open_v2_overlay(overlay_name):
		_overlay_open_frame[overlay_name] = Engine.get_process_frames()

func _toggle_build_play_mode() -> void:
	"""Toggle between BUILD and PLAY modes (TAB key)

	This is handled here (in _input) because Godot's focus navigation
	intercepts TAB before _unhandled_input() runs.
	"""
	const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")

	var group = ToolConfig.get_current_group()
	var new_mode_idx = ToolConfig.cycle_group_mode(group)
	var new_mode = ToolConfig.get_group_mode_name(group)
	_verbose.info("input", "🔧" if new_mode_idx > 0 else "🎮",
		"Switched to %s MODE (Tab to toggle)" % new_mode.to_upper())

	# Update ToolSelectionRow UI
	if action_bar_manager:
		var tool_row = action_bar_manager.get_tool_row()
		if tool_row and tool_row.has_method("refresh_for_mode"):
			tool_row.refresh_for_mode(new_mode)

	# QuantumInstrumentInput handles mode changes for gameplay


func _on_restart_pressed() -> void:
	"""Handle R or Shift+R - reload the most recently saved or loaded game.

	Delegates to GameStateManager.request_restart(), which sets pending_restart_slot
	and triggers reload_current_scene(). FarmView picks up the slot on next _ready().
	"""
	_verbose.info("ui", "🔄", "Restart - requesting reload of last active save")

	# Reset music before the scene goes away
	if has_node("/root/MusicManager"):
		var music = get_node("/root/MusicManager")
		if music.has_method("reset"):
			music.reset()

	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("request_restart"):
		gsm.request_restart()
	else:
		# Fallback: plain scene reload (no save context)
		get_tree().paused = false
		get_tree().reload_current_scene()


func _on_dev_restart_pressed() -> void:
	_on_restart_pressed()


func _push_modal(modal: Control) -> void:
	"""Add modal/overlay to stack"""
	if overlay_stack and not overlay_stack.has_overlay(modal):
		overlay_stack.push(modal)
		_verbose.debug("input", "📚", "Overlay stack: %s" % overlay_stack.get_stack_info())


func _pop_modal(modal: Control) -> void:
	"""Remove modal/overlay from stack"""
	if overlay_stack:
		overlay_stack.pop_overlay(modal)
		_verbose.debug("input", "📚", "Overlay stack: %s" % overlay_stack.get_stack_info())


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

	# Store reference for quest board updates
	action_preview_row = action_bar_manager.get_action_row()

	# Connect tool selection signal
	var tool_row = action_bar_manager.get_tool_row()
	if tool_row and tool_row.has_signal("tool_selected"):
		tool_row.tool_selected.connect(_on_tool_selected_from_bar)

	# Connect action button signal - will be connected to QuantumInstrumentInput later
	# (after farm setup completes and input_handler is available)

	_verbose.info("ui", "✅", "Action bars created")
	# ═══════════════════════════════════════════════════════════════

	# Create overlay manager and add to overlay layer
	overlay_manager = OverlayManager.new()
	overlay_layer.add_child(overlay_manager)

	# Setup overlay manager with proper dependencies
	overlay_manager.setup(layout_manager, null, null, null, quest_manager)

	# Connect overlay stack and overlay manager bidirectionally
	if overlay_stack:
		overlay_stack.set_overlay_manager(overlay_manager)
		overlay_manager.set_overlay_stack(overlay_stack)

	# Initialize overlays (C/V/N/Z/ESC menus - K moved to Z, freeing K/L for homerow)
	overlay_manager.create_overlays(overlay_layer)

	# Create logger config panel (debug tool, press X to toggle) — registered as v2 overlay
	logger_config_panel = LoggerConfigPanel.new()
	overlay_layer.add_child(logger_config_panel)
	overlay_manager.register_v2_overlay("logger", logger_config_panel)
	_verbose.info("ui", "✅", "Logger config panel created (press X to toggle)")

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
	var gsm = get_tree().root.get_node_or_null("/root/GameStateManager")
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
	"""Connect signals from overlays to manage unified overlay stack.

	Note: _push_modal() and _pop_modal() delegate to OverlayStackManager.
	These signal handlers keep overlays synchronized with the stack.
	"""
	var quest_board = overlay_manager.get("quest_board")
	if quest_board:
		quest_board.board_closed.connect(func():
			_pop_modal(quest_board)
			_restore_action_toolbar()
		)
		quest_board.board_opened.connect(func():
			_update_action_toolbar_for_overlay(quest_board)
		)
		quest_board.slot_selection_changed.connect(func(_slot_state: int, _is_locked: bool):
			_update_action_toolbar_for_overlay(quest_board)
		)
		_verbose.info("ui", "✅", "Quest board signals connected")

	if overlay_manager.escape_menu:
		overlay_manager.escape_menu.resume_pressed.connect(func():
			_pop_modal(overlay_manager.escape_menu)
		)
		overlay_manager.escape_menu.save_pressed.connect(func():
			_push_modal(overlay_manager.save_load_menu)
		)
		overlay_manager.escape_menu.load_pressed.connect(func():
			_push_modal(overlay_manager.save_load_menu)
		)
		overlay_manager.escape_menu.quantum_settings_pressed.connect(func():
			_pop_modal(overlay_manager.escape_menu)
			if overlay_manager.quantum_config_ui:
				overlay_manager.toggle_quantum_config()
		)
		overlay_manager.escape_menu.restart_pressed.connect(func():
			_on_restart_pressed()
		)
		overlay_manager.escape_menu.dev_restart_pressed.connect(func():
			_on_dev_restart_pressed()
		)
		_verbose.info("ui", "✅", "Escape menu signals connected")

	if overlay_manager.save_load_menu:
		overlay_manager.save_load_menu.menu_closed.connect(func():
			_pop_modal(overlay_manager.save_load_menu)
		)
		_verbose.info("ui", "✅", "Save/Load menu signals connected")


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

	# Already connected? Skip (check for tool_group_changed signal)
	if input_handler.has_signal("tool_group_changed") and input_handler.tool_group_changed.get_connections().size() > 0:
		return

	# Connect quest_manager to economy (CRITICAL for quest completion!)
	if quest_manager and farm_ui.farm and farm_ui.farm.economy:
		quest_manager.connect_to_economy(farm_ui.farm.economy)
		_verbose.info("ui", "✅", "QuestManager connected to economy")
		_connect_quest_manager_to_biomes(farm_ui)

	# ═══════════════════════════════════════════════════════════════
	# KEYBOARD → UI: QuantumInstrumentInput signals update UI
	# ═══════════════════════════════════════════════════════════════

	# Tool group changes (1-4 keys) → update ToolSelectionRow highlight
	if input_handler.has_signal("tool_group_changed"):
		input_handler.tool_group_changed.connect(func(group: int):
			if action_bar_manager:
				action_bar_manager.select_tool(group)
				# Also refresh ActionPreviewRow for new group's Q/E/R actions
				var action_row = action_bar_manager.get_action_row()
				if action_row and action_row.has_method("update_for_tool"):
					action_row.update_for_tool(group)
		)
		_verbose.info("ui", "✔", "tool_group_changed → ToolSelectionRow")

	# Mode cycling (F key) → refresh ActionPreviewRow labels
	if input_handler.has_signal("mode_cycled"):
		input_handler.mode_cycled.connect(func(_group: int, _mode_idx: int, _mode_label: String):
			if action_bar_manager:
				var action_row = action_bar_manager.get_action_row()
				if action_row and action_row.has_method("update_for_tool"):
					# Get current group and refresh display
					var current_group = input_handler.get_current_tool_group() if input_handler.has_method("get_current_tool_group") else 1
					action_row.update_for_tool(current_group)
		)
		_verbose.info("ui", "✔", "mode_cycled → ActionPreviewRow refresh")


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
	var abm = get_node_or_null("/root/ActiveBiomeManager")

	if abm and abm.has_signal("active_biome_changed"):
		var biome_callable = Callable(self, "_handle_active_biome_change").bind(farm_ref)
		if not abm.active_biome_changed.is_connected(biome_callable):
			abm.active_biome_changed.connect(biome_callable)
		var active_biome = abm.get_active_biome() if abm.has_method("get_active_biome") else "StarterForest"
		biome_callable.call(active_biome, "")
	else:
		_handle_active_biome_change("StarterForest", "", farm_ref)

	_quest_biome_connected = true

	# Submenu changes → update ActionPreviewRow with submenu actions
	if input_handler.has_signal("submenu_changed"):
		input_handler.submenu_changed.connect(func(submenu_name: String, submenu_actions: Dictionary):
			if action_bar_manager:
				action_bar_manager.update_for_submenu(submenu_name, submenu_actions)
		)
		_verbose.info("ui", "✔", "submenu_changed → ActionPreviewRow submenu")

	# Action performed → refresh availability buttons
	if input_handler.has_signal("action_performed"):
		input_handler.action_performed.connect(func(_action: String, _result: Dictionary):
			if action_bar_manager:
				var action_row = action_bar_manager.get_action_row()
				if action_row and action_row.has_method("update_action_availability"):
					action_row.update_action_availability()
		)
		_verbose.info("ui", "✔", "action_performed → ActionPreviewRow availability")

	# ═══════════════════════════════════════════════════════════════
	# UI → KEYBOARD: Button clicks trigger QuantumInstrumentInput
	# ═══════════════════════════════════════════════════════════════

	if action_bar_manager:
		# ToolSelectionRow clicks → select tool group
		var tool_row = action_bar_manager.get_tool_row()
		if tool_row and tool_row.has_signal("tool_selected"):
			# Disconnect old handler if present
			if tool_row.tool_selected.is_connected(_on_tool_selected_from_bar):
				tool_row.tool_selected.disconnect(_on_tool_selected_from_bar)
			# Connect to QuantumInstrumentInput's internal method
			tool_row.tool_selected.connect(func(tool_num: int):
				const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
				ToolConfig.select_group(tool_num)
				input_handler.tool_group_changed.emit(tool_num)
			)
			_verbose.info("ui", "✔", "ToolSelectionRow → tool_group_changed")

		# ActionPreviewRow clicks → execute Q/E/R action
		var action_row = action_bar_manager.get_action_row()
		if action_row and action_row.has_signal("action_pressed"):
			action_row.action_pressed.connect(func(action_key: String):
				# Call QuantumInstrumentInput's internal action method
				if input_handler.has_method("_perform_action"):
					input_handler._perform_action(action_key)
			)
			_verbose.info("ui", "✔", "ActionPreviewRow → _perform_action")

		# Inject references for action availability checking
		action_row.quantum_input = input_handler
		_verbose.info("ui", "✔", "ActionPreviewRow.quantum_input injected")

	_verbose.info("ui", "✔", "QuantumInstrumentInput connected to action bars")

	# ═══════════════════════════════════════════════════════════════
	# SELECTION CHANGES → Refresh action availability
	# ═══════════════════════════════════════════════════════════════

	if action_bar_manager and farm_ui and farm_ui.farm and farm_ui.plot_grid_display:
		action_bar_manager.inject_references(farm_ui.farm, farm_ui.plot_grid_display)

		# Selection changes → update action button availability
		if farm_ui.plot_grid_display.has_signal("selection_count_changed"):
			farm_ui.plot_grid_display.selection_count_changed.connect(func(_count: int):
				var action_row = action_bar_manager.get_action_row()
				if action_row and action_row.has_method("update_action_availability"):
					action_row.update_action_availability()
			)
			_verbose.info("ui", "✔", "Selection changes → action availability")

	# Resource changes → update action button availability
	if farm_ui.farm.economy and farm_ui.farm.economy.has_signal("resource_changed"):
		farm_ui.farm.economy.resource_changed.connect(func(_emoji, _amount):
			var action_row = action_bar_manager.get_action_row()
			if action_row and action_row.has_method("update_action_availability"):
				action_row.update_action_availability()
		)
		_verbose.info("ui", "✔", "Resource changes → action availability")


func _handle_active_biome_change(biome_name: String, _old_biome: String, farm_ref: Node) -> void:
	if not quest_manager or not farm_ref or not farm_ref.grid or not farm_ref.grid.biomes or biome_name == "":
		return

	var biome = farm_ref.grid.biomes.get(biome_name, null)
	if biome:
		quest_manager.connect_to_biome(biome)

## ACTION TOOLBAR UPDATES (for quest board context)

func _update_action_toolbar_for_overlay(overlay: Control) -> void:
	"""Update action toolbar to show context-specific actions from an overlay"""
	if action_bar_manager:
		action_bar_manager.update_for_overlay(overlay)

func _restore_action_toolbar() -> void:
	"""Restore action toolbar to normal tool mode"""
	if action_bar_manager:
		action_bar_manager.restore_normal_mode()


func _on_tool_selected_from_bar(tool_num: int) -> void:
	"""Handle tool selection from action bar"""
	# Update action bar display
	if action_bar_manager:
		action_bar_manager.select_tool(tool_num)

	# Forward to FarmUI if available
	if current_farm_ui and current_farm_ui.has_method("_on_tool_selected"):
		current_farm_ui._on_tool_selected(tool_num)
