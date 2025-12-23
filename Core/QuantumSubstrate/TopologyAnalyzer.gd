class_name TopologyAnalyzer
extends Node

## Analyzes entanglement network topology and detects knot patterns
## Rewards players organically for discovering topological structures

signal knot_discovered(knot_info: Dictionary)
signal topology_changed(new_bonus: float)

# Known knot patterns (discovered by players or predefined)
var discovered_knots: Dictionary = {}  # knot_signature -> KnotInfo

# Current network analysis cache
var current_topology: Dictionary = {}
var current_bonus_multiplier: float = 1.0


## Knot Information Structure
class KnotInfo:
	var name: String = "Unknown Knot"
	var signature: String = ""  # Graph fingerprint
	var bonus_multiplier: float = 1.0
	var protection_level: int = 0  # 0-10
	var description: String = ""
	var glow_color: Color = Color.WHITE
	var discovered: bool = false


## Main Analysis Function

func analyze_entanglement_network(plots: Array) -> Dictionary:
	"""Analyze the topological structure of entangled wheat plots

	Returns topology info with bonuses. No artificial restrictions!
	Just pure mathematical reward.
	"""
	if plots.is_empty():
		return _create_trivial_topology()

	# Build graph representation
	var graph = _build_graph_from_plots(plots)

	# Calculate topological features
	var features = _calculate_topology_features(graph)

	# Detect known patterns
	var pattern = _detect_knot_pattern(features, graph)

	# Check if this is a NEW discovery
	if pattern.signature != "" and not discovered_knots.has(pattern.signature):
		_trigger_discovery(pattern)

	# Calculate bonuses (no gating, just rewards)
	var bonus = _calculate_bonus_from_topology(features, pattern)

	# Cache results
	current_topology = {
		"features": features,
		"pattern": pattern,
		"bonus_multiplier": bonus,
		"node_count": graph.nodes.size(),
		"edge_count": graph.edges.size()
	}

	current_bonus_multiplier = bonus

	return current_topology


## Graph Construction

func _build_graph_from_plots(plots: Array) -> Dictionary:
	"""Convert wheat plot entanglements into graph structure

	FIXED: Now uses WheatPlot.entangled_plots instead of the broken
	DualEmojiQubit.entangled_partners system.
	"""
	var graph = {
		"nodes": {},  # plot -> index
		"edges": [],  # [index_a, index_b, strength]
		"adjacency": {},  # index -> [connected_indices]
		"plot_by_id": {}  # plot_id -> plot (for lookup)
	}

	# Assign indices to plots and build ID lookup
	for i in range(plots.size()):
		graph.nodes[plots[i]] = i
		graph.adjacency[i] = []
		graph.plot_by_id[plots[i].plot_id] = plots[i]

	# Build edge list from entanglements (using WheatPlot.entangled_plots)
	var seen_edges = {}
	for plot in plots:
		var plot_idx = graph.nodes[plot]

		# Use WheatPlot.entangled_plots instead of quantum_state.entangled_partners
		for partner_id in plot.entangled_plots.keys():
			# Find partner plot by ID
			var partner_plot = graph.plot_by_id.get(partner_id)
			if not partner_plot:
				continue

			var partner_idx = graph.nodes[partner_plot]

			# Avoid duplicate edges
			var edge_key = _make_edge_key(plot_idx, partner_idx)
			if seen_edges.has(edge_key):
				continue

			var strength = plot.entangled_plots[partner_id]
			graph.edges.append([plot_idx, partner_idx, strength])
			graph.adjacency[plot_idx].append(partner_idx)
			graph.adjacency[partner_idx].append(plot_idx)
			seen_edges[edge_key] = true

	return graph


func _find_plot_by_qubit(plots: Array, qubit) -> Variant:
	"""Helper: Find wheat plot containing specific qubit"""
	for plot in plots:
		if plot.quantum_state == qubit:
			return plot
	return null


