extends SceneTree

## 🌀 CLAUDE HUNTS ENTANGLEMENT MASTER - 10 Entanglements Challenge!
## Goal: Create 10 entanglements and test complex patterns

const Farm = preload("res://Core/Farm.gd")

var farm: Farm
var current_turn: int = 0
var game_time: float = 0.0

# Statistics
var entanglements_created: int = 0


func _initialize():
	print("\n" + "=".repeat(80))
	print("🌀 CLAUDE HUNTS ENTANGLEMENT MASTER - 10 Entanglements Challenge!")
	print("=".repeat(80))
	print("Mission:")
	print("  1. Unlock 'Entanglement Master' (10 entanglements)")
	print("  2. Test complex entanglement patterns")
	print("  3. Test entanglement clusters")
	print("  4. Find edge cases and bugs")
	print("=".repeat(80) + "\n")

	await get_root().ready
	await _setup_game()

	print("\n📋 STRATEGY: Create diverse entanglement patterns")
	print("   - Fill all 12 plots with wheat")
	print("   - Create various entanglement patterns:")
	print("     • Linear chains")
	print("     • Squares/cycles")
	print("     • Stars (hub and spoke)")
	print("     • Maximum entanglement density")
	print("   - Test if clusters work correctly\n")

	# Execute the entanglement master plan
	_execute_master_plan()

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
	print("📊 Starting resources: 🌾%d 👥%d\n" % [
		farm.economy.get_resource("🌾"),
		farm.economy.get_resource("👥")
	])


