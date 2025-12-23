class_name GoalPanel
extends PanelContainer

## GoalPanel - Displays current goal and progress
## Central UI component showing player objectives
## Click to cycle between tutorial goals and active contracts

signal goal_clicked

# Layout manager reference (for dynamic scaling)
var layout_manager: Node  # Will be UILayoutManager instance

# UI elements
var goal_title_label: Label
var goal_progress_bar: ProgressBar
var goal_progress_label: Label
var goal_counter_label: Label


func set_layout_manager(manager: Node):
	"""Set the layout manager reference for dynamic scaling"""
	layout_manager = manager


func _ready():
	_create_ui()
	# Enable mouse input for click-to-cycle
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event):
	"""Handle mouse clicks to cycle goals"""
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			goal_clicked.emit()
			# Visual feedback
			var tween = create_tween()
			tween.tween_property(self, "modulate", Color(0.8, 0.8, 1.0), 0.1)
			tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.1)


func _create_ui():
	"""Create goal display UI with dynamic scaling"""
	var scale_factor = layout_manager.scale_factor if layout_manager else 1.0
	var title_font_size = layout_manager.get_scaled_font_size(16) if layout_manager else 16
	var counter_font_size = layout_manager.get_scaled_font_size(14) if layout_manager else 14
	var progress_font_size = layout_manager.get_scaled_font_size(12) if layout_manager else 12

	var panel_width = int(400 * scale_factor)
	var panel_height = int(80 * scale_factor)
	custom_minimum_size = Vector2(panel_width, panel_height)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(10 * scale_factor))
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS  # Let clicks through to parent
	add_child(vbox)

	# Goal title with counter
	var title_hbox = HBoxContainer.new()
	title_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	title_hbox.mouse_filter = Control.MOUSE_FILTER_PASS  # Let clicks through
	vbox.add_child(title_hbox)

	goal_title_label = Label.new()
	goal_title_label.text = "🎯 Goal: Loading..."
	goal_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal_title_label.add_theme_font_size_override("font_size", title_font_size)
	title_hbox.add_child(goal_title_label)

	goal_counter_label = Label.new()
	goal_counter_label.text = ""
	goal_counter_label.add_theme_font_size_override("font_size", counter_font_size)
	goal_counter_label.modulate = Color(0.7, 0.7, 0.7)
	title_hbox.add_child(goal_counter_label)

	# Progress bar with label
	var progress_hbox = HBoxContainer.new()
	progress_hbox.add_theme_constant_override("separation", int(10 * scale_factor))
	progress_hbox.mouse_filter = Control.MOUSE_FILTER_PASS  # Let clicks through
	vbox.add_child(progress_hbox)

	goal_progress_bar = ProgressBar.new()
	goal_progress_bar.custom_minimum_size = Vector2(int(300 * scale_factor), int(20 * scale_factor))
	goal_progress_bar.show_percentage = false
	progress_hbox.add_child(goal_progress_bar)

	goal_progress_label = Label.new()
	goal_progress_label.text = "0 / 0"
	goal_progress_label.add_theme_font_size_override("font_size", progress_font_size)
	goal_progress_label.add_theme_constant_override("outline_size", int(8 * scale_factor))
	progress_hbox.add_child(goal_progress_label)


## Public API - Update Methods

func update_goal(goal_data: Dictionary, progress: float, progress_text: String, current_index: int = 0, total_count: int = 1):
	"""Update goal display

	Args:
	  goal_data: Dictionary with "title" key
	  progress: Float 0.0 - 1.0
	  progress_text: String like "5 / 10"
	  current_index: Index of currently displayed goal (0-based)
	  total_count: Total number of goals/contracts available
	"""
	# Update goal title
	var goal_prefix = "🎯"
	if goal_data.get("type") == "contract":
		goal_prefix = "📜"  # Contract emoji instead of goal emoji

	goal_title_label.text = "%s %s" % [goal_prefix, goal_data["title"]]

	# Update counter if multiple goals available
	if total_count > 1:
		goal_counter_label.text = " (%d/%d)" % [current_index + 1, total_count]
		goal_counter_label.visible = true
	else:
		goal_counter_label.visible = false

	# Update progress bar (0.0 - 1.0)
	goal_progress_bar.value = progress * 100.0  # ProgressBar uses 0-100
	goal_progress_bar.max_value = 100.0

	# Update progress text
	goal_progress_label.text = progress_text

	# Color based on completion
	if progress >= 1.0:
		goal_progress_bar.modulate = Color(0.4, 1.0, 0.4)  # Green when complete
		goal_title_label.modulate = Color(0.4, 1.0, 0.4)  # Green title too
	else:
		goal_progress_bar.modulate = Color(1.0, 1.0, 1.0)  # White in progress
		goal_title_label.modulate = Color(1.0, 1.0, 1.0)  # White title


func flash_complete():
	"""Flash the panel green to celebrate goal completion"""
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(0.4, 1.0, 0.4), 0.3)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.3)
	tween.tween_property(self, "modulate", Color(0.4, 1.0, 0.4), 0.3)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.3)
