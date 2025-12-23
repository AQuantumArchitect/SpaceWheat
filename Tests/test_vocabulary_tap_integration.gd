#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Integration Test: Vocabulary Evolution × Energy Tap System
##
## Tests the complete integration of:
## 1. VocabularyEvolution wired into game loop
## 2. FarmGrid with vocabulary_evolution reference
## 3. Energy tap target validation against discovered vocabulary
## 4. Mutation pressure boost from active taps
## 5. Vocabulary discovery feedback loop

const WheatPlot = preload("res://Core/GameMechanics/WheatPlot.gd")
const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const VocabularyEvolution = preload("res://Core/QuantumSubstrate/VocabularyEvolution.gd")

var vocabulary: VocabularyEvolution
var farm: FarmGrid

func _initialize():
	var line = ""
	for i in range(80):
		line += "="

	print("\n" + line)
	print("📚 VOCABULARY × ENERGY TAP INTEGRATION TEST")
	print("Integration of vocabulary discovery with energy tap progression")
	print(line + "\n")

	var test_count = 0
	var pass_count = 0

	# Test 1: VocabularyEvolution initialized
	test_count += 1
	if _test_vocabulary_initialization():
		pass_count += 1
		print("✅ Test 1 PASSED: VocabularyEvolution initialized")
	else:
		print("❌ Test 1 FAILED: VocabularyEvolution initialization failed")
	print()

	# Test 2: FarmGrid receives vocabulary reference
	test_count += 1
	if _test_farmgrid_vocabulary_injection():
		pass_count += 1
		print("✅ Test 2 PASSED: FarmGrid has vocabulary_evolution reference")
	else:
		print("❌ Test 2 FAILED: FarmGrid vocabulary reference missing")
	print()

	# Test 3: get_available_tap_emojis() returns basic emojis
	test_count += 1
	if _test_initial_available_emojis():
		pass_count += 1
		print("✅ Test 3 PASSED: Initial available emojis includes basic set")
	else:
		print("❌ Test 3 FAILED: Available emojis validation failed")
	print()

	# Test 4: Can plant tap for discovered emoji
	test_count += 1
	if _test_plant_tap_for_discovered_emoji():
		pass_count += 1
		print("✅ Test 4 PASSED: Energy tap planted for discovered emoji")
	else:
		print("❌ Test 4 FAILED: Cannot plant tap for discovered emoji")
	print()

	# Test 5: Cannot plant tap for undiscovered emoji
	test_count += 1
	if _test_reject_tap_for_undiscovered_emoji():
		pass_count += 1
		print("✅ Test 5 PASSED: Rejected tap for undiscovered emoji")
	else:
		print("❌ Test 5 FAILED: Should reject undiscovered emoji")
	print()

	# Test 6: Mutation pressure updates in _process() loop
	test_count += 1
	if _test_process_updates_mutation_pressure():
		pass_count += 1
		print("✅ Test 6 PASSED: _process() updates vocabulary mutation pressure")
	else:
		print("❌ Test 6 FAILED: _process() mutation pressure update failed")
	print()

	# Test 7: Active taps calculate mutation pressure boost
	test_count += 1
	if _test_tap_mutation_pressure_boost():
		pass_count += 1
		print("✅ Test 7 PASSED: Mutation pressure boost calculated correctly")
	else:
		print("❌ Test 7 FAILED: Mutation pressure boost calculation failed")
	print()

	# Test 8: Vocabulary is wired into game loop
	test_count += 1
	if _test_vocabulary_game_loop_integration():
		pass_count += 1
		print("✅ Test 8 PASSED: Vocabulary system integrated into game loop")
	else:
		print("❌ Test 8 FAILED: Vocabulary not properly integrated")
	print()

	# Summary
	var line2 = ""
	for i in range(80):
		line2 += "="

	print(line2)
	print("TEST SUMMARY: %d/%d tests passed" % [pass_count, test_count])

	if pass_count == test_count:
		print("🎉 ALL TESTS PASSED - Vocabulary × Tap integration complete!")
	else:
		print("⚠️  Some tests failed - review implementation")

	print(line2 + "\n")

	quit()


func _test_vocabulary_initialization() -> bool:
	"""Test that VocabularyEvolution can be initialized"""
	vocabulary = VocabularyEvolution.new()
	vocabulary._ready()

	# Check that mutation_pressure is initialized
	return vocabulary.mutation_pressure > 0.0


func _test_farmgrid_vocabulary_injection() -> bool:
	"""Test that FarmGrid can receive vocabulary reference"""
	farm = FarmGrid.new()
	farm.grid_width = 5
	farm.grid_height = 5

	# Inject vocabulary reference
	farm.vocabulary_evolution = vocabulary

	# Verify it was set
	return farm.vocabulary_evolution == vocabulary


func _test_initial_available_emojis() -> bool:
	"""Test that get_available_tap_emojis returns basic emojis"""
	var available = farm.get_available_tap_emojis()

	# Should include basic emojis
	var basic_set = ["🌾", "👥", "🍅", "🍄"]
	for basic in basic_set:
		if not available.has(basic):
			return false

	return true


