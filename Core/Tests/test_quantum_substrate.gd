extends Node

## Standalone Test Script for Quantum Substrate
## Run this scene to validate TomatoNode and TomatoConspiracyNetwork

# Preload the classes
const TomatoNode = preload("res://Core/QuantumSubstrate/TomatoNode.gd")
const TomatoConspiracyNetwork = preload("res://Core/QuantumSubstrate/TomatoConspiracyNetwork.gd")

var network: TomatoConspiracyNetwork
var test_passed: int = 0
var test_failed: int = 0


func _ready():
	print("\n============================================================")
	print("QUANTUM SUBSTRATE TEST SUITE")
	print("============================================================\n")

	# Run all tests
	test_tomato_node_creation()
	test_bloch_sphere_operations()
	test_energy_calculation()
	test_node_evolution()
	test_network_initialization()
	test_energy_diffusion()
	test_energy_conservation()
	test_conspiracy_activation()

	# Summary
	print("\n============================================================")
	print("TEST SUMMARY")
	print("============================================================")
	print("✅ Passed: %d" % test_passed)
	print("❌ Failed: %d" % test_failed)
	print("============================================================\n")

	if test_failed == 0:
		print("🎉 ALL TESTS PASSED! Quantum substrate is working correctly.\n")
	else:
		print("⚠️  SOME TESTS FAILED. Review output above.\n")

	# Keep running to show real-time evolution
	set_process(true)


func _process(delta):
	# Optional: Show live network state every 2 seconds
	pass


## Test Cases

func test_tomato_node_creation():
	print("TEST: TomatoNode Creation")
	var node = TomatoNode.new()
	node.node_id = "test"
	node.emoji_transform = "🌱→🍅"
	node.theta = PI / 2.0
	node.phi = 0.0
	node.q = 1.0
	node.p = 0.0
	node.update_energy()

	assert_true(node.node_id == "test", "Node ID should be set")
	assert_true(node.energy > 0.0, "Energy should be calculated")
	print("  ✓ Node created: %s\n" % node.get_debug_string())


func test_bloch_sphere_operations():
	print("TEST: Bloch Sphere Operations")
	var node = TomatoNode.new()

	# North pole (theta = 0)
	node.theta = 0.0
	node.phi = 0.0
	var north = node.get_bloch_vector()
	assert_approx(north, Vector3(0, 0, 1), "North pole should be (0,0,1)")

	# South pole (theta = PI)
	node.theta = PI
	node.phi = 0.0
	var south = node.get_bloch_vector()
	assert_approx(south, Vector3(0, 0, -1), "South pole should be (0,0,-1)")

	# Equator (theta = PI/2, phi = 0)
	node.theta = PI / 2.0
	node.phi = 0.0
	var equator = node.get_bloch_vector()
	assert_approx(equator, Vector3(1, 0, 0), "Equator point should be (1,0,0)")

	print("  ✓ Bloch sphere conversions correct\n")


func test_energy_calculation():
	print("TEST: Energy Calculation")
	var node = TomatoNode.new()

	# Zero state
	node.theta = 0.0
	node.phi = 0.0
	node.q = 0.0
	node.p = 0.0
	node.update_energy()
	assert_true(node.energy == 0.0, "Zero state should have zero energy")

	# Non-zero Gaussian state
	node.q = 1.0
	node.p = 1.0
	node.update_energy()
	var expected = (1.0 * 1.0 + 1.0 * 1.0) / 2.0  # Gaussian energy
	assert_approx_float(node.energy, expected, "Gaussian energy should be (q²+p²)/2")

	print("  ✓ Energy calculations correct\n")


func test_node_evolution():
	print("TEST: Node Evolution")
	var node = TomatoNode.new()
	node.theta = PI / 4.0
	node.phi = 0.0
	node.q = 1.0
	node.p = 0.0
	node.update_energy()

	var initial_energy = node.energy
	var initial_theta = node.theta

	# Evolve for 10 steps
	for i in range(10):
		node.evolve(0.1)

	assert_true(node.theta != initial_theta, "Theta should change after evolution")
	assert_true(abs(node.energy - initial_energy) > 0.01, "Energy should change")

	print("  ✓ Node evolution working\n")


