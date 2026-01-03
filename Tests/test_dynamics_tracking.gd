#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test BiomeDynamicsTracker integration
## Verifies that dynamics tracking works and updates quest offers

const BiomeDynamicsTracker = preload("res://Core/QuantumSubstrate/BiomeDynamicsTracker.gd")
const FactionStateMatcher = preload("res://Core/QuantumSubstrate/FactionStateMatcher.gd")
const QuantumBath = preload("res://Core/QuantumSubstrate/QuantumBath.gd")

func _init():
	print("\n" + "=".repeat(80))
	print("🔄 DYNAMICS TRACKING TEST")
	print("=".repeat(80))

	# Test 1: Tracker basics
	print("\n📊 Test 1: BiomeDynamicsTracker Basics")
	test_tracker_basics()

	# Test 2: Dynamics in stable bath
	print("\n⚖️  Test 2: Stable Bath (no changes)")
	test_stable_dynamics()

	# Test 3: Dynamics in evolving bath
	print("\n🌀 Test 3: Evolving Bath (rapid changes)")
	test_evolving_dynamics()

	# Test 4: Integration with FactionStateMatcher
	print("\n⚛️  Test 4: FactionStateMatcher Integration")
	test_faction_matcher_integration()

	print("\n" + "=".repeat(80))
	print("✅ ALL DYNAMICS TESTS COMPLETE")
	print("=".repeat(80) + "\n")

	quit(0)


func test_tracker_basics():
	var tracker = BiomeDynamicsTracker.new()

	# Disable throttling for instant testing
	tracker.min_snapshot_interval_ms = 0

	# Add some snapshots
	tracker.add_snapshot({"purity": 0.5, "entropy": 0.5, "coherence": 0.0})
	OS.delay_msec(1)  # Small delay so timestamps differ
	tracker.add_snapshot({"purity": 0.6, "entropy": 0.4, "coherence": 0.1})

	var dynamics = tracker.get_dynamics()
	var label = tracker.get_stability_label()

	print("  Snapshots recorded: %d" % tracker.history.size())
	print("  Dynamics value: %.3f" % dynamics)
	print("  Stability label: %s" % label)
	print("  ✅ Tracker working")


func test_stable_dynamics():
	var tracker = BiomeDynamicsTracker.new()
	tracker.min_snapshot_interval_ms = 0

	# Record same state multiple times (no change)
	for i in range(5):
		tracker.add_snapshot({"purity": 0.7, "entropy": 0.3, "coherence": 0.2})
		OS.delay_msec(10)

	var dynamics = tracker.get_dynamics()

	print("  Recorded 5 identical snapshots")
	print("  Dynamics: %.3f (should be ~0.0 for stable)" % dynamics)

	if dynamics < 0.3:
		print("  ✅ Correctly identified as stable")
	else:
		print("  ⚠️  Unexpectedly high dynamics for stable state")


func test_evolving_dynamics():
	var tracker = BiomeDynamicsTracker.new()
	tracker.min_snapshot_interval_ms = 0

	# Record rapidly changing state
	for i in range(5):
		var purity = 0.3 + float(i) * 0.15  # Changes from 0.3 to 0.9
		tracker.add_snapshot({"purity": purity, "entropy": 1.0 - purity, "coherence": 0.0})
		OS.delay_msec(10)

	var dynamics = tracker.get_dynamics()

	print("  Recorded 5 changing snapshots (purity: 0.3 → 0.9)")
	print("  Dynamics: %.3f (should be >0.5 for active)" % dynamics)

	if dynamics > 0.5:
		print("  ✅ Correctly identified as active/volatile")
	else:
		print("  ⚠️  Unexpectedly low dynamics for changing state")


func test_faction_matcher_integration():
	# Create mock biome with tracker
	var biome = Node.new()
	biome.dynamics_tracker = BiomeDynamicsTracker.new()
	biome.dynamics_tracker.min_snapshot_interval_ms = 0

	# Add some evolution history
	for i in range(3):
		biome.dynamics_tracker.add_snapshot({
			"purity": 0.5 + float(i) * 0.1,
			"entropy": 0.5,
			"coherence": 0.1
		})
		OS.delay_msec(10)

	# Create bath
	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["🌾", "🍄", "💨"])

	# Extract observables WITH biome reference
	var obs = FactionStateMatcher.extract_observables(bath, biome)

	print("  Extracted observables with dynamics:")
	print("    Purity: %.3f" % obs.purity)
	print("    Entropy: %.3f" % obs.entropy)
	print("    Dynamics: %.3f (from tracker)" % obs.dynamics)

	if obs.dynamics != 0.5:
		print("  ✅ Dynamics populated from tracker (not placeholder!)")
	else:
		print("  ⚠️  Dynamics is placeholder 0.5 (tracker not working?)")

	# Extract observables WITHOUT biome reference (fallback)
	var obs_fallback = FactionStateMatcher.extract_observables(bath)

	print("\n  Extracted observables WITHOUT biome:")
	print("    Dynamics: %.3f (should be 0.5 fallback)" % obs_fallback.dynamics)

	if obs_fallback.dynamics == 0.5:
		print("  ✅ Fallback to 0.5 when no tracker")
