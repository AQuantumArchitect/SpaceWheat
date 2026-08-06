class_name ActionPreviewRow
extends HBoxContainer

## Physical keyboard layout UI - Middle row with the Q/E/R/F action quartet
## Displays what each primary action chip will do based on selected tool or overlay
## Buttons use BtnBtmMidl.svg (identical styling to 1234 tool buttons)
## Uses BtnBtmMidl.svg from Assets/UI/Chrome for sci-fi aesthetic

const LindbladHandler = preload("res://Core/Instrumentation/Handlers/LindbladHandler.gd")
const UIProgression = preload("res://UI/Core/UIProgression.gd")

const ACTION_KEYS = ["Q", "E", "R", "F"]

# Action buttons - now stores container references with .texture and .label children
var action_buttons: Dictionary = {}  # "Q", "E", "R", "F" -> {container, texture, label, disabled}
var current_tool: int = 3
var current_submenu: String = ""
var current_projection: Dictionary = {}

# Styling - colors applied via modulate on the TextureRect (matches ToolSelectionRow)
var button_color: Color = Color(1.0, 1.0, 1.0)  # Normal state (texture's natural color)
var hover_color: Color = Color(1.2, 1.2, 1.2)  # Slightly brighter on hover
var disabled_color: Color = Color(0.3, 0.3, 0.3)  # Dark for disabled
var enabled_color: Color = Color(0.5, 1.0, 0.5)  # Green tint for available actions
var destructive_color: Color = Color(1.0, 0.55, 0.1)  # Amber — irreversible action (QF confirm required)
var pressed_color: Color = Color(0.6, 0.6, 0.6)  # Darker when pressed

# Layout manager for scaling
var layout_manager
var scale_factor: float = 1.0

# Signals
signal action_pressed(action_key: String)


func _ready():
	# Escape ActionBarLayer's z and sit above all overlays (max ~53).
	z_as_relative = false
	z_index = 60

	add_theme_constant_override("separation", 6)

	# IGNORE, not PASS: a PASS full-width strip CLAIMS picks and deadens
	# everything drawn beneath its band (see SelectionButtonRow). The QERF
	# chips are STOP children and receive clicks directly.
	mouse_filter = MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Create Q, E, R, F action buttons (matches 1234 button style)
	for action_key in ACTION_KEYS:
		var btn_data = _create_action_button(action_key)
		add_child(btn_data.container)
		action_buttons[action_key] = btn_data

	render_projection({
		"context": "tool",
		"tool": current_tool,
		"submenu_name": "",
		"actions": {}
	})
	print("🛠️  ActionPreviewRow initialized with BtnBtmMidl textures (matches 1234 buttons)")


func render_projection(projection: Dictionary) -> void:
	# Render a fully projected Q/E/R/F action state.
	current_projection = projection.duplicate(true)
	current_tool = int(current_projection.get("tool", current_tool))
	current_submenu = str(current_projection.get("submenu_name", ""))

	var actions: Dictionary = current_projection.get("actions", {})
	for action_key in ACTION_KEYS:
		var action_info: Dictionary = actions.get(action_key, {})
		_apply_button_projection(action_key, action_info)


func set_layout_manager(mgr) -> void:
	# Set layout manager for responsive scaling
	layout_manager = mgr
	if layout_manager:
		scale_factor = layout_manager.scale_factor


# ============================================================================
# PRIVATE METHODS
# ============================================================================

func get_snapshot() -> Dictionary:
	# Return structured snapshot of current action button state.
	var actions: Dictionary = {}
	for key in ACTION_KEYS:
		if not action_buttons.has(key):
			continue
		var btn = action_buttons[key]
		actions[key] = {"label": btn.label.text, "disabled": btn.disabled}
	return {"current_tool": current_tool, "submenu": current_submenu, "actions": actions}


func debug_layout() -> String:
	# Return detailed layout debug information for F3 display
	var debug_text = ""
	debug_text += "ActionPreviewRow (Q/E/R/F toolbar):\n"
	debug_text += "  Position: (%.0f, %.0f)\n" % [position.x, position.y]
	debug_text += "  Actual size: %.0f × %.0f\n" % [size.x, size.y]
	debug_text += "  Custom min size: %s\n" % custom_minimum_size
	debug_text += "  Size flags H: %d (3=EXPAND_FILL)\n" % size_flags_horizontal
	debug_text += "  Size flags V: %d\n" % size_flags_vertical
	debug_text += "  Buttons: %d total (BtnBtmMidl style)\n" % action_buttons.size()

	var button_widths = []
	for action_key in ACTION_KEYS:
		if action_buttons.has(action_key):
			var btn_data = action_buttons[action_key]
			button_widths.append("%.0f" % btn_data.container.size.x)
	debug_text += "  Button widths: [%s] (should be equal for stretch)\n" % ", ".join(button_widths)

	return debug_text


