extends SceneTree

## Golden-vector dump for QuantumEvolutionEngine (kernel extraction, packet B).
##
## Drives EVERY method bound in QuantumEvolutionEngine::_bind_methods with
## deterministic inputs and writes the results as bit-exact JSON.
##
## Run:
##   godot --headless --path . --script tests/kernel_golden_dump.gd -- --out=<path.json>
## (default output: user://kernel_golden.json)
##
## Determinism rules:
##   * Inputs come from an integer LCG (31-bit state, no overflow) and are mapped to
##     doubles by dividing by powers of two, plus + - * / only. No randf/randi and no
##     libm calls (sin, cos, sqrt, exp, ...) when BUILDING inputs.
##   * Every double and PackedFloat64Array is stored as the lowercase hex of its raw
##     little-endian IEEE-754 bytes. Ints, bools, strings are plain JSON.
##   * Record layout: key -> {"t": "d"|"a"|"i"|"b"|"s", "v": <value>} ("n" = original
##     length, only on arrays that were thinned to a strided sample to bound the
##     file size). Keys are written sorted.
##
## The engine prints warnings/errors on its error paths. That is expected.

const NQ := {2: 1, 4: 2, 8: 3, 16: 4, 32: 5, 64: 6}
const DT_A := 0.05
const DT_B := 0.1
const THIN_ABOVE := 2048  # doubles; arrays longer than this are sampled when thin=true
const THIN_SAMPLES := 512

var rec: Dictionary = {}
var _s: int = 1


# ------------------------------------------------------------------ LCG inputs

func _seed(x: int) -> void:
	_s = (x * 2654435761 + 12345) & 0x7FFFFFFF


## [0,1) with 21 bits. s*1103515245 < 2^31 * 2^31 = 2^62: never overflows int64.
func _u() -> float:
	_s = (_s * 1103515245 + 12345) & 0x7FFFFFFF
	return float(_s >> 10) / 2097152.0


func _zeros(n: int) -> PackedFloat64Array:
	var p := PackedFloat64Array()
	p.resize(n)
	p.fill(0.0)
	return p


func _make_h(dim: int, seed_v: int) -> PackedFloat64Array:
	_seed(seed_v)
	var p := _zeros(2 * dim * dim)
	for i in dim:
		p[(i * dim + i) * 2] = (_u() - 0.5) * 3.0
		for j in range(i + 1, dim):
			var re := (_u() - 0.5) * 0.5
			var im := (_u() - 0.5) * 0.5
			p[(i * dim + j) * 2] = re
			p[(i * dim + j) * 2 + 1] = im
			p[(j * dim + i) * 2] = re
			p[(j * dim + i) * 2 + 1] = -im
	return p


func _normalize_trace(p: PackedFloat64Array, dim: int) -> void:
	var tr := 0.0
	for i in dim:
		tr += p[(i * dim + i) * 2]
	for k in p.size():
		p[k] = p[k] / tr


## Convex mix of a few basis projectors + a small floor + small Hermitian off-diagonals.
func _make_rho_mixed(dim: int, seed_v: int) -> PackedFloat64Array:
	_seed(seed_v)
	var p := _zeros(2 * dim * dim)
	for i in dim:
		p[(i * dim + i) * 2] = 0.015625
	var few := 4 if dim >= 4 else dim
	for _k in few:
		var idx := int(_u() * float(dim))
		p[(idx * dim + idx) * 2] += float(1 + int(_u() * 8.0)) / 8.0
	for i in dim:
		for j in range(i + 1, dim):
			var re := (_u() - 0.5) * 0.02
			var im := (_u() - 0.5) * 0.02
			p[(i * dim + j) * 2] = re
			p[(i * dim + j) * 2 + 1] = im
			p[(j * dim + i) * 2] = re
			p[(j * dim + i) * 2 + 1] = -im
	_normalize_trace(p, dim)
	return p


