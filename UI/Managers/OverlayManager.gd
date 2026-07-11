class_name OverlayManager
extends Node

# Access autoload safely (avoids compile-time errors)
@onready var _verbose = get_node_or_null("/root/VerboseConfig")
## Centralizes management of all overlays (Quests, Knowledge, Network, Map, System Menu)
## Handles overlay visibility, positioning, and menu actions.
## Save/load is owned by the X system surface (EscapeMenu, Keep tab) — there is
## no standalone save/load overlay.

# Preload dependencies

# Unified overlay stack system
const OverlayBaseClass = preload("res://UI/Core/OverlayBase.gd")

# Overlay instances
var quest_board: QuestBoard  # New modal 4-slot quest board (primary interface)
var escape_menu: EscapeMenu
# keyboard_hint_button REMOVED - controls/help now lives on Z
var biome_inspector: BiomeInspectorOverlay  # Biome inspection overlay
var map_meta_overlay: MapMetaOverlay  # Biome × faction map overlay
var touch_button_bar: Control  # Touch-friendly panel buttons for the top-level menu row
var icon_detail_panel  # Icon information detail panel

# Unified overlay registry
var overlays: Dictionary = {}  # _name → OverlayBase instance
var _pending_pair_scope: Array = []  # [biome_a_name, biome_b_name] passed from N → C
# Active overlay is tracked by OverlayStackManager
var inspector_overlay = null  # Density matrix inspector
var controls_overlay = null  # Keyboard controls reference
var atlas_overlay = null  # QubitAtlasOverlay
var welcome_overlay = null  # First-run welcome / how-to-play splash

# Reference to unified overlay stack (set by PlayerShell)
var overlay_stack = null  # OverlayStackManager

# Dependencies
var layout_manager
var quest_manager
var faction_manager
var farm  # Farm reference for biome inspector

# Signals for menu actions
signal menu_resumed()

# Overlay stack signals
signal overlay_changed(overlay_name: String, is_open: bool)

# HAUNTED UI FIX: Prevent duplicate overlay creation
var _overlays_created: bool = false


func setup(layout_mgr, _icon_sys, faction_mgr, _conspiracy_net, quest_mgr = null) -> void:
	# Initialize OverlayManager with required dependencies.
	# _icon_sys + _conspiracy_net stay positional to match the PlayerShell call site.
	layout_manager = layout_mgr
	faction_manager = faction_mgr
	quest_manager = quest_mgr
	_verbose.info("ui", "📋", "OverlayManager initialized")


func set_overlay_stack(stack) -> void:
	# Set reference to OverlayStackManager for overlay management.
	overlay_stack = stack
	_verbose.info("ui", "📋", "OverlayManager connected to OverlayStackManager")


func _get_current_biome(farm_ref):
	# Get the current active biome object from farm (not the hardcoded biotic_flux)
	if not farm_ref:
		return null

	var current_biome_name := ""
	var observation = farm_ref.observation_frame if "observation_frame" in farm_ref else null
	if observation and observation.has_method("get_neutral_biome"):
		current_biome_name = observation.get_neutral_biome()
	elif farm_ref and farm_ref.has_method("get_current_biome"):
		var biome = farm_ref.get_current_biome()
		if biome and "biome_name" in biome:
			current_biome_name = str(biome.biome_name)

	if current_biome_name.is_empty():
		return null

	# Look up biome object in grid
	if farm_ref.grid and farm_ref.grid.has_biome(current_biome_name):
		return farm_ref.grid.get_biome(current_biome_name)

	return null


func _resolve_farm() -> Node:
	# Resolve the active farm through the current runtime authority graph.
	if farm and is_instance_valid(farm):
		return farm
	return InstrumentLocator.resolve_active_farm(self)


## ========================================
## VISIBILITY-BASED PROCESS MANAGEMENT
## ========================================

