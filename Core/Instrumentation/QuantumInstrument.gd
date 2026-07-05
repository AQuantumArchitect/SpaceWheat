class_name QuantumInstrument
extends RefCounted

## QuantumInstrument - Single game mechanics API for all input sources.
##
## All quantum farm actions route through here:
##   Keyboard → QII (adapter) ──┐
##   Bot → Bridge (adapter) ────┼──→ QuantumInstrument ──→ Farm
##   Touch → Gesture (adapter) ─┘    (game mechanics)     (physics)
##
## Validates, executes, and emits signals for every gameplay action.
## Holds selection state (biome, plot, checked plots) shared across adapters.

const GateActionHandler = preload("res://Core/Instrumentation/Handlers/GateActionHandler.gd")
const LindbladHandler = preload("res://Core/Instrumentation/Handlers/LindbladHandler.gd")
const GranularityController = preload("res://Core/Utilities/GranularityController.gd")
const GameStateSerializerClass = preload("res://Core/GameState/GameStateSerializer.gd")
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")

const DEFAULT_TIMESCALE_OBJECTIVE: Dictionary = {
	"focus_emojis": [],
	"resource_floors": {"🍞": 13.0, "❄️": 8.0, "👥": 13.0},
	"top_k": 8,
	"target_gain_per_wait": 1.0,
	"horizon_min_phrames": 6,
	"horizon_max_phrames": 72
}

# ============================================================================
# SIGNALS
# ============================================================================

signal action_performed(action: String, result: Dictionary)
signal plot_check_changed(position: Vector2i, is_checked: bool)

# ============================================================================
# STATE
# ============================================================================

var farm: Node = null

## Terminal pool (instrument owns its measurement probes)
var terminal_pool = null

## Selection state (absorbed from QuantumInstrumentState)
var current_biome: String = ""
var current_plot_idx: int = 0
var last_plot_idx: int = -1  # persists across leave_plot_ring; read by BiomeInspectorOverlay
var last_selected_position: Vector2i = GridSentinel.INVALID_POSITION
var checked_plots: Array[Vector2i] = []

## Submenu state
var current_submenu_name: String = ""
var current_submenu_data: Dictionary = {}
var submenu_page: int = 0

## Active archetype frame (hat row 4-0). Empty string (FRAME_NULL) = no hat.
var current_frame: String = ToolConfig.FRAME_ACE
var _timescale_objective: Dictionary = DEFAULT_TIMESCALE_OBJECTIVE.duplicate(true)

## Cached autoload references
var _verbose = null

# ============================================================================
# GATE DISPATCH TABLE (moved from snapshot bridge)
# ============================================================================

const _GATE_DISPATCH: Dictionary = {
	"pauli_x": Callable(GateActionHandler, "apply_pauli_x"),
	"pauli_y": Callable(GateActionHandler, "apply_pauli_y"),
	"pauli_z": Callable(GateActionHandler, "apply_pauli_z"),
	"hadamard": Callable(GateActionHandler, "apply_hadamard"),
	"s_gate": Callable(GateActionHandler, "apply_s_gate"),
	"t_gate": Callable(GateActionHandler, "apply_t_gate"),
	"sdg": Callable(GateActionHandler, "apply_sdg_gate"),
	"tdg": Callable(GateActionHandler, "apply_tdg_gate"),
	"rx": Callable(GateActionHandler, "apply_rx_gate"),
	"ry": Callable(GateActionHandler, "apply_ry_gate"),
	"rz": Callable(GateActionHandler, "apply_rz_gate"),
	"cnot": Callable(GateActionHandler, "apply_cnot"),
	"cz": Callable(GateActionHandler, "apply_cz"),
	"swap": Callable(GateActionHandler, "apply_swap"),
	"bell": Callable(GateActionHandler, "create_bell_pair"),
	"ghz": Callable(GateActionHandler, "create_ghz_state"),
	"cluster": Callable(GateActionHandler, "cluster"),
}


# ============================================================================
# SETUP
# ============================================================================

func setup(farm_ref: Node) -> void:
	farm = farm_ref
	_log("info", "instrument", "🎛️", "QuantumInstrument initialized (farm=%s)" % [
		str(farm_ref.name) if farm_ref else "null"
	])


# ============================================================================
# SELECTION MANAGEMENT
# ============================================================================

func select_plot(plot_idx: int, biome_name: String, position: Vector2i) -> Dictionary:
	var old_idx = current_plot_idx
	var old_biome = current_biome
	current_plot_idx = plot_idx
	current_biome = biome_name
	last_selected_position = position
	var changed = old_idx != plot_idx or old_biome != biome_name
	return {
		"selection_changed": changed,
		"old_idx": old_idx,
		"new_idx": plot_idx,
		"old_biome": old_biome,
		"new_biome": biome_name,
		"position": position
	}


func toggle_plot_check(position: Vector2i) -> Dictionary:
	var idx = checked_plots.find(position)
	if idx >= 0:
		checked_plots.remove_at(idx)
		plot_check_changed.emit(position, false)
		return {"is_checked": false, "position": position, "checked_count": checked_plots.size()}
	else:
		checked_plots.append(position)
		plot_check_changed.emit(position, true)
		return {"is_checked": true, "position": position, "checked_count": checked_plots.size()}


func clear_checked_plots() -> void:
	for pos in checked_plots.duplicate():
		plot_check_changed.emit(pos, false)
	checked_plots.clear()


func get_checked_plots() -> Array[Vector2i]:
	return checked_plots.duplicate()


func set_checked_plots(positions: Array) -> void:
	checked_plots.clear()
	for pos in positions:
		if pos is Vector2i:
			checked_plots.append(pos)
			plot_check_changed.emit(pos, true)


# ============================================================================
# SUBMENU MANAGEMENT (absorbed from QuantumInstrumentState)
# ============================================================================

func enter_submenu(name: String, context: Dictionary) -> Dictionary:
	submenu_page = 0
	current_submenu_name = name
	if name == "icon_injection":
		var icon_injection_scene = load("res://UI/Core/Submenus/IconInjectionSubmenu.gd")
		current_submenu_data = icon_injection_scene.generate_submenu(
			context.biome, context.farm, submenu_page
		)
	elif name == "gate_selection":
		var gate_selection_scene = load("res://UI/Core/Submenus/GateSelectionSubmenu.gd")
		current_submenu_data = gate_selection_scene.generate_submenu(
			context.biome, context.farm, checked_plots, submenu_page
		)
	else:
		push_error("Unknown submenu: %s" % name)
		return {}
	return current_submenu_data


func exit_submenu() -> void:
	current_submenu_name = ""
	current_submenu_data = {}
	submenu_page = 0


func cycle_submenu_page(context: Dictionary) -> Dictionary:
	submenu_page += 1
	var submenu_data = enter_submenu(current_submenu_name, context)
	return {
		"submenu_changed": true,
		"submenu_name": current_submenu_name,
		"submenu_data": submenu_data,
		"page": submenu_page,
		"max_pages": submenu_data.get("max_pages", 1)
	}


func is_in_submenu() -> bool:
	return current_submenu_name != ""


# ============================================================================
# TOOL MANAGEMENT
# ============================================================================

func set_frame(frame_name: String) -> Dictionary:
	var old_frame = current_frame
	if not ToolConfig.select_frame(frame_name):
		return {"frame": old_frame, "changed": false, "error": "invalid_frame"}
	current_frame = ToolConfig.get_current_frame()
	return {"frame": current_frame, "changed": old_frame != current_frame}


func cycle_frame_mode() -> Dictionary:
	var new_index = ToolConfig.cycle_frame_mode(current_frame)
	var mode_label = ToolConfig.get_frame_mode_label(current_frame)
	return {
		"mode_cycled": true,
		"frame": current_frame,
		"mode_index": new_index,
		"mode_label": mode_label
	}


# ============================================================================
# STATE QUERY (for AI/automation)
# ============================================================================

# ============================================================================
# GROUP 1: UNITARY GATE ACTIONS
# ============================================================================

func _action_guard(positions: Array[Vector2i]) -> Dictionary:
	# Return an error dict if preconditions fail, or {} if all clear.
	if not farm:
		return {"success": false, "error": "no_farm", "message": "Farm not initialized"}
	if positions.is_empty():
		return {"success": false, "error": "no_selection", "message": "No plot selected"}
	return {}


func _cost_action(action_name: String, positions: Array[Vector2i], executor: Callable, context: Dictionary = {}) -> Dictionary:
	var guard = _action_guard(positions)
	if not guard.is_empty(): return guard
	var gate = preflight_action_cost(action_name, context)
	if not gate.get("ok", true):
		return {"success": false, "error": "insufficient_resources", "message": gate.get("message", "Cannot afford %s" % action_name), "cost": gate.get("cost", {})}
	var result: Dictionary = executor.call()
	if result.get("success", false):
		commit_action_cost(action_name, context, action_name)
	return result


func action_rotate(positions: Array[Vector2i], direction: int) -> Dictionary:
	var action_name = "rotate_up" if direction > 0 else "rotate_down"
	return _cost_action(action_name, positions, func():
		var axis = ToolConfig.get_frame_mode_name(ToolConfig.FRAME_DRUID)
		if axis == "": axis = "X"
		var result: Dictionary
		match axis:
			"X": result = GateActionHandler.apply_rx_gate(farm, positions)
			"Y": result = GateActionHandler.apply_ry_gate(farm, positions)
			"Z": result = GateActionHandler.apply_rz_gate(farm, positions)
			_: result = {"success": true, "axis": axis, "direction": direction}
		action_performed.emit(action_name, result)
		return result
	)


func action_hadamard(positions: Array[Vector2i]) -> Dictionary:
	return _cost_action("hadamard", positions, func():
		var result = GateActionHandler.apply_hadamard(farm, positions)
		action_performed.emit("hadamard", result)
		# Recorded under the gate_inject namespace so quest gate predicates
		# (gate_sequence_contains / gate_order) see Druid-frame Hadamards the
		# same as Operator-frame gates — physically it IS a gate injection.
		_notify_quest_projection("gate_inject:hadamard", result)
		return result
	)


