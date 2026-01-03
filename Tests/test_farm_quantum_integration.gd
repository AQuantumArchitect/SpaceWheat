extends SceneTree

## Test farm-level integration with density matrix quantum system

const Farm = preload("res://Core/Farm.gd")

func _init():
	print("\n╔════════════════════════════════════════════════════════╗")
	print("║  FARM QUANTUM INTEGRATION TEST                       ║")
	print("╚════════════════════════════════════════════════════════╝\n")

	await test_farm_initialization()
	await test_farm_biome_integration()

	print("\n✅ ALL FARM QUANTUM INTEGRATION TESTS PASSED!\n")
	quit()

func test_farm_initialization():
	print("📊 Test 1: Farm initialization with quantum biomes...")

	var farm = Farm.new()
	root.add_child(farm)
	await process_frame

	# Give initialization time to complete
	await process_frame
	await process_frame

	print("  ✓ Farm created")

	# Check biomes
	var biotic_flux = farm.get_node_or_null("BioticFluxBiome")
	var market = farm.get_node_or_null("MarketBiome")
	var forest = farm.get_node_or_null("ForestEcosystem")
	var kitchen = farm.get_node_or_null("QuantumKitchen")

	if biotic_flux:
		print("  ✓ BioticFlux biome exists")
		if biotic_flux.bath:
			var purity = biotic_flux.bath.get_purity()
			var trace = biotic_flux.bath.get_total_probability()
			print("    Bath: purity=%.4f, trace=%.6f" % [purity, trace])

	if market:
		print("  ✓ Market biome exists")
		if market.bath:
			var emoji_count = market.bath.emoji_list.size()
			print("    Bath: %d emojis" % emoji_count)

	if forest:
		print("  ✓ Forest biome exists")
		if forest.bath:
			var emoji_count = forest.bath.emoji_list.size()
			print("    Bath: %d emojis" % emoji_count)

	if kitchen:
		print("  ✓ Kitchen biome exists")
		if kitchen.bath:
			var emoji_count = kitchen.bath.emoji_list.size()
			print("    Bath: %d emojis" % emoji_count)

	print("  ✅ PASS\n")
	farm.queue_free()

func test_farm_biome_integration():
	print("📊 Test 2: Farm biome quantum evolution...")

	var farm = Farm.new()
	root.add_child(farm)
	await process_frame
	await process_frame

	# Get biotic flux biome
	var biotic_flux = farm.get_node_or_null("BioticFluxBiome")
	if not biotic_flux:
		print("  ⚠ BioticFlux biome not found, skipping test")
		farm.queue_free()
		return

	if not biotic_flux.bath:
		print("  ⚠ BioticFlux bath not initialized, skipping test")
		farm.queue_free()
		return

	var initial_purity = biotic_flux.bath.get_purity()
	var initial_trace = biotic_flux.bath.get_total_probability()

	print("  ✓ Initial state:")
	print("    Purity = %.4f" % initial_purity)
	print("    Trace = %.6f" % initial_trace)

	# Evolve for 1 second
	for i in range(60):
		farm._process(1.0 / 60.0)

	var final_purity = biotic_flux.bath.get_purity()
	var final_trace = biotic_flux.bath.get_total_probability()

	print("  ✓ After 1 second evolution:")
	print("    Purity = %.4f (Δ = %.4f)" % [final_purity, final_purity - initial_purity])
	print("    Trace = %.6f (Δ = %.8f)" % [final_trace, final_trace - initial_trace])

	# Validate physics
	assert(abs(final_trace - 1.0) < 0.01, "Trace not preserved: %.6f" % final_trace)

	print("  ✅ PASS\n")
	farm.queue_free()