func _setup_visibility_processing(panel: Node) -> void:
	# Configure panel to enable/disable processing based on visibility.

	# When panel becomes visible, enable processing (_process() runs).
	# When panel becomes invisible, disable processing (saves CPU).
	if not panel:
		return

	# Disable processing initially if panel is hidden
	if panel.has_method("set_process"):
		if "visible" in panel and not panel.visible:
			panel.set_process(false)
			_verbose.debug("ui", "⏸️", "Disabled processing for hidden panel: %s" % panel.name)

	# Connect visibility change signal to toggle processing
	if panel.has_signal("visibility_changed"):
		panel.visibility_changed.connect(func():
			if panel.has_method("set_process"):
				panel.set_process(panel.visible)
				if panel.visible:
					_verbose.debug("ui", "▶️", "Enabled processing for panel: %s" % panel.name)
				else:
					_verbose.debug("ui", "⏸️", "Disabled processing for panel: %s" % panel.name)
		)


func create_overlays(parent: Control) -> void:
	# Create all overlay panels and add them to parent
	# HAUNTED UI FIX: Guard against duplicate overlay creation
	if _overlays_created:
		_verbose.warn("ui", "⚠️", "OverlayManager.create_overlays() called multiple times, skipping duplicate creation")
		return
	_overlays_created = true

	if not layout_manager:
		push_error("OverlayManager: layout_manager not set before create_overlays()")
		return

	# Force parent (OverlayLayer) to update its size based on anchors
	parent.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.set("layout_mode", 1)  # Control.LayoutMode.ANCHORS (enum not exposed to GDScript)
	# Force immediate size update
	if parent.is_inside_tree():
		var viewport_size = parent.get_viewport().get_visible_rect().size
		parent.set_size(viewport_size)
		_verbose.debug("ui", "📏", "OverlayLayer forced to size: %s" % viewport_size)

	# Create Quest Board (New Modal 4-Slot System - Primary Interface)
	quest_board = QuestBoard.new()
	if layout_manager:
		quest_board.set_layout_manager(layout_manager)
	if quest_manager:
		quest_board.set_quest_manager(quest_manager)
	quest_board.visible = false
	quest_board.z_index = 14
	parent.add_child(quest_board)

	# Connect signals
	quest_board.quest_accepted.connect(_on_quest_board_quest_accepted)
	quest_board.quest_completed.connect(_on_quest_board_quest_completed)
	quest_board.quest_abandoned.connect(_on_quest_board_quest_abandoned)
	_verbose.info("ui", "📋", "Quest Board created (C key)")
	_setup_visibility_processing(quest_board)

	# SimStatsOverlay merged into InspectorOverlay (N key) — perf stats live there.

	# Create Escape Menu
	escape_menu = EscapeMenu.new()
	if layout_manager and escape_menu.has_method("set_layout_manager"):
		escape_menu.set_layout_manager(layout_manager)
	escape_menu.z_index = 18  # System tier - below action bars
	escape_menu.deactivate()
	parent.add_child(escape_menu)
	register_overlay("escape_menu", escape_menu)

	# Connect escape menu signals
	escape_menu.resume_pressed.connect(_on_menu_resume)
	_verbose.info("ui", "🎮", "Escape menu created (ESC to toggle)")
	_setup_visibility_processing(escape_menu)

	# KeyboardHintButton removed - controls/help now lives on the Z shell menu

	# Create Biome Inspector Overlay (now extends Control with internal CanvasLayer)
	biome_inspector = BiomeInspectorOverlay.new()
	# z_index managed by OverlayStackManager via overlay_tier property
	parent.add_child(biome_inspector)
	biome_inspector.overlay_closed.connect(_on_biome_inspector_closed)
	_verbose.info("ui", "🌍", "Biome inspector overlay created (B to toggle)")
	_setup_visibility_processing(biome_inspector)

	# Touch button bar retired — superseded by the top MenuSelectionRow in
	# PlayerShell, which surfaces all 7 ZXCVBNM menus in the same chrome as
	# the bottom rows. `touch_button_bar` stays declared for null checks but
	# is never instantiated.

	# Create Icon Detail Panel
	icon_detail_panel = IconDetailPanel.new()
	icon_detail_panel.set_layout_manager(layout_manager)
	parent.add_child(icon_detail_panel)
	icon_detail_panel.panel_closed.connect(_on_icon_detail_panel_closed)
	_verbose.info("ui", "📖", "Icon detail panel created (click emojis in icon to view)")
	_setup_visibility_processing(icon_detail_panel)

	# Create unified overlays
	_create_overlays(parent)

	# Update positions after layout is ready
	await get_tree().process_frame
	update_positions()


