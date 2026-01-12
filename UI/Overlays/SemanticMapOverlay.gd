class_name SemanticMapOverlay
extends "res://UI/Overlays/V2OverlayBase.gd"

## SemanticMapOverlay - Octant visualization and vocabulary explorer
##
## Displays the 8 semantic octants with:
##   - Current region highlight
##   - Vocabulary (discovered emojis) per octant
##   - Strange attractor visualization
##
## Controls:
##   Q = Navigate octants
##   E = Zoom into selected octant
##   R = Show attractors
##   F = Cycle projection mode (2D/3D view)
##   WASD = Navigate within octant emojis
##   ESC = Close overlay

const V2OverlayBaseClass = preload("res://UI/Overlays/V2OverlayBase.gd")

# Semantic octant regions (from SemanticOctant.gd)
const REGIONS = [
	{"name": "Phoenix", "icon": "🔥", "desc": "Abundance & transformation", "color": Color(1.0, 0.6, 0.2)},
	{"name": "Sage", "icon": "🧙", "desc": "Wisdom & patience", "color": Color(0.6, 0.4, 0.8)},
	{"name": "Warrior", "icon": "⚔️", "desc": "Conflict & struggle", "color": Color(0.9, 0.2, 0.2)},
	{"name": "Merchant", "icon": "💰", "desc": "Trade & accumulation", "color": Color(1.0, 0.85, 0.3)},
	{"name": "Ascetic", "icon": "🧘", "desc": "Minimalism & conservation", "color": Color(0.5, 0.5, 0.5)},
	{"name": "Gardener", "icon": "🌻", "desc": "Cultivation & harmony", "color": Color(0.3, 0.8, 0.3)},
	{"name": "Innovator", "icon": "💡", "desc": "Experimentation & chaos", "color": Color(0.3, 0.7, 1.0)},
	{"name": "Guardian", "icon": "🛡️", "desc": "Defense & protection", "color": Color(0.4, 0.4, 0.6)}
]

# View modes
enum ViewMode { OCTANT_GRID, VOCABULARY, ATTRACTOR_MAP }
const VIEW_MODE_NAMES = ["Octant Grid", "Vocabulary", "Attractor Map"]

var current_view_mode: int = ViewMode.OCTANT_GRID
var selected_octant: int = 0
var vocabulary_data: Dictionary = {}  # Loaded from game state

# UI elements
var title_label: Label
var view_mode_label: Label
var octant_grid: GridContainer
var vocab_container: Control
var attractor_container: Control
var octant_panels: Array = []  # References to octant panel nodes
var emoji_grid: GridContainer

# Layout
const PANEL_WIDTH: int = 650
const PANEL_HEIGHT: int = 500
const OCTANT_SIZE: int = 140


func _init():
	overlay_name = "semantic_map"
	overlay_icon = "🧭"
	action_labels = {
		"Q": "Prev Octant",
		"E": "Next Octant",
		"R": "Attractors",
		"F": "View Mode"
	}


func _ready() -> void:
	super._ready()
	_build_ui()


func _build_ui() -> void:
	"""Build the semantic map overlay UI."""
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.10, 0.14, 0.95)
	panel_style.border_color = Color(0.4, 0.3, 0.6, 0.8)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", panel_style)

	# Main layout
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	# Title bar
	var title_bar = _create_title_bar()
	vbox.add_child(title_bar)

	# Content area
	var content = Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)

	# Octant grid view
	octant_grid = _create_octant_grid()
	octant_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(octant_grid)

	# Vocabulary view (initially hidden)
	vocab_container = _create_vocabulary_view()
	vocab_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	vocab_container.visible = false
	content.add_child(vocab_container)

	# Attractor view (initially hidden)
	attractor_container = _create_attractor_view()
	attractor_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	attractor_container.visible = false
	content.add_child(attractor_container)


func _create_title_bar() -> Control:
	"""Create title bar with overlay name and view mode."""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)

	# Title
	title_label = Label.new()
	title_label.text = "🧭 Semantic Map"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	hbox.add_child(title_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# View mode indicator
	view_mode_label = Label.new()
	view_mode_label.text = "[F] %s" % VIEW_MODE_NAMES[current_view_mode]
	view_mode_label.add_theme_font_size_override("font_size", 14)
	view_mode_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	hbox.add_child(view_mode_label)

	return hbox


func _create_octant_grid() -> GridContainer:
	"""Create 2x4 grid of octant panels."""
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)

	octant_panels.clear()
	for i in range(8):
		var panel = _create_octant_panel(i)
		grid.add_child(panel)
		octant_panels.append(panel)

	return grid


func _create_octant_panel(index: int) -> Control:
	"""Create a single octant panel."""
	var region = REGIONS[index]

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(OCTANT_SIZE, OCTANT_SIZE)

	var style = StyleBoxFlat.new()
	style.bg_color = region.color.darkened(0.7)
	style.border_color = region.color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Icon and name
	var header = Label.new()
	header.text = "%s %s" % [region.icon, region.name]
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", region.color)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	# Description
	var desc = Label.new()
	desc.text = region.desc
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# Emoji count placeholder
	var count_label = Label.new()
	count_label.name = "CountLabel"
	count_label.text = "0 emojis"
	count_label.add_theme_font_size_override("font_size", 11)
	count_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(count_label)

	return panel


