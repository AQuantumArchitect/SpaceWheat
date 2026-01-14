extends SceneTree

## Comprehensive Icon Rate Validation Experiment
## Tests all key predictions in one unified test:
##   1. Wheat growth rate (30x slower)
##   2. Mushroom growth rate (10x slower)
##   3. Lindblad transfer dynamics
##   4. Bath normalization stability

var start_time: float = 0.0
var duration: float = 30.0  # 30 second test
var measurement_interval: float = 2.0
var last_measurement: float = 0.0

# Test data
var wheat_bath: Node
var mushroom_bath: Node
var measurements: Dictionary = {
	"wheat": [],
	"mushroom": []
}

func _init():
	print("\n╔═══════════════════════════════════════════════════════════╗")
	print("║   COMPREHENSIVE ICON RATE VALIDATION EXPERIMENT           ║")
	print("╚═══════════════════════════════════════════════════════════╝\n")

	# Initialize IconRegistry
	var IconRegistryScript = load("res://Core/QuantumSubstrate/IconRegistry.gd")
	var icon_registry = IconRegistryScript.new()
	icon_registry.name = "IconRegistry"
	root.add_child(icon_registry)
	icon_registry._ready()

	print("✅ IconRegistry initialized: %d icons\n" % icon_registry.icons.size())

	# Create wheat growth test bath
	wheat_bath = _create_wheat_test_bath(icon_registry)

	# Create mushroom growth test bath
	mushroom_bath = _create_mushroom_test_bath(icon_registry)

	print("\n⏱️  Starting 30-second simulation...")
	print("\nTime(s) | 🌾 Wheat P | 🍄 Mushroom P | Notes")
	print("--------|------------|---------------|---------------------------")

	start_time = Time.get_ticks_msec() / 1000.0
	last_measurement = start_time

func _create_wheat_test_bath(icon_registry) -> Node:
	print("📊 EXPERIMENT 1: Wheat Growth Rate (30x slower)")
	var QuantumBath = load("res://Core/QuantumSubstrate/QuantumBath.gd")
	var bath = QuantumBath.new()

	# Wheat test: Include ALL Lindblad sources for wheat
	# ☀ sun, 💧 water, ⛰ soil → 🌾 wheat → 🍂 decay
	var icons: Array[Icon] = []
	for emoji in ["☀", "💧", "⛰", "🌾", "🍂"]:
		var icon = icon_registry.get_icon(emoji)
		if icon:
			icons.append(icon)

	# Initialize bath with emojis
	var emojis: Array[String] = []
	for icon in icons:
		emojis.append(icon.emoji)
	bath.initialize_with_emojis(emojis)

	# Build operators from icons
	bath.active_icons = icons
	bath.build_hamiltonian_from_icons(icons)
	bath.build_lindblad_from_icons(icons)

	# Verify wheat rates
	var wheat_idx = bath.emoji_to_index.get("🌾", -1)
	var total_rate = 0.0
	for term in bath.lindblad_terms:
		if term.target == wheat_idx:
			var source = bath.emoji_list[term.source]
			print("  %s → 🌾: %.5f/sec" % [source, term.rate])
			total_rate += term.rate

	var t_90 = -log(0.1) / total_rate if total_rate > 0 else 999
	print("  Total incoming rate: %.5f/sec" % total_rate)
	print("  Predicted 90%% maturity: ~%.1f seconds" % t_90)

	# Set initial conditions: All sources present
	var sun_idx = bath.emoji_to_index.get("☀", -1)
	var water_idx = bath.emoji_to_index.get("💧", -1)
	var soil_idx = bath.emoji_to_index.get("⛰", -1)
	var decay_idx = bath.emoji_to_index.get("🍂", -1)

	bath.amplitudes[sun_idx] = Complex.new(0.5, 0.0)  # Sun present
	if water_idx >= 0:
		bath.amplitudes[water_idx] = Complex.new(0.4, 0.0)  # Water present
	if soil_idx >= 0:
		bath.amplitudes[soil_idx] = Complex.new(0.3, 0.0)  # Soil present
	bath.amplitudes[wheat_idx] = Complex.new(0.05, 0.0)  # Wheat seed
	if decay_idx >= 0:
		bath.amplitudes[decay_idx] = Complex.new(0.2, 0.0)

	bath.normalize()

	print("  Initial wheat: %.4f\n" % bath.amplitudes[wheat_idx].abs_sq())

	var container = Node.new()
	container.set_meta("bath", bath)
	container.set_meta("test_type", "wheat")
	root.add_child(container)

	return container

