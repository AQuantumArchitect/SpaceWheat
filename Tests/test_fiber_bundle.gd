extends SceneTree

## Test Suite: Fiber Bundle System (Feature 2)
## Tests SemanticOctant detection and FiberBundle context-aware actions

const SemanticOctant = preload("res://Core/QuantumSubstrate/SemanticOctant.gd")
const FiberBundle = preload("res://Core/QuantumSubstrate/FiberBundle.gd")
const QuantumComputer = preload("res://Core/QuantumSubstrate/QuantumComputer.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")

var test_count: int = 0
var pass_count: int = 0


func _init():
	print("\n" + "=".repeat(70))
	print("FIBER BUNDLE TEST SUITE (Feature 2)")
	print("=".repeat(70) + "\n")

	# SemanticOctant tests
	test_octant_detection_all_regions()
	test_octant_boundary_cases()
	test_region_information()
	test_region_modifiers()
	test_adjacent_regions()
	test_transition_difficulty()

	# FiberBundle tests
	test_fiber_bundle_basic()
	test_fiber_bundle_variants()
	test_grower_bundle_preset()
	test_context_resolution()

	# Integration tests
	test_quantum_computer_detection()

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


func assert_approx(actual: float, expected: float, tolerance: float, message: String):
	test_count += 1
	if abs(actual - expected) < tolerance:
		pass_count += 1
		print("  ✓ " + message)
	else:
		print("  ✗ FAILED: %s (expected: %.4f, got: %.4f)" % [message, expected, actual])


## ========================================
## SemanticOctant Tests
## ========================================

func test_octant_detection_all_regions():
	print("\nTEST: Octant Detection - All 8 Regions")

	# Test each octant with clear positions
	var tests = [
		[Vector3(0.7, 0.7, 0.7), SemanticOctant.Region.PHOENIX, "PHOENIX (+++)"],
		[Vector3(0.3, 0.7, 0.3), SemanticOctant.Region.SAGE, "SAGE (-+-)"],
		[Vector3(0.7, 0.3, 0.3), SemanticOctant.Region.WARRIOR, "WARRIOR (+--)"],
		[Vector3(0.7, 0.3, 0.7), SemanticOctant.Region.MERCHANT, "MERCHANT (+-+)"],
		[Vector3(0.3, 0.3, 0.3), SemanticOctant.Region.ASCETIC, "ASCETIC (---)"],
		[Vector3(0.3, 0.7, 0.7), SemanticOctant.Region.GARDENER, "GARDENER (-++)"],
		[Vector3(0.7, 0.7, 0.3), SemanticOctant.Region.INNOVATOR, "INNOVATOR (++-)"],
		[Vector3(0.3, 0.3, 0.7), SemanticOctant.Region.GUARDIAN, "GUARDIAN (--+)"],
	]

	for test in tests:
		var pos = test[0]
		var expected = test[1]
		var name = test[2]
		var detected = SemanticOctant.detect_region(pos)
		assert_equal(detected, expected, name)

	print()


func test_octant_boundary_cases():
	print("\nTEST: Octant Detection - Boundary Cases")

	# Test at exactly 0.5 threshold (should be "high")
	var at_threshold = SemanticOctant.detect_region(Vector3(0.5, 0.5, 0.5))
	assert_equal(at_threshold, SemanticOctant.Region.PHOENIX, "At threshold (0.5, 0.5, 0.5) should be PHOENIX")

	# Test just below threshold
	var below = SemanticOctant.detect_region(Vector3(0.49, 0.49, 0.49))
	assert_equal(below, SemanticOctant.Region.ASCETIC, "Below threshold should be ASCETIC")

	# Test extreme values
	var extreme_high = SemanticOctant.detect_region(Vector3(1.0, 1.0, 1.0))
	assert_equal(extreme_high, SemanticOctant.Region.PHOENIX, "Extreme high should be PHOENIX")

	var extreme_low = SemanticOctant.detect_region(Vector3(0.0, 0.0, 0.0))
	assert_equal(extreme_low, SemanticOctant.Region.ASCETIC, "Extreme low should be ASCETIC")

	print()


func test_region_information():
	print("\nTEST: Region Information")

	for region in [SemanticOctant.Region.PHOENIX, SemanticOctant.Region.SAGE, SemanticOctant.Region.WARRIOR]:
		var name = SemanticOctant.get_region_name(region)
		var emoji = SemanticOctant.get_region_emoji(region)
		var desc = SemanticOctant.get_region_description(region)
		var color = SemanticOctant.get_region_color(region)

		assert_true(name.length() > 0, "%s has name" % name)
		assert_true(emoji.length() > 0, "%s has emoji" % name)
		assert_true(desc.length() > 20, "%s has description" % name)
		assert_true(color != Color.BLACK, "%s has color" % name)

	print()


