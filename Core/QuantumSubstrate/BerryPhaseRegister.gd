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

## The walk (loop records for KnotRegister — docs/ENGINE_FRONTIER.md, Machine 2).
## Tracked qubits also keep a decimated polyline of their Bloch path; when the
## walk returns to its seed vertex having enclosed real solid angle, the loop
## freezes into a record that outlives harvest. Records carry the running Ω per
## vertex — the fiber coordinate of the loop's Berry-connection lift.
const LOOP_MIN_ARC: float = 0.15        # radians of arc between recorded vertices
const LOOP_MAX_POINTS: int = 128        # vertex cap; on overflow the path thins 2×
const LOOP_CLOSE_EPS: float = 0.25      # arc distance to the seed vertex that closes a loop
const LOOP_MIN_POINTS: int = 12         # vertices required before closure can fire
const LOOP_OMEGA_FLOOR: float = PI      # |solid angle| a loop must enclose to freeze (hemisphere-class; 0.5 rad scraps never close upstairs)
const FROZEN_LOOP_CAP: int = 8          # frozen records kept per biome (FIFO)

# qubit_index -> {tracked: bool, accumulated: float, prev_x/y/z: float, ripe_threshold: float,
#                 path: PackedFloat64Array (x,y,z,omega stride 4), arc_gate: float, loop_omega0: float}
var _state: Dictionary = {}

# Frozen loop records: [{qubit: int, points: PackedFloat64Array (stride 4, closed), omega: float, vertex_count: int}]
# Session-only (not serialized); survive consume() — the knot outlives the harvest.
var _frozen_loops: Array = []

# Per-biome harvest counters. Incremented on consume(); never decay.
var _consumed_count: int = 0
var _consumed_phase: float = 0.0


func get_consumed_count() -> int:
	return _consumed_count


func get_consumed_phase() -> float:
	return _consumed_phase


func restore_consumed(count: int, phase: float) -> void:
	# Save/load seam: the harvest counters are CAMPAIGN progression (the act-1
	# berry ladder and every teaching claim gate on them), so they must survive
	# a reload. The tracked-path state stays session-only on purpose —
	# re-tracking costs nothing, but a spent register never refunds its berry,
	# so losing the credit can strand a resumed run (relay wall, 2026-07-15).
	_consumed_count = maxi(0, count)
	_consumed_phase = maxf(0.0, phase)


func clear() -> void:
	_state.clear()
	_frozen_loops.clear()
	_consumed_count = 0
	_consumed_phase = 0.0


func integrate_step(packed: PackedFloat64Array, num_qubits: int) -> void:
	# Path-integrate Berry phase across one evolution slice's Bloch packet.
	# Called every cursor advance (including stride-skipped slices) so closed-loop
	# accumulation is faithful regardless of observation_stride. Stride-agnostic:
	# accepts any per-qubit layout [p0, p1, x, y, z, r, ...] with stride >= 6
	# (the live packet is stride 9 — see QuantumComputer.export_bloch_packet).
	if _state.is_empty():
		return
	if packed.is_empty() or num_qubits <= 0:
		return
	var stride: int = int(packed.size() / float(num_qubits))
	if stride < 6 or packed.size() < num_qubits * stride:
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
				_path_reset(entry)
				if cur_r >= BERRY_EPSILON:
					_path_push(entry, cur_x / cur_r, cur_y / cur_r, cur_z / cur_r)
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
					_path_advance(entry, qid, bx, by, bz)
				entry["prev_x"] = cur_x
				entry["prev_y"] = cur_y
				entry["prev_z"] = cur_z
			else:
				# Decoherence breaks the walk: below epsilon the path has no
				# well-defined continuation — the partial loop is forfeit
				# (ripeness must beat the gray; scalar residual keeps decaying
				# under the existing rules).
				_path_reset(entry)
		else:
			var residual: float = float(entry.get("accumulated", 0.0))
			residual *= 1.0 - BERRY_DECAY_PER_STEP
			if absf(residual) < BERRY_RESIDUAL_MIN:
				to_remove.append(qid)
			else:
				entry["accumulated"] = residual
	for qid in to_remove:
		_state.erase(qid)


func reseed_tracked() -> void:
	# Projective collapse cuts the walk: the Bloch vector jumps with no unitary
	# path connecting the endpoints, so geometric phase has no meaning across it.
	# Every tracked qubit re-seeds from the next evolved slice; partial loops are
	# forfeit. (Weak drains are continuous and never call this.)
	for qid in _state.keys():
		var entry: Dictionary = _state[qid]
		if entry.get("tracked", false):
			entry["pending_seed"] = true
			entry["path"] = PackedFloat64Array()


func _path_reset(entry: Dictionary) -> void:
	entry["path"] = PackedFloat64Array()
	entry["arc_gate"] = LOOP_MIN_ARC
	entry["loop_omega0"] = float(entry.get("accumulated", 0.0))


