extends SceneTree

## Experiment 4: Forest Predator-Prey Dynamics Validation
## Tests Lotka-Volterra oscillations in forest ecosystem
##
## Theoretical model:
##   Trophic cascade: 🌿 vegetation ← 🐇 rabbit ← 🐺 wolf
##   Lindblad rates (10x slower): 🐇←🌿: 0.015/sec, 🐺←🐇: 0.012/sec
##   Expected: Observable predator-prey oscillations over ~60-120 seconds
##   Classic Lotka-Volterra: Prey peaks → Predator peaks → Prey crash → repeat

var biome: Node
var start_time: float = 0.0
var measurement_interval: float = 2.0  # Sample every 2 seconds
var last_measurement: float = 0.0
var duration: float = 240.0  # 4 minutes to see full cycles
var measurements: Array = []

func _init():
	print("\n╔════════════════════════════════════════════════════════╗")
	print("║   EXPERIMENT 4: FOREST PREDATOR-PREY DYNAMICS         ║")
	print("╚════════════════════════════════════════════════════════╝\n")

	# Initialize IconRegistry
	var IconRegistryScript = load("res://Core/QuantumSubstrate/IconRegistry.gd")
	var icon_registry = IconRegistryScript.new()
	icon_registry.name = "IconRegistry"
	root.add_child(icon_registry)
	icon_registry._ready()

	# Initialize ForestEcosystem
	var ForestBiome = load("res://Core/Environment/ForestEcosystem_Biome.gd")
	biome = ForestBiome.new()
	biome.name = "ForestEcosystem"
	root.add_child(biome)
	biome._ready()

	if not biome.bath:
		push_error("❌ Bath not initialized!")
		quit()
		return

	print("✅ Bath initialized")
	print("  Total emojis: %d" % biome.bath.emoji_list.size())

	# Verify predator-prey Lindblad rates
	print("\n📊 Predator-Prey Lindblad rates in bath:")
	var wolf_idx = biome.bath.emoji_to_index.get("🐺", -1)
	var rabbit_idx = biome.bath.emoji_to_index.get("🐇", -1)
	var deer_idx = biome.bath.emoji_to_index.get("🦌", -1)
	var vegetation_idx = biome.bath.emoji_to_index.get("🌿", -1)
	var eagle_idx = biome.bath.emoji_to_index.get("🦅", -1)

	print("\n  🐺 Wolf predation:")
	for term in biome.bath.lindblad_terms:
		if term.target == wolf_idx:
			var source = biome.bath.emoji_list[term.source]
			if source in ["🐇", "🦌"]:
				print("    %s → 🐺: %.5f/sec" % [source, term.rate])

	print("\n  🐇 Rabbit herbivory:")
	for term in biome.bath.lindblad_terms:
		if term.target == rabbit_idx:
			var source = biome.bath.emoji_list[term.source]
			if source == "🌿":
				print("    %s → 🐇: %.5f/sec" % [source, term.rate])

	print("\n  🦌 Deer herbivory:")
	for term in biome.bath.lindblad_terms:
		if term.target == deer_idx:
			var source = biome.bath.emoji_list[term.source]
			if source == "🌿":
				print("    %s → 🦌: %.5f/sec" % [source, term.rate])

	print("\n📈 Theoretical predictions:")
	print("  Lotka-Volterra dynamics: Prey peaks lead predator peaks by ~15-30s")
	print("  Expected oscillation period: ~60-120 seconds")
	print("  Expected: Stable cycles (not exponential growth/extinction)")

	# Set initial conditions: Balanced ecosystem
	print("\n🌲 Setting initial ecosystem state...")

	# Producers
	if vegetation_idx >= 0:
		biome.bath.amplitudes[vegetation_idx] = Complex.new(0.6, 0.0)

	# Primary consumers (herbivores)
	if rabbit_idx >= 0:
		biome.bath.amplitudes[rabbit_idx] = Complex.new(0.4, 0.0)
	if deer_idx >= 0:
		biome.bath.amplitudes[deer_idx] = Complex.new(0.3, 0.0)

	# Secondary consumers (predators)
	if wolf_idx >= 0:
		biome.bath.amplitudes[wolf_idx] = Complex.new(0.2, 0.0)
	if eagle_idx >= 0:
		biome.bath.amplitudes[eagle_idx] = Complex.new(0.15, 0.0)

	# Environmental factors
	var sun_idx = biome.bath.emoji_to_index.get("☀", -1)
	var water_idx = biome.bath.emoji_to_index.get("💧", -1)
	var soil_idx = biome.bath.emoji_to_index.get("⛰", -1)
	var decay_idx = biome.bath.emoji_to_index.get("🍂", -1)

	if sun_idx >= 0:
		biome.bath.amplitudes[sun_idx] = Complex.new(0.5, 0.0)
	if water_idx >= 0:
		biome.bath.amplitudes[water_idx] = Complex.new(0.4, 0.0)
	if soil_idx >= 0:
		biome.bath.amplitudes[soil_idx] = Complex.new(0.3, 0.0)
	if decay_idx >= 0:
		biome.bath.amplitudes[decay_idx] = Complex.new(0.2, 0.0)

	biome.bath.normalize()

	print("  Initial populations:")
	if vegetation_idx >= 0:
		print("    🌿 Vegetation: %.4f" % biome.bath.amplitudes[vegetation_idx].norm_squared())
	if rabbit_idx >= 0:
		print("    🐇 Rabbit: %.4f" % biome.bath.amplitudes[rabbit_idx].norm_squared())
	if deer_idx >= 0:
		print("    🦌 Deer: %.4f" % biome.bath.amplitudes[deer_idx].norm_squared())
	if wolf_idx >= 0:
		print("    🐺 Wolf: %.4f" % biome.bath.amplitudes[wolf_idx].norm_squared())
	if eagle_idx >= 0:
		print("    🦅 Eagle: %.4f" % biome.bath.amplitudes[eagle_idx].norm_squared())

	print("\n⏱️  Starting simulation (240 seconds - ~2-4 cycles)...")
	print("Time(s) | 🌿 Veg  | 🐇 Rabbit | 🦌 Deer | 🐺 Wolf | 🦅 Eagle")
	print("--------|---------|----------|---------|---------|----------")

	start_time = Time.get_ticks_msec() / 1000.0
	last_measurement = start_time