func _make_rho_pure(dim: int, seed_v: int) -> PackedFloat64Array:
	_seed(seed_v)
	var p := _zeros(2 * dim * dim)
	var k := int(_u() * float(dim))
	for i in dim:
		p[(i * dim + i) * 2] = 0.001
	p[(k * dim + k) * 2] = 1.0
	for j in dim:
		if j == k:
			continue
		var re := (_u() - 0.5) * 0.002
		var im := (_u() - 0.5) * 0.002
		p[(k * dim + j) * 2] = re
		p[(k * dim + j) * 2 + 1] = im
		p[(j * dim + k) * 2] = re
		p[(j * dim + k) * 2 + 1] = -im
	_normalize_trace(p, dim)
	return p


## Triplets [row, col, re, im, ...] for Lindblad operator k (rational amplitudes).
func _make_lindblad(dim: int, k: int) -> PackedFloat64Array:
	var t := PackedFloat64Array()
	var s := (k % (dim - 1)) + 1
	for i in range(dim - s):
		t.append(float(i))
		t.append(float(i + s))
		t.append(float(1 + (i + k) % 3) / 4.0)
		t.append(0.0 if i % 2 == 0 else float(k + 1) / 8.0)
	if k >= 1:
		var d := k % dim
		t.append(float(d))
		t.append(float(d))
		t.append(0.125 * float(k + 1))
		t.append(0.0)
	return t


# ------------------------------------------------------------------ recording

func _hex_d(x: float) -> String:
	var a := PackedFloat64Array()
	a.append(x)
	return a.to_byte_array().hex_encode()


func _r_d(key: String, x: float) -> void:
	rec[key] = {"t": "d", "v": _hex_d(x)}


func _r_i(key: String, x: int) -> void:
	rec[key] = {"t": "i", "v": x}


func _r_b(key: String, x: bool) -> void:
	rec[key] = {"t": "b", "v": x}


func _r_s(key: String, x: String) -> void:
	rec[key] = {"t": "s", "v": x}


func _r_a(key: String, a: PackedFloat64Array, thin: bool = false) -> void:
	if thin and a.size() > THIN_ABOVE:
		var stride := a.size() / THIN_SAMPLES
		var s := PackedFloat64Array()
		for i in THIN_SAMPLES:
			s.append(a[i * stride])
		rec[key] = {"t": "a", "n": a.size(), "v": s.to_byte_array().hex_encode()}
		return
	rec[key] = {"t": "a", "v": a.to_byte_array().hex_encode()}


## Record any engine return value (recursing into Dictionaries).
func _r_var(key: String, v: Variant, thin: bool = false) -> void:
	match typeof(v):
		TYPE_FLOAT:
			_r_d(key, v)
		TYPE_INT:
			_r_i(key, v)
		TYPE_BOOL:
			_r_b(key, v)
		TYPE_STRING:
			_r_s(key, v)
		TYPE_PACKED_FLOAT64_ARRAY:
			_r_a(key, v, thin)
		TYPE_DICTIONARY:
			var ks: Array = v.keys()
			ks.sort()
			_r_s(key + "/#keys", ",".join(ks))
			for k in ks:
				_r_var(key + "/" + str(k), v[k], thin)
		_:
			_r_s(key, "UNSUPPORTED_TYPE_%d" % typeof(v))


func _r_eq(key: String, a: PackedFloat64Array, b: PackedFloat64Array) -> void:
	_r_b(key, a == b)


# ------------------------------------------------------------------ engine setup

func _engine(dim: int, h: Variant, n_lind: int, finalize: bool = true) -> QuantumEvolutionEngine:
	var e := QuantumEvolutionEngine.new()
	e.set_dimension(dim)
	if h != null:
		e.set_hamiltonian(h)
	for k in n_lind:
		e.add_lindblad_triplets(_make_lindblad(dim, k))
	if finalize:
		e.finalize()
	return e


func _state(p: String, e: QuantumEvolutionEngine) -> void:
	_r_i(p + "/dimension", e.get_dimension())
	_r_i(p + "/lindblad_count", e.get_lindblad_count())
	_r_b(p + "/is_finalized", e.is_finalized())


# ------------------------------------------------------------------ per-dim cases

