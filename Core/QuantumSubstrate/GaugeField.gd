class_name GaugeField
extends RefCounted

## Lattice gauge field on an arbitrary graph — the fence ledger.
##
## Each edge (i, j) carries a U(1) phase A_ij ∈ (−π, π] with A_ji = −A_ij.
## The Z₂ story is the same field restricted to {0, π} (signs u_ij = e^{iA} ∈
## {+1, −1}); use the *_sign helpers to play it as fences.
##
## The whole point, executable:
##
##   - A LOCAL gauge transformation at node i (χ_i) shifts every incident
##     edge, A_ij → A_ij + χ_i − χ_j. Half the ledger changes. Nothing
##     physical does.
##   - A CLOSED-LOOP sum W(C) = Σ_C A_ij is untouched: every χ enters twice
##     with opposite signs. The Wilson loop is the survivor — the relationship
##     around the loop was the information, never the individual fences.
##   - On a TREE there are no loops, so gauge freedom can erase every edge
##     phase (gauge_fix_tree drives all tree edges to exactly zero). Add one
##     edge that closes a cycle and one number becomes ineradicable. The
##     count of surviving numbers is the first Betti number β₁ = E − V + C:
##     topology creates the places gauge-invariant information can live.
##
## Wired per-biome via QuantumComputer.get_gauge_field(): nodes = qubits,
## edges = the NeighborhoodGraph's coherent couplings, phases seeded from
## arg(J) of the authored Hamiltonian (0 for positive real J, π for negative —
## the Z₂ sign structure of icons.json is the honest starting ledger). The
## field is a ledger ABOUT the coupling graph: player gauge moves never feed
## back into U(t), and nothing here is persisted — local conventions are
## exactly the thing that is not physical, so a reload re-seeds from H and
## every Wilson loop survives on its own. Campaign: docs/GAUGE_CAMPAIGN.md
## ("Turn the Compass", "The Fence Remembers"); audit row in FOR_PHYSICISTS.md.

# Insertion-ordered node ids (Variant keys: plot indices, biome names, ...).
var _nodes: Array = []
var _node_set: Dictionary = {}

# Edges as {a, b, phase}; canonical orientation is storage order a→b.
# Edges built from a NeighborhoodGraph also carry "ekey" (sorted emoji pair)
# so player-set phases survive qubit reindexing across substrate rebuilds.
var _edges: Array = []

# a -> {b: edge_index} for both orientations.
var _index: Dictionary = {}

# node -> accumulated local frame χ (display bookkeeping for the viz dial;
# updated by gauge_transform). node -> north emoji for rebuild carry.
var _frame: Dictionary = {}
var _node_emoji: Dictionary = {}

# Has anyone read the loop card since this field was built? Deliberately NOT
# carried across rebuilds: a changed topology voids the reading — quests that
# ask for read → flip → survived need the read on the CURRENT graph.
var inspected: bool = false


## Build from a NeighborhoodGraph's coherent edges (webway/sink excluded — a
## gauge phase on an irreversible channel would be dishonest). `carry` is a
## prior field's carry_state(): player-set edge phases and node frames keyed
## by emoji, re-applied wherever the same fences/plots still exist.
static func from_neighborhood(ng, carry: Dictionary = {}) -> GaugeField:
	var g := GaugeField.new()
	if ng == null:
		return g
	var carry_edges: Dictionary = carry.get("edges", {})
	var carry_frames: Dictionary = carry.get("frames", {})
	for n in ng.nodes:
		var q: int = int(n["qubit"])
		g.add_node(q)
		var north := str(n.get("north", ""))
		if north != "":
			g._node_emoji[q] = north
			if carry_frames.has(north):
				g._frame[q] = float(carry_frames[north])
	for e in ng.edges:
		if str(e.get("kind", "")) != "coherent":
			continue
		var a: int = int(e["from_qubit"])
		var b: int = int(e["to_qubit"])
		var ekey := GaugeField._emoji_key(str(e.get("from_emoji", "")), str(e.get("to_emoji", "")))
		var phase: float = float(carry_edges[ekey]) if carry_edges.has(ekey) else float(e.get("phase", 0.0))
		g.add_edge(a, b, phase)
		if g.has_edge(a, b):
			g._edges[int(g._index[a][b])]["ekey"] = ekey
	return g


