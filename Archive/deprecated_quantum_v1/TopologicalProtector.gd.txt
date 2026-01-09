class_name TopologicalProtector
extends TopologyAnalyzer

## Topological Protection - Active Quantum State Shielding
## Extends TopologyAnalyzer with active protection based on knot invariants
##
## Physics: Topological quantum computing uses topology for error correction
## - Jones polynomial determines protection strength
## - Higher topological complexity = slower decoherence
## - Knot invariants are robust against local perturbations
##
## Gameplay: Transform topology from decorative to functional!
## - Early game: No topology → fast decoherence
## - Mid game: Simple structures → modest protection
## - Late game: Complex knots → quantum immortality

## Settings
var enable_active_protection: bool = true
var protection_strength_multiplier: float = 1.0

## Cache (per plot)
var plot_protection_cache: Dictionary = {}  # plot_id -> protection_strength

## Statistics
var total_protection_events: int = 0
var total_shielding_time: float = 0.0


func _ready():
	# Note: TopologyAnalyzer doesn't define _ready(), so no super call needed
	pass


## Protection Strength Calculation

func get_protection_strength(network: Array) -> float:
	"""Calculate protection from Jones polynomial

	Physics: Topological invariants provide stability against noise.
	Higher Jones polynomial = more complex topology = stronger protection.

	Args:
		network: Array of WheatPlot in connected component

	Returns:
		Protection strength (0.0 to 1.0)
		- 0.0: No protection (unknot/trivial)
		- 1.0: Maximum protection (complex topology)

	Formula:
		protection = log(J + 1) / log(10)

		Where J is Jones polynomial approximation.
	"""
	if network.is_empty():
		return 0.0

	# Analyze topology
	var topology = analyze_entanglement_network(network)
	var jones = topology.features.jones_approximation

	# Logarithmic scaling: J=1 → 0%, J=10 → 100%
	var protection = log(jones + 1.0) / log(10.0)

	# Apply multiplier (for game balance tuning)
	protection *= protection_strength_multiplier

	return clamp(protection, 0.0, 1.0)


## Active Shielding

func apply_topological_shielding(plot, dt: float, all_plots: Array = []) -> void:
	"""Actively protect quantum state using topology

	Extends T₁/T₂ coherence times based on local network's Jones polynomial.

	Physics: Topological qubits are protected from local noise.
	The more complex the topology, the harder it is to decohere.

	Args:
		plot: WheatPlot to protect
		dt: Time step (seconds)
		all_plots: All plots (for network extraction)
	"""
	if not enable_active_protection:
		return

	# Only protect entangled states
	if plot.quantum_state == null:
		return
	if plot.quantum_state.entangled_pair == null:
		return

	# Get local connected network
	var network = _get_local_entangled_network_from_list(plot, all_plots)

	if network.size() < 3:
		# Need at least triangle for topological protection
		plot_protection_cache[plot.plot_id] = 0.0
		return

	# Calculate protection strength
	var protection = get_protection_strength(network)

	if protection <= 0.0:
		plot_protection_cache[plot.plot_id] = 0.0
		return

	# T₁/T₂ multiplier (up to 11x at full protection)
	# This makes decoherence exponentially slower!
	var T1_multiplier = 1.0 + (protection * 10.0)
	var T2_multiplier = 1.0 + (protection * 10.0)

	# Apply to qubit's coherence times
	# Note: This extends the time constant, making decoherence slower
	if "coherence_time_T1" in plot.quantum_state:
		plot.quantum_state.coherence_time_T1 *= T1_multiplier
	if "coherence_time_T2" in plot.quantum_state:
		plot.quantum_state.coherence_time_T2 *= T2_multiplier

	# Cache for visualization
	plot_protection_cache[plot.plot_id] = protection

	# Statistics
	total_protection_events += 1
	total_shielding_time += dt

	# Debug output (only for strong protection)
	if protection > 0.5:
		print("🛡️ Strong protection: %.0f%% on plot %s (T₁×%.1f)" %
		      [protection * 100, plot.plot_id, T1_multiplier])


func protect_entangled_pair(pair, dt: float, all_plots: Array = []) -> void:
	"""Protect density matrix from decoherence

	Apply topological protection to both qubits in entangled pair.
	Protection strength is average of both local networks.

	Args:
		pair: EntangledPair to protect
		dt: Time step
		all_plots: All plots for network extraction
	"""
	if not enable_active_protection:
		return

	# Get plots for both qubits
	var plot_a = _find_plot_containing_qubit(pair.qubit_a, all_plots)
	var plot_b = _find_plot_containing_qubit(pair.qubit_b, all_plots)

	if plot_a == null or plot_b == null:
		return

	# Apply protection to both
	apply_topological_shielding(plot_a, dt, all_plots)
	apply_topological_shielding(plot_b, dt, all_plots)


