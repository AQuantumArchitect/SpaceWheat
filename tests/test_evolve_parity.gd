extends "res://tests/smoke_test_base.gd"

## QuantumEvolutionEngine: evolve_step() vs evolve() parity + packed-array size guards.
##
## Two things are asserted here, both on the native hot path:
##
## 1. PARITY — evolve_step(ρ, dt) and evolve(ρ, dt, dt) must be the same physics.
##    They were independently hand-written (duplicated precondition check, duplicated
##    exact-unitary fast path, duplicated coherent+Lindblad RHS) and had diverged:
##    evolve() carries an adaptive-substep loop that bounds Tr(ρ²) ≤ 1, evolve_step()
##    did a single unguarded Euler kick. Same generator, two integrators.
##
## 2. SIZE GUARDS — unpack_dense() is the single authority for the packed↔dense
##    convention. A mis-sized ρ must never be read past its end (heap overread);
##    it must fail loud and return a zero matrix instead.
##
## Run: godot --headless --path . --script tests/test_evolve_parity.gd


const DIVIDER = "============================================================"
const TOL_EXACT := 1e-12
const TOL_LOOSE := 1e-9


func _init():
	print("\n" + DIVIDER)
	print("QUANTUM EVOLUTION ENGINE — evolve_step / evolve PARITY")
	print(DIVIDER)

	await self.process_frame

	test_unitary_path_parity()
	test_dissipative_small_dt_parity()
	test_dissipative_large_dt_purity_bound()
	test_pure_lindblad_parity()
	test_undersized_rho_rejected()
	test_oversized_rho_rejected()
	test_undersized_hamiltonian_rejected()

	_finish("RESULTS")


## ---------------------------------------------------------------- helpers


## Dense packed identity-scaled / arbitrary matrix helpers. Packed layout is
## row-major [re00, im00, re01, im01, ...] — 2·dim² doubles.
func _packed_zero(dim: int) -> PackedFloat64Array:
	var p := PackedFloat64Array()
	p.resize(dim * dim * 2)
	p.fill(0.0)
	return p


## A genuine mixed 2-qubit state with coherences: ρ = |ψ⟩⟨ψ| blended with I/4.
func _make_rho(dim: int, mix: float) -> PackedFloat64Array:
	# |ψ⟩ ∝ (1, 0.6+0.3i, -0.2, 0.45i) normalized
	var psi_re: Array[float] = [1.0, 0.6, -0.2, 0.0]
	var psi_im: Array[float] = [0.0, 0.3, 0.0, 0.45]
	var norm := 0.0
	for k in dim:
		norm += psi_re[k] * psi_re[k] + psi_im[k] * psi_im[k]
	norm = sqrt(norm)
	for k in dim:
		psi_re[k] /= norm
		psi_im[k] /= norm

	var p := _packed_zero(dim)
	for i in dim:
		for j in dim:
			# ψ_i · conj(ψ_j)
			var re := psi_re[i] * psi_re[j] + psi_im[i] * psi_im[j]
			var im := psi_im[i] * psi_re[j] - psi_re[i] * psi_im[j]
			var idx := (i * dim + j) * 2
			p[idx] = (1.0 - mix) * re + (mix / float(dim) if i == j else 0.0)
			p[idx + 1] = (1.0 - mix) * im
	return p


## Hermitian 4×4 Hamiltonian: two self-energies + an XX-ish coupling with a
## complex off-diagonal (so the imaginary part is load-bearing).
func _make_hamiltonian(dim: int) -> PackedFloat64Array:
	var h := _packed_zero(dim)
	var diag := [0.0, 0.7, 1.1, 1.9]
	for i in dim:
		h[(i * dim + i) * 2] = diag[i]
	# H[1][2] = 0.35 + 0.22i, H[2][1] = conj
	h[(1 * dim + 2) * 2] = 0.35
	h[(1 * dim + 2) * 2 + 1] = 0.22
	h[(2 * dim + 1) * 2] = 0.35
	h[(2 * dim + 1) * 2 + 1] = -0.22
	# H[0][3] = 0.15
	h[(0 * dim + 3) * 2] = 0.15
	h[(3 * dim + 0) * 2] = 0.15
	return h


## Lindblad triplet stream: [row, col, re, im, ...]. A lowering operator on
## qubit 0 of a 2-qubit register (|1x⟩ → |0x⟩), rate folded into the amplitude.
func _make_lindblad(rate: float) -> PackedFloat64Array:
	var g := sqrt(rate)
	var t := PackedFloat64Array()
	# |00⟩⟨10| : (0,2) ; |01⟩⟨11| : (1,3)
	t.append_array([0.0, 2.0, g, 0.0])
	t.append_array([1.0, 3.0, g, 0.0])
	return t