func _case_dim(dim: int) -> void:
	var nq: int = NQ[dim]
	var big := dim >= 64
	var pre := "d%d" % dim
	var h := _make_h(dim, 100 + dim)
	var mx := _make_rho_mixed(dim, 200 + dim)
	var np := _make_rho_pure(dim, 300 + dim)
	_r_a(pre + "/in/h", h, true)
	_r_a(pre + "/in/rho_mixed", mx, true)
	_r_a(pre + "/in/rho_pure", np, true)

	# ---- closed: H, no L (exact-unitary path) ----------------------------------
	var c := pre + "/closed"
	var e := _engine(dim, null, 0, false)
	e.set_hamiltonian(h)
	_state(c + "/pre_finalize", e)
	e.finalize()
	_state(c + "/post_finalize", e)
	var o1 := e.evolve(mx, DT_A, DT_A)
	_r_a(c + "/evolve_mx_dt0.05", o1, big)
	_r_i(c + "/substeps_after_dt0.05", e.get_last_substep_count())
	var o2 := e.evolve(mx, DT_B, DT_B)
	_r_a(c + "/evolve_mx_dt0.1", o2, big)
	var o3 := e.evolve(mx, DT_B, DT_B)  # propagator cache hit
	_r_eq(c + "/evolve_mx_dt0.1_cachehit_equal", o2, o3)
	var o4 := e.evolve(mx, DT_A, DT_A)  # changed dt: rebuild
	_r_eq(c + "/evolve_mx_dt0.05_rebuilt_equal", o1, o4)
	_r_a(c + "/evolve_np_dt0.1", e.evolve(np, DT_B, DT_B), big)
	_r_a(c + "/evolve_mx_dt0.1_max0.025", e.evolve(mx, DT_B, DT_B / 4.0), big)
	_r_i(c + "/substeps_after_unitary", e.get_last_substep_count())
	var es := e.evolve_step(mx, DT_B)
	_r_eq(c + "/evolve_step_mx_dt0.1_equal_evolve", es, o2)
	_r_a(c + "/evolve_step_mx_dt0.1", es, true)
	e.set_coherent(false)
	_r_a(c + "/evolve_mx_dt0.1_nocoherent", e.evolve(mx, DT_B, DT_B), big)
	_r_i(c + "/substeps_after_nocoherent", e.get_last_substep_count())
	e.set_coherent(true)
	var ewm := e.evolve_with_mi(mx, DT_B, DT_B, nq)
	_r_var(c + "/evolve_with_mi_mx", ewm, big)
	_r_i(c + "/substeps_after_evolve_with_mi", e.get_last_substep_count())
	_state(c + "/end", e)

	# ---- analysis methods, on the closed engine ---------------------------------
	_analysis(pre, e, mx, np, nq, big)

	# ---- open: H + n Lindblad ---------------------------------------------------
	for n in [1, 3]:
		var o := "%s/open%d" % [pre, n]
		var eo := _engine(dim, h, n)
		_state(o + "/post_finalize", eo)
		_r_a(o + "/evolve_mx_dt0.1_max0.1", eo.evolve(mx, DT_B, DT_B), big)
		_r_i(o + "/substeps_mx_dt0.1_max0.1", eo.get_last_substep_count())
		_r_a(o + "/evolve_mx_dt0.1_max0.025", eo.evolve(mx, DT_B, DT_B / 4.0), big)
		_r_i(o + "/substeps_mx_dt0.1_max0.025", eo.get_last_substep_count())
		_r_a(o + "/evolve_mx_dt0.05_max0.05", eo.evolve(mx, DT_A, DT_A), big)
		_r_i(o + "/substeps_mx_dt0.05_max0.05", eo.get_last_substep_count())
		_r_a(o + "/evolve_np_dt0.1_max0.1", eo.evolve(np, DT_B, DT_B), big)
		_r_i(o + "/substeps_np_dt0.1_max0.1", eo.get_last_substep_count())
		_r_a(o + "/evolve_np_dt0.1_max0.025", eo.evolve(np, DT_B, DT_B / 4.0), big)
		_r_i(o + "/substeps_np_dt0.1_max0.025", eo.get_last_substep_count())
		var oes := eo.evolve_step(mx, DT_B)
		_r_a(o + "/evolve_step_mx_dt0.1", oes, big)
		_r_eq(o + "/evolve_step_equal_evolve", oes, eo.evolve(mx, DT_B, DT_B))
		eo.set_coherent(false)
		_r_a(o + "/evolve_mx_dt0.1_nocoherent", eo.evolve(mx, DT_B, DT_B), big)
		_r_i(o + "/substeps_nocoherent", eo.get_last_substep_count())
		eo.set_coherent(true)
		_r_var(o + "/evolve_with_mi_mx", eo.evolve_with_mi(mx, DT_B, DT_B / 4.0, nq), big)
		_r_i(o + "/substeps_after_evolve_with_mi", eo.get_last_substep_count())
		_state(o + "/end", eo)

		if n == 1:
			# The substep-count quirk: an exact-unitary evolve does NOT reset the counter.
			eo.clear_operators()
			_state(o + "/after_clear", eo)
			eo.set_hamiltonian(h)
			eo.finalize()
			_r_i(o + "/quirk_substeps_before_unitary", eo.get_last_substep_count())
			_r_a(o + "/quirk_unitary_evolve", eo.evolve(mx, DT_B, DT_B), big)
			_r_i(o + "/quirk_substeps_after_unitary", eo.get_last_substep_count())
			_state(o + "/quirk_end", eo)

	# ---- pure Lindbladian (no H at all) -----------------------------------------
	var l := pre + "/lonly1"
	var el := _engine(dim, null, 1)
	_state(l + "/post_finalize", el)
	_r_a(l + "/evolve_mx_dt0.1_max0.1", el.evolve(mx, DT_B, DT_B), big)
	_r_i(l + "/substeps_mx_dt0.1_max0.1", el.get_last_substep_count())
	_r_a(l + "/evolve_mx_dt0.1_max0.025", el.evolve(mx, DT_B, DT_B / 4.0), big)
	_r_i(l + "/substeps_mx_dt0.1_max0.025", el.get_last_substep_count())
	_r_a(l + "/evolve_np_dt0.1_max0.1", el.evolve(np, DT_B, DT_B), big)
	_r_a(l + "/evolve_step_mx_dt0.1", el.evolve_step(mx, DT_B), big)