func update_positions() -> void:
	# Update positions of all overlays based on layout_manager
	if not layout_manager:
		return



func _on_biome_inspector_closed() -> void:
	# Handle biome inspector overlay closed signal
	pass


func _on_icon_detail_panel_closed() -> void:
	# Handle icon detail panel closed signal
	# Nothing special needed - panel just hides itself
	pass


# _create_keyboard_hint_button REMOVED
# Z opens ControlsOverlay via PlayerShell, and M is the biome × faction map.
# _create_touch_button_bar REMOVED — retired with the touch bar; touch routes
# through TouchInputManager gestures now. (touch_button_bar var stays for null checks.)


# ============================================================================
# MENU SIGNAL HANDLERS
# ============================================================================

func _on_menu_resume() -> void:
	# Resume from the system menu — close every open overlay so the player
	# returns to the live game in one step, regardless of how deep the stack
	# was when they hit R.
	close_all_overlays()
	menu_resumed.emit()


func _on_quest_board_quest_accepted(quest: Dictionary) -> void:
	# Handle when player accepts a quest from quest board
	_verbose.info("quest", "📋", "Quest accepted from board: %s - %s" % [quest.get("faction", ""), quest.get("body", "")])


func _on_quest_board_quest_completed(quest_id: int, _rewards: Dictionary) -> void:
	# Handle when player completes a quest from quest board
	_verbose.info("quest", "🎉", "Quest completed from board: ID %d" % quest_id)


func _on_quest_board_quest_abandoned(quest_id: int) -> void:
	# Handle when player abandons a quest from quest board
	_verbose.info("quest", "❌", "Quest abandoned from board: ID %d" % quest_id)


# ============================================================================
# OVERLAY STACK SYSTEM
# ============================================================================
# Overlays extend OverlayBase and are registered here for stack-based
# management and shared keyboard routing.