# ============================================================================
# SPARK FRAME: INSTANT POLE-SHIFT ACTIONS + ACE PLANT
# ============================================================================
# Spark = strong one-shot Lindblad pulse (surprisal-priced pole emoji), the
# dissipative kick that can re-purify. Plant = coherent Rabi pulse toward the
# north pole — unitary, legal anywhere, cannot purify. Openness is a place:
# every Lindblad verb gates on the TARGET biome's regime (is_open_here), never
# on a global switch. The closed island is unbreakable by construction.

## Honest refusal for a Lindblad verb aimed entirely at sealed ground.
func _enclave_holds(verb: String) -> Dictionary:
	return {
		"success": false, "blocked": true, "error": "enclave_holds",
		"message": "%s needs open (wet) country — the enclave holds: nothing leaks here, nothing pumps." % verb,
	}


## Split a selection by the target biomes' regimes. Lindblad verbs act on the
## open subset and report the sealed remainder.
func _open_positions_of(positions: Array[Vector2i]) -> Array[Vector2i]:
	var open: Array[Vector2i] = []
	if not farm or not farm.grid:
		return open
	for pos in positions:
		var biome = farm.grid.get_biome_for_plot(pos)
		if biome and biome.quantum_computer and biome.quantum_computer.is_open_here():
			open.append(pos)
	return open


func _spark_context(pos: Vector2i, charge_pole: int) -> Dictionary:
	# Drive-cost context: charge the surprisal of the pole being driven —
	# forcing an improbable pole is more work (cost-side mirror of harvest).
	var context: Dictionary = {}
	var north_emoji = LindbladHandler._resolve_north_emoji(farm, pos)
	context["north_emoji"] = north_emoji
	var south_emoji = LindbladHandler._resolve_south_emoji(farm, pos)
	context["south_emoji"] = south_emoji
	var charged = north_emoji if charge_pole == 0 else south_emoji
	var biome = farm.grid.get_biome_for_plot(pos) if farm and farm.grid else null
	if biome and biome.quantum_computer and charged != "":
		var kT = EnergyPricing.biome_temperature(biome, farm)
		var p_target = clampf(float(biome.quantum_computer.get_population(charged)), 0.0, 1.0)
		context["drive_units"] = EnergyPricing.drive_units(p_target, kT)
	return context


func action_spark_north(positions: Array[Vector2i]) -> Dictionary:
	var guard = _action_guard(positions)
	if not guard.is_empty(): return guard
	var open_positions = _open_positions_of(positions)
	if open_positions.is_empty():
		return _enclave_holds("The Spark's jolt")
	var context = _spark_context(open_positions[0], 0)
	var gate = preflight_action_cost("spark_north", context)
	if not gate.get("ok", true):
		return {"success": false, "error": "insufficient_resources",
				"message": gate.get("message", "Need the north-pole emoji to spark"),
				"cost": gate.get("cost", {})}
	var result = LindbladHandler.lindblad_drive(farm, open_positions)
	action_performed.emit("spark_north", result)
	if result.get("success", false):
		commit_action_cost("spark_north", context, "spark_north")
		_notify_quest_projection("spark_north", result)
	return result


func action_spark_south(positions: Array[Vector2i]) -> Dictionary:
	var guard = _action_guard(positions)
	if not guard.is_empty(): return guard
	var open_positions = _open_positions_of(positions)
	if open_positions.is_empty():
		return _enclave_holds("The Spark's jolt")
	var context = _spark_context(open_positions[0], 1)
	var gate = preflight_action_cost("spark_south", context)
	if not gate.get("ok", true):
		return {"success": false, "error": "insufficient_resources",
				"message": gate.get("message", "Need the south-pole emoji to spark"),
				"cost": gate.get("cost", {})}
	var result = LindbladHandler.lindblad_decay(farm, open_positions)
	action_performed.emit("spark_south", result)
	if result.get("success", false):
		commit_action_cost("spark_south", context, "spark_south")
		_notify_quest_projection("spark_south", result)
	return result


func action_plant(positions: Array[Vector2i]) -> Dictionary:
	# Ace R — coherent Rabi pulse toward each plot's north pole. Unitary:
	# works in ANY regime (the one investment verb the enclave allows), and
	# purity-preserving by theorem — it aligns the Bloch vector but cannot
	# lengthen it. A fog must be measured, or jolted with the Spark.
	var guard = _action_guard(positions)
	if not guard.is_empty(): return guard
	var context = _spark_context(positions[0], 0)
	var gate = preflight_action_cost("plant", context)
	if not gate.get("ok", true):
		return {"success": false, "error": "insufficient_resources",
				"message": gate.get("message", "Need the north-pole emoji to plant"),
				"cost": gate.get("cost", {})}
	var result = GateActionHandler.apply_plant(farm, positions)
	action_performed.emit("plant", result)
	if result.get("success", false):
		commit_action_cost("plant", context, "plant")
		_notify_quest_projection("plant", result)
	return result


# ============================================================================
# GROUP 2: LINDBLADIAN ACTIONS (Merchant frame)
# ============================================================================

func action_drain(positions: Array[Vector2i], kind: String = "damp") -> Dictionary:
	# Merchant Q (export) — standing channel out. kind picks the canonical
	# channel: thermal / dephase / damp. Per-plot regime gating lives in the
	# handler: openness is a place.
	var guard = _action_guard(positions)
	if not guard.is_empty(): return guard

	var result = LindbladHandler.enable_persistent_decay(farm, positions, LindbladHandler.PERSISTENT_RATE, kind)
	action_performed.emit("drain", result)
	if result.get("success", false):
		_notify_quest_projection("drain", result)
	return result


func action_pump(positions: Array[Vector2i], kind: String = "damp") -> Dictionary:
	# Merchant R (import) — standing channel in. kind: thermal / damp
	# (dephase-import is refused: decoherence is irreversible).
	var guard = _action_guard(positions)
	if not guard.is_empty(): return guard

	var result = LindbladHandler.enable_persistent_drive(farm, positions, LindbladHandler.PERSISTENT_RATE, kind)
	action_performed.emit("pump", result)
	if result.get("success", false):
		_notify_quest_projection("pump", result)
	return result


func action_settle(positions: Array[Vector2i]) -> Dictionary:
	# Merchant F — close the standing contract on the selected plots. Free,
	# regime-blind: a contract can always be closed.
	var guard = _action_guard(positions)
	if not guard.is_empty(): return guard

	var result = LindbladHandler.settle_channels(farm, positions)
	action_performed.emit("settle", result)
	if result.get("success", false):
		_notify_quest_projection("settle", result)
	return result


# ============================================================================
# GROUP 3: PROBE ACTIONS
# ============================================================================

func action_explore(biome_name: String, grid_pos: Vector2i = GridSentinel.INVALID_POSITION) -> Dictionary:
	if not farm or not terminal_pool:
		return {"success": false, "error": "no_farm", "message": "Farm not ready"}
	var economy = _get_economy()
	if not economy:
		return {"success": false, "error": "no_economy", "message": "Economy system not initialized"}

	var biome = _resolve_biome(biome_name)
	if not biome:
		return {"success": false, "error": "no_biome", "message": "Biome '%s' not found" % biome_name}

	# Invariant: plot_idx ≡ register_id. The column the player highlighted IS
	# the register they're exploring — no random mapping. Fall back to -1 only
	# when called without a grid position (headless/diagnostic paths).
	var target_register_id = grid_pos.x if grid_pos != GridSentinel.INVALID_POSITION else -1

	var result = ProbeActions.action_explore(terminal_pool, biome, economy, target_register_id)
	# Attach terminal to its grid plot. Under the plot_idx ≡ register_id
	# invariant, the canonical grid position for any register is always
	# (register_id, biome_row). If the caller supplied a grid_pos, use it
	# (should match anyway); otherwise derive.
	if result.get("success", false):
		var terminal = result.get("terminal", null)
		if terminal:
			var bound_register = int(result.get("register_id", -1))
			if grid_pos != GridSentinel.INVALID_POSITION:
				terminal.grid_position = grid_pos
			elif bound_register >= 0:
				terminal.grid_position = _derive_grid_position_for_register(biome_name, bound_register)
		_attach_terminal_to_plot(terminal)
	_emit_farm_action("explore", result, grid_pos)
	action_performed.emit("explore", result)
	return result


func action_measure(grid_pos: Vector2i) -> Dictionary:
	if not farm or not terminal_pool:
		return {"success": false, "error": "no_farm", "message": "Farm not ready"}
	var economy = _get_economy()

	var _plot = farm.grid.get_plot(grid_pos) if farm.grid else null
	var terminal = _plot.terminal if _plot else null
	if not terminal:
		return {"success": false, "error": "no_terminal", "message": "No terminal at selection", "blocked": true}
	if not terminal.can_measure():
		# Say WHY: the two not-ready states need opposite advice, and the
		# generic line was shadowing ProbeActions' specific toasts forever.
		if terminal.is_measured:
			return {"success": false, "error": "already_measured", "message": "Already measured — Q harvests it.", "blocked": true}
		return {"success": false, "error": "not_bound", "message": "Nothing to measure — select a plot first (G H J K L ;).", "blocked": true}

	var biome_name = terminal.bound_biome_name
	if biome_name == "":
		return {"success": false, "error": "no_biome", "message": "Terminal not bound to biome", "blocked": true}
	var biome = _resolve_biome(biome_name)
	if not biome:
		return {"success": false, "error": "no_biome", "message": "Biome '%s' not found" % biome_name, "blocked": true}

	var result = ProbeActions.action_measure(terminal, biome, economy, farm)
	_emit_farm_action("measure", result, grid_pos)
	action_performed.emit("measure", result)
	# Quest-visible: the Zeno arc counts watching (gate_sequence_contains "measure").
	# In the wet country, repeated measurement is how a state is KEPT.
	_notify_quest_projection("measure", {"biome": biome_name, "success": result.get("success", false)})
	return result