func _make_edge_key(a: int, b: int) -> String:
	"""Create unique edge identifier"""
	if a < b:
		return "%d-%d" % [a, b]
	else:
		return "%d-%d" % [b, a]


## Topology Feature Detection

func _calculate_topology_features(graph: Dictionary) -> Dictionary:
	"""Calculate topological invariants and features"""
	var features = {}

	# Basic graph properties
	features["node_count"] = graph.nodes.size()
	features["edge_count"] = graph.edges.size()
	features["density"] = _calculate_density(graph)

	# Connectivity
	features["is_connected"] = _is_connected(graph)
	features["num_components"] = _count_components(graph)

	# Cycles
	features["has_cycles"] = _has_cycles(graph)
	features["cycle_basis"] = _find_cycle_basis(graph)
	features["num_cycles"] = features.cycle_basis.size()

	# Topological complexity
	features["euler_characteristic"] = _calculate_euler_characteristic(graph)
	features["genus"] = _estimate_genus(graph)  # Simplified

	# Crossing patterns (for knot detection)
	features["crossing_number"] = _estimate_crossing_number(graph)

	# Symmetry
	features["symmetry_order"] = _detect_symmetry(graph)

	# Simplified Jones polynomial approximation
	features["jones_approximation"] = _approximate_jones_polynomial(graph)

	return features


func _calculate_density(graph: Dictionary) -> float:
	"""Graph density: actual edges / possible edges"""
	var n = graph.nodes.size()
	if n < 2:
		return 0.0
	var max_edges = n * (n - 1) / 2.0
	return graph.edges.size() / max_edges


func _is_connected(graph: Dictionary) -> bool:
	"""Check if graph is fully connected (DFS)"""
	if graph.nodes.is_empty():
		return true

	var visited = {}
	var stack = [0]  # Start from node 0

	while not stack.is_empty():
		var node = stack.pop_back()
		if visited.has(node):
			continue

		visited[node] = true

		for neighbor in graph.adjacency.get(node, []):
			if not visited.has(neighbor):
				stack.append(neighbor)

	return visited.size() == graph.nodes.size()


func _count_components(graph: Dictionary) -> int:
	"""Count disconnected components"""
	if graph.nodes.is_empty():
		return 0

	var visited = {}
	var components = 0

	for node_idx in graph.adjacency.keys():
		if visited.has(node_idx):
			continue

		# DFS from this node
		var stack = [node_idx]
		while not stack.is_empty():
			var node = stack.pop_back()
			if visited.has(node):
				continue

			visited[node] = true
			for neighbor in graph.adjacency.get(node, []):
				if not visited.has(neighbor):
					stack.append(neighbor)

		components += 1

	return components


func _has_cycles(graph: Dictionary) -> bool:
	"""Simple cycle detection using DFS"""
	if graph.nodes.is_empty():
		return false

	var visited = {}
	var rec_stack = {}

	for start_node in graph.adjacency.keys():
		if visited.has(start_node):
			continue

		if _has_cycle_dfs(graph, start_node, -1, visited, rec_stack):
			return true

	return false


func _has_cycle_dfs(graph: Dictionary, node: int, parent: int, visited: Dictionary, rec_stack: Dictionary) -> bool:
	"""DFS helper for cycle detection"""
	visited[node] = true
	rec_stack[node] = true

	for neighbor in graph.adjacency.get(node, []):
		if neighbor == parent:
			continue  # Don't go back to parent

		if not visited.has(neighbor):
			if _has_cycle_dfs(graph, neighbor, node, visited, rec_stack):
				return true
		elif rec_stack.has(neighbor):
			return true

	rec_stack.erase(node)
	return false


