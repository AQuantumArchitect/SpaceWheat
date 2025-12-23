## TEST: Energy as Amplitude (Radius) System
## Tests the refactored energy system where radius [0,1] represents stored energy

extends Node

const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const Biome = preload("res://Core/Environment/Biome.gd")

var test_count: int = 0
var pass_count: int = 0

func _ready():
	print("\n" + "=".repeat(80))
	print("  TEST SUITE: Energy as Amplitude (Radius) System")
	print("=".repeat(80) + "\n")

	test_initial_energy_at_plant()
	test_energy_grows_exponentially_with_sun()
	test_energy_decays_with_t1_damping()
	test_coherence_modulates_growth()
	test_measurement_freezes_energy()
	test_energy_yield_calculation()
	test_amplitude_normalized_to_one()

	print("\n" + "=".repeat(80))
	print("  TEST RESULTS: %d/%d PASSED ✅" % [pass_count, test_count])
	print("=".repeat(80) + "\n")

	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0 if pass_count == test_count else 1)


## TEST 1: Initial Energy at Plant
func test_initial_energy_at_plant():
	test_count += 1
	print("TEST %d: Initial Energy at Plant" % test_count)
	print("─".repeat(40))

	var qubit = DualEmojiQubit.new("🌾", "👥", PI/2.0)

	# Check initial radius (energy)
	assert(qubit.radius == 0.3, "Initial radius should be 0.3")
	assert(qubit.measured_energy == 0.0, "Measured energy should start at 0")
	assert(qubit.theta == PI/2.0, "Initial theta should be π/2 (superposition)")

	print("  ✅ Initial radius = 0.3 (starting energy)")
	print("  ✅ Measured energy = 0 (not frozen yet)")
	print("  ✅ Theta = π/2 (superposition)")
	print("✅ PASSED\n")
	pass_count += 1


## TEST 2: Energy Grows Exponentially with Sun
func test_energy_grows_exponentially_with_sun():
	test_count += 1
	print("TEST %d: Exponential Energy Growth with Sun" % test_count)
	print("─".repeat(40))

	var qubit = DualEmojiQubit.new("🌾", "👥", PI/2.0)
	var initial_radius = qubit.radius

	# Simulate sun energy (sun_strength = 0.5, dt = 1 second)
	qubit.grow_energy(0.5, 1.0)

	var expected = initial_radius * exp(0.5 * qubit.get_coherence() * 1.0)
	var actual = qubit.radius

	print("  Initial radius: %.4f" % initial_radius)
	print("  Coherence factor: %.4f" % qubit.get_coherence())
	print("  Sun strength: 0.5")
	print("  After 1 second: %.4f" % actual)
	print("  Expected (approx): %.4f" % expected)

	# Allow 1% tolerance for floating point
	var tolerance = 0.01
	assert(abs(actual - expected) < tolerance, "Growth should be exponential")
	assert(qubit.radius > initial_radius, "Energy should increase with sun")

	print("✅ PASSED\n")
	pass_count += 1


## TEST 3: Energy Decays with T1 Damping
func test_energy_decays_with_t1_damping():
	test_count += 1
	print("TEST %d: Energy Decay with T1 Damping" % test_count)
	print("─".repeat(40))

	var qubit = DualEmojiQubit.new("🌾", "👥", PI/2.0)
	var initial_radius = qubit.radius

	# Apply T1 damping (amplitude damping)
	qubit.apply_amplitude_damping(0.1)  # 10% decay rate

	var expected = initial_radius * (1.0 - 0.1)
	var actual = qubit.radius

	print("  Initial radius: %.4f" % initial_radius)
	print("  Decay rate: 0.1 (10%)")
	print("  After damping: %.4f" % actual)
	print("  Expected: %.4f" % expected)

	assert(qubit.radius < initial_radius, "T1 damping should reduce radius")
	assert(abs(qubit.radius - expected) < 0.001, "Decay should be linear in rate")

	print("✅ PASSED\n")
	pass_count += 1


