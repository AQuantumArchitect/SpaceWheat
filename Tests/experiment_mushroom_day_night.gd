extends SceneTree

## Experiment 2: Mushroom Day/Night Cycle Validation
## Tests mushroom growth from moon (night) and damage from sun (day)
##
## Theoretical model:
##   Lindblad rates: 🌙→🍄: 0.006/sec, 🍂→🍄: 0.012/sec
##   Total incoming rate: 0.018/sec
##   Expected maturity time (night): ~15 seconds to 90% probability
##   Energy couplings: ☀: -0.20 (damage), 🌙: +0.40 (growth)
##   Expected behavior: Grow at night, shrink (radius) during day

var biome: Node
var start_time: float = 0.0
var measurement_interval: float = 0.5
var last_measurement: float = 0.0
var duration: float = 120.0  # 2 minutes to see full day/night cycle
var measurements: Array = []

# Day/night cycle parameters (match Icon driver settings)
var day_night_frequency: float = 1.0 / 60.0  # 60-second period
var current_phase: String = "night"  # Start at night

func _init():
	print("\n╔════════════════════════════════════════════════════════╗")
	print("║   EXPERIMENT 2: MUSHROOM DAY/NIGHT CYCLE              ║")
	print("╚════════════════════════════════════════════════════════╝\n")

	# Initialize IconRegistry
	var IconRegistryScript = load("res://Core/QuantumSubstrate/IconRegistry.gd")
	var icon_registry = IconRegistryScript.new()
	icon_registry.name = "IconRegistry"
	root.add_child(icon_registry)
	icon_registry._ready()

	# Initialize BioticFluxBiome
	var BioticFluxBiome = load("res://Core/Environment/BioticFluxBiome.gd")
	biome = BioticFluxBiome.new()
	biome.name = "BioticFluxBiome"
	root.add_child(biome)
	biome._ready()

	if not biome.bath:
		push_error("❌ Bath not initialized!")
		quit()
		return

	print("✅ Bath initialized")

	# Verify mushroom Lindblad rates
	print("\n📊 Mushroom Lindblad rates in bath:")
	var mushroom_idx = biome.bath.emoji_to_index.get("🍄", -1)
	var total_incoming_rate = 0.0
	for term in biome.bath.lindblad_terms:
		if term.target == mushroom_idx:
			var source_emoji = biome.bath.emoji_list[term.source]
			print("  %s → 🍄: %.5f/sec" % [source_emoji, term.rate])
			total_incoming_rate += term.rate

	print("\n📈 Theoretical predictions:")
	print("  Total incoming rate: %.5f/sec" % total_incoming_rate)
	var amplitude_per_frame = sqrt(total_incoming_rate * 0.016)
	print("  Amplitude transfer/frame: %.5f (%.2f%%)" % [amplitude_per_frame, amplitude_per_frame * 100])
	var t_90 = -log(0.1) / total_incoming_rate if total_incoming_rate > 0 else 999
	print("  Expected 90%% probability: ~%.1f seconds (at night)" % t_90)

	# Check energy couplings
	var mushroom_icon = icon_registry.get_icon("🍄")
	if mushroom_icon:
		print("\n🌡️  Mushroom energy couplings:")
		for obs in mushroom_icon.energy_couplings:
			var coupling = mushroom_icon.energy_couplings[obs]
			var sign = "+" if coupling > 0 else ""
			print("  %s: %s%.2f (radius %s during exposure)" % [
				obs, sign, coupling,
				"grows" if coupling > 0 else "shrinks"
			])

	# Set initial conditions
	print("\n🌱 Setting initial conditions (night time)...")
	var sun_idx = biome.bath.emoji_to_index.get("☀", -1)
	var moon_idx = biome.bath.emoji_to_index.get("🌙", -1)
	var water_idx = biome.bath.emoji_to_index.get("💧", -1)
	var decay_idx = biome.bath.emoji_to_index.get("🍂", -1)

	# Night: Moon high, sun low
	biome.bath.amplitudes[moon_idx] = Complex.new(0.6, 0.0)
	biome.bath.amplitudes[sun_idx] = Complex.new(0.1, 0.0)
	biome.bath.amplitudes[water_idx] = Complex.new(0.3, 0.0)
	if decay_idx >= 0:
		biome.bath.amplitudes[decay_idx] = Complex.new(0.4, 0.0)  # Organic matter present
	biome.bath.amplitudes[mushroom_idx] = Complex.new(0.05, 0.0)  # Spore

	biome.bath.normalize()

	print("  Initial mushroom probability: %.4f" % biome.bath.amplitudes[mushroom_idx].norm_squared())
	print("  Starting in NIGHT phase (moon dominant)")

	print("\n⏱️  Starting simulation (120 seconds - 2 day/night cycles)...")
	print("Time(s)  | Phase | 🍄 P(t) | 🌙 P(t) | ☀ P(t) | Expected Growth")
	print("---------|-------|---------|---------|--------|------------------")

	start_time = Time.get_ticks_msec() / 1000.0
	last_measurement = start_time

