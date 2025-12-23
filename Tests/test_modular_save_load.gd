## Modular save/load test - demonstrating full cycle
## Run with: godot --headless -s test_modular_save_load.gd

extends SceneTree

var farm_view = null
var test_log = []

func _init():
	var sep = "=".repeat(60)
	print("\n" + sep)
	print("🧪 MODULAR SAVE/LOAD CYCLE TEST")
	print(sep + "\n")

func _initialize():
	# Phase 1: Boot
	print("\n▶ PHASE 1: BOOT & INITIALIZE")
	print("-".repeat(60))
	if not await boot_game():
		print("❌ Boot failed")
		_quit(false)
		return

	# Phase 2: Setup and capture state
	print("\n▶ PHASE 2: SETUP GAME BOARD")
	print("-".repeat(60))
	var initial_snapshot = await setup_board()
	print("Initial state: %d credits, %d wheat" % [
		initial_snapshot["credits"],
		initial_snapshot["wheat_inventory"]
	])

	# Phase 3: Save
	print("\n▶ PHASE 3: SAVE GAME (slot 0)")
	print("-".repeat(60))
	if not GameStateManager.save_game(0):
		print("❌ Save failed")
		_quit(false)
		return
	print("✓ Game saved to slot 0")

	# Phase 4: Play different game
	print("\n▶ PHASE 4: START NEW GAME (slot 1)")
	print("-".repeat(60))
	# Delete slot 1 first
	var path1 = "user://saves/save_slot_1.tres"
	if ResourceLoader.exists(path1):
		DirAccess.remove_absolute(path1)

	# Plant different plots
	var different_positions = [Vector2i(4, 0), Vector2i(5, 0)]
	print("Planting different plots...")
	for pos in different_positions:
		var plot = farm_view.farm.grid.get_plot(pos)
		if plot:
			var qubit = farm_view.farm.biome.create_quantum_state(pos, "🌾", "🌱", PI/2)
			plot.plant(qubit)
	print("✓ Different plots planted")

	var new_game_snapshot = capture_snapshot()
	print("New game state: %d credits, %d wheat" % [
		new_game_snapshot["credits"],
		new_game_snapshot["wheat_inventory"]
	])

	# Verify different
	if verify_snapshots_different(initial_snapshot, new_game_snapshot):
		print("✓ New game is different from saved game (expected)")
	else:
		print("⚠ Games are the same (unexpected)")

	# Phase 5: Load original
	print("\n▶ PHASE 5: LOAD ORIGINAL GAME (slot 0)")
	print("-".repeat(60))
	if not GameStateManager.load_and_apply(0):
		print("❌ Load failed")
		_quit(false)
		return

	# Wait for state application
	var timer2 = Timer.new()
	root.add_child(timer2)
	timer2.start(1.0)
	await timer2.timeout
	timer2.queue_free()

	var loaded_snapshot = capture_snapshot()
	print("Loaded state: %d credits, %d wheat" % [
		loaded_snapshot["credits"],
		loaded_snapshot["wheat_inventory"]
	])

	# Verify matches
	if verify_snapshots_match(initial_snapshot, loaded_snapshot):
		print("✓ Loaded state matches saved state")
	else:
		print("❌ Loaded state does not match saved state")
		_quit(false)
		return

	# Phase 6: Continue playing from loaded state
	print("\n▶ PHASE 6: CONTINUE PLAYING AFTER LOAD")
	print("-".repeat(60))
	print("Playing game loop for 2 seconds...")
	var final_timer = Timer.new()
	root.add_child(final_timer)
	final_timer.start(2.0)
	await final_timer.timeout
	final_timer.queue_free()

	var final_snapshot = capture_snapshot()
	print("After gameplay: %d credits, %d wheat" % [
		final_snapshot["credits"],
		final_snapshot["wheat_inventory"]
	])

	# Summary
	print("\n" + "=".repeat(60))
	print("✅ COMPLETE SAVE/LOAD CYCLE TEST PASSED")
	print("=".repeat(60))
	_quit(true)

func boot_game() -> bool:
	print("Loading FarmView scene...")
	var scene = load("res://scenes/FarmView.tscn")
	if not scene:
		print("❌ Could not load scene")
		return false

	farm_view = scene.instantiate()
	root.add_child(farm_view)

	# Wait for _ready
	var timer = Timer.new()
	root.add_child(timer)
	timer.start(3.0)
	await timer.timeout
	timer.queue_free()

	if not (farm_view.farm and farm_view.farm.biome and farm_view.farm.grid):
		print("❌ Farm components missing")
		return false

	print("✓ Game booted successfully")
	print("  Grid: %dx%d" % [farm_view.farm.grid_width, farm_view.farm.grid_height])
	print("  Credits: %d" % farm_view.economy.credits)
	return true

func setup_board() -> Dictionary:
	print("Setting up game board...")
	var positions = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]

	# Plant
	for pos in positions:
		var plot = farm_view.farm.grid.get_plot(pos)
		var qubit = farm_view.farm.biome.create_quantum_state(pos, "🌾", "🌱", PI/2)
		plot.plant(qubit)

	print("  Planted %d plots" % positions.size())

	# Advance time
	var advance_timer = Timer.new()
	root.add_child(advance_timer)
	advance_timer.start(2.0)
	await advance_timer.timeout
	advance_timer.queue_free()

	# Measure
	for pos in positions:
		var outcome = farm_view.farm.biome.measure_qubit(pos)
		var plot = farm_view.farm.grid.get_plot(pos)
		plot.measure(outcome)

	print("  Measured all plots")

	# Harvest
	for pos in positions:
		var plot = farm_view.farm.grid.get_plot(pos)
		plot.harvest()
		farm_view.farm.biome.clear_qubit(pos)
		plot.clear()

	print("  Harvested all plots")
	return capture_snapshot()

func capture_snapshot() -> Dictionary:
	return {
		"credits": farm_view.economy.credits,
		"wheat_inventory": farm_view.economy.wheat_inventory,
		"flour_inventory": farm_view.economy.flour_inventory,
		"planted_count": _count_planted(),
		"measured_count": _count_measured(),
	}

func _count_planted() -> int:
	var count = 0
	for y in range(farm_view.farm.grid_height):
		for x in range(farm_view.farm.grid_width):
			var plot = farm_view.farm.grid.get_plot(Vector2i(x, y))
			if plot and plot.is_planted:
				count += 1
	return count

func _count_measured() -> int:
	var count = 0
	for y in range(farm_view.farm.grid_height):
		for x in range(farm_view.farm.grid_width):
			var plot = farm_view.farm.grid.get_plot(Vector2i(x, y))
			if plot and plot.has_been_measured:
				count += 1
	return count

func verify_snapshots_match(snap1: Dictionary, snap2: Dictionary) -> bool:
	return (snap1["credits"] == snap2["credits"] and
			snap1["wheat_inventory"] == snap2["wheat_inventory"] and
			snap1["flour_inventory"] == snap2["flour_inventory"])

func verify_snapshots_different(snap1: Dictionary, snap2: Dictionary) -> bool:
	return not verify_snapshots_match(snap1, snap2)

func _quit(success: bool) -> void:
	print("")
	quit(0 if success else 1)
