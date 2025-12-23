## Helper class for save/load testing
## Provides reusable utilities - use via composition, not inheritance

extends Node

class_name SaveLoadHelper

# References
var farm_view: Node = null
var farm: Node = null
var biome: Node = null
var grid: Node = null
var economy: Node = null
var game_state_manager: Node = null

# Test log
var test_log: Array[String] = []

## ============================================================================
## INITIALIZATION
## ============================================================================

func initialize_game() -> bool:
	_log("🎮 Initializing game...")

	var scene = load("res://scenes/FarmView.tscn")
	if not scene:
		_error("Failed to load FarmView scene")
		return false

	farm_view = scene.instantiate()
	add_child(farm_view)

	# Wait for scene tree processing
	await get_tree().process_frame
	await get_tree().process_frame

	# Verify references
	farm = farm_view.farm
	if not farm:
		_error("Farm reference not found in FarmView")
		return false

	biome = farm.biome
	grid = farm.grid
	economy = farm.economy
	game_state_manager = get_tree().root.get_node_or_null("GameStateManager")

	if not (biome and grid and economy):
		_error("Missing core farm components")
		return false

	# Register with GameStateManager
	if game_state_manager:
		game_state_manager.active_farm_view = farm_view

	_log("✓ Game initialized successfully")
	return true

## ============================================================================
## BOARD SETUP
## ============================================================================

func plant_wheat_at(position: Vector2i) -> bool:
	"""Plant wheat at a specific grid position"""
	var plot = grid.get_plot(position)
	if not plot:
		_error("No plot at %s" % position)
		return false

	if plot.is_planted:
		_log("⚠ Plot already planted at %s" % position)
		return false

	var qubit = biome.create_quantum_state(position, "🌾", "🌱", PI/2)
	if not qubit:
		_error("Failed to create quantum state at %s" % position)
		return false

	plot.plant(qubit)
	_log("🌾 Planted wheat at %s" % [position])
	return true

func plant_wheat_cluster(positions: Array[Vector2i]) -> int:
	"""Plant wheat at multiple positions"""
	var count = 0
	for pos in positions:
		if plant_wheat_at(pos):
			count += 1
	_log("🌾 Planted %d wheat plots" % count)
	return count

func measure_plot(position: Vector2i) -> String:
	"""Measure (collapse) quantum state at position"""
	var plot = grid.get_plot(position)
	if not plot:
		_error("No plot at %s" % position)
		return ""

	if not plot.is_planted:
		_log("⚠ Plot not planted at %s" % position)
		return ""

	var outcome = biome.measure_qubit(position)
	plot.measure(outcome)
	_log("📐 Measured plot at %s: %s" % [position, outcome])
	return outcome

func harvest_plot(position: Vector2i) -> bool:
	"""Harvest and collect from plot"""
	var plot = grid.get_plot(position)
	if not plot:
		_error("No plot at %s" % position)
		return false

	if not plot.is_planted:
		_log("⚠ Plot not planted at %s" % position)
		return false

	if not plot.has_been_measured:
		measure_plot(position)

	var harvest_result = plot.harvest()
	biome.clear_qubit(position)
	plot.clear()

	_log("🌾 → 🍞 Harvested plot at %s" % position)
	return harvest_result

func advance_time(seconds: float) -> void:
	"""Advance game time"""
	var frames_needed = int(seconds * 60.0)
	for i in range(frames_needed):
		await get_tree().process_frame

## ============================================================================
## GAME LOOP
## ============================================================================

