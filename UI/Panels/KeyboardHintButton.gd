class_name KeyboardHintButton
extends Button

## Small keyboard hint toggle button [K]
## Shows in GoalPanel corner, toggles popup with keyboard shortcuts
## Provides clean UI without always-visible keyboard help

var hints_panel: PanelContainer
var hints_visible: bool = false

# Layout manager for scaling
var layout_manager
var scale_factor: float = 1.0

# Signal
signal hints_toggled(visible: bool)


func _ready():
	# Button setup
	text = "[K] Keyboard"
	custom_minimum_size = Vector2(150 * scale_factor, 40 * scale_factor)
	pressed.connect(_on_button_pressed)

	# Position button in upper right
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -160 * scale_factor  # Offset from right edge
	offset_top = 10 * scale_factor     # Offset from top

	# Ensure button is clickable and visible above farm UI
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 1000

	# Create hints panel (initially hidden)
	hints_panel = _create_hints_panel()
	get_parent().add_child(hints_panel)

	print("⌨️  KeyboardHintButton initialized (upper right)")


func toggle_hints() -> void:
	"""Toggle keyboard hints panel visibility"""
	if hints_panel:
		hints_visible = not hints_visible
		hints_panel.visible = hints_visible
		hints_toggled.emit(hints_visible)
		print("⌨️  Keyboard hints %s" % ("shown" if hints_visible else "hidden"))


func set_layout_manager(mgr) -> void:
	"""Set layout manager for responsive scaling"""
	layout_manager = mgr
	if layout_manager:
		scale_factor = layout_manager.scale_factor
		custom_minimum_size = Vector2(150 * scale_factor, 40 * scale_factor)


# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _on_button_pressed() -> void:
	"""Handle button press"""
	toggle_hints()