func action_pop(grid_pos: Vector2i) -> Dictionary:
	var economy = _get_economy()
	if not farm or not terminal_pool or not economy:
		return {"success": false, "error": "no_farm", "message": "Farm not ready"}

	var terminal = _resolve_terminal_for_harvest(grid_pos)
	if not terminal:
		return {"success": false, "error": "no_terminal", "message": "No terminal at selection"}

	_detach_terminal_from_plot(terminal)
	var result = ProbeActions.action_pop(terminal, terminal_pool, economy, farm)
	_emit_farm_action("pop", result, grid_pos)
	action_performed.emit("pop", result)
	return result


func action_reap() -> Dictionary:
	var economy = _get_economy()
	if not farm or not economy:
		return {"success": false, "error": "no_farm", "message": "Farm not ready"}

	var result = ProbeActions.action_reap(farm, economy)
	_emit_farm_action("reap", result)
	action_performed.emit("reap", result)
	# Quest-visible: the Rite arc counts seasons reaped (gate_sequence_contains "reap").
	_notify_quest_projection("reap", {"rite_credits": result.get("rite_credits", 0), "success": result.get("success", false)})
	return result


func action_clear_all() -> Dictionary:
	if not farm or not terminal_pool:
		return {"success": false, "error": "no_farm", "message": "Farm not ready"}

	var result = ProbeActions.action_clear_all(terminal_pool, farm, _get_economy())
	_emit_farm_action("clear_all", result)
	action_performed.emit("clear_all", result)
	return result


# ============================================================================
# GROUP 3: GATE MODE ACTIONS
# ============================================================================

func action_build_gate(positions: Array[Vector2i]) -> Dictionary:
	if not farm:
		return {"success": false, "error": "no_farm", "message": "Farm not initialized"}

	if positions.size() == 2:
		var result = GateActionHandler.create_bell_pair(farm, positions)
		action_performed.emit("build_gate", result)
		return result
	elif positions.size() > 2:
		var result = GateActionHandler.cluster(farm, positions)
		action_performed.emit("build_gate", result)
		return result
	else:
		var result = {"success": false, "error": "need_more_plots", "message": "Select 2+ plots for gate"}
		action_performed.emit("build_gate", result)
		return result


func action_inspect(positions: Array[Vector2i]) -> Dictionary:
	return _cost_action("inspect", positions, func():
		var result = GateActionHandler.inspect_entanglement(farm, positions)
		action_performed.emit("inspect", result)
		return result
	)


func action_remove_gates(positions: Array[Vector2i]) -> Dictionary:
	return _cost_action("remove_gates", positions, func():
		var result = GateActionHandler.disentangle(farm, positions)
		action_performed.emit("remove_gates", result)
		return result
	)


# ============================================================================
# GROUP 4: META ACTIONS
# ============================================================================

func action_inject_icon(biome_name: String) -> Dictionary:
	if not farm:
		return {"success": false, "error": "no_farm", "message": "Farm not initialized"}

	var biome = _resolve_biome(biome_name)
	if not biome:
		return {"success": false, "error": "no_biome", "message": "No biome at selection"}

	var qubit_count = biome.get_total_register_count() if biome.has_method("get_total_register_count") else 0
	var max_qubits = _get_max_biome_qubits()
	if qubit_count >= max_qubits:
		return {
			"success": false,
			"error": "qubit_cap_reached",
			"message": "Biome is at max capacity (%d qubits)" % max_qubits
		}

	var candidate_icons = _collect_injectable_icons(farm, biome)
	var icon = _pick_injectable_icon(candidate_icons, biome)
	if icon.is_empty():
		return {"success": false, "error": "no_available_icon", "message": "No injectable icon for this biome"}
	return action_inject_icon_pair(biome_name, icon)


func action_inject_icon_pair(biome_name: String, icon: Dictionary) -> Dictionary:
	if not farm:
		return {"success": false, "error": "no_farm", "message": "Farm not initialized"}

	var biome = _resolve_biome(biome_name)
	if not biome:
		return {"success": false, "error": "no_biome", "message": "No biome at selection"}
	if not biome.viz_cache or not biome.viz_cache.has_metadata():
		return {"success": false, "error": "viz_unavailable", "message": "Biome visualization data not ready"}

	var north_emoji = str(icon.get("north", ""))
	var south_emoji = str(icon.get("south", ""))
	if north_emoji == "" or south_emoji == "" or north_emoji == south_emoji:
		return {"success": false, "error": "invalid_icon", "message": "Invalid icon"}
	if biome.viz_cache.get_qubit(north_emoji) >= 0:
		return {"success": false, "error": "already_in_biome", "message": "%s already in biome" % north_emoji}
	if biome.viz_cache.get_qubit(south_emoji) >= 0:
		return {"success": false, "error": "already_in_biome", "message": "%s already in biome" % south_emoji}

	var qubit_count = biome.get_total_register_count() if biome.has_method("get_total_register_count") else 0
	var max_qubits = _get_max_biome_qubits()
	if qubit_count >= max_qubits:
		return {
			"success": false,
			"error": "qubit_cap_reached",
			"message": "Biome is at max capacity (%d qubits)" % max_qubits
		}

	var context = {"south_emoji": south_emoji}
	var gate = preflight_action_cost("inject_icon", context)
	if not gate.get("ok", true):
		return {
			"success": false,
			"error": "insufficient_funds",
			"message": "Insufficient resources for icon injection (%s)" % [gate.get("cost", {})]
		}

	var result = biome.expand_quantum_system(north_emoji, south_emoji)
	if result.get("success", false):
		if not bool(commit_action_cost("inject_icon", context, "inject_icon").get("ok", false)):
			return {"success": false, "error": "cost_commit_failed", "message": "Icon injection failed: unable to spend cost."}
		if farm and farm.has_method("discover_icon"):
			farm.discover_icon(north_emoji, south_emoji)
		result["north_emoji"] = north_emoji
		result["south_emoji"] = south_emoji
		result["cost"] = gate.get("cost", {})

	action_performed.emit("inject_icon", result)
	return result


func action_remove_icon(biome_name: String, grid_pos: Vector2i) -> Dictionary:
	if not farm:
		return {"success": false, "error": "no_farm", "message": "Farm not initialized"}

	var biome = _resolve_biome(biome_name)
	if not biome or not biome.quantum_computer:
		return {"success": false, "error": "no_biome", "message": "No biome at selection"}

	var qc = biome.quantum_computer
	var rm = qc.register_map

	if rm.num_qubits < 2:
		return {"success": false, "error": "minimum_reached", "message": "Cannot remove last icon"}

	var target_qubit = rm.num_qubits - 1
	var icon_to_remove = {}
	var _icon_plot = farm.grid.get_plot(grid_pos) if farm and farm.grid else null
	var terminal = _icon_plot.terminal if _icon_plot else null
	var biome_type = BiomeBase.type_name(biome)
	if terminal and terminal.is_bound and terminal.bound_biome_name == biome_type:
		target_qubit = terminal.bound_register_id
	icon_to_remove = _get_icon_for_qubit(rm, target_qubit)

	var removal_context = {"north_emoji": icon_to_remove.get("north", ""), "south_emoji": icon_to_remove.get("south", "")}
	var cost_gate = preflight_action_cost("remove_icon", removal_context)
	if not cost_gate.get("ok", true):
		var cost = cost_gate.get("cost", {})
		return {
			"success": false,
			"error": "insufficient_resources",
			"message": "Need %d %s to remove signature." % [cost.values()[0], cost.keys()[0]] if not cost.is_empty() else "Insufficient resources"
		}

	if icon_to_remove.is_empty():
		return {"success": false, "error": "no_icon_found", "message": "Could not find icon to remove"}

	_unbind_terminals_for_register(biome, target_qubit)

	var result = _shrink_quantum_system(biome, target_qubit, icon_to_remove)

	if result.get("success", false):
		if not bool(commit_action_cost("remove_icon", removal_context, "remove_icon").get("ok", false)):
			return {"success": false, "error": "cost_commit_failed", "message": "Remove signature failed: unable to spend cost."}
		_reindex_bound_terminals(biome, target_qubit)
		_log("info", "instrument", "-", "Removed icon %s/%s from %s" % [
			icon_to_remove.get("north", "?"), icon_to_remove.get("south", "?"), biome_name
		])

	action_performed.emit("remove_icon", result)
	return result


func action_set_active_icon_slot(slot_idx: int, icon_idx: int) -> void:
	if not farm or not farm.has_method("set_active_icon_slot"):
		return
	farm.set_active_icon_slot(slot_idx, icon_idx)
	action_performed.emit("set_active_icon_slot", {"slot": slot_idx, "icon": icon_idx})


func action_discover_biome() -> Dictionary:
	if not farm:
		return {"success": false, "error": "no_farm", "message": "Farm not ready"}
	if not farm.has_method("discover_biome"):
		return {"success": false, "error": "no_method", "message": "Farm cannot discover biomes"}

	var result = farm.discover_biome()
	action_performed.emit("discover_biome", result)
	return result


func action_remove_biome() -> Dictionary:
	if not farm:
		return {"success": false, "error": "no_farm", "message": "Farm not ready"}
	if not farm.has_method("remove_biome"):
		return {"success": false, "error": "no_method", "message": "Farm cannot remove biomes"}

	var result = farm.remove_biome()
	action_performed.emit("remove_biome", result)
	return result


func action_cycle_biome() -> Dictionary:
	var active_biome_mgr = _get_autoload("ActiveBiomeManager")
	if not active_biome_mgr:
		return {"success": false, "error": "no_biome_manager", "message": "ActiveBiomeManager not available"}

	var old_biome = active_biome_mgr.get_active_biome()
	active_biome_mgr.cycle_next()
	var new_biome = active_biome_mgr.get_active_biome()

	var result = {"success": true, "old_biome": old_biome, "new_biome": new_biome}
	action_performed.emit("cycle_biome", result)
	return result


# ============================================================================
# QUEST API (shared by UI + rig adapters)
# ============================================================================

