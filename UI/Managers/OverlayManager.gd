class_name OverlayManager
extends Node

# Access autoload safely (avoids compile-time errors)
@onready var _verbose = get_node("/root/VerboseConfig")
@onready var _icon_registry = get_node("/root/IconRegistry")

## Centralizes management of all overlays (Quests, Vocabulary, Network, Escape Menu, Save/Load)
## Handles overlay visibility, positioning, and menu actions

# Preload dependencies
const QuestBoard = preload("res://UI/Overlays/QuestBoard.gd")  # New modal quest board
const NetworkInfoPanel = preload("res://UI/NetworkInfoPanel.gd")
# DEPRECATED: ConspiracyNetworkOverlay - tomato conspiracy system removed
# const ConspiracyNetworkOverlay = preload("res://UI/ConspiracyNetworkOverlay.gd")
const SaveLoadMenu = preload("res://UI/Overlays/SaveLoadMenu.gd")
const EscapeMenu = preload("res://UI/Overlays/EscapeMenu.gd")
const BiomeInspectorOverlay = preload("res://UI/Overlays/BiomeInspectorOverlay.gd")
const QuantumRigorConfigUI = preload("res://UI/Overlays/QuantumRigorConfigUI.gd")
const IconDetailPanel = preload("res://UI/Widgets/IconDetailPanel.gd")
# const SaveDataAdapter = preload("res://UI/SaveDataAdapter.gd")  # Legacy - unused, commented out to fix compilation error

# Unified overlay stack system
const OverlayBaseClass = preload("res://UI/Core/OverlayBase.gd")
const InspectorOverlay = preload("res://UI/Overlays/InspectorOverlay.gd")
const ControlsOverlay = preload("res://UI/Overlays/ControlsOverlay.gd")
const SemanticMapOverlay = preload("res://UI/Overlays/SemanticMapOverlay.gd")
const BalanceWorkbenchOverlay = preload("res://UI/Overlays/BalanceWorkbenchOverlay.gd")

# Overlay instances
var quest_board: QuestBoard  # New modal 4-slot quest board (primary interface)
var vocabulary_overlay: Control
var network_info_panel: NetworkInfoPanel
var escape_menu: EscapeMenu
var save_load_menu
# keyboard_hint_button REMOVED - K key now opens ControlsOverlay
var biome_inspector: BiomeInspectorOverlay  # Biome inspection overlay
var quantum_config_ui: QuantumRigorConfigUI  # Quantum rigor mode settings panel
var touch_button_bar: Control  # Touch-friendly panel buttons on LEFT side (C/V/B/N/K)
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

# Track overlay visibility state
var overlay_states: Dictionary = {
	"quests": false,
	"vocabulary": false,
	"network": false,
	"escape_menu": false,
	"save_load": false,
	"biomes": false,
	"quantum_config": false  # Quantum rigor mode settings
}

