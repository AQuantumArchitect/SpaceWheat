class_name QuantumProjectionBuilder
extends RefCounted

const QuantumVisualGrammar = preload("res://Core/Visualization/QuantumVisualGrammar.gd")

## Builds semantic projection bodies for the quantum graph.
##
## This is intentionally pure data shaping. It does not draw and does not query
## the quantum computer directly. Feed it cached viz payloads and current nodes;
## renderers can consume the returned bodies later.

const BASIS_REGISTER := "register"
const BASIS_SELF_ENERGY := "self_energy"


func build_register_projection(nodes: Array) -> Dictionary:
	var registers: Array = []
	for node in nodes:
		if not node or not node.visible:
			continue
		registers.append(_node_record(node))

	return {
		"basis": BASIS_REGISTER,
		"anchor_emoji": "",
		"channels": [
			QuantumVisualGrammar.CHANNEL_BUBBLE_RADIUS,
			QuantumVisualGrammar.CHANNEL_BUBBLE_EMOJI_OPACITY,
			QuantumVisualGrammar.CHANNEL_BUBBLE_COLOR_PHASE,
			QuantumVisualGrammar.CHANNEL_BUBBLE_PHASE_ARC,
			QuantumVisualGrammar.CHANNEL_BUBBLE_PURITY_RING,
			QuantumVisualGrammar.CHANNEL_BUBBLE_UNCERTAINTY_RING,
		],
		"clusters": [],
		"contours": [],
		"edges": [],
		"flows": [],
		"registers": registers,
	}


func build_self_energy_projection(
	nodes: Array,
	self_energies: Dictionary,
	hamiltonian_couplings: Dictionary = {},
	anchor_emoji: String = "",
	band_count: int = 5
) -> Dictionary:
	var visible_nodes := _visible_nodes(nodes)
	if visible_nodes.is_empty():
		return _empty_projection(BASIS_SELF_ENERGY, anchor_emoji)

	var energy_records: Array = []
	var min_energy := INF
	var max_energy := -INF
	for node in visible_nodes:
		var energy := _node_average_self_energy(node, self_energies)
		min_energy = minf(min_energy, energy)
		max_energy = maxf(max_energy, energy)
		energy_records.append({
			"node": node,
			"energy": energy,
			"coupling": _node_anchor_coupling(node, hamiltonian_couplings, anchor_emoji),
		})

	var span = maxf(max_energy - min_energy, 0.0001)
	var bins: Dictionary = {}
	var safe_band_count = maxi(1, band_count)

	for record in energy_records:
		var normalized = clampf((record.energy - min_energy) / span, 0.0, 0.9999)
		var band = int(floor(normalized * safe_band_count))
		if not bins.has(band):
			bins[band] = []
		bins[band].append(record)

	var clusters: Array = []
	var contours: Array = []
	var sorted_bands := bins.keys()
	sorted_bands.sort()
	for band in sorted_bands:
		var members: Array = bins[band]
		var cluster := _cluster_from_records(
			"self_energy:%s:%d" % [anchor_emoji, band],
			members,
			min_energy,
			max_energy,
			band,
			safe_band_count,
			anchor_emoji
		)
		clusters.append(cluster)
		contours.append(_contour_from_cluster(cluster))

	var registers: Array = []
	for record in energy_records:
		var node_record = _node_record(record.node)
		node_record["self_energy"] = record.energy
		node_record["anchor_coupling"] = record.coupling
		registers.append(node_record)

	return {
		"basis": BASIS_SELF_ENERGY,
		"anchor_emoji": anchor_emoji,
		"channels": [
			QuantumVisualGrammar.CHANNEL_FIELD_SELF_ENERGY_CONTOUR,
			QuantumVisualGrammar.CHANNEL_EDGE_HAMILTONIAN_STRAND,
			QuantumVisualGrammar.CHANNEL_EDGE_MUTUAL_INFORMATION,
		],
		"min_energy": min_energy,
		"max_energy": max_energy,
		"clusters": clusters,
		"contours": contours,
		"edges": _hamiltonian_edges_from_records(energy_records, hamiltonian_couplings),
		"flows": [],
		"registers": registers,
	}


