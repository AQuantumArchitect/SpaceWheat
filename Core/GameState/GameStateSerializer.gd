class_name GameStateSerializer
extends RefCounted


## GameStateSerializer - capture/apply GameState to a live Farm.
## Keeps GameStateManager focused on orchestration.


func _log(level: String, category: String, icon: String, msg: String) -> void:
	# Routes through the one VerboseHelper authority like every other class
	# (slop knot #23). The old injected-_verbose variant silently no-op'd
	# whenever set_verbose() was never called — save/load diagnostics vanished
	# in standalone/tool use. VerboseHelper falls back to print/push_* instead.
	VerboseHelper.log(level, category, icon, msg)


func _find_quantum_instrument_input(_farm: Node) -> Node:
	# Find QuantumInstrumentInput via its scene group.
	var tree = Engine.get_main_loop()
	if not tree or not tree is SceneTree:
		return null
	var handlers = tree.get_nodes_in_group("quantum_instrument_input")
	if handlers.size() > 0:
		return handlers[0]
	return null


func capture_state_from_farm(farm: Node, current_state: GameState, scenario_id: String) -> GameState:
	# Capture current game state from active Farm.

	# Refactored for Farm/Biome/Qubit architecture:
	# - Economy: All resource inventories
	# - Plots: Configuration, planted/measured/entanglement state
	# - Goals: Progress
	# - Icons: Activation levels
	# - Time: Biome elapsed time + sun/moon phase
	# - Quantum State: Complete biome_state tree (sun qubit, icon qubits, emoji qubits)
	var state = GameState.new()

	if not farm:
		push_error("Farm not found - cannot capture state")
		return state

	# Meta
	state.scenario_id = scenario_id
	state.save_timestamp = Time.get_unix_time_from_system()
	state.game_time = current_state.game_time if current_state else 0.0

	# Simulation speed (from first biome)
	if farm.grid and farm.grid.has_biomes():
		var first_biome = farm.grid.get_primary_biome()
		if "quantum_time_scale" in first_biome:
			state.quantum_time_scale = first_biome.quantum_time_scale
		if "observation_stride" in first_biome:
			state.observation_stride = first_biome.observation_stride
		# max_evolution_dt not serialized — derived from BiomeCharacteristics, not player state
		_log("debug", "save", "⏱️", "Captured timescale: speed=%.4fx stride=%d" % [state.quantum_time_scale, state.observation_stride])

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
	if economy.has_method("get_economy_variables"):
		state.economy_variables = economy.get_economy_variables().duplicate(true)
	var graph_snapshot = BalanceService.get_farm_variable_graph(farm)
	if bool(graph_snapshot.get("ok", false)):
		var lines = graph_snapshot.get("lines", [])
		if lines is Array:
			state.farm_variable_graph_jsonl = lines.duplicate()
		if current_state and ("farm_variable_graph_path" in current_state):
			state.farm_variable_graph_path = str(current_state.farm_variable_graph_path)
	if current_state and ("balance_workbench_config" in current_state):
		var cfg = current_state.balance_workbench_config
		if cfg is Dictionary and not cfg.is_empty():
			state.balance_workbench_config = cfg.duplicate(true)
	if current_state and ("policy_state" in current_state):
		var pstate = current_state.policy_state
		if pstate is Dictionary and not pstate.is_empty():
			state.policy_state = pstate.duplicate(true)
	if current_state and ("policy_graph_jsonl" in current_state):
		var pgraph = current_state.policy_graph_jsonl
		if pgraph is Array and not pgraph.is_empty():
			state.policy_graph_jsonl = pgraph.duplicate()
	if current_state and ("policy_graph_path" in current_state):
		state.policy_graph_path = str(current_state.policy_graph_path)
	if farm.has_method("get_reap_count"):
		state.reap_count = int(farm.get_reap_count())
	elif "reap_count" in farm:
		state.reap_count = int(farm.reap_count)
	if "faction_density" in farm and farm.faction_density != null:
		state.faction_density = farm.faction_density.serialize()
	if "bridge_register" in farm and farm.bridge_register != null:
		state.bridges = farm.bridge_register.to_dict()
	# Phase 2: faction_standings (6-channel rep). Convert FactionStanding records → dicts.
	if "faction_standings" in farm and farm.faction_standings != null:
		var standings_out: Dictionary = {}
		for fname in farm.faction_standings:
			var s = farm.faction_standings[fname]
			if s != null and s.has_method("to_dict"):
				standings_out[fname] = s.to_dict()
		state.faction_standings = standings_out
	# Phase III: player_alignment (12-qubit AlignmentGraph). |+⟩^⊗12 default also
	# serializes (single dense ket); load path will rehydrate or reset as needed.
	if "player_alignment" in farm and farm.player_alignment != null \
			and farm.player_alignment.has_method("to_dict"):
		state.player_alignment = farm.player_alignment.to_dict()
	_log("debug", "save", "💰", "Captured %d emoji types in economy" % state.all_emoji_credits.size())

	var known_emojis: Array = []

	# Player signature (farm-owned canonical).
	if farm and farm.has_method("get_known_icons"):
		state.known_icons = _resolve_known_icons_for_capture(farm)
		known_emojis = GameState.derive_known_emojis_from_icons(state.known_icons)
		_log("debug", "save", "📖", "Captured signature: %d icons → %d emojis" % [state.known_icons.size(), known_emojis.size()])

	# Active icon slots (3 indices into known_icons — player's expression voice).
	if farm and "active_icon_slots" in farm:
		state.active_icon_slots = (farm.active_icon_slots as Array).duplicate()

	# Story flags + narrative log
	if "story_flags_fired" in farm:
		state.story_flags_fired = farm.story_flags_fired.duplicate()
	if "story_log" in farm:
		state.story_log = farm.story_log.duplicate(true)

	# Revealed plots (cosmetic bubble reveal set)
	if "revealed_plots" in farm:
		state.revealed_plots = farm.revealed_plots.keys()

	# Biome progression state (unlocked/unexplored/active spindle position)
	_capture_biome_progression_state(state, current_state)

	# IconMap snapshot (tooling cache only; known_icons remain canonical truth)
	var icon_snapshot = _capture_atom_map_snapshot(farm, known_emojis)
	state.atom_map_snapshot = icon_snapshot.get("atom_map_snapshot", {})
	state.atom_map_snapshot_source = str(icon_snapshot.get("atom_map_snapshot_source", ""))
	state.atom_map_snapshot_time = int(icon_snapshot.get("atom_map_snapshot_time", 0))

	# Plots (from Farm.grid)
	state.plots.clear()
	var grid = farm.grid
	for y in range(state.grid_height):
		for x in range(state.grid_width):
			var pos = Vector2i(x, y)
			var plot = grid.get_plot(pos)

			var has_live_measurement: bool = bool(plot.get_is_measured())
			var has_memory: bool = bool(plot.has_method("has_measurement_memory") and plot.has_measurement_memory())
			var has_measurement: bool = has_live_measurement or has_memory
			var has_live_register: bool = bool(plot.is_active())
			var _persist_plot: bool = has_live_register or has_measurement
			var plot_data = {
				"position": pos,
				"type_name": plot.plot_type_name,
				"is_planted": has_live_register,
				"has_been_measured": has_measurement,
				"theta_frozen": plot.theta_frozen,
				"entangled_with": plot.entangled_plots.keys()
			}

			# Persist both bound plots and measured terminals. Measured terminals may
			# release their live register, so their identity must come from the
			# terminal measurement snapshot rather than the current bound fields.
			if has_live_register:
				var register_id: int = int(plot.bound_register_id)
				var biome_name: String = str(plot.bound_biome_name)
				var north_emoji: String = str(plot.north_emoji)
				var south_emoji: String = str(plot.south_emoji)

				if has_live_measurement and plot.terminal:
					register_id = int(plot.terminal.measured_register_id)
					biome_name = str(plot.terminal.measured_biome_name)
					north_emoji = str(plot.terminal.north_emoji)
					south_emoji = str(plot.terminal.south_emoji)

				plot_data["register_id"] = register_id
				plot_data["biome_name"] = biome_name
				plot_data["north_emoji"] = north_emoji
				plot_data["south_emoji"] = south_emoji
				if has_live_measurement:
					plot_data["measured_outcome"] = plot.measured_outcome
					plot_data["measured_probability"] = plot.measured_probability
			elif has_memory and plot.has_method("get_measurement_memory"):
				var memory = plot.get_measurement_memory()
				plot_data["north_emoji"] = str(memory.get("north_emoji", ""))
				plot_data["south_emoji"] = str(memory.get("south_emoji", ""))
				plot_data["measured_outcome"] = str(memory.get("outcome", ""))
				plot_data["measured_probability"] = float(memory.get("probability", 0.0))

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

	# Multi-Biome Capture
	state.biome_states = _capture_all_biome_states(farm)

	# Capture plot→biome assignments
	state.plot_biome_assignments = {}
	if farm.grid:
		for pos_key in farm.grid.get_plot_biome_assignments().keys():
			state.plot_biome_assignments[pos_key] = farm.grid.get_plot_biome_assignment(pos_key)

	# Capture selection state from QuantumInstrumentInput
	var instrument_input = _find_quantum_instrument_input(farm)
	if instrument_input and instrument_input.has_method("get_checked_plots"):
		state.selected_plot_positions = instrument_input.get_checked_plots().duplicate()
		_log("debug", "save", "✅", "Captured selection state: %d plots selected" % state.selected_plot_positions.size())
	else:
		state.selected_plot_positions = []

	# The Witness's belief field rides the save (v5+). Autoload; absent only
	# in stripped test harnesses, where an empty dict (= blank field) is right.
	var witness = _get_autoload("WitnessOrgan")
	if witness and witness.has_method("to_save_dict"):
		state.witness_state = witness.to_save_dict()

	# The quest ledger rides the save (v6+): Commitments Active + History are
	# player state, not session state. CRITICAL: the FARM does not own the
	# quest manager — the SHELL does. A resolver handed only the farm silently
	# no-ops (that exact bug shipped once as 72ff67a9), so resolve through the
	# locator's shell path, with the farm as the in-tree scope.
	var qm_capture = InstrumentLocator.resolve_quest_manager(farm, farm)
	if qm_capture and qm_capture.has_method("to_save_dict"):
		state.quest_state = qm_capture.to_save_dict()
	elif current_state and current_state.quest_state is Dictionary:
		# Shell-less lane (headless harness without a QuestManager): carry the
		# loaded ledger forward rather than silently dropping it from the save.
		state.quest_state = current_state.quest_state.duplicate(true)

	var money = state.all_emoji_credits.get("💰", 0)
	_log("info", "save", "📸", "Captured game state: grid=" + str(state.grid_width) + "x" + str(state.grid_height) +
		", plots=" + str(state.plots.size()) + ", 💰=" + str(money) + ", selected=" + str(state.selected_plot_positions.size()))
	return state


