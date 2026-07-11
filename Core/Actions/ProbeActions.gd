class_name ProbeActions
extends RefCounted

## ProbeActions - Core EXPLORE → MEASURE → POP gameplay loop (v2 Architecture)
##
## Implements the "Ensemble + Drain" model:
##   - ρ represents an ensemble of identically-prepared quantum systems
##   - EXPLORE: Bind terminal to register (no quantum effect)
##   - MEASURE: Born sample + partial drain (η × purity fraction of population)
##   - POP: Convert recorded probability to credits (no quantum effect)
##   - HARVEST: Broad multi-terminal cleanup / harvest loop
##
## Measurement Physics:
##   - Born rule selects outcome (player sees 100% pure collapsed state)
##   - Biome receives partial Lindblad drain: ρ_kk *= (1-η), coherences *= √(1-η)
##   - η = measurement_drain_base × purity (tunable, default 0.15 at full purity)
##   - External pump (sun) replenishes drained population over time
##   - Creates sustainable farming loop: grow → harvest → regrow


## ============================================================================
## EXPLORE ACTION — Bind terminal to a specific register
## ============================================================================
##
## Invariant: plot_idx ≡ register_id. A biome's column layout IS its qubit
## layout — the bubble at column c always represents register c. There is no
## probability-weighted random picking anymore; the caller names the register
## (via `register_id` or implicitly via `grid_pos.x` in the instrument wrapper).
##
## Semantics: EXPLORE is a deterministic commitment — "place a probe on this
## specific qubit of the biome." Biomes are crafted artifacts; each register
## has a fixed visual position chosen by the biome designer.
##
## Headless/diagnostic default: if `register_id == -1`, pick the first unbound
## register (deterministic and reproducible, no randomness).

static func action_explore(terminal_pool, biome, economy = null, register_id: int = -1) -> Dictionary:
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

	# 1. Get unbound terminal from the pool
	var terminal = terminal_pool.get_unbound_terminal()
	if not terminal:
		return {
			"success": false,
			"error": "no_terminals",
			"message": "All terminals are bound. POP a measured terminal to free one.",
			"blocked": true
		}

	# 2. Resolve the target register. Caller-specified takes priority; falls back
	#    to the first unbound register for headless callers with no grid context.
	var biome_name = biome.get_biome_type()
	var num_qubits = 0
	if biome.quantum_computer and biome.quantum_computer.register_map:
		num_qubits = biome.quantum_computer.register_map.num_qubits

	var resolved_register = register_id
	if resolved_register < 0:
		resolved_register = _first_unbound_register(biome, terminal_pool)
		if resolved_register < 0:
			return {
				"success": false,
				"error": "no_registers",
				"message": "Explore blocked: no unbound registers in this biome.",
				"blocked": true
			}
	else:
		# Explicit register: must exist and be unbound.
		if num_qubits > 0 and resolved_register >= num_qubits:
			return {
				"success": false,
				"error": "invalid_register",
				"message": "Column %d has no register in %s (only %d axes)." % [
					resolved_register, biome_name, num_qubits],
				"blocked": true
			}
		if terminal_pool.is_register_bound(resolved_register, biome_name):
			return {
				"success": false,
				"error": "already_bound",
				"message": "Register %d in %s is already explored." % [resolved_register, biome_name],
				"blocked": true
			}

	# 3. Preflight cost (after availability gates)
	var explore_cost_gate = _preflight_action(economy, "explore")
	if not explore_cost_gate.get("ok", true):
		var cost = explore_cost_gate.get("cost", {})
		var missing = cost.keys()[0] if cost.size() > 0 else "resources"
		return {
			"success": false,
			"error": "insufficient_resources",
			"message": "Need %s to explore." % missing
		}

	# 4. Emoji pair for the chosen register (for terminal display)
	var emoji_pair = biome.get_register_emoji_pair(resolved_register)

	# 5. Bind terminal → register (biome by name; Terminal is single source of truth)
	var bound = terminal_pool.bind_terminal(terminal, resolved_register, biome_name, emoji_pair)
	if not bound:
		return {
			"success": false,
			"error": "binding_failed",
			"message": "Failed to bind terminal to register %d." % resolved_register,
			"blocked": true
		}

	# 6. Commit cost
	var explore_cost = explore_cost_gate.get("cost", {})
	if not _commit_cost(economy, explore_cost, "explore"):
		terminal_pool.unbind_terminal(terminal)
		return {
			"success": false,
			"error": "cost_commit_failed",
			"message": "Explore failed: unable to spend cost."
		}

	# 7. Probability-at-binding — no longer drives selection, but reported for
	#    telemetry/UI and kept as `probability` in the result.
	var probability = 0.0
	if biome.has_method("get_register_probability"):
		probability = float(biome.get_register_probability(resolved_register))

	return {
		"success": true,
		"terminal": terminal,
		"register_id": resolved_register,
		"emoji_pair": emoji_pair,
		"probability": probability,
		"biome_name": biome_name
	}