func _find_cycle_basis(graph: Dictionary) -> Array:
	"""Find fundamental cycles (simplified - returns small cycles)"""
	var cycles = []

	# Look for 3-cycles (triangles)
	for node in graph.adjacency.keys():
		for neighbor in graph.adjacency.get(node, []):
			for third in graph.adjacency.get(neighbor, []):
				if third in graph.adjacency.get(node, []) and third > node:
					cycles.append([node, neighbor, third])

	# Look for 4-cycles (squares)
	for node in graph.adjacency.keys():
		for n1 in graph.adjacency.get(node, []):
			for n2 in graph.adjacency.get(n1, []):
				if n2 == node:
					continue
				for n3 in graph.adjacency.get(n2, []):
					if n3 in graph.adjacency.get(node, []) and n3 != n1:
						cycles.append([node, n1, n2, n3])

	return cycles


func _calculate_euler_characteristic(graph: Dictionary) -> int:
	"""χ = V - E + F (simplified for planar graphs)"""
	var V = graph.nodes.size()
	var E = graph.edges.size()

	# For planar graphs: F = E - V + 2 (Euler's formula)
	# χ = V - E + F = V - E + (E - V + 2) = 2

	# For non-planar: approximate
	if E > 3 * V - 6:  # More than planar max
		return 2 - (E - (3*V - 6))  # Rough estimate

	return 2  # Planar


func _estimate_genus(graph: Dictionary) -> int:
	"""Estimate topological genus (handles on surface)"""
	var chi = _calculate_euler_characteristic(graph)

	# For orientable surfaces: χ = 2 - 2g
	# So: g = (2 - χ) / 2
	var genus = (2 - chi) / 2

	return max(0, genus)


func _estimate_crossing_number(graph: Dictionary) -> int:
	"""Estimate minimum crossings (simplified heuristic)"""
	var V = graph.nodes.size()
	var E = graph.edges.size()

	# Planar graphs: E ≤ 3V - 6
	var planar_max = 3 * V - 6

	if E <= planar_max:
		return 0  # Likely planar

	# Rough estimate: excess edges might cause crossings
	return E - planar_max


func _detect_symmetry(graph: Dictionary) -> int:
	"""Detect rotational/reflection symmetry order"""
	# Simplified: check for regular patterns
	var node_count = graph.nodes.size()

	# Check for fully connected (complete graph)
	if graph.edges.size() == node_count * (node_count - 1) / 2:
		return node_count  # High symmetry

	# Check for cyclic (ring) structure
	var all_degree_2 = true
	for node in graph.adjacency.keys():
		if graph.adjacency[node].size() != 2:
			all_degree_2 = false
			break

	if all_degree_2:
		return node_count  # Ring symmetry

	return 1  # No special symmetry


func _approximate_jones_polynomial(graph: Dictionary) -> float:
	"""Parametric Jones polynomial approximation

	Returns a continuous value that increases with topological complexity.
	Based on cycle structure, crossings, and linking numbers.
	"""
	var cycles = _find_cycle_basis(graph)

	if cycles.is_empty():
		return 1.0  # Unknot (J = 1)

	# Cycle contribution (exponential growth)
	var cycle_term = 0.0
	for cycle in cycles:
		var length = cycle.size()
		# Longer cycles contribute more complexity
		cycle_term += pow(1.618, length - 2)  # Golden ratio scaling

	# Crossing contribution (polynomial growth)
	var crossings = _estimate_crossing_number(graph)
	var crossing_term = sqrt(1.0 + crossings * crossings)  # L2 norm

	# Linking contribution (cycle interactions)
	var linking_term = _estimate_linking_number(cycles, graph)

	# Genus contribution (handles/holes in surface)
	var genus = _estimate_genus(graph)
	var genus_term = pow(1.414, genus)  # sqrt(2) scaling

	# Combined Jones approximation
	# J ≈ 1 + cycle_complexity + crossing_complexity + linking + genus
	var J = 1.0 + (cycle_term * 0.3) + (crossing_term * 0.2) + (linking_term * 0.3) + (genus_term * 0.2)

	return J


