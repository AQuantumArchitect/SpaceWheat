class_name OverlayManager
extends Node

# Access autoload safely (avoids compile-time errors)
@onready var _verbose = InstrumentLocator.resolve_verbose_config(self)
## Centralizes management of all overlays (Quests, Vocabulary, Network, Escape Menu, Save/Load)
## Handles overlay visibility, positioning, and menu actions

# Preload dependencies
const QuestBoard = preload("res://UI/Overlays/QuestBoard.gd")  # New modal quest board
# DEPRECATED: ConspiracyNetworkOverlay - tomato conspiracy system removed
# const ConspiracyNetworkOverlay = preload("res://UI/ConspiracyNetworkOverlay.gd")
const SaveLoadMenu = preload("res://UI/Overlays/SaveLoadMenu.gd")
const EscapeMenu = preload("res://UI/Overlays/EscapeMenu.gd")
const BiomeInspectorOverlay = preload("res://UI/Overlays/BiomeInspectorOverlay.gd")
const QuantumRigorConfigUI = preload("res://UI/Overlays/QuantumRigorConfigUI.gd")
const IconDetailPanel = preload("res://UI/Widgets/IconDetailPanel.gd")

# Unified overlay stack system
const OverlayBaseClass = preload("res://UI/Core/OverlayBase.gd")
const InspectorOverlay = preload("res://UI/Overlays/InspectorOverlay.gd")
const ControlsOverlay = preload("res://UI/Overlays/ControlsOverlay.gd")
const SemanticMapOverlay = preload("res://UI/Overlays/SemanticMapOverlay.gd")
const BalanceWorkbenchOverlay = preload("res://UI/Overlays/BalanceWorkbenchOverlay.gd")
const MenuRegistry = preload("res://UI/Core/MenuRegistry.gd")
const InstrumentLocator = preload("res://Core/Instrumentation/InstrumentLocator.gd")

# Overlay instances
var quest_board: QuestBoard  # New modal 4-slot quest board (primary interface)
var escape_menu: EscapeMenu
var save_load_menu
# keyboard_hint_button REMOVED - controls/help now lives on Z
var biome_inspector: BiomeInspectorOverlay  # Biome inspection overlay
var quantum_config_ui: QuantumRigorConfigUI  # Quantum rigor mode settings panel
var touch_button_bar: Control  # Touch-friendly panel buttons for the top-level menu row
var icon_detail_panel  # Icon information detail panel

# Unified overlay registry
var overlays: Dictionary = {}  # name → OverlayBase instance
# Active overlay is tracked by OverlayStackManager
var inspector_overlay = null  # Density matrix inspector
var controls_overlay = null  # Keyboard controls reference
var semantic_map_overlay = null  # Semantic octant visualization
var balance_workbench_overlay = null

# Reference to unified overlay stack (set by PlayerShell)
var overlay_stack = null  # OverlayStackManager

# Dependencies
var layout_manager
var quest_manager
var faction_manager
var vocabulary_evolution
var conspiracy_network
var farm  # Farm reference for biome inspector

# Signals for menu actions
signal save_requested(slot: int)
signal load_requested(slot: int)
signal load_completed()
signal quit_requested()
signal menu_resumed()
signal debug_scenario_requested(name: String)

# Overlay stack signals
signal overlay_changed(overlay_name: String, is_open: bool)

# HAUNTED UI FIX: Prevent duplicate overlay creation
var _overlays_created: bool = false


func setup(layout_mgr, vocab_sys, faction_mgr, conspiracy_net, quest_mgr = null) -> void:
	"""Initialize OverlayManager with required dependencies"""
	layout_manager = layout_mgr
	vocabulary_evolution = vocab_sys
	faction_manager = faction_mgr
	conspiracy_network = conspiracy_net
	quest_manager = quest_mgr
	_verbose.info("ui", "📋", "OverlayManager initialized")


func set_overlay_stack(stack) -> void:
	"""Set reference to OverlayStackManager for overlay management."""
	overlay_stack = stack
	_verbose.info("ui", "📋", "OverlayManager connected to OverlayStackManager")


func _get_current_biome(farm_ref):
	"""Get the current active biome object from farm (not the hardcoded biotic_flux)"""
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
	"""Resolve the active farm through the current runtime authority graph."""
	if farm and is_instance_valid(farm):
		return farm
	return InstrumentLocator.resolve_active_farm(self)


