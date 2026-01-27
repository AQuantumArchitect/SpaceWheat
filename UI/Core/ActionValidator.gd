class_name ActionValidator
extends RefCounted

## ActionValidator - Pure validation functions for action availability
##
## Extracts all _can_execute_* logic from FarmInputHandler.
## All methods are static with no side effects.
##
## Used by:
## - ActionPreviewRow for button highlighting
## - FarmInputHandler for pre-execution validation

const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")


## ============================================================================
## MAIN ENTRY POINT
## ============================================================================

static func can_execute_action(
	action_key: String,
	current_tool: int,
	current_submenu: String,
	cached_submenu: Dictionary,
	farm,
	selected_plots: Array[Vector2i],
	current_selection: Vector2i
) -> bool:
	"""Check if action for given key can succeed with current selection.

	Uses any-valid strategy: returns true if at least 1 plot can succeed.

	Args:
		action_key: "Q", "E", or "R"
		current_tool: Active tool number (1-4)
		current_submenu: Active submenu name (empty = no submenu)
		cached_submenu: Cached submenu data for dynamic menus
		farm: Farm instance
		selected_plots: Currently selected plot positions
		current_selection: Cursor position

	Returns:
		bool: true if action would succeed on at least one selected plot
	"""
	if current_submenu != "":
		return _can_execute_submenu_action(
			action_key, current_submenu, cached_submenu, farm, selected_plots
		)
	else:
		return _can_execute_tool_action(
			action_key, current_tool, farm, selected_plots, current_selection
		)


## ============================================================================
## TOOL ACTION VALIDATION
## ============================================================================

static func _can_execute_tool_action(
	action_key: String,
	current_tool: int,
	farm,
	selected_plots: Array[Vector2i],
	current_selection: Vector2i
) -> bool:
	"""Check if tool action can succeed (not in submenu)."""
	if selected_plots.is_empty():
		return false

	# Use ToolConfig API to properly resolve action name
	var action = ToolConfig.get_action_name(current_tool, action_key)

	# Route to specific validation based on action type
	match action:
		# ═══════════════════════════════════════════════════════════════
		# v2 PROBE Tool (Tool 1) - Core gameplay loop
		# ═══════════════════════════════════════════════════════════════
		"explore":
			return _can_execute_explore(farm, current_selection)
		"measure":
			return _can_execute_measure(farm, selected_plots)
		"pop":
			return _can_execute_pop(farm, selected_plots)

		# ═══════════════════════════════════════════════════════════════
		# v2 GATES Tool (Tool 2) - 1-qubit gates
		# ═══════════════════════════════════════════════════════════════
		"rotate_down", "rotate_up", "hadamard":
			return true  # Available if plots selected
		"apply_pauli_x", "apply_hadamard", "apply_pauli_z", "apply_ry", \
		"apply_pauli_y", "apply_s_gate", "apply_t_gate", "apply_sdg_gate", \
		"apply_rx_gate", "apply_ry_gate", "apply_rz_gate":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# v2 ENTANGLE Tool (Tool 3) - 2-qubit gates
		# ═══════════════════════════════════════════════════════════════
		"build_gate":
			return selected_plots.size() >= 2  # Need 2+ plots for Bell/cluster
		"inspect", "remove_gates":
			return true  # Available if any plots selected
		"apply_cnot", "apply_swap", "apply_cz":
			return selected_plots.size() >= 2  # Need 2 plots for 2-qubit gates
		"create_bell_pair":
			return selected_plots.size() >= 2  # Need 2 plots for Bell pair
		"disentangle", "inspect_entanglement":
			return true  # Available if any plots selected

		# Entanglement cluster operations
		"cluster", "measure_trigger", "remove_gates":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# v2 INDUSTRY Tool (Tool 4)
		# ═══════════════════════════════════════════════════════════════
		"place_mill", "place_market":
			return true  # Available if plots selected
		"place_kitchen":
			return selected_plots.size() == 3  # Kitchen needs exactly 3 plots
		"harvest_flour", "market_sell":
			return true  # Available if plots selected
		"bake_bread":
			return selected_plots.size() == 3  # Baking needs exactly 3 plots

		# ═══════════════════════════════════════════════════════════════
		# BUILD MODE - Tool 1 (BIOME)
		# ═══════════════════════════════════════════════════════════════
		"submenu_biome_assign":
			return true  # Opens submenu
		"clear_biome_assignment", "inspect_plot":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# BUILD MODE - Tool 2 (ICON)
		# ═══════════════════════════════════════════════════════════════
		"submenu_icon_assign":
			return true  # Opens submenu
		"icon_swap", "icon_clear":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# BUILD MODE - Tool 3 (LINDBLAD)
		# ═══════════════════════════════════════════════════════════════
		"drain", "pump":
			return true  # Available if plots selected
		"transfer":
			return selected_plots.size() == 2  # Transfer needs exactly 2 plots
		"lindblad_drive", "lindblad_decay":
			return true  # Available if plots selected
		"lindblad_transfer":
			return selected_plots.size() == 2  # Transfer needs exactly 2 plots

		# ═══════════════════════════════════════════════════════════════
		# BUILD MODE - Tool 4 (QUANTUM) System/Phase/Rotation modes
		# ═══════════════════════════════════════════════════════════════
		"inject_vocabulary":
			return _can_execute_inject_vocabulary(farm, current_selection)
		"remove_vocabulary", "toggle_view", "cycle_biome":
			return true  # Available if plots selected
		"system_reset", "system_snapshot", "system_debug":
			return true  # Available if plots selected

		_:
			# Catch-all for any submenu-opening actions
			if action.begins_with("submenu_"):
				return true
			return false


