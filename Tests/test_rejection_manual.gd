extends Node2D

## Manual rejection test - Click anywhere to trigger rejection visual

var plot_grid: Control
var farm: Node

func _ready():
	print("\n" + "=".repeat(80))
	print("MANUAL REJECTION TEST")
	print("Click anywhere on screen to trigger rejection visual")
	print("=".repeat(80))

	# Create PlotGridDisplay
	var PlotGridDisplay = load("res://UI/PlotGridDisplay.gd")
	plot_grid = PlotGridDisplay.new()
	plot_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	plot_grid.z_index = 10  # Way above everything
	add_child(plot_grid)

	# Create fake classical_plot_positions
	plot_grid.classical_plot_positions = {
		Vector2i(0, 0): Vector2(640, 360)
	}

	# Start processing for animation
	plot_grid.set_process(true)

	print("✅ Test ready - PlotGridDisplay created")
	print("   z_index: %d" % plot_grid.z_index)
	print("   visible: %s" % plot_grid.visible)
	print("   size: %s" % plot_grid.size)

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		print("\n🖱️ Mouse clicked - triggering rejection at (0,0)")
		plot_grid.show_rejection_effect("test_action", Vector2i(0, 0), "Test rejection reason")
		print("   Rejection effect added, should see red circle!")
