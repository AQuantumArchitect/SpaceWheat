class_name ProbeActions
extends RefCounted

## ProbeActions - Core EXPLORE → MEASURE → POP gameplay loop (v2 Architecture)
##
## Implements the "Ensemble + Drain" model:
##   - ρ represents an ensemble of identically-prepared quantum systems
##   - EXPLORE: Bind terminal to register (no quantum effect)
##   - MEASURE: Sample via Born rule, DRAIN probability from ρ, record claim
##   - POP: Convert recorded probability to credits (no quantum effect)
##   - HARVEST: Global collapse, convert all probability, end level
##
## Physics:
##   - Ensemble interpretation: MEASURE samples without full collapse
##   - Drain simulates "extracting" from the ensemble
##   - External pump (sun) replenishes probability over time
##   - Creates sustainable farming loop: grow → harvest → regrow

const WeightedRandom = preload("res://Core/Utilities/WeightedRandom.gd")
const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")
const ActionCostRuntime = preload("res://Core/GameMechanics/ActionCostRuntime.gd")
const VerboseHelper = preload("res://Core/Config/VerboseHelper.gd")
const BalanceService = preload("res://Core/GameMechanics/BalanceService.gd")


## ============================================================================
## EXPLORE ACTION - Bind terminal to register with probability weighting
## ============================================================================

static func action_explore(terminal_pool, biome, economy = null) -> Dictionary:
	# 0. Null checks for required parameters
	if not terminal_pool:
		return {
			"success": false,
			"error": "no_pool",
			"message": "Plot pool not initialized."
		}
	if not biome:
		return {
			"success": false,
			"error": "no_biome",
			"message": "Biome not initialized."
		}

	# 1. Get unbound terminal
	var terminal = terminal_pool.get_unbound_terminal()
	if not terminal:
		return {
			"success": false,
			"error": "no_terminals",
			"message": "All terminals are bound. POP a measured terminal to free one.",
			"blocked": true
		}

	# 2. Check for unbound registers (availability gate)
	var available_registers = biome.get_available_registers_v2(terminal_pool) if biome.has_method("get_available_registers_v2") else []
	if available_registers.is_empty():
		return {
			"success": false,
			"error": "no_registers",
			"message": "Explore blocked: no unbound registers in this biome.",
			"blocked": true
		}

	# 2b. Preflight cost (after availability gates)
	var explore_cost_gate = _preflight_action(economy, "explore")
	if not explore_cost_gate.get("ok", true):
		var cost = explore_cost_gate.get("cost", {})
		var missing = cost.keys()[0] if cost.size() > 0 else "resources"
		return {
			"success": false,
			"error": "insufficient_resources",
			"message": "Need %s to explore." % missing
		}

	# 3. Get unbound registers with probabilities (queries TerminalPool for binding state)
	var probabilities = biome.get_register_probabilities(terminal_pool)
	if probabilities.is_empty():
		return {
			"success": false,
			"error": "no_registers",
			"message": "Explore blocked: no unbound registers in this biome.",
			"blocked": true
		}

	# 3. Weighted random selection using squared probabilities
	# This makes high-probability registers MORE likely to be discovered
	# Squaring ensures weights are always positive and emphasizes differences
	var register_ids: Array[int] = []
	var weights: Array[float] = []

	for reg_id in probabilities:
		register_ids.append(reg_id)
		var prob = probabilities[reg_id]
		# Use prob² for weighting (ensures positive, emphasizes high-prob states)
		weights.append(prob * prob)

	var selected_index = WeightedRandom.weighted_choice_index(weights)
	if selected_index < 0:
		return {
			"success": false,
			"error": "selection_failed",
			"message": "Explore blocked: weighted selection failed (all weights zero?).",
			"blocked": true
		}

	var selected_register = register_ids[selected_index]
	var selected_probability = weights[selected_index]

	# 4. Get emoji pair for this register
	var emoji_pair = biome.get_register_emoji_pair(selected_register)

	# 5. Get biome name for binding (decouple from object reference)
	var biome_name = biome.get_biome_type() if biome.has_method("get_biome_type") else biome.name

	# 6. Bind terminal to register with biome NAME (Terminal is now the single source of truth)
	var bound = terminal_pool.bind_terminal(terminal, selected_register, biome_name, emoji_pair)
	if not bound:
		return {
			"success": false,
			"error": "binding_failed",
			"message": "Failed to bind terminal to register (already bound?).",
			"blocked": true
		}

	# NOTE: No need to call mark_register_bound() - Terminal.is_bound is the source of truth
	# TerminalPool.is_register_bound() queries Terminal directly

	# Commit cost after successful bind
	var explore_cost = explore_cost_gate.get("cost", {})
	if not _commit_cost(economy, explore_cost, "explore"):
		terminal_pool.unbind_terminal(terminal)
		return {
			"success": false,
			"error": "cost_commit_failed",
			"message": "Explore failed: unable to spend cost."
		}

	return {
		"success": true,
		"terminal": terminal,
		"register_id": selected_register,
		"emoji_pair": emoji_pair,
		"probability": selected_probability,
		"biome_name": biome_name
	}


