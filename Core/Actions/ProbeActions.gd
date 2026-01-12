class_name ProbeActions
extends RefCounted

## ProbeActions - Core EXPLORE → MEASURE → POP gameplay loop (v2 Architecture)
##
## Implements the "Quantum Tomography Paradigm":
##   EXPLORE: Discover pre-existing state in quantum soup (weighted by probability)
##   MEASURE: Born rule collapse, freeze bubble, break entanglement visuals
##   POP: Harvest resource, unbind terminal, return to pool
##
## Key Difference from v1:
##   - Players DISCOVER state, not CREATE it
##   - Probability-weighted selection from density matrix
##   - Unique binding constraint: one terminal per register

const WeightedRandom = preload("res://Core/Utilities/WeightedRandom.gd")


## ============================================================================
## EXPLORE ACTION - Bind terminal to register with probability weighting
## ============================================================================

static func action_explore(plot_pool: RefCounted, biome: RefCounted) -> Dictionary:
	"""Execute EXPLORE action: discover a register in the quantum soup.

	Algorithm:
	1. Get unbound terminal from pool
	2. Get unbound registers with probabilities from biome
	3. Weighted random selection (higher probability = more likely)
	4. Bind terminal to selected register
	5. Return result with emoji for bubble spawn

	Args:
		plot_pool: PlotPool instance
		biome: BiomeBase instance (the quantum soup to probe)

	Returns:
		Dictionary with keys:
		- success: bool
		- terminal: Terminal (if success)
		- register_id: int (if success)
		- emoji_pair: {north, south} (if success)
		- error: String (if failure)
	"""
	# 1. Get unbound terminal
	var terminal = plot_pool.get_unbound_terminal()
	if not terminal:
		return {
			"success": false,
			"error": "no_terminals",
			"message": "All terminals are bound. POP a measured terminal to free one."
		}

	# 2. Get unbound registers with probabilities
	var probabilities = biome.get_register_probabilities()
	if probabilities.is_empty():
		return {
			"success": false,
			"error": "no_registers",
			"message": "No unbound registers available in this biome."
		}

	# 3. Weighted random selection
	var register_ids: Array[int] = []
	var weights: Array[float] = []

	for reg_id in probabilities:
		register_ids.append(reg_id)
		weights.append(probabilities[reg_id])

	var selected_index = WeightedRandom.weighted_choice_index(weights)
	if selected_index < 0:
		return {
			"success": false,
			"error": "selection_failed",
			"message": "Weighted selection failed (all weights zero?)."
		}

	var selected_register = register_ids[selected_index]
	var selected_probability = weights[selected_index]

	# 4. Get emoji pair for this register
	var emoji_pair = biome.get_register_emoji_pair(selected_register)

	# 5. Bind terminal to register
	var bound = plot_pool.bind_terminal(terminal, selected_register, biome, emoji_pair)
	if not bound:
		return {
			"success": false,
			"error": "binding_failed",
			"message": "Failed to bind terminal to register (already bound?)."
		}

	# Mark register as bound in biome
	biome.mark_register_bound(selected_register, terminal.terminal_id)

	return {
		"success": true,
		"terminal": terminal,
		"register_id": selected_register,
		"emoji_pair": emoji_pair,
		"probability": selected_probability
	}


## ============================================================================
## MEASURE ACTION - Collapse quantum state via Born rule
## ============================================================================

static func action_measure(terminal: RefCounted, biome: RefCounted) -> Dictionary:
	"""Execute MEASURE action: collapse the quantum state.

	Algorithm:
	1. Check terminal is bound and not already measured
	2. Get density matrix element for this register
	3. Born rule: P(outcome) = |<outcome|rho|outcome>|
	4. Sample outcome (north or south emoji)
	5. Mark terminal as measured with outcome
	6. (Optional) Break tether visuals for entanglement

	Args:
		terminal: Terminal instance (must be bound)
		biome: BiomeBase instance

	Returns:
		Dictionary with keys:
		- success: bool
		- outcome: String (emoji result)
		- probability: float (Born rule probability)
		- was_entangled: bool (had visible tethers)
		- error: String (if failure)
	"""
	# 1. Validate terminal state
	if not terminal.can_measure():
		if not terminal.is_bound:
			return {
				"success": false,
				"error": "not_bound",
				"message": "Terminal is not bound. Use EXPLORE first."
			}
		if terminal.is_measured:
			return {
				"success": false,
				"error": "already_measured",
				"message": "Terminal already measured. Use POP to harvest."
			}
		return {
			"success": false,
			"error": "cannot_measure",
			"message": "Terminal cannot be measured."
		}

	# 2. Get register probability (diagonal of density matrix)
	var register_id = terminal.bound_register_id
	var north_prob = biome.get_register_probability(register_id)
	var south_prob = 1.0 - north_prob

	# 3. Born rule sampling
	var outcome: String
	var outcome_prob: float

	if randf() < north_prob:
		outcome = terminal.north_emoji
		outcome_prob = north_prob
	else:
		outcome = terminal.south_emoji
		outcome_prob = south_prob

	# Handle edge case where emoji not set
	if outcome.is_empty():
		outcome = "?"

	# 4. Check entanglement before collapse
	var was_entangled = _check_entanglement(register_id, biome)

	# 5. Collapse density matrix (project to measured state)
	_collapse_density_matrix(register_id, outcome == terminal.north_emoji, biome)

	# 6. Mark terminal as measured
	terminal.mark_measured(outcome, outcome_prob)

	return {
		"success": true,
		"outcome": outcome,
		"probability": outcome_prob,
		"was_entangled": was_entangled,
		"register_id": register_id
	}