func _engine(dim: int, with_h: bool, lindblad_rate: float, coherent: bool) -> QuantumEvolutionEngine:
	var e := QuantumEvolutionEngine.new()
	e.set_dimension(dim)
	if with_h:
		e.set_hamiltonian(_make_hamiltonian(dim))
	if lindblad_rate > 0.0:
		e.add_lindblad_triplets(_make_lindblad(lindblad_rate))
	e.set_coherent(coherent)
	e.finalize()
	return e


func _max_abs_diff(a: PackedFloat64Array, b: PackedFloat64Array) -> float:
	if a.size() != b.size():
		return INF
	var m := 0.0
	for i in a.size():
		m = max(m, abs(a[i] - b[i]))
	return m


func _trace(p: PackedFloat64Array, dim: int) -> float:
	var t := 0.0
	for i in dim:
		t += p[(i * dim + i) * 2]
	return t


func _purity(p: PackedFloat64Array, dim: int) -> float:
	# Tr(ρ²) = Σ_ij |ρ_ij|² for Hermitian ρ
	var s := 0.0
	for i in p.size() / 2:
		s += p[i * 2] * p[i * 2] + p[i * 2 + 1] * p[i * 2 + 1]
	return s


## ---------------------------------------------------------------- tests

func test_unitary_path_parity():
	# Coherent, no dissipation → both functions take the EXACT unitary fast path
	# (ρ → UρU†, U = exp(-iH·dt)). Exact for any dt, so they must agree bit-close
	# regardless of how the surrounding integrator is written.
	print("\n[Exact-unitary path: evolve_step ≡ evolve]")
	var dim := 4
	var e := _engine(dim, true, 0.0, true)
	var rho := _make_rho(dim, 0.0)

	for dt in [0.001, 0.02, 0.5, 5.0]:
		var a: PackedFloat64Array = e.evolve_step(rho, dt)
		var b: PackedFloat64Array = e.evolve(rho, dt, dt)
		var d := _max_abs_diff(a, b)
		_check(d < TOL_EXACT, "dt=%s agree (max|Δ|=%s)" % [dt, d], "diff=%s" % d)
		# and purity is preserved exactly on this path
		_check(abs(_purity(a, dim) - 1.0) < TOL_LOOSE, "dt=%s purity preserved" % dt, "purity=%s" % _purity(a, dim))


func test_dissipative_small_dt_parity():
	# With dissipators the exact-unitary path is off; both go through the
	# Euler generator. At a dt small enough that the purity quadratic never
	# demands a substep, the adaptive loop takes exactly one step of size dt —
	# so the two must agree to integration precision.
	print("\n[Dissipative, small dt: single-step regime]")
	var dim := 4
	var e := _engine(dim, true, 0.08, true)
	var rho := _make_rho(dim, 0.35)  # well inside the Bloch ball

	for dt in [1e-4, 1e-3, 5e-3]:
		var a: PackedFloat64Array = e.evolve_step(rho, dt)
		var b: PackedFloat64Array = e.evolve(rho, dt, dt)
		var d := _max_abs_diff(a, b)
		_check(d < TOL_LOOSE, "dt=%s agree (max|Δ|=%s)" % [dt, d], "diff=%s" % d)


func test_dissipative_large_dt_purity_bound():
	# The knot: a big dt. A single unguarded Euler kick can throw ρ past the
	# purity boundary (Tr(ρ²) > 1) — a non-physical state that the native engine
	# then chokes on downstream. Whatever evolve_step does, it must land on a
	# legal density matrix: trace 1, purity ≤ 1.
	print("\n[Dissipative, large dt: must stay a legal state]")
	var dim := 4
	var e := _engine(dim, true, 0.9, true)
	var rho := _make_rho(dim, 0.05)  # nearly pure — the dangerous corner

	for dt in [0.05, 0.25, 1.0]:
		var a: PackedFloat64Array = e.evolve_step(rho, dt)
		var b: PackedFloat64Array = e.evolve(rho, dt, dt)
		var pa := _purity(a, dim)
		var pb := _purity(b, dim)
		_check(abs(_trace(a, dim) - 1.0) < 1e-6, "dt=%s evolve_step trace≈1" % dt, "trace=%s" % _trace(a, dim))
		_check(pa <= 1.0 + 1e-9, "dt=%s evolve_step purity ≤ 1" % dt, "purity=%s" % pa)
		_check(pb <= 1.0 + 1e-9, "dt=%s evolve purity ≤ 1" % dt, "purity=%s" % pb)
		var d := _max_abs_diff(a, b)
		_check(d < TOL_LOOSE, "dt=%s agree (max|Δ|=%s)" % [dt, d], "diff=%s" % d)