## ========================================
## VISIBILITY-BASED PROCESS MANAGEMENT
## ========================================

func _setup_visibility_processing(panel: Node) -> void:
	"""Configure panel to enable/disable processing based on visibility.

	When panel becomes visible, enable processing (_process() runs).
	When panel becomes invisible, disable processing (saves CPU).
	"""
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
	"""Create all overlay panels and add them to parent"""
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
	parent.layout_mode = 1
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
	_verbose.info("ui", "📋", "Quest Board created (press C to toggle - modal 4-slot system)")
	_setup_visibility_processing(quest_board)

	# SimStatsOverlay REMOVED - merged into InspectorOverlay (N key)
	# Performance stats now only visible when user presses N to open Inspector
	# sim_stats_overlay = SimStatsOverlay.new()
	# sim_stats_overlay.z_index = 4096  # Max z_index in Godot 4 (was 5000, exceeded limit)
	# parent.add_child(sim_stats_overlay)
	_verbose.info("ui", "⏱", "Simulation stats overlay removed - now in InspectorOverlay (N key)")

	# Create Escape Menu
	escape_menu = EscapeMenu.new()
	if layout_manager and escape_menu.has_method("set_layout_manager"):
		escape_menu.set_layout_manager(layout_manager)
	escape_menu.z_index = 18  # System tier - below SaveLoadMenu and action bars
	escape_menu.deactivate()
	parent.add_child(escape_menu)
	register_overlay("escape_menu", escape_menu)

	# Connect escape menu signals
	escape_menu.resume_pressed.connect(_on_menu_resume)
	escape_menu.quit_pressed.connect(func(): quit_requested.emit())
	escape_menu.save_pressed.connect(_on_save_pressed)
	escape_menu.load_pressed.connect(_on_load_pressed)
	escape_menu.reload_last_save_pressed.connect(_on_reload_last_save_pressed)
	# Note: EscapeMenu doesn't have debug_environment_selected - removed this connection
	_verbose.info("ui", "🎮", "Escape menu created (ESC to toggle)")
	_setup_visibility_processing(escape_menu)

	# KeyboardHintButton removed - controls/help now lives on the Z shell menu

	# Create Save/Load Menu
	_verbose.debug("save", "💾", "Creating Save/Load menu...")
	save_load_menu = SaveLoadMenu.new()
	if layout_manager and save_load_menu.has_method("set_layout_manager"):
		save_load_menu.set_layout_manager(layout_manager)
	_verbose.debug("save", "💾", "Save/Load menu instantiated, setting properties...")
	save_load_menu.z_index = 19  # Above EscapeMenu, still below action bars
	save_load_menu.hide_menu()
	_verbose.debug("save", "💾", "Adding Save/Load menu to parent...")
	parent.add_child(save_load_menu)
	register_overlay("save_load", save_load_menu)
	_verbose.info("save", "💾", "Save/Load menu created")

	# Connect save/load menu signals
	_verbose.debug("save", "💾", "Connecting save/load menu signals...")
	save_load_menu.slot_selected.connect(_on_save_load_slot_selected)
	save_load_menu.debug_environment_selected.connect(_on_debug_environment_selected)
	save_load_menu.menu_closed.connect(_on_save_load_menu_closed)
	_verbose.debug("save", "💾", "Save/Load menu signals connected")
	_setup_visibility_processing(save_load_menu)

	# Create Biome Inspector Overlay (now extends Control with internal CanvasLayer)
	biome_inspector = BiomeInspectorOverlay.new()
	# z_index managed by OverlayStackManager via overlay_tier property
	parent.add_child(biome_inspector)
	biome_inspector.overlay_closed.connect(_on_biome_inspector_closed)
	_verbose.info("ui", "🌍", "Biome inspector overlay created (B to toggle)")
	_setup_visibility_processing(biome_inspector)

	# Create Quantum Rigor Config UI (Phase 1 UI Integration)
	quantum_config_ui = QuantumRigorConfigUI.new()
	quantum_config_ui.visible = false
	quantum_config_ui.z_index = 18  # System-tier panel, below action bars
	parent.add_child(quantum_config_ui)
	_verbose.info("ui", "🔬", "Quantum rigor config panel created (via system menu)")
	_setup_visibility_processing(quantum_config_ui)

	# Create Touch Button Bar (for touch devices)
	touch_button_bar = _create_touch_button_bar()
	parent.add_child(touch_button_bar)
	_setup_visibility_processing(touch_button_bar)
	_verbose.debug("ui", "📏", "Parent (OverlayLayer) size: %s" % parent.size)
	_verbose.debug("ui", "📏", "Parent (OverlayLayer) position: (%s, %s)" % [parent.position.x, parent.position.y])
	_verbose.debug("ui", "📏", "TouchButtonBar position: (%s, %s)" % [touch_button_bar.position.x, touch_button_bar.position.y])
	_verbose.debug("ui", "📏", "TouchButtonBar size: %s" % touch_button_bar.size)
	_verbose.debug("ui", "📏", "TouchButtonBar global_position: (%s, %s)" % [touch_button_bar.global_position.x, touch_button_bar.global_position.y])
	_verbose.debug("ui", "📏", "TouchButtonBar z_index: %d" % touch_button_bar.z_index)
	_verbose.debug("ui", "📏", "TouchButtonBar visible: %s" % touch_button_bar.visible)

	# Create Icon Detail Panel
	icon_detail_panel = IconDetailPanel.new()
	icon_detail_panel.set_layout_manager(layout_manager)
	parent.add_child(icon_detail_panel)
	icon_detail_panel.panel_closed.connect(_on_icon_detail_panel_closed)
	_verbose.info("ui", "📖", "Icon detail panel created (click emojis in vocab to view)")
	_setup_visibility_processing(icon_detail_panel)

	# Create unified overlays
	_create_overlays(parent)

	# Update positions after layout is ready
	await get_tree().process_frame
	update_positions()


