## TEST: Biome Energy Growth Integration
## Tests sun/moon cycle energy growth and Hamiltonian bias

extends Node

const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const Biome = preload("res://Core/Environment/Biome.gd")

var test_count: int = 0
var pass_count: int = 0

func _ready():
	print("\n" + "=".repeat(80))
	print("  TEST SUITE: Biome Energy Growth Integration")
	print("=".repeat(80) + "\n")

	test_sun_phase_energy_growth()
	test_moon_phase_no_growth()
	test_sun_hamiltonian_bias()
	test_moon_phase_theta_neutral()
	test_full_cycle_simulation()

	print("\n" + "=".repeat(80))
	print("  TEST RESULTS: %d/%d PASSED ✅" % [pass_count, test_count])
	print("=".repeat(80) + "\n")

	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0 if pass_count == test_count else 1)


## TEST 1: Sun Phase Energy Growth
func test_sun_phase_energy_growth():
	test_count += 1
	print("TEST %d: Sun Phase Energy Growth" % test_count)
	print("─".repeat(40))

	var biome = Biome.new()
	var qubit = DualEmojiQubit.new("🌾", "👥", PI/2.0)

	biome.sun_moon_phase = 0.0  # Start at noon (peak sun)
	var initial_radius = qubit.radius

	print("  Initial conditions:")
	print("    Sun/moon phase: %.2f rad (SUN)" % biome.sun_moon_phase)
	print("    Is sun? %s" % biome.is_currently_sun())
	print("    Initial radius: %.4f" % initial_radius)

	# Apply energy growth during sun phase
	biome.apply_energy_growth(qubit, 1.0)

	print("  After 1 second of sun energy:")
	print("    Final radius: %.4f" % qubit.radius)
	print("    Growth: %.4f" % (qubit.radius - initial_radius))

	assert(qubit.radius > initial_radius, "Energy should grow during sun phase")

	print("✅ PASSED\n")
	pass_count += 1


## TEST 2: Moon Phase No Growth
func test_moon_phase_no_growth():
	test_count += 1
	print("TEST %d: Moon Phase No Growth" % test_count)
	print("─".repeat(40))

	var biome = Biome.new()
	var qubit = DualEmojiQubit.new("🌾", "👥", PI/2.0)

	biome.sun_moon_phase = PI + 0.1  # Midnight/moon phase
	var initial_radius = qubit.radius

	print("  Initial conditions:")
	print("    Sun/moon phase: %.2f rad (MOON)" % biome.sun_moon_phase)
	print("    Is sun? %s" % biome.is_currently_sun())
	print("    Initial radius: %.4f" % initial_radius)

	# Apply energy growth during moon phase (should be minimal)
	biome.apply_energy_growth(qubit, 1.0)

	print("  After 1 second of moon (no energy):")
	print("    Final radius: %.4f" % qubit.radius)
	print("    Change: %.6f" % (qubit.radius - initial_radius))

	assert(abs(qubit.radius - initial_radius) < 0.001,
		"Energy should NOT grow during moon phase")

	print("✅ PASSED\n")
	pass_count += 1


## TEST 3: Sun Hamiltonian Bias (σ_z Stickiness)
func test_sun_hamiltonian_bias():
	test_count += 1
	print("TEST %d: Sun Hamiltonian Bias Toward 🌾 (σ_z)" % test_count)
	print("─".repeat(40))

	var biome = Biome.new()
	var qubit = DualEmojiQubit.new("🌾", "👥", PI/2.0)  # Start superposed

	biome.sun_moon_phase = 0.0  # Noon (peak sun Hamiltonian strength)
	var initial_theta = qubit.theta

	print("  Initial conditions:")
	print("    Sun phase: %.2f rad (NOON)" % biome.sun_moon_phase)
	print("    Initial theta: %.4f rad (superposition)" % initial_theta)
	print("    North emoji (🌾) at θ=0, south (👥) at θ=π")

	# Apply sun Hamiltonian (should bias theta toward 0)
	biome.apply_sun_moon_hamiltonian(qubit, 1.0)

	print("  After 1 second of sun Hamiltonian:")
	print("    Final theta: %.4f rad" % qubit.theta)
	print("    Change: %.4f rad (toward north)" % (initial_theta - qubit.theta))

	assert(qubit.theta < initial_theta, "Sun σ_z should push θ toward 0 (🌾)")

	print("✅ PASSED\n")
	pass_count += 1