func test_region_modifiers():
	print("\nTEST: Region Modifiers")

	# PHOENIX should have high growth
	var phoenix_mods = SemanticOctant.get_region_modifiers(SemanticOctant.Region.PHOENIX)
	assert_true(phoenix_mods.growth_rate > 1.0, "PHOENIX has high growth rate")
	assert_true(phoenix_mods.coherence_decay > 1.0, "PHOENIX has fast decay (volatile)")

	# ASCETIC should have low growth
	var ascetic_mods = SemanticOctant.get_region_modifiers(SemanticOctant.Region.ASCETIC)
	assert_true(ascetic_mods.growth_rate < 1.0, "ASCETIC has low growth rate")
	assert_true(ascetic_mods.coherence_decay < 1.0, "ASCETIC has slow decay (stable)")

	# MERCHANT should have high harvest
	var merchant_mods = SemanticOctant.get_region_modifiers(SemanticOctant.Region.MERCHANT)
	assert_true(merchant_mods.harvest_yield > 1.0, "MERCHANT has high harvest yield")

	print()


func test_adjacent_regions():
	print("\nTEST: Adjacent Regions")

	# ASCETIC (---) should be adjacent to SAGE (-+-), WARRIOR (+--), GUARDIAN (--+)
	var ascetic_adj = SemanticOctant.get_adjacent_regions(SemanticOctant.Region.ASCETIC)
	assert_equal(ascetic_adj.size(), 3, "Each region has 3 adjacent regions")

	# Check that SAGE is adjacent (differs by 1 axis)
	assert_true(SemanticOctant.Region.SAGE in ascetic_adj, "ASCETIC adjacent to SAGE")
	assert_true(SemanticOctant.Region.WARRIOR in ascetic_adj, "ASCETIC adjacent to WARRIOR")
	assert_true(SemanticOctant.Region.GUARDIAN in ascetic_adj, "ASCETIC adjacent to GUARDIAN")

	# PHOENIX should NOT be adjacent to ASCETIC (opposite corner)
	assert_false(SemanticOctant.Region.PHOENIX in ascetic_adj, "ASCETIC NOT adjacent to PHOENIX")

	print()


func test_transition_difficulty():
	print("\nTEST: Transition Difficulty")

	# Same region
	var same = SemanticOctant.get_transition_difficulty(
		SemanticOctant.Region.PHOENIX,
		SemanticOctant.Region.PHOENIX
	)
	assert_approx(same, 0.0, 0.001, "Same region = difficulty 0")

	# Adjacent (1 axis different)
	var adjacent = SemanticOctant.get_transition_difficulty(
		SemanticOctant.Region.PHOENIX,  # +++
		SemanticOctant.Region.INNOVATOR # ++-
	)
	assert_approx(adjacent, 1.0, 0.001, "Adjacent region = difficulty 1")

	# Diagonal (2 axes different)
	var diagonal = SemanticOctant.get_transition_difficulty(
		SemanticOctant.Region.PHOENIX,  # +++
		SemanticOctant.Region.MERCHANT  # +-+
	)
	assert_approx(diagonal, 1.0, 0.001, "2 axes different = difficulty 1")

	# Opposite (3 axes different)
	var opposite = SemanticOctant.get_transition_difficulty(
		SemanticOctant.Region.PHOENIX,  # +++
		SemanticOctant.Region.ASCETIC   # ---
	)
	assert_approx(opposite, 3.0, 0.001, "Opposite region = difficulty 3")

	print()


## ========================================
## FiberBundle Tests
## ========================================

func test_fiber_bundle_basic():
	print("\nTEST: FiberBundle - Basic Operations")

	var bundle = FiberBundle.new(1)
	bundle.set_base_actions({
		"Q": {"action": "test", "label": "Test Action", "emoji": "🧪"}
	})

	assert_equal(bundle.tool_id, 1, "Tool ID set correctly")
	assert_true(bundle.base_actions.has("Q"), "Base action registered")

	# Get action without variants
	var action = bundle.get_action("Q", SemanticOctant.Region.ASCETIC)
	assert_equal(action.label, "Test Action", "Base action returned when no variant")

	print()


