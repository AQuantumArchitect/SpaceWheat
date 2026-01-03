extends SceneTree

## Simple test of BootManager with actual PlayerShell and Farm

func _init():
	print("======================================================================")
	print("TEST: Clean Boot Sequence (Simple Integration)")
	print("======================================================================\n")

	# Create farm
	print("📝 Creating Farm...")
	var farm = load("res://Core/Farm.gd").new()
	get_root().add_child(farm)
	print("   ✓ Farm created\n")

	# Wait for farm._ready()
	await process_frame
	await process_frame

	# Create quantum visualization
	print("📝 Creating QuantumViz...")
	var BathQuantumViz = load("res://Core/Visualization/BathQuantumVisualizationController.gd")
	var quantum_viz = BathQuantumViz.new()
	get_root().add_child(quantum_viz)
	print("   ✓ QuantumViz created\n")

	# Create PlayerShell from scene
	print("📝 Creating PlayerShell...")
	var shell_scene = load("res://UI/PlayerShell.tscn")
	if not shell_scene:
		print("   ❌ Failed to load PlayerShell.tscn")
		quit(1)

	var shell = shell_scene.instantiate()
	get_root().add_child(shell)
	print("   ✓ PlayerShell created\n")

	# Wait for shell._ready()
	await process_frame

	# Test boot sequence
	print("📍 STARTING BOOT SEQUENCE...\n")

	var boot_start = Time.get_ticks_msec()

	# Call boot using the class directly
	var BootManagerClass = load("res://Core/Boot/BootManager.gd")
	BootManagerClass.boot(farm, shell, quantum_viz)

	var boot_time = Time.get_ticks_msec() - boot_start

	print("\n✅ Boot completed in %d ms\n" % boot_time)

	# Verify state
	print("📊 VERIFICATION:")
	print("──────────────────────────────────────────────────────────────────────")

	var success = true

	# Check farm state
	if farm.grid and farm.grid.biomes.size() > 0:
		print("✅ Farm has %d biomes" % farm.grid.biomes.size())
	else:
		print("❌ Farm grid not initialized")
		success = false

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
		success = false

	# Check visualization
	if quantum_viz.graph and quantum_viz.graph.layout_calculator:
		print("✅ Visualization initialized with layout calculator")
	else:
		print("❌ Visualization not fully initialized")
		success = false

	# Check UI
	var farm_ui = shell.get_farm_ui()
	if farm_ui:
		print("✅ FarmUI instantiated and mounted")
	else:
		print("❌ FarmUI not found")
		success = false

	# Check farm processing enabled
	if farm.is_processing():
		print("✅ Farm processing enabled")
	else:
		print("❌ Farm processing not enabled")
		success = false

	print("──────────────────────────────────────────────────────────────────────")

	# Final result
	print("\n" + "=======================================================================")
	if success:
		print("✅ CLEAN BOOT TEST PASSED")
		print("=======================================================================")
		quit(0)
	else:
		print("❌ CLEAN BOOT TEST FAILED")
		print("=======================================================================")
		quit(1)