func _analysis(pre: String, e: QuantumEvolutionEngine, mx: PackedFloat64Array,
		np: PackedFloat64Array, nq: int, big: bool) -> void:
	for tag in ["mx", "np"]:
		var rho: PackedFloat64Array = mx if tag == "mx" else np
		var a := "%s/ana_%s" % [pre, tag]
		_r_d(a + "/purity", e.compute_purity_from_packed(rho))
		_r_a(a + "/bloch", e.compute_bloch_metrics_from_packed(rho, nq))
		_r_a(a + "/mi_all", e.compute_all_mutual_information(rho, nq))
		# adaptive MI: screening + candidate reuse
		for purity in [0.95, 0.5]:
			e.clear_mi_candidates()
			var p := "%s/mi_adaptive_p%s" % [a, str(purity)]
			_r_a(p + "/full1", e.compute_mi_adaptive(rho, nq, purity, true))
			_r_a(p + "/cand1", e.compute_mi_adaptive(rho, nq, purity, false))
			_r_a(p + "/cand_other_purity", e.compute_mi_adaptive(rho, nq, 1.0 - purity + 0.4, false))
			_r_a(p + "/full2", e.compute_mi_adaptive(rho, nq, purity, true))
			e.clear_mi_candidates()
			_r_a(p + "/cleared_cand", e.compute_mi_adaptive(rho, nq, purity, false))
			_r_a(p + "/cleared_full", e.compute_mi_adaptive(rho, nq, purity, true))
			_r_a(p + "/after_full_cand", e.compute_mi_adaptive(rho, nq, purity, false))
		# eigen
		_r_var(a + "/eigenstates", e.compute_eigenstates(rho), true)
		_r_a(a + "/dominant", e.compute_dominant_eigenvector(rho))
		_r_a(a + "/eigenvalues", e.compute_eigenvalues(rho))
	var dom_m := e.compute_dominant_eigenvector(mx)
	var dom_p := e.compute_dominant_eigenvector(np)
	_r_d(pre + "/cos2/m_m", e.compute_cos2_similarity(dom_m, dom_m))
	_r_d(pre + "/cos2/m_p", e.compute_cos2_similarity(dom_m, dom_p))
	_r_d(pre + "/cos2/m_short", e.compute_cos2_similarity(dom_m, dom_m.slice(0, 2)))
	_r_d(pre + "/cos2/empty", e.compute_cos2_similarity(PackedFloat64Array(), PackedFloat64Array()))
	_r_d(pre + "/cos2/raw_mx_np", e.compute_cos2_similarity(mx.slice(0, 16), np.slice(0, 16)))


