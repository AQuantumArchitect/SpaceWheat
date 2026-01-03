extends SceneTree

## 🍄 CLAUDE FARMS MUSHROOMS - Multi-Biome Exploration!
## Goal: Test mushroom farming (labor-based economy)

const Farm = preload("res://Core/Farm.gd")

var farm: Farm
var current_turn: int = 0
var game_time: float = 0.0

# Statistics
var mushroom_harvests: int = 0
var detritus_harvests: int = 0


func _initialize():
	print("\n" + "=".repeat(80))
	print("🍄 CLAUDE FARMS MUSHROOMS - Multi-Biome Test!")
	print("=".repeat(80))
	print("Mission:")
	print("  1. Test mushroom farming (costs labor, not wheat)")
	print("  2. Test 🍄↔🍂 superposition (mushroom vs detritus)")
	print("  3. Compare growth rates with wheat")
	print("  4. Hunt for bugs in mushroom system")
	print("=".repeat(80) + "\n")

	await get_root().ready
	await _setup_game()

	print("\n📋 STRATEGY: Side-by-side wheat vs mushroom farming")
	print("   - Plant wheat at (0,0) using wheat credits")
	print("   - Plant mushroom at (1,0) using labor credits")
	print("   - Evolve both for 60s")
	print("   - Compare growth rates and harvest outcomes\n")

	# Execute farming experiment
	_execute_experiment()

	# Final report
	_print_final_report()

	quit(0)


func _setup_game():
	print("Setting up game world...")

	# Create farm
	farm = Farm.new()
	get_root().add_child(farm)
	for i in range(10):
		await process_frame

	print("✅ Game world ready!")
	print("📊 Starting resources: 🌾%d 👥%d 🍄%d 🍂%d\n" % [
		farm.economy.get_resource("🌾"),
		farm.economy.get_resource("👥"),
		farm.economy.get_resource("🍄"),
		farm.economy.get_resource("🍂")
	])