func quest_offer_all() -> Dictionary:
	var qm = _resolve_quest_manager()
	if not qm or not qm.has_method("offer_all_faction_quests"):
		return {"ok": false, "error": "no_quest_manager"}
	var biome = _resolve_current_biome_for_quests()
	if not biome:
		return {"ok": false, "error": "no_current_biome"}
	var offers = qm.offer_all_faction_quests(biome)
	var biome_name = str(biome.biome_name) if biome and "biome_name" in biome else ""
	var result = {
		"ok": true,
		"offers": offers if offers is Array else [],
		"biome": biome_name
	}
	action_performed.emit("offer_quests", result)
	_notify_quest_projection("offer_quests", {"count": result["offers"].size(), "biome": biome_name})
	return result


func quest_accept(quest_data: Dictionary) -> Dictionary:
	var qm = _resolve_quest_manager()
	if not qm or not qm.has_method("accept_quest"):
		return {"ok": false, "accepted": false, "error": "accept_unavailable"}
	var accepted = qm.accept_quest(quest_data)
	var quest_id = int(quest_data.get("id", -1))
	var result = {"ok": accepted, "accepted": accepted, "quest_id": quest_id}
	action_performed.emit("accept_quest", result)
	if accepted:
		_notify_quest_projection("accept_quest", {"quest_id": quest_id})
	return result


func quest_accept_by_id(quest_id: int) -> Dictionary:
	var qm = _resolve_quest_manager()
	if not qm:
		return {"ok": false, "accepted": false, "error": "no_quest_manager", "quest_id": quest_id}
	var quest: Dictionary = {}
	if qm.has_method("get_quest_by_id"):
		quest = qm.get_quest_by_id(quest_id)
	if quest.is_empty():
		var offer_result = quest_offer_all()
		if bool(offer_result.get("ok", false)):
			var offers = offer_result.get("offers", [])
			if offers is Array:
				for offer in offers:
					if offer is Dictionary and int(offer.get("id", -1)) == quest_id:
						quest = offer
						break
	if quest.is_empty():
		return {"ok": false, "accepted": false, "error": "quest_not_found", "quest_id": quest_id}
	return quest_accept(quest)


func quest_complete(quest_id: int) -> Dictionary:
	var qm = _resolve_quest_manager()
	if not qm or not qm.has_method("complete_quest"):
		return {"ok": false, "completed": false, "error": "complete_unavailable", "quest_id": quest_id}
	var completed = qm.complete_quest(quest_id)
	var result = {"ok": completed, "completed": completed, "quest_id": quest_id}
	if completed and qm.completed_quests:
		var last: Dictionary = qm.completed_quests.back()
		result["rewards"] = last.get("reward_payload", {})
	action_performed.emit("complete_quest", result)
	if completed:
		_notify_quest_projection("complete_quest", {"quest_id": quest_id})
	return result


func quest_complete_or_claim(quest_id: int) -> Dictionary:
	var qm = _resolve_quest_manager()
	if not qm or not qm.has_method("complete_or_claim"):
		return {"ok": false, "completed_or_claimed": false, "error": "complete_or_claim_unavailable", "quest_id": quest_id}
	var completed_or_claimed = qm.complete_or_claim(quest_id)
	var result = {
		"ok": completed_or_claimed,
		"completed_or_claimed": completed_or_claimed,
		"quest_id": quest_id
	}
	action_performed.emit("complete_or_claim", result)
	if completed_or_claimed:
		_notify_quest_projection("complete_or_claim", {"quest_id": quest_id})
	return result


func quest_claim(quest_id: int) -> Dictionary:
	var qm = _resolve_quest_manager()
	if not qm or not qm.has_method("claim_quest"):
		return {"ok": false, "claimed": false, "error": "claim_unavailable", "quest_id": quest_id}
	var claimed = qm.claim_quest(quest_id)
	var result = {"ok": claimed, "claimed": claimed, "quest_id": quest_id}
	action_performed.emit("claim_quest", result)
	if claimed:
		_notify_quest_projection("claim_quest", {"quest_id": quest_id})
	return result


func get_action_cost(action_name: String, context: Dictionary = {}) -> Dictionary:
	# Get effective action cost, honoring economy overrides.
	return ActionCostRuntime.get_action_cost(farm, EconomyConstants.normalize_action_id(action_name), context)


func preflight_action_cost(action_name: String, context: Dictionary = {}) -> Dictionary:
	# Check affordability for an action cost (no spend).
	return ActionCostRuntime.preflight_action(farm, action_name, context)


func can_afford_cost(cost: Dictionary) -> Dictionary:
	# Check affordability for an arbitrary cost dictionary (no spend).
	var gate = ActionCostRuntime.preflight_cost(farm, cost)
	if bool(gate.get("ok", false)):
		return gate
	if not gate.has("cost"):
		gate["cost"] = cost
	return gate


func get_resource_snapshot() -> Dictionary:
	var economy = _get_economy()
	if not economy:
		return {"resources": {}, "ordered": []}
	var resources: Dictionary = {}
	if economy.has_method("get_all_resources"):
		resources = economy.get_all_resources()
	else:
		resources = economy.emoji_credits.duplicate(true) if "emoji_credits" in economy else {}
	var ordered: Array = resources.keys()
	ordered.sort()
	return {"resources": resources, "ordered": ordered}


func add_resource(emoji: String, credits_amount: int, reason: String = "rig_add") -> Dictionary:
	var economy = _get_economy()
	if not economy:
		return {"ok": false, "error": "no_economy"}
	if not economy.has_method("add_resource"):
		return {"ok": false, "error": "add_resource_unavailable"}
	economy.add_resource(emoji, credits_amount, reason)
	return {"ok": true, "emoji": emoji, "amount": credits_amount}


func set_resource(emoji: String, credits_amount: int, reason: String = "rig_set") -> Dictionary:
	var economy = _get_economy()
	if not economy:
		return {"ok": false, "error": "no_economy"}
	if not economy.has_method("set_resource"):
		return {"ok": false, "error": "set_resource_unavailable"}
	economy.set_resource(emoji, credits_amount, reason)
	return {"ok": true, "emoji": emoji, "amount": credits_amount}


func get_recent_resource_mutations(limit: int = 40) -> Array:
	var economy = _get_economy()
	if not economy:
		return []
	if economy.has_method("get_recent_resource_mutations"):
		return economy.get_recent_resource_mutations(limit)
	return []


func commit_action_cost(action_name: String, context: Dictionary = {}, reason: String = "") -> Dictionary:
	# Commit spend for an action via the unified economy action API.
	var economy = _get_economy()
	if not economy:
		return {"ok": false, "error": "no_economy"}
	var spend_reason = reason if reason != "" else action_name
	var ok = ActionCostRuntime.commit_action(economy, action_name, context, spend_reason)
	return {
		"ok": ok,
		"action": EconomyConstants.normalize_action_id(action_name),
		"cost": get_action_cost(action_name, context),
		"reason": spend_reason
	}


func configure_economy(overrides: Dictionary) -> Dictionary:
	if not farm:
		return {"ok": false, "error": "no_farm"}
	if not (overrides is Dictionary) or overrides.is_empty():
		return {"ok": false, "error": "empty_overrides"}
	return BalanceService.apply_patch(farm, overrides, "instrument.configure_economy")


func get_balance_snapshot() -> Dictionary:
	if not farm:
		return {"ok": false, "error": "no_farm"}
	var snapshot = BalanceService.get_snapshot(farm)
	snapshot["ok"] = true
	return snapshot


func patch_balance(patch: Dictionary, source: String = "instrument.patch_balance") -> Dictionary:
	if not farm:
		return {"ok": false, "error": "no_farm"}
	if not (patch is Dictionary) or patch.is_empty():
		return {"ok": false, "error": "empty_patch"}
	return BalanceService.apply_patch(farm, patch, source)


func reset_balance_to_default() -> Dictionary:
	if not farm:
		return {"ok": false, "error": "no_farm"}
	return BalanceService.reset_to_default(farm)


func export_balance_profile(path: String = "user://saves/balance_profile_last.json") -> Dictionary:
	if not farm:
		return {"ok": false, "error": "no_farm"}
	var snapshot = BalanceService.get_snapshot(farm)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return {"ok": false, "error": "file_open_failed", "path": path}
	file.store_string(JSON.stringify(snapshot, "\t"))
	return {"ok": true, "path": path}


func load_balance_profile(path: String) -> Dictionary:
	if not farm:
		return {"ok": false, "error": "no_farm"}
	if path == "":
		return {"ok": false, "error": "empty_path"}
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "missing_file", "path": path}
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {"ok": false, "error": "file_open_failed", "path": path}
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {"ok": false, "error": "invalid_json", "path": path}
	var patch = {
		"profile_id": parsed.get("profile_id", "default"),
		"action_costs": parsed.get("action_costs", {}),
		"gate_costs": parsed.get("gate_costs", {}),
		"quest_rewards": parsed.get("quest_rewards", {}),
	}
	return BalanceService.apply_patch(farm, patch, "instrument.load_balance_profile")


func get_farm_variable_graph() -> Dictionary:
	if not farm:
		return {"ok": false, "error": "no_farm"}
	return BalanceService.get_farm_variable_graph(farm)


func apply_farm_variable_graph(lines: Array, source: String = "instrument.apply_farm_variable_graph") -> Dictionary:
	if not farm:
		return {"ok": false, "error": "no_farm"}
	return BalanceService.apply_farm_variable_graph(farm, lines, source)


func load_farm_variable_graph_file(path: String) -> Dictionary:
	if not farm:
		return {"ok": false, "error": "no_farm"}
	if path == "":
		return {"ok": false, "error": "empty_path"}
	return BalanceService.load_farm_variable_graph_file(farm, path, "instrument.load_farm_variable_graph_file")


