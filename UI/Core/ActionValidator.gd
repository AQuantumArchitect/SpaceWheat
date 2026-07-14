class_name ActionValidator
extends RefCounted

## ActionValidator - Pure validation functions for action availability
##
## Extracts all _can_execute_* logic from the live input path.
## All methods are static with no side effects.
##
## Used by:
## - UIContextController for action availability projection
## - QuantumInstrumentInput for pre-execution validation

const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")


## ============================================================================
## MAIN ENTRY POINT
## ============================================================================

static func can_execute_action(
	action_key: String,
	current_tool,
	current_submenu: String,
	cached_submenu: Dictionary,
	farm,
	selected_plots: Array[Vector2i],
	current_selection: Vector2i
) -> bool:
	# Check if action for given key can succeed with current selection.

	# Uses any-valid strategy: returns true if at least 1 plot can succeed.

	# Args:
	# action_key: "Q", "E", or "R"
	# current_tool: Active archetype frame name (String).
	# current_submenu: Active submenu name (empty = no submenu)
	# cached_submenu: Cached submenu data for dynamic menus
	# farm: Farm instance
	# selected_plots: Currently selected plot positions
	# current_selection: Cursor position

	# Returns:
	# bool: true if action would succeed on at least one selected plot
	if current_submenu != "":
		return _can_execute_submenu_action(
			action_key, current_submenu, cached_submenu, farm, selected_plots
		)
	else:
		return _can_execute_tool_action(
			action_key, current_tool, farm, selected_plots, current_selection
		)


static func can_execute_action_name(
	action_name: String,
	farm,
	selected_plots: Array[Vector2i],
	current_selection: Vector2i
) -> bool:
	# Check if a specific action name can succeed (bypasses ToolConfig lookup).
	match action_name:
		"explore":
			return _can_execute_explore(farm, current_selection)
		"measure":
			return _can_execute_measure(farm, selected_plots)
		"pop", "reap":
			return _can_execute_pop(farm, selected_plots)
		"inject_icon":
			return _can_execute_inject_icon(farm, current_selection)
		"remove_icon":
			return _can_execute_remove_icon(farm, current_selection)
		"discover_biome":
			return _can_execute_discover_biome(farm)
		"remove_biome":
			return _can_execute_remove_biome(farm)
		"cycle_mode":
			return true
		_:
			return true


## ============================================================================
## TOOL ACTION VALIDATION
## ============================================================================

static func _can_execute_tool_action(
	action_key: String,
	current_tool,
	farm,
	selected_plots: Array[Vector2i],
	current_selection: Vector2i
) -> bool:
	# Check if tool action can succeed (not in submenu).
	if action_key == "F" and ToolConfig.has_explicit_f_action(current_tool):
		return true

	if selected_plots.is_empty():
		return false

	# Use ToolConfig API to properly resolve action name
	var action = ToolConfig.get_action_name(current_tool, action_key)

	# Route to specific validation based on action type
	match action:
		# ═══════════════════════════════════════════════════════════════
		# Ace frame — probe/explore/harvest core gameplay loop
		# ═══════════════════════════════════════════════════════════════
		"explore":
			return _can_execute_explore(farm, current_selection)
		"measure":
			return _can_execute_measure(farm, selected_plots)
		"pop":
			return _can_execute_pop(farm, selected_plots)
		"plant":
			return true  # Coherent Rabi pulse — unitary, legal in any regime

		# ═══════════════════════════════════════════════════════════════
		# Druid frame — 1-qubit unitary gates
		# ═══════════════════════════════════════════════════════════════
		"rotate_down", "rotate_up", "hadamard":
			return true  # Available if plots selected
		"apply_pauli_x", "apply_hadamard", "apply_pauli_z", "apply_ry", \
		"apply_pauli_y", "apply_s_gate", "apply_t_gate", "apply_sdg_gate", \
		"apply_rx_gate", "apply_ry_gate", "apply_rz_gate":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# Operator frame — 2-qubit entangling gates
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
		# LEGACY TOOL COMMENTS - retained action families
		# ═══════════════════════════════════════════════════════════════
		"submenu_biome_assign":
			return true  # Opens submenu
		"clear_biome_assignment", "inspect_plot":
			return true  # Available if plots selected

		"submenu_icon_assign":
			return true  # Opens submenu
		"icon_swap", "icon_clear":
			return true  # Available if plots selected

		# ═══════════════════════════════════════════════════════════════
		# Spark frame — one-shot Lindblad jolt (wet country) + bridges
		# ═══════════════════════════════════════════════════════════════
		"spark_north", "spark_south":
			return _any_open_plot(farm, selected_plots)
		"jolt_inspect", "read_price":
			return true  # Read-only gauges — available wherever a plot is selected
		"bridge_anchor", "bridge_braid", "bridge_fuse", "bridge_inspect":
			return true  # Never sealed — the span is the anti-Lindblad artifact

		# ═══════════════════════════════════════════════════════════════
		# Merchant frame — standing contracts (wet country only)
		# ═══════════════════════════════════════════════════════════════
		"drain", "pump":
			return _any_open_plot(farm, selected_plots)
		"settle":
			return _any_active_channel(farm, selected_plots)
		"lindblad_drive", "lindblad_decay":
			return _any_open_plot(farm, selected_plots)

		# ═══════════════════════════════════════════════════════════════
		# TOOL 4 META / SYSTEM ACTIONS
		# ═══════════════════════════════════════════════════════════════
		"inject_icon":
			return _can_execute_inject_icon(farm, current_selection)
		"remove_icon":
			return _can_execute_remove_icon(farm, current_selection)
		"discover_biome":
			return _can_execute_discover_biome(farm)
		"remove_biome":
			return _can_execute_remove_biome(farm)
		"cycle_mode":
			return true
		"toggle_view", "cycle_biome":
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
	# Check if EXPLORE action is available (Ace frame — probe/explore).

	# EXPLORE binds an unbound terminal to a register in the current biome.
	# Available when: unbound terminals exist AND biome has unbound registers.
	var terminal_pool = farm.get("terminal_pool") if farm else null
	if not terminal_pool:
		return false

	# Explore is always available when unbound terminals exist — re-exploring a bound
	# terminal is valid, so we don't check register availability here.
	return terminal_pool.get_unbound_count() > 0