# Signals for menu actions
signal overlay_toggled(name: String, visible: bool)
signal save_requested(slot: int)
signal load_requested(slot: int)
signal load_completed()
signal restart_requested()
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

	# Get current biome name
	var current_biome_name = "StarterForest"  # Default fallback
	var observation = farm_ref.observation_frame if "observation_frame" in farm_ref else null
	if observation and observation.has_method("get_neutral_biome"):
		current_biome_name = observation.get_neutral_biome()

	# Look up biome object in grid
	if farm_ref.grid and farm_ref.grid.has_biome(current_biome_name):
		return farm_ref.grid.get_biome(current_biome_name)

	return null


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
	quest_board.z_index = 1001
	parent.add_child(quest_board)

	# Connect signals
	quest_board.quest_accepted.connect(_on_quest_board_quest_accepted)
	quest_board.quest_completed.connect(_on_quest_board_quest_completed)
	quest_board.quest_abandoned.connect(_on_quest_board_quest_abandoned)
	quest_board.board_closed.connect(_on_quest_board_closed)

	_verbose.info("ui", "📋", "Quest Board created (press C to toggle - modal 4-slot system)")
	_setup_visibility_processing(quest_board)

	# SimStatsOverlay REMOVED - merged into InspectorOverlay (N key)
	# Performance stats now only visible when user presses N to open Inspector
	# sim_stats_overlay = SimStatsOverlay.new()
	# sim_stats_overlay.z_index = 4096  # Max z_index in Godot 4 (was 5000, exceeded limit)
	# parent.add_child(sim_stats_overlay)
	_verbose.info("ui", "⏱", "Simulation stats overlay removed - now in InspectorOverlay (N key)")

	# Create Vocabulary Overlay
	vocabulary_overlay = _create_vocabulary_overlay()
	parent.add_child(vocabulary_overlay)
	_verbose.info("ui", "📖", "Vocabulary overlay created (press V to toggle)")
	_setup_visibility_processing(vocabulary_overlay)

	# Create Escape Menu
	escape_menu = EscapeMenu.new()
	if layout_manager and escape_menu.has_method("set_layout_manager"):
		escape_menu.set_layout_manager(layout_manager)
	escape_menu.z_index = 4000  # System tier - below SaveLoadMenu
	escape_menu.deactivate()
	parent.add_child(escape_menu)

	# Connect escape menu signals
	escape_menu.resume_pressed.connect(_on_menu_resume)
	escape_menu.restart_pressed.connect(_on_restart_pressed)
	escape_menu.dev_restart_pressed.connect(_on_dev_restart_pressed)
	escape_menu.quit_pressed.connect(func(): quit_requested.emit())
	escape_menu.save_pressed.connect(_on_save_pressed)
	escape_menu.load_pressed.connect(_on_load_pressed)
	escape_menu.reload_last_save_pressed.connect(_on_reload_last_save_pressed)
	# Note: EscapeMenu doesn't have debug_environment_selected - removed this connection
	_verbose.info("ui", "🎮", "Escape menu created (ESC to toggle)")
	_setup_visibility_processing(escape_menu)

	# KeyboardHintButton REMOVED - K key now opens ControlsOverlay via the overlay stack

	# Create Save/Load Menu
	_verbose.debug("save", "💾", "Creating Save/Load menu...")
	save_load_menu = SaveLoadMenu.new()
	if layout_manager and save_load_menu.has_method("set_layout_manager"):
		save_load_menu.set_layout_manager(layout_manager)
	_verbose.debug("save", "💾", "Save/Load menu instantiated, setting properties...")
	save_load_menu.z_index = 4095  # HIGHEST - above ESC menu (4000), max is 4096
	save_load_menu.hide_menu()
	_verbose.debug("save", "💾", "Adding Save/Load menu to parent...")
	parent.add_child(save_load_menu)
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
	quantum_config_ui.z_index = 1003  # Above other overlays
	parent.add_child(quantum_config_ui)
	_verbose.info("ui", "🔬", "Quantum rigor config panel created (Shift+Q to toggle)")
	_setup_visibility_processing(quantum_config_ui)

	# Create Touch Button Bar (for touch devices)
	touch_button_bar = _create_touch_button_bar()
	parent.add_child(touch_button_bar)
	_setup_visibility_processing(touch_button_bar)
	# Note: Function logs "C/V/B/N/K on LEFT side" - no need for duplicate log
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


func toggle_overlay(name: String) -> void:
	"""Toggle visibility of an overlay by name"""
	match name:
		"quests":
			toggle_quest_board()
		"vocabulary":
			toggle_vocabulary_overlay()
		"escape_menu":
			toggle_escape_menu()
		"biomes":
			toggle_biome_inspector()
		"quantum_config":
			toggle_quantum_config_ui()
		_:
			push_warning("OverlayManager: Unknown overlay '%s'" % name)


func show_overlay(name: String) -> void:
	"""Show a specific overlay"""
	_verbose.debug("ui", "🔓", "show_overlay('%s') called" % name)
	match name:
		"quests":
			if quest_board and farm:
				var biome = _get_current_biome(farm)
				if biome:
					quest_board.set_biome(biome)
				quest_board.open_board()
				overlay_states["quests"] = true
				overlay_toggled.emit("quests", true)
				_verbose.info("quest", "✅", "Quest board opened")
			elif not quest_board:
				_verbose.warn("quest", "❌", "quest_board is null!")
			else:
				_verbose.warn("quest", "❌", "farm reference not set!")
		"vocabulary":
			if vocabulary_overlay:
				_verbose.debug("ui", "→", "Setting vocabulary_overlay.visible = true")
				vocabulary_overlay.visible = true
				overlay_states["vocabulary"] = true
				overlay_toggled.emit("vocabulary", true)
				_verbose.info("ui", "✅", "vocabulary_overlay shown")
			else:
				_verbose.warn("ui", "❌", "vocabulary_overlay is null!")
		"escape_menu":
			if escape_menu:
				_verbose.debug("ui", "→", "Calling escape_menu.activate()")
				escape_menu.activate()
				overlay_states["escape_menu"] = true
				overlay_toggled.emit("escape_menu", true)
				_verbose.info("ui", "✅", "escape_menu shown")
			else:
				_verbose.warn("ui", "❌", "escape_menu is null!")
		"quantum_config":
			if quantum_config_ui:
				_verbose.debug("ui", "→", "Setting quantum_config_ui.visible = true")
				quantum_config_ui.visible = true
				overlay_states["quantum_config"] = true
				overlay_toggled.emit("quantum_config", true)
				_verbose.info("ui", "✅", "quantum_config_ui shown")
			else:
				_verbose.warn("ui", "❌", "quantum_config_ui is null!")
		_:
			push_warning("OverlayManager: Unknown overlay '%s'" % name)