func get_policy_snapshot(include_offers: bool = true, include_grid: bool = true) -> Dictionary:
	# Aggregate policy-facing reads into one payload for rig/runner loops.
	var resource_snapshot = get_resource_snapshot()
	var resources = resource_snapshot.get("resources", {}) if resource_snapshot is Dictionary else {}
	if not (resources is Dictionary):
		resources = {}

	var known_icons = get_known_icons()
	if not (known_icons is Array):
		known_icons = []

	var active_quests = get_active_quests()
	if not (active_quests is Array):
		active_quests = []

	var story_offers = get_story_offers()
	if not (story_offers is Array):
		story_offers = []

	var offers: Array = []
	if include_offers:
		var raw_offers = get_quest_offers_for_current_biome()
		if raw_offers is Array:
			offers = raw_offers

	var grid_snapshot: Dictionary = {}
	if include_grid:
		var raw_grid = get_grid_snapshot()
		if raw_grid is Dictionary:
			grid_snapshot = raw_grid

	var biomes: Array = []
	var raw_biomes = grid_snapshot.get("biomes", []) if grid_snapshot is Dictionary else []
	if raw_biomes is Array:
		for biome_name in raw_biomes:
			var name = str(biome_name)
			if name != "":
				biomes.append(name)

	return {
		"resources": resources,
		"resource_snapshot": resource_snapshot if resource_snapshot is Dictionary else {},
		"known_icons": known_icons,
		"offers": offers,
		"active_quests": active_quests,
		"story_offers": story_offers,
		"grid": grid_snapshot,
		"biomes": biomes,
	}


func get_active_quests() -> Array:
	var qm = _resolve_quest_manager()
	if qm and qm.has_method("get_active_quests"):
		return qm.get_active_quests()
	return []


func get_known_icons() -> Array:
	if farm and farm.has_method("get_known_icons"):
		return farm.get_known_icons()
	return []


func get_quest_offers_for_current_biome() -> Array:
	var offer_result = quest_offer_all()
	if offer_result is Dictionary and bool(offer_result.get("ok", false)):
		var offers = offer_result.get("offers", [])
		if offers is Array:
			return offers
	return []


func get_story_offers() -> Array:
	var qm = _resolve_quest_manager()
	if qm and qm.has_method("get_story_offers"):
		var offers = qm.get_story_offers()
		if offers is Array:
			return offers
	return []


func get_biome_positions(biome_name: String) -> Array:
	if not farm or not ("grid" in farm) or not farm.grid:
		return []
	return farm.grid.get_plot_positions_for_biome(biome_name)


func get_grid_snapshot() -> Dictionary:
	if not farm or not ("grid" in farm) or not farm.grid:
		return {"ok": false, "error": "no_grid"}
	var grid = farm.grid
	var snapshot: Dictionary = {"ok": true}
	if "grid_width" in grid:
		snapshot["grid_width"] = grid.grid_width
	if "grid_height" in grid:
		snapshot["grid_height"] = grid.grid_height
	if grid.has_biomes():
		var biome_names = grid.get_biome_names()
		biome_names.sort()
		snapshot["biomes"] = biome_names
	if snapshot.has("grid_width") and snapshot.has("grid_height"):
		snapshot["plot_count"] = int(snapshot["grid_width"]) * int(snapshot["grid_height"])
	return snapshot


# ============================================================================
# GATE DISPATCH API (moved from snapshot bridge)
# ============================================================================

func gate_inject(gate_name: String, positions: Array[Vector2i]) -> Dictionary:
	if not farm:
		return {"ok": false, "error": "no_farm"}
	if not _GATE_DISPATCH.has(gate_name):
		return {"ok": false, "error": "unknown_gate", "gate": gate_name, "available": _GATE_DISPATCH.keys()}
	var gate_callable = _GATE_DISPATCH[gate_name] as Callable
	if gate_callable == null or not gate_callable.is_valid():
		return {"ok": false, "error": "invalid_gate_dispatch", "gate": gate_name}
	var cost_check = preflight_action_cost(gate_name)
	if not cost_check.get("ok", true):
		return {"ok": false, "success": false, "error": "insufficient_resources", "message": cost_check.get("message", "Cannot afford %s" % gate_name), "cost": cost_check.get("cost", {})}
	var result = gate_callable.call(farm, positions)
	result["gate"] = gate_name
	action_performed.emit("gate_inject", result)
	_notify_quest_projection("gate_inject:%s" % gate_name, result)
	if result.get("success", false) or result.get("ok", false):
		commit_action_cost(gate_name, {}, gate_name)
	return result


func lindblad_pump(positions: Array[Vector2i]) -> Dictionary:
	if not farm:
		return {"ok": false, "error": "no_farm"}
	# Rig/API pump — same semantics and same per-plot regime gating as the
	# player's action_pump: the handler refuses sealed ground plot by plot.
	var result = LindbladHandler.enable_persistent_drive(farm, positions)
	action_performed.emit("lindblad_pump", result)
	_notify_quest_projection("lindblad_pump", result)
	return result


func lindblad_drain(positions: Array[Vector2i]) -> Dictionary:
	if not farm:
		return {"ok": false, "error": "no_farm"}
	# Rig/API drain — mirrors action_drain; per-plot regime gating in the handler.
	var result = LindbladHandler.enable_persistent_decay(farm, positions)
	action_performed.emit("lindblad_drain", result)
	_notify_quest_projection("lindblad_drain", result)
	return result


func time_skip(phrames: int, delta: float = -1.0) -> Dictionary:
	if not farm:
		return {"ok": false, "error": "no_farm"}
	if not farm.has_method("time_skip_phrames"):
		return {"ok": false, "error": "farm_time_skip_unavailable"}
	var dt = delta if delta > 0.0 else PhysicsConfig.PHRAME_DT
	var result = farm.time_skip_phrames(phrames, dt)
	action_performed.emit("time_skip", result)
	_notify_quest_projection("time_skip", result)
	return result


# ============================================================================
# COMPOUND ACTIONS (unified from MilkHunterBridge + rig_listener)
# ============================================================================

func probe_cycle(biome_name: String) -> Dictionary:
	if not farm or not terminal_pool:
		return {"success": false, "error": "no_terminal_pool"}
	var economy = _get_economy()
	if not farm.grid or not farm.grid.has_biomes():
		return {"success": false, "error": "no_biomes"}
	var biome = farm.grid.get_biome(biome_name)
	if not biome:
		return {"success": false, "error": "unknown_biome"}

	_notify_autoload("ActiveBiomeManager", "set_active_biome", [biome_name])
	_notify_autoload("ObservationFrame", "set_neutral_biome", [biome_name])

	var explore = ProbeActions.action_explore(terminal_pool, biome, economy)
	if not explore.get("success", false):
		var explore_fail = {"success": false, "stage": "explore", "details": explore}
		return explore_fail
	var terminal = explore.get("terminal", null)
	if terminal:
		var reg = int(explore.get("register_id", -1))
		if reg >= 0:
			terminal.grid_position = _derive_grid_position_for_register(biome_name, reg)
	_attach_terminal_to_plot(terminal)
	# Emit explore signal so bubbles appear during bot runs
	_emit_farm_action("explore", explore)

	var measure = ProbeActions.action_measure(terminal, biome, economy, farm)
	if not measure.get("success", false):
		var measure_fail = {"success": false, "stage": "measure", "details": measure}
		return measure_fail
	_emit_farm_action("measure", measure)

	_detach_terminal_from_plot(terminal)
	var pop = ProbeActions.action_pop(terminal, terminal_pool, economy, farm)
	_emit_farm_action("pop", pop)

	var probe_result = {"success": true, "explore": explore, "measure": measure, "pop": pop, "active_biome": biome_name}
	_notify_quest_projection("probe_cycle", probe_result)
	return probe_result


func victory_lap() -> Dictionary:
	if not farm or not farm.grid or not farm.grid.has_biomes():
		return {"success": false, "error": "no_farm_or_biomes"}
	if not terminal_pool:
		return {"success": false, "error": "no_terminal_pool"}
	var economy = _get_economy()

	var biomes: Array[String] = []
	for biome_name in farm.grid.get_biome_names():
		if biome_name is String and str(biome_name) != "":
			biomes.append(str(biome_name))
	biomes.sort()

	var explore_total = 0
	var explore_failures: Array = []

	for biome_name in biomes:
		var biome = farm.grid.get_biome(biome_name)
		if not biome:
			continue
		while true:
			var explore = ProbeActions.action_explore(terminal_pool, biome, economy)
			if explore.get("success", false):
				explore_total += 1
				var t = explore.get("terminal", null)
				if t:
					var reg = int(explore.get("register_id", -1))
					if reg >= 0:
						t.grid_position = _derive_grid_position_for_register(biome_name, reg)
				_attach_terminal_to_plot(t)
				_emit_farm_action("explore", explore)
				continue
			var reason = str(explore.get("error", "unknown"))
			if reason == "no_registers":
				break
			explore_failures.append({"biome": biome_name, "error": reason, "details": explore})
			if reason == "no_terminals":
				break
			break
		if terminal_pool.get_unbound_count() <= 0:
			break

	var measure_total = 0
	var measure_failures: Array = []
	var active_terminals: Array = terminal_pool.get_active_terminals().duplicate()
	for terminal in active_terminals:
		if not terminal or not terminal.is_bound:
			continue
		var t_biome_name = str(terminal.bound_biome_name)
		var biome = farm.grid.get_biome(t_biome_name)
		if not biome:
			measure_failures.append({"terminal": terminal.terminal_id, "error": "unknown_biome", "biome": t_biome_name})
			continue
		var measure = ProbeActions.action_measure(terminal, biome, economy, farm)
		if measure.get("success", false):
			measure_total += 1
			_emit_farm_action("measure", measure)
		else:
			measure_failures.append({
				"terminal": terminal.terminal_id,
				"biome": t_biome_name,
				"error": str(measure.get("error", "unknown")),
				"details": measure
			})

	var harvest_total = 0
	var harvest_failures: Array = []
	var measured_terminals: Array = terminal_pool.get_measured_terminals().duplicate()
	for terminal in measured_terminals:
		if not terminal:
			continue
		_detach_terminal_from_plot(terminal)
		var pop = ProbeActions.action_pop(terminal, terminal_pool, economy, farm)
		if pop.get("success", false):
			harvest_total += 1
			_emit_farm_action("pop", pop)
		else:
			harvest_failures.append({
				"terminal": terminal.terminal_id,
				"error": str(pop.get("error", "unknown")),
				"details": pop
			})

	var milk_amount = 0.0
	if economy and economy.has_method("get_resource"):
		milk_amount = float(economy.get_resource("\ud83c\udf7c"))

	var result = {
		"success": true,
		"biomes": biomes,
		"explore_total": explore_total,
		"explore_failures": explore_failures,
		"measure_total": measure_total,
		"measure_failures": measure_failures,
		"harvest_total": harvest_total,
		"harvest_failures": harvest_failures,
		"milk_after": milk_amount
	}
	_notify_quest_projection("victory_lap", result)
	return result