func _create_action_button(action_key: String) -> Dictionary:
	# Create an action button with texture background, icon glyph, and text label.
	# Matches the styling of ToolSelectionRow buttons (BtnBtmMidl.svg).

	# Returns a Dictionary with:
	# - container: The root Control node
	# - texture: The TextureRect for button background
	# - icon: The TextureRect for action icon glyph
	# - label: The Label for button text
	# - disabled: bool tracking disabled state
	# Container to hold texture, icon, and label
	var container = Control.new()
	container.name = "ActionBtn_%s" % action_key
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.size_flags_stretch_ratio = 1.0
	container.custom_minimum_size = Vector2(0, 42 * scale_factor)
	container.mouse_filter = Control.MOUSE_FILTER_STOP

	# Flat chip background (Apple-minimal pass — glossy SVG chrome removed).
	# Kept under the legacy "texture" key: state tints modulate the chip node.
	var texture_rect = Panel.new()
	texture_rect.name = "BtnChip"
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color(0.07, 0.08, 0.10, 0.60)
	chip_style.set_corner_radius_all(7)
	texture_rect.add_theme_stylebox_override("panel", chip_style)
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(texture_rect)

	# TextureRect for action icon glyph (left side)
	var icon_rect = TextureRect.new()
	icon_rect.name = "ActionIcon"
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	icon_rect.offset_left = 8 * scale_factor
	icon_rect.offset_right = 40 * scale_factor
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.visible = false  # Hidden by default, shown when icon is set
	container.add_child(icon_rect)

	# Container for action costs (left side, glyph + amount)
	var cost_container = HBoxContainer.new()
	cost_container.name = "CostContainer"
	cost_container.layout_mode = 1  # Anchors-based positioning
	cost_container.size_flags_horizontal = Control.SIZE_SHRINK_END
	cost_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cost_container.custom_minimum_size = Vector2(110 * scale_factor, 24 * scale_factor)
	cost_container.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	cost_container.offset_left = -120 * scale_factor
	cost_container.offset_right = -6 * scale_factor
	cost_container.offset_top = 6 * scale_factor
	cost_container.offset_bottom = -6 * scale_factor
	cost_container.add_theme_constant_override("separation", int(2 * scale_factor))
	cost_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_container.visible = false
	cost_container.z_index = 5
	cost_container.z_as_relative = true
	container.add_child(cost_container)

	# Label for button text (centered over texture)
	var label = Label.new()
	label.name = "ButtonLabel"
	label.text = "[%s]" % action_key
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", int(15 * scale_factor))
	label.add_theme_color_override("font_color", Color(0.94, 0.94, 0.94))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	container.add_child(label)

	# Connect input events
	container.gui_input.connect(_on_action_button_input.bind(action_key))
	container.mouse_entered.connect(_on_action_button_hover.bind(action_key, true))
	container.mouse_exited.connect(_on_action_button_hover.bind(action_key, false))

	return {
		"container": container,
		"texture": texture_rect,
		"icon": icon_rect,
		"label": label,
		"cost_container": cost_container,
		"base_label_offset": 0,
		"disabled": false
	}

func _apply_button_projection(action_key: String, action_info: Dictionary) -> void:
	if not action_buttons.has(action_key):
		return

	var btn_data = action_buttons[action_key]
	btn_data.icon.visible = false
	btn_data.base_label_offset = 0
	btn_data.label.offset_left = 0

	var label_text = str(action_info.get("label", "-"))
	var emoji = str(action_info.get("emoji", ""))
	var icon_path = str(action_info.get("icon", ""))
	var shift_hint = str(action_info.get("shift_label", ""))
	# Producer-computed consequence annotation (IconInjectionSubmenu's
	# "+2 new atoms · gap 0.61→0.54 ▼" etc.) — this is the only place it's
	# ever rendered; the projection carries it through but no widget read it.
	var hint_suffix := str(action_info.get("hint", "")).strip_edges().trim_prefix("· ").strip_edges()
	if hint_suffix != "":
		hint_suffix = " · %s" % hint_suffix
	var is_disabled = bool(action_info.get("disabled", false))
	var is_available = bool(action_info.get("available", false))
	var has_icon = false

	if icon_path != "":
		if ResourceLoader.exists(icon_path):
			var icon_tex = load(icon_path)
			if icon_tex:
				btn_data.icon.texture = icon_tex
				btn_data.icon.visible = true
				has_icon = true

	if has_icon:
		btn_data.label.text = "[%s] %s%s%s" % [
				action_key, label_text, " (%s)" % shift_hint if shift_hint != "" else "", hint_suffix]
		btn_data.label.offset_left = 40 * scale_factor
		btn_data.base_label_offset = 40 * scale_factor
	else:
		var prefix = ("%s " % emoji) if emoji != "" else ""
		var suffix = " (%s)" % shift_hint if shift_hint != "" else ""
		btn_data.label.text = "[%s] %s%s%s%s" % [action_key, prefix, label_text, suffix, hint_suffix]

	btn_data.disabled = is_disabled
	btn_data.available = is_available
	btn_data.texture.modulate = _resolve_button_color(btn_data)

	var cost = action_info.get("cost", {})
	var has_cost = _set_cost_display(btn_data, cost if cost is Dictionary else {})
	_adjust_label_for_cost(btn_data, has_cost)


