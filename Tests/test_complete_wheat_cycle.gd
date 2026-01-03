extends Node

## Complete wheat cycle: Plant → Evolve → Harvest with proper emoji injection

var farm: Node

func _ready():
	print("\n" + "=".repeat(80))
	print("COMPLETE WHEAT FARMING CYCLE TEST")
	print("Plant → Evolve → Harvest with emoji injection verification")
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

	print("✅ Farm found")

	# Get BioticFlux biome
	var biome = farm.biotic_flux_biome
	if not biome or not biome.bath:
		print("❌ BioticFlux biome or bath not found")
		get_tree().quit()
		return

	print("✅ BioticFlux biome ready\n")

	# ========================================================================
	# PHASE 1: PLANTING
	# ========================================================================
	print("=== PHASE 1: PLANTING ===")
	print("Bath emojis before: %s" % str(biome.bath.emoji_list))
	print("Has 👥 before: %s" % ("YES" if biome.bath.emoji_to_index.has("👥") else "NO"))

	# Plant at (2,0) - BioticFlux plot (U key)
	print("\n🌱 Planting wheat at (2,0)...")
	var success = farm.build(Vector2i(2, 0), "wheat")

	if not success:
		print("❌ Planting failed!")
		get_tree().quit()
		return

	await get_tree().process_frame

	var plot = farm.grid.get_plot(Vector2i(2, 0))
	if not plot or not plot.is_planted or not plot.quantum_state:
		print("❌ Plot not properly planted")
		get_tree().quit()
		return

	print("✅ Plot planted successfully")
	print("   Bath emojis after: %s" % str(biome.bath.emoji_list))
	print("   Has 👥 after: %s" % ("YES" if biome.bath.emoji_to_index.has("👥") else "NO"))
	print("   Initial coherence: %.6f" % plot.quantum_state.radius)
	print("   Initial theta: %.6f" % plot.quantum_state.theta)

	# Check resources before
	var wheat_before = farm.economy.get_resource_units("🌾")
	var labor_before = farm.economy.get_resource_units("👥")
	print("\n📊 Resources BEFORE harvest:")
	print("   🌾 Wheat: %d" % wheat_before)
	print("   👥 Labor: %d" % labor_before)

	# ========================================================================
	# PHASE 2: QUANTUM EVOLUTION
	# ========================================================================
	print("\n=== PHASE 2: QUANTUM EVOLUTION ===")
	print("⏱️  Waiting 3 seconds for Hamiltonian evolution...")

	# Track coherence over time
	var samples = 6
	for i in range(samples):
		await get_tree().create_timer(0.5).timeout
		var r = plot.quantum_state.radius
		var theta = plot.quantum_state.theta
		var purity = plot.quantum_state.purity
		print("   t=%.1fs: radius=%.6f, theta=%.4f, purity=%.4f" % [
			(i + 1) * 0.5, r, theta, purity
		])

	# ========================================================================
	# PHASE 3: HARVESTING
	# ========================================================================
	print("\n=== PHASE 3: HARVESTING ===")
	print("Final coherence: %.6f" % plot.quantum_state.radius)
	print("Final theta: %.6f" % plot.quantum_state.theta)
	print("Final purity: %.6f" % plot.quantum_state.purity)

	print("\n✂️  Harvesting plot (2,0)...")
	var result = farm.harvest_plot(Vector2i(2, 0))

	print("\n📋 Harvest result:")
	print("   success: %s" % result.get("success", false))
	print("   outcome: %s" % result.get("outcome", "?"))
	print("   yield: %d" % result.get("yield", 0))
	print("   coherence: %.6f" % result.get("energy", 0.0))
	print("   purity: %.6f" % result.get("purity", 0.0))

	# Check resources after
	var wheat_after = farm.economy.get_resource_units("🌾")
	var labor_after = farm.economy.get_resource_units("👥")
	print("\n📊 Resources AFTER harvest:")
	print("   🌾 Wheat: %d (Δ=%+d)" % [wheat_after, wheat_after - wheat_before])
	print("   👥 Labor: %d (Δ=%+d)" % [labor_after, labor_after - labor_before])

	# ========================================================================
	# PHASE 4: ANALYSIS
	# ========================================================================
	print("\n=== ANALYSIS ===")

	var outcome = result.get("outcome", "?")
	if outcome == "?":
		print("❌ Outcome is '?' - low coherence prevented meaningful measurement")
		print("   → Need longer evolution time or stronger Hamiltonian coupling")
	elif outcome == "🌾":
		print("✅ Measured WHEAT! Coherence was sufficient for wheat outcome")
	elif outcome == "👥":
		print("✅ Measured LABOR! Coherence was sufficient for labor outcome")
	else:
		print("⚠️  Unexpected outcome: %s" % outcome)

	var gained_resources = (wheat_after > wheat_before) or (labor_after > labor_before)
	if gained_resources:
		print("✅ Resources gained from harvest!")
	else:
		print("❌ No resources gained - '?' outcome gives minimal credits")

	# Check Hamiltonian coupling
	var H = biome.bath._hamiltonian
	var wheat_idx = biome.bath.emoji_to_index.get("🌾", -1)
	var labor_idx = biome.bath.emoji_to_index.get("👥", -1)
	if wheat_idx >= 0 and labor_idx >= 0:
		var coupling = H.get_element(wheat_idx, labor_idx)
		print("\n🔗 Hamiltonian coupling H[🌾][👥]: %.6f" % coupling.abs())

	print("\n" + "=".repeat(80))
	print("TEST COMPLETE")
	print("=".repeat(80))

	get_tree().quit()
