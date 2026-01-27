class_name ActionPanelModeSelect
extends PanelContainer

## Mode-based Action Panel
## Tools: Select mode, then tap grid to apply
## Actions: Execute immediately when pressed

# Mode selection signals
signal mode_selected(mode_name: String)
signal action_executed(action_name: String)

# Layout manager reference (for dynamic scaling)
var layout_manager: Node  # Will be UILayoutManager instance

# HBoxContainer reference (for manual size management - horizontal button row)
var _vbox_container: BoxContainer = null  # Can be VBox or HBox

# Current selected mode
var selected_mode: String = ""

# Tool button references (mode selection)
var tool_buttons: Dictionary = {}

# Action button references (immediate execution)
var action_buttons: Dictionary = {}

# Colors
const COLOR_TOOL = Color(0.3, 0.5, 0.8)  # Blue for tools
const COLOR_TOOL_SELECTED = Color(0.5, 0.8, 1.0)  # Bright blue when selected
const COLOR_ACTION = Color(0.5, 0.7, 0.3)  # Green for actions


func set_layout_manager(manager: Node):
	"""Set the layout manager reference for dynamic scaling"""
	layout_manager = manager
	# Rebuild UI with new scale factor (layout manager is now available)
	if is_node_ready():
		_clear_ui()
		_create_ui()


func _ready():
	"""Called when node enters tree - create UI with scaling"""
	if layout_manager:
		_create_ui()


func _clear_ui():
	"""Remove all children (for rebuilding with new scale)"""
	for child in get_children():
		child.queue_free()
	tool_buttons.clear()
	action_buttons.clear()


func _create_ui():
	"""Create action panel UI - horizontal touch-screen button row at bottom"""
	var scale_factor = layout_manager.scale_factor if layout_manager else 1.0
	var button_font_size = layout_manager.get_scaled_font_size(16) if layout_manager else 16
	var margin = int(8 * scale_factor)  # Margin around edges and between buttons
	var button_spacing = int(6 * scale_factor)

	# DON'T set custom_minimum_size here - let the parent (FarmView) control it
	mouse_filter = Control.MOUSE_FILTER_PASS

	# Main horizontal layout for action buttons row
	var main_hbox = HBoxContainer.new()
	main_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.add_theme_constant_override("separation", button_spacing)
	main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.mouse_filter = Control.MOUSE_FILTER_PASS

	# Set position and let _process() sync size
	main_hbox.position = Vector2(margin, margin)
	main_hbox.custom_minimum_size = Vector2(0, 0)

	add_child(main_hbox)

	# Store reference to HBoxContainer for later size updates
	_vbox_container = main_hbox

	# === TOOLS: Tool buttons for farming operations - these share the bottom row proportionally ===
	# Each button gets equal width via SIZE_EXPAND_FILL
	# Tools are selector modes: click to enable, click grid to apply
	_create_action_button(main_hbox, "measure", "👁️ Measure", "Measure plots [M]", button_font_size)
	_create_action_button(main_hbox, "harvest", "✂️ Harvest", "Harvest wheat [H]", button_font_size)


