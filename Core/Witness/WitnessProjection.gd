class_name WitnessProjection
extends RefCounted

## Projections of the Witness's belief field — the READ side, cheap by law
## (umwelt graph_state never rebuilds a density matrix; neither does this).
##
##   graph_state(organ)  → umwelt graph_state v1-compatible dict: the graph a
##                         small LLM navigates by (nodes/edges/organs/globals),
##                         with emoji glyphs per role (SpaceWheat and umwelt
##                         share the emoji projection language natively).
##   gauge(organ)        → diff-stable snapshot (sorted keys, 6dp): two gauges
##                         with no input between them are byte-identical, so an
##                         empty diff PROVES the Witness didn't learn.

const COHERENCE_THRESHOLD := 0.3   # |xy| above this shows the coherent glyph
const POLE_THRESHOLD := 0.3        # |z| above this shows pos/neg glyph


static func glyph_for(emoji_map: Dictionary, bloch: Vector3) -> String:
	var primary: String
	if bloch.z > POLE_THRESHOLD:
		primary = str(emoji_map.get("pos", "🔵"))
	elif bloch.z < -POLE_THRESHOLD:
		primary = str(emoji_map.get("neg", "🔴"))
	else:
		primary = str(emoji_map.get("zero", "⚪"))
	var r_xy := sqrt(bloch.x * bloch.x + bloch.y * bloch.y)
	if r_xy > COHERENCE_THRESHOLD:
		primary += str(emoji_map.get("coherent", "💠"))
	return primary


static func _node_entry(organ, node_spec: Dictionary, node_name: String, depth: int,
		parent: String, children: Array, compact: bool) -> Dictionary:
	var roles: Array = []
	for r in node_spec.get("roles", []):
		roles.append(str(r))
	var entry := {
		"path": "/witness" if node_name == "witness" else "/witness/%s" % node_name,
		"name": node_name,
		"kind": str(node_spec.get("kind", "region")),
		"depth": depth,
		"is_leaf": children.is_empty(),
		"parent": parent if not parent.is_empty() else null,
		"children": children,
		"roles": roles,
		"grid_pos": node_spec.get("grid_pos", [0, 0]),
		"organs": [],
	}
	var cluster = organ.clusters.get(node_name)
	if cluster != null:
		var emoji_maps = node_spec.get("emoji", {})
		var bloch := {}
		var glyphs := {}
		for role in roles:
			var b: Vector3 = cluster.role_bloch(role)
			if compact and sqrt(b.x * b.x + b.y * b.y) < 0.1:
				bloch[role] = [0.0, 0.0, snappedf(b.z, 0.001)]
			else:
				bloch[role] = [snappedf(b.x, 0.001), snappedf(b.y, 0.001), snappedf(b.z, 0.001)]
			glyphs[role] = glyph_for(emoji_maps.get(role, {}), b)
		var cluster_organ := {
			"type": "bloch_cluster",
			"n_qubits": cluster.n_qubits,
			"purity": snappedf(cluster.purity(), 0.001),
			"bloch": bloch,
			"glyphs": glyphs,
		}
		if not cluster.obs_confidence.is_empty():
			var conf := {}
			for role in cluster.obs_confidence:
				conf[role] = snappedf(float(cluster.obs_confidence[role]), 0.001)
			cluster_organ["obs_confidence"] = conf
		entry["organs"].append(cluster_organ)
	return entry


## umwelt graph_state v1 schema. compact mode targets <2KB for haiku context:
## 3dp, coherence-gated x/y, and a hard node cap with an explicit marker.
static func graph_state(organ, compact: bool = true, max_biome_nodes: int = 12) -> Dictionary:
	var spec: Dictionary = organ.spec
	var biome_names: Array = []
	for cname in organ.clusters:
		if str(cname).begins_with("biome:"):
			biome_names.append(str(cname))
	biome_names.sort()
	var truncated := false
	if biome_names.size() > max_biome_nodes:
		biome_names = biome_names.slice(0, max_biome_nodes)
		truncated = true

	var children := ["self"]
	children.append_array(biome_names)
	var nodes := [
		_node_entry(organ, WitnessSpec.find_node(spec, "witness"), "witness", 0, "", children, compact),
		_node_entry(organ, WitnessSpec.find_node(spec, "self"), "self", 1, "witness", [], compact),
	]
	var tpl := WitnessSpec.template_node(spec)
	for bname in biome_names:
		nodes.append(_node_entry(organ, tpl, bname, 1, "witness", [], compact))

	var edges := []
	for bridge in spec.get("bridges", []):
		if bool(bridge.get("per_instance", false)):
			for bname in biome_names:
				edges.append({
					"source": str(bridge.get("source", "")),
					"target": bname,
					"kind": str(bridge.get("kind", "open")),
					"shared_roles": bridge.get("shared_roles", []),
					"weight": float(bridge.get("weight", 0.0)),
					"is_tendril": false,
				})

	var out := {
		"version": 1,
		"topology": {"nodes": nodes, "edges": edges},
		"globals": [
			{"type": "ingest", "unmatched": organ.unmatched_snapshot()},
			{"type": "summary",
				"clusters": organ.clusters.size(),
				"qubits": organ.total_qubits(),
				"observes": organ.observes_total,
				"last_stride_ms": snappedf(organ.last_stride_ms, 0.01)},
		],
	}
	if truncated:
		out["truncated"] = true
	return out


## Diff-stable gauge: alphabetical cluster order, alphabetical roles, 6dp.
## Byte-identical across runs with identical belief state — the "verified
## learning" seam (empty git diff = didn't learn).
static func gauge(organ) -> Dictionary:
	var cluster_names := []
	for cname in organ.clusters:
		cluster_names.append(str(cname))
	cluster_names.sort()
	var clusters := {}
	for cname in cluster_names:
		var cluster = organ.clusters[cname]
		var sorted_roles: Array = cluster.roles.duplicate()
		sorted_roles.sort()
		var bloch := {}
		for role in sorted_roles:
			var b: Vector3 = cluster.role_bloch(role)
			bloch[role] = [snappedf(b.x, 0.000001), snappedf(b.y, 0.000001), snappedf(b.z, 0.000001)]
		var entry := {
			"bloch": bloch,
			"purity": snappedf(cluster.purity(), 0.000001),
			"roles": sorted_roles,
		}
		if not cluster.obs_confidence.is_empty():
			var conf := {}
			var conf_roles: Array = cluster.obs_confidence.keys()
			conf_roles.sort()
			for role in conf_roles:
				conf[role] = snappedf(float(cluster.obs_confidence[role]), 0.000001)
			entry["obs_confidence"] = conf
		clusters[cname] = entry
	return {
		"spec_hash": WitnessSpec.spec_hash(organ.spec),
		"clusters": clusters,
		"observes_total": organ.observes_total,
	}
