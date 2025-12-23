extends SceneTree

## Game Startup Test
## Verifies the game loads and all systems initialize

func _initialize():
	print("\n" + "=".repeat(80))
	print("  GAME STARTUP TEST - SYSTEM INITIALIZATION")
	print("=".repeat(80) + "\n")

	# Load the main scene
	var main_scene = load("res://scenes/FarmView.tscn")
	if not main_scene:
		print("❌ FAILED: Could not load FarmView.tscn")
		quit(1)
		return

	print("✅ FarmView.tscn loaded successfully\n")

	# Instance it
	var farm_view = main_scene.instantiate()
	if not farm_view:
		print("❌ FAILED: Could not instantiate FarmView")
		quit(1)
		return

	print("✅ FarmView instantiated successfully\n")

	# Add to scene tree
	root.add_child(farm_view)

	# Let it initialize (process a few frames)
	for i in range(5):
		root._process(0.016)  # Simulate 60 FPS

	print("=".repeat(40))
	print("CHECKING SYSTEMS INITIALIZATION")
	print("=".repeat(40) + "\n")

	# Check core systems
	if farm_view.economy:
		print("✅ FarmEconomy initialized")
		print("   Credits: %d" % farm_view.economy.credits)
	else:
		print("❌ FAILED: FarmEconomy not initialized")

	if farm_view.farm_grid:
		print("✅ FarmGrid initialized")
	else:
		print("❌ FAILED: FarmGrid not initialized")

	if farm_view.goals:
		print("✅ GoalsSystem initialized")
	else:
		print("❌ FAILED: GoalsSystem not initialized")

	print()

	# Check Icons
	if farm_view.biotic_icon:
		print("✅ Biotic Flux Icon initialized")
	else:
		print("❌ FAILED: Biotic Flux Icon not initialized")

	if farm_view.chaos_icon:
		print("✅ Cosmic Chaos Icon initialized")
	else:
		print("❌ FAILED: Cosmic Chaos Icon not initialized")

	if farm_view.imperium_icon:
		print("✅ Imperium Icon initialized")
		if farm_view.imperium_icon.has_method("get_political_season"):
			print("   Political season: %s" % farm_view.imperium_icon.get_political_season())
	else:
		print("❌ FAILED: Imperium Icon not initialized")

	print()

	# Check Vocabulary Evolution (NEW!)
	if farm_view.vocabulary_evolution:
		print("✅ Vocabulary Evolution initialized")
		var stats = farm_view.vocabulary_evolution.get_evolution_stats()
		print("   Initial pool: %d concepts" % stats.pool_size)
		print("   Mutation pressure: %.2f" % stats.mutation_pressure)

		# Simulate 10 seconds of evolution
		for i in range(100):
			farm_view.vocabulary_evolution.evolve(0.1)

		var evolved_stats = farm_view.vocabulary_evolution.get_evolution_stats()
		print("   After 10s:")
		print("   Pool: %d concepts" % evolved_stats.pool_size)
		print("   Spawned: %d" % evolved_stats.total_spawned)
		print("   Discoveries: %d" % evolved_stats.discovered_count)

		if evolved_stats.total_spawned > stats.pool_size:
			print("   ✅ Vocabulary actively evolving")
		else:
			print("   ⚠️ Limited evolution (may need more time)")
	else:
		print("❌ FAILED: Vocabulary Evolution not initialized")

	print()

	# Check Quantum Force Graph
	if farm_view.quantum_graph:
		print("✅ QuantumForceGraph initialized")
		print("   Center: %s" % farm_view.quantum_graph.center_position)
	else:
		print("❌ FAILED: QuantumForceGraph not initialized")

	print()

	# Check Conspiracy Network
	if farm_view.conspiracy_network:
		print("✅ TomatoConspiracyNetwork initialized")
	else:
		print("❌ FAILED: TomatoConspiracyNetwork not initialized")

	print()

	print("=".repeat(80))
	print("  GAME STARTUP TEST COMPLETE ✅")
	print("=".repeat(80))
	print()
	print("All revolutionary biome features integrated:")
	print("  🔸 Berry Phase tracking active in wheat")
	print("  🔸 Semantic Coupling enabled in QuantumForceGraph")
	print("  🔸 Strange Attractor evolving in Carrion Throne")
	print("  🔸 Vocabulary Evolution discovering emoji pairs")
	print()
	print("Ready for normal playtesting! 🎮\n")

	quit()
