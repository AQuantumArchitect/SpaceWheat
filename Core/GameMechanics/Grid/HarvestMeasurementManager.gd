class_name HarvestMeasurementManager
extends RefCounted

## HarvestMeasurementManager - Quantum measurement, harvesting, topology-based yield
##
## Extracted from FarmGrid.gd as part of decomposition.
## Handles measurement, harvest, topology bonus, coherence penalty.

const TopologyAnalyzer = preload("res://Core/QuantumSubstrate/TopologyAnalyzer.gd")

# Signals
signal plot_harvested(position: Vector2i, yield_data: Dictionary)
signal plot_changed(position: Vector2i, change_type: String, details: Dictionary)
signal visualization_changed()

# Component dependencies (injected via set_dependencies)
var _plot_manager = null  # GridPlotManager
var _biome_routing = null  # BiomeRoutingManager
var _economy = null  # FarmEconomy
var _entanglement = null  # EntanglementManager
var _topology_analyzer: TopologyAnalyzer = null
var _faction_territory_manager = null
var _verbose = null


func set_dependencies(plot_manager, biome_routing, economy, entanglement, topology_analyzer = null) -> void:
	"""Inject component dependencies."""
	_plot_manager = plot_manager
	_biome_routing = biome_routing
	_economy = economy
	_entanglement = entanglement
	_topology_analyzer = topology_analyzer if topology_analyzer else TopologyAnalyzer.new()


func set_faction_territory_manager(ftm) -> void:
	"""Set faction territory manager reference."""
	_faction_territory_manager = ftm


func set_verbose(verbose_ref) -> void:
	"""Set verbose logger reference."""
	_verbose = verbose_ref


func harvest_wheat(position: Vector2i) -> Dictionary:
	"""Harvest wheat at position (quantum-only: must be planted)"""
	var plot = _plot_manager.get_plot(position)
	if plot == null or not plot.is_planted:
		return {"success": false}

	var yield_data = plot.harvest()
	if yield_data["success"]:
		_biome_routing.clear_register_tracking(position)

		# Remove projection from biome
		var plot_biome = _biome_routing.get_biome_for_plot(position)
		if plot_biome and plot_biome.has_method("remove_projection"):
			plot_biome.remove_projection(position)
			if _verbose:
				_verbose.debug("farm", "🗑️", "Removed projection from biome at %s" % position)

		plot_harvested.emit(position, yield_data)

		# Emit generic signals for visualization update
		plot_changed.emit(position, "harvested", {"yield": yield_data})
		visualization_changed.emit()

	return yield_data


func get_local_network(center_plot, radius: int = 2) -> Array:
	"""Get plots within entanglement distance from center plot

	Args:
		center_plot: The plot at the center of the local network
		radius: Number of entanglement hops to include

	Returns:
		Array of plots forming the local entanglement network
	"""
	if not center_plot:
		return []

	var local = [center_plot]
	var visited = {center_plot: true}
	var current_layer = [center_plot]

	for hop in range(radius):
		var next_layer = []
		for plot in current_layer:
			if not plot.is_planted:
				continue

			# Get entangled partners via WheatPlot.entangled_plots
			for partner_id in plot.entangled_plots.keys():
				var partner_pos = _plot_manager.find_plot_by_id(partner_id)
				if partner_pos != Vector2i(-1, -1):
					var partner_plot = _plot_manager.get_plot(partner_pos)
					if partner_plot and not visited.has(partner_plot):
						local.append(partner_plot)
						next_layer.append(partner_plot)
						visited[partner_plot] = true

		current_layer = next_layer
		if current_layer.is_empty():
			break

	return local


