extends SceneTree

## Dreaming Hive Biome Test Suite
## Tests all 5-qubit semantic mechanics and cross-biome integration

const DreamingHiveBiome = preload("res://Core/Biomes/DreamingHiveBiome.gd")
const WheatPlot = preload("res://Core/GameMechanics/WheatPlot.gd")

var test_count = 0
var passed_count = 0


func _initialize():
	print("\n" + "=".repeat(80))
	print("  DREAMING HIVE BIOME TEST SUITE")
	print("=".repeat(80) + "\n")

	# Run all tests
	test_1_initialization()
	test_2_qubit_architecture()
	test_3_hamiltonian_evolution()
	test_4_phase_detection()
	test_5_berry_phase_accumulation()
	test_6_myth_injection()
	test_7_innovation_harvest()
	test_8_memory_archaeology()
	test_9_cross_biome_entanglement()
	test_10_player_interactions()

	# Summary
	print("\n" + "=".repeat(80))
	print("  TEST SUMMARY: %d / %d PASSED" % [passed_count, test_count])
	print("=".repeat(80) + "\n")

	if passed_count == test_count:
		print("✅ ALL TESTS PASSED\n")
		quit(0)
	else:
		print("❌ SOME TESTS FAILED\n")
		quit(1)


func test_1_initialization():
	print("TEST 1: Hive Initialization")
	print("─".repeat(40))

	var hive = DreamingHiveBiome.new()

	assert_true(hive.qubits.size() == 5, "Should have 5 qubits")
	assert_true(hive.system_time == 0.0, "System time starts at 0")
	assert_true(not hive.is_active, "Starts inactive")

	# Check each qubit
	var expected_north = ["🧠", "🧬", "🎭", "🎨", "👥"]
	var expected_south = ["🫧", "🪱", "🪞", "🤖", "🕸️"]

	for i in range(5):
		var qb = hive.qubits[i]
		assert_true(qb.north_emoji == expected_north[i], "Qubit %d north emoji correct" % i)
		assert_true(qb.south_emoji == expected_south[i], "Qubit %d south emoji correct" % i)
		assert_true(qb.berry_phase_enabled, "Qubit %d has Berry phase enabled" % i)

	print()


func test_2_qubit_architecture():
	print("TEST 2: 5D Semantic Space Architecture")
	print("─".repeat(40))

	var hive = DreamingHiveBiome.new()

	# Verify semantic roles
	print("Qubit 0 (Memory/Imagination): %s ↔ %s" % [hive.qubits[0].north_emoji, hive.qubits[0].south_emoji])
	print("Qubit 1 (Genome/Mutation): %s ↔ %s" % [hive.qubits[1].north_emoji, hive.qubits[1].south_emoji])
	print("Qubit 2 (Persona/Shadow): %s ↔ %s" % [hive.qubits[2].north_emoji, hive.qubits[2].south_emoji])
	print("Qubit 3 (Innovation/Automation): %s ↔ %s" % [hive.qubits[3].north_emoji, hive.qubits[3].south_emoji])
	print("Qubit 4 (Population/Network): %s ↔ %s" % [hive.qubits[4].north_emoji, hive.qubits[4].south_emoji])

	# Verify initial theta values match design
	assert_true(abs(hive.qubits[0].theta - PI * 0.7 / 2.0) < 0.01, "Memory qubit theta correct")
	assert_true(abs(hive.qubits[1].theta - PI / 2.0) < 0.01, "Genome qubit theta correct")
	assert_true(abs(hive.qubits[2].theta - PI * 0.8 / 2.0) < 0.01, "Persona qubit theta correct")
	assert_true(abs(hive.qubits[3].theta - PI * 0.3 / 2.0) < 0.01, "Innovation qubit theta correct")
	assert_true(abs(hive.qubits[4].theta - PI * 0.6 / 2.0) < 0.01, "Population qubit theta correct")

	print()


