class_name GameStateSerializer
extends RefCounted

## GameStateSerializer - capture/apply GameState to a live Farm.
## Keeps GameStateManager focused on orchestration.

const GameState = preload("res://Core/GameState/GameState.gd")

var _verbose = null
var _vocabulary_evolution = null
var _player_vocab = null


func set_verbose(verbose) -> void:
	_verbose = verbose


func set_vocabulary_evolution(vocab) -> void:
	_vocabulary_evolution = vocab


func set_player_vocab(player_vocab) -> void:
	_player_vocab = player_vocab


func _log(level: String, category: String, icon: String, msg: String) -> void:
	if _verbose and _verbose.has_method(level):
		_verbose.call(level, category, icon, msg)


func _find_quantum_instrument_input(farm: Node) -> Node:
	"""Find QuantumInstrumentInput in the scene tree (for selection state)."""
	var tree = Engine.get_main_loop()
	if not tree or not tree is SceneTree:
		return null

	# Try to find it through common paths
	var farm_view = tree.root.get_node_or_null("FarmView")
	if farm_view:
		var shell = farm_view.get_node_or_null("PlayerShell")
		if shell:
			var farm_ui = shell.get_node_or_null("FarmUIContainer/FarmUI")
			if farm_ui and "input_handler" in farm_ui:
				return farm_ui.input_handler

	# Fallback: search for it in the quantum_instrument_input group
	var handlers = tree.get_nodes_in_group("quantum_instrument_input")
	if handlers.size() > 0:
		return handlers[0]

	return null