func harvest_with_topology(position: Vector2i, local_radius: int = 2) -> Dictionary:
	"""Harvest wheat with local topology bonus and coherence penalty

	This is the NEW harvest method that implements the quantum-classical divide:
	- Analyzes local entanglement topology for bonus
	- Applies coherence penalty (decoherence reduces yield)
	- Measures quantum state (collapses superposition)
	- Breaks entanglements (measurement destroys quantum state)

	Args:
		position: Grid position to harvest
		local_radius: Entanglement hops to include in local network (default 2)

	Returns:
		Dictionary with harvest results
	"""
	var plot = _plot_manager.get_plot(position)
	if plot == null or not plot.is_planted:
		return {"success": false}

	# 1. Get local entanglement network
	var local_plots = get_local_network(plot, local_radius)

	# 2. Analyze local topology
	var local_topology = _topology_analyzer.analyze_entanglement_network(local_plots)

	# 3. Check coherence from quantum_computer (Model C)
	var coherence = 1.0
	var biome = _biome_routing.get_biome_for_plot(position)

	if biome and biome.quantum_computer:
		var reg_id = _biome_routing.get_register_for_plot(position)
		if reg_id >= 0:
			# Model C: get_marginal_coherence takes (null, reg_id)
			coherence = biome.quantum_computer.get_marginal_coherence(null, reg_id)
			coherence = clamp(coherence, 0.0, 1.0)

	# 4. Measure quantum state (Model C)
	var measurement_result = ""

	if biome and biome.quantum_computer:
		if plot.north_emoji != "" and plot.south_emoji != "":
			var outcome_emoji = biome.quantum_computer.measure_axis(plot.north_emoji, plot.south_emoji)
			measurement_result = outcome_emoji if outcome_emoji != "" else plot.north_emoji
			if _verbose:
				_verbose.debug("farm", "📊", "Harvest measurement at %s: outcome = %s" % [position, measurement_result])

	# Fallback if no quantum system available
	if measurement_result == "":
		measurement_result = plot.north_emoji  # Default to north state

	# 5. Calculate base yield from growth
	# Note: growth_progress was deprecated in Model B
	# Using constant base yield for now (plots are harvested immediately upon measurement)
	var growth_factor = 1.0  # Model B: plots grow instantly, no time-based progression
	var base_yield = 10.0 * growth_factor

	# 6. Quantum state modifier
	var state_modifier = 1.5 if measurement_result == "👥" else 1.0

	# 7. Local topology bonus (parametric from Jones polynomial)
	var topology_bonus = local_topology.bonus_multiplier  # 1.0x to 3.0x

	# 8. Coherence penalty (decoherence reduces yield)
	var coherence_factor = coherence  # 0.0 to 1.0

	# 9. Faction territory value modifier
	var territory_value_modifier = 1.0
	if _faction_territory_manager:
		var territory_effects = _faction_territory_manager.get_territory_effects(position)
		if territory_effects.has("harvest_value_multiplier"):
			territory_value_modifier = territory_effects.harvest_value_multiplier

	# 10. Final yield calculation
	var final_yield = base_yield * state_modifier * topology_bonus * coherence_factor * territory_value_modifier

	# 11. Award resources to economy
	# FarmEconomy uses 1 quantum energy = 10 credits conversion
	if _economy and measurement_result != "":
		var quantum_energy = final_yield / 10.0  # Convert credits to quantum units
		_economy.receive_harvest(measurement_result, quantum_energy, "harvest")

	# 12. Break entanglements (clear FarmGrid metadata tracking)
	if _entanglement:
		_entanglement.clear_plot_entanglements(plot)

	# 13. Reset plot
	plot.reset()

	# Clear register tracking
	_biome_routing.clear_register_tracking(position)

	# 14. Emit signal with full data
	var yield_data = {
		"success": true,
		"yield": final_yield,
		"base_yield": base_yield,
		"state": measurement_result,
		"state_bonus": state_modifier,
		"topology_bonus": topology_bonus,
		"coherence": coherence,
		"coherence_penalty": coherence_factor,
		"pattern_name": local_topology.pattern.name,
		"jones": local_topology.features.jones_approximation,
		"protection": local_topology.pattern.protection_level,
		"glow_color": local_topology.pattern.glow_color
	}

	plot_harvested.emit(position, yield_data)

	return yield_data


