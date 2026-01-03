#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: ToolConfig Static Methods
## Ultra-simple test without Farm/Grid dependencies

const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")

func _init():
	print("\n🧪 TOOLCONFIG STATIC METHODS TEST")
	print("=" + "=".repeat(49))

	# TEST 1: get_submenu for energy_tap
	print("\n📂 TEST 1: GET SUBMENU (energy_tap)")
	var submenu = ToolConfig.get_submenu("energy_tap")

	if not submenu.has("Q") or not submenu.has("E") or not submenu.has("R"):
		print("❌ FAIL: Submenu missing Q/E/R keys")
		quit(1)
		return

	if not submenu.get("dynamic", false):
		print("❌ FAIL: energy_tap should be marked dynamic")
		quit(1)
		return

	print("✅ PASS: energy_tap submenu has Q/E/R and dynamic=true")

	# TEST 2: Action name generation
	print("\n🏷️  TEST 2: ACTION NAME GENERATION")
	var name_wheat = ToolConfig._emoji_to_action_name("🌾")
	var name_mushroom = ToolConfig._emoji_to_action_name("🍄")
	var name_tomato = ToolConfig._emoji_to_action_name("🍅")
	var name_wolf = ToolConfig._emoji_to_action_name("🐺")

	print("  🌾 → %s" % name_wheat)
	print("  🍄 → %s" % name_mushroom)
	print("  🍅 → %s" % name_tomato)
	print("  🐺 → %s" % name_wolf)

	if name_wheat != "wheat":
		print("❌ FAIL: 🌾 should map to 'wheat'")
		quit(1)
		return

	if name_mushroom != "mushroom":
		print("❌ FAIL: 🍄 should map to 'mushroom'")
		quit(1)
		return

	if name_tomato != "tomato":
		print("❌ FAIL: 🍅 should map to 'tomato'")
		quit(1)
		return

	if not name_wolf.begins_with("emoji_"):
		print("❌ FAIL: 🐺 should map to emoji_*")
		quit(1)
		return

	print("✅ PASS: Action names generated correctly")

	# TEST 3: Static submenu (non-dynamic)
	print("\n📦 TEST 3: STATIC SUBMENU (plant)")
	var plant_submenu = ToolConfig.get_submenu("plant")

	if plant_submenu.get("dynamic", false):
		print("❌ FAIL: plant submenu should NOT be dynamic")
		quit(1)
		return

	if not plant_submenu.has("Q") or plant_submenu["Q"]["action"] != "plant_wheat":
		print("❌ FAIL: plant submenu should have Q=plant_wheat")
		quit(1)
		return

	print("✅ PASS: Static submenus work correctly")

	print("\n" + "=" + "=".repeat(49))
	print("✅ ALL STATIC TESTS PASSED")
	print("=" + "=".repeat(49) + "\n")
	quit(0)
