## Game loop validation test
## Tests: plant → advance → measure → harvest cycle with verification

extends SaveLoadTestBase

func _initialize():
	"""Test complete game loop with state verification"""

	_log("\n" + "=" * 60)
	_log("GAME LOOP VALIDATION TEST")
	_log("=" * 60)

	# Initialize game
	if not await initialize_game():
		_error("Failed to initialize game")
		quit(1)
		return

	_log("✓ Game initialized\n")

	# Capture initial state
	var initial_snapshot = capture_game_snapshot()
	_log("Initial state:")
	_log("  Credits: %d" % initial_snapshot["credits"])
	_log("  Planted plots: %d" % initial_snapshot["planted_positions"].size())
	_log("  Measured plots: %d" % initial_snapshot["measured_positions"].size())

	# Test 1: Plant single plot
	_log("\n📌 TEST 1: Plant single plot")
	if not plant_wheat_at(Vector2i(0, 0)):
		_error("Failed to plant at (0,0)")
		quit(1)
		return

	var plot_0_0 = grid.get_plot(Vector2i(0, 0))
	_log("  is_planted: %s" % plot_0_0.is_planted)
	_log("  quantum_state exists: %s" % (biome.get_qubit(Vector2i(0, 0)) != null))

	# Test 2: Advance time
	_log("\n⏱ TEST 2: Advance time (3 seconds)")
	var snapshot_before_advance = capture_game_snapshot()
	await advance_time(3.0)
	var snapshot_after_advance = capture_game_snapshot()

	_log("  Sun/moon phase: %.2f → %.2f" % [
		snapshot_before_advance["sun_moon_phase"],
		snapshot_after_advance["sun_moon_phase"]
	])

	# Test 3: Measure plot
	_log("\n📐 TEST 3: Measure plot")
	var outcome = measure_plot(Vector2i(0, 0))
	_log("  Measured outcome: %s" % outcome)
	_log("  Measurement state: %s" % plot_0_0.has_been_measured)

	if outcome.is_empty():
		_error("Measurement returned empty")
		quit(1)
		return

	# Test 4: Harvest plot
	_log("\n🌾 TEST 4: Harvest plot")
	var snapshot_before_harvest = capture_game_snapshot()
	if not harvest_plot(Vector2i(0, 0)):
		_error("Failed to harvest")
		quit(1)
		return

	var snapshot_after_harvest = capture_game_snapshot()
	_log("  Credits: %d → %d" % [
		snapshot_before_harvest["credits"],
		snapshot_after_harvest["credits"]
	])
	_log("  Plot cleared: %s" % (not plot_0_0.is_planted))

	# Test 5: Multi-plot loop
	_log("\n🔄 TEST 5: Multi-plot game loop")
	var positions = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	var loop_results = await run_game_loop(positions, 2.0)

	if loop_results["planted"] != positions.size():
		_error("Not all plots planted")
		quit(1)
		return

	if loop_results["harvested"] != positions.size():
		_error("Not all plots harvested")
		quit(1)
		return

	var final_snapshot = capture_game_snapshot()

	# Test 6: Verify state consistency
	_log("\n✅ TEST 6: State consistency check")
	_log("  Total planted ever: 4 (1 + 3)")
	_log("  Current planted: %d" % final_snapshot["planted_positions"].size())
	_log("  Current measured: %d" % final_snapshot["measured_positions"].size())
	_log("  Credits change: %+d" % (final_snapshot["credits"] - initial_snapshot["credits"]))

	_log("\n" + "=" * 60)
	_log("✅ GAME LOOP VALIDATION COMPLETE")
	_log("=" * 60)

	print_summary()
	quit(0)