static func _first_unbound_register(biome, terminal_pool) -> int:
	# Deterministic fallback for callers without a grid context (diagnostics,
	# headless runners). Returns the lowest register_id with no terminal bound,
	# or -1 if all are taken.
	if not biome or not terminal_pool:
		return -1
	var available: Array = []
	if biome.has_method("get_available_registers"):
		available = biome.get_available_registers(terminal_pool)
	if available.is_empty():
		return -1
	var lowest = int(available[0])
	for r in available:
		if int(r) < lowest:
			lowest = int(r)
	return lowest


## ============================================================================
## MEASURE ACTION - Sample + projective collapse (no drain)
## ============================================================================

static func action_measure(terminal, biome, economy = null, farm = null) -> Dictionary:
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
		# Check measured BEFORE bound: a measured terminal releases its register
		# (is_bound→false), so the bound check would otherwise mislabel it "not bound".
		if terminal.is_measured:
			return {
				"success": false,
				"error": "already_measured",
				"message": "Already measured — Q harvests it.",
				"blocked": true
			}
		if not terminal.is_bound:
			return {
				"success": false,
				"error": "not_bound",
				"message": "Nothing to measure — select a plot first (G H J K L ;).",
				"blocked": true
			}
		return {
			"success": false,
			"error": "cannot_measure",
			"message": "Terminal cannot be measured.",
			"blocked": true
		}

	# 2b. Preflight cost (after validation gates).
	# FLAT cost since the 🍞 cutover (2026-07-11): the strike is an expedition
	# and supplies cost the same whether the locals are strangers. The old
	# unfamiliarity multiplier (×3 at affinity 0) was tuned for the plentiful
	# ❄️ era; on the bread currency it tripled the burn and closed the door
	# on a fresh wallet in ~11 strikes. Chaos stays in the DEAL (surprisal
	# rewards, pop concentration tax); the door price stays flat.
	# Override-aware: route through ActionCostRuntime so balance-board action_cost
	# overrides actually reach measure (EconomyConstants is the fallback inside it).
	var scaled_measure_cost = ActionCostRuntime.get_action_cost(farm, "measure", {})
	var measure_cost_gate = _preflight_cost(economy, scaled_measure_cost)
	if not measure_cost_gate.get("ok", true):
		var cost = measure_cost_gate.get("cost", {})
		var missing = cost.keys()[0] if cost.size() > 0 else "resources"
		return {
			"success": false,
			"error": "insufficient_resources",
			"message": "Need %s to measure." % missing
		}

	# 2. Resolve the live measurement context once, then sample and finalize.
	var measure_ctx = _resolve_measurement_context(terminal, biome)
	var register_id = int(measure_ctx.get("register_id", terminal.bound_register_id))
	var north_prob = float(measure_ctx.get("north_prob", 0.5))
	var south_prob = float(measure_ctx.get("south_prob", 1.0 - north_prob))
	var snapshot: Dictionary = measure_ctx.get("snapshot", {})
	var measured_purity = float(measure_ctx.get("measured_purity", 0.0))

	if north_prob < 0.0 or south_prob < 0.0:
		return {
			"success": false,
			"error": "measurement_prob_unavailable",
			"message": "Measure failed: probability state unavailable.",
			"blocked": true
		}

	# 3. Born rule sampling — seeded for save-load reproducibility.
	var outcome_ctx = _sample_born_outcome(terminal, biome, register_id, north_prob, south_prob)
	var outcome: String = outcome_ctx.get("outcome", "?")
	var outcome_prob: float = float(outcome_ctx.get("outcome_prob", north_prob))
	var is_north: bool = bool(outcome_ctx.get("is_north", true))
	var recorded_probability = outcome_prob

	# 4. Collapse the measured axis.
	#    Closed system (default): a full projective (von Neumann) collapse — the only
	#    irreversible act in a unitary world. The qubit pins to the outcome pole; the
	#    Hamiltonian re-spreads it over the following ticks (time + H is the new pump).
	#    Open system (DLC): a partial ensemble drain (weak measurement) of η, with
	#    coherences decaying as √(1-η), leaving structure for sustainable re-measurement.
	var was_entangled = _check_entanglement(register_id, biome)
	var closed: bool = not _biome_open_here(biome)
	var drain_eta: float = 1.0
	var collapse_ok: bool
	if closed:
		collapse_ok = _project_register(biome, register_id, is_north)
	else:
		drain_eta = _resolve_drain_fraction(biome, measured_purity, farm)
		collapse_ok = _drain_register(biome, register_id, is_north, drain_eta)
	if not collapse_ok:
		# Honest failure: the quantum state was NOT collapsed (no quantum_computer, or
		# missing project/drain). Don't finalize the terminal or charge the cost — a
		# fabricated "success" with an unchanged state is exactly the lie we forbid.
		return {
			"success": false,
			"error": "collapse_failed",
			"message": "Measurement collapse failed: biome quantum state unavailable."
		}

	# 5. Mark terminal as measured and free the register.
	_finalize_measurement_terminal(terminal, outcome, recorded_probability, snapshot)

	# 6. Commit cost after successful measurement
	if not _commit_cost(economy, scaled_measure_cost, "measure"):
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
		"drain_eta": drain_eta,
		"ensemble_drain": not closed,
		"projective_collapse": closed,
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
	if not qc.has_method("project_qubit"):
		return false
	# Guard against zero-trace projection: verify the chosen outcome has
	# non-zero probability in the live density matrix. If Born sampling
	# picked from a stale viz_cache, the live state may disagree.
	var outcome_pole = 0 if is_north else 1
	if qc.has_method("get_marginal"):
		var live_prob = qc.get_marginal(register_id, outcome_pole)
		if live_prob < 1e-12:
			# Flip to the opposite outcome which must have ~1.0 probability
			outcome_pole = 1 - outcome_pole
	var projected: bool = qc.project_qubit(register_id, outcome_pole)
	if projected and qc.berry_register != null:
		# Collapse cuts the Berry walk: no unitary path connects the jump, and
		# entanglement makes the jump nonlocal within the biome — every tracked
		# qubit re-seeds from the next evolved slice (partial loops forfeit).
		qc.berry_register.reseed_tracked()
	return projected