func capture_state_from_farm(farm: Node, current_state: GameState, scenario_id: String) -> GameState:
	"""Capture current game state from active Farm.

	Refactored for Farm/Biome/Qubit architecture:
	- Economy: All resource inventories
	- Plots: Configuration, planted/measured/entanglement state
	- Goals: Progress
	- Icons: Activation levels
	- Time: Biome elapsed time + sun/moon phase
	- Quantum State: Complete biome_state tree (sun qubit, icon qubits, emoji qubits)
	"""
	var state = GameState.new()

	if not farm:
		push_error("Farm not found - cannot capture state")
		return state

	# Meta
	state.scenario_id = scenario_id
	state.save_timestamp = Time.get_unix_time_from_system()
	state.game_time = current_state.game_time if current_state else 0.0

	# Simulation speed (from first biome)
	if farm.grid and farm.grid.biomes and not farm.grid.biomes.is_empty():
		var first_biome = farm.grid.biomes.values()[0]
		if "quantum_time_scale" in first_biome:
			state.quantum_time_scale = first_biome.quantum_time_scale
		if "observation_stride" in first_biome:
			state.observation_stride = first_biome.observation_stride
		if "max_evolution_dt" in first_biome:
			state.max_evolution_dt = first_biome.max_evolution_dt
			_log("debug", "save", "⏱️", "Captured timescale: speed=%.4fx stride=%d dt=%.4f" % [state.quantum_time_scale, state.observation_stride, state.max_evolution_dt])

	# Grid Dimensions (from Farm.grid)
	state.grid_width = farm.grid.grid_width
	state.grid_height = farm.grid.grid_height

	# Economy (from Farm.economy) - save ALL emoji credits
	var economy = farm.economy
	state.all_emoji_credits = economy.emoji_credits.duplicate()
	state.tributes_paid = economy.total_tributes_paid if "total_tributes_paid" in economy else 0
	state.tributes_failed = economy.total_tributes_failed if "total_tributes_failed" in economy else 0
	if economy.has_method("get_balance_profile_id"):
		state.balance_profile_id = economy.get_balance_profile_id()
	if economy.has_method("get_economy_overrides"):
		state.balance_overrides = economy.get_economy_overrides().duplicate(true)
	if farm.has_method("get_reap_count"):
		state.reap_count = int(farm.get_reap_count())
	elif "reap_count" in farm:
		state.reap_count = int(farm.reap_count)
	_log("debug", "save", "💰", "Captured %d emoji types in economy" % state.all_emoji_credits.size())

	# Player Vocabulary (farm-owned canonical)
	if farm and farm.has_method("get_known_pairs"):
		state.known_pairs = farm.get_known_pairs()
		state.known_emojis = []
		for pair in state.known_pairs:
			var north = pair.get("north", "")
			var south = pair.get("south", "")
			if north != "" and north not in state.known_emojis:
				state.known_emojis.append(north)
			if south != "" and south not in state.known_emojis:
				state.known_emojis.append(south)
		_log("debug", "save", "📖", "Captured vocabulary: %d pairs → %d emojis" % [state.known_pairs.size(), state.known_emojis.size()])

	# Biome progression state (unlocked/unexplored/active spindle position)
	_capture_biome_progression_state(state, current_state)

	# IconMap snapshot (tooling cache only; known_pairs remain canonical truth)
	var icon_snapshot = _capture_icon_map_snapshot(farm, state.known_emojis)
	state.icon_map_snapshot = icon_snapshot.get("icon_map_snapshot", {})
	state.icon_map_snapshot_source = str(icon_snapshot.get("icon_map_snapshot_source", ""))
	state.icon_map_snapshot_time = int(icon_snapshot.get("icon_map_snapshot_time", 0))

	# Player Vocabulary Quantum Computer (for affinity calculations)
	if _player_vocab and _player_vocab.has_method("serialize"):
		state.player_vocab_data = _player_vocab.serialize()
		_log("debug", "save", "🔬", "Captured PlayerVocabulary QC data")

	# Plots (from Farm.grid)
	state.plots.clear()
	var grid = farm.grid
	for y in range(state.grid_height):
		for x in range(state.grid_width):
			var pos = Vector2i(x, y)
			var plot = grid.get_plot(pos)

			var plot_data = {
				"position": pos,
				"type_name": plot.plot_type_name,
				"is_planted": plot.is_active(),
				"has_been_measured": plot.get_is_measured(),
				"theta_frozen": plot.theta_frozen,
				"entangled_with": plot.entangled_plots.keys(),
				"lindblad_pump_active": plot.lindblad_pump_active if "lindblad_pump_active" in plot else false,
				"lindblad_drain_active": plot.lindblad_drain_active if "lindblad_drain_active" in plot else false,
				"lindblad_pump_rate": plot.lindblad_pump_rate if "lindblad_pump_rate" in plot else 0.0,
				"lindblad_drain_rate": plot.lindblad_drain_rate if "lindblad_drain_rate" in plot else 0.0
			}
			# NEW: Read from BasePlot directly (Register→Plot→Terminal architecture)
			if plot.is_active():
				plot_data["register_id"] = plot.bound_register_id
				plot_data["biome_name"] = plot.bound_biome_name
				plot_data["north_emoji"] = plot.north_emoji
				plot_data["south_emoji"] = plot.south_emoji
				if plot.is_measured:
					plot_data["measured_outcome"] = plot.measured_outcome
					plot_data["measured_probability"] = plot.measured_probability
			if "persistent_gates" in plot:
				var serialized_gates = []
				for gate in plot.persistent_gates:
					var serialized_gate = {
						"type": gate.get("type", ""),
						"active": gate.get("active", true)
					}
					serialized_gate["linked_registers"] = gate.get("linked_registers", [])
					var linked_plots_serialized = []
					for linked_pos in gate.get("linked_plots", []):
						linked_plots_serialized.append({"x": linked_pos.x, "y": linked_pos.y})
					serialized_gate["linked_plots"] = linked_plots_serialized
					serialized_gates.append(serialized_gate)
				plot_data["persistent_gates"] = serialized_gates
			else:
				plot_data["persistent_gates"] = []

			state.plots.append(plot_data)

	# Icons (deprecated: registry-managed)
	state.biotic_activation = 0.0
	state.chaos_activation = 0.0
	state.imperium_activation = 0.0

	# Multi-Biome Capture
	state.biome_states = _capture_all_biome_states(farm)

	# Capture plot→biome assignments
	state.plot_biome_assignments = {}
	if farm.grid and "plot_biome_assignments" in farm.grid:
		for pos_key in farm.grid.plot_biome_assignments.keys():
			state.plot_biome_assignments[pos_key] = farm.grid.plot_biome_assignments[pos_key]

	# Vocabulary Evolution State
	if _vocabulary_evolution and _vocabulary_evolution.has_method("serialize"):
		state.vocabulary_state = _vocabulary_evolution.serialize()
		_log("debug", "save", "📚", "Captured vocabulary: %d discovered, %d evolving" % [
			state.vocabulary_state.get("discovered_vocabulary", []).size(),
			state.vocabulary_state.get("evolving_qubits", []).size()
		])

	# Capture selection state from QuantumInstrumentInput
	var input_handler = _find_quantum_instrument_input(farm)
	if input_handler and input_handler.has_method("get_checked_plots"):
		state.selected_plot_positions = input_handler.get_checked_plots().duplicate()
		_log("debug", "save", "✅", "Captured selection state: %d plots selected" % state.selected_plot_positions.size())
	else:
		state.selected_plot_positions = []

	var money = state.all_emoji_credits.get("💰", 0)
	_log("info", "save", "📸", "Captured game state: grid=" + str(state.grid_width) + "x" + str(state.grid_height) +
		", plots=" + str(state.plots.size()) + ", 💰=" + str(money) + ", selected=" + str(state.selected_plot_positions.size()))
	return state


