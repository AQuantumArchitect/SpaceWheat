#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test Suite: Biome Dynamics Tracker (Feature 6)
## Tests the BiomeDynamicsTracker component for quantum observable evolution

const BiomeDynamicsTracker = preload("res://Core/QuantumSubstrate/BiomeDynamicsTracker.gd")

var test_count: int = 0
var pass_count: int = 0


func _init():
	print("\n" + "=".repeat(70))
	print("BIOME DYNAMICS TRACKER TEST SUITE (Feature 6)")
	print("=".repeat(70) + "\n")

	# Basic tracking tests
	test_snapshot_creation()
	test_history_recording()
	test_history_ring_buffer()
	test_throttling()

	# Dynamics calculation tests
	test_dynamics_stable_state()
	test_dynamics_changing_state()
	test_dynamics_volatile_state()
	test_dynamics_normalization()

	# Label generation tests
	test_stability_labels()

	# Edge case tests
	test_empty_history_dynamics()
	test_single_snapshot_dynamics()

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


func assert_in_range(actual: float, min_val: float, max_val: float, message: String):
	test_count += 1
	if actual >= min_val and actual <= max_val:
		pass_count += 1
		print("  ✓ " + message)
	else:
		print("  ✗ FAILED: %s (expected [%.2f, %.2f], got %.2f)" % [message, min_val, max_val, actual])


## ========================================
## Snapshot Creation Tests
## ========================================

func test_snapshot_creation():
	print("\nTEST: Snapshot Creation")

	var tracker = BiomeDynamicsTracker.new()

	var obs = {
		"purity": 0.8,
		"entropy": 0.2,
		"coherence": 0.6
	}

	tracker.add_snapshot(obs)

	assert_equal(tracker.history.size(), 1, "Snapshot added to history")
	var snapshot = tracker.history[0]
	assert_approx(snapshot.purity, 0.8, 0.001, "Purity recorded")
	assert_approx(snapshot.entropy, 0.2, 0.001, "Entropy recorded")
	assert_approx(snapshot.coherence, 0.6, 0.001, "Coherence recorded")
	print()


func test_history_recording():
	print("\nTEST: History Recording")

	var tracker = BiomeDynamicsTracker.new()
	tracker.min_snapshot_interval_ms = 0  # Disable throttling for this test

	# Add multiple snapshots
	var snapshots_to_add = 5
	for i in range(snapshots_to_add):
		var obs = {
			"purity": 0.5 + i * 0.1,
			"entropy": 0.5 - i * 0.05,
			"coherence": float(i) * 0.1
		}
		tracker.add_snapshot(obs)

	assert_equal(tracker.history.size(), snapshots_to_add, "Multiple snapshots recorded")
	print()


func test_history_ring_buffer():
	print("\nTEST: History Ring Buffer (Max Size)")

	var tracker = BiomeDynamicsTracker.new()
	tracker.min_snapshot_interval_ms = 0  # Disable throttling
	tracker.max_history_size = 3

	# Add more snapshots than max size
	for i in range(5):
		var obs = {
			"purity": 0.5,
			"entropy": 0.5,
			"coherence": float(i) * 0.1
		}
		tracker.add_snapshot(obs)

	assert_equal(tracker.history.size(), 3, "History capped at max_history_size")
	# Last snapshot should be the most recent (coherence = 0.4)
	assert_approx(tracker.history[-1].coherence, 0.4, 0.001, "Ring buffer keeps latest samples")
	print()


func test_throttling():
	print("\nTEST: Snapshot Throttling")

	var tracker = BiomeDynamicsTracker.new()
	tracker.min_snapshot_interval_ms = 500  # 500ms minimum between snapshots

	var obs = {"purity": 0.5, "entropy": 0.5, "coherence": 0.0}

	# Add same snapshot multiple times rapidly
	tracker.add_snapshot(obs)
	tracker.add_snapshot(obs)
	tracker.add_snapshot(obs)

	assert_equal(tracker.history.size(), 1, "Only one snapshot recorded (others throttled)")
	print()


## ========================================
## Dynamics Calculation Tests
## ========================================

