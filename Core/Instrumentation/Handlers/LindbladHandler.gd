extends RefCounted

## LindbladHandler - Static instrumentation dispatcher for Lindblad operations.
##
## Follows ProbeActions pattern:
## - Static methods only
## - Explicit parameters (no implicit state)
## - Dictionary returns with {success: bool, ...data, error?: String}

const PULSE_RATE = 1.0
const PULSE_DT = 0.5
const PERSISTENT_RATE = 0.5
const DRAIN_GEAR_EMOJI = "⚙"


static func get_preview_cost(action_name: String, axis_pair: Dictionary = {}) -> Dictionary:
	var normalized = EconomyConstants.normalize_action_id(action_name)
	return EconomyConstants.get_lindblad_injection_cost(normalized, {
		"north_emoji": str(axis_pair.get("north", "")),
		"south_emoji": str(axis_pair.get("south", ""))
	})


static func _get_lindblad_cost(action_name: String, north_emoji: String, south_emoji: String, invest_units: int = 0) -> Dictionary:
	var normalized = EconomyConstants.normalize_action_id(action_name)
	var ctx := {
		"north_emoji": north_emoji,
		"south_emoji": south_emoji
	}
	# Invest-cost symmetry (pump): surprisal cost in the north pole, if supplied.
	if invest_units > 0:
		ctx["invest_units"] = invest_units
	return EconomyConstants.get_lindblad_injection_cost(normalized, ctx)


static func _preflight_lindblad_cost(
	farm,
	action_name: String,
	north_emoji: String,
	south_emoji: String,
	insufficient: Dictionary,
	invest_units: int = 0
) -> Dictionary:
	if not farm or not farm.economy:
		return {}

	var cost = _get_lindblad_cost(action_name, north_emoji, south_emoji, invest_units)
	var gate = ActionCostRuntime.preflight_cost(farm.economy, cost)
	if not gate.get("ok", true):
		for emoji in cost.keys():
			var amount = float(cost[emoji])
			if farm.economy.has_method("can_afford_resource") and not farm.economy.can_afford_resource(emoji, amount):
				insufficient[emoji] = insufficient.get(emoji, 0) + 1
		return {}

	return cost


static func _resolve_axis_pair(farm, pos: Vector2i) -> Dictionary:
	var biome = farm.grid.get_biome_for_plot(pos) if farm and farm.grid else null
	var binding = _resolve_axis_binding(farm, pos, biome)
	return {
		"north": str(binding.get("north", "")),
		"south": str(binding.get("south", ""))
	}


static func _get_biome_name(biome) -> String:
	if not biome:
		return ""
	if biome.has_method("get_biome_type"):
		return str(biome.get_biome_type())
	return str(biome.name if "name" in biome else "")


