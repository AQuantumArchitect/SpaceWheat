class_name BridgeRegister
extends RefCounted

## The Majorana bridge bank (docs/ENGINE_FRONTIER.md, Machine 1).
##
## Each bridge is one nonlocal fermion split between two biomes: a standalone
## 2×2 density matrix over the parity basis {|even⟩, |odd⟩}, anchored to a
## qubit (a north/south atom pair) in each host biome. It lives in NEITHER
## biome's Hilbert space — that is both the physics point and the cheapness
## (no tensor-product growth; the native engine never sees it).
##
## Protection is DERIVED, not decreed: the decoherence rate is the PRODUCT of
## the two ends' local wet-noise rates,
##     Γ_bridge = KAPPA · Γ_a · Γ_b
## because no local operator can flip a nonlocal parity — the Bath needs a
## handle on BOTH ends at once. Anchor one end in closed country and the
## bridge is immortal; both ends wet gives a second-order fade, visibly
## gentler than either biome's own graying.
##
## Local rates read live per anchor atom via the host biome's viz payload
## (QuantumVizCache.get_lindblad_outgoing, summed over both poles) — coarse
## where payloads are cold (DEFAULT_WET_RATE), zero wherever is_open_here()
## is false. Story regime changes reprice every bridge on the next tick.
##
## Braiding is the only writing the bridge understands, and it is Clifford
## only — the honest Ising-anyon alphabet: braiding the end-modes at anchor A
## applies S = diag(1, i); at anchor B, √X. The two do not commute (the braid
## word matters — What Survives ch. 4 pays off here). Reading is fusion: Born
## sample the parity, collapse, and the bridge is spent. Looking kills it.
##
## Farm-owned; ticked at 20 Hz beside the soul's Lindblad decay (Farm
## _physics_process). Serialized in GameState.bridges (owner-blessed).

const KAPPA: float = 10.0             # Γ_bridge = KAPPA · Γ_a · Γ_b
const DEFAULT_WET_RATE: float = 0.05  # open-country end with no live payload data
const MAX_BRIDGES: int = 6

# Each bridge: {id, biome_a, north_a, south_a, biome_b, north_b, south_b,
#               rho: Array[8 floats: 00r,00i,01r,01i,10r,10i,11r,11i],
#               age: float, braids_a: int, braids_b: int, gamma: float}
var _bridges: Array = []
var _next_id: int = 1

# Lifetime counters (serialized) — the flag predicates read these.
var built_total: int = 0
var braids_total: int = 0
var fused_total: int = 0
var fused_odd_total: int = 0


func bridges() -> Array:
	return _bridges


func count() -> int:
	return _bridges.size()


func get_bridge(id: int) -> Dictionary:
	for b in _bridges:
		if int(b.get("id", -1)) == id:
			return b
	return {}


func bridges_at(biome_name: String) -> Array:
	var out: Array = []
	for b in _bridges:
		if str(b.get("biome_a", "")) == biome_name or str(b.get("biome_b", "")) == biome_name:
			out.append(b)
	return out


func build(anchor_a: Dictionary, anchor_b: Dictionary) -> Dictionary:
	# anchor: {biome: String, north: String, south: String}
	if _bridges.size() >= MAX_BRIDGES:
		return {"success": false, "error": "bridge_limit", "message": "The span bank holds %d bridges — fuse one first." % MAX_BRIDGES}
	var ba := str(anchor_a.get("biome", ""))
	var bb := str(anchor_b.get("biome", ""))
	if ba == "" or bb == "":
		return {"success": false, "error": "missing_anchor"}
	if ba == bb:
		return {"success": false, "error": "same_biome", "message": "A bridge needs two shores — both anchors sit in %s." % ba}
	var bridge := {
		"id": _next_id,
		"biome_a": ba,
		"north_a": str(anchor_a.get("north", "")),
		"south_a": str(anchor_a.get("south", "")),
		"biome_b": bb,
		"north_b": str(anchor_b.get("north", "")),
		"south_b": str(anchor_b.get("south", "")),
		"rho": [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],  # |even⟩⟨even|
		"age": 0.0,
		"braids_a": 0,
		"braids_b": 0,
		"gamma": 0.0,
	}
	_next_id += 1
	built_total += 1
	_bridges.append(bridge)
	return {"success": true, "id": int(bridge["id"]), "bridge": bridge}


