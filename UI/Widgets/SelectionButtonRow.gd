class_name SelectionButtonRow
extends HBoxContainer

## SelectionButtonRow — shared FLAT chip row (Apple-minimal pass, 2026-07-08).
## The glossy SVG button chrome is gone: each button is a quiet translucent
## rounded chip; state reads as a gentle whole-chip tint plus a gold underline
## on the selected item. Subclasses provide specs and handle selection.

const CHIP_BG := Color(0.07, 0.08, 0.10, 0.60)
const CHIP_CORNER_RADIUS := 7
const SELECT_UNDERLINE_COLOR := Color(1.0, 0.8, 0.3, 0.95)  # global accent gold

# State tints applied via modulate on the WHOLE chip (bg + glyph + label).
var selected_color: Color = Color(1.25, 1.18, 0.95)  # warm lift
var normal_color: Color = Color(1.0, 1.0, 1.0)
var hover_color: Color = Color(1.35, 1.35, 1.35)
var pressed_color: Color = Color(0.7, 0.7, 0.7)
var disabled_color: Color = Color(0.45, 0.45, 0.45)

## Compact mode (emoji-only corner clusters): fixed-size chips that hug one
## end of the row instead of stretching across the screen.
var compact: bool = false
var compact_chip_size: Vector2 = Vector2(46, 38)

# Layout manager for scaling
var layout_manager
var scale_factor: float = 1.0

# Button data array - each element is {container, chip, label, icon, id, disabled}
# ("chip" is the tint target — the whole button Control, kept under the legacy
# key name "texture" so subclass state code needs no changes.)
var buttons: Array[Dictionary] = []
var selected_id: int = -1

signal button_selected(id: int)


func _ready():
	# Container setup
	add_theme_constant_override("separation", 6)

	# Allow keyboard input to pass through, but buttons can still receive clicks
	mouse_filter = MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func build_buttons(button_specs: Array[Dictionary]) -> void:
	# Rebuild buttons from specs.

	# Spec fields:
	# - id: int
	# - text: String
	# - icon_path: String (optional)
	# - enabled: bool (optional, default true)
	_clear_buttons()
	for spec in button_specs:
		var btn_data = _create_button(spec)
		add_child(btn_data.container)
		buttons.append(btn_data)


func _create_button(spec: Dictionary) -> Dictionary:
	# Create a single button from a spec.
	var button_id = spec.get("id", -1)
	var label_text = spec.get("text", "")
	var icon_path = spec.get("icon_path", "")
	var enabled = spec.get("enabled", true)

	# Container to hold chip background, icon, and label
	var container = Control.new()
	container.name = "SelectBtn_%d" % button_id
	if compact:
		container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		container.custom_minimum_size = compact_chip_size * scale_factor
	else:
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.custom_minimum_size = Vector2(0, 40 * scale_factor)
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.size_flags_stretch_ratio = 1.0
	container.mouse_filter = Control.MOUSE_FILTER_STOP

	# Flat chip background
	var chip = Panel.new()
	chip.name = "BtnChip"
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = CHIP_BG
	chip_style.set_corner_radius_all(CHIP_CORNER_RADIUS)
	chip.add_theme_stylebox_override("panel", chip_style)
	chip.set_anchors_preset(Control.PRESET_FULL_RECT)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(chip)

	# TextureRect for icon glyph
	var icon_rect = TextureRect.new()
	icon_rect.name = "BtnIcon"
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if compact and label_text == "":
		# Icon-only chip: glyph fills the chip with a small margin.
		icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_rect.offset_left = 6 * scale_factor
		icon_rect.offset_top = 5 * scale_factor
		icon_rect.offset_right = -6 * scale_factor
		icon_rect.offset_bottom = -5 * scale_factor
	else:
		icon_rect.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		icon_rect.offset_left = 8 * scale_factor
		icon_rect.offset_right = 40 * scale_factor
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var has_icon = false
	if icon_path != "":
		# Check if resource exists before loading (graceful fallback)
		if ResourceLoader.exists(icon_path):
			var icon_tex = load(icon_path)
			if icon_tex:
				icon_rect.texture = icon_tex
				has_icon = true
			else:
				icon_rect.visible = false
		else:
			# SVG missing - hide icon, use text label only
			icon_rect.visible = false
	else:
		icon_rect.visible = false

	container.add_child(icon_rect)

	# Label for button text
	var label = Label.new()
	label.name = "ButtonLabel"
	label.text = label_text
	if has_icon:
		label.offset_left = 40 * scale_factor
	else:
		label.offset_left = 0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", int((18 if compact else 15) * scale_factor))
	label.add_theme_color_override("font_color", Color(0.94, 0.94, 0.94))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	container.add_child(label)

	# Connect input events
	container.gui_input.connect(_on_button_input.bind(button_id))
	container.mouse_entered.connect(_on_button_hover.bind(button_id, true))
	container.mouse_exited.connect(_on_button_hover.bind(button_id, false))

	var tooltip: String = str(spec.get("tooltip", ""))
	if tooltip != "":
		container.tooltip_text = tooltip

	var btn_data = {
		"container": container,
		# Legacy key name: the tint target is now the WHOLE chip, so state
		# changes (hover/selected/disabled) dim or lift bg + glyph together.
		"texture": container,
		"icon": icon_rect,
		"label": label,
		"id": button_id,
		"disabled": not enabled,
		"tooltip": tooltip,
	}

	if not enabled:
		container.modulate = disabled_color

	return btn_data