func _process(_delta: float) -> bool:
	var current_time = Time.get_ticks_msec() / 1000.0
	var elapsed = current_time - start_time

	# Determine day/night phase based on time
	# Simple model: 0-30s = night, 30-60s = day, 60-90s = night, 90-120s = day
	var cycle_pos = fmod(elapsed, 60.0)
	var new_phase = "night" if cycle_pos < 30.0 else "day"

	# Update sun/moon amplitudes to simulate day/night
	var sun_idx = biome.bath.emoji_to_index.get("☀", -1)
	var moon_idx = biome.bath.emoji_to_index.get("🌙", -1)

	if new_phase != current_phase:
		current_phase = new_phase
		print("\n>>> PHASE CHANGE: %s at t=%.1fs <<<\n" % [current_phase.to_upper(), elapsed])

		# Swap sun/moon dominance
		if current_phase == "day":
			biome.bath.amplitudes[sun_idx] = Complex.new(0.7, 0.0)
			biome.bath.amplitudes[moon_idx] = Complex.new(0.1, 0.0)
		else:
			biome.bath.amplitudes[sun_idx] = Complex.new(0.1, 0.0)
			biome.bath.amplitudes[moon_idx] = Complex.new(0.6, 0.0)

		biome.bath.normalize()

	# Update bath physics
	biome.bath.evolve(0.016)

	# Take measurements
	if current_time - last_measurement >= measurement_interval:
		last_measurement = current_time

		var mushroom_idx = biome.bath.emoji_to_index.get("🍄", -1)
		var mushroom_prob = biome.bath.amplitudes[mushroom_idx].norm_squared()
		var moon_prob = biome.bath.amplitudes[moon_idx].norm_squared()
		var sun_prob = biome.bath.amplitudes[sun_idx].norm_squared()

		# Expected growth: High during night (moon present), low during day
		var expected_growth = "HIGH (moon)" if current_phase == "night" else "LOW (sun damage)"

		print("%7.1f  | %5s | %7.4f | %7.4f | %7.4f | %s" % [
			elapsed, current_phase, mushroom_prob, moon_prob, sun_prob, expected_growth
		])

		measurements.append({
			"time": elapsed,
			"phase": current_phase,
			"mushroom_prob": mushroom_prob,
			"moon_prob": moon_prob,
			"sun_prob": sun_prob
		})

	# End simulation
	if elapsed >= duration:
		_finish_experiment()
		return true

	return false

func _finish_experiment():
	print("\n" + "=".repeat(70))
	print("EXPERIMENT RESULTS")
	print("=".repeat(70))

	if measurements.is_empty():
		push_error("❌ No measurements recorded!")
		quit()
		return

	# Analyze night vs day growth
	var night_measurements: Array = []
	var day_measurements: Array = []

	for m in measurements:
		if m.phase == "night":
			night_measurements.append(m)
		else:
			day_measurements.append(m)

	# Calculate average mushroom probability during each phase
	var night_avg = 0.0
	for m in night_measurements:
		night_avg += m.mushroom_prob
	if not night_measurements.is_empty():
		night_avg /= night_measurements.size()

	var day_avg = 0.0
	for m in day_measurements:
		day_avg += m.mushroom_prob
	if not day_measurements.is_empty():
		day_avg /= day_measurements.size()

	print("\n📊 Statistical Analysis:")
	print("  Night measurements: %d" % night_measurements.size())
	print("  Day measurements: %d" % day_measurements.size())
	print("  Average mushroom probability (night): %.4f" % night_avg)
	print("  Average mushroom probability (day): %.4f" % day_avg)
	print("  Night/Day ratio: %.2fx" % (night_avg / day_avg if day_avg > 0 else 999))

	# Check if mushrooms grow during night
	print("\n✅ VALIDATION:")

	var night_growth = false
	var prev_prob = 0.0
	for m in night_measurements:
		if m.mushroom_prob > prev_prob + 0.01:  # Growth threshold
			night_growth = true
			break
		prev_prob = m.mushroom_prob

	if night_growth:
		print("  ✅ Mushrooms grow during night (as expected)")
	else:
		print("  ❌ Mushrooms did NOT grow during night (unexpected!)")

	# Check for day/night difference
	if night_avg > day_avg * 1.2:
		print("  ✅ Clear day/night difference observed (%.1fx)" % (night_avg / day_avg if day_avg > 0 else 0))
	elif night_avg > day_avg:
		print("  ⚠️  Weak day/night difference (%.1fx)" % (night_avg / day_avg if day_avg > 0 else 0))
	else:
		print("  ❌ No day/night advantage detected")

	# Find peak mushroom probability
	var peak_prob = 0.0
	var peak_time = 0.0
	for m in measurements:
		if m.mushroom_prob > peak_prob:
			peak_prob = m.mushroom_prob
			peak_time = m.time

	print("  Peak mushroom probability: %.4f at t=%.1fs" % [peak_prob, peak_time])

	if peak_prob > 0.5:
		print("  ✅ Mushrooms reached maturity (>50%% probability)")
	else:
		print("  ⚠️  Mushrooms did not reach full maturity")

	print("\n" + "=".repeat(70))
	quit()