func victory_lap_partial(selected_biomes: Array[String] = [], max_registers: int = 8, _milk_spend: int = 0, _phase_window: int = 1) -> Dictionary:
	if not farm or not farm.grid or not farm.grid.has_biomes():
		return {"success": false, "error": "no_farm_or_biomes"}
	if not terminal_pool:
		return {"success": false, "error": "no_terminal_pool"}
	var economy = _get_economy()

	var biomes: Array[String] = []
	if selected_biomes.is_empty():
		for biome_name in farm.grid.get_biome_names():
			if biome_name is String and str(biome_name) != "":
				biomes.append(str(biome_name))
		biomes.sort()
	else:
		biomes = selected_biomes.duplicate()

	# Explore one terminal per biome if there's capacity
	for biome_name in biomes:
		if terminal_pool.get_unbound_count() <= 0:
			break
		var biome = farm.grid.get_biome(biome_name)
		if not biome:
			continue
		var explore = ProbeActions.action_explore(terminal_pool, biome, economy)
		if explore.get("success", false):
			var t = explore.get("terminal", null)
			if t:
				var reg = int(explore.get("register_id", -1))
				if reg >= 0:
					t.grid_position = _derive_grid_position_for_register(biome_name, reg)
				_attach_terminal_to_plot(t)
				_emit_farm_action("explore", explore)

	var popped_total = 0
	var pop_failures: Array = []
	var active_terminals: Array = terminal_pool.get_active_terminals().duplicate()
	for terminal in active_terminals:
		if popped_total >= max_registers:
			break
		if not terminal or not terminal.is_bound:
			continue
		var t_biome = str(terminal.bound_biome_name)
		if not biomes.is_empty() and t_biome not in biomes:
			continue
		var biome = farm.grid.get_biome(t_biome)
		if not biome:
			continue
		if not bool(terminal.is_measured):
			var measure = ProbeActions.action_measure(terminal, biome, economy, farm)
			if not measure.get("success", false):
				pop_failures.append({"biome": t_biome, "error": "measure_failed"})
				continue
			_emit_farm_action("measure", measure)
		_detach_terminal_from_plot(terminal)
		var pop = ProbeActions.action_pop(terminal, terminal_pool, economy, farm)
		if pop.get("success", false):
			popped_total += 1
			_emit_farm_action("pop", pop)
		else:
			pop_failures.append({"biome": t_biome, "error": str(pop.get("error", "unknown"))})

	var milk_amount = 0.0
	if economy and economy.has_method("get_resource"):
		milk_amount = float(economy.get_resource("\ud83c\udf7c"))

	var result = {
		"success": true,
		"selected_biomes": biomes,
		"max_registers": max_registers,
		"popped_total": popped_total,
		"pop_failures": pop_failures,
		"milk_after": milk_amount,
	}
	_notify_quest_projection("victory_lap_partial", result)
	return result


func configure_seed_state(cmd: Dictionary) -> Dictionary:
	var out: Dictionary = {"ok": true}
	var gsm = _get_autoload("GameStateManager")
	if not gsm or not gsm.current_state:
		return {"ok": false, "error": "no_game_state"}

	# Clear all quests before applying seed state — prevents pending story offers
	# from previous runs (loaded via save slot) from polluting a fresh character seed.
	if cmd.get("clear_quests", false):
		var qm = _resolve_quest_manager()
		if qm and qm.has_method("clear_all_quests"):
			qm.clear_all_quests()
			out["quests_cleared"] = true

	var known_icons = _sanitize_known_icons(cmd.get("known_icons", []))
	if not known_icons.is_empty():
		if farm and farm.has_method("set_known_icons"):
			farm.set_known_icons(known_icons)
		gsm.current_state.known_icons = known_icons.duplicate(true)
		out["known_icons"] = known_icons

	var unlocked_biomes = _sanitize_biomes(cmd.get("unlocked_biomes", []))
	if not unlocked_biomes.is_empty():
		gsm.current_state.unlocked_biomes = unlocked_biomes.duplicate()
		if unlocked_biomes.size() > 0 and str(gsm.current_state.active_biome_name) == "":
			gsm.current_state.active_biome_name = str(unlocked_biomes[0])
		out["unlocked_biomes"] = unlocked_biomes
		var default_pool: Array[String] = []
		var obs = _get_autoload("ObservationFrame")
		if obs and obs.has_method("get_loadable_biomes"):
			default_pool = obs.get_loadable_biomes()
		var pool: Array[String] = []
		for biome_name in default_pool:
			if biome_name not in unlocked_biomes:
				pool.append(biome_name)
		gsm.current_state.unexplored_biome_pool = pool
		_notify_autoload("ActiveBiomeManager", "set_biome_order", [unlocked_biomes])

	var unexplored_biomes = _sanitize_biomes(cmd.get("unexplored_biomes", []))
	if not unexplored_biomes.is_empty():
		gsm.current_state.unexplored_biome_pool = unexplored_biomes.duplicate()
		out["unexplored_biomes"] = unexplored_biomes

	var active_biome = str(cmd.get("active_biome", ""))
	if active_biome != "":
		gsm.current_state.active_biome_name = active_biome
		_notify_autoload("ObservationFrame", "set_neutral_biome", [active_biome])
		_notify_autoload("ActiveBiomeManager", "set_active_biome", [active_biome])
		out["active_biome"] = active_biome

	var policy_graph_path = str(cmd.get("policy_graph_path", ""))
	if policy_graph_path != "":
		gsm.current_state.policy_graph_path = policy_graph_path
		out["policy_graph_path"] = policy_graph_path

	var policy_graph_jsonl = cmd.get("policy_graph_jsonl", [])
	if policy_graph_jsonl is Array:
		var typed_lines: Array[String] = []
		for raw_line in policy_graph_jsonl:
			var line = str(raw_line).strip_edges()
			if line != "":
				typed_lines.append(line)
		gsm.current_state.policy_graph_jsonl = typed_lines
		if not typed_lines.is_empty():
			out["policy_graph_jsonl"] = typed_lines

	return out


# ============================================================================
# PRIVATE HELPERS
# ============================================================================

func _emit_farm_action(action: String, result: Dictionary, pos: Vector2i = GridSentinel.INVALID_POSITION) -> void:
	if farm and farm.has_method("emit_action_signal"):
		farm.emit_action_signal(action, result, pos)


func _derive_grid_position_for_register(biome_name: String, register_id: int) -> Vector2i:
	# Under plot_idx ≡ register_id, a register's canonical grid position is
	# (register_id, biome_row). Returns INVALID_POSITION when the biome row
	# lookup fails.
	if not farm or register_id < 0:
		return GridSentinel.INVALID_POSITION
	if not farm.has_method("get_biome_row"):
		return GridSentinel.INVALID_POSITION
	var row = int(farm.get_biome_row(biome_name))
	if row < 0:
		return GridSentinel.INVALID_POSITION
	return Vector2i(register_id, row)


func _attach_terminal_to_plot(t) -> void:
	if t and t.grid_position != GridSentinel.INVALID_POSITION and farm and farm.grid:
		var plot = farm.grid.get_plot(t.grid_position)
		if plot:
			if plot.has_method("clear_measurement_memory"):
				plot.clear_measurement_memory()
			plot.terminal = t


func _detach_terminal_from_plot(t) -> void:
	if t and t.grid_position != GridSentinel.INVALID_POSITION and farm and farm.grid:
		var plot = farm.grid.get_plot(t.grid_position)
		if plot:
			plot.terminal = null


func _notify_autoload(node_name: String, method: String, args: Array) -> void:
	var node = _get_autoload(node_name)
	if node and node.has_method(method):
		node.callv(method, args)


func _resolve_quest_manager():
	var qm = InstrumentLocator.resolve_quest_manager(_get_scope_node(), farm)
	if qm:
		return qm
	var gsm = _get_autoload("GameStateManager")
	var active_farm = gsm.get_active_farm() if gsm and gsm.has_method("get_active_farm") else null
	if active_farm and "quest_manager" in active_farm:
		return active_farm.quest_manager
	return null


func _get_scope_node() -> Node:
	if farm:
		return farm
	var tree = Engine.get_main_loop()
	if tree and tree is SceneTree:
		return tree.root
	return null


func _notify_quest_projection(action_name: String, payload: Dictionary) -> void:
	var qm = _resolve_quest_manager()
	if not qm:
		return
	if qm.has_method("record_quantum_action"):
		qm.record_quantum_action(action_name, payload)


func _resolve_current_biome_for_quests():
	if farm and farm.has_method("get_current_biome"):
		var current_biome_node = farm.get_current_biome()
		if current_biome_node:
			return current_biome_node
	var biome_name = str(current_biome)
	if biome_name == "":
		var active_biome_mgr = _get_autoload("ActiveBiomeManager")
		if active_biome_mgr and active_biome_mgr.has_method("get_active_biome"):
			biome_name = str(active_biome_mgr.get_active_biome())
	if biome_name == "":
		var obs = _get_autoload("ObservationFrame")
		if obs and obs.has_method("get_neutral_biome"):
			biome_name = str(obs.get_neutral_biome())
	if farm and farm.grid and farm.grid.has_biomes():
		if biome_name != "" and farm.grid.has_biome(biome_name):
			return farm.grid.get_biome(biome_name)
		return farm.grid.get_primary_biome()
	return null


# ============================================================================
# TIMESCALE CONTROLS (two-axis: stride + resolution)
# ============================================================================

func set_observation_stride(biome_name: String, stride: int) -> Dictionary:
	# Set observation stride for a biome. 0=locked, 1=normal, 2+=fast forward.
	var biome = _resolve_biome(biome_name)
	if not biome:
		return {"ok": false, "error": "unknown_biome", "biome": biome_name}
	var clamped = clampi(stride, GranularityController.MIN_STRIDE, GranularityController.MAX_STRIDE)
	var old_stride = _biome_stride(biome)
	biome.observation_stride = clamped
	var batcher = farm.biome_evolution_batcher if farm and "biome_evolution_batcher" in farm else null
	if batcher:
		batcher.reset_stride_carry(biome_name)
	var result = {"ok": true, "biome": biome_name, "old_stride": old_stride, "new_stride": clamped, "locked": clamped == 0}
	action_performed.emit("set_observation_stride", result)
	return result