func _path_push(entry: Dictionary, bx: float, by: float, bz: float) -> void:
	var path: PackedFloat64Array = entry.get("path", PackedFloat64Array())
	path.append(bx)
	path.append(by)
	path.append(bz)
	path.append(float(entry.get("accumulated", 0.0)))
	entry["path"] = path


func _path_advance(entry: Dictionary, qid: int, bx: float, by: float, bz: float) -> void:
	# Maintain the decimated walk; freeze a loop record when the walk returns to
	# its seed vertex having enclosed real solid angle.
	var path: PackedFloat64Array = entry.get("path", PackedFloat64Array())
	if path.is_empty():
		_path_reset(entry)
		_path_push(entry, bx, by, bz)
		return
	var n: int = int(path.size() / 4.0)
	var last: int = (n - 1) * 4
	var dot_last: float = clampf(bx * path[last] + by * path[last + 1] + bz * path[last + 2], -1.0, 1.0)
	if acos(dot_last) < float(entry.get("arc_gate", LOOP_MIN_ARC)):
		return
	_path_push(entry, bx, by, bz)
	path = entry["path"]
	n += 1
	if n > LOOP_MAX_POINTS:
		# Overflow: thin every other vertex and widen the gate — long slow loops
		# stay recordable at coarser resolution.
		var thinned := PackedFloat64Array()
		for i in range(n):
			if i % 2 == 0 or i == n - 1:
				var b: int = i * 4
				thinned.append(path[b])
				thinned.append(path[b + 1])
				thinned.append(path[b + 2])
				thinned.append(path[b + 3])
		entry["path"] = thinned
		entry["arc_gate"] = float(entry.get("arc_gate", LOOP_MIN_ARC)) * 2.0
		path = thinned
		n = int(path.size() / 4.0)
	if n < LOOP_MIN_POINTS:
		return
	var dot0: float = clampf(bx * path[0] + by * path[1] + bz * path[2], -1.0, 1.0)
	if acos(dot0) > LOOP_CLOSE_EPS:
		return
	var omega: float = float(entry.get("accumulated", 0.0)) - float(entry.get("loop_omega0", 0.0))
	if absf(omega) < LOOP_OMEGA_FLOOR:
		return
	# Freeze: close the polyline onto its seed vertex and bank the record.
	var pts: PackedFloat64Array = path.duplicate()
	pts.append(path[0])
	pts.append(path[1])
	pts.append(path[2])
	pts.append(float(entry.get("accumulated", 0.0)))
	# The fiber ledger: closed on the Bloch sphere is NOT closed upstairs.
	# The lift's loose ends sit e^{iΩ/2} apart — that gap IS the holonomy.
	# A ripe loop (Ω = 2π) lands on the antipode: spinor sign reversed.
	# Only Ω ≡ 0 (mod 4π) truly closes in S³ (KnotRegister.LIFT_CLOSE_EPS).
	var holonomy: float = omega * 0.5
	var fiber_defect: float = absf(wrapf(holonomy, -PI, PI))
	_frozen_loops.append({
		"qubit": qid,
		"points": pts,
		"omega": omega,
		"vertex_count": int(pts.size() / 4.0),
		"holonomy": holonomy,
		"fiber_defect": fiber_defect,
		"closed_upstairs": fiber_defect < KnotRegister.LIFT_CLOSE_EPS,
		"spinor_flip": fiber_defect > PI - KnotRegister.LIFT_CLOSE_EPS,
	})
	while _frozen_loops.size() > FROZEN_LOOP_CAP:
		_frozen_loops.pop_front()
	_path_reset(entry)
	_path_push(entry, bx, by, bz)


func frozen_loops() -> Array:
	return _frozen_loops


func frozen_loop_count() -> int:
	return _frozen_loops.size()


func clear_frozen() -> void:
	_frozen_loops.clear()


func last_record_for(qubit_index: int) -> Dictionary:
	# Newest frozen record for this qubit (the knot that outlives harvest).
	var q: int = int(qubit_index)
	for i in range(_frozen_loops.size() - 1, -1, -1):
		var rec: Dictionary = _frozen_loops[i]
		if int(rec.get("qubit", -1)) == q:
			return rec
	return {}


func has_fiber_ledger(qubit_index: int) -> bool:
	# Live walk OR a banked loop — interfere reads either.
	return has_entry(qubit_index) or not last_record_for(qubit_index).is_empty()


func force_accumulated(qubit_index: int, phase: float) -> void:
	# Public write for the rig / tests. Do not poke _state from outside.
	start_tracking(qubit_index)
	if _state.has(qubit_index):
		_state[qubit_index]["accumulated"] = float(phase)
		_state[qubit_index]["pending_seed"] = true


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
		_state[qubit_index].erase("path")


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


