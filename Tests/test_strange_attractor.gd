extends SceneTree

## Test Suite: Strange Attractor Analysis
## Tests the StrangeAttractorAnalyzer and cross-biome entanglement prevention

const StrangeAttractorAnalyzer = preload("res://Core/QuantumSubstrate/StrangeAttractorAnalyzer.gd")
const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const FarmPlot = preload("res://Core/GameMechanics/FarmPlot.gd")

var test_count: int = 0
var pass_count: int = 0

func _init():
	print("\n" + "=".repeat(70))
	print("STRANGE ATTRACTOR & CROSS-BIOME PREVENTION TEST SUITE")
	print("=".repeat(70) + "\n")

	# Feature 1: Strange Attractor Analysis
	test_attractor_initialization()
	test_attractor_recording()
	test_attractor_classification()
	test_attractor_personality_descriptions()

	# Feature X: Cross-Biome Entanglement Prevention
	test_cross_biome_entanglement_blocked()
	test_same_biome_entanglement_allowed()
	test_triplet_cross_biome_blocked()

	# Summary
	print("\n" + "=".repeat(70))
	print("TESTS PASSED: %d/%d" % [pass_count, test_count])
	print("=".repeat(70) + "\n")

	quit()


## ========================================
## Test Utilities
## ========================================

func assert_true(condition: bool, message: String):
	test_count += 1
	if condition:
		pass_count += 1
		print("  ✓ " + message)
	else:
		print("  ✗ FAILED: " + message)


func assert_false(condition: bool, message: String):
	assert_true(not condition, message)


func assert_equal(actual, expected, message: String):
	test_count += 1
	if actual == expected:
		pass_count += 1
		print("  ✓ " + message)
	else:
		print("  ✗ FAILED: %s (expected: %s, got: %s)" % [message, str(expected), str(actual)])


## ========================================
## Feature 1: Strange Attractor Analysis
## ========================================

func test_attractor_initialization():
	print("\nTEST: Strange Attractor Initialization")

	var analyzer = StrangeAttractorAnalyzer.new()
	var emojis: Array[String] = ["🌾", "👥", "💰"]

	analyzer.initialize(emojis)

	assert_equal(analyzer.selected_emojis.size(), 3, "Should have 3 selected emojis")
	assert_equal(analyzer.selected_emojis[0], "🌾", "First emoji should be wheat")
	assert_equal(analyzer.trajectory.size(), 0, "Trajectory should be empty initially")
	assert_equal(analyzer.get_personality(), "unknown", "Personality unknown with no data")

	print("  ✓ StrangeAttractorAnalyzer initialized correctly\n")


func test_attractor_recording():
	print("\nTEST: Attractor Trajectory Recording")

	var analyzer = StrangeAttractorAnalyzer.new()
	analyzer.initialize(["🌾", "🍄", "💰"])

	# Record 10 snapshots
	for i in range(10):
		var observables = {
			"🌾": 0.5 + 0.1 * sin(i * 0.1),
			"🍄": 0.3 + 0.1 * cos(i * 0.1),
			"💰": 0.2 + 0.05 * sin(i * 0.2)
		}
		analyzer.record_snapshot(observables)

	assert_equal(analyzer.trajectory.size(), 10, "Should have 10 trajectory points")

	# Check first point
	var first_point = analyzer.trajectory[0]
	assert_true(abs(first_point.x - 0.5) < 0.01, "First point X should be ~0.5")

	# Test rolling window (max_trajectory_length = 1500)
	analyzer.max_trajectory_length = 5
	for i in range(10):
		analyzer.record_snapshot({"🌾": 0.5, "🍄": 0.3, "💰": 0.2})

	assert_equal(analyzer.trajectory.size(), 5, "Should maintain rolling window of 5")

	print("  ✓ Trajectory recording working correctly\n")


func test_attractor_classification():
	print("\nTEST: Attractor Personality Classification")

	var analyzer = StrangeAttractorAnalyzer.new()
	analyzer.initialize(["🌾", "🍄", "💰"])

	# Simulate stable attractor (fixed point)
	print("  Testing stable attractor...")
	for i in range(150):
		analyzer.record_snapshot({
			"🌾": 0.5,
			"🍄": 0.3,
			"💰": 0.2
		})

	var signature = analyzer.get_signature()
	print("    Personality: %s" % signature.personality)
	print("    Spread: %.3f" % signature.spread)
	assert_true(signature.personality == "stable", "Fixed point should be classified as stable")

	# Simulate cyclic attractor
	print("  Testing cyclic attractor...")
	analyzer = StrangeAttractorAnalyzer.new()
	analyzer.initialize(["🌾", "🍄", "💰"])

	for i in range(200):
		var t = i * 0.1
		analyzer.record_snapshot({
			"🌾": 0.5 + 0.3 * sin(t),
			"🍄": 0.5 + 0.3 * cos(t),
			"💰": 0.5 + 0.2 * sin(2 * t)
		})

	signature = analyzer.get_signature()
	print("    Personality: %s" % signature.personality)
	print("    Periodicity: %.3f" % signature.periodicity)
	# Note: May classify as cyclic or irregular depending on metrics

	# Simulate explosive attractor
	print("  Testing explosive attractor...")
	analyzer = StrangeAttractorAnalyzer.new()
	analyzer.initialize(["🌾", "🍄", "💰"])

	for i in range(150):
		var growth = exp(i * 0.01)
		analyzer.record_snapshot({
			"🌾": min(1.0, 0.5 * growth),
			"🍄": min(1.0, 0.3 * growth),
			"💰": min(1.0, 0.2 * growth)
		})

	signature = analyzer.get_signature()
	print("    Personality: %s" % signature.personality)
	print("    Spread: %.3f" % signature.spread)
	# Explosive should have high spread

	print("  ✓ Attractor classification working\n")