func _execute_experiment():
	"""Run the mushroom farming experiment"""

	print("──────────────────────────────────────────────────────────────────────")
	print("🌱 PHASE 1: Plant wheat and mushroom side-by-side")
	print("──────────────────────────────────────────────────────────────────────")

	# Plant wheat
	print("\n   🌾 Planting wheat at (0,0) - costs 1 wheat credit")
	var wheat_success = farm.build(Vector2i(0, 0), "wheat")
	if wheat_success:
		print("      ✅ Wheat planted successfully")
		_debug_plot_state(Vector2i(0, 0))
	else:
		print("      ❌ Failed to plant wheat!")

	# Plant mushroom
	print("\n   🍄 Planting mushroom at (1,0) - costs 1 labor credit")
	var mushroom_success = farm.build(Vector2i(1, 0), "mushroom")
	if mushroom_success:
		print("      ✅ Mushroom planted successfully")
		_debug_plot_state(Vector2i(1, 0))
	else:
		print("      ❌ Failed to plant mushroom!")
		print("      📊 Debug: Labor credits = %d" % farm.economy.get_resource("👥"))

	print("\n   📊 Resources after planting:")
	print("      🌾 Wheat: %d (-1 from planting)" % farm.economy.get_resource("🌾"))
	print("      👥 Labor: %d (-1 from planting)" % farm.economy.get_resource("👥"))

	# Phase 2: Quantum evolution
	print("\n──────────────────────────────────────────────────────────────────────")
	print("⏳ PHASE 2: Quantum evolution (60s)")
	print("──────────────────────────────────────────────────────────────────────")

	print("\n   Before evolution:")
	_debug_plot_state(Vector2i(0, 0))
	_debug_plot_state(Vector2i(1, 0))

	print("\n   ⏳ Waiting 60s for quantum evolution...")
	_advance_all_biomes(60.0)

	print("\n   After evolution:")
	_debug_plot_state(Vector2i(0, 0))
	_debug_plot_state(Vector2i(1, 0))

	# Phase 3: Measurement
	print("\n──────────────────────────────────────────────────────────────────────")
	print("🔬 PHASE 3: Measurement")
	print("──────────────────────────────────────────────────────────────────────")

	print("\n   🔬 Measuring wheat plot (0,0)")
	var wheat_outcome = farm.measure_plot(Vector2i(0, 0))
	print("      Outcome: %s" % wheat_outcome)
	_debug_plot_state(Vector2i(0, 0))

	print("\n   🔬 Measuring mushroom plot (1,0)")
	var mushroom_outcome = farm.measure_plot(Vector2i(1, 0))
	print("      Outcome: %s (either 🍄 or 🍂)" % mushroom_outcome)
	_debug_plot_state(Vector2i(1, 0))

	# Phase 4: Harvest
	print("\n──────────────────────────────────────────────────────────────────────")
	print("✂️  PHASE 4: Harvest")
	print("──────────────────────────────────────────────────────────────────────")

	print("\n   ✂️  Harvesting wheat (0,0)")
	var wheat_result = farm.harvest_plot(Vector2i(0, 0))
	if wheat_result.get("success"):
		print("      Outcome: %s" % wheat_result.get("outcome"))
		print("      Yield: %d credits" % wheat_result.get("yield"))
		print("      Energy: %.3f" % wheat_result.get("energy"))

	print("\n   ✂️  Harvesting mushroom (1,0)")
	var mushroom_result = farm.harvest_plot(Vector2i(1, 0))
	if mushroom_result.get("success"):
		var outcome = mushroom_result.get("outcome")
		print("      Outcome: %s" % outcome)
		print("      Yield: %d credits" % mushroom_result.get("yield"))
		print("      Energy: %.3f" % mushroom_result.get("energy"))

		# Track statistics
		if outcome == "🍄":
			mushroom_harvests += 1
		elif outcome == "🍂":
			detritus_harvests += 1

	print("\n   📊 Resources after harvest:")
	print("      🌾 Wheat: %d" % farm.economy.get_resource("🌾"))
	print("      👥 Labor: %d" % farm.economy.get_resource("👥"))
	print("      🍄 Mushroom: %d" % farm.economy.get_resource("🍄"))
	print("      🍂 Detritus: %d" % farm.economy.get_resource("🍂"))

	# Phase 5: Multi-plot mushroom farm
	print("\n──────────────────────────────────────────────────────────────────────")
	print("🍄 PHASE 5: Multi-plot mushroom farm")
	print("──────────────────────────────────────────────────────────────────────")

	# Check if we have enough labor to plant more mushrooms
	var labor = farm.economy.get_resource("👥")
	print("\n   💰 Available labor: %d credits" % labor)

	if labor >= 3:
		print("   🍄 Planting 3 mushrooms in a row")
		for x in range(3):
			var pos = Vector2i(x, 1)
			var success = farm.build(pos, "mushroom")
			if success:
				print("      ✅ Mushroom planted at %s" % pos)
			else:
				print("      ❌ Failed to plant at %s (labor: %d)" % [pos, farm.economy.get_resource("👥")])

		print("\n   ⏳ Waiting 60s for growth...")
		_advance_all_biomes(60.0)

		print("\n   🔬 Measuring all 3 mushrooms")
		for x in range(3):
			var pos = Vector2i(x, 1)
			var outcome = farm.measure_plot(pos)
			print("      %s: %s" % [pos, outcome])

		print("\n   ✂️  Harvesting all 3 mushrooms")
		for x in range(3):
			var pos = Vector2i(x, 1)
			var result = farm.harvest_plot(pos)
			if result.get("success"):
				var outcome = result.get("outcome")
				print("      %s: %s → %d credits" % [pos, outcome, result.get("yield")])

				if outcome == "🍄":
					mushroom_harvests += 1
				elif outcome == "🍂":
					detritus_harvests += 1
	else:
		print("   ⚠️  Not enough labor to plant more mushrooms (need 3, have %d)" % labor)
		print("      Skipping multi-plot test")


