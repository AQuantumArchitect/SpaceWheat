## Quick boot test
## Fast sanity check: can the game boot and core systems initialize?

extends SaveLoadTestBase

func _initialize():
	"""Quick boot verification"""

	_log("\n" + "=".repeat(60))
	_log("QUICK BOOT TEST")
	_log("=".repeat(60))

	var all_pass = true

	# Test 1: Initialize game
	_log("\n🎮 TEST 1: Game initialization")
	if not await initialize_game():
		_error("Failed to initialize game")
		all_pass = false
	else:
		_log("✓ Game initialized")

	# Test 2: Verify core systems
	_log("\n🔧 TEST 2: Core systems present")

	var systems = {
		"farm": farm,
		"biome": biome,
		"grid": grid,
		"economy": economy,
	}

	for system_name in systems:
		if systems[system_name]:
			_log("  ✓ %s" % system_name)
		else:
			_error("  Missing: %s" % system_name)
			all_pass = false

	# Test 3: Check grid dimensions
	_log("\n📐 TEST 3: Grid dimensions")
	_log("  Grid size: %dx%d" % [farm.grid_width, farm.grid_height])
	_log("  Total plots: %d" % (farm.grid_width * farm.grid_height))

	# Test 4: Verify economy state
	_log("\n💰 TEST 4: Economy initialization")
	_log("  Credits: %d" % economy.credits)
	_log("  Wheat inventory: %d" % economy.wheat_inventory)

	# Test 5: Verify biome state
	_log("\n🌍 TEST 5: Biome state")
	_log("  Temperature: %.0fK" % biome.base_temperature)
	_log("  Sun/moon phase: %.2f" % biome.sun_moon_phase)
	_log("  Is sun: %s" % biome.is_currently_sun())

	# Test 6: Can we access a plot?
	_log("\n📍 TEST 6: Plot access")
	var test_plot = grid.get_plot(Vector2i(0, 0))
	if test_plot:
		_log("  ✓ Can access plot at (0, 0)")
		_log("    - Type: %d" % test_plot.plot_type)
		_log("    - Planted: %s" % test_plot.is_planted)
	else:
		_error("Cannot access plot at (0, 0)")
		all_pass = false

	# Test 7: GameStateManager available?
	_log("\n💾 TEST 7: GameStateManager")
	if game_state_manager:
		_log("  ✓ GameStateManager available")
	else:
		_log("  ⚠ GameStateManager not found (save/load tests won't work)")

	# Summary
	_log("\n" + "=".repeat(60))
	if all_pass:
		_log("✅ BOOT TEST PASSED")
	else:
		_log("❌ BOOT TEST FAILED")
	_log("=".repeat(60))

	print_summary()
	quit(0 if all_pass else 1)