# ------------------------------------------------------------------ global cases

func _case_batch_and_similarity() -> void:
	var rhos := {}
	rhos["a_d2"] = _make_rho_mixed(2, 1)
	rhos["b_d4"] = _make_rho_pure(4, 2)
	rhos["c_d8"] = _make_rho_mixed(8, 3)
	rhos["d_d3_odd"] = _make_rho_mixed(3, 4)
	rhos["e_bad_size7"] = _zeros(7)
	rhos["f_empty"] = PackedFloat64Array()
	rhos["g_not_packed"] = "text"
	rhos["h_regular_array"] = [1.0, 2.0]
	var e := QuantumEvolutionEngine.new()  # batch ignores engine dimension
	var res: Dictionary = e.compute_batch_eigenstates(rhos)
	_r_var("batch/result", res)
	_r_i("batch/result_size", res.size())
	_r_var("batch/empty_input", e.compute_batch_eigenstates({}))

	var v1 := e.compute_dominant_eigenvector(_make_rho_mixed(4, 11))
	var ed := QuantumEvolutionEngine.new()
	ed.set_dimension(4)
	var d1 := ed.compute_dominant_eigenvector(_make_rho_mixed(4, 11))
	var d2 := ed.compute_dominant_eigenvector(_make_rho_pure(4, 12))
	var d3 := ed.compute_dominant_eigenvector(_make_rho_mixed(4, 13))
	_r_a("simmat/engine_dim0_dominant", v1)  # dim not set -> empty
	var arr: Array = [d1, d2, d3, "not an array", PackedFloat64Array([1.0, 0.0, 0.0, 0.0]), d1]
	_r_a("simmat/n6_with_nonarray", ed.compute_eigenstate_similarity_matrix(arr))
	_r_a("simmat/n3", ed.compute_eigenstate_similarity_matrix([d1, d2, d3]))
	_r_a("simmat/n1", ed.compute_eigenstate_similarity_matrix([d1]))
	_r_a("simmat/n0", ed.compute_eigenstate_similarity_matrix([]))
	_r_a("simmat/first_nonarray", ed.compute_eigenstate_similarity_matrix([5, d1, d2]))