func _create_overlays(parent: Control) -> void:
	# Create and register all stack-managed overlays.
	_verbose.info("ui", "📊", "Creating overlay stack...")

	# Create Inspector Overlay (density matrix visualization)
	# Note: Overlay centers its own panel in _build_standard_panel()
	inspector_overlay = InspectorOverlay.new()
	inspector_overlay.z_index = 11  # Info-tier overlay
	if layout_manager:
		inspector_overlay.set_layout_manager(layout_manager)
	parent.add_child(inspector_overlay)
	register_overlay("inspector", inspector_overlay)
	_setup_visibility_processing(inspector_overlay)

	# Create Controls Overlay (keyboard reference)
	controls_overlay = ControlsOverlay.new()
	controls_overlay.z_index = 11
	if layout_manager:
		controls_overlay.set_layout_manager(layout_manager)
	parent.add_child(controls_overlay)
	register_overlay("controls", controls_overlay)
	_setup_visibility_processing(controls_overlay)

	# Welcome / how-to-play splash (shown once on first run by GameRoot; dismiss begins tutorial)
	welcome_overlay = WelcomeOverlay.new()
	welcome_overlay.z_index = 14  # modal tier, above info overlays
	if layout_manager:
		welcome_overlay.set_layout_manager(layout_manager)
	parent.add_child(welcome_overlay)
	register_overlay("welcome", welcome_overlay)

	# Atom Atlas (V — atoms / icons / signature / affinity)
	atlas_overlay = QubitAtlasOverlay.new()
	atlas_overlay.z_index = 11
	if layout_manager:
		atlas_overlay.set_layout_manager(layout_manager)
	parent.add_child(atlas_overlay)
	register_overlay("atlas", atlas_overlay)
	_setup_visibility_processing(atlas_overlay)

	# Register existing overlays that already implement OverlayBase methods
	if quest_board:
		register_overlay("quests", quest_board)

	# BiomeInspectorOverlay already implements OverlayBase methods
	if biome_inspector:
		register_overlay("biome_detail", biome_inspector)

	# M surface — biome × faction relationships
	map_meta_overlay = MapMetaOverlay.new()
	if layout_manager and map_meta_overlay.has_method("set_layout_manager"):
		map_meta_overlay.set_layout_manager(layout_manager)
	parent.add_child(map_meta_overlay)
	register_overlay("map_meta", map_meta_overlay)
	_setup_visibility_processing(map_meta_overlay)

	# Neighborhood Graph — GraphEdit cluster view of the active biome's reservoir.
	# No top-level keybind yet (ZXCVBNM is full + in flux); reachable as a menu
	# button via MenuRegistry (keycode -1). Assign a key when the keymap settles.
	var neighborhood_graph_overlay = NeighborhoodGraphOverlay.new()
	if layout_manager and neighborhood_graph_overlay.has_method("set_layout_manager"):
		neighborhood_graph_overlay.set_layout_manager(layout_manager)
	parent.add_child(neighborhood_graph_overlay)
	register_overlay("neighborhood_graph", neighborhood_graph_overlay)
	_setup_visibility_processing(neighborhood_graph_overlay)

	_verbose.info("ui", "📊", "Overlay stack created with %d overlays" % overlays.size())


func register_overlay(_name: String, overlay) -> void:
	# Register an overlay for stack management.

	# Args:
	# _name: Unique identifier (e.g., "inspector", "quests")
	# overlay: OverlayBase instance
	if overlays.has(_name):
		_verbose.warn("ui", "⚠️", "overlay '%s' already registered, replacing" % _name)

	# Anonymous nodes ("@Control@276") make stack forensics unreadable — every
	# registered overlay carries its registry key as its node name.
	if overlay is Node and str(overlay.name).begins_with("@"):
		overlay.name = _name

	overlays[_name] = overlay
	if overlay and overlay.has_signal("overlay_closed"):
		var close_callable = Callable(self, "_on_registered_overlay_closed").bind(_name)
		if not overlay.overlay_closed.is_connected(close_callable):
			overlay.overlay_closed.connect(close_callable)
	_verbose.info("ui", "📋", "Registered overlay: %s" % _name)


func unregister_overlay(_name: String) -> void:
	# Unregister an overlay.
	if overlays.has(_name):
		overlays.erase(_name)
		_verbose.info("ui", "📋", "Unregistered overlay: %s" % _name)


## Open the C surface (quests) scoped to a tensor pair. Call this instead of
## open_overlay("quests") when transferring scope from the N network frame.
func open_overlay_with_pair(_name: String, biome_a_name: String, biome_b_name: String) -> bool:
	_pending_pair_scope = [biome_a_name, biome_b_name]
	return open_overlay(_name)


## Write a pair scope without opening an overlay. N calls this on GHJKL selection
## so that when the player presses C (ZXCVBNM ring), the scope is already set.
func set_pending_pair_scope(biome_a_name: String, biome_b_name: String) -> void:
	_pending_pair_scope = [biome_a_name, biome_b_name]


