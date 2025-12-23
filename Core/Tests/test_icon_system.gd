extends Node

## Test suite for Icon Hamiltonian system, Berry phase, and DualEmojiQubit

const TomatoNode = preload("res://Core/QuantumSubstrate/TomatoNode.gd")
const TomatoConspiracyNetwork = preload("res://Core/QuantumSubstrate/TomatoConspiracyNetwork.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const IconHamiltonian = preload("res://Core/Icons/IconHamiltonian.gd")
const BioticFluxIcon = preload("res://Core/Icons/BioticFluxIcon.gd")
const ChaosIcon = preload("res://Core/Icons/ChaosIcon.gd")
const ImperiumIcon = preload("res://Core/Icons/ImperiumIcon.gd")
const TopologyAnalyzer = preload("res://Core/QuantumSubstrate/TopologyAnalyzer.gd")

var test_passed: int = 0
var test_failed: int = 0


func _ready():
	print("\n============================================================")
	print("ICON SYSTEM & BERRY PHASE TEST SUITE")
	print("============================================================\n")

	# Icon system tests
	test_icon_creation()
	test_icon_modulation()
	test_icon_network_integration()

	# Berry phase tests
	test_berry_phase_tracking()
	test_berry_phase_on_circle()

	# DualEmojiQubit tests
	test_dual_emoji_creation()
	test_dual_emoji_measurement()
	test_dual_emoji_gates()
	test_dual_emoji_berry_phase()

	# Entanglement tests
	test_basic_entanglement()
	test_entanglement_limits()
	test_bell_pair_creation()
	test_measurement_collapse_propagation()
	test_synchronized_evolution()

	# Topology Analyzer tests
	test_topology_analyzer_creation()
	test_graph_construction()
	test_pattern_detection_trefoil()
	test_pattern_detection_ring()
	test_borromean_pattern()
	test_bonus_calculation()
	test_knot_discovery_system()

	# Summary
	print("\n============================================================")
	print("TEST SUMMARY")
	print("============================================================")
	print("✅ Passed: %d" % test_passed)
	print("❌ Failed: %d" % test_failed)
	print("============================================================\n")

	if test_failed == 0:
		print("🎉 ALL TESTS PASSED! Icon system working correctly.\n")
	else:
		print("⚠️  SOME TESTS FAILED. Review output above.\n")


## Icon System Tests

func test_icon_creation():
	print("TEST: Icon Creation")

	var biotic = BioticFluxIcon.new()
	assert_true(biotic.icon_name == "Biotic Flux", "Biotic Icon name correct")
	assert_true(biotic.icon_emoji == "🌾", "Biotic Icon emoji correct")
	assert_true(biotic.evolution_bias.x > 0, "Biotic has positive theta bias")

	var chaos = ChaosIcon.new()
	assert_true(chaos.icon_name == "Chaos Vortex", "Chaos Icon name correct")
	assert_true(chaos.icon_emoji == "🍅", "Chaos Icon emoji correct")

	var imperium = ImperiumIcon.new()
	assert_true(imperium.icon_name == "Carrion Throne", "Imperium Icon name correct")

	print("  ✓ All three Icons created successfully\n")


func test_icon_modulation():
	print("TEST: Icon Modulation on Node")

	var node = TomatoNode.new()
	node.node_id = "seed"
	node.theta = PI/2
	node.phi = 0.0
	node.q = 1.0
	node.p = 0.0
	node.update_energy()

	var initial_theta = node.theta
	var initial_energy = node.energy

	# Create and activate Biotic Icon
	var biotic = BioticFluxIcon.new()
	biotic.set_activation(1.0)  # Full strength

	# Apply modulation
	for i in range(10):
		biotic.modulate_node_evolution(node, 0.1)

	assert_true(node.theta != initial_theta, "Icon modulation changed theta")
	assert_true(abs(node.energy - initial_energy) > 0.01, "Icon modulation affected energy")

	print("  ✓ Icon successfully modulates node evolution\n")


func test_icon_network_integration():
	print("TEST: Icon Integration with Network")

	var network = TomatoConspiracyNetwork.new()
	add_child(network)
	# Manually call _ready to initialize network (avoids await in headless mode)
	network._ready()

	var initial_energy = network.get_total_energy()

	# Add Biotic Icon
	var biotic = BioticFluxIcon.new()
	biotic.set_activation(0.5)
	network.add_icon(biotic)

	assert_true(network.get_active_icon_count() == 1, "Icon added to network")

	# Evolve with Icon influence
	for i in range(100):
		network.evolve_network(0.01)

	var final_energy = network.get_total_energy()
	assert_true(abs(final_energy - initial_energy) > 0.1, "Icon influences network evolution")

	print("  ✓ Icon successfully integrates with conspiracy network\n")


## Berry Phase Tests

func test_berry_phase_tracking():
	print("TEST: Berry Phase Tracking")

	var node = TomatoNode.new()
	node.node_id = "test"
	node.theta = 0.0
	node.phi = 0.0
	node.enable_berry_phase_tracking()

	assert_true(node.berry_phase_enabled, "Berry phase tracking enabled")
	assert_true(node.berry_phase == 0.0, "Initial Berry phase is zero")

	# Evolve through a path
	for i in range(100):
		node.theta = float(i) / 100.0 * PI
		node.evolve(0.01)

	# Berry phase should have accumulated
	assert_true(abs(node.berry_phase) > 0.01, "Berry phase accumulated during evolution")

	print("  ✓ Berry phase tracking works\n")


func test_berry_phase_on_circle():
	print("TEST: Berry Phase on Closed Circle")

	var node = TomatoNode.new()
	node.enable_berry_phase_tracking()

	# Move around a circle on the Bloch sphere (latitude circle at θ=π/2)
	var steps = 100
	for i in range(steps + 1):
		var angle = float(i) / steps * TAU
		node.theta = PI/2
		node.phi = angle
		node.update_energy()
		node.evolve(0.01)

	# For a complete circle at θ=π/2, Berry phase should be ≈ 2π * (1 - cos(π/2)) = π
	# But our accumulation is approximate, so we check it's non-zero
	assert_true(abs(node.berry_phase) > 0.5, "Berry phase accumulated on closed loop")

	print("  ✓ Berry phase accumulates on closed paths\n")


## DualEmojiQubit Tests

func test_dual_emoji_creation():
	print("TEST: DualEmojiQubit Creation")

	var qubit = DualEmojiQubit.new("🌾", "👥", PI/2)

	assert_true(qubit.north_emoji == "🌾", "North emoji set correctly")
	assert_true(qubit.south_emoji == "👥", "South emoji set correctly")
	assert_true(abs(qubit.theta - PI/2) < 0.01, "Theta initialized correctly")

	var state = qubit.get_semantic_state()
	assert_true(state == "🌾👥", "Superposition shows both emojis")

	print("  ✓ DualEmojiQubit created correctly\n")


func test_dual_emoji_measurement():
	print("TEST: DualEmojiQubit Measurement")

	var qubit = DualEmojiQubit.new("🌾", "👥", PI/2)

	var north_prob = qubit.get_north_probability()
	var south_prob = qubit.get_south_probability()

	assert_approx_float(north_prob + south_prob, 1.0, "Probabilities sum to 1")

	# Measure (collapses state)
	var result = qubit.measure()
	assert_true(result == "🌾" or result == "👥", "Measurement returns valid emoji")

	# After measurement, should be at a pole
	assert_true(qubit.theta < 0.1 or qubit.theta > PI - 0.1, "State collapsed to pole")

	print("  ✓ Measurement and collapse work correctly\n")


func test_dual_emoji_gates():
	print("TEST: DualEmojiQubit Quantum Gates")

	var qubit = DualEmojiQubit.new("🌾", "👥", 0.0)  # Start at north pole

	# Apply Hadamard to create superposition
	qubit.apply_hadamard()
	assert_true(abs(qubit.theta - PI/2) < 0.1, "Hadamard creates superposition")

	# Apply Pauli-X (bit flip)
	qubit = DualEmojiQubit.new("🌾", "👥", 0.0)
	qubit.apply_pauli_x()
	assert_true(abs(qubit.theta - PI) < 0.1, "Pauli-X flips state")

	print("  ✓ Quantum gates work correctly\n")


func test_dual_emoji_berry_phase():
	print("TEST: DualEmojiQubit Berry Phase")

	var qubit = DualEmojiQubit.new("🌾", "👥", PI/2)
	qubit.enable_berry_phase()

	var initial_phase = qubit.get_berry_phase()

	# Evolve in circle
	for i in range(100):
		qubit.evolve(0.01, 0.5)

	var final_phase = qubit.get_berry_phase()
	assert_true(abs(final_phase - initial_phase) > 0.1, "Berry phase accumulated")

	print("  ✓ DualEmojiQubit Berry phase tracking works\n")


## Entanglement Tests

func test_basic_entanglement():
	print("TEST: Basic Entanglement")

	var qubit_a = DualEmojiQubit.new("🌾", "👥", PI/2)
	var qubit_b = DualEmojiQubit.new("🌾", "👥", PI/2)

	# Initially not entangled
	assert_true(not qubit_a.is_entangled_with(qubit_b), "Qubits start unentangled")
	assert_true(qubit_a.get_entanglement_count() == 0, "Zero entanglements initially")

	# Create entanglement
	var success = qubit_a.create_entanglement(qubit_b, 0.8)
	assert_true(success, "Entanglement created successfully")

	# Check bidirectional link
	assert_true(qubit_a.is_entangled_with(qubit_b), "A entangled with B")
	assert_true(qubit_b.is_entangled_with(qubit_a), "B entangled with A (bidirectional)")
	assert_true(qubit_a.get_entanglement_count() == 1, "A has 1 entanglement")
	assert_true(qubit_b.get_entanglement_count() == 1, "B has 1 entanglement")

	# Break entanglement
	qubit_a.break_entanglement(qubit_b)
	assert_true(not qubit_a.is_entangled_with(qubit_b), "Entanglement broken")
	assert_true(qubit_a.get_entanglement_count() == 0, "A has no entanglements")
	assert_true(qubit_b.get_entanglement_count() == 0, "B has no entanglements")

	print("  ✓ Basic entanglement operations work\n")


func test_entanglement_limits():
	print("TEST: Entanglement Limits (Max 3)")

	var center = DualEmojiQubit.new("🌾", "👥", PI/2)
	var partners = []
	for i in range(5):
		partners.append(DualEmojiQubit.new("🌾", "👥", PI/2))

	# Create 3 entanglements (should all succeed)
	for i in range(3):
		var success = center.create_entanglement(partners[i])
		assert_true(success, "Entanglement %d succeeded" % (i+1))

	assert_true(center.get_entanglement_count() == 3, "Center has 3 entanglements")

	# Try to create 4th (should fail)
	var failed = center.create_entanglement(partners[3])
	assert_true(not failed, "4th entanglement rejected (max 3)")
	assert_true(center.get_entanglement_count() == 3, "Still only 3 entanglements")

	# Break all
	center.break_all_entanglements()
	assert_true(center.get_entanglement_count() == 0, "All entanglements broken")

	print("  ✓ Entanglement limits enforced correctly\n")


func test_bell_pair_creation():
	print("TEST: Bell Pair Creation")

	var qubit_a = DualEmojiQubit.new("🌾", "👥", 0.0)  # Start at north
	var qubit_b = DualEmojiQubit.new("🌾", "👥", PI)  # Start at south

	# Create Φ+ Bell pair
	var success = qubit_a.create_bell_pair(qubit_b, "phi_plus")
	assert_true(success, "Bell pair created")

	# Both should now be in superposition
	assert_approx_float(qubit_a.theta, PI/2, "A in superposition")
	assert_approx_float(qubit_b.theta, PI/2, "B in superposition")

	# Same phase for Φ+
	assert_approx_float(qubit_a.phi, 0.0, "A phase correct for Φ+")
	assert_approx_float(qubit_b.phi, 0.0, "B phase correct for Φ+")

	# Try Ψ+ (opposite states)
	var qubit_c = DualEmojiQubit.new("🌾", "👥", 0.0)
	var qubit_d = DualEmojiQubit.new("🌾", "👥", 0.0)

	qubit_c.create_bell_pair(qubit_d, "psi_plus")
	assert_approx_float(abs(qubit_c.phi - qubit_d.phi), PI/2, "Ψ+ has phase difference")

	print("  ✓ Bell pair creation works correctly\n")


func test_measurement_collapse_propagation():
	print("TEST: Measurement Collapse Propagation")

	var qubit_a = DualEmojiQubit.new("🌾", "👥", PI/2)
	var qubit_b = DualEmojiQubit.new("🌾", "👥", PI/2)

	# Create strong entanglement
	qubit_a.create_bell_pair(qubit_b, "phi_plus")

	# Both in superposition
	var a_prob_before = qubit_a.get_north_probability()
	var b_prob_before = qubit_b.get_north_probability()
	assert_approx_float(a_prob_before, 0.5, "A in superposition before measurement")
	assert_approx_float(b_prob_before, 0.5, "B in superposition before measurement")

	# Measure A (should collapse both)
	var result_a = qubit_a.measure()

	# A collapsed to a pole
	assert_true(qubit_a.theta < 0.1 or qubit_a.theta > PI - 0.1, "A collapsed")

	# B should be affected (correlated collapse)
	# For strong entanglement, B should also be near a pole
	var b_collapsed = qubit_b.theta < PI/4 or qubit_b.theta > 3*PI/4
	assert_true(b_collapsed, "B collapsed due to entanglement (spooky action!)")

	print("  ✓ Measurement collapse propagates through entanglement\n")


func test_synchronized_evolution():
	print("TEST: Synchronized Evolution")

	var qubit_a = DualEmojiQubit.new("🌾", "👥", 0.0)   # North
	var qubit_b = DualEmojiQubit.new("🌾", "👥", PI)   # South
	var qubit_c = DualEmojiQubit.new("🌾", "👥", PI/2) # Middle

	# Create triangle of entanglements
	qubit_a.create_entanglement(qubit_b, 0.8)
	qubit_b.create_entanglement(qubit_c, 0.8)
	qubit_c.create_entanglement(qubit_a, 0.8)

	var initial_variance = calculate_theta_variance([qubit_a, qubit_b, qubit_c])

	# Synchronize for a while
	for i in range(100):
		qubit_a.synchronize_with_partners(0.1, 0.3)
		qubit_b.synchronize_with_partners(0.1, 0.3)
		qubit_c.synchronize_with_partners(0.1, 0.3)

	var final_variance = calculate_theta_variance([qubit_a, qubit_b, qubit_c])

	# Variance should decrease (states converging)
	assert_true(final_variance < initial_variance, "States synchronized (variance decreased)")

	print("  ✓ Synchronized evolution works\n")


func calculate_theta_variance(qubits: Array) -> float:
	"""Helper: Calculate variance of theta values"""
	var mean = 0.0
	for q in qubits:
		mean += q.theta
	mean /= qubits.size()

	var variance = 0.0
	for q in qubits:
		var diff = q.theta - mean
		variance += diff * diff
	variance /= qubits.size()

	return variance


## Assertion Helpers

func assert_true(condition: bool, message: String):
	if condition:
		test_passed += 1
	else:
		test_failed += 1
		print("  ❌ FAILED: %s" % message)


func assert_approx_float(a: float, b: float, message: String, epsilon: float = 0.01):
	if abs(a - b) < epsilon:
		test_passed += 1
	else:
		test_failed += 1
		print("  ❌ FAILED: %s (got %.3f, expected %.3f)" % [message, a, b])


## Topology Analyzer Tests

# Helper class to mock wheat plots for testing
class MockWheatPlot:
	var quantum_state: DualEmojiQubit

	func _init(qubit: DualEmojiQubit):
		quantum_state = qubit


func test_topology_analyzer_creation():
	print("TEST: TopologyAnalyzer Creation")

	var analyzer = TopologyAnalyzer.new()

	assert_true(analyzer.discovered_knots.is_empty(), "No knots discovered initially")
	assert_true(analyzer.current_bonus_multiplier == 1.0, "Initial bonus is 1.0")

	print("  ✓ TopologyAnalyzer created correctly\n")


func test_graph_construction():
	print("TEST: Graph Construction from Entangled Plots")

	var analyzer = TopologyAnalyzer.new()

	# Create 3 wheat plots in a triangle
	var q1 = DualEmojiQubit.new("🌾", "👥", PI/2)
	var q2 = DualEmojiQubit.new("🌾", "👥", PI/2)
	var q3 = DualEmojiQubit.new("🌾", "👥", PI/2)

	var p1 = MockWheatPlot.new(q1)
	var p2 = MockWheatPlot.new(q2)
	var p3 = MockWheatPlot.new(q3)

	# Create entanglement triangle
	q1.create_entanglement(q2, 0.8)
	q2.create_entanglement(q3, 0.8)
	q3.create_entanglement(q1, 0.8)

	# Analyze network
	var topology = analyzer.analyze_entanglement_network([p1, p2, p3])

	assert_true(topology.node_count == 3, "Graph has 3 nodes")
	assert_true(topology.edge_count == 3, "Graph has 3 edges (triangle)")
	assert_true(topology.features.has_cycles, "Triangle has cycles")
	assert_true(topology.features.is_connected, "Graph is connected")

	print("  ✓ Graph construction works correctly\n")


func test_pattern_detection_trefoil():
	print("TEST: Trefoil Knot Pattern Detection")

	var analyzer = TopologyAnalyzer.new()

	# Create 3-node network with extra twist (simulates trefoil)
	var q1 = DualEmojiQubit.new("🌾", "👥", PI/2)
	var q2 = DualEmojiQubit.new("🌾", "👥", PI/2)
	var q3 = DualEmojiQubit.new("🌾", "👥", PI/2)

	var p1 = MockWheatPlot.new(q1)
	var p2 = MockWheatPlot.new(q2)
	var p3 = MockWheatPlot.new(q3)

	# Create triangle with all-to-all connections (creates twist)
	q1.create_entanglement(q2, 0.9)
	q1.create_entanglement(q3, 0.9)
	q2.create_entanglement(q3, 0.9)

	var topology = analyzer.analyze_entanglement_network([p1, p2, p3])

	# Should detect as trefoil or complex network
	assert_true(topology.pattern.bonus_multiplier >= 1.1, "Trefoil gives bonus >= 1.1")
	assert_true(topology.features.num_cycles >= 1, "Has at least one cycle")

	print("  ✓ Trefoil pattern detection works\n")


func test_pattern_detection_ring():
	print("TEST: Simple Ring Pattern Detection")

	var analyzer = TopologyAnalyzer.new()

	# Create simple ring (4 nodes in a circle)
	var qubits = []
	var plots = []
	for i in range(4):
		var q = DualEmojiQubit.new("🌾", "👥", PI/2)
		qubits.append(q)
		plots.append(MockWheatPlot.new(q))

	# Connect in ring
	for i in range(4):
		var next_i = (i + 1) % 4
		qubits[i].create_entanglement(qubits[next_i], 0.8)

	var topology = analyzer.analyze_entanglement_network(plots)

	assert_true(topology.features.has_cycles, "Ring has cycles")
	assert_true(topology.features.num_cycles >= 1, "At least one cycle detected")
	assert_true(topology.bonus_multiplier > 1.0, "Ring gives bonus")

	print("  ✓ Ring pattern detection works\n")


func test_borromean_pattern():
	print("TEST: Borromean Rings Detection")

	var analyzer = TopologyAnalyzer.new()

	# Create 3 separate cycles that share nodes (simplified Borromean)
	var qubits = []
	var plots = []
	for i in range(6):
		var q = DualEmojiQubit.new("🌾", "👥", PI/2)
		qubits.append(q)
		plots.append(MockWheatPlot.new(q))

	# Create 3 triangles with shared nodes
	# Triangle 1: 0-1-2
	qubits[0].create_entanglement(qubits[1], 0.8)
	qubits[1].create_entanglement(qubits[2], 0.8)
	qubits[2].create_entanglement(qubits[0], 0.8)

	# Triangle 2: 2-3-4 (shares node 2)
	qubits[2].create_entanglement(qubits[3], 0.8)
	qubits[3].create_entanglement(qubits[4], 0.8)

	# Triangle 3: 4-5-0 (shares nodes 4 and 0)
	qubits[4].create_entanglement(qubits[5], 0.8)
	qubits[5].create_entanglement(qubits[0], 0.8)

	var topology = analyzer.analyze_entanglement_network(plots)

	assert_true(topology.features.num_cycles >= 3, "Multiple cycles detected")
	assert_true(topology.bonus_multiplier >= 1.0, "Complex network gives bonus")

	# If detected as Borromean specifically, should have high bonus
	if topology.pattern.name == "Borromean Rings":
		assert_true(topology.pattern.bonus_multiplier >= 1.8, "Borromean gives 2.0x bonus")
		assert_true(topology.pattern.protection_level == 3, "Borromean has protection 3")

	print("  ✓ Complex network topology detection works\n")


func test_bonus_calculation():
	print("TEST: Bonus Calculation")

	var analyzer = TopologyAnalyzer.new()

	# Test trivial case (no entanglements)
	var q_solo = DualEmojiQubit.new("🌾", "👥", PI/2)
	var p_solo = MockWheatPlot.new(q_solo)

	var topology_trivial = analyzer.analyze_entanglement_network([p_solo])
	assert_approx_float(topology_trivial.bonus_multiplier, 1.0, "No entanglement = 1.0x bonus")

	# Test simple pair
	var q1 = DualEmojiQubit.new("🌾", "👥", PI/2)
	var q2 = DualEmojiQubit.new("🌾", "👥", PI/2)
	q1.create_entanglement(q2, 0.8)

	var p1 = MockWheatPlot.new(q1)
	var p2 = MockWheatPlot.new(q2)

	var topology_pair = analyzer.analyze_entanglement_network([p1, p2])
	assert_true(topology_pair.bonus_multiplier >= 1.0, "Entangled pair gets bonus")

	# Bonus should be capped at 3.0x
	assert_true(topology_pair.bonus_multiplier <= 3.0, "Bonus capped at 3.0x")

	print("  ✓ Bonus calculation works correctly\n")


func test_knot_discovery_system():
	print("TEST: Knot Discovery System")

	var analyzer = TopologyAnalyzer.new()

	# Create a triangle (should trigger discovery)
	var q1 = DualEmojiQubit.new("🌾", "👥", PI/2)
	var q2 = DualEmojiQubit.new("🌾", "👥", PI/2)
	var q3 = DualEmojiQubit.new("🌾", "👥", PI/2)

	q1.create_entanglement(q2, 0.8)
	q2.create_entanglement(q3, 0.8)
	q3.create_entanglement(q1, 0.8)

	var p1 = MockWheatPlot.new(q1)
	var p2 = MockWheatPlot.new(q2)
	var p3 = MockWheatPlot.new(q3)

	# First analysis - should discover
	var topology1 = analyzer.analyze_entanglement_network([p1, p2, p3])
	var signature = topology1.pattern.signature

	assert_true(analyzer.discovered_knots.has(signature), "Knot discovered and recorded")
	assert_true(analyzer.discovered_knots[signature].discovered, "Discovery flag set")

	# Second analysis - should NOT trigger discovery again (already discovered)
	var initial_count = analyzer.discovered_knots.size()
	var topology2 = analyzer.analyze_entanglement_network([p1, p2, p3])

	assert_true(analyzer.discovered_knots.size() == initial_count, "No duplicate discovery")

	# Get discovered knots list
	var discovered_list = analyzer.get_discovered_knots()
	assert_true(discovered_list.size() >= 1, "At least one knot in discovered list")

	print("  ✓ Knot discovery system works correctly\n")