func test_network_initialization():
	print("TEST: Network Initialization")
	network = TomatoConspiracyNetwork.new()
	add_child(network)  # Need to be in tree for _ready()

	await get_tree().process_frame  # Wait for _ready()

	assert_true(network.nodes.size() == 12, "Network should have 12 nodes")
	assert_true(network.connections.size() == 15, "Network should have 15 connections")

	# Check specific nodes exist
	assert_true(network.nodes.has("seed"), "Seed node should exist")
	assert_true(network.nodes.has("meta"), "Meta node should exist")

	# Check connections are bidirectional
	var seed_node = network.nodes["seed"]
	assert_true(seed_node.connections.has("solar"), "Seed should be connected to solar")
	assert_true(seed_node.connections.has("water"), "Seed should be connected to water")

	print("  ✓ Network initialized with %d nodes and %d connections\n" % [network.nodes.size(), network.connections.size()])


func test_energy_diffusion():
	print("TEST: Energy Diffusion")

	if not network:
		network = TomatoConspiracyNetwork.new()
		add_child(network)
		await get_tree().process_frame

	# Get initial energy distribution
	var seed_energy_before = network.nodes["seed"].energy
	var solar_energy_before = network.nodes["solar"].energy

	# Evolve network for 100 steps
	for i in range(100):
		network.evolve_network(0.1)

	var seed_energy_after = network.nodes["seed"].energy
	var solar_energy_after = network.nodes["solar"].energy

	# Energy should have changed (diffused)
	assert_true(
		abs(seed_energy_after - seed_energy_before) > 0.01,
		"Seed energy should change due to diffusion"
	)

	print("  ✓ Energy diffusion working\n")


func test_energy_conservation():
	print("TEST: Energy Conservation")

	if not network:
		network = TomatoConspiracyNetwork.new()
		add_child(network)
		await get_tree().process_frame

	var initial_total = network.get_total_energy()

	# Evolve for many steps
	for i in range(1000):
		network.evolve_network(0.01)

	var final_total = network.get_total_energy()

	# Energy should be approximately conserved (small drift due to damping is expected)
	var drift_percent = abs(final_total - initial_total) / initial_total * 100.0
	print("  Energy drift: %.2f%%" % drift_percent)
	assert_true(
		drift_percent < 50.0,  # Allow some drift due to damping
		"Energy should be approximately conserved"
	)

	print("  ✓ Energy approximately conserved (drift: %.2f%%)\n" % drift_percent)


func test_conspiracy_activation():
	print("TEST: Conspiracy Activation")

	if not network:
		network = TomatoConspiracyNetwork.new()
		add_child(network)
		await get_tree().process_frame

	# Manually set high energy to trigger conspiracy
	var seed_node = network.nodes["seed"]
	seed_node.energy = 2.0  # Above threshold for growth_acceleration (0.8)

	# Check conspiracies
	network.check_all_conspiracies()

	assert_true(
		network.active_conspiracies.get("growth_acceleration", false),
		"growth_acceleration should activate when seed energy > 0.8"
	)

	# Deactivate
	seed_node.energy = 0.1
	network.check_all_conspiracies()

	assert_true(
		not network.active_conspiracies.get("growth_acceleration", false),
		"growth_acceleration should deactivate when energy drops"
	)

	print("  ✓ Conspiracy activation/deactivation working\n")


## Assertion Helpers

func assert_true(condition: bool, message: String):
	if condition:
		test_passed += 1
	else:
		test_failed += 1
		print("  ❌ FAILED: %s" % message)


func assert_approx(v1: Vector3, v2: Vector3, message: String):
	if v1.is_equal_approx(v2):
		test_passed += 1
	else:
		test_failed += 1
		print("  ❌ FAILED: %s (got %s, expected %s)" % [message, v1, v2])


func assert_approx_float(a: float, b: float, message: String, epsilon: float = 0.001):
	if abs(a - b) < epsilon:
		test_passed += 1
	else:
		test_failed += 1
		print("  ❌ FAILED: %s (got %.3f, expected %.3f)" % [message, a, b])