func hide_overlay(name: String) -> void:
	"""Hide a specific overlay"""
	_verbose.debug("ui", "🔐", "hide_overlay('%s') called" % name)
	match name:
		"quests":
			if quest_board:
				quest_board.close_board()
				overlay_states["quests"] = false
				overlay_toggled.emit("quests", false)
				_verbose.info("quest", "✅", "Quest board closed")
			else:
				_verbose.warn("quest", "❌", "quest_board is null!")
		"vocabulary":
			if vocabulary_overlay:
				_verbose.debug("ui", "→", "Setting vocabulary_overlay.visible = false")
				vocabulary_overlay.visible = false
				overlay_states["vocabulary"] = false
				overlay_toggled.emit("vocabulary", false)
				_verbose.info("ui", "✅", "vocabulary_overlay hidden")
			else:
				_verbose.warn("ui", "❌", "vocabulary_overlay is null!")
		"escape_menu":
			if escape_menu:
				_verbose.debug("ui", "→", "Calling escape_menu.deactivate()")
				escape_menu.deactivate()
				overlay_states["escape_menu"] = false
				overlay_toggled.emit("escape_menu", false)
				_verbose.info("ui", "✅", "escape_menu hidden")
			else:
				_verbose.warn("ui", "❌", "escape_menu is null!")
		"quantum_config":
			if quantum_config_ui:
				_verbose.debug("ui", "→", "Setting quantum_config_ui.visible = false")
				quantum_config_ui.visible = false
				overlay_states["quantum_config"] = false
				overlay_toggled.emit("quantum_config", false)
				_verbose.info("ui", "✅", "quantum_config_ui hidden")
			else:
				_verbose.warn("ui", "❌", "quantum_config_ui is null!")
		_:
			push_warning("OverlayManager: Unknown overlay '%s'" % name)


func hide_all_overlays() -> void:
	"""Hide all overlays (useful when entering/exiting menus)"""
	for overlay_name in overlay_states.keys():
		hide_overlay(overlay_name)


func update_positions() -> void:
	"""Update positions of all overlays based on layout_manager"""
	if not layout_manager:
		return

	# Vocabulary overlay - position set during creation, can be overridden here if needed
	# (currently left at creation position for UX consistency)


func show_escape_menu() -> void:
	"""Show the escape menu"""
	show_overlay("escape_menu")


func hide_escape_menu() -> void:
	"""Hide the escape menu"""
	hide_overlay("escape_menu")


func is_menu_open() -> bool:
	"""Check if any menu/overlay is currently visible"""
	return overlay_states.values().any(func(visible): return visible)


# ============================================================================
# PRIVATE METHODS
# ============================================================================

func toggle_quest_board() -> void:
	"""Toggle quest board visibility (modal 4-slot system)"""
	_verbose.debug("quest", "🔄", "toggle_quest_board() called")
	if quest_board:
		_verbose.debug("quest", "→", "quest_board exists, visible = %s" % quest_board.visible)
		if quest_board.visible:
			_verbose.debug("quest", "→", "Board is visible, closing")
			quest_board.close_board()
		else:
			_verbose.debug("quest", "→", "Board is hidden, opening")
			if farm:
				# Get current biome from farm
				var biome = _get_current_biome(farm)
				if biome:
					quest_board.set_biome(biome)
					quest_board.open_board()
					overlay_states["quests"] = true
					overlay_toggled.emit("quests", true)
					_verbose.info("quest", "✅", "Quest board opened")
				else:
					_verbose.warn("quest", "❌", "No biome available!")
			else:
				_verbose.warn("quest", "❌", "Farm reference not set!")
	else:
		_verbose.warn("quest", "❌", "quest_board is null!")