## ============================================================================
## MEASURE ACTION - Sample + projective collapse (no drain)
## ============================================================================

static func action_measure(terminal, biome, economy = null) -> Dictionary:
	# 0. Null checks - terminal and biome must exist
	if not terminal:
		return {
			"success": false,
			"error": "no_terminal",
			"message": "No terminal to measure. Use EXPLORE first.",
			"blocked": true
		}
	if not biome:
		return {
			"success": false,
			"error": "no_biome",
			"message": "Biome not initialized.",
			"blocked": true
		}

	# 1. Validate terminal state consistency
	var state_error = terminal.validate_state()
	if state_error != "":
		return {
			"success": false,
			"error": "invalid_terminal_state",
			"message": "Terminal in invalid state: %s" % state_error,
			"blocked": true
		}

	# 2. Validate terminal can be measured
	if not terminal.can_measure():
		if not terminal.is_bound:
			return {
				"success": false,
				"error": "not_bound",
				"message": "Terminal is not bound. Use EXPLORE first.",
				"blocked": true
			}
		if terminal.is_measured:
			return {
				"success": false,
				"error": "already_measured",
				"message": "Terminal already measured. Use POP to harvest.",
				"blocked": true
			}
		return {
			"success": false,
			"error": "cannot_measure",
			"message": "Terminal cannot be measured.",
			"blocked": true
		}

	# 2b. Preflight cost (after validation gates)
	var measure_cost_gate = _preflight_action(economy, "measure")
	if not measure_cost_gate.get("ok", true):
		var cost = measure_cost_gate.get("cost", {})
		var missing = cost.keys()[0] if cost.size() > 0 else "resources"
		return {
			"success": false,
			"error": "insufficient_resources",
			"message": "Need %s to measure." % missing
		}

	# 2. Get current probability snapshot from lookahead packet (viz_cache)
	var register_id = terminal.bound_register_id
	var north_prob = biome.get_register_probability(register_id) if biome else 0.5
	var south_prob = 1.0 - north_prob
	var snapshot: Dictionary = {}
	var measured_purity = biome.get_purity() if biome else 0.0

	if biome and biome.viz_cache:
		var bloch = biome.viz_cache.get_bloch(register_id)
		if not bloch.is_empty():
			snapshot = bloch.duplicate()
		var snap = biome.viz_cache.get_snapshot(register_id)
		for k in snap.keys():
			snapshot[k] = snap[k]
		var has_p0 = snap.has("p0")
		var has_p1 = snap.has("p1")
		if has_p0:
			north_prob = snap.get("p0", north_prob)
		if has_p1:
			south_prob = snap.get("p1", south_prob)
		elif has_p0:
			south_prob = 1.0 - north_prob
		if snap.has("purity") and snap.get("purity", -1.0) >= 0.0:
			measured_purity = snap.get("purity", measured_purity)

	# 3. Born rule sampling
	var outcome: String
	var outcome_prob: float
	var is_north: bool

	if randf() < north_prob:
		outcome = terminal.north_emoji
		outcome_prob = north_prob
		is_north = true
	else:
		outcome = terminal.south_emoji
		outcome_prob = south_prob
		is_north = false

	# Handle edge case where emoji not set
	if outcome.is_empty():
		outcome = "?"

	# 4. Record the probability - this is the "claim" that POP will convert
	var recorded_probability = outcome_prob

	# 5. Check entanglement before projection
	var was_entangled = _check_entanglement(register_id, biome)
	var projection_success = _project_register(biome, register_id, is_north)

	# 6. Mark terminal as measured with RECORDED probability and collapsed purity.
	measured_purity = 1.0
	snapshot["purity"] = measured_purity
	terminal.mark_measured(outcome, recorded_probability, measured_purity, snapshot)

	# 7. FREE THE REGISTER - allow another terminal to bind to it
	# Terminal keeps its measurement snapshot for REAP to harvest
	terminal.release_register()

	# 8. Commit cost after successful measurement
	var measure_cost = measure_cost_gate.get("cost", {})
	if not _commit_cost(economy, measure_cost, "measure"):
		# NOTE: We don't roll back the measurement since it already happened
		# This should rarely occur since we preflighted the cost
		return {
			"success": false,
			"error": "cost_commit_failed",
			"message": "Measurement succeeded but unable to spend cost."
		}

	return {
		"success": true,
		"outcome": outcome,
		"probability": recorded_probability,
		"recorded_probability": recorded_probability,
		"was_entangled": was_entangled,
		"was_projected": projection_success,
		"projective_collapse": true,
		"register_id": register_id
	}


