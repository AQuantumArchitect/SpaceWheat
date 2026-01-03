extends SceneTree

## 🎮💾 CLAUDE PLAYS WITH SAVES - BRANCHING TIMELINES!
## Play to Turn 5 → SAVE → Try 2 different strategies → Compare!

const Farm = preload("res://Core/Farm.gd")
const GameStateManager = preload("res://Core/GameState/GameStateManager.gd")

var farm: Farm
var gsm: GameStateManager
var current_turn: int = 0
var game_time: float = 0.0

# Play state
var my_planted_plots: Array[Vector2i] = []
var my_measured_plots: Array[Vector2i] = []
var plots_plant_time: Dictionary = {}

# Strategy tracking
var current_strategy: String = "CONSERVATIVE"
var timeline: String = "PRIME"

func _initialize():
	print("\n" + "=".repeat(80))
	print("🎮💾 CLAUDE PLAYS SPACEWHEAT - BRANCHING TIMELINES EXPERIMENT!")
	print("=".repeat(80))
	print("Plan:")
	print("  1. Play conservatively to Turn 5")
	print("  2. SAVE to slot 1")
	print("  3. Continue conservatively to Turn 10 (Timeline A)")
	print("  4. LOAD from slot 1")
	print("  5. Play aggressively to Turn 10 (Timeline B)")
	print("  6. Compare outcomes!")
	print("=".repeat(80) + "\n")

	await get_root().ready
	await _setup_game()

	# TIMELINE A: Conservative all the way
	print("\n🌟 TIMELINE ALPHA: Conservative Strategy")
	print("=".repeat(80))
	current_strategy = "CONSERVATIVE"
	timeline = "ALPHA"

	# Play to Turn 5
	for i in range(5):
		await _play_turn()

	# SAVE GAME
	print("\n💾 CHECKPOINT: Saving game state at Turn 5...")
	var save_success = gsm.save_game(1)
	if save_success:
		print("✅ Saved to slot 1!")
	else:
		print("❌ Save failed!")

	var alpha_turn_5_resources = _capture_resources()

	# Continue to Turn 10
	for i in range(5):
		await _play_turn()

	var alpha_final_resources = _capture_resources()

	# Show Timeline A results
	print("\n" + "=".repeat(80))
	print("📊 TIMELINE ALPHA RESULTS (Conservative → Conservative)")
	print("=".repeat(80))
	print("  Turn 5 resources: %s" % _format_resources(alpha_turn_5_resources))
	print("  Turn 10 resources: %s" % _format_resources(alpha_final_resources))
	print("  Net gain: %s" % _format_resource_diff(alpha_turn_5_resources, alpha_final_resources))
	print("=".repeat(80) + "\n")

	# TIMELINE B: Load and go aggressive
	print("\n💾 LOADING from Turn 5 checkpoint...")

	# Reload state into existing farm (no need to recreate farm!)
	var load_success = gsm.load_and_apply(1)
	if load_success:
		print("✅ Loaded from slot 1!")
		# farm reference stays the same, state has been restored
		for i in range(10):
			await process_frame
	else:
		print("❌ Load failed!")
		_end_game()
		return

	# Reset play state
	current_turn = 5
	game_time = 100.0  # Approximation
	my_planted_plots.clear()
	my_measured_plots.clear()
	plots_plant_time.clear()

	print("\n🌟 TIMELINE BETA: Aggressive Strategy")
	print("=".repeat(80))
	current_strategy = "AGGRESSIVE"
	timeline = "BETA"

	var beta_turn_5_resources = _capture_resources()

	# Play aggressively to Turn 10
	for i in range(5):
		await _play_turn()

	var beta_final_resources = _capture_resources()

	# Show Timeline B results
	print("\n" + "=".repeat(80))
	print("📊 TIMELINE BETA RESULTS (Conservative → Aggressive)")
	print("=".repeat(80))
	print("  Turn 5 resources: %s" % _format_resources(beta_turn_5_resources))
	print("  Turn 10 resources: %s" % _format_resources(beta_final_resources))
	print("  Net gain: %s" % _format_resource_diff(beta_turn_5_resources, beta_final_resources))
	print("=".repeat(80) + "\n")

	# COMPARE
	print("\n" + "=".repeat(80))
	print("🏆 TIMELINE COMPARISON")
	print("=".repeat(80))
	print("\n📊 Starting from same Turn 5 save:")
	print("  Alpha (Conservative): %s" % _format_resource_diff(alpha_turn_5_resources, alpha_final_resources))
	print("  Beta (Aggressive):    %s" % _format_resource_diff(beta_turn_5_resources, beta_final_resources))

	var winner = _determine_winner(alpha_final_resources, beta_final_resources)
	print("\n🏆 WINNER: %s!" % winner)
	print("=".repeat(80) + "\n")

	_end_game()

