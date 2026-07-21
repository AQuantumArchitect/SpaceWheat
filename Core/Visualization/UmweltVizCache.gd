class_name UmweltVizCache
extends RefCounted
# A viz_cache-shaped adapter over an umwelt cognifold-trace JSON, so SpaceWheat's 3D
# cognifold renderer (QuantumField3D) can draw an umwelt belief-field as a reasoning-
# transparency instrument — the SAME renderer, pointed at a reasoning trace instead of a
# farm. It presents exactly the read surface QuantumField3D consumes off `biome.viz_cache`:
#   has_metadata / get_num_qubits / get_axis(i) / get_snapshot(reg) / get_mutual_information.
#
# A belief in umwelt IS a qubit: value=(z+1)/2=p0, confidence=|r|=r_bloch, theta/phi from the
# Bloch vector, per-register purity=(1+|r|²)/2. Those are produced upstream by the umwelt
# `cognifold_trace` projection (a pure Bloch-Cartesian→spherical transform); this adapter just
# serves them. Registers are contiguous 0..n-1 (QuantumField3D iterates by index), and edge
# i/j index the same order, so `reg` here is a direct index into the trace's register list.

var world: String = ""
var _regs: Array = []            # per-register dicts from the trace (frame A)
var _edge_w: Dictionary = {}     # undirected weight, keyed _key(i, j)
var _regs_b: Array = []          # optional "next" frame (frame B) for smooth filmstrip tween
var _blend: float = 0.0          # 0 → frame A, 1 → frame B


func load_trace(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return false
	return load_frame(d)


## Swap the cache to an already-parsed trace dict IN PLACE — same object, new frame. Used by
## the filmstrip playback so QuantumField3D keeps its persistent bubbles (same biome name,
## same register count) and simply reads the new state each frame, animating the field instead
## of rebuilding it. Returns true if the frame carries registers.
func load_frame(d: Dictionary) -> bool:
	_regs_b = []          # single frame → no tween
	_blend = 0.0
	world = str(d.get("world", ""))
	_regs = d.get("registers", []) if typeof(d.get("registers")) == TYPE_ARRAY else []
	_edge_w.clear()
	for e in d.get("edges", []):
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var a := int(e.get("i", -1))
		var b := int(e.get("j", -1))
		if a < 0 or b < 0:
			continue
		# keep the strongest link if a pair appears more than once (bridge + zz, etc.)
		var k := _key(a, b)
		_edge_w[k] = maxf(float(_edge_w.get(k, 0.0)), absf(float(e.get("weight", 0.0))))
	return _regs.size() > 0


## Load a tween pair: topology/edges/gauge come from frame A; get_snapshot interpolates the
## state point A→B by set_blend(t). Frame B must have the same register count as A (same world);
## if not, we degrade to A only (no tween) rather than mis-pair indices.
func load_frame_pair(a: Dictionary, b: Dictionary) -> bool:
	var ok := load_frame(a)
	var rb = b.get("registers", []) if typeof(b.get("registers")) == TYPE_ARRAY else []
	_regs_b = rb if rb.size() == _regs.size() else []
	_blend = 0.0
	return ok


func set_blend(t: float) -> void:
	_blend = clampf(t, 0.0, 1.0)


func _key(a: int, b: int) -> int:
	return min(a, b) * 100000 + max(a, b)


# ---- viz_cache read surface (what QuantumField3D calls) ----------------------
func has_metadata() -> bool:
	return _regs.size() > 0


func get_num_qubits() -> int:
	return _regs.size()


func get_axis(i: int) -> Dictionary:
	if i < 0 or i >= _regs.size():
		return {}
	var r: Dictionary = _regs[i]
	return {"north": str(r.get("north_emoji", "")), "south": str(r.get("south_emoji", ""))}


func get_snapshot(reg: int) -> Dictionary:
	if reg < 0 or reg >= _regs.size():
		return {}
	var r: Dictionary = _regs[reg]
	if _regs_b.size() != _regs.size() or _blend <= 0.0:
		return _snap_of(r)
	return _snap_lerp(r, _regs_b[reg], _blend)


func _snap_of(r: Dictionary) -> Dictionary:
	return {
		"p0": float(r.get("p0", 0.5)), "p1": float(r.get("p1", 0.5)),
		"r_xy": float(r.get("r_xy", 0.0)), "r_bloch": float(r.get("r_bloch", 1.0)),
		"phi": float(r.get("phi", 0.0)), "theta": float(r.get("theta", 0.0)),
		"purity": float(r.get("purity", 1.0)),
	}


## Interpolate a state point A→B in BLOCH-VECTOR space (so phase wrap never glitches): build each
## Bloch vector from (theta, phi, r_bloch), lerp the vectors, then read back the angles + radius.
## Scalars (p0/p1/purity/r_xy) lerp linearly.
func _snap_lerp(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var va := _bloch_vec(a)
	var vb := _bloch_vec(b)
	var v := va.lerp(vb, t)
	var rb := v.length()
	var theta := (acos(clampf(v.z / rb, -1.0, 1.0)) if rb > 1e-9 else 0.0)
	var phi := atan2(v.y, v.x)
	return {
		"p0": lerpf(float(a.get("p0", 0.5)), float(b.get("p0", 0.5)), t),
		"p1": lerpf(float(a.get("p1", 0.5)), float(b.get("p1", 0.5)), t),
		"r_xy": lerpf(float(a.get("r_xy", 0.0)), float(b.get("r_xy", 0.0)), t),
		"r_bloch": rb,
		"phi": phi, "theta": theta,
		"purity": lerpf(float(a.get("purity", 1.0)), float(b.get("purity", 1.0)), t),
	}


func _bloch_vec(r: Dictionary) -> Vector3:
	var rb := float(r.get("r_bloch", 1.0))
	var th := float(r.get("theta", 0.0))
	var ph := float(r.get("phi", 0.0))
	var st := sin(th)
	return Vector3(st * cos(ph), st * sin(ph), cos(th)) * rb


func get_mutual_information(a: int, b: int) -> float:
	return float(_edge_w.get(_key(a, b), 0.0))


# ---- extra reasoning-transparency channels (beyond SpaceWheat's shape) -------
## Full gauge for a register: value, confidence, reliability, forecast_skill, forecast ladder.
## Not read by QuantumField3D yet; here so a richer overlay (Inc 3) can light them up.
func get_gauge(reg: int) -> Dictionary:
	if reg < 0 or reg >= _regs.size():
		return {}
	var r: Dictionary = _regs[reg]
	return {
		"node": str(r.get("node", "")), "role": str(r.get("role", "")),
		"value": float(r.get("value", r.get("p0", 0.5))),
		"confidence": float(r.get("confidence", r.get("r_bloch", 0.0))),
		"reliability": r.get("reliability", null),
		"forecast_skill": r.get("forecast_skill", null),
		"forecast": r.get("forecast", []),
	}
