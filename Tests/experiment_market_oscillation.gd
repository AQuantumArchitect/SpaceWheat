extends SceneTree

## Experiment 3: Market Oscillation Validation
## Tests Bull/Bear market dynamics and trading cycle periodicity
##
## Theoretical model:
##   Lindblad rates: 💰→🐂: 0.008/sec (money buys bulls)
##                   📦→💰: 0.005/sec (goods sold for money)
##   Hamiltonian couplings: 🐂↔🐻 create oscillation
##   Expected behavior: ~60-second trading cycles (vs old 6-second chaos)

var biome: Node
var start_time: float = 0.0
var measurement_interval: float = 1.0  # Sample every second
var last_measurement: float = 0.0
var duration: float = 180.0  # 3 minutes to see multiple cycles
var measurements: Array = []

func _init():
	print("\n╔════════════════════════════════════════════════════════╗")
	print("║   EXPERIMENT 3: MARKET OSCILLATION VALIDATION          ║")
	print("╚════════════════════════════════════════════════════════╝\n")

	# Initialize IconRegistry
	var IconRegistryScript = load("res://Core/QuantumSubstrate/IconRegistry.gd")
	var icon_registry = IconRegistryScript.new()
	icon_registry.name = "IconRegistry"
	root.add_child(icon_registry)
	icon_registry._ready()

	# Initialize MarketBiome
	var MarketBiome = load("res://Core/Environment/MarketBiome.gd")
	biome = MarketBiome.new()
	biome.name = "MarketBiome"
	root.add_child(biome)
	biome._ready()

	if not biome.bath:
		push_error("❌ Bath not initialized!")
		quit()
		return

	print("✅ Bath initialized")
	print("  Emojis: %s" % [", ".join(biome.bath.emoji_list)])

	# Verify market Lindblad rates
	print("\n📊 Market Lindblad rates in bath:")
	var bull_idx = biome.bath.emoji_to_index.get("🐂", -1)
	var bear_idx = biome.bath.emoji_to_index.get("🐻", -1)
	var money_idx = biome.bath.emoji_to_index.get("💰", -1)
	var goods_idx = biome.bath.emoji_to_index.get("📦", -1)

	for term in biome.bath.lindblad_terms:
		var source = biome.bath.emoji_list[term.source]
		var target = biome.bath.emoji_list[term.target]
		if source in ["💰", "📦", "🐂", "🐻"] or target in ["💰", "📦", "🐂", "🐻"]:
			print("  %s → %s: %.5f/sec" % [source, target, term.rate])

	# Check Hamiltonian couplings
	print("\n🔄 Market Hamiltonian couplings:")
	for term in biome.bath.hamiltonian_sparse:
		var emoji1 = biome.bath.emoji_list[term.i]
		var emoji2 = biome.bath.emoji_list[term.j]
		if emoji1 in ["🐂", "🐻"] or emoji2 in ["🐂", "🐻"]:
			print("  %s ↔ %s: %.4f" % [emoji1, emoji2, term.coupling])

	print("\n📈 Theoretical predictions:")
	print("  Trading cycle period: ~60 seconds (10x slower than old model)")
	print("  Expected: Predictable Bull/Bear oscillations")
	print("  Expected: Strategic trading windows")

	# Set initial conditions: Balanced market
	print("\n💼 Setting initial conditions...")
	biome.bath.amplitudes[bull_idx] = Complex.new(0.4, 0.0)
	biome.bath.amplitudes[bear_idx] = Complex.new(0.3, 0.0)
	biome.bath.amplitudes[money_idx] = Complex.new(0.5, 0.0)
	biome.bath.amplitudes[goods_idx] = Complex.new(0.4, 0.0)

	var temple_idx = biome.bath.emoji_to_index.get("🏛️", -1)
	var chaotic_idx = biome.bath.emoji_to_index.get("🏚️", -1)
	if temple_idx >= 0:
		biome.bath.amplitudes[temple_idx] = Complex.new(0.3, 0.0)
	if chaotic_idx >= 0:
		biome.bath.amplitudes[chaotic_idx] = Complex.new(0.2, 0.0)

	biome.bath.normalize()

	print("  Initial state:")
	print("    🐂 Bull: %.4f" % biome.bath.amplitudes[bull_idx].norm_squared())
	print("    🐻 Bear: %.4f" % biome.bath.amplitudes[bear_idx].norm_squared())
	print("    💰 Money: %.4f" % biome.bath.amplitudes[money_idx].norm_squared())
	print("    📦 Goods: %.4f" % biome.bath.amplitudes[goods_idx].norm_squared())

	print("\n⏱️  Starting simulation (180 seconds - ~3 trading cycles)...")
	print("Time(s) | 🐂 Bull | 🐻 Bear | 💰 Money | 📦 Goods | Market Sentiment")
	print("--------|---------|---------|----------|----------|------------------")

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

		var bull_idx = biome.bath.emoji_to_index.get("🐂", -1)
		var bear_idx = biome.bath.emoji_to_index.get("🐻", -1)
		var money_idx = biome.bath.emoji_to_index.get("💰", -1)
		var goods_idx = biome.bath.emoji_to_index.get("📦", -1)

		var bull_prob = biome.bath.amplitudes[bull_idx].norm_squared()
		var bear_prob = biome.bath.amplitudes[bear_idx].norm_squared()
		var money_prob = biome.bath.amplitudes[money_idx].norm_squared()
		var goods_prob = biome.bath.amplitudes[goods_idx].norm_squared()

		# Market sentiment: Bull vs Bear
		var sentiment = "BULL" if bull_prob > bear_prob else "BEAR"
		var strength = abs(bull_prob - bear_prob) / max(bull_prob, bear_prob)
		var sentiment_str = "%s (%.0f%%)" % [sentiment, strength * 100]

		print("%6.0f  | %7.4f | %7.4f | %8.4f | %8.4f | %s" % [
			elapsed, bull_prob, bear_prob, money_prob, goods_prob, sentiment_str
		])

		measurements.append({
			"time": elapsed,
			"bull": bull_prob,
			"bear": bear_prob,
			"money": money_prob,
			"goods": goods_prob
		})

	# End simulation
	if elapsed >= duration:
		_finish_experiment()
		return true

	return false

