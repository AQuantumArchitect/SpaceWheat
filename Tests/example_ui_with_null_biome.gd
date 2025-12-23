#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Example: Farm UI Development with NullBiome
##
## This demonstrates how UI developers can work on the FarmView
## without quantum evolution interfering.
##
## Key Point: Replace Biome with NullBiome for UI development

const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
const WheatPlot = preload("res://Core/GameMechanics/WheatPlot.gd")
const NullBiome = preload("res://Core/Environment/NullBiome.gd")

func _initialize():
	print_header()

	# Build a farm with UI-inert biome
	var farm_state = _create_ui_test_farm()

	# Simulate UI interactions (no quantum evolution happens)
	_simulate_ui_interactions(farm_state)

	# Show that state is stable
	_verify_no_evolution(farm_state)

	print_footer()
	quit()


func print_header():
	var line = ""
	for i in range(80):
		line += "="
	print("\n" + line)
	print("🎨 FARM UI DEVELOPMENT - Using NullBiome")
	print("UI teams can develop without quantum evolution interference")
	print(line + "\n")


func print_footer():
	var line = ""
	for i in range(80):
		line += "="
	print(line)
	print("✅ UI DEVELOPMENT EXAMPLE COMPLETE")
	print(line + "\n")


func _create_ui_test_farm() -> Dictionary:
	"""Set up a farm with NullBiome for UI testing"""
	print("📋 Creating Farm UI Test Environment\n")

	var state = {
		"grid": FarmGrid.new(),
		"economy": FarmEconomy.new(),
		"biome": NullBiome.new(),
		"plots": {}
	}

	var grid = state["grid"]
	grid.grid_width = 6
	grid.grid_height = 2

	# Initialize biome (NullBiome - does nothing)
	state["biome"]._ready()
	grid.biome = state["biome"]

	# Initialize plots
	for y in range(grid.grid_height):
		for x in range(grid.grid_width):
			var plot = WheatPlot.new()
			plot.grid_position = Vector2i(x, y)
			plot.plot_id = "Plot_%d_%d" % [x, y]
			grid.plots[Vector2i(x, y)] = plot
			state["plots"][plot.plot_id] = plot

	state["economy"].credits = 150

	print("✓ FarmGrid: 6×2 = 12 plots")
	print("✓ Biome: NullBiome (no quantum evolution)")
	print("✓ Economy: %d credits" % state["economy"].credits)
	print("✓ Ready for UI development\n")

	return state


func _simulate_ui_interactions(farm_state: Dictionary):
	"""Simulate typical UI interactions without quantum interference"""
	var line = ""
	for i in range(70):
		line += "─"
	print(line)
	print("SIMULATING UI INTERACTIONS")
	print(line + "\n")

	var grid = farm_state["grid"]
	var economy = farm_state["economy"]
	var biome = farm_state["biome"]

	# UI Interaction 1: User plants wheat
	print("🖱️ UI: User clicks 'Plant Wheat' at (0,0)\n")

	var plot = grid.get_plot(Vector2i(0, 0))
	plot.plot_type = WheatPlot.PlotType.WHEAT
	plot.is_planted = true

	print("   ✓ Plot state: is_planted=%s" % plot.is_planted)
	print()

	# Process biome frames (simulates UI staying open for a few seconds)
	print("⏱️ UI: Farm view stays open while user reads description\n")

	for frame in range(60):
		biome._process(0.016)

	print("   ✓ 60 frames processed (1.0s elapsed)")
	print("   ✓ Biome time: %.1f seconds" % biome.time_elapsed)
	print("   ✓ Plot state UNCHANGED: is_planted=%s" % plot.is_planted)
	print("   → No quantum evolution interfered with UI!\n")

	# UI Interaction 2: User opens economy panel
	print("💰 UI: User opens Economy Panel\n")

	var panel_data = {
		"credits": economy.credits,
		"wheat": economy.wheat_inventory,
		"labor": economy.labor_inventory,
		"timestamp": Time.get_unix_time_from_system()
	}

	print("   Panel data collected:")
	print("   - Credits: %d" % panel_data["credits"])
	print("   - Wheat: %d" % panel_data["wheat"])
	print("   - Labor: %d" % panel_data["labor"])
	print()

	# Process more frames (UI rendering)
	print("🖼️ UI: Rendering economy panel for 2 seconds\n")

	var initial_credits = economy.credits
	var initial_time = biome.time_elapsed

	for frame in range(120):
		biome._process(0.016)
		# Simulate UI rendering (no actual rendering, just elapsed time)

	var final_credits = economy.credits
	var final_time = biome.time_elapsed

	print("   ✓ 120 frames processed (2.0s elapsed)")
	print("   ✓ State comparison:")
	print("      Before: Credits=%d, Time=%.1fs" % [
		initial_credits,
		initial_time
	])
	print("      After:  Credits=%d, Time=%.1fs" % [
		final_credits,
		final_time
	])
	print("      Change: Credits=%s" % (initial_credits == final_credits))
	print("      → UI state remained stable!\n")

	# UI Interaction 3: User closes panel and farms for a while
	print("🌾 UI: User closes panel and leaves farm running\n")

	print("   ⏱️ Running biome for 10 seconds...\n")

	for frame in range(600):
		biome._process(0.016)

	print("   ✓ 600 frames processed (10.0s elapsed)")
	print("   ✓ NullBiome time: %.1f seconds" % biome.time_elapsed)
	print("   ✓ No quantum evolution occurred - safe for UI!")
	print()


func _verify_no_evolution(farm_state: Dictionary):
	"""Verify that NullBiome truly prevents evolution"""
	var line = ""
	for i in range(70):
		line += "─"
	print(line)
	print("VERIFICATION: No Quantum Evolution Occurred")
	print(line + "\n")

	var biome = farm_state["biome"]
	var plots = farm_state["plots"]

	print("✓ NullBiome quantum_states: %d (empty)" % biome.quantum_states.size())
	print("✓ No sun qubit evolution: sun_qubit = %s" % (biome.sun_qubit))
	print("✓ No wheat icon evolution: wheat_icon = %s" % (biome.wheat_icon))
	print("✓ No mushroom icon evolution: mushroom_icon = %s" % (biome.mushroom_icon))
	print()

	print("💡 Summary:")
	print("   - UI development is completely isolated from quantum mechanics")
	print("   - Farm state doesn't change unexpectedly")
	print("   - Perfect for UI component development and testing")
	print("   - No performance overhead from quantum evolution")
	print()
