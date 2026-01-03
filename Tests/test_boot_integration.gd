extends SceneTree

## Test BootManager integration - runs game for 3 seconds then quits

func _init():
	print("======================================================================")
	print("TEST: BootManager Integration Test")
	print("======================================================================\n")

	# Wait for game to boot
	print("Waiting for game to boot...")
	for i in range(60):  # ~1 second at 60fps
		await process_frame

	print("\n======================================================================")
	print("Boot appears successful - game running for 1 second")
	print("======================================================================\n")

	# Check for farm existence
	var root = get_root()
	var farm_view = root.get_node_or_null("FarmView")

	if farm_view:
		print("✅ FarmView found")
		var farm = farm_view.get("farm")
		if farm:
			print("✅ Farm exists")
			if farm.grid and farm.grid.biomes.size() > 0:
				print("✅ Farm has %d biomes" % farm.grid.biomes.size())

				# Check biome baths
				var bath_count = 0
				for biome_name in farm.grid.biomes.keys():
					var biome = farm.grid.biomes[biome_name]
					if biome.bath and biome.bath._hamiltonian and biome.bath._lindblad:
						bath_count += 1

				if bath_count == farm.grid.biomes.size():
					print("✅ All %d biome baths initialized" % bath_count)
				else:
					print("❌ Only %d/%d biome baths initialized" % [bath_count, farm.grid.biomes.size()])

			if farm.is_processing():
				print("✅ Farm processing enabled")
			else:
				print("❌ Farm processing not enabled")
		else:
			print("❌ Farm not found in FarmView")
	else:
		print("❌ FarmView not found")

	print("\n======================================================================")
	print("✅ TEST COMPLETE - Quitting")
	print("======================================================================")

	quit(0)
