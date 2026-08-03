class_name FactionDensityMatrix
extends RefCounted

## FactionDensityMatrix — mythic facade over the native QuantumMythosEngine.
##
## This file holds NO math. Every public method forwards to the native engine.
## Shape, naming, and save-format integration stay in GDScript; the
## computation lives in C++ (see native/src/mythos_graph_core.cpp).
##
## Physical meaning: the ~90 factions occupy distinct computational-basis kets
## |b₁…b₁₂⟩ of a 12-qubit Hilbert space. The player's concept state is a
## density matrix ρ on this space, support restricted to the faction span.
##
## Contract: Tr(ρ) = 1, ρ = ρ†, ρ ⪰ 0. Diagonals ρ[f,f] ∈ [0,1] = pure-alignment
## probability; off-diagonals ρ[f₁,f₂] ∈ ℂ = coherent superposition.


const AXIS_COUNT: int = 12
const DEFAULT_DECOHERENCE_TAU: float = 300.0

const NATIVE_CLASS := "QuantumMythosEngine"

var _registry: FactionRegistry = null
var _engine = null  # QuantumMythosEngine instance — always present after _init
var _names: Array = []   # mirror of engine.faction_get_names() for fast iteration
var _index: Dictionary = {}


func _init(registry: FactionRegistry = null) -> void:
	_registry = registry if registry else FactionRegistry.get_shared()
	assert(ClassDB.class_exists(NATIVE_CLASS),
		"FactionDensityMatrix requires native %s — rebuild native/" % NATIVE_CLASS)
	_engine = ClassDB.instantiate(NATIVE_CLASS)
	_load_world_into_engine()