func update_positions() -> void:
	"""Update positions of all overlays based on layout_manager"""
	if not layout_manager:
		return

func toggle_quantum_config_ui() -> void:
	"""Toggle quantum rigor config UI."""
	_verbose.debug("ui", "🔄", "toggle_quantum_config_ui() called")
	if not quantum_config_ui:
		_verbose.warn("ui", "❌", "quantum_config_ui is null!")
		return
	_verbose.debug("ui", "→", "quantum_config_ui exists, visible = %s" % quantum_config_ui.visible)
	quantum_config_ui.visible = not quantum_config_ui.visible
	if quantum_config_ui.visible:
		_verbose.info("ui", "✅", "quantum_config_ui shown")
	else:
		_verbose.info("ui", "✅", "quantum_config_ui hidden")


func _on_biome_inspector_closed() -> void:
	"""Handle biome inspector overlay closed signal"""
	pass


func _on_icon_detail_panel_closed() -> void:
	"""Handle icon detail panel closed signal"""
	# Nothing special needed - panel just hides itself
	pass


func _on_emoji_clicked(emoji: String, icon) -> void:
	"""Handle emoji button click - show Icon detail panel"""
	if icon_detail_panel:
		icon_detail_panel.show_icon(icon)
	else:
		push_warning("Icon detail panel not available")


# _create_keyboard_hint_button REMOVED
# Z opens ControlsOverlay via PlayerShell, and M is reserved for the workbench.


func _create_touch_button_bar() -> Control:
	"""Create touch-friendly button bar for LEFT CENTER of screen."""
	const PanelTouchButton = preload("res://UI/Components/PanelTouchButton.gd")

	var scale = layout_manager.scale_factor if layout_manager else 1.0

	# VBoxContainer for buttons stacked vertically
	var button_bar = VBoxContainer.new()
	button_bar.name = "TouchButtonBar"
	button_bar.add_theme_constant_override("separation", int(8 * scale))

	# Position on LEFT CENTER of screen (aligned center vertically)
	button_bar.layout_mode = 1  # Required for anchors in Godot 4
	button_bar.anchor_left = 0.0  # Anchor to LEFT
	button_bar.anchor_right = 0.0
	button_bar.anchor_top = 0.5  # Center vertically
	button_bar.anchor_bottom = 0.5
	button_bar.offset_left = 10 * scale   # 10px from left edge
	button_bar.offset_right = 80 * scale  # 70px wide
	button_bar.offset_top = -150 * scale  # Center around middle (5 buttons)
	button_bar.offset_bottom = 150 * scale
	button_bar.grow_horizontal = Control.GROW_DIRECTION_END  # Grow rightward from left anchor
	button_bar.grow_vertical = Control.GROW_DIRECTION_BOTH
	button_bar.z_index = 4090  # Near Godot max (4096), above all UI elements
	button_bar.mouse_filter = Control.MOUSE_FILTER_PASS  # Allow clicks through to children

	var touch_entries = MenuRegistry.get_touch_button_menus()
	for entry in touch_entries:
		var button = PanelTouchButton.new()
		button.set_layout_manager(layout_manager)
		button.button_emoji = str(entry.get("button_emoji", ""))
		button.keyboard_hint = "[%s]" % str(entry.get("key_label", ""))
		var overlay_name = str(entry.get("overlay_name", ""))
		button.button_activated.connect(func(): toggle_overlay(overlay_name))
		button_bar.add_child(button)

	var hints: Array[String] = []
	for entry in touch_entries:
		hints.append(str(entry.get("key_label", "")))
	_verbose.info("ui", "📱", "Touch button bar created: %s on LEFT side" % "/".join(hints))
	return button_bar