static func _check_entanglement(register_id: int, biome) -> bool:
	if not biome:
		return false
	if biome.has_method("get_coherence_with_other_registers"):
		var coherence = biome.get_coherence_with_other_registers(register_id)
		return coherence > 0.1  # Threshold for "visible" entanglement
	return false


static func _project_register(biome, register_id: int, is_north: bool) -> bool:
	if not biome or not biome.quantum_computer:
		return false
	var qc = biome.quantum_computer
	if qc.has_method("project_qubit"):
		return qc.project_qubit(register_id, 0 if is_north else 1)
	return false


## ============================================================================
## POP ACTION - Convert recorded probability to credits
## ============================================================================

static func action_pop(terminal, terminal_pool, economy = null, farm = null) -> Dictionary:
	var harvest_result = _prepare_pop_result(terminal, terminal_pool, economy, farm)
	if not harvest_result.get("success", false):
		return harvest_result

	# Capture biome name before unbinding
	var biome_name = harvest_result.get("biome_name", "")
	if biome_name == "":
		biome_name = terminal.measured_biome_name if terminal.measured_biome_name != "" else terminal.bound_biome_name
	var register_id = harvest_result.get("register_id", -1)

	terminal_pool.unbind_terminal(terminal)
	_log("info", "farm", "📤", "Register %d released in %s" % [register_id, biome_name if biome_name else "biome"])

	return harvest_result


static func action_reap(arg0, arg1 = null, arg2 = null, arg3 = null) -> Dictionary:
	# New path: action_reap(farm, economy)
	if _looks_like_farm(arg0):
		var farm = arg0
		var economy = arg1 if arg1 != null else (farm.economy if ("economy" in farm) else null)
		return _action_reap_global(farm, economy)

	# Legacy compatibility path: action_reap(terminal, terminal_pool, economy, farm)
	return _action_reap_terminal(arg0, arg1, arg2, arg3)


static func _action_reap_terminal(terminal, terminal_pool, economy = null, farm = null) -> Dictionary:
	return action_pop(terminal, terminal_pool, economy, farm)


