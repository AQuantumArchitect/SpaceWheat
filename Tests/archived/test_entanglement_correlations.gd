## TEST: Entanglement Measurement Correlations
## Tests Bell state correlations and emoji outcome coupling

extends Node

const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const EntangledPair = preload("res://Core/QuantumSubstrate/EntangledPair.gd")

var test_count: int = 0
var pass_count: int = 0

func _ready():
	print("\n" + "=".repeat(80))
	print("  TEST SUITE: Entanglement Measurement Correlations")
	print("=".repeat(80) + "\n")

	test_bell_phi_plus_creates_same_correlation()
	test_bell_psi_plus_creates_opposite_correlation()
	test_measurement_correlation_detection()
	test_both_measurement_correlated_outcomes()
	test_correlation_strength_calculation()
	test_emoji_correlation_gameplay()

	print("\n" + "=".repeat(80))
	print("  TEST RESULTS: %d/%d PASSED ✅" % [pass_count, test_count])
	print("=".repeat(80) + "\n")

	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0 if pass_count == test_count else 1)


## TEST 1: Bell |Φ+⟩ State Creates Same Correlation
func test_bell_phi_plus_creates_same_correlation():
	test_count += 1
	print("TEST %d: Bell |Φ+⟩ Creates Same Correlation" % test_count)
	print("─".repeat(40))

	var pair = EntangledPair.new()
	pair.qubit_a_id = "plot_A"
	pair.qubit_b_id = "plot_B"
	pair.north_emoji_a = "🌾"
	pair.south_emoji_a = "👥"
	pair.north_emoji_b = "🌾"
	pair.south_emoji_b = "👥"

	pair.create_bell_phi_plus()

	# Extract diagonal probabilities
	var p00 = pair.density_matrix[0][0].x  # Both north
	var p11 = pair.density_matrix[3][3].x  # Both south
	var p01 = pair.density_matrix[1][1].x  # A north, B south
	var p10 = pair.density_matrix[2][2].x  # A south, B north

	print("  |Φ+⟩ diagonal probabilities:")
	print("    P(00): %.3f (both 🌾)" % p00)
	print("    P(01): %.3f (A=🌾, B=👥)" % p01)
	print("    P(10): %.3f (A=👥, B=🌾)" % p10)
	print("    P(11): %.3f (both 👥)" % p11)

	var same_prob = p00 + p11
	var opposite_prob = p01 + p10

	print("  P(same emoji): %.3f" % same_prob)
	print("  P(opposite emoji): %.3f" % opposite_prob)

	assert(same_prob > 0.9, "Φ+ should have >90% same correlation")
	assert(opposite_prob < 0.1, "Φ+ should have <10% opposite correlation")

	print("✅ PASSED\n")
	pass_count += 1


## TEST 2: Bell |Ψ+⟩ State Creates Opposite Correlation
func test_bell_psi_plus_creates_opposite_correlation():
	test_count += 1
	print("TEST %d: Bell |Ψ+⟩ Creates Opposite Correlation" % test_count)
	print("─".repeat(40))

	var pair = EntangledPair.new()
	pair.qubit_a_id = "plot_A"
	pair.qubit_b_id = "plot_B"
	pair.north_emoji_a = "🌾"
	pair.south_emoji_a = "👥"
	pair.north_emoji_b = "🌾"
	pair.south_emoji_b = "👥"

	pair.create_bell_psi_plus()

	# Extract diagonal probabilities
	var p00 = pair.density_matrix[0][0].x
	var p01 = pair.density_matrix[1][1].x
	var p10 = pair.density_matrix[2][2].x
	var p11 = pair.density_matrix[3][3].x

	print("  |Ψ+⟩ diagonal probabilities:")
	print("    P(00): %.3f (both 🌾)" % p00)
	print("    P(01): %.3f (A=🌾, B=👥)" % p01)
	print("    P(10): %.3f (A=👥, B=🌾)" % p10)
	print("    P(11): %.3f (both 👥)" % p11)

	var same_prob = p00 + p11
	var opposite_prob = p01 + p10

	print("  P(same emoji): %.3f" % same_prob)
	print("  P(opposite emoji): %.3f" % opposite_prob)

	assert(opposite_prob > 0.9, "Ψ+ should have >90% opposite correlation")
	assert(same_prob < 0.1, "Ψ+ should have <10% same correlation")

	print("✅ PASSED\n")
	pass_count += 1


## TEST 3: Measurement Correlation Detection Method
func test_measurement_correlation_detection():
	test_count += 1
	print("TEST %d: Measurement Correlation Detection" % test_count)
	print("─".repeat(40))

	# Test |Φ+⟩ (same correlation)
	var pair_same = EntangledPair.new()
	pair_same.qubit_a_id = "A"
	pair_same.qubit_b_id = "B"
	pair_same.create_bell_phi_plus()

	var corr_same = pair_same.get_measurement_correlation()

	print("  |Φ+⟩ correlation type: %s" % corr_same["type"])
	print("    Strength: %.3f" % corr_same["strength"])
	print("    P(same): %.3f" % corr_same["prob_same"])
	print("    P(opposite): %.3f" % corr_same["prob_opposite"])

	assert(corr_same["type"] == "same", "Φ+ should detect as 'same' correlation")
	assert(corr_same["strength"] > 0.9, "Φ+ strength should be >0.9")

	# Test |Ψ+⟩ (opposite correlation)
	var pair_opposite = EntangledPair.new()
	pair_opposite.qubit_a_id = "A"
	pair_opposite.qubit_b_id = "B"
	pair_opposite.create_bell_psi_plus()

	var corr_opposite = pair_opposite.get_measurement_correlation()

	print("  |Ψ+⟩ correlation type: %s" % corr_opposite["type"])
	print("    Strength: %.3f" % corr_opposite["strength"])
	print("    P(same): %.3f" % corr_opposite["prob_same"])
	print("    P(opposite): %.3f" % corr_opposite["prob_opposite"])

	assert(corr_opposite["type"] == "opposite", "Ψ+ should detect as 'opposite' correlation")
	assert(corr_opposite["strength"] > 0.9, "Ψ+ strength should be >0.9")

	print("✅ PASSED\n")
	pass_count += 1


