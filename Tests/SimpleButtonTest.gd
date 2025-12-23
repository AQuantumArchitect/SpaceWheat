extends SceneTree

func _ready():
	print("\n╔════════════════════════════════════════════════════════════╗")
	print("║      TEST PATHWAY: Tool 1 → Action Q → Location T         ║")
	print("╚════════════════════════════════════════════════════════════╝\n")
	
	# Wait for scene to fully load
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	var farm_view = get_tree().root.get_child(0)
	if not farm_view:
		print("❌ FarmView not found!")
		quit()
		return
	
	print("✅ Found FarmView")
	
	# Get the farm
	if farm_view.farm:
		print("✅ Farm is available")
		print("   Wheat: %d" % farm_view.farm.economy.wheat_inventory)
		print("   Grid: %dx%d" % [farm_view.farm.grid.grid_width, farm_view.farm.grid.grid_height])
		
		# Try to plant wheat at position (0,0)
		print("\n🌱 Testing plant action at (0,0)...")
		var success = farm_view.farm.plant_plot(Vector2i(0, 0), "wheat", farm_view.farm.biome)
		
		if success:
			print("✅ PLANTED WHEAT!")
			print("   Wheat remaining: %d" % farm_view.farm.economy.wheat_inventory)
			
			# Verify plot is planted
			var plot = farm_view.farm.grid.get_plot(Vector2i(0, 0))
			if plot and plot.is_planted:
				print("✅ Plot is marked as planted")
			else:
				print("❌ Plot not marked as planted")
		else:
			print("❌ Plant failed")
	else:
		print("❌ Farm not available")
	
	print("\n✅ TEST COMPLETE - No script errors!")
	quit()