static func _action_reap_global(farm, economy = null) -> Dictionary:
	if not farm or not economy:
		return {
			"success": false,
			"error": "no_farm",
			"message": "Farm not ready."
		}

	var active_biomes = _get_active_biomes_for_reap(farm)
	if active_biomes.is_empty():
		return {
			"success": false,
			"error": "no_active_biomes",
			"message": "Reap requires at least one active biome with bound terminals."
		}

	var reap_count_before = _get_reap_count(farm)
	var reap_cost = BalanceService.get_reap_cost(farm, reap_count_before)
	var reap_cost_gate = _preflight_cost(economy, reap_cost)
	if not reap_cost_gate.get("ok", true):
		return {
			"success": false,
			"error": "insufficient_resources",
			"message": "Need %s to reap." % _format_cost(reap_cost)
		}
	if not _commit_cost(economy, reap_cost, "reap"):
		return {
			"success": false,
			"error": "cost_commit_failed",
			"message": "Reap failed: unable to spend cost."
		}

	var reap_cycles = int(BalanceService.get_tuning_value(farm, "reap_evolution_cycles", 13))
	reap_cycles = maxi(reap_cycles, 0)
	var active_biome_names: Array = []
	for biome in active_biomes:
		var biome_name = biome.get_biome_type() if biome and biome.has_method("get_biome_type") else ""
		if biome_name != "":
			active_biome_names.append(biome_name)

	var fast_forward_result = {"success": true, "cycles": reap_cycles, "evolved_steps": 0}
	var batcher = farm.biome_evolution_batcher if ("biome_evolution_batcher" in farm) else null
	if reap_cycles > 0:
		if batcher and batcher.has_method("run_additional_cycles"):
			fast_forward_result = batcher.run_additional_cycles(reap_cycles, active_biome_names)
		else:
			fast_forward_result = _manual_fast_forward_biomes(active_biomes, reap_cycles)

	var flux_to_credits = float(BalanceService.get_tuning_value(farm, "flux_to_credits", 1.0))
	var reap_base_yield = float(BalanceService.get_tuning_value(farm, "reap_base_yield", 50.0))
	var known_emojis: Array = farm.get_known_emojis() if farm.has_method("get_known_emojis") else []

	var flux_totals: Dictionary = {}
	var icon_totals: Dictionary = {}
	var total_flux_credits = 0
	var total_icon_credits = 0

	for biome in active_biomes:
		if not biome or not biome.quantum_computer:
			continue
		var qc = biome.quantum_computer

		# Phase 2: convert accumulated sink flux to credits.
		var fluxes: Dictionary = {}
		if qc.has_method("get_all_sink_fluxes"):
			fluxes = qc.get_all_sink_fluxes()
		for emoji in fluxes.keys():
			var raw_flux = float(fluxes.get(emoji, 0.0))
			var credits = int(raw_flux * flux_to_credits)
			if credits <= 0:
				continue
			economy.add_resource(emoji, credits, "reap_flux")
			flux_totals[emoji] = flux_totals.get(emoji, 0) + credits
			total_flux_credits += credits
		if qc.has_method("reset_sink_flux"):
			qc.reset_sink_flux()

		# Phase 3: broad IconMap-style harvest from live biome mass distribution.
		var mass_map = _resolve_mass_map_for_biome(biome)
		var by_emoji: Dictionary = mass_map.get("by_emoji", {})
		var total_mass = float(mass_map.get("total", 0.0))
		if total_mass <= 0.0:
			continue
		for emoji in by_emoji.keys():
			var mass = float(by_emoji.get(emoji, 0.0))
			if mass <= 0.0:
				continue
			var mass_fraction = mass / total_mass
			var purity = _resolve_emoji_purity(biome, emoji)
			var purity_bonus = (1.0 + purity) if emoji in known_emojis else purity
			var credits = int(mass_fraction * reap_base_yield * purity_bonus)
			if credits <= 0:
				continue
			economy.add_resource(emoji, credits, "reap_iconmap")
			icon_totals[emoji] = icon_totals.get(emoji, 0) + credits
			total_icon_credits += credits

	var reap_count_after = reap_count_before + 1
	_set_reap_count(farm, reap_count_after)

	return {
		"success": true,
		"global": true,
		"active_biomes": active_biome_names,
		"reap_count_before": reap_count_before,
		"reap_count_after": reap_count_after,
		"reap_cost": reap_cost,
		"evolution_cycles": reap_cycles,
		"fast_forward": fast_forward_result,
		"flux_totals": flux_totals,
		"icon_totals": icon_totals,
		"total_flux_credits": total_flux_credits,
		"total_icon_credits": total_icon_credits,
		"total_credits": total_flux_credits + total_icon_credits,
		"harvest_results": []
	}


