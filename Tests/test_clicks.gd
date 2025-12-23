extends Node

func _ready():
	print("\n🧪 CLICK TEST - Creating FarmView scene...")
	
	# Load and instantiate
	var packed_scene = load("res://scenes/FarmView.tscn")
	var farm_view = packed_scene.instantiate()
	add_child(farm_view)
	
	# Wait a bit for initialization
	await get_tree().create_timer(0.2).timeout
	
	print("\n🧪 Testing plot tile click...")
	
	if farm_view.plot_tiles and farm_view.plot_tiles.size() > 12:
		var tile = farm_view.plot_tiles[12]
		print("🧪 Tile grid_pos: %s, size: %s, mouse_filter: %s" % [tile.grid_position, tile.size, tile.mouse_filter])
		
		# Simulate press
		var press_event = InputEventMouseButton.new()
		press_event.button_index = MOUSE_BUTTON_LEFT
		press_event.pressed = true
		press_event.position = Vector2(40, 40)
		
		print("\n🧪 ===== INJECTING PRESS =====")
		tile._gui_input(press_event)
		
		await get_tree().create_timer(0.1).timeout
		
		# Simulate release
		var release_event = InputEventMouseButton.new()
		release_event.button_index = MOUSE_BUTTON_LEFT
		release_event.pressed = false
		release_event.position = Vector2(40, 40)
		
		print("🧪 ===== INJECTING RELEASE =====")
		tile._gui_input(release_event)
	else:
		print("❌ Could not find plot tiles!")
	
	await get_tree().create_timer(0.5).timeout
	print("\n🧪 ===== TEST COMPLETE =====\n")
	get_tree().quit()
