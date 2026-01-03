extends SceneTree
## Simple smoke test for core Farm APIs (no UI, no BootManager)

var farm: Node
var passed: int = 0
var failed: int = 0
var check_count: int = 0

func _init():
	print("\n" + "=".repeat(70))
	print("API SMOKE TEST - Core Farm Operations")
	print("=".repeat(70) + "\n")

	# Create farm without UI
	var Farm = preload("res://Core/Farm.gd")
	farm = Farm.new()
	farm.name = "TestFarm"
	root.add_child(farm)

	print("⏳ Farm added to tree, waiting for _ready() to complete...")

	# Use process_frame signal to check when farm is ready
	process_frame.connect(_check_farm_ready)


func _check_farm_ready():
	check_count += 1

	# Wait until farm.grid exists (means _ready() completed)
	if not farm or not farm.grid:
		if check_count > 100:  # Safety timeout
			print("❌ TIMEOUT: Farm never initialized")
			quit()
		return

	# Farm is ready, disconnect and run tests
	process_frame.disconnect(_check_farm_ready)
	print("✅ Farm._ready() completed after %d frames\n" % check_count)
	_run_tests()


func _run_tests():

	# Test 1: Plant wheat
	print("TEST 1: farm.build(pos, 'wheat')")
	farm.build(Vector2i(0, 0), "wheat")
	var plot = farm.grid.get_plot(Vector2i(0, 0))
	if plot and plot.is_planted:
		print("  ✅ PASS - Plot planted")
		passed += 1
	else:
		print("  ❌ FAIL - Plot not planted")
		failed += 1

	# Test 2: Create entanglement
	print("\nTEST 2: farm.grid.create_entanglement()")
	farm.build(Vector2i(1, 0), "wheat")
	farm.grid.create_entanglement(Vector2i(0, 0), Vector2i(1, 0), "phi_plus")
	var plot0 = farm.grid.get_plot(Vector2i(0, 0))
	if plot0 and plot0.entangled_plots.size() > 0:
		print("  ✅ PASS - Entanglement created")
		passed += 1
	else:
		print("  ❌ FAIL - No entanglement")
		failed += 1

	# Test 3: Harvest
	print("\nTEST 3: farm.harvest_plot()")
	var wheat_before = farm.economy.wheat_inventory
	farm.harvest_plot(Vector2i(0, 0))
	var wheat_after = farm.economy.wheat_inventory
	if wheat_after > wheat_before:
		print("  ✅ PASS - Wheat gained (%d → %d)" % [wheat_before, wheat_after])
		passed += 1
	else:
		print("  ❌ FAIL - No wheat gained")
		failed += 1

	# Test 4: Plant mill
	print("\nTEST 4: farm.grid.plant_mill()")
	farm.grid.plant_mill(Vector2i(2, 0))
	var mill_plot = farm.grid.get_plot(Vector2i(2, 0))
	if mill_plot and mill_plot.is_planted:
		print("  ✅ PASS - Mill planted")
		passed += 1
	else:
		print("  ❌ FAIL - Mill not planted")
		failed += 1

	# Test 5: Plant market
	print("\nTEST 5: farm.grid.plant_market()")
	farm.grid.plant_market(Vector2i(3, 0))
	var market_plot = farm.grid.get_plot(Vector2i(3, 0))
	if market_plot and market_plot.is_planted:
		print("  ✅ PASS - Market planted")
		passed += 1
	else:
		print("  ❌ FAIL - Market not planted")
		failed += 1

	# Test 6: Plant energy tap
	print("\nTEST 6: farm.grid.plant_energy_tap()")
	farm.grid.plant_energy_tap(Vector2i(4, 0))
	var tap_plot = farm.grid.get_plot(Vector2i(4, 0))
	if tap_plot and tap_plot.is_planted:
		print("  ✅ PASS - Energy tap planted")
		passed += 1
	else:
		print("  ❌ FAIL - Energy tap not planted")
		failed += 1

	# Test 7: Triplet entanglement (kitchen)
	print("\nTEST 7: farm.grid.create_triplet_entanglement()")
	farm.build(Vector2i(0, 1), "wheat")
	farm.build(Vector2i(1, 1), "wheat")
	farm.build(Vector2i(2, 1), "wheat")
	farm.grid.create_triplet_entanglement(Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1))
	var p1 = farm.grid.get_plot(Vector2i(0, 1))
	if p1 and p1.entangled_plots.size() > 0:
		print("  ✅ PASS - Triplet entanglement created")
		passed += 1
	else:
		print("  ❌ FAIL - No triplet entanglement")
		failed += 1

	# Summary
	print("\n" + "=".repeat(70))
	print("RESULTS: %d passed, %d failed (out of 7 tests)" % [passed, failed])
	print("=".repeat(70) + "\n")

	if failed == 0:
		print("✅ ALL CORE APIs WORKING - Tools should function correctly\n")
	else:
		print("⚠️  Some APIs failed - Tool functionality may be affected\n")

	quit()
