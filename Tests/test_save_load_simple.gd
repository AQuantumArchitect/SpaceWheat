extends Node

## Simple Save/Load Test
## Runs in the context of the running game

var test_complete = false
var farm_view = null

func _ready():
	print("\n" + "=".repeat(80))
	print("🧪 SAVE/LOAD INTEGRATION TEST")
	print("=".repeat(80))

	# Load FarmView scene
	print("\n📦 Loading FarmView...")
	var scene = load("res://scenes/FarmView.tscn")
	if not scene:
		print("❌ Failed to load FarmView.tscn")
		get_tree().quit(1)
		return

	farm_view = scene.instantiate()
	add_child(farm_view)

	# Wait for game to initialize
	print("⏳ Waiting for initialization (5 seconds)...")
	await get_tree().create_timer(5.0).timeout

	run_test()

func run_test():
	print("\n📋 TEST SEQUENCE:")
	print("  1. Check GameStateManager")
	print("  2. Capture initial state")
	print("  3. Modify state")
	print("  4. Save game")
	print("  5. Reload and compare\n")

	# Step 1: Check GameStateManager
	print("─".repeat(80))
	print("Step 1: Check GameStateManager")
	print("─".repeat(80))

	if not GameStateManager:
		print("❌ GameStateManager not found!")
		finish_test(false)
		return

	print("✅ GameStateManager available")

	var farm = GameStateManager.active_farm
	if not farm:
		print("❌ active_farm is null!")
		finish_test(false)
		return

	print("✅ Farm reference obtained")
	print("  Grid: %dx%d" % [farm.grid.grid_width, farm.grid.grid_height])

	# Step 2: Capture initial state
	print("\n" + "─".repeat(80))
	print("Step 2: Capture Initial State")
	print("─".repeat(80))

	var initial_credits = farm.economy.credits
	var initial_wheat = farm.economy.wheat_inventory

	print("  💰 Credits: %d" % initial_credits)
	print("  🌾 Wheat: %d" % initial_wheat)

	# Step 3: Modify state
	print("\n" + "─".repeat(80))
	print("Step 3: Modify State")
	print("─".repeat(80))

	farm.economy.credits = 999
	farm.economy.wheat_inventory = 42

	print("  💰 Credits: %d → %d" % [initial_credits, farm.economy.credits])
	print("  🌾 Wheat: %d → %d" % [initial_wheat, farm.economy.wheat_inventory])

	# Step 4: Save
	print("\n" + "─".repeat(80))
	print("Step 4: Save Game")
	print("─".repeat(80))

	var save_ok = GameStateManager.save_game(9)  # Use slot 9 for testing
	if not save_ok:
		print("❌ Save failed!")
		finish_test(false)
		return

	print("✅ Save successful")

	# Step 5: Reload
	print("\n" + "─".repeat(80))
	print("Step 5: Reload Game")
	print("─".repeat(80))

	# Modify again to test reload
	farm.economy.credits = 1
	farm.economy.wheat_inventory = 1

	print("  Modified to: credits=%d, wheat=%d" % [farm.economy.credits, farm.economy.wheat_inventory])

	var load_ok = GameStateManager.load_game(9)  # Load from slot 9
	if not load_ok:
		print("❌ Load failed!")
		finish_test(false)
		return

	print("✅ Load successful")

	# Wait for state to apply
	await get_tree().create_timer(0.5).timeout

	# Verify
	print("\n" + "─".repeat(80))
	print("Step 6: Verify State")
	print("─".repeat(80))

	var loaded_credits = farm.economy.credits
	var loaded_wheat = farm.economy.wheat_inventory

	print("  💰 Credits: %d (expected 999)" % loaded_credits)
	print("  🌾 Wheat: %d (expected 42)" % loaded_wheat)

	var success = (loaded_credits == 999 and loaded_wheat == 42)

	if success:
		print("\n✅ ALL CHECKS PASSED")
	else:
		print("\n❌ STATE MISMATCH")

	finish_test(success)

func finish_test(success: bool):
	print("\n" + "=".repeat(80))
	if success:
		print("✅ TEST PASSED")
	else:
		print("❌ TEST FAILED")
	print("=".repeat(80) + "\n")

	test_complete = true
	get_tree().quit(0 if success else 1)