func _create_action_button(parent: Control, action_name: String, text: String, tooltip: String, font_size: int):
	"""Create a tool button - touch-screen style rectangle with toggle functionality"""
	var btn = Button.new()
	btn.text = text
	# For horizontal layout: each button gets equal width via SIZE_EXPAND_FILL
	# Height is controlled by parent HBoxContainer and its available space
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", font_size)
	btn.tooltip_text = tooltip
	# Don't use toggle_mode - handle state manually to avoid consuming input
	btn.toggle_mode = false

	# Style as tool button (blue) - clean touch-screen button style
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_TOOL
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = COLOR_TOOL.darkened(0.4)
	btn.add_theme_stylebox_override("normal", style)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = COLOR_TOOL.lightened(0.2)
	style_hover.corner_radius_top_left = 6
	style_hover.corner_radius_top_right = 6
	style_hover.corner_radius_bottom_left = 6
	style_hover.corner_radius_bottom_right = 6
	style_hover.border_width_left = 2
	style_hover.border_width_right = 2
	style_hover.border_width_top = 2
	style_hover.border_width_bottom = 2
	style_hover.border_color = COLOR_TOOL.darkened(0.2)
	btn.add_theme_stylebox_override("hover", style_hover)

	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = COLOR_TOOL_SELECTED
	style_pressed.corner_radius_top_left = 6
	style_pressed.corner_radius_top_right = 6
	style_pressed.corner_radius_bottom_left = 6
	style_pressed.corner_radius_bottom_right = 6
	style_pressed.border_width_left = 3
	style_pressed.border_width_right = 3
	style_pressed.border_width_top = 3
	style_pressed.border_width_bottom = 3
	style_pressed.border_color = Color.WHITE
	btn.add_theme_stylebox_override("pressed", style_pressed)

	btn.pressed.connect(_on_tool_button_pressed.bind(action_name, btn))

	action_buttons[action_name] = btn
	parent.add_child(btn)


func _on_tool_button_pressed(tool_name: String, button: Button):
	"""Handle tool button press - toggle mode selection"""
	# Check if this tool is already selected
	if selected_mode == tool_name:
		# Already selected - deselect it
		selected_mode = ""
		_update_button_styles()
		mode_selected.emit("")
		print("🛠️ Tool deselected")
	else:
		# Select this tool
		selected_mode = tool_name
		_update_button_styles()
		mode_selected.emit(tool_name)
		print("🛠️ Tool selected: %s" % tool_name)


func _update_button_styles():
	"""Update button styles to show selected state"""
	for tool_name in action_buttons:
		var btn = action_buttons[tool_name]
		if tool_name == selected_mode:
			# Selected style
			var style = StyleBoxFlat.new()
			style.bg_color = COLOR_TOOL_SELECTED
			style.corner_radius_top_left = 6
			style.corner_radius_top_right = 6
			style.corner_radius_bottom_left = 6
			style.corner_radius_bottom_right = 6
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_width_top = 3
			style.border_width_bottom = 3
			style.border_color = Color.WHITE
			btn.add_theme_stylebox_override("normal", style)
		else:
			# Unselected style
			var style = StyleBoxFlat.new()
			style.bg_color = COLOR_TOOL
			style.corner_radius_top_left = 6
			style.corner_radius_top_right = 6
			style.corner_radius_bottom_left = 6
			style.corner_radius_bottom_right = 6
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			style.border_color = COLOR_TOOL.darkened(0.4)
			btn.add_theme_stylebox_override("normal", style)


func _on_action_button_pressed(action_name: String):
	"""Handle action button press - execute immediately"""
	action_executed.emit(action_name)
	print("⚡ Action executed: %s" % action_name)


func get_selected_mode() -> String:
	"""Get currently selected tool mode"""
	return selected_mode


func clear_selection():
	"""Clear tool selection"""
	selected_mode = ""
	_update_button_styles()


func set_tool_enabled(tool_name: String, enabled: bool):
	"""Enable/disable a tool button"""
	if action_buttons.has(tool_name):
		action_buttons[tool_name].disabled = not enabled


func set_action_enabled(action_name: String, enabled: bool):
	"""Enable/disable an action button"""
	if action_buttons.has(action_name):
		action_buttons[action_name].disabled = not enabled


func _process(delta):
	"""Update HBoxContainer size to match parent PanelContainer (with margins)"""
	if not _vbox_container:
		return

	if size != Vector2.ZERO:
		# Account for margins (8px by default, scaled by scale factor)
		var scale_factor = layout_manager.scale_factor if layout_manager else 1.0
		var margin = int(8 * scale_factor)
		var available_size = size - Vector2(margin * 2, margin * 2)

		# Make HBoxContainer fill available space with margins
		_vbox_container.position = Vector2(margin, margin)
		_vbox_container.size = available_size
