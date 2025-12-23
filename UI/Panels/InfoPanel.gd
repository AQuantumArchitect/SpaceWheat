class_name InfoPanel
extends PanelContainer

## InfoPanel - Displays status messages and feedback
## Bottom UI component for showing game events and actions

# Layout manager reference (for dynamic scaling)
var layout_manager: Node  # Will be UILayoutManager instance

var info_label: Label
var message_timer: Timer


func set_layout_manager(manager: Node):
	"""Set the layout manager reference for dynamic scaling"""
	layout_manager = manager


func _ready():
	_create_ui()


func _create_ui():
	"""Create info display UI with dynamic scaling"""
	var scale_factor = layout_manager.scale_factor if layout_manager else 1.0
	var font_size = layout_manager.get_scaled_font_size(14) if layout_manager else 14
	var panel_height = int(60 * scale_factor)

	custom_minimum_size = Vector2(0, panel_height)

	info_label = Label.new()
	info_label.text = "Select a plot to begin"
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", font_size)
	add_child(info_label)

	# Timer for auto-clearing messages
	message_timer = Timer.new()
	message_timer.one_shot = true
	message_timer.timeout.connect(_on_message_timeout)
	add_child(message_timer)


## Public API - Update Methods

func show_message(message: String, duration: float = 0.0, color: Color = Color.WHITE):
	"""Display a message

	Args:
	  message: Text to display
	  duration: Auto-clear after N seconds (0 = don't auto-clear)
	  color: Text color
	"""
	_ensure_initialized()  # Make sure label exists before using it

	if info_label:
		info_label.text = message
		info_label.modulate = color

		if duration > 0:
			message_timer.start(duration)


func clear():
	"""Clear the message"""
	_ensure_initialized()

	if info_label:
		info_label.text = ""
		info_label.modulate = Color.WHITE


func _ensure_initialized():
	"""Ensure info_label is initialized (call _ready() if not yet called)"""
	if not info_label:
		_ready()  # Initialize the label if not already done


func flash_success(message: String):
	"""Show a success message with green flash"""
	show_message(message, 3.0, Color(0.4, 1.0, 0.4))


func flash_error(message: String):
	"""Show an error message with red flash"""
	show_message(message, 3.0, Color(1.0, 0.4, 0.4))


func flash_warning(message: String):
	"""Show a warning message with yellow flash"""
	show_message(message, 3.0, Color(1.0, 1.0, 0.4))


func show_plot_info(wheat_plot):
	"""Display plot state information with dual emoji"""
	if not wheat_plot:
		clear()
		return

	var state_desc = wheat_plot.get_state_description()
	show_message(state_desc, 0.0, Color.WHITE)


func _on_message_timeout():
	"""Clear message when timer expires"""
	clear()