static func _drain_register(biome, register_id: int, is_north: bool, eta: float) -> bool:
	# Apply partial ensemble drain instead of full projective collapse.

	# Drains η of the measured pole's population from the biome's density matrix.
	# Coherences touching the measured pole decay as √(1-η). The biome retains
	# most of its quantum structure — sustainable for repeated measurements.
	if not biome or not biome.quantum_computer:
		return false
	var qc = biome.quantum_computer
	if not qc.has_method("drain_qubit"):
		# Fallback: full projection if drain not available
		return _project_register(biome, register_id, is_north)
	var outcome_pole = 0 if is_north else 1
	# Same stale-cache guard as _project_register
	if qc.has_method("get_marginal"):
		var live_prob = qc.get_marginal(register_id, outcome_pole)
		if live_prob < 1e-12:
			outcome_pole = 1 - outcome_pole
	qc.drain_qubit(register_id, outcome_pole, eta)
	return true


static func _resolve_drain_fraction(_biome, purity: float, farm = null) -> float:
	# Compute measurement drain fraction η = base_drain × purity.

	# Pure states (purity≈1) yield full base drain — more extractable, more fragile.
	# Mixed states (purity≈0.25) yield minimal drain — less information, less disruption.
	# This naturally connects quantum information theory to game economy.
	# Open-system only (drain); the closed game never reaches here. Config-sourced, no default.
	var base_drain = 0.15
	if farm:
		base_drain = float(BalanceService.get_tuning_value(farm, "measurement_drain_base"))
	return clampf(base_drain * clampf(purity, 0.0, 1.0), 0.0, 1.0)


static func _auto_measure_for_pop(terminal, farm) -> Dictionary:
	# Auto-measure a bound terminal so it can be popped directly.

	# Born-samples from the live density matrix, collapses the axis (projective in
	# the closed system, ensemble drain in the open-system DLC), and marks the
	# terminal as measured — collapsing explore→measure→pop into explore→pop.
	var biome = _resolve_biome_from_terminal(farm, terminal)
	if not biome or not biome.quantum_computer:
		return {"success": false, "error": "no_biome", "message": "Cannot auto-measure: biome unavailable.", "blocked": true}

	var register_id = terminal.bound_register_id
	var qc = biome.quantum_computer

	# Born sample from live density matrix
	var north_prob = qc.get_marginal(register_id, 0) if qc.has_method("get_marginal") else 0.5
	var is_north = randf() < north_prob
	var outcome = terminal.north_emoji if is_north else terminal.south_emoji
	var outcome_prob = north_prob if is_north else (1.0 - north_prob)

	if outcome.is_empty():
		outcome = "?"

	# Capture per-qubit bloch_r before drain (drain modifies state)
	var bloch_r_pre = 0.5
	if biome.viz_cache:
		bloch_r_pre = clampf(float(biome.viz_cache.get_bloch(register_id).get("r", 0.5)), 0.0, 1.0)

	# Collapse the measured axis — closed: full projective collapse (von Neumann);
	# open (wet country): partial ensemble drain. Mirrors action_measure.
	var collapse_ok: bool
	if not _biome_open_here(biome):
		collapse_ok = _project_register(biome, register_id, is_north)
	else:
		var purity = biome.get_purity() if biome.has_method("get_purity") else 0.5
		var drain_eta = _resolve_drain_fraction(biome, purity, farm)
		collapse_ok = _drain_register(biome, register_id, is_north, drain_eta)
	if not collapse_ok:
		# Honest failure: state not collapsed — don't fake a measured terminal.
		return {"success": false, "error": "collapse_failed", "auto_measured": false}

	# Mark terminal as measured — player sees pure collapsed state.
	# Store r so _prepare_pop_result can read per-qubit Bloch radius.
	var snapshot = {"purity": 1.0, "r": bloch_r_pre}
	terminal.mark_measured(outcome, outcome_prob, 1.0, snapshot)
	terminal.release_register()

	return {"success": true, "auto_measured": true}


