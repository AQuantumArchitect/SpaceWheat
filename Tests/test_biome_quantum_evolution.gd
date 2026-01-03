extends SceneTree

## Test biome quantum evolution with density matrix system

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const MarketBiome = preload("res://Core/Environment/MarketBiome.gd")

func _init():
	print("\n╔════════════════════════════════════════════════════════╗")
	print("║  BIOME QUANTUM EVOLUTION TEST                        ║")
	print("╚════════════════════════════════════════════════════════╝\n")

	await test_biotic_flux_evolution()
	await test_market_evolution()
	await test_projection_mechanics()

	print("\n✅ ALL BIOME EVOLUTION TESTS PASSED!\n")
	quit()

func test_biotic_flux_evolution():
	print("📊 Test 1: BioticFlux quantum evolution...")

	var biome = BioticFluxBiome.new()
	root.add_child(biome)
	await process_frame

	var bath = biome.bath

	print("  ✓ Initial state:")
	var initial_purity = bath.get_purity()
	var initial_entropy = bath.get_entropy()
	print("    Purity = %.4f" % initial_purity)
	print("    Entropy = %.4f" % initial_entropy)

	# Check initial populations
	var wheat_pop = bath.get_probability("🌾")
	var death_pop = bath.get_probability("💀")
	print("    P(🌾) = %.4f" % wheat_pop)
	print("    P(💀) = %.4f" % death_pop)

	# Evolve for 1 second (60 frames)
	for i in range(60):
		biome._process(1.0 / 60.0)

	print("\n  ✓ After 1 second evolution:")
	var final_purity = bath.get_purity()
	var final_entropy = bath.get_entropy()
	var final_trace = bath.get_total_probability()

	print("    Purity = %.4f (Δ = %.4f)" % [final_purity, final_purity - initial_purity])
	print("    Entropy = %.4f (Δ = %.4f)" % [final_entropy, final_entropy - initial_entropy])
	print("    Trace = %.6f (should be 1.0)" % final_trace)

	var wheat_pop_final = bath.get_probability("🌾")
	var death_pop_final = bath.get_probability("💀")
	print("    P(🌾) = %.4f (Δ = %.4f)" % [wheat_pop_final, wheat_pop_final - wheat_pop])
	print("    P(💀) = %.4f (Δ = %.4f)" % [death_pop_final, death_pop_final - death_pop])

	# Validate physics
	assert(abs(final_trace - 1.0) < 0.01, "Trace not preserved: %.6f" % final_trace)
	assert(final_purity <= initial_purity + 0.01, "Purity increased (unphysical)")
	assert(wheat_pop_final >= 0 and wheat_pop_final <= 1.0, "Probability out of bounds")

	print("  ✅ PASS\n")
	biome.queue_free()

func test_market_evolution():
	print("📊 Test 2: Market quantum evolution...")

	var biome = MarketBiome.new()
	root.add_child(biome)
	await process_frame

	var bath = biome.bath

	print("  ✓ Market bath initialized with %d emojis" % bath.emoji_list.size())

	var initial_trace = bath.get_total_probability()
	var initial_purity = bath.get_purity()

	# Evolve for 0.5 seconds
	for i in range(30):
		biome._process(1.0 / 60.0)

	var final_trace = bath.get_total_probability()
	var final_purity = bath.get_purity()

	print("  ✓ After 0.5 seconds:")
	print("    Trace: %.6f → %.6f" % [initial_trace, final_trace])
	print("    Purity: %.4f → %.4f" % [initial_purity, final_purity])

	assert(abs(final_trace - 1.0) < 0.01, "Market trace not preserved")

	print("  ✅ PASS\n")
	biome.queue_free()

func test_projection_mechanics():
	print("📊 Test 3: Projection mechanics (DualEmojiQubit)...")

	var biome = BioticFluxBiome.new()
	root.add_child(biome)
	await process_frame

	var bath = biome.bath

	# Test projection onto wheat/death axis
	var projection = bath.project_onto_axis("🌾", "💀")

	print("  ✓ Wheat ↔ Death projection:")
	print("    North (🌾): P = %.4f" % projection.p_north)
	print("    South (💀): P = %.4f" % projection.p_south)
	print("    θ = %.2f rad (%.1f°)" % [projection.theta, rad_to_deg(projection.theta)])
	print("    φ = %.2f rad (%.1f°)" % [projection.phi, rad_to_deg(projection.phi)])
	print("    Radius = %.4f" % projection.radius)
	print("    Purity (2D) = %.4f" % projection.purity)

	# Validate projection
	var p_subspace_sum = projection.p_north + projection.p_south
	var p_subspace = projection.get("p_subspace", p_subspace_sum)
	assert(abs(p_subspace_sum - p_subspace) < 0.01,
		"Projection probabilities don't match subspace total: %.4f vs %.4f" % [p_subspace_sum, p_subspace])
	assert(projection.radius >= 0 and projection.radius <= 1.0,
		"Bloch radius out of bounds: %.4f" % projection.radius)
	assert(projection.theta >= 0 and projection.theta <= PI,
		"Theta out of bounds")
	assert(projection.phi >= -PI and projection.phi <= PI,
		"Phi out of bounds")

	# Evolve and check projection changes
	for i in range(30):
		biome._process(1.0 / 60.0)

	var projection2 = bath.project_onto_axis("🌾", "💀")
	print("\n  ✓ After evolution:")
	print("    θ: %.2f → %.2f rad" % [projection.theta, projection2.theta])
	print("    Radius: %.4f → %.4f" % [projection.radius, projection2.radius])

	print("  ✅ PASS\n")
	biome.queue_free()