func _test_plant_tap_for_discovered_emoji() -> bool:
	"""Test that we can plant energy tap for discovered emoji"""
	# Initialize plots
	for x in range(farm.grid_width):
		for y in range(farm.grid_height):
			var pos = Vector2i(x, y)
			var plot = WheatPlot.new()
			plot.grid_position = pos
			farm.plots[pos] = plot

	# Try to plant tap for basic discovered emoji
	var result = farm.plant_energy_tap(Vector2i(0, 0), "🌾")

	if not result:
		return false

	# Verify plot is configured correctly
	var plot = farm.get_plot(Vector2i(0, 0))
	return plot.is_planted and plot.plot_type == WheatPlot.PlotType.ENERGY_TAP and plot.tap_target_emoji == "🌾"


func _test_reject_tap_for_undiscovered_emoji() -> bool:
	"""Test that we CANNOT plant energy tap for undiscovered emoji"""
	# Try to plant tap for emoji NOT in vocabulary
	var result = farm.plant_energy_tap(Vector2i(1, 0), "🦠")  # Undiscovered emoji

	# Should fail
	if result:
		return false

	# Verify plot was NOT planted
	var plot = farm.get_plot(Vector2i(1, 0))
	return not plot.is_planted


func _test_process_updates_mutation_pressure() -> bool:
	"""Test that FarmGrid._process() updates vocabulary mutation pressure from taps"""
	# Set initial mutation pressure to baseline
	var initial_pressure = vocabulary.mutation_pressure
	print("   📊 Initial mutation pressure: %.4f" % initial_pressure)

	# Create a Biome so _process() doesn't early return
	var biome_dummy = preload("res://Core/Environment/Biome.gd").new()
	farm.biome = biome_dummy

	# Call _process with delta
	farm._process(0.1)

	# Get new mutation pressure
	var new_pressure = vocabulary.mutation_pressure

	print("   📊 Mutation pressure after _process(): %.4f" % new_pressure)

	# At this point, only 1 tap has been planted (from Test 4)
	# boost = 1 × 0.02 = 0.02, so new = 0.15 + 0.02 = 0.17
	var tap_stats = farm._count_active_energy_taps()
	var active_taps_at_test6 = tap_stats["count"]
	var expected_boost = float(active_taps_at_test6) * 0.02
	var expected_pressure = min(0.15 + expected_boost, 2.0)

	print("   📊 Expected pressure (with %d taps): %.4f" % [active_taps_at_test6, expected_pressure])

	# Allow floating point tolerance
	return abs(new_pressure - expected_pressure) < 0.001


func _test_tap_mutation_pressure_boost() -> bool:
	"""Test that active taps calculate mutation pressure boost"""
	# Plant 3 more taps (1 already planted in Test 4, so will have 4 total)
	farm.plant_energy_tap(Vector2i(2, 0), "🌾")
	farm.plant_energy_tap(Vector2i(3, 0), "👥")
	farm.plant_energy_tap(Vector2i(4, 0), "🍅")

	# Calculate boost
	var boost = farm.get_tap_mutation_pressure_boost()

	# Count active taps
	var tap_stats = farm._count_active_energy_taps()
	var active_taps = tap_stats["count"]

	print("   📊 Active taps: %d" % active_taps)
	print("   📊 Mutation pressure boost: %.4f" % boost)

	# With 4 active taps (1 from test 4 + 3 new): 4 × 0.02 = 0.08
	var expected_boost = float(active_taps) * 0.02

	# Allow small floating point error
	return abs(boost - expected_boost) < 0.001


func _test_vocabulary_game_loop_integration() -> bool:
	"""Test that vocabulary system is properly wired into game loop"""
	# Verify key components are present and linked

	# 1. Vocabulary exists and is running
	if not vocabulary:
		print("   ❌ Vocabulary not initialized")
		return false

	print("   ✓ Vocabulary system initialized")

	# 2. FarmGrid has reference to vocabulary
	if farm.vocabulary_evolution != vocabulary:
		print("   ❌ FarmGrid.vocabulary_evolution not linked")
		return false

	print("   ✓ FarmGrid has vocabulary reference")

	# 3. FarmGrid can query available tap emojis
	var available = farm.get_available_tap_emojis()
	if available.is_empty():
		print("   ❌ No available emojis")
		return false

	print("   ✓ Available emojis: %s" % ", ".join(available))

	# 4. FarmGrid can count active taps
	var tap_stats = farm._count_active_energy_taps()
	if not tap_stats.has("count"):
		print("   ❌ Cannot count active taps")
		return false

	print("   ✓ Active taps: %d" % tap_stats["count"])

	# 5. FarmGrid can calculate mutation boost
	var boost = farm.get_tap_mutation_pressure_boost()
	print("   ✓ Mutation boost calculated: %.4f" % boost)

	# All integration points verified
	return true


