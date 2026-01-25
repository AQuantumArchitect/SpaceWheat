class_name ControlsOverlay
extends "res://UI/Overlays/V2OverlayBase.gd"

## ControlsOverlay - Full keyboard reference with section navigation
##
## Expands on KeyboardHintButton with full v2 overlay features:
##   - Section navigation via WASD/QE
##   - Compact/full toggle via F
##   - Search/filter via R
##
## Controls:
##   Q/E = Navigate sections
##   R = Search/filter (future)
##   F = Toggle compact/full mode
##   WASD = Navigate within section
##   ESC = Close overlay

# Sections
enum Section {
	TOOL_SELECTION,
	ACTIONS,
	LOCATION,
	OVERLAYS,
	QUANTUM_UI,
	ADVANCED
}

const SECTION_NAMES = [
	"Tool Selection",
	"Actions (QER)",
	"Location",
	"Overlays & Menus",
	"Quantum UI",
	"Advanced Actions"
]

const SECTION_ICONS = ["🛠️", "⚡", "📍", "📋", "🔬", "⚡"]

var current_section: int = Section.TOOL_SELECTION
var compact_mode: bool = false

# UI elements
var section_tabs: HBoxContainer
var content_container: Control
var section_panels: Array = []  # Array of PanelContainer

# Layout
const COMPACT_HEIGHT: int = 300


func _init():
	overlay_name = "controls"
	overlay_icon = "⌨️"
	overlay_title = "⌨️ Keyboard Controls"
	fallback_panel_width = 650
	fallback_panel_height = 500
	panel_border_color = Color(0.5, 0.5, 0.3, 0.8)  # Gold/tan border
	main_vbox_separation = UIStyleFactory.VBOX_SPACING_NORMAL
	# Enable corner ornamentation
	use_ornamentation = true
	ornamentation_tint = UIOrnamentation.TINT_GOLD
	action_labels = {
		"Q": "Prev Section",
		"E": "Next Section",
		"R": "Search",
		"F": "Compact/Full"
	}


func _ready() -> void:
	super._ready()
	_build_ui()


func _build_ui() -> void:
	"""Build the controls overlay UI."""
	# Use base class to create standard panel (handles sizing, background, vbox, title)
	var vbox = _build_standard_panel()

	# Section tabs
	section_tabs = _create_section_tabs()
	vbox.add_child(section_tabs)

	# Content area with scroll
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(scroll)

	content_container = VBoxContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_container)

	# Create section panels
	_create_section_panels()
	_update_section_display()


func _create_section_tabs() -> HBoxContainer:
	"""Create section tab bar."""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	for i in range(SECTION_NAMES.size()):
		var tab = Button.new()
		tab.text = "%s %s" % [SECTION_ICONS[i], SECTION_NAMES[i]]
		tab.add_theme_font_size_override("font_size", 12)
		tab.toggle_mode = true
		tab.button_pressed = (i == current_section)
		tab.pressed.connect(func(): _select_section(i))
		hbox.add_child(tab)

	return hbox


func _create_section_panels() -> void:
	"""Create content for each section."""
	section_panels.clear()

	# Tool Selection
	section_panels.append(_create_tool_section())
	# Actions
	section_panels.append(_create_actions_section())
	# Location
	section_panels.append(_create_location_section())
	# Overlays
	section_panels.append(_create_overlays_section())
	# Quantum UI
	section_panels.append(_create_quantum_section())
	# Advanced
	section_panels.append(_create_advanced_section())


func _create_tool_section() -> Control:
	"""Create tool selection help section."""
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)

	# Mode toggle header
	var mode_header = Label.new()
	mode_header.text = "Tab = Toggle PLAY/BUILD Mode"
	mode_header.add_theme_font_size_override("font_size", 14)
	mode_header.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	content.add_child(mode_header)

	# PLAY mode tools
	var play_label = Label.new()
	play_label.text = "\nPLAY MODE (default):"
	play_label.add_theme_font_size_override("font_size", 13)
	play_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	content.add_child(play_label)

	var play_entries = [
		["1", "🔬 Probe", "Explore/Measure/Pop (core loop)"],
		["2", "⚡ Gates", "X/H/Ry + F-cycle to Z/S/T"],
		["3", "🔗 Entangle", "CNOT/SWAP/CZ + F-cycle to Bell/Disentangle"],
		["4", "🏭 Industry", "Mill/Market/Kitchen + F-cycle to Harvest"]
	]

	for entry in play_entries:
		content.add_child(_create_help_row(entry[0], entry[1], entry[2]))

	# BUILD mode tools
	var build_label = Label.new()
	build_label.text = "\nBUILD MODE (Tab to switch):"
	build_label.add_theme_font_size_override("font_size", 13)
	build_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
	content.add_child(build_label)

	var build_entries = [
		["1", "🌍 Biome", "Assign plots to biomes"],
		["2", "⚙️ Icon", "Configure emoji icons"],
		["3", "🔬 Lindblad", "Drive/Decay/Transfer dissipation"],
		["4", "⚛️ Quantum", "Reset/Snapshot/Debug + F-cycle to phase gates"]
	]

	for entry in build_entries:
		content.add_child(_create_help_row(entry[0], entry[1], entry[2]))

	return content


