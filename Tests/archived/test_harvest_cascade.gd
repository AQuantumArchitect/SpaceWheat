extends SceneTree

## Test Harvest Measurement Cascade
## Check if harvesting one plot properly updates its entangled partner

const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")


func _initialize():
	print("\n" + "=".repeat(80))
	print("  HARVEST MEASUREMENT CASCADE TEST")
	print("=".repeat(80) + "\n")

	test_harvest_updates_partner()

	print("\n" + "=".repeat(80))
	print("  TEST COMPLETE")
	print("=".repeat(80) + "\n")

	quit()


func test_harvest_updates_partner():
	print("TEST: Harvest Updates Entangled Partner")
	print("─".repeat(40))

	var farm = FarmGrid.new()
	farm.grid_width = 3
	farm.grid_height = 3
	farm._ready()

	# Create entangled pair
	farm.plant_wheat(Vector2i(0, 0))
	farm.plant_wheat(Vector2i(1, 0))
	farm.create_entanglement(Vector2i(0, 0), Vector2i(1, 0), "phi_plus")

	var plot_a = farm.get_plot(Vector2i(0, 0))
	var plot_b = farm.get_plot(Vector2i(1, 0))
	var pair = farm.entangled_pairs[0]

	print("  Setup: Two entangled plots")
	print("  Pair purity: %.3f (should be 1.000)" % pair.get_purity())
	print("  Plot A θ: %.2f (should be π/2 ≈ 1.57)" % plot_a.quantum_state.theta)
	print("  Plot B θ: %.2f (should be π/2 ≈ 1.57)" % plot_b.quantum_state.theta)

	# Make plot A mature and harvest
	plot_a.growth_progress = 1.0
	plot_a.is_mature = true

	print("\n  Harvesting plot A...")
	var yield_data = farm.harvest_with_topology(Vector2i(0, 0))

	print("  Measured result: %s" % yield_data["state"])

	# Check what happened to plot B
	print("\n  After harvest:")
	print("  Entangled pairs left: %d (should be 0)" % farm.entangled_pairs.size())
	print("  Plot A quantum_state: %s" % ("null" if plot_a.quantum_state == null else "exists"))

	if plot_b.quantum_state != null:
		print("  Plot B quantum_state: exists")
		print("  Plot B θ: %.2f" % plot_b.quantum_state.theta)
		print("  Plot B state: %s" % plot_b.quantum_state.get_semantic_state())
		print("  Plot B entangled_pair: %s" % ("null" if plot_b.quantum_state.entangled_pair == null else "exists"))

		# Check if B collapsed
		var b_collapsed = plot_b.quantum_state.theta < 0.3 or plot_b.quantum_state.theta > 2.8
		if b_collapsed:
			print("\n  ✅ Plot B COLLAPSED (θ near 0 or π)")
		else:
			print("\n  ❌ Plot B NOT COLLAPSED (still in superposition!)")
			print("  ⚠️ Problem: Partner qubit wasn't updated after measurement")
	else:
		print("  Plot B quantum_state: null")
		print("  ⚠️ Plot B state was destroyed (unexpected)")

	print()