# ============================================================================
# MENU SIGNAL HANDLERS
# ============================================================================

func _on_menu_resume() -> void:
	"""Resume game from escape menu"""
	menu_resumed.emit()


func _on_restart_pressed() -> void:
	"""RESTART (R): Reload last save, preserving player progress.

	GameStateManager is the only lifecycle authority for restart semantics.
	"""
	_verbose.info("ui", "🔄", "Restarting game (reload last save)...")

	var gsm = InstrumentLocator.resolve_game_state_manager(self)
	if gsm and gsm.has_method("request_restart"):
		gsm.request_restart()


func _on_dev_restart_pressed() -> void:
	"""DEV RESTART (Shift+R): Hard reset everything for a fresh boot.

	GameStateManager is the only lifecycle authority for this cold-boot path.
	"""
	_verbose.info("ui", "🔧", "======================================================")
	_verbose.info("ui", "🔧", "DEV RESTART - Full reset for fresh boot")
	_verbose.info("ui", "🔧", "======================================================")

	var gsm = InstrumentLocator.resolve_game_state_manager(self)
	if gsm and gsm.has_method("request_fresh_restart"):
		gsm.request_fresh_restart(true)


func _on_save_pressed() -> void:
	"""Show save menu when Save is pressed from escape menu"""
	_verbose.debug("save", "📋", "OverlayManager._on_save_pressed() called")
	_verbose.debug("save", "→", "save_load_menu exists: %s" % (save_load_menu != null))
	if save_load_menu:
		_verbose.debug("save", "→", "Opening registered save_load overlay in SAVE mode...")
		open_overlay("save_load")
		save_load_menu.open_menu(SaveLoadMenu.Mode.SAVE)
		_verbose.debug("save", "→", "save_load_menu.visible = %s" % save_load_menu.visible)
		_verbose.info("save", "💾", "Save menu opened")
	else:
		_verbose.warn("save", "⚠️", "Save/Load menu not available")


func _on_load_pressed() -> void:
	"""Show load menu when Load is pressed from escape menu"""
	_verbose.debug("save", "📋", "OverlayManager._on_load_pressed() called")
	_verbose.debug("save", "→", "save_load_menu exists: %s" % (save_load_menu != null))
	if save_load_menu:
		_verbose.debug("save", "→", "Opening registered save_load overlay in LOAD mode...")
		open_overlay("save_load")
		save_load_menu.open_menu(SaveLoadMenu.Mode.LOAD)
		_verbose.debug("save", "→", "save_load_menu.visible = %s" % save_load_menu.visible)
		_verbose.info("save", "📂", "Load menu opened")
	else:
		_verbose.warn("save", "⚠️", "Save/Load menu not available")


func _on_reload_last_save_pressed() -> void:
	"""Reload the last saved game"""
	var gsm = InstrumentLocator.resolve_game_state_manager(self)
	if gsm and gsm.last_saved_slot >= 0:
		if gsm.load_and_apply(gsm.last_saved_slot):
			_verbose.info("save", "✅", "Game reloaded from last save")
			emit_signal("load_completed")
		else:
			_verbose.error("save", "❌", "Failed to reload last save")
	else:
		_verbose.warn("save", "⚠️", "No previous save to reload")