func open_quest_board_faction_browser() -> void:
	"""Open faction browser from quest board (C key while board open)"""
	if quest_board and quest_board.visible:
		quest_board.open_faction_browser()
		_verbose.info("quest", "📚", "Opened faction browser from quest board")


func toggle_vocabulary_overlay() -> void:
	"""Toggle vocabulary overlay visibility and refresh content"""
	_verbose.debug("ui", "🔄", "toggle_vocabulary_overlay() called")
	if vocabulary_overlay:
		_verbose.debug("ui", "→", "vocabulary_overlay exists, visible = %s" % vocabulary_overlay.visible)
		if vocabulary_overlay.visible:
			_verbose.debug("ui", "→", "Overlay is visible, calling hide_overlay()")
			hide_overlay("vocabulary")
		else:
			_verbose.debug("ui", "→", "Overlay is hidden, refreshing and showing")
			_refresh_vocabulary_overlay()
			show_overlay("vocabulary")
	else:
		_verbose.warn("ui", "❌", "vocabulary_overlay is null!")


func toggle_escape_menu() -> void:
	"""Toggle escape menu visibility"""
	_verbose.debug("ui", "🔄", "toggle_escape_menu() called")
	if escape_menu:
		_verbose.debug("ui", "→", "escape_menu exists, is_visible() = %s" % escape_menu.is_visible())
		if escape_menu.is_visible():
			_verbose.debug("ui", "→", "Menu is visible, calling hide_overlay()")
			hide_overlay("escape_menu")
		else:
			_verbose.debug("ui", "→", "Menu is hidden, calling show_overlay()")
			show_overlay("escape_menu")
	else:
		_verbose.warn("ui", "❌", "escape_menu is null!")


func toggle_biome_inspector() -> void:
	"""Toggle biome inspector overlay (B key)"""
	_verbose.debug("ui", "🔄", "toggle_biome_inspector() called")
	if biome_inspector:
		if not farm:
			_verbose.warn("ui", "⚠️", "Farm reference not set in OverlayManager")
			return

		_verbose.debug("ui", "→", "biome_inspector exists, visible = %s" % biome_inspector.is_overlay_visible())
		if biome_inspector.is_overlay_visible():
			_verbose.debug("ui", "→", "Overlay is visible, hiding")
			biome_inspector.hide_overlay()
		else:
			_verbose.debug("ui", "→", "Overlay is hidden, showing all biomes")
			biome_inspector.show_all_biomes(farm)
	else:
		_verbose.warn("ui", "❌", "biome_inspector is null!")


func toggle_quantum_config_ui() -> void:
	"""Toggle quantum rigor config UI (Shift+Q)"""
	_verbose.debug("ui", "🔄", "toggle_quantum_config_ui() called")
	if quantum_config_ui:
		_verbose.debug("ui", "→", "quantum_config_ui exists, visible = %s" % quantum_config_ui.visible)
		if quantum_config_ui.visible:
			_verbose.debug("ui", "→", "Panel is visible, hiding")
			hide_overlay("quantum_config")
		else:
			_verbose.debug("ui", "→", "Panel is hidden, showing")
			show_overlay("quantum_config")
	else:
		_verbose.warn("ui", "❌", "quantum_config_ui is null!")


func _on_biome_inspector_closed() -> void:
	"""Handle biome inspector overlay closed signal"""
	overlay_states["biomes"] = false
	overlay_toggled.emit("biomes", false)


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


