class_name WitnessCluster
extends RefCounted

## One belief cluster of the Witness — a small density matrix whose qubits are
## ROLES (beliefs about aspects of the world), not game registers. Ported from
## umwelt's substrate/cluster.py (the reference implementation, ~/ws/umwelt):
##
##   observe(role, target, α)   weak measurement — partial collapse of one role
##                              toward an arbitrary Bloch target:
##                                ρ' = (1−α)·ρ + α·(ρ_target_q ⊗ Tr_q[ρ])
##                              preserving correlations among the other roles.
##                              α ≤ 0 is a PROVABLE no-op (η=0 theorem): the
##                              belief cannot move faster than the observation's
##                              admitted strength. Confidence is recorded even
##                              at α=0 (a null read shows in the gauge ledger).
##
##   depolarize(dt)             the dissipative-role law: every role relaxes
##                              toward I/2 (maximal uncertainty) at gamma_diss.
##                              Roles fed one polarity of evidence MUST forget
##                              or they saturate at a pole (umwelt FIELD_NOTES §1).
##                              Exact map, not an integrator: same injection
##                              with target = Bloch origin, α = 1−exp(−γ·dt).
##
## Qubit convention: role index q occupies bit (n_qubits−1−q) of the state
## index — roles list left-to-right = tensor factors left-to-right (kron order).
## Phase 1 has H = 0 (no coherent dynamics), so the only maps applied are the
## two above — both are exact convex mixes of valid density matrices, so ρ
## stays positive, Hermitian, trace-1 by construction; no renormalize crutch.

var cluster_name: String = ""
var roles: Array = []                # role names, tensor order
var role_index: Dictionary = {}      # role → qubit index
var n_qubits: int = 0
var dim: int = 0
var rho: ComplexMatrix = null
var gamma_diss: Dictionary = {}      # role → relaxation rate (1/s)
var obs_confidence: Dictionary = {}  # role → last edge-supplied validity (gauge quantity)
var observe_count: int = 0
var couplings: Array = []            # [{a: role, b: role, j: float}] — exchange terms
var _u_cache: Dictionary = {}        # dt → [U, U†] for the coupling unitary


func _init(name_: String = "", roles_: Array = [], gamma_by_role: Dictionary = {}):
	cluster_name = name_
	for r in roles_:
		roles.append(str(r))
	n_qubits = roles.size()
	dim = 1 << n_qubits if n_qubits > 0 else 0
	for q in range(n_qubits):
		role_index[roles[q]] = q
	gamma_diss = gamma_by_role.duplicate()
	if dim > 0:
		reset()


## Maximally mixed — the blank state. A fresh Witness knows nothing (umwelt's
## blank-slate boot), and forgetting back to this state is always legal.
func reset() -> void:
	rho = ComplexMatrix.identity(dim)
	rho = rho.scale_real(1.0 / float(dim))
	obs_confidence.clear()


## Weak observation of one role toward an arbitrary Bloch target.
## Umwelt contract: caller has already folded confidence into alpha (k·η);
## `confidence` is RECORDED here as a read-only gauge quantity, even when
## alpha=0, so a null/failed read is visible in the ledger.
func observe(role: String, target: Vector3, alpha: float, confidence: float = 1.0) -> void:
	if not role_index.has(role):
		push_error("WitnessCluster %s: unknown role '%s'" % [cluster_name, role])
		return
	obs_confidence[role] = confidence
	if alpha <= 0.0:
		return
	observe_count += 1
	var x := target.x
	var y := target.y
	var z := target.z
	# Clamp to the Bloch ball so ρ_target stays a valid density matrix.
	var r := sqrt(x * x + y * y + z * z)
	if r > 1.0:
		x /= r
		y /= r
		z /= r
	# ρ_target = ½(I + xσx + yσy + zσz)  → 2×2 entries:
	#   t00 = (1+z)/2      t01 = (x − iy)/2
	#   t10 = (x + iy)/2   t11 = (1−z)/2
	_inject_target_rdm(role_index[role],
		0.5 * (1.0 + z), 0.5 * x, -0.5 * y, 0.5 * (1.0 - z),
		minf(alpha, 1.0))


## One evolution stride: coherent exchange couplings first (exact unitary,
## cached e^{−iH·dt} on native expm), then the dissipative-role law. This is
## the cluster's whole autonomous dynamics — beliefs mix along authored
## couplings and everything eases back toward uncertainty.
func stride(dt: float) -> void:
	if dt <= 0.0:
		return
	if not couplings.is_empty():
		var pair = _coupling_unitary(dt)
		if pair != null:
			rho = pair[0].mul(rho).mul(pair[1])
	depolarize(dt)