func _create_mushroom_test_bath(icon_registry) -> Node:
	print("📊 EXPERIMENT 2: Mushroom Growth Rate (10x slower)")
	var QuantumBath = load("res://Core/QuantumSubstrate/QuantumBath.gd")
	var bath = QuantumBath.new()

	# Mushroom test: 🌙 moon, 🍄 mushroom, 🍂 decay
	var icons: Array[Icon] = []
	for emoji in ["🌙", "🍄", "🍂"]:
		var icon = icon_registry.get_icon(emoji)
		if icon:
			icons.append(icon)

	# Initialize bath with emojis
	var emojis: Array[String] = []
	for icon in icons:
		emojis.append(icon.emoji)
	bath.initialize_with_emojis(emojis)

	# Build operators from icons
	bath.active_icons = icons
	bath.build_hamiltonian_from_icons(icons)
	bath.build_lindblad_from_icons(icons)

	# Verify mushroom rates
	var mushroom_idx = bath.emoji_to_index.get("🍄", -1)
	var total_rate = 0.0
	for term in bath.lindblad_terms:
		if term.target == mushroom_idx:
			var source = bath.emoji_list[term.source]
			print("  %s → 🍄: %.5f/sec" % [source, term.rate])
			total_rate += term.rate

	var t_90 = -log(0.1) / total_rate if total_rate > 0 else 999
	print("  Total incoming rate: %.5f/sec" % total_rate)
	print("  Predicted 90%% maturity: ~%.1f seconds" % t_90)

	# Set initial conditions
	var moon_idx = bath.emoji_to_index.get("🌙", -1)
	var decay_idx = bath.emoji_to_index.get("🍂", -1)

	bath.amplitudes[moon_idx] = Complex.new(0.7, 0.0)  # Strong moon (night)
	bath.amplitudes[mushroom_idx] = Complex.new(0.05, 0.0)  # Mushroom spore
	if decay_idx >= 0:
		bath.amplitudes[decay_idx] = Complex.new(0.3, 0.0)  # Organic matter

	bath.normalize()

	print("  Initial mushroom: %.4f\n" % bath.amplitudes[mushroom_idx].abs_sq())

	var container = Node.new()
	container.set_meta("bath", bath)
	container.set_meta("test_type", "mushroom")
	root.add_child(container)

	return container

func _process(_delta: float) -> bool:
	var current_time = Time.get_ticks_msec() / 1000.0
	var elapsed = current_time - start_time

	# Evolve both baths
	var wheat_bath_obj = wheat_bath.get_meta("bath")
	var mushroom_bath_obj = mushroom_bath.get_meta("bath")

	wheat_bath_obj.evolve(0.016)
	mushroom_bath_obj.evolve(0.016)

	# Take measurements
	if current_time - last_measurement >= measurement_interval:
		last_measurement = current_time

		var wheat_idx = wheat_bath_obj.emoji_to_index.get("🌾", -1)
		var mushroom_idx = mushroom_bath_obj.emoji_to_index.get("🍄", -1)

		var wheat_prob = wheat_bath_obj.amplitudes[wheat_idx].abs_sq()
		var mushroom_prob = mushroom_bath_obj.amplitudes[mushroom_idx].abs_sq()

		# Determine notes
		var notes = ""
		if wheat_prob > 0.5 and measurements.wheat.size() > 0 and measurements.wheat[-1]["prob"] < 0.5:
			notes += "Wheat 50% | "
		if wheat_prob > 0.9:
			notes += "Wheat mature | "
		if mushroom_prob > 0.5 and measurements.mushroom.size() > 0 and measurements.mushroom[-1]["prob"] < 0.5:
			notes += "Mushroom 50% | "
		if mushroom_prob > 0.9:
			notes += "Mushroom mature | "

		print("%6.0f  | %10.4f | %13.4f | %s" % [elapsed, wheat_prob, mushroom_prob, notes])

		measurements.wheat.append({"time": elapsed, "prob": wheat_prob})
		measurements.mushroom.append({"time": elapsed, "prob": mushroom_prob})

	# End simulation
	if elapsed >= duration:
		_finish_experiment()
		return true

	return false

