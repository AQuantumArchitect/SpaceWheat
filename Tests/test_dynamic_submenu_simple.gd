#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: Dynamic Submenu Generation (Simple)
##
## Tests ToolConfig dynamic generation logic without full Farm initialization

const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")

# Mock Farm with minimal grid interface
class MockGrid:
	var available_emojis: Array[String] = []

	func get_available_tap_emojis() -> Array[String]:
		return available_emojis

class MockFarm:
	var grid: MockGrid

	func _init():
		grid = MockGrid.new()

func _init():
	print("🧪 DYNAMIC SUBMENU GENERATION TEST\n")

	# TEST 1: Empty vocabulary - disabled state
	print("🔴 TEST 1: EMPTY VOCABULARY → DISABLED STATE")
	var farm1 = MockFarm.new()
	farm1.grid.available_emojis = []  # No emojis discovered

	var submenu1 = ToolConfig.get_dynamic_submenu("energy_tap", farm1)

	print("  Generated submenu:")
	print("    Q: emoji='%s' label='%s' action='%s'" % [
		submenu1["Q"]["emoji"],
		submenu1["Q"]["label"],
		submenu1["Q"]["action"]
	])
	print("    E: emoji='%s' label='%s' action='%s'" % [
		submenu1["E"]["emoji"],
		submenu1["E"]["label"],
		submenu1["E"]["action"]
	])
	print("    R: emoji='%s' label='%s' action='%s'" % [
		submenu1["R"]["emoji"],
		submenu1["R"]["label"],
		submenu1["R"]["action"]
	])
	print("    _disabled: %s" % submenu1.get("_disabled", false))

	# Verify disabled state
	if not submenu1.get("_disabled", false):
		print("  ❌ FAIL: Submenu should be disabled with empty vocabulary")
		quit(1)
		return

	# Verify empty actions
	if submenu1["Q"]["action"] != "":
		print("  ❌ FAIL: Q action should be empty when disabled")
		quit(1)
		return

	print("  ✅ PASS: Empty vocabulary correctly disables submenu\n")

	# TEST 2: One emoji - Q enabled, E/R locked
	print("🟡 TEST 2: ONE EMOJI → Q ENABLED, E/R LOCKED")
	var farm2 = MockFarm.new()
	farm2.grid.available_emojis = ["🌾"]  # Only wheat

	var submenu2 = ToolConfig.get_dynamic_submenu("energy_tap", farm2)

	print("  Generated submenu:")
	print("    Q: emoji='%s' label='%s' action='%s'" % [
		submenu2["Q"]["emoji"],
		submenu2["Q"]["label"],
		submenu2["Q"]["action"]
	])
	print("    E: emoji='%s' label='%s' action='%s'" % [
		submenu2["E"]["emoji"],
		submenu2["E"]["label"],
		submenu2["E"]["action"]
	])
	print("    R: emoji='%s' label='%s' action='%s'" % [
		submenu2["R"]["emoji"],
		submenu2["R"]["label"],
		submenu2["R"]["action"]
	])

	# Verify Q is enabled
	if submenu2["Q"]["emoji"] != "🌾":
		print("  ❌ FAIL: Q should show 🌾, got: %s" % submenu2["Q"]["emoji"])
		quit(1)
		return

	if submenu2["Q"]["action"] == "":
		print("  ❌ FAIL: Q action should not be empty")
		quit(1)
		return

	# Verify E/R are locked
	if submenu2["E"]["action"] != "":
		print("  ❌ FAIL: E action should be empty (locked)")
		quit(1)
		return

	if submenu2["R"]["action"] != "":
		print("  ❌ FAIL: R action should be empty (locked)")
		quit(1)
		return

	print("  ✅ PASS: One emoji correctly enables Q, locks E/R\n")

	# TEST 3: Three emojis - All enabled
	print("🟢 TEST 3: THREE EMOJIS → ALL ENABLED")
	var farm3 = MockFarm.new()
	farm3.grid.available_emojis = ["🌾", "🍄", "🍅"]

	var submenu3 = ToolConfig.get_dynamic_submenu("energy_tap", farm3)

	print("  Generated submenu:")
	print("    Q: emoji='%s' label='%s' action='%s'" % [
		submenu3["Q"]["emoji"],
		submenu3["Q"]["label"],
		submenu3["Q"]["action"]
	])
	print("    E: emoji='%s' label='%s' action='%s'" % [
		submenu3["E"]["emoji"],
		submenu3["E"]["label"],
		submenu3["E"]["action"]
	])
	print("    R: emoji='%s' label='%s' action='%s'" % [
		submenu3["R"]["emoji"],
		submenu3["R"]["label"],
		submenu3["R"]["action"]
	])

	# Verify all actions enabled
	if submenu3["Q"]["action"] == "" or submenu3["E"]["action"] == "" or submenu3["R"]["action"] == "":
		print("  ❌ FAIL: All actions should be enabled with 3 emojis")
		quit(1)
		return

	# Verify emojis match
	if submenu3["Q"]["emoji"] != "🌾":
		print("  ❌ FAIL: Q should be 🌾, got: %s" % submenu3["Q"]["emoji"])
		quit(1)
		return

	if submenu3["E"]["emoji"] != "🍄":
		print("  ❌ FAIL: E should be 🍄, got: %s" % submenu3["E"]["emoji"])
		quit(1)
		return

	if submenu3["R"]["emoji"] != "🍅":
		print("  ❌ FAIL: R should be 🍅, got: %s" % submenu3["R"]["emoji"])
		quit(1)
		return

	print("  ✅ PASS: Three emojis correctly enable all buttons\n")

	# TEST 4: Action name generation
	print("🔵 TEST 4: ACTION NAME GENERATION")

	var action_wheat = ToolConfig._emoji_to_action_name("🌾")
	var action_mushroom = ToolConfig._emoji_to_action_name("🍄")
	var action_tomato = ToolConfig._emoji_to_action_name("🍅")
	var action_wolf = ToolConfig._emoji_to_action_name("🐺")

	print("  🌾 → '%s'" % action_wheat)
	print("  🍄 → '%s'" % action_mushroom)
	print("  🍅 → '%s'" % action_tomato)
	print("  🐺 → '%s'" % action_wolf)

	# Verify hardcoded mappings
	if action_wheat != "wheat":
		print("  ❌ FAIL: 🌾 should map to 'wheat', got: %s" % action_wheat)
		quit(1)
		return

	if action_mushroom != "mushroom":
		print("  ❌ FAIL: 🍄 should map to 'mushroom', got: %s" % action_mushroom)
		quit(1)
		return

	if action_tomato != "tomato":
		print("  ❌ FAIL: 🍅 should map to 'tomato', got: %s" % action_tomato)
		quit(1)
		return

	# Verify dynamic hash-based naming
	if not action_wolf.begins_with("emoji_"):
		print("  ❌ FAIL: 🐺 should map to emoji_*, got: %s" % action_wolf)
		quit(1)
		return

	print("  ✅ PASS: Action names generated correctly\n")

	# TEST 5: More than 3 emojis - only first 3 shown
	print("🟣 TEST 5: FIVE EMOJIS → FIRST 3 SHOWN")
	var farm5 = MockFarm.new()
	farm5.grid.available_emojis = ["🌾", "🍄", "🍅", "👥", "🐺"]

	var submenu5 = ToolConfig.get_dynamic_submenu("energy_tap", farm5)

	print("  Available: %s" % farm5.grid.available_emojis)
	print("  Generated submenu:")
	print("    Q: emoji='%s'" % submenu5["Q"]["emoji"])
	print("    E: emoji='%s'" % submenu5["E"]["emoji"])
	print("    R: emoji='%s'" % submenu5["R"]["emoji"])

	# Verify only first 3 emojis are shown
	if submenu5["Q"]["emoji"] != "🌾":
		print("  ❌ FAIL: Q should show first emoji (🌾)")
		quit(1)
		return

	if submenu5["E"]["emoji"] != "🍄":
		print("  ❌ FAIL: E should show second emoji (🍄)")
		quit(1)
		return

	if submenu5["R"]["emoji"] != "🍅":
		print("  ❌ FAIL: R should show third emoji (🍅)")
		quit(1)
		return

	print("  ✅ PASS: Correctly shows first 3 of 5 emojis\n")

	# TEST 6: Non-dynamic submenu (should pass through unchanged)
	print("🔷 TEST 6: NON-DYNAMIC SUBMENU (plant)")
	var farm6 = MockFarm.new()

	var plant_submenu = ToolConfig.get_dynamic_submenu("plant", farm6)
	var static_submenu = ToolConfig.get_submenu("plant")

	# Should be identical (no dynamic generation)
	if plant_submenu["Q"]["action"] != static_submenu["Q"]["action"]:
		print("  ❌ FAIL: Non-dynamic submenu should be unchanged")
		quit(1)
		return

	print("  Non-dynamic submenu 'plant' passed through unchanged")
	print("  ✅ PASS: Non-dynamic submenus work correctly\n")

	print("=" + "=".repeat(49))
	print("✅ ALL TESTS PASSED - DYNAMIC SUBMENU WORKS!")
	print("=" + "=".repeat(49))
	quit(0)
