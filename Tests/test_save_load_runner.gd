extends Node

var farm_view = null

func _ready():
	print("\n============================================================")
	print("🧪 SAVE/LOAD TEST (Scene Mode)")
	print("============================================================\n")

	await get_tree().create_timer(0.5).timeout
	run_tests()

func run_tests():
	# Load FarmView
	print("📦 Loading FarmView scene...")
	var scene = load("res://scenes/FarmView.tscn")
	farm_view = scene.instantiate()
	add_child(farm_view)

	await get_tree().create_timer(3.0).timeout

	# TEST 1: Check registration
	print("\n------------------------------------------------------------")
	print("TEST 1: GameStateManager Registration")
	print("------------------------------------------------------------")

	if GameStateManager.active_farm_view == farm_view:
		print("✅ PASS: FarmView registered with GameStateManager")
	else:
		print("❌ FAIL: FarmView not registered")
		get_tree().quit(1)
		return

	# TEST 2: Capture state
	print("\n------------------------------------------------------------")
	print("TEST 2: Capture State")
	print("------------------------------------------------------------")

	var original_credits = farm_view.economy.credits
	print("  Credits: " + str(original_credits))

	var state = GameStateManager.capture_state_from_game()
	if state and state.plots.size() == 25:
		print("✅ PASS: State captured (" + str(state.plots.size()) + " plots)")
	else:
		print("❌ FAIL: State capture failed")
		get_tree().quit(1)
		return

	# TEST 3: Save to disk
	print("\n------------------------------------------------------------")
	print("TEST 3: Save to Disk")
	print("------------------------------------------------------------")

	var save_success = GameStateManager.save_game(0)
	if save_success:
		print("✅ PASS: Save successful")
	else:
		print("❌ FAIL: Save failed")
		get_tree().quit(1)
		return

	# TEST 4: Modify and load
	print("\n------------------------------------------------------------")
	print("TEST 4: Load and Apply")
	print("------------------------------------------------------------")

	farm_view.economy.credits = 999
	print("  Modified credits to: 999")

	var load_success = GameStateManager.load_and_apply(0)
	if load_success:
		print("✅ PASS: Load successful")

		var restored_credits = farm_view.economy.credits
		print("  Restored credits: " + str(restored_credits))

		if restored_credits == original_credits:
			print("✅ PASS: Credits restored correctly")
		else:
			print("❌ FAIL: Credits mismatch")
			get_tree().quit(1)
			return
	else:
		print("❌ FAIL: Load failed")
		get_tree().quit(1)
		return

	# SUCCESS
	print("\n============================================================")
	print("🎉 ALL TESTS PASSED!")
	print("============================================================")
	print("")
	print("Save/load system is WORKING!")
	print("")

	await get_tree().create_timer(1.0).timeout
	get_tree().quit(0)