func open_overlay(_name: String) -> bool:
	# Open an overlay by _name.

	# Uses OverlayStackManager for unified overlay management.
	# Returns true if overlay was opened successfully.
	if not overlays.has(_name):
		# Overlays not ready yet (or were torn down by reset()). Silent no-op.
		return false

	var overlay = overlays[_name]
	var farm_ref = _resolve_farm()

	if _name == "inspector" and overlay.has_method("set_biome"):
		if farm_ref and farm_ref.has_method("get_current_biome"):
			var biome = farm_ref.get_current_biome()
			if biome:
				overlay.set_biome(biome)

	# QuestBoard needs quest_manager and current_biome
	if _name == "quests":
		if overlay.has_method("set_quest_manager") and quest_manager:
			overlay.set_quest_manager(quest_manager)
		if overlay.has_method("set_biome") and farm_ref:
			var biome = _get_current_biome(farm_ref)
			if biome:
				overlay.set_biome(biome)
		# Pair-mode scope (N → C handoff). Cleared after read so reopening the
		# C surface without explicit scope returns to single-biome mode.
		if _pending_pair_scope.size() == 2 and overlay.has_method("set_pair_scope"):
			var scope_a: String = str(_pending_pair_scope[0])
			var scope_b: String = str(_pending_pair_scope[1])
			overlay.set_pair_scope(scope_a, scope_b)
			_announce_contract_scope(scope_a, scope_b)
			_pending_pair_scope = []
		elif overlay.has_method("clear_pair_scope"):
			overlay.clear_pair_scope()

	# MapMetaOverlay needs the active farm and biome.
	if _name == "map_meta":
		if farm_ref:
			overlay.farm = farm_ref
		if overlay.has_method("set_biome") and farm_ref:
			var biome = _get_current_biome(farm_ref)
			if biome:
				overlay.set_biome(biome)

	# BiomeInspectorOverlay needs farm reference
	if _name == "biome_detail":
		if farm_ref:
			overlay.farm = farm_ref

	# Use OverlayStackManager for unified management
	if overlay_stack:
		overlay_stack.push(overlay)
	else:
		# Fallback: activate directly when no stack manager is available
		overlay.activate()

	_verbose.info("ui", "📖", "Opened overlay: %s" % _name)
	_log_overlay_open_next_frame(_name, overlay)
	overlay_changed.emit(_name, true)
	return true


func _announce_contract_scope(biome_a_name: String, biome_b_name: String) -> void:
	var shell = InstrumentLocator.resolve_player_shell(self)
	if shell and shell.has_method("show_hint"):
		shell.show_hint("[color=#cfe6ff]N → C scope:[/color] %s × %s" % [biome_a_name, biome_b_name])


func warm_shell_surfaces(force_refresh: bool = false) -> void:
	# Prewarm shell-level overlay caches before the title card is shown or
	# before the first visible open. Safe to call repeatedly.
	if escape_menu and escape_menu.has_method("warm_cache"):
		escape_menu.warm_cache(force_refresh)


func _log_overlay_open_next_frame(_name: String, overlay: Control) -> void:
	# Deferred one-frame diagnostics for overlay open visibility/layering issues.
	if not is_inside_tree():
		return
	call_deferred("_log_overlay_open_next_frame_deferred", _name, overlay)


func _log_overlay_open_next_frame_deferred(_name: String, overlay: Control) -> void:
	# Deferred one-frame diagnostics for overlay open visibility/layering issues.
	if not is_inside_tree():
		return
	var top_name = "none"
	var stack_size = 0
	if overlay_stack:
		stack_size = overlay_stack.size()
		var top = overlay_stack.get_top()
		if top:
			top_name = top.name

	var panel_exists = false
	if overlay and overlay.has_method("get_panel"):
		panel_exists = overlay.get_panel() != null

	var msg = "overlay='%s' visible=%s in_tree=%s z=%d size=%.1fx%.1f pos=(%.1f,%.1f) panel=%s stack_top=%s stack_size=%d" % [
		_name,
		overlay.visible if overlay else false,
		overlay.is_inside_tree() if overlay else false,
		overlay.z_index if overlay else -1,
		overlay.size.x if overlay else 0.0,
		overlay.size.y if overlay else 0.0,
		overlay.global_position.x if overlay else 0.0,
		overlay.global_position.y if overlay else 0.0,
		panel_exists,
		top_name,
		stack_size
	]
	_verbose.info("ui", "🔎", "QuestOverlayFrame+1 %s" % msg)
	_verbose.info("test", "🧪", "QuestOverlayFrame+1 %s" % msg)


