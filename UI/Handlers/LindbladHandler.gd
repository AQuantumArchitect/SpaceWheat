class_name LindbladHandler
extends RefCounted

## LindbladHandler - Static handler for Lindblad (dissipative) operations
##
## Follows ProbeActions pattern:
## - Static methods only
## - Explicit parameters (no implicit state)
## - Dictionary returns with {success: bool, ...data, error?: String}


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
	var drive_rate = 1.0  # Strong drive (1/s)
	var dt = 0.5  # Half second pulse

	for pos in positions:
		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome or not biome.quantum_computer:
			continue

		# V2 MODEL: Get emoji from terminal
		var emoji = ""
		if farm.plot_pool:
			var terminal = farm.plot_pool.get_terminal_at_grid_pos(pos)
			if terminal and terminal.is_bound and terminal.has_method("get_emoji_pair"):
				var pair = terminal.get_emoji_pair()
				emoji = pair.get("north", "")

		# V1 FALLBACK: Get emoji from plot
		if emoji == "":
			var plot = farm.grid.get_plot(pos)
			if plot and plot.is_planted:
				emoji = plot.north_emoji if plot.north_emoji else ""

		if emoji == "" or not biome.quantum_computer.register_map.has(emoji):
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
	var decay_rate = 1.0  # Strong decay (1/s)
	var dt = 0.5  # Half second pulse

	for pos in positions:
		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome or not biome.quantum_computer:
			continue

		# V2 MODEL: Get emoji from terminal
		var emoji = ""
		if farm.plot_pool:
			var terminal = farm.plot_pool.get_terminal_at_grid_pos(pos)
			if terminal and terminal.is_bound and terminal.has_method("get_emoji_pair"):
				var pair = terminal.get_emoji_pair()
				emoji = pair.get("north", "")

		# V1 FALLBACK: Get emoji from plot
		if emoji == "":
			var plot = farm.grid.get_plot(pos)
			if plot and plot.is_planted:
				emoji = plot.north_emoji if plot.north_emoji else ""

		if emoji == "" or not biome.quantum_computer.register_map.has(emoji):
			continue

		# Get qubit index and apply decay
		var qubit_idx = biome.quantum_computer.register_map.qubit(emoji)
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

	if farm.plot_pool:
		var terminal_from = farm.plot_pool.get_terminal_at_grid_pos(pos_from)
		if terminal_from and terminal_from.is_bound and terminal_from.has_method("get_emoji_pair"):
			emoji_from = terminal_from.get_emoji_pair().get("north", "")

		var terminal_to = farm.plot_pool.get_terminal_at_grid_pos(pos_to)
		if terminal_to and terminal_to.is_bound and terminal_to.has_method("get_emoji_pair"):
			emoji_to = terminal_to.get_emoji_pair().get("north", "")

	# V1 FALLBACK: Get emojis from plots
	if emoji_from == "":
		var plot_from = farm.grid.get_plot(pos_from)
		if plot_from and plot_from.is_planted:
			emoji_from = plot_from.north_emoji if plot_from.north_emoji else ""
	if emoji_to == "":
		var plot_to = farm.grid.get_plot(pos_to)
		if plot_to and plot_to.is_planted:
			emoji_to = plot_to.north_emoji if plot_to.north_emoji else ""

	if emoji_from == "" or emoji_to == "":
		return {
			"success": false,
			"error": "missing_emojis",
			"message": "Both plots must have bound terminals"
		}

	if not biome.quantum_computer.register_map.has(emoji_from) or not biome.quantum_computer.register_map.has(emoji_to):
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
		if not plot or not plot.is_planted:
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