func _setup_game():
	print("Setting up game world...")

	# Create GameStateManager first
	gsm = GameStateManager.new()
	get_root().add_child(gsm)
	await process_frame

	# Create farm
	farm = Farm.new()
	get_root().add_child(farm)
	for i in range(10):
		await process_frame

	# Register with save system
	gsm.active_farm = farm

	print("✅ Game world ready!\n")

func _play_turn():
	"""Play one turn with current strategy"""

	current_turn += 1

	print("\n──────────────────────────────────────────────────────────────────────")
	print("🎮 TURN %d | Timeline: %s | Strategy: %s" % [current_turn, timeline, current_strategy])
	print("──────────────────────────────────────────────────────────────────────")

	_observe_state()
	_decide_action()

	await process_frame

func _observe_state():
	"""Show current game state"""

	print("\n📊 STATE:")
	print("   ⏰ Time: %.1f days" % (game_time / 20.0))
	print("   💰 Wheat: %d | Labor: %d" % [
		farm.economy.get_resource("🌾"),
		farm.economy.get_resource("👥")
	])

	var empty = 0
	var planted = 0
	var measured = 0

	for y in range(farm.grid.grid_height):
		for x in range(farm.grid.grid_width):
			var pos = Vector2i(x, y)
			var plot = farm.grid.get_plot(pos)
			if plot:
				if not plot.is_planted:
					empty += 1
				elif not plot.has_been_measured:
					planted += 1
				else:
					measured += 1

	print("   🗺️  Empty: %d | Planted: %d | Measured: %d" % [empty, planted, measured])

func _decide_action():
	"""Make decision based on current strategy"""

	var can_plant = farm.economy.get_resource("🌾") >= 1  # Planting costs 1 credit now
	var has_empty = _count_empty_plots() > 0
	var has_unmeasured = _count_unmeasured_plots() > 0
	var has_measured = _count_measured_plots() > 0
	var has_mature = _has_mature_plots()

	if current_strategy == "CONSERVATIVE":
		# Conservative: Wait for maturity, measure carefully, harvest everything
		if has_measured:
			print("   💡 [CONSERVATIVE] Harvest measured plots")
			_action_harvest()
		elif has_mature:
			print("   💡 [CONSERVATIVE] Measure mature plot")
			_action_measure()
		elif has_unmeasured:
			print("   💡 [CONSERVATIVE] Wait for maturity (3 days)")
			_action_wait(60.0)
		elif can_plant and has_empty and my_planted_plots.size() < 2:
			print("   💡 [CONSERVATIVE] Plant ONE plot, will wait for maturity")
			_action_plant()
		else:
			print("   💡 [CONSERVATIVE] Wait")
			_action_wait(20.0)

	elif current_strategy == "AGGRESSIVE":
		# Aggressive: Plant many, measure early, rapid turnover
		if has_measured:
			print("   💡 [AGGRESSIVE] Quick harvest!")
			_action_harvest()
		elif has_unmeasured:
			print("   💡 [AGGRESSIVE] Measure IMMEDIATELY (no wait)")
			_action_measure()
		elif can_plant and has_empty:
			print("   💡 [AGGRESSIVE] Plant MAXIMUM plots!")
			# Plant up to 4 plots at once
			for i in range(min(4, _count_empty_plots())):
				if farm.economy.get_resource("🌾") >= 1:  # Planting costs 1 credit now
					_action_plant()
		else:
			print("   💡 [AGGRESSIVE] Quick wait")
			_action_wait(10.0)