func _refresh_vocabulary_overlay() -> void:
	"""Refresh vocabulary overlay with current player vocabulary"""
	if not vocabulary_overlay:
		return

	const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")

	# Get player's known emojis from the canonical pair state.
	var gsm = get_node_or_null("/root/GameStateManager")
	var known_pairs: Array = []
	if gsm and gsm.has_method("get_player_vocab_pairs"):
		known_pairs = gsm.get_player_vocab_pairs()
	elif gsm and gsm.current_state:
		known_pairs = gsm.current_state.known_pairs
	var known_emojis: Array = GameState.derive_known_emojis_from_pairs(known_pairs)

	# Get stats label and emoji grid
	var stats_label = vocabulary_overlay.find_child("StatsLabel", true, false)
	var emoji_grid = vocabulary_overlay.find_child("EmojiGrid", true, false)

	if not stats_label or not emoji_grid:
		push_error("VocabularyOverlay missing required children!")
		return

	# Update stats
	var total_factions = FactionDatabase.ALL_FACTIONS.size()
	var accessible = gsm.get_accessible_factions().size() if gsm else 0

	stats_label.text = "Vocabulary: %d emojis | Accessible Factions: %d/%d (%.0f%%)" % [
		known_emojis.size(),
		accessible,
		total_factions,
		float(accessible) / total_factions * 100
	]

	# Clear existing emoji labels
	for child in emoji_grid.get_children():
		child.queue_free()

	# Add emoji labels (or buttons if Icon exists)
	var scale_factor = layout_manager.scale_factor if layout_manager else 1.0
	var emoji_font_size = layout_manager.get_scaled_font_size(32) if layout_manager else 32

	for emoji in known_emojis:
		# Check if Icon exists for this emoji
		var icon = _icon_registry.get_icon(emoji) if _icon_registry else null

		if icon:
			# Create button for emojis with Icons (clickable)
			var emoji_button = Button.new()
			emoji_button.text = emoji
			emoji_button.flat = true  # No button background
			emoji_button.add_theme_font_size_override("font_size", emoji_font_size)
			emoji_button.custom_minimum_size = Vector2(50 * scale_factor, 50 * scale_factor)

			# Visual indicator: slight yellow tint for Icons
			emoji_button.modulate = Color(1.0, 1.0, 0.7)  # Light yellow

			# Connect to Icon detail panel
			emoji_button.pressed.connect(_on_emoji_clicked.bind(emoji, icon))

			emoji_grid.add_child(emoji_button)
		else:
			# Create label for emojis without Icons (not clickable)
			var label = Label.new()
			label.text = emoji
			label.add_theme_font_size_override("font_size", emoji_font_size)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.custom_minimum_size = Vector2(50 * scale_factor, 50 * scale_factor)

			# Slightly dimmed for no Icon
			label.modulate = Color(0.8, 0.8, 0.8)

			emoji_grid.add_child(label)

	_verbose.debug("ui", "📖", "Vocabulary overlay refreshed: %d emojis, %d/%d factions accessible" % [
		known_emojis.size(),
		accessible,
		total_factions
	])


func _create_vocabulary_overlay() -> Control:
	"""Create vocabulary display overlay - shows player's discovered emojis"""
	var scale_factor = layout_manager.scale_factor if layout_manager else 1.0
	var font_size = layout_manager.get_scaled_font_size(18) if layout_manager else 18
	var title_font_size = layout_manager.get_scaled_font_size(24) if layout_manager else 24
	var stats_font_size = layout_manager.get_scaled_font_size(14) if layout_manager else 14

	# Main panel container
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500 * scale_factor, 600 * scale_factor)
	panel.position = Vector2(100 * scale_factor, 100 * scale_factor)
	panel.z_index = 1000
	panel.visible = false

	# VBox for content
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(10 * scale_factor))
	panel.add_child(vbox)

	# Header HBox
	var header_hbox = HBoxContainer.new()
	vbox.add_child(header_hbox)

	# Title
	var title = Label.new()
	title.text = "📖 Vocabulary"
	title.add_theme_font_size_override("font_size", title_font_size)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title)

	# Close button (top right)
	var close_btn = Button.new()
	close_btn.text = "✖"
	close_btn.add_theme_font_size_override("font_size", font_size)
	close_btn.pressed.connect(func():
		panel.visible = false
	)
	header_hbox.add_child(close_btn)

	# Stats label (shows faction accessibility)
	var stats_label = Label.new()
	stats_label.name = "StatsLabel"
	stats_label.add_theme_font_size_override("font_size", stats_font_size)
	stats_label.modulate = Color(0.7, 0.9, 1.0)  # Light blue
	vbox.add_child(stats_label)

	# Scroll container for emoji grid
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size.y = 450 * scale_factor
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	# Grid container for emojis
	var grid = GridContainer.new()
	grid.name = "EmojiGrid"
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", int(15 * scale_factor))
	grid.add_theme_constant_override("v_separation", int(15 * scale_factor))
	scroll.add_child(grid)

	# Close button (bottom)
	var close_btn_bottom = Button.new()
	close_btn_bottom.text = "Close [V]"
	close_btn_bottom.add_theme_font_size_override("font_size", font_size)
	close_btn_bottom.pressed.connect(func():
		panel.visible = false
	)
	vbox.add_child(close_btn_bottom)

	return panel


