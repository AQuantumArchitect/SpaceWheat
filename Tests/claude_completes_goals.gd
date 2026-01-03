extends SceneTree

## 🎯 CLAUDE COMPLETES GOALS!
## Let's try to unlock all 6 achievements by playing strategically

const Farm = preload("res://Core/Farm.gd")

var farm: Farm
var current_turn: int = 0
var game_time: float = 0.0

# Strategy state
var planted_plots: Array[Vector2i] = []
var plots_plant_time: Dictionary = {}


func _initialize():
	print("\n" + "=".repeat(80))
	print("🎯 CLAUDE COMPLETES GOALS - Achievement Hunter Mode!")
	print("=".repeat(80))
	print("Goals to unlock:")
	print("  1. First Harvest (1 wheat)")
	print("  2. Profit Maker (200 wheat)")
	print("  3. Quantum Farmer (1 entanglement)")
	print("  4. Wheat Baron (50 total wheat)")
	print("  5. Entanglement Master (10 entanglements)")
	print("  6. Farm Tycoon (1000 wheat)")
	print("=".repeat(80) + "\n")

	await get_root().ready
	await _setup_game()

	# Play strategy: Focus on wheat production to unlock goals
	print("\n📋 STRATEGY: Fast wheat farming to unlock Profit Maker")
	print("   - Plant multiple plots")
	print("   - Fast evolution cycles")
	print("   - Harvest aggressively")
	print("   - Track goal progress\n")

	# Play for 30 turns or until we complete some goals
	for i in range(30):
		await _play_turn()

		# Check if we unlocked goals
		_check_goal_progress()

		# Pause if we completed a major goal
		if farm.goals.progress["total_wheat_harvested"] >= 50:
			print("\n🎉 Major milestone: 50 wheat harvested! Continuing...\n")

	# Final report
	print("\n" + "=".repeat(80))
	print("📊 FINAL STATISTICS")
	print("=".repeat(80))
	_print_final_stats()

	quit(0)


func _setup_game():
	print("Setting up game world...")

	# Create farm
	farm = Farm.new()
	get_root().add_child(farm)
	for i in range(10):
		await process_frame

	print("✅ Game world ready!\n")


func _play_turn():
	"""Play one turn focused on wheat production"""
	current_turn += 1

	print("──────────────────────────────────────────────────────────────────────")
	print("🎮 TURN %d" % current_turn)
	print("──────────────────────────────────────────────────────────────────────")

	_observe_state()
	_decide_action()

	await process_frame


func _observe_state():
	"""Show current game state and goal progress"""
	var wheat = farm.economy.get_resource("🌾")
	var labor = farm.economy.get_resource("👥")
	var harvested = farm.goals.progress["total_wheat_harvested"]

	print("📊 STATE:")
	print("   💰 Resources: 🌾%d 👥%d" % [wheat, labor])
	print("   📈 Progress: %d wheat harvested (goal: 50)" % harvested)
	print("   🗺️  Planted: %d plots" % planted_plots.size())


func _decide_action():
	"""Aggressive wheat farming strategy"""
	var can_plant = farm.economy.get_resource("🌾") >= 1
	var empty_count = _count_empty_plots()
	var unmeasured_count = planted_plots.size()
	var has_mature = _has_mature_plots()

	# Strategy priority:
	# 1. Harvest if we have mature plots
	# 2. Measure mature plots
	# 3. Plant aggressively (fill all empty plots)
	# 4. Wait for maturity

	if has_mature:
		var mature_pos = _find_mature_plot()
		var plot = farm.grid.get_plot(mature_pos)

		if plot.has_been_measured:
			# Harvest measured mature plot
			print("   🌾 Harvesting mature plot at %s" % mature_pos)
			var result = farm.harvest_plot(mature_pos)
			if result.get("success"):
				planted_plots.erase(mature_pos)
				plots_plant_time.erase(mature_pos)
				print("   ✅ Harvested: +%d credits (outcome: %s)" % [result.get("yield"), result.get("outcome")])
		else:
			# Measure mature plot
			print("   🔬 Measuring mature plot at %s" % mature_pos)
			var outcome = farm.measure_plot(mature_pos)
			print("   ✅ Measured: %s" % outcome)

	elif can_plant and empty_count > 0:
		# Plant as many as we can afford (aggressive expansion)
		var plants_this_turn = 0
		while farm.economy.get_resource("🌾") >= 1 and _count_empty_plots() > 0 and plants_this_turn < 3:
			var pos = _find_empty_plot()
			if pos != Vector2i(-1, -1):
				var success = farm.build(pos, "wheat")
				if success:
					planted_plots.append(pos)
					plots_plant_time[pos] = game_time
					plants_this_turn += 1

		print("   🌱 Planted %d plots (aggressive expansion)" % plants_this_turn)

	elif unmeasured_count > 0:
		# Wait for quantum evolution
		print("   ⏳ Waiting 40s for quantum evolution...")
		for biome_name in farm.grid.biomes.keys():
			farm.grid.biomes[biome_name].advance_simulation(40.0)
		game_time += 40.0

	else:
		print("   💤 Idle turn")


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
		if time_since_plant >= 40.0:  # Shorter maturity time for faster farming
			return true
	return false


func _find_mature_plot() -> Vector2i:
	for pos in planted_plots:
		var time_since_plant = game_time - plots_plant_time.get(pos, game_time)
		if time_since_plant >= 40.0:
			return pos
	return Vector2i(-1, -1)


func _check_goal_progress():
	"""Check and announce goal completions"""
	for i in range(farm.goals.goals.size()):
		var goal = farm.goals.goals[i]
		if not goal["completed"]:
			var progress_type = goal["type"]
			var current = 0

			if progress_type == "harvest_count":
				current = farm.goals.progress["harvest_count"]
			elif progress_type == "total_wheat_harvested":
				current = farm.goals.progress["total_wheat_harvested"]
			elif progress_type == "wheat_inventory":
				current = farm.economy.get_resource("🌾")
			elif progress_type == "entanglement_count":
				current = farm.goals.progress["entanglement_count"]

			var target = goal["target"]
			if current >= target and not farm.goals.goals_completed[i]:
				print("\n   🎉 GOAL UNLOCKED: %s!" % goal["title"])
				print("   💰 Reward: +%d credits\n" % goal["reward_credits"])


func _print_final_stats():
	var wheat = farm.economy.get_resource("🌾")
	var labor = farm.economy.get_resource("👥")
	var harvested = farm.goals.progress["total_wheat_harvested"]
	var harvest_count = farm.goals.progress["harvest_count"]

	print("Final Resources: 🌾%d 👥%d" % [wheat, labor])
	print("Total Harvests: %d" % harvest_count)
	print("Total Wheat Harvested: %d" % harvested)
	print("\nGoals Completed:")

	for i in range(farm.goals.goals.size()):
		var goal = farm.goals.goals[i]
		var progress_type = goal["type"]
		var current = 0

		if progress_type == "harvest_count":
			current = farm.goals.progress["harvest_count"]
		elif progress_type == "total_wheat_harvested":
			current = farm.goals.progress["total_wheat_harvested"]
		elif progress_type == "wheat_inventory":
			current = farm.economy.get_resource("🌾")
		elif progress_type == "entanglement_count":
			current = farm.goals.progress["entanglement_count"]

		var target = goal["target"]
		var status = "✅" if current >= target else "❌"
		print("  %s %s (%d/%d)" % [status, goal["title"], current, target])

	print("\n" + "=".repeat(80))