func _on_save_load_slot_selected(slot: int, mode: String) -> void:
	"""Handle save/load slot selection from the SaveLoadMenu"""
	var gsm = InstrumentLocator.resolve_game_state_manager(self)
	if not gsm:
		_verbose.error("save", "❌", "GameStateManager not available")
		return

	if mode == "save":
		# Save to the selected slot
		if gsm.save_game(slot):
			_verbose.info("save", "✅", "Game saved to slot %d" % (slot + 1))
			save_requested.emit(slot)
			_close_registered_overlay("save_load")
			_close_registered_overlay("escape_menu")
		else:
			_verbose.error("save", "❌", "Failed to save to slot %d" % (slot + 1))
	elif mode == "load":
		# Load from the selected slot and APPLY to game
		_verbose.info("save", "📂", "Loading save from slot %d..." % (slot + 1))

		# Use load_and_apply to actually apply the state to the game
		if gsm.load_and_apply(slot):
			_verbose.info("save", "✅", "Save loaded and applied from slot %d" % (slot + 1))

			# Refresh UI to show loaded state
			_refresh_ui_after_load()

			# Emit signal
			load_requested.emit(slot)
			_close_registered_overlay("save_load")
			_close_registered_overlay("escape_menu")
			emit_signal("load_completed")
		else:
			_verbose.error("save", "❌", "Failed to load/apply save from slot %d" % (slot + 1))


func _refresh_ui_after_load() -> void:
	"""Refresh all UI elements after loading a save"""
	_verbose.info("save", "🔄", "Refreshing UI after load...")

	# Find PlayerShell to access FarmUI
	var player_shell = get_tree().get_first_node_in_group("player_shell")
	if not player_shell:
		_verbose.warn("save", "⚠️", "PlayerShell not found - cannot refresh UI")
		return

	var farm_ui = player_shell.get_farm_ui() if player_shell.has_method("get_farm_ui") else null
	if not farm_ui:
		_verbose.warn("save", "⚠️", "FarmUI not found - cannot refresh UI")
		return

	# Refresh PlotGridDisplay
	var plot_grid = farm_ui.get_node_or_null("PlotGridDisplay")
	if plot_grid and plot_grid.has_method("refresh_all_tiles"):
		plot_grid.refresh_all_tiles()
		_verbose.info("save", "✓", "PlotGridDisplay refreshed")

	# Refresh economy display if present
	if farm_ui.has_method("refresh_resource_display"):
		farm_ui.refresh_resource_display()
		_verbose.info("save", "✓", "Resource display refreshed")

	# Refresh quantum visualization if present
	var quantum_viz = farm_ui.get_node_or_null("QuantumVisualization")
	if quantum_viz and quantum_viz.has_method("refresh"):
		quantum_viz.refresh()
		_verbose.info("save", "✓", "Quantum visualization refreshed")

	_verbose.info("save", "✅", "UI refresh complete")


func _on_debug_environment_selected(env_name: String) -> void:
	"""Handle debug environment/scenario selection"""
	_verbose.info("save", "🎮", "Loading debug environment: %s" % env_name)

	# Emit signal for debug scenario (other systems can listen for this)
	debug_scenario_requested.emit(env_name)

	# Hide the save/load menu and escape menu
	_close_registered_overlay("save_load")
	_close_registered_overlay("escape_menu")


func _on_save_load_menu_closed() -> void:
	"""Handle save/load menu closed - return to escape menu"""
	_verbose.debug("save", "📋", "Returning from save/load menu to escape menu")
	# When user presses ESC in save/load menu, return to main escape menu (don't close it)
	if overlay_stack:
		if overlay_stack.dismiss_overlay(save_load_menu):
			overlay_changed.emit("save_load", false)
	if escape_menu and not (overlay_stack and overlay_stack.has_overlay(escape_menu)):
		open_overlay("escape_menu")
	elif not escape_menu:
		_verbose.warn("save", "⚠️", "Escape menu not available to return to")


func _on_quest_board_quest_accepted(quest: Dictionary) -> void:
	"""Handle when player accepts a quest from quest board"""
	_verbose.info("quest", "📋", "Quest accepted from board: %s - %s" % [quest.get("faction", ""), quest.get("body", "")])


func _on_quest_board_quest_completed(quest_id: int, rewards: Dictionary) -> void:
	"""Handle when player completes a quest from quest board"""
	_verbose.info("quest", "🎉", "Quest completed from board: ID %d" % quest_id)


func _on_quest_board_quest_abandoned(quest_id: int) -> void:
	"""Handle when player abandons a quest from quest board"""
	_verbose.info("quest", "❌", "Quest abandoned from board: ID %d" % quest_id)