func apply_state_to_farm(state: GameState, farm: Node) -> void:
	"""Apply loaded state to active Farm.

	Refactored for Farm/Biome/Qubit architecture:
	- Loads economy, plot configuration, time from GameState
	- Restores complete biome quantum state tree (all qubits)
	"""
	if not farm:
		push_error("Farm not found - cannot apply state")
		return

	if state.save_version != 1:
		push_error("Save file version mismatch: expected 1, got %d" % state.save_version)
		push_error("This save may be incompatible with current game version")

	if farm.grid:
		if state.grid_width != farm.grid.grid_width or state.grid_height != farm.grid.grid_height:
			push_warning("Grid size mismatch: save has %dx%d, farm has %dx%d" % [
				state.grid_width, state.grid_height,
				farm.grid.grid_width, farm.grid.grid_height
			])
			push_warning("Out-of-bounds plots will be skipped")

	_log("info", "save", "🔄", "Applying game state to farm (" + str(state.grid_width) + "x" + str(state.grid_height) + ")...")

	var economy = farm.economy
	if state.all_emoji_credits and state.all_emoji_credits.size() > 0:
		for emoji in state.all_emoji_credits.keys():
			economy.emoji_credits[emoji] = state.all_emoji_credits[emoji]
		_log("debug", "save", "💰", "Loaded %d emoji types from all_emoji_credits" % state.all_emoji_credits.size())

	if "total_tributes_paid" in economy:
		economy.total_tributes_paid = state.tributes_paid
	if "total_tributes_failed" in economy:
		economy.total_tributes_failed = state.tributes_failed

	for emoji in economy.emoji_credits.keys():
		economy._emit_resource_change(emoji)

	if economy.has_method("apply_economy_overrides"):
		var balance_payload = state.balance_overrides.duplicate(true)
		if state.balance_profile_id != "" and not balance_payload.has("profile_id"):
			balance_payload["profile_id"] = state.balance_profile_id
		economy.apply_economy_overrides(balance_payload)

	if farm.has_method("set_reap_count"):
		farm.set_reap_count(int(state.reap_count))
	elif "reap_count" in farm:
		farm.reap_count = int(state.reap_count)

	if farm.grid and farm.grid.biomes:
		var biome_count = 0
		for biome in farm.grid.biomes.values():
			if "quantum_time_scale" in biome:
				biome.quantum_time_scale = state.quantum_time_scale
				biome_count += 1
			if "observation_stride" in biome:
				biome.observation_stride = state.observation_stride
			if "max_evolution_dt" in biome:
				biome.max_evolution_dt = state.max_evolution_dt
		_log("debug", "save", "⏱️", "Applied timescale: speed=%.4fx stride=%d dt=%.4f to %d biomes" % [state.quantum_time_scale, state.observation_stride, state.max_evolution_dt, biome_count])

	var has_player_vocab_data = state.player_vocab_data and not state.player_vocab_data.is_empty()
	if farm and farm.has_method("set_known_pairs"):
		farm.set_known_pairs(state.known_pairs, not has_player_vocab_data, false)
		if state.icon_map_snapshot and not state.icon_map_snapshot.is_empty():
			_log("debug", "save", "🗺️", "Loaded IconMap snapshot cache (%s, %d emojis)" % [
				state.icon_map_snapshot_source,
				state.icon_map_snapshot.get("by_emoji", {}).size()
			])

	# Restore biome unlock/exploration progression before grid refresh so layout sync is correct.
	_restore_biome_progression_state(state)

	var grid = farm.grid
	if farm.has_method("refresh_grid_for_biomes"):
		farm.refresh_grid_for_biomes()
		grid = farm.grid

	var oob_count = 0
	var oob_first_pos = null
	for plot_data in state.plots:
		var pos = plot_data["position"]
		if pos.x < 0 or pos.x >= grid.grid_width or pos.y < 0 or pos.y >= grid.grid_height:
			oob_count += 1
			if oob_first_pos == null:
				oob_first_pos = pos
			continue

		var plot = grid.get_plot(pos)
		if plot:
			# Restore plot type (with backward compat for old enum saves)
			if plot_data.has("type_name"):
				plot.plot_type_name = plot_data["type_name"]
			elif plot_data.has("type"):  # Old saves with enum
				var old_type = plot_data["type"]
				match old_type:
					0: plot.plot_type_name = "wheat"
					2: plot.plot_type_name = "mushroom"
					6: plot.plot_type_name = "energy_tap"
					_: plot.plot_type_name = "wheat"

			if plot_data.get("is_planted", false):
				var saved_register = plot_data.get("register_id", -1)
				var saved_biome = plot_data.get("biome_name", "")
				var saved_north = plot_data.get("north_emoji", "")
				var saved_south = plot_data.get("south_emoji", "")
				if saved_register >= 0 and saved_biome != "":
					var emoji_pair = {"north": saved_north, "south": saved_south}

					# NEW: Bind register to plot directly (Register→Plot architecture)
					plot.bind_to_register(saved_register, saved_biome, emoji_pair)

					# Restore measurement state if present
					if plot_data.get("has_been_measured", false):
						var outcome = plot_data.get("measured_outcome", "")
						var probability = plot_data.get("measured_probability", 0.5)
						plot.mark_measured(outcome, probability)

					# Emit signal to trigger UI refresh (creates Terminal in UI layer)
					# UI will create Terminal and bubble based on plot state
					if farm.has_signal("terminal_bound"):
						farm.terminal_bound.emit(pos, "", emoji_pair)  # terminal_id not needed anymore

					if plot.is_measured and farm.has_signal("plot_measured"):
						farm.plot_measured.emit(pos, plot.measured_outcome)

			plot.theta_frozen = plot_data.get("theta_frozen", false)
			plot.lindblad_pump_active = plot_data.get("lindblad_pump_active", false)
			plot.lindblad_drain_active = plot_data.get("lindblad_drain_active", false)
			plot.lindblad_pump_rate = plot_data.get("lindblad_pump_rate", 0.5)
			plot.lindblad_drain_rate = plot_data.get("lindblad_drain_rate", 0.5)

			plot.entangled_plots.clear()
			for entangled_pos in plot_data.get("entangled_with", []):
				var other_plot = grid.get_plot(entangled_pos)
				if other_plot:
					plot.entangled_plots[other_plot.plot_id] = 1.0

	if oob_count > 0:
		_log("debug", "save", "🧹", "Skipped %d out-of-bounds plots (grid %dx%d). First: %s" % [
			oob_count, grid.grid_width, grid.grid_height, str(oob_first_pos)
		])

	if state.plot_biome_assignments and farm.grid:
		if "plot_biome_assignments" in farm.grid:
			farm.grid.plot_biome_assignments = state.plot_biome_assignments.duplicate()

	var has_register_infra = false
	if state.biome_states:
		_restore_all_biome_states(farm, state.biome_states)
		for bs in state.biome_states.values():
			if bs.has("register_infrastructure"):
				has_register_infra = true
				break
	if not has_register_infra:
		_migrate_plot_infra_to_register(farm, state)

	_reconnect_plots_to_projections(farm, state)

	if "biotic_icon" in farm and farm.biotic_icon and farm.biotic_icon.has_method("set_activation"):
		farm.biotic_icon.set_activation(state.biotic_activation)
	if "chaos_icon" in farm and farm.chaos_icon and farm.chaos_icon.has_method("set_activation"):
		farm.chaos_icon.set_activation(state.chaos_activation)
	if "imperium_icon" in farm and farm.imperium_icon and farm.imperium_icon.has_method("set_activation"):
		farm.imperium_icon.set_activation(state.imperium_activation)

	if _vocabulary_evolution and state.vocabulary_state:
		_vocabulary_evolution.deserialize(state.vocabulary_state)
		_log("debug", "save", "📚", "Restored vocabulary evolution from save")

	if _player_vocab and state.player_vocab_data and not state.player_vocab_data.is_empty():
		if _player_vocab.has_method("deserialize"):
			_player_vocab.deserialize(state.player_vocab_data)
			_log("debug", "save", "🔬", "Restored PlayerVocabulary QC data")

	# Restore selection state to QuantumInstrumentInput
	if state.selected_plot_positions and state.selected_plot_positions.size() > 0:
		var input_handler = _find_quantum_instrument_input(farm)
		if input_handler and input_handler.has_method("set_checked_plots"):
			input_handler.set_checked_plots(state.selected_plot_positions)
			_log("debug", "save", "✅", "Restored selection state: %d plots selected" % state.selected_plot_positions.size())
		else:
			_log("debug", "save", "⚠️", "QuantumInstrumentInput not found - selection state not restored")

	_log("info", "save", "✓", "State applied to farm successfully - quantum states will regenerate from biome")