static func _sorted_biome_positions(farm, biome_name: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not farm or not farm.grid:
		return out
	return farm.grid.get_plot_positions_for_biome(biome_name)


static func _project_register_for_position(farm, biome, pos: Vector2i) -> int:
	if not farm or not farm.grid or not biome:
		return -1

	var biome_name = _get_biome_name(biome)
	if biome_name == "":
		return -1

	var positions = _sorted_biome_positions(farm, biome_name)
	if positions.is_empty():
		return -1

	var slot_index = -1
	for i in range(positions.size()):
		if positions[i] == pos:
			slot_index = i
			break
	if slot_index < 0:
		return -1

	var num_qubits = 0
	if biome.viz_cache and biome.viz_cache.has_method("get_num_qubits"):
		num_qubits = int(biome.viz_cache.get_num_qubits())
	if num_qubits <= 0 and biome.quantum_computer and biome.quantum_computer.register_map:
		num_qubits = int(biome.quantum_computer.register_map.num_qubits)
	if num_qubits <= 0:
		return -1

	return posmod(slot_index, num_qubits)


static func _resolve_axis_binding(farm, pos: Vector2i, biome) -> Dictionary:
	# Resolve axis+register for a plot without mutating plot binding state.
	var north = ""
	var south = ""
	var register_id = -1
	var plot = farm.grid.get_plot(pos) if farm and farm.grid else null
	var biome_name = _get_biome_name(biome)

	# Terminal-delegating: plot.north_emoji reads from plot.terminal when attached
	if plot and plot.is_active():
		north = str(plot.north_emoji) if plot.north_emoji else ""
		south = str(plot.south_emoji) if plot.south_emoji else ""
		register_id = plot.bound_register_id

	if register_id < 0 and north != "":
		register_id = _resolve_qubit_index(biome, north)

	if register_id < 0:
		register_id = _project_register_for_position(farm, biome, pos)

	if register_id >= 0 and biome and biome.viz_cache and biome.viz_cache.has_metadata():
		var axis = biome.viz_cache.get_axis(register_id)
		if axis is Dictionary:
			if north == "":
				north = str(axis.get("north", ""))
			if south == "":
				south = str(axis.get("south", ""))

	return {
		"north": north,
		"south": south,
		"register_id": register_id,
		"plot": plot,
		"biome_name": biome_name
	}


static func _get_register_infra(biome, register_id: int) -> Dictionary:
	if not biome or not biome.quantum_computer or register_id < 0:
		return {}
	return biome.quantum_computer._ensure_register_infra(register_id)


## Install the inverse persistent Lindblad flag on TheDemos (player neighborhood)
## so every Merchant transfer is conservation-paired.
##
##   kind = "pump":  player drained from B → TheDemos pumps the same emoji (mass arrives)
##   kind = "drain": player pumped to B    → TheDemos drains the same emoji (mass departs)
##
## No-ops silently if TheDemos doesn't have the emoji as a qubit (golden-cut
## simplification — we don't expand TheDemos's signature here). Caller gets
## a diagnostic dict either way for trajectory logging.
static func _install_demos_inverse(farm, emoji: String, kind: String, rate: float) -> Dictionary:
	if not farm or not farm.grid or emoji == "":
		return {"installed": false, "reason": "bad_args", "emoji": emoji, "kind": kind}
	var demos = farm.grid.get_biome("TheDemos") if farm.grid.has_method("get_biome") else null
	if demos == null or demos.quantum_computer == null:
		return {"installed": false, "reason": "no_demos", "emoji": emoji, "kind": kind}
	if not demos.quantum_computer.has(emoji):
		return {"installed": false, "reason": "emoji_not_in_demos_qc", "emoji": emoji, "kind": kind}
	var demos_qid: int = int(demos.quantum_computer.qubit(emoji))
	var infra = _get_register_infra(demos, demos_qid)
	if infra.is_empty():
		return {"installed": false, "reason": "no_infra", "emoji": emoji, "kind": kind}

	if kind == "pump":
		infra["lindblad_pump_active"] = true
		infra["lindblad_pump_rate"] = rate
		infra["lindblad_harvest_visible"] = true
	elif kind == "drain":
		infra["lindblad_drain_active"] = true
		infra["lindblad_drain_rate"] = rate
		infra["lindblad_harvest_visible"] = true
	else:
		return {"installed": false, "reason": "unknown_kind", "kind": kind}

	# Trajectory log entry — unified observation across all merchant moves.
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop is SceneTree:
		var story_engine = main_loop.root.get_node_or_null("/root/StoryEngine")
		if story_engine != null and story_engine.has_method("note_market_action"):
			story_engine.note_market_action({
				"kind": "merchant_" + kind,
				"emoji": emoji,
				"target_biome": "TheDemos",
				"rate": rate,
			})

	return {"installed": true, "kind": kind, "emoji": emoji, "rate": rate, "demos_qubit": demos_qid}


static func _resolve_qubit_index(biome, emoji: String) -> int:
	# Resolve qubit index from viz_cache metadata.
	if not biome or emoji == "":
		return -1
	if biome.viz_cache and biome.viz_cache.has_metadata():
		var q = biome.viz_cache.get_qubit(emoji)
		if q >= 0:
			return q
	return -1


## ============================================================================
## LINDBLAD CONTROL OPERATIONS
## ============================================================================

static func lindblad_drive(farm, positions: Array[Vector2i]) -> Dictionary:
	# Apply Lindblad drive to increase population on selected plots.

	# Drive operation pumps population into the target state.
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	var success_count = 0
	var driven_emojis: Dictionary = {}
	var drive_rate = PULSE_RATE  # Strong drive (1/s)
	var dt = PULSE_DT  # Half second pulse

	for pos in positions:
		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome or not biome.quantum_computer:
			continue

		var plot = farm.grid.get_plot(pos)
		if not plot or not plot.is_active():
			continue
		var emoji = plot.north_emoji if plot.north_emoji else ""

		if _resolve_qubit_index(biome, emoji) < 0:
			continue

		biome.quantum_computer.apply_drive(emoji, drive_rate, dt)
		success_count += 1
		driven_emojis[emoji] = driven_emojis.get(emoji, 0) + 1

	return {
		"success": success_count > 0,
		"driven_count": success_count,
		"driven_emojis": driven_emojis,
		"drive_rate": drive_rate,
		"dt": dt
	}


static func lindblad_decay(farm, positions: Array[Vector2i]) -> Dictionary:
	# Apply Lindblad decay to decrease population on selected plots.

	# Decay operation removes population from the target state.
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	var success_count = 0
	var decayed_emojis: Dictionary = {}
	var decay_rate = PULSE_RATE  # Strong decay (1/s)
	var dt = PULSE_DT  # Half second pulse

	for pos in positions:
		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome or not biome.quantum_computer:
			continue

		var plot = farm.grid.get_plot(pos)
		if not plot or not plot.is_active():
			continue
		var emoji = plot.north_emoji if plot.north_emoji else ""

		var qubit_idx = _resolve_qubit_index(biome, emoji)
		if qubit_idx < 0:
			continue

		# Get qubit index and apply decay
		biome.quantum_computer.apply_decay(qubit_idx, decay_rate, dt)
		success_count += 1
		decayed_emojis[emoji] = decayed_emojis.get(emoji, 0) + 1

	return {
		"success": success_count > 0,
		"decayed_count": success_count,
		"decayed_emojis": decayed_emojis,
		"decay_rate": decay_rate,
		"dt": dt
	}


static func enable_persistent_drive(farm, positions: Array[Vector2i],
		rate: float = PERSISTENT_RATE) -> Dictionary:
	# Enable continuous Lindblad drive on selected plots.
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	var success_count = 0
	var activated_count = 0
	var charged_count = 0
	var already_active = 0
	var insufficient: Dictionary = {}
	var driven_emojis: Dictionary = {}
	var no_biome = 0
	var unresolved_axis = 0
	var unresolved_qubit = 0
	var no_plot = 0
	var missing_infra = 0

	for pos in positions:
		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome or not biome.quantum_computer:
			no_biome += 1
			continue

		var binding = _resolve_axis_binding(farm, pos, biome)
		var north_emoji = str(binding.get("north", ""))
		var south_emoji = str(binding.get("south", ""))
		var qubit_idx = int(binding.get("register_id", -1))
		var plot = binding.get("plot", null)
		if north_emoji == "":
			unresolved_axis += 1
			continue
		if qubit_idx < 0:
			unresolved_qubit += 1
			continue

		if not plot:
			no_plot += 1
			continue
		var infra = _get_register_infra(biome, qubit_idx)
		if infra.is_empty():
			missing_infra += 1
			continue
		if bool(infra.get("lindblad_pump_active", false)) or bool(infra.get("lindblad_drain_active", false)):
			already_active += 1
			continue

		# Invest-cost symmetry: pump (R/import) charges the surprisal of the target
		# north pole — forcing an improbable pole costs more (twin of harvest reward).
		var pump_units := EnergyPricing.invest_units(
			clampf(float(biome.quantum_computer.get_marginal(qubit_idx, 0)), 0.0, 1.0),
			EnergyPricing.biome_temperature(biome, farm))
		var cost = _preflight_lindblad_cost(
			farm,
			EconomyConstants.normalize_action_id("lindblad_pump"),
			north_emoji,
			south_emoji,
			insufficient,
			pump_units
		)
		if cost.is_empty():
			continue

		if not ActionCostRuntime.commit_cost(farm.economy, cost, "lindblad_pump"):
			continue

		infra["lindblad_pump_active"] = true
		infra["lindblad_pump_rate"] = rate
		activated_count += 1

		charged_count += 1
		success_count += 1
		driven_emojis[north_emoji] = driven_emojis.get(north_emoji, 0) + 1

		# Lindbladian conservation pair: pumping into this biome's emoji
		# means mass flows OUT of TheDemos for the same emoji. Install the
		# inverse drain flag on TheDemos.
		_install_demos_inverse(farm, north_emoji, "drain", rate)

	var result = {
		"success": success_count > 0,
		"driven_count": success_count,
		"driven_emojis": driven_emojis,
		"drive_rate": rate,
		"dt": 0.0,
		"persistent_enabled": activated_count,
		"persistent_rate": rate,
		"charged_count": charged_count,
		"already_active": already_active,
		"insufficient": insufficient,
		"rejections": {
			"no_biome": no_biome,
			"no_plot": no_plot,
			"missing_infra": missing_infra,
			"unresolved_axis": unresolved_axis,
			"unresolved_qubit": unresolved_qubit
		},
		"cost_model": "pump=8💨+32N"
	}
	if not result.success:
		if already_active > 0:
			result["message"] = "Pump already active on %d plot(s)" % already_active
		elif not insufficient.is_empty():
			result["message"] = "Insufficient resources for pump"
		else:
			result["message"] = "No valid plots to pump"
	return result


static func enable_persistent_decay(farm, positions: Array[Vector2i],
		rate: float = PERSISTENT_RATE) -> Dictionary:
	# Enable continuous Lindblad decay on selected plots.
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	var success_count = 0
	var activated_count = 0
	var charged_count = 0
	var already_active = 0
	var insufficient: Dictionary = {}
	var decayed_emojis: Dictionary = {}
	var no_biome = 0
	var unresolved_axis = 0
	var unresolved_qubit = 0
	var no_plot = 0
	var missing_infra = 0

	for pos in positions:
		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome or not biome.quantum_computer:
			no_biome += 1
			continue

		var binding = _resolve_axis_binding(farm, pos, biome)
		var north_emoji = str(binding.get("north", ""))
		var south_emoji = str(binding.get("south", ""))
		var qubit_idx = int(binding.get("register_id", -1))
		var plot = binding.get("plot", null)
		if north_emoji == "":
			unresolved_axis += 1
			continue
		if qubit_idx < 0:
			unresolved_qubit += 1
			continue

		if not plot:
			no_plot += 1
			continue
		var infra = _get_register_infra(biome, qubit_idx)
		if infra.is_empty():
			missing_infra += 1
			continue
		if bool(infra.get("lindblad_drain_active", false)) or bool(infra.get("lindblad_pump_active", false)):
			already_active += 1
			continue

		var cost = _preflight_lindblad_cost(
			farm,
			EconomyConstants.normalize_action_id("lindblad_drain"),
			north_emoji,
			south_emoji,
			insufficient
		)
		if cost.is_empty():
			continue

		if not ActionCostRuntime.commit_cost(farm.economy, cost, "lindblad_drain"):
			continue

		# Activate only after cost commit: one persistent drain channel per register.
		infra["lindblad_drain_active"] = true
		infra["lindblad_drain_rate"] = rate
		infra["lindblad_harvest_visible"] = true
		activated_count += 1

		charged_count += 1
		success_count += 1
		decayed_emojis[north_emoji] = decayed_emojis.get(north_emoji, 0) + 1

		# Lindbladian conservation pair: the mass leaving this biome's emoji
		# arrives at TheDemos. Install the inverse pump flag on TheDemos so
		# the player faction physically gains what was drained.
		_install_demos_inverse(farm, north_emoji, "pump", rate)

	var result = {
		"success": success_count > 0,
		"decayed_count": success_count,
		"decayed_emojis": decayed_emojis,
		"decay_rate": rate,
		"dt": 0.0,
		"persistent_enabled": activated_count,
		"persistent_rate": rate,
		"charged_count": charged_count,
		"already_active": already_active,
		"insufficient": insufficient,
		"rejections": {
			"no_biome": no_biome,
			"no_plot": no_plot,
			"missing_infra": missing_infra,
			"unresolved_axis": unresolved_axis,
			"unresolved_qubit": unresolved_qubit
		},
		"cost_model": "drain=2⚙+8S"
	}
	if not result.success:
		if already_active > 0:
			result["message"] = "Drain already active on %d plot(s)" % already_active
		elif not insufficient.is_empty():
			result["message"] = "Insufficient resources for drain"
		else:
			result["message"] = "No valid plots to drain"
	return result


static func lindblad_transfer(farm, positions: Array[Vector2i]) -> Dictionary:
	# Transfer population between two selected plots.

	# Requires exactly 2 plots. Transfers from first to second.
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.size() != 2:
		return {
			"success": false,
			"error": "need_two_positions",
			"message": "Select exactly 2 plots"
		}

	var pos_from = positions[0]
	var pos_to = positions[1]

	var biome = farm.grid.get_biome_for_plot(pos_from)
	if not biome or not biome.quantum_computer:
		return {
			"success": false,
			"error": "no_quantum_computer",
			"message": "No quantum computer"
		}

	var plot_from = farm.grid.get_plot(pos_from)
	var plot_to = farm.grid.get_plot(pos_to)
	var emoji_from = plot_from.north_emoji if (plot_from and plot_from.is_active()) else ""
	var emoji_to = plot_to.north_emoji if (plot_to and plot_to.is_active()) else ""

	if emoji_from == "" or emoji_to == "":
		return {
			"success": false,
			"error": "missing_emojis",
			"message": "Both plots must have bound terminals"
		}

	if _resolve_qubit_index(biome, emoji_from) < 0 or _resolve_qubit_index(biome, emoji_to) < 0:
		return {
			"success": false,
			"error": "emojis_not_in_register",
			"message": "Emojis not in register"
		}

	# Transfer population
	var transfer_amount = 0.15  # Transfer 15% of population
	biome.quantum_computer.transfer_population(emoji_from, emoji_to, transfer_amount, 0.0)

	return {
		"success": true,
		"from_emoji": emoji_from,
		"to_emoji": emoji_to,
		"transfer_amount": transfer_amount
	}


# NOTE: reset_to_pure/reset_to_mixed removed (2026-01)
# These called biome methods that no longer exist in Model C


static func pump_to_wheat(farm, positions: Array[Vector2i]) -> Dictionary:
	# Establish pump channel from south to wheat.

	# Creates Lindblad pump operator for population transfer.
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	var success_count = 0
	var pumped: Dictionary = {}

	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if not plot or not plot.is_active():
			continue

		var north = plot.north_emoji
		var south = plot.south_emoji
		if not north or not south:
			continue

		var biome = farm.grid.get_biome_for_plot(pos)
		if biome and biome.has_method("place_energy_pump"):
			if biome.place_energy_pump(south, north, 0.05):
				success_count += 1
				var pair_key = "%s->%s" % [south, north]
				pumped[pair_key] = pumped.get(pair_key, 0) + 1

	return {
		"success": success_count > 0,
		"pump_count": success_count,
		"pumped_pairs": pumped
	}


static func _resolve_north_emoji(farm, pos: Vector2i) -> String:
	# Resolve north emoji from plot (delegates to terminal when attached).
	var plot = farm.grid.get_plot(pos) if farm and farm.grid else null
	if plot and plot.is_active():
		return plot.north_emoji if plot.north_emoji else ""
	return ""


static func _resolve_south_emoji(farm, pos: Vector2i) -> String:
	# Resolve south emoji from plot.
	var plot = farm.grid.get_plot(pos) if farm and farm.grid else null
	if plot and plot.is_active():
		return plot.south_emoji if plot.south_emoji else ""
	return ""
