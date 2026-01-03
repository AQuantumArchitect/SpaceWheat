extends Node

## Test Hamiltonian coupling to verify coherence can build via evolution

var farm: Node

func _ready():
	# Wait 1 second for boot to complete
	await get_tree().create_timer(1.0).timeout
	_run_test()

func _run_test():
	print("\n" + "=".repeat(80))
	print("HAMILTONIAN COUPLING VERIFICATION TEST")
	print("=".repeat(80) + "\n")

	# Find farm
	var farm_view = get_tree().root.find_child("FarmView", true, false)
	if not farm_view:
		print("❌ FarmView not found")
		get_tree().quit()
		return

	farm = farm_view.get_farm()
	if not farm:
		print("❌ Farm not found")
		get_tree().quit()
		return

	print("✅ Farm found\n")

	# Check BioticFlux biome (main farming biome)
	var biome = farm.biotic_flux_biome
	if not biome:
		print("❌ BioticFlux biome not found")
		get_tree().quit()
		return

	if not biome.bath:
		print("❌ BioticFlux biome has no bath!")
		get_tree().quit()
		return

	print("=== BIOTIC FLUX BIOME BATH STATE ===")
	print("Bath emojis: %s" % str(biome.bath.emoji_list))
	print("Bath dimension: %d" % biome.bath._density_matrix.dimension())
	print("Bath purity: %.6f" % biome.bath.get_purity())
	print("")

	# Check Hamiltonian matrix
	print("=== HAMILTONIAN COUPLING ANALYSIS ===")
	var H = biome.bath._hamiltonian
	if not H:
		print("❌ Hamiltonian not initialized!")
		get_tree().quit()
		return

	print("Hamiltonian dimension: %d×%d" % [H.dimension(), H.dimension()])

	# Key emoji pairs to check
	var test_pairs = [
		["🌾", "👥"],  # Wheat ↔ Labor (farming)
		["🌾", "🌻"],  # Wheat ↔ Sunflower
		["🌾", "🍄"],  # Wheat ↔ Mushroom
		["👥", "🍄"],  # Labor ↔ Mushroom
		["🌻", "🍄"],  # Sunflower ↔ Mushroom
	]

	print("\nChecking Hamiltonian couplings:")
	var total_couplings = 0
	var nonzero_couplings = 0

	for pair in test_pairs:
		var emoji_a = pair[0]
		var emoji_b = pair[1]

		var idx_a = biome.bath.emoji_to_index.get(emoji_a, -1)
		var idx_b = biome.bath.emoji_to_index.get(emoji_b, -1)

		if idx_a < 0 or idx_b < 0:
			print("   %s ↔ %s: Not in bath (skipped)" % [emoji_a, emoji_b])
			continue

		total_couplings += 1

		var coupling = H.get_element(idx_a, idx_b)
		var magnitude = coupling.abs()

		if magnitude > 1e-10:
			nonzero_couplings += 1
			print("   %s ↔ %s: H[%d][%d] = %.6f (✅ EXISTS)" % [emoji_a, emoji_b, idx_a, idx_b, magnitude])
		else:
			print("   %s ↔ %s: H[%d][%d] = 0.000000 (❌ NO COUPLING)" % [emoji_a, emoji_b, idx_a, idx_b])

	print("\n=== COUPLING SUMMARY ===")
	print("Total pairs checked: %d" % total_couplings)
	print("Non-zero couplings: %d" % nonzero_couplings)
	print("Zero couplings: %d" % (total_couplings - nonzero_couplings))

	if nonzero_couplings == 0:
		print("\n❌ CRITICAL: NO HAMILTONIAN COUPLINGS FOUND!")
		print("   → Quantum evolution CANNOT build coherence")
		print("   → Harvesting will always produce '?' outcomes")
		print("   → Need to add Icon.hamiltonian_couplings definitions")
	else:
		print("\n✅ Hamiltonian couplings exist - evolution can build coherence")

	# Test actual evolution
	print("\n=== EVOLUTION TEST ===")
	print("Initial bath state:")
	print("   Purity: %.6f" % biome.bath.get_purity())

	# Create a projection to track
	var test_qubit = biome.create_projection(Vector2i(99, 99), "🌾", "👥")
	print("   Projection 🌾↔👥 radius: %.6f" % test_qubit.radius)

	# Evolve for 2 seconds
	print("\nEvolving for 2 seconds...")
	for i in range(120):  # 2 seconds at 60 FPS
		biome.bath.evolve(1.0/60.0)
		await get_tree().process_frame

	print("After evolution:")
	print("   Bath purity: %.6f" % biome.bath.get_purity())
	print("   Projection 🌾↔👥 radius: %.6f" % test_qubit.radius)

	if test_qubit.radius > 0.1:
		print("✅ Coherence increased - Hamiltonian evolution working!")
	elif abs(test_qubit.radius) < 0.01:
		print("❌ No coherence built - Hamiltonian not driving evolution")
	else:
		print("⚠️  Small coherence change - may need stronger coupling")

	print("\n" + "=".repeat(80))
	print("TEST COMPLETE")
	print("=".repeat(80))

	get_tree().quit()