func apply_state_to_farm(state: GameState, farm: Node) -> void:
	# Apply loaded state to active Farm.

	# Refactored for Farm/Biome/Qubit architecture:
	# - Loads economy, plot configuration, time from GameState
	# - Restores complete biome quantum state tree (all qubits)
	if not farm:
		push_error("Farm not found - cannot apply state")
		return

	# Save format handling:
	#   v4 → the beta floor (2026-07-10). Everything below is a pre-beta era
	#        that SaveStore refuses at load (MIN_COMPATIBLE_SAVE_VERSION), so
	#        by the time a state reaches here it must be v4+. Future versions
	#        add an explicit migration branch here (ratcheted by
	#        tests/test_save_format_freeze.py).
	if state.save_version < SaveStore.MIN_COMPATIBLE_SAVE_VERSION or state.save_version > GameState.CURRENT_SAVE_VERSION:
		push_error("Save file version unsupported: %d (supported: %d..%d)" % [
			state.save_version, SaveStore.MIN_COMPATIBLE_SAVE_VERSION, GameState.CURRENT_SAVE_VERSION])
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
			economy.emoji_credits[EmojiUtil.normalize(emoji)] = state.all_emoji_credits[emoji]
		_log("debug", "save", "💰", "Loaded %d emoji types from all_emoji_credits" % state.all_emoji_credits.size())

	if "total_tributes_paid" in economy:
		economy.total_tributes_paid = state.tributes_paid
	if "total_tributes_failed" in economy:
		economy.total_tributes_failed = state.tributes_failed

	for emoji in economy.emoji_credits.keys():
		economy._emit_resource_change(emoji)

	var graph_applied = false
	if state.farm_variable_graph_jsonl is Array and not state.farm_variable_graph_jsonl.is_empty():
		var apply_result = BalanceService.apply_farm_variable_graph(
			farm,
			state.farm_variable_graph_jsonl,
			"save_state.farm_variable_graph"
		)
		graph_applied = bool(apply_result.get("ok", false))
	elif state.farm_variable_graph_path != "":
		var load_result = BalanceService.load_farm_variable_graph_file(
			farm,
			state.farm_variable_graph_path,
			"save_state.farm_variable_graph_path"
		)
		graph_applied = bool(load_result.get("ok", false))
	if not graph_applied:
		# No save-specific graph → load the canonical default.jsonl as the base economy
		# defaults (single source of truth). BalanceConfig.DEFAULTS is the code-level
		# fallback only if the file is missing/unreadable. Layering:
		#   BalanceConfig.DEFAULTS  <  default.jsonl (canonical)  <  save deltas.
		var def_result = BalanceService.load_farm_variable_graph_file(
			farm, FarmVariableGraph.DEFAULT_GRAPH_PATH, "default_graph"
		)
		if not bool(def_result.get("ok", false)):
			BalanceService.reset_to_default(farm)

	if farm.has_method("set_reap_count"):
		farm.set_reap_count(int(state.reap_count))
	elif "reap_count" in farm:
		farm.reap_count = int(state.reap_count)

	if "faction_density" in farm and farm.faction_density != null:
		var fd_state = state.faction_density if "faction_density" in state else {}
		if fd_state is Dictionary:
			farm.faction_density.deserialize(fd_state)
		if farm.has_method("reset_identity_band_watch"):
			farm.reset_identity_band_watch()

	if "bridge_register" in farm and farm.bridge_register != null:
		var bridge_state = state.bridges if "bridges" in state else {}
		if bridge_state is Dictionary:
			farm.bridge_register.from_dict(bridge_state)

	# Phase 2: faction_standings — rebuild FactionStanding objects from saved dicts.
	if "faction_standings" in farm:
		var saved_standings: Dictionary = state.faction_standings if "faction_standings" in state else {}
		var standing_class = load("res://Core/Factions/FactionStanding.gd")
		farm.faction_standings = {}
		for fname in saved_standings:
			var sd = saved_standings[fname]
			if sd is Dictionary:
				farm.faction_standings[fname] = standing_class.from_dict(sd)

	# Story flags + narrative log
	if "story_flags_fired" in farm:
		farm.story_flags_fired = (state.story_flags_fired if "story_flags_fired" in state else {}).duplicate()
	if "story_log" in farm:
		farm.story_log = (state.story_log if "story_log" in state else []).duplicate(true)

	# Revealed plots (cosmetic bubble reveal). Migration: a pre-reveal-era save that
	# was actually played (any fired flag) saw the full field — restore it rather
	# than going dark. A fresh scenario state (no flags, no reveals) starts dark.
	if "revealed_plots" in farm:
		farm.revealed_plots = {}
		var saved_revealed: Array = state.revealed_plots if "revealed_plots" in state else []
		for pos in saved_revealed:
			if pos is Vector2i:
				farm.revealed_plots[pos] = true
		if farm.revealed_plots.is_empty() and not farm.story_flags_fired.is_empty():
			if farm.grid and farm.grid.has_method("get_plot_biome_assignments"):
				for pos in farm.grid.get_plot_biome_assignments():
					farm.revealed_plots[pos] = true

	if "player_alignment" in farm:
		var AlignmentGraphCls = load("res://Core/Alignment/AlignmentGraph.gd")
		var saved_pa: Dictionary = state.player_alignment if "player_alignment" in state else {}
		if saved_pa is Dictionary and not saved_pa.is_empty():
			farm.player_alignment = AlignmentGraphCls.from_dict(saved_pa)
		else:
			farm.player_alignment = AlignmentGraphCls.from_uniform_superposition()

	if farm.grid and farm.grid.has_biomes():
		var biome_count = 0
		for biome in farm.grid.get_all_biomes().values():
			if "quantum_time_scale" in biome:
				biome.quantum_time_scale = state.quantum_time_scale
				biome_count += 1
			if "observation_stride" in biome:
				biome.observation_stride = state.observation_stride
			# max_evolution_dt not restored — BiomeCharacteristics.apply_to_biome() sets it at boot
		_log("debug", "save", "⏱️", "Applied timescale: speed=%.4fx stride=%d to %d biomes" % [state.quantum_time_scale, state.observation_stride, biome_count])

	var restored_known_icons = _resolve_known_icons_from_state(state)
	if farm and farm.has_method("set_known_icons"):
		farm.set_known_icons(restored_known_icons)
		if state.atom_map_snapshot and not state.atom_map_snapshot.is_empty():
			_log("debug", "save", "🗺️", "Loaded IconMap snapshot cache (%s, %d emojis)" % [
				state.atom_map_snapshot_source,
				state.atom_map_snapshot.get("by_emoji", {}).size()
			])

	# Restore active icon slots (3 indices into known_icons).
	if farm and "active_icon_slots" in farm:
		var slots: Array = []
		if "active_icon_slots" in state and state.active_icon_slots is Array:
			for s in state.active_icon_slots:
				slots.append(int(s))
		if slots.size() != 3:
			slots = [0, 1, 2]
		var max_idx: int = max(0, farm.known_icons.size() - 1)
		for i in range(slots.size()):
			slots[i] = clampi(slots[i], 0, max_idx)
		farm.active_icon_slots = slots

	# Restore biome unlock/exploration progression before grid refresh so layout sync is correct.
	_restore_biome_progression_state(state)

	var grid = farm.grid
	if farm.has_method("refresh_grid_for_biomes"):
		farm.refresh_grid_for_biomes()
		grid = farm.grid

	var terminal_pool = farm.terminal_pool if "terminal_pool" in farm else null
	if terminal_pool and terminal_pool.has_method("reset_all"):
		terminal_pool.reset_all()
	if grid:
		for y in range(grid.grid_height):
			for x in range(grid.grid_width):
				var existing_plot = grid.get_plot(Vector2i(x, y))
				if existing_plot and existing_plot.has_method("unbind_register"):
					existing_plot.unbind_register()

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
			# Restore plot type from older enum saves
			if plot_data.has("type_name"):
				plot.plot_type_name = plot_data["type_name"]
			elif plot_data.has("type"):  # Old saves with enum
				var old_type = plot_data["type"]
				match old_type:
					0: plot.plot_type_name = "wheat"
					2: plot.plot_type_name = "mushroom"
					6: plot.plot_type_name = "wheat"  # Deprecated energy taps coerce to a live crop type
					_: plot.plot_type_name = "wheat"

			if plot_data.get("is_planted", false):
				var saved_register = plot_data.get("register_id", -1)
				var saved_biome = plot_data.get("biome_name", "")
				var saved_north = plot_data.get("north_emoji", "")
				var saved_south = plot_data.get("south_emoji", "")
				if saved_register >= 0 and saved_biome != "":
					var emoji_pair = {"north": saved_north, "south": saved_south}

					# TerminalPool is the save/load authority for live register bindings.
					var tp = terminal_pool
					if tp and tp.has_method("get_unbound_terminal"):
						var t = tp.get_unbound_terminal()
						if t:
							t.grid_position = pos
							var terminal_bound := bool(tp.bind_terminal(t, saved_register, saved_biome, emoji_pair))
							if terminal_bound:
								plot.attach_terminal(t)
							else:
								_log("warn", "save", "⚠️", "Terminal restore bind rejected at %s for register %d in %s" % [
									str(pos), saved_register, saved_biome
								])
						else:
							_log("warn", "save", "⚠️", "No free terminal while restoring bound plot at %s" % str(pos))
					else:
						_log("warn", "save", "⚠️", "No terminal pool while restoring bound plot at %s" % str(pos))

					# Restore measurement state if present
					if plot_data.get("has_been_measured", false):
						var outcome = plot_data.get("measured_outcome", "")
						var probability = plot_data.get("measured_probability", 0.5)
						if plot.terminal and plot.terminal.is_bound:
							plot.terminal.mark_measured(outcome, probability)
						elif plot.has_method("remember_measurement"):
							plot.remember_measurement(outcome, probability, saved_north, saved_south)
			elif plot_data.get("has_been_measured", false):
				var memory_outcome = plot_data.get("measured_outcome", "")
				var memory_probability = plot_data.get("measured_probability", 0.5)
				var memory_north = plot_data.get("north_emoji", "")
				var memory_south = plot_data.get("south_emoji", "")
				if plot.has_method("remember_measurement"):
					plot.remember_measurement(memory_outcome, memory_probability, memory_north, memory_south)

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
		for pos_key in state.plot_biome_assignments.keys():
			farm.grid.set_plot_biome_assignment(pos_key, str(state.plot_biome_assignments[pos_key]))

	var has_register_infra = false
	if state.biome_states:
		await _restore_all_biome_states(farm, state.biome_states)
		for bs in state.biome_states.values():
			if bs.has("register_infrastructure"):
				has_register_infra = true
				break
	if not has_register_infra:
		_migrate_plot_infra_to_register(farm, state)

	# Restore selection state to QuantumInstrumentInput
	if state.selected_plot_positions and state.selected_plot_positions.size() > 0:
		var instrument_input = _find_quantum_instrument_input(farm)
		if instrument_input and instrument_input.has_method("set_checked_plots"):
			instrument_input.set_checked_plots(state.selected_plot_positions)
			_log("debug", "save", "✅", "Restored selection state: %d plots selected" % state.selected_plot_positions.size())
		else:
			_log("debug", "save", "⚠️", "QuantumInstrumentInput not found - selection state not restored")

	# Restore the Witness's belief field (v5+). v4 migration is explicit:
	# pre-Witness saves carry no belief field, so it cold-boots maximally
	# mixed — blank beliefs are a valid state (advisory organ; forgetting is
	# legal). Spec drift inside a v5 save also cold-boots (load_save_dict).
	var witness = _get_autoload("WitnessOrgan")
	if witness and witness.has_method("load_save_dict"):
		if state.save_version == 4:
			witness.load_save_dict({})
			_log("info", "save", "👁️", "v4 save (pre-Witness) — belief field cold-boots blank")
		else:
			witness.load_save_dict(state.witness_state if state.witness_state is Dictionary else {})

	# Restore the quest ledger (v6+). This runs on BOTH load lanes (slot
	# restart and path load) — AFTER SessionLifecycle.reset_runtime_singletons
	# cleared the session board, and BEFORE StoryEngine._restore_arc_quests_
	# after_load re-offers arcs (its has_quest_for_flag guard then skips flags
	# whose quest sits in the restored actives — no duplicate teachings).
	# Same shell-not-farm resolver gotcha as the capture side (72ff67a9).
	var saved_quests: Dictionary = {}
	if state.save_version == 4 or state.save_version == 5:
		# Pre-ledger eras carry no quest_state — the board regenerates from
		# persisted truth (tutorial_seen, story_flags_fired, known_icons),
		# which is exactly what these saves always did. Explicit no-op.
		saved_quests = {}
	elif state.quest_state is Dictionary:
		saved_quests = state.quest_state
	var qm_restore = InstrumentLocator.resolve_quest_manager(farm, farm)
	if qm_restore and qm_restore.has_method("restore_from_save_dict"):
		qm_restore.restore_from_save_dict(saved_quests)
		if not saved_quests.is_empty():
			_log("info", "save", "📜", "Restored quest ledger: %d active, %d completed, %d failed (next id %d)" % [
				saved_quests.get("active", {}).size(), saved_quests.get("completed", []).size(),
				saved_quests.get("failed", []).size(), int(saved_quests.get("next_quest_id", 0))])

	_log("info", "save", "✓", "State applied to farm successfully - quantum states will regenerate from biome")