## TEST 4: Moon Phase Theta Neutral
func test_moon_phase_theta_neutral():
	test_count += 1
	print("TEST %d: Moon Phase Theta Neutral (No Bias)" % test_count)
	print("─".repeat(40))

	var biome = Biome.new()
	var qubit = DualEmojiQubit.new("🌾", "👥", PI/2.0)

	biome.sun_moon_phase = PI  # Midnight
	var initial_theta = qubit.theta

	print("  Initial conditions:")
	print("    Moon phase: %.2f rad (MIDNIGHT)" % biome.sun_moon_phase)
	print("    Initial theta: %.4f rad" % initial_theta)

	# Apply "Hamiltonian" during moon (should be zero strength)
	biome.apply_sun_moon_hamiltonian(qubit, 1.0)

	print("  After 1 second of moon (no bias):")
	print("    Final theta: %.4f rad" % qubit.theta)
	print("    Change: %.6f rad (essentially none)" % abs(qubit.theta - initial_theta))

	assert(abs(qubit.theta - initial_theta) < 0.001,
		"Moon phase should have no θ bias")

	print("✅ PASSED\n")
	pass_count += 1


## TEST 5: Full Cycle Simulation
func test_full_cycle_simulation():
	test_count += 1
	print("TEST %d: Full Sun/Moon Cycle Simulation" % test_count)
	print("─".repeat(40))

	var biome = Biome.new()
	var qubit = DualEmojiQubit.new("🌾", "👥", PI/2.0)

	var initial_radius = qubit.radius
	var initial_theta = qubit.theta

	print("  Simulating full 20-second day/night cycle:")
	print("  Starting: radius=%.4f, theta=%.4f" % [initial_radius, initial_theta])
	print("")

	# Simulate one full period (20 seconds at sun_moon_period = 20.0)
	var dt = 0.1  # 100ms per step
	var max_steps = 200  # 20 seconds total
	var max_radius = 0.0
	var min_radius = 10.0

	for step in range(max_steps):
		# Apply both effects
		biome.apply_energy_growth(qubit, dt)
		biome.apply_sun_moon_hamiltonian(qubit, dt)

		# Also apply some decoherence to keep it realistic
		biome.apply_dissipation(qubit, Vector2i.ZERO, dt)

		# Advance biome phase
		biome._sync_sun_moon_phase(dt)

		if qubit.radius > max_radius:
			max_radius = qubit.radius
		if qubit.radius < min_radius:
			min_radius = qubit.radius

	var final_radius = qubit.radius
	var final_theta = qubit.theta

	print("  ☀️  SUN PHASE (0-10s): Energy growth, θ biased toward 0")
	print("  🌙 MOON PHASE (10-20s): Energy stalls, θ drifts freely")
	print("")
	print("  Final state after full cycle:")
	print("    Radius: %.4f → %.4f (max: %.4f, min: %.4f)" % [initial_radius, final_radius, max_radius, min_radius])
	print("    Theta: %.4f → %.4f" % [initial_theta, final_theta])
	print("    Phase cycle: 0 → %.2f rad" % biome.sun_moon_phase)

	# Energy should have grown overall (despite dissipation) due to sun
	assert(max_radius > initial_radius, "Energy should peak during sun phase")

	# Theta should have drifted (sun biases it, moon lets it drift)
	assert(final_theta != initial_theta, "Theta should change through cycle")

	print("✅ PASSED\n")
	pass_count += 1
