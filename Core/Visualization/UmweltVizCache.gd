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
var _regs: Array = []            # per-register dicts from the trace
var _edge_w: Dictionary = {}     # undirected weight, keyed _key(i, j)


func load_trace(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return false
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
	return {
		"p0": float(r.get("p0", 0.5)), "p1": float(r.get("p1", 0.5)),
		"r_xy": float(r.get("r_xy", 0.0)), "r_bloch": float(r.get("r_bloch", 1.0)),
		"phi": float(r.get("phi", 0.0)), "theta": float(r.get("theta", 0.0)),
		"purity": float(r.get("purity", 1.0)),
	}


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