func _resolve_known_icons_from_state(state: GameState) -> Array:
	# Resolve known icons from save state.
	var merged: Array = []
	var seen: Dictionary = {}

	var sources: Array = []
	if state and state.known_icons is Array:
		sources.append(state.known_icons)

	for source in sources:
		for icon in source:
			if not (icon is Dictionary):
				continue
			var north = str(icon.get("north", ""))
			var south = str(icon.get("south", ""))
			if north == "" or south == "" or north == south:
				continue
			var key = "%s|%s" % [north, south]
			if seen.has(key):
				continue
			seen[key] = true
			merged.append({"north": north, "south": south})

	if merged.is_empty():
		return [{"north": "🌾", "south": "👥"}]
	return merged


func _capture_biome_progression_state(state: GameState, current_state: GameState) -> void:
	var observation_frame = _get_autoload("ObservationFrame")
	if observation_frame and observation_frame.has_method("get_unlocked_biomes"):
		state.unlocked_biomes = observation_frame.get_unlocked_biomes()
	elif current_state:
		state.unlocked_biomes = current_state.unlocked_biomes.duplicate()
	else:
		state.unlocked_biomes = []

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
		state.active_biome_name = ""


func _restore_biome_progression_state(state: GameState) -> void:
	var unlocked_biomes = state.unlocked_biomes.duplicate()

	var active_biome = str(state.active_biome_name)
	if (active_biome == "" or not (active_biome in unlocked_biomes)) and not unlocked_biomes.is_empty():
		active_biome = str(unlocked_biomes[0])

	var gsm = _get_autoload("GameStateManager")
	if gsm and gsm.current_state:
		gsm.current_state.unlocked_biomes = unlocked_biomes.duplicate()
		gsm.current_state.unexplored_biome_pool = state.unexplored_biome_pool.duplicate()
		gsm.current_state.active_biome_name = active_biome

	# ObservationFrame is the single authority for biome order (slop-patrol
	# Tier 3); its biome_order_changed signal fans out to ActiveBiomeManager.
	var observation_frame = _get_autoload("ObservationFrame")
	if observation_frame:
		if observation_frame.has_method("set_biome_order"):
			observation_frame.set_biome_order(unlocked_biomes)
		if observation_frame.has_method("set_neutral_biome") and active_biome != "":
			observation_frame.set_neutral_biome(active_biome)

	var active_biome_manager = _get_autoload("ActiveBiomeManager")
	if active_biome_manager:
		if active_biome_manager.has_method("set_biome_order"):
			# Idempotent: the mirror applies locally and only writes back to
			# the authority if it has diverged (covers partial headless boots
			# and the window before ABM's deferred signal connect).
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