func test_pure_lindblad_parity():
	# coherent OFF → pure Lindbladian, no exact-unitary path, no -i[H,ρ] term.
	# Exercises the third combination of the generator switches.
	print("\n[Pure Lindbladian (coherent off)]")
	var dim := 4
	var e := _engine(dim, true, 0.4, false)
	var rho := _make_rho(dim, 0.2)

	for dt in [1e-3, 0.1]:
		var a: PackedFloat64Array = e.evolve_step(rho, dt)
		var b: PackedFloat64Array = e.evolve(rho, dt, dt)
		var d := _max_abs_diff(a, b)
		_check(d < TOL_LOOSE, "dt=%s agree (max|Δ|=%s)" % [dt, d], "diff=%s" % d)
		_check(abs(_trace(a, dim) - 1.0) < 1e-6, "dt=%s trace≈1" % dt, "trace=%s" % _trace(a, dim))


func test_undersized_rho_rejected():
	# A ρ shorter than 2·dim² would make unpack_dense walk off the end of the
	# buffer. Every packed-array entry point must refuse it, not overread.
	print("\n[Undersized ρ is rejected, not overread]")
	var dim := 4
	var e := _engine(dim, true, 0.1, true)
	var short_rho := _packed_zero(2)  # 2×2 worth of data handed to a 4×4 engine

	var stepped: PackedFloat64Array = e.evolve_step(short_rho, 0.01)
	_check(stepped == short_rho, "evolve_step returns input unchanged")
	var evolved: PackedFloat64Array = e.evolve(short_rho, 0.01, 0.01)
	_check(evolved == short_rho, "evolve returns input unchanged")

	# The unguarded family: these used to call unpack_dense raw.
	var purity: float = e.compute_purity_from_packed(short_rho)
	_check(purity == 0.0, "compute_purity_from_packed → 0 (zero matrix), no crash", "purity=%s" % purity)
	var bloch: PackedFloat64Array = e.compute_bloch_metrics_from_packed(short_rho, 2)
	_check(bloch.size() >= 0, "compute_bloch_metrics_from_packed survives")
	var mi: PackedFloat64Array = e.compute_all_mutual_information(short_rho, 2)
	_check(mi.size() == 1, "compute_all_mutual_information survives")
	var eig: Dictionary = e.compute_eigenstates(short_rho)
	_check(eig != null, "compute_eigenstates survives")
	var evals: PackedFloat64Array = e.compute_eigenvalues(short_rho)
	_check(evals.size() == dim, "compute_eigenvalues survives")
	var dom: PackedFloat64Array = e.compute_dominant_eigenvector(short_rho)
	_check(dom.size() == dim * 2, "compute_dominant_eigenvector survives")
	var withmi: Dictionary = e.evolve_with_mi(short_rho, 0.01, 0.01, 2)
	_check(withmi != null, "evolve_with_mi survives")


func test_oversized_rho_rejected():
	# Oversized is memory-safe to read but is still a convention violation:
	# somebody handed this engine another biome's state. Silently truncating
	# would evolve the wrong physics under the right-looking numbers.
	print("\n[Oversized ρ is rejected, not truncated]")
	var dim := 4
	var e := _engine(dim, true, 0.0, true)
	var big := _packed_zero(8)  # 8×8 worth of data for a 4×4 engine
	# Non-zero payload so "0.0" can only mean "refused", never "read zeros".
	for i in big.size():
		big[i] = 0.125

	var stepped: PackedFloat64Array = e.evolve_step(big, 0.01)
	_check(stepped == big, "evolve_step returns input unchanged")
	var purity: float = e.compute_purity_from_packed(big)
	_check(purity == 0.0, "compute_purity_from_packed → 0 (zero matrix)", "purity=%s" % purity)


func test_undersized_hamiltonian_rejected():
	# set_hamiltonian reads 2·dim² doubles out of its argument with the same
	# raw pointer walk. A short H is the same overread by another door.
	print("\n[Undersized H is rejected]")
	var e := QuantumEvolutionEngine.new()
	e.set_dimension(4)
	# 2×2 H for a 4×4 engine, with a non-zero payload: if the short buffer is
	# read at all, some coupling gets installed and ρ moves.
	var short_h := _packed_zero(2)
	short_h[0] = 0.0
	short_h[2] = 1.7   # H[0][1].re
	short_h[4] = 1.7   # H[1][0].re
	short_h[6] = 2.3   # H[1][1].re
	e.set_hamiltonian(short_h)
	e.finalize()
	# H must NOT have been installed: with no Hamiltonian and no Lindblads the
	# engine is a no-op evolver, so ρ comes back untouched.
	var rho := _make_rho(4, 0.3)
	var out: PackedFloat64Array = e.evolve_step(rho, 0.1)
	_check(_max_abs_diff(out, rho) < TOL_EXACT, "short H not installed (ρ unchanged)", "diff=%s" % _max_abs_diff(out, rho))
