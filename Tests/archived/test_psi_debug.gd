extends SceneTree

## Debug |Ψ+⟩ Measurement
## Manual trace-through of the measurement process

const EntangledPair = preload("res://Core/QuantumSubstrate/EntangledPair.gd")

func _initialize():
	print("\n" + "=".repeat(80))
	print("  DEBUG |Ψ+⟩ MEASUREMENT")
	print("=".repeat(80) + "\n")

	var pair = EntangledPair.new()
	pair.qubit_a_id = "A"
	pair.qubit_b_id = "B"
	pair.north_emoji_a = "NORTH_A"
	pair.south_emoji_a = "SOUTH_A"
	pair.north_emoji_b = "NORTH_B"
	pair.south_emoji_b = "SOUTH_B"

	pair.create_bell_psi_plus()

	print("Initial state: |Ψ+⟩ = (|01⟩ + |10⟩)/√2")
	print("\nDensity matrix:")
	print_density_matrix(pair.density_matrix)

	print("\n--- Measure Qubit A ---")
	var rho_a = pair._partial_trace_b()
	print("Reduced density matrix ρ_A:")
	print("  ρ_A[0][0] = %.6f (P(A=north))" % rho_a[0][0].x)
	print("  ρ_A[1][1] = %.6f (P(A=south))" % rho_a[1][1].x)

	# Manually force a specific outcome to test
	print("\nForcing measurement outcome: A = NORTH (0)")

	# Manually collapse
	var result_a = 0  # Force north
	var new_rho = []
	for i in range(4):
		var row = []
		for j in range(4):
			row.append(Vector2(0, 0))
		new_rho.append(row)

	var offset = result_a * 2
	for i in range(2):
		for j in range(2):
			new_rho[offset + i][offset + j] = pair.density_matrix[offset + i][offset + j]

	print("\nAfter extracting block [%d:%d, %d:%d]:" % [offset, offset+2, offset, offset+2])
	print_density_matrix(new_rho)

	# Normalize
	var trace = Vector2(0, 0)
	for i in range(4):
		trace += new_rho[i][i]
	print("\nTrace before normalization: %.6f" % trace.x)

	if trace.x > 0.0001:
		for i in range(4):
			for j in range(4):
				new_rho[i][j] /= trace.x

	print("\nAfter normalization:")
	print_density_matrix(new_rho)

	# Update pair's density matrix
	pair.density_matrix = new_rho

	print("\n--- Now Measure Qubit B ---")
	var rho_b = pair._partial_trace_b()  # FIX: _partial_trace_b() returns ρ_B
	print("Reduced density matrix ρ_B:")
	print("  ρ_B[0][0] = %.6f (P(B=north))" % rho_b[0][0].x)
	print("  ρ_B[1][1] = %.6f (P(B=south))" % rho_b[1][1].x)

	var prob_north_b = rho_b[0][0].x
	print("\nExpected: B should measure SOUTH (1) with 100%% probability")
	print("Actual:   P(B=north) = %.2f%%" % (prob_north_b * 100.0))
	print("          P(B=south) = %.2f%%" % ((1.0 - prob_north_b) * 100.0))

	if prob_north_b < 0.01:
		print("\n✅ CORRECT: B will measure south (anti-correlated with A=north)")
	else:
		print("\n❌ BUG: B should have ~0%% probability of north, got %.2f%%" % (prob_north_b * 100.0))

	quit()


func print_density_matrix(rho: Array):
	"""Print 4x4 density matrix in readable format"""
	var labels = ["|00⟩", "|01⟩", "|10⟩", "|11⟩"]
	print("       %s    %s    %s    %s" % labels)
	for i in range(4):
		var row_str = "%s " % labels[i]
		for j in range(4):
			row_str += " %.3f " % rho[i][j].x
		print(row_str)
