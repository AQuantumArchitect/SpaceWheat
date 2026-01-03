extends SceneTree

## Test PlotGridDisplay rejection visual directly

func _init():
	print("\n" + "=".repeat(80))
	print("TEST: PlotGridDisplay Rejection Visual")
	print("=".repeat(80))

	# Load PlotGridDisplay script
	var PlotGridDisplay = load("res://UI/PlotGridDisplay.gd")
	if not PlotGridDisplay:
		push_error("Failed to load PlotGridDisplay script!")
		quit(1)
		return

	print("\nCreating PlotGridDisplay...")
	var plot_grid = PlotGridDisplay.new()
	root.add_child(plot_grid)

	await process_frame
	await process_frame

	print("PlotGridDisplay ready")
	print("   Type: %s" % plot_grid.get_class())
	print("   Has show_rejection_effect method? %s" % plot_grid.has_method("show_rejection_effect"))

	# Check method signature
	if plot_grid.has_method("show_rejection_effect"):
		print("\nCalling show_rejection_effect()...")
		plot_grid.show_rejection_effect("build_wheat", Vector2i(0, 0), "Test rejection reason")

		await process_frame

		print("   rejection_effects count: %d" % plot_grid.rejection_effects.size())
		if plot_grid.rejection_effects.size() > 0:
			print("   ✅ Rejection effect added successfully!")
			var effect = plot_grid.rejection_effects[0]
			print("   Grid pos: %s" % effect.grid_pos)
			print("   Reason: %s" % effect.reason)
		else:
			print("   ❌ No rejection effects added!")
	else:
		push_error("PlotGridDisplay does not have show_rejection_effect method!")

	print("\n" + "=".repeat(80))
	print("Test complete")
	print("=".repeat(80))

	quit(0)