func test_3_hamiltonian_evolution():
	print("TEST 3: Myth Engine Hamiltonian Evolution")
	print("─".repeat(40))

	var hive = DreamingHiveBiome.new()
	hive.activate()

	# Record initial states
	var initial_theta = []
	for qb in hive.qubits:
		initial_theta.append(qb.theta)

	print("Initial states:")
	for i in range(5):
		print("  Qubit %d: θ=%.3f" % [i, initial_theta[i]])

	# Evolve for 5 seconds
	for i in range(50):
		hive._process(0.1)

	print("\nAfter 5s evolution:")
	var changed_count = 0
	for i in range(5):
		var delta = abs(hive.qubits[i].theta - initial_theta[i])
		print("  Qubit %d: θ=%.3f (Δ=%.3f)" % [i, hive.qubits[i].theta, delta])
		if delta > 0.01:
			changed_count += 1

	assert_true(changed_count >= 3, "At least 3 qubits should evolve")
	assert_true(hive.system_time > 4.9, "System time should advance")

	print()


func test_4_phase_detection():
	print("TEST 4: Phase Detection & Cycling")
	print("─".repeat(40))

	var hive = DreamingHiveBiome.new()
	hive.activate()

	var phases_seen = {}

	# Run for 30 seconds, tracking phases
	for i in range(300):
		hive._process(0.1)

		var phase = hive.get_current_phase()
		phases_seen[phase] = true

		if i % 100 == 0:
			print("t=%.1fs: %s" % [hive.system_time, phase])

	print("\nPhases observed: %d" % phases_seen.size())
	for phase in phases_seen:
		print("  - %s" % phase)

	# Should see at least 2 different phases over 30s
	assert_true(phases_seen.size() >= 2, "Should cycle through multiple phases")

	print()


func test_5_berry_phase_accumulation():
	print("TEST 5: Berry Phase Accumulation (Institutional Memory)")
	print("─".repeat(40))

	var hive = DreamingHiveBiome.new()
	hive.activate()

	var initial_berry = []
	for qb in hive.qubits:
		initial_berry.append(qb.get_berry_phase_abs())

	print("Initial Berry phases: %s" % str(initial_berry))

	# Evolve for 10 seconds
	for i in range(100):
		hive._process(0.1)

	print("\nAfter 10s:")
	var total_accumulated = 0.0
	for i in range(5):
		var berry = hive.qubits[i].get_berry_phase_abs()
		var delta = berry - initial_berry[i]
		print("  Qubit %d: γ=%.3f (Δ=%.3f)" % [i, berry, delta])
		total_accumulated += delta

	assert_true(total_accumulated > 0.1, "Berry phase should accumulate")
	assert_true(hive.get_total_berry_phase() > 0.0, "Total Berry phase should be positive")

	print("Total cultural age: %.3f" % hive.get_cultural_age())

	print()


func test_6_myth_injection():
	print("TEST 6: Myth Injection (Chaos Engine)")
	print("─".repeat(40))

	var hive = DreamingHiveBiome.new()
	var plot = WheatPlot.new()
	plot.plant()

	var initial_theta = plot.quantum_state.theta
	var initial_phi = plot.quantum_state.phi

	print("Plot initial: θ=%.3f φ=%.3f" % [initial_theta, initial_phi])

	# Test "rebirth" myth
	hive.inject_myth(plot, "rebirth")
	assert_true(abs(plot.quantum_state.theta - PI/2) < 0.01, "Rebirth sets to equator")
	print("After 'rebirth': θ=%.3f (should be ~1.571)" % plot.quantum_state.theta)

	# Replant and test "shadow" myth
	plot.plant()
	initial_theta = plot.quantum_state.theta
	hive.inject_myth(plot, "shadow")
	print("After 'shadow': θ=%.3f (phase flipped)" % plot.quantum_state.theta)

	# Test "synthesis" myth
	plot.plant()
	hive.inject_myth(plot, "synthesis")
	print("After 'synthesis': θ=%.3f (blended with Hive)" % plot.quantum_state.theta)

	print()