func set_resolution(biome_name: String, dt: float) -> Dictionary:
	# Set evolution resolution (max_evolution_dt) for a biome.
	var biome = _resolve_biome(biome_name)
	if not biome:
		return {"ok": false, "error": "unknown_biome", "biome": biome_name}
	var clamped = clampf(dt, GranularityController.MIN_DT, GranularityController.MAX_DT)
	var old_dt = _biome_dt(biome)
	biome.max_evolution_dt = clamped
	var batcher = farm.biome_evolution_batcher if farm and "biome_evolution_batcher" in farm else null
	if batcher:
		batcher.reset_stride_carry(biome_name)
	var result = {"ok": true, "biome": biome_name, "old_dt": old_dt, "new_dt": clamped}
	action_performed.emit("set_resolution", result)
	return result


func get_timescale_snapshot(biome_name: String) -> Dictionary:
	# Get current timescale state for a biome: stride, dt, locked status.
	var biome = _resolve_biome(biome_name)
	if not biome:
		return {"ok": false, "error": "unknown_biome", "biome": biome_name}
	var stride = _biome_stride(biome)
	var dt = _biome_dt(biome)
	return {"ok": true, "biome": biome_name, "stride": stride, "dt": dt, "locked": stride == 0}


func set_timescale_objective(objective: Dictionary) -> Dictionary:
	var out = DEFAULT_TIMESCALE_OBJECTIVE.duplicate(true)
	if not objective.is_empty():
		var focus: Array[String] = []
		var seen: Dictionary = {}
		var raw_focus = objective.get("focus_emojis", [])
		if raw_focus is Array:
			for emoji in raw_focus:
				var s = str(emoji)
				if s == "" or seen.has(s):
					continue
				seen[s] = true
				focus.append(s)
		out["focus_emojis"] = focus
		var floors: Dictionary = out.get("resource_floors", {}).duplicate(true)
		var raw_floors = objective.get("resource_floors", {})
		if raw_floors is Dictionary:
			for emoji in raw_floors.keys():
				var s = str(emoji)
				if s == "":
					continue
				floors[s] = max(0.0, float(raw_floors[emoji]))
		out["resource_floors"] = floors
		out["top_k"] = clampi(int(objective.get("top_k", out.get("top_k", 8))), 1, 32)
		out["target_gain_per_wait"] = clampf(float(objective.get("target_gain_per_wait", out.get("target_gain_per_wait", 1.0))), 0.05, 100.0)
		out["horizon_min_phrames"] = max(1, int(objective.get("horizon_min_phrames", out.get("horizon_min_phrames", 6))))
		out["horizon_max_phrames"] = max(out["horizon_min_phrames"], int(objective.get("horizon_max_phrames", out.get("horizon_max_phrames", 72))))
	_timescale_objective = out
	var result = {"ok": true, "objective": _timescale_objective.duplicate(true)}
	action_performed.emit("set_timescale_objective", result)
	return result


func get_timescale_objective() -> Dictionary:
	return {"ok": true, "objective": _timescale_objective.duplicate(true)}


func clear_timescale_objective() -> Dictionary:
	_timescale_objective = DEFAULT_TIMESCALE_OBJECTIVE.duplicate(true)
	var result = {"ok": true, "objective": _timescale_objective.duplicate(true)}
	action_performed.emit("clear_timescale_objective", result)
	return result


func set_biome_stride(biome_name: String, stride: int) -> Dictionary:
	return set_observation_stride(biome_name, stride)


func set_biome_resolution(biome_name: String, dt: float) -> Dictionary:
	return set_resolution(biome_name, dt)


func get_biome_timescale(biome_name: String) -> Dictionary:
	return get_timescale_snapshot(biome_name)