static func _prepare_pop_result(terminal, terminal_pool, economy = null, farm = null) -> Dictionary:
	if not terminal:
		return {
			"success": false,
			"error": "no_terminal",
			"message": "No terminal to harvest. Use MEASURE first.",
			"blocked": true
		}
	if not terminal_pool:
		return {
			"success": false,
			"error": "no_pool",
			"message": "Plot pool not initialized.",
			"blocked": true
		}

	var state_error = terminal.validate_state()
	if state_error != "":
		return {
			"success": false,
			"error": "invalid_terminal_state",
			"message": "Terminal in invalid state: %s" % state_error,
			"blocked": true
		}

	if not terminal.can_pop():
		if not terminal.is_measured:
			return {
				"success": false,
				"error": "not_measured",
				"message": "Terminal not measured. Use MEASURE first.",
				"blocked": true
			}
		return {
			"success": false,
			"error": "cannot_pop",
			"message": "Terminal cannot be popped.",
			"blocked": true
		}

	var resource = terminal.measured_outcome
	var recorded_prob = terminal.measured_probability
	var terminal_id = terminal.terminal_id
	var register_id = terminal.measured_register_id
	var biome_name = terminal.measured_biome_name
	var purity = _resolve_terminal_purity(terminal, farm)

	# Check if emoji is in known vocabulary (known gets a big multiplier, unknown is penalized)
	var is_known_vocab = false
	if farm and farm.has_method("get_known_emojis"):
		var known_emojis = farm.get_known_emojis()
		is_known_vocab = resource in known_emojis

	var biome = _resolve_biome_from_terminal(farm, terminal)
	var mass_map = _resolve_mass_map_for_biome(biome)
	var by_emoji: Dictionary = mass_map.get("by_emoji", {})
	var total_mass = float(mass_map.get("total", 0.0))
	var mass_fraction = 0.0
	if total_mass > 0.0:
		mass_fraction = float(by_emoji.get(resource, 0.0)) / total_mass
	else:
		mass_fraction = maxf(recorded_prob, 0.0)

	var pop_base_yield_scale = float(BalanceService.get_tuning_value(farm, "pop_base_yield_scale", 100.0))
	var purity_bonus = (1.0 + purity) if is_known_vocab else purity
	var credits = mass_fraction * pop_base_yield_scale * purity_bonus
	var resource_amount = maxi(int(credits), 1)

	if economy:
		var pop_cost_gate = _preflight_action(economy, "pop")
		if not pop_cost_gate.get("ok", true):
			return {
				"success": false,
				"error": "insufficient_resources",
				"message": "Need 👥 to pop."
			}
		if not _commit_cost(economy, pop_cost_gate.get("cost", {}), "pop"):
			return {
				"success": false,
				"error": "cost_commit_failed",
				"message": "Pop failed: unable to spend cost."
			}
		economy.add_resource(resource, resource_amount, "pop")

	return {
		"success": true,
		"resource": resource,
		"amount": resource_amount,
		"recorded_probability": recorded_prob,
		"purity": purity,
		"mass_fraction": mass_fraction,
		"purity_bonus": purity_bonus,
		"credits": credits,
		"terminal_id": terminal_id,
		"register_id": register_id,
		"biome_name": biome_name
	}


## ============================================================================
## HARVEST ALL ACTION - End of Turn (3R)
## ============================================================================

static func action_clear_all(terminal_pool) -> Dictionary:
	if not terminal_pool:
		return {
			"success": false,
			"error": "no_pool",
			"message": "Plot pool not initialized."
		}

	var cleared_count = 0
	var terminals_to_clear: Array = []

	# Collect all bound terminals
	if terminal_pool.has_method("get_all_terminals"):
		for terminal in terminal_pool.get_all_terminals():
			if terminal and terminal.is_bound:
				terminals_to_clear.append(terminal)

	# Unbind each terminal (no harvesting)
	for terminal in terminals_to_clear:
		terminal_pool.unbind_terminal(terminal)
		cleared_count += 1
	
	_log("info", "farm", "🧹", "Cleared %d terminals (no harvest)" % cleared_count)

	return {
		"success": true,
		"terminals_cleared": cleared_count
	}