func _capture_atom_map_snapshot(farm: Node, known_emojis: Array) -> Dictionary:
	# Capture a compact icon map payload for tooling.

	# Preference order:
	# 1) BiomeEvolutionBatcher global icon map (runtime-truth snapshot)
	# 2) Derived uniform map from known emojis
	var out := {
		"atom_map_snapshot": {},
		"atom_map_snapshot_source": "",
		"atom_map_snapshot_time": int(Time.get_unix_time_from_system())
	}

	if farm and "biome_evolution_batcher" in farm and farm.biome_evolution_batcher:
		var batcher = farm.biome_evolution_batcher
		var payload = batcher.get_global_icon_map()
		if payload is Dictionary and not payload.is_empty():
			var by_emoji = payload.get("by_emoji", {})
			if by_emoji is Dictionary and not by_emoji.is_empty():
				out["atom_map_snapshot"] = {
					"by_emoji": by_emoji.duplicate(true),
					"total": float(payload.get("total", 0.0)),
					"steps": int(payload.get("steps", 0))
				}
				out["atom_map_snapshot_source"] = "batcher_global"
				return out

	var derived = {}
	for emoji in known_emojis:
		var s = str(emoji)
		if s != "" and not derived.has(s):
			derived[s] = 1.0
	if not derived.is_empty():
		out["atom_map_snapshot"] = {
			"by_emoji": derived,
			"total": float(derived.size()),
			"steps": 1
		}
		out["atom_map_snapshot_source"] = "derived_from_icons"
	return out


