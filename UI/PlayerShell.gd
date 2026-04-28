## PlayerShell - Player-level UI layer
## Handles:
## - Overlay/menu system (ESC menu, V signature, C contracts, etc)
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
const FpsDisplay = preload("res://UI/HUD/FpsDisplay.gd")
const HintToast = preload("res://UI/Widgets/HintToast.gd")

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
var fps_display: Control = null  # Top-left FPS projection display
var _hint_toast_stack: VBoxContainer = null  # Bottom-right stack of ephemeral hint toasts
var _quest_biome_connected: bool = false
var _overlay_open_frame: Dictionary = {}  # overlay_name -> Engine frame opened

## Unified Overlay Stack Management (replaces modal_stack)
var overlay_stack: OverlayStackManager = null

## Global pause flag — driven by E (pause) / F (resume) peek in _input.
## See UI/Core/KEYBOARD_GRAMMAR.md "Mechanics — side-effect peek".
## Read by Farm._physics_process to short-circuit sim evolution.
var paused: bool = false
signal paused_changed(is_paused: bool)


func _input(event: InputEvent) -> void:
	"""Layer 1: High-priority input routing (overlays + shell actions).

	Before the exclusive consume-or-fall-through chain runs, we peek at
	E and F as side-effects (pause / resume). The peek does NOT consume
	the event — primary verbs still fire through normal dispatch. See
	UI/Core/KEYBOARD_GRAMMAR.md "Mechanics — side-effect peek".
	"""
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	# Side-effect peek: E pauses, F resumes. No set_input_as_handled,
	# no return — fall through to normal dispatch so tools/menus still
	# receive their primary E/F verb.
	if event.keycode == KEY_E:
		_set_global_paused(true)
	elif event.keycode == KEY_F:
		_set_global_paused(false)

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


## Spawn an ephemeral corner-toast with bbcode text. Used by the Socialite
## "Tip" verb (and any future quick-feedback action) to whisper a hint to
## the player without blocking input or stealing focus.
func show_hint(bbcode_text: String) -> void:
	if not _hint_toast_stack or not is_inside_tree():
		return
	var toast := HintToast.new()
	_hint_toast_stack.add_child(toast)
	toast.show_text(bbcode_text)


func _set_global_paused(value: bool) -> void:
	"""Set the global sim-pause flag. Idempotent. Read by Farm._physics_process."""
	if paused == value:
		return
	paused = value
	paused_changed.emit(paused)
	_verbose.info("input", "⏸" if value else "▶", "Sim %s" % ("paused" if value else "resumed"))


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

	# , / . — cycle previous/next top-level menu (mirror of [ / ] for biomes).
	if keycode == KEY_COMMA:
		_cycle_menu_overlay(-1)
		return true
	if keycode == KEY_PERIOD:
		_cycle_menu_overlay(1)
		return true

	# [ / ] — universal tab cycle. When a Surface is open, cycle its frame_ids;
	# otherwise cycle the active biome in the main game.
	if keycode == KEY_BRACKETLEFT:
		if _any_menu_open():
			if _cycle_active_surface_frame(-1):
				return true
			return false
		_cycle_active_biome(-1)
		return true
	if keycode == KEY_BRACKETRIGHT:
		if _any_menu_open():
			if _cycle_active_surface_frame(1):
				return true
			return false
		_cycle_active_biome(1)
		return true

	# TAB only works when no menu is active
	if _any_menu_open():
		return false

	if keycode == KEY_TAB:
		_cycle_current_tool_mode_alias()
		return true

	# WASD — crawl the biome × plot grid. Mirrors menu navigation so the
	# same fingers move the same way in main game and in any open surface.
	#   A/D = prev/next plot in the active biome
	#   W/S = prev/next biome (cycles ActiveBiomeManager)
	if keycode == KEY_A:
		_step_active_plot(-1)
		return true
	if keycode == KEY_D:
		_step_active_plot(1)
		return true
	if keycode == KEY_W:
		_cycle_active_biome(-1)
		return true
	if keycode == KEY_S:
		_cycle_active_biome(1)
		return true

	return false


func _step_active_plot(delta: int) -> void:
	if input_handler and input_handler.has_method("step_active_plot"):
		input_handler.step_active_plot(delta)