func _create_hints_panel() -> PanelContainer:
	"""Create keyboard hints popup panel"""
	var scale_factor = layout_manager.scale_factor if layout_manager else 1.0
	var font_size = layout_manager.get_scaled_font_size(14) if layout_manager else 14
	var title_font_size = layout_manager.get_scaled_font_size(18) if layout_manager else 18

	# Main panel container with scroll support
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(600 * scale_factor, 500 * scale_factor)
	# Position in upper right below the button
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -620 * scale_factor  # Panel width + margin
	panel.offset_top = 60 * scale_factor     # Below button
	panel.z_index = 2000  # Above overlays
	panel.visible = false

	# Add scroll container for long content
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(580 * scale_factor, 480 * scale_factor)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(scroll)

	# VBox for content inside scroll
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(8 * scale_factor))
	scroll.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "⌨️  Keyboard Controls"
	title.add_theme_font_size_override("font_size", title_font_size)
	vbox.add_child(title)

	# Separator
	var sep1 = Control.new()
	sep1.custom_minimum_size.y = int(5 * scale_factor)
	vbox.add_child(sep1)

	# Tool selection section
	var tool_section = Label.new()
	tool_section.text = "🛠️  TOOL SELECTION (Numbers 1-6):"
	tool_section.add_theme_font_size_override("font_size", font_size)
	tool_section.add_theme_font_size_override("font_size", title_font_size)
	vbox.add_child(tool_section)

	var tool_help = Label.new()
	tool_help.text = """  1 = Grower 🌱 (Plant, Entangle, Measure+Harvest)
  2 = Quantum ⚛️ (Cluster, Peek, Measure)
  3 = Industry 🏭 (Build Market/Kitchen)
  4 = Biome Control ⚡ (Energy Tap, Lindblad, Pump/Reset)
  5 = Gates 🔄 (1-Qubit Gates, 2-Qubit Gates, Remove)
  6 = Biome 🌍 (Assign Biome, Clear, Inspect)"""
	tool_help.add_theme_font_size_override("font_size", font_size)
	tool_help.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(tool_help)

	# Separator
	var sep2 = Control.new()
	sep2.custom_minimum_size.y = int(5 * scale_factor)
	vbox.add_child(sep2)

	# Actions section
	var action_section = Label.new()
	action_section.text = "⚡ ACTIONS (Q/E/R - Context-sensitive):"
	action_section.add_theme_font_size_override("font_size", title_font_size)
	vbox.add_child(action_section)

	var action_help = Label.new()
	action_help.text = """  Q = First action for selected tool
  E = Second action for selected tool
  R = Third action for selected tool
  (Actions change based on selected tool)"""
	action_help.add_theme_font_size_override("font_size", font_size)
	action_help.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(action_help)

	# Separator
	var sep3 = Control.new()
	sep3.custom_minimum_size.y = int(5 * scale_factor)
	vbox.add_child(sep3)

	# Location section
	var loc_section = Label.new()
	loc_section.text = "📍 LOCATION SELECTION:"
	loc_section.add_theme_font_size_override("font_size", title_font_size)
	vbox.add_child(loc_section)

	var loc_help = Label.new()
	loc_help.text = """  WASD = Move cursor (Up, Left, Down, Right)
  Y/U/I/O/P = Quick-select locations 1-5"""
	loc_help.add_theme_font_size_override("font_size", font_size)
	loc_help.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(loc_help)

	# Separator
	var sep4 = Control.new()
	sep4.custom_minimum_size.y = int(5 * scale_factor)
	vbox.add_child(sep4)

	# Overlays section
	var overlay_section = Label.new()
	overlay_section.text = "📋 OVERLAYS & MENUS:"
	overlay_section.add_theme_font_size_override("font_size", title_font_size)
	vbox.add_child(overlay_section)

	var overlay_help = Label.new()
	overlay_help.text = """  C = Quest Board
  V = Vocabulary panel
  L = Logger config (debug)
  ESC = Pause menu
    In Pause Menu:
    • S = Save Game
    • L = Load Game
    • X = Quantum Settings
    • D = Reload Last Save
    • R = Restart
    • Q = Quit"""
	overlay_help.add_theme_font_size_override("font_size", font_size)
	overlay_help.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(overlay_help)

	# Separator
	var sep5 = Control.new()
	sep5.custom_minimum_size.y = int(5 * scale_factor)
	vbox.add_child(sep5)

	# Quantum UI section
	var quantum_section = Label.new()
	quantum_section.text = "🔬 QUANTUM UI (Always Visible):"
	quantum_section.add_theme_font_size_override("font_size", title_font_size)
	vbox.add_child(quantum_section)

	var quantum_help = Label.new()
	quantum_help.text = """  Left Side:
    • Quantum HUD Panel (collapsible)
      - Energy Meter (real vs imaginary)
      - Uncertainty Meter (precision/flexibility)
      - Semantic Context (octant/region)
      - Attractor Personality

  Top Right:
    • Quantum Mode Indicator
      Shows: HARDWARE/INSPECTOR mode
      Configure: ESC → X (Quantum Settings)"""
	quantum_help.add_theme_font_size_override("font_size", font_size)
	quantum_help.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(quantum_help)

	# Separator
	var sep6 = Control.new()
	sep6.custom_minimum_size.y = int(5 * scale_factor)
	vbox.add_child(sep6)

	# Advanced tool actions section
	var advanced_section = Label.new()
	advanced_section.text = "⚡ ADVANCED TOOL ACTIONS:"
	advanced_section.add_theme_font_size_override("font_size", title_font_size)
	vbox.add_child(advanced_section)

	var advanced_help = Label.new()
	advanced_help.text = """  Tool 2 (Quantum):
    • E = Peek State (no collapse)
      Shows probabilities without measurement
    • R = Batch Measure
      Measures entire entangled components

  Tool 4 (Biome Control):
    • E → Q/E/R = Lindblad Operations
      Drive (+pop), Decay (-pop), Transfer
    • R → Q/E/R = Pump/Reset
      Pump to wheat, Reset pure, Reset mixed

  Tool 5 (Gates):
    • Q → Q/E/R = Basic 1-Qubit Gates
      Pauli-X (flip), Hadamard (superposition), Pauli-Z (phase)
    • E → Q/E/R = Phase Gates
      Pauli-Y, S-gate (π/2), T-gate (π/4)
    • R → Q/E/R = 2-Qubit Gates
      CNOT, CZ, SWAP

  Tool 6 (Biome):
    • R = Inspect Plot
      Opens detailed biome inspector"""
	advanced_help.add_theme_font_size_override("font_size", font_size)
	advanced_help.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(advanced_help)

	# Separator
	var sep7 = Control.new()
	sep7.custom_minimum_size.y = int(8 * scale_factor)
	vbox.add_child(sep7)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close [K]"
	close_btn.add_theme_font_size_override("font_size", font_size)
	close_btn.pressed.connect(func():
		toggle_hints()
	)
	vbox.add_child(close_btn)

	return panel
