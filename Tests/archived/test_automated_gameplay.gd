extends SceneTree

## Automated Gameplay Test
## Simulates real player actions to test all systems integration

var farm_view = null
var test_time: float = 0.0
var test_phase: int = 0

func _initialize():
	print("\n" + "=".repeat(80))
	print("  AUTOMATED GAMEPLAY TEST - FULL SYSTEM INTEGRATION")
	print("=".repeat(80) + "\n")

	# Load and instance the main scene
	var main_scene = load("res://UI/FarmView.tscn")
	if not main_scene:
		print("❌ FAILED: Could not load FarmView.tscn")
		quit(1)
		return

	farm_view = main_scene.instantiate()
	root.add_child(farm_view)

	# Wait for initialization
	await _wait_frames(3)

	print("✅ FarmView loaded and initialized\n")

	# Run automated gameplay
	_run_gameplay_test()

	print("\n" + "=".repeat(80))
	print("  AUTOMATED GAMEPLAY TEST COMPLETE ✅")
	print("=".repeat(80) + "\n")

	quit()


func _run_gameplay_test():
	"""Simulate a real gameplay session"""

	# PHASE 1: Plant initial wheat
	print("PHASE 1: Planting Initial Wheat")
	print("─".repeat(40))

	# Give player starting money
	farm_view.economy.credits = 100

	# Plant wheat in a 3x3 grid
	var plant_positions = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)
	]

	for pos in plant_positions:
		farm_view._select_plot(pos)
		farm_view._on_plant_pressed()

	print("  Planted %d wheat plots" % plant_positions.size())
	print("  Credits remaining: %d" % farm_view.economy.credits)
	print()

	# Let game run for 5 seconds (wheat growing + vocabulary evolving)
	await _simulate_time(5.0)

	# PHASE 2: Check Berry Phase Accumulation
	print("PHASE 2: Berry Phase Accumulation Check")
	print("─".repeat(40))

	var total_berry = 0.0
	var plots_with_berry = 0

	for pos in plant_positions:
		var plot = farm_view.farm_grid.get_plot(pos)
		if plot and plot.is_planted and plot.quantum_state:
			var berry = plot.quantum_state.get_berry_phase_abs()
			var stability = plot.quantum_state.get_cultural_stability()

			if berry > 0.0:
				total_berry += berry
				plots_with_berry += 1

			if plots_with_berry == 1:  # Print first plot as example
				print("  Example plot [%s]:" % pos)
				print("    Berry phase: %.3f" % berry)
				print("    Cultural stability: %.2f" % stability)
				print("    Reliability bonus: %.2fx" % plot.quantum_state.get_reliability_bonus())

	print("  Plots with Berry phase: %d / %d" % [plots_with_berry, plant_positions.size()])
	print("  Average Berry phase: %.3f" % (total_berry / max(1, plots_with_berry)))

	if plots_with_berry == plant_positions.size():
		print("  ✅ All plots accumulating Berry phase")
	else:
		print("  ⚠️ WARNING: Some plots not accumulating Berry phase")

	print()

	# PHASE 3: Vocabulary Evolution Check
	print("PHASE 3: Vocabulary Evolution Status")
	print("─".repeat(40))

	if farm_view.vocabulary_evolution:
		var stats = farm_view.vocabulary_evolution.get_evolution_stats()
		var discovered = farm_view.vocabulary_evolution.get_discovered_vocabulary()

		print("  Evolving concepts: %d" % stats.pool_size)
		print("  Total spawned: %d" % stats.total_spawned)
		print("  Total cannibalized: %d" % stats.total_cannibalized)
		print("  Discoveries: %d" % stats.discovered_count)
		print("  Mutation pressure: %.2f" % stats.mutation_pressure)

		if stats.total_spawned > 5:
			print("  ✅ Vocabulary evolving (spawned %d concepts)" % stats.total_spawned)
		else:
			print("  ⚠️ WARNING: Limited vocabulary evolution")

		if discovered.size() > 0:
			print("  ✅ DISCOVERED NEW EMOJI PAIRS!")
			for i in range(min(3, discovered.size())):
				var d = discovered[i]
				print("    %s ↔ %s (γ=%.2f)" % [d.north, d.south, d.berry_phase])
	else:
		print("  ❌ FAILED: Vocabulary evolution not initialized")

	print()

	# PHASE 4: Wait for Maturity and Harvest
	print("PHASE 4: Waiting for Maturity and Harvesting")
	print("─".repeat(40))

	print("  Waiting for wheat to mature...")

	# Wait up to 15 seconds for maturity
	var wait_time = 0.0
	var any_mature = false

	while wait_time < 15.0:
		await _simulate_time(0.5)
		wait_time += 0.5

		# Check if any wheat is mature
		for pos in plant_positions:
			var plot = farm_view.farm_grid.get_plot(pos)
			if plot and plot.is_mature:
				any_mature = true
				break

		if any_mature:
			break

	if any_mature:
		print("  ✅ Wheat matured after %.1fs" % wait_time)
	else:
		print("  ⚠️ WARNING: No wheat matured in 15s")

	# Harvest all mature wheat
	var harvested_count = 0
	var total_yield = 0

	for pos in plant_positions:
		var plot = farm_view.farm_grid.get_plot(pos)
		if plot and plot.is_mature:
			# Measure first
			farm_view._select_plot(pos)
			farm_view._on_measure_pressed()

			# Then harvest
			await get_tree().process_frame
			farm_view._on_harvest_pressed()

			harvested_count += 1

	print("  Harvested %d plots" % harvested_count)
	print("  Total wheat: %d" % farm_view.economy.wheat)
	print()

	# PHASE 5: Strange Attractor Status
	print("PHASE 5: Strange Attractor (Carrion Throne)")
	print("─".repeat(40))

	if farm_view.imperium_icon:
		var history = farm_view.imperium_icon.get_attractor_history()
		var season = farm_view.imperium_icon.get_political_season() if farm_view.imperium_icon.has_method("get_political_season") else "Unknown"

		print("  Attractor history size: %d" % history.size())
		print("  Current season: %s" % season)

		if history.size() > 0:
			print("  ✅ Strange attractor evolving")

			var latest = history[history.size() - 1]
			print("  Latest state:")
			print("    Harvest/Decay: %s" % latest.harvest_decay)
			print("    Authority/Growth: %s" % latest.authority_growth)
		else:
			print("  ⚠️ No attractor history (Icon may not be activated)")
	else:
		print("  ⚠️ Imperium Icon not found")

	print()

	# PHASE 6: Icon Activation Status
	print("PHASE 6: Icon Activation")
	print("─".repeat(40))

	print("  Biotic Flux: %.0f%% active" % (farm_view.biotic_icon.get_activation() * 100))
	print("  Cosmic Chaos: %.0f%% active" % (farm_view.chaos_icon.get_activation() * 100))
	print("  Imperium: %.0f%% active" % (farm_view.imperium_icon.active_strength * 100))
	print()

	# PHASE 7: Final Statistics
	print("PHASE 7: Final Game Statistics")
	print("─".repeat(40))

	print("  Credits: %d💰" % farm_view.economy.credits)
	print("  Wheat: %d🌾" % farm_view.economy.wheat)
	print("  Plots planted: %d" % farm_view.farm_grid.get_planted_count())
	print("  Plots mature: %d" % _count_mature_plots())
	print()


func _simulate_time(duration: float):
	"""Simulate game time passing"""
	var elapsed = 0.0
	var dt = 1.0 / 60.0  # 60 FPS

	while elapsed < duration:
		# Process farm_view (will call _process which evolves vocabulary)
		farm_view._process(dt)

		# Also need to grow wheat
		farm_view.farm_grid._process(dt)

		# Update Icons
		farm_view._update_icon_activation()

		await get_tree().process_frame
		elapsed += dt


func _count_mature_plots() -> int:
	var count = 0
	for x in range(5):
		for y in range(5):
			var plot = farm_view.farm_grid.get_plot(Vector2i(x, y))
			if plot and plot.is_mature:
				count += 1
	return count