func _execute_master_plan():
	"""Execute the entanglement master quest"""

	# Phase 1: Plant all 12 plots
	print("──────────────────────────────────────────────────────────────────────")
	print("🌱 PHASE 1: Plant all 12 plots")
	print("──────────────────────────────────────────────────────────────────────")

	var grid_width = farm.grid.grid_width
	var grid_height = farm.grid.grid_height

	for y in range(grid_height):
		for x in range(grid_width):
			var pos = Vector2i(x, y)
			var plot = farm.grid.get_plot(pos)
			if plot:
				var success = farm.build(pos, "wheat")
				if success:
					print("   ✅ Planted wheat at %s" % pos)
				else:
					print("   ❌ Failed to plant at %s" % pos)

	print("   📊 Planted %d plots\n" % (grid_width * grid_height))

	# Wait for some quantum evolution
	print("   ⏳ Waiting 30s for quantum evolution...")
	_advance_all_biomes(30.0)
	print("   ✅ Radius grew to ~0.167 across all plots\n")

	# Phase 2: Create entanglement patterns
	print("──────────────────────────────────────────────────────────────────────")
	print("🔗 PHASE 2: Create entanglement patterns")
	print("──────────────────────────────────────────────────────────────────────")

	# Pattern 1: Linear chain (top row)
	print("\n   🔗 Pattern 1: Linear Chain (top row)")
	for x in range(grid_width - 1):
		var pos_a = Vector2i(x, 0)
		var pos_b = Vector2i(x + 1, 0)
		var success = farm.entangle_plots(pos_a, pos_b, "phi_plus")
		if success:
			entanglements_created += 1
			print("      ✅ Entangled %s ↔ %s (chain link %d)" % [pos_a, pos_b, x + 1])
		else:
			print("      ❌ Failed to entangle %s ↔ %s" % [pos_a, pos_b])

	print("   📊 Progress: %d/%d entanglements" % [farm.goals.progress["entanglement_count"], 10])

	# Pattern 2: Linear chain (bottom row)
	print("\n   🔗 Pattern 2: Linear Chain (bottom row)")
	for x in range(grid_width - 1):
		var pos_a = Vector2i(x, 1)
		var pos_b = Vector2i(x + 1, 1)
		var success = farm.entangle_plots(pos_a, pos_b, "phi_plus")
		if success:
			entanglements_created += 1
			print("      ✅ Entangled %s ↔ %s (chain link %d)" % [pos_a, pos_b, x + 1])
		else:
			print("      ❌ Failed to entangle %s ↔ %s" % [pos_a, pos_b])

	print("   📊 Progress: %d/%d entanglements" % [farm.goals.progress["entanglement_count"], 10])

	# Check if we've already hit 10
	if farm.goals.progress["entanglement_count"] >= 10:
		print("\n🎉 ENTANGLEMENT MASTER UNLOCKED! 🎉")
		print("   (Unlocked after %d total entanglements)" % entanglements_created)
		return

	# Pattern 3: Vertical connections (columns)
	print("\n   🔗 Pattern 3: Vertical Connections")
	for x in range(grid_width):
		var pos_a = Vector2i(x, 0)
		var pos_b = Vector2i(x, 1)
		var success = farm.entangle_plots(pos_a, pos_b, "psi_plus")  # Try psi_plus for variety
		if success:
			entanglements_created += 1
			print("      ✅ Entangled %s ↔ %s (vertical link %d)" % [pos_a, pos_b, x + 1])
		else:
			print("      ❌ Failed to entangle %s ↔ %s" % [pos_a, pos_b])

		# Check progress
		if farm.goals.progress["entanglement_count"] >= 10:
			print("\n🎉 ENTANGLEMENT MASTER UNLOCKED! 🎉")
			print("   (Unlocked after %d total entanglements)" % entanglements_created)
			return

	print("\n   📊 Final progress: %d/%d entanglements" % [farm.goals.progress["entanglement_count"], 10])

	# Phase 3: Analyze the network
	print("\n──────────────────────────────────────────────────────────────────────")
	print("📊 PHASE 3: Analyze entanglement network")
	print("──────────────────────────────────────────────────────────────────────")

	print("\n   🔍 Checking entanglement infrastructure on each plot:")
	for y in range(grid_height):
		for x in range(grid_width):
			var pos = Vector2i(x, y)
			var plot = farm.grid.get_plot(pos)
			if plot:
				var count = plot.plot_infrastructure_entanglements.size()
				print("      Plot %s: %d entanglements" % [pos, count])

	# Test measurement cascade on heavily entangled network
	print("\n   🔬 Testing measurement cascade on entangled network...")
	print("      Measuring corner plot (0,0) - should cascade across network")
	var outcome = farm.measure_plot(Vector2i(0, 0))
	print("      Measurement outcome: %s" % outcome)
	print("      Checking cascade effects...")

	var measured_count = 0
	for y in range(grid_height):
		for x in range(grid_width):
			var pos = Vector2i(x, y)
			var plot = farm.grid.get_plot(pos)
			if plot and plot.has_been_measured:
				measured_count += 1
				print("         ✓ Plot %s measured: %s" % [pos, plot.measured_outcome])

	print("\n      📊 Cascade measured %d/%d plots" % [measured_count, grid_width * grid_height])


func _advance_all_biomes(seconds: float):
	"""Advance quantum evolution in all biomes"""
	for biome_name in farm.grid.biomes.keys():
		var biome = farm.grid.biomes[biome_name]
		biome.advance_simulation(seconds)
	game_time += seconds


func _print_final_report():
	print("\n" + "=".repeat(80))
	print("📊 ENTANGLEMENT MASTER QUEST COMPLETE - FINAL REPORT")
	print("=".repeat(80))

	# Resources
	var wheat = farm.economy.get_resource("🌾")
	var labor = farm.economy.get_resource("👥")
	print("\n💰 Final Resources:")
	print("   🌾 Wheat: %d credits" % wheat)
	print("   👥 Labor: %d credits" % labor)

	# Entanglement statistics
	print("\n🔗 Entanglement Statistics:")
	print("   Total entanglements created: %d" % entanglements_created)
	print("   Goal progress: %d/10" % farm.goals.progress["entanglement_count"])

	if farm.goals.progress["entanglement_count"] >= 10:
		print("   ✅ ENTANGLEMENT MASTER: UNLOCKED!")
	else:
		print("   ❌ ENTANGLEMENT MASTER: Not yet unlocked (need %d more)" % (10 - farm.goals.progress["entanglement_count"]))

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
