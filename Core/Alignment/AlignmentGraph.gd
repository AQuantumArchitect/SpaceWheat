class_name AlignmentGraph
extends RefCounted

## AlignmentGraph — 12-qubit density matrix on the FactionAxes Hilbert space.
##
## One substrate, one ontology. Used by:
##   - factions (initialized at corner state |bits⟩⟨bits| from FactionAxes bits)
##   - the player (initialized as |+⟩^⊗12 — equal superposition, no preferred pole)
##
## Storage is low-rank: ρ = Σₖ weights[k] · |kets[k]⟩⟨kets[k]|
## Each ket is sparse: Dictionary[int basis_index → Vector2(re, im)].
##
## The full dense ρ would be 4096×4096; we never materialize it. Operations
## (rotation, Lindblad jump toward a target, partial trace, overlap kernel) all
## act directly on the low-rank components. Rank is compacted after mixing
## operations (default cap K_MAX = 16) so storage stays bounded under
## continuous evolution.
##
## Bit convention matches Faction.bits: index 0 is the highest (MSB) bit, so
## basis_index = (bits[0] << 11) | (bits[1] << 10) | ... | bits[11].
## This keeps |bits⟩ ↔ basis_index round-trip identical to the existing
## faction encoding.

const AXIS_COUNT: int = 12
const DIM: int = 4096  # 2^12
const K_MAX: int = 16
const WEIGHT_FLOOR: float = 1e-6
const AMP_FLOOR_SQ: float = 1e-20

var weights: PackedFloat64Array = PackedFloat64Array()
var kets: Array = []  # Array[Dictionary[int → Vector2]]


func _init() -> void:
	weights = PackedFloat64Array()
	kets = []


# ---------------- constructors ----------------

static func from_corner(bits) -> RefCounted:
	var idx := _bits_to_index(bits)
	var g = load("res://Core/Alignment/AlignmentGraph.gd").new()
	g.weights = PackedFloat64Array([1.0])
	g.kets = [{idx: Vector2(1.0, 0.0)}]
	return g


static func from_uniform_superposition() -> RefCounted:
	var amp := 1.0 / sqrt(float(DIM))
	var ket: Dictionary = {}
	for i in range(DIM):
		ket[i] = Vector2(amp, 0.0)
	var g = load("res://Core/Alignment/AlignmentGraph.gd").new()
	g.weights = PackedFloat64Array([1.0])
	g.kets = [ket]
	return g


# ---------------- bit helpers ----------------

static func _bits_to_index(bits) -> int:
	assert(bits.size() == AXIS_COUNT,
		"AlignmentGraph: bits must be length %d, got %d" % [AXIS_COUNT, bits.size()])
	var idx := 0
	for i in range(AXIS_COUNT):
		idx = (idx << 1) | (int(bits[i]) & 1)
	return idx


static func _index_to_bits(idx: int) -> PackedByteArray:
	var bits := PackedByteArray()
	bits.resize(AXIS_COUNT)
	for i in range(AXIS_COUNT):
		bits[i] = (idx >> (AXIS_COUNT - 1 - i)) & 1
	return bits


# ---------------- diagonal access ----------------

func diagonal_weight(idx: int) -> float:
	var s := 0.0
	for k in range(weights.size()):
		var ket: Dictionary = kets[k]
		var a: Vector2 = ket.get(idx, Vector2.ZERO)
		s += weights[k] * (a.x * a.x + a.y * a.y)
	return s


func corner_weight(bits) -> float:
	return diagonal_weight(_bits_to_index(bits))


