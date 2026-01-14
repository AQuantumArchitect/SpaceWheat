extends SceneTree

## Experiment 1: Wheat Growth Rate Validation
## Measures actual wheat growth curve and compares to theoretical predictions
##
## Theoretical model:
##   Lindblad rates: ☀→🌾: 0.00267/sec, 💧→🌾: 0.00167/sec, ⛰→🌾: 0.00067/sec
##   Total incoming rate: 0.00501/sec
##   Amplitude transfer per frame (dt=0.016): √(0.00501 × 0.016) ≈ 0.00895 ≈ 0.9%
##   Expected time to 50% probability: ~13 seconds
##   Expected time to 90% probability: ~30 seconds

var biome: Node
var start_time: float = 0.0
var measurement_interval: float = 0.5  # Sample every 0.5 seconds
var last_measurement: float = 0.0
var duration: float = 45.0  # Run for 45 seconds
var measurements: Array = []

func _init():
	print("\n╔════════════════════════════════════════════════════════╗")
	print("║   EXPERIMENT 1: WHEAT GROWTH RATE VALIDATION          ║")
	print("╚════════════════════════════════════════════════════════╝\n")

	# Initialize IconRegistry
	var IconRegistryScript = load("res://Core/QuantumSubstrate/IconRegistry.gd")
	var icon_registry = IconRegistryScript.new()
	icon_registry.name = "IconRegistry"
	root.add_child(icon_registry)
	icon_registry._ready()

	# Create QuantumBath directly
	var QuantumBath = load("res://Core/QuantumSubstrate/QuantumBath.gd")
	var bath = QuantumBath.new()

	# Get Icons for BioticFlux biome
	var emojis = ["☀", "🌙", "🌾", "🍄", "💀", "🍂"]
	var icons: Array[Icon] = []
	for emoji in emojis:
		var icon = icon_registry.get_icon(emoji)
		if icon:
			icons.append(icon)
		else:
			push_warning("Icon not found: " + emoji)

	# Initialize bath with icons
	bath.initialize_from_icons(icons)

	# Create a simple biome container (just for organizing the bath)
	biome = Node.new()
	biome.name = "TestBiome"
	biome.set("bath", bath)
	root.add_child(biome)

	if not bath:
		push_error("❌ Bath not initialized!")
		quit()
		return

	# Replace references to biome.bath with bath directly
	var actual_bath = bath

	print("✅ Bath initialized")
	print("  Emojis: %s" % [", ".join(bath.emoji_list)])
	print("  Hamiltonian terms: %d" % bath.hamiltonian_sparse.size())
	print("  Lindblad terms: %d" % bath.lindblad_terms.size())

	# Verify wheat Lindblad rates
	print("\n📊 Wheat Lindblad rates in bath:")
	var wheat_idx = bath.emoji_to_index.get("🌾", -1)
	var total_incoming_rate = 0.0
	for term in bath.lindblad_terms:
		if term.target == wheat_idx:
			var source_emoji = bath.emoji_list[term.source]
			print("  %s → 🌾: %.5f/sec" % [source_emoji, term.rate])
			total_incoming_rate += term.rate

	print("\n📈 Theoretical predictions:")
	print("  Total incoming rate: %.5f/sec" % total_incoming_rate)
	var amplitude_per_frame = sqrt(total_incoming_rate * 0.016)
	print("  Amplitude transfer/frame (dt=0.016): %.5f (%.2f%%)" % [amplitude_per_frame, amplitude_per_frame * 100])
	var t_50 = -log(0.5) / total_incoming_rate if total_incoming_rate > 0 else 999
	var t_90 = -log(0.1) / total_incoming_rate if total_incoming_rate > 0 else 999
	print("  Expected 50%% probability: ~%.1f seconds" % t_50)
	print("  Expected 90%% probability: ~%.1f seconds" % t_90)

	# Set initial conditions: Eternal emojis at high amplitude, wheat at low
	print("\n🌱 Setting initial conditions...")
	var sun_idx = bath.emoji_to_index.get("☀", -1)
	var moon_idx = bath.emoji_to_index.get("🌙", -1)
	var water_idx = bath.emoji_to_index.get("💧", -1)
	var soil_idx = bath.emoji_to_index.get("⛰", -1)
	var death_idx = bath.emoji_to_index.get("💀", -1)
	var decay_idx = bath.emoji_to_index.get("🍂", -1)

	# Initialize with sun, water, soil at moderate amplitude
	# Wheat starts near zero
	bath.amplitudes[sun_idx] = Complex.new(0.5, 0.0)
	bath.amplitudes[wheat_idx] = Complex.new(0.05, 0.0)  # Small initial seed
	bath.amplitudes[moon_idx] = Complex.new(0.1, 0.0)
	if death_idx >= 0:
		bath.amplitudes[death_idx] = Complex.new(0.1, 0.0)
	if decay_idx >= 0:
		bath.amplitudes[decay_idx] = Complex.new(0.1, 0.0)

	# Water and soil don't exist in the emojis list, so skip them
	bath.normalize()

	var initial_prob = bath.amplitudes[wheat_idx].abs_sq()
	print("  Initial wheat probability: %.4f" % initial_prob)

	print("\n⏱️  Starting simulation (45 seconds)...")
	print("Time(s)  | Wheat P(t) | Expected P(t) | Error")
	print("---------|------------|---------------|-------")

	start_time = Time.get_ticks_msec() / 1000.0
	last_measurement = start_time