func _adjust_label_for_cost(btn_data: Dictionary, has_cost: bool, cost_width: int = 130) -> void:
	var base_offset = btn_data.get("base_label_offset", 0)
	if btn_data.has("label"):
		btn_data.label.offset_left = base_offset
		if has_cost:
			btn_data.label.offset_right = -cost_width * scale_factor
		else:
			btn_data.label.offset_right = 0

func _set_cost_display(btn_data: Dictionary, cost: Dictionary) -> bool:
	if not btn_data.has("cost_container"):
		return false

	var container: HBoxContainer = btn_data.cost_container
	for child in container.get_children():
		child.queue_free()

	if cost.is_empty():
		container.visible = false
		return false

	_build_cost_entries(container, cost)
	container.visible = true
	return true

func _build_cost_entries(container: HBoxContainer, cost: Dictionary) -> void:
	var keys = cost.keys()
	keys.sort()
	if keys.has(LindbladHandler.DRAIN_GEAR_EMOJI):
		keys.erase(LindbladHandler.DRAIN_GEAR_EMOJI)
		keys.append(LindbladHandler.DRAIN_GEAR_EMOJI)

	for emoji in keys:
		var amount = cost[emoji]
		if amount == 0:
			continue
		var entry = HBoxContainer.new()
		entry.add_theme_constant_override("separation", int(2 * scale_factor))
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var amount_label = Label.new()
		# Costs are integer resources; a float payload (e.g. {🌱: 5.0} from the
		# icon-injection submenu) must not render as "5.0" on the badge (#266).
		# Signed: a bare "1🍼" read ambiguous (cost or reward?) — "−1🍼" is honest,
		# what the wallet actually loses (d1-03, literalist care pass).
		var amount_f := float(amount)
		var amount_str := str(int(round(amount_f))) if is_equal_approx(amount_f, round(amount_f)) else String.num(amount_f, 1)
		amount_label.text = "−%s" % amount_str
		amount_label.add_theme_font_size_override("font_size", int(18 * scale_factor))
		amount_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
		amount_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		amount_label.add_theme_constant_override("shadow_offset_x", 1)
		amount_label.add_theme_constant_override("shadow_offset_y", 1)
		amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(amount_label)

		var display = EmojiDisplay.new()
		display.emoji = emoji
		display.font_size = int(22 * scale_factor)
		display.custom_minimum_size = Vector2(40 * scale_factor, 40 * scale_factor)
		display.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		display.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		display.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(display)

		container.add_child(entry)

func _on_action_button_input(event: InputEvent, action_key: String) -> void:
	var btn_data = action_buttons.get(action_key)
	if not btn_data:
		return
	if btn_data.disabled:
		# A locked-hat chip click used to be a total no-op: zero toast, zero
		# press flash, indistinguishable from a click that never landed
		# (mouse-only campaign wave 4, lost-lamb). The progressive-disclosure
		# lock is the one disabled-reason a chip's own text names (a "🔒"
		# glyph _build_frame_actions mixes into the label) -- other disabled
		# reasons (submenu unavailability, an overlay's own non-binding) get
		# no lock glyph and stay silent here, unchanged, since a "not yet
		# unlocked" toast would misdescribe them. Read-only, no dispatch, so
		# it's safe regardless of context.
		var label_node: Label = btn_data.get("label")
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed \
				and label_node != null and label_node.text.contains("🔒"):
			UIProgression.redirect_locked()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			btn_data.texture.modulate = pressed_color
		else:
			_update_single_button_color(action_key)
			action_pressed.emit(action_key)
		get_viewport().set_input_as_handled()


func _on_action_button_hover(action_key: String, is_hovering: bool) -> void:
	# Handle mouse hover on action button.
	var btn_data = action_buttons.get(action_key)
	if not btn_data or btn_data.disabled:
		return

	if is_hovering:
		# Brighten slightly on hover (unless already showing enabled color)
		var current_mod = btn_data.texture.modulate
		if current_mod != enabled_color:
			btn_data.texture.modulate = hover_color
	else:
		# Restore appropriate color
		_update_single_button_color(action_key)


func _update_single_button_color(action_key: String) -> void:
	# Update a single button's color based on its current state.
	var btn_data = action_buttons.get(action_key)
	if not btn_data:
		return

	if btn_data.disabled:
		btn_data.texture.modulate = disabled_color
	elif btn_data.get("available", false):
		btn_data.texture.modulate = enabled_color
	else:
		btn_data.texture.modulate = button_color


func _resolve_button_color(btn_data: Dictionary) -> Color:
	if btn_data.get("disabled", false):
		return disabled_color
	if btn_data.get("destructive", false):
		return destructive_color  # amber — even when available, warns before QF confirm
	if btn_data.get("available", false):
		return enabled_color
	return button_color
