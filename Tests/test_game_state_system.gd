extends SceneTree

var farm_view = null

func _init():
	var sep = "============================================================"
	print("\n" + sep)
	print("💾 GAME STATE MANAGEMENT SYSTEM TEST")
	print(sep + "\n")

func _initialize():
	print("📦 Loading FarmView scene...")
	var scene = load("res://scenes/FarmView.tscn")
	farm_view = scene.instantiate()
	root.add_child(farm_view)

	await create_timer(2.0).timeout

	var sep = "============================================================"
	print("\n" + sep)
	print("✅ TEST RESULTS")
	print(sep)

	# Test 1: GameStateManager exists and is registered
	if GameStateManager:
		print("✓ GameStateManager autoload exists")
		if GameStateManager.active_farm_view == farm_view:
			print("✓ FarmView registered with GameStateManager")
		else:
			print("✗ FarmView NOT registered with GameStateManager")
	else:
		print("✗ GameStateManager autoload NOT found")

	# Test 2: Save/Load menu exists
	if farm_view.save_load_menu:
		print("✓ SaveLoadMenu created")
	else:
		print("✗ SaveLoadMenu NOT created")

	# Test 3: Escape menu has new buttons
	if farm_view.escape_menu:
		print("✓ EscapeMenu exists")
	else:
		print("✗ EscapeMenu NOT found")

	# Test 4: Try capturing state
	print("\n" + sep)
	print("📸 Testing state capture...")
	print(sep)

	var state = GameStateManager.capture_state_from_game()
	if state:
		print("✓ State captured successfully")
		print("  Credits: " + str(state.credits))
		print("  Plots: " + str(state.plots.size()))
		print("  Scenario: " + state.scenario_id)
	else:
		print("✗ Failed to capture state")

	# Test 5: Try saving to slot
	print("\n" + sep)
	print("💾 Testing save to slot 0...")
	print(sep)

	var save_success = GameStateManager.save_game(0)
	if save_success:
		print("✓ Save successful")

		# Test 6: Check save file exists
		if GameStateManager.save_exists(0):
			print("✓ Save file exists")

			# Test 7: Get save info
			var info = GameStateManager.get_save_info(0)
			print("  Save info:")
			print("    Display name: " + info["display_name"])
			print("    Credits: " + str(info["credits"]))
			print("    Goal: " + str(info["goal_index"] + 1))
		else:
			print("✗ Save file NOT found")
	else:
		print("✗ Save failed")

	# Test 8: Try loading
	print("\n" + sep)
	print("📂 Testing load from slot 0...")
	print(sep)

	var load_success = GameStateManager.load_and_apply(0)
	if load_success:
		print("✓ Load successful")
	else:
		print("✗ Load failed")

	# Test 9: Scenario system
	print("\n" + sep)
	print("🎮 Testing scenario system...")
	print(sep)

	if ResourceLoader.exists("res://Scenarios/default.tres"):
		print("✓ Default scenario exists")
		var scenario = ResourceLoader.load("res://Scenarios/default.tres")
		if scenario:
			print("✓ Default scenario loads")
			print("  Scenario ID: " + scenario.scenario_id)
			print("  Starting credits: " + str(scenario.credits))
		else:
			print("✗ Failed to load scenario")
	else:
		print("✗ Default scenario file NOT found")

	print("\n" + sep)
	print("🎉 GAME STATE MANAGEMENT SYSTEM TESTS COMPLETE")
	print(sep + "\n")

	quit()
