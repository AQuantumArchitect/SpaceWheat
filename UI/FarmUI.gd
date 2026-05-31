## FarmUI - Farm-level UI layer
## Handles:
## - Plot grid display and tiles
## - Keyboard selection (T/Y/U/I/O/P/0/9/8/7)
## - Frame switching (hat row 4-0, sub-modes 1-3)
## - Action execution (Q/E/R)
##
## This layer is swappable - created fresh for each farm

class_name FarmUI
extends Control

signal farm_setup_complete  # Emitted when setup_farm() finishes and instrument_input is ready

# Input is handled by QuantumInstrumentInput (created in BootManager)
const QuantumModeStatusIndicator = preload("res://UI/Widgets/QuantumModeStatusIndicator.gd")

var farm: Node
var grid_config: GridConfig
var plot_grid_display = null  # From scene
var instrument_input = null  # Created dynamically
var resource_panel = null  # From scene
var quantum_mode_indicator = null  # Created dynamically
var quantum_visualization = null  # Optional - only if needed later
var layout_manager: Node = null

# DEBUG: Layout visibility
var debug_layout_visible: bool = false
var debug_label: Label = null


func _log_debug(message: String) -> void:
	VerboseHelper.debug("ui", "farm", message)


func _ready() -> void:
	# FarmUI scene is ready - get references to child nodes and setup layout.

	# NOTE: Farm setup (setup_farm()) will be called by BootManager after all
	# dependencies are guaranteed to exist. We only initialize scene structure here.
	_log_debug("🎮 FarmUI initializing from scene...")

	# Ensure FarmUI is properly sized to fill parent (using anchors)
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Get references to scene-defined child nodes
	resource_panel = get_node("MainContainer/ResourcePanel")
	plot_grid_display = get_node("PlotGridDisplay")  # Now sibling of MainContainer
	# Action bars (ToolSelectionRow, ActionPreviewRow) are now managed by PlayerShell's ActionBarManager

	# Quantum mode status indicator removed - no longer needed in Phase 2 UI

	_log_debug("   ✅ All child nodes referenced")

	if layout_manager:
		inject_layout_manager(layout_manager)

	# CRITICAL: Ensure FarmUI fills its parent (FarmUIContainer)
	# This continues the delegation cascade: FarmView → PlayerShell → FarmUIContainer → FarmUI
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# FarmUI.tscn already has full anchors (0,0,1,1), so size is automatically controlled
	# MainContainer.tscn also has full anchors, so it automatically fills FarmUI
	# NO manual size setting needed - anchors handle it!

	# CRITICAL: MainContainer must pass input through to PlotGridDisplay below
	var main_container = get_node_or_null("MainContainer")
	if main_container:
		main_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_log_debug("   ✅ MainContainer mouse_filter set to IGNORE for plot tile input")

	# Apply responsive sizing BEFORE layout engine runs (critical - must happen in _ready)
	_apply_parametric_sizing()

	# DEBUG: Add info about toggling debug display
	_log_debug("💡 Press F3 to toggle layout debug display")
	_log_debug("   ⏳ Waiting for BootManager to call setup_farm()...")


func setup_farm(farm_ref: Node) -> void:
	# Configure FarmUI for a specific farm (called after scene instantiation)
	_log_debug("📂 Loading farm into FarmUI...")

	farm = farm_ref
	grid_config = farm.grid_config if farm else null

	# Wire ResourcePanel to economy
	if farm and farm.economy and resource_panel:
		if resource_panel.has_method("connect_to_economy"):
			resource_panel.connect_to_economy(farm.economy)
			_log_debug("   ✅ ResourcePanel wired to economy")
		else:
			push_warning("FarmUI.setup_farm: resource_panel has no connect_to_economy()")

	# Wire PlotGridDisplay to farm
	if farm and plot_grid_display:
		plot_grid_display.inject_farm(farm)
		plot_grid_display.inject_grid_config(grid_config)
		if farm.grid and farm.grid.has_biomes():
			plot_grid_display.inject_biomes(farm.grid.get_all_biomes())

		_log_debug("   ✅ PlotGridDisplay wired to farm")

	# Action bars (ToolSelectionRow, ActionPreviewRow) are now managed by PlayerShell's ActionBarManager
	# Signal connections are handled in PlayerShell.load_farm_ui()

	# Instrument input is created in BootManager and injected here

	# Wire instrument input (will be set by BootManager after creation)
	if farm and instrument_input:
		instrument_input.farm = farm
		instrument_input.inject_plot_grid_display(plot_grid_display)

	# Wire plot selection changes
	if plot_grid_display and plot_grid_display.has_signal("selection_count_changed"):
		if not plot_grid_display.selection_count_changed.is_connected(_on_selection_changed):
			plot_grid_display.selection_count_changed.connect(_on_selection_changed)
		_log_debug("   📡 Connected to plot selection changes")

	_log_debug("✅ FarmUI farm setup complete")
	farm_setup_complete.emit()  # Signal PlayerShell that instrument_input is ready


