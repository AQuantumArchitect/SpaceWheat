## Complete save/load cycle test
## Tests: boot → setup board → save → new game → load → verify

extends SaveLoadTestBase

var test_results = {
	"boot_success": false,
	"board_setup_success": false,
	"save_success": false,
	"new_game_success": false,
	"load_success": false,
	"verification_success": false,
	"details": []
}

func _initialize():
	"""Run the complete test cycle"""

	# Phase 1: Boot
	_log("\n" + "=" * 60)
	_log("PHASE 1: BOOT & INITIALIZE")
	_log("=" * 60)

	if not await initialize_game():
		_error("Boot failed - cannot continue")
		_exit_with_result(false)
		return

	test_results["boot_success"] = true
	_log("✓ Boot successful\n")

	# Phase 2: Set up game board
	_log("=" * 60)
	_log("PHASE 2: BOARD SETUP")
	_log("=" * 60)

	var planting_positions = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var snapshot_before_save = capture_game_snapshot()

	if not await _setup_board(planting_positions):
		_error("Board setup failed - cannot continue")
		_exit_with_result(false)
		return

	var snapshot_after_setup = capture_game_snapshot()
	test_results["board_setup_success"] = true
	test_results["details"].append("Board setup: planted %d plots" % snapshot_after_setup["planted_positions"].size())

	# Phase 3: Save game to slot 0
	_log("\n" + "=" * 60)
	_log("PHASE 3: SAVE GAME (SLOT 0)")
	_log("=" * 60)

	if not save_game(0):
		_error("Save failed - cannot continue")
		_exit_with_result(false)
		return

	var snapshot_after_save = capture_game_snapshot()
	test_results["save_success"] = true
	test_results["details"].append("Saved game with %d credits, %d wheat" % [
		snapshot_after_save["credits"], snapshot_after_save["wheat_inventory"]
	])

	# Phase 4: Start new game (slot 1 to avoid overwriting)
	_log("\n" + "=" * 60)
	_log("PHASE 4: NEW GAME (SLOT 1)")
	_log("=" * 60)

	# Delete old slot 1 to ensure clean start
	delete_save(1)
	await get_tree().process_frame

	# Run a different game loop in slot 1
	if not await _run_different_game():
		_error("New game failed - cannot continue")
		_exit_with_result(false)
		return

	var snapshot_different_game = capture_game_snapshot()
	test_results["new_game_success"] = true
	test_results["details"].append("Different game: %d credits, %d wheat" % [
		snapshot_different_game["credits"], snapshot_different_game["wheat_inventory"]
	])

	# Verify games are different
	var comparison = verify_state_matches(snapshot_after_save, snapshot_different_game)
	if comparison["matches"]:
		_error("Games should be different but aren't!")
		_exit_with_result(false)
		return

	_log("✓ New game is different (expected)")
	for diff in comparison["differences"]:
		_log("  - %s" % diff)

	# Phase 5: Load original game from slot 0
	_log("\n" + "=" * 60)
	_log("PHASE 5: LOAD ORIGINAL (SLOT 0)")
	_log("=" * 60)

	if not await load_game(0):
		_error("Load failed - cannot continue")
		_exit_with_result(false)
		return

	var snapshot_after_load = capture_game_snapshot()
	test_results["load_success"] = true
	test_results["details"].append("Loaded game: %d credits, %d wheat" % [
		snapshot_after_load["credits"], snapshot_after_load["wheat_inventory"]
	])

	# Phase 6: Verify loaded state matches saved state
	_log("\n" + "=" * 60)
	_log("PHASE 6: VERIFICATION")
	_log("=" * 60)

	var final_comparison = verify_state_matches(snapshot_after_save, snapshot_after_load, 0.01)

	if not final_comparison["matches"]:
		_error("Loaded state doesn't match saved state!")
		for diff in final_comparison["differences"]:
			_log("  - %s" % diff)
		_exit_with_result(false)
		return

	test_results["verification_success"] = true
	_log("✓ Loaded state matches saved state")

	# Phase 7: Run game loop to verify functionality
	_log("\n" + "=" * 60)
	_log("PHASE 7: POST-LOAD GAME LOOP")
	_log("=" * 60)

	var new_planting = [Vector2i(3, 0), Vector2i(4, 0)]
	var loop_results = await run_game_loop(new_planting, 3.0)

	test_results["details"].append("Post-load loop: planted %d, harvested %d" % [
		loop_results["planted"], loop_results["harvested"]
	])

	# Final summary
	_log("\n" + "=" * 60)
	_log("TEST SUMMARY")
	_log("=" * 60)

	_print_results()
	_exit_with_result(true)

func _setup_board(positions: Array[Vector2i]) -> bool:
	"""Set up initial board: plant wheat, advance time, measure, harvest"""
	_log("Setting up board with %d plots..." % positions.size())

	# Run a complete game loop
	var results = await run_game_loop(positions, 2.0)

	if results["planted"] != positions.size():
		_error("Failed to plant all plots")
		return false

	_log("✓ Board setup complete")
	return true

func _run_different_game() -> bool:
	"""Run a different game scenario to create different state"""
	_log("Running different game scenario...")

	# Plant different plots
	var different_positions = [Vector2i(4, 0), Vector2i(5, 0)]
	var results = await run_game_loop(different_positions, 2.0)

	if results["planted"] != different_positions.size():
		_error("Failed to plant different plots")
		return false

	_log("✓ Different game created")
	return true

func _print_results() -> void:
	"""Print detailed test results"""
	var all_pass = (
		test_results["boot_success"] and
		test_results["board_setup_success"] and
		test_results["save_success"] and
		test_results["new_game_success"] and
		test_results["load_success"] and
		test_results["verification_success"]
	)

	print("\n📊 TEST RESULTS:")
	print("  Boot:           %s" % _bool_symbol(test_results["boot_success"]))
	print("  Board Setup:    %s" % _bool_symbol(test_results["board_setup_success"]))
	print("  Save:           %s" % _bool_symbol(test_results["save_success"]))
	print("  New Game:       %s" % _bool_symbol(test_results["new_game_success"]))
	print("  Load:           %s" % _bool_symbol(test_results["load_success"]))
	print("  Verification:   %s" % _bool_symbol(test_results["verification_success"]))
	print("")
	print("OVERALL: %s" % ("✅ PASS" if all_pass else "❌ FAIL"))

	if test_results["details"]:
		print("\n📝 Details:")
		for detail in test_results["details"]:
			print("  - %s" % detail)

func _bool_symbol(value: bool) -> String:
	return "✅ PASS" if value else "❌ FAIL"

func _exit_with_result(success: bool) -> void:
	"""Exit with appropriate status code"""
	print_summary()
	get_tree().quit(0 if success else 1)