func _create_actions_section() -> Control:
	"""Create QER actions help section."""
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)

	var desc = Label.new()
	desc.text = "Q, E, R = Context-sensitive actions that change based on selected tool"
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(desc)

	var entries = [
		["Q", "First Action", "Primary action for current tool"],
		["E", "Second Action", "Secondary action for current tool"],
		["R", "Third Action", "Tertiary action for current tool"],
		["F", "Cycle Mode", "Switch tool sub-modes (Gates, Entangle, Industry, Quantum)"],
		["Tab", "PLAY↔BUILD", "Toggle between PLAY and BUILD mode tools"],
		["Space", "Pause/Resume", "Pause/resume quantum evolution"],
		["H", "Harvest All", "Global harvest (collapse all measured)"]
	]

	for entry in entries:
		content.add_child(_create_help_row(entry[0], entry[1], entry[2]))

	return content


func _create_location_section() -> Control:
	"""Create location navigation help section."""
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)

	var entries = [
		["WASD", "Move Cursor", "Navigate plot selection"],
		["Y", "Location 1", "Quick-select first location"],
		["U", "Location 2", "Quick-select second location"],
		["I", "Location 3", "Quick-select third location"],
		["O", "Location 4", "Quick-select fourth location"],
		["P", "Location 5", "Quick-select fifth location"]
	]

	for entry in entries:
		content.add_child(_create_help_row(entry[0], entry[1], entry[2]))

	return content


func _create_overlays_section() -> Control:
	"""Create overlays help section."""
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)

	var entries = [
		["C", "Quest Board", "View and manage faction quests"],
		["V", "Vocabulary", "Semantic vocabulary/meaning-space"],
		["B", "Biome Inspector", "Detailed biome inspection"],
		["K", "Keyboard Help", "Toggle quick keyboard reference"],
		["L", "Logger Config", "Debug logging settings"],
		["ESC", "Pause Menu", "Save, Load, Settings, Quit"]
	]

	for entry in entries:
		content.add_child(_create_help_row(entry[0], entry[1], entry[2]))

	var pause_label = Label.new()
	pause_label.text = "\nIn Pause Menu: S=Save, L=Load, X=Quantum Settings, D=Reload, R=Restart, Q=Quit"
	pause_label.add_theme_font_size_override("font_size", 12)
	pause_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	pause_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(pause_label)

	return content


func _create_quantum_section() -> Control:
	"""Create quantum UI help section."""
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)

	var left_label = Label.new()
	left_label.text = "Left Side Panel (Collapsible):"
	left_label.add_theme_font_size_override("font_size", 14)
	left_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	content.add_child(left_label)

	var left_items = Label.new()
	left_items.text = "  • Energy Meter (real vs imaginary)\n  • Uncertainty Meter (precision/flexibility)\n  • Semantic Context (octant/region)\n  • Attractor Personality"
	left_items.add_theme_font_size_override("font_size", 13)
	left_items.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	content.add_child(left_items)

	var right_label = Label.new()
	right_label.text = "\nTop Right - Quantum Mode Indicator:"
	right_label.add_theme_font_size_override("font_size", 14)
	right_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	content.add_child(right_label)

	var right_items = Label.new()
	right_items.text = "  Shows: HARDWARE/INSPECTOR mode\n  Configure: ESC → X (Quantum Settings)"
	right_items.add_theme_font_size_override("font_size", 13)
	right_items.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	content.add_child(right_items)

	return content


