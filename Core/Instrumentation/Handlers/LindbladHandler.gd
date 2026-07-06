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


static func _get_lindblad_cost(action_name: String, north_emoji: String, south_emoji: String, drive_units: int = 0) -> Dictionary:
	var normalized = EconomyConstants.normalize_action_id(action_name)
	var ctx := {
		"north_emoji": north_emoji,
		"south_emoji": south_emoji
	}
	# Drive-cost symmetry (pump/drain): surprisal cost in the driven pole, if supplied.
	if drive_units > 0:
		ctx["drive_units"] = drive_units
	return EconomyConstants.get_lindblad_injection_cost(normalized, ctx)


static func _preflight_lindblad_cost(
	farm,
	action_name: String,
	north_emoji: String,
	south_emoji: String,
	insufficient: Dictionary,
	drive_units: int = 0
) -> Dictionary:
	if not farm or not farm.economy:
		return {}

	var cost = _get_lindblad_cost(action_name, north_emoji, south_emoji, drive_units)
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


## Trajectory log entry — unified observation across all merchant moves.
##
## There is no "conservation pair": a Lindblad channel's counterparty IS the
## environment, by definition — the Bath absorbs what drains and supplies what
## pumps; the wallet is the ledger. (The old TheDemos inverse-flag scheme died
## here: it installed dissipative channels on the closed island the story
## promises stays pure, and silently no-opped for every emoji but 👥/🌾.)
static func _note_market_action(verb: String, emoji: String, biome_name: String, rate: float, channel: String) -> void:
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop is SceneTree:
		var story_engine = main_loop.root.get_node_or_null("/root/StoryEngine")
		if story_engine != null and story_engine.has_method("note_market_action"):
			story_engine.note_market_action({
				"kind": verb,
				"emoji": emoji,
				"target_biome": biome_name,
				"rate": rate,
				"channel": channel,
			})


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
	var sealed = 0
	var driven_emojis: Dictionary = {}
	var drive_rate = PULSE_RATE  # Strong drive (1/s)
	var dt = PULSE_DT  # Half second pulse

	for pos in positions:
		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome or not biome.quantum_computer:
			continue

		# Openness is a place: the jolt fires only where the regime runs open.
		if not biome.quantum_computer.is_open_here():
			sealed += 1
			continue

		# Register-first: plot_idx ≡ register_id, and the axis lives on the register
		# map. The legacy plot.north_emoji is only set by the old plant flow, so a
		# jolt gated on it could NEVER fire on register-first ground (found live:
		# every spark on open GildedRot refused with no error).
		var emoji := ""
		var plot = farm.grid.get_plot(pos)
		if plot and plot.north_emoji:
			emoji = str(plot.north_emoji)
		elif biome.quantum_computer.register_map:
			emoji = str(biome.quantum_computer.register_map.axis(pos.x).get("north", ""))
		if emoji == "" or _resolve_qubit_index(biome, emoji) < 0:
			continue

		biome.quantum_computer.apply_drive(emoji, drive_rate, dt)
		success_count += 1
		driven_emojis[emoji] = driven_emojis.get(emoji, 0) + 1

	var result = {
		"success": success_count > 0,
		"driven_count": success_count,
		"sealed": sealed,
		"driven_emojis": driven_emojis,
		"drive_rate": drive_rate,
		"dt": dt
	}
	if success_count == 0 and sealed > 0:
		result["error"] = "enclave_holds"
		result["message"] = "The enclave holds — the jolt needs open (wet) country."
	return result


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
	var sealed = 0
	var decayed_emojis: Dictionary = {}
	var decay_rate = PULSE_RATE  # Strong decay (1/s)
	var dt = PULSE_DT  # Half second pulse

	for pos in positions:
		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome or not biome.quantum_computer:
			continue

		# Openness is a place: the jolt fires only where the regime runs open.
		if not biome.quantum_computer.is_open_here():
			sealed += 1
			continue

		var plot = farm.grid.get_plot(pos)
		# Register-first fallback — same fix as lindblad_drive above.
		var emoji := ""
		if plot and plot.north_emoji:
			emoji = str(plot.north_emoji)
		elif biome.quantum_computer.register_map:
			emoji = str(biome.quantum_computer.register_map.axis(pos.x).get("north", ""))
		var qubit_idx = _resolve_qubit_index(biome, emoji) if emoji != "" else -1
		if qubit_idx < 0:
			continue

		# Get qubit index and apply decay
		biome.quantum_computer.apply_decay(qubit_idx, decay_rate, dt)
		success_count += 1
		decayed_emojis[emoji] = decayed_emojis.get(emoji, 0) + 1

	var result = {
		"success": success_count > 0,
		"decayed_count": success_count,
		"sealed": sealed,
		"decayed_emojis": decayed_emojis,
		"decay_rate": decay_rate,
		"dt": dt
	}
	if success_count == 0 and sealed > 0:
		result["error"] = "enclave_holds"
		result["message"] = "The enclave holds — the jolt needs open (wet) country."
	return result


