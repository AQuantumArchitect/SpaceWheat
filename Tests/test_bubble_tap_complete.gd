extends Node

## Complete Bubble Tap Test
## 1. Plants wheat to create bubbles
## 2. Waits for bubbles to appear
## 3. Taps the bubbles
## 4. Verifies the tap action works

var farm_view: Node = null
var test_phase: int = 0

func _ready() -> void:
	print("\n")
	print("🧪 ═══════════════════════════════════════════════")
	print("🧪 COMPLETE BUBBLE TAP TEST")
	print("🧪 This test will:")
	print("🧪   1. Plant wheat on multiple plots")
	print("🧪   2. Verify bubbles appear")
	print("🧪   3. Tap the bubbles")
	print("🧪   4. Verify tap actions work")
	print("🧪 ═══════════════════════════════════════════════")
	print("\n")

	# Wait for initialization
	print("⏳ Waiting for game initialization...")
	await get_tree().create_timer(3.0).timeout

	# Get farm_view reference
	farm_view = get_node("/root/AutomatedTapTest/FarmView")
	if not farm_view:
		print("❌ FAILED: Could not find FarmView!")
		get_tree().quit(1)
		return

	var farm = farm_view.get_farm()
	if not farm:
		print("❌ FAILED: Farm not available!")
		get_tree().quit(1)
		return

	var quantum_viz = farm_view.quantum_viz
	if not quantum_viz or not quantum_viz.graph:
		print("❌ FAILED: Quantum visualization not available!")
		get_tree().quit(1)
		return

	print("✅ Initialization complete")
	print("   Farm: %s" % farm)
	print("   Quantum viz: %s" % quantum_viz)
	print("   Graph: %s" % quantum_viz.graph)
	print("\n")

	# Phase 1: Plant wheat to create bubbles
	print("═══════════════════════════════════════════════")
	print("PHASE 1: Planting wheat to create bubbles")
	print("═══════════════════════════════════════════════")

	var plots_to_plant = [Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]

	for plot_pos in plots_to_plant:
		print("   🌾 Planting wheat at %s..." % plot_pos)
		farm.plant_wheat(plot_pos)
		await get_tree().create_timer(0.3).timeout

	print("\n   ⏳ Waiting for bubbles to spawn...")
	await get_tree().create_timer(1.0).timeout

	# Verify bubbles exist
	var bubble_count = quantum_viz.graph.quantum_nodes.size()
	print("   📊 Bubble count: %d" % bubble_count)

	if bubble_count == 0:
		print("   ❌ NO BUBBLES CREATED!")
		print("   This means plot_planted signal might not be working")
		get_tree().quit(1)
		return

	print("   ✅ Bubbles created successfully!")
	print("\n")

	# Phase 2: Get bubble positions and tap them
	print("═══════════════════════════════════════════════")
	print("PHASE 2: Tapping bubbles")
	print("═══════════════════════════════════════════════")

	for i in range(min(bubble_count, 3)):
		var bubble = quantum_viz.graph.quantum_nodes[i]
		var bubble_pos = bubble.position
		var grid_pos = bubble.grid_position

		print("\n   🎯 Test %d: Tapping bubble at grid %s, screen pos %s" % [i + 1, grid_pos, bubble_pos])

		# Get plot state before tap
		var plot = farm.grid.get_plot_at(grid_pos)
		var before_measured = plot.is_measured if plot else false
		var before_planted = plot.is_planted if plot else false

		print("      Before: planted=%s, measured=%s" % [before_planted, before_measured])

		# Inject click at bubble position
		await get_tree().create_timer(0.2).timeout
		_inject_click(bubble_pos)
		await get_tree().create_timer(0.5).timeout

		# Check plot state after tap
		plot = farm.grid.get_plot_at(grid_pos)
		var after_measured = plot.is_measured if plot else false
		var after_planted = plot.is_planted if plot else false

		print("      After:  planted=%s, measured=%s" % [after_planted, after_measured])

		if before_planted and not before_measured and after_measured:
			print("      ✅ TAP WORKED! Plot was measured!")
		elif before_measured and not after_planted:
			print("      ✅ TAP WORKED! Plot was harvested!")
		else:
			print("      ⚠️  State didn't change as expected")

	print("\n")
	print("═══════════════════════════════════════════════")
	print("🧪 TEST COMPLETE")
	print("═══════════════════════════════════════════════")

	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


func _inject_click(pos: Vector2) -> void:
	"""Inject mouse click at position"""
	# Press
	var press_event = InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_LEFT
	press_event.pressed = true
	press_event.position = pos
	press_event.global_position = pos

	Input.parse_input_event(press_event)
	get_viewport().push_input(press_event)

	await get_tree().create_timer(0.1).timeout

	# Release
	var release_event = InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_LEFT
	release_event.pressed = false
	release_event.position = pos
	release_event.global_position = pos

	Input.parse_input_event(release_event)
	get_viewport().push_input(release_event)