func _capture_biome_progression_state(state: GameState, current_state: GameState) -> void:
	var observation_frame = _get_autoload("ObservationFrame")
	if observation_frame and observation_frame.has_method("get_unlocked_biomes"):
		state.unlocked_biomes = observation_frame.get_unlocked_biomes()
	elif current_state:
		state.unlocked_biomes = current_state.unlocked_biomes.duplicate()
	else:
		state.unlocked_biomes = ["StarterForest", "Village"]

	if observation_frame and observation_frame.has_method("get_unexplored_biomes"):
		state.unexplored_biome_pool = observation_frame.get_unexplored_biomes()
	elif current_state:
		state.unexplored_biome_pool = current_state.unexplored_biome_pool.duplicate()

	var active_biome_manager = _get_autoload("ActiveBiomeManager")
	if active_biome_manager and active_biome_manager.has_method("get_active_biome"):
		state.active_biome_name = str(active_biome_manager.get_active_biome())
	elif observation_frame and observation_frame.has_method("get_neutral_biome"):
		state.active_biome_name = str(observation_frame.get_neutral_biome())
	elif current_state:
		state.active_biome_name = str(current_state.active_biome_name)
	else:
		state.active_biome_name = "StarterForest"


func _restore_biome_progression_state(state: GameState) -> void:
	var unlocked_biomes = state.unlocked_biomes.duplicate()
	if unlocked_biomes.is_empty():
		unlocked_biomes = ["StarterForest", "Village"]

	var active_biome = str(state.active_biome_name)
	if (active_biome == "" or not (active_biome in unlocked_biomes)) and not unlocked_biomes.is_empty():
		active_biome = str(unlocked_biomes[0])

	var gsm = _get_autoload("GameStateManager")
	if gsm and gsm.current_state:
		gsm.current_state.unlocked_biomes = unlocked_biomes.duplicate()
		gsm.current_state.unexplored_biome_pool = state.unexplored_biome_pool.duplicate()
		gsm.current_state.active_biome_name = active_biome

	var observation_frame = _get_autoload("ObservationFrame")
	if observation_frame:
		if "BIOME_ORDER" in observation_frame:
			observation_frame.BIOME_ORDER = unlocked_biomes.duplicate()
		if observation_frame.has_method("set_neutral_biome") and active_biome != "":
			observation_frame.set_neutral_biome(active_biome)

	var active_biome_manager = _get_autoload("ActiveBiomeManager")
	if active_biome_manager:
		if active_biome_manager.has_method("set_biome_order"):
			active_biome_manager.set_biome_order(unlocked_biomes)
		if active_biome_manager.has_method("set_active_biome") and active_biome != "":
			active_biome_manager.set_active_biome(active_biome)