## Topology Breaking Detection

func detect_topology_breaking_event(plot, all_plots: Array) -> Dictionary:
	"""Check if removing this plot breaks non-trivial topology

	Simulates removal and compares Jones polynomial before/after.
	Used for harvest warnings: "⚠️ Breaking topology!"

	Args:
		plot: WheatPlot to potentially remove
		all_plots: All plots in farm

	Returns:
		{
			breaks_topology: bool,      # True if significant change
			jones_before: float,        # Jones before removal
			jones_after: float,         # Jones after removal
			jones_delta: float,         # Absolute change
			protection_lost: float      # Fraction of protection lost (0.0-1.0)
		}
	"""
	# Get network containing this plot
	var network_before = _get_local_entangled_network_from_list(plot, all_plots)

	if network_before.size() < 3:
		# No topology to break
		return {
			"breaks_topology": false,
			"jones_before": 1.0,
			"jones_after": 1.0,
			"jones_delta": 0.0,
			"protection_lost": 0.0
		}

	# Analyze before removal
	var topology_before = analyze_entanglement_network(network_before)
	var jones_before = topology_before.features.jones_approximation

	# Simulate network after removal
	var network_after = network_before.filter(func(p): return p != plot)

	if network_after.is_empty():
		# Complete destruction
		return {
			"breaks_topology": true,
			"jones_before": jones_before,
			"jones_after": 1.0,
			"jones_delta": jones_before - 1.0,
			"protection_lost": get_protection_strength(network_before)
		}

	# Analyze after removal
	var topology_after = analyze_entanglement_network(network_after)
	var jones_after = topology_after.features.jones_approximation

	# Calculate change
	var jones_delta = abs(jones_before - jones_after)
	var breaks = jones_delta > 0.5  # Significant change threshold

	# Protection lost (as fraction)
	var protection_lost = jones_delta / jones_before if jones_before > 0 else 0.0

	return {
		"breaks_topology": breaks,
		"jones_before": jones_before,
		"jones_after": jones_after,
		"jones_delta": jones_delta,
		"protection_lost": clamp(protection_lost, 0.0, 1.0)
	}


## Error Syndrome Detection (Quantum Error Correction)

func get_error_syndrome(all_plots: Array) -> Dictionary:
	"""Detect broken/weak entanglements (quantum error correction)

	Scans all entanglements and identifies weak bonds that need repair.
	This is analogous to measuring stabilizers in quantum error correction!

	Args:
		all_plots: All plots in farm

	Returns:
		Dictionary of error syndromes:
		{
			edge_id: {
				type: String,          # "entanglement_loss", "weak_bond"
				strength: float,       # Current strength (0.0 to 1.0)
				threshold: float,      # Expected healthy strength
				suggested_fix: String, # "re-entangle", "strengthen"
				plot_a: String,        # First plot ID
				plot_b: String         # Second plot ID
			}
		}
	"""
	var syndrome = {}
	var seen_edges = {}  # Avoid duplicates

	# Threshold for "healthy" entanglement
	var healthy_threshold = 0.5

	for plot in all_plots:
		if plot.quantum_state == null:
			continue

		# Check each entanglement
		for partner_id in plot.entangled_plots.keys():
			# Create unique edge key (undirected)
			var edge_key = _make_edge_key_from_ids(plot.plot_id, partner_id)

			if seen_edges.has(edge_key):
				continue  # Already processed

			seen_edges[edge_key] = true

			var strength = plot.entangled_plots[partner_id]

			if strength < healthy_threshold:
				var edge_id = "%s-%s" % [plot.plot_id, partner_id]

				syndrome[edge_id] = {
					"type": "entanglement_loss" if strength < 0.2 else "weak_bond",
					"strength": strength,
					"threshold": healthy_threshold,
					"suggested_fix": "re-entangle" if strength < 0.2 else "strengthen",
					"plot_a": plot.plot_id,
					"plot_b": partner_id
				}

	return syndrome


## Helper Functions

func _get_local_entangled_network_from_list(plot, all_plots: Array) -> Array:
	"""Get connected component containing plot via BFS

	Args:
		plot: WheatPlot to start from
		all_plots: All available plots

	Returns:
		Array of WheatPlot in same connected component
	"""
	if all_plots.is_empty():
		return []

	# BFS to find connected component
	var component = []
	var visited = {}
	var queue = [plot]

	while not queue.is_empty():
		var current = queue.pop_front()

		if current == null:
			continue

		if visited.has(current.plot_id):
			continue

		visited[current.plot_id] = true
		component.append(current)

		# Add entangled neighbors
		for partner_id in current.entangled_plots.keys():
			# Find partner in all_plots
			for p in all_plots:
				if p.plot_id == partner_id and not visited.has(p.plot_id):
					queue.append(p)
					break

	return component


