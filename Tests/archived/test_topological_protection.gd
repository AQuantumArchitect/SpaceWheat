extends SceneTree

## Topological Protection Tests
## Tests active quantum state shielding from knot invariants

func _initialize():
	print("\n" + "=".repeat(80))
	print("  TOPOLOGICAL PROTECTION - COMPREHENSIVE TESTS")
	print("=".repeat(80) + "\n")

	# Load scripts manually
	var TopologyAnalyzerScript = load("res://Core/QuantumSubstrate/TopologyAnalyzer.gd")
	var TopologicalProtectorScript = load("res://Core/QuantumSubstrate/TopologicalProtector.gd")
	var DualEmojiQubitScript = load("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
	var EntangledPairScript = load("res://Core/QuantumSubstrate/EntangledPair.gd")

	# Mock WheatPlot class for testing
	var MockPlot = _create_mock_plot_class(DualEmojiQubitScript, EntangledPairScript)

	# Test 1: Protection Strength Calculation
	print("TEST 1: Protection Strength Calculation")
	print("─".repeat(40))
	var protector = TopologicalProtectorScript.new()
	protector._ready()

	# Create simple chain (no cycles)
	var chain = _create_chain_network(3, MockPlot, DualEmojiQubitScript)
	var protection_chain = protector.get_protection_strength(chain)
	print("  Chain (3 plots): %.0f%% protection" % (protection_chain * 100))

	# Create triangle (1 cycle)
	var triangle = _create_triangle_network(MockPlot, DualEmojiQubitScript)
	var protection_triangle = protector.get_protection_strength(triangle)
	print("  Triangle (1 cycle): %.0f%% protection" % (protection_triangle * 100))

	# Create complex network (multiple cycles)
	var complex_net = _create_complex_network(MockPlot, DualEmojiQubitScript)
	var protection_complex = protector.get_protection_strength(complex_net)
	print("  Complex (4+ cycles): %.0f%% protection" % (protection_complex * 100))

	# Verify ordering: complex > triangle > chain
	if protection_complex > protection_triangle and protection_triangle > protection_chain:
		print("  ✅ Protection increases with topological complexity\n")
	else:
		print("  ❌ Protection ordering incorrect\n")
		quit(1)

	# Test 2: Active Shielding (T₁/T₂ Extension)
	print("TEST 2: Active Shielding (T₁/T₂ Extension)")
	print("─".repeat(40))

	# Create entangled plot
	var plot_a = MockPlot.new("plot_a")
	var plot_b = MockPlot.new("plot_b")
	var qubit_a = DualEmojiQubitScript.new("🌾", "👥")
	var qubit_b = DualEmojiQubitScript.new("🌾", "👥")

	plot_a.quantum_state = qubit_a
	plot_b.quantum_state = qubit_b

	# Entangle them
	var pair = EntangledPairScript.new()
	pair.qubit_a_id = "plot_a"
	pair.qubit_b_id = "plot_b"
	pair.create_bell_phi_plus()  # Maximally entangled state

	qubit_a.entangled_pair = pair
	qubit_b.entangled_pair = pair

	# Set initial coherence times
	qubit_a.coherence_time_T1 = 10.0
	qubit_a.coherence_time_T2 = 5.0

	print("  Initial T₁: %.1f, T₂: %.1f" % [qubit_a.coherence_time_T1, qubit_a.coherence_time_T2])

	# Create triangle network for protection
	var network_for_protection = _create_triangle_network(MockPlot, DualEmojiQubitScript)
	network_for_protection[0].quantum_state = qubit_a  # Replace with our test qubit

	# Apply shielding
	protector.apply_topological_shielding(network_for_protection[0], 0.1, network_for_protection)

	print("  After shielding T₁: %.1f, T₂: %.1f" % [qubit_a.coherence_time_T1, qubit_a.coherence_time_T2])

	# Should be extended (T₁ > 10.0, T₂ > 5.0)
	if qubit_a.coherence_time_T1 > 15.0 and qubit_a.coherence_time_T2 > 7.0:
		print("  ✅ T₁/T₂ times extended by topological protection\n")
	else:
		print("  ❌ T₁/T₂ not extended properly\n")
		quit(1)

	# Test 3: Topology Breaking Detection
	print("TEST 3: Topology Breaking Detection")
	print("─".repeat(40))

	var triangle_network = _create_triangle_network(MockPlot, DualEmojiQubitScript)
	var plot_to_remove = triangle_network[0]

	var break_info = protector.detect_topology_breaking_event(plot_to_remove, triangle_network)

	print("  Jones before: %.2f" % break_info.jones_before)
	print("  Jones after: %.2f" % break_info.jones_after)
	print("  Delta: %.2f" % break_info.jones_delta)
	print("  Breaks topology: %s" % ("Yes" if break_info.breaks_topology else "No"))
	print("  Protection lost: %.0f%%" % (break_info.protection_lost * 100))

	# Removing vertex from triangle should reduce Jones polynomial
	if break_info.jones_delta > 0.1:
		print("  ✅ Topology breaking detected\n")
	else:
		print("  ❌ Topology breaking not detected\n")
		quit(1)

	# Test 4: Error Syndrome Detection
	print("TEST 4: Error Syndrome Detection")
	print("─".repeat(40))

	# Create network with weak entanglements
	var weak_network = _create_weak_entanglement_network(MockPlot, DualEmojiQubitScript)

	var syndrome = protector.get_error_syndrome(weak_network)

	print("  Weak entanglements detected: %d" % syndrome.size())

	for edge_id in syndrome.keys():
		var error = syndrome[edge_id]
		print("    - %s: strength=%.2f (should be ≥ %.2f)" %
		      [error.type, error.strength, error.threshold])

	if syndrome.size() > 0:
		print("  ✅ Error syndromes detected\n")
	else:
		print("  ❌ No error syndromes detected (should find weak bonds)\n")
		quit(1)

	# Test 5: Local Network Extraction
	print("TEST 5: Local Network Extraction (BFS)")
	print("─".repeat(40))

	# Create two disconnected components
	var component_a = _create_triangle_network(MockPlot, DualEmojiQubitScript)
	var component_b = _create_chain_network(2, MockPlot, DualEmojiQubitScript)

	# Ensure different IDs
	for i in range(component_b.size()):
		component_b[i].plot_id = "B_%d" % i

	var all_plots = component_a + component_b

	# Extract network for plot in component A
	var local_network = protector._get_local_entangled_network_from_list(component_a[0], all_plots)

	print("  Total plots: %d" % all_plots.size())
	print("  Component A size: %d" % component_a.size())
	print("  Component B size: %d" % component_b.size())
	print("  Local network extracted: %d" % local_network.size())

	# Should only get component A (3 plots, not 5 total)
	if local_network.size() == component_a.size():
		print("  ✅ BFS correctly extracts connected component\n")
	else:
		print("  ❌ BFS extracted wrong component size\n")
		quit(1)

	# Test 6: Protection Visual Effects
	print("TEST 6: Protection Visual Effects")
	print("─".repeat(40))

	# Apply protection and check visual data
	var protected_plot = triangle_network[0]
	protector.apply_topological_shielding(protected_plot, 0.1, triangle_network)

	var visual = protector.get_protection_visual_for_plot(protected_plot.plot_id)

	print("  Has protection: %s" % ("Yes" if visual.has_protection else "No"))
	print("  Strength: %.0f%%" % (visual.strength * 100))
	print("  Color: %s" % visual.color)
	print("  Pulse rate: %.2f Hz" % visual.pulse_rate)

	if visual.has_protection and visual.strength > 0.1:
		print("  ✅ Visual effects configured\n")
	else:
		print("  ❌ Visual effects not working\n")
		quit(1)

	# Test 7: Statistics
	print("TEST 7: Protection Statistics")
	print("─".repeat(40))

	var stats = protector.get_protection_statistics()

	print("  Total protection events: %d" % stats.total_events)
	print("  Average protection: %.0f%%" % (stats.average_protection * 100))
	print("  Protected plots: %d" % stats.protected_plot_count)
	print("  Max protection: %.0f%%" % (stats.max_protection * 100))

	if stats.total_events > 0:
		print("  ✅ Statistics tracking working\n")
	else:
		print("  ❌ Statistics not tracked\n")
		quit(1)

	print("=".repeat(80))
	print("  ALL TOPOLOGICAL PROTECTION TESTS PASSED ✅")
	print("=".repeat(80) + "\n")

	print("\n📊 Summary:")
	print("  - Protection scales with topological complexity")
	print("  - T₁/T₂ times extended by Jones polynomial")
	print("  - Topology breaking detection functional")
	print("  - Error syndrome detection working")
	print("  - BFS network extraction correct")
	print("  - Visual effects configured")
	print("  - Statistics tracking active")
	print("\n🛡️ Topological Protection is production ready!\n")

	quit()


## Helper: Create Mock WheatPlot Class

func _create_mock_plot_class(DualEmojiQubitScript, EntangledPairScript):
	"""Create mock WheatPlot for testing"""

	var MockPlotClass = RefCounted.new()

	# Add script that defines the class
	var script = GDScript.new()
	script.source_code = """
extends RefCounted

var plot_id: String = ""
var quantum_state = null
var entangled_plots: Dictionary = {}

func _init(id: String = ""):
	plot_id = id if id != "" else "plot_%d" % randi()
"""
	script.reload()

	return script


## Helper: Create Chain Network (Linear)

func _create_chain_network(length: int, MockPlotClass, QubitScript) -> Array:
	"""Create linear chain of entangled plots"""
	var chain = []

	for i in range(length):
		var plot = MockPlotClass.new("chain_%d" % i)
		plot.quantum_state = QubitScript.new("🌾", "👥")
		chain.append(plot)

	# Entangle linearly: 0-1-2
	for i in range(length - 1):
		chain[i].entangled_plots[chain[i+1].plot_id] = 0.8
		chain[i+1].entangled_plots[chain[i].plot_id] = 0.8

	return chain


## Helper: Create Triangle Network (1 cycle)

func _create_triangle_network(MockPlotClass, QubitScript) -> Array:
	"""Create triangle: 3 plots with cycle"""
	var triangle = []

	for i in range(3):
		var plot = MockPlotClass.new("tri_%d" % i)
		plot.quantum_state = QubitScript.new("🌾", "👥")
		triangle.append(plot)

	# Entangle in triangle: 0-1-2-0
	triangle[0].entangled_plots[triangle[1].plot_id] = 0.9
	triangle[1].entangled_plots[triangle[0].plot_id] = 0.9

	triangle[1].entangled_plots[triangle[2].plot_id] = 0.9
	triangle[2].entangled_plots[triangle[1].plot_id] = 0.9

	triangle[2].entangled_plots[triangle[0].plot_id] = 0.9
	triangle[0].entangled_plots[triangle[2].plot_id] = 0.9

	return triangle


## Helper: Create Complex Network (Multiple Cycles)

func _create_complex_network(MockPlotClass, QubitScript) -> Array:
	"""Create complex network with multiple cycles"""
	var network = []

	# Create 6 plots
	for i in range(6):
		var plot = MockPlotClass.new("complex_%d" % i)
		plot.quantum_state = QubitScript.new("🌾", "👥")
		network.append(plot)

	# Create multiple triangles and squares
	# Triangle 1: 0-1-2
	_add_edge(network, 0, 1)
	_add_edge(network, 1, 2)
	_add_edge(network, 2, 0)

	# Triangle 2: 3-4-5
	_add_edge(network, 3, 4)
	_add_edge(network, 4, 5)
	_add_edge(network, 5, 3)

	# Connect triangles
	_add_edge(network, 1, 4)

	return network


func _add_edge(network: Array, i: int, j: int):
	"""Add bidirectional edge between plots"""
	network[i].entangled_plots[network[j].plot_id] = 0.85
	network[j].entangled_plots[network[i].plot_id] = 0.85


## Helper: Create Weak Entanglement Network

func _create_weak_entanglement_network(MockPlotClass, QubitScript) -> Array:
	"""Create network with intentionally weak entanglements"""
	var network = []

	for i in range(3):
		var plot = MockPlotClass.new("weak_%d" % i)
		plot.quantum_state = QubitScript.new("🌾", "👥")
		network.append(plot)

	# Weak entanglements (< 0.5 threshold)
	network[0].entangled_plots[network[1].plot_id] = 0.3  # Weak!
	network[1].entangled_plots[network[0].plot_id] = 0.3

	network[1].entangled_plots[network[2].plot_id] = 0.1  # Very weak!
	network[2].entangled_plots[network[1].plot_id] = 0.1

	return network
