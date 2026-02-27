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

const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")
const GateActionHandler = preload("res://UI/Handlers/GateActionHandler.gd")
const LindbladHandler = preload("res://UI/Handlers/LindbladHandler.gd")
const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")
const BiomeHandler = preload("res://UI/Handlers/BiomeHandler.gd")
const PhysicsConfig = preload("res://Core/Config/PhysicsConfig.gd")
const GranularityController = preload("res://Core/Utils/GranularityController.gd")
const GameStateSerializerClass = preload("res://Core/GameState/GameStateSerializer.gd")
const VerboseHelper = preload("res://Core/Config/VerboseHelper.gd")

## Fallback biome pool used when ObservationFrame.get_loadable_biomes() is unavailable.
const DEFAULT_BIOME_POOL: Array[String] = [
	"StarterForest", "Village", "BioticFlux",
	"StellarForges", "FungalNetworks", "VolcanicWorlds"
]

const DEFAULT_TIMESCALE_OBJECTIVE: Dictionary = {
	"focus_emojis": [],
	"resource_floors": {"🍞": 64.0, "❄️": 32.0, "👥": 64.0},
	"top_k": 8,
	"target_gain_per_wait": 1.0,
	"horizon_min_phrames": 6,
	"horizon_max_phrames": 72
}

# ============================================================================
# SIGNALS
# ============================================================================

signal action_performed(action: String, result: Dictionary)
signal selection_changed(plot_idx: int, biome: String)
signal plot_check_changed(position: Vector2i, is_checked: bool)

# ============================================================================
# STATE
# ============================================================================

var farm: Node = null

## Terminal pool (instrument owns its measurement probes)
var terminal_pool = null

## Selection state (absorbed from QuantumInstrumentState)
var current_biome: String = ""
var current_plot_idx: int = -1
var last_selected_position: Vector2i = Vector2i(-1, -1)
var checked_plots: Array[Vector2i] = []

## Submenu state
var current_submenu_name: String = ""
var current_submenu_data: Dictionary = {}
var submenu_page: int = 0

## Tool state
var current_tool_group: int = 3
var tool_mode_indices: Dictionary = {}
var _timescale_objective: Dictionary = DEFAULT_TIMESCALE_OBJECTIVE.duplicate(true)

## Cached autoload references
var _verbose = null

