## Quick boot test - Run as: godot --headless -s test_quick_boot_v2.gd

extends SceneTree

func _initialize():
	var sep = "=".repeat(60)
	print("\n" + sep)
	print("🧪 QUICK BOOT TEST")
	print(sep)

	var all_pass = true

	# Create GameStateManager
	var manager = load("res://Core/GameState/GameStateManager.gd").new()
	manager.name = "GameStateManager"
	root.add_child(manager)
	await manager.tree_entered

	# Create helper
	var HelperClass = load("res://tests/test_save_load_helper.gd")
	var helper = HelperClass.new()
	root.add_child(helper)
	await helper.tree_entered

	# Test 1: Initialize
	print("\n🎮 TEST 1: Game initialization")
	if not await helper.initialize_game():
		print("❌ Failed")
		all_pass = false
	else:
		print("✓ Game initialized")

	# Test 2: Verify systems
	print("\n🔧 TEST 2: Core systems")
	if helper.farm and helper.biome and helper.grid and helper.economy:
		print("✓ All systems present")
	else:
		print("❌ Missing systems")
		all_pass = false

	# Test 3: Grid info
	print("\n📐 TEST 3: Grid dimensions")
	print("  Grid: %dx%d" % [helper.farm.grid_width, helper.farm.grid_height])
	print("  Economy: %d credits" % helper.economy.credits)

	# Test 4: Biome
	print("\n🌍 TEST 4: Biome state")
	print("  Temp: %.0fK" % helper.biome.base_temperature)
	print("  Is sun: %s" % helper.biome.is_currently_sun())

	# Summary
	print("\n" + sep)
	if all_pass:
		print("✅ BOOT TEST PASSED")
	else:
		print("❌ BOOT TEST FAILED")
	print(sep)

	quit(0 if all_pass else 1)