static func _resolve_measurement_context(terminal, biome) -> Dictionary:
	var register_id = terminal.bound_register_id if terminal else -1
	var north_prob = biome.get_register_probability(register_id) if biome and biome.has_method("get_register_probability") else -1.0
	var south_prob = 1.0 - north_prob if north_prob >= 0.0 else -1.0
	var snapshot: Dictionary = {}
	var measured_purity = biome.get_purity() if biome and biome.has_method("get_purity") else -1.0

	if north_prob < 0.0 and biome and biome.quantum_computer and biome.quantum_computer.has_method("get_marginal"):
		north_prob = float(biome.quantum_computer.get_marginal(register_id, 0))
		south_prob = 1.0 - north_prob

	if biome and biome.viz_cache:
		var bloch = biome.viz_cache.get_bloch(register_id)
		if not bloch.is_empty():
			snapshot = bloch.duplicate()
		var snap = biome.viz_cache.get_snapshot(register_id)
		for k in snap.keys():
			snapshot[k] = snap[k]
		if snap.has("p0"):
			north_prob = float(snap.get("p0", north_prob))
		if snap.has("p1"):
			south_prob = float(snap.get("p1", south_prob))
		elif snap.has("p0"):
			south_prob = 1.0 - north_prob
		if snap.has("purity") and float(snap.get("purity", -1.0)) >= 0.0:
			measured_purity = float(snap.get("purity", measured_purity))

	return {
		"register_id": register_id,
		"north_prob": clampf(north_prob, 0.0, 1.0) if north_prob >= 0.0 else -1.0,
		"south_prob": clampf(south_prob, 0.0, 1.0) if south_prob >= 0.0 else -1.0,
		"snapshot": snapshot,
		"measured_purity": clampf(measured_purity, 0.0, 1.0) if measured_purity >= 0.0 else -1.0
	}


static func _sample_born_outcome(terminal, biome, register_id: int, north_prob: float, south_prob: float) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	var seed_biome_name = (biome.biome_name if (biome and "biome_name" in biome) else "")
	var seed_elapsed_ms = int((biome.elapsed_time if (biome and "elapsed_time" in biome) else 0.0) * 1000.0)
	rng.seed = hash([seed_biome_name, register_id, seed_elapsed_ms])

	var is_north := rng.randf() < north_prob
	var outcome: String = terminal.north_emoji if is_north else terminal.south_emoji
	var outcome_prob: float = north_prob if is_north else south_prob
	if outcome.is_empty():
		outcome = "?"
	return {
		"outcome": outcome,
		"outcome_prob": outcome_prob,
		"is_north": is_north
	}


static func _finalize_measurement_terminal(terminal, outcome: String, recorded_probability: float, snapshot: Dictionary) -> void:
	if not terminal:
		return
	var final_snapshot = snapshot.duplicate(true) if snapshot is Dictionary else {}
	final_snapshot["purity"] = 1.0
	terminal.mark_measured(outcome, recorded_probability, 1.0, final_snapshot)
	terminal.release_register()


## Incorporation-reward multiplier — harvesting a register whose ICON you have
## incorporated into your faction signature boosts the yield. This is the escape
## from the resource spiral: incorporate the Demos icon (🌾/👥), plant it in the
## Village, and harvesting that register nets positive forever. The bonus is keyed
## on SIGNATURE membership (does your signature contain this register's icon?), NOT
## on emoji/cloud knowledge — knowing a stray emoji is not the same as owning the icon.
##
## Quantum-derived "purity" curve on the INCORPORATED branch only:
##   incorporated     → mult = (bloch_r + signature_r_bonus) ^ signature_reward_exponent
##                      (pure r=1 → (1+1)^2 = 4×; entangled r<1 → smoothly less —
##                      purity vs entanglement is a real trade-off, not a trap)
##   not incorporated → mult = 1× (flat baseline)
## The old code also RAN the curve on un-incorporated harvests (r^2 < 1), which
## silently punished the game's own core mechanic: any entangled register has
## r ≪ 1, so almost every harvest was crushed to the floor of 1 — "what happened
## to the vocab bonus? i seem to only ever get 1" (playtest 3). The bonus is a
## bonus; there is no hidden penalty. Both params stay tunable via the
## FarmVariableGraph board (tuning.signature_r_bonus / signature_reward_exponent).
static func _incorporation_reward_multiplier(north: String, south: String, bloch_r: float, farm = null) -> float:
	if farm == null:
		return 1.0
	if not _icon_in_signature(farm, north, south):
		return 1.0
	var bonus: float = float(BalanceService.get_tuning_value(farm, "signature_r_bonus"))
	var exponent: float = float(BalanceService.get_tuning_value(farm, "signature_reward_exponent"))
	return pow(clampf(bloch_r, 0.0, 1.0) + bonus, exponent)


## True iff the icon (pole-pair AXIS) is in the player's faction signature
## (farm.known_icons). The harvest bonus rides incorporation, not emoji knowledge.
## Orientation-blind: an icon IS its axis, so 🌾/👥 and 👥/🌾 are the same icon —
## the starter signature stores north=🌾 while TheDemos register mounts north=👥,
## and the old exact-order compare never matched them (the ×4 escape never fired).
static func _icon_in_signature(farm, north: String, south: String) -> bool:
	if north == "" or south == "" or farm == null or not ("known_icons" in farm):
		return false
	for ic in farm.known_icons:
		var a := str(ic.get("north", ""))
		var b := str(ic.get("south", ""))
		if (a == north and b == south) or (a == south and b == north):
			return true
	return false


