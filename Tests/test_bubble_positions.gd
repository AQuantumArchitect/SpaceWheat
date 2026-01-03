extends Node

## Bubble Position Diagnostic
## Outputs bubble positions to help debug touch input issues

func _ready() -> void:
	print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("BUBBLE POSITION DIAGNOSTIC")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

	await get_tree().create_timer(2.5).timeout
	await run_diagnostic()
	print("\n✅ Diagnostic complete - press ESC to quit")


func run_diagnostic() -> void:
	var scene = get_tree().current_scene
	var farm_view = scene.get_node_or_null("FarmView")

	if not farm_view:
		print("❌ No FarmView")
		return

	var farm = farm_view.get_farm()
	var quantum_viz = farm_view.quantum_viz

	if not farm or not quantum_viz:
		print("❌ Farm/quantum_viz missing")
		return

	# Print viewport info
	var viewport = get_viewport()
	var viewport_size = viewport.get_visible_rect().size
	print("📐 VIEWPORT INFO:")
	print("   Size: %.0f × %.0f" % [viewport_size.x, viewport_size.y])
	print()

	# Plant wheat on several plots
	print("🌾 Planting wheat on 3 plots...")
	var test_positions: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(2, 0),
		Vector2i(4, 0)
	]

	for pos in test_positions:
		var positions: Array[Vector2i] = [pos]
		farm.batch_plant(positions, "wheat")

	await get_tree().create_timer(0.5).timeout

	# Check bubbles
	var bubble_count = quantum_viz.graph.quantum_nodes.size()
	print("   Created %d bubbles\n" % bubble_count)

	print("🎯 BUBBLE POSITIONS:")
	print("   Format: grid_pos → global_pos (clickable?)\n")

	for grid_pos in quantum_viz.graph.quantum_nodes.keys():
		var bubble = quantum_viz.graph.quantum_nodes[grid_pos]
		var global_pos = bubble.global_position
		var local_pos = bubble.position

		# Check if position is within viewport
		var in_viewport = (
			global_pos.x >= 0 and global_pos.x <= viewport_size.x and
			global_pos.y >= 0 and global_pos.y <= viewport_size.y
		)

		var status = "✅ IN VIEWPORT" if in_viewport else "❌ OFF-SCREEN"

		print("   %s → global:(%.1f, %.1f) local:(%.1f, %.1f) %s" % [
			grid_pos,
			global_pos.x, global_pos.y,
			local_pos.x, local_pos.y,
			status
		])

		# Check input handling capability
		if bubble.has_method("_input_event"):
			print("      Input method: _input_event() ✅")
		elif bubble.has_method("_gui_input"):
			print("      Input method: _gui_input() ✅")
		elif bubble.has_method("_unhandled_input"):
			print("      Input method: _unhandled_input() ✅")
		else:
			print("      Input method: NONE ❌")

	# Check QuantumForceGraph input settings
	print("\n⚙️  QUANTUMFORCEGRAPH SETTINGS:")
	var graph = quantum_viz.graph
	print("   process_mode: %d (0=inherit, 1=pausable, 2=always, 3=disabled)" % graph.process_mode)
	print("   input enabled: %s" % (not graph.is_set_process_input(false)))
	print("   position: %s" % graph.position)
	print("   global_position: %s" % graph.global_position)
	print("   z_index: %d" % graph.z_index)

	# Check CanvasLayer
	var canvas_layer = graph.get_parent()
	if canvas_layer is CanvasLayer:
		print("\n📺 CANVASLAYER INFO:")
		print("   layer: %d" % canvas_layer.layer)
		print("   visible: %s" % canvas_layer.visible)

	# Print input chain
	print("\n🔗 INPUT CHAIN:")
	print("   1. User clicks screen at position X,Y")
	print("   2. Godot routes to Node2D in CanvasLayer")
	print("   3. QuantumForceGraph._unhandled_input() receives event")
	print("   4. Graph checks which QuantumNode is at position")
	print("   5. Emits node_clicked signal")
	print("   6. FarmView._on_quantum_node_clicked() handles it")
	print()
	print("   💡 TIP: Click on bubbles at the positions shown above!")
	print("        If they don't work, bubbles may be off-screen or z-order issue")