## Canonical autoload accessor. Static so any class can call GameStateSerializer.get_autoload().
static func get_autoload(name: String) -> Node:
	var tree = Engine.get_main_loop()
	if not tree or not (tree is SceneTree):
		return null
	return tree.root.get_node_or_null(name)


func _get_autoload(name: String) -> Node:
	var tree = Engine.get_main_loop()
	if not tree or not (tree is SceneTree):
		return null
	return tree.root.get_node_or_null(name)


func _capture_icon_map_snapshot(farm: Node, known_emojis: Array) -> Dictionary:
	"""Capture a compact icon map payload for tooling.

	Preference order:
	1) BiomeEvolutionBatcher global icon map (runtime-truth snapshot)
	2) Derived uniform map from known emojis
	"""
	var out := {
		"icon_map_snapshot": {},
		"icon_map_snapshot_source": "",
		"icon_map_snapshot_time": int(Time.get_unix_time_from_system())
	}

	if farm and "biome_evolution_batcher" in farm and farm.biome_evolution_batcher:
		var batcher = farm.biome_evolution_batcher
		if batcher.has_method("get_global_icon_map"):
			var payload = batcher.get_global_icon_map()
			if payload is Dictionary and not payload.is_empty():
				var by_emoji = payload.get("by_emoji", {})
				if by_emoji is Dictionary and not by_emoji.is_empty():
					out["icon_map_snapshot"] = {
						"by_emoji": by_emoji.duplicate(true),
						"total": float(payload.get("total", 0.0)),
						"steps": int(payload.get("steps", 0))
					}
					out["icon_map_snapshot_source"] = "batcher_global"
					return out

	var derived = {}
	for emoji in known_emojis:
		var s = str(emoji)
		if s != "" and not derived.has(s):
			derived[s] = 1.0
	if not derived.is_empty():
		out["icon_map_snapshot"] = {
			"by_emoji": derived,
			"total": float(derived.size()),
			"steps": 1
		}
		out["icon_map_snapshot_source"] = "derived_from_pairs"
	return out


