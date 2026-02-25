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

## Selection state (absorbed from QuantumInstrumentState)
var current_biome: String = ""
var current_plot_idx: int = -1
var current_subspace_idx: int = -1
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
	_log("debug", "instrument", "✅", "Set %d checked plots" % checked_plots.size())


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

func get_available_actions(context: Dictionary) -> Array:
	var actions: Array = []
	if is_in_submenu():
		for key in ["Q", "E", "R"]:
			if current_submenu_data.get("actions", {}).has(key):
				var action_data = current_submenu_data["actions"][key]
				actions.append({
					"key": key,
					"action": action_data.get("action", ""),
					"enabled": action_data.get("enabled", true),
					"cost": action_data.get("cost", {}),
					"label": action_data.get("label", "")
				})
	else:
		var ToolConfig = load("res://Core/GameState/ToolConfig.gd")
		var tool_group = ToolConfig.get_group(current_tool_group)
		var mode_index = ToolConfig.get_group_mode_index(current_tool_group)
		var modes = tool_group.get("modes", [[]])
		if mode_index < 0 or mode_index >= modes.size():
			return actions
		var tool_actions = modes[mode_index]
		if tool_actions is String:
			actions.append({"key": "Q", "action": tool_actions, "enabled": true, "cost": {}, "label": tool_actions})
		elif tool_actions is Array:
			for i in range(min(3, tool_actions.size())):
				var action_key = ["Q", "E", "R"][i]
				actions.append({"key": action_key, "action": tool_actions[i], "enabled": true, "cost": {}, "label": tool_actions[i]})
	return actions


func get_state_snapshot() -> Dictionary:
	return {
		"current_biome": current_biome,
		"current_plot_idx": current_plot_idx,
		"last_selected_position": last_selected_position,
		"checked_plots": checked_plots.duplicate(),
		"current_submenu_name": current_submenu_name,
		"submenu_page": submenu_page,
		"current_tool_group": current_tool_group,
		"tool_mode_indices": tool_mode_indices.duplicate()
	}


func restore_state(snapshot: Dictionary) -> void:
	current_biome = snapshot.get("current_biome", "")
	current_plot_idx = snapshot.get("current_plot_idx", -1)
	last_selected_position = snapshot.get("last_selected_position", Vector2i(-1, -1))
	checked_plots = snapshot.get("checked_plots", []).duplicate()
	current_submenu_name = snapshot.get("current_submenu_name", "")
	submenu_page = snapshot.get("submenu_page", 0)
	current_tool_group = snapshot.get("current_tool_group", 3)
	tool_mode_indices = snapshot.get("tool_mode_indices", {}).duplicate()


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
	if not farm or not farm.terminal_pool:
		return {"success": false, "error": "no_farm", "message": "Farm not ready"}
	if not farm.economy:
		return {"success": false, "error": "no_economy", "message": "Economy system not initialized"}

	var biome = _resolve_biome(biome_name)
	if not biome:
		return {"success": false, "error": "no_biome", "message": "Biome '%s' not found" % biome_name}

	var result = ProbeActions.action_explore(farm.terminal_pool, biome, farm.economy)
	_emit_farm_action("explore", result, grid_pos)
	action_performed.emit("explore", result)
	return result