func test_fiber_bundle_variants():
	print("\nTEST: FiberBundle - Variant System")

	var bundle = FiberBundle.new(1)
	bundle.set_base_actions({
		"Q": {"action": "plant", "label": "Plant", "emoji": "🌾"}
	})

	# Add variant
	bundle.add_variant(SemanticOctant.Region.PHOENIX, "Q", {
		"label": "Plant Phoenix Wheat",
		"emoji": "🔥🌾",
		"modifier": {"growth_rate": 1.5}
	})

	# Test in PHOENIX (should use variant)
	var phoenix_action = bundle.get_action("Q", SemanticOctant.Region.PHOENIX)
	assert_equal(phoenix_action.label, "Plant Phoenix Wheat", "PHOENIX uses variant label")
	assert_equal(phoenix_action.emoji, "🔥🌾", "PHOENIX uses variant emoji")
	assert_true(phoenix_action.has("modifier"), "PHOENIX has modifier")

	# Test in SAGE (should use base)
	var sage_action = bundle.get_action("Q", SemanticOctant.Region.SAGE)
	assert_equal(sage_action.label, "Plant", "SAGE uses base label")
	assert_equal(sage_action.emoji, "🌾", "SAGE uses base emoji")

	# Test has_variant
	assert_true(bundle.has_variant("Q", SemanticOctant.Region.PHOENIX), "Has PHOENIX variant")
	assert_false(bundle.has_variant("Q", SemanticOctant.Region.SAGE), "No SAGE variant")

	print()


func test_grower_bundle_preset():
	print("\nTEST: FiberBundle - Grower Preset")

	var bundle = FiberBundle.create_grower_bundle()

	assert_equal(bundle.tool_id, 1, "Grower bundle has tool ID 1")

	# Check all 8 regions have Q variants
	var variant_count = 0
	for region in [
		SemanticOctant.Region.PHOENIX,
		SemanticOctant.Region.SAGE,
		SemanticOctant.Region.WARRIOR,
		SemanticOctant.Region.MERCHANT,
		SemanticOctant.Region.ASCETIC,
		SemanticOctant.Region.GARDENER,
		SemanticOctant.Region.INNOVATOR,
		SemanticOctant.Region.GUARDIAN
	]:
		if bundle.has_variant("Q", region):
			variant_count += 1

	assert_equal(variant_count, 8, "Grower bundle has 8 Q variants")

	# Check specific variant content
	var phoenix_plant = bundle.get_action("Q", SemanticOctant.Region.PHOENIX)
	assert_true("Phoenix" in phoenix_plant.label, "Phoenix variant mentions Phoenix")
	assert_true(phoenix_plant.modifier.growth_rate > 1.0, "Phoenix has growth boost")

	print()


func test_context_resolution():
	print("\nTEST: FiberBundle - Context Resolution")

	var bundle = FiberBundle.create_grower_bundle()

	# Get all actions for different contexts
	var phoenix_actions = bundle.get_all_actions(SemanticOctant.Region.PHOENIX)
	var sage_actions = bundle.get_all_actions(SemanticOctant.Region.SAGE)

	# Q actions should differ
	assert_true(
		phoenix_actions["Q"].label != sage_actions["Q"].label,
		"Different contexts give different Q actions"
	)

	# E actions should be same (no variants defined)
	assert_equal(
		phoenix_actions["E"].label,
		sage_actions["E"].label,
		"E actions same when no variant"
	)

	# Context metadata should be set
	assert_equal(
		phoenix_actions["Q"]._context_name,
		"Phoenix",
		"Context metadata includes region name"
	)

	print()


## ========================================
## Integration Tests
## ========================================

func test_quantum_computer_detection():
	print("\nTEST: Integration - Quantum Computer Detection")

	# Create a quantum computer with known state
	var qc = QuantumComputer.new("test")
	qc.allocate_axis(0, "🌾", "🍄")  # Energy axis
	qc.allocate_axis(1, "☀", "🌙")   # Growth axis
	qc.allocate_axis(2, "💰", "📦")  # Wealth axis

	# Initialize to high on all axes (PHOENIX territory)
	# Basis 0 = |000⟩ = 🌾☀💰 (all north poles = high)
	qc.initialize_basis(0)

	var emoji_axes: Array[String] = ["🌾", "☀", "💰"]
	var region = SemanticOctant.detect_from_quantum_computer(qc, emoji_axes)

	# Should be PHOENIX (all high)
	assert_equal(region, SemanticOctant.Region.PHOENIX, "Detected PHOENIX from QC state")

	# Change to low state
	qc.initialize_basis(7)  # |111⟩ = 🍄🌙📦 (all south poles = low)

	# Now detect using south pole emojis as axes
	var low_axes: Array[String] = ["🍄", "🌙", "📦"]
	region = SemanticOctant.detect_from_quantum_computer(qc, low_axes)
	assert_equal(region, SemanticOctant.Region.PHOENIX, "South poles also detect as high when measured")

	print()