## Everything a rebuild needs to preserve the player's bookkeeping choices:
## current edge phases keyed by emoji pair + node frames keyed by north emoji.
func carry_state() -> Dictionary:
	var edges_out: Dictionary = {}
	for e in _edges:
		if e.has("ekey"):
			edges_out[e["ekey"]] = float(e["phase"])
	var frames_out: Dictionary = {}
	for node in _frame.keys():
		if _node_emoji.has(node):
			frames_out[_node_emoji[node]] = float(_frame[node])
	return {"edges": edges_out, "frames": frames_out}


## The accumulated local frame χ at a node — how far this plot's clock dial
## has been turned. Pure display bookkeeping; physics never reads it.
func node_frame(id) -> float:
	return float(_frame.get(id, 0.0))


static func _emoji_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a <= b else "%s|%s" % [b, a]


func add_node(id) -> void:
	if _node_set.has(id):
		return
	_node_set[id] = true
	_nodes.append(id)
	_index[id] = {}


func add_edge(a, b, phase: float = 0.0) -> void:
	# Simple graph: one edge per pair; re-adding overwrites the phase.
	if a == b:
		return
	add_node(a)
	add_node(b)
	var existing: int = int(_index[a].get(b, -1))
	if existing >= 0:
		var e: Dictionary = _edges[existing]
		e["phase"] = wrapf(phase if e["a"] == a else -phase, -PI, PI)
		return
	_edges.append({"a": a, "b": b, "phase": wrapf(phase, -PI, PI)})
	var idx: int = _edges.size() - 1
	_index[a][b] = idx
	_index[b][a] = idx


func node_count() -> int:
	return _nodes.size()


func edge_count() -> int:
	return _edges.size()


func nodes() -> Array:
	return _nodes.duplicate()


func has_edge(a, b) -> bool:
	return _index.has(a) and _index[a].has(b)


func neighbors(id) -> Array:
	return _index[id].keys() if _index.has(id) else []


func degree(id) -> int:
	return _index[id].size() if _index.has(id) else 0


func edge_phase(a, b) -> float:
	# Oriented: A_ab = −A_ba. 0.0 for absent edges (no phase to report).
	if not has_edge(a, b):
		return 0.0
	var e: Dictionary = _edges[int(_index[a][b])]
	return float(e["phase"]) if e["a"] == a else -float(e["phase"])


func set_edge_sign(a, b, sign_value: int) -> void:
	# Z₂ fence: +1 → phase 0, −1 → phase π.
	add_edge(a, b, 0.0 if sign_value >= 0 else PI)


func edge_sign(a, b) -> int:
	# Z₂ reading of the fence: which half of the circle the phase sits in.
	return 1 if cos(edge_phase(a, b)) >= 0.0 else -1


func gauge_transform(node, chi: float) -> void:
	# The local move: rezero node's clock by χ. Every incident fence shifts,
	# A_ij → A_ij + χ_i − χ_j. Locally everything changed; physically nothing.
	if not _index.has(node):
		return
	_frame[node] = wrapf(float(_frame.get(node, 0.0)) + chi, -PI, PI)
	for b in _index[node].keys():
		var idx: int = int(_index[node][b])
		var e: Dictionary = _edges[idx]
		var delta: float = chi if e["a"] == node else -chi
		e["phase"] = wrapf(float(e["phase"]) + delta, -PI, PI)


func gauge_flip(node) -> void:
	# The Z₂ move: turn the sign convention around at one plot. Every fence
	# touching it flips; every closed-loop product survives (g² = 1).
	gauge_transform(node, PI)


func wilson_phase(cycle: Array) -> float:
	# Φ_C = Σ A_ij around the node cycle (last node connects back to first),
	# wrapped to (−π, π]. The gauge-invariant residue of the whole ledger.
	var n: int = cycle.size()
	if n < 3:
		return 0.0
	var total: float = 0.0
	for i in range(n):
		total += edge_phase(cycle[i], cycle[(i + 1) % n])
	return wrapf(total, -PI, PI)


func wilson_sign(cycle: Array) -> int:
	# W(C) = Π u_ij for the Z₂ fence game.
	return 1 if cos(wilson_phase(cycle)) >= 0.0 else -1


func betti_1() -> int:
	# β₁ = E − V + C: independent cycles = places invariant information lives.
	return _edges.size() - _nodes.size() + _component_count()


