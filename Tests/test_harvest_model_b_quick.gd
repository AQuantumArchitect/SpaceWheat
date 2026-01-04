#!/usr/bin/env godot
extends SceneTree

# Quick test: Verify harvest_with_topology() doesn't crash with Model B API

func _ready():
	print("\n=== TEST: Harvest Model B Refactoring ===\n")

	# Load essential resources
	var farm_scene = preload("res://scenes/Farm.tscn")
	if not farm_scene:
		print("❌ Failed to load Farm scene")
		quit(1)

	var farm = farm_scene.instantiate()
	add_child(farm)

	# Wait for farm to initialize
	await farm.tree_entered
	print("✅ Farm loaded")

	# Get grid
	var grid = farm.grid
	if not grid:
		print("❌ No grid in farm")
		quit(1)

	print("✅ Grid available")

	# Plant a crop at (5,5) to test
	var test_pos = Vector2i(5, 5)
	var plot = grid.get_plot(test_pos)

	if not plot:
		print("❌ Plot not found at %s" % test_pos)
		quit(1)

	print("✅ Got plot at %s" % test_pos)

	# Plant it
	plot.plant("🌾", "wheat")
	print("✅ Planted wheat at %s" % test_pos)

	# Check if register was allocated
	var register_id = grid.get_register_for_plot(test_pos)
	print("ℹ️  Register ID: %d" % register_id)

	if register_id < 0:
		print("⚠️  No register allocated - testing without quantum_computer")

	# Advance growth
	plot.growth_progress = 1.0
	print("✅ Set growth to 100%")

	# Try to harvest
	print("\n📊 Attempting harvest...")
	var harvest_result = grid.harvest_with_topology(test_pos)

	print("\n=== HARVEST RESULT ===")
	if harvest_result.has("success") and harvest_result["success"]:
		print("✅ Harvest succeeded!")
		print("  - Yield: %.1f" % harvest_result.get("yield", 0.0))
		print("  - State: %s" % harvest_result.get("state", "unknown"))
		print("  - Coherence: %.2f" % harvest_result.get("coherence", 0.0))
		print("  - Topology Bonus: %.2f" % harvest_result.get("topology_bonus", 1.0))
		quit(0)
	else:
		print("❌ Harvest failed!")
		print("  Result: %s" % harvest_result)
		quit(1)