func test_dynamics_stable_state():
	print("\nTEST: Dynamics - Stable State (No Change)")

	var tracker = BiomeDynamicsTracker.new()
	tracker.min_snapshot_interval_ms = 0

	# Add same snapshot many times
	var obs = {"purity": 0.8, "entropy": 0.2, "coherence": 0.5}
	for i in range(5):
		tracker.add_snapshot(obs)
		if i < 4:
			get_tree().process_frame  # Slight delay between snapshots

	var dynamics = tracker.get_dynamics()
	assert_in_range(dynamics, 0.0, 0.2, "Stable state has low dynamics (0-0.2)")
	print()


func test_dynamics_changing_state():
	print("\nTEST: Dynamics - Changing State (Moderate Change)")

	var tracker = BiomeDynamicsTracker.new()
	tracker.min_snapshot_interval_ms = 10  # 10ms minimum

	# Add snapshots with gradual changes
	var obs1 = {"purity": 0.5, "entropy": 0.5, "coherence": 0.0}
	var obs2 = {"purity": 0.6, "entropy": 0.4, "coherence": 0.1}
	var obs3 = {"purity": 0.7, "entropy": 0.3, "coherence": 0.2}

	tracker.add_snapshot(obs1)
	OS.delay_msec(15)
	tracker.add_snapshot(obs2)
	OS.delay_msec(15)
	tracker.add_snapshot(obs3)

	var dynamics = tracker.get_dynamics()
	assert_in_range(dynamics, 0.0, 1.0, "Dynamics value normalized to [0, 1]")
	print()


func test_dynamics_volatile_state():
	print("\nTEST: Dynamics - Volatile State (Large Change)")

	var tracker = BiomeDynamicsTracker.new()
	tracker.min_snapshot_interval_ms = 10

	# Add snapshots with rapid changes
	var snap_values = [
		{"purity": 0.2, "entropy": 0.8, "coherence": 0.0},
		{"purity": 0.9, "entropy": 0.1, "coherence": 0.8},
		{"purity": 0.1, "entropy": 0.9, "coherence": 0.0},
		{"purity": 0.95, "entropy": 0.05, "coherence": 0.9}
	]

	for snap in snap_values:
		tracker.add_snapshot(snap)
		OS.delay_msec(15)

	var dynamics = tracker.get_dynamics()
	# High volatility should give higher dynamics value
	assert_true(dynamics > 0.3, "Volatile state has higher dynamics (>0.3)")
	print()


func test_dynamics_normalization():
	print("\nTEST: Dynamics - Normalization to [0, 1]")

	var tracker = BiomeDynamicsTracker.new()
	tracker.min_snapshot_interval_ms = 10

	# Add any snapshots
	var obs1 = {"purity": 0.5, "entropy": 0.5, "coherence": 0.0}
	var obs2 = {"purity": 0.6, "entropy": 0.4, "coherence": 0.1}

	tracker.add_snapshot(obs1)
	OS.delay_msec(15)
	tracker.add_snapshot(obs2)

	var dynamics = tracker.get_dynamics()
	assert_in_range(dynamics, 0.0, 1.0, "Dynamics always normalized to [0, 1]")
	print()


## ========================================
## Stability Label Tests
## ========================================

func test_stability_labels():
	print("\nTEST: Stability Labels")

	var tracker = BiomeDynamicsTracker.new()

	# Test with stable state (empty history gives neutral 0.5)
	var label = tracker.get_stability_label()
	assert_true(label != "", "Stability label generated")
	assert_true(
		label.contains("Stable") or label.contains("Moderate") or label.contains("Volatile") or label.contains("Unstable"),
		"Label is descriptive: %s" % label
	)
	print()


## ========================================
## Edge Case Tests
## ========================================

func test_empty_history_dynamics():
	print("\nTEST: Dynamics - Empty History")

	var tracker = BiomeDynamicsTracker.new()

	# No snapshots added
	var dynamics = tracker.get_dynamics()

	assert_approx(dynamics, 0.5, 0.001, "Empty history returns neutral dynamics (0.5)")
	print()


func test_single_snapshot_dynamics():
	print("\nTEST: Dynamics - Single Snapshot")

	var tracker = BiomeDynamicsTracker.new()
	tracker.min_snapshot_interval_ms = 0

	var obs = {"purity": 0.8, "entropy": 0.2, "coherence": 0.5}
	tracker.add_snapshot(obs)

	var dynamics = tracker.get_dynamics()

	assert_approx(dynamics, 0.5, 0.001, "Single snapshot returns neutral dynamics (0.5)")
	print()