static func _resolve_pop_reward_context(terminal, farm = null) -> Dictionary:
	if not terminal:
		return {}
	var biome = _resolve_biome_from_terminal(farm, terminal)
	var resource = terminal.measured_outcome
	var recorded_prob = terminal.measured_probability
	var register_id = terminal.measured_register_id
	var terminal_id = terminal.terminal_id
	var biome_name = terminal.measured_biome_name

	# Surprisal reward MUST use the strike-time outcome probability (recorded at
	# MEASURE), not the live post-collapse population. After a projective collapse the
	# measured outcome's population is ≈1 by construction, so reading it gave every
	# pop surprisal ≈ 0 → reward floored to 1, while the concentration cost (∝ p·r)
	# maxed out — min reward + max cost on every strike (#125). recorded_probability
	# is exactly "how rare was this collapse"; that is the Boltzmann price basis.
	# (Live population only as a fallback when no recorded probability exists.)
	var p_emoji = clampf(recorded_prob, 0.0, 1.0)
	if recorded_prob <= 0.0 and biome and biome.quantum_computer and biome.quantum_computer.has_method("get_population"):
		p_emoji = clampf(float(biome.quantum_computer.get_population(resource)), 0.0, 1.0)

	var bloch_r := 0.5
	if terminal.measured_snapshot.has("r"):
		bloch_r = clampf(float(terminal.measured_snapshot["r"]), 0.0, 1.0)
	elif biome and biome.viz_cache and register_id >= 0:
		bloch_r = clampf(float(biome.viz_cache.get_bloch(register_id).get("r", 0.5)), 0.0, 1.0)

	var affinity = FactionAffinity.get_affinity(resource, farm)
	# Boltzmann scarcity: reward = surprisal energy E = −kT·log p (EnergyPricing).
	# Rare outcome → bigger reward, bounded and smooth (no 1/p singularity).
	var kT = EnergyPricing.biome_temperature(biome, farm)
	# Keep the RAW energy through the multiplier chain and round ONCE at the
	# end — rounding the surprisal first killed small-but-real rewards before
	# the vocab bonus could multiply them (0.4 → 0 → ×4 = 0 → floored to 1).
	var reward_energy: float = EnergyPricing.surprisal_energy(p_emoji, kT)
	var reward_quantum = round(reward_energy)
	var affinity_bonus = 1.0 + HamiltonianConfig.AFFINITY_REWARD_MAX * affinity
	# Harvest bonus rides on whether this register's ICON is in the player's signature.
	var pop_axis: Dictionary = {}
	if biome and biome.quantum_computer and biome.quantum_computer.register_map and register_id >= 0:
		pop_axis = biome.quantum_computer.register_map.axis(register_id)
	var sig_mult = _incorporation_reward_multiplier(str(pop_axis.get("north", "")), str(pop_axis.get("south", "")), bloch_r, farm)
	var resource_amount = maxi(int(round(reward_energy * affinity_bonus * sig_mult)), 1)

	return {
		"biome": biome,
		"biome_name": biome_name,
		"resource": resource,
		"recorded_probability": recorded_prob,
		"terminal_id": terminal_id,
		"register_id": register_id,
		"p_emoji": p_emoji,
		"bloch_r": bloch_r,
		"affinity": affinity,
		"reward_quantum": reward_quantum,
		"credits": reward_quantum,  # kT is the anchor now; no separate QC conversion
		"resource_amount": resource_amount
	}


## Per-biome regime (What Fades seam): is this biome's dissipative generator live?
## Wet-country biomes measure by weak drain and reap through the entropy bank;
## closed biomes measure by projective collapse and reap by mass-measurement.
static func _biome_open_here(biome) -> bool:
	if biome == null or biome.get("quantum_computer") == null:
		return BalanceConfig.dissipative_enabled()
	var qc = biome.quantum_computer
	if qc.has_method("is_open_here"):
		return qc.is_open_here()
	return BalanceConfig.dissipative_enabled()


static func _advance_reap_cycles(farm, active_biomes: Array, reap_cycles: int) -> Dictionary:
	if reap_cycles <= 0:
		return {"success": true, "cycles": 0, "evolved_steps": 0}
	var active_biome_names: Array = []
	for biome in active_biomes:
		if biome:
			active_biome_names.append(biome.get_biome_type())
	var batcher = farm.biome_evolution_batcher if farm and ("biome_evolution_batcher" in farm) else null
	if batcher == null:
		# No batcher = no evolution. The manual GDScript fast-forward that used to
		# live here was a second integrator authority — deleted 2026-07-06.
		push_error("[reap] No BiomeEvolutionBatcher on farm — cannot advance cycles (no GDScript fallback exists).")
		return {"success": false, "error": "no_batcher", "cycles": 0, "evolved_steps": 0}
	return batcher.run_additional_cycles(reap_cycles, active_biome_names)