func action_measure(grid_pos: Vector2i) -> Dictionary:
	if not farm or not farm.terminal_pool:
		return {"success": false, "error": "no_farm", "message": "Farm not ready"}

	var terminal = farm.terminal_pool.get_terminal_at_grid_pos(grid_pos)
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
	if not farm or not farm.terminal_pool or not farm.economy:
		return {"success": false, "error": "no_farm", "message": "Farm not ready"}

	var terminal = _resolve_terminal_for_harvest(grid_pos)
	if not terminal:
		return {"success": false, "error": "no_terminal", "message": "No terminal at selection"}

	var result = ProbeActions.action_pop(terminal, farm.terminal_pool, farm.economy, farm)
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
	if not farm or not farm.terminal_pool:
		return {"success": false, "error": "no_farm", "message": "Farm not ready"}

	var result = ProbeActions.action_clear_all(farm.terminal_pool)
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
	if qubit_count >= EconomyConstants.MAX_BIOME_QUBITS:
		return {
			"success": false,
			"error": "qubit_cap_reached",
			"message": "Biome is at max capacity (%d qubits)" % EconomyConstants.MAX_BIOME_QUBITS
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
	var terminal = farm.terminal_pool.get_terminal_at_grid_pos(grid_pos) if farm and farm.terminal_pool else null
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
	if not farm or not ("terminal_pool" in farm) or not farm.terminal_pool:
		return {"success": false, "error": "no_terminal_pool"}
	if not farm.grid or not farm.grid.biomes:
		return {"success": false, "error": "no_biomes"}
	var biome = farm.grid.biomes.get(biome_name, null)
	if not biome:
		return {"success": false, "error": "unknown_biome"}

	_notify_autoload("ActiveBiomeManager", "set_active_biome", [biome_name])
	_notify_autoload("ObservationFrame", "set_neutral_biome", [biome_name])

	var explore = ProbeActions.action_explore(farm.terminal_pool, biome, farm.economy)
	if not explore.get("success", false):
		var explore_fail = {"success": false, "stage": "explore", "details": explore}
		return explore_fail
	# Emit explore signal so bubbles appear during bot runs
	_emit_farm_action("explore", explore)

	var terminal = explore.get("terminal", null)
	var measure = ProbeActions.action_measure(terminal, biome, farm.economy)
	if not measure.get("success", false):
		var measure_fail = {"success": false, "stage": "measure", "details": measure}
		return measure_fail
	_emit_farm_action("measure", measure)

	var pop = ProbeActions.action_pop(terminal, farm.terminal_pool, farm.economy, farm)
	_emit_farm_action("pop", pop)

	var probe_result = {"success": true, "explore": explore, "measure": measure, "pop": pop, "active_biome": biome_name}
	_notify_quest_projection("probe_cycle", probe_result)
	return probe_result


func victory_lap() -> Dictionary:
	if not farm or not farm.grid or not farm.grid.biomes:
		return {"success": false, "error": "no_farm_or_biomes"}
	if not ("terminal_pool" in farm) or not farm.terminal_pool:
		return {"success": false, "error": "no_terminal_pool"}

	var biomes: Array[String] = []
	for biome_name in farm.grid.biomes.keys():
		if biome_name is String and str(biome_name) != "":
			biomes.append(str(biome_name))
	biomes.sort()

	var explore_total = 0
	var explore_failures: Array = []
	var terminal_pool = farm.terminal_pool

	for biome_name in biomes:
		var biome = farm.grid.biomes.get(biome_name, null)
		if not biome:
			continue
		while true:
			var explore = ProbeActions.action_explore(terminal_pool, biome, farm.economy)
			if explore.get("success", false):
				explore_total += 1
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


func victory_lap_partial(
	selected_biomes: Array[String] = [],
	max_registers: int = 8,
	milk_spend: int = 0,
	phase_window: int = 1
) -> Dictionary:
	if not farm or not farm.grid or not farm.grid.biomes:
		return {"success": false, "error": "no_farm_or_biomes"}
	if not ("terminal_pool" in farm) or not farm.terminal_pool:
		return {"success": false, "error": "no_terminal_pool"}

	var terminal_pool = farm.terminal_pool
	var target_registers = max(1, max_registers)
	var target_phase_window = max(1, phase_window)
	var target_milk_spend = max(0, milk_spend)

	var chosen_biomes: Array[String] = []
	var seen: Dictionary = {}
	if selected_biomes.is_empty():
		for biome_name in farm.grid.biomes.keys():
			if biome_name is String and str(biome_name) != "":
				var b = str(biome_name)
				if not seen.has(b):
					chosen_biomes.append(b)
					seen[b] = true
	else:
		for biome_name in selected_biomes:
			if biome_name == "":
				continue
			if not farm.grid.biomes.has(biome_name):
				continue
			if seen.has(biome_name):
				continue
			chosen_biomes.append(biome_name)
			seen[biome_name] = true
	chosen_biomes.sort()
	if chosen_biomes.is_empty():
		return {"success": false, "error": "no_target_biomes"}

	var explore_total = 0
	var measure_total = 0
	var harvest_total = 0
	var explore_failures: Array = []
	var measure_failures: Array = []
	var harvest_failures: Array = []
	var explored_terminals: Array = []

	for biome_name in chosen_biomes:
		if explore_total >= target_registers:
			break
		var biome = farm.grid.biomes.get(biome_name, null)
		if not biome:
			continue
		while explore_total < target_registers:
			var explore = ProbeActions.action_explore(terminal_pool, biome, farm.economy)
			if not explore.get("success", false):
				var reason = str(explore.get("error", "unknown"))
				if reason != "no_registers":
					explore_failures.append({"biome": biome_name, "error": reason, "details": explore})
				break
			explore_total += 1
			var term = explore.get("terminal", null)
			if term:
				explored_terminals.append(term)
			_emit_farm_action("explore", explore)
			if terminal_pool.get_unbound_count() <= 0:
				break

	var measured_terminals: Array = []
	for terminal in explored_terminals:
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
			measured_terminals.append(terminal)
			_emit_farm_action("measure", measure)
		else:
			measure_failures.append({
				"terminal": terminal.terminal_id,
				"biome": t_biome_name,
				"error": str(measure.get("error", "unknown")),
				"details": measure
			})

	var milk_before = 0.0
	if farm and "economy" in farm and farm.economy and farm.economy.has_method("get_resource"):
		milk_before = float(farm.economy.get_resource("🍼"))
	var actual_milk_spend = 0.0
	if target_milk_spend > 0 and farm.economy and farm.economy.has_method("remove_resource"):
		var spend = min(float(target_milk_spend), milk_before)
		if spend > 0.0 and farm.economy.remove_resource("🍼", spend, "victory_lap_partial_spend"):
			actual_milk_spend = spend

	var reward_multiplier = _compute_partial_victory_multiplier(measure_total, actual_milk_spend, target_phase_window)
	var bonus_total = 0.0
	var bonus_by_emoji: Dictionary = {}

	for terminal in measured_terminals:
		if not terminal:
			continue
		var pop = ProbeActions.action_pop(terminal, terminal_pool, farm.economy, farm)
		if pop.get("success", false):
			harvest_total += 1
			_emit_farm_action("pop", pop)
			var resource = str(pop.get("resource", ""))
			var amount = float(pop.get("amount", 0))
			if resource != "" and amount > 0.0 and reward_multiplier > 1.0 and farm.economy and farm.economy.has_method("add_resource"):
				var bonus = floor(max(0.0, amount * (reward_multiplier - 1.0)))
				if bonus > 0.0:
					farm.economy.add_resource(resource, bonus, "victory_lap_partial_bonus")
					bonus_total += bonus
					bonus_by_emoji[resource] = float(bonus_by_emoji.get(resource, 0.0)) + bonus
		else:
			harvest_failures.append({
				"terminal": terminal.terminal_id,
				"error": str(pop.get("error", "unknown")),
				"details": pop
			})

	var milk_after = milk_before
	if farm and "economy" in farm and farm.economy and farm.economy.has_method("get_resource"):
		milk_after = float(farm.economy.get_resource("🍼"))

	var result = {
		"success": true,
		"mode": "partial",
		"biomes": chosen_biomes,
		"max_registers": target_registers,
		"phase_window": target_phase_window,
		"milk_spend_requested": target_milk_spend,
		"milk_spend_actual": actual_milk_spend,
		"reward_multiplier": reward_multiplier,
		"explore_total": explore_total,
		"explore_failures": explore_failures,
		"measure_total": measure_total,
		"measure_failures": measure_failures,
		"harvest_total": harvest_total,
		"harvest_failures": harvest_failures,
		"bonus_total": bonus_total,
		"bonus_by_emoji": bonus_by_emoji,
		"milk_before": milk_before,
		"milk_after": milk_after
	}
	_notify_quest_projection("victory_lap_partial", result)
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

func _compute_partial_victory_multiplier(selected_count: int, milk_spend: float, phase_window: int) -> float:
	var registers = max(0, selected_count)
	var phase = max(1, phase_window)
	var register_factor = max(1.0, log(1.0 + float(registers)) / log(2.0))
	var milk_factor = 1.0 + (0.20 * (log(1.0 + max(0.0, milk_spend)) / log(2.0)))
	var phase_factor = clamp(0.8 + (0.1 * float(phase - 1)), 0.8, 1.2)
	return max(1.0, register_factor * milk_factor * phase_factor)


func _emit_farm_action(action: String, result: Dictionary, pos: Vector2i = Vector2i(-1, -1)) -> void:
	if farm and farm.has_method("emit_action_signal"):
		farm.emit_action_signal(action, result, pos)


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
	_timescale_objective = _sanitize_timescale_objective(objective)
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


func get_timescale_projection(biome_name: String, top_k: int = -1) -> Dictionary:
	var biome = _resolve_biome(biome_name)
	if not biome:
		return {"ok": false, "error": "unknown_biome", "biome": biome_name}

	var icon_map = _get_biome_icon_map_payload(biome_name, biome)
	var rankings = _build_timescale_emoji_rankings(icon_map, _timescale_objective, top_k)
	var recommendation = _build_timescale_recommendation(rankings, icon_map, biome, _timescale_objective)
	return {
		"ok": true,
		"biome": biome_name,
		"objective": _timescale_objective.duplicate(true),
		"icon_map": icon_map,
		"emoji_rankings": rankings,
		"recommendation": recommendation
	}


func recommend_timescale(biome_name: String, top_k: int = -1) -> Dictionary:
	var projection = get_timescale_projection(biome_name, top_k)
	if not bool(projection.get("ok", false)):
		return projection
	var recommendation = projection.get("recommendation", {}).duplicate(true)
	recommendation["ok"] = true
	recommendation["biome"] = biome_name
	recommendation["emoji_rankings"] = projection.get("emoji_rankings", [])
	return recommendation


func auto_apply_timescale(biome_name: String, top_k: int = -1) -> Dictionary:
	"""One-click helper: recommend + apply stride/dt for a biome."""
	var recommendation = recommend_timescale(biome_name, top_k)
	if not bool(recommendation.get("ok", false)):
		return {
			"ok": false,
			"biome": biome_name,
			"error": recommendation.get("error", "recommendation_failed"),
			"recommendation": recommendation
		}

	var stride = int(recommendation.get("recommended_stride", 1))
	var dt = float(recommendation.get("recommended_dt", 0.02))
	if stride <= 0:
		stride = 1
	if dt <= 0.0:
		dt = 0.02

	var stride_result = set_observation_stride(biome_name, stride)
	var resolution_result = set_resolution(biome_name, dt)
	var ok = bool(stride_result.get("ok", false)) and bool(resolution_result.get("ok", false))
	return {
		"ok": ok,
		"biome": biome_name,
		"applied": ok,
		"recommended_stride": stride,
		"recommended_dt": dt,
		"recommended_wait_phrames": int(recommendation.get("recommended_wait_phrames", 0)),
		"recommendation": recommendation,
		"stride_result": stride_result,
		"resolution_result": resolution_result
	}


func _sanitize_timescale_objective(raw: Dictionary) -> Dictionary:
	var out = DEFAULT_TIMESCALE_OBJECTIVE.duplicate(true)
	if raw.is_empty():
		return out

	var focus: Array[String] = []
	var seen: Dictionary = {}
	var raw_focus = raw.get("focus_emojis", [])
	if raw_focus is Array:
		for emoji in raw_focus:
			var s = str(emoji)
			if s == "" or seen.has(s):
				continue
			seen[s] = true
			focus.append(s)
	out["focus_emojis"] = focus

	var floors: Dictionary = out.get("resource_floors", {}).duplicate(true)
	var raw_floors = raw.get("resource_floors", {})
	if raw_floors is Dictionary:
		for emoji in raw_floors.keys():
			var s = str(emoji)
			if s == "":
				continue
			floors[s] = max(0.0, float(raw_floors[emoji]))
	out["resource_floors"] = floors

	out["top_k"] = clampi(int(raw.get("top_k", out.get("top_k", 8))), 1, 32)
	out["target_gain_per_wait"] = clampf(float(raw.get("target_gain_per_wait", out.get("target_gain_per_wait", 1.0))), 0.05, 100.0)
	out["horizon_min_phrames"] = max(1, int(raw.get("horizon_min_phrames", out.get("horizon_min_phrames", 6))))
	out["horizon_max_phrames"] = max(out["horizon_min_phrames"], int(raw.get("horizon_max_phrames", out.get("horizon_max_phrames", 72))))
	return out


func _get_biome_icon_map_payload(biome_name: String, biome) -> Dictionary:
	var payload: Dictionary = {}
	if biome and biome.viz_cache and biome.viz_cache.has_method("get_icon_map"):
		payload = biome.viz_cache.get_icon_map()
	if payload.is_empty() and farm and "biome_evolution_batcher" in farm and farm.biome_evolution_batcher:
		var batcher = farm.biome_evolution_batcher
		if batcher.has_method("get_biome_icon_map"):
			payload = batcher.get_biome_icon_map(biome_name)
		elif batcher.has_method("get_global_icon_map"):
			payload = batcher.get_global_icon_map()

	var by_emoji: Dictionary = {}
	var total = 0.0
	var steps = 0
	var raw_by_emoji = payload.get("by_emoji", {})
	if raw_by_emoji is Dictionary:
		for emoji in raw_by_emoji.keys():
			var s = str(emoji)
			if s == "":
				continue
			var weight = float(raw_by_emoji[emoji])
			if weight <= 0.0:
				continue
			by_emoji[s] = weight
			total += weight
	steps = max(1, int(payload.get("steps", 1)))
	if by_emoji.is_empty() and farm and farm.has_method("get_known_emojis"):
		var known = farm.get_known_emojis()
		if known is Array:
			for emoji in known:
				var s = str(emoji)
				if s == "":
					continue
				by_emoji[s] = 1.0
				total += 1.0
			steps = 1
	if total <= 0.0:
		total = 1.0
	return {
		"by_emoji": by_emoji,
		"total": total,
		"steps": steps,
		"num_qubits": int(payload.get("num_qubits", 0))
	}


func _build_timescale_emoji_rankings(icon_map: Dictionary, objective: Dictionary, top_k_override: int = -1) -> Array:
	var rankings: Array = []
	var by_emoji: Dictionary = icon_map.get("by_emoji", {})
	var total = max(1e-9, float(icon_map.get("total", 1.0)))
	var steps = max(1, int(icon_map.get("steps", 1)))
	var focus_raw = objective.get("focus_emojis", [])
	var focus: Dictionary = {}
	if focus_raw is Array:
		for emoji in focus_raw:
			focus[str(emoji)] = true
	var floors: Dictionary = objective.get("resource_floors", {})

	for emoji in by_emoji.keys():
		var s = str(emoji)
		var weight = float(by_emoji[s])
		var probability = weight / total
		var per_step_probability = weight / float(steps)
		var floor = float(floors.get(s, 0.0))
		var have = _get_resource_amount(farm, s)
		var deficit = max(0.0, floor - have)
		var deficit_norm = (deficit / max(1.0, floor)) if floor > 0.0 else 0.0
		var is_focus = focus.has(s)
		var objective_score = probability * (1.0 + (1.5 * deficit_norm) + (0.6 if is_focus else 0.0))
		rankings.append({
			"emoji": s,
			"weight": weight,
			"probability": probability,
			"per_step_probability": per_step_probability,
			"resource_have": have,
			"resource_floor": floor,
			"resource_deficit": deficit,
			"focus": is_focus,
			"objective_score": objective_score
		})

	rankings.sort_custom(func(a, b):
		var sa = float(a.get("objective_score", 0.0))
		var sb = float(b.get("objective_score", 0.0))
		if sa == sb:
			return float(a.get("probability", 0.0)) > float(b.get("probability", 0.0))
		return sa > sb
	)

	var top_k = int(objective.get("top_k", 8))
	if top_k_override > 0:
		top_k = top_k_override
	top_k = clampi(top_k, 1, 64)
	if rankings.size() > top_k:
		return rankings.slice(0, top_k)
	return rankings


func _build_timescale_recommendation(rankings: Array, icon_map: Dictionary, biome, objective: Dictionary) -> Dictionary:
	var by_emoji: Dictionary = icon_map.get("by_emoji", {})
	var total = max(1e-9, float(icon_map.get("total", 1.0)))

	var concentration = 0.0
	var entropy = 0.0
	for emoji in by_emoji.keys():
		var p = float(by_emoji[emoji]) / total
		if p <= 0.0:
			continue
		concentration += p * p
		entropy += -p * log(p)
	var entropy_max = log(max(2.0, float(by_emoji.size())))
	var entropy_normalized = (entropy / entropy_max) if entropy_max > 0.0 else 0.0

	var focus_pressure = 0.0
	var floors: Dictionary = objective.get("resource_floors", {})
	for emoji in floors.keys():
		var floor = float(floors[emoji])
		if floor <= 0.0:
			continue
		var have = _get_resource_amount(farm, str(emoji))
		if have < floor:
			focus_pressure += (floor - have) / max(1.0, floor)

	var roughness = clampf(concentration, 0.0, 1.0)
	var stride = int(round(1.0 + (1.0 - roughness) * 7.0))
	if focus_pressure > 0.75:
		stride -= 1
	if focus_pressure > 1.5:
		stride -= 1
	stride = clampi(stride, 1, 16)

	var dt = 0.004 + ((1.0 - roughness) * 0.06)
	if focus_pressure > 0.75:
		dt *= 0.7
	dt = clampf(dt, GranularityController.MIN_DT, 0.2)

	var min_wait = max(1, int(objective.get("horizon_min_phrames", 6)))
	var max_wait = max(min_wait, int(objective.get("horizon_max_phrames", 72)))
	var wait_phrames = int(round(float(min_wait) + (1.0 - roughness) * float(max_wait - min_wait) + (focus_pressure * 8.0)))
	wait_phrames = clampi(wait_phrames, min_wait, max_wait)

	var current_stride = _biome_stride(biome)
	var current_dt = _biome_dt(biome)

	return {
		"current_stride": current_stride,
		"current_dt": current_dt,
		"recommended_stride": stride,
		"recommended_dt": dt,
		"recommended_wait_phrames": wait_phrames,
		"concentration": concentration,
		"entropy_normalized": entropy_normalized,
		"focus_pressure": focus_pressure,
		"top_emoji": rankings[0].get("emoji", "") if not rankings.is_empty() else "",
		"top_probability": float(rankings[0].get("probability", 0.0)) if not rankings.is_empty() else 0.0
	}


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
	if not farm or not farm.terminal_pool:
		return null
	var terminal = farm.terminal_pool.get_terminal_at_grid_pos(grid_pos)
	if terminal:
		return terminal
	if last_selected_position != Vector2i(-1, -1) and last_selected_position != grid_pos:
		var fallback = farm.terminal_pool.get_terminal_at_grid_pos(last_selected_position)
		if fallback and fallback.is_measured:
			return fallback
	if farm.terminal_pool.has_method("get_measured_terminals"):
		for candidate in farm.terminal_pool.get_measured_terminals():
			if candidate.grid_position == grid_pos:
				return candidate
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
	if not farm or not farm.terminal_pool:
		return
	var biome_name = biome.get_biome_type() if biome.has_method("get_biome_type") else biome.name
	for terminal in farm.terminal_pool.get_all_terminals():
		if terminal.is_bound and terminal.bound_biome_name == biome_name and terminal.bound_register_id == register_id:
			farm.terminal_pool.unbind_terminal(terminal)


func _reindex_bound_terminals(biome, removed_qubit: int) -> void:
	if not farm or not farm.terminal_pool:
		return
	var biome_name = biome.get_biome_type() if biome.has_method("get_biome_type") else biome.name
	for terminal in farm.terminal_pool.get_all_terminals():
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
