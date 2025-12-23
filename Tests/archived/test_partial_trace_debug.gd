extends SceneTree

## Debug Partial Trace Calculation
## Check if the partial trace formula is correct

func _initialize():
	print("\n" + "=".repeat(80))
	print("  DEBUG PARTIAL TRACE")
	print("=".repeat(80) + "\n")

	# Create |01⟩⟨01| state (A=0, B=1)
	var density_matrix = []
	for i in range(4):
		var row = []
		for j in range(4):
			row.append(Vector2(0, 0))
		density_matrix.append(row)

	density_matrix[1][1] = Vector2(1.0, 0.0)

	print("State: |01⟩⟨01| (A=north, B=south)")
	print("\nBasis ordering: |00⟩, |01⟩, |10⟩, |11⟩")
	print("First digit = A, Second digit = B")
	print("\nDensity matrix:")
	print_matrix(density_matrix)

	print("\n--- Partial Trace over A (keep B) ---")
	print("Formula: ρ_B[i][j] = Σ_k ρ[k*2+i][k*2+j]")
	print()

	var rho_b = [
		[Vector2(0, 0), Vector2(0, 0)],
		[Vector2(0, 0), Vector2(0, 0)]
	]

	for i in range(2):
		for j in range(2):
			print("Computing ρ_B[%d][%d]:" % [i, j])
			for k in range(2):
				var idx_from = k*2 + i
				var idx_to = k*2 + j
				var val = density_matrix[idx_from][idx_to].x
				print("  k=%d: ρ[%d][%d] = %.3f" % [k, idx_from, idx_to, val])
				rho_b[i][j] += density_matrix[idx_from][idx_to]
			print("  → ρ_B[%d][%d] = %.3f\n" % [i, j, rho_b[i][j].x])

	print("Result:")
	print("  ρ_B[0][0] = %.3f (P(B=0) = north)" % rho_b[0][0].x)
	print("  ρ_B[1][1] = %.3f (P(B=1) = south)" % rho_b[1][1].x)

	print("\nExpected: ρ_B = [[0,0],[0,1]] (B definitely = south)")
	print("Actual:   ρ_B = [[%.3f,%.3f],[%.3f,%.3f]]" % [
		rho_b[0][0].x, rho_b[0][1].x,
		rho_b[1][0].x, rho_b[1][1].x
	])

	if abs(rho_b[0][0].x - 0.0) < 0.01 and abs(rho_b[1][1].x - 1.0) < 0.01:
		print("\n✅ CORRECT")
	else:
		print("\n❌ WRONG - Partial trace formula has a bug!")

	print("\n--- Let's verify by manual calculation ---")
	print("|01⟩ = |A=0⟩ ⊗ |B=1⟩")
	print("Tracing out A means summing over A=0 and A=1:")
	print("  ρ_B[0][0] = ⟨00|ρ|00⟩ + ⟨10|ρ|10⟩")
	print("            = ρ[0][0] + ρ[2][2]")
	print("            = %.3f + %.3f = %.3f ✅" % [
		density_matrix[0][0].x,
		density_matrix[2][2].x,
		density_matrix[0][0].x + density_matrix[2][2].x
	])
	print()
	print("  ρ_B[1][1] = ⟨01|ρ|01⟩ + ⟨11|ρ|11⟩")
	print("            = ρ[1][1] + ρ[3][3]")
	print("            = %.3f + %.3f = %.3f ✅" % [
		density_matrix[1][1].x,
		density_matrix[3][3].x,
		density_matrix[1][1].x + density_matrix[3][3].x
	])

	print("\nSo the MATHEMATICAL formula is correct.")
	print("But the CODE implementation must be wrong!")

	quit()


func print_matrix(rho: Array):
	var labels = ["|00⟩", "|01⟩", "|10⟩", "|11⟩"]
	print("       %s    %s    %s    %s" % labels)
	for i in range(4):
		var row_str = "%s " % labels[i]
		for j in range(4):
			row_str += " %.3f " % rho[i][j].x
		print(row_str)