static func enable_persistent_drive(farm, positions: Array[Vector2i],
		rate: float = PERSISTENT_RATE, kind: String = "damp") -> Dictionary:
	# Enable a continuous import channel on selected plots (Merchant R).
	# kind: "thermal" (detailed-balance pair, net up) or "damp" (one-way pump).
	# Dephase-import is refused — decoherence is irreversible; no channel
	# pumps coherence back in.
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

	if kind == "dephase":
		return {
			"success": false,
			"error": "irreversible",
			"message": "No contract can sell you back your phase — coherence returns only through your own gates."
		}

	var success_count = 0
	var activated_count = 0
	var charged_count = 0
	var already_active = 0
	var sealed = 0
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

		# Openness is a place: contracts run only where the regime is open.
		if not biome.quantum_computer.is_open_here():
			sealed += 1
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

		# Drive-cost: pump (charge north) costs the surprisal of the target north
		# pole — forcing an improbable pole is more work (any Lindblad drive costs).
		var pump_units := EnergyPricing.drive_units(
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
		infra["lindblad_channel_kind"] = kind
		activated_count += 1

		charged_count += 1
		success_count += 1
		driven_emojis[north_emoji] = driven_emojis.get(north_emoji, 0) + 1

		_note_market_action("merchant_pump", north_emoji, str(binding.get("biome_name", "")), rate, kind)

	var result = {
		"success": success_count > 0,
		"driven_count": success_count,
		"driven_emojis": driven_emojis,
		"drive_rate": rate,
		"dt": 0.0,
		"channel_kind": kind,
		"persistent_enabled": activated_count,
		"persistent_rate": rate,
		"charged_count": charged_count,
		"already_active": already_active,
		"sealed": sealed,
		"insufficient": insufficient,
		"rejections": {
			"no_biome": no_biome,
			"no_plot": no_plot,
			"missing_infra": missing_infra,
			"unresolved_axis": unresolved_axis,
			"unresolved_qubit": unresolved_qubit
		},
		"cost_model": "pump = 4📜 + ⌈−kT·log p_N⌉ × north-pole"
	}
	if not result.success:
		if sealed > 0 and already_active == 0 and insufficient.is_empty():
			result["message"] = "The enclave holds — contracts need open (wet) country."
		elif already_active > 0:
			result["message"] = "Pump already active on %d plot(s)" % already_active
		elif not insufficient.is_empty():
			result["message"] = "Insufficient resources for pump"
		else:
			result["message"] = "No valid plots to pump"
	return result


static func enable_persistent_decay(farm, positions: Array[Vector2i],
		rate: float = PERSISTENT_RATE, kind: String = "damp") -> Dictionary:
	# Enable a continuous export channel on selected plots (Merchant Q).
	# kind: "thermal" (detailed-balance pair, net down — plot stays warm),
	#       "dephase" (pure phase damping — no credits, kT rises instead),
	#       "damp" (one-way amplitude damping — credits as it drains).
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
	var sealed = 0
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

		# Openness is a place: contracts run only where the regime is open.
		if not biome.quantum_computer.is_open_here():
			sealed += 1
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

		# Drive-cost: drain (discharge south) costs the surprisal of the target south
		# pole — mirror of pump; forcing the field (either direction) is work.
		# Dephasing moves no population, so it stakes no pole emoji — 🧺 fee only.
		var drain_units := 0
		if kind != "dephase":
			drain_units = EnergyPricing.drive_units(
				clampf(float(biome.quantum_computer.get_marginal(qubit_idx, 1)), 0.0, 1.0),
				EnergyPricing.biome_temperature(biome, farm))
		var cost = _preflight_lindblad_cost(
			farm,
			EconomyConstants.normalize_action_id("lindblad_drain"),
			north_emoji if kind != "dephase" else "",
			south_emoji if kind != "dephase" else "",
			insufficient,
			drain_units
		)
		if cost.is_empty():
			continue

		if not ActionCostRuntime.commit_cost(farm.economy, cost, "lindblad_drain"):
			continue

		# Activate only after cost commit: one persistent drain channel per register.
		infra["lindblad_drain_active"] = true
		infra["lindblad_drain_rate"] = rate
		infra["lindblad_channel_kind"] = kind
		# Dephasing pays deferred (kT rises with entropy); nothing lands in the wallet.
		infra["lindblad_harvest_visible"] = kind != "dephase"
		activated_count += 1

		charged_count += 1
		success_count += 1
		decayed_emojis[north_emoji] = decayed_emojis.get(north_emoji, 0) + 1

		_note_market_action("merchant_drain", north_emoji, str(binding.get("biome_name", "")), rate, kind)

	var result = {
		"success": success_count > 0,
		"decayed_count": success_count,
		"decayed_emojis": decayed_emojis,
		"decay_rate": rate,
		"dt": 0.0,
		"channel_kind": kind,
		"persistent_enabled": activated_count,
		"persistent_rate": rate,
		"charged_count": charged_count,
		"already_active": already_active,
		"sealed": sealed,
		"insufficient": insufficient,
		"rejections": {
			"no_biome": no_biome,
			"no_plot": no_plot,
			"missing_infra": missing_infra,
			"unresolved_axis": unresolved_axis,
			"unresolved_qubit": unresolved_qubit
		},
		"cost_model": "drain = 4🧺 + ⌈−kT·log p_S⌉ × south-pole (dephase: 4🧺 only)"
	}
	if not result.success:
		if sealed > 0 and already_active == 0 and insufficient.is_empty():
			result["message"] = "The enclave holds — contracts need open (wet) country."
		elif already_active > 0:
			result["message"] = "Drain already active on %d plot(s)" % already_active
		elif not insufficient.is_empty():
			result["message"] = "Insufficient resources for drain"
		else:
			result["message"] = "No valid plots to drain"
	return result




static func settle_channels(farm, positions: Array[Vector2i]) -> Dictionary:
	# Close standing contracts: clear pump/drain flags on the selected plots.
	# Free, and deliberately regime-blind — a contract can always be CLOSED,
	# even on ground that has since sealed. The ledger keeps what already moved.
	if not farm or not farm.grid:
		return {"success": false, "error": "farm_not_ready", "message": "Farm not loaded"}
	if positions.is_empty():
		return {"success": false, "error": "no_positions", "message": "No plots selected"}

	var settled = 0
	var idle = 0
	var settled_emojis: Dictionary = {}
	for pos in positions:
		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome or not biome.quantum_computer:
			continue
		var binding = _resolve_axis_binding(farm, pos, biome)
		var qubit_idx = int(binding.get("register_id", -1))
		if qubit_idx < 0:
			continue
		var infra = _get_register_infra(biome, qubit_idx)
		if infra.is_empty():
			continue
		var was_pump = bool(infra.get("lindblad_pump_active", false))
		var was_drain = bool(infra.get("lindblad_drain_active", false))
		if not was_pump and not was_drain:
			idle += 1
			continue
		infra["lindblad_pump_active"] = false
		infra["lindblad_drain_active"] = false
		infra["lindblad_harvest_visible"] = false
		var kind = str(infra.get("lindblad_channel_kind", "damp"))
		infra.erase("lindblad_channel_kind")
		settled += 1
		var emoji = str(binding.get("north", ""))
		if emoji != "":
			settled_emojis[emoji] = settled_emojis.get(emoji, 0) + 1
		_note_market_action("merchant_settle", emoji, str(binding.get("biome_name", "")), 0.0, kind)

	var result = {
		"success": settled > 0,
		"settled_count": settled,
		"settled_emojis": settled_emojis,
		"idle": idle,
	}
	if settled == 0:
		result["error"] = "no_active_channel"
		result["message"] = "No standing contract on the selected plot(s)."
	return result


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
