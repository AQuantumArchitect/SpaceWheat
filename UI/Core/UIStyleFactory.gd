class_name UIStyleFactory
extends RefCounted

## UIStyleFactory - Centralized UI styling to eliminate duplication
##
## Usage:
##   var panel_style = UIStyleFactory.create_panel_style()
##   var button = UIStyleFactory.create_styled_button("Click Me", Color.GREEN)
##
## All overlays and panels should use these methods instead of creating
## StyleBoxFlat instances directly.

# =============================================================================
# COLOR CONSTANTS (Single Source of Truth)
# =============================================================================

## Standard overlay background colors
const COLOR_PANEL_BG = Color(0.08, 0.10, 0.14, 0.95)
const COLOR_PANEL_BORDER = Color(0.3, 0.4, 0.5, 0.8)
const COLOR_HUD_BG = Color(0.08, 0.10, 0.18, 0.92)
const COLOR_MODAL_DIMMER = Color(0.0, 0.0, 0.0, 0.7)

## State-based slot/card colors
const COLOR_SLOT_EMPTY = Color(0.15, 0.15, 0.15, 0.9)
const COLOR_SLOT_ACTIVE = Color(0.2, 0.3, 0.5, 0.9)
const COLOR_SLOT_READY = Color(0.2, 0.5, 0.2, 0.95)

## Alignment-based colors (for quest offers)
const COLOR_ALIGN_HIGH = Color(0.2, 0.4, 0.2, 0.8)    # Green (>70%)
const COLOR_ALIGN_MED = Color(0.3, 0.3, 0.2, 0.8)     # Neutral (50-70%)
const COLOR_ALIGN_LOW = Color(0.4, 0.3, 0.2, 0.8)     # Orange (30-50%)
const COLOR_ALIGN_VERY_LOW = Color(0.4, 0.2, 0.2, 0.8) # Red (<30%)

## Text colors
const COLOR_TEXT_TITLE = Color(0.9, 0.95, 1.0)
const COLOR_TEXT_SUBTITLE = Color(0.6, 0.7, 0.8)
const COLOR_TEXT_MUTED = Color(0.5, 0.6, 0.7)
const COLOR_TEXT_HIGHLIGHT = Color(1.0, 0.9, 0.3)  # Gold

## Selection highlight
const COLOR_SELECTION = Color(1.0, 0.9, 0.0)


# =============================================================================
# SPACING CONSTANTS
# =============================================================================

const VBOX_SPACING_TIGHT = 4     # Dense content
const VBOX_SPACING_NORMAL = 8    # Standard
const VBOX_SPACING_RELAXED = 12  # Overlays
const VBOX_SPACING_LOOSE = 16    # Modals

const HBOX_SPACING_TIGHT = 4
const HBOX_SPACING_NORMAL = 8
const HBOX_SPACING_RELAXED = 16


# =============================================================================
# PANEL STYLES
# =============================================================================

static func create_panel_style(
	bg_color: Color = COLOR_PANEL_BG,
	border_color: Color = COLOR_PANEL_BORDER,
	border_width: int = 2,
	corner_radius: int = 12,
	content_margin: int = 16
) -> StyleBoxFlat:
	"""Create a standard panel StyleBoxFlat."""
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.set_content_margin_all(content_margin)
	return style


static func create_slot_style(
	bg_color: Color = COLOR_SLOT_EMPTY,
	border_color: Color = Color(0.5, 0.5, 0.5, 0.6),
	border_width: int = 3,
	corner_radius: int = 6,
	content_margin_h: int = 8,
	content_margin_v: int = 4
) -> StyleBoxFlat:
	"""Create a card/slot StyleBoxFlat (smaller margins, subtle border)."""
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = content_margin_h
	style.content_margin_right = content_margin_h
	style.content_margin_top = content_margin_v
	style.content_margin_bottom = content_margin_v
	return style