func inject_layout_manager(layout_mgr: Node) -> void:
	# Inject shared UILayoutManager for normalized sizing.
	layout_manager = layout_mgr
	if resource_panel and resource_panel.has_method("set_layout_manager"):
		resource_panel.set_layout_manager(layout_manager)
	if plot_grid_display and plot_grid_display.has_method("inject_layout_manager"):
		plot_grid_display.inject_layout_manager(layout_manager)


func _input(event: InputEvent) -> void:
	# Handle debug display toggle and UI input

	# Note: Tool selection (1-4) is handled by QuantumInstrumentInput via signals
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:  # F3 to toggle debug layout display
			debug_layout_visible = not debug_layout_visible
			_update_debug_display()
			get_viewport().set_input_as_handled()


func _on_selection_changed(count: int) -> void:
	# Handle plot selection changes
	var has_selection = count > 0
	if has_selection:
		_log_debug("✅ %d plot(s) selected - Q/E/R actions available" % count)
	else:
		_log_debug("❌ No plots selected - Q/E/R actions disabled")


func _apply_parametric_sizing() -> void:
	# Apply parametric sizing to UI components based on viewport dimensions.

	# Uses UILayoutManager constants for consistent layout proportions.
	var viewport_size = get_viewport_rect().size
	var viewport_height = viewport_size.y

	# Use UILayoutManager constants for consistent proportions across all UI
	var top_bar_percent = UILayoutManager.TOP_BAR_HEIGHT_PERCENT  # 0.06 (6%)

	# Parametric layout: divide viewport into zones
	# 0-6% (Top): ResourcePanel
	# 6-100% (Middle): PlotGridDisplay
	# Action bars are now in PlayerShell's ActionBarLayer (bottom, fixed 140px)

	var resource_panel_height = viewport_height * top_bar_percent
	var plot_grid_height = viewport_height * (1.0 - top_bar_percent)

	# Apply to MainContainer children
	if resource_panel:
		resource_panel.custom_minimum_size = Vector2(0, resource_panel_height)

	if plot_grid_display:
		plot_grid_display.custom_minimum_size = Vector2(0, plot_grid_height)


func _update_debug_display() -> void:
	# Update or create debug display showing layout positions
	if debug_layout_visible:
		# Create debug label if needed
		if debug_label == null:
			debug_label = Label.new()
			debug_label.z_index = 1000  # Above everything
			debug_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
			add_child(debug_label)

		# Build debug text with detailed layout info
		var debug_text = "=== LAYOUT DEBUG (Press F3 to toggle) ===\n"
		debug_text += "\n(Action bars debug available in PlayerShell)\n"

		debug_text += "\nMainContainer:\n"
		var main_container = get_node_or_null("MainContainer")
		if main_container:
			debug_text += "  Position: (%.0f, %.0f)\n" % [main_container.position.x, main_container.position.y]
			debug_text += "  Size: %.0f × %.0f\n" % [main_container.size.x, main_container.size.y]
			debug_text += "  Size flags H: %d\n" % main_container.size_flags_horizontal

		debug_text += "\nFarmUI (root):\n"
		debug_text += "  Size: %.0f × %.0f\n" % [size.x, size.y]
		debug_text += "  Viewport: %.0f × %.0f\n" % [get_viewport_rect().size.x, get_viewport_rect().size.y]

		debug_label.text = debug_text
		debug_label.position = Vector2(10, 10)
		debug_label.add_theme_font_size_override("font_size", 10)
		debug_label.show()
	else:
		if debug_label != null:
			debug_label.hide()

## ========================================
## Phase 1 UI Integration: Quantum Mode Indicator
## ========================================

func _create_quantum_mode_indicator() -> void:
	# Create and position quantum rigor mode status indicator (top-right corner)
	# Create the indicator component
	quantum_mode_indicator = QuantumModeStatusIndicator.new()

	# Get MainContainer to add it there
	var main_container = get_node_or_null("MainContainer")
	if not main_container:
		push_error("Cannot create quantum mode indicator: MainContainer not found")
		return

	# Add as child of MainContainer
	main_container.add_child(quantum_mode_indicator)

	# Position in top-right corner
	quantum_mode_indicator.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	quantum_mode_indicator.offset_left = -220  # 220 pixels from right edge
	quantum_mode_indicator.offset_top = 8      # 8 pixels from top
	quantum_mode_indicator.custom_minimum_size = Vector2(210, 40)

	# Enable input processing for the indicator
	quantum_mode_indicator.mouse_filter = Control.MOUSE_FILTER_PASS

	_log_debug("   ✅ Quantum mode status indicator created (top-right corner)")
