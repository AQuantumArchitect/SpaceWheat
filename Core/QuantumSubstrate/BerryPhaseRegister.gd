class_name BerryPhaseRegister
extends RefCounted

## Per-biome sim-side register tracking real Berry phase (geometric solid angle)
## accumulated by tracked qubits over the path their Bloch vectors trace.
##
## Lives on QuantumComputer; runs headless. The viz cache may mirror this for
## rendering, but the truth is here.
##
## Integration: signed solid angle of spherical triangle (ẑ, prev_b̂, cur_b̂) per
## slice (L'Huilier form). For closed loops this sums to the enclosed solid angle.
## Decoherence (|r| < BERRY_EPSILON) freezes integration. When a qubit stops
## tracking, the residual decays slowly until it falls below BERRY_RESIDUAL_MIN
## and the entry is dropped.

const BERRY_EPSILON: float = 0.05                # |r| below this freezes integration (decoherence)
const BERRY_DEFAULT_RIPE_THRESHOLD: float = TAU  # default ripeness: 2π solid angle ≈ one hemisphere
const BERRY_DECAY_PER_STEP: float = 0.0001       # ~1.5%/sec at 156 steps/sec; half-life ~47s untracked
const BERRY_RESIDUAL_MIN: float = 0.001          # below this, drop the entry

# qubit_index -> {tracked: bool, accumulated: float, prev_x/y/z: float, ripe_threshold: float}
var _state: Dictionary = {}

# Per-biome harvest counters. Incremented on consume(); never decay.
var _consumed_count: int = 0
var _consumed_phase: float = 0.0


func get_consumed_count() -> int:
	return _consumed_count


func get_consumed_phase() -> float:
	return _consumed_phase


func clear() -> void:
	_state.clear()
	_consumed_count = 0
	_consumed_phase = 0.0


func integrate_step(packed: PackedFloat64Array, num_qubits: int) -> void:
	# Path-integrate Berry phase across one evolution slice's Bloch packet.
	# Called every cursor advance (including stride-skipped slices) so closed-loop
	# accumulation is faithful regardless of observation_stride.
	if _state.is_empty():
		return
	if packed.is_empty() or num_qubits <= 0:
		return
	var stride := 8
	if packed.size() < num_qubits * stride:
		return
	var to_remove: Array = []
	for qid in _state.keys():
		if qid < 0 or qid >= num_qubits:
			continue
		var entry: Dictionary = _state[qid]
		if entry.get("tracked", false):
			var base: int = qid * stride
			var cur_x: float = packed[base + 2]
			var cur_y: float = packed[base + 3]
			var cur_z: float = packed[base + 4]
			var cur_r: float = packed[base + 5]
			# First step after start_tracking: just seed prev_bloch from this
			# slice's packet. Skip accumulation so the very first triangle isn't
			# spurious (we have no honest baseline before this slice).
			if entry.get("pending_seed", false):
				entry["prev_x"] = cur_x
				entry["prev_y"] = cur_y
				entry["prev_z"] = cur_z
				entry["pending_seed"] = false
				continue
			if cur_r >= BERRY_EPSILON:
				var prev_x: float = entry.get("prev_x", cur_x)
				var prev_y: float = entry.get("prev_y", cur_y)
				var prev_z: float = entry.get("prev_z", cur_z)
				var prev_norm: float = sqrt(prev_x * prev_x + prev_y * prev_y + prev_z * prev_z)
				if prev_norm >= BERRY_EPSILON:
					var ax: float = prev_x / prev_norm
					var ay: float = prev_y / prev_norm
					var az: float = prev_z / prev_norm
					var bx: float = cur_x / cur_r
					var by: float = cur_y / cur_r
					var bz: float = cur_z / cur_r
					# L'Huilier: Ω = 2·atan2(ẑ·(a×b), 1 + ẑ·a + a·b + b·ẑ)
					var cross_z: float = ax * by - ay * bx
					var dot_ab: float = ax * bx + ay * by + az * bz
					var denom: float = 1.0 + az + dot_ab + bz
					entry["accumulated"] = float(entry.get("accumulated", 0.0)) + 2.0 * atan2(cross_z, denom)
				entry["prev_x"] = cur_x
				entry["prev_y"] = cur_y
				entry["prev_z"] = cur_z
		else:
			var residual: float = float(entry.get("accumulated", 0.0))
			residual *= 1.0 - BERRY_DECAY_PER_STEP
			if absf(residual) < BERRY_RESIDUAL_MIN:
				to_remove.append(qid)
			else:
				entry["accumulated"] = residual
	for qid in to_remove:
		_state.erase(qid)


func start_tracking(qubit_index: int) -> void:
	# Marks the qubit for tracking. The next integration step will seed prev_bloch
	# from the actual evolved Bloch vector (no caller-provided seed needed; works
	# headless). Preserves any decaying accumulator from a prior session.
	if _state.has(qubit_index):
		var entry: Dictionary = _state[qubit_index]
		entry["tracked"] = true
		entry["pending_seed"] = true
	else:
		_state[qubit_index] = {
			"tracked": true,
			"accumulated": 0.0,
			"prev_x": 0.0,
			"prev_y": 0.0,
			"prev_z": 1.0,
			"ripe_threshold": BERRY_DEFAULT_RIPE_THRESHOLD,
			"pending_seed": true,
		}


func stop_tracking(qubit_index: int) -> void:
	if _state.has(qubit_index):
		_state[qubit_index]["tracked"] = false


func consume(qubit_index: int) -> void:
	# Harvest semantics: zero accumulator and forget the entry.
	# Bumps per-biome harvest counters that story flags can read.
	var entry = _state.get(qubit_index, null)
	if entry != null:
		_consumed_count += 1
		_consumed_phase += absf(float(entry.get("accumulated", 0.0)))
	_state.erase(qubit_index)


func is_tracked(qubit_index: int) -> bool:
	var entry = _state.get(qubit_index, null)
	return entry != null and entry.get("tracked", false)


func has_entry(qubit_index: int) -> bool:
	return _state.has(qubit_index)


func get_phase(qubit_index: int) -> float:
	var entry = _state.get(qubit_index, null)
	if entry == null:
		return 0.0
	return float(entry.get("accumulated", 0.0))


func get_ripe_threshold(qubit_index: int) -> float:
	var entry = _state.get(qubit_index, null)
	if entry == null:
		return BERRY_DEFAULT_RIPE_THRESHOLD
	return float(entry.get("ripe_threshold", BERRY_DEFAULT_RIPE_THRESHOLD))


func set_ripe_threshold(qubit_index: int, threshold: float) -> void:
	if _state.has(qubit_index):
		_state[qubit_index]["ripe_threshold"] = threshold


func is_ripe(qubit_index: int) -> bool:
	var entry = _state.get(qubit_index, null)
	if entry == null:
		return false
	var acc: float = float(entry.get("accumulated", 0.0))
	var thr: float = float(entry.get("ripe_threshold", BERRY_DEFAULT_RIPE_THRESHOLD))
	return absf(acc) >= thr


func tracked_qubits() -> Array:
	var out: Array = []
	for qid in _state.keys():
		if _state[qid].get("tracked", false):
			out.append(qid)
	return out