## ============================================================================
## PROBE ACTION VALIDATION
## ============================================================================

static func _can_execute_explore(farm, current_selection: Vector2i) -> bool:
	"""Check if EXPLORE action is available (v2 PROBE Tool 1).

	EXPLORE binds an unbound terminal to a register in the current biome.
	Available when: unbound terminals exist AND biome has unbound registers.
	"""
	if not farm or not farm.plot_pool:
		return false

	# Need unbound terminals
	if farm.plot_pool.get_unbound_count() == 0:
		return false

	# Get biome from current selection
	if not farm.grid:
		return false

	var biome = farm.grid.get_biome_for_plot(current_selection)
	if not biome:
		return false

	# Must have unbound registers
	var probabilities = biome.get_register_probabilities(farm.plot_pool)
	return not probabilities.is_empty()


static func _can_execute_measure(farm, selected_plots: Array[Vector2i]) -> bool:
	"""Check if MEASURE action is available (v2 PROBE Tool 1).

	MEASURE collapses an active terminal (bound but not measured).
	Available when: active terminal exists at any selected position.
	"""
	if not farm or not farm.plot_pool:
		return false

	if selected_plots.is_empty():
		return false

	# Check any selected plot has an active terminal
	for pos in selected_plots:
		var terminal = farm.plot_pool.get_terminal_at_grid_pos(pos)
		if terminal and terminal.can_measure():
			return true

	return false


static func _can_execute_pop(farm, selected_plots: Array[Vector2i]) -> bool:
	"""Check if POP action is available (v2 PROBE Tool 1).

	POP harvests a measured terminal and unbinds it.
	Available when: measured terminal exists at any selected position.
	"""
	if not farm or not farm.plot_pool:
		return false

	if selected_plots.is_empty():
		return false

	# Check any selected plot has a measured terminal
	for pos in selected_plots:
		var terminal = farm.plot_pool.get_terminal_at_grid_pos(pos)
		if terminal and terminal.can_pop():
			return true

	return false


## ============================================================================
## SUBMENU ACTION VALIDATION
## ============================================================================