func _cycle_active_surface_frame(step: int) -> bool:
	"""Cycle the frame_ids of the topmost Surface overlay. Returns true if a
	cycle was performed, false if no Surface with frame_ids is on top."""
	if not overlay_stack or overlay_stack.is_empty():
		return false
	var top = overlay_stack.get_top()
	if top == null:
		return false
	if not top.has_method("cycle_frame"):
		return false
	if not ("frame_ids" in top):
		return false
	var ids = top.frame_ids
	if not (ids is Array) or ids.is_empty():
		return false
	top.cycle_frame(step)
	return true


func _cycle_active_biome(delta: int) -> void:
	"""Cycle to the previous/next biome via ActiveBiomeManager."""
	var abm = InstrumentLocator.resolve_active_biome_manager(self)
	if not abm:
		return
	if delta > 0 and abm.has_method("cycle_next"):
		abm.cycle_next()
	elif delta < 0 and abm.has_method("cycle_prev"):
		abm.cycle_prev()


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

func _cycle_menu_overlay(delta: int) -> void:
	"""Cycle to the previous/next top-level menu (, and . keys).

	Mirrors the [ / ] biome-cycle pattern. If no top-level menu is currently
	open, the first (delta>0) or last (delta<0) menu opens for discoverability.
	"""
	if not overlay_manager or not overlay_stack:
		return

	var menus = MenuRegistry.get_top_level_menus()
	if menus.is_empty():
		return

	var current_idx := -1
	for i in range(menus.size()):
		var entry_name = str(menus[i].get("overlay_name", ""))
		if entry_name == "" or not overlay_manager.has_overlay(entry_name):
			continue
		var entry_overlay = overlay_manager.get_overlay(entry_name)
		if entry_overlay and overlay_stack.has_overlay(entry_overlay):
			current_idx = i
			break

	var n = menus.size()
	var next_idx: int = 0 if delta > 0 else n - 1
	if current_idx >= 0:
		next_idx = (current_idx + delta + n) % n

	var next_entry = menus[next_idx]
	var next_name = str(next_entry.get("overlay_name", ""))
	var next_group = str(next_entry.get("menu_group", ""))
	if next_name == "":
		return
	if next_group == "game":
		_toggle_farm_overlay(next_name)
	else:
		_toggle_shell_menu(next_name)


func _cycle_current_tool_mode_alias() -> void:
	"""Cycle the active archetype frame's sub-mode (Tab).

	Canonical mode-cycle key after the keyboard-grammar refactor (used to
	be F). TAB is kept because Godot focus handling intercepts it before
	the gameplay input layer sees it, so PlayerShell intercepts first.
	Direct selection is also available on number keys 1/2/3.
	"""
	const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")

	var frame_name: String = ToolConfig.get_current_frame()
	if frame_name == ToolConfig.FRAME_ACE:
		return
	var new_mode_idx = ToolConfig.cycle_frame_mode(frame_name)
	if new_mode_idx < 0:
		return
	var new_mode = ToolConfig.get_frame_mode_name(frame_name)
	_verbose.info("input", "⇥",
		"TAB cycled frame %s → %s" % [frame_name, new_mode])
	# Notify QuantumInstrumentInput so action-bar listeners refresh.
	if input_handler and input_handler.has_method("_on_mode_changed"):
		input_handler._on_mode_changed(frame_name, new_mode_idx)



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

	# Create FPS display (top-left projection display)
	fps_display = FpsDisplay.new()
	fps_display.name = "FpsDisplay"
	overlay_layer.add_child(fps_display)
	_verbose.info("ui", "✅", "FPS display created")

	# Hint-toast stack (bottom-right corner; ephemeral pop-ups)
	_hint_toast_stack = VBoxContainer.new()
	_hint_toast_stack.name = "HintToastStack"
	_hint_toast_stack.alignment = BoxContainer.ALIGNMENT_END
	_hint_toast_stack.add_theme_constant_override("separation", 6)
	_hint_toast_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_toast_stack.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint_toast_stack.offset_left = -340
	_hint_toast_stack.offset_top = -260
	_hint_toast_stack.offset_right = -16
	_hint_toast_stack.offset_bottom = -120
	overlay_layer.add_child(_hint_toast_stack)
	_apply_top_strip_layout()
	if layout_manager and layout_manager.has_signal("layout_changed"):
		InstrumentLocator.safe_connect(layout_manager.layout_changed, _on_layout_changed)

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

	if fps_display:
		fps_display.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		fps_display.offset_right = -8
		fps_display.offset_top = 4


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
		InstrumentLocator.safe_connect(abm.active_biome_changed, biome_callable)
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