func measure_plot(position: Vector2i) -> String:
	"""Measure quantum state (observer effect). Entanglement means measuring one collapses entire network!

	Uses biome's quantum_computer for register-based measurement.
	"""
	var plot = _plot_manager.get_plot(position)
	if plot == null or not plot.is_planted:
		return ""

	# Get biome for this plot
	var biome = _biome_routing.get_biome_for_plot(position)
	if not biome:
		if _verbose:
			_verbose.warn("farm", "⚠️", "No biome for plot at %s" % position)
		return ""

	var result = ""

	if not biome.quantum_computer:
		if _verbose:
			_verbose.warn("farm", "⚠️", "No quantum system for plot at %s" % position)
		return plot.north_emoji  # Default fallback

	if plot.north_emoji == "" or plot.south_emoji == "":
		return plot.north_emoji  # Default fallback

	# Model C: Use measure_axis directly
	var outcome_emoji = biome.quantum_computer.measure_axis(plot.north_emoji, plot.south_emoji)
	result = outcome_emoji if outcome_emoji != "" else plot.north_emoji
	var basis_outcome = "north" if outcome_emoji == plot.north_emoji else "south"
	if _verbose:
		_verbose.debug("farm", "📊", "Measure operation (Model C): %s collapsed to %s" % [position, result])

	# UPDATE PLOT STATE
	plot.has_been_measured = true
	plot.measured_outcome = basis_outcome  # "north" or "south"

	# For compatibility, still track which plots were in the component
	# (This is purely for logging/visualization - quantum collapse already happened in quantum_computer)
	var measured_ids = {plot.plot_id: true}

	# Flood-fill through FarmGrid entanglement metadata to find component
	# (This mirrors the quantum measurement - all plots in component are now measured)
	var to_check = []
	for entangled_id in plot.entangled_plots.keys():
		to_check.append(entangled_id)

	# Flood-fill through the entanglement network
	while not to_check.is_empty():
		var current_id = to_check.pop_front()

		# Skip if already processed
		if measured_ids.has(current_id):
			continue

		# Find this plot
		var current_pos = _plot_manager.find_plot_by_id(current_id)
		if current_pos == Vector2i(-1, -1):
			continue

		var current_plot = _plot_manager.get_plot(current_pos)
		if not current_plot or not current_plot.is_planted:
			continue

		# Mark as measured (quantum_computer already handled the measurement)
		if _verbose:
			_verbose.debug("quantum", "↪", "Entanglement network collapsed %s (via quantum_computer)" % current_id)
		measured_ids[current_id] = true

		# Add its entangled partners to the queue
		for next_id in current_plot.entangled_plots.keys():
			if not measured_ids.has(next_id):
				to_check.append(next_id)

	# MEASUREMENT COLLAPSES TO CLASSICAL STATE: (Model B)
	# Break ALL entanglements for measured plots (quantum → classical transition)
	for measured_id in measured_ids.keys():
		var measured_pos = _plot_manager.find_plot_by_id(measured_id)
		if measured_pos == Vector2i(-1, -1):
			continue

		var measured_plot = _plot_manager.get_plot(measured_pos)
		if not measured_plot:
			continue

		# Clear all entanglements for this plot (FarmGrid metadata only)
		if not measured_plot.entangled_plots.is_empty():
			var num_broken = measured_plot.entangled_plots.size()
			measured_plot.entangled_plots.clear()
			if _verbose:
				_verbose.debug("quantum", "🔓", "Measurement broke %d entanglements for %s (classical state)" % [num_broken, measured_id])

	# Emit signals for visualization update
	plot_changed.emit(position, "measured", {"outcome": result})
	visualization_changed.emit()

	return result