# ============================================================================
# OVERLAY STACK SYSTEM
# ============================================================================
# Overlays extend OverlayBase and are registered here for stack-based
# management and shared keyboard routing.

func _create_overlays(parent: Control) -> void:
	"""Create and register all stack-managed overlays."""
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
	controls_overlay.set_overlay_source(self)
	_setup_visibility_processing(controls_overlay)

	# Create Semantic Map Overlay (vocabulary + octants)
	semantic_map_overlay = SemanticMapOverlay.new()
	semantic_map_overlay.z_index = 11
	if layout_manager:
		semantic_map_overlay.set_layout_manager(layout_manager)
	parent.add_child(semantic_map_overlay)
	register_overlay("semantic_map", semantic_map_overlay)
	_setup_visibility_processing(semantic_map_overlay)

	# Create Balance Workbench Overlay (shared balance tuning projection)
	balance_workbench_overlay = BalanceWorkbenchOverlay.new()
	balance_workbench_overlay.z_index = 11
	if layout_manager:
		balance_workbench_overlay.set_layout_manager(layout_manager)
	parent.add_child(balance_workbench_overlay)
	register_overlay("balance_workbench", balance_workbench_overlay)
	_setup_visibility_processing(balance_workbench_overlay)

	# Register existing overlays that already implement OverlayBase methods
	if quest_board:
		register_overlay("quests", quest_board)

	# BiomeInspectorOverlay already implements OverlayBase methods
	if biome_inspector:
		register_overlay("biome_detail", biome_inspector)

	_verbose.info("ui", "📊", "Overlay stack created with %d overlays" % overlays.size())


func register_overlay(name: String, overlay) -> void:
	"""Register an overlay for stack management.

	Args:
		name: Unique identifier (e.g., "inspector", "quests")
		overlay: OverlayBase instance
	"""
	if overlays.has(name):
		_verbose.warn("ui", "⚠️", "overlay '%s' already registered, replacing" % name)

	overlays[name] = overlay
	if overlay and overlay.has_signal("overlay_closed"):
		var close_callable = Callable(self, "_on_registered_overlay_closed").bind(name)
		if not overlay.overlay_closed.is_connected(close_callable):
			overlay.overlay_closed.connect(close_callable)
	_verbose.info("ui", "📋", "Registered overlay: %s" % name)


func unregister_overlay(name: String) -> void:
	"""Unregister an overlay."""
	if overlays.has(name):
		overlays.erase(name)
		_verbose.info("ui", "📋", "Unregistered overlay: %s" % name)


func open_overlay(name: String) -> bool:
	"""Open an overlay by name.

	Uses OverlayStackManager for unified overlay management.
	Returns true if overlay was opened successfully.
	"""
	if not overlays.has(name):
		_verbose.warn("ui", "❌", "overlay '%s' not registered" % name)
		return false

	var overlay = overlays[name]
	var farm_ref = _resolve_farm()

	if name == "inspector" and overlay.has_method("set_biome"):
		if farm_ref and farm_ref.has_method("get_current_biome"):
			var biome = farm_ref.get_current_biome()
			if biome:
				overlay.set_biome(biome)

	# QuestBoard needs quest_manager and current_biome
	if name == "quests":
		if overlay.has_method("set_quest_manager") and quest_manager:
			overlay.set_quest_manager(quest_manager)
		if overlay.has_method("set_biome") and farm_ref:
			var biome = _get_current_biome(farm_ref)
			if biome:
				overlay.set_biome(biome)

	# BiomeInspectorOverlay needs farm reference
	if name == "biome_detail":
		if overlay.has_method("show_all_biomes") and farm_ref:
			overlay.farm = farm_ref

	if name == "balance_workbench":
		if overlay.has_method("set_farm"):
			overlay.set_farm(farm_ref)

	# Use OverlayStackManager for unified management
	if overlay_stack:
		overlay_stack.push(overlay)
	else:
		# Fallback: activate directly when no stack manager is available
		overlay.activate()

	_verbose.info("ui", "📖", "Opened overlay: %s" % name)
	_log_overlay_open_next_frame(name, overlay)
	overlay_changed.emit(name, true)
	return true


func _log_overlay_open_next_frame(name: String, overlay: Control) -> void:
	"""Deferred one-frame diagnostics for overlay open visibility/layering issues."""
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	tree.create_timer(0.0).timeout.connect(func():
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
			name,
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
	, CONNECT_ONE_SHOT)