## Exchange Hamiltonian H = Σ J·(|01⟩⟨10| + |10⟩⟨01|) on each coupled role
## pair — transfers belief population between roles (a ZZ term would only
## dephase; exchange is what lets a settled belief inform an unknown one).
## U = e^{−iH·dt} built once per dt through the native expm kernel.
func _coupling_unitary(dt: float):
	var key := snappedf(dt, 0.0001)
	if _u_cache.has(key):
		return _u_cache[key]
	var h = ComplexMatrix.zeros(dim)
	for coupling in couplings:
		var ra := str(coupling.get("a", ""))
		var rb := str(coupling.get("b", ""))
		if not (role_index.has(ra) and role_index.has(rb)):
			continue
		var j := float(coupling.get("j", 0.0))
		if absf(j) < 1e-12:
			continue
		var sa: int = n_qubits - 1 - int(role_index[ra])
		var sb: int = n_qubits - 1 - int(role_index[rb])
		for i in range(dim):
			# i has a=0, b=1 → couples to i with a=1, b=0
			if ((i >> sa) & 1) == 0 and ((i >> sb) & 1) == 1:
				var k: int = (i | (1 << sa)) & ~(1 << sb)
				var existing = h.get_element(i, k)
				h.set_element(i, k, Complex.new(existing.re + j, existing.im))
				h.set_element(k, i, Complex.new(existing.re + j, -existing.im))
	if h.frobenius_norm() < 1e-12:
		_u_cache[key] = null
		return null
	var u = h.scale(Complex.new(0.0, -key)).expm()
	var pair := [u, u.dagger()]
	_u_cache[key] = pair
	return pair


## The dissipative-role law: relax every role toward the Bloch origin (I/2)
## with per-role strength λ = 1 − exp(−gamma_diss·dt). Exact CPTP map.
func depolarize(dt: float) -> void:
	if dt <= 0.0:
		return
	for role in roles:
		var g: float = float(gamma_diss.get(role, 0.0))
		if g <= 0.0:
			continue
		var lam := 1.0 - exp(-g * dt)
		if lam <= 1e-12:
			continue
		_inject_target_rdm(role_index[role], 0.5, 0.0, 0.0, 0.5, lam)


## ρ' = (1−α)·ρ + α·(target_rdm ⊗_q Tr_q[ρ]) — mix qubit q toward a 2×2
## target RDM, preserving the other qubits' mutual correlations (umwelt
## cluster._inject_target_rdm, in packed-index form instead of tensor reshape).
## target entries: t00/t11 real; t01 = t01re + i·t01im; t10 = conj(t01).
func _inject_target_rdm(q: int, t00: float, t01re: float, t01im: float, t11: float, alpha: float) -> void:
	var packed := rho._to_packed()
	var half: int = dim >> 1
	var bit_shift: int = n_qubits - 1 - q          # role q's bit position
	var bit_mask: int = 1 << bit_shift
	var low_mask: int = bit_mask - 1               # bits below q's bit

	if n_qubits == 1:
		var out1 := PackedFloat64Array()
		out1.resize(8)
		var keep1 := 1.0 - alpha
		out1[0] = keep1 * packed[0] + alpha * t00   # (0,0) re
		out1[1] = keep1 * packed[1]
		out1[2] = keep1 * packed[2] + alpha * t01re # (0,1)
		out1[3] = keep1 * packed[3] + alpha * t01im
		out1[4] = keep1 * packed[4] + alpha * t01re # (1,0) = conj(t01)
		out1[5] = keep1 * packed[5] - alpha * t01im
		out1[6] = keep1 * packed[6] + alpha * t11   # (1,1)
		out1[7] = keep1 * packed[7]
		rho._from_packed(out1, dim)
		return

	# rest = Tr_q[ρ]: (dim/2)×(dim/2). rest-index ri ↔ full index with q's bit
	# stripped; expand(ri, b) reinserts bit b at q's position.
	var rest_re := PackedFloat64Array()
	var rest_im := PackedFloat64Array()
	rest_re.resize(half * half)
	rest_im.resize(half * half)
	for ri in range(half):
		var row_base: int = ((ri & ~low_mask) << 1) | (ri & low_mask)
		for rj in range(half):
			var col_base: int = ((rj & ~low_mask) << 1) | (rj & low_mask)
			var s_re := 0.0
			var s_im := 0.0
			for b in range(2):
				var i: int = row_base | (b << bit_shift)
				var j: int = col_base | (b << bit_shift)
				var idx: int = (i * dim + j) * 2
				s_re += packed[idx]
				s_im += packed[idx + 1]
			rest_re[ri * half + rj] = s_re
			rest_im[ri * half + rj] = s_im

	# new[i,j] = (1−α)·ρ[i,j] + α·t[b_i, b_j]·rest[strip(i), strip(j)]
	var out := PackedFloat64Array()
	out.resize(dim * dim * 2)
	var keep := 1.0 - alpha
	for i in range(dim):
		var bi: int = (i >> bit_shift) & 1
		var si: int = ((i >> 1) & ~low_mask) | (i & low_mask)   # i with q's bit stripped
		for j in range(dim):
			var bj: int = (j >> bit_shift) & 1
			var sj: int = ((j >> 1) & ~low_mask) | (j & low_mask)
			# t[bi, bj]
			var t_re: float
			var t_im: float
			if bi == 0 and bj == 0:
				t_re = t00; t_im = 0.0
			elif bi == 1 and bj == 1:
				t_re = t11; t_im = 0.0
			elif bi == 0 and bj == 1:
				t_re = t01re; t_im = t01im
			else:
				t_re = t01re; t_im = -t01im
			var r_re := rest_re[si * half + sj]
			var r_im := rest_im[si * half + sj]
			var idx2: int = (i * dim + j) * 2
			out[idx2] = keep * packed[idx2] + alpha * (t_re * r_re - t_im * r_im)
			out[idx2 + 1] = keep * packed[idx2 + 1] + alpha * (t_re * r_im + t_im * r_re)
	rho._from_packed(out, dim)