func close_overlay() -> void:
	# Close the top overlay on the stack.
	if not overlay_stack:
		return

	var top = overlay_stack.get_top()
	if not top:
		return

	var overlay_name = top.overlay_name if top.get("overlay_name") else top.name
	overlay_stack.pop()

	_verbose.info("ui", "📕", "Closed overlay: %s" % overlay_name)
	overlay_changed.emit(overlay_name, false)


func _close_registered_overlay(_name: String) -> void:
	# Close a registered overlay through the current runtime authority.
	if not overlays.has(_name):
		return

	var overlay = overlays[_name]
	if overlay_stack and overlay_stack.has_overlay(overlay):
		overlay_stack.pop_overlay(overlay)
	else:
		if overlay.has_method("deactivate"):
			overlay.deactivate()
		else:
			overlay.visible = false

	overlay_changed.emit(_name, false)


func _on_registered_overlay_closed(_name: String) -> void:
	# Synchronize stack state when a registered overlay closes itself.
	if not overlays.has(_name) or not overlay_stack:
		return

	var overlay = overlays[_name]
	if overlay_stack.dismiss_overlay(overlay):
		overlay_changed.emit(_name, false)


func close_all_overlays() -> void:
	# Close all registered overlays (used by logger config for mutual exclusion).
	if not overlay_stack:
		return

	for overlay_key in overlays.keys():
		var overlay = overlays[overlay_key]
		if overlay_stack.has_overlay(overlay):
			overlay_stack.pop_overlay(overlay)
			overlay_changed.emit(name, false)


func reset() -> void:
	# Deactivate all overlays and drop farm-scoped refs for the new session.
	# Overlay nodes and overlay_stack are app-lifetime (same as PlayerShell)
	# and stay registered so ESC / ZXCVBNM keep working after a restart.
	close_all_overlays()
	if escape_menu:
		if escape_menu.has_method("deactivate"):
			escape_menu.deactivate()
		if escape_menu.has_method("invalidate_cached_save_slots"):
			escape_menu.invalidate_cached_save_slots()
	# Drop only farm-scoped refs; overlay refs and stack are kept alive.
	farm = null
	quest_manager = null
	faction_manager = null


func toggle_overlay(_name: String) -> void:
	# Toggle an overlay open/closed.

	# Behavior:
	# - If this overlay is already open → close it
	# - If another overlay is open → close it, then open this one
	# - If no overlay is open → open this one

	# This gives "radio button" behavior for ZXCVBN keys.
	if not overlays.has(_name):
		# Overlays may not be created yet (early input) or were torn down
		# by reset(). Silently no-op rather than spam the log.
		return

	var overlay = overlays[_name]

	# Check if this specific overlay is already open
	if overlay_stack and overlay_stack.has_overlay(overlay):
		# Same key pressed twice → close it
		overlay_stack.pop_overlay(overlay)
		overlay_changed.emit(_name, false)
		return

	# Close any other registered overlay that's currently open (radio button behavior)
	if overlay_stack:
		for other_name in overlays.keys():
			var other_overlay = overlays[other_name]
			if overlay_stack.has_overlay(other_overlay):
				overlay_stack.pop_overlay(other_overlay)
				overlay_changed.emit(other_name, false)

	# Open the requested overlay
	open_overlay(_name)


func is_overlay_active() -> bool:
	# Check if any overlay is currently on the stack.
	if overlay_stack:
		return not overlay_stack.is_empty()
	return false


func get_active_overlay():
	# Get the top overlay from the stack, or null.
	if overlay_stack:
		return overlay_stack.get_top()
	return null


func get_overlay(_name: String):
	# Get a registered overlay by _name, or null.
	return overlays.get(_name, null)


func has_overlay(_name: String) -> bool:
	# Check whether an overlay _name is registered.
	return overlays.has(_name)


func get_registered_overlays() -> Array:
	# Get list of all registered overlay names.
	return overlays.keys()
