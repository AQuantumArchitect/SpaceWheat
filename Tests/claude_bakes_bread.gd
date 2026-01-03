extends SceneTree

## 🍞 CLAUDE BAKES BREAD - Kitchen Triplet Entanglement Test!
## Goal: Test 3-qubit triplet entanglement → bread production

const Farm = preload("res://Core/Farm.gd")

var farm: Farm
var game_time: float = 0.0

# Statistics
var bread_attempts: int = 0
var bread_successes: int = 0


func _initialize():
	print("\n" + "=".repeat(80))
	print("🍞 CLAUDE BAKES BREAD - Kitchen Triplet Entanglement Test!")
	print("=".repeat(80))
	print("Mission:")
	print("  1. Test triplet entanglement (3-qubit Bell states)")
	print("  2. Create bread from 3 entangled wheat plots")
	print("  3. Test kitchen measurement mechanics")
	print("  4. Hunt for bugs in bread production")
	print("=".repeat(80) + "\n")

	await get_root().ready
	await _setup_game()

	print("\n📋 STRATEGY: Triplet entanglement bread production")
	print("   - Plant 3 wheat plots in kitchen biome")
	print("   - Create triplet entanglement between them")
	print("   - Evolve the entangled state")
	print("   - Measure to produce bread")
	print("   - Test if bread is produced\n")

	# Execute bread baking experiment
	_execute_bread_baking()

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
	print("📊 Starting resources: 🌾%d 👥%d 🍞%d\n" % [
		farm.economy.get_resource("🌾"),
		farm.economy.get_resource("👥"),
		farm.economy.get_resource("🍞")
	])