## TEST 4: Both Measurement Returns Correlated Outcomes
func test_both_measurement_correlated_outcomes():
	test_count += 1
	print("TEST %d: Both Measurement Returns Correlated Outcomes" % test_count)
	print("─".repeat(40))

	var same_outcomes = 0
	var opposite_outcomes = 0
	var total_trials = 100

	print("  Running %d measurement trials on |Φ+⟩..." % total_trials)

	for trial in range(total_trials):
		var pair = EntangledPair.new()
		pair.qubit_a_id = "A"
		pair.qubit_b_id = "B"
		pair.north_emoji_a = "🌾"
		pair.south_emoji_a = "👥"
		pair.north_emoji_b = "🌾"
		pair.south_emoji_b = "👥"

		pair.create_bell_phi_plus()
		var result = pair.measure_both()

		if result["a"] == result["b"]:
			same_outcomes += 1
		else:
			opposite_outcomes += 1

	var same_ratio = float(same_outcomes) / total_trials
	var opposite_ratio = float(opposite_outcomes) / total_trials

	print("  Results after %d trials:" % total_trials)
	print("    Same outcomes: %d (%.1f%%)" % [same_outcomes, same_ratio * 100])
	print("    Opposite outcomes: %d (%.1f%%)" % [opposite_outcomes, opposite_ratio * 100])

	assert(same_ratio > 0.8, "Φ+ should give >80% same outcomes in practice")

	print("✅ PASSED\n")
	pass_count += 1


## TEST 5: Correlation Strength Calculation
func test_correlation_strength_calculation():
	test_count += 1
	print("TEST %d: Correlation Strength Calculation" % test_count)
	print("─".repeat(40))

	# Create |Φ+⟩ state
	var pair = EntangledPair.new()
	pair.qubit_a_id = "A"
	pair.qubit_b_id = "B"
	pair.create_bell_phi_plus()

	var correlation = pair.get_measurement_correlation()

	print("  |Φ+⟩ Correlation strength: %.3f" % correlation["strength"])
	print("  Concurrence (Bell inequality): %.3f" % correlation["concurrence"])

	# For pure Bell state, concurrence should be ~1.0
	assert(correlation["concurrence"] > 0.9, "Pure Bell state concurrence should be ~1.0")

	# Strength should be either prob_same or prob_opposite
	var expected_strength = max(correlation["prob_same"], correlation["prob_opposite"])
	assert(abs(correlation["strength"] - expected_strength) < 0.01,
		"Strength should be max of same/opposite probabilities")

	print("✅ PASSED\n")
	pass_count += 1


## TEST 6: Emoji Correlation Gameplay Scenario
func test_emoji_correlation_gameplay():
	test_count += 1
	print("TEST %d: Emoji Correlation Gameplay Scenario" % test_count)
	print("─".repeat(40))

	print("  Scenario 1: Two wheat plots entangled with |Φ+⟩ (same correlation)")
	print("  ─".repeat(40))

	var pair_same = EntangledPair.new()
	pair_same.qubit_a_id = "wheat_1"
	pair_same.qubit_b_id = "wheat_2"
	pair_same.north_emoji_a = "🌾"  # Wheat
	pair_same.south_emoji_a = "👥"  # Labor
	pair_same.north_emoji_b = "🌾"
	pair_same.south_emoji_b = "👥"
	pair_same.create_bell_phi_plus()

	var corr1 = pair_same.get_measurement_correlation()

	print("    Wheat plot 1 ↔ Wheat plot 2: |Φ+⟩")
	print("    Harvest together?")
	print("      → Both get 🌾 or both get 👥 (%.0f%% likely)" % [corr1["prob_same"] * 100])
	print("      Gameplay: Synchronized harvest, coordinated resources")

	assert(corr1["type"] == "same", "Same emoji plots should use same correlation")

	print("\n  Scenario 2: Wheat & Tomato entangled with |Ψ+⟩ (opposite correlation)")
	print("  ─".repeat(40))

	var pair_opp = EntangledPair.new()
	pair_opp.qubit_a_id = "wheat_field"
	pair_opp.qubit_b_id = "tomato_field"
	pair_opp.north_emoji_a = "🌾"  # Wheat
	pair_opp.south_emoji_a = "👥"  # Labor
	pair_opp.north_emoji_b = "🍅"  # Tomato
	pair_opp.south_emoji_b = "🍝"  # Sauce
	pair_opp.create_bell_psi_plus()

	var corr2 = pair_opp.get_measurement_correlation()

	print("    Wheat field ↔ Tomato field: |Ψ+⟩")
	print("    Harvest together?")
	print("      → Wheat gets 🌾 & Tomato gets 🍝 OR vice versa (%.0f%% likely)" % [corr2["prob_opposite"] * 100])
	print("      Gameplay: Complementary resources, trade-offs")

	assert(corr2["type"] == "opposite", "Opposite emoji plots should use opposite correlation")

	print("\n✅ PASSED\n")
	pass_count += 1