func _resolve_known_icons_for_capture(farm: Node) -> Array:
	var merged: Array = []
	var seen: Dictionary = {}

	if farm and farm.has_method("get_known_icons"):
		for icon in farm.get_known_icons():
			if not (icon is Dictionary):
				continue
			var north = str(icon.get("north", ""))
			var south = str(icon.get("south", ""))
			if north == "" or south == "" or north == south:
				continue
			var key = "%s|%s" % [north, south]
			if seen.has(key):
				continue
			seen[key] = true
			merged.append({"north": north, "south": south})

	if merged.is_empty():
		return [{"north": "🌾", "south": "👥"}]
	return merged


func _capture_all_biome_states(farm: Node) -> Dictionary:
	var all_states = {}
	if not farm.grid or not farm.grid.has_biomes():
		push_warning("Farm grid has no biomes registry - cannot capture biome states")
		return all_states

	for biome_name in farm.grid.get_biome_names():
		var biome = farm.grid.get_biome(biome_name)
		if biome:
			var state = _capture_single_biome_state(biome, biome_name)
			state["biome_class"] = biome.get_script().resource_path
			all_states[biome_name] = state
			_log("debug", "save", "💾", "Captured %s biome (%s)" % [biome_name, state["biome_class"]])

	return all_states


func _capture_single_biome_state(biome: Node, _biome_name: String) -> Dictionary:
	var state_dict = {
		"time_elapsed": 0.0,
		"quantum_states": []
	}

	if "time_elapsed" in biome:
		state_dict["time_elapsed"] = biome.time_elapsed
	elif "time_tracker" in biome and biome.time_tracker:
		state_dict["time_elapsed"] = biome.time_tracker.time_elapsed

	if "quantum_states" in biome:
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

	if biome.quantum_computer and biome.quantum_computer.register_infrastructure.size() > 0:
		var infra = {}
		for reg_id in biome.quantum_computer.register_infrastructure:
			infra[str(reg_id)] = biome.quantum_computer.register_infrastructure[reg_id].duplicate(true)
		state_dict["register_infrastructure"] = infra

	# Berry harvest counters are campaign progression (berry_consumed_count_gte
	# gates the act-1 ladder and every teaching claim). A save keeps its SPENT
	# registers; without these two numbers it forgets the credit for spending
	# them, which strands berry gates on any resumed run.
	if biome.quantum_computer and biome.quantum_computer.berry_register:
		state_dict["berry_consumed_count"] = biome.quantum_computer.berry_register.get_consumed_count()
		state_dict["berry_consumed_phase"] = biome.quantum_computer.berry_register.get_consumed_phase()

	# Density matrix ρ — the deepest level of truth. Plots are projections of
	# ρ via viz_cache; without persisting ρ, registers re-boot to ground state
	# on load and plots render against stale (or empty) Bloch snapshots.
	if biome.quantum_computer and biome.quantum_computer.density_matrix:
		state_dict["density_matrix"] = _encode_complex_matrix(biome.quantum_computer.density_matrix)

	# Snapshot fully-built icon physics so Python lab can load exactly what the game uses.
	# This is the authoritative post-composition state (faction + JSONL + biome overrides).
	if "icons" in biome and biome.icons is Dictionary:
		var icon_snap = {}
		for emoji in biome.icons:
			var ic = biome.icons[emoji]
			if not ic:
				continue
			icon_snap[emoji] = {
				"self_energy":          ic.self_energy if "self_energy" in ic else 0.0,
				"driver":               ic.self_energy_driver if "self_energy_driver" in ic else "",
				"driver_frequency":     ic.driver_frequency if "driver_frequency" in ic else 0.0,
				"driver_phase":         ic.driver_phase if "driver_phase" in ic else 0.0,
				"driver_amplitude":     ic.driver_amplitude if "driver_amplitude" in ic else 1.0,
				"hamiltonian_couplings":ic.hamiltonian_couplings.duplicate() if "hamiltonian_couplings" in ic else {},
			}
		state_dict["icons"] = icon_snap
		# Physics signature — lets the load path detect H/L drift between save and
		# load (e.g. icons.json/biomes.json edits). Uses the ONE canonical fingerprint
		# the builder stamps on the QuantumComputer (the same identity the C++ engine
		# drift check uses) — not a second, separately-computed signature.
		state_dict["physics_signature"] = str(biome.quantum_computer.physics_signature) if biome.quantum_computer else ""

	# Snapshot register axes so Python lab can reconstruct RegisterMap.
	if biome.quantum_computer and biome.quantum_computer.register_map:
		var rm = biome.quantum_computer.register_map
		var axes = []
		for qubit_idx in rm.axes:
			var axis = rm.axes[qubit_idx]
			axes.append({"qubit": int(qubit_idx), "north": axis["north"], "south": axis["south"]})
		state_dict["register_axes"] = axes

	return state_dict


