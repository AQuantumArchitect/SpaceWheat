extends Node2D

## Visual Touch Test - Shows touch feedback on screen
## Plant wheat with Q, then tap bubbles - visual feedback shows what's happening

var farm_view = null
var feedback_label = null

func _ready() -> void:
	# Wait for FarmView to initialize
	await get_tree().create_timer(2.0).timeout

	farm_view = get_tree().current_scene.get_node_or_null("FarmView")
	if not farm_view:
		print("ERROR: No FarmView found!")
		return

	# Create on-screen feedback label
	feedback_label = Label.new()
	feedback_label.position = Vector2(20, 20)
	feedback_label.add_theme_font_size_override("font_size", 24)
	add_child(feedback_label)

	update_feedback("Ready! Press Q to plant wheat, then tap bubbles")

	# Connect to tap handler to show visual feedback
	if farm_view.quantum_viz and farm_view.quantum_viz.graph:
		farm_view.quantum_viz.graph.node_clicked.connect(_on_bubble_tapped)
		print("✅ Connected to bubble tap signal for visual feedback")


func update_feedback(message: String) -> void:
	if feedback_label:
		feedback_label.text = message
		print("📢 %s" % message)


func _on_bubble_tapped(grid_pos: Vector2i, button_index: int) -> void:
	update_feedback("BUBBLE TAPPED! Grid: %s, Button: %d" % [grid_pos, button_index])

	# Flash the feedback
	await get_tree().create_timer(2.0).timeout
	update_feedback("Ready for next tap...")