func _execute_bread_baking():
	"""Execute the bread baking experiment"""

	print("──────────────────────────────────────────────────────────────────────")
	print("🌱 PHASE 1: Find kitchen biome plots")
	print("──────────────────────────────────────────────────────────────────────")

	# Find plots in kitchen biome
	var kitchen_plots: Array[Vector2i] = []
	var grid_width = farm.grid.grid_width
	var grid_height = farm.grid.grid_height

	for y in range(grid_height):
		for x in range(grid_width):
			var pos = Vector2i(x, y)
			var biome = farm.grid.get_biome_for_plot(pos)
			if biome and biome.get_biome_type() == "QuantumKitchen":
				kitchen_plots.append(pos)
				print("   ✅ Found kitchen plot: %s" % pos)

	print("\n   📊 Total kitchen plots: %d" % kitchen_plots.size())

	if kitchen_plots.size() < 3:
		print("   ❌ ERROR: Need at least 3 kitchen plots for triplet entanglement!")
		print("      Found only %d kitchen plots" % kitchen_plots.size())
		return

	# Select first 3 kitchen plots for triplet
	var triplet_plots = [kitchen_plots[0], kitchen_plots[1], kitchen_plots[2]]
	print("   🎯 Selected triplet: %s, %s, %s" % [triplet_plots[0], triplet_plots[1], triplet_plots[2]])

	# Phase 2: Plant wheat in kitchen plots
	print("\n──────────────────────────────────────────────────────────────────────")
	print("🌱 PHASE 2: Plant wheat in kitchen plots")
	print("──────────────────────────────────────────────────────────────────────")

	for pos in triplet_plots:
		var success = farm.build(pos, "wheat")
		if success:
			print("   ✅ Planted wheat at %s" % pos)
		else:
			print("   ❌ Failed to plant wheat at %s" % pos)
			return

	# Wait for quantum evolution
	print("\n   ⏳ Waiting 30s for quantum evolution...")
	_advance_all_biomes(30.0)

	# Check plot states
	print("\n   📊 Plot states after evolution:")
	for pos in triplet_plots:
		_debug_plot_state(pos)

	# Phase 3: Create triplet entanglement
	print("\n──────────────────────────────────────────────────────────────────────")
	print("🔗 PHASE 3: Create triplet entanglement")
	print("──────────────────────────────────────────────────────────────────────")

	print("\n   🔗 Creating triplet entanglement: %s ↔ %s ↔ %s" % [triplet_plots[0], triplet_plots[1], triplet_plots[2]])

	var success = farm.grid.create_triplet_entanglement(triplet_plots[0], triplet_plots[1], triplet_plots[2])

	if success:
		print("      ✅ Triplet entanglement created!")
	else:
		print("      ❌ Triplet entanglement failed!")
		return

	# Phase 4: Measure to produce bread
	print("\n──────────────────────────────────────────────────────────────────────")
	print("🔬 PHASE 4: Measure triplet to produce bread")
	print("──────────────────────────────────────────────────────────────────────")

	bread_attempts += 1

	print("\n   🔬 Measuring first plot: %s" % triplet_plots[0])
	var outcome1 = farm.measure_plot(triplet_plots[0])
	print("      Outcome: %s" % outcome1)

	print("\n   🔬 Measuring second plot: %s" % triplet_plots[1])
	var outcome2 = farm.measure_plot(triplet_plots[1])
	print("      Outcome: %s" % outcome2)

	print("\n   🔬 Measuring third plot: %s" % triplet_plots[2])
	var outcome3 = farm.measure_plot(triplet_plots[2])
	print("      Outcome: %s" % outcome3)

	print("\n   📊 Triplet measurement outcomes: %s, %s, %s" % [outcome1, outcome2, outcome3])

	# Check if bread was produced
	var bread_before = farm.economy.get_resource("🍞")
	print("\n   💰 Bread credits before harvest: %d" % bread_before)

	# Harvest all 3 plots
	print("\n   ✂️  Harvesting triplet...")
	for pos in triplet_plots:
		var result = farm.harvest_plot(pos)
		if result.get("success"):
			print("      %s: %s → %d credits" % [pos, result.get("outcome"), result.get("yield")])

	var bread_after = farm.economy.get_resource("🍞")
	var bread_produced = bread_after - bread_before

	print("\n   📊 Results:")
	print("      Bread before: %d" % bread_before)
	print("      Bread after: %d" % bread_after)
	print("      Bread produced: %d" % bread_produced)

	if bread_produced > 0:
		print("      ✅ BREAD PRODUCTION SUCCESSFUL! 🍞")
		bread_successes += 1
	else:
		print("      ❌ No bread produced from triplet measurement")

	# Phase 5: Test multiple triplets
	print("\n──────────────────────────────────────────────────────────────────────")
	print("🔄 PHASE 5: Test multiple triplet attempts")
	print("──────────────────────────────────────────────────────────────────────")

	if kitchen_plots.size() >= 6:
		print("\n   🔗 Creating second triplet with remaining plots")

		# Select next 3 kitchen plots
		var triplet2 = [kitchen_plots[3], kitchen_plots[4], kitchen_plots[5]]
		print("   🎯 Triplet 2: %s, %s, %s" % [triplet2[0], triplet2[1], triplet2[2]])

		# Plant wheat
		for pos in triplet2:
			farm.build(pos, "wheat")

		_advance_all_biomes(30.0)

		# Create entanglement
		var success2 = farm.grid.create_triplet_entanglement(triplet2[0], triplet2[1], triplet2[2])
		print("   Entanglement: %s" % ("✅ Created" if success2 else "❌ Failed"))

		if success2:
			bread_attempts += 1

			# Measure all 3
			for pos in triplet2:
				farm.measure_plot(pos)

			var bread_before2 = farm.economy.get_resource("🍞")

			# Harvest all 3
			for pos in triplet2:
				farm.harvest_plot(pos)

			var bread_after2 = farm.economy.get_resource("🍞")
			var bread_produced2 = bread_after2 - bread_before2

			if bread_produced2 > 0:
				print("   ✅ Triplet 2: Produced %d bread!" % bread_produced2)
				bread_successes += 1
			else:
				print("   ❌ Triplet 2: No bread produced")
	else:
		print("\n   ⚠️  Not enough kitchen plots for second triplet (need 6, have %d)" % kitchen_plots.size())


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

	var biome = farm.grid.get_biome_for_plot(pos)
	var biome_name = biome.get_biome_type() if biome else "unknown"

	print("     🔍 Plot %s (%s): planted=%s, measured=%s" % [pos, biome_name, plot.is_planted, plot.has_been_measured])

	if plot.quantum_state:
		print("        Quantum: radius=%.3f, theta=%.2f" % [plot.quantum_state.radius, plot.quantum_state.theta])
		print("        Semantic: %s" % plot.get_dominant_emoji())


func _print_final_report():
	print("\n" + "=".repeat(80))
	print("📊 BREAD BAKING EXPERIMENT COMPLETE - FINAL REPORT")
	print("=".repeat(80))

	# Resources
	var wheat = farm.economy.get_resource("🌾")
	var bread = farm.economy.get_resource("🍞")

	print("\n💰 Final Resources:")
	print("   🌾 Wheat: %d credits" % wheat)
	print("   🍞 Bread: %d credits" % bread)

	# Bread production statistics
	print("\n🍞 Bread Production Statistics:")
	print("   Triplet attempts: %d" % bread_attempts)
	print("   Successful: %d" % bread_successes)
	if bread_attempts > 0:
		print("   Success rate: %.1f%%" % (100.0 * bread_successes / bread_attempts))

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
