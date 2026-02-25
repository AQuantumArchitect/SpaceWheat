class_name LindbladHandler
extends RefCounted

## LindbladHandler - Static handler for Lindblad (dissipative) operations
##
## Follows ProbeActions pattern:
## - Static methods only
## - Explicit parameters (no implicit state)
## - Dictionary returns with {success: bool, ...data, error?: String}

const PULSE_RATE = 1.0
const PULSE_DT = 0.5
const PERSISTENT_RATE = 0.5
const PUMP_RESOURCE_EMOJI = "🌱"
const DRAIN_GEAR_EMOJI = "⚙"
const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")


static func get_preview_cost(action_name: String, axis_pair: Dictionary = {}) -> Dictionary:
	var normalized = EconomyConstants.normalize_action_id(action_name)
	return EconomyConstants.get_lindblad_injection_cost(normalized, {
		"north_emoji": str(axis_pair.get("north", "")),
		"south_emoji": str(axis_pair.get("south", ""))
	})


static func _get_lindblad_cost(action_name: String, north_emoji: String, south_emoji: String) -> Dictionary:
	var normalized = EconomyConstants.normalize_action_id(action_name)
	return EconomyConstants.get_lindblad_injection_cost(normalized, {
		"north_emoji": north_emoji,
		"south_emoji": south_emoji
	})


static func _preflight_lindblad_cost(
	farm,
	action_name: String,
	north_emoji: String,
	south_emoji: String,
	insufficient: Dictionary
) -> Dictionary:
	if not farm or not farm.economy:
		return {}

	var cost = _get_lindblad_cost(action_name, north_emoji, south_emoji)
	var gate = EconomyConstants.preflight_cost(cost, farm.economy)
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
	if not ("plot_biome_assignments" in farm.grid):
		return out

	for key in farm.grid.plot_biome_assignments.keys():
		var assigned = str(farm.grid.plot_biome_assignments.get(key, ""))
		if assigned != biome_name:
			continue
		if key is Vector2i:
			out.append(key)
		elif key is Vector2:
			out.append(Vector2i(int((key as Vector2).x), int((key as Vector2).y)))
	out.sort_custom(func(a, b) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)
	return out


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
	"""Resolve axis+register for a plot and bind BasePlot if needed.

	Persistent Lindblad infra is stored on register_infrastructure through BasePlot
	properties. If a selected plot is unbound, we project a deterministic register
	by biome slot so drain/pump can still be installed for headless tooling.
	"""
	var north = ""
	var south = ""
	var register_id = -1
	var auto_bound_plot = false
	var plot = farm.grid.get_plot(pos) if farm and farm.grid else null
	var biome_name = _get_biome_name(biome)

	if farm and farm.terminal_pool:
		var terminal = farm.terminal_pool.get_terminal_at_grid_pos(pos)
		if terminal and terminal.has_method("get_emoji_pair"):
			var pair = terminal.get_emoji_pair()
			north = str(pair.get("north", ""))
			south = str(pair.get("south", ""))
			if "bound_register_id" in terminal:
				register_id = int(terminal.bound_register_id)

	if north == "" and plot and plot.has_method("is_active") and plot.is_active():
		north = str(plot.north_emoji if plot.north_emoji else "")
		south = str(plot.south_emoji if plot.south_emoji else "")
		if "bound_register_id" in plot:
			register_id = int(plot.bound_register_id)

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

	if plot and register_id >= 0 and north != "" and plot.has_method("is_active") and not plot.is_active():
		if plot.has_method("bind_to_register"):
			plot.bind_to_register(register_id, biome_name, {"north": north, "south": south})
			auto_bound_plot = true

	return {
		"north": north,
		"south": south,
		"register_id": register_id,
		"plot": plot,
		"biome_name": biome_name,
		"auto_bound_plot": auto_bound_plot
	}


