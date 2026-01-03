extends SceneTree
## Simple headless test runner for tool evaluation
## Waits for boot sequence then runs tests

var farm: Node
var input_handler: Node
var plot_grid_display: Node
var test_results: Dictionary = {}

func _init():
	print("\n" + "=".repeat(80))
	print("HEADLESS TOOL EVALUATION TEST")
	print("=".repeat(80) + "\n")

	# Load FarmView scene
	var scene = load("res://scenes/FarmView.tscn")
	var farm_view = scene.instantiate()
	root.add_child(farm_view)

	# Wait for boot sequence to complete
	print("⏳ Waiting for BootManager boot sequence...")

	# Use a timer-based approach instead of awaits
	var timer = Timer.new()
	root.add_child(timer)
	timer.timeout.connect(_check_boot_complete.bind(farm_view))
	timer.start(0.5)  # Check every 0.5 seconds


func _check_boot_complete(farm_view):
	"""Check if boot sequence has completed and components are ready"""

	# Try to find input handler
	var farm_ui = farm_view.find_child("FarmUI", true, false)
	if not farm_ui:
		return  # Not ready yet, keep waiting

	var handler = farm_ui.get("input_handler")
	if not handler:
		return  # Not ready yet, keep waiting

	# Boot complete! Run tests
	print("✅ Boot sequence complete - running tests\n")

	farm = farm_view.get_farm()
	input_handler = handler
	plot_grid_display = farm_ui.get("plot_grid_display")

	_run_all_tests()


func _run_all_tests():
	"""Run all tool tests sequentially"""
	print("\n" + "-".repeat(80))
	print("TOOL 1: GROWER")
	print("-".repeat(80))
	_test_tool_1()

	print("\n" + "-".repeat(80))
	print("TOOL 2: QUANTUM")
	print("-".repeat(80))
	_test_tool_2()

	print("\n" + "-".repeat(80))
	print("TOOL 3: INDUSTRY")
	print("-".repeat(80))
	_test_tool_3()

	print("\n" + "-".repeat(80))
	print("TOOL 4: ENERGY")
	print("-".repeat(80))
	_test_tool_4()

	_print_summary()
	quit()


func _test_tool_1():
	"""Test Grower tool (plant, entangle, harvest)"""
	input_handler.current_tool = 1

	# Test plant
	print("[Q] plant_batch")
	input_handler.current_selection = Vector2i(0, 0)
	plot_grid_display._toggle_plot_selection(Vector2i(0, 0))
	farm.build(Vector2i(0, 0), "wheat")
	var planted = farm.grid.get_plot(Vector2i(0, 0)).is_planted
	test_results["Tool1_plant"] = "PASS" if planted else "FAIL"
	print("  Result: %s" % test_results["Tool1_plant"])

	# Test entangle
	print("[E] entangle_batch")
	farm.build(Vector2i(1, 0), "wheat")
	plot_grid_display._toggle_plot_selection(Vector2i(1, 0))
	farm.grid.create_entanglement(Vector2i(0, 0), Vector2i(1, 0), "phi_plus")
	var entangled = farm.grid.get_plot(Vector2i(0, 0)).entangled_plots.size() > 0
	test_results["Tool1_entangle"] = "PASS" if entangled else "FAIL"
	print("  Result: %s" % test_results["Tool1_entangle"])

	# Test harvest
	print("[R] measure_and_harvest")
	var wheat_before = farm.economy.wheat_inventory
	farm.harvest_plot(Vector2i(0, 0))
	var wheat_after = farm.economy.wheat_inventory
	test_results["Tool1_harvest"] = "PASS" if wheat_after > wheat_before else "FAIL"
	print("  Result: %s (wheat: %d → %d)" % [test_results["Tool1_harvest"], wheat_before, wheat_after])


