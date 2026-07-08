class_name QuantumVizCache
extends RefCounted

var _bloch_cache: Dictionary = {}  # qubit_index -> {p0,p1,x,y,z,r,theta,phi}
var _purity_cache: float = -1.0
var _num_qubits: int = 0
var _axes: Dictionary = {}  # qubit_index -> {north, south}
var _emoji_to_qubit: Dictionary = {}
var _emoji_to_pole: Dictionary = {}
var _emoji_list: Array = []
var _mi_values: PackedFloat64Array = PackedFloat64Array()
var _mi_num_qubits: int = 0
var _self_energies: Dictionary = {}  # emoji -> base self-energy
var _self_energy_drivers: Dictionary = {}  # emoji -> {type, frequency, phase, amplitude}
var _hamiltonian_couplings: Dictionary = {}  # emoji -> {target: strength}
var _lindblad_outgoing: Dictionary = {}  # emoji -> {target: rate}
var _sink_fluxes: Dictionary = {}  # emoji -> flux
var _icon_map: Dictionary = {}
var _icon_map_emojis: Array = []
var _icon_map_weights: PackedFloat64Array = PackedFloat64Array()
var _icon_map_by_emoji: Dictionary = {}
var _icon_map_steps: int = 0
var _icon_map_total: float = 0.0

## Biome-level ambient scalars (event-driven, NEVER recomputed per frame).
## Spectral gap is a pure function of H — set on H build/mutation. Var(H) is a
## constant of motion under unitary evolution — set on H mutation + collapse
## events + a slow active-biome backstop. -1.0 = not yet computed.
var _spectral_gap: float = -1.0
var _energy_variance: float = -1.0


func clear() -> void:
	_bloch_cache.clear()
	_purity_cache = -1.0
	_mi_values = PackedFloat64Array()
	_mi_num_qubits = 0
	_self_energies.clear()
	_self_energy_drivers.clear()
	_hamiltonian_couplings.clear()
	_lindblad_outgoing.clear()
	_sink_fluxes.clear()
	_icon_map = {}
	_icon_map_emojis.clear()
	_icon_map_weights = PackedFloat64Array()
	_icon_map_by_emoji.clear()
	_icon_map_steps = 0
	_icon_map_total = 0.0


func clear_metadata() -> void:
	_num_qubits = 0
	_axes.clear()
	_emoji_to_qubit.clear()
	_emoji_to_pole.clear()
	_emoji_list.clear()


func update_from_bloch_packet(packed: PackedFloat64Array, num_qubits: int) -> void:
	# Update cache from packed [p0,p1,x,y,z,r,theta,phi,r_xy] per qubit (stride=9).
	if packed.is_empty() or num_qubits <= 0:
		return  # Keep existing cache — don't clear on empty packet
	var stride = 9
	var expected = num_qubits * stride
	if packed.size() < expected:
		return  # Keep existing cache — packet too short
	_bloch_cache.clear()
	for q in range(num_qubits):
		var base = q * stride
		_bloch_cache[q] = {
			"p0": packed[base + 0],
			"p1": packed[base + 1],
			"x": packed[base + 2],
			"y": packed[base + 3],
			"z": packed[base + 4],
			"r": packed[base + 5],
			"theta": packed[base + 6],
			"phi": packed[base + 7],
			"r_xy": packed[base + 8],
		}


func update_purity(purity: float) -> void:
	# Floating-point rounding in native Lindblad evolution can produce Tr(ρ²) slightly
	# above 1.0 (typically 1.001). Clamp silently for small overshoot; only warn if
	# the violation is large enough to indicate a real bug.
	if purity > 1.01 or purity < -0.01:
		push_warning("QuantumVizCache: purity far out of [0,1]: %.4f — possible Tr(ρ²) invariant violation" % purity)
	_purity_cache = clampf(purity, 0.0, 1.0)


func get_purity() -> float:
	return _purity_cache


func set_biome_scalars(gap: float, var_h: float) -> void:
	_spectral_gap = gap
	_energy_variance = var_h


func get_spectral_gap() -> float:
	return _spectral_gap


func get_energy_variance() -> float:
	return _energy_variance


func update_mi_values(mi_values: PackedFloat64Array, num_qubits: int) -> void:
	_mi_values = mi_values
	_mi_num_qubits = num_qubits


func get_mutual_information(qubit_a: int, qubit_b: int) -> float:
	if _mi_values.is_empty() or _mi_num_qubits < 2:
		return 0.0
	if qubit_a == qubit_b:
		return 0.0
	var i = qubit_a
	var j = qubit_b
	if i > j:
		var tmp = i
		i = j
		j = tmp
	var idx = _mi_index(i, j, _mi_num_qubits)
	if idx < 0 or idx >= _mi_values.size():
		return 0.0
	return _mi_values[idx]


func update_couplings_from_payload(payload: Dictionary) -> void:
	# Inject Hamiltonian/Lindblad visual structure from precomputed payload.
	_self_energies = payload.get("self_energies", {}).duplicate(true)
	_self_energy_drivers = payload.get("self_energy_drivers", {}).duplicate(true)
	_hamiltonian_couplings = payload.get("hamiltonian", {}).duplicate(true)
	_lindblad_outgoing = payload.get("lindblad", {}).duplicate(true)
	_sink_fluxes = payload.get("sink_fluxes", {}).duplicate(true)


