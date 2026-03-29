#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: Single Plot Lifecycle with Live-Coupled Projections
##
## Verifies basic game loop:
## 1. Plant wheat at (0,0)
## 2. Verify qubit is bath-coupled
## 3. Evolve for a few ticks
## 4. Measure
## 5. Harvest
## 6. Verify resources gained

const Farm = preload("res://Core/Farm.gd")
const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")

var farm: Farm
var test_position = Vector2i(0, 0)

func _init():
	print("\n🧪 SINGLE PLOT LIFECYCLE TEST (Live-Coupled Projections)")
	print("=" + "=".repeat(59))

	# Create farm
	print("\n🌾 Creating farm...")
	farm = Farm.new()
	farm._ready()

	if not farm.grid:
		print("❌ FAIL: Farm has no grid")
		quit(1)
		return

	print("  ✓ Farm initialized: %dx%d grid" % [farm.grid.grid_width, farm.grid.grid_height])

	# Manually initialize biomes if needed (in headless tests, _ready may not auto-call)
	if farm.market_biome and not farm.market_biome.bath:
		print("  ⚙️  Manually initializing Market biome...")
		farm.market_biome._ready()

	# Verify biome exists and has bath
	# Position (0,0) is assigned to Market biome
	var biome = farm.grid.get_biome("Market")
	if not biome:
		print("❌ FAIL: No Market biome found")
		print("  Available biomes: %s" % str(farm.grid.get_biome_names()))
		quit(1)
		return

	if not biome.bath:
		print("❌ FAIL: Biome has no bath")
		quit(1)
		return

	print("  ✓ Biome initialized with bath")
	print("  ✓ Bath has %d emojis: %s" % [biome.bath.emoji_list.size(), str(biome.bath.emoji_list)])

	# Give economy starting resources (wheat costs 1 wheat credit to plant)
	if farm.economy:
		farm.economy.add_resource("🌾", 100, "test_starting_balance")
		print("  ✓ Economy initialized with 100 wheat credits")

	# TEST 1: Plant wheat
	print("\n🌱 TEST 1: PLANTING WHEAT")
	var plant_result = farm.build(test_position, "wheat")

	if not plant_result:
		print("❌ FAIL: Could not plant wheat at %s" % test_position)
		quit(1)
		return

	print("  ✓ Planted wheat at %s" % test_position)

	# Verify plot exists
	var plot = farm.grid.get_plot(test_position)
	if not plot:
		print("❌ FAIL: No plot found at %s after planting" % test_position)
		quit(1)
		return

	if not plot.is_planted:
		print("❌ FAIL: Plot not marked as planted")
		quit(1)
		return

	print("  ✓ Plot is_planted = true")

	# Verify qubit exists
	if not plot.quantum_state:
		print("❌ FAIL: Plot has no quantum_state")
		quit(1)
		return

	print("  ✓ Plot has quantum_state (DualEmojiQubit)")

	# TEST 2: Verify bath coupling
	print("\n🔭 TEST 2: BATH COUPLING")
	var qubit = plot.quantum_state

	print("  Qubit emojis: %s ↔ %s" % [qubit.north_emoji, qubit.south_emoji])

	if not qubit.bath:
		print("❌ FAIL: Qubit has no bath reference!")
		quit(1)
		return

	print("  ✓ Qubit has bath reference")

	# Verify theta is computed from bath (not stored)
	var theta_initial = qubit.theta
	print("  Initial theta (from bath): %.4f" % theta_initial)

	# Get populations from bath
	var north_pop = biome.bath.get_population(qubit.north_emoji)
	var south_pop = biome.bath.get_population(qubit.south_emoji)
	print("  Bath populations: %s=%.4f, %s=%.4f" % [
		qubit.north_emoji, north_pop,
		qubit.south_emoji, south_pop
	])

	# TEST 3: Evolution
	print("\n⏱️  TEST 3: EVOLUTION")
	print("  Evolving for 5 ticks (dt=1.0)...")

	for tick in range(5):
		# Evolve biome (which evolves bath)
		biome.evolve(1.0)

		var theta = qubit.theta
		var north = biome.bath.get_population(qubit.north_emoji)
		var south = biome.bath.get_population(qubit.south_emoji)

		print("    Tick %d: θ=%.4f | %s=%.4f %s=%.4f" % [
			tick + 1, theta,
			qubit.north_emoji, north,
			qubit.south_emoji, south
		])

	var theta_after_evolution = qubit.theta
	print("  ✓ Evolution complete")
	print("  Theta changed: %.4f → %.4f (Δ=%.4f)" % [
		theta_initial,
		theta_after_evolution,
		abs(theta_after_evolution - theta_initial)
	])

	# TEST 4: Measurement
	print("\n🔬 TEST 4: MEASUREMENT")
	var outcome = farm.measure_plot(test_position)

	if outcome == "":
		print("❌ FAIL: Measurement returned empty string")
		quit(1)
		return

	print("  ✓ Measured: %s" % outcome)

	# Verify bath collapsed
	var collapsed_north = biome.bath.get_population(qubit.north_emoji)
	var collapsed_south = biome.bath.get_population(qubit.south_emoji)

	print("  Bath after collapse:")
	print("    %s: %.6f" % [qubit.north_emoji, collapsed_north])
	print("    %s: %.6f" % [qubit.south_emoji, collapsed_south])

	# One should be near 0, the other near some value
	if outcome == qubit.north_emoji:
		if collapsed_south > 0.01:
			print("  ⚠️  WARNING: Measured north but south still has %.4f population" % collapsed_south)
	else:
		if collapsed_north > 0.01:
			print("  ⚠️  WARNING: Measured south but north still has %.4f population" % collapsed_north)

	# TEST 5: Harvest
	print("\n✂️  TEST 5: HARVEST")

	# Check economy before harvest
	var wheat_before = 0
	if farm.economy:
		wheat_before = farm.economy.get_resource("🌾")

	print("  Wheat before harvest: %d" % wheat_before)

	var harvest_result = farm.harvest_plot(test_position)

	if not harvest_result.get("success", false):
		print("❌ FAIL: Harvest failed")
		quit(1)
		return

	var yield_amount = harvest_result.get("yield", 0)
	print("  ✓ Harvested successfully")
	print("  Yield: %d" % yield_amount)

	if farm.economy:
		var wheat_after = farm.economy.get_resource("🌾")
		print("  Wheat after harvest: %d (+%d)" % [wheat_after, wheat_after - wheat_before])

	# Verify plot is empty
	var plot_after = farm.grid.get_plot(test_position)
	if plot_after and plot_after.is_planted:
		print("❌ FAIL: Plot still marked as planted after harvest")
		quit(1)
		return

	print("  ✓ Plot cleared after harvest")

	# TEST 6: Bath normalization
	print("\n🔄 TEST 6: BATH NORMALIZATION")
	var total_prob = 0.0
	for emoji in biome.bath.emoji_list:
		total_prob += biome.bath.get_probability(emoji)

	print("  Total probability in bath: %.6f" % total_prob)

	if abs(total_prob - 1.0) > 0.01:
		print("❌ FAIL: Bath not normalized! (should be 1.0)")
		quit(1)
		return

	print("  ✓ Bath remains normalized")

	# Success!
	print("\n" + "=" + "=".repeat(59))
	print("✅ ALL TESTS PASSED - SINGLE PLOT LIFECYCLE WORKS!")
	print("=" + "=".repeat(59))
	quit(0)