# ---------------- partial trace over all axes except axis_i ----------------
# Returns 2x2 reduced density: {p0, p1, off: Vector2 = ρ[0,1]}
func partial_trace_axis(axis_i: int) -> Dictionary:
	assert(axis_i >= 0 and axis_i < AXIS_COUNT)
	var bit_pos := AXIS_COUNT - 1 - axis_i
	var mask := 1 << bit_pos
	var p0 := 0.0
	var p1 := 0.0
	var off := Vector2.ZERO
	for k in range(weights.size()):
		var w: float = weights[k]
		var ket: Dictionary = kets[k]
		# Sum amplitudes paired by their "rest" bits (everything except axis_i).
		var paired: Dictionary = {}
		for idx_v in ket:
			var idx: int = int(idx_v)
			var amp: Vector2 = ket[idx]
			var bit: int = (idx >> bit_pos) & 1
			var rest: int = idx & ~mask
			if not paired.has(rest):
				paired[rest] = [Vector2.ZERO, Vector2.ZERO]
			paired[rest][bit] = amp
		for rest in paired:
			var a0: Vector2 = paired[rest][0]
			var a1: Vector2 = paired[rest][1]
			p0 += w * (a0.x * a0.x + a0.y * a0.y)
			p1 += w * (a1.x * a1.x + a1.y * a1.y)
			# ρ_axis[0,1] += w · a0 · conj(a1)
			off.x += w * (a0.x * a1.x + a0.y * a1.y)
			off.y += w * (a0.y * a1.x - a0.x * a1.y)
	return {"p0": p0, "p1": p1, "off": off}


# Marginal probability of bit b (0 or 1) on axis_i.
func axis_marginal(axis_i: int, bit_value: int) -> float:
	var pt := partial_trace_axis(axis_i)
	return pt.p0 if bit_value == 0 else pt.p1


# Project to bits via per-axis majority vote on the reduced ρ.
func principal_bits() -> PackedByteArray:
	var bits := PackedByteArray()
	bits.resize(AXIS_COUNT)
	for i in range(AXIS_COUNT):
		var pt := partial_trace_axis(i)
		bits[i] = 1 if pt.p1 > pt.p0 else 0
	return bits


# ---------------- overlap (market kernel) ----------------
# Tr(ρ_self · ρ_other) = Σᵢⱼ wᵢ · qⱼ · |⟨ψᵢ|φⱼ⟩|²
func overlap(other) -> float:
	if other == null:
		return 0.0
	var s := 0.0
	for i in range(weights.size()):
		var ki: Dictionary = kets[i]
		var wi: float = weights[i]
		for j in range(other.weights.size()):
			var kj: Dictionary = other.kets[j]
			var wj: float = other.weights[j]
			# inner = ⟨ψᵢ|φⱼ⟩ = Σ conj(ki[idx]) · kj[idx]
			var inner := Vector2.ZERO
			var small: Dictionary = ki if ki.size() <= kj.size() else kj
			for idx in small:
				if not kj.has(idx) or not ki.has(idx):
					continue
				var a: Vector2 = ki[idx]
				var b: Vector2 = kj[idx]
				inner.x += a.x * b.x + a.y * b.y
				inner.y += a.x * b.y - a.y * b.x
			s += wi * wj * (inner.x * inner.x + inner.y * inner.y)
	return s


# ---------------- evolution: Lindblad jump toward target ----------------
# ρ ← (1-r)·ρ + r·ρ_target, implemented via low-rank concatenation + compact.
func lindblad_jump_toward(target, rate: float) -> void:
	rate = clampf(rate, 0.0, 1.0)
	if rate <= 0.0 or target == null or target.weights.is_empty():
		return
	var new_weights := PackedFloat64Array()
	var new_kets: Array = []
	for k in range(weights.size()):
		new_weights.append(weights[k] * (1.0 - rate))
		new_kets.append(kets[k])
	for k in range(target.weights.size()):
		new_weights.append(target.weights[k] * rate)
		new_kets.append(target.kets[k])
	weights = new_weights
	kets = new_kets
	_compact()