func get_timescale_projection(biome_name: String, top_k: int = -1) -> Dictionary:
	var timescale = get_timescale_snapshot(biome_name)
	if not bool(timescale.get("ok", false)):
		return timescale

	var payload: Dictionary = {}
	if farm and "biome_evolution_batcher" in farm and farm.biome_evolution_batcher:
		var batcher = farm.biome_evolution_batcher
		payload = batcher.get_biome_probability_map(biome_name)
	var weights = _extract_emoji_weights(payload)
	var ranked: Array = []
	var floors: Dictionary = _timescale_objective.get("resource_floors", {})
	for emoji in weights.keys():
		var w = float(weights[emoji])
		var floor_target = float(floors.get(emoji, 0.0))
		var have = _get_resource_amount(farm, emoji)
		var deficit = max(0.0, floor_target - have)
		var score = w + deficit
		ranked.append({
			"emoji": str(emoji),
			"weight": w,
			"have": have,
			"floor": floor_target,
			"deficit": deficit,
			"score": score,
		})
	ranked.sort_custom(func(a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	var limit = top_k if top_k > 0 else int(_timescale_objective.get("top_k", 8))
	limit = clampi(limit, 1, 64)
	var projected: Array = []
	for i in range(min(limit, ranked.size())):
		projected.append(ranked[i])
	return {
		"ok": true,
		"biome": biome_name,
		"timescale": timescale,
		"objective": _timescale_objective.duplicate(true),
		"ranked": projected,
		"count": projected.size(),
	}


func recommend_timescale(biome_name: String, top_k: int = -1) -> Dictionary:
	var projection = get_timescale_projection(biome_name, top_k)
	if not bool(projection.get("ok", false)):
		return projection
	var timescale = projection.get("timescale", {})
	var current_stride = int(timescale.get("stride", 1))
	var current_dt = float(timescale.get("dt", 0.02))
	var ranked: Array = projection.get("ranked", [])
	var mean_score = 0.0
	for row in ranked:
		mean_score += float(row.get("score", 0.0))
	if not ranked.is_empty():
		mean_score /= float(ranked.size())
	var recommended_stride = clampi(int(round(clampf(2.0 - mean_score, 1.0, 16.0))), 1, 16)
	var recommended_dt = clampf(current_dt * (1.0 + min(1.0, mean_score) * 0.5), GranularityController.MIN_DT, GranularityController.MAX_DT)
	var horizon_min = int(_timescale_objective.get("horizon_min_phrames", 6))
	var horizon_max = int(_timescale_objective.get("horizon_max_phrames", 72))
	var recommended_wait = clampi(int(round(float(horizon_min) * float(recommended_stride))), horizon_min, horizon_max)
	return {
		"ok": true,
		"biome": biome_name,
		"current_stride": current_stride,
		"current_dt": current_dt,
		"recommended_stride": recommended_stride,
		"recommended_dt": recommended_dt,
		"recommended_wait_phrames": recommended_wait,
		"projection": projection,
	}


func auto_apply_timescale(biome_name: String, top_k: int = -1) -> Dictionary:
	var rec = recommend_timescale(biome_name, top_k)
	if not bool(rec.get("ok", false)):
		return rec
	var stride_result = set_observation_stride(biome_name, int(rec.get("recommended_stride", 1)))
	var dt_result = set_resolution(biome_name, float(rec.get("recommended_dt", 0.02)))
	return {
		"ok": bool(stride_result.get("ok", false)) and bool(dt_result.get("ok", false)),
		"biome": biome_name,
		"recommendation": rec,
		"stride_result": stride_result,
		"resolution_result": dt_result,
	}


func _extract_emoji_weights(payload: Dictionary) -> Dictionary:
	if payload.is_empty():
		return {}
	var by_emoji = payload.get("by_emoji", {})
	if by_emoji is Dictionary:
		return by_emoji.duplicate(true)
	var out: Dictionary = {}
	for key in payload.keys():
		var value = payload.get(key, null)
		if value is float or value is int:
			var emoji = str(key)
			if emoji != "":
				out[emoji] = float(value)
	return out


static func _get_resource_amount(farm_node: Node, emoji: String) -> float:
	var economy = ActionCostRuntime.resolve_economy(farm_node)
	if not economy or not economy.has_method("get_resource"):
		return 0.0
	return float(economy.get_resource(emoji))


func _get_max_biome_qubits() -> int:
	return ActionCostRuntime.get_max_biome_qubits(farm)


func _get_economy():
	return ActionCostRuntime.resolve_economy(farm)


func _resolve_biome(biome_name: String):
	if not farm or not farm.grid:
		return null
	return farm.grid.get_biome(biome_name)


func _resolve_terminal_for_harvest(grid_pos: Vector2i) -> RefCounted:
	if not farm or not farm.grid:
		return null
	var plot = farm.grid.get_plot(grid_pos)
	if plot and plot.terminal:
		return plot.terminal
	return null


func _pick_injectable_icon(icons: Array, biome) -> Dictionary:
	for i in range(icons.size() - 1, -1, -1):
		var icon = icons[i]
		var north = icon.get("north", "")
		var south = icon.get("south", "")
		if north == "" or south == "":
			continue
		if biome.viz_cache and biome.viz_cache.has_metadata() and biome.viz_cache.get_qubit(north) >= 0:
			continue
		if biome.viz_cache and biome.viz_cache.has_metadata() and biome.viz_cache.get_qubit(south) >= 0:
			continue
		return {"north": north, "south": south}
	return {}


func _get_icon_for_qubit(register_map, qubit_index: int) -> Dictionary:
	var north = ""
	var south = ""
	for emoji in register_map.coordinates.keys():
		var coord = register_map.coordinates[emoji]
		if coord.qubit == qubit_index:
			if coord.pole == 0:
				north = emoji
			else:
				south = emoji
	if north != "" and south != "":
		return {"north": north, "south": south}
	return {}


func _unbind_terminals_for_register(biome, register_id: int) -> void:
	if not terminal_pool:
		return
	var biome_name = BiomeBase.type_name(biome)
	for terminal in terminal_pool.get_all_terminals():
		if terminal.is_bound and terminal.bound_biome_name == biome_name and terminal.bound_register_id == register_id:
			_detach_terminal_from_plot(terminal)
			terminal_pool.unbind_terminal(terminal)


func _reindex_bound_terminals(biome, removed_qubit: int) -> void:
	if not terminal_pool:
		return
	var biome_name = BiomeBase.type_name(biome)
	for terminal in terminal_pool.get_all_terminals():
		if not terminal.is_bound or terminal.bound_biome_name != biome_name:
			continue
		if terminal.bound_register_id > removed_qubit:
			terminal.bound_register_id -= 1


func _shrink_quantum_system(biome, qubit_to_remove: int, icon: Dictionary) -> Dictionary:
	var qc = biome.quantum_computer
	var rm = qc.register_map
	var north = icon.get("north", "")
	var south = icon.get("south", "")
	var old_dim = rm.dim()
	var old_num_qubits = rm.num_qubits

	rm.coordinates.erase(north)
	rm.coordinates.erase(south)

	if qc.density_matrix:
		qc.density_matrix = _trace_out_qubit(qc.density_matrix, qubit_to_remove, old_num_qubits)

	_reindex_register_map_after_removal(rm, qubit_to_remove, old_num_qubits)
	_reindex_entanglement_graph(qc, qubit_to_remove)
	_rebuild_operators_after_shrink(biome)

	return {
		"success": true,
		"removed_north": north,
		"removed_south": south,
		"old_dim": old_dim,
		"new_dim": rm.dim(),
		"old_qubits": old_num_qubits,
		"new_qubits": rm.num_qubits
	}


func _trace_out_qubit(density_matrix, qubit_index: int, num_qubits: int):
	var old_dim = density_matrix.n
	var new_num_qubits = num_qubits - 1
	var new_dim = 1 << new_num_qubits
	if new_dim < 1:
		return density_matrix

	var ComplexMatrixClass = load("res://Core/QuantumSubstrate/ComplexMatrix.gd")
	var ComplexClass = load("res://Core/QuantumSubstrate/Complex.gd")
	var new_dm = ComplexMatrixClass.new(new_dim)

	for i in range(new_dim):
		for j in range(new_dim):
			var sum_re = 0.0
			var sum_im = 0.0
			for traced_val in [0, 1]:
				var old_i = _insert_bit(i, qubit_index, traced_val, new_num_qubits)
				var old_j = _insert_bit(j, qubit_index, traced_val, new_num_qubits)
				if old_i < old_dim and old_j < old_dim:
					var elem = density_matrix.get_element(old_i, old_j)
					if elem:
						sum_re += elem.re
						sum_im += elem.im
			new_dm.set_element(i, j, ComplexClass.new(sum_re, sum_im))

	return new_dm


func _insert_bit(index: int, bit_position: int, bit_value: int, _num_bits: int) -> int:
	var high_mask = (-1) << bit_position
	var high_bits = (index & high_mask) << 1
	var low_mask = (1 << bit_position) - 1
	var low_bits = index & low_mask
	return high_bits | (bit_value << bit_position) | low_bits


func _reindex_register_map_after_removal(register_map, removed_qubit: int, old_num_qubits: int) -> void:
	var updated_axes: Dictionary = {}
	for emoji in register_map.coordinates.keys():
		var coord = register_map.coordinates[emoji]
		var qubit_index = coord.get("qubit", -1)
		if qubit_index > removed_qubit:
			coord["qubit"] = qubit_index - 1
			register_map.coordinates[emoji] = coord
			qubit_index -= 1
		if not updated_axes.has(qubit_index):
			updated_axes[qubit_index] = {"north": "", "south": ""}
		if coord.get("pole", 0) == 0:
			updated_axes[qubit_index]["north"] = emoji
		else:
			updated_axes[qubit_index]["south"] = emoji
	register_map.axes = updated_axes
	register_map.num_qubits = max(old_num_qubits - 1, 0)


func _reindex_entanglement_graph(quantum_computer, removed_qubit: int) -> void:
	if not quantum_computer or not quantum_computer.entanglement_graph:
		return
	var updated_graph: Dictionary = {}
	for reg_id in quantum_computer.entanglement_graph.keys():
		if reg_id == removed_qubit:
			continue
		var new_reg = reg_id - 1 if reg_id > removed_qubit else reg_id
		var neighbors: Array = []
		for neighbor in quantum_computer.entanglement_graph[reg_id]:
			if neighbor == removed_qubit:
				continue
			var new_neighbor = neighbor - 1 if neighbor > removed_qubit else neighbor
			if not neighbors.has(new_neighbor):
				neighbors.append(new_neighbor)
		updated_graph[new_reg] = neighbors
	quantum_computer.entanglement_graph = updated_graph


func _rebuild_operators_after_shrink(biome) -> void:
	var qc = biome.quantum_computer
	var HamBuilder = load("res://Core/QuantumSubstrate/HamiltonianBuilder.gd")
	var LindBuilder = load("res://Core/QuantumSubstrate/LindbladBuilder.gd")
	var BiomeBuilderCls = load("res://Core/Biomes/BiomeBuilder.gd")
	var BiomeRegistryCls = load("res://Core/Biomes/BiomeRegistry.gd")
	var verbose_ref = _get_verbose()

	# Load biome def so we rebuild H from the neighborhood loadout and L from atom_components.
	var biome_def = null
	if qc and qc.biome_name != "":
		biome_def = BiomeRegistryCls.new().get_by_name(qc.biome_name)

	var biome_icons: Array = []
	var atom_components: Dictionary = {}
	if biome_def != null:
		biome_icons = BiomeBuilderCls._build_neighborhood_icon_list(biome_def)
		var ac = biome_def.atom_components if "atom_components" in biome_def else null
		if ac is Dictionary:
			atom_components = ac
	else:
		# Fallback: reconstruct icons from register_map axes; atom_components stays empty.
		var IconRegistryCls = load("res://Core/Factions/IconRegistry.gd")
		var IconCls = load("res://Core/QuantumSubstrate/Icon.gd")
		var lexicon = (Engine.get_main_loop().root.get_node_or_null("/root/IconRegistry") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
		if lexicon == null:
			lexicon = IconRegistryCls.new()  # test harness fallback
		for q in range(qc.register_map.num_qubits):
			var axis = qc.register_map.axes.get(q, {})
			var north: String = str(axis.get("north", ""))
			var south: String = str(axis.get("south", ""))
			if north == "" or south == "":
				continue
			var physics = lexicon.get_icon_physics_by_pair(north, south)
			var rec = lexicon.find_icon_by_pair(north, south)
			var iname: String = str(rec.get("name", north)) if not rec.is_empty() else north
			biome_icons.append(IconCls.from_pair_physics(iname, north, south, physics, 1.0))

	qc.hamiltonian = HamBuilder.build_from_icons(biome_icons, qc.register_map, verbose_ref)
	var lindblad_result = LindBuilder.build_from_atoms(atom_components, qc.register_map, verbose_ref, qc.biome_name)
	qc.lindblad_operators = lindblad_result.get("operators", [])
	var driven_configs = HamBuilder.get_driven_icons(biome_icons, qc.register_map)
	qc.set_driven_icons(driven_configs)

	# Same-dim H/L mutation — must tell the C++ lookahead engine to re-register
	# or it'll keep replaying the pre-shrink operators (silent de-sync).
	var local_farm = InstrumentLocator.resolve_active_farm_main_loop()
	if local_farm and local_farm.biome_evolution_batcher and local_farm.biome_evolution_batcher.has_method("mark_for_reregister"):
		local_farm.biome_evolution_batcher.mark_for_reregister(qc.biome_name)


## Return observation_stride for a biome with a safe default.
static func _biome_stride(biome) -> int:
	return biome.observation_stride if "observation_stride" in biome else 1


## Return max_evolution_dt for a biome with a safe default.
static func _biome_dt(biome) -> float:
	return biome.max_evolution_dt if "max_evolution_dt" in biome else 0.02


## Deduplicate and validate a raw biome name array from RPC input.
## Static so rig_listener can call QuantumInstrument._sanitize_biomes() without an instance.
static func _sanitize_biomes(raw) -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	if raw is Array:
		for value in raw:
			var biome_name = str(value)
			if biome_name == "" or seen.has(biome_name):
				continue
			seen[biome_name] = true
			out.append(biome_name)
	return out


## Deduplicate and validate a raw known_icons array from RPC input.
## Static so rig_listener can call QuantumInstrument._sanitize_known_icons() without an instance.
static func _sanitize_known_icons(raw) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	if raw is Array:
		for icon in raw:
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
			out.append({"north": north, "south": south})
	return out


	# ============================================================================
	# INJECTABLE ICON HELPERS (inlined from removed IconUtils)
	# ============================================================================

func _collect_known_icons(farm_ref) -> Array:
	if farm_ref and farm_ref.has_method("get_known_icons"):
		return farm_ref.get_known_icons()
	return []

func _collect_injectable_icons(farm_ref, biome = null) -> Array:
	var known = _collect_known_icons(farm_ref)
	var filtered: Array = []
	var seen: Dictionary = {}
	for icon in known:
		if not (icon is Dictionary):
			continue
		var north = str(icon.get("north", ""))
		var south = str(icon.get("south", ""))
		if north == "" or south == "" or north == south:
			continue
		if biome and biome.viz_cache and biome.viz_cache.has_metadata():
			if biome.viz_cache.get_qubit(north) >= 0 or biome.viz_cache.get_qubit(south) >= 0:
				continue
		var key = "%s|%s" % [north, south]
		if seen.has(key):
			continue
		seen[key] = true
		filtered.append({"north": north, "south": south})
	return filtered

# ============================================================================
# AUTOLOAD ACCESS (RefCounted pattern - same as QuantumComputer.gd)
# ============================================================================

func _get_autoload(name: String):
	return GameStateSerializerClass.get_autoload(name)


func _get_verbose():
	if not _verbose:
		_verbose = VerboseHelper.get_config()
	return _verbose

func _log(level: String, category: String, emoji: String, message: String) -> void:
	VerboseHelper.log(level, category, emoji, message)