func _action_plant():
	"""Plant wheat"""
	var pos = _find_empty_plot()
	if pos == Vector2i(-1, -1):
		return

	var success = farm.build(pos, "wheat")
	if success:
		my_planted_plots.append(pos)
		plots_plant_time[pos] = game_time
		print("   ✅ Planted at %s" % pos)

func _action_measure():
	"""Measure a plot"""
	var pos = _find_unmeasured_plot()
	if pos == Vector2i(-1, -1):
		return

	var outcome = farm.measure_plot(pos)
	if outcome:
		my_planted_plots.erase(pos)
		my_measured_plots.append(pos)
		print("   ✅ Measured %s: %s" % [pos, outcome])

func _action_harvest():
	"""Harvest a plot"""
	var pos = _find_measured_plot()
	if pos == Vector2i(-1, -1):
		return

	var result = farm.harvest_plot(pos)
	if result.get("success"):
		my_measured_plots.erase(pos)
		plots_plant_time.erase(pos)
		print("   ✅ Harvested: yield=%d" % result.get("yield", 0))

func _action_wait(seconds: float):
	"""Wait for quantum evolution"""
	print("   ⏰ Waiting %.0fs..." % seconds)

	# Advance ALL biomes for quantum evolution
	for biome_name in farm.grid.biomes.keys():
		var biome = farm.grid.biomes[biome_name]
		print("   🔄 Advancing %s simulation by %.1fs..." % [biome_name, seconds])
		biome.advance_simulation(seconds)

	game_time += seconds
	print("   ✅ Simulation advanced to %.1f days" % (game_time / 20.0))

# Helper functions
func _find_empty_plot() -> Vector2i:
	for y in range(farm.grid.grid_height):
		for x in range(farm.grid.grid_width):
			var pos = Vector2i(x, y)
			var plot = farm.grid.get_plot(pos)
			if plot and not plot.is_planted:
				return pos
	return Vector2i(-1, -1)

func _find_unmeasured_plot() -> Vector2i:
	for pos in my_planted_plots:
		return pos
	return Vector2i(-1, -1)

func _find_measured_plot() -> Vector2i:
	for pos in my_measured_plots:
		return pos
	return Vector2i(-1, -1)

func _count_empty_plots() -> int:
	var count = 0
	for y in range(farm.grid.grid_height):
		for x in range(farm.grid.grid_width):
			var pos = Vector2i(x, y)
			var plot = farm.grid.get_plot(pos)
			if plot and not plot.is_planted:
				count += 1
	return count

func _count_unmeasured_plots() -> int:
	return my_planted_plots.size()

func _count_measured_plots() -> int:
	return my_measured_plots.size()

func _has_mature_plots() -> bool:
	for pos in my_planted_plots:
		var time_since_plant = game_time - plots_plant_time.get(pos, game_time)
		if time_since_plant >= 60.0:
			return true
	return false

func _capture_resources() -> Dictionary:
	return {
		"wheat": farm.economy.get_resource("🌾"),
		"labor": farm.economy.get_resource("👥")
	}

func _format_resources(res: Dictionary) -> String:
	return "🌾%d 👥%d" % [res.get("wheat", 0), res.get("labor", 0)]

func _format_resource_diff(before: Dictionary, after: Dictionary) -> String:
	var wheat_gain = after.get("wheat", 0) - before.get("wheat", 0)
	var labor_gain = after.get("labor", 0) - before.get("labor", 0)
	return "🌾%+d 👥%+d" % [wheat_gain, labor_gain]

func _determine_winner(alpha: Dictionary, beta: Dictionary) -> String:
	var alpha_score = alpha.get("wheat", 0) + alpha.get("labor", 0) * 10
	var beta_score = beta.get("wheat", 0) + beta.get("labor", 0) * 10

	if alpha_score > beta_score:
		return "TIMELINE ALPHA (Conservative)"
	elif beta_score > alpha_score:
		return "TIMELINE BETA (Aggressive)"
	else:
		return "TIE"

func _end_game():
	print("\n✨ Experiment complete! Two timelines diverged from one save point.\n")
	quit(0)
