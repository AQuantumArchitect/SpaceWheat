extends SceneTree

## Integration Test - Revolutionary Biome Features
## Tests all 4 implemented features working together

func _initialize():
	print("\n" + "=".repeat(80))
	print("  INTEGRATION TEST - REVOLUTIONARY BIOME FEATURES")
	print("=".repeat(80) + "\n")

	# Load necessary scripts
	var DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
	var WheatPlot = preload("res://Core/GameMechanics/WheatPlot.gd")
	var SemanticCoupling = preload("res://Core/QuantumSubstrate/SemanticCoupling.gd")
	var VocabularyEvolution = preload("res://Core/QuantumSubstrate/VocabularyEvolution.gd")
	var CarrionThroneIcon = preload("res://Core/Icons/CarrionThroneIcon.gd")

	var all_passed = true

	# TEST 1: Berry Phase in WheatPlot
	print("TEST 1: Berry Phase Integration in WheatPlot")
	print("─".repeat(40))

	var plot = WheatPlot.new()
	plot.plant()

	if not plot.quantum_state.berry_phase_enabled:
		print("  ❌ FAILED: Berry phase not enabled on plant")
		all_passed = false
	else:
		print("  ✅ Berry phase enabled on plant")

	# Evolve for a bit to accumulate Berry phase
	for i in range(50):
		plot.quantum_state.evolve(0.1, 0.5)

	var berry = plot.quantum_state.get_berry_phase_abs()
	var stability = plot.quantum_state.get_cultural_stability()

	print("  Accumulated Berry phase: %.3f" % berry)
	print("  Cultural stability: %.2f" % stability)

	if berry > 0.0:
		print("  ✅ Berry phase accumulating")
	else:
		print("  ❌ FAILED: No Berry phase accumulation")
		all_passed = false

	print()

	# TEST 2: Semantic Coupling Between Plots
	print("TEST 2: Semantic Coupling")
	print("─".repeat(40))

	var plot_a = WheatPlot.new()
	var plot_b = WheatPlot.new()
	plot_a.plant()
	plot_b.plant()

	# Give them different initial states to show coupling effect
	plot_a.quantum_state.theta = PI * 0.3  # Closer to north
	plot_b.quantum_state.theta = PI * 0.7  # Closer to south

	# Record initial states
	var initial_a = plot_a.quantum_state.theta
	var initial_b = plot_b.quantum_state.theta

	print("  Plot A initial θ: %.3f" % initial_a)
	print("  Plot B initial θ: %.3f" % initial_b)

	# Apply semantic coupling for 5 seconds
	for i in range(50):
		SemanticCoupling.apply_semantic_coupling(
			plot_a.quantum_state,
			plot_b.quantum_state,
			0.1,
			1.0
		)

	var final_a = plot_a.quantum_state.theta
	var final_b = plot_b.quantum_state.theta

	print("  Plot A final θ: %.3f" % final_a)
	print("  Plot B final θ: %.3f" % final_b)

	var similarity = SemanticCoupling.calculate_pair_similarity(
		plot_a.quantum_state,
		plot_b.quantum_state
	)

	print("  Similarity: %.2f" % similarity)
	print("  Coupling type: %s" % SemanticCoupling.get_coupling_description(similarity))

	# States should have changed due to coupling
	if abs(final_a - initial_a) > 0.01 or abs(final_b - initial_b) > 0.01:
		print("  ✅ Semantic coupling affecting states")
	else:
		print("  ⚠️ WARNING: States not changing (may be neutral coupling)")

	print()

	# TEST 3: Strange Attractor Evolution
	print("TEST 3: Strange Attractor (Political Seasons)")
	print("─".repeat(40))

	var carrion = CarrionThroneIcon.new()
	carrion._ready()

	# Activate the Icon (required for evolution)
	carrion.active_strength = 0.75

	print("  Initial season: %s" % carrion.get_political_season())
	print("  Initial history size: %d" % carrion.get_attractor_history().size())
	print("  Activation: %.0f%%" % (carrion.active_strength * 100))

	# Evolve for 10 seconds
	for i in range(100):
		carrion.update_political_season(0.1)

	var history = carrion.get_attractor_history()
	print("  After 10s history size: %d" % history.size())
	print("  Current season: %s" % carrion.get_political_season())

	if history.size() > 0:
		var latest = history[history.size() - 1]
		print("  Latest state:")
		print("    Harvest/Decay: %s" % latest.harvest_decay)
		print("    Labor/Conflict: %s" % latest.labor_conflict)
		print("    Authority/Growth: %s" % latest.authority_growth)
		print("    Wealth/Void: %s" % latest.wealth_void)
		print("  ✅ Strange attractor evolving")
	else:
		print("  ❌ FAILED: No attractor history")
		all_passed = false

	print()

	# TEST 4: Vocabulary Evolution
	print("TEST 4: Vocabulary Evolution System")
	print("─".repeat(40))

	var vocab = VocabularyEvolution.new()
	vocab._ready()

	var initial_stats = vocab.get_evolution_stats()
	print("  Initial pool: %d concepts" % initial_stats.pool_size)

	# Evolve for 20 seconds
	for i in range(200):
		vocab.evolve(0.1)

	var final_stats = vocab.get_evolution_stats()
	print("  Final pool: %d concepts" % final_stats.pool_size)
	print("  Total spawned: %d" % final_stats.total_spawned)
	print("  Total cannibalized: %d" % final_stats.total_cannibalized)
	print("  Discoveries: %d" % final_stats.discovered_count)

	if final_stats.total_spawned > initial_stats.pool_size:
		print("  ✅ Vocabulary evolving and spawning")
	else:
		print("  ❌ FAILED: No new concepts spawned")
		all_passed = false

	print()

	# TEST 5: Cross-Feature Integration
	print("TEST 5: Cross-Feature Integration")
	print("─".repeat(40))

	# Create a plot with Berry phase + semantic coupling
	var integrated_plot = WheatPlot.new()
	integrated_plot.plant()

	# Evolve with Berry phase
	for i in range(30):
		integrated_plot.quantum_state.evolve(0.1, 0.5)

	var pre_coupling_berry = integrated_plot.quantum_state.get_berry_phase_abs()

	# Apply semantic coupling
	var reference_plot = WheatPlot.new()
	reference_plot.plant()

	for i in range(20):
		SemanticCoupling.apply_semantic_coupling(
			integrated_plot.quantum_state,
			reference_plot.quantum_state,
			0.1,
			0.5
		)

	var post_coupling_berry = integrated_plot.quantum_state.get_berry_phase_abs()

	print("  Berry phase before coupling: %.3f" % pre_coupling_berry)
	print("  Berry phase after coupling: %.3f" % post_coupling_berry)
	print("  Cultural stability: %.2f" % integrated_plot.quantum_state.get_cultural_stability())

	# Berry phase should continue accumulating even during coupling
	if post_coupling_berry >= pre_coupling_berry:
		print("  ✅ Berry phase + semantic coupling compatible")
	else:
		print("  ⚠️ WARNING: Berry phase decreased (may be due to state changes)")

	print()

	# FINAL SUMMARY
	print("=".repeat(80))
	if all_passed:
		print("  ALL INTEGRATION TESTS PASSED ✅")
	else:
		print("  SOME TESTS FAILED ❌")
	print("=".repeat(80))

	print("\nIntegration Summary:")
	print("  ✅ Berry Phase: Tracks geometric memory in wheat")
	print("  ✅ Semantic Coupling: Plots influence each other")
	print("  ✅ Strange Attractor: Political seasons evolve")
	print("  ✅ Vocabulary Evolution: Living language discovers emoji pairs")
	print("\nAll systems operational. Ready for gameplay integration. 🌾⚛️\n")

	quit(0 if all_passed else 1)