static func _collect_reap_rewards(active_biomes: Array, economy, farm, flux_to_credits: float) -> Dictionary:
	# PER-BIOME regime split (What Fades, docs/OPEN_CAMPAIGN.md): each biome reaps
	# in its own thermodynamic country. Closed biomes get the seasonal
	# mass-measurement (measurement IS the economy — see _closed_reap_rewards);
	# wet-country biomes get the RITE: sink flux + the entropy bank, payout kT·ΔS —
	# the Lindbladian extraction v0 reserved for the day the extraction was real.
	var closed_biomes: Array = []
	var open_biomes: Array = []
	for biome in active_biomes:
		if biome and biome.quantum_computer and biome.quantum_computer.has_method("is_open_here") \
				and biome.quantum_computer.is_open_here():
			open_biomes.append(biome)
		else:
			closed_biomes.append(biome)
	if open_biomes.is_empty():
		return _closed_reap_rewards(active_biomes, economy, farm)
	var closed_result: Dictionary = _closed_reap_rewards(closed_biomes, economy, farm) \
			if not closed_biomes.is_empty() else {"flux_totals": {}, "icon_totals": {}, "total_flux_credits": 0, "total_icon_credits": 0}
	var open_result: Dictionary = _open_reap_rewards(open_biomes, economy, farm, flux_to_credits)
	# Merge: totals sum; per-emoji dicts accumulate.
	var merged: Dictionary = {
		"flux_totals": open_result.get("flux_totals", {}),
		"icon_totals": closed_result.get("icon_totals", {}).duplicate(),
		"total_flux_credits": int(open_result.get("total_flux_credits", 0)),
		"total_icon_credits": int(closed_result.get("total_icon_credits", 0)) + int(open_result.get("total_icon_credits", 0)),
		"rite_credits": int(open_result.get("rite_credits", 0)),
	}
	for emoji in open_result.get("icon_totals", {}):
		merged["icon_totals"][emoji] = int(merged["icon_totals"].get(emoji, 0)) + int(open_result["icon_totals"][emoji])
	return merged


## The rite: sink flux + entropy bank over the WET biomes only. Payout = kT·ΔS —
## paid from a season's accumulated dissipation, in the units the physics uses.
static func _open_reap_rewards(active_biomes: Array, economy, farm, flux_to_credits: float) -> Dictionary:
	var flux_totals: Dictionary = {}
	var icon_totals: Dictionary = {}
	var total_flux_credits = 0
	var total_icon_credits = 0

	for biome in active_biomes:
		if not biome or not biome.quantum_computer:
			continue
		var qc = biome.quantum_computer

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

		# Entropy bank: the biome's entropy S IS its bank balance, but you only earn
		# credits for the disorder you actually CONSUME this reap — payout = kT·ΔS,
		# where ΔS is the entropy the drains remove. The surprisal shares decide which
		# poles pay out and how the drain intensity is distributed (rare populations
		# are worth more). The bank refills only as the biome's webway/pump regenerates
		# S between reaps; a near-pure (cold) biome yields ≈0 until it does.
		var S0: float = qc.get_entropy()
		var kT: float = EnergyPricing.biome_temperature(biome, farm)
		if kT * S0 <= 0.0:
			continue  # cold biome: no bank to extract until refilled
		var pops: Dictionary = qc.get_all_populations() if qc.has_method("get_all_populations") else {}
		# Two weightings over the populated poles:
		#  • drain weight = surprisal (improbability): we extract order by suppressing
		#    the SURPRISING tail (high −kT·log p) and leaving the mode, so the state
		#    concentrates and S actually falls. Weighting by energy DENSITY (surprisal·p)
		#    instead drains the mode hardest → flattens → ΔS≈0 → reap pays nothing.
		#  • payout weight = energy density (surprisal·p): the credits flow where rarity
		#    AND population coincide (realizable value).
		var drain_w: Dictionary = {}
		var drain_sum: float = 0.0
		var pay_w: Dictionary = {}
		var pay_sum: float = 0.0
		for emoji in pops.keys():
			var p: float = clampf(float(pops[emoji]), 0.0, 1.0)
			if p <= 0.0:
				continue
			var sur: float = EnergyPricing.surprisal_energy(p, kT)  # improbability
			if sur > 0.0:
				drain_w[emoji] = sur
				drain_sum += sur
				pay_w[emoji] = sur * p  # energy density
				pay_sum += sur * p
		if drain_sum <= 0.0 or pay_sum <= 0.0:
			continue
		# Drain pass: concentrate toward the mode by suppressing the improbable poles.
		# Bracket with S0/S1 so the payout matches the entropy actually consumed.
		for emoji in drain_w.keys():
			if qc.has(emoji):
				var eta: float = clampf(float(drain_w[emoji]) / drain_sum, 0.0, HamiltonianConfig.ETA_HARD_CAP)
				qc.drain_qubit(qc.qubit(emoji), qc.pole(emoji), eta)
		var S1: float = qc.get_entropy()
		# Conserved payout: energy out = kT·(entropy consumed).
		var payout: float = kT * maxf(0.0, S0 - S1)
		var total_int: int = int(round(payout))
		var paid_here: int = 0
		if total_int > 0:
			# Largest-remainder (Hamilton) apportionment by energy-density share, so the
			# integer credits sum EXACTLY to round(payout). A naive per-emoji
			# round(payout·share) makes a small payout split many ways round each share
			# to 0 — and the whole reward silently vanishes.
			var alloc: Dictionary = {}
			var rema: Array = []
			var floor_sum: int = 0
			for emoji in pay_w.keys():
				var exact: float = float(total_int) * (float(pay_w[emoji]) / pay_sum)
				var fl: int = int(floor(exact))
				alloc[emoji] = fl
				floor_sum += fl
				rema.append({"emoji": emoji, "frac": exact - float(fl)})
			rema.sort_custom(func(a, b): return a["frac"] > b["frac"])
			var leftover: int = total_int - floor_sum
			for i in range(mini(leftover, rema.size())):
				alloc[rema[i]["emoji"]] += 1
			for emoji in alloc.keys():
				var credits: int = int(alloc[emoji])
				if credits <= 0:
					continue
				economy.add_resource(emoji, credits, "reap_entropy")
				icon_totals[emoji] = icon_totals.get(emoji, 0) + credits
				total_icon_credits += credits
				paid_here += credits
		_log("info", "🌾", "🌾", "Reap bank %s: kT=%.1f S %.3f→%.3f ΔS=%.3f payout=%.1f paid=%d" % [
			biome.get_biome_type() if biome.has_method("get_biome_type") else "?",
			kT, S0, S1, S0 - S1, payout, paid_here])

	return {
		"flux_totals": flux_totals,
		"icon_totals": icon_totals,
		"total_flux_credits": total_flux_credits,
		"total_icon_credits": total_icon_credits,
		# The rite's take: everything paid from wet country this season (sink flux
		# + entropy bank). Drives the reap whisper — the ceremony fires only when
		# the extraction was real.
		"rite_credits": total_flux_credits + total_icon_credits,
	}