func _capture_all_biome_states(farm: Node) -> Dictionary:
	var all_states = {}
	if not farm.grid or not "biomes" in farm.grid:
		push_warning("Farm grid has no biomes registry - cannot capture biome states")
		return all_states

	for biome_name in farm.grid.biomes.keys():
		var biome = farm.grid.biomes[biome_name]
		if biome:
			var state = _capture_single_biome_state(biome, biome_name)
			state["biome_class"] = biome.get_script().resource_path
			all_states[biome_name] = state
			_log("debug", "save", "💾", "Captured %s biome (%s)" % [biome_name, state["biome_class"]])

	return all_states


func _capture_single_biome_state(biome: Node, biome_name: String) -> Dictionary:
	var state_dict = {
		"time_elapsed": 0.0,
		"quantum_states": []
	}

	if "time_elapsed" in biome:
		state_dict["time_elapsed"] = biome.time_elapsed
	elif "time_tracker" in biome and biome.time_tracker:
		state_dict["time_elapsed"] = biome.time_tracker.time_elapsed

	if biome_name == "BioticFlux" and "sun_qubit" in biome and biome.sun_qubit:
		state_dict["sun_qubit"] = {
			"theta": biome.sun_qubit.theta,
			"phi": biome.sun_qubit.phi,
			"radius": biome.sun_qubit.radius
		}

	if "quantum_states" in biome and not ("bath" in biome and biome.bath):
		for pos in biome.quantum_states.keys():
			var qubit = biome.quantum_states[pos]
			if qubit:
				var qubit_data = {
					"position": pos,
					"theta": qubit.theta,
					"phi": qubit.phi,
					"radius": qubit.radius
				}
				if "north_emoji" in qubit:
					qubit_data["north_emoji"] = qubit.north_emoji
				if "south_emoji" in qubit:
					qubit_data["south_emoji"] = qubit.south_emoji
				state_dict["quantum_states"].append(qubit_data)

	state_dict["bell_gates"] = []
	if "bell_gates" in biome:
		for gate in biome.bell_gates:
			var gate_positions = []
			for pos in gate:
				gate_positions.append({"x": pos.x, "y": pos.y})
			state_dict["bell_gates"].append(gate_positions)

	if "bath" in biome and biome.bath:
		state_dict["bath_state"] = _serialize_bath_state(biome.bath)
		state_dict["active_projections"] = []
		if "active_projections" in biome:
			for pos in biome.active_projections.keys():
				var proj_data = biome.active_projections[pos]
				state_dict["active_projections"].append({
					"position": pos,
					"north": proj_data.north,
					"south": proj_data.south
				})

	if biome.quantum_computer and biome.quantum_computer.register_infrastructure.size() > 0:
		var infra = {}
		for reg_id in biome.quantum_computer.register_infrastructure:
			infra[str(reg_id)] = biome.quantum_computer.register_infrastructure[reg_id].duplicate(true)
		state_dict["register_infrastructure"] = infra

	return state_dict