static func _can_execute_measure(farm, selected_plots: Array[Vector2i]) -> bool:
	# Check if STRIKE/MEASURE is available (Ace frame — the strike verb).
	#
	# A strike collapses the selected register. Selection no longer pre-binds a
	# terminal — the strike binds one on demand — so the verb is available on any
	# live QC register (plot_idx ≡ register_id), or on an already-active terminal.
	if not farm or selected_plots.is_empty():
		return false
	var grid = farm.get("grid") if farm else null
	if not grid:
		return false
	for pos in selected_plots:
		var plot = grid.get_plot(pos) if grid else null
		var terminal = plot.terminal if plot else null
		# Already-bound terminal → measurable now.
		if terminal and terminal.can_measure():
			return true
		# Live QC register → strikeable (measure binds the terminal on demand).
		var biome = grid.get_biome_for_plot(pos)
		if biome and biome.quantum_computer and biome.quantum_computer.register_map:
			if pos.x >= 0 and pos.x < biome.quantum_computer.register_map.num_qubits:
				return true

	return false


static func _can_execute_pop(farm, selected_plots: Array[Vector2i]) -> bool:
	# Check if POP action is available (Ace frame — probe/harvest).

	# POP harvests a measured terminal and unbinds it.
	# Available when: measured terminal exists at any selected position.
	if not farm:
		return false

	if selected_plots.is_empty():
		return false

	# Check any selected plot has a measured terminal (or bound terminal that will auto-measure on pop)
	var grid = farm.get("grid") if farm else null
	for pos in selected_plots:
		var plot = grid.get_plot(pos) if grid else null
		var terminal = plot.terminal if plot else null
		if terminal and (terminal.can_pop() or terminal.is_bound):
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
	# Check if submenu action can succeed.
	if selected_plots.is_empty():
		return false

	var submenu = cached_submenu
	if submenu.is_empty():
		return false

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

static func _any_open_plot(farm, selected_plots: Array[Vector2i]) -> bool:
	# Openness is a place: Lindblad verbs are live if ANY selected plot sits
	# on ground whose regime runs open (QuantumComputer.is_open_here).
	var grid = farm.get("grid") if farm else null
	if not grid:
		return false
	for pos in selected_plots:
		var biome = grid.get_biome_for_plot(pos)
		if biome and biome.quantum_computer and biome.quantum_computer.is_open_here():
			return true
	return false


static func _any_active_channel(farm, selected_plots: Array[Vector2i]) -> bool:
	# Settle is live if any selected plot's register carries a standing channel.
	var grid = farm.get("grid") if farm else null
	if not grid:
		return false
	for pos in selected_plots:
		var biome = grid.get_biome_for_plot(pos)
		if not biome or not biome.quantum_computer:
			continue
		var qc = biome.quantum_computer
		if not ("register_infrastructure" in qc):
			continue
		for reg_id in qc.register_infrastructure.keys():
			var infra: Dictionary = qc.register_infrastructure[reg_id]
			if bool(infra.get("lindblad_pump_active", false)) or bool(infra.get("lindblad_drain_active", false)):
				return true
	return false