func _case_errors() -> void:
	var dim := 4
	var h := _make_h(dim, 500)
	var mx := _make_rho_mixed(dim, 501)
	# Non-zero mis-sized inputs, so "returned unchanged" is distinguishable from "zeroed".
	var small := mx.slice(0, 30)
	var big := mx.duplicate()
	big.append_array(_make_rho_mixed(2, 502))
	big.append_array(PackedFloat64Array([0.5, 0.25, 0.125, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]))  # 32+8+10 = 50

	# -- before set_dimension --------------------------------------------------
	var e := QuantumEvolutionEngine.new()
	_state("err/fresh", e)
	e.set_hamiltonian(h)
	e.add_lindblad_triplets(_make_lindblad(dim, 0))
	_state("err/ham_lind_before_setdim", e)
	_r_a("err/evolve_before_finalize_dim0", e.evolve(mx, DT_B, DT_B))
	_r_var("err/eigenstates_dim0", e.compute_eigenstates(mx))
	_r_a("err/dominant_dim0", e.compute_dominant_eigenvector(mx))
	_r_a("err/eigenvalues_dim0", e.compute_eigenvalues(mx))

	# -- evolve before finalize --------------------------------------------------
	e.set_dimension(dim)
	e.set_hamiltonian(h)
	_state("err/dim4_unfinalized", e)
	_r_a("err/evolve_before_finalize", e.evolve(mx, DT_B, DT_B))
	_r_a("err/evolve_step_before_finalize", e.evolve_step(mx, DT_B))
	_r_var("err/evolve_with_mi_before_finalize", e.evolve_with_mi(mx, DT_B, DT_B, 2))
	_r_i("err/substeps_never_evolved", e.get_last_substep_count())

	# -- mis-sized H -------------------------------------------------------------
	e.clear_operators()
	e.set_hamiltonian(small)
	e.set_hamiltonian(big)
	e.set_hamiltonian(PackedFloat64Array())
	e.finalize()
	_state("err/after_bad_h", e)
	_r_a("err/evolve_no_h_no_l", e.evolve(mx, DT_B, DT_B))
	_r_i("err/substeps_no_h_no_l", e.get_last_substep_count())

	# -- mis-sized rho -----------------------------------------------------------
	e.set_hamiltonian(h)
	e.finalize()
	for sz in [["small", small], ["big", big], ["empty", PackedFloat64Array()]]:
		var nm: String = sz[0]
		var bad: PackedFloat64Array = sz[1]
		_r_a("err/rho_%s/evolve" % nm, e.evolve(bad, DT_B, DT_B))
		_r_a("err/rho_%s/evolve_step" % nm, e.evolve_step(bad, DT_B))
		_r_var("err/rho_%s/evolve_with_mi" % nm, e.evolve_with_mi(bad, DT_B, DT_B, 2))
		_r_d("err/rho_%s/purity" % nm, e.compute_purity_from_packed(bad))
		_r_a("err/rho_%s/bloch" % nm, e.compute_bloch_metrics_from_packed(bad, 2))
		_r_a("err/rho_%s/mi_all" % nm, e.compute_all_mutual_information(bad, 2))
		_r_a("err/rho_%s/mi_adaptive" % nm, e.compute_mi_adaptive(bad, 2, 0.5, true))
		_r_var("err/rho_%s/eigenstates" % nm, e.compute_eigenstates(bad))
		_r_a("err/rho_%s/dominant" % nm, e.compute_dominant_eigenvector(bad))
		_r_a("err/rho_%s/eigenvalues" % nm, e.compute_eigenvalues(bad))
	_r_i("err/substeps_after_bad_rho", e.get_last_substep_count())

	# -- num_qubits edge values (no out-of-bounds: 0 and 1 produce empty results) --
	for q in [0, 1]:
		_r_a("err/nq%d/mi_all" % q, e.compute_all_mutual_information(mx, q))
		_r_a("err/nq%d/mi_adaptive" % q, e.compute_mi_adaptive(mx, q, 0.5, true))
		_r_a("err/nq%d/bloch" % q, e.compute_bloch_metrics_from_packed(mx, q) if q == 0 else PackedFloat64Array())
	_r_var("err/nq0/evolve_with_mi", e.evolve_with_mi(mx, DT_B, DT_B, 0))
	_r_var("err/nq1/evolve_with_mi", e.evolve_with_mi(mx, DT_B, DT_B, 1))

	# -- out-of-range Lindblad triplets ------------------------------------------
	e.clear_operators()
	e.set_hamiltonian(h)
	var t := PackedFloat64Array([
		4.0, 0.0, 0.5, 0.0,      # row == dim
		0.0, -1.0, 0.5, 0.0,     # negative col
		1.0, 0.0, 0.25, 0.125,   # valid
		2.0, 2.0, 1e-16, 1e-16,  # below drop threshold
		9.0, 9.0, 0.5, 0.5,      # far out of range
		0.5, 1.9, 0.5, 0.0,      # fractional indices truncate to (0,1)
		3.0, 1.0, 0.5])          # trailing partial entry (3 doubles) ignored
	e.add_lindblad_triplets(t)
	_r_i("err/lind_oor/count", e.get_lindblad_count())
	e.finalize()
	_r_a("err/lind_oor/evolve", e.evolve(mx, DT_B, DT_B / 4.0))
	_r_i("err/lind_oor/substeps", e.get_last_substep_count())
	# an empty / all-dropped triplet list still pushes an (empty) operator
	e.add_lindblad_triplets(PackedFloat64Array())
	_r_i("err/lind_empty/count", e.get_lindblad_count())
	_r_b("err/lind_empty/finalized_after_add", e.is_finalized())
	e.finalize()
	_r_a("err/lind_empty/evolve", e.evolve(mx, DT_B, DT_B))

	# -- change after finalize ---------------------------------------------------
	e.set_hamiltonian(h)
	_r_b("err/finalized_after_set_h", e.is_finalized())
	_r_a("err/evolve_after_set_h_unfinalized", e.evolve(mx, DT_B, DT_B))
	e.finalize()
	e.set_dimension(4)
	_r_b("err/finalized_after_set_dim", e.is_finalized())

	# -- clear_operators then reuse ------------------------------------------------
	e.clear_operators()
	_state("err/cleared", e)
	_r_a("err/evolve_after_clear_unfinalized", e.evolve(mx, DT_B, DT_B))
	e.finalize()
	_r_a("err/evolve_after_clear_finalized_empty", e.evolve(mx, DT_B, DT_B))
	_r_i("err/substeps_after_clear_finalized", e.get_last_substep_count())
	e.set_hamiltonian(_make_h(dim, 600))
	e.add_lindblad_triplets(_make_lindblad(dim, 1))
	e.finalize()
	_state("err/reused", e)
	_r_a("err/evolve_reused_open", e.evolve(mx, DT_B, DT_B))
	e.clear_operators()
	e.set_hamiltonian(_make_h(dim, 601))
	e.finalize()
	_r_a("err/evolve_reused_closed", e.evolve(mx, DT_B, DT_B))

	# -- changing dimension re-validates the cache (propagator stale after set_dimension) --
	var e2 := QuantumEvolutionEngine.new()
	e2.set_dimension(4)
	e2.set_hamiltonian(h)
	e2.finalize()
	_r_a("err/dimchange/before", e2.evolve(mx, DT_B, DT_B))
	e2.set_dimension(2)
	e2.set_hamiltonian(_make_h(2, 700))
	e2.finalize()
	_r_a("err/dimchange/after", e2.evolve(_make_rho_mixed(2, 701), DT_B, DT_B))
	_r_a("err/dimchange/after_old_rho", e2.evolve(mx, DT_B, DT_B))

	# -- dimension 1 and degenerate dt ----------------------------------------------
	var e3 := _engine(2, _make_h(2, 800), 1)
	var r2 := _make_rho_mixed(2, 801)
	_r_a("err/dt_zero", e3.evolve(r2, 0.0, 0.0))
	_r_i("err/dt_zero_substeps", e3.get_last_substep_count())
	_r_a("err/max_dt_zero", e3.evolve(r2, DT_B, 0.0))
	_r_a("err/max_dt_negative", e3.evolve(r2, DT_B, -1.0))
	_r_a("err/max_dt_big", e3.evolve(r2, DT_B, 5.0))
	_r_i("err/max_dt_big_substeps", e3.get_last_substep_count())
	_r_a("err/dt_large", e3.evolve(r2, 3.0, 3.0))
	_r_i("err/dt_large_substeps", e3.get_last_substep_count())


# ------------------------------------------------------------------ main

func _out_path() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			return a.substr(6)
	return "user://kernel_golden.json"


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	for dim in [2, 4, 8, 16, 32, 64]:
		if only != "" and only != "d%d" % dim:
			continue
		var t := Time.get_ticks_msec()
		_case_dim(dim)
		print("[kernel_golden] dim %d done in %d ms" % [dim, Time.get_ticks_msec() - t])
	if only == "":
		_case_batch_and_similarity()
		_case_errors()

	var path := _out_path()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("kernel_golden_dump: cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		quit(2)
		return
	f.store_string(JSON.stringify(rec, "", true))
	f.close()
	print("[kernel_golden] %d records -> %s in %d ms" % [rec.size(), path, Time.get_ticks_msec() - t0])
	quit(0)
