extends SceneTree

## Test Script: Phase 2 - Dynamic Menu Generation
## Verifies that menus are generated from biome capabilities

const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")

func _init():
	print("======================================================================")
	print("TESTING PHASE 2: DYNAMIC MENU GENERATION")
	print("======================================================================")
	print()

	# Create minimal farm setup for testing
	var farm = load("res://Core/Farm.gd").new()
	farm.name = "TestFarm"
	root.add_child(farm)

	# Wait for farm initialization
	await process_frame
	await process_frame

	# Test menu generation for each biome
	test_biome_menu(farm, "BioticFlux", Vector2i(0, 0))
	test_biome_menu(farm, "Forest", Vector2i(2, 0))
	test_biome_menu(farm, "Kitchen", Vector2i(4, 0))
	test_biome_menu(farm, "Market", Vector2i(1, 1))

	print()
	print("======================================================================")
	print("✅ PHASE 2 TEST COMPLETE")
	print("======================================================================")

	quit()

func test_biome_menu(farm, biome_name: String, position: Vector2i):
	"""Test menu generation for a specific biome"""
	print("Testing %s biome at %s:" % [biome_name, position])

	# Assign plot to biome
	if farm.grid:
		farm.grid.plot_biome_assignments[position] = biome_name

	# Generate plant submenu
	var base = {
		"name": "Plant",
		"Q": {"action": "", "label": "Empty", "emoji": ""},
		"E": {"action": "", "label": "Empty", "emoji": ""},
		"R": {"action": "", "label": "Empty", "emoji": ""}
	}

	var menu = ToolConfig._generate_plant_submenu(base, farm, position)

	# Verify menu structure
	print("  Menu name: %s" % menu.name)
	print("  Q: %s [%s] → %s" % [menu.Q.emoji, menu.Q.label, menu.Q.action])
	print("  E: %s [%s] → %s" % [menu.E.emoji, menu.E.label, menu.E.action])
	print("  R: %s [%s] → %s" % [menu.R.emoji, menu.R.label, menu.R.action])

	# Verify actions are parametric (not hard-coded)
	if menu.Q.action != "" and not menu.Q.action.begins_with("plant_"):
		push_error("❌ Action doesn't follow parametric pattern: %s" % menu.Q.action)
	else:
		print("  ✅ Actions follow parametric pattern (plant_<type>)")

	print()