func braid(id: int, end: String) -> Dictionary:
	# The braid alphabet: end "a" → S = diag(1, i); end "b" → √X. Clifford only —
	# that constraint is taught, not hidden.
	var bridge := get_bridge(id)
	if bridge.is_empty():
		return {"success": false, "error": "no_bridge"}
	var u: Array
	if end == "a":
		u = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0]  # diag(1, i)
		bridge["braids_a"] = int(bridge.get("braids_a", 0)) + 1
	else:
		# √X = ½ [[1+i, 1−i], [1−i, 1+i]]
		u = [0.5, 0.5, 0.5, -0.5, 0.5, -0.5, 0.5, 0.5]
		bridge["braids_b"] = int(bridge.get("braids_b", 0)) + 1
	braids_total += 1
	bridge["rho"] = _apply_unitary(bridge["rho"], u)
	return {"success": true, "id": id, "end": end, "odds": parity_odds(id)}


func fuse(id: int, roll: float) -> Dictionary:
	# Fusion: Born sample the joint parity, collapse, and spend the bridge.
	# Caller supplies the roll (randf()) so determinism policy stays theirs,
	# and pays the surprisal in its own economy.
	var bridge := get_bridge(id)
	if bridge.is_empty():
		return {"success": false, "error": "no_bridge"}
	var rho: Array = bridge.get("rho", [])
	var p_even: float = clampf(float(rho[0]), 0.0, 1.0)
	var even: bool = roll < p_even
	var p: float = p_even if even else (1.0 - p_even)
	fused_total += 1
	if not even:
		fused_odd_total += 1
	_bridges.erase(bridge)
	return {
		"success": true,
		"id": id,
		"outcome": "even" if even else "odd",
		"probability": p,
		"age": float(bridge.get("age", 0.0)),
		"braids": int(bridge.get("braids_a", 0)) + int(bridge.get("braids_b", 0)),
		"biome_a": str(bridge.get("biome_a", "")),
		"biome_b": str(bridge.get("biome_b", "")),
		"north_a": str(bridge.get("north_a", "")),
		"north_b": str(bridge.get("north_b", "")),
	}


func parity_odds(id: int) -> Dictionary:
	var bridge := get_bridge(id)
	if bridge.is_empty():
		return {}
	var rho: Array = bridge.get("rho", [])
	return {
		"even": clampf(float(rho[0]), 0.0, 1.0),
		"odd": clampf(float(rho[6]), 0.0, 1.0),
		"coherence": sqrt(float(rho[2]) * float(rho[2]) + float(rho[3]) * float(rho[3])),
	}


func tick(delta: float, farm) -> void:
	# 20 Hz beside the soul decay. Γ_bridge = KAPPA · Γ_a · Γ_b; a closed-country
	# end zeroes the product — the island is perfect anchor ground.
	if _bridges.is_empty():
		return
	for bridge in _bridges:
		var ga := _end_rate(farm, str(bridge.get("biome_a", "")), str(bridge.get("north_a", "")), str(bridge.get("south_a", "")))
		var gb := _end_rate(farm, str(bridge.get("biome_b", "")), str(bridge.get("north_b", "")), str(bridge.get("south_b", "")))
		var gamma: float = KAPPA * ga * gb
		bridge["gamma"] = gamma
		bridge["age"] = float(bridge.get("age", 0.0)) + delta
		if gamma > 0.0:
			# Parity noise as depolarizing flow toward I/2.
			var lam: float = 1.0 - exp(-gamma * delta)
			var rho: Array = bridge.get("rho", [])
			for i in range(8):
				rho[i] = float(rho[i]) * (1.0 - lam)
			rho[0] = float(rho[0]) + lam * 0.5
			rho[6] = float(rho[6]) + lam * 0.5
			bridge["rho"] = rho


