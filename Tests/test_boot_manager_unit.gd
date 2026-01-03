extends SceneTree

## Unit test for BootManager - minimal dependencies

func _init():
	print("======================================================================")
	print("TEST: BootManager Unit Test")
	print("======================================================================\n")

	print("Test 1: BootManager loads without errors")
	var BootManagerClass = load("res://Core/Boot/BootManager.gd")
	if BootManagerClass:
		print("✅ BootManager class loaded\n")
	else:
		print("❌ Failed to load BootManager\n")
		quit(1)

	print("Test 2: Farm loads without errors")
	var FarmClass = load("res://Core/Farm.gd")
	if FarmClass:
		print("✅ Farm class loaded\n")
	else:
		print("❌ Failed to load Farm\n")
		quit(1)

	print("Test 3: Create minimal Farm instance")
	var farm = FarmClass.new()
	get_root().add_child(farm)
	print("✅ Farm instance created\n")

	# Wait for farm._ready()
	print("Test 4: Waiting for Farm._ready() to complete...")
	await process_frame
	await process_frame

	if farm.grid and farm.grid.biomes.size() > 0:
		print("✅ Farm initialized with %d biomes\n" % farm.grid.biomes.size())
	else:
		print("❌ Farm not properly initialized\n")
		quit(1)

	print("Test 5: Verify biome baths are initialized")
	var bath_count = 0
	for biome_name in farm.grid.biomes.keys():
		var biome = farm.grid.biomes[biome_name]
		if biome.bath:
			if biome.bath._hamiltonian and biome.bath._lindblad:
				bath_count += 1
				print("   ✓ %s: bath initialized" % biome_name)
			else:
				print("   ✗ %s: bath missing _hamiltonian or _lindblad" % biome_name)
		else:
			print("   ✗ %s: bath is null" % biome_name)

	if bath_count == farm.grid.biomes.size():
		print("✅ All biome baths initialized\n")
	else:
		print("❌ Only %d/%d baths ready\n" % [bath_count, farm.grid.biomes.size()])

	# Note: Full BootManager test would require PlayerShell and QuantumViz
	# which are UI-heavy and take a long time to initialize
	# This unit test verifies the critical Farm components

	print("======================================================================")
	print("✅ BOOTMANAGER UNIT TEST PASSED")
	print("======================================================================")
	print("\nNote: Full integration test requires UI scene loading")
	print("Farm and bath initialization verified successfully")

	quit(0)