func build_self_energy_projection_from_cache(
	nodes: Array,
	viz_cache,
	anchor_emoji: String = "",
	time: float = 0.0,
	band_count: int = 5
) -> Dictionary:
	if not viz_cache:
		return _empty_projection(BASIS_SELF_ENERGY, anchor_emoji)

	var self_energies: Dictionary = {}
	if viz_cache.has_method("get_self_energies"):
		self_energies = viz_cache.get_self_energies(time)

	var hamiltonian_couplings: Dictionary = {}
	if viz_cache.has_method("get_hamiltonian_couplings"):
		var emojis := _projection_emojis(nodes, anchor_emoji)
		for emoji in emojis:
			hamiltonian_couplings[emoji] = viz_cache.get_hamiltonian_couplings(emoji)

	return build_self_energy_projection(
		nodes,
		self_energies,
		hamiltonian_couplings,
		anchor_emoji,
		band_count
	)


func _empty_projection(basis: String, anchor_emoji: String) -> Dictionary:
	return {
		"basis": basis,
		"anchor_emoji": anchor_emoji,
		"channels": [],
		"clusters": [],
		"contours": [],
		"edges": [],
		"flows": [],
		"registers": [],
	}


func _visible_nodes(nodes: Array) -> Array:
	var out: Array = []
	for node in nodes:
		if node and node.visible:
			out.append(node)
	return out


func _projection_emojis(nodes: Array, anchor_emoji: String = "") -> Array:
	var seen: Dictionary = {}
	if anchor_emoji != "":
		seen[anchor_emoji] = true
	for node in nodes:
		if not node:
			continue
		if node.emoji_north != "":
			seen[node.emoji_north] = true
		if node.emoji_south != "":
			seen[node.emoji_south] = true
	return seen.keys()


func _node_record(node) -> Dictionary:
	return {
		"id": str(node.get_instance_id()),
		"type": "register",
		"biome_name": node.biome_name,
		"register_id": node.register_id,
		"grid_position": node.grid_position,
		"position": node.position,
		"radius": node.radius,
		"energy": node.energy,
		"coherence": node.coherence,
		"phase": node.phi_raw,
		"emoji_north": node.emoji_north,
		"emoji_south": node.emoji_south,
		"channels": [
			QuantumVisualGrammar.CHANNEL_BUBBLE_RADIUS,
			QuantumVisualGrammar.CHANNEL_BUBBLE_EMOJI_OPACITY,
			QuantumVisualGrammar.CHANNEL_BUBBLE_COLOR_PHASE,
			QuantumVisualGrammar.CHANNEL_BUBBLE_PHASE_ARC,
		],
	}


func _cluster_from_records(
	cluster_id: String,
	records: Array,
	min_energy: float,
	max_energy: float,
	band: int,
	band_count: int,
	anchor_emoji: String
) -> Dictionary:
	var center := Vector2.ZERO
	var energy_sum := 0.0
	var coupling_sum := 0.0
	var members: Array = []

	for record in records:
		var node = record.node
		center += node.position
		energy_sum += float(record.energy)
		coupling_sum += float(record.coupling)
		members.append(str(node.get_instance_id()))

	var count = max(records.size(), 1)
	center /= float(count)

	return {
		"id": cluster_id,
		"type": "cluster",
		"basis": BASIS_SELF_ENERGY,
		"anchor_emoji": anchor_emoji,
		"band": band,
		"band_count": band_count,
		"center": center,
		"radius": 36.0 + sqrt(float(count)) * 18.0,
		"energy": energy_sum / float(count),
		"energy_min": min_energy,
		"energy_max": max_energy,
		"anchor_coupling": coupling_sum / float(count),
		"members": members,
		"children": [],
		"lod": _cluster_lod(count),
		"channel": QuantumVisualGrammar.CHANNEL_FIELD_SELF_ENERGY_CONTOUR,
	}


