extends SceneTree

## Quick test to verify Icon Lindblad rate adjustments

func _init():
	print("\n=== ICON LINDBLAD RATE VALIDATION TEST ===\n")

	# Load IconRegistry
	var IconRegistryScript = load("res://Core/QuantumSubstrate/IconRegistry.gd")
	var icon_registry = IconRegistryScript.new()
	icon_registry.name = "IconRegistry"
	root.add_child(icon_registry)
	icon_registry._ready()

	# Check CoreIcons rates
	print("✓ IconRegistry initialized with %d icons" % icon_registry.icons.size())

	# Verify wheat rates (30x slower)
	var wheat = icon_registry.get_icon("🌾")
	if wheat:
		print("\n🌾 Wheat Lindblad rates:")
		for source in wheat.lindblad_incoming:
			var rate = wheat.lindblad_incoming[source]
			print("  %s → 🌾: %.5f/sec (expected ~0.00067-0.00267)" % [source, rate])
			if rate > 0.01:
				push_error("  ❌ WHEAT RATE TOO HIGH! Expected 30x slower")

	# Verify mushroom rates (10x slower)
	var mushroom = icon_registry.get_icon("🍄")
	if mushroom:
		print("\n🍄 Mushroom Lindblad rates:")
		for source in mushroom.lindblad_incoming:
			var rate = mushroom.lindblad_incoming[source]
			print("  %s → 🍄: %.5f/sec (expected ~0.006-0.012)" % [source, rate])
			if rate > 0.02:
				push_error("  ❌ MUSHROOM RATE TOO HIGH! Expected 10x slower")

	# Verify market rates (10x slower)
	var bull = icon_registry.get_icon("🐂")
	if bull:
		print("\n🐂 Bull Lindblad rates:")
		for source in bull.lindblad_incoming:
			var rate = bull.lindblad_incoming[source]
			print("  %s → 🐂: %.5f/sec (expected ~0.008)" % [source, rate])

	# Test BioticFluxBiome initialization
	print("\n=== Testing BioticFluxBiome bath initialization ===")
	var BioticFluxBiome = load("res://Core/Environment/BioticFluxBiome.gd")
	var biome = BioticFluxBiome.new()
	biome.name = "BioticFluxBiome"
	root.add_child(biome)
	biome._ready()

	# Check bath initialization
	if biome.bath:
		print("\n✅ Bath initialized successfully")
		print("  Emojis: %d" % biome.bath.emoji_list.size())
		print("  Hamiltonian terms: %d" % biome.bath.hamiltonian_sparse.size())
		print("  Lindblad terms: %d" % biome.bath.lindblad_terms.size())

		# Check specific Lindblad rate
		for term in biome.bath.lindblad_terms:
			var source_emoji = biome.bath.emoji_list[term.source]
			var target_emoji = biome.bath.emoji_list[term.target]
			if source_emoji == "☀" and target_emoji == "🌾":
				print("\n  ☀ → 🌾 rate: %.5f/sec" % term.rate)
				if term.rate > 0.01:
					push_error("  ❌ SUN→WHEAT RATE TOO HIGH!")
				else:
					print("  ✅ Rate looks good (30x slower)")
	else:
		push_error("❌ Bath not initialized!")

	print("\n=== TEST COMPLETE ===")
	quit()