static func _check_entanglement(register_id: int, biome: RefCounted) -> bool:
	"""Check if register has significant off-diagonal coherence (entanglement)."""
	# This would check the density matrix for off-diagonal elements
	# involving this register. For now, return false as placeholder.
	# Full implementation requires density matrix access.
	if biome.has_method("get_coherence_with_other_registers"):
		var coherence = biome.get_coherence_with_other_registers(register_id)
		return coherence > 0.1  # Threshold for "visible" entanglement
	return false


static func _collapse_density_matrix(register_id: int, is_north: bool, biome: RefCounted) -> void:
	"""Collapse density matrix for measured register.

	Applies projection operator P = |outcome><outcome| to density matrix.
	This zeros off-diagonal elements and updates diagonal.
	"""
	# Call biome's collapse method if available
	if biome.has_method("collapse_register"):
		biome.collapse_register(register_id, is_north)
	elif biome.has_method("project_register"):
		biome.project_register(register_id, 0 if is_north else 1)
	else:
		# Fallback: just log (density matrix may be handled elsewhere)
		print("ProbeActions: collapse_density_matrix called but no handler in biome")


## ============================================================================
## POP ACTION - Harvest resource and unbind terminal
## ============================================================================

static func action_pop(terminal: RefCounted, plot_pool: RefCounted, economy: RefCounted = null) -> Dictionary:
	"""Execute POP action: harvest measured outcome and free terminal.

	Algorithm:
	1. Check terminal is measured
	2. Get measured outcome (resource type)
	3. Add to economy/inventory if available
	4. Unbind terminal from register
	5. Clear measurement state
	6. Return result for particle effects

	Args:
		terminal: Terminal instance (must be measured)
		plot_pool: PlotPool instance
		economy: FarmEconomy instance (optional, for resource tracking)

	Returns:
		Dictionary with keys:
		- success: bool
		- resource: String (emoji that was harvested)
		- amount: int (typically 1)
		- terminal_id: String
		- error: String (if failure)
	"""
	# 1. Validate terminal state
	if not terminal.can_pop():
		if not terminal.is_bound:
			return {
				"success": false,
				"error": "not_bound",
				"message": "Terminal is not bound."
			}
		if not terminal.is_measured:
			return {
				"success": false,
				"error": "not_measured",
				"message": "Terminal not measured. Use MEASURE first."
			}
		return {
			"success": false,
			"error": "cannot_pop",
			"message": "Terminal cannot be popped."
		}

	# 2. Get measured outcome
	var resource = terminal.measured_outcome
	var terminal_id = terminal.terminal_id
	var register_id = terminal.bound_register_id
	var biome = terminal.bound_biome

	# 3. Add to economy if available
	var amount = 1
	if economy and economy.has_method("add_resource"):
		economy.add_resource(resource, amount)

	# 4. Mark register unbound in biome before unbinding terminal
	if biome and biome.has_method("mark_register_unbound"):
		biome.mark_register_unbound(register_id)

	# 5. Unbind terminal (clears measurement state)
	plot_pool.unbind_terminal(terminal)

	return {
		"success": true,
		"resource": resource,
		"amount": amount,
		"terminal_id": terminal_id,
		"register_id": register_id
	}


## ============================================================================
## UTILITY FUNCTIONS
## ============================================================================

static func get_explore_preview(plot_pool: RefCounted, biome: RefCounted) -> Dictionary:
	"""Get preview info for EXPLORE action (for UI display).

	Returns:
		Dictionary with:
		- can_explore: bool
		- available_terminals: int
		- available_registers: int
		- top_probabilities: Array[{emoji, probability}]
	"""
	var available_terminals = plot_pool.get_unbound_count()
	var probabilities = biome.get_register_probabilities() if biome else {}

	# Get top 3 register probabilities for display
	var top_probs: Array = []
	var sorted_regs = probabilities.keys()
	sorted_regs.sort_custom(func(a, b): return probabilities[a] > probabilities[b])

	for i in range(min(3, sorted_regs.size())):
		var reg_id = sorted_regs[i]
		var emoji_pair = biome.get_register_emoji_pair(reg_id) if biome else {}
		top_probs.append({
			"emoji": emoji_pair.get("north", "?"),
			"probability": probabilities[reg_id]
		})

	return {
		"can_explore": available_terminals > 0 and not probabilities.is_empty(),
		"available_terminals": available_terminals,
		"available_registers": probabilities.size(),
		"top_probabilities": top_probs
	}


static func get_measure_preview(terminal: RefCounted, biome: RefCounted) -> Dictionary:
	"""Get preview info for MEASURE action (for UI display).

	Returns:
		Dictionary with:
		- can_measure: bool
		- north_emoji: String
		- south_emoji: String
		- north_probability: float
		- south_probability: float
	"""
	if not terminal or not terminal.is_bound or terminal.is_measured:
		return {
			"can_measure": false,
			"north_emoji": "",
			"south_emoji": "",
			"north_probability": 0.0,
			"south_probability": 0.0
		}

	var north_prob = biome.get_register_probability(terminal.bound_register_id) if biome else 0.5

	return {
		"can_measure": true,
		"north_emoji": terminal.north_emoji,
		"south_emoji": terminal.south_emoji,
		"north_probability": north_prob,
		"south_probability": 1.0 - north_prob
	}


static func get_pop_preview(terminal: RefCounted) -> Dictionary:
	"""Get preview info for POP action (for UI display).

	Returns:
		Dictionary with:
		- can_pop: bool
		- resource: String (emoji to harvest)
		- probability: float (what probability was at measure time)
	"""
	if not terminal or not terminal.is_measured:
		return {
			"can_pop": false,
			"resource": "",
			"probability": 0.0
		}

	return {
		"can_pop": true,
		"resource": terminal.measured_outcome,
		"probability": terminal.measured_probability
	}