# _create_keyboard_hint_button REMOVED
# K key now opens ControlsOverlay via the overlay stack (toggle_overlay("controls"))


func _create_touch_button_bar() -> Control:
	"""Create touch-friendly button bar for LEFT CENTER of screen

	Buttons: C (Quests), V (Vocabulary), B (Biome), N (Inspector), K (Controls)
	All use the overlay stack for consistency.
	"""
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

	# C - Quest Board
	var quest_button = PanelTouchButton.new()
	quest_button.set_layout_manager(layout_manager)
	quest_button.button_emoji = "📋"
	quest_button.keyboard_hint = "[C]"
	quest_button.button_activated.connect(func(): toggle_overlay("quests"))
	button_bar.add_child(quest_button)

	# V - Vocabulary/Semantic Map
	var vocab_button = PanelTouchButton.new()
	vocab_button.set_layout_manager(layout_manager)
	vocab_button.button_emoji = "📖"
	vocab_button.keyboard_hint = "[V]"
	vocab_button.button_activated.connect(func(): toggle_overlay("semantic_map"))
	button_bar.add_child(vocab_button)

	# B - Biome Detail
	var biome_button = PanelTouchButton.new()
	biome_button.set_layout_manager(layout_manager)
	biome_button.button_emoji = "🌍"
	biome_button.keyboard_hint = "[B]"
	biome_button.button_activated.connect(func(): toggle_overlay("biome_detail"))
	button_bar.add_child(biome_button)

	# N - Inspector (density matrix + quantum state)
	var inspector_button = PanelTouchButton.new()
	inspector_button.set_layout_manager(layout_manager)
	inspector_button.button_emoji = "🔬"
	inspector_button.keyboard_hint = "[N]"
	inspector_button.button_activated.connect(func(): toggle_overlay("inspector"))
	button_bar.add_child(inspector_button)

	# K - Controls/Keyboard reference
	var controls_button = PanelTouchButton.new()
	controls_button.set_layout_manager(layout_manager)
	controls_button.button_emoji = "⌨️"
	controls_button.keyboard_hint = "[K]"
	controls_button.button_activated.connect(func(): toggle_overlay("controls"))
	button_bar.add_child(controls_button)

	_verbose.info("ui", "📱", "Touch button bar created: C/V/B/N/K on LEFT side")
	return button_bar


# ============================================================================
# MENU SIGNAL HANDLERS
# ============================================================================

func _on_menu_resume() -> void:
	"""Resume game from escape menu"""
	hide_overlay("escape_menu")
	menu_resumed.emit()


func _on_restart_pressed() -> void:
	"""Restart the game by reloading the current scene"""
	_verbose.info("ui", "🔄", "Restarting game...")
	# Ensure BootManager allows a fresh boot after scene reload.
	var boot_mgr = get_node_or_null("/root/BootManager")
	if boot_mgr:
		boot_mgr._core_booted = false
		boot_mgr._ui_booted = false
		boot_mgr._booted = false
		boot_mgr.is_ready = false
		_verbose.info("ui", "✓", "BootManager reset for restart")
	# Reset music completely before reloading
	if has_node("/root/MusicManager"):
		get_node("/root/MusicManager").reset()
	get_tree().reload_current_scene()
	emit_signal("restart_requested")