func _find_plot_containing_qubit(qubit, all_plots: Array):
	"""Find WheatPlot that contains this qubit

	Args:
		qubit: DualEmojiQubit to search for
		all_plots: All plots to search

	Returns:
		WheatPlot or null
	"""
	for plot in all_plots:
		if plot.quantum_state == qubit:
			return plot
	return null


func _make_edge_key_from_ids(id_a: String, id_b: String) -> String:
	"""Create unique edge identifier from plot IDs (undirected)

	Ensures consistent ordering so A-B and B-A map to same key.
	"""
	if id_a < id_b:
		return "%s-%s" % [id_a, id_b]
	else:
		return "%s-%s" % [id_b, id_a]


## Visual Effects

func get_protection_visual_for_plot(plot_id: String) -> Dictionary:
	"""Get visual effect parameters for protected plot

	Returns shader parameters for rendering protection shield.

	Returns:
		{
			has_protection: bool,
			strength: float,       # 0.0 to 1.0
			color: Color,          # Shield glow color
			pulse_rate: float      # Animation speed (Hz)
		}
	"""
	if not plot_protection_cache.has(plot_id):
		return {
			"has_protection": false,
			"strength": 0.0,
			"color": Color.TRANSPARENT,
			"pulse_rate": 0.0
		}

	var protection = plot_protection_cache[plot_id]

	# Shield color: cyan/blue (topological protection theme)
	# Alpha scales with protection strength
	var shield_color = Color(0.3, 0.7, 1.0, protection * 0.6)

	# Pulse faster with stronger protection (visual feedback)
	var pulse_rate = 0.5 + (protection * 1.5)  # 0.5 to 2.0 Hz

	return {
		"has_protection": protection > 0.1,
		"strength": protection,
		"color": shield_color,
		"pulse_rate": pulse_rate
	}


func get_all_protected_plots() -> Array:
	"""Get list of all plot IDs with active protection

	Returns:
		Array of plot IDs (String) that have protection > 0
	"""
	var protected = []
	for plot_id in plot_protection_cache.keys():
		if plot_protection_cache[plot_id] > 0.1:
			protected.append(plot_id)
	return protected


func clear_protection_cache():
	"""Clear protection cache (call when farm resets)"""
	plot_protection_cache.clear()
	total_protection_events = 0
	total_shielding_time = 0.0


## Statistics & Debug

func get_average_protection() -> float:
	"""Get average protection across all cached plots"""
	if plot_protection_cache.is_empty():
		return 0.0

	var total = 0.0
	for p in plot_protection_cache.values():
		total += p

	return total / plot_protection_cache.size()


func get_protection_statistics() -> Dictionary:
	"""Get comprehensive protection statistics

	Returns:
		{
			total_events: int,
			total_time: float,
			average_protection: float,
			protected_plot_count: int,
			max_protection: float
		}
	"""
	var max_protection = 0.0
	var protected_count = 0

	for p in plot_protection_cache.values():
		if p > 0.1:
			protected_count += 1
		if p > max_protection:
			max_protection = p

	return {
		"total_events": total_protection_events,
		"total_time": total_shielding_time,
		"average_protection": get_average_protection(),
		"protected_plot_count": protected_count,
		"max_protection": max_protection
	}


func get_debug_string() -> String:
	"""Debug output string"""
	var avg_protection = get_average_protection()
	var protected_count = get_all_protected_plots().size()

	return "TopologicalProtector | Protected: %d plots | Avg: %.0f%% | Events: %d" % [
		protected_count,
		avg_protection * 100,
		total_protection_events
	]


## Physics Description

func get_physics_explanation() -> String:
	"""Return educational description of topological protection

	For tooltips, codex entries, etc.
	"""
	return """[Topological Protection]

Physics: Topological quantum computing uses knot invariants for error correction.
Complex topologies are robust against local noise and perturbations.

Mechanism:
- Jones polynomial J measures topological complexity
- Protection strength = log(J + 1) / log(10)
- T₁/T₂ times extended by up to 11x

Examples:
- Unknot (chain): J≈1, no protection
- Triangle: J≈2.5, 40% protection (4x slower decoherence)
- Complex knot: J≈8, 90% protection (10x slower decoherence)

Gameplay Strategy:
- Build complex entanglement networks
- Create cycles, crossings, and links
- Higher Jones polynomial = longer quantum state lifetime

Educational Value:
- Learn topology = stability principle
- Understand topological quantum computing
- Experience quantum error correction"""
