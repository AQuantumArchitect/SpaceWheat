extends SceneTree

var farm_view = null

func _init():
	var sep = "============================================================"
	print("\n" + sep)
	print("🧪 MOUSE INPUT INJECTION TEST - PROPER VIEWPORT TESTING")
	print(sep + "\n")

func _initialize():
	print("📦 Loading FarmView scene...")
	var scene = load("res://scenes/FarmView.tscn")
	farm_view = scene.instantiate()
	root.add_child(farm_view)
	
	print("⏳ Waiting 2 seconds for full scene initialization...")
	await create_timer(2.0).timeout
	
	print("✓ Scene should be fully ready now\n")
	
	# Get viewport to inject input properly
	var viewport = root.get_viewport()
	print("📺 Viewport: " + str(viewport))
	print("📏 Viewport size: " + str(viewport.get_visible_rect().size))
	
	# Check if plot tiles exist and are ready
	if farm_view.plot_tiles and farm_view.plot_tiles.size() > 0:
		var tile0 = farm_view.plot_tiles[0]
		print("\n🔍 Plot Tile 0 status:")
		print("   Grid pos: " + str(tile0.grid_position))
		print("   Position: " + str(tile0.global_position))
		print("   Size: " + str(tile0.size))
		print("   Visible: " + str(tile0.visible))
		print("   Mouse filter: " + str(tile0.mouse_filter))
		print("   In tree: " + str(tile0.is_inside_tree()))
	else:
		print("❌ ERROR: No plot tiles found!")
		quit()
		return
	
	var sep = "============================================================"
	
	# TEST 1: Click on first plot tile
	print("\n" + sep)
	print("🖱️ TEST 1: Click on Plot Tile 0")
	print(sep)
	
	var tile0 = farm_view.plot_tiles[0]
	var tile_center = tile0.global_position + tile0.size / 2
	print("📍 Tile 0 center position: " + str(tile_center))
	
	await create_timer(0.5).timeout
	print("\n⬇️ PRESSING at " + str(tile_center) + "...")
	
	var press_event = InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_LEFT
	press_event.pressed = true
	press_event.position = tile_center
	press_event.global_position = tile_center
	viewport.push_input(press_event)
	
	await create_timer(0.2).timeout
	print("⬆️ RELEASING at " + str(tile_center) + "...")
	
	var release_event = InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_LEFT
	release_event.pressed = false
	release_event.position = tile_center
	release_event.global_position = tile_center
	viewport.push_input(release_event)
	
	await create_timer(0.5).timeout
	
	# TEST 2: Click on middle tile
	print("\n" + sep)
	print("🖱️ TEST 2: Click on Plot Tile 12 (middle)")
	print(sep)
	
	var tile12 = farm_view.plot_tiles[12]
	var tile12_center = tile12.global_position + tile12.size / 2
	print("📍 Tile 12 center position: " + str(tile12_center))
	
	await create_timer(0.5).timeout
	print("\n⬇️ PRESSING at " + str(tile12_center) + "...")
	
	var press_event2 = InputEventMouseButton.new()
	press_event2.button_index = MOUSE_BUTTON_LEFT
	press_event2.pressed = true
	press_event2.position = tile12_center
	press_event2.global_position = tile12_center
	viewport.push_input(press_event2)
	
	await create_timer(0.2).timeout
	print("⬆️ RELEASING at " + str(tile12_center) + "...")
	
	var release_event2 = InputEventMouseButton.new()
	release_event2.button_index = MOUSE_BUTTON_LEFT
	release_event2.pressed = false
	release_event2.position = tile12_center
	release_event2.global_position = tile12_center
	viewport.push_input(release_event2)
	
	await create_timer(1.0).timeout
	
	print("\n" + sep)
	print("✅ TEST COMPLETE - Expected prints:")
	print("   🐭🐭🐭 FarmView._input() = mouse event reached top level")
	print("   🖱️ QuantumForceGraph._input() = graph received event")
	print("   🎯 PlotTile._gui_input() = tile received event ⚠️ CRITICAL")
	print("   📡 FarmView._on_tile_clicked = click handler called")
	print("   👆 Click at = plot click processed")
	print(sep + "\n")
	
	quit()