func _finish_experiment():
	print("\n" + "=".repeat(80))
	print("EXPERIMENT RESULTS")
	print("=".repeat(80))

	if measurements.is_empty():
		push_error("❌ No measurements recorded!")
		quit()
		return

	# Detect oscillation cycles
	print("\n📊 Oscillation Analysis:")

	var bull_peaks: Array = []
	var bear_peaks: Array = []

	# Find local maxima for bull and bear
	for i in range(1, measurements.size() - 1):
		var prev = measurements[i - 1]
		var curr = measurements[i]
		var next = measurements[i + 1]

		# Bull peak
		if curr.bull > prev.bull and curr.bull > next.bull and curr.bull > 0.3:
			bull_peaks.append(curr.time)

		# Bear peak
		if curr.bear > prev.bear and curr.bear > next.bear and curr.bear > 0.3:
			bear_peaks.append(curr.time)

	print("  Bull market peaks detected: %d" % bull_peaks.size())
	for t in bull_peaks:
		print("    - t = %.1fs" % t)

	print("  Bear market peaks detected: %d" % bear_peaks.size())
	for t in bear_peaks:
		print("    - t = %.1fs" % t)

	# Calculate average cycle period
	var bull_periods: Array = []
	for i in range(1, bull_peaks.size()):
		bull_periods.append(bull_peaks[i] - bull_peaks[i - 1])

	var bear_periods: Array = []
	for i in range(1, bear_peaks.size()):
		bear_periods.append(bear_peaks[i] - bear_peaks[i - 1])

	if not bull_periods.is_empty():
		var avg_bull_period = 0.0
		for p in bull_periods:
			avg_bull_period += p
		avg_bull_period /= bull_periods.size()
		print("\n  Average bull cycle period: %.1f seconds" % avg_bull_period)

	if not bear_periods.is_empty():
		var avg_bear_period = 0.0
		for p in bear_periods:
			avg_bear_period += p
		avg_bear_period /= bear_periods.size()
		print("  Average bear cycle period: %.1f seconds" % avg_bear_period)

	# Calculate volatility
	var bull_variance = 0.0
	var bull_mean = 0.0
	for m in measurements:
		bull_mean += m.bull
	bull_mean /= measurements.size()

	for m in measurements:
		bull_variance += (m.bull - bull_mean) ** 2
	bull_variance /= measurements.size()
	var bull_volatility = sqrt(bull_variance)

	print("\n  Bull market volatility: %.4f (std dev)" % bull_volatility)

	# Validation
	print("\n✅ VALIDATION:")

	if bull_peaks.size() >= 2:
		print("  ✅ Multiple bull market cycles detected")
	else:
		print("  ⚠️  Fewer than 2 bull cycles (may need longer simulation)")

	if not bull_periods.is_empty():
		var avg_period = 0.0
		for p in bull_periods:
			avg_period += p
		avg_period /= bull_periods.size()

		if avg_period >= 50 and avg_period <= 70:
			print("  ✅ Cycle period ~60 seconds (as predicted)")
		elif avg_period >= 30 and avg_period <= 90:
			print("  ⚠️  Cycle period %.1fs (close to 60s prediction)" % avg_period)
		else:
			print("  ❌ Cycle period %.1fs (expected ~60s)" % avg_period)

	if bull_volatility > 0.05:
		print("  ✅ Significant market oscillations detected")
	else:
		print("  ⚠️  Low volatility - market may be too stable")

	# Check for chaotic behavior (old model had ~6s cycles)
	if not bull_periods.is_empty():
		var min_period = bull_periods[0]
		for p in bull_periods:
			if p < min_period:
				min_period = p

		if min_period < 10:
			print("  ❌ Detected very fast cycles (%.1fs) - chaotic behavior!" % min_period)
		else:
			print("  ✅ No chaotic fast cycles detected (minimum: %.1fs)" % min_period)

	print("\n" + "=".repeat(80))
	quit()
