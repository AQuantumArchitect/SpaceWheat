extends SceneTree

## Test Actual Measurement Functions
## Use the real measure_qubit_a() and measure_qubit_b() methods

const EntangledPair = preload("res://Core/QuantumSubstrate/EntangledPair.gd")

func _initialize():
	print("\n" + "=".repeat(80))
	print("  TEST ACTUAL MEASUREMENT FUNCTIONS")
	print("=".repeat(80) + "\n")

	print("Running 10 trials of |Ψ+⟩ measurement:")
	print("Expected: ANTI-correlation (opposite outcomes)")
	print()

	var same_count = 0
	var opposite_count = 0

	for trial in range(10):
		var pair = EntangledPair.new()
		pair.qubit_a_id = "A"
		pair.qubit_b_id = "B"
		pair.north_emoji_a = "NORTH_A"
		pair.south_emoji_a = "SOUTH_A"
		pair.north_emoji_b = "NORTH_B"
		pair.south_emoji_b = "SOUTH_B"

		pair.create_bell_psi_plus()

		print("Trial %d:" % (trial + 1))
		print("  State before: |Ψ+⟩ = (|01⟩ + |10⟩)/√2")

		var result_a = pair.measure_qubit_a()
		var result_b = pair.measure_qubit_b()

		print("  A measured: %s" % result_a)
		print("  B measured: %s" % result_b)

		# Compare actual quantum values, not emoji strings
		var a_is_north = (result_a == pair.north_emoji_a)
		var b_is_north = (result_b == pair.north_emoji_b)

		print("  A is north: %s, B is north: %s" % [a_is_north, b_is_north])

		if a_is_north == b_is_north:
			same_count += 1
			print("  → SAME quantum value (should be opposite!) ❌")
		else:
			opposite_count += 1
			print("  → OPPOSITE quantum values ✅")

		print()

	print("Results:")
	print("  Same: %d/10" % same_count)
	print("  Opposite: %d/10" % opposite_count)

	if opposite_count >= 8:
		print("\n✅ Anti-correlation working!")
	else:
		print("\n❌ BUG: Should have mostly opposite outcomes")
		print("⚠️ The measurement functions have a bug!")

	quit()