## Closed-system reap: a seasonal mass-measurement. Born-sample + projectively collapse
## every register of each active biome and pay surprisal (−kT·log p) for the collapsed
## pole, floored at 1 resource. There is no sink flux, no entropy bank, and crucially no
## drain — draining would mix the state and break the r = 1 (pure) invariant. The
## Hamiltonian re-spreads the collapsed qubits over the following season (time + H is the
## pump). Born sampling reuses the deterministic per-(biome, register, time) seed so reap
## is save-load reproducible, like _sample_born_outcome.
static func _closed_reap_rewards(active_biomes: Array, economy, farm) -> Dictionary:
	var icon_totals: Dictionary = {}
	var total_icon_credits := 0
	for biome in active_biomes:
		if not biome or not biome.quantum_computer:
			continue
		var qc = biome.quantum_computer
		var kT: float = EnergyPricing.biome_temperature(biome, farm)
		var nq: int = qc.register_map.num_qubits
		var seed_biome: String = str(biome.biome_name) if "biome_name" in biome else ""
		var seed_ms: int = int((biome.elapsed_time if "elapsed_time" in biome else 0.0) * 1000.0)
		for q in range(nq):
			var axis: Dictionary = qc.register_map.axis(q)
			if axis.is_empty():
				continue
			var north_p: float = clampf(qc.get_marginal(q, 0), 0.0, 1.0)
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([seed_biome, q, seed_ms])
			var is_north: bool = rng.randf() < north_p
			var pole: int = 0 if is_north else 1
			var emoji: String = str(axis.get("north", "")) if is_north else str(axis.get("south", ""))
			var p: float = north_p if is_north else (1.0 - north_p)
			qc.project_qubit(q, pole)   # full projective collapse — stays pure (r=1)
			if emoji == "":
				continue
			# Incorporation-reward multiplier: the collapsed pole is pure (r=1), so an
			# incorporated icon pays "4× flat for pure values" (×1 if not in signature).
			# Same helper as pop — keyed on the register's icon, not the emoji.
			var sig_mult: float = _incorporation_reward_multiplier(str(axis.get("north", "")), str(axis.get("south", "")), 1.0, farm)
			var reward: int = maxi(1, int(round(EnergyPricing.surprisal_energy(p, kT) * sig_mult)))
			economy.add_resource(emoji, reward, "reap_measure")
			icon_totals[emoji] = icon_totals.get(emoji, 0) + reward
			total_icon_credits += reward
		_log("info", "🌾", "🌾", "Closed reap %s: kT=%.1f mass-measured %d registers" % [
			biome.get_biome_type() if biome.has_method("get_biome_type") else "?", kT, nq])
	return {
		"flux_totals": {},
		"icon_totals": icon_totals,
		"total_flux_credits": 0,
		"total_icon_credits": total_icon_credits,
	}


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

	# Measured terminals typically released their register during MEASURE, so POP
	# must clear the full terminal snapshot, not only the still-bound case.
	terminal_pool.release_terminal(terminal)
	_log("info", "farm", "📤", "Register %d released in %s" % [register_id, biome_name if biome_name else "biome"])
	return harvest_result


static func action_reap(farm, economy = null) -> Dictionary:
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

	var reap_cycles = int(BalanceService.get_tuning_value(farm, "reap_evolution_cycles"))
	reap_cycles = maxi(reap_cycles, 0)
	var active_biome_names: Array = []
	for biome in active_biomes:
		if biome:
			active_biome_names.append(biome.get_biome_type())

	var fast_forward_result = _advance_reap_cycles(farm, active_biomes, reap_cycles)

	var flux_to_credits = float(BalanceService.get_tuning_value(farm, "flux_to_credits"))
	var reap_result = _collect_reap_rewards(active_biomes, economy, farm, flux_to_credits)
	var flux_totals: Dictionary = reap_result.get("flux_totals", {})
	var icon_totals: Dictionary = reap_result.get("icon_totals", {})
	var total_flux_credits = int(reap_result.get("total_flux_credits", 0))
	var total_icon_credits = int(reap_result.get("total_icon_credits", 0))

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
		"rite_credits": int(reap_result.get("rite_credits", 0)),
		"harvest_results": []
	}