func _advance_all_biomes(seconds: float):
	"""Advance quantum evolution in all biomes"""
	for biome_name in farm.grid.biomes.keys():
		var biome = farm.grid.biomes[biome_name]
		biome.advance_simulation(seconds)
	game_time += seconds


func _debug_plot_state(pos: Vector2i):
	"""Print detailed plot state for debugging"""
	var plot = farm.grid.get_plot(pos)
	if not plot:
		print("     ⚠️  Plot %s does not exist!" % pos)
		return

	var plant_type = "unknown"
	if plot.quantum_state:
		var emojis = plot.get_plot_emojis()
		plant_type = "%s↔%s" % [emojis.north, emojis.south]

	print("     🔍 Plot %s (%s): planted=%s, measured=%s" % [pos, plant_type, plot.is_planted, plot.has_been_measured])

	if plot.quantum_state:
		print("        Quantum: radius=%.3f, theta=%.2f, phi=%.2f" % [
			plot.quantum_state.radius,
			plot.quantum_state.theta,
			plot.quantum_state.phi
		])
		print("        Semantic: %s" % plot.get_dominant_emoji())
		print("        Energy: %.3f" % plot.quantum_state.energy)


func _print_final_report():
	print("\n" + "=".repeat(80))
	print("📊 MUSHROOM FARMING EXPERIMENT COMPLETE - FINAL REPORT")
	print("=".repeat(80))

	# Resources
	var wheat = farm.economy.get_resource("🌾")
	var labor = farm.economy.get_resource("👥")
	var mushroom = farm.economy.get_resource("🍄")
	var detritus = farm.economy.get_resource("🍂")

	print("\n💰 Final Resources:")
	print("   🌾 Wheat: %d credits" % wheat)
	print("   👥 Labor: %d credits" % labor)
	print("   🍄 Mushroom: %d credits" % mushroom)
	print("   🍂 Detritus: %d credits" % detritus)

	# Harvest statistics
	var total_mushroom_harvests = mushroom_harvests + detritus_harvests
	print("\n🍄 Mushroom Harvest Statistics:")
	print("   Total harvests: %d" % total_mushroom_harvests)
	if total_mushroom_harvests > 0:
		print("   Mushroom (🍄): %d (%.1f%%)" % [mushroom_harvests, 100.0 * mushroom_harvests / total_mushroom_harvests])
		print("   Detritus (🍂): %d (%.1f%%)" % [detritus_harvests, 100.0 * detritus_harvests / total_mushroom_harvests])

	# Economic analysis
	print("\n📈 Economic Analysis:")
	print("   Labor economy viable: %s" % ("✅ YES" if labor >= 1 else "❌ NO"))
	print("   Mushroom credits gained: %d" % mushroom)
	print("   Detritus credits gained: %d" % detritus)

	# Goals
	print("\n🎯 Goals Progress:")
	for i in range(farm.goals.goals.size()):
		var goal = farm.goals.goals[i]
		var progress_type = goal["type"]
		var current_val = 0

		if progress_type == "harvest_count":
			current_val = farm.goals.progress["harvest_count"]
		elif progress_type == "total_wheat_harvested":
			current_val = farm.goals.progress["total_wheat_harvested"]
		elif progress_type == "wheat_inventory":
			current_val = wheat
		elif progress_type == "entanglement_count":
			current_val = farm.goals.progress["entanglement_count"]

		var target = goal["target"]
		var progress_pct = 100.0 * current_val / target
		var status = "✅" if current_val >= target else "🔄"
		print("   %s %s: %d/%d (%.1f%%)" % [status, goal["title"], current_val, target, progress_pct])

	print("\n" + "=".repeat(80))