func end_rate_for(farm, biome_name: String, north: String, south: String) -> float:
	return _end_rate(farm, biome_name, north, south)


func _end_rate(farm, biome_name: String, north: String, south: String) -> float:
	# The Bath's local handle on this anchor: zero in closed country (or on a
	# sleeping shore); else the anchor qubit's summed outgoing webway rates
	# from the live viz payload, DEFAULT_WET_RATE when the payload is cold.
	if farm == null or not ("grid" in farm) or farm.grid == null or not farm.grid.has_method("get_biome"):
		return 0.0
	var biome = farm.grid.get_biome(biome_name)
	if biome == null or not ("quantum_computer" in biome) or biome.quantum_computer == null:
		return 0.0
	var qc = biome.quantum_computer
	if qc.has_method("is_open_here") and not qc.is_open_here():
		return 0.0
	var rate := 0.0
	if "viz_cache" in biome and biome.viz_cache != null and biome.viz_cache.has_method("get_lindblad_outgoing"):
		for emoji in [north, south]:
			if str(emoji) == "":
				continue
			var outgoing: Dictionary = biome.viz_cache.get_lindblad_outgoing(str(emoji))
			for target in outgoing:
				rate += absf(float(outgoing[target]))
	if rate <= 0.0:
		rate = DEFAULT_WET_RATE
	return rate


func to_dict() -> Dictionary:
	var rows: Array = []
	for b in _bridges:
		rows.append(b.duplicate(true))
	return {
		"next_id": _next_id,
		"built_total": built_total,
		"braids_total": braids_total,
		"fused_total": fused_total,
		"fused_odd_total": fused_odd_total,
		"bridges": rows,
	}


func from_dict(data: Dictionary) -> void:
	_bridges.clear()
	_next_id = int(data.get("next_id", 1))
	built_total = int(data.get("built_total", 0))
	braids_total = int(data.get("braids_total", 0))
	fused_total = int(data.get("fused_total", 0))
	fused_odd_total = int(data.get("fused_odd_total", 0))
	for row in data.get("bridges", []):
		if row is Dictionary and row.has("rho"):
			_bridges.append((row as Dictionary).duplicate(true))


static func _apply_unitary(rho: Array, u: Array) -> Array:
	# ρ' = U ρ U† on packed 2×2 complex layout [00r,00i,01r,01i,10r,10i,11r,11i].
	var m := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for i in range(2):
		for j in range(2):
			var re := 0.0
			var im := 0.0
			for k in range(2):
				var ur: float = float(u[(i * 2 + k) * 2])
				var ui: float = float(u[(i * 2 + k) * 2 + 1])
				var rr: float = float(rho[(k * 2 + j) * 2])
				var ri: float = float(rho[(k * 2 + j) * 2 + 1])
				re += ur * rr - ui * ri
				im += ur * ri + ui * rr
			m[(i * 2 + j) * 2] = re
			m[(i * 2 + j) * 2 + 1] = im
	var out := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for i in range(2):
		for j in range(2):
			var re := 0.0
			var im := 0.0
			for k in range(2):
				var mr: float = float(m[(i * 2 + k) * 2])
				var mi: float = float(m[(i * 2 + k) * 2 + 1])
				# conj(U[j][k])
				var ur: float = float(u[(j * 2 + k) * 2])
				var ui: float = -float(u[(j * 2 + k) * 2 + 1])
				re += mr * ur - mi * ui
				im += mr * ui + mi * ur
			out[(i * 2 + j) * 2] = re
			out[(i * 2 + j) * 2 + 1] = im
	return out
