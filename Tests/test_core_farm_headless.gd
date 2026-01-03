extends Node

## Headless Core Farm API Test
## Tests basic farm operations after BootManager boot sequence
## No UI interactions - direct API calls only

var farm: Node
var passed: int = 0
var failed: int = 0

func _ready():
	print("\n" + "=".repeat(70))
	print("HEADLESS CORE FARM API TEST")
	print("=".repeat(70) + "\n")

	# Wait for BootManager boot sequence
	print("⏳ Waiting for BootManager...")
	var boot_mgr = get_node_or_null("/root/BootManager")
	if boot_mgr:
		if not boot_mgr.is_ready:
			if boot_mgr.has_signal("game_ready"):
				await boot_mgr.game_ready
		print("✅ BootManager ready\n")
		# Wait a few frames for post-boot setup
		for i in range(5):
			await get_tree().process_frame
	else:
		print("⚠️  BootManager not found\n")

	# Find farm
	var farm_view = get_tree().root.find_child("FarmView", true, false)
	if not farm_view:
		_fail("FarmView not found")
		return

	farm = farm_view.get_farm()
	if not farm:
		_fail("Farm not found")
		return

	print("✅ Farm found, running tests...\n")

	# Run core API tests
	_test_plant_wheat()
	await get_tree().process_frame

	_test_create_entanglement()
	await get_tree().process_frame

	_test_harvest_plot()
	await get_tree().process_frame

	_test_plant_mill()
	await get_tree().process_frame

	_test_plant_market()
	await get_tree().process_frame

	_test_triplet_entanglement()
	await get_tree().process_frame

	# Print summary
	_print_summary()

	get_tree().quit()


func _test_plant_wheat():
	print("TEST 1: farm.build(pos, 'wheat')")
	farm.build(Vector2i(0, 0), "wheat")
	var plot = farm.grid.get_plot(Vector2i(0, 0))
	if plot and plot.is_planted:
		_pass("Wheat planted at (0,0)")
	else:
		_fail("Plot not planted")


func _test_create_entanglement():
	print("\nTEST 2: farm.grid.create_entanglement()")
	farm.build(Vector2i(1, 0), "wheat")

	# Get biome for the plot
	var biome_name = farm.grid.plot_biome_assignments.get(Vector2i(0, 0))
	if not biome_name:
		_fail("Plot has no biome assignment")
		return

	var biome = farm.grid.biomes.get(biome_name)
	if not biome:
		_fail("Biome not found: %s" % biome_name)
		return

	# Create entanglement
	farm.grid.create_entanglement(Vector2i(0, 0), Vector2i(1, 0), "phi_plus")

	# Check if bell gate was created in biome
	var gate_found = false
	for gate in biome.bell_gates:
		if Vector2i(0, 0) in gate and Vector2i(1, 0) in gate:
			gate_found = true
			break

	if gate_found:
		_pass("Entanglement created (Bell gate found)")
	else:
		_fail("No Bell gate created (gates: %d)" % biome.bell_gates.size())


func _test_harvest_plot():
	print("\nTEST 3: farm.harvest_plot()")

	var plot_before = farm.grid.get_plot(Vector2i(0, 0))
	var was_planted = plot_before and plot_before.is_planted

	# Harvest returns a Dictionary with {success, outcome, yield, ...}
	var harvest_result = farm.harvest_plot(Vector2i(0, 0))

	var plot_after = farm.grid.get_plot(Vector2i(0, 0))
	var now_empty = plot_after and not plot_after.is_planted

	# Check harvest succeeded (plot was planted before, now empty)
	if harvest_result.get("success", false) and was_planted and now_empty:
		var outcome = harvest_result.get("outcome", "?")
		var yield_amt = harvest_result.get("yield", 0)
		_pass("Harvest succeeded (outcome=%s, yield=%d)" % [outcome, yield_amt])
	else:
		_fail("Harvest failed (success=%s, was_planted=%s, now_empty=%s)" % [
			harvest_result.get("success", false), was_planted, now_empty])


func _test_plant_mill():
	print("\nTEST 4: farm.grid.place_mill()")
	var success = farm.grid.place_mill(Vector2i(2, 0))
	var plot = farm.grid.get_plot(Vector2i(2, 0))
	# FarmPlot.PlotType enum: 0=WHEAT, 1=MILL, 2=MARKET, etc.
	if success and plot and plot.is_planted:
		_pass("Mill placed (plot_type=%d)" % plot.plot_type)
	else:
		_fail("Mill not placed (success=%s)" % success)


func _test_plant_market():
	print("\nTEST 5: farm.grid.place_market()")
	var success = farm.grid.place_market(Vector2i(3, 0))
	var plot = farm.grid.get_plot(Vector2i(3, 0))
	if success and plot and plot.is_planted:
		_pass("Market placed (plot_type=%d)" % plot.plot_type)
	else:
		_fail("Market not placed (success=%s)" % success)


func _test_triplet_entanglement():
	print("\nTEST 6: farm.grid.create_triplet_entanglement()")
	farm.build(Vector2i(0, 1), "wheat")
	farm.build(Vector2i(1, 1), "wheat")
	farm.build(Vector2i(2, 1), "wheat")

	# Get biome
	var biome_name = farm.grid.plot_biome_assignments.get(Vector2i(0, 1))
	var biome = farm.grid.biomes.get(biome_name)

	if not biome:
		_fail("No biome for triplet entanglement")
		return

	farm.grid.create_triplet_entanglement(Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1))

	# Check for triplet gate in bell_gates (bell_gates stores both pairs and triplets)
	var triplet_found = false
	for gate in biome.bell_gates:
		# Triplet gates have 3 elements
		if gate.size() == 3:
			if Vector2i(0, 1) in gate and Vector2i(1, 1) in gate and Vector2i(2, 1) in gate:
				triplet_found = true
				break

	if triplet_found:
		_pass("Triplet entanglement created (3-qubit gate found)")
	else:
		_fail("No triplet gate created (bell_gates: %d)" % biome.bell_gates.size())


func _pass(message: String):
	passed += 1
	print("  ✅ PASS - %s" % message)


func _fail(message: String):
	failed += 1
	print("  ❌ FAIL - %s" % message)


func _print_summary():
	print("\n" + "=".repeat(70))
	print("RESULTS: %d passed, %d failed (out of 6 tests)" % [passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✅ ALL CORE FARM APIs WORKING IN HEADLESS MODE\n")
	else:
		print("⚠️  Some tests failed - see above for details\n")
