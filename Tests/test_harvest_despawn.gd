extends SceneTree

## Test harvest bubble despawn functionality

func _init():
	print("\n" + "=".repeat(80))
	print("HARVEST BUBBLE DESPAWN TEST")
	print("=".repeat(80))

	# Load required scripts
	var Farm = load("res://Core/Farm.gd")
	var BioticFluxBiome = load("res://Core/Environment/BioticFluxBiome.gd")
	var BathQuantumVisualizationController = load("res://Core/Visualization/BathQuantumVisualizationController.gd")

	# Create farm with BioticFlux biome
	var farm = Farm.new()
	farm.grid_size = Vector2i(3, 3)
	farm._ready()

	# Create biome
	var biome = BioticFluxBiome.new()
	biome._ready()
	farm.grid.register_biome("BioticFlux", biome)

	# Assign plots to biome
	for y in range(3):
		for x in range(3):
			farm.grid.assign_plot_to_biome(Vector2i(x, y), "BioticFlux")

	# Create visualization controller
	var viz = BathQuantumVisualizationController.new()
	viz.add_biome("BioticFlux", biome)
	viz.initialize()
	viz.connect_to_farm(farm)

	print("\n1. Initial state:")
	print("   Bubbles: %d" % viz.graph.quantum_nodes.size())
	print("   Projections: %d" % biome.active_projections.size())

	# Plant wheat at (1, 1)
	var pos = Vector2i(1, 1)
	print("\n2. Planting wheat at %s..." % pos)
	var success = farm.build("wheat", pos)
	print("   Plant result: %s" % success)
	print("   Bubbles after plant: %d" % viz.graph.quantum_nodes.size())
	print("   Projections after plant: %d" % biome.active_projections.size())

	if viz.graph.quantum_nodes.size() != 1:
		print("❌ FAIL: Expected 1 bubble after planting, got %d" % viz.graph.quantum_nodes.size())
		quit()

	if biome.active_projections.size() != 1:
		print("❌ FAIL: Expected 1 projection after planting, got %d" % biome.active_projections.size())
		quit()

	# Get initial quantum state radius
	var plot = farm.grid.get_plot(pos)
	var initial_radius = plot.quantum_state.radius if plot.quantum_state else 0.0
	print("   Initial radius: %.3f" % initial_radius)

	# Harvest wheat
	print("\n3. Harvesting wheat at %s..." % pos)
	var harvest_result = farm.harvest_plot(pos)
	print("   Harvest result: %s" % harvest_result)
	print("   Energy extracted: %.3f" % harvest_result.get("energy", 0.0))
	print("   Expected energy (10%% of radius): %.3f" % (initial_radius * 0.1))
	print("   Bubbles after harvest: %d" % viz.graph.quantum_nodes.size())
	print("   Projections after harvest: %d" % biome.active_projections.size())

	# Verify bubble despawned
	if viz.graph.quantum_nodes.size() != 0:
		print("❌ FAIL: Expected 0 bubbles after harvest, got %d" % viz.graph.quantum_nodes.size())
		quit()
	else:
		print("✅ PASS: Bubble despawned correctly")

	# Verify projection removed
	if biome.active_projections.size() != 0:
		print("❌ FAIL: Expected 0 projections after harvest, got %d" % biome.active_projections.size())
		quit()
	else:
		print("✅ PASS: Projection removed correctly")

	# Verify energy extraction (10% of radius)
	var expected_energy = initial_radius * 0.1
	var actual_energy = harvest_result.get("energy", 0.0)
	if abs(actual_energy - expected_energy) < 0.001:
		print("✅ PASS: Energy extraction correct (10%% of radius)")
	else:
		print("❌ FAIL: Energy mismatch - expected %.3f, got %.3f" % [expected_energy, actual_energy])
		quit()

	# Verify plot is cleared but gates preserved
	if plot.is_planted:
		print("❌ FAIL: Plot still marked as planted after harvest")
		quit()
	else:
		print("✅ PASS: Plot cleared after harvest")

	if plot.persistent_gates.size() == 0:
		print("✅ PASS: Persistent gates preserved (none existed)")
	else:
		print("✅ PASS: Persistent gates preserved (%d gates)" % plot.persistent_gates.size())

	print("\n" + "=".repeat(80))
	print("✅ ALL TESTS PASSED")
	print("=".repeat(80))

	quit()