func _restore_all_biome_states(farm: Node, biome_states: Dictionary) -> void:
	if not farm.grid or not "biomes" in farm.grid:
		push_warning("Farm grid has no biomes registry - cannot restore biome states")
		return

	var batcher = farm.biome_evolution_batcher if ("biome_evolution_batcher" in farm and farm.biome_evolution_batcher) else null

	for biome_name in biome_states.keys():
		var biome_state = biome_states[biome_name]
		var biome = farm.grid.get_biome(biome_name)
		if not biome:
			push_warning("Biome %s not found in grid registry - skipping restore" % biome_name)
			continue
		await _restore_single_biome_state(biome, biome_state, biome_name)
		# The lookahead buffer still holds frames computed from the PRE-load
		# state (possibly at a different register dimension). Flush it so a
		# stale writeback cannot clobber the restored ρ; the flush re-primes
		# frozen frames from the restored ρ and the next packet refills off it.
		if batcher and batcher.has_method("invalidate_biome_buffer"):
			batcher.invalidate_biome_buffer(str(biome_name))
		_log("debug", "save", "📂", "Restored %s biome" % biome_name)

	_warn_for_physics_drift(farm, biome_states)


func _restore_single_biome_state(biome: Node, state: Dictionary, biome_name: String) -> void:
	if state.has("time_elapsed"):
		if "time_elapsed" in biome:
			biome.time_elapsed = state.time_elapsed
		elif "time_tracker" in biome and biome.time_tracker:
			biome.time_tracker.time_elapsed = state.time_elapsed

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

	if biome.is_inside_tree():
		await biome.get_tree().process_frame

	if state.has("register_axes") and biome.quantum_computer:
		var axes = state["register_axes"]
		if axes is Array and not axes.is_empty():
			var qc_axes = biome.quantum_computer
			var restored = false
			if qc_axes.has_method("restore_register_map_from_axes"):
				restored = qc_axes.restore_register_map_from_axes(axes)
			else:
				if qc_axes.register_map and qc_axes.register_map.has_method("clear"):
					qc_axes.register_map.clear()
				for axis_data in axes:
					if not (axis_data is Dictionary):
						continue
					var qubit_raw = axis_data.get("qubit", -1)
					if not str(qubit_raw).is_valid_int():
						continue
					var north_emoji = str(axis_data.get("north", ""))
					var south_emoji = str(axis_data.get("south", ""))
					if north_emoji == "" or south_emoji == "":
						continue
					qc_axes.register_map.register_axis(int(qubit_raw), north_emoji, south_emoji)
					qc_axes._ensure_entanglement_node(int(qubit_raw))
					qc_axes._ensure_register_infra(int(qubit_raw))
					restored = true
			if not restored:
				push_warning("Biome %s register_axes present but could not be restored" % biome_name)

	if state.has("register_infrastructure") and biome.quantum_computer:
		var qc = biome.quantum_computer
		for reg_str in state["register_infrastructure"]:
			qc.register_infrastructure[int(reg_str)] = state["register_infrastructure"][reg_str]

	# Berry credit restore (absent on pre-fix saves → 0, the old behavior).
	if biome.quantum_computer and biome.quantum_computer.berry_register:
		biome.quantum_computer.berry_register.restore_consumed(
			int(state.get("berry_consumed_count", 0)),
			float(state.get("berry_consumed_phase", 0.0)))

	# Restore ρ, then re-seed viz_cache so PlotGridDisplay reads live Bloch
	# snapshots immediately on load instead of -1.0 from an empty cache.
	if state.has("density_matrix") and biome.quantum_computer:
		var qc_rho = biome.quantum_computer
		var rho = _decode_complex_matrix(state["density_matrix"])
		if rho:
			qc_rho.density_matrix = rho
			if "viz_cache" in biome and biome.viz_cache and qc_rho.register_map:
				var metadata_payload = {
					"num_qubits": qc_rho.register_map.num_qubits,
					"axes": qc_rho.register_map.axes.duplicate(true) if "axes" in qc_rho.register_map else {},
				}
				var emoji_to_qubit: Dictionary = {}
				var emoji_to_pole: Dictionary = {}
				var emoji_list: Array = []
				for emoji in qc_rho.register_map.coordinates.keys():
					var coord = qc_rho.register_map.coordinates[emoji]
					emoji_to_qubit[emoji] = coord.get("qubit", -1)
					emoji_to_pole[emoji] = coord.get("pole", -1)
					emoji_list.append(emoji)
				metadata_payload["emoji_to_qubit"] = emoji_to_qubit
				metadata_payload["emoji_to_pole"] = emoji_to_pole
				metadata_payload["emoji_list"] = emoji_list
				biome.viz_cache.update_metadata_from_payload(metadata_payload)
				var packet = qc_rho.export_bloch_packet()
				if packet.is_empty():
					packet = PackedFloat64Array()
					packet.resize(qc_rho.register_map.num_qubits * 9)
					for q in range(qc_rho.register_map.num_qubits):
						var base = q * 9
						packet[base + 0] = qc_rho.get_marginal(q, 0)
						packet[base + 1] = qc_rho.get_marginal(q, 1)
						packet[base + 2] = 0.0
						packet[base + 3] = 0.0
						packet[base + 4] = packet[base + 0] - packet[base + 1]
						packet[base + 5] = abs(packet[base + 4])
						packet[base + 6] = 0.0
						packet[base + 7] = 0.0
						packet[base + 8] = 0.0
				biome.viz_cache.update_from_bloch_packet(packet, qc_rho.register_map.num_qubits)
			elif qc_rho.register_map == null or qc_rho.register_map.num_qubits <= 0:
				push_warning("Biome %s restored density matrix without a valid register map" % biome_name)

	# Path-load P0 family #5: a save can carry RUNTIME-INJECTED axes (icon
	# injections / berry incorporations after boot). The axes restore above
	# grows register_map, but the boot-built H/L are still sized for the BOOT
	# layout — without this the biome evolves under a wrong, undersized H until
	# some unrelated rebuild happens to fire. If the live operators no longer
	# match the restored register layout (dimension or physics signature),
	# trigger the CANONICAL rebuild — the same builder authority the runtime
	# inject lane uses (BiomeQuantumSystemBuilder), which also marks the C++
	# lookahead twin for re-register. Must run AFTER ρ restore: the rebuild's
	# buffer flush re-primes the lookahead from the CURRENT ρ, and priming from
	# the pre-restore (old-dim) ρ would feed stale frames back over the
	# restored state (negative-trace garbage → I/d hard reinit).
	if biome.quantum_computer and biome.quantum_computer.register_map:
		var qc_ops = biome.quantum_computer
		var reg_dim: int = qc_ops.register_map.dim()
		var h_dim: int = qc_ops.hamiltonian.n if qc_ops.hamiltonian else 0
		var saved_sig := str(state.get("physics_signature", ""))
		var sig_mismatch: bool = saved_sig != "" and saved_sig != str(qc_ops.physics_signature)
		if (h_dim != reg_dim or sig_mismatch) and biome.has_method("rebuild_operators_from_register_map"):
			if biome.rebuild_operators_from_register_map():
				var h_dim_now: int = qc_ops.hamiltonian.n if qc_ops.hamiltonian else 0
				_log("info", "save", "🔁", "Rebuilt %s operators after restore (H dim %d → %d for %d-qubit register)" % [
						biome_name, h_dim, h_dim_now, qc_ops.register_map.num_qubits])
			else:
				push_warning("Biome %s operators stale after restore (H dim %d vs register dim %d) and rebuild failed" % [biome_name, h_dim, reg_dim])