func _contour_from_cluster(cluster: Dictionary) -> Dictionary:
	return {
		"id": "%s:contour" % cluster.get("id", ""),
		"type": "contour",
		"basis": BASIS_SELF_ENERGY,
		"channel": QuantumVisualGrammar.CHANNEL_FIELD_SELF_ENERGY_CONTOUR,
		"motion_policy": QuantumVisualGrammar.get_motion_policy_name(QuantumVisualGrammar.CHANNEL_FIELD_SELF_ENERGY_CONTOUR),
		"anchor_emoji": cluster.get("anchor_emoji", ""),
		"band": cluster.get("band", 0),
		"band_count": cluster.get("band_count", 1),
		"center": cluster.get("center", Vector2.ZERO),
		"radius": cluster.get("radius", 0.0),
		"energy": cluster.get("energy", 0.0),
		"energy_min": cluster.get("energy_min", 0.0),
		"energy_max": cluster.get("energy_max", 0.0),
		"density": cluster.get("members", []).size(),
		"members": cluster.get("members", []),
	}


func _hamiltonian_edges_from_records(records: Array, hamiltonian_couplings: Dictionary) -> Array:
	var edges: Array = []
	var node_by_emoji: Dictionary = {}
	for record in records:
		var node = record.node
		for emoji in [node.emoji_north, node.emoji_south]:
			if emoji != "":
				node_by_emoji[emoji] = node

	var drawn: Dictionary = {}
	for source_emoji in hamiltonian_couplings.keys():
		var source_node = node_by_emoji.get(source_emoji, null)
		if not source_node:
			continue
		var outbound = hamiltonian_couplings.get(source_emoji, {})
		if not outbound is Dictionary:
			continue
		for target_emoji in outbound.keys():
			var target_node = node_by_emoji.get(target_emoji, null)
			if not target_node:
				continue
			var strength = float(outbound.get(target_emoji, 0.0))
			if absf(strength) < 0.001:
				continue
			var pair := [source_emoji, target_emoji]
			pair.sort()
			var key := "%s:%s" % [pair[0], pair[1]]
			if drawn.has(key):
				continue
			drawn[key] = true
			edges.append({
				"id": "h:%s" % key,
				"type": "hamiltonian_strand",
				"channel": QuantumVisualGrammar.CHANNEL_EDGE_HAMILTONIAN_STRAND,
				"motion_policy": QuantumVisualGrammar.get_motion_policy_name(QuantumVisualGrammar.CHANNEL_EDGE_HAMILTONIAN_STRAND),
				"source_emoji": source_emoji,
				"target_emoji": target_emoji,
				"source_id": str(source_node.get_instance_id()),
				"target_id": str(target_node.get_instance_id()),
				"source_position": source_node.position,
				"target_position": target_node.position,
				"strength": strength,
			})
	return edges


func _cluster_lod(member_count: int) -> int:
	if member_count >= 8:
		return 2
	if member_count >= 3:
		return 1
	return 0


func _node_average_self_energy(node, self_energies: Dictionary) -> float:
	var north = float(self_energies.get(node.emoji_north, 0.0))
	var south = float(self_energies.get(node.emoji_south, 0.0))
	if node.emoji_north == "" and node.emoji_south == "":
		return 0.0
	if node.emoji_north == "":
		return south
	if node.emoji_south == "":
		return north
	return (north + south) * 0.5


func _node_anchor_coupling(node, hamiltonian_couplings: Dictionary, anchor_emoji: String) -> float:
	if anchor_emoji == "":
		return 0.0

	var best := 0.0
	for emoji in [node.emoji_north, node.emoji_south]:
		if emoji == "":
			continue
		var outbound = hamiltonian_couplings.get(anchor_emoji, {})
		if outbound is Dictionary:
			best = maxf(best, absf(float(outbound.get(emoji, 0.0))))
		var inbound = hamiltonian_couplings.get(emoji, {})
		if inbound is Dictionary:
			best = maxf(best, absf(float(inbound.get(anchor_emoji, 0.0))))
	return best
