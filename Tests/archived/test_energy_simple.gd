## SIMPLE TEST: Energy Amplitude System
## Minimal test to verify energy as radius works

extends Node

const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

func _ready():
	print("\n" + "=".repeat(60))
	print("QUICK TEST: Energy as Amplitude (Radius)")
	print("=".repeat(60) + "\n")

	var passes = 0
	var total = 0

	# TEST 1: Initial radius
	total += 1
	var q1 = DualEmojiQubit.new("🌾", "👥", PI/2.0)
	if q1.radius == 0.3:
		print("✅ TEST 1: Initial radius = 0.3")
		passes += 1
	else:
		print("❌ TEST 1: FAILED - initial radius = %f" % q1.radius)

	# TEST 2: Measurement freezes energy
	total += 1
	var q2 = DualEmojiQubit.new("🌾", "👥", PI/2.0)
	q2.radius = 0.5
	q2.measure()
	if q2.measured_energy == 0.5:
		print("✅ TEST 2: Measurement freezes energy at 0.5")
		passes += 1
	else:
		print("❌ TEST 2: FAILED - frozen energy = %f" % q2.measured_energy)

	# TEST 3: Energy growth
	total += 1
	var q3 = DualEmojiQubit.new("🌾", "👥", PI/2.0)
	var r_before = q3.radius
	q3.grow_energy(0.5, 1.0)
	if q3.radius > r_before:
		print("✅ TEST 3: Energy grows with sun strength")
		passes += 1
	else:
		print("❌ TEST 3: FAILED - radius didn't grow")

	# TEST 4: T1 damping reduces energy
	total += 1
	var q4 = DualEmojiQubit.new("🌾", "👥", PI/2.0)
	r_before = q4.radius
	q4.apply_amplitude_damping(0.1)
	if q4.radius < r_before:
		print("✅ TEST 4: T1 damping reduces radius")
		passes += 1
	else:
		print("❌ TEST 4: FAILED - radius didn't decay")

	# TEST 5: Coherence modulates growth
	total += 1
	var q5_super = DualEmojiQubit.new("🌾", "👥", PI/2.0)
	var q5_pure = DualEmojiQubit.new("🌾", "👥", 0.0)
	var coh_super = q5_super.get_coherence()
	var coh_pure = q5_pure.get_coherence()
	if coh_super > coh_pure:
		print("✅ TEST 5: Superposition has higher coherence than pure state")
		passes += 1
	else:
		print("❌ TEST 5: FAILED - coherence not right")

	print("\n" + "=".repeat(60))
	print("RESULTS: %d/%d PASSED" % [passes, total])
	print("=".repeat(60) + "\n")

	await get_tree().create_timer(0.1).timeout
	get_tree().quit(0 if passes == total else 1)
