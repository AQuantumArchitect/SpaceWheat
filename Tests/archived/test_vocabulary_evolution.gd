extends SceneTree

## Vocabulary Evolution Test
## Verifies procedural emoji discovery system

func _initialize():
	print("\n" + "=".repeat(80))
	print("  VOCABULARY EVOLUTION - EMOJI DISCOVERY TEST")
	print("=".repeat(80) + "\n")

	# Load script
	var VocabularyEvolutionScript = load("res://Core/QuantumSubstrate/VocabularyEvolution.gd")

	# Test 1: System Creation
	print("TEST 1: System Creation")
	print("─".repeat(40))
	var vocab_system = VocabularyEvolutionScript.new()
	vocab_system._ready()
	var stats = vocab_system.get_evolution_stats()
	print("  Initial pool size: %d" % stats.pool_size)
	print("  Mutation pressure: %.2f" % stats.mutation_pressure)
	print("  ✅ System created\n")

	# Test 2: Evolution (10 seconds simulated)
	print("TEST 2: Evolution (10 seconds)")
	print("─".repeat(40))
	for i in range(100):  # 100 steps of 0.1s = 10s
		vocab_system.evolve(0.1)

	stats = vocab_system.get_evolution_stats()
	print("  Pool size: %d" % stats.pool_size)
	print("  Total spawned: %d" % stats.total_spawned)
	print("  Total cannibalized: %d" % stats.total_cannibalized)
	print("  Discovered: %d" % stats.discovered_count)

	if stats.total_spawned > 0:
		print("  ✅ Concepts are spawning")
	else:
		print("  ❌ No concepts spawned")
		quit(1)

	print()

	# Test 3: Longer evolution (30 more seconds)
	print("TEST 3: Extended Evolution (30 seconds)")
	print("─".repeat(40))
	for i in range(300):  # 300 steps of 0.1s = 30s
		vocab_system.evolve(0.1)

	stats = vocab_system.get_evolution_stats()
	print("  Pool size: %d" % stats.pool_size)
	print("  Total spawned: %d" % stats.total_spawned)
	print("  Total cannibalized: %d" % stats.total_cannibalized)
	print("  Discovered: %d" % stats.discovered_count)

	if stats.discovered_count > 0:
		print("  ✅ Concepts discovered!")
	else:
		print("  ⚠️ No discoveries yet (may need more time)")

	print()

	# Test 4: Discovered Vocabulary
	print("TEST 4: Discovered Vocabulary")
	print("─".repeat(40))
	var discovered = vocab_system.get_discovered_vocabulary()

	if discovered.size() > 0:
		for i in range(min(5, discovered.size())):
			var d = discovered[i]
			print("  %s ↔ %s (γ=%.2f, t=%.1fs)" % [
				d.north,
				d.south,
				d.berry_phase,
				d.discovery_time
			])
		print("  ✅ Vocabulary discovered and exported")
	else:
		print("  No discoveries yet")

	print()

	# Test 5: Export for Breeding
	print("TEST 5: Export for Breeding")
	print("─".repeat(40))
	var exports = vocab_system.export_vocabulary_for_breeding()
	print("  Exportable concepts: %d" % exports.size())

	if exports.size() > 0:
		for i in range(min(3, exports.size())):
			var e = exports[i]
			print("  %s ↔ %s (stability: %.2f)" % [
				e.north,
				e.south,
				e.stability
			])
		print("  ✅ Vocabulary ready for crossbreeding")
	else:
		print("  No exports yet")

	print()

	print("=".repeat(80))
	print("  VOCABULARY EVOLUTION TEST COMPLETE")
	print("=".repeat(80))
	print("\nThe vocabulary evolves. Living language emerges. 🧬✨\n")

	quit()
