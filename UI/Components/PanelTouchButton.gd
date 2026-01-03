class_name PanelTouchButton
extends Button

## Touch-Friendly Panel Toggle Button
## Large button for opening panels on touch devices
## Displays emoji + keyboard hint

signal button_activated

@export var button_emoji: String = ""
@export var button_label: String = ""
@export var keyboard_hint: String = ""

var layout_manager: Node = null


func set_layout_manager(manager: Node) -> void:
	"""Set layout manager for scaling"""
	layout_manager = manager


func _ready() -> void:
	"""Initialize button appearance and behavior"""
	var scale = layout_manager.scale_factor if layout_manager else 1.0
	var font_size = layout_manager.get_scaled_font_size(24) if layout_manager else 24

	# Large size for touch accessibility
	custom_minimum_size = Vector2(70 * scale, 70 * scale)

	# Set text with emoji and keyboard hint
	text = button_emoji
	if keyboard_hint:
		text += "\n" + keyboard_hint

	# Font size
	add_theme_font_size_override("font_size", font_size)

	# Connect pressed signal
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	"""Emit button_activated signal when pressed"""
	button_activated.emit()