func _warn_for_physics_drift(farm: Node, biome_states: Dictionary) -> void:
	if not farm or not farm.grid:
		return
	for biome_name in biome_states.keys():
		var state = biome_states[biome_name]
		if not (state is Dictionary) or not state.has("physics_signature"):
			continue
		var saved_sig = str(state["physics_signature"])
		if saved_sig == "":
			continue
		var biome = farm.grid.get_biome(str(biome_name))
		if not biome or not biome.quantum_computer:
			continue
		# Compare the ONE canonical fingerprint the builder stamped on the rebuilt
		# biome to the one saved with it. Same identity used for engine-drift detection
		# — no second, separately-computed signature to fall out of agreement with.
		var current_sig = str(biome.quantum_computer.physics_signature)
		if current_sig != "" and saved_sig != current_sig:
			push_warning("Biome '%s' physics drift on load: saved signature %s != current %s — restored ρ will evolve under different H/L than at save time" % [biome_name, saved_sig, current_sig])


func _migrate_plot_infra_to_register(farm: Node, state: GameState) -> void:
	if not farm.grid:
		return

	var migrated_count = 0
	for plot_data in state.plots:
		var pos = plot_data.get("position", GridSentinel.INVALID_POSITION)
		if pos == GridSentinel.INVALID_POSITION:
			continue

		var reg_id = plot_data.get("register_id", -1)
		var biome_name = plot_data.get("biome_name", "")
		if reg_id < 0 or biome_name == "":
			continue

		var biome = farm.grid.get_biome(biome_name)
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
		_log("info", "save", "🔄", "Migrated %d plot infra entries to register_infrastructure" % migrated_count)