## Reduced Bloch vector of one role: rdm[k,ℓ] = Σ_rest ρ[idx(k,rest), idx(ℓ,rest)]
## → x = 2·Re(rdm01), y = −2·Im(rdm01), z = rdm00 − rdm11.
func role_bloch(role: String) -> Vector3:
	if not role_index.has(role):
		return Vector3.ZERO
	var q: int = role_index[role]
	var packed := rho._to_packed()
	var half: int = dim >> 1
	var bit_shift: int = n_qubits - 1 - q
	var low_mask: int = (1 << bit_shift) - 1
	var rdm00 := 0.0
	var rdm11 := 0.0
	var rdm01_re := 0.0
	var rdm01_im := 0.0
	for ri in range(half):
		var base: int = ((ri & ~low_mask) << 1) | (ri & low_mask)
		var i0: int = base                       # q's bit = 0
		var i1: int = base | (1 << bit_shift)    # q's bit = 1
		rdm00 += packed[(i0 * dim + i0) * 2]
		rdm11 += packed[(i1 * dim + i1) * 2]
		rdm01_re += packed[(i0 * dim + i1) * 2]
		rdm01_im += packed[(i0 * dim + i1) * 2 + 1]
	return Vector3(2.0 * rdm01_re, -2.0 * rdm01_im, rdm00 - rdm11)


## Tr(ρ²) = Σ|ρ_ij|² for Hermitian ρ.
func purity() -> float:
	var packed := rho._to_packed()
	var s := 0.0
	for k in range(dim * dim):
		var re := packed[k * 2]
		var im := packed[k * 2 + 1]
		s += re * re + im * im
	return s


## Diff-stable content hash of ρ (rounded 9dp) — save/load pinning + gauges.
func canon_hash() -> String:
	var packed := rho._to_packed()
	var parts := PackedStringArray()
	for k in range(dim * dim * 2):
		parts.append("%.9f" % packed[k])
	return ",".join(parts).md5_text()


func to_save_dict() -> Dictionary:
	return {
		"roles": roles.duplicate(),
		"dim": dim,
		"packed_rho": rho._to_packed().duplicate(),
		"gamma_diss": gamma_diss.duplicate(),
		"obs_confidence": obs_confidence.duplicate(),
		"observe_count": observe_count,
	}


## Restore from a save section. Returns false (and stays blank) on any shape
## mismatch — forgetting is a legal state; a corrupt belief is not.
func from_save_dict(d: Dictionary) -> bool:
	var saved_roles: Array = d.get("roles", [])
	if saved_roles.size() != roles.size():
		return false
	for q in range(roles.size()):
		if str(saved_roles[q]) != str(roles[q]):
			return false
	var packed = d.get("packed_rho", PackedFloat64Array())
	if not (packed is PackedFloat64Array) or packed.size() != dim * dim * 2:
		return false
	rho._from_packed(packed.duplicate(), dim)
	var conf = d.get("obs_confidence", {})
	if conf is Dictionary:
		obs_confidence = conf.duplicate()
	observe_count = int(d.get("observe_count", 0))
	return true
