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

const FactionRegistry = preload("res://Core/Factions/FactionRegistry.gd")

const AXIS_COUNT: int = 12
const DEFAULT_DECOHERENCE_TAU: float = 300.0

const NATIVE_CLASS := "QuantumMythosEngine"

var _registry: FactionRegistry = null
var _engine = null  # QuantumMythosEngine instance — always present after _init
var _names: Array = []   # mirror of engine.faction_get_names() for fast iteration
var _index: Dictionary = {}


func _init(registry: FactionRegistry = null) -> void:
	_registry = registry if registry else FactionRegistry.new()
	assert(ClassDB.class_exists(NATIVE_CLASS),
		"FactionDensityMatrix requires native %s — rebuild native/" % NATIVE_CLASS)
	_engine = ClassDB.instantiate(NATIVE_CLASS)
	_load_world_into_engine()


func _load_world_into_engine() -> void:
	_engine.clear()
	_engine.configure_default_axes()
	# Pass 1: emojis with self-energies
	var seen_emojis: Dictionary = {}
	for f in _registry.get_all():
		for emoji in f.signature:
			if seen_emojis.has(emoji):
				continue
			seen_emojis[emoji] = true
			var se: float = 0.0
			if f.self_energies.has(emoji):
				se = float(f.self_energies[emoji])
			_engine.add_emoji(emoji, se, 0.0)
	# Pass 2: factions
	for f in _registry.get_all():
		var bits := PackedFloat64Array()
		for b in f.get_axial_bits():
			bits.push_back(float(b))
		var sig := PackedStringArray()
		for e in f.signature:
			sig.push_back(str(e))
		_engine.add_faction(str(f.name), bits, sig)
	_engine.faction_initialize_uniform()
	# Compose the emoji-basis Hamiltonian so the eigensolver has something to
	# work with when consumers (ContractMarket, N menu) ask for spectral data.
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

	if data.has("version") and data.has("names") and data.has("data"):
		# v2 payload: pass through.
		var names_packed := PackedStringArray()
		for n in data.get("names", []):
			names_packed.push_back(str(n))
		var data_packed := PackedFloat64Array()
		for v in data.get("data", []):
			data_packed.push_back(float(v))
		_engine.faction_deserialize({"names": names_packed, "data": data_packed})
		return

	# v1 legacy: flat {faction_name: float} diagonal dict. Build a degenerate
	# v2 payload (diagonal-only, off-diagonals zero) and pass through.
	var n: int = _names.size()
	if n == 0:
		_engine.faction_initialize_uniform()
		return
	var names_packed := PackedStringArray()
	var data_packed := PackedFloat64Array()
	data_packed.resize(2 * n * n)
	var total: float = 0.0
	for i in range(n):
		var fname = _names[i]
		var w: float = maxf(float(data.get(fname, 0.0)), 0.0)
		names_packed.push_back(fname)
		data_packed[2 * (i * n + i)] = w
		total += w
	if total <= 0.0:
		_engine.faction_initialize_uniform()
		return
	_engine.faction_deserialize({"names": names_packed, "data": data_packed})
