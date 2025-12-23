extends SceneTree

## Topology System Tests
## Verify TopologyAnalyzer works correctly after fixes

const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const TopologyAnalyzer = preload("res://Core/QuantumSubstrate/TopologyAnalyzer.gd")

func _initialize():
	print("\n" + "=".repeat(80))
	print("  TOPOLOGY SYSTEM TESTS")
	print("=".repeat(80) + "\n")

	test_simple_pair()
	test_triangle()
	test_chain()
	test_no_entanglement()

	print("\n" + "=".repeat(80))
	print("  ALL TOPOLOGY TESTS PASSED ✅")
	print("=".repeat(80) + "\n")

	quit()


func test_simple_pair():
	print("TEST 1: Simple Pair (2 plots, 1 edge)")
	print("─".repeat(40))

	var farm = FarmGrid.new()
	farm.grid_width = 3
	farm.grid_height = 3
	farm._ready()

	# Plant and entangle two plots
	farm.plant_wheat(Vector2i(0, 0))
	farm.plant_wheat(Vector2i(1, 0))
	farm.create_entanglement(Vector2i(0, 0), Vector2i(1, 0), "phi_plus")

	var plots = [
		farm.get_plot(Vector2i(0, 0)),
		farm.get_plot(Vector2i(1, 0))
	]

	# Analyze topology
	var topology = farm.topology_analyzer.analyze_entanglement_network(plots)

	print("  Node count: %d (expected: 2)" % topology.node_count)
	print("  Edge count: %d (expected: 1)" % topology.edge_count)

	test_assert(topology.node_count == 2, "Should have 2 nodes")
	test_assert(topology.edge_count == 1, "Should have 1 edge")
	test_assert(topology.features.is_connected, "Should be connected")

	print("  ✅ Simple pair topology correct\n")


func test_triangle():
	print("TEST 2: Triangle (3 plots, 3 edges)")
	print("─".repeat(40))

	var farm = FarmGrid.new()
	farm.grid_width = 3
	farm.grid_height = 3
	farm._ready()

	# Create triangle: 0-1, 1-2, 2-0
	farm.plant_wheat(Vector2i(0, 0))
	farm.plant_wheat(Vector2i(1, 0))
	farm.plant_wheat(Vector2i(2, 0))

	farm.create_entanglement(Vector2i(0, 0), Vector2i(1, 0), "phi_plus")
	farm.create_entanglement(Vector2i(1, 0), Vector2i(2, 0), "phi_plus")
	farm.create_entanglement(Vector2i(2, 0), Vector2i(0, 0), "phi_plus")

	var plots = [
		farm.get_plot(Vector2i(0, 0)),
		farm.get_plot(Vector2i(1, 0)),
		farm.get_plot(Vector2i(2, 0))
	]

	var topology = farm.topology_analyzer.analyze_entanglement_network(plots)

	print("  Node count: %d (expected: 3)" % topology.node_count)
	print("  Edge count: %d (expected: 3)" % topology.edge_count)
	print("  Has cycles: %s (expected: true)" % topology.features.has_cycles)

	test_assert(topology.node_count == 3, "Should have 3 nodes")
	test_assert(topology.edge_count == 3, "Should have 3 edges")
	test_assert(topology.features.has_cycles, "Triangle should have cycles")

	print("  Bonus multiplier: %.2f" % topology.bonus_multiplier)
	test_assert(topology.bonus_multiplier > 1.0, "Triangle should give bonus")

	print("  ✅ Triangle topology correct\n")


func test_chain():
	print("TEST 3: Chain (4 plots, 3 edges)")
	print("─".repeat(40))

	var farm = FarmGrid.new()
	farm.grid_width = 4
	farm.grid_height = 1
	farm._ready()

	# Create chain: 0-1-2-3
	farm.plant_wheat(Vector2i(0, 0))
	farm.plant_wheat(Vector2i(1, 0))
	farm.plant_wheat(Vector2i(2, 0))
	farm.plant_wheat(Vector2i(3, 0))

	farm.create_entanglement(Vector2i(0, 0), Vector2i(1, 0), "phi_plus")
	farm.create_entanglement(Vector2i(1, 0), Vector2i(2, 0), "phi_plus")
	farm.create_entanglement(Vector2i(2, 0), Vector2i(3, 0), "phi_plus")

	var plots = [
		farm.get_plot(Vector2i(0, 0)),
		farm.get_plot(Vector2i(1, 0)),
		farm.get_plot(Vector2i(2, 0)),
		farm.get_plot(Vector2i(3, 0))
	]

	var topology = farm.topology_analyzer.analyze_entanglement_network(plots)

	print("  Node count: %d (expected: 4)" % topology.node_count)
	print("  Edge count: %d (expected: 3)" % topology.edge_count)
	print("  Has cycles: %s (expected: false)" % topology.features.has_cycles)

	test_assert(topology.node_count == 4, "Should have 4 nodes")
	test_assert(topology.edge_count == 3, "Should have 3 edges")
	test_assert(not topology.features.has_cycles, "Chain should not have cycles")

	print("  ✅ Chain topology correct\n")


func test_no_entanglement():
	print("TEST 4: No Entanglement (3 plots, 0 edges)")
	print("─".repeat(40))

	var farm = FarmGrid.new()
	farm.grid_width = 3
	farm.grid_height = 1
	farm._ready()

	# Plant but don't entangle
	farm.plant_wheat(Vector2i(0, 0))
	farm.plant_wheat(Vector2i(1, 0))
	farm.plant_wheat(Vector2i(2, 0))

	var plots = [
		farm.get_plot(Vector2i(0, 0)),
		farm.get_plot(Vector2i(1, 0)),
		farm.get_plot(Vector2i(2, 0))
	]

	var topology = farm.topology_analyzer.analyze_entanglement_network(plots)

	print("  Node count: %d (expected: 3)" % topology.node_count)
	print("  Edge count: %d (expected: 0)" % topology.edge_count)

	test_assert(topology.node_count == 3, "Should have 3 nodes")
	test_assert(topology.edge_count == 0, "Should have 0 edges")
	test_assert(topology.bonus_multiplier == 1.0, "No entanglement = no bonus")

	print("  ✅ No entanglement case correct\n")


func test_assert(condition: bool, message: String):
	if not condition:
		print("  ❌ FAILED: %s" % message)
		push_error(message)
		quit(1)