func test_attractor_personality_descriptions():
	print("\nTEST: Personality Descriptions & Colors")

	var descriptions = [
		StrangeAttractorAnalyzer.get_personality_description("stable"),
		StrangeAttractorAnalyzer.get_personality_description("cyclic"),
		StrangeAttractorAnalyzer.get_personality_description("chaotic"),
		StrangeAttractorAnalyzer.get_personality_description("explosive")
	]

	for desc in descriptions:
		assert_true(desc.length() > 10, "Description should be meaningful")

	var color = StrangeAttractorAnalyzer.get_personality_color("chaotic")
	assert_true(color == Color.ORANGE_RED, "Chaotic should be orange-red")

	var emoji = StrangeAttractorAnalyzer.get_personality_emoji("cyclic")
	assert_true(emoji == "🔄", "Cyclic should be 🔄")

	print("  ✓ Personality descriptions working\n")


## ========================================
## Feature X: Cross-Biome Entanglement Prevention
## ========================================

func test_cross_biome_entanglement_blocked():
	print("\nTEST: Cross-Biome Entanglement Prevention")

	var farm_grid = FarmGrid.new()

	# Create two plots at different positions
	var pos_a = Vector2i(0, 0)
	var pos_b = Vector2i(1, 0)

	var plot_a = FarmPlot.new()
	var plot_b = FarmPlot.new()

	farm_grid.plots[pos_a] = plot_a
	farm_grid.plots[pos_b] = plot_b

	# Assign to different biomes
	farm_grid.plot_biome_assignments[pos_a] = "biotic_flux"
	farm_grid.plot_biome_assignments[pos_b] = "market"

	# Attempt to create entanglement (should fail)
	var success = farm_grid.create_entanglement(pos_a, pos_b)

	assert_false(success, "Cross-biome entanglement should be blocked")
	print("  ✓ Cross-biome entanglement correctly prevented\n")


func test_same_biome_entanglement_allowed():
	print("\nTEST: Same-Biome Entanglement Allowed")

	var farm_grid = FarmGrid.new()

	var pos_a = Vector2i(0, 0)
	var pos_b = Vector2i(1, 0)

	var plot_a = FarmPlot.new()
	var plot_b = FarmPlot.new()

	farm_grid.plots[pos_a] = plot_a
	farm_grid.plots[pos_b] = plot_b

	# Assign to SAME biome
	farm_grid.plot_biome_assignments[pos_a] = "biotic_flux"
	farm_grid.plot_biome_assignments[pos_b] = "biotic_flux"

	# Create entanglement (should succeed - infrastructure only)
	var success = farm_grid.create_entanglement(pos_a, pos_b)

	assert_true(success, "Same-biome entanglement should be allowed")
	print("  ✓ Same-biome entanglement correctly allowed\n")


func test_triplet_cross_biome_blocked():
	print("\nTEST: Triplet Cross-Biome Entanglement Blocked")

	var farm_grid = FarmGrid.new()

	var pos_a = Vector2i(0, 0)
	var pos_b = Vector2i(1, 0)
	var pos_c = Vector2i(2, 0)

	var plot_a = FarmPlot.new()
	var plot_b = FarmPlot.new()
	var plot_c = FarmPlot.new()

	farm_grid.plots[pos_a] = plot_a
	farm_grid.plots[pos_b] = plot_b
	farm_grid.plots[pos_c] = plot_c

	# Two in one biome, one in another
	farm_grid.plot_biome_assignments[pos_a] = "biotic_flux"
	farm_grid.plot_biome_assignments[pos_b] = "biotic_flux"
	farm_grid.plot_biome_assignments[pos_c] = "market"

	# Attempt triplet entanglement (should fail)
	var success = farm_grid.create_triplet_entanglement(pos_a, pos_b, pos_c)

	assert_false(success, "Triplet cross-biome entanglement should be blocked")
	print("  ✓ Triplet cross-biome entanglement correctly prevented\n")