# ---------------- evolution: per-axis RY rotation ----------------
# Apply RY(θ) on axis_i to every ket. RY = [[c, -s], [s, c]] with c=cos(θ/2), s=sin(θ/2).
# Pure rotation: norm-preserving, no rank growth.
func rotate_axis(axis_i: int, theta: float) -> void:
	assert(axis_i >= 0 and axis_i < AXIS_COUNT)
	var bit_pos := AXIS_COUNT - 1 - axis_i
	var mask := 1 << bit_pos
	var c := cos(theta * 0.5)
	var s := sin(theta * 0.5)
	for k in range(kets.size()):
		var ket: Dictionary = kets[k]
		var new_ket: Dictionary = {}
		var visited: Dictionary = {}
		for idx_v in ket:
			var idx: int = int(idx_v)
			if visited.has(idx):
				continue
			var partner: int = idx ^ mask
			visited[idx] = true
			visited[partner] = true
			var bit_this: int = (idx >> bit_pos) & 1
			var idx0: int = idx if bit_this == 0 else partner
			var idx1: int = partner if bit_this == 0 else idx
			var a0: Vector2 = ket.get(idx0, Vector2.ZERO)
			var a1: Vector2 = ket.get(idx1, Vector2.ZERO)
			var n0 := Vector2(c * a0.x - s * a1.x, c * a0.y - s * a1.y)
			var n1 := Vector2(s * a0.x + c * a1.x, s * a0.y + c * a1.y)
			if n0.x * n0.x + n0.y * n0.y > AMP_FLOOR_SQ:
				new_ket[idx0] = n0
			if n1.x * n1.x + n1.y * n1.y > AMP_FLOOR_SQ:
				new_ket[idx1] = n1
		kets[k] = new_ket


# ---------------- bookkeeping ----------------

func trace() -> float:
	var t := 0.0
	for k in range(weights.size()):
		var ket: Dictionary = kets[k]
		var n2 := 0.0
		for idx in ket:
			var a: Vector2 = ket[idx]
			n2 += a.x * a.x + a.y * a.y
		t += weights[k] * n2
	return t


func purity() -> float:
	return overlap(self)


func rank() -> int:
	return weights.size()


func _compact() -> void:
	# Drop near-zero-weight components, renormalize Σw = 1, cap rank at K_MAX
	# by dropping the smallest-weight components and rescaling the rest.
	var keep_w := PackedFloat64Array()
	var keep_k: Array = []
	for k in range(weights.size()):
		if weights[k] >= WEIGHT_FLOOR:
			keep_w.append(weights[k])
			keep_k.append(kets[k])
	weights = keep_w
	kets = keep_k
	while weights.size() > K_MAX:
		var min_idx := 0
		for k in range(1, weights.size()):
			if weights[k] < weights[min_idx]:
				min_idx = k
		weights.remove_at(min_idx)
		kets.remove_at(min_idx)
	var total := 0.0
	for k in range(weights.size()):
		total += weights[k]
	if total > 0.0:
		for k in range(weights.size()):
			weights[k] = weights[k] / total


# ---------------- serialization (save v3) ----------------

func to_dict() -> Dictionary:
	var ket_data: Array = []
	for k in range(kets.size()):
		var entries: Array = []
		var ket: Dictionary = kets[k]
		for idx in ket:
			var a: Vector2 = ket[idx]
			entries.append([idx, a.x, a.y])
		ket_data.append(entries)
	return {
		"version": 1,
		"axis_count": AXIS_COUNT,
		"weights": Array(weights),
		"kets": ket_data,
	}


static func from_dict(d: Dictionary) -> RefCounted:
	var g = load("res://Core/Alignment/AlignmentGraph.gd").new()
	if d == null or d.is_empty():
		return g
	var axis_count := int(d.get("axis_count", AXIS_COUNT))
	assert(axis_count == AXIS_COUNT,
		"AlignmentGraph: save axis_count=%d, expected %d" % [axis_count, AXIS_COUNT])
	var w_arr: Array = d.get("weights", [])
	g.weights = PackedFloat64Array(w_arr)
	g.kets = []
	for entries in d.get("kets", []):
		var ket: Dictionary = {}
		for e in entries:
			ket[int(e[0])] = Vector2(float(e[1]), float(e[2]))
		g.kets.append(ket)
	return g


func _to_string() -> String:
	return "AlignmentGraph(rank=%d trace=%.4f purity=%.4f)" % [rank(), trace(), purity()]