static func has_active_terminal_at(farm, pos: Vector2i) -> bool:
	# Check if there's an active (bound but not measured) terminal at position.
	var grid = farm.get("grid") if farm else null
	var plot = grid.get_plot(pos) if grid else null
	var terminal = plot.terminal if plot else null
	return terminal != null and terminal.can_measure()


static func has_measured_terminal_at(farm, pos: Vector2i) -> bool:
	# Check if there's a measured terminal at position.
	var grid = farm.get("grid") if farm else null
	var plot = grid.get_plot(pos) if grid else null
	var terminal = plot.terminal if plot else null
	return terminal != null and terminal.can_pop()


static func _can_execute_inject_icon(farm, current_selection: Vector2i) -> bool:
	# Check if there is at least one icon not yet in the biome.
	var grid = farm.get("grid") if farm else null
	if not grid:
		return false

	var biome = grid.get_biome_for_plot(current_selection)
	if not biome:
		return false
	if not biome.viz_cache or not biome.viz_cache.has_metadata():
		return false
	if _get_qubit_count(biome) >= ActionCostRuntime.get_max_biome_qubits(farm):
		return false

	var icons = _collect_injectable_icons(farm, biome)
	if icons.is_empty():
		return false
		
	# Check affordability for at least the first candidate icon.
	var first_icon = icons[0]
	var gate = ActionCostRuntime.preflight_action(farm, "inject_icon", {"south_emoji": first_icon.get("south", "")})
	return bool(gate.get("ok", false))


static func _can_execute_icon_assign(farm, selected_plots: Array[Vector2i], action: String) -> bool:
	# Check if icon assignment can succeed for this emoji.
	var grid = farm.get("grid") if farm else null
	if not grid or selected_plots.is_empty():
		return false

	var emoji = action.replace("icon_assign_", "")
	if emoji == "":
		return false

	if not farm.has_method("get_icon_for_emoji"):
		return false

	var icon = farm.get_icon_for_emoji(emoji)
	if not icon:
		return false

	var north = icon.get("north", "")
	var south = icon.get("south", "")
	if north == "" or south == "":
		return false

	var biome = grid.get_biome_for_plot(selected_plots[0])
	if not biome:
		return false
	if not biome.viz_cache or not biome.viz_cache.has_metadata():
		return false
	if _get_qubit_count(biome) >= ActionCostRuntime.get_max_biome_qubits(farm):
		return false

	# Duplicate emojis are legal: an icon already in the biome can be injected
	# again as a degenerate instance — no presence gate.
	return true
static func _can_execute_remove_icon(farm, current_selection: Vector2i) -> bool:
	# Check if there is at least 2 qubits (minimum to remove one) and player can afford it.
	var grid = farm.get("grid") if farm else null
	if not grid or not farm.get("economy"):
		return false

	var biome = grid.get_biome_for_plot(current_selection)
	if not biome:
		return false
	if not biome.viz_cache or not biome.viz_cache.has_metadata():
		return false

	if _get_qubit_count(biome) < 2:
		return false

	var gate = ActionCostRuntime.preflight_action(farm, "remove_icon")
	return bool(gate.get("ok", false))


static func _can_execute_discover_biome(farm) -> bool:
	# Check if player can afford to explore a new biome.
	if not farm:
		return false
	var economy = farm.get("economy")
	if not economy:
		return false

	if farm.has_method("can_discover_biome"):
		var gate = farm.can_discover_biome()
		return gate.get("ok", false)

	var gate = ActionCostRuntime.preflight_action(farm, "discover_biome")
	return bool(gate.get("ok", false))


static func _can_execute_remove_biome(farm) -> bool:
	# Check if the currently active biome can be liquidated and removed.
	if not farm:
		return false
	if farm.has_method("can_remove_biome"):
		var gate = farm.can_remove_biome()
		return bool(gate.get("ok", false))
	return false


static func _get_qubit_count(biome) -> int:
	if not biome:
		return 0
	if biome.has_method("get_total_register_count"):
		var count = biome.get_total_register_count()
		if count > 0:
			return count
	return 0


static func _collect_known_icons(farm_ref) -> Array:
	if farm_ref and farm_ref.has_method("get_known_icons"):
		return farm_ref.get_known_icons()
	return []


static func _collect_injectable_icons(farm_ref, _biome = null) -> Array:
	# Known icons stay plantable even when already in the biome — duplicate
	# emojis are legal (degenerate instances), so there is no presence filter.
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
		var key = "%s|%s" % [north, south]
		if seen.has(key):
			continue
		seen[key] = true
		filtered.append({"north": north, "south": south})
	return filtered