static func create_selection_style(base_style: StyleBoxFlat, selection_color: Color = COLOR_SELECTION) -> StyleBoxFlat:
	"""Create a copy of a style with selection highlight border."""
	var style = base_style.duplicate()
	style.border_color = selection_color
	style.border_width_left = 5
	style.border_width_right = 5
	style.border_width_top = 5
	style.border_width_bottom = 5
	return style


# =============================================================================
# BUTTON STYLES
# =============================================================================

static func create_button_style_normal(bg_color: Color) -> StyleBoxFlat:
	"""Create normal button state style."""
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = Color(0.7, 0.7, 0.7, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


static func create_button_style_hover(bg_color: Color) -> StyleBoxFlat:
	"""Create hover button state style (lightened, expanded)."""
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color.lightened(0.2)
	style.border_color = Color(0.9, 0.9, 0.9, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


static func create_button_style_pressed(bg_color: Color) -> StyleBoxFlat:
	"""Create pressed button state style (darkened)."""
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color.darkened(0.2)
	style.border_color = Color(0.5, 0.5, 0.5, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


static func create_styled_button(
	text: String,
	bg_color: Color,
	min_size: Vector2 = Vector2(300, 36),
	font_size: int = 16
) -> Button:
	"""Create a fully-styled button with normal/hover/pressed states."""
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.add_theme_font_size_override("font_size", font_size)

	btn.add_theme_stylebox_override("normal", create_button_style_normal(bg_color))
	btn.add_theme_stylebox_override("hover", create_button_style_hover(bg_color))
	btn.add_theme_stylebox_override("pressed", create_button_style_pressed(bg_color))

	return btn


# =============================================================================
# LABEL HELPERS
# =============================================================================

static func create_title_label(
	text: String,
	font_size: int = 20,
	color: Color = COLOR_TEXT_TITLE
) -> Label:
	"""Create a styled title label."""
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


static func create_subtitle_label(
	text: String,
	font_size: int = 14,
	color: Color = COLOR_TEXT_SUBTITLE
) -> Label:
	"""Create a styled subtitle label."""
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


static func create_muted_label(
	text: String,
	font_size: int = 12,
	color: Color = COLOR_TEXT_MUTED
) -> Label:
	"""Create a muted/hint label."""
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


# =============================================================================
# COLOR HELPERS
# =============================================================================

static func get_alignment_color(alignment: float) -> Color:
	"""Get background color based on alignment score (0.0 - 1.0)."""
	if alignment > 0.7:
		return COLOR_ALIGN_HIGH
	elif alignment > 0.5:
		return COLOR_ALIGN_MED
	elif alignment > 0.3:
		return COLOR_ALIGN_LOW
	else:
		return COLOR_ALIGN_VERY_LOW


static func get_alignment_text_color(alignment: float) -> Color:
	"""Get text color based on alignment score."""
	if alignment > 0.7:
		return Color(0.5, 1.0, 0.5)  # Bright green
	elif alignment > 0.5:
		return Color(1.0, 1.0, 0.7)  # Light yellow
	elif alignment > 0.3:
		return Color(1.0, 0.7, 0.5)  # Orange
	else:
		return Color(1.0, 0.5, 0.5)  # Light red


# =============================================================================
# CONTAINER HELPERS
# =============================================================================

static func create_vbox(separation: int = VBOX_SPACING_NORMAL) -> VBoxContainer:
	"""Create VBoxContainer with standard separation."""
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", separation)
	return vbox


static func create_hbox(separation: int = HBOX_SPACING_NORMAL) -> HBoxContainer:
	"""Create HBoxContainer with standard separation."""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", separation)
	return hbox


# =============================================================================
# MODAL HELPERS
# =============================================================================

static func create_modal_dimmer(color: Color = COLOR_MODAL_DIMMER) -> ColorRect:
	"""Create a full-screen dimmer background for modal dialogs."""
	var dimmer = ColorRect.new()
	dimmer.color = color
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.layout_mode = 1
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	return dimmer


static func create_centered_panel(
	panel_size: Vector2,
	bg_color: Color = COLOR_PANEL_BG,
	border_color: Color = COLOR_PANEL_BORDER
) -> PanelContainer:
	"""Create a centered panel container for modal dialogs.

	Args:
		panel_size: Size of the panel (width, height)
		bg_color: Background color
		border_color: Border color
	"""
	var panel = PanelContainer.new()
	panel.custom_minimum_size = panel_size
	panel.add_theme_stylebox_override("panel", create_panel_style(bg_color, border_color))

	# Center anchors
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5

	# Offset to center
	panel.offset_left = -panel_size.x / 2
	panel.offset_right = panel_size.x / 2
	panel.offset_top = -panel_size.y / 2
	panel.offset_bottom = panel_size.y / 2
	panel.layout_mode = 1

	return panel


# =============================================================================
# SELECTION HELPERS
# =============================================================================

static func apply_selection_border(
	control: Control,
	selected: bool,
	selection_color: Color = COLOR_SELECTION,
	border_width: int = 4
) -> void:
	"""Apply or remove selection border from a control.

	Works with controls that have a StyleBoxFlat "normal" or "panel" override.
	"""
	var style: StyleBoxFlat = null

	# Try to get existing style
	if control is Button:
		style = control.get_theme_stylebox("normal") as StyleBoxFlat
	elif control is PanelContainer:
		style = control.get_theme_stylebox("panel") as StyleBoxFlat

	if not style:
		return

	if selected:
		style.border_color = selection_color
		style.set_border_width_all(border_width)
	else:
		style.border_color = Color(0.5, 0.5, 0.5, 0.6)
		style.set_border_width_all(2)


static func apply_selection_modulate(
	control: Control,
	selected: bool,
	highlight_color: Color = Color(1.3, 1.3, 1.0)
) -> void:
	"""Apply or remove selection highlight via modulate.

	Simpler alternative to border-based selection.
	"""
	if selected:
		control.modulate = highlight_color
	else:
		control.modulate = Color.WHITE


# =============================================================================
# MENU BUTTON HELPERS
# =============================================================================

static func create_menu_button(
	text: String,
	bg_color: Color,
	min_size: Vector2 = Vector2(300, 50),
	font_size: int = 20
) -> Button:
	"""Create a menu-style button (larger than standard buttons)."""
	return create_styled_button(text, bg_color, min_size, font_size)


# =============================================================================
# HUD HELPERS (shared between SimStatsOverlay, InspectorOverlay, etc.)
# =============================================================================

static func create_hud_label(text: String, color: Color, font_size: int = 0) -> Label:
	"""Create a HUD label (expand-fill, left-aligned). Pass font_size=0 to skip override."""
	var label = Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_color_override("font_color", color)
	label.text = text
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	return label


static func create_hud_separator() -> HSeparator:
	"""Create a subtle HUD separator line."""
	var sep = HSeparator.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.4, 0.4, 0.3)
	sep.add_theme_stylebox_override("separator", style)
	return sep


static func get_speed_fraction(speed: float) -> String:
	"""Convert a decimal time-scale value to a human-readable fraction string."""
	var lookup = {
		0.03125: "1/32",
		0.0625: "1/16",
		0.125: "1/8",
		0.25: "1/4",
		0.5: "1/2",
		1.0: "1",
		2.0: "2",
		4.0: "4",
		8.0: "8",
		16.0: "16"
	}
	for key in lookup.keys():
		if abs(speed - key) < 1e-4:
			return lookup[key]
	return ""


static func get_physics_fps_from_farm(farm_node) -> float:
	"""Get physics frames-per-second from a farm's biome_evolution_batcher."""
	if not farm_node:
		return 0.0
	if "biome_evolution_batcher" in farm_node:
		var batcher = farm_node.biome_evolution_batcher
		if batcher and "physics_frames_per_second" in batcher:
			return batcher.physics_frames_per_second
	return 0.0


static func get_simulation_speed(farm_node) -> float:
	"""Get quantum time scale from the first available biome."""
	if farm_node and "grid" in farm_node and farm_node.grid:
		for biome in farm_node.grid.biomes.values():
			if not biome:
				continue
			if "quantum_time_scale" in biome:
				return biome.quantum_time_scale
			if biome.has_method("get_quantum_time_scale"):
				return biome.get_quantum_time_scale()
	if farm_node and "quantum_time_scale" in farm_node:
		return farm_node.quantum_time_scale
	return 1.0


static func create_slot_button(
	text: String,
	bg_color: Color = COLOR_SLOT_EMPTY,
	min_size: Vector2 = Vector2(550, 80),
	font_size: int = 18
) -> Button:
	"""Create a slot-style button for save slots, quest slots, etc."""
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.add_theme_font_size_override("font_size", font_size)

	var style_normal = create_slot_style(bg_color)
	btn.add_theme_stylebox_override("normal", style_normal)

	var style_hover = create_slot_style(bg_color.lightened(0.15))
	btn.add_theme_stylebox_override("hover", style_hover)

	var style_pressed = create_slot_style(bg_color.darkened(0.15))
	btn.add_theme_stylebox_override("pressed", style_pressed)

	return btn


# =============================================================================
# SECTION / STAT BAR HELPERS
# =============================================================================

static func create_section_header(
	text: String,
	font_size: int = 13,
	color: Color = COLOR_TEXT_SUBTITLE
) -> Label:
	"""Create a left-aligned section header label."""
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


static func create_stat_bar(
	label_text: String,
	value: float,
	color: Color,
	label_width: int = 55,
	bar_width: int = 100,
	bar_height: int = 14,
	font_size: int = 12
) -> HBoxContainer:
	"""Create a compact labeled progress bar for stats.

	Returns HBox: [Label] [ColorRect bg > ColorRect fill] [Label percent]
	"""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	# Label
	var label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size.x = label_width
	label.add_theme_font_size_override("font_size", font_size)
	hbox.add_child(label)

	# Bar background
	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0.2, 0.2, 0.2)
	bar_bg.custom_minimum_size = Vector2(bar_width, bar_height)
	hbox.add_child(bar_bg)

	# Bar fill (child of background)
	var bar_fill = ColorRect.new()
	bar_fill.color = color
	bar_fill.name = "Fill"
	bar_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	bar_fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar_bg.add_child(bar_fill)

	# Percentage label
	var pct_label = Label.new()
	pct_label.name = "Percent"
	pct_label.text = "%d%%" % int(value * 100)
	pct_label.custom_minimum_size.x = 35
	pct_label.add_theme_font_size_override("font_size", font_size)
	hbox.add_child(pct_label)

	return hbox


static func update_stat_bar(bar: HBoxContainer, value: float) -> void:
	"""Update a stat bar's fill width and percentage text."""
	if not bar or bar.get_child_count() < 3:
		return

	var bar_bg = bar.get_child(1)
	var pct_label = bar.get_child(2)

	# Update fill width
	var fill = bar_bg.get_node_or_null("Fill")
	if fill:
		fill.custom_minimum_size.x = bar_bg.size.x * clamp(value, 0.0, 1.0)

	# Update percentage text
	if pct_label and pct_label is Label:
		pct_label.text = "%d%%" % int(value * 100)


# =============================================================================
# HUD SCAFFOLD
# =============================================================================

static func create_hud_scaffold(
	bg_color: Color = COLOR_HUD_BG,
	border_color: Color = COLOR_PANEL_BORDER,
	padding: int = 8,
	separation: int = 4,
	corner_radius: int = 6
) -> Dictionary:
	"""Create the standard HUD scaffold: PanelContainer > MarginContainer > VBoxContainer.

	Returns {"panel": PanelContainer, "margin": MarginContainer, "vbox": VBoxContainer}
	"""
	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = bg_color
	panel_style.set_border_width_all(2)
	panel_style.border_color = border_color
	panel_style.set_corner_radius_all(corner_radius)
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", padding)
	margin.add_theme_constant_override("margin_top", padding)
	margin.add_theme_constant_override("margin_right", padding)
	margin.add_theme_constant_override("margin_bottom", padding)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", separation)

	margin.add_child(vbox)
	panel.add_child(margin)

	return {"panel": panel, "margin": margin, "vbox": vbox}
