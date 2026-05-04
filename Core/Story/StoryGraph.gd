extends RefCounted

## Container for nodes + edges + attention density.
##
## Density is a {node_id → float} map summing to 1.0 — the player faction's
## *collective* attention. The Z surface displays the argmax (or WASD-overridden)
## node, but the substrate operates on the full distribution.

var nodes: Dictionary = {}            # node_id → StoryNode
var edges: Dictionary = {}            # edge_id → StoryEdge
var outgoing: Dictionary = {}         # node_id → Array[edge_id]
var incoming: Dictionary = {}         # node_id → Array[edge_id]

var density: Dictionary = {}          # node_id → float (sums to 1)


func add_node(node) -> void:
	if node == null or node.id == "":
		return
	nodes[node.id] = node
	if not outgoing.has(node.id):
		outgoing[node.id] = []
	if not incoming.has(node.id):
		incoming[node.id] = []


func add_edge(edge) -> void:
	if edge == null or edge.id == "":
		return
	edges[edge.id] = edge
	if not outgoing.has(edge.from_node):
		outgoing[edge.from_node] = []
	if not incoming.has(edge.to_node):
		incoming[edge.to_node] = []
	if not (edge.id in outgoing[edge.from_node]):
		outgoing[edge.from_node].append(edge.id)
	if not (edge.id in incoming[edge.to_node]):
		incoming[edge.to_node].append(edge.id)


func get_node(id: String):
	return nodes.get(id, null)


func get_edge(id: String):
	return edges.get(id, null)


func get_outgoing_edges(node_id: String) -> Array:
	var out: Array = []
	for eid in outgoing.get(node_id, []):
		var e = edges.get(eid, null)
		if e != null:
			out.append(e)
	return out


## Density operations — all preserve the unit-sum invariant via renormalization.

func init_uniform_density() -> void:
	density.clear()
	if nodes.is_empty():
		return
	var w := 1.0 / float(nodes.size())
	for nid in nodes.keys():
		density[nid] = w


func init_seed_density(seed_node_id: String) -> void:
	density.clear()
	if nodes.is_empty():
		return
	# Seed node holds 0.6, rest split 0.4 evenly.
	var others := []
	for nid in nodes.keys():
		if nid != seed_node_id:
			others.append(nid)
	if not nodes.has(seed_node_id):
		init_uniform_density()
		return
	density[seed_node_id] = 0.6
	if others.size() > 0:
		var spread := 0.4 / float(others.size())
		for nid in others:
			density[nid] = spread


func argmax_node() -> String:
	var best_id := ""
	var best_w := -INF
	for nid in density:
		var w: float = density[nid]
		if w > best_w:
			best_w = w
			best_id = nid
	return best_id


## Shift mass from one node to another by `amount`. Clamps to [0, 1].
func shift_mass(from_id: String, to_id: String, amount: float) -> void:
	if amount <= 0.0 or from_id == to_id:
		return
	var from_w: float = density.get(from_id, 0.0)
	var actual := minf(amount, from_w)
	if actual <= 0.0:
		return
	density[from_id] = from_w - actual
	density[to_id] = density.get(to_id, 0.0) + actual


## Renormalize density to sum=1 (defensive — call after bulk ops).
func renormalize() -> void:
	var total := 0.0
	for nid in density:
		total += float(density[nid])
	if total <= 0.0:
		init_uniform_density()
		return
	if abs(total - 1.0) < 1e-6:
		return
	for nid in density:
		density[nid] = float(density[nid]) / total


## Coherence: 1 - normalized entropy. 1 = pure focus, 0 = uniform smear.
func coherence() -> float:
	var n := nodes.size()
	if n <= 1:
		return 1.0
	var h := 0.0
	for nid in density:
		var p: float = float(density[nid])
		if p > 1e-9:
			h -= p * log(p)
	var h_max := log(float(n))
	if h_max <= 0.0:
		return 1.0
	return clampf(1.0 - h / h_max, 0.0, 1.0)