func _estimate_linking_number(cycles: Array, graph: Dictionary) -> float:
	"""Estimate linking number between cycles (how intertwined they are)

	For each pair of cycles, estimate if they're linked.
	Returns total linking complexity.
	"""
	if cycles.size() < 2:
		return 0.0

	var linking = 0.0

	for i in range(cycles.size()):
		for j in range(i+1, cycles.size()):
			var cycle_a = cycles[i]
			var cycle_b = cycles[j]

			# Check for shared nodes (indicates linking)
			var shared_nodes = 0
			for node in cycle_a:
				if node in cycle_b:
					shared_nodes += 1

			# Shared nodes indicate potential linking
			if shared_nodes > 0:
				# More shared nodes = stronger linking
				linking += sqrt(shared_nodes)

			# Check for edge crossings (non-planar indication)
			var crossing_edges = 0
			for edge_a in _get_cycle_edges(cycle_a):
				for edge_b in _get_cycle_edges(cycle_b):
					if _edges_may_cross(edge_a, edge_b):
						crossing_edges += 1

			linking += crossing_edges * 0.1

	return linking


func _get_cycle_edges(cycle: Array) -> Array:
	"""Get edges in a cycle"""
	var edges = []
	for i in range(cycle.size()):
		var next_i = (i + 1) % cycle.size()
		edges.append([cycle[i], cycle[next_i]])
	return edges


func _edges_may_cross(edge_a: Array, edge_b: Array) -> bool:
	"""Check if two edges might cross (simplified heuristic)"""
	# If edges share a node, they don't cross
	if edge_a[0] in edge_b or edge_a[1] in edge_b:
		return false

	# Otherwise, they might cross (we'd need 3D embedding to know for sure)
	return true


## Parametric Pattern Recognition

func _detect_knot_pattern(features: Dictionary, graph: Dictionary) -> KnotInfo:
	"""Parametrically determine knot properties from topological invariants

	Uses Jones polynomial approximation and other invariants to continuously
	calculate bonus, protection, and visual properties. No categorical bucketing!
	"""
	var pattern = KnotInfo.new()

	# Generate unique signature from invariants
	pattern.signature = _generate_signature(features, graph)

	# Extract topological invariants
	var J = features.jones_approximation          # Jones polynomial approximation
	var genus = features.genus                     # Topological genus (handles)
	var crossings = features.crossing_number       # Minimum crossings
	var cycles = features.num_cycles               # Number of cycles
	var symmetry = features.symmetry_order         # Rotational symmetry
	var nodes = features.node_count                # Graph size

	# No edges = no entanglement = no bonus
	if graph.edges.is_empty():
		pattern.bonus_multiplier = 1.0
		pattern.protection_level = 0
		pattern.description = _generate_description(features, pattern)
		return pattern

	# === PARAMETRIC BONUS CALCULATION ===
	# Bonus grows with topological complexity (all continuous functions)

	var jones_bonus = (J - 1.0) * 0.15              # Jones contributes 15% per unit
	var genus_bonus = pow(genus, 1.2) * 0.1         # Genus contributes exponentially
	var crossing_bonus = sqrt(crossings) * 0.08     # Crossings contribute with diminishing returns
	var symmetry_bonus = log(symmetry + 1) * 0.05   # Symmetry gives logarithmic bonus

	# Combined bonus (sum of all contributions)
	var total_bonus = 1.0 + jones_bonus + genus_bonus + crossing_bonus + symmetry_bonus

	# Clamp to reasonable range
	pattern.bonus_multiplier = clamp(total_bonus, 1.0, 3.0)

	# === PARAMETRIC PROTECTION CALCULATION ===
	# Protection based on topological resilience

	# High genus and crossings = stable (hard to untangle)
	var stability = (genus * 2.0) + (crossings * 1.5) + (cycles * 0.5)

	# But if highly linked (Borromean-like), very fragile
	var linking_penalty = 0.0
	if cycles >= 3:
		# Estimate if this is a Borromean-like pattern (fragile linkage)
		var cycle_basis = features.cycle_basis
		var shared_count = 0
		for i in range(min(3, cycle_basis.size())):
			for j in range(i+1, min(3, cycle_basis.size())):
				for node in cycle_basis[i]:
					if node in cycle_basis[j]:
						shared_count += 1
						break
		# If many cycles share nodes but not fully interconnected, it's fragile
		if shared_count >= 2 and crossings < 3:
			linking_penalty = 5.0  # Borromean-like fragility

	pattern.protection_level = int(clamp(stability - linking_penalty, 0, 10))

	# === PARAMETRIC GLOW COLOR ===
	# Color derived from invariants (continuous spectrum)

	# Hue based on Jones polynomial (0 = red, 0.33 = green, 0.66 = blue, 1.0 = red)
	var hue = fmod((J - 1.0) * 0.15, 1.0)

	# Saturation based on crossing number (more crossings = more saturated)
	var saturation = clamp(0.5 + crossings * 0.1, 0.3, 1.0)

	# Value based on genus (higher genus = brighter)
	var value = clamp(0.6 + genus * 0.15, 0.4, 1.0)

	# Alpha based on symmetry (more symmetric = more opaque)
	var alpha = clamp(0.4 + log(symmetry + 1) * 0.2, 0.3, 0.8)

	pattern.glow_color = Color.from_hsv(hue, saturation, value, alpha)

	# === DESCRIPTIVE NAME GENERATION ===
	# Generate name from properties (not categorical)

	pattern.name = _generate_descriptive_name(features, J, genus, crossings, cycles)

	# === PARAMETRIC DESCRIPTION ===
	pattern.description = _generate_description(features, pattern)

	return pattern