static func _can_execute_submenu_action(
	action_key: String,
	current_submenu: String,
	cached_submenu: Dictionary,
	farm,
	selected_plots: Array[Vector2i]
) -> bool:
	"""Check if submenu action can succeed."""
	if selected_plots.is_empty():
		return false

	var submenu = cached_submenu if not cached_submenu.is_empty() else ToolConfig.get_submenu(current_submenu)

	# Check if entire submenu disabled
	if submenu.get("_disabled", false):
		return false

	var action_info = submenu.get(action_key, {})
	var action = action_info.get("action", "")

	# Empty action = locked slot
	if action == "":
		return false

	# Route to specific validation
	match action:
		_:
			# Mill power/conversion and biome assignment always available
			if action.begins_with("mill_") or action.begins_with("assign_to_"):
				return true
			# Icon actions
			if action.begins_with("icon_assign_"):
				return _can_execute_icon_assign(farm, selected_plots, action)
			if action.begins_with("icon_"):
				return true
			return false


## ============================================================================
## UTILITY VALIDATION HELPERS
## ============================================================================

static func has_active_terminal_at(farm, pos: Vector2i) -> bool:
	"""Check if there's an active (bound but not measured) terminal at position."""
	if not farm or not farm.plot_pool:
		return false
	var terminal = farm.plot_pool.get_terminal_at_grid_pos(pos)
	return terminal != null and terminal.can_measure()


static func has_measured_terminal_at(farm, pos: Vector2i) -> bool:
	"""Check if there's a measured terminal at position."""
	if not farm or not farm.plot_pool:
		return false
	var terminal = farm.plot_pool.get_terminal_at_grid_pos(pos)
	return terminal != null and terminal.can_pop()


static func _can_execute_inject_vocabulary(farm, current_selection: Vector2i) -> bool:
	"""Check if there is at least one vocab pair not yet in the biome."""
	if not farm or not farm.grid:
		return false

	var biome = farm.grid.get_biome_for_plot(current_selection)
	if not biome or not biome.quantum_computer:
		return false
	if biome.quantum_computer.register_map.num_qubits >= EconomyConstants.MAX_BIOME_QUBITS:
		return false

	var pairs = _collect_injectable_pairs(farm, biome.quantum_computer)
	for pair in pairs:
		var north = pair.get("north", "")
		var south = pair.get("south", "")
		if north == "" or south == "":
			continue
		if biome.quantum_computer.register_map.has(north):
			continue
		if biome.quantum_computer.register_map.has(south):
			continue
		return true

	return false


static func _collect_injectable_pairs(farm_ref, quantum_computer = null) -> Array:
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
		if quantum_computer and quantum_computer.register_map:
			if quantum_computer.register_map.has(north) or quantum_computer.register_map.has(south):
				continue
		var key = "%s|%s" % [north, south]
		if seen.has(key):
			continue
		seen[key] = true
		filtered.append({"north": north, "south": south})
	return filtered


static func _can_execute_icon_assign(farm, selected_plots: Array[Vector2i], action: String) -> bool:
	"""Check if icon assignment can succeed for this emoji."""
	if not farm or not farm.grid or selected_plots.is_empty():
		return false

	var emoji = action.replace("icon_assign_", "")
	if emoji == "":
		return false

	if not farm.has_method("get_pair_for_emoji"):
		return false

	var pair = farm.get_pair_for_emoji(emoji)
	if not pair:
		return false

	var north = pair.get("north", "")
	var south = pair.get("south", "")
	if north == "" or south == "":
		return false

	var biome = farm.grid.get_biome_for_plot(selected_plots[0])
	if not biome or not biome.quantum_computer:
		return false
	if biome.quantum_computer.register_map.num_qubits >= EconomyConstants.MAX_BIOME_QUBITS:
		return false

	if biome.quantum_computer.register_map.has(north):
		return false
	if biome.quantum_computer.register_map.has(south):
		return false

	return true