func get_fiber_angle(qubit_index: int) -> float:
	# The live fiber coordinate of the walk's horizontal lift: γ = Ω/2,
	# unwrapped. What the Bloch shadow forgets and the lift remembers — the
	# angle the qubit's global phase has turned relative to where it started
	# tracking. Not locally observable; visible only RELATIONALLY, by
	# interfering against a reference that stayed home.
	# After consume() the live entry is gone; the frozen record IS the walk.
	if has_entry(qubit_index):
		return get_phase(qubit_index) * 0.5
	var rec: Dictionary = last_record_for(qubit_index)
	if rec.is_empty():
		return 0.0
	return float(rec.get("holonomy", float(rec.get("omega", 0.0)) * 0.5))


func get_spinor_sign(qubit_index: int) -> int:
	# Which hemisphere of the fiber circle the lift currently occupies:
	# +1 near e^{i·0} = +|ψ₀⟩, −1 near e^{iπ} = −|ψ₀⟩. After a ripe loop
	# (Ω = 2π) the Bloch vector is home but this reads −1: the crop came
	# back and it is NOT the same state. Two ripe loops (Ω = 4π) read +1.
	if has_entry(qubit_index):
		return 1 if cos(get_fiber_angle(qubit_index)) >= 0.0 else -1
	var rec: Dictionary = last_record_for(qubit_index)
	if rec.is_empty():
		return 1
	if rec.has("spinor_flip"):
		return -1 if bool(rec.get("spinor_flip", false)) else 1
	return 1 if cos(float(rec.get("holonomy", 0.0))) >= 0.0 else -1


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


func serialize_frozen() -> Array:
	var out: Array = []
	for rec in _frozen_loops:
		if not (rec is Dictionary):
			continue
		var pts: PackedFloat64Array = rec.get("points", PackedFloat64Array())
		var packed: Array = []
		for i in range(pts.size()):
			packed.append(float(pts[i]))
		out.append({
			"qubit": int(rec.get("qubit", -1)),
			"points": packed,
			"omega": float(rec.get("omega", 0.0)),
			"vertex_count": int(rec.get("vertex_count", 0)),
			"holonomy": float(rec.get("holonomy", 0.0)),
			"fiber_defect": float(rec.get("fiber_defect", 0.0)),
			"closed_upstairs": bool(rec.get("closed_upstairs", false)),
			"spinor_flip": bool(rec.get("spinor_flip", false)),
		})
	return out


func restore_frozen(records: Array) -> void:
	_frozen_loops.clear()
	for rec in records:
		if not (rec is Dictionary):
			continue
		var packed = rec.get("points", [])
		var pts := PackedFloat64Array()
		if packed is PackedFloat64Array:
			pts = packed
		elif packed is Array:
			for v in packed:
				pts.append(float(v))
		_frozen_loops.append({
			"qubit": int(rec.get("qubit", -1)),
			"points": pts,
			"omega": float(rec.get("omega", 0.0)),
			"vertex_count": int(rec.get("vertex_count", int(pts.size() / 4.0))),
			"holonomy": float(rec.get("holonomy", float(rec.get("omega", 0.0)) * 0.5)),
			"fiber_defect": float(rec.get("fiber_defect", 0.0)),
			"closed_upstairs": bool(rec.get("closed_upstairs", false)),
			"spinor_flip": bool(rec.get("spinor_flip", false)),
		})
	while _frozen_loops.size() > FROZEN_LOOP_CAP:
		_frozen_loops.pop_front()


func serialize_tracked() -> Array:
	var out: Array = []
	for qid in _state.keys():
		var entry: Dictionary = _state[qid]
		if not bool(entry.get("tracked", false)):
			continue
		var path: PackedFloat64Array = entry.get("path", PackedFloat64Array())
		var packed: Array = []
		for i in range(path.size()):
			packed.append(float(path[i]))
		out.append({
			"qid": int(qid),
			"accumulated": float(entry.get("accumulated", 0.0)),
			"ripe_threshold": float(entry.get("ripe_threshold", BERRY_DEFAULT_RIPE_THRESHOLD)),
			"path": packed,
			"loop_omega0": float(entry.get("loop_omega0", 0.0)),
			"arc_gate": float(entry.get("arc_gate", LOOP_MIN_ARC)),
		})
	return out


func restore_tracked(records: Array) -> void:
	for rec in records:
		if not (rec is Dictionary):
			continue
		var qid: int = int(rec.get("qid", -1))
		if qid < 0:
			continue
		var packed = rec.get("path", [])
		var path := PackedFloat64Array()
		if packed is PackedFloat64Array:
			path = packed
		elif packed is Array:
			for v in packed:
				path.append(float(v))
		_state[qid] = {
			"tracked": true,
			"accumulated": float(rec.get("accumulated", 0.0)),
			"prev_x": 0.0,
			"prev_y": 0.0,
			"prev_z": 1.0,
			"ripe_threshold": float(rec.get("ripe_threshold", BERRY_DEFAULT_RIPE_THRESHOLD)),
			"pending_seed": true,  # next live slice reseeds; do not invent a triangle across the save cut
			"path": path,
			"loop_omega0": float(rec.get("loop_omega0", 0.0)),
			"arc_gate": float(rec.get("arc_gate", LOOP_MIN_ARC)),
		}