func get_self_energy(emoji: String, time: float = 0.0) -> float:
	var base = float(_self_energies.get(emoji, 0.0))
	var driver = _self_energy_drivers.get(emoji, {})
	if not driver is Dictionary or driver.is_empty():
		return base

	var driver_type = str(driver.get("type", ""))
	var frequency = float(driver.get("frequency", 0.0))
	var phase = float(driver.get("phase", 0.0))
	var amplitude = float(driver.get("amplitude", 1.0))

	match driver_type:
		"cosine":
			return base * amplitude * cos(frequency * time * TAU + phase)
		"sine":
			return base * amplitude * sin(frequency * time * TAU + phase)
		"pulse":
			var pulse_phase = fmod(frequency * time + phase / TAU, 1.0)
			return base * amplitude if pulse_phase < 0.5 else 0.0
		_:
			return base


func get_self_energies(time: float = 0.0) -> Dictionary:
	if _self_energy_drivers.is_empty():
		return _self_energies.duplicate(true)

	var out: Dictionary = {}
	for emoji in _self_energies.keys():
		out[emoji] = get_self_energy(emoji, time)
	return out


func get_self_energy_drivers() -> Dictionary:
	return _self_energy_drivers.duplicate(true)


func get_hamiltonian_couplings(emoji: String) -> Dictionary:
	return _hamiltonian_couplings.get(emoji, {})


func get_lindblad_outgoing(emoji: String) -> Dictionary:
	return _lindblad_outgoing.get(emoji, {})


func get_sink_fluxes() -> Dictionary:
	return _sink_fluxes


func update_metadata_from_payload(payload: Dictionary) -> void:
	# Inject structural metadata from payload (emoji↔qubit mapping).
	clear_metadata()
	if payload.is_empty():
		return
	_num_qubits = payload.get("num_qubits", 0)
	_axes = payload.get("axes", {}).duplicate(true)
	_emoji_to_qubit = payload.get("emoji_to_qubit", {}).duplicate(true)
	_emoji_to_pole = payload.get("emoji_to_pole", {}).duplicate(true)
	var emojis = payload.get("emoji_list", [])
	_emoji_list = emojis.duplicate() if emojis is Array else emojis


func update_icon_map(payload: Dictionary) -> void:
	# Inject IconMap payload (cumulative emoji probabilities).
	_icon_map = payload.duplicate(true)
	_icon_map_emojis = payload.get("emojis", [])
	_icon_map_weights = payload.get("weights", PackedFloat64Array())
	_icon_map_by_emoji = payload.get("by_emoji", {})
	_icon_map_steps = payload.get("steps", 0)
	_icon_map_total = payload.get("total", 0.0)


func has_metadata() -> bool:
	return _num_qubits > 0 and _axes.size() > 0


func get_num_qubits() -> int:
	return _num_qubits


func get_axis(qubit_index: int) -> Dictionary:
	return _axes.get(qubit_index, {})


func get_emojis() -> Array:
	return _emoji_list.duplicate()


func get_qubit(emoji: String) -> int:
	return _emoji_to_qubit.get(emoji, -1)


func get_pole(emoji: String) -> int:
	return _emoji_to_pole.get(emoji, -1)


func get_bloch(qubit_index: int) -> Dictionary:
	# Return full Bloch entry {p0,p1,x,y,z,r,theta,phi} or {}.
	return _bloch_cache.get(qubit_index, {})


func get_icon_map() -> Dictionary:
	return _icon_map.duplicate(true)


func get_icon_map_emojis() -> Array:
	return _icon_map_emojis.duplicate()


func get_icon_map_weights() -> PackedFloat64Array:
	return _icon_map_weights


func get_icon_map_probability(emoji: String, normalized: bool = true) -> float:
	if not _icon_map_by_emoji.has(emoji):
		return 0.0
	var weight = float(_icon_map_by_emoji[emoji])
	if normalized and _icon_map_steps > 0:
		return weight / float(_icon_map_steps)
	return weight


func get_icon_map_total() -> float:
	return _icon_map_total


func get_icon_map_steps() -> int:
	return _icon_map_steps


func _mi_index(i: int, j: int, n: int) -> int:
	# Upper-triangular packed index for i < j
	if i < 0 or j < 0 or i >= n or j >= n or i >= j:
		return -1
	# Count of pairs before row i
	var base = int(float(i * (2 * n - i - 1)) / 2.0)
	return int(base + (j - i - 1))


func get_snapshot(qubit_index: int) -> Dictionary:
	# Return {p0,p1,r_xy,phi,purity,theta,r_bloch} or {} if cache missing.
	# All values read directly from C++ bloch cache — no GDScript math.
	var bloch = _bloch_cache.get(qubit_index, {})
	if bloch.is_empty():
		return {}
	return {
		"p0": bloch.get("p0", 0.5),
		"p1": bloch.get("p1", 0.5),
		"r_xy": clampf(bloch.get("r_xy", 0.0), 0.0, 1.0),
		"r_bloch": clampf(bloch.get("r", 0.0), 0.0, 1.0),
		"phi": bloch.get("phi", 0.0),
		"theta": bloch.get("theta", PI / 2.0),
		"purity": _purity_cache,
	}