static func _looks_like_farm(value) -> bool:
	if value == null:
		return false
	return ("grid" in value) and ("terminal_pool" in value)


static func _resolve_biome_from_terminal(farm, terminal):
	if not farm or not terminal:
		return null
	if not ("grid" in farm) or not farm.grid or not farm.grid.has_biomes():
		return null
	var biome_name = terminal.measured_biome_name if terminal.measured_biome_name != "" else terminal.bound_biome_name
	return farm.grid.get_biome(biome_name)


static func _resolve_terminal_purity(terminal, farm = null) -> float:
	if not terminal:
		return 0.0
	var purity = float(terminal.measured_purity)
	var biome = _resolve_biome_from_terminal(farm, terminal)
	if biome and biome.viz_cache and terminal.measured_register_id >= 0:
		var snap = biome.viz_cache.get_snapshot(terminal.measured_register_id)
		if snap.has("purity"):
			purity = float(snap.get("purity", purity))
	return clampf(purity, 0.0, 1.0)


static func _resolve_mass_map_for_biome(biome) -> Dictionary:
	if not biome:
		return {"by_emoji": {}, "total": 0.0, "source": "none"}

	if biome.has_method("get_icon_map"):
		var icon_map = biome.get_icon_map()
		var by_emoji = icon_map.get("by_emoji", {})
		var total = float(icon_map.get("total", 0.0))
		if by_emoji is Dictionary and total > 0.0:
			return {"by_emoji": by_emoji, "total": total, "source": "icon_map"}

	if biome.quantum_computer and biome.quantum_computer.has_method("get_all_populations"):
		var populations = biome.quantum_computer.get_all_populations()
		var by_emoji_qc: Dictionary = {}
		var total_qc = 0.0
		for emoji in populations.keys():
			var mass = float(populations[emoji])
			if mass <= 0.0:
				continue
			by_emoji_qc[emoji] = mass
			total_qc += mass
		if total_qc > 0.0:
			return {"by_emoji": by_emoji_qc, "total": total_qc, "source": "qc_populations"}

	return {"by_emoji": {}, "total": 0.0, "source": "none"}


static func _resolve_emoji_purity(biome, emoji: String) -> float:
	if not biome:
		return 0.0
	if biome.viz_cache and biome.viz_cache.has_metadata():
		var q = biome.viz_cache.get_qubit(emoji)
		if q >= 0:
			var snap = biome.viz_cache.get_snapshot(q)
			if snap.has("purity"):
				return clampf(float(snap.get("purity", 0.0)), 0.0, 1.0)
	if biome.has_method("get_purity"):
		return clampf(float(biome.get_purity()), 0.0, 1.0)
	return 0.0


static func _get_active_biomes_for_reap(farm) -> Array:
	var out: Array = []
	if not farm or not ("grid" in farm) or not farm.grid or not farm.grid.has_biomes():
		return out
	var terminal_pool = farm.terminal_pool if ("terminal_pool" in farm) else null

	for biome_name in farm.grid.get_biome_names():
		var biome = farm.grid.get_biome(biome_name)
		if not biome or not biome.quantum_computer:
			continue
		if "quantum_evolution_enabled" in biome and not biome.quantum_evolution_enabled:
			continue
		if "evolution_paused" in biome and biome.evolution_paused:
			continue
		if terminal_pool:
			var has_terminal_context = false
			var biome_name_str = str(biome_name)
			if terminal_pool.has_method("get_terminals_in_biome"):
				var terminals = terminal_pool.get_terminals_in_biome(biome_name_str)
				has_terminal_context = not terminals.is_empty()
			if not has_terminal_context and terminal_pool.has_method("get_measured_terminals"):
				for terminal in terminal_pool.get_measured_terminals():
					if not terminal:
						continue
					var measured_biome_name = str(terminal.measured_biome_name if "measured_biome_name" in terminal else "")
					var bound_biome_name = str(terminal.bound_biome_name if "bound_biome_name" in terminal else "")
					if measured_biome_name == biome_name_str or bound_biome_name == biome_name_str:
						has_terminal_context = true
						break
			if not has_terminal_context:
				continue
		out.append(biome)
	return out