func close_overlay() -> void:
	"""Close the top overlay on the stack."""
	if not overlay_stack:
		return

	var top = overlay_stack.get_top()
	if not top:
		return

	var overlay_name = top.overlay_name if top.get("overlay_name") else top.name
	overlay_stack.pop()

	_verbose.info("ui", "📕", "Closed overlay: %s" % overlay_name)
	overlay_changed.emit(overlay_name, false)


func _close_registered_overlay(name: String) -> void:
	"""Close a registered overlay through the current runtime authority."""
	if not overlays.has(name):
		return

	var overlay = overlays[name]
	if overlay_stack and overlay_stack.has_overlay(overlay):
		overlay_stack.pop_overlay(overlay)
	else:
		if overlay.has_method("deactivate"):
			overlay.deactivate()
		else:
			overlay.visible = false

	overlay_changed.emit(name, false)


func _on_registered_overlay_closed(name: String) -> void:
	"""Synchronize stack state when a registered overlay closes itself."""
	if not overlays.has(name) or not overlay_stack:
		return

	var overlay = overlays[name]
	if overlay_stack.dismiss_overlay(overlay):
		overlay_changed.emit(name, false)


func close_all_overlays() -> void:
	"""Close all registered overlays (used by logger config for mutual exclusion)."""
	if not overlay_stack:
		return

	for name in overlays.keys():
		var overlay = overlays[name]
		if overlay_stack.has_overlay(overlay):
			overlay_stack.pop_overlay(overlay)
			overlay_changed.emit(name, false)


func reset() -> void:
	"""Reset runtime overlay state for shutdown or restart."""
	close_all_overlays()
	if quantum_config_ui and quantum_config_ui.visible:
		quantum_config_ui.visible = false
	if save_load_menu and save_load_menu.has_method("hide_menu"):
		save_load_menu.hide_menu()
	elif save_load_menu:
		save_load_menu.visible = false
	if escape_menu and escape_menu.has_method("deactivate"):
		escape_menu.deactivate()
	elif escape_menu:
		escape_menu.visible = false
	overlays.clear()
	quest_board = null
	escape_menu = null
	save_load_menu = null
	biome_inspector = null
	quantum_config_ui = null
	touch_button_bar = null
	icon_detail_panel = null
	inspector_overlay = null
	controls_overlay = null
	semantic_map_overlay = null
	balance_workbench_overlay = null
	overlay_stack = null
	farm = null
	quest_manager = null
	faction_manager = null
	vocabulary_evolution = null
	conspiracy_network = null
	_overlays_created = false


func toggle_overlay(name: String) -> void:
	"""Toggle an overlay open/closed.

	Behavior:
	- If this overlay is already open → close it
	- If another overlay is open → close it, then open this one
	- If no overlay is open → open this one

	This gives "radio button" behavior for ZXCVBN keys.
	"""
	if not overlays.has(name):
		_verbose.warn("ui", "❌", "overlay '%s' not registered" % name)
		return

	var overlay = overlays[name]

	# Check if this specific overlay is already open
	if overlay_stack and overlay_stack.has_overlay(overlay):
		# Same key pressed twice → close it
		overlay_stack.pop_overlay(overlay)
		overlay_changed.emit(name, false)
		return

	# Close any other registered overlay that's currently open (radio button behavior)
	if overlay_stack:
		for other_name in overlays.keys():
			var other_overlay = overlays[other_name]
			if overlay_stack.has_overlay(other_overlay):
				overlay_stack.pop_overlay(other_overlay)
				overlay_changed.emit(other_name, false)

	# Open the requested overlay
	open_overlay(name)


func is_overlay_active() -> bool:
	"""Check if any overlay is currently on the stack."""
	if overlay_stack:
		return not overlay_stack.is_empty()
	return false


func get_active_overlay():
	"""Get the top overlay from the stack, or null."""
	if overlay_stack:
		return overlay_stack.get_top()
	return null


func get_overlay(name: String):
	"""Get a registered overlay by name, or null."""
	return overlays.get(name, null)


func has_overlay(name: String) -> bool:
	"""Check whether an overlay name is registered."""
	return overlays.has(name)


func get_registered_overlays() -> Array:
	"""Get list of all registered overlay names."""
	return overlays.keys()