func _test_tool_2():
	"""Test Quantum tool (cluster, measure, break entanglement)"""
	input_handler.current_tool = 2

	# Plant 3 plots for clustering
	for i in range(3):
		farm.build(Vector2i(i, 1), "wheat")

	print("[Q] cluster (3 plots)")
	farm.grid.create_entanglement(Vector2i(0, 1), Vector2i(1, 1), "phi_plus")
	farm.grid.create_entanglement(Vector2i(1, 1), Vector2i(2, 1), "phi_plus")
	var clustered = farm.grid.get_plot(Vector2i(0, 1)).entangled_plots.size() > 0
	test_results["Tool2_cluster"] = "PASS" if clustered else "FAIL"
	print("  Result: %s" % test_results["Tool2_cluster"])

	print("[E] measure_plot")
	var before_links = farm.grid.get_plot(Vector2i(0, 1)).entangled_plots.size()
	farm.measure_plot(Vector2i(0, 1))
	var after_links = farm.grid.get_plot(Vector2i(0, 1)).entangled_plots.size()
	test_results["Tool2_measure"] = "PASS" if after_links < before_links else "FAIL"
	print("  Result: %s (links: %d → %d)" % [test_results["Tool2_measure"], before_links, after_links])

	print("[R] break_entanglement")
	if farm.grid.get_plot(Vector2i(1, 1)):
		farm.grid.get_plot(Vector2i(1, 1)).entangled_plots.clear()
	var no_links = farm.grid.get_plot(Vector2i(1, 1)).entangled_plots.size() == 0
	test_results["Tool2_break"] = "PASS" if no_links else "FAIL"
	print("  Result: %s" % test_results["Tool2_break"])


func _test_tool_3():
	"""Test Industry tool (mill, market, kitchen)"""
	input_handler.current_tool = 3

	print("[Q] place_mill")
	farm.grid.plant_mill(Vector2i(3, 0))
	var has_mill = farm.grid.get_plot(Vector2i(3, 0)).is_planted
	test_results["Tool3_mill"] = "PASS" if has_mill else "FAIL"
	print("  Result: %s" % test_results["Tool3_mill"])

	print("[E] place_market")
	farm.grid.plant_market(Vector2i(4, 0))
	var has_market = farm.grid.get_plot(Vector2i(4, 0)).is_planted
	test_results["Tool3_market"] = "PASS" if has_market else "FAIL"
	print("  Result: %s" % test_results["Tool3_market"])

	print("[R] place_kitchen")
	# Kitchen needs 3 plots
	farm.grid.create_triplet_entanglement(Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1))
	var p1 = farm.grid.get_plot(Vector2i(3, 1))
	var p2 = farm.grid.get_plot(Vector2i(4, 1))
	var p3 = farm.grid.get_plot(Vector2i(5, 1))
	var kitchen_works = p1 and p2 and p3 and p1.entangled_plots.size() > 0
	test_results["Tool3_kitchen"] = "PASS" if kitchen_works else "FAIL"
	print("  Result: %s" % test_results["Tool3_kitchen"])


func _test_tool_4():
	"""Test Energy tool (inject, drain, tap)"""
	input_handler.current_tool = 4

	# Plant a plot with quantum state
	farm.build(Vector2i(0, 0), "wheat")

	print("[Q] inject_energy")
	var plot = farm.grid.get_plot(Vector2i(0, 0))
	var energy_before = plot.quantum_state.energy if plot.quantum_state else 0.0
	if plot.quantum_state:
		plot.quantum_state.energy += 5.0  # Simulate injection
	var energy_after = plot.quantum_state.energy if plot.quantum_state else 0.0
	test_results["Tool4_inject"] = "PASS" if energy_after > energy_before else "FAIL"
	print("  Result: %s (energy: %.2f → %.2f)" % [test_results["Tool4_inject"], energy_before, energy_after])

	print("[E] drain_energy")
	var wheat_before = farm.economy.wheat_inventory
	if plot.quantum_state and plot.quantum_state.energy > 0:
		var drained = min(plot.quantum_state.energy, 3.0)
		plot.quantum_state.energy -= drained
		farm.economy.wheat_inventory += int(drained)
	var wheat_after = farm.economy.wheat_inventory
	test_results["Tool4_drain"] = "PASS" if wheat_after > wheat_before else "FAIL"
	print("  Result: %s (wheat: %d → %d)" % [test_results["Tool4_drain"], wheat_before, wheat_after])

	print("[R] place_energy_tap")
	farm.grid.plant_energy_tap(Vector2i(2, 1))
	var has_tap = farm.grid.get_plot(Vector2i(2, 1)).is_planted
	test_results["Tool4_tap"] = "PASS" if has_tap else "FAIL"
	print("  Result: %s" % test_results["Tool4_tap"])


func _print_summary():
	print("\n" + "=".repeat(80))
	print("TEST SUMMARY")
	print("=".repeat(80))

	var passed = 0
	var failed = 0

	for action in test_results.keys():
		var result = test_results[action]
		if result == "PASS":
			passed += 1
			print("  ✅ %s: PASS" % action)
		else:
			failed += 1
			print("  ❌ %s: FAIL" % action)

	print("\n📊 Results: %d passed, %d failed (out of %d total)" % [passed, failed, test_results.size()])
	print("=".repeat(80) + "\n")