func fundamental_cycles() -> Array:
	# One node-cycle per non-tree edge of a BFS spanning forest. Their Wilson
	# phases are a complete gauge-invariant description of the field; the
	# array's size is betti_1().
	var forest := _spanning_forest()
	var parents: Dictionary = forest["parents"]
	var out: Array = []
	for e in _edges:
		if _is_tree_edge(parents, e["a"], e["b"]):
			continue
		out.append(_splice_cycle(parents, e["a"], e["b"]))
	return out


func gauge_fix_tree() -> Dictionary:
	# The tree lesson, executed: choose χ by BFS so every spanning-forest
	# edge becomes exactly 0 (χ_root = 0; χ_child = χ_parent + A_parent→child,
	# all read from the pre-transformation field). What cannot be erased is
	# left concentrated on the non-tree chords — one surviving number per
	# fundamental cycle, equal to that cycle's Wilson phase.
	# Returns {chi: node → χ, residual: [{a, b, phase}, ...]}.
	var forest := _spanning_forest()
	var parents: Dictionary = forest["parents"]
	var chi: Dictionary = {}
	for root in forest["roots"]:
		chi[root] = 0.0
		var queue: Array = [root]
		while not queue.is_empty():
			var cur = queue.pop_front()
			for b in _index.get(cur, {}).keys():
				if parents.get(b, null) == cur and not chi.has(b):
					chi[b] = wrapf(float(chi[cur]) + edge_phase(cur, b), -PI, PI)
					queue.append(b)
	# Apply in one pass from the frozen χ table (per-node application would
	# read half-transformed fences while computing nothing — χ is settled).
	for e in _edges:
		e["phase"] = wrapf(
			float(e["phase"]) + float(chi.get(e["a"], 0.0)) - float(chi.get(e["b"], 0.0)),
			-PI, PI)
	for node in chi.keys():
		_frame[node] = wrapf(float(_frame.get(node, 0.0)) + float(chi[node]), -PI, PI)
	var residual: Array = []
	for e in _edges:
		if _is_tree_edge(parents, e["a"], e["b"]):
			continue
		residual.append({"a": e["a"], "b": e["b"], "phase": float(e["phase"])})
	return {"chi": chi, "residual": residual}


func random_gauge(rng_seed: int) -> void:
	# Scramble every local convention (red-team helper): the test that any
	# candidate "observable" must survive to call itself gauge-invariant.
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for node in _nodes:
		gauge_transform(node, rng.randf_range(-PI, PI))


# -- internals ----------------------------------------------------------------


func _component_count() -> int:
	return _spanning_forest()["roots"].size()


func _spanning_forest() -> Dictionary:
	# BFS forest over insertion order: {parents: node → parent (roots absent),
	# roots: Array}. Deterministic for a given construction order.
	var parents: Dictionary = {}
	var visited: Dictionary = {}
	var roots: Array = []
	for start in _nodes:
		if visited.has(start):
			continue
		roots.append(start)
		visited[start] = true
		var queue: Array = [start]
		while not queue.is_empty():
			var cur = queue.pop_front()
			for b in _index.get(cur, {}).keys():
				if not visited.has(b):
					visited[b] = true
					parents[b] = cur
					queue.append(b)
	return {"parents": parents, "roots": roots}


func _is_tree_edge(parents: Dictionary, a, b) -> bool:
	return parents.get(a, null) == b or parents.get(b, null) == a


func _root_path(parents: Dictionary, node) -> Array:
	var path: Array = [node]
	var cur = node
	while parents.has(cur):
		cur = parents[cur]
		path.append(cur)
	return path


func _splice_cycle(parents: Dictionary, a, b) -> Array:
	# Tree path a→…→LCA→…→b, then the chord b→a closes it implicitly.
	var pa := _root_path(parents, a)
	var pb := _root_path(parents, b)
	var in_pa: Dictionary = {}
	for i in range(pa.size()):
		in_pa[pa[i]] = i
	var lca_i: int = pa.size() - 1
	var lca_j: int = pb.size() - 1
	for j in range(pb.size()):
		if in_pa.has(pb[j]):
			lca_i = int(in_pa[pb[j]])
			lca_j = j
			break
	var cycle: Array = []
	for i in range(lca_i + 1):        # a … LCA inclusive
		cycle.append(pa[i])
	for j in range(lca_j - 1, -1, -1):  # LCA-child … b
		cycle.append(pb[j])
	return cycle
