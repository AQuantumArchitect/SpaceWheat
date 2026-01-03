extends SceneTree

## Test: Save/Load with Biome Variations
## Verifies dynamic biome capture and restoration

const Farm = preload("res://Core/Farm.gd")

# Test biome variations
const MinimalTestBiome = preload("res://Core/Environment/MinimalTestBiome.gd")
const DualBiome = preload("res://Core/Environment/DualBiome.gd")
const TripleBiome = preload("res://Core/Environment/TripleBiome.gd")
const MergedEcosystem_Biome = preload("res://Core/Environment/MergedEcosystem_Biome.gd")


func _init():
	# Defer test execution until autoloads are ready
	call_deferred("run_test")

func run_test():
	print("")
	print("🧪 BIOME SAVE/LOAD TEST")
	print("======================================================================")
	print("Testing: Save/load with MinimalTest, Dual, Triple, MergedEcosystem biomes")
	print("")

	# Wait for autoloads to initialize
	await self.process_frame

	# Get GameStateManager
	var game_state_mgr = get_root().get_node_or_null("/root/GameStateManager")
	if not game_state_mgr:
		print("❌ ERROR: GameStateManager not found")
		quit()
		return

	# Create farm with test biomes
	var farm = Farm.new()
	get_root().add_child(farm)

	# Wait for farm initialization
	await self.process_frame

	# Add test biomes to the farm
	print("📋 PHASE 1: ADDING TEST BIOMES")
	print("----------------------------------------------------------------------")

	# Create and register test biomes
	var minimal_biome = MinimalTestBiome.new()
	minimal_biome.name = "MinimalTest"
	farm.add_child(minimal_biome)
	farm.grid.register_biome("MinimalTest", minimal_biome)
	minimal_biome.grid = farm.grid
	print("✅ Added MinimalTest biome")

	var dual_biome = DualBiome.new()
	dual_biome.name = "Dual"
	farm.add_child(dual_biome)
	farm.grid.register_biome("Dual", dual_biome)
	dual_biome.grid = farm.grid
	print("✅ Added Dual biome")

	var triple_biome = TripleBiome.new()
	triple_biome.name = "Triple"
	farm.add_child(triple_biome)
	farm.grid.register_biome("Triple", triple_biome)
	triple_biome.grid = farm.grid
	print("✅ Added Triple biome")

	var merged_biome = MergedEcosystem_Biome.new()
	merged_biome.name = "MergedEcosystem"
	farm.add_child(merged_biome)
	farm.grid.register_biome("MergedEcosystem", merged_biome)
	merged_biome.grid = farm.grid
	print("✅ Added MergedEcosystem biome")

	# Wait for biome initialization
	await self.process_frame

	print("")
	print("Total registered biomes: %d" % farm.grid.biomes.size())
	print("Biomes: ", farm.grid.biomes.keys())

	# Assign some plots to test biomes
	print("")
	print("📍 PHASE 2: ASSIGNING PLOTS TO TEST BIOMES")
	print("----------------------------------------------------------------------")

	# Use existing plots from Farm._ready() and add test biomes to specific plots
	# Override some BioticFlux plots with test biomes
	farm.grid.assign_plot_to_biome(Vector2i(2, 0), "MinimalTest")  # Was BioticFlux
	farm.grid.assign_plot_to_biome(Vector2i(3, 0), "Dual")  # Was BioticFlux
	farm.grid.assign_plot_to_biome(Vector2i(4, 0), "Triple")  # Was BioticFlux
	farm.grid.assign_plot_to_biome(Vector2i(5, 0), "MergedEcosystem")  # Was BioticFlux

	print("✅ Assigned 4 plots to test biomes")

	# Plant wheat in each test biome
	print("")
	print("🌾 PHASE 3: PLANTING IN TEST BIOMES")
	print("----------------------------------------------------------------------")

	var test_plots = [
		Vector2i(2, 0),  # MinimalTest
		Vector2i(3, 0),  # Dual
		Vector2i(4, 0),  # Triple
		Vector2i(5, 0)   # MergedEcosystem
	]

	for pos in test_plots:
		var biome_name = farm.grid.plot_biome_assignments[pos]
		var success = farm.grid.plant(pos, "wheat")
		if success:
			print("✅ Planted wheat at %s (%s biome)" % [pos, biome_name])
		else:
			print("❌ Failed to plant at %s" % pos)

	# Let quantum states evolve briefly
	print("")
	print("⏱️  Evolving quantum states...")
	await self.process_frame
	await self.process_frame

	# SAVE GAME
	print("")
	print("💾 PHASE 4: SAVING GAME")
	print("----------------------------------------------------------------------")

	game_state_mgr.active_farm = farm
	var save_success = game_state_mgr.save_game(0)

	if not save_success:
		print("❌ SAVE FAILED!")
		quit()
		return

	print("✅ Game saved to slot 0")

	# Verify save captured test biomes
	var saved_state = game_state_mgr.load_game_state(0)
	if saved_state and saved_state.biome_states:
		print("")
		print("Biomes in save file:")
		for biome_name in saved_state.biome_states.keys():
			var biome_state = saved_state.biome_states[biome_name]
			var biome_class = biome_state.get("biome_class", "UNKNOWN")
			var emoji_count = 0
			if biome_state.has("bath_state"):
				emoji_count = biome_state.bath_state.emojis.size()
			print("  • %s (%s) - %d emojis" % [biome_name, biome_class.get_file(), emoji_count])

	# RESET FARM (simulate game restart)
	print("")
	print("🔄 PHASE 5: RESETTING FARM (simulating restart)")
	print("----------------------------------------------------------------------")

	# Remove farm
	get_root().remove_child(farm)
	farm.queue_free()
	await self.process_frame

	# Create fresh farm
	farm = Farm.new()
	get_root().add_child(farm)
	await self.process_frame

	# Re-add test biomes (Farm doesn't create them automatically)
	minimal_biome = MinimalTestBiome.new()
	minimal_biome.name = "MinimalTest"
	farm.add_child(minimal_biome)
	farm.grid.register_biome("MinimalTest", minimal_biome)
	minimal_biome.grid = farm.grid

	dual_biome = DualBiome.new()
	dual_biome.name = "Dual"
	farm.add_child(dual_biome)
	farm.grid.register_biome("Dual", dual_biome)
	dual_biome.grid = farm.grid

	triple_biome = TripleBiome.new()
	triple_biome.name = "Triple"
	farm.add_child(triple_biome)
	farm.grid.register_biome("Triple", triple_biome)
	triple_biome.grid = farm.grid

	merged_biome = MergedEcosystem_Biome.new()
	merged_biome.name = "MergedEcosystem"
	farm.add_child(merged_biome)
	farm.grid.register_biome("MergedEcosystem", merged_biome)
	merged_biome.grid = farm.grid

	await self.process_frame

	print("✅ Fresh farm created with %d registered biomes" % farm.grid.biomes.size())

	# LOAD GAME
	print("")
	print("📂 PHASE 6: LOADING GAME")
	print("----------------------------------------------------------------------")

	game_state_mgr.active_farm = farm
	var load_success = game_state_mgr.load_and_apply(0)

	if not load_success:
		print("❌ LOAD FAILED!")
		quit()
		return

	print("✅ Game loaded from slot 0")

	# VERIFICATION
	print("")
	print("✔️  PHASE 7: VERIFICATION")
	print("----------------------------------------------------------------------")

	# Check biome states restored
	print("")
	print("Biome state verification:")
	var all_passed = true

	for biome_name in ["MinimalTest", "Dual", "Triple", "MergedEcosystem"]:
		var biome = farm.grid.biomes.get(biome_name, null)
		if not biome:
			print("  ❌ %s biome not found!" % biome_name)
			all_passed = false
			continue

		if not biome.bath:
			print("  ❌ %s has no bath!" % biome_name)
			all_passed = false
			continue

		var emoji_count = biome.bath.emoji_list.size()
		print("  ✅ %s restored (%d emojis)" % [biome_name, emoji_count])

	# Check plot assignments
	print("")
	print("Plot assignment verification:")
	for pos in test_plots:
		var assigned_biome = farm.grid.plot_biome_assignments.get(pos, "NONE")
		var plot = farm.grid.get_plot(pos)
		var is_planted = plot.is_planted if plot else false

		if assigned_biome == "NONE":
			print("  ❌ Plot %s not assigned!" % pos)
			all_passed = false
		elif not is_planted:
			print("  ❌ Plot %s (%s) not planted!" % [pos, assigned_biome])
			all_passed = false
		else:
			print("  ✅ Plot %s assigned to %s (planted)" % [pos, assigned_biome])

	# Final result
	print("")
	print("======================================================================")
	if all_passed:
		print("✅ ALL TESTS PASSED - Save/load works with biome variations!")
	else:
		print("❌ SOME TESTS FAILED - Check output above")
	print("======================================================================")

	quit()