func _load_world_into_engine() -> void:
	_engine.clear()
	_engine.configure_default_axes()
	# Pass 1: emojis with self-energies. Derived from icons.json via IconRegistry
	# so the abstract engine reads the same authority as biome H.
	var lexicon = (Engine.get_main_loop().root.get_node_or_null("/root/IconRegistry") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if lexicon == null:
		# Headless SceneTree contexts (godot --headless -s tests/*.gd) have no
		# autoloads; construct the same authority over the same icons.json.
		lexicon = load("res://Core/Factions/IconRegistry.gd").new()
	var seen_emojis: Dictionary = {}
	for f in _registry.get_all():
		var derived_se: Dictionary = lexicon.get_cloud_physics(f.cloud).get("self_energies", {})
		for emoji in f.cloud:
			if seen_emojis.has(emoji):
				continue
			seen_emojis[emoji] = true
			var se: float = float(derived_se.get(emoji, 0.0))
			_engine.add_emoji(emoji, se, 0.0)
	# Pass 2: factions
	for f in _registry.get_all():
		var bits := PackedFloat64Array()
		for b in f.get_axial_bits():
			bits.push_back(float(b))
		var cloud := PackedStringArray()
		for e in f.cloud:
			cloud.push_back(str(e))
		_engine.add_faction(str(f.name), bits, cloud)
	_engine.faction_initialize_uniform()
	# Compose the emoji-basis Hamiltonian so the eigensolver has something to
	# work with when consumers (MarketLattice projections, N menu) ask for
	# spectral data.
	_engine.compose_hamiltonian()
	# Cache names + index for callers that iterate
	_names.clear()
	_index.clear()
	for n in _engine.faction_get_names():
		_index[n] = _names.size()
		_names.append(n)


## ========================================
## Mutation API (forwards to native)
## ========================================

func pump(faction_name: String, rate: float) -> void:
	_engine.faction_pump(faction_name, rate)


func kick_coherence(name_a: String, name_b: String, re: float, im: float) -> void:
	_engine.faction_kick_coherence(name_a, name_b, re, im)


func apply_lindblad_decay(dt: float, tau: float = DEFAULT_DECOHERENCE_TAU) -> void:
	_engine.faction_apply_lindblad_decay(dt, tau)


func apply_axis_bias(axis_i: int, bit_b: int, strength: float) -> void:
	_engine.faction_apply_axis_bias(axis_i, bit_b, strength)


## ========================================
## Read API (forwards to native)
## ========================================

func get_weight(faction_name: String) -> float:
	return _engine.faction_get_weight(faction_name)


func get_coherence(name_a: String, name_b: String) -> Vector2:
	return _engine.faction_get_coherence(name_a, name_b)


func partial_trace_axis(axis_i: int) -> Dictionary:
	return _engine.faction_partial_trace_axis(axis_i)


func affinity_for_emoji(emoji: String) -> float:
	return _engine.faction_affinity_for_emoji(emoji)


func factions_speaking(emoji: String) -> Array:
	var arr: PackedStringArray = _engine.faction_factions_speaking(emoji)
	var out: Array = []
	for n in arr:
		out.append(n)
	return out


func hamming_distance(name_a: String, name_b: String) -> int:
	return _engine.faction_hamming_distance(name_a, name_b)


func get_size() -> int:
	return _engine.faction_get_size()


func get_faction_names() -> Array:
	return _names.duplicate()


func get_registry() -> FactionRegistry:
	return _registry


func get_faction_index(faction_name: String) -> int:
	return _engine.faction_get_index(faction_name)


func get_faction_bits(faction_name: String) -> PackedByteArray:
	# Bits live in the GDScript Faction record; native stores them too but the
	# GDScript callers expect PackedByteArray. Return from registry for fidelity.
	var f = _registry.get_by_name(faction_name)
	return f.get_axial_bits() if f != null else PackedByteArray()


func get_diagonal_sum() -> float:
	return _engine.faction_diagonal_sum()


func get_purity() -> float:
	return _engine.faction_purity()


func get_hamiltonian_eigen_summary(limit: int = 8) -> Dictionary:
	# Native eigensolver summary: {eigenvalues, residual, iterations,
	# used_external_backend, eigenvectors_available}. Empty summary when
	# the Hamiltonian has no emojis yet.
	return _engine.get_hamiltonian_eigen_summary(limit)


func get_principal_mode() -> Dictionary:
	# Dominant mode of ρ_factions: {ok, eigenvalue, amplitudes (length F)}.
	# amplitudes are |ψ_k|² normalized.
	return _engine.faction_principal_mode()


func get_principal_axis_projection() -> Array:
	# 12-axis projection of the dominant mode. Each value ∈ [0,1] is the
	# probability of bit=1 on that axis given the dominant eigenvector.
	# Native always returns AXIS_COUNT values (0.5s when ρ is empty).
	var packed: PackedFloat64Array = _engine.faction_principal_axis_projection()
	var out: Array = []
	for v in packed:
		out.append(float(v))
	return out


## ========================================
## Identity vocabulary — who the player is becoming
## (the soul's readback surface; see docs/glossary/soul.md)
## ========================================

# Purity bands for the identity ρ. The mixed floor for a ~90-faction support
# is ≈ 1/n ≈ 0.011, so "resolved" is a deliberate life, not a default.
# Index-aligned: BAND_THRESHOLDS[i] is the floor of BAND_KEYS[i]; the last
# band ("smeared") has no floor.
const BAND_THRESHOLDS := [0.8, 0.5, 0.2]
const BAND_KEYS := ["resolved", "leaning", "torn", "smeared"]


static func band_key(p: float) -> String:
	for i in range(BAND_THRESHOLDS.size()):
		if p >= float(BAND_THRESHOLDS[i]):
			return String(BAND_KEYS[i])
	return String(BAND_KEYS[BAND_KEYS.size() - 1])


static func band_rank(key: String) -> int:
	# Higher = more resolved. Unknown keys rank lowest.
	var i: int = BAND_KEYS.find(key)
	return (BAND_KEYS.size() - 1 - i) if i >= 0 else 0


static func band_floor(key: String) -> float:
	var i: int = BAND_KEYS.find(key)
	if i < 0 or i >= BAND_THRESHOLDS.size():
		return 0.0
	return float(BAND_THRESHOLDS[i])


func dominant_factions(k: int = 3) -> Array:
	# Top-k factions by diagonal weight ρ[f,f]: who holds the most of you.
	# Each row: {name, weight}.
	var rows: Array = []
	for n in _names:
		rows.append({"name": n, "weight": float(get_weight(str(n)))})
	rows.sort_custom(func(a, b): return float(a.weight) > float(b.weight))
	return rows.slice(0, k)


func decisive_axes(k: int = 3) -> Array:
	# The concept axes where the dominant mode has actually chosen a pole:
	# top-k by |p − 0.5|. Each row: {axis, bit, p, lean, emoji, label}.
	var projection: Array = get_principal_axis_projection()
	var rows: Array = []
	for i in range(mini(projection.size(), AXIS_COUNT)):
		var p: float = float(projection[i])
		var bit: int = 1 if p >= 0.5 else 0
		rows.append({
			"axis": i, "bit": bit, "p": p,
			"lean": absf(p - 0.5),
			"emoji": FactionAxes.pole_emoji(i, bit),
			"label": FactionAxes.pole_label(i, bit),
		})
	rows.sort_custom(func(a, b): return float(a.lean) > float(b.lean))
	return rows.slice(0, k)


func principal_graph() -> AlignmentGraph:
	# Synthetic pure product state matching the dominant mode's axis marginals:
	# ψ = ⊗_i (√(1−p_i)|0⟩ + √p_i|1⟩). The same construction the M overlay
	# ranks factions with — here it is the shared identity-side handle for
	# kinship() so every surface reads the player the same way.
	var projection: Array = get_principal_axis_projection()
	if projection.size() != AXIS_COUNT:
		return null
	var ket: Dictionary = {}
	for idx in range(AlignmentGraph.DIM):
		var amp: float = 1.0
		for i in range(AXIS_COUNT):
			var bit: int = (idx >> (AXIS_COUNT - 1 - i)) & 1
			var p: float = clampf(float(projection[i]), 0.0, 1.0)
			amp *= sqrt(p) if bit == 1 else sqrt(1.0 - p)
			if amp == 0.0:
				break
		if amp > 0.0:
			ket[idx] = Vector2(amp, 0.0)
	if ket.is_empty():
		return null
	var g := AlignmentGraph.new()
	g.weights = PackedFloat64Array([1.0])
	g.kets = [ket]
	return g


func kinship(fac) -> float:
	# How a faction sits with who you are becoming, as the GEOMETRIC MEAN of
	# per-axis agreement: raw overlap between 12-axis product states is a
	# product of per-axis overlaps (exponentially small for any disagreement),
	# so the 12th root restores an interpretable scale — 1.0 = kin on every
	# axis, 0.5 = undecided against them, 0.0 = opposed somewhere outright.
	# Returns -1.0 when unreadable.
	if fac == null or not ("alignment" in fac) or fac.alignment == null:
		return -1.0
	var g := principal_graph()
	if g == null:
		return -1.0
	var ov: float = clampf(float(fac.alignment.overlap(g)), 0.0, 1.0)
	if ov <= 0.0:
		return 0.0
	return pow(ov, 1.0 / float(AXIS_COUNT))


static func kinship_gloss(x: float) -> String:
	if x < 0.0:
		return "unread"
	if x >= 0.8:
		return "kin"
	if x >= 0.6:
		return "warm"
	if x >= 0.4:
		return "acquainted"
	if x >= 0.2:
		return "distant"
	return "opposed"


## ========================================
## Save / load (v2 format: {version, names, data})
## ========================================

func serialize() -> Dictionary:
	var raw: Dictionary = _engine.faction_serialize()
	var names_arr: Array = []
	for n in raw.get("names", PackedStringArray()):
		names_arr.append(n)
	var data_arr: Array = []
	for v in raw.get("data", PackedFloat64Array()):
		data_arr.append(v)
	return {
		"version": 2,
		"names": names_arr,
		"data": data_arr,
	}


func deserialize(data: Dictionary) -> void:
	if data == null or data.is_empty():
		_engine.faction_initialize_uniform()
		return

	assert(data.has("version") and data.has("names") and data.has("data"),
		"FactionDensityMatrix.deserialize: malformed payload, expected {version, names, data}")
	var names_packed := PackedStringArray()
	for n in data.get("names", []):
		names_packed.push_back(str(n))
	var data_packed := PackedFloat64Array()
	for v in data.get("data", []):
		data_packed.push_back(float(v))
	_engine.faction_deserialize({"names": names_packed, "data": data_packed})
