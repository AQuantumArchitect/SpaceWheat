extends SceneTree

## Test: Rejection visual feedback with full UI
## Loads FarmUI and simulates planting to trigger rejection

const Farm = preload("res://Core/Farm.gd")
const FarmUI = preload("res://UI/FarmUI.gd")

var farm: Farm
var farm_ui: FarmUI

func _initialize():
	print("\n" + "=".repeat(80))
	print("TEST: Rejection Visual Feedback (Full UI)")
	print("=".repeat(80))

	await get_root().ready

	# Create farm
	farm = Farm.new()
	farm.name = "Farm"
	get_root().add_child(farm)

	print("\nFarm initialized, waiting for ready...")
	await farm.ready

	# Load FarmUI scene
	print("\nLoading FarmUI scene...")
	var farm_ui_scene = load("res://UI/FarmUI.tscn")
	if not farm_ui_scene:
		push_error("Failed to load FarmUI scene!")
		quit(1)
		return

	farm_ui = farm_ui_scene.instantiate()
	get_root().add_child(farm_ui)

	print("Waiting for FarmUI ready...")
	await farm_ui.ready

	print("Setting up farm reference in FarmUI...")
	farm_ui.setup_farm(farm)

	# Wait for any pending signals
	await process_frame
	await process_frame

	print("\n" + "=".repeat(80))
	print("Setup complete - starting test sequence")
	print("=".repeat(80))

	# Test 1: Try to plant WHEAT at (0,0) [Market biome - should REJECT]
	print("\n1. Test: Try to plant WHEAT at (0,0) [Market biome - should REJECT]")
	if farm.grid.biomes.has("Market"):
		var market = farm.grid.biomes.get("Market")
		if market and market.bath:
			print("   Market biome emojis: %s" % market.bath.emoji_list)

	# Simulate Tool 1 selection (wheat)
	if farm_ui.input_handler:
		farm_ui.input_handler.current_tool = 1
		farm_ui._select_tool(1)

	# Simulate plot selection at (0,0)
	if farm_ui.plot_grid_display:
		farm_ui.plot_grid_display.selected_plots = [Vector2i(0, 0)]
		farm_ui.plot_grid_display.selection_count_changed.emit(1)

	# Try to plant (this should REJECT because wheat not in Market biome)
	var result1 = farm.build(Vector2i(0, 0), "wheat")
	if result1:
		print("   Build result: ALLOWED (ERROR)")
	else:
		print("   Build result: REJECTED (CORRECT)")

	await process_frame

	# Test 2: Try to plant TOMATO at (2,0) [BioticFlux biome - should REJECT]
	print("\n2. Test: Try to plant TOMATO at (2,0) [BioticFlux biome - should REJECT]")
	if farm.grid.biomes.has("BioticFlux"):
		var biotic = farm.grid.biomes.get("BioticFlux")
		if biotic and biotic.bath:
			print("   BioticFlux biome emojis: %s" % biotic.bath.emoji_list)

	# Simulate Tool 2 selection (tomato)
	if farm_ui.input_handler:
		farm_ui.input_handler.current_tool = 2
		farm_ui._select_tool(2)

	# Simulate plot selection at (2,0)
	if farm_ui.plot_grid_display:
		farm_ui.plot_grid_display.selected_plots = [Vector2i(2, 0)]
		farm_ui.plot_grid_display.selection_count_changed.emit(1)

	# Try to plant (this should REJECT because tomato not in BioticFlux)
	var result2 = farm.build(Vector2i(2, 0), "tomato")
	if result2:
		print("   Build result: ALLOWED (ERROR)")
	else:
		print("   Build result: REJECTED (CORRECT)")

	await process_frame

	# Test 3: Try to plant WHEAT at (2,0) [BioticFlux biome - should ALLOW]
	print("\n3. Test: Try to plant WHEAT at (2,0) [BioticFlux biome - should ALLOW]")

	# Simulate Tool 1 selection (wheat)
	if farm_ui.input_handler:
		farm_ui.input_handler.current_tool = 1
		farm_ui._select_tool(1)

	# Simulate plot selection at (2,0)
	if farm_ui.plot_grid_display:
		farm_ui.plot_grid_display.selected_plots = [Vector2i(2, 0)]
		farm_ui.plot_grid_display.selection_count_changed.emit(1)

	# Try to plant (this should ALLOW because wheat IS in BioticFlux)
	var result3 = farm.build(Vector2i(2, 0), "wheat")
	if result3:
		print("   Build result: ALLOWED (CORRECT)")
	else:
		print("   Build result: REJECTED (ERROR)")

	await process_frame

	# Test 4: Try to plant WHEAT at (2,0) again [should REJECT - occupied]
	print("\n4. Test: Try to plant WHEAT at (2,0) again [should REJECT - occupied]")

	# Try to plant again at same spot (should REJECT - occupied)
	var result4 = farm.build(Vector2i(2, 0), "wheat")
	if result4:
		print("   Build result: ALLOWED (ERROR)")
	else:
		print("   Build result: REJECTED (CORRECT)")

	# Wait for signals to propagate
	await process_frame
	await process_frame

	print("\n" + "=".repeat(80))
	print("Test sequence complete!")
	print("=".repeat(80))

	# Check if PlotGridDisplay has rejection_effects
	if farm_ui and farm_ui.plot_grid_display:
		print("\nPlotGridDisplay state:")
		print("   rejection_effects count: %d" % farm_ui.plot_grid_display.rejection_effects.size())
		print("   classical_plot_positions count: %d" % farm_ui.plot_grid_display.classical_plot_positions.size())
		if farm_ui.plot_grid_display.classical_plot_positions.size() > 0:
			print("   First 5 plot positions:")
			var count = 0
			for pos in farm_ui.plot_grid_display.classical_plot_positions:
				print("      %s -> %s" % [pos, farm_ui.plot_grid_display.classical_plot_positions[pos]])
				count += 1
				if count >= 5:
					break

	print("\nIf you saw debug output from PlotGridDisplay, the system is working!")
	print("   Look for: 'PlotGridDisplay.show_rejection_effect() CALLED!'")
	print("   Look for: '_draw_rejection_effects() CALLED with N effects!'")

	quit(0)
