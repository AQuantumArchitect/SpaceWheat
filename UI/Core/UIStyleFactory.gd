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