## TEST 4: Coherence Modulates Growth Rate
func test_coherence_modulates_growth():
	test_count += 1
	print("TEST %d: Coherence Modulates Energy Growth" % test_count)
	print("─".repeat(40))

	# Pure superposition (high coherence)
	var qubit_super = DualEmojiQubit.new("🌾", "👥", PI/2.0)
	var coh_super = qubit_super.get_coherence()

	# Pure state (low coherence)
	var qubit_pure = DualEmojiQubit.new("🌾", "👥", 0.0)
	var coh_pure = qubit_pure.get_coherence()

	print("  Superposition (θ=π/2) coherence: %.4f" % coh_super)
	print("  Pure state (θ=0) coherence: %.4f" % coh_pure)

	assert(coh_super > coh_pure, "Superposition should have higher coherence")
	assert(coh_pure < 0.1, "Pure states should have low coherence")

	# Grow both with same sun strength
	var sun_strength = 0.5
	var dt = 1.0

	var r_super_before = qubit_super.radius
	var r_pure_before = qubit_pure.radius

	qubit_super.grow_energy(sun_strength, dt)
	qubit_pure.grow_energy(sun_strength, dt)

	var r_super_after = qubit_super.radius
	var r_pure_after = qubit_pure.radius

	var growth_super = r_super_after / r_super_before
	var growth_pure = r_pure_after / r_pure_before

	print("  Superposition growth factor: %.4f" % growth_super)
	print("  Pure state growth factor: %.4f" % growth_pure)

	assert(growth_super > growth_pure, "Superposition should grow faster than pure state")

	print("✅ PASSED\n")
	pass_count += 1


## TEST 5: Measurement Freezes Energy
func test_measurement_freezes_energy():
	test_count += 1
	print("TEST %d: Measurement Freezes Energy Value" % test_count)
	print("─".repeat(40))

	var qubit = DualEmojiQubit.new("🌾", "👥", PI/2.0)

	# Grow energy before measurement
	qubit.grow_energy(0.5, 2.0)
	var radius_before_measure = qubit.radius

	print("  Radius before measurement: %.4f" % radius_before_measure)

	# Measure (should freeze radius)
	var outcome = qubit.measure()

	print("  Measurement outcome: %s" % outcome)
	print("  Frozen energy: %.4f" % qubit.measured_energy)

	assert(qubit.measured_energy == radius_before_measure,
		"Frozen energy should equal radius at measurement")
	assert(outcome == qubit.north_emoji or outcome == qubit.south_emoji,
		"Outcome should be one of the emoji poles")

	# Try to grow after measurement (should still increase radius)
	qubit.grow_energy(0.5, 1.0)
	print("  Radius after growth: %.4f" % qubit.radius)
	print("  Frozen energy (still): %.4f" % qubit.measured_energy)

	assert(qubit.measured_energy != qubit.radius,
		"Frozen energy should NOT change after measurement")

	print("✅ PASSED\n")
	pass_count += 1


## TEST 6: Energy Yield Calculation
func test_energy_yield_calculation():
	test_count += 1
	print("TEST %d: Harvest Yield from Frozen Energy" % test_count)
	print("─".repeat(40))

	var qubit = DualEmojiQubit.new("🌾", "👥", PI/2.0)

	# Scenario: grow to radius 0.5
	qubit.radius = 0.5
	qubit.measure()

	var frozen_energy = qubit.measured_energy
	var expected_yield = int(frozen_energy * 10.0)

	print("  Frozen energy: %.2f" % frozen_energy)
	print("  Expected yield (×10): %d" % expected_yield)

	assert(frozen_energy == 0.5, "Frozen energy should be set to radius")
	assert(expected_yield == 5, "Yield should be int(energy × 10)")

	# Try another: radius 0.7
	var qubit2 = DualEmojiQubit.new("🌾", "👥", PI/2.0)
	qubit2.radius = 0.7
	qubit2.measure()

	var yield2 = int(qubit2.measured_energy * 10.0)
	print("  Frozen energy (2): %.2f → yield: %d" % [qubit2.measured_energy, yield2])
	assert(yield2 == 7, "Yield calculation should be consistent")

	print("✅ PASSED\n")
	pass_count += 1


## TEST 7: Amplitude Normalized to [0, 1]
func test_amplitude_normalized_to_one():
	test_count += 1
	print("TEST %d: Amplitude Clamped to [0, 1]" % test_count)
	print("─".repeat(40))

	var qubit = DualEmojiQubit.new("🌾", "👥", PI/2.0)

	# Try to overgrow (exponential might exceed 1.0)
	for i in range(10):
		qubit.grow_energy(1.0, 0.5)

	print("  After aggressive growth: %.4f" % qubit.radius)
	assert(qubit.radius <= 1.0, "Radius should be clamped to max 1.0")

	# Apply damping until depleted
	for i in range(20):
		qubit.apply_amplitude_damping(0.1)

	print("  After aggressive damping: %.4f" % qubit.radius)
	assert(qubit.radius >= 0.0, "Radius should never go negative")

	print("✅ PASSED\n")
	pass_count += 1
