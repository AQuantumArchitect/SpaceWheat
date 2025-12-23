## Base test framework for save/load testing
## Provides reusable utilities for modular test composition

extends Node

class_name SaveLoadTestBase

# References
var farm_view: Node = null
var farm: Node = null
var biome: Node = null
var grid: Node = null
var economy: Node = null
var game_state_manager: Node = null

# Test metadata
var test_name: String = ""
var test_log: Array[String] = []

func _ready():
	test_name = self.get_class()
	_log("═" * 60)
	_log("Starting %s" % test_name)
	_log("═" * 60)

## ============================================================================
## INITIALIZATION
## ============================================================================

func initialize_game() -> bool:
	"""Load and initialize FarmView scene"""
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
## BOARD SETUP - Farm Creation Utilities
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

	# Create quantum state in biome
	var qubit = biome.create_quantum_state(position, "🌾", "🌱", PI/2)
	if not qubit:
		_error("Failed to create quantum state at %s" % position)
		return false

	# Plant in grid
	plot.plant(qubit)

	_log("🌾 Planted wheat at %s (theta=%.2f)" % [position, qubit.theta])
	return true

func plant_wheat_cluster(positions: Array[Vector2i]) -> int:
	"""Plant wheat at multiple positions, return count"""
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

	_log("📐 Measured plot at %s: %s (probability north: %.2f)" % [
		position, outcome, biome.get_probability_north(position)
	])
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

	# Measure if not already measured
	if not plot.has_been_measured:
		measure_plot(position)

	# Harvest (collect resources)
	var harvest_result = plot.harvest()
	biome.clear_qubit(position)
	plot.clear()

	_log("🌾 → 🍞 Harvested plot at %s" % position)
	return harvest_result

func advance_time(seconds: float) -> void:
	"""Advance game time by running process for given seconds"""
	var frames_needed = int(seconds * 60.0)  # 60 FPS
	for i in range(frames_needed):
		await get_tree().process_frame

## ============================================================================
## GAME LOOP - Full Simulation Flow
## ============================================================================

func run_game_loop(planting_positions: Array[Vector2i], duration: float = 5.0) -> Dictionary:
	"""Run complete game loop: plant → advance time → measure → harvest

	Returns: Dictionary with results {planted, measured, harvested, credits_change}
	"""
	_log("\n▶ Starting game loop (%d plots, %.1fs)" % [planting_positions.size(), duration])

	var initial_credits = economy.credits
	var results = {
		"planted": 0,
		"measured": 0,
		"harvested": 0,
		"credits_change": 0
	}

	# Phase 1: Plant
	_log("  PHASE 1: PLANTING")
	results["planted"] = plant_wheat_cluster(planting_positions)

	# Phase 2: Advance time (let quantum evolution happen)
	_log("  PHASE 2: GROWING (%.1fs)" % duration)
	await advance_time(duration)

	# Phase 3: Measure
	_log("  PHASE 3: MEASURING")
	for pos in planting_positions:
		if grid.get_plot(pos).is_planted:
			measure_plot(pos)
			results["measured"] += 1

	# Phase 4: Harvest
	_log("  PHASE 4: HARVESTING")
	for pos in planting_positions:
		if grid.get_plot(pos).is_planted:
			if harvest_plot(pos):
				results["harvested"] += 1

	results["credits_change"] = economy.credits - initial_credits

	_log("✓ Game loop complete:")
	_log("  - Planted: %d" % results["planted"])
	_log("  - Measured: %d" % results["measured"])
	_log("  - Harvested: %d" % results["harvested"])
	_log("  - Credits change: %+d" % results["credits_change"])

	return results

## ============================================================================
## STATE CAPTURE & VERIFICATION
## ============================================================================

func capture_game_snapshot() -> Dictionary:
	"""Capture current game state snapshot for comparison"""
	return {
		"credits": economy.credits,
		"wheat_inventory": economy.wheat_inventory,
		"flour_inventory": economy.flour_inventory,
		"planted_positions": _get_planted_positions(),
		"measured_positions": _get_measured_positions(),
		"sun_moon_phase": biome.sun_moon_phase,
		"quantum_states": _snapshot_quantum_states(),
	}