func _generate_descriptive_name(features: Dictionary, J: float, genus: int, crossings: int, cycles: int) -> String:
	"""Generate descriptive name from topological properties"""

	# Special case: unknot
	if cycles == 0:
		return "Unknot"

	# Build name from properties
	var name_parts = []

	# Complexity descriptor
	if J > 8.0:
		name_parts.append("Exotic")
	elif J > 5.0:
		name_parts.append("Complex")
	elif J > 3.0:
		name_parts.append("Intricate")
	elif J > 2.0:
		name_parts.append("Compound")

	# Genus descriptor (topological type)
	if genus == 0:
		if cycles == 1:
			name_parts.append("Ring")
		else:
			name_parts.append("Planar")
	elif genus == 1:
		name_parts.append("Toric")  # Torus-like
	elif genus == 2:
		name_parts.append("Double-Toric")
	else:
		name_parts.append("Multi-Toric")

	# Crossing descriptor
	if crossings == 0:
		pass  # No crossing descriptor
	elif crossings <= 3:
		name_parts.append("%d-Crossing" % crossings)
	else:
		name_parts.append("High-Crossing")

	# Cycle descriptor
	if cycles >= 3:
		name_parts.append("%d-Link" % cycles)

	# Combine
	if name_parts.is_empty():
		return "Simple Structure"

	return " ".join(name_parts)


func _generate_description(features: Dictionary, pattern: KnotInfo) -> String:
	"""Generate parametric description from properties"""

	var J = features.jones_approximation
	var genus = features.genus
	var crossings = features.crossing_number
	var cycles = features.num_cycles

	var desc_parts = []

	# Complexity statement
	if J > 6.0:
		desc_parts.append("Highly complex topology.")
	elif J > 3.0:
		desc_parts.append("Moderately complex structure.")
	elif J > 2.0:
		desc_parts.append("Balanced topological form.")
	else:
		desc_parts.append("Simple connectivity.")

	# Stability statement
	if pattern.protection_level >= 8:
		desc_parts.append("Extremely stable configuration.")
	elif pattern.protection_level >= 5:
		desc_parts.append("Robust entanglement.")
	elif pattern.protection_level >= 3:
		desc_parts.append("Moderate resilience.")
	else:
		desc_parts.append("Fragile interdependence.")

	# Production statement
	var bonus_percent = (pattern.bonus_multiplier - 1.0) * 100
	if bonus_percent > 50:
		desc_parts.append("Exceptional productivity.")
	elif bonus_percent > 20:
		desc_parts.append("Enhanced growth rates.")
	elif bonus_percent > 0:
		desc_parts.append("Modest yield improvement.")

	return " ".join(desc_parts)