# ============================================================================
# GATE DISPATCH TABLE (moved from FarmInstrument)
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
		farm_ref.name if farm_ref else "null"
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
	if changed:
		selection_changed.emit(plot_idx, biome_name)
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
	if name == "vocab_injection":
		var VocabInjectionSubmenu = load("res://UI/Core/Submenus/VocabInjectionSubmenu.gd")
		current_submenu_data = VocabInjectionSubmenu.generate_submenu(
			context.biome, context.farm, submenu_page
		)
	elif name == "gate_selection":
		var GateSelectionSubmenu = load("res://UI/Core/Submenus/GateSelectionSubmenu.gd")
		current_submenu_data = GateSelectionSubmenu.generate_submenu(
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

func set_tool_group(group: int) -> Dictionary:
	var old_group = current_tool_group
	current_tool_group = group
	return {"group": group, "changed": old_group != group}


func cycle_tool_mode() -> Dictionary:
	var ToolConfig = load("res://Core/GameState/ToolConfig.gd")
	var new_index = ToolConfig.cycle_group_mode(current_tool_group)
	var mode_label = ToolConfig.get_group_mode_label(current_tool_group)
	return {
		"mode_cycled": true,
		"group": current_tool_group,
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
	"""Return an error dict if preconditions fail, or {} if all clear."""
	if not farm:
		return {"success": false, "error": "no_farm", "message": "Farm not initialized"}
	if positions.is_empty():
		return {"success": false, "error": "no_selection", "message": "No plot selected"}
	return {}


func action_rotate(positions: Array[Vector2i], direction: int) -> Dictionary:
	var guard = _action_guard(positions)
	if not guard.is_empty(): return guard

	var ToolConfig = load("res://Core/GameState/ToolConfig.gd")
	var axis = ToolConfig.get_group_mode_name(1)
	if axis == "":
		axis = "X"

	var result: Dictionary
	match axis:
		"X": result = GateActionHandler.apply_rx_gate(farm, positions)
		"Y": result = GateActionHandler.apply_ry_gate(farm, positions)
		"Z": result = GateActionHandler.apply_rz_gate(farm, positions)
		_: result = {"success": true, "axis": axis, "direction": direction}

	action_performed.emit("rotate_up" if direction > 0 else "rotate_down", result)
	return result


func action_hadamard(positions: Array[Vector2i]) -> Dictionary:
	var guard = _action_guard(positions)
	if not guard.is_empty(): return guard

	var result = GateActionHandler.apply_hadamard(farm, positions)
	action_performed.emit("hadamard", result)
	return result


# ============================================================================
# GROUP 2: LINDBLADIAN ACTIONS
# ============================================================================

func action_drain(positions: Array[Vector2i]) -> Dictionary:
	var guard = _action_guard(positions)
	if not guard.is_empty(): return guard

	var result = LindbladHandler.enable_persistent_decay(farm, positions)
	action_performed.emit("drain", result)
	return result


func action_transfer(positions: Array[Vector2i]) -> Dictionary:
	var guard = _action_guard(positions)
	if not guard.is_empty(): return guard

	var result = LindbladHandler.lindblad_transfer(farm, positions)
	action_performed.emit("transfer", result)
	return result


func action_pump(positions: Array[Vector2i]) -> Dictionary:
	var guard = _action_guard(positions)
	if not guard.is_empty(): return guard

	var result = LindbladHandler.enable_persistent_drive(farm, positions)
	action_performed.emit("pump", result)
	return result


# ============================================================================
# GROUP 3: PROBE ACTIONS
# ============================================================================

func action_explore(biome_name: String, grid_pos: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	if not farm or not terminal_pool:
		return {"success": false, "error": "no_farm", "message": "Farm not ready"}
	if not farm.economy:
		return {"success": false, "error": "no_economy", "message": "Economy system not initialized"}

	var biome = _resolve_biome(biome_name)
	if not biome:
		return {"success": false, "error": "no_biome", "message": "Biome '%s' not found" % biome_name}

	var result = ProbeActions.action_explore(terminal_pool, biome, farm.economy)
	# Attach terminal to its grid plot
	if result.get("success", false):
		_attach_terminal_to_plot(result.get("terminal"))
	_emit_farm_action("explore", result, grid_pos)
	action_performed.emit("explore", result)
	return result


func action_measure(grid_pos: Vector2i) -> Dictionary:
	if not farm or not terminal_pool:
		return {"success": false, "error": "no_farm", "message": "Farm not ready"}

	var _plot = farm.grid.get_plot(grid_pos) if farm.grid else null
	var terminal = _plot.terminal if _plot else null
	if not terminal:
		return {"success": false, "error": "no_terminal", "message": "No terminal at selection", "blocked": true}
	if not terminal.can_measure():
		return {"success": false, "error": "cannot_measure", "message": "Terminal not ready to measure", "blocked": true}

	var biome_name = terminal.bound_biome_name
	if biome_name == "":
		return {"success": false, "error": "no_biome", "message": "Terminal not bound to biome", "blocked": true}
	var biome = _resolve_biome(biome_name)
	if not biome:
		return {"success": false, "error": "no_biome", "message": "Biome '%s' not found" % biome_name, "blocked": true}

	var result = ProbeActions.action_measure(terminal, biome, farm.economy)
	_emit_farm_action("measure", result, grid_pos)
	action_performed.emit("measure", result)
	return result


func action_pop(grid_pos: Vector2i) -> Dictionary:
	if not farm or not terminal_pool or not farm.economy:
		return {"success": false, "error": "no_farm", "message": "Farm not ready"}

	var terminal = _resolve_terminal_for_harvest(grid_pos)
	if not terminal:
		return {"success": false, "error": "no_terminal", "message": "No terminal at selection"}

	_detach_terminal_from_plot(terminal)
	var result = ProbeActions.action_pop(terminal, terminal_pool, farm.economy, farm)
	_emit_farm_action("pop", result, grid_pos)
	action_performed.emit("pop", result)
	return result


func action_reap() -> Dictionary:
	if not farm or not farm.economy:
		return {"success": false, "error": "no_farm", "message": "Farm not ready"}

	var result = ProbeActions.action_reap(farm, farm.economy)
	_emit_farm_action("reap", result)
	action_performed.emit("reap", result)
	return result


func action_harvest_all() -> Dictionary:
	if not farm or not farm.economy:
		return {"success": false, "error": "no_farm", "message": "Farm not ready"}

	var result = ProbeActions.action_reap(farm, farm.economy)
	_emit_farm_action("reap", result)
	_emit_farm_action("harvest_all", result)

	if result.get("success", false):
		clear_checked_plots()

	action_performed.emit("harvest_all", result)
	return result


func action_clear_all() -> Dictionary:
	if not farm or not terminal_pool:
		return {"success": false, "error": "no_farm", "message": "Farm not ready"}

	# Detach all terminals from their plots before clearing
	for t in terminal_pool.get_all_terminals():
		if t.is_bound:
			_detach_terminal_from_plot(t)
	var result = ProbeActions.action_clear_all(terminal_pool)
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
	if not farm:
		return {"success": false, "error": "no_farm", "message": "Farm not initialized"}
	if positions.is_empty():
		return {"success": false, "error": "no_selection", "message": "No plot selected"}

	var result = GateActionHandler.inspect_entanglement(farm, positions)
	action_performed.emit("inspect", result)
	return result


func action_remove_gates(positions: Array[Vector2i]) -> Dictionary:
	if not farm:
		return {"success": false, "error": "no_farm", "message": "Farm not initialized"}
	if positions.is_empty():
		return {"success": false, "error": "no_selection", "message": "No plot selected"}

	var result = GateActionHandler.disentangle(farm, positions)
	action_performed.emit("remove_gates", result)
	return result


# ============================================================================
# GROUP 4: META ACTIONS
# ============================================================================

func action_inject_vocabulary(biome_name: String) -> Dictionary:
	if not farm:
		return {"success": false, "error": "no_farm", "message": "Farm not initialized"}

	var biome = _resolve_biome(biome_name)
	if not biome:
		return {"success": false, "error": "no_biome", "message": "No biome at selection"}

	var qubit_count = biome.get_total_register_count() if biome.has_method("get_total_register_count") else 0
	var max_qubits = EconomyConstants.get_max_biome_qubits(farm.economy if farm and farm.economy else null)
	if qubit_count >= max_qubits:
		return {
			"success": false,
			"error": "qubit_cap_reached",
			"message": "Biome is at max capacity (%d qubits)" % max_qubits
		}

	var candidate_pairs = _collect_injectable_pairs(farm, biome)
	var pair = _pick_injectable_pair(candidate_pairs, biome)
	if pair.is_empty():
		return {"success": false, "error": "no_available_pair", "message": "No injectable vocab pair for this biome"}

	var context = {"south_emoji": pair.get("south", "")}
	var gate = EconomyConstants.preflight_action("inject_vocabulary", farm.economy if farm else null, context)
	if not gate.get("ok", true):
		return {
			"success": false,
			"error": "insufficient_funds",
			"message": "Insufficient resources for vocab injection (%s)" % [gate.get("cost", {})]
		}

	var result = biome.expand_quantum_system(pair.get("north", ""), pair.get("south", ""))
	if result.get("success", false):
		if not EconomyConstants.commit_action("inject_vocabulary", farm.economy, context):
			return {"success": false, "error": "cost_commit_failed", "message": "Vocab injection failed: unable to spend cost."}
		if farm and farm.has_method("discover_pair"):
			farm.discover_pair(pair.get("north", ""), pair.get("south", ""))

	action_performed.emit("inject_vocabulary", result)
	return result


func action_remove_vocabulary(biome_name: String, grid_pos: Vector2i) -> Dictionary:
	if not farm:
		return {"success": false, "error": "no_farm", "message": "Farm not initialized"}

	var biome = _resolve_biome(biome_name)
	if not biome or not biome.quantum_computer:
		return {"success": false, "error": "no_biome", "message": "No biome at selection"}

	var qc = biome.quantum_computer
	var rm = qc.register_map

	if rm.num_qubits < 2:
		return {"success": false, "error": "minimum_reached", "message": "Cannot remove last vocab pair"}

	var target_qubit = rm.num_qubits - 1
	var pair_to_remove = {}
	var _vocab_plot = farm.grid.get_plot(grid_pos) if farm and farm.grid else null
	var terminal = _vocab_plot.terminal if _vocab_plot else null
	var biome_type = biome.get_biome_type() if biome.has_method("get_biome_type") else biome.name
	if terminal and terminal.is_bound and terminal.bound_biome_name == biome_type:
		target_qubit = terminal.bound_register_id
	pair_to_remove = _get_pair_for_qubit(rm, target_qubit)

	var cost_gate = EconomyConstants.preflight_action("remove_vocabulary", farm.economy if farm else null)
	if not cost_gate.get("ok", true):
		var cost = cost_gate.get("cost", {})
		return {
			"success": false,
			"error": "insufficient_resources",
			"message": "Need %d %s to remove vocabulary." % [cost.values()[0], cost.keys()[0]] if not cost.is_empty() else "Insufficient resources"
		}

	if pair_to_remove.is_empty():
		return {"success": false, "error": "no_pair_found", "message": "Could not find vocab pair to remove"}

	_unbind_terminals_for_register(biome, target_qubit)

	var result = _shrink_quantum_system(biome, target_qubit, pair_to_remove)

	if result.get("success", false):
		if not EconomyConstants.commit_action("remove_vocabulary", farm.economy):
			return {"success": false, "error": "cost_commit_failed", "message": "Remove vocabulary failed: unable to spend cost."}
		_reindex_bound_terminals(biome, target_qubit)
		_log("info", "instrument", "-", "Removed vocab %s/%s from %s" % [
			pair_to_remove.get("north", "?"), pair_to_remove.get("south", "?"), biome_name
		])

	action_performed.emit("remove_vocabulary", result)
	return result


func action_explore_biome() -> Dictionary:
	if not farm:
		return {"success": false, "error": "no_farm", "message": "Farm not ready"}
	if not farm.has_method("explore_biome"):
		return {"success": false, "error": "no_method", "message": "Farm cannot explore biomes"}

	var result = farm.explore_biome()
	action_performed.emit("explore_biome", result)
	return result


func action_discover_biome() -> Dictionary:
	# Terminology alias: biome unlock/discovery (eagle-gated), not terminal explore.
	var result = action_explore_biome()
	action_performed.emit("discover_biome", result)
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
# GATE DISPATCH API (moved from FarmInstrument)
# ============================================================================

func gate_inject(gate_name: String, positions: Array[Vector2i]) -> Dictionary:
	if not farm:
		return {"ok": false, "error": "no_farm"}
	if not _GATE_DISPATCH.has(gate_name):
		return {"ok": false, "error": "unknown_gate", "gate": gate_name, "available": _GATE_DISPATCH.keys()}
	var gate_callable = _GATE_DISPATCH[gate_name] as Callable
	if gate_callable == null or not gate_callable.is_valid():
		return {"ok": false, "error": "invalid_gate_dispatch", "gate": gate_name}
	var result = gate_callable.call(farm, positions)
	result["gate"] = gate_name
	action_performed.emit("gate_inject", result)
	_notify_quest_projection("gate_inject:%s" % gate_name, result)
	return result


func lindblad_pump(positions: Array[Vector2i]) -> Dictionary:
	if not farm:
		return {"ok": false, "error": "no_farm"}
	# Rig/API pump should install persistent channels (same semantics as player action_pump).
	var result = LindbladHandler.enable_persistent_drive(farm, positions)
	action_performed.emit("lindblad_pump", result)
	_notify_quest_projection("lindblad_pump", result)
	return result


func lindblad_drain(positions: Array[Vector2i]) -> Dictionary:
	if not farm:
		return {"ok": false, "error": "no_farm"}
	# Rig/API drain should install persistent channels (same semantics as player action_drain).
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
	if not farm.grid or not farm.grid.biomes:
		return {"success": false, "error": "no_biomes"}
	var biome = farm.grid.biomes.get(biome_name, null)
	if not biome:
		return {"success": false, "error": "unknown_biome"}

	_notify_autoload("ActiveBiomeManager", "set_active_biome", [biome_name])
	_notify_autoload("ObservationFrame", "set_neutral_biome", [biome_name])

	var explore = ProbeActions.action_explore(terminal_pool, biome, farm.economy)
	if not explore.get("success", false):
		var explore_fail = {"success": false, "stage": "explore", "details": explore}
		return explore_fail
	var terminal = explore.get("terminal", null)
	_attach_terminal_to_plot(terminal)
	# Emit explore signal so bubbles appear during bot runs
	_emit_farm_action("explore", explore)

	var measure = ProbeActions.action_measure(terminal, biome, farm.economy)
	if not measure.get("success", false):
		var measure_fail = {"success": false, "stage": "measure", "details": measure}
		return measure_fail
	_emit_farm_action("measure", measure)

	_detach_terminal_from_plot(terminal)
	var pop = ProbeActions.action_pop(terminal, terminal_pool, farm.economy, farm)
	_emit_farm_action("pop", pop)

	var probe_result = {"success": true, "explore": explore, "measure": measure, "pop": pop, "active_biome": biome_name}
	_notify_quest_projection("probe_cycle", probe_result)
	return probe_result


func victory_lap() -> Dictionary:
	if not farm or not farm.grid or not farm.grid.biomes:
		return {"success": false, "error": "no_farm_or_biomes"}
	if not terminal_pool:
		return {"success": false, "error": "no_terminal_pool"}

	var biomes: Array[String] = []
	for biome_name in farm.grid.biomes.keys():
		if biome_name is String and str(biome_name) != "":
			biomes.append(str(biome_name))
	biomes.sort()

	var explore_total = 0
	var explore_failures: Array = []

	for biome_name in biomes:
		var biome = farm.grid.biomes.get(biome_name, null)
		if not biome:
			continue
		while true:
			var explore = ProbeActions.action_explore(terminal_pool, biome, farm.economy)
			if explore.get("success", false):
				explore_total += 1
				_attach_terminal_to_plot(explore.get("terminal"))
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
		var biome = farm.grid.biomes.get(t_biome_name, null)
		if not biome:
			measure_failures.append({"terminal": terminal.terminal_id, "error": "unknown_biome", "biome": t_biome_name})
			continue
		var measure = ProbeActions.action_measure(terminal, biome, farm.economy)
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
		var pop = ProbeActions.action_pop(terminal, terminal_pool, farm.economy, farm)
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
	if farm and "economy" in farm and farm.economy and farm.economy.has_method("get_resource"):
		milk_amount = float(farm.economy.get_resource("\ud83c\udf7c"))

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


func configure_seed_state(cmd: Dictionary) -> Dictionary:
	var out: Dictionary = {"ok": true}
	var gsm = _get_autoload("GameStateManager")
	if not gsm or not gsm.current_state:
		return {"ok": false, "error": "no_game_state"}

	var known_pairs = _sanitize_known_pairs(cmd.get("known_pairs", []))
	if not known_pairs.is_empty():
		if farm and farm.has_method("set_known_pairs"):
			farm.set_known_pairs(known_pairs, true, true)
		gsm.current_state.known_pairs = known_pairs.duplicate(true)
		gsm.current_state.known_emojis = gsm.current_state.get_known_emojis()
		out["known_pairs"] = known_pairs

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
		else:
			default_pool = DEFAULT_BIOME_POOL.duplicate()
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

	return out


# ============================================================================
# PRIVATE HELPERS
# ============================================================================

func _emit_farm_action(action: String, result: Dictionary, pos: Vector2i = Vector2i(-1, -1)) -> void:
	if farm and farm.has_method("emit_action_signal"):
		farm.emit_action_signal(action, result, pos)


func _attach_terminal_to_plot(t) -> void:
	if t and t.grid_position != Vector2i(-1, -1) and farm and farm.grid:
		var plot = farm.grid.get_plot(t.grid_position)
		if plot:
			plot.terminal = t


func _detach_terminal_from_plot(t) -> void:
	if t and t.grid_position != Vector2i(-1, -1) and farm and farm.grid:
		var plot = farm.grid.get_plot(t.grid_position)
		if plot:
			plot.terminal = null


func _notify_autoload(node_name: String, method: String, args: Array) -> void:
	var node = _get_autoload(node_name)
	if node and node.has_method(method):
		node.callv(method, args)


func _resolve_quest_manager():
	if farm and "quest_manager" in farm and farm.quest_manager:
		return farm.quest_manager
	var gsm = _get_autoload("GameStateManager")
	if gsm and "active_farm" in gsm and gsm.active_farm and "quest_manager" in gsm.active_farm:
		return gsm.active_farm.quest_manager
	return null


func _notify_quest_projection(action_name: String, payload: Dictionary) -> void:
	var qm = _resolve_quest_manager()
	if not qm:
		return
	if qm.has_method("record_quantum_action"):
		qm.record_quantum_action(action_name, payload)


# ============================================================================
# TIMESCALE CONTROLS (two-axis: stride + resolution)
# ============================================================================

func set_observation_stride(biome_name: String, stride: int) -> Dictionary:
	"""Set observation stride for a biome. 0=locked, 1=normal, 2+=fast forward."""
	var biome = _resolve_biome(biome_name)
	if not biome:
		return {"ok": false, "error": "unknown_biome", "biome": biome_name}
	var clamped = clampi(stride, GranularityController.MIN_STRIDE, GranularityController.MAX_STRIDE)
	var old_stride = _biome_stride(biome)
	biome.observation_stride = clamped
	var batcher = farm.biome_evolution_batcher if farm and "biome_evolution_batcher" in farm else null
	if batcher and batcher.has_method("reset_stride_carry"):
		batcher.reset_stride_carry(biome_name)
	var result = {"ok": true, "biome": biome_name, "old_stride": old_stride, "new_stride": clamped, "locked": clamped == 0}
	action_performed.emit("set_observation_stride", result)
	return result


func set_resolution(biome_name: String, dt: float) -> Dictionary:
	"""Set evolution resolution (max_evolution_dt) for a biome."""
	var biome = _resolve_biome(biome_name)
	if not biome:
		return {"ok": false, "error": "unknown_biome", "biome": biome_name}
	var clamped = clampf(dt, GranularityController.MIN_DT, GranularityController.MAX_DT)
	var old_dt = _biome_dt(biome)
	biome.max_evolution_dt = clamped
	var batcher = farm.biome_evolution_batcher if farm and "biome_evolution_batcher" in farm else null
	if batcher and batcher.has_method("reset_stride_carry"):
		batcher.reset_stride_carry(biome_name)
	var result = {"ok": true, "biome": biome_name, "old_dt": old_dt, "new_dt": clamped}
	action_performed.emit("set_resolution", result)
	return result


func get_timescale_snapshot(biome_name: String) -> Dictionary:
	"""Get current timescale state for a biome: stride, dt, locked status."""
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


static func _get_resource_amount(farm_node: Node, emoji: String) -> float:
	if not farm_node or not ("economy" in farm_node) or not farm_node.economy:
		return 0.0
	if not farm_node.economy.has_method("get_resource"):
		return 0.0
	return float(farm_node.economy.get_resource(emoji))


func _resolve_biome(biome_name: String):
	if not farm or not farm.grid:
		return null
	return farm.grid.biomes.get(biome_name)


func _resolve_terminal_for_harvest(grid_pos: Vector2i) -> RefCounted:
	if not farm or not farm.grid:
		return null
	var plot = farm.grid.get_plot(grid_pos)
	if plot and plot.terminal:
		return plot.terminal
	# Fallback: try last selected position
	if last_selected_position != Vector2i(-1, -1) and last_selected_position != grid_pos:
		var fallback_plot = farm.grid.get_plot(last_selected_position)
		if fallback_plot and fallback_plot.terminal and fallback_plot.terminal.is_measured:
			return fallback_plot.terminal
	return null


func _collect_injectable_pairs(farm_ref, biome = null) -> Array:
	var pairs: Array = []
	if farm_ref and farm_ref.has_method("get_known_pairs"):
		pairs.append_array(farm_ref.get_known_pairs())
	if farm_ref and "vocabulary_evolution" in farm_ref and farm_ref.vocabulary_evolution:
		var vocab = farm_ref.vocabulary_evolution
		if vocab and vocab.has_method("get_discovered_vocabulary"):
			var discovered = vocab.get_discovered_vocabulary()
			if discovered is Array:
				pairs.append_array(discovered)
	var filtered: Array = []
	var seen: Dictionary = {}
	for pair in pairs:
		if not (pair is Dictionary):
			continue
		var north = pair.get("north", "")
		var south = pair.get("south", "")
		if north == "" or south == "" or north == south:
			continue
		if biome and (_biome_has_emoji(biome, north) or _biome_has_emoji(biome, south)):
			continue
		var key = "%s|%s" % [north, south]
		if seen.has(key):
			continue
		seen[key] = true
		filtered.append({"north": north, "south": south})
	return filtered


func _pick_injectable_pair(pairs: Array, biome) -> Dictionary:
	for i in range(pairs.size() - 1, -1, -1):
		var pair = pairs[i]
		var north = pair.get("north", "")
		var south = pair.get("south", "")
		if north == "" or south == "":
			continue
		if _biome_has_emoji(biome, north):
			continue
		if _biome_has_emoji(biome, south):
			continue
		return {"north": north, "south": south}
	return {}


func _biome_has_emoji(biome, emoji: String) -> bool:
	if not biome or emoji == "":
		return false
	if biome.viz_cache and biome.viz_cache.has_metadata():
		return biome.viz_cache.get_qubit(emoji) >= 0
	return false


func _get_pair_for_qubit(register_map, qubit_index: int) -> Dictionary:
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
	var biome_name = biome.get_biome_type() if biome.has_method("get_biome_type") else biome.name
	for terminal in terminal_pool.get_all_terminals():
		if terminal.is_bound and terminal.bound_biome_name == biome_name and terminal.bound_register_id == register_id:
			_detach_terminal_from_plot(terminal)
			terminal_pool.unbind_terminal(terminal)


func _reindex_bound_terminals(biome, removed_qubit: int) -> void:
	if not terminal_pool:
		return
	var biome_name = biome.get_biome_type() if biome.has_method("get_biome_type") else biome.name
	for terminal in terminal_pool.get_all_terminals():
		if not terminal.is_bound or terminal.bound_biome_name != biome_name:
			continue
		if terminal.bound_register_id > removed_qubit:
			terminal.bound_register_id -= 1


func _shrink_quantum_system(biome, qubit_to_remove: int, pair: Dictionary) -> Dictionary:
	var qc = biome.quantum_computer
	var rm = qc.register_map
	var north = pair.get("north", "")
	var south = pair.get("south", "")
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
	var _icon_reg = _get_autoload("IconRegistry")
	if not _icon_reg:
		push_warning("_rebuild_operators_after_shrink: IconRegistry not available")
		return

	var all_icons = {}
	for emoji in qc.register_map.coordinates.keys():
		var icon = _icon_reg.get_icon(emoji)
		if icon:
			all_icons[emoji] = icon

	var HamBuilder = load("res://Core/QuantumSubstrate/HamiltonianBuilder.gd")
	var LindBuilder = load("res://Core/QuantumSubstrate/LindbladBuilder.gd")
	var verbose_ref = _get_verbose()

	qc.hamiltonian = HamBuilder.build(all_icons, qc.register_map, verbose_ref)
	var lindblad_result = LindBuilder.build(all_icons, qc.register_map, verbose_ref)
	qc.lindblad_operators = lindblad_result.get("operators", [])
	qc.gated_lindblad_configs = lindblad_result.get("gated_configs", [])

	var driven_configs = HamBuilder.get_driven_icons(all_icons, qc.register_map)
	qc.set_driven_icons(driven_configs)


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


## Deduplicate and validate a raw known_pairs array from RPC input.
## Static so rig_listener can call QuantumInstrument._sanitize_known_pairs() without an instance.
static func _sanitize_known_pairs(raw) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	if raw is Array:
		for pair in raw:
			if not (pair is Dictionary):
				continue
			var north = str(pair.get("north", ""))
			var south = str(pair.get("south", ""))
			if north == "" or south == "" or north == south:
				continue
			var key = "%s|%s" % [north, south]
			if seen.has(key):
				continue
			seen[key] = true
			out.append({"north": north, "south": south})
	return out


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