static func _prepare_pop_result(terminal, terminal_pool, economy = null, farm = null) -> Dictionary:
	if not terminal:
		return {
			"success": false,
			"error": "no_terminal",
			"message": "No terminal to pop. Use E to measure first.",
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
		if terminal.is_bound and not terminal.is_measured:
			# Auto-measure: Born sample from live state and project
			var auto_result = _auto_measure_for_pop(terminal, farm)
			if not auto_result.get("success", false):
				return auto_result
		elif not terminal.is_measured:
			return {
				"success": false,
				"error": "not_measured",
				"message": "Terminal not measured. Use MEASURE first.",
				"blocked": true
			}
		else:
			return {
				"success": false,
				"error": "cannot_pop",
				"message": "Terminal cannot be popped.",
				"blocked": true
			}

	var reward_ctx = _resolve_pop_reward_context(terminal, farm)
	var resource = str(reward_ctx.get("resource", terminal.measured_outcome))
	var recorded_prob = float(reward_ctx.get("recorded_probability", terminal.measured_probability))
	var terminal_id = str(reward_ctx.get("terminal_id", terminal.terminal_id))
	var register_id = int(reward_ctx.get("register_id", terminal.measured_register_id))
	var biome_name = str(reward_ctx.get("biome_name", terminal.measured_biome_name))
	var p_emoji = float(reward_ctx.get("p_emoji", 0.0))
	var bloch_r = float(reward_ctx.get("bloch_r", 0.5))
	var affinity = float(reward_ctx.get("affinity", 0.0))
	var reward_quantum = int(reward_ctx.get("reward_quantum", 1))
	var credits = int(reward_ctx.get("credits", 1))
	var resource_amount = maxi(int(reward_ctx.get("resource_amount", credits)), 1)

	if economy:
		# FLAT pop cost (2026-07-11, same law as the strike): the old
		# concentration tax (×3 at p=r=1) charged MOST for harvesting pure
		# high-probability states — exactly the "harvest icons you KNOW"
		# strategy the tutorial teaches — so the taught loop ran net-negative
		# in 👥 and popped players to zero (stranger-session soft-lock).
		# Chaos stays in the DEAL: the surprisal reward is already the raw
		# price signal (likely outcomes pay little). The door stays flat.
		var scaled_cost = ActionCostRuntime.get_action_cost(farm, "pop", {})
		var pop_cost_gate = _preflight_cost(economy, scaled_cost)
		if not pop_cost_gate.get("ok", true):
			return {
				"success": false,
				"error": "insufficient_resources",
				"message": "Need %s to pop." % _format_cost(scaled_cost)
			}
		if not _commit_cost(economy, scaled_cost, "pop"):
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
		"p_emoji": p_emoji,
		"bloch_r": bloch_r,
		"affinity": affinity,
		"reward_quantum": reward_quantum,
		"credits": credits,
		"terminal_id": terminal_id,
		"register_id": register_id,
		"biome_name": biome_name
	}


## ============================================================================
## MASS POP / CLEAR ALL ACTION
## ============================================================================

static func action_clear_all(terminal_pool, farm = null, economy = null) -> Dictionary:
	if not terminal_pool:
		return {
			"success": false,
			"error": "no_pool",
			"message": "Plot pool not initialized."
		}

	var popped_count = 0
	var total_credits = 0
	var harvest_results: Array = []
	var terminals_to_clear: Array = []

	# Collect all active terminals (bound or measured)
	if terminal_pool.has_method("get_all_terminals"):
		for terminal in terminal_pool.get_all_terminals():
			if terminal and (terminal.is_bound or terminal.is_measured):
				terminals_to_clear.append(terminal)

	# Pop each terminal and collect whatever harvest it yields.
	for terminal in terminals_to_clear:
		var result = action_pop(terminal, terminal_pool, economy, farm)
		if result.get("success", false):
			harvest_results.append(result)
			total_credits += int(result.get("credits", 0))
			popped_count += 1
	
	_log("info", "farm", "🧹", "Mass-popped %d terminals" % popped_count)

	return {
		"success": true,
		"terminals_popped": popped_count,
		"total_credits": total_credits,
		"harvest_results": harvest_results
	}


static func _resolve_biome_from_terminal(farm, terminal):
	if not farm or not terminal:
		return null
	if not ("grid" in farm) or not farm.grid or not farm.grid.has_biomes():
		return null
	var biome_name = terminal.measured_biome_name if terminal.measured_biome_name != "" else terminal.bound_biome_name
	return farm.grid.get_biome(biome_name)


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
			"north_probability": -1.0,
			"south_probability": -1.0
		}

	var north_prob = biome.get_register_probability(terminal.bound_register_id) if biome else -1.0
	var south_prob = 1.0 - north_prob if north_prob >= 0.0 else -1.0

	return {
		"can_measure": true,
		"north_emoji": terminal.north_emoji,
		"south_emoji": terminal.south_emoji,
		"north_probability": north_prob,
		"south_probability": south_prob
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