func _create_advanced_section() -> Control:
	"""Create advanced tool actions help section."""
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)

	# PLAY MODE Tools with F-cycling
	var play_header = Label.new()
	play_header.text = "PLAY MODE - F-Cycling Details:"
	play_header.add_theme_font_size_override("font_size", 14)
	play_header.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	content.add_child(play_header)

	# Tool 2: Gates
	var t2_label = Label.new()
	t2_label.text = "\nTool 2 (Gates) - F-cycles:"
	t2_label.add_theme_font_size_override("font_size", 13)
	t2_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	content.add_child(t2_label)

	content.add_child(_create_help_row("Convert", "X/H/Ry", "Bit flip, Superposition, Tune probability"))
	content.add_child(_create_help_row("Phase", "Z/S/T", "Phase flip, π/2 phase, π/4 phase"))

	# Tool 3: Entangle
	var t3_label = Label.new()
	t3_label.text = "\nTool 3 (Entangle) - F-cycles:"
	t3_label.add_theme_font_size_override("font_size", 13)
	t3_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	content.add_child(t3_label)

	content.add_child(_create_help_row("Link", "CNOT/SWAP/CZ", "Two-qubit gates"))
	content.add_child(_create_help_row("Manage", "Bell/Disentangle/Inspect", "Entanglement control"))

	# Tool 4: Industry
	var t4_label = Label.new()
	t4_label.text = "\nTool 4 (Industry) - F-cycles:"
	t4_label.add_theme_font_size_override("font_size", 13)
	t4_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	content.add_child(t4_label)

	content.add_child(_create_help_row("Build", "Mill/Market/Kitchen", "Place structures"))
	content.add_child(_create_help_row("Harvest", "Flour/Sell/Bake", "Operate structures"))

	# BUILD MODE
	var build_header = Label.new()
	build_header.text = "\nBUILD MODE - Tab to access:"
	build_header.add_theme_font_size_override("font_size", 14)
	build_header.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
	content.add_child(build_header)

	content.add_child(_create_help_row("Tool 1", "Biome", "Assign/Clear/Inspect biome assignments"))
	content.add_child(_create_help_row("Tool 2", "Icon", "Assign/Swap/Clear emoji icons"))
	content.add_child(_create_help_row("Tool 3", "Lindblad", "Drive/Decay/Transfer dissipation"))
	content.add_child(_create_help_row("Tool 4", "Quantum", "Reset/Snapshot/Debug + phase gates"))

	return content


func _create_help_row(key: String, action: String, description: String) -> Control:
	"""Create a help row: [KEY] Action - Description."""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	# Key label
	var key_label = Label.new()
	key_label.text = "[%s]" % key
	key_label.custom_minimum_size = Vector2(80, 0)
	key_label.add_theme_font_size_override("font_size", 13)
	key_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	hbox.add_child(key_label)

	# Action label
	var action_label = Label.new()
	action_label.text = action
	action_label.custom_minimum_size = Vector2(140, 0)
	action_label.add_theme_font_size_override("font_size", 13)
	action_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	hbox.add_child(action_label)

	# Description label
	var desc_label = Label.new()
	desc_label.text = description
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(desc_label)

	return hbox


func _update_section_display() -> void:
	"""Update which section is visible."""
	# Show/hide panels based on current section (don't delete them!)
	# First, ensure all panels are added to content_container if not already
	for i in range(section_panels.size()):
		var panel = section_panels[i]
		if panel.get_parent() != content_container:
			content_container.add_child(panel)
		panel.visible = (i == current_section)

	# Update tab states
	for i in range(section_tabs.get_child_count()):
		var tab = section_tabs.get_child(i)
		if tab is Button:
			tab.button_pressed = (i == current_section)

	# Update compact mode
	if compact_mode:
		custom_minimum_size.y = COMPACT_HEIGHT
	else:
		var panel_size = _get_recommended_size()
		custom_minimum_size.y = panel_size.y if panel_size.y > 0 else fallback_panel_height


func _select_section(index: int) -> void:
	"""Select a section by index."""
	if index >= 0 and index < SECTION_NAMES.size():
		current_section = index
		_update_section_display()
		action_performed.emit("section_changed", {"section": SECTION_NAMES[index]})


# ============================================================================
# ACTION HANDLERS
# ============================================================================

func on_q_pressed() -> void:
	"""Q = Previous section."""
	current_section = (current_section - 1) % SECTION_NAMES.size()
	if current_section < 0:
		current_section = SECTION_NAMES.size() - 1
	_update_section_display()
	action_performed.emit("prev_section", {"section": SECTION_NAMES[current_section]})


func on_e_pressed() -> void:
	"""E = Next section."""
	current_section = (current_section + 1) % SECTION_NAMES.size()
	_update_section_display()
	action_performed.emit("next_section", {"section": SECTION_NAMES[current_section]})


func on_r_pressed() -> void:
	"""R = Search/filter (future feature)."""
	action_performed.emit("search", {})
	# TODO: Implement search popup


func on_f_pressed() -> void:
	"""F = Toggle compact/full mode."""
	compact_mode = not compact_mode
	_update_section_display()
	action_performed.emit("toggle_compact", {"compact": compact_mode})


func get_action_labels() -> Dictionary:
	"""v2 overlay interface: Get current QER+F labels."""
	return action_labels
