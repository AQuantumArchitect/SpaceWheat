extends SceneTree

## 🏃 CLAUDE FARMS MARATHON - Unlock All Achievements!
## Goal: Complete "Wheat Baron" (50 wheat) and explore entanglements

const Farm = preload("res://Core/Farm.gd")

var farm: Farm
var current_turn: int = 0
var game_time: float = 0.0

# Strategy state
var planted_plots: Array[Vector2i] = []
var plots_plant_time: Dictionary = {}

# Statistics
var total_turns_played: int = 0
var wheat_harvests: int = 0
var labor_harvests: int = 0


func _initialize():
	print("\n" + "=".repeat(80))
	print("🏃 CLAUDE FARMS MARATHON - Achievement Sprint!")
	print("=".repeat(80))
	print("Mission:")
	print("  1. Unlock 'Wheat Baron' (50 wheat credits harvested)")
	print("  2. Explore entanglement system")
	print("  3. Find and document any bugs")
	print("  4. Test all biomes")
	print("=".repeat(80) + "\n")

	await get_root().ready
	await _setup_game()

	print("\n📋 STRATEGY: Optimized wheat farming")
	print("   - Maximum plot utilization (12 plots)")
	print("   - Optimal evolution time (40s)")
	print("   - Fast harvest cycles")
	print("   - Track statistics\n")

	# Play until we unlock Wheat Baron or 100 turns
	var wheat_baron_unlocked = false
	while current_turn < 100 and not wheat_baron_unlocked:
		await _play_turn()

		# Check for Wheat Baron completion
		if farm.goals.progress["total_wheat_harvested"] >= 50:
			wheat_baron_unlocked = true
			print("\n" + "=".repeat(80))
			print("🎉 WHEAT BARON UNLOCKED! 🎉")
			print("=".repeat(80))
			print("Total turns: %d" % current_turn)
			print("Wheat harvests: %d" % wheat_harvests)
			print("Labor harvests: %d" % labor_harvests)
			print("=".repeat(80) + "\n")

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


func _play_turn():
	"""Play one optimized farming turn"""
	current_turn += 1

	# Compact turn display every 10 turns
	if current_turn % 10 == 1:
		print("──────────────────────────────────────────────────────────────────────")
		print("🎮 TURNS %d-%d" % [current_turn, current_turn + 9])
		print("──────────────────────────────────────────────────────────────────────")

	_decide_action()
	await process_frame


func _decide_action():
	"""Optimized farming strategy for maximum wheat production"""
	var can_plant = farm.economy.get_resource("🌾") >= 1
	var empty_count = _count_empty_plots()
	var has_mature = _has_mature_plots()

	# Priority: Harvest → Measure → Plant → Wait
	if has_mature:
		var mature_pos = _find_mature_plot()
		var plot = farm.grid.get_plot(mature_pos)

		if plot.has_been_measured:
			# Harvest
			var result = farm.harvest_plot(mature_pos)
			if result.get("success"):
				var outcome = result.get("outcome")
				if outcome == "🌾":
					wheat_harvests += 1
				elif outcome == "👥":
					labor_harvests += 1

				planted_plots.erase(mature_pos)
				plots_plant_time.erase(mature_pos)

				# Progress update every 10 wheat
				if wheat_harvests % 10 == 0 and wheat_harvests > 0:
					print("   📈 Progress: %d wheat harvested (goal: 50)" % farm.goals.progress["total_wheat_harvested"])
		else:
			# Measure
			farm.measure_plot(mature_pos)

	elif can_plant and empty_count > 0:
		# Plant as many as possible (fill the farm)
		var plants_this_turn = 0
		while farm.economy.get_resource("🌾") >= 1 and _count_empty_plots() > 0 and plants_this_turn < 6:
			var pos = _find_empty_plot()
			if pos != Vector2i(-1, -1):
				var success = farm.build(pos, "wheat")
				if success:
					planted_plots.append(pos)
					plots_plant_time[pos] = game_time
					plants_this_turn += 1

		if current_turn % 10 == 1:
			print("   🌱 Planted %d plots" % plants_this_turn)

	elif planted_plots.size() > 0:
		# Wait for quantum evolution (40s = optimal for 2x growth)
		for biome_name in farm.grid.biomes.keys():
			farm.grid.biomes[biome_name].advance_simulation(40.0)
		game_time += 40.0


func _count_empty_plots() -> int:
	var count = 0
	for y in range(farm.grid.grid_height):
		for x in range(farm.grid.grid_width):
			var pos = Vector2i(x, y)
			var plot = farm.grid.get_plot(pos)
			if plot and not plot.is_planted:
				count += 1
	return count


func _find_empty_plot() -> Vector2i:
	for y in range(farm.grid.grid_height):
		for x in range(farm.grid.grid_width):
			var pos = Vector2i(x, y)
			var plot = farm.grid.get_plot(pos)
			if plot and not plot.is_planted:
				return pos
	return Vector2i(-1, -1)


func _has_mature_plots() -> bool:
	for pos in planted_plots:
		var time_since_plant = game_time - plots_plant_time.get(pos, game_time)
		if time_since_plant >= 40.0:
			return true
	return false


func _find_mature_plot() -> Vector2i:
	for pos in planted_plots:
		var time_since_plant = game_time - plots_plant_time.get(pos, game_time)
		if time_since_plant >= 40.0:
			return pos
	return Vector2i(-1, -1)


func _print_final_report():
	print("\n" + "=".repeat(80))
	print("📊 MARATHON COMPLETE - FINAL STATISTICS")
	print("=".repeat(80))

	# Resources
	var wheat = farm.economy.get_resource("🌾")
	var labor = farm.economy.get_resource("👥")
	print("\n💰 Final Resources:")
	print("   🌾 Wheat: %d credits" % wheat)
	print("   👥 Labor: %d credits" % labor)

	# Harvests
	print("\n🌾 Harvest Statistics:")
	print("   Total harvests: %d" % farm.goals.progress["harvest_count"])
	print("   Wheat harvests: %d (%.1f%%)" % [wheat_harvests, 100.0 * wheat_harvests / max(1, farm.goals.progress["harvest_count"])])
	print("   Labor harvests: %d (%.1f%%)" % [labor_harvests, 100.0 * labor_harvests / max(1, farm.goals.progress["harvest_count"])])
	print("   Total wheat credits earned: %d" % farm.goals.progress["total_wheat_harvested"])

	# Efficiency
	var turns_per_harvest = float(current_turn) / max(1, farm.goals.progress["harvest_count"])
	var credits_per_turn = float(farm.goals.progress["total_wheat_harvested"]) / max(1, current_turn)
	print("\n⚡ Efficiency:")
	print("   Turns per harvest: %.2f" % turns_per_harvest)
	print("   Wheat credits per turn: %.2f" % credits_per_turn)
	print("   Total turns played: %d" % current_turn)
	print("   Game time: %.1f days" % (game_time / 20.0))

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