static func _manual_fast_forward_biomes(active_biomes: Array, cycles: int) -> Dictionary:
	if cycles <= 0:
		return {"success": true, "cycles": 0, "evolved_steps": 0}
	var evolved_steps = 0
	var dt = 0.17
	for _i in range(cycles):
		for biome in active_biomes:
			if not biome or not biome.quantum_computer:
				continue
			var max_dt = biome.max_evolution_dt if "max_evolution_dt" in biome else dt
			biome.quantum_computer.evolve(dt, max_dt, null)
			evolved_steps += 1
			if biome.viz_cache:
				var packet = biome.quantum_computer.export_bloch_packet() if biome.quantum_computer.has_method("export_bloch_packet") else PackedFloat64Array()
				var num_qubits = biome.quantum_computer.register_map.num_qubits if biome.quantum_computer.register_map else 0
				if packet.size() > 0 and num_qubits > 0:
					biome.viz_cache.update_from_bloch_packet(packet, num_qubits)
				if biome.quantum_computer.has_method("get_purity"):
					biome.viz_cache.update_purity(biome.quantum_computer.get_purity())
	return {"success": true, "cycles": cycles, "evolved_steps": evolved_steps}


static func _get_reap_count(farm) -> int:
	if not farm:
		return 0
	if farm.has_method("get_reap_count"):
		return int(farm.get_reap_count())
	if "reap_count" in farm:
		return int(farm.reap_count)
	return 0


static func _set_reap_count(farm, value: int) -> void:
	if not farm:
		return
	if farm.has_method("set_reap_count"):
		farm.set_reap_count(value)
	elif "reap_count" in farm:
		farm.reap_count = value


static func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return "resources"
	var keys = cost.keys()
	keys.sort()
	var parts: Array[String] = []
	for emoji in keys:
		parts.append("%s×%d" % [str(emoji), int(cost[emoji])])
	return " ".join(parts)


static func _save_density_matrices(biome) -> Dictionary:
	if not biome:
		return {}

	var snapshot = {
		"timestamp": Time.get_ticks_msec(),
		"biome_type": biome.get_biome_type() if biome.has_method("get_biome_type") else "unknown"
	}

	# Try to get density matrix from biome
	if biome.has_method("get_density_matrix"):
		var dm = biome.get_density_matrix()
		if dm and dm.has_method("serialize"):
			snapshot["density_matrix"] = dm.serialize()
		elif dm and dm.has_method("get_state"):
			snapshot["density_matrix"] = dm.get_state()

	# Try to get register states
	if biome.has_method("get_register_probabilities"):
		snapshot["probabilities"] = biome.get_register_probabilities()

	return snapshot


## ============================================================================
## UTILITY FUNCTIONS
## ============================================================================

static func get_explore_preview(terminal_pool, biome) -> Dictionary:
	var available_terminals = terminal_pool.get_unbound_count()
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


static func get_measure_preview(terminal, biome) -> Dictionary:
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

# ============================================================================
# INTERNAL HELPERS
# ============================================================================

static func _preflight_action(economy, action_name: String, context: Dictionary = {}) -> Dictionary:
	return ActionCostRuntime.preflight_action(economy, action_name, context, true)


static func _preflight_cost(economy, cost: Dictionary) -> Dictionary:
	return ActionCostRuntime.preflight_cost(economy, cost, true)


static func _commit_cost(economy, cost: Dictionary, reason: String = "") -> bool:
	return ActionCostRuntime.commit_cost(economy, cost, reason, true)


static func _log(level: String, category: String, emoji: String, message: String) -> void:
	VerboseHelper.log(level, category, emoji, message)