func _get_planted_positions() -> Array[Vector2i]:
	"""Get all currently planted positions"""
	var positions: Array[Vector2i] = []
	for y in range(farm.grid_height):
		for x in range(farm.grid_width):
			var pos = Vector2i(x, y)
			var plot = grid.get_plot(pos)
			if plot and plot.is_planted:
				positions.append(pos)
	return positions

func _get_measured_positions() -> Array[Vector2i]:
	"""Get all measured positions"""
	var positions: Array[Vector2i] = []
	for y in range(farm.grid_height):
		for x in range(farm.grid_width):
			var pos = Vector2i(x, y)
			var plot = grid.get_plot(pos)
			if plot and plot.has_been_measured:
				positions.append(pos)
	return positions

func _snapshot_quantum_states() -> Dictionary:
	"""Snapshot quantum state parameters (theta, radius, energy) at each position"""
	var snapshot = {}
	for pos in biome.quantum_states.keys():
		var qubit = biome.quantum_states[pos]
		if qubit:
			snapshot[pos] = {
				"theta": qubit.theta,
				"radius": qubit.radius,
				"energy": qubit.energy,
				"north_prob": qubit.get_north_probability(),
			}
	return snapshot

func verify_state_matches(snapshot1: Dictionary, snapshot2: Dictionary, tolerance: float = 0.01) -> Dictionary:
	"""Compare two state snapshots and return differences"""
	var issues = []

	# Compare resources
	if snapshot1["credits"] != snapshot2["credits"]:
		issues.append("Credits: %d → %d" % [snapshot1["credits"], snapshot2["credits"]])

	if snapshot1["wheat_inventory"] != snapshot2["wheat_inventory"]:
		issues.append("Wheat: %d → %d" % [snapshot1["wheat_inventory"], snapshot2["wheat_inventory"]])

	if snapshot1["flour_inventory"] != snapshot2["flour_inventory"]:
		issues.append("Flour: %d → %d" % [snapshot1["flour_inventory"], snapshot2["flour_inventory"]])

	# Compare planted positions
	var planted1 = snapshot1["planted_positions"] as Array[Vector2i]
	var planted2 = snapshot2["planted_positions"] as Array[Vector2i]
	if planted1 != planted2:
		issues.append("Planted positions: %s → %s" % [planted1, planted2])

	# Compare measured positions
	var measured1 = snapshot1["measured_positions"] as Array[Vector2i]
	var measured2 = snapshot2["measured_positions"] as Array[Vector2i]
	if measured1 != measured2:
		issues.append("Measured positions: %s → %s" % [measured1, measured2])

	return {
		"matches": issues.size() == 0,
		"differences": issues,
		"difference_count": issues.size()
	}

## ============================================================================
## SAVE/LOAD OPERATIONS
## ============================================================================

func save_game(slot: int) -> bool:
	"""Save current game state to specified slot"""
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
	"""Load game state from specified slot"""
	_log("📂 Loading game from slot %d..." % slot)

	if not game_state_manager:
		_error("GameStateManager not available")
		return false

	var result = game_state_manager.load_and_apply(slot)
	if result:
		_log("✓ Game loaded successfully")
		# Wait for scene updates
		await get_tree().process_frame
	else:
		_error("Failed to load game")

	return result

func delete_save(slot: int) -> bool:
	"""Delete save file at slot"""
	var path = "user://saves/save_slot_%d.tres" % slot
	if ResourceLoader.exists(path):
		return DirAccess.remove_absolute(path) == OK
	return true

## ============================================================================
## LOGGING
## ============================================================================

func _log(message: String) -> void:
	"""Log message with timestamp"""
	var timestamp = "[%.2f]" % Engine.get_process_frames() / 60.0
	var formatted = "%s %s" % [timestamp, message]
	print(formatted)
	test_log.append(formatted)

func _error(message: String) -> void:
	"""Log error message"""
	_log("❌ ERROR: %s" % message)

func get_log() -> Array[String]:
	"""Return full test log"""
	return test_log

func print_summary() -> void:
	"""Print test summary"""
	_log("")
	_log("═" * 60)
	_log("Test log (%d entries)" % test_log.size())
	_log("═" * 60)
	for entry in test_log:
		print(entry)