func _on_dev_restart_pressed() -> void:
	"""DEV RESTART: Hard reset autoloads + reload scene (Shift+R)

	This resets key singleton state so the boot sequence runs fresh.
	Useful for debugging initialization issues without restarting Godot.
	"""
	_verbose.info("ui", "🔧", "======================================================")
	_verbose.info("ui", "🔧", "DEV RESTART - Resetting autoloads for fresh boot")
	_verbose.info("ui", "🔧", "======================================================")

	# Reset BootManager so boot() will run again
	var boot_mgr = get_node_or_null("/root/BootManager")
	if boot_mgr:
		boot_mgr._core_booted = false
		boot_mgr._ui_booted = false
		boot_mgr._booted = false
		boot_mgr.is_ready = false
		_verbose.info("ui", "✓", "BootManager reset (_core_booted=false, _ui_booted=false)")

	# Reset GameStateManager
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm:
		gsm.active_farm = null
		_verbose.info("ui", "✓", "GameStateManager reset (active_farm=null)")

	# Reset ActiveBiomeManager
	var abm = get_node_or_null("/root/ActiveBiomeManager")
	if abm:
		if abm.has_method("reset"):
			abm.reset()
		else:
			# Manual reset if no reset method
			abm._active_biome = "BioticFlux" if "_active_biome" in abm else null
		_verbose.info("ui", "✓", "ActiveBiomeManager reset")

	# Reset MusicManager
	if has_node("/root/MusicManager"):
		get_node("/root/MusicManager").reset()
		_verbose.info("ui", "✓", "MusicManager reset")

	# Reset ActionChainTracker if it exists
	var act = get_node_or_null("/root/ActionChainTracker")
	if act and act.has_method("reset"):
		act.reset()
		_verbose.info("ui", "✓", "ActionChainTracker reset")

	# Reset ObservationFrame if it exists
	var obs = get_node_or_null("/root/ObservationFrame")
	if obs and obs.has_method("reset"):
		obs.reset()
		_verbose.info("ui", "✓", "ObservationFrame reset")

	_verbose.info("ui", "🔄", "Reloading scene with fresh boot...")
	get_tree().reload_current_scene()
	emit_signal("restart_requested")


func _on_save_pressed() -> void:
	"""Show save menu when Save is pressed from escape menu"""
	_verbose.debug("save", "📋", "OverlayManager._on_save_pressed() called")
	_verbose.debug("save", "→", "save_load_menu exists: %s" % (save_load_menu != null))
	if save_load_menu:
		_verbose.debug("save", "→", "Calling show_menu(SAVE)...")
		if save_load_menu.has_method("open_menu"):
			save_load_menu.open_menu(SaveLoadMenu.Mode.SAVE)
		else:
			save_load_menu.show_menu()
		_verbose.debug("save", "→", "save_load_menu.visible = %s" % save_load_menu.visible)
		_verbose.info("save", "💾", "Save menu opened")
	else:
		_verbose.warn("save", "⚠️", "Save/Load menu not available")


func _on_load_pressed() -> void:
	"""Show load menu when Load is pressed from escape menu"""
	_verbose.debug("save", "📋", "OverlayManager._on_load_pressed() called")
	_verbose.debug("save", "→", "save_load_menu exists: %s" % (save_load_menu != null))
	if save_load_menu:
		_verbose.debug("save", "→", "Calling show_menu(LOAD)...")
		if save_load_menu.has_method("open_menu"):
			save_load_menu.open_menu(SaveLoadMenu.Mode.LOAD)
		else:
			save_load_menu.show_menu()
		_verbose.debug("save", "→", "save_load_menu.visible = %s" % save_load_menu.visible)
		_verbose.info("save", "📂", "Load menu opened")
	else:
		_verbose.warn("save", "⚠️", "Save/Load menu not available")


func _on_reload_last_save_pressed() -> void:
	"""Reload the last saved game"""
	var gsm = get_node_or_null("/root/GameStateManager")
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
	var gsm = get_node_or_null("/root/GameStateManager")
	if not gsm:
		_verbose.error("save", "❌", "GameStateManager not available")
		return

	if mode == "save":
		# Save to the selected slot
		if gsm.save_game(slot):
			_verbose.info("save", "✅", "Game saved to slot %d" % (slot + 1))
			save_requested.emit(slot)
			save_load_menu.hide_menu()
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
			save_load_menu.hide_menu()
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
	save_load_menu.hide_menu()
	hide_overlay("escape_menu")


func _on_save_load_menu_closed() -> void:
	"""Handle save/load menu closed - return to escape menu"""
	_verbose.debug("save", "📋", "Returning from save/load menu to escape menu")
	# When user presses ESC in save/load menu, return to main escape menu (don't close it)
	if escape_menu:
		escape_menu.activate()
	else:
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