func _is_borromean_pattern(graph: Dictionary) -> bool:
	"""Detect Borromean ring pattern (simplified)"""
	# True Borromean: 3 rings, no pair linked, but triple linked
	# Simplified check: 3 separate cycles that share nodes

	var cycles = _find_cycle_basis(graph)
	if cycles.size() < 3:
		return false

	# Check if we have 3 distinct but interconnected cycles
	var has_three_distinct = cycles.size() >= 3

	# Check for shared nodes between cycles
	var shared_nodes = 0
	for i in range(min(3, cycles.size())):
		for j in range(i+1, min(3, cycles.size())):
			for node in cycles[i]:
				if node in cycles[j]:
					shared_nodes += 1
					break

	return has_three_distinct and shared_nodes >= 2


func _generate_signature(features: Dictionary, graph: Dictionary) -> String:
	"""Generate unique signature from topological invariants

	Uses multiple invariants to create a unique fingerprint.
	Different topologies will have different signatures.
	"""
	return "%d-%d-%d-%d-%d-%.3f" % [
		features.node_count,
		features.edge_count,
		features.num_cycles,
		features.crossing_number,
		features.genus,
		features.jones_approximation
	]


## Bonus Calculation

func _calculate_bonus_from_topology(features: Dictionary, pattern: KnotInfo) -> float:
	"""Return bonus multiplier from parametric pattern calculation

	Bonus is already computed parametrically in _detect_knot_pattern
	from Jones polynomial and other topological invariants.
	"""
	return pattern.bonus_multiplier  # Already includes all contributions


## Discovery System

func _trigger_discovery(pattern: KnotInfo):
	"""Trigger discovery notification for new knot"""
	pattern.discovered = true
	discovered_knots[pattern.signature] = pattern

	print("🎉 KNOT DISCOVERED: %s" % pattern.name)
	print("   Bonus: +%.0f%%" % ((pattern.bonus_multiplier - 1.0) * 100))
	print("   Protection: %d/10" % pattern.protection_level)

	knot_discovered.emit({
		"name": pattern.name,
		"bonus": pattern.bonus_multiplier,
		"protection": pattern.protection_level,
		"description": pattern.description,
		"color": pattern.glow_color
	})


func _create_trivial_topology() -> Dictionary:
	"""Return empty/trivial topology"""
	return {
		"features": {},
		"pattern": KnotInfo.new(),
		"bonus_multiplier": 1.0,
		"node_count": 0,
		"edge_count": 0
	}


## Public API

func get_current_bonus() -> float:
	"""Get current topology bonus multiplier"""
	return current_bonus_multiplier


func get_discovered_knots() -> Array:
	"""Get list of all discovered knot patterns"""
	return discovered_knots.values()


func get_current_jones_polynomial() -> float:
	"""Get current Jones polynomial approximation (for contract evaluation)"""
	if current_topology.has("features") and current_topology.features.has("jones_approximation"):
		return current_topology.features.jones_approximation
	return 0.0


func get_current_protection_level() -> int:
	"""Get current topological protection level (for contract evaluation)"""
	if current_topology.has("pattern"):
		return current_topology.pattern.protection_level
	return 0


func get_topology_info() -> Dictionary:
	"""Get current topology analysis"""
	return current_topology
