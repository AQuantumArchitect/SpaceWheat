extends SceneTree

## Test BootManager.boot() sequence to verify all phases complete in order

func _init():
	print("======================================================================")
	print("TEST: BootManager Boot Sequence")
	print("======================================================================\n")

	# Track phase completion order
	var phases_completed = []

	# Create the game components
	print("📝 Creating game components...")
	var farm = load("res://Core/Farm.gd").new()
	print("   ✓ Farm created")

	# Add farm to scene tree so it can initialize
	var root = get_root()
	root.add_child(farm)
	print("   ✓ Farm added to tree")

	# Wait for farm._ready() to complete
	await process_frame
	await process_frame

	# Create quantum visualization
	var BathQuantumViz = load("res://Core/Visualization/BathQuantumVisualizationController.gd")
	var quantum_viz = BathQuantumViz.new()
	root.add_child(quantum_viz)
	print("   ✓ QuantumViz created\n")

	# Create mock PlayerShell (just need the load_farm_ui method)
	print("📝 Creating mock PlayerShell...")
	var shell = _create_mock_shell(root)
	print("   ✓ Mock shell created\n")

	# Create BootManager and connect signals to track phases
	print("📝 Connecting BootManager signals...")
	var boot_manager = load("res://Core/Boot/BootManager.gd").new()
	root.add_child(boot_manager)

	if boot_manager.has_signal("core_systems_ready"):
		boot_manager.core_systems_ready.connect(func(): phases_completed.append("CORE_SYSTEMS"))
		print("   ✓ Connected core_systems_ready")
	if boot_manager.has_signal("visualization_ready"):
		boot_manager.visualization_ready.connect(func(): phases_completed.append("VISUALIZATION"))
		print("   ✓ Connected visualization_ready")
	if boot_manager.has_signal("ui_ready"):
		boot_manager.ui_ready.connect(func(): phases_completed.append("UI"))
		print("   ✓ Connected ui_ready")
	if boot_manager.has_signal("game_ready"):
		boot_manager.game_ready.connect(func(): phases_completed.append("GAME"))
		print("   ✓ Connected game_ready")

	# Wait one frame to ensure all connections are ready
	await process_frame

	# Call boot sequence
	print("\n📍 STARTING BOOT SEQUENCE...\n")
	BootManager.boot(farm, shell, quantum_viz)

	# Wait for any deferred calls
	await process_frame

	# Verify phase order
	print("\n📊 VERIFICATION:")
	print("─".repeat(70))

	var expected_phases = ["CORE_SYSTEMS", "VISUALIZATION", "UI", "GAME"]
	var success = true

	if phases_completed.size() != expected_phases.size():
		print("❌ Expected %d phases, got %d" % [expected_phases.size(), phases_completed.size()])
		success = false
	else:
		for i in range(phases_completed.size()):
			var expected = expected_phases[i]
			var actual = phases_completed[i]
			if expected == actual:
				print("✅ Phase %d: %s (correct)" % [i + 1, actual])
			else:
				print("❌ Phase %d: Expected %s, got %s" % [i + 1, expected, actual])
				success = false

	print("─".repeat(70))

	# Verify farm state
	print("\n🌾 FARM STATE:")
	print("   Farm: %s" % ("✓ OK" if farm else "❌ NULL"))
	print("   Grid: %s" % ("✓ OK" if farm.grid else "❌ NULL"))
	print("   Biomes: %s" % ("✓ OK" if farm.grid.get_biome_count() > 0 else "❌ EMPTY"))

	# Verify biome baths
	print("\n🛁 BIOME BATHS:")
	var baths_ok = true
	for biome_name in farm.grid.get_biome_names():
		var biome = farm.grid.get_biome(biome_name)
		if biome.bath and biome.bath._hamiltonian and biome.bath._lindblad:
			print("   %s: ✓ OK" % biome_name)
		else:
			print("   %s: ❌ Missing components" % biome_name)
			baths_ok = false

	success = success and baths_ok

	# Verify quantum visualization
	print("\n📊 VISUALIZATION:")
	if quantum_viz.graph:
		print("   Graph: ✓ Created")
		if quantum_viz.graph.layout_calculator:
			print("   Calculator: ✓ Created")
		else:
			print("   Calculator: ❌ NULL")
			success = false
	else:
		print("   Graph: ❌ NULL")
		success = false

	# Final result
	print("\n" + "=".repeat(70))
	if success and phases_completed.size() == expected_phases.size():
		print("✅ BOOT SEQUENCE TEST PASSED")
		print("=".repeat(70))
		quit(0)
	else:
		print("❌ BOOT SEQUENCE TEST FAILED")
		print("=".repeat(70))
		quit(1)


func _create_mock_shell(parent: Node) -> Node:
	"""Create a minimal mock PlayerShell for testing"""
	var MockShell = preload("res://UI/PlayerShell.gd")
	var shell = Node.new()
	shell.name = "MockPlayerShell"

	# Add a load_farm_ui method that BootManager expects
	var load_farm_ui_fn = func(farm_ui):
		if farm_ui:
			print("   ✓ Mock shell load_farm_ui() called successfully")

	# Store the function as a callable
	shell.set_meta("_load_farm_ui", load_farm_ui_fn)

	parent.add_child(shell)
	return shell
