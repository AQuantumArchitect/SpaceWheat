## SIMPLE TEST: Entanglement Measurement Correlations
## Minimal test for Bell state emoji outcomes

extends Node

const EntangledPair = preload("res://Core/QuantumSubstrate/EntangledPair.gd")

func _ready():
	print("\n" + "=".repeat(60))
	print("QUICK TEST: Entanglement Measurement Correlations")
	print("=".repeat(60) + "\n")

	var passes = 0
	var total = 0

	# TEST 1: Bell |Φ+⟩ creates same correlation
	total += 1
	var pair1 = EntangledPair.new()
	pair1.qubit_a_id = "A"
	pair1.qubit_b_id = "B"
	pair1.create_bell_phi_plus()
	var corr1 = pair1.get_measurement_correlation()

	if corr1["type"] == "same" and corr1["strength"] > 0.9:
		print("✅ TEST 1: |Φ+⟩ creates same correlation (%.0f%%)" % [corr1["prob_same"] * 100])
		passes += 1
	else:
		print("❌ TEST 1: FAILED - type=%s, strength=%.2f" % [corr1["type"], corr1["strength"]])

	# TEST 2: Bell |Ψ+⟩ creates opposite correlation
	total += 1
	var pair2 = EntangledPair.new()
	pair2.qubit_a_id = "A"
	pair2.qubit_b_id = "B"
	pair2.create_bell_psi_plus()
	var corr2 = pair2.get_measurement_correlation()

	if corr2["type"] == "opposite" and corr2["strength"] > 0.9:
		print("✅ TEST 2: |Ψ+⟩ creates opposite correlation (%.0f%%)" % [corr2["prob_opposite"] * 100])
		passes += 1
	else:
		print("❌ TEST 2: FAILED - type=%s, strength=%.2f" % [corr2["type"], corr2["strength"]])

	# TEST 3: Measurement returns correlated outcomes
	total += 1
	var same_count = 0
	for i in range(10):
		var p = EntangledPair.new()
		p.qubit_a_id = "A"
		p.qubit_b_id = "B"
		p.north_emoji_a = "🌾"
		p.south_emoji_a = "👥"
		p.north_emoji_b = "🌾"
		p.south_emoji_b = "👥"
		p.create_bell_phi_plus()
		var result = p.measure_both()
		if result["a"] == result["b"]:
			same_count += 1

	if same_count > 7:  # At least 70% same
		print("✅ TEST 3: Phi+ measurement gives same outcomes (7/10 trials)")
		passes += 1
	else:
		print("❌ TEST 3: FAILED - only %d/10 same outcomes" % same_count)

	# TEST 4: Concurrence measures entanglement
	total += 1
	var pair4 = EntangledPair.new()
	pair4.create_bell_phi_plus()
	var conc = pair4.get_concurrence()
	if conc > 0.9:
		print("✅ TEST 4: Bell state has high concurrence (%.2f)" % conc)
		passes += 1
	else:
		print("❌ TEST 4: FAILED - concurrence too low: %.2f" % conc)

	print("\n" + "=".repeat(60))
	print("RESULTS: %d/%d PASSED" % [passes, total])
	print("=".repeat(60) + "\n")

	await get_tree().create_timer(0.1).timeout
	get_tree().quit(0 if passes == total else 1)