func _on_quest_board_closed() -> void:
	"""Handle when quest board is closed"""
	overlay_states["quests"] = false
	overlay_toggled.emit("quests", false)


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
	inspector_overlay.z_index = 2000  # Above regular overlays
	if layout_manager:
		inspector_overlay.set_layout_manager(layout_manager)
	parent.add_child(inspector_overlay)
	register_overlay("inspector", inspector_overlay)
	_setup_visibility_processing(inspector_overlay)

	# Create Controls Overlay (keyboard reference)
	controls_overlay = ControlsOverlay.new()
	controls_overlay.z_index = 2000
	if layout_manager:
		controls_overlay.set_layout_manager(layout_manager)
	parent.add_child(controls_overlay)
	register_overlay("controls", controls_overlay)
	_setup_visibility_processing(controls_overlay)

	# Create Semantic Map Overlay (vocabulary + octants)
	semantic_map_overlay = SemanticMapOverlay.new()
	semantic_map_overlay.z_index = 2000
	if layout_manager:
		semantic_map_overlay.set_layout_manager(layout_manager)
	parent.add_child(semantic_map_overlay)
	register_overlay("semantic_map", semantic_map_overlay)
	_setup_visibility_processing(semantic_map_overlay)

	# Create Balance Workbench Overlay (shared balance tuning projection)
	balance_workbench_overlay = BalanceWorkbenchOverlay.new()
	balance_workbench_overlay.z_index = 2000
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


func _center_overlay(overlay: Control) -> void:
	"""Center an overlay in the middle of the screen.

	Delegates to UILayoutManager if available, otherwise uses local fallback.
	"""
	# Delegate to layout_manager if available (single source of truth)
	if layout_manager and layout_manager.has_method("center_overlay"):
		var size = overlay.custom_minimum_size
		if size == Vector2.ZERO and layout_manager.has_method("get_overlay_size"):
			size = layout_manager.get_overlay_size()
		layout_manager.center_overlay(overlay, size)
		return

	# Fallback: manual centering
	overlay.anchor_left = 0.5
	overlay.anchor_right = 0.5
	overlay.anchor_top = 0.5
	overlay.anchor_bottom = 0.5

	# Get the minimum size (set by custom_minimum_size in overlay)
	var min_size = overlay.custom_minimum_size
	if min_size == Vector2.ZERO:
		min_size = Vector2(600, 400)  # Default fallback

	# Center the overlay around the anchor point
	overlay.offset_left = -min_size.x / 2
	overlay.offset_right = min_size.x / 2
	overlay.offset_top = -min_size.y / 2
	overlay.offset_bottom = min_size.y / 2

	# Ensure it grows from center
	overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	overlay.grow_vertical = Control.GROW_DIRECTION_BOTH


func register_overlay(name: String, overlay) -> void:
	"""Register an overlay for stack management.

	Args:
		name: Unique identifier (e.g., "inspector", "quests")
		overlay: OverlayBase instance
	"""
	if overlays.has(name):
		_verbose.warn("ui", "⚠️", "overlay '%s' already registered, replacing" % name)

	overlays[name] = overlay
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

	# Bind data to overlays that need it
	# Try multiple paths to find Farm node (scene structure varies)
	var farm_ref = get_tree().root.get_node_or_null("/root/FarmView/Farm")
	if not farm_ref:
		farm_ref = get_tree().root.get_node_or_null("/root/Farm")
	if not farm_ref:
		# Search in parent hierarchy (FarmView might not be at root)
		var parent = get_parent()
		while parent and not farm_ref:
			if parent.has_method("get_node_or_null"):
				farm_ref = parent.get_node_or_null("Farm")
			parent = parent.get_parent() if parent.has_method("get_parent") else null
	if not farm_ref:
		farm_ref = farm  # Fallback to stored reference
	if not farm_ref:
		# Final fallback: try GameStateManager
		var gsm = get_tree().root.get_node_or_null("/root/GameStateManager")
		if gsm and "active_farm" in gsm:
			farm_ref = gsm.active_farm

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


func close_all_overlays() -> void:
	"""Close all registered overlays (used by logger config for mutual exclusion)."""
	if not overlay_stack:
		return

	for name in overlays.keys():
		var overlay = overlays[name]
		if overlay_stack.has_overlay(overlay):
			overlay_stack.pop_overlay(overlay)
			overlay_changed.emit(name, false)


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


func get_active_overlay_actions() -> Dictionary:
	"""Get QER+F action labels for current overlay (for ActionPreviewRow).

	Returns empty dict if no overlay active.
	"""
	var top = get_active_overlay()
	if top and top.has_method("get_action_labels"):
		return top.get_action_labels()
	return {}


func get_overlay(name: String):
	"""Get a registered overlay by name, or null."""
	return overlays.get(name, null)


func has_overlay(name: String) -> bool:
	"""Check whether an overlay name is registered."""
	return overlays.has(name)


func get_registered_overlays() -> Array:
	"""Get list of all registered overlay names."""
	return overlays.keys()