func _clear_buttons() -> void:
	for btn_data in buttons:
		if btn_data.container and btn_data.container.get_parent() == self:
			btn_data.container.queue_free()
	buttons.clear()


func _on_button_input(event: InputEvent, button_id: int) -> void:
	var btn_data = _get_button_data(button_id)
	if not btn_data or btn_data.disabled:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			btn_data.texture.modulate = pressed_color
		else:
			set_selected(button_id)
			button_selected.emit(button_id)
		get_viewport().set_input_as_handled()


func _on_button_hover(button_id: int, is_hovering: bool) -> void:
	var btn_data = _get_button_data(button_id)
	if not btn_data or btn_data.disabled:
		return

	if button_id == selected_id:
		return

	if is_hovering:
		btn_data.texture.modulate = hover_color
	else:
		btn_data.texture.modulate = normal_color


func _get_button_data(button_id: int) -> Dictionary:
	for btn_data in buttons:
		if btn_data.id == button_id:
			return btn_data
	return {}


## Return the tooltip text of the currently-selected button, or "" if none.
## Overlays can call this inside get_hovered_tooltip() to expose button
## descriptions via the E key for keyboard players.
func get_selected_button_tooltip() -> String:
	var btn_data = _get_button_data(selected_id)
	if btn_data.is_empty():
		return ""
	return str(btn_data.get("tooltip", ""))


func set_selected(button_id: int) -> void:
	selected_id = button_id
	for btn_data in buttons:
		if btn_data.disabled:
			btn_data.texture.modulate = disabled_color
		elif btn_data.id == button_id:
			btn_data.texture.modulate = selected_color
		else:
			btn_data.texture.modulate = normal_color
	queue_redraw()


func set_button_enabled(button_id: int, enabled: bool) -> void:
	var btn_data = _get_button_data(button_id)
	if btn_data.is_empty():
		return
	btn_data.disabled = not enabled
	if not enabled:
		btn_data.texture.modulate = disabled_color
	else:
		if btn_data.id == selected_id:
			btn_data.texture.modulate = selected_color
		else:
			btn_data.texture.modulate = normal_color


func set_layout_manager(mgr) -> void:
	layout_manager = mgr
	if layout_manager:
		scale_factor = layout_manager.scale_factor


func _draw() -> void:
	# Quiet gold underline marks the selected chip (the WASD-crawl amber ring
	# around whole rows died 2026-07-08 with the crawl itself).
	if selected_id >= 0:
		for btn_data in buttons:
			if btn_data.id == selected_id:
				var r: Rect2 = btn_data.container.get_rect()
				draw_rect(Rect2(r.position.x, r.end.y - 2.0, r.size.x, 2.0), SELECT_UNDERLINE_COLOR, true)
				break