func _encode_complex_matrix(m) -> Dictionary:
	# ComplexMatrix._to_packed_auto() returns a Dictionary with Packed* arrays.
	# JSON.stringify rewrites those as plain Arrays of numbers — round-trip is
	# lossless; _decode_complex_matrix re-Packs them before hydrating.
	if m == null:
		return {}
	return m._to_packed_auto()


func _decode_complex_matrix(encoded):
	if encoded == null or typeof(encoded) != TYPE_DICTIONARY:
		return null
	var dim := int(encoded.get("dim", 0))
	if dim <= 0:
		return null
	var ComplexMatrixClass = load("res://Core/QuantumSubstrate/ComplexMatrix.gd")
	var m = ComplexMatrixClass.new(dim)
	var hydrated: Dictionary = encoded.duplicate()
	if str(hydrated.get("format", "dense")) == "csr":
		hydrated["row_ptr"] = PackedInt32Array(encoded.get("row_ptr", []))
		hydrated["col_idx"] = PackedInt32Array(encoded.get("col_idx", []))
		hydrated["values_real"] = PackedFloat64Array(encoded.get("values_real", []))
		hydrated["values_imag"] = PackedFloat64Array(encoded.get("values_imag", []))
	else:
		hydrated["data"] = PackedFloat64Array(encoded.get("data", []))
	m._from_packed_auto(hydrated)
	return m