func test_7_innovation_harvest():
	print("TEST 7: Innovation Harvest")
	print("─".repeat(40))

	var hive = DreamingHiveBiome.new()
	hive.activate()

	# Boost innovation qubit
	hive.qubits[3].theta = 0.3  # High innovation (🎨)

	# Accumulate some Berry phase
	for i in range(100):
		hive._process(0.1)

	var harvest = hive.harvest_innovation()

	print("Innovation level: %.2f" % harvest.innovation_level)
	print("Stability: %.2f" % harvest.stability)
	print("Technologies: %s" % str(harvest.technologies))
	print("Cost: %d wheat" % harvest.cost_in_wheat)

	assert_true(harvest.innovation_level >= 0.0, "Innovation level should be valid")
	assert_true(harvest.cost_in_wheat > 0, "Should have a wheat cost")

	print()


func test_8_memory_archaeology():
	print("TEST 8: Memory Archaeology")
	print("─".repeat(40))

	var hive = DreamingHiveBiome.new()
	hive.activate()

	# Evolve for a while
	for i in range(200):
		hive._process(0.1)

	var archaeology = hive.analyze_memory_archaeology()

	print("Memory depth: %.3f" % archaeology.memory_depth)
	print("Genetic stability: %.3f" % archaeology.genetic_stability)
	print("Cultural age: %.3f" % archaeology.cultural_age)
	print("Dominant phase: %s" % archaeology.dominant_phase)

	assert_true(archaeology.cultural_age > 0.0, "Cultural age should accumulate")
	assert_true(archaeology.dominant_phase != "", "Should have a dominant phase")

	print()


func test_9_cross_biome_entanglement():
	print("TEST 9: Cross-Biome Entanglement Hub")
	print("─".repeat(40))

	var hive = DreamingHiveBiome.new()
	var plot = WheatPlot.new()
	plot.plant()

	var initial_pop_state = hive.qubits[4].get_bloch_vector()
	var initial_plot_state = plot.quantum_state.get_bloch_vector()

	print("Before entanglement:")
	print("  Population qubit: %s" % initial_pop_state)
	print("  Plot qubit: %s" % initial_plot_state)

	# Entangle
	var success = hive.entangle_with_farm(plot)
	assert_true(success, "Entanglement should succeed")

	# Both should now be part of entangled pair
	assert_true(hive.qubits[4].is_in_pair(), "Population qubit should be in pair")
	assert_true(plot.quantum_state.is_in_pair(), "Plot qubit should be in pair")

	print("\nAfter entanglement:")
	print("  Population in pair: %s" % hive.qubits[4].is_in_pair())
	print("  Plot in pair: %s" % plot.quantum_state.is_in_pair())

	print()


func test_10_player_interactions():
	print("TEST 10: Player Interactions")
	print("─".repeat(40))

	var hive = DreamingHiveBiome.new()

	# Test myth sequence injection
	var initial_theta = []
	for qb in hive.qubits:
		initial_theta.append(qb.theta)

	hive.player_inject_myth(["🧠", "🎨", "👥"])

	var changed = 0
	for i in range(5):
		if abs(hive.qubits[i].theta - initial_theta[i]) > 0.01:
			changed += 1

	assert_true(changed >= 3, "Myth sequence should affect qubits")
	print("Myth sequence affected %d qubits" % changed)

	# Test shadow restraint
	var shadow_initial = hive.qubits[2].theta
	hive.restrain_shadow(0.5)
	var shadow_after = hive.qubits[2].theta

	assert_true(shadow_after < shadow_initial, "Shadow should be restrained")
	print("Shadow restrained: %.3f → %.3f" % [shadow_initial, shadow_after])

	# Test myth export
	hive.activate()
	for i in range(100):
		hive._process(0.1)

	var exports = hive.export_myth_structures()
	print("Exported myths: %d" % exports.size())

	print()


## Assertion helpers

func assert_true(condition: bool, message: String):
	test_count += 1
	if condition:
		passed_count += 1
		print("  ✅ %s" % message)
	else:
		print("  ❌ FAILED: %s" % message)