func _process(_delta: float) -> bool:
	var current_time = Time.get_ticks_msec() / 1000.0
	var elapsed = current_time - start_time

	# Update bath physics
	biome.bath.evolve(0.016)

	# Take measurements
	if current_time - last_measurement >= measurement_interval:
		last_measurement = current_time

		var vegetation_idx = biome.bath.emoji_to_index.get("🌿", -1)
		var rabbit_idx = biome.bath.emoji_to_index.get("🐇", -1)
		var deer_idx = biome.bath.emoji_to_index.get("🦌", -1)
		var wolf_idx = biome.bath.emoji_to_index.get("🐺", -1)
		var eagle_idx = biome.bath.emoji_to_index.get("🦅", -1)

		var veg_prob = biome.bath.amplitudes[vegetation_idx].norm_squared() if vegetation_idx >= 0 else 0.0
		var rabbit_prob = biome.bath.amplitudes[rabbit_idx].norm_squared() if rabbit_idx >= 0 else 0.0
		var deer_prob = biome.bath.amplitudes[deer_idx].norm_squared() if deer_idx >= 0 else 0.0
		var wolf_prob = biome.bath.amplitudes[wolf_idx].norm_squared() if wolf_idx >= 0 else 0.0
		var eagle_prob = biome.bath.amplitudes[eagle_idx].norm_squared() if eagle_idx >= 0 else 0.0

		print("%6.0f  | %7.4f | %8.4f | %7.4f | %7.4f | %8.4f" % [
			elapsed, veg_prob, rabbit_prob, deer_prob, wolf_prob, eagle_prob
		])

		measurements.append({
			"time": elapsed,
			"vegetation": veg_prob,
			"rabbit": rabbit_prob,
			"deer": deer_prob,
			"wolf": wolf_prob,
			"eagle": eagle_prob
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

	# Detect oscillation patterns
	print("\n📊 Oscillation Analysis:")

	# Find peaks for each species
	var rabbit_peaks: Array = []
	var wolf_peaks: Array = []

	for i in range(1, measurements.size() - 1):
		var prev = measurements[i - 1]
		var curr = measurements[i]
		var next = measurements[i + 1]

		# Rabbit peak (local maximum)
		if curr.rabbit > prev.rabbit and curr.rabbit > next.rabbit and curr.rabbit > 0.1:
			rabbit_peaks.append(curr.time)

		# Wolf peak (local maximum)
		if curr.wolf > prev.wolf and curr.wolf > next.wolf and curr.wolf > 0.05:
			wolf_peaks.append(curr.time)

	print("  Rabbit population peaks: %d" % rabbit_peaks.size())
	for t in rabbit_peaks:
		print("    - t = %.0fs" % t)

	print("\n  Wolf population peaks: %d" % wolf_peaks.size())
	for t in wolf_peaks:
		print("    - t = %.0fs" % t)

	# Calculate phase lag (predator should lag prey)
	if rabbit_peaks.size() > 0 and wolf_peaks.size() > 0:
		var phase_lags: Array = []
		for wolf_t in wolf_peaks:
			# Find nearest earlier rabbit peak
			var nearest_rabbit_t = -1.0
			for rabbit_t in rabbit_peaks:
				if rabbit_t < wolf_t:
					if nearest_rabbit_t < 0 or (wolf_t - rabbit_t) < (wolf_t - nearest_rabbit_t):
						nearest_rabbit_t = rabbit_t

			if nearest_rabbit_t >= 0:
				var lag = wolf_t - nearest_rabbit_t
				phase_lags.append(lag)

		if not phase_lags.is_empty():
			var avg_lag = 0.0
			for lag in phase_lags:
				avg_lag += lag
			avg_lag /= phase_lags.size()

			print("\n  Average predator-prey phase lag: %.1f seconds" % avg_lag)
			print("    (Predator peaks follow prey peaks by this delay)")

	# Calculate oscillation periods
	var rabbit_periods: Array = []
	for i in range(1, rabbit_peaks.size()):
		rabbit_periods.append(rabbit_peaks[i] - rabbit_peaks[i - 1])

	var wolf_periods: Array = []
	for i in range(1, wolf_peaks.size()):
		wolf_periods.append(wolf_peaks[i] - wolf_peaks[i - 1])

	if not rabbit_periods.is_empty():
		var avg_period = 0.0
		for p in rabbit_periods:
			avg_period += p
		avg_period /= rabbit_periods.size()
		print("\n  Rabbit population cycle period: %.1f seconds" % avg_period)

	if not wolf_periods.is_empty():
		var avg_period = 0.0
		for p in wolf_periods:
			avg_period += p
		avg_period /= wolf_periods.size()
		print("  Wolf population cycle period: %.1f seconds" % avg_period)

	# Check for stability (populations shouldn't go to zero or explode)
	var min_rabbit = 1.0
	var max_rabbit = 0.0
	var min_wolf = 1.0
	var max_wolf = 0.0

	for m in measurements:
		if m.rabbit < min_rabbit:
			min_rabbit = m.rabbit
		if m.rabbit > max_rabbit:
			max_rabbit = m.rabbit
		if m.wolf < min_wolf:
			min_wolf = m.wolf
		if m.wolf > max_wolf:
			max_wolf = m.wolf

	print("\n📊 Population Stability:")
	print("  Rabbit range: %.4f - %.4f" % [min_rabbit, max_rabbit])
	print("  Wolf range: %.4f - %.4f" % [min_wolf, max_wolf])

	# Validation
	print("\n✅ VALIDATION:")

	if rabbit_peaks.size() >= 2:
		print("  ✅ Multiple prey population cycles detected")
	else:
		print("  ⚠️  Fewer than 2 prey cycles detected")

	if wolf_peaks.size() >= 2:
		print("  ✅ Multiple predator population cycles detected")
	else:
		print("  ⚠️  Fewer than 2 predator cycles detected")

	if min_rabbit > 0.01 and min_wolf > 0.01:
		print("  ✅ Populations remain stable (no extinction)")
	else:
		print("  ❌ Population collapse detected!")

	if max_rabbit < 0.9 and max_wolf < 0.9:
		print("  ✅ Populations remain bounded (no explosion)")
	else:
		print("  ⚠️  Population may be growing too large")

	if rabbit_peaks.size() > 0 and wolf_peaks.size() > 0:
		if rabbit_peaks[0] < wolf_peaks[0]:
			print("  ✅ Prey peak precedes predator peak (Lotka-Volterra dynamics)")
		else:
			print("  ⚠️  Predator-prey phase relationship unclear")

	print("\n" + "=".repeat(70))
	quit()