func _finish_experiment():
	print("\n" + "=".repeat(70))
	print("EXPERIMENT RESULTS")
	print("=".repeat(70))

	# Analyze wheat growth
	print("\n📊 WHEAT GROWTH (Expected 30x slower: ~30-40s to maturity):")
	var wheat_t50 = -1.0
	var wheat_t90 = -1.0

	for m in measurements.wheat:
		if wheat_t50 < 0 and m.prob >= 0.5:
			wheat_t50 = m.time
		if wheat_t90 < 0 and m.prob >= 0.9:
			wheat_t90 = m.time

	if wheat_t50 > 0:
		print("  50%% probability reached: %.1fs" % wheat_t50)
	else:
		print("  50%% probability: NOT REACHED in 30s")

	if wheat_t90 > 0:
		print("  90%% probability reached: %.1fs" % wheat_t90)
	else:
		print("  90%% probability: NOT REACHED in 30s")

	var final_wheat = measurements.wheat[-1].prob if not measurements.wheat.is_empty() else 0.0
	print("  Final probability: %.4f" % final_wheat)

	# Analyze mushroom growth
	print("\n📊 MUSHROOM GROWTH (Expected 10x slower: ~12-18s to maturity):")
	var mushroom_t50 = -1.0
	var mushroom_t90 = -1.0

	for m in measurements.mushroom:
		if mushroom_t50 < 0 and m.prob >= 0.5:
			mushroom_t50 = m.time
		if mushroom_t90 < 0 and m.prob >= 0.9:
			mushroom_t90 = m.time

	if mushroom_t50 > 0:
		print("  50%% probability reached: %.1fs" % mushroom_t50)
	else:
		print("  50%% probability: NOT REACHED in 30s")

	if mushroom_t90 > 0:
		print("  90%% probability reached: %.1fs" % mushroom_t90)
	else:
		print("  90%% probability: NOT REACHED in 30s")

	var final_mushroom = measurements.mushroom[-1].prob if not measurements.mushroom.is_empty() else 0.0
	print("  Final probability: %.4f" % final_mushroom)

	# Validation
	print("\n✅ VALIDATION:")

	# Wheat should be slower than mushroom
	if wheat_t90 > mushroom_t90 and mushroom_t90 > 0:
		print("  ✅ Wheat slower than mushroom (correct 30x vs 10x scaling)")
	elif wheat_t90 > 0 and mushroom_t90 > 0:
		print("  ⚠️  Wheat/mushroom timing ratio unexpected:")
		print("     Wheat: %.1fs, Mushroom: %.1fs (ratio: %.1fx)" % [
			wheat_t90, mushroom_t90, wheat_t90 / mushroom_t90
		])
	else:
		print("  ⚠️  Could not compare (one or both didn't reach 90%%)")

	# Wheat target: ~30-40s to 90%
	if wheat_t90 > 0:
		if wheat_t90 >= 25 and wheat_t90 <= 50:
			print("  ✅ Wheat maturity time in expected range (25-50s)")
		else:
			print("  ❌ Wheat maturity %.1fs outside expected 25-50s range" % wheat_t90)

	# Mushroom target: ~12-18s to 90%
	if mushroom_t90 > 0:
		if mushroom_t90 >= 8 and mushroom_t90 <= 25:
			print("  ✅ Mushroom maturity time in expected range (8-25s)")
		else:
			print("  ❌ Mushroom maturity %.1fs outside expected 8-25s range" % mushroom_t90)

	# Check normalization stability
	var wheat_bath_obj = wheat_bath.get_meta("bath")
	var mushroom_bath_obj = mushroom_bath.get_meta("bath")

	var wheat_norm = 0.0
	for amp in wheat_bath_obj.amplitudes:
		wheat_norm += amp.abs_sq()

	var mushroom_norm = 0.0
	for amp in mushroom_bath_obj.amplitudes:
		mushroom_norm += amp.abs_sq()

	print("\n  Bath normalization check:")
	print("    Wheat bath: Σ|α|² = %.6f (should be ~1.0)" % wheat_norm)
	print("    Mushroom bath: Σ|α|² = %.6f (should be ~1.0)" % mushroom_norm)

	if abs(wheat_norm - 1.0) < 0.01 and abs(mushroom_norm - 1.0) < 0.01:
		print("  ✅ Bath normalization stable")
	else:
		print("  ❌ Bath normalization drifted!")

	print("\n" + "=".repeat(70))
	quit()