func _restore_all_biome_states(farm: Node, biome_states: Dictionary) -> void:
	if not farm.grid or not "biomes" in farm.grid:
		push_warning("Farm grid has no biomes registry - cannot restore biome states")
		return

	for biome_name in biome_states.keys():
		var biome_state = biome_states[biome_name]
		var biome = farm.grid.biomes.get(biome_name, null)
		if not biome:
			push_warning("Biome %s not found in grid registry - skipping restore" % biome_name)
			continue
		_restore_single_biome_state(biome, biome_state, biome_name)
		_log("debug", "save", "📂", "Restored %s biome" % biome_name)


func _restore_single_biome_state(biome: Node, state: Dictionary, biome_name: String) -> void:
	if state.has("time_elapsed"):
		if "time_elapsed" in biome:
			biome.time_elapsed = state.time_elapsed
		elif "time_tracker" in biome and biome.time_tracker:
			biome.time_tracker.time_elapsed = state.time_elapsed

	if biome_name == "BioticFlux" and state.has("sun_qubit") and "sun_qubit" in biome and biome.sun_qubit:
		var sq = state.sun_qubit
		biome.sun_qubit.theta = sq.get("theta", 0.0)
		biome.sun_qubit.phi = sq.get("phi", 0.0)
		biome.sun_qubit.radius = sq.get("radius", 1.0)

	if state.has("quantum_states") and "quantum_states" in biome:
		for qubit_data in state.quantum_states:
			var pos = qubit_data["position"]
			if biome.quantum_states.has(pos):
				var qubit = biome.quantum_states[pos]
				qubit.theta = qubit_data.get("theta", PI/2.0)
				qubit.phi = qubit_data.get("phi", 0.0)
				qubit.radius = qubit_data.get("radius", 0.3)

	if state.has("bell_gates") and "bell_gates" in biome:
		biome.bell_gates.clear()
		for gate_data in state.bell_gates:
			var gate_positions = []
			for pos_dict in gate_data:
				gate_positions.append(Vector2i(pos_dict.x, pos_dict.y))
			biome.bell_gates.append(gate_positions)

	if not "bath" in biome or not biome.bath:
		if biome.is_inside_tree():
			await biome.get_tree().process_frame

	if state.has("bath_state") and "bath" in biome and biome.bath:
		_deserialize_bath_state(biome.bath, state.bath_state)

		if state.has("active_projections") and biome.has_method("create_projection"):
			biome.active_projections.clear()
			for proj in state.active_projections:
				biome.create_projection(proj.position, proj.north, proj.south)

	if state.has("register_infrastructure") and biome.quantum_computer:
		var qc = biome.quantum_computer
		for reg_str in state["register_infrastructure"]:
			qc.register_infrastructure[int(reg_str)] = state["register_infrastructure"][reg_str]


