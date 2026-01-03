extends Node

## Test that planting wheat injects missing emojis into biome bath

var farm: Node

func _ready():
	print("\n" + "=".repeat(80))
	print("WHEAT PLANTING EMOJI INJECTION TEST")
	print("=".repeat(80) + "\n")

	# Wait for boot
	var boot_mgr = get_node_or_null("/root/BootManager")
	if boot_mgr and not boot_mgr.is_ready:
		await boot_mgr.game_ready
	for i in range(5):
		await get_tree().process_frame

	# Find farm
	var farm_view = get_tree().root.find_child("FarmView", true, false)
	farm = farm_view.get_farm() if farm_view else null

	if not farm:
		print("❌ Farm not found")
		get_tree().quit()
		return

	print("✅ Farm found\n")

	# Get BioticFlux biome
	var biome = farm.biotic_flux_biome
	if not biome or not biome.bath:
		print("❌ BioticFlux biome or bath not found")
		get_tree().quit()
		return

	print("=== BEFORE PLANTING ===")
	print("Bath emojis: %s" % str(biome.bath.emoji_list))
	print("Bath dimension: %d" % biome.bath._density_matrix.dimension())

	var has_wheat_before = biome.bath.emoji_to_index.has("🌾")
	var has_labor_before = biome.bath.emoji_to_index.has("👥")
	print("Has 🌾: %s" % ("YES" if has_wheat_before else "NO"))
	print("Has 👥: %s" % ("YES" if has_labor_before else "NO"))

	# Plant wheat at (2,0) - BioticFlux plot (U key)
	print("\n🌱 Planting wheat at (2,0) - BioticFlux plot...")
	var success = farm.build(Vector2i(2, 0), "wheat")

	if not success:
		print("❌ Planting failed!")
		get_tree().quit()
		return

	print("✅ Planting succeeded")

	# Wait a frame for processing
	await get_tree().process_frame

	# Check plot
	var plot = farm.grid.get_plot(Vector2i(2, 0))
	if not plot or not plot.is_planted:
		print("❌ Plot not marked as planted")
		get_tree().quit()
		return

	print("✅ Plot is planted")

	# Check quantum state
	if not plot.quantum_state:
		print("❌ Plot has no quantum state!")
		get_tree().quit()
		return

	print("✅ Plot has quantum state")
	print("   North emoji: %s" % plot.quantum_state.north_emoji)
	print("   South emoji: %s" % plot.quantum_state.south_emoji)
	print("   Radius (coherence): %.6f" % plot.quantum_state.radius)
	print("   Theta: %.6f" % plot.quantum_state.theta)

	# Check bath AFTER planting
	print("\n=== AFTER PLANTING ===")
	print("Bath emojis: %s" % str(biome.bath.emoji_list))
	print("Bath dimension: %d" % biome.bath._density_matrix.dimension())

	var has_wheat_after = biome.bath.emoji_to_index.has("🌾")
	var has_labor_after = biome.bath.emoji_to_index.has("👥")
	print("Has 🌾: %s" % ("YES" if has_wheat_after else "NO"))
	print("Has 👥: %s" % ("YES" if has_labor_after else "NO"))

	# Check if injection happened
	print("\n=== INJECTION ANALYSIS ===")
	if not has_labor_before and has_labor_after:
		print("✅ 👥 was INJECTED during planting!")
	elif not has_labor_before and not has_labor_after:
		print("❌ 👥 was NOT injected - INJECTION FAILED!")
		print("   This means create_projection() didn't inject missing emoji")
	elif has_labor_before:
		print("⚠️  👥 was already in bath before planting")

	# Check Hamiltonian coupling after injection
	if has_wheat_after and has_labor_after:
		print("\n=== HAMILTONIAN COUPLING CHECK ===")
		var H = biome.bath._hamiltonian
		var wheat_idx = biome.bath.emoji_to_index.get("🌾", -1)
		var labor_idx = biome.bath.emoji_to_index.get("👥", -1)

		if wheat_idx >= 0 and labor_idx >= 0:
			var coupling = H.get_element(wheat_idx, labor_idx)
			print("H[🌾][👥] coupling magnitude: %.6f" % coupling.abs())

			if coupling.abs() > 1e-10:
				print("✅ Hamiltonian coupling EXISTS - evolution can build coherence!")
			else:
				print("❌ Hamiltonian coupling is ZERO - evolution won't work!")
				print("   Problem: Icon for 👥 may not have hamiltonian_couplings defined")

	print("\n" + "=".repeat(80))
	print("TEST COMPLETE")
	print("=".repeat(80))

	get_tree().quit()