func _process(_delta: float) -> bool:
	var current_time = Time.get_ticks_msec() / 1000.0
	var elapsed = current_time - start_time

	# Update bath physics
	var bath = biome.get("bath")
	bath.evolve(0.016)  # 60 FPS timestep

	# Take measurements at intervals
	if current_time - last_measurement >= measurement_interval:
		last_measurement = current_time

		var wheat_idx = bath.emoji_to_index.get("🌾", -1)
		var actual_prob = bath.amplitudes[wheat_idx].abs_sq()

		# Theoretical: P(t) ≈ 1 - exp(-k×t) for single-state growth
		# But with competition and normalization, it's more complex
		# Use simple exponential approach: P(t) ≈ P_eq × (1 - exp(-k×t))
		# Assuming P_eq ≈ 0.8 (wheat can reach 80% in ideal conditions)
		var total_rate = 0.00501  # From measured Lindblad terms
		var P_equilibrium = 0.7  # Rough estimate
		var expected_prob = P_equilibrium * (1.0 - exp(-total_rate * elapsed))

		var error = abs(actual_prob - expected_prob)
		var error_pct = (error / expected_prob * 100.0) if expected_prob > 0.01 else 0.0

		print("%7.1f  | %10.4f | %13.4f | %5.1f%%" % [elapsed, actual_prob, expected_prob, error_pct])

		measurements.append({
			"time": elapsed,
			"actual": actual_prob,
			"expected": expected_prob,
			"error": error
		})

	# End simulation after duration
	if elapsed >= duration:
		_finish_experiment()
		return true  # Stop processing

	return false

func _finish_experiment():
	print("\n" + "=".repeat(60))
	print("EXPERIMENT RESULTS")
	print("=".repeat(60))

	if measurements.is_empty():
		push_error("❌ No measurements recorded!")
		quit()
		return

	# Calculate statistics
	var total_error = 0.0
	var max_error = 0.0
	var max_error_time = 0.0

	for m in measurements:
		total_error += m.error
		if m.error > max_error:
			max_error = m.error
			max_error_time = m.time

	var avg_error = total_error / measurements.size()
	var final_measurement = measurements[-1]

	print("\n📊 Statistical Analysis:")
	print("  Total measurements: %d" % measurements.size())
	print("  Average error: %.4f (%.1f%% relative)" % [avg_error, avg_error * 100 / 0.5])
	print("  Maximum error: %.4f at t=%.1fs" % [max_error, max_error_time])
	print("  Final wheat probability: %.4f" % final_measurement.actual)
	print("  Expected final probability: %.4f" % final_measurement.expected)

	# Validate against theoretical predictions
	print("\n✅ VALIDATION:")

	var t_50_actual = -1.0
	var t_90_actual = -1.0

	for m in measurements:
		if t_50_actual < 0 and m.actual >= 0.5:
			t_50_actual = m.time
		if t_90_actual < 0 and m.actual >= 0.9:
			t_90_actual = m.time

	var total_rate = 0.00501
	var t_50_theory = -log(0.5) / total_rate * 0.7  # Scale by P_eq
	var t_90_theory = -log(0.1) / total_rate * 0.7

	if t_50_actual > 0:
		print("  50%% probability reached at: %.1fs (predicted: %.1fs)" % [t_50_actual, t_50_theory])
	else:
		print("  50%% probability: NOT REACHED (predicted: %.1fs)" % t_50_theory)

	if t_90_actual > 0:
		print("  90%% probability reached at: %.1fs (predicted: %.1fs)" % [t_90_actual, t_90_theory])
	else:
		print("  90%% probability: NOT REACHED (predicted: %.1fs)" % t_90_theory)

	# Overall assessment
	if avg_error < 0.05:
		print("\n✅ EXCELLENT: Model predictions match simulation within 5% error")
	elif avg_error < 0.10:
		print("\n✅ GOOD: Model predictions match simulation within 10% error")
	elif avg_error < 0.15:
		print("\n⚠️  ACCEPTABLE: Model shows 10-15% deviation from predictions")
	else:
		print("\n❌ POOR: Model deviates significantly from theoretical predictions")

	print("\n" + "=".repeat(60))
	quit()