func _migrate_plot_infra_to_register(farm: Node, state: GameState) -> void:
	if not farm.grid:
		return

	var migrated_count = 0
	for plot_data in state.plots:
		var pos = plot_data.get("position", Vector2i(-1, -1))
		if pos == Vector2i(-1, -1):
			continue

		var reg_id = plot_data.get("register_id", -1)
		var biome_name = plot_data.get("biome_name", "")
		if reg_id < 0 or biome_name == "":
			continue

		var biome = farm.grid.biomes.get(biome_name, null)
		if not biome or not biome.quantum_computer:
			continue

		var qc = biome.quantum_computer
		var infra = qc._ensure_register_infra(reg_id)
		infra["theta_frozen"] = plot_data.get("theta_frozen", false)
		infra["lindblad_pump_active"] = plot_data.get("lindblad_pump_active", false)
		infra["lindblad_drain_active"] = plot_data.get("lindblad_drain_active", false)
		infra["lindblad_pump_rate"] = plot_data.get("lindblad_pump_rate", 0.5)
		infra["lindblad_drain_rate"] = plot_data.get("lindblad_drain_rate", 0.5)

		if plot_data.has("persistent_gates"):
			var gates = []
			for gate_data in plot_data["persistent_gates"]:
				gates.append({
					"type": gate_data.get("type", ""),
					"active": gate_data.get("active", true),
					"linked_registers": []
				})
			infra["persistent_gates"] = gates

		migrated_count += 1

	if migrated_count > 0:
		_log("info", "save", "🔄", "Migrated %d plot infra entries to register_infrastructure (old save compat)" % migrated_count)


func _reconnect_plots_to_projections(farm: Node, state: GameState) -> void:
	if not farm.grid:
		return

	var reconnected_count = 0
	for plot_data in state.plots:
		var pos = plot_data["position"]
		var plot = farm.grid.get_plot(pos)
		if not plot:
			continue
		if not plot.is_active():
			continue

		var biome_name = ""
		if farm.grid.plot_biome_assignments.has(pos):
			biome_name = farm.grid.plot_biome_assignments[pos]
		else:
			continue

		var biome = farm.grid.biomes.get(biome_name, null)
		if not biome:
			push_warning("Biome %s not found for plot reconnection" % biome_name)
			continue

		if not "active_projections" in biome:
			continue
		if not pos in biome.active_projections:
			continue

		var projection = biome.active_projections[pos]
		if not projection.has("qubit"):
			continue

		if projection.has("bath_subplot_id"):
			plot.bath_subplot_id = projection.bath_subplot_id
			reconnected_count += 1
		elif projection.has("register_id"):
			plot.bath_subplot_id = projection.register_id
			reconnected_count += 1

	if reconnected_count > 0:
		_log("debug", "farm", "🔗", "Reconnected %d plots to biome projections" % reconnected_count)


func _serialize_bath_state(bath: RefCounted) -> Dictionary:
	var serialized_amps = {}
	for emoji in bath.emoji_list:
		var amp = bath.get_amplitude(emoji)
		serialized_amps[emoji] = {"real": amp.re, "imag": amp.im}
	return {
		"emojis": bath.emoji_list.duplicate(),
		"amplitudes": serialized_amps,
		"bath_time": bath.bath_time
	}


func _deserialize_bath_state(bath: RefCounted, state: Dictionary) -> void:
	const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
	for i in range(state.emojis.size()):
		var emoji = state.emojis[i]
		if state.amplitudes.has(emoji):
			var amp_data = state.amplitudes[emoji]
			var amp = Complex.new(amp_data.real, amp_data.imag)
			bath.amplitudes[i] = amp
	bath.bath_time = state.bath_time