func _create_vocabulary_view() -> Control:
	"""Create vocabulary grid for selected octant."""
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 10)

	# Octant header
	var header = Label.new()
	header.name = "OctantHeader"
	header.text = "📖 Vocabulary - Phoenix"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	container.add_child(header)

	# Scroll container
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	container.add_child(scroll)

	# Emoji grid
	emoji_grid = GridContainer.new()
	emoji_grid.columns = 10
	emoji_grid.add_theme_constant_override("h_separation", 12)
	emoji_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(emoji_grid)

	# Back hint
	var hint = Label.new()
	hint.text = "[F] Back to Octant Grid"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	container.add_child(hint)

	return container


func _create_attractor_view() -> Control:
	"""Create strange attractor visualization."""
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 10)

	# Header
	var header = Label.new()
	header.text = "🌀 Strange Attractors"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	container.add_child(header)

	# Placeholder for attractor visualization
	var placeholder = Label.new()
	placeholder.text = "Attractor visualization coming soon...\n\nAttractors represent stable states in the semantic space."
	placeholder.add_theme_font_size_override("font_size", 14)
	placeholder.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(placeholder)

	return container


# ============================================================================
# LIFECYCLE
# ============================================================================

func activate() -> void:
	"""Called when overlay opens - refresh data."""
	super.activate()
	_load_vocabulary_data()
	_update_octant_counts()
	_update_selection_visual()


func _load_vocabulary_data() -> void:
	"""Load vocabulary from game state."""
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.current_state and gsm.current_state.has("vocabulary"):
		vocabulary_data = gsm.current_state.vocabulary
	else:
		vocabulary_data = {}


func _update_octant_counts() -> void:
	"""Update emoji counts in each octant panel."""
	for i in range(octant_panels.size()):
		var panel = octant_panels[i]
		var count_label = panel.find_child("CountLabel", true, false)
		if count_label:
			var count = _get_octant_emoji_count(i)
			count_label.text = "%d emojis" % count


func _get_octant_emoji_count(octant_index: int) -> int:
	"""Get number of discovered emojis in an octant."""
	# TODO: Map vocabulary to octants based on semantic position
	# For now, return placeholder count
	return vocabulary_data.size() / 8 if octant_index == 0 else 0


func _update_view() -> void:
	"""Update visibility based on current view mode."""
	view_mode_label.text = "[F] %s" % VIEW_MODE_NAMES[current_view_mode]

	octant_grid.visible = (current_view_mode == ViewMode.OCTANT_GRID)
	vocab_container.visible = (current_view_mode == ViewMode.VOCABULARY)
	attractor_container.visible = (current_view_mode == ViewMode.ATTRACTOR_MAP)


func _update_selection_visual() -> void:
	"""Update visual highlight of selected octant."""
	for i in range(octant_panels.size()):
		var panel = octant_panels[i]
		var style = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			var region = REGIONS[i]
			if i == selected_octant:
				style.border_color = Color(1.0, 1.0, 0.5)
				style.border_width_left = 4
				style.border_width_right = 4
				style.border_width_top = 4
				style.border_width_bottom = 4
			else:
				style.border_color = region.color
				style.border_width_left = 2
				style.border_width_right = 2
				style.border_width_top = 2
				style.border_width_bottom = 2


# ============================================================================
# ACTION HANDLERS
# ============================================================================

func on_q_pressed() -> void:
	"""Q = Previous octant."""
	selected_octant = (selected_octant - 1) % 8
	if selected_octant < 0:
		selected_octant = 7
	_update_selection_visual()
	action_performed.emit("prev_octant", {"octant": selected_octant, "name": REGIONS[selected_octant].name})


func on_e_pressed() -> void:
	"""E = Next octant / Zoom in."""
	if current_view_mode == ViewMode.OCTANT_GRID:
		selected_octant = (selected_octant + 1) % 8
		_update_selection_visual()
		action_performed.emit("next_octant", {"octant": selected_octant, "name": REGIONS[selected_octant].name})
	else:
		# Zoom into selected octant vocabulary
		current_view_mode = ViewMode.VOCABULARY
		_update_view()
		_populate_vocabulary_grid()


func on_r_pressed() -> void:
	"""R = Show attractors."""
	current_view_mode = ViewMode.ATTRACTOR_MAP
	_update_view()
	action_performed.emit("show_attractors", {})


func on_f_pressed() -> void:
	"""F = Cycle view mode."""
	current_view_mode = (current_view_mode + 1) % VIEW_MODE_NAMES.size()
	_update_view()
	if current_view_mode == ViewMode.VOCABULARY:
		_populate_vocabulary_grid()
	action_performed.emit("cycle_view", {"mode": VIEW_MODE_NAMES[current_view_mode]})


func _populate_vocabulary_grid() -> void:
	"""Populate emoji grid with vocabulary for selected octant."""
	# Clear existing
	for child in emoji_grid.get_children():
		child.queue_free()

	# Update header
	var header = vocab_container.find_child("OctantHeader", true, false)
	if header:
		var region = REGIONS[selected_octant]
		header.text = "%s Vocabulary - %s" % [region.icon, region.name]

	# Add emojis (placeholder - real implementation would filter by octant)
	for emoji in vocabulary_data.keys():
		var label = Label.new()
		label.text = emoji
		label.add_theme_font_size_override("font_size", 24)
		emoji_grid.add_child(label)


func get_action_labels() -> Dictionary:
	"""v2 overlay interface: Get context-sensitive labels."""
	var labels = action_labels.duplicate()

	if current_view_mode == ViewMode.OCTANT_GRID:
		labels["E"] = "Next Octant"
	else:
		labels["E"] = "Zoom In"

	return labels