static func _resolve_qubit_index(biome, emoji: String) -> int:
	"""Resolve qubit index from viz_cache metadata."""
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
	"""Apply Lindblad drive to increase population on selected plots.

	Drive operation pumps population into the target state.
	"""
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

		# V2 MODEL: Get emoji from terminal
		var emoji = ""
		if farm.terminal_pool:
			var terminal = farm.terminal_pool.get_terminal_at_grid_pos(pos)
			if terminal and terminal.is_bound and terminal.has_method("get_emoji_pair"):
				var pair = terminal.get_emoji_pair()
				emoji = pair.get("north", "")

		# V1 FALLBACK: Get emoji from plot
		if emoji == "":
			var plot = farm.grid.get_plot(pos)
			if plot and plot.is_active():
				emoji = plot.north_emoji if plot.north_emoji else ""

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
	"""Apply Lindblad decay to decrease population on selected plots.

	Decay operation removes population from the target state.
	"""
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

		# V2 MODEL: Get emoji from terminal
		var emoji = ""
		if farm.terminal_pool:
			var terminal = farm.terminal_pool.get_terminal_at_grid_pos(pos)
			if terminal and terminal.is_bound and terminal.has_method("get_emoji_pair"):
				var pair = terminal.get_emoji_pair()
				emoji = pair.get("north", "")

		# V1 FALLBACK: Get emoji from plot
		if emoji == "":
			var plot = farm.grid.get_plot(pos)
			if plot and plot.is_active():
				emoji = plot.north_emoji if plot.north_emoji else ""

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
	"""Enable continuous Lindblad drive on selected plots."""
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
	var unbound_plot = 0
	var auto_bound_plot = 0

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
		if bool(binding.get("auto_bound_plot", false)):
			auto_bound_plot += 1
		if north_emoji == "":
			unresolved_axis += 1
			continue
		if qubit_idx < 0:
			unresolved_qubit += 1
			continue

		if not plot:
			no_plot += 1
			continue
		if plot.has_method("is_active") and not plot.is_active():
			unbound_plot += 1
			continue
		if plot and (plot.lindblad_pump_active or plot.lindblad_drain_active):
			already_active += 1
			continue

		if plot:
			# Free persistent pump: always activate when placement is valid.
			plot.lindblad_pump_active = true
			plot.lindblad_pump_rate = rate
			activated_count += 1

		success_count += 1
		driven_emojis[north_emoji] = driven_emojis.get(north_emoji, 0) + 1

	return {
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
			"unbound_plot": unbound_plot,
			"unresolved_axis": unresolved_axis,
			"unresolved_qubit": unresolved_qubit
			},
			"auto_bound_plot": auto_bound_plot,
			"cost_model": "pump=free_persistent"
		}


static func enable_persistent_decay(farm, positions: Array[Vector2i],
		rate: float = PERSISTENT_RATE) -> Dictionary:
	"""Enable continuous Lindblad decay on selected plots."""
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
	var unbound_plot = 0
	var auto_bound_plot = 0

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
		if bool(binding.get("auto_bound_plot", false)):
			auto_bound_plot += 1
		if north_emoji == "":
			unresolved_axis += 1
			continue
		if qubit_idx < 0:
			unresolved_qubit += 1
			continue

		if not plot:
			no_plot += 1
			continue
		if plot.has_method("is_active") and not plot.is_active():
			unbound_plot += 1
			continue
		var known_emojis: Array = farm.get_known_emojis() if farm.has_method("get_known_emojis") else []
		if north_emoji not in known_emojis:
			insufficient[north_emoji] = insufficient.get(north_emoji, 0) + 1
			continue
		if plot and (plot.lindblad_drain_active or plot.lindblad_pump_active):
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

		if not EconomyConstants.commit_cost(cost, farm.economy, "lindblad_drain"):
			continue

		if plot:
			# Activate only after cost commit: one persistent drain channel per plot.
			plot.lindblad_drain_active = true
			plot.lindblad_drain_rate = rate
			activated_count += 1

		charged_count += 1
		success_count += 1
		decayed_emojis[north_emoji] = decayed_emojis.get(north_emoji, 0) + 1

	return {
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
			"unbound_plot": unbound_plot,
			"unresolved_axis": unresolved_axis,
			"unresolved_qubit": unresolved_qubit
		},
		"auto_bound_plot": auto_bound_plot,
		"cost_model": "drain=2⚙+8S"
	}


static func lindblad_transfer(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Transfer population between two selected plots.

	Requires exactly 2 plots. Transfers from first to second.
	"""
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

	# V2 MODEL: Get emojis from terminals
	var emoji_from = ""
	var emoji_to = ""

	if farm.terminal_pool:
		var terminal_from = farm.terminal_pool.get_terminal_at_grid_pos(pos_from)
		if terminal_from and terminal_from.is_bound and terminal_from.has_method("get_emoji_pair"):
			emoji_from = terminal_from.get_emoji_pair().get("north", "")

		var terminal_to = farm.terminal_pool.get_terminal_at_grid_pos(pos_to)
		if terminal_to and terminal_to.is_bound and terminal_to.has_method("get_emoji_pair"):
			emoji_to = terminal_to.get_emoji_pair().get("north", "")

	# V1 FALLBACK: Get emojis from plots
	if emoji_from == "":
		var plot_from = farm.grid.get_plot(pos_from)
		if plot_from and plot_from.is_active():
			emoji_from = plot_from.north_emoji if plot_from.north_emoji else ""
	if emoji_to == "":
		var plot_to = farm.grid.get_plot(pos_to)
		if plot_to and plot_to.is_active():
			emoji_to = plot_to.north_emoji if plot_to.north_emoji else ""

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
	"""Establish pump channel from south to wheat.

	Creates Lindblad pump operator for population transfer.
	"""
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
	"""Resolve north emoji from terminal first, then planted plot."""
	if farm.terminal_pool:
		var terminal = farm.terminal_pool.get_terminal_at_grid_pos(pos)
		if terminal and terminal.is_bound and terminal.has_method("get_emoji_pair"):
			var pair = terminal.get_emoji_pair()
			var north = pair.get("north", "")
			if north != "":
				return north

	var plot = farm.grid.get_plot(pos) if farm.grid else null
	if plot and plot.is_active():
		return plot.north_emoji if plot.north_emoji else ""

	return ""
