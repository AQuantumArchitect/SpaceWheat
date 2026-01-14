extends SceneTree

## Verify Game Uses Native Acceleration
## Checks that ComplexMatrix operations in the game use native backend

const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const IconBuilder = preload("res://Core/Factions/IconBuilder.gd")
const AllFactions = preload("res://Core/Factions/AllFactions.gd")
const QuantumBath = preload("res://Core/QuantumSubstrate/QuantumBath.gd")

func _init():
	print("")
	print("═══════════════════════════════════════════════════════════════")
	print("  VERIFICATION: Game Uses Native Acceleration")
	print("═══════════════════════════════════════════════════════════════")
	print("")

	# Test 1: Check native availability
	print("Test 1: Native Backend Status")
	var is_native = ComplexMatrix.is_native_available()
	print("  Native available: %s" % ("✅ YES" if is_native else "❌ NO"))
	print("")

	if not is_native:
		print("ERROR: Native backend not loaded!")
		print("Game will use slow pure GDScript implementation.")
		quit()
		return

	# Test 2: Verify matrix operations use native
	print("Test 2: Matrix Operations Use Native Backend")
	var test_matrix = ComplexMatrix.new(4)
	var has_native_backend = test_matrix._get_native() != null
	print("  Matrix has native backend: %s" % ("✅ YES" if has_native_backend else "❌ NO"))
	print("")

	# Test 3: Simulate biome creation (what happens during game start)
	print("Test 3: Biome Creation Uses Native")
	print("  Building Forest biome icons...")
	var forest = IconBuilder.build_forest_biome()
	print("    Created %d icons" % forest.size())

	print("  Creating QuantumBath...")
	var bath = QuantumBath.new()
	bath.initialize_with_emojis(forest.keys())
	print("    Initialized bath with %d emojis" % forest.size())

	# Build operators (this creates ComplexMatrix instances)
	var icons_array = forest.values()
	bath.build_hamiltonian_from_icons(icons_array)
	bath.build_lindblad_from_icons(icons_array)
	print("    Built Hamiltonian and Lindblad operators")

	# Check if density matrix uses native
	var rho = bath.get_density_matrix()
	if rho:
		var rho_has_native = rho.rho._get_native() != null if rho.rho else false
		print("    Density matrix uses native: %s" % ("✅ YES" if rho_has_native else "❌ NO"))
	else:
		print("    ❌ ERROR: Could not get density matrix")

	print("")

	# Test 4: Profile a quantum evolution step
	print("Test 4: Profile Quantum Evolution Step")
	if bath.has_method("evolve"):
		var start = Time.get_ticks_usec()
		bath.evolve(0.1)
		var elapsed = Time.get_ticks_usec() - start
		print("  Evolution step (0.1s): %.1f μs" % elapsed)

		# Check if still valid
		var rho_after = bath.get_density_matrix()
		if rho_after:
			var trace = rho_after.get_trace()
			print("  Trace after evolution: %.6f (should be ≈1.0)" % trace)
			print("  Status: %s" % ("✅ WORKING" if abs(trace - 1.0) < 0.01 else "⚠️  WARNING"))
	else:
		print("  ⚠️  Bath.evolve() not available")

	print("")
	print("═══════════════════════════════════════════════════════════════")
	print("  SUMMARY")
	print("═══════════════════════════════════════════════════════════════")
	print("")

	if is_native and has_native_backend:
		print("✅ Game is using NATIVE (Eigen) acceleration")
		print("")
		print("Performance characteristics:")
		print("  - Small matrices (2-8D): 2-20x faster")
		print("  - Large matrices (16-32D): 20-70x faster")
		print("  - Biome evolution steps: Significantly accelerated")
	else:
		print("❌ Game is using PURE GDSCRIPT (slow)")
		print("")
		print("This will cause poor performance in quantum simulations.")
		print("Check that:")
		print("  1. quantum_matrix.gdextension exists")
		print("  2. Native library is in native/bin/")
		print("  3. .godot cache was rebuilt")

	print("")
	print("═══════════════════════════════════════════════════════════════")
	print("")

	quit()