func run_game_loop(planting_positions: Array[Vector2i], duration: float = 5.0) -> Dictionary:
	"""Run complete game loop"""
	_log("\n▶ Starting game loop (%d plots, %.1fs)" % [planting_positions.size(), duration])

	var initial_credits = economy.credits
	var results = {"planted": 0, "measured": 0, "harvested": 0, "credits_change": 0}

	_log("  PHASE 1: PLANTING")
	results["planted"] = plant_wheat_cluster(planting_positions)

	_log("  PHASE 2: GROWING")
	await advance_time(duration)

	_log("  PHASE 3: MEASURING")
	for pos in planting_positions:
		if grid.get_plot(pos).is_planted:
			measure_plot(pos)
			results["measured"] += 1

	_log("  PHASE 4: HARVESTING")
	for pos in planting_positions:
		if grid.get_plot(pos).is_planted:
			if harvest_plot(pos):
				results["harvested"] += 1

	results["credits_change"] = economy.credits - initial_credits
	_log("✓ Game loop complete")
	return results

## ============================================================================
## STATE MANAGEMENT
## ============================================================================

func capture_game_snapshot() -> Dictionary:
	"""Capture current game state"""
	return {
		"credits": economy.credits,
		"wheat_inventory": economy.wheat_inventory,
		"flour_inventory": economy.flour_inventory,
		"planted_positions": _get_planted_positions(),
		"measured_positions": _get_measured_positions(),
		"sun_moon_phase": biome.sun_moon_phase,
	}

func _get_planted_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for y in range(farm.grid_height):
		for x in range(farm.grid_width):
			var pos = Vector2i(x, y)
			var plot = grid.get_plot(pos)
			if plot and plot.is_planted:
				positions.append(pos)
	return positions

func _get_measured_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for y in range(farm.grid_height):
		for x in range(farm.grid_width):
			var pos = Vector2i(x, y)
			var plot = grid.get_plot(pos)
			if plot and plot.has_been_measured:
				positions.append(pos)
	return positions

func verify_state_matches(snap1: Dictionary, snap2: Dictionary) -> Dictionary:
	"""Compare two snapshots"""
	var issues = []

	if snap1["credits"] != snap2["credits"]:
		issues.append("Credits: %d → %d" % [snap1["credits"], snap2["credits"]])

	if snap1["wheat_inventory"] != snap2["wheat_inventory"]:
		issues.append("Wheat: %d → %d" % [snap1["wheat_inventory"], snap2["wheat_inventory"]])

	if snap1["planted_positions"] != snap2["planted_positions"]:
		issues.append("Planted: %s → %s" % [snap1["planted_positions"], snap2["planted_positions"]])

	if snap1["measured_positions"] != snap2["measured_positions"]:
		issues.append("Measured: %s → %s" % [snap1["measured_positions"], snap2["measured_positions"]])

	return {"matches": issues.size() == 0, "differences": issues}

## ============================================================================
## SAVE/LOAD
## ============================================================================

func save_game(slot: int) -> bool:
	_log("💾 Saving game to slot %d..." % slot)
	if not game_state_manager:
		_error("GameStateManager not available")
		return false

	var result = game_state_manager.save_game(slot)
	if result:
		_log("✓ Game saved successfully")
	else:
		_error("Failed to save game")
	return result

func load_game(slot: int) -> bool:
	_log("📂 Loading game from slot %d..." % slot)
	if not game_state_manager:
		_error("GameStateManager not available")
		return false

	var result = game_state_manager.load_and_apply(slot)
	if result:
		_log("✓ Game loaded successfully")
		await get_tree().process_frame
	else:
		_error("Failed to load game")
	return result

func delete_save(slot: int) -> bool:
	var path = "user://saves/save_slot_%d.tres" % slot
	return DirAccess.remove_absolute(path) == OK if ResourceLoader.exists(path) else true

## ============================================================================
## LOGGING
## ============================================================================

func _log(message: String) -> void:
	var timestamp = "[%.2f]" % (Engine.get_process_frames() / 60.0)
	var formatted = "%s %s" % [timestamp, message]
	print(formatted)
	test_log.append(formatted)

func _error(message: String) -> void:
	_log("❌ ERROR: %s" % message)

func print_summary() -> void:
	_log("")
	_log("═" * 60)
	_log("Test log (%d entries)" % test_log.size())
	_log("═" * 60)
	for entry in test_log:
		print(entry)
