class_name QuantumInstrumentInput
extends Node

## QuantumInstrumentInput - Musical instrument spindle for quantum navigation
##
## Thin keyboard adapter over QuantumInstrument (game mechanics API).
## Handles keyboard input and updates PlotGridDisplay visual elements.
##
## A unified interface where plot selection, biome navigation, and quantum
## operations fuse into a single system. Creates a fractal address to game
## state through hierarchical navigation.
##
## Key Layout:
##   1 2 3 [4]    = Tool groups (time scale ratchet)
##
##   T Y U I O P  = Biome selection (6 spindle slots)
##   J K L ; ' H G = Homerow plot selection (up to 7 plots in current biome)
##   M , . /      = Reserved for future subspace navigation
##
##   Q = DOWN action (dig into, bind, construct)
##   E = NEUTRAL action (observe, balance, transfer)
##   R = UP action (extract, harvest, remove)
##   F = Mode cycling within tool group
##
##   - = Decrease stride and sim speed together
##   = = Increase stride and sim speed together
##   Shift+- = Decrease resolution dt (finer substeps, 10x more accurate)
##   Shift+= = Increase resolution dt (coarser substeps, 10x faster)

# Preloads
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const InputBindingRegistry = preload("res://UI/Core/InputBindingRegistry.gd")
const GridSentinel = preload("res://Core/GameState/GridSentinel.gd")
const ActionValidator = preload("res://UI/Core/ActionValidator.gd")
const GranularityController = preload("res://Core/Utils/GranularityController.gd")
const GateSelectionSubmenu = preload("res://UI/Core/Submenus/GateSelectionSubmenu.gd")
const InstrumentLocator = preload("res://Core/Instrumentation/InstrumentLocator.gd")

# Access autoloads safely
@onready var _verbose = InstrumentLocator.resolve_verbose_config(self)
@onready var _observation_frame = InstrumentLocator.resolve_observation_frame(self)
@onready var _chain_tracker = InstrumentLocator.resolve_action_chain_tracker(self)
@onready var _active_biome_mgr = InstrumentLocator.resolve_active_biome_manager(self)

# Instrument reference (game mechanics API, injected by BootManager)
var _instrument  # QuantumInstrument

# UI references (projection targets)
var farm  # Farm instance
var plot_grid_display  # PlotGridDisplay reference for visual selection

# Selection state (current plot/biome/subspace selection)
var current_selection: Dictionary = {"plot_idx": -1, "biome": "", "subspace_idx": -1}

var _current_submenu: Dictionary = {}  # Local UI cache for signal emission
var _in_submenu: bool = false  # Local UI cache for signal emission
var _submenu_page: int = 0  # Local UI cache for signal emission

# Signals
signal action_performed(action: String, result: Dictionary)
signal selection_changed(plot_idx: int, biome: String)
signal biome_switched(old_biome: String, new_biome: String)
signal tool_group_changed(group: int)
signal mode_cycled(group: int, mode_index: int, mode_label: String)
signal submenu_changed(submenu_name: String, submenu_actions: Dictionary)
signal plot_checked(grid_pos: Vector2i, is_checked: bool)  # Multi-select checkbox toggled

# Actions that modify density matrix at phrame 0 (require buffer invalidation)
const BUFFER_INVALIDATING_ACTIONS: Array[String] = [
	# Tool 1: Unitary gates (apply gates to density matrix)
	"rotate_up", "rotate_down", "hadamard",
	# Tool 2: Lindbladian (energy exchange modifies state)
	"drain", "transfer", "pump",
	# Tool 3: Measure (collapse wavefunction + build entangled states)
	"measure", "build_gate", "remove_gates",
# Tool 4: Meta (system expansion/contraction adds/removes qubits)
	"inject_vocabulary", "remove_vocabulary"
]


func _ready() -> void:
	add_to_group("quantum_instrument_input")
	set_process_unhandled_key_input(true)
	InputBindingRegistry.ensure_inputmap_actions()

	_verbose.info("input", "~", "QuantumInstrumentInput initialized (Homerow + Biome Selection)")


## ============================================================================
## INJECTION
## ============================================================================

func inject_farm(farm_ref) -> void:
	"""Inject farm reference for action execution."""
	farm = farm_ref
	_verbose.info("input", "~", "Farm injected into QuantumInstrumentInput")


func inject_plot_grid_display(pgd_ref) -> void:
	"""Inject PlotGridDisplay reference for visual selection updates."""
	plot_grid_display = pgd_ref
	_verbose.info("input", "~", "PlotGridDisplay injected into QuantumInstrumentInput")


func inject_instrument(inst) -> void:
	"""Inject QuantumInstrument reference for game mechanics delegation."""
	_instrument = inst
	# Forward instrument's plot_check_changed to QII's plot_checked signal
	if _instrument.has_signal("plot_check_changed"):
		_instrument.plot_check_changed.connect(func(pos, checked): plot_checked.emit(pos, checked))
	_verbose.info("input", "~", "QuantumInstrument injected into QuantumInstrumentInput")


## ============================================================================
## SELECTION STATE (for save/load)
## ============================================================================

func get_checked_plots() -> Array[Vector2i]:
	"""Get current checked plot positions (for save/load)."""
	if _instrument:
		return _instrument.get_checked_plots()
	return []


func set_checked_plots(positions: Array) -> void:
	"""Set checked plot positions (for save/load restoration)."""
	if _instrument:
		_instrument.set_checked_plots(positions)
	_verbose.debug("input", "✅", "Restored %d checked plots from save" % positions.size())


## ============================================================================
## INPUT HANDLING
## ============================================================================

func _unhandled_key_input(event: InputEvent) -> void:
	"""Handle keyboard input for the quantum instrument."""
	if not event is InputEventKey or not event.pressed:
		return
	if event.echo:
		return

	var key = _keycode_to_string(event.keycode)

	# Auto-close submenu when any non-action key is pressed
	if _instrument.is_in_submenu() and key not in ["Q", "E", "R", "F"]:
		_close_submenu()

	# Tool group selection: 1, 2, 3, 4
	if key in ["1", "2", "3", "4"]:
		_select_tool_group(int(key))
		get_viewport().set_input_as_handled()
		return

	# Timescale controls: -/= = stride + sim speed, Shift+-/Shift+= = resolution (dt)
	if key == "-":
		if event.is_shift_pressed():
			_decrease_resolution()
		else:
			_decrease_time_controls()
		get_viewport().set_input_as_handled()
		return
	if key == "=":
		if event.is_shift_pressed():
			_increase_resolution()
		else:
			_increase_time_controls()
		get_viewport().set_input_as_handled()
		return

	# Action keys
	match key:
		"Q", "E", "R":
			if _instrument.is_in_submenu():
				_handle_submenu_action(key)
			else:
				if event.is_shift_pressed():
					_perform_shift_key_action(key)
				else:
					_perform_action(key)
			get_viewport().set_input_as_handled()
		"F":
			if _instrument.is_in_submenu():
				_cycle_submenu_page()
			elif ToolConfig.has_f_cycling(ToolConfig.get_current_group()):
				_cycle_mode()
			else:
				var f_action = ToolConfig.get_action(ToolConfig.get_current_group(), "F")
				if not f_action.is_empty():
					_perform_action("F")
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	"""Handle InputMap actions for biome/plot/subspace selection."""
	if _handle_biome_row_input(event):
		get_viewport().set_input_as_handled()
		return

	if _handle_plot_row_input(event):
		get_viewport().set_input_as_handled()
		return

	if _handle_subspace_row_input(event):
		get_viewport().set_input_as_handled()
		return


func _handle_biome_row_input(event: InputEvent) -> bool:
	for i in range(InputBindingRegistry.BIOME_ACTIONS.size()):
		if not event.is_action_pressed(InputBindingRegistry.BIOME_ACTIONS[i]):
			continue

		var key_label = InputBindingRegistry.BIOME_ACTIONS[i]
		if _active_biome_mgr:
			var slot_key = _active_biome_mgr.get_slot_key(i)
			if slot_key != "":
				key_label = slot_key

		_select_biome(i, key_label)
		return true

	return false


func _handle_plot_row_input(event: InputEvent) -> bool:
	for i in range(InputBindingRegistry.HOMEROW_ACTIONS.size()):
		if not event.is_action_pressed(InputBindingRegistry.HOMEROW_ACTIONS[i]):
			continue

		_select_plot(i, InputBindingRegistry.HOMEROW_ACTIONS[i])
		return true

	return false


func _handle_subspace_row_input(event: InputEvent) -> bool:
	for i in range(InputBindingRegistry.SUBSPACE_ACTIONS.size()):
		if not event.is_action_pressed(InputBindingRegistry.SUBSPACE_ACTIONS[i]):
			continue

		_select_subspace(i, InputBindingRegistry.SUBSPACE_ACTIONS[i])
		return true

	return false


## ============================================================================
## TOOL GROUP MANAGEMENT
## ============================================================================

func _select_tool_group(group_num: int) -> void:
	"""Select a tool group (1-4)."""
	ToolConfig.select_group(group_num)
	tool_group_changed.emit(group_num)

	var group_name = ToolConfig.get_group_name(group_num)
	var mode_label = ToolConfig.get_group_mode_label(group_num)
	var display = group_name
	if mode_label != "":
		display = "%s [%s]" % [group_name, mode_label]
	_verbose.info("input", "~", "Tool: %s" % display)


func _cycle_mode() -> void:
	"""Cycle F-mode for current tool group."""
	var current_group = ToolConfig.get_current_group()
	if not ToolConfig.has_f_cycling(current_group):
		_verbose.debug("input", "~", "No F-cycling for group %d" % current_group)
		return

	var new_index = ToolConfig.cycle_group_mode(current_group)
	var mode_label = ToolConfig.get_group_mode_label(current_group)
	var mode_emoji = ToolConfig.get_group_mode_emoji(current_group)

	mode_cycled.emit(current_group, new_index, mode_label)
	_verbose.info("input", "~", "Mode: %s (%s)" % [mode_label, mode_emoji])


## ============================================================================
## CONTEXT BUILDING (for headless state)
## ============================================================================

func _build_context_dict() -> Dictionary:
	"""Build context dictionary for headless state operations."""
	var biome = _get_current_biome()
	var position = _instrument.last_selected_position

	return {
		"farm": farm,
		"biome": biome,
		"position": position,
		"economy": farm.economy if farm else null,
		"selection": _instrument.checked_plots  # Use headless state
	}


## ============================================================================
## SUBMENU HANDLING
## ============================================================================

func _open_submenu_for_action(action_info: Dictionary) -> void:
	"""Open a submenu for an action.

	Args:
		action_info: Action info dictionary from ToolConfig containing "submenu" field
	"""
	var submenu_name = action_info.get("submenu", "")
	if submenu_name.is_empty():
		_verbose.warn("input", "📋", "Action has submenu field but name is empty")
		return

	# Enter submenu using headless state
	var context = _build_context_dict()
	var submenu_data = _instrument.enter_submenu(submenu_name, context)

	# Update local submenu cache for UI signal emission
	_current_submenu = submenu_data
	_in_submenu = true
	_submenu_page = 0

	# Emit signals and log
	if submenu_name == "vocab_injection":
		_verbose.info("input", "📋", "Opened vocab injection submenu")
		var submenu_actions = submenu_data.get("actions", {})
		submenu_changed.emit(submenu_name, submenu_actions)

		# Debug: Print submenu contents
		if not submenu_data.is_empty():
			var actions = submenu_data.get("actions", {})
			_verbose.info("input", "📋", "Submenu has %d actions (Q/E/R)" % actions.size())
			for key in ["Q", "E", "R"]:
				if actions.has(key):
					var action = actions[key]
					var label = action.get("label", "")
					var affinity = action.get("affinity", 0.0)
					_verbose.info("input", "📋", "  %s: %s (affinity: %.2f)" % [key, label, affinity])
		else:
			_verbose.warn("input", "📋", "Submenu is empty!")

	elif submenu_name == "gate_selection":
		var selection_count = _instrument.checked_plots.size()
		_verbose.info("input", "⚛️", "Opened gate selection submenu (%d qubits selected)" % selection_count)
		var submenu_actions = submenu_data.get("actions", {})
		submenu_changed.emit(submenu_name, submenu_actions)

		# Debug: Print gate options
		if not submenu_data.is_empty():
			var actions = submenu_data.get("actions", {})
			for key in ["Q", "E", "R"]:
				if actions.has(key):
					var action = actions[key]
					var label = action.get("label", "")
					var gate_type = action.get("gate_type", "")
					_verbose.debug("input", "⚛️", "  %s: %s (%s)" % [key, label, gate_type])


func _generate_vocab_injection_submenu() -> Dictionary:
	"""Generate the vocab injection submenu dynamically."""
	var VocabInjectionSubmenu = preload("res://UI/Core/Submenus/VocabInjectionSubmenu.gd")
	if not farm:
		_verbose.warn("input", "📋", "Farm not available")
		return {}

	var biome = _get_current_biome()
	if not biome:
		_verbose.warn("input", "📋", "No current biome")
		return {}

	return VocabInjectionSubmenu.generate_submenu(biome, farm, _submenu_page)


func _generate_gate_selection_submenu() -> Dictionary:
	"""Generate the gate selection submenu dynamically based on _instrument.checked_plots."""
	if not farm:
		_verbose.warn("input", "⚛️", "Farm not available")
		return {}

	var biome = _get_current_biome()
	if not biome:
		_verbose.warn("input", "⚛️", "No current biome")
		return {}

	# Pass _instrument.checked_plots as selection (preserves order)
	var selection: Array = []
	for pos in _instrument.checked_plots:
		selection.append(pos)

	return GateSelectionSubmenu.generate_submenu(biome, farm, selection, _submenu_page)


func _cycle_submenu_page() -> void:
	"""Cycle to next page in paginated submenu (F key)."""
	if not _instrument.is_in_submenu():
		return

	var max_pages = _instrument.current_submenu_data.get("max_pages", 1)
	if max_pages <= 1:
		_verbose.debug("input", "📋", "Only 1 page in submenu")
		return

	# Cycle page using headless state
	var context = _build_context_dict()
	var result = _instrument.cycle_submenu_page(context)

	# Update local submenu cache
	_current_submenu = result.submenu_data
	_submenu_page = result.page

	_verbose.info("input", "📋", "Submenu page %d/%d" % [result.page + 1, result.max_pages])
	submenu_changed.emit(result.submenu_name, result.submenu_data.get("actions", {}))


func _close_submenu() -> void:
	"""Close the active submenu and reset all submenu state."""
	_instrument.exit_submenu()
	_in_submenu = false
	_current_submenu = {}
	submenu_changed.emit("", {})


func _handle_submenu_action(action_key: String) -> void:
	"""Handle Q/E/R actions while in a submenu.

	Args:
		action_key: "Q", "E", or "R"
	"""
	if _current_submenu.is_empty():
		_verbose.warn("input", "📋", "No submenu active")
		return

	var actions = _current_submenu.get("actions", {})
	var action_data = actions.get(action_key, {})

	if action_data.is_empty():
		_verbose.info("input", "📋", "You pressed %s - no option in that slot" % action_key)
		_verbose.info("input", "📋", "Available options: Q=%s E=%s R=%s" % [
			"✓" if actions.has("Q") else "✗",
			"✓" if actions.has("E") else "✗",
			"✓" if actions.has("R") else "✗"
		])
		return  # Stay in submenu

	# Check if option is disabled
	if not action_data.get("enabled", true):
		_verbose.info("input", "📋", "Option disabled: %s" % action_data.get("label", ""))
		return  # Stay in submenu

	var action = action_data.get("action", "")

	# Handle vocab_injection submenu actions
	if action == "inject_vocabulary":
		var vocab_pair = action_data.get("vocab_pair", {})
		var label = action_data.get("label", "")
		if not vocab_pair.is_empty():
			_verbose.info("input", "📋", "You selected: %s - injecting..." % label)
			_execute_inject_vocabulary(vocab_pair)

	# Handle gate_selection submenu actions
	elif action == "build_gate":
		var gate_type = action_data.get("gate_type", "bell")
		var label = action_data.get("label", gate_type)
		var qubits_required = action_data.get("qubits_required", 2)
		_verbose.info("input", "⚛️", "Building %s gate (requires %d qubits)" % [label, qubits_required])
		_execute_build_gate(gate_type)

	_close_submenu()


func _execute_inject_vocabulary(vocab_pair: Dictionary) -> void:
	"""Execute vocabulary injection with user-selected pair.

	Args:
		vocab_pair: {north: String, south: String}
	"""
	var biome = _get_current_biome()
	if not biome:
		_verbose.warn("input", "+", "No biome for vocab injection")
		return
	var result = _instrument.action_inject_vocabulary_pair(biome.get_biome_type(), vocab_pair)
	var cost = result.get("cost", {})
	if result.get("success", false):
		_verbose.info("input", "+", "Injected vocab %s/%s into %s" % [
			vocab_pair.get("north", ""),
			vocab_pair.get("south", ""),
			biome.name
		])

		# Invalidate buffer (vocab injection adds qubits, modifies density matrix)
		_invalidate_biome_buffer_for_action("inject_vocabulary")

		action_performed.emit("inject_vocabulary", {
			"success": true,
			"north_emoji": vocab_pair.get("north", ""),
			"south_emoji": vocab_pair.get("south", ""),
			"cost": cost,
			"biome": biome.name
		})
	else:
		_verbose.warn("input", "+", "Vocab injection failed: %s" % result.get("message", result.get("error", "unknown")))
		action_performed.emit("inject_vocabulary", result)


func _execute_build_gate(gate_type: String) -> void:
	"""Execute gate building with the specified gate type.

	Args:
		gate_type: Type of gate to build (bell, cnot, cz, swap, ghz, cluster)
	"""
	# Use _instrument.checked_plots as selection (order preserved)
	var positions: Array[Vector2i] = []
	for pos in _instrument.checked_plots:
		positions.append(pos)

	if positions.size() < 2:
		_verbose.warn("input", "⚛️", "Need 2+ qubits selected for %s gate" % gate_type)
		action_performed.emit("build_gate", {"success": false, "error": "need_more_qubits"})
		return

	var result: Dictionary = {}
	if _instrument and _instrument.has_method("gate_inject"):
		result = _instrument.gate_inject(gate_type, positions)
	else:
		_verbose.warn("input", "⚛️", "Gate build unavailable: no instrument gate dispatch")
		result = {"success": false, "error": "no_gate_dispatch", "gate_type": gate_type}

	if result.get("success", false):
		_verbose.info("input", "⚛️", "Built %s gate on %d qubits" % [gate_type, positions.size()])

		# Clear selections after successful gate build
		clear_all_checks()
	else:
		_verbose.warn("input", "⚛️", "Failed to build %s: %s" % [gate_type, result.get("error", result.get("message", "unknown"))])

	action_performed.emit("build_gate", result)


func apply_chain_gate(positions) -> void:
	"""Apply gate from chain swipe gesture.
	Populates _instrument.checked_plots, then executes gate build.
	Default: bell (2 bubbles) or cluster (3+ bubbles).
	"""
	clear_all_checks()
	for pos in positions:
		_instrument.checked_plots.append(pos)
		plot_checked.emit(pos, true)

	var gate_type = "bell" if positions.size() == 2 else "cluster"
	_execute_build_gate(gate_type)


## ============================================================================
## BIOME SELECTION (TYUIOP Row)
## ============================================================================

func _select_biome(biome_idx: int, key: String) -> void:
	"""Select a biome from the TYUIOP row.

	Args:
		biome_idx: Which biome (0-5) was selected (T=0, Y=1, U=2, I=3, O=4, P=5)
		key: The key that was pressed (for logging)
	"""
	if not _active_biome_mgr:
		_verbose.warn("input", "~", "ActiveBiomeManager not available")
		return

	var new_biome = _active_biome_mgr.get_biome_for_slot(biome_idx)
	if new_biome == "":
		_verbose.info("input", "•", "Biome slot %s unassigned" % key)
		return

	var old_biome = _active_biome_mgr.get_active_biome()

	# Switch active biome
	_active_biome_mgr.set_active_biome(new_biome)

	# Update current selection to reflect new biome
	_instrument.current_biome = new_biome

	# Record in chain tracker
	if _chain_tracker:
		_chain_tracker.record_observation(key, -1, new_biome, 0)

	# Emit signal
	biome_switched.emit(old_biome, new_biome)
	_verbose.info("input", "~", "Biome: %s → %s" % [old_biome, new_biome])


## ============================================================================
## PLOT SELECTION (Shared Homerow)
## ============================================================================

func _select_plot(plot_idx: int, key: String) -> void:
	"""Select or toggle a plot in the current biome.

	Args:
		plot_idx: Which plot index was selected (0..N-1)
		key: The key that was pressed (for chain tracking)
	"""
	if not _active_biome_mgr:
		_verbose.warn("input", "~", "ActiveBiomeManager not available")
		return

	# Guard against out-of-range plot indices
	if farm and farm.grid_config and plot_idx >= farm.grid_config.grid_width:
		_verbose.debug("input", "•", "Plot %d outside grid width %d" % [plot_idx, farm.grid_config.grid_width])
		return
	var register_count = _get_active_biome_register_count()
	if register_count > 0 and plot_idx >= register_count:
		_verbose.debug("input", "•", "Plot %d exceeds registers (%d)" % [plot_idx, register_count])
		return

	# Get current active biome
	var biome_name = _active_biome_mgr.get_active_biome()
	var target_grid_pos = _get_grid_position_for(plot_idx, biome_name)
	var was_highlighted = (
		_instrument.current_plot_idx == plot_idx and
		_instrument.current_biome == biome_name
	)

	# Record the observation in the chain tracker
	if _chain_tracker:
		_chain_tracker.record_observation(key, plot_idx, biome_name, 0)

	# Second tap on the highlighted plot toggles only the checkbox state.
	if was_highlighted:
		if target_grid_pos.x >= 0:
			toggle_check(target_grid_pos)
		_verbose.debug("input", "~", "Plot %d in %s remains highlighted" % [plot_idx, biome_name])
		return

	# First tap on a different plot moves the highlight there.
	current_selection = {
		"plot_idx": plot_idx,
		"biome": biome_name,
		"subspace_idx": -1
	}
	_instrument.current_plot_idx = plot_idx
	_instrument.current_biome = biome_name
	_instrument.last_selected_position = target_grid_pos

	_verbose.debug("input", "📍", "SELECTION DEBUG: plot_idx=%d, biome=%s → grid_pos=%s" % [plot_idx, biome_name, target_grid_pos])

	if plot_grid_display and farm and target_grid_pos.x >= 0:
		plot_grid_display.set_selected_plot(target_grid_pos)
		_verbose.debug("input", "~", "Visual selection: %s" % target_grid_pos)

	selection_changed.emit(plot_idx, biome_name)
	_verbose.debug("input", "~", "Plot %d in %s" % [plot_idx, biome_name])

	# Highlighting a plot ensures it joins the checked set, but does not
	# disturb any other checked plots already participating in batch actions.
	if target_grid_pos.x >= 0 and not _instrument.checked_plots.has(target_grid_pos):
		toggle_check(target_grid_pos)


## ============================================================================
## MULTI-SELECT SYSTEM (Checkboxes)
## ============================================================================

func toggle_check(grid_pos: Vector2i) -> void:
	"""Toggle checkmark for multi-select at given grid position.

	Args:
		grid_pos: Grid position to toggle (Vector2i(plot_idx, biome_row))
	"""
	if grid_pos.x < 0 or grid_pos.y < 0:
		return  # Invalid position

	var was_checked = grid_pos in _instrument.checked_plots

	if was_checked:
		# Uncheck: remove from list
		_instrument.checked_plots.erase(grid_pos)
		_verbose.debug("input", "☐", "Unchecked plot at %s" % grid_pos)
	else:
		# Check: add to list
		_instrument.checked_plots.append(grid_pos)
		_verbose.debug("input", "☑", "Checked plot at %s (total: %d)" % [grid_pos, _instrument.checked_plots.size()])

	# Emit signal so PlotGridDisplay can update visual checkbox
	plot_checked.emit(grid_pos, not was_checked)


func clear_all_checks() -> void:
	"""Clear all checkmarks (useful for batch operation completion)."""
	for pos in _instrument.checked_plots.duplicate():  # Duplicate to avoid modification during iteration
		plot_checked.emit(pos, false)
	_instrument.checked_plots.clear()
	_verbose.debug("input", "☐", "Cleared all checkmarks")


func _clear_checks_and_cycle_biome() -> void:
	"""Shift+4E: Full quantum reset + cycle to next biome (fresh start).

	Performs:
	- Clear all checkmarks
	- Deselect all plots
	- Reset selection state
	- Reset quantum simulation (if available)
	- Cycle to next biome
	"""
	_verbose.info("input", "⇧4E", "QUANTUM RESET + CYCLE - Clearing selections and cycling biome")

	# Clear all checkmarks
	clear_all_checks()

	# Deselect all plots visually
	if plot_grid_display:
		plot_grid_display.set_selected_plot(GridSentinel.INVALID_POSITION)

	# Reset current selection state
	current_selection = {"plot_idx": -1, "biome": "", "subspace_idx": -1}
	_instrument.last_selected_position = GridSentinel.INVALID_POSITION

	# Reset quantum simulation (if farm has reset method)
	if farm and farm.has_method("reset_quantum_state"):
		farm.reset_quantum_state()
		_verbose.info("input", "⚛️", "Quantum state reset")
	else:
		_verbose.debug("input", "~", "No quantum reset method available (farm.reset_quantum_state)")

	# Cycle to next biome
	var result = _instrument.action_cycle_biome() if _instrument else {"success": false}
	if result.get("success", false):
		_verbose.info("input", "✓", "Reset complete + cycled to %s" % result.get("new_biome", "next biome"))
	else:
		_verbose.warn("input", "⚠️", "Failed to cycle biome: %s" % result.get("message", "unknown"))


## ============================================================================
## SUBSPACE SELECTION (M,./ Row - Reserved)
## ============================================================================

func _select_subspace(subspace_idx: int, key: String) -> void:
	"""Select a subspace within the current biome (reserved for future).

	Args:
		subspace_idx: Which subspace (0-3) was selected
		key: The key that was pressed (for logging)
	"""
	_verbose.debug("input", "~", "Subspace selection reserved for future (idx: %d)" % subspace_idx)

	# Update current selection to track subspace
	_instrument.current_subspace_idx = subspace_idx

	# TODO: Implement subspace navigation when needed


## ============================================================================
## ACTION EXECUTION
## ============================================================================

func _perform_action(action_key: String) -> void:
	"""Execute the action mapped to Q/E/R for current tool group.

	Args:
		action_key: "Q" (DOWN), "E" (NEUTRAL), or "R" (UP)
	"""
	var current_group = ToolConfig.get_current_group()
	var action_info = ToolConfig.get_action(current_group, action_key)

	if action_info.is_empty():
		_verbose.debug("input", "~", "No action for %s in group %d" % [action_key, current_group])
		return

	var emoji = action_info.get("emoji", "")
	_verbose.info("input", emoji, "%s" % action_info.get("label", ""))

	# Check if this action opens a submenu
	if action_info.has("submenu"):
		_verbose.debug("input", "📋", "Opening submenu: %s" % action_info["submenu"])
		_open_submenu_for_action(action_info)
		return

	var action_name = action_info.get("action", "")
	if action_name == "":
		return

	if not ActionValidator.can_execute_action_name(
		action_name, farm, _get_selected_positions(), _get_grid_position()
	):
		_verbose.info("input", "•", "%s blocked%s" % [
			action_info.get("label", action_name),
			_get_block_reason(action_name)
		])
		return

	_run_action(action_name, emoji if emoji != "" else action_name, action_info.get("label", action_name))


func _get_block_reason(action_name: String) -> String:
	"""Return a human-readable reason why an action is blocked, or '' if unknown."""
	if action_name != "explore" or not farm:
		return ""
	var grid = farm.get("grid")
	var biome = grid.get_biome_for_plot(_get_grid_position()) if grid else null
	if not biome:
		return ""
	var terminal_pool = farm.get("terminal_pool")
	var free = biome.get_available_registers(terminal_pool) if biome.has_method("get_available_registers") and terminal_pool else []
	if free.is_empty():
		var name = biome.get_biome_type() if biome.has_method("get_biome_type") else "biome"
		var total = biome.get_total_register_count() if biome.has_method("get_total_register_count") else -1
		var used = total - free.size() if total >= 0 else -1
		if total >= 0 and used >= 0:
			return ": %s full (%d/%d registers in use) — empty plots are just sockets; pop a terminal to free a register" % [name, used, total]
		return ": %s full — empty plots are just sockets; pop a terminal to free a register" % name
	return ""


func _perform_shift_key_action(action_key: String) -> void:
	"""Apply the Q/E/R action across all checked plots (multi-select batch operation).

	For gate actions (Tool 1: Unitary), uses batch injection with single buffer invalidation.
	Selection order is preserved - gates are applied in the order plots were checked.
	"""
	var current_group = ToolConfig.get_current_group()
	var action_info = ToolConfig.get_action(current_group, action_key)
	if action_info.is_empty():
		return

	# Use shift_action if defined, otherwise use normal action
	var action_name = action_info.get("shift_action", action_info.get("action", ""))
	if action_name == "":
		return

	var symbol = "⇧%s" % action_key
	var log_label = action_info.get("shift_label", action_info.get("label", action_name))

	var original_selection = current_selection.duplicate()

	# Use checked plots instead of entire homerow (ORDER PRESERVED from selection)
	var positions = _instrument.checked_plots.duplicate()
	if positions.is_empty():
		_verbose.debug("input", "⚠️", "No plots checked - Shift+action requires checked plots")
		return

	# BATCH GATE PATH: For Tool 1 (Unitary) gate actions, use batch injection
	# This applies all gates in selection order with SINGLE buffer invalidation
	if _is_gate_action(action_name):
		_perform_batch_gate_action(action_name, positions, symbol, log_label)
		_restore_selection(original_selection)
		return

	# NON-GATE PATH: Apply the action across checked positions
	_verbose.info("input", symbol, "Batch %s on %d checked plots" % [log_label, positions.size()])

	for pos in positions:
		_set_selection_for_grid_pos(pos)
		if not ActionValidator.can_execute_action_name(
			action_name, farm, _get_selected_positions(), _get_grid_position()
		):
			# For explore: if biome is full, stop iterating (all remaining plots will also fail)
			if action_name == "explore":
				var reason = _get_block_reason(action_name)
				if reason != "":
					_verbose.info("input", "•", "%s blocked%s" % [log_label, reason])
					break
			continue
		if action_name == "pop":
			_run_cleanup_action(action_name, symbol, log_label)
		else:
			_run_action(action_name, symbol, log_label)
		_refresh_plot_tiles([pos])
	_restore_selection(original_selection)


func _is_gate_action(action_name: String) -> bool:
	"""Check if action is a unitary gate operation (eligible for batch injection)."""
	return action_name in ["hadamard", "rotate_up", "rotate_down"]


func _perform_batch_gate_action(action_name: String, positions: Array, symbol: String, log_label: String) -> void:
	"""Apply gate action to multiple qubits using batch injection.

	Gates are applied in selection order (first checked = first gate applied).
	Buffer invalidation happens ONCE at the end, not per-gate.

	Args:
		action_name: Gate action (hadamard, rotate_up, rotate_down)
		positions: Array[Vector2i] of grid positions in selection order
		symbol: Log symbol
		log_label: Human-readable label
	"""
	const GateInjectorClass = preload("res://Core/QuantumSubstrate/GateInjector.gd")

	# Determine gate name from action
	var gate_name = _get_gate_name_for_action(action_name)
	if gate_name == "":
		_verbose.warn("input", "⚠️", "Unknown gate action: %s" % action_name)
		return

	# Collect gate operations in selection order
	var gate_ops: Array = []
	var order_log: Array = []

	for pos in positions:
		var biome = _get_biome_for_position(pos)
		if not biome or not biome.quantum_computer:
			continue

		var qubit = _get_qubit_for_position(pos, biome)
		if qubit < 0:
			continue

		gate_ops.append({
			"biome": biome,
			"qubit": qubit,
			"gate_name": gate_name
		})
		order_log.append("q%d" % qubit)

	if gate_ops.is_empty():
		_verbose.warn("input", "⚠️", "No valid qubits for batch gate")
		return

	_verbose.info("input", symbol, "Batch %s on %d qubits (order: %s)" % [
		log_label, gate_ops.size(), " → ".join(order_log)
	])

	# BATCH INJECTION: All gates applied, single buffer invalidation
	var result = GateInjectorClass.inject_gate_batch(gate_ops, farm)

	if result.success:
		_verbose.info("input", "✓", "Applied %d gates, order preserved: %s" % [
			result.applied_count, result.order
		])

		# Invalidate buffer ONCE after batch gate application
		if action_name in BUFFER_INVALIDATING_ACTIONS:
			_invalidate_biome_buffer_for_action(action_name)
	else:
		_verbose.warn("input", "✗", "Batch gate failed: %s" % result.get("error", "unknown"))

	action_performed.emit(action_name, result)
	_refresh_plot_tiles(positions)


func _get_gate_name_for_action(action_name: String) -> String:
	"""Map action name to gate library name."""
	match action_name:
		"hadamard":
			return "H"
		"rotate_up", "rotate_down":
			# Get axis from Tool 1 mode (X, Y, or Z)
			var axis = ToolConfig.get_group_mode_name(1)
			if axis == "":
				axis = "X"
			return "R" + axis.to_lower()  # Rx, Ry, or Rz
		_:
			return ""


func _get_biome_for_position(pos: Vector2i):
	"""Get biome for a grid position."""
	if not farm or not farm.grid:
		return null
	var biome_name = farm.get_biome_for_row(pos.y) if farm.has_method("get_biome_for_row") else ""
	if biome_name == "":
		return null
	return farm.grid.get_biome(biome_name)


func _get_qubit_for_position(pos: Vector2i, biome) -> int:
	"""Get qubit index for a grid position via plot/terminal binding."""
	if not farm or not farm.grid:
		return -1

	var plot = farm.grid.get_plot(pos)
	if plot and plot.is_active():
		var reg = plot.bound_register_id
		if reg >= 0:
			return reg
		# Fallback: try viz_cache lookup
		if biome and biome.viz_cache:
			return biome.viz_cache.get_qubit(plot.north_emoji)

	return -1


func _run_action(action_name: String, log_symbol: String, action_label: String) -> Dictionary:
	"""Execute an action and emit logging + signal."""
	var result = _execute_action(action_name)

	# Invalidate buffer if action modified density matrix at phrame 0
	if result.get("success", false) and action_name in BUFFER_INVALIDATING_ACTIONS:
		_invalidate_biome_buffer_for_action(action_name)

	_log_action_result(action_name, log_symbol, action_label, result)
	return result


func _run_cleanup_action(action_name: String, log_symbol: String, action_label: String) -> void:
	"""Execute a cleanup version of an action (e.g., pop cleanup)."""
	var result = _execute_cleanup_action(action_name)
	_log_action_result(action_name, log_symbol, action_label, result)


func _execute_cleanup_action(action_name: String) -> Dictionary:
	"""Execute cleanup variants for actions that require special handling.

	NOTE: Currently just calls _execute_action() for all actions.
	Previously had special handling for pop cleanup, now unified into standard action dispatch.
	"""
	return _execute_action(action_name)


func _log_action_result(action_name: String, log_symbol: String, action_label: String, result: Dictionary) -> void:
	var symbol = log_symbol if log_symbol != "" else action_name
	var label = action_label if action_label != "" else action_name
	if result.get("success", false):
		_verbose.info("input", symbol, "%s succeeded: %s" % [label, result])
	else:
		var message = result.get("message", "unknown")
		if result.get("blocked", false):
			_verbose.info("input", "•", "%s blocked: %s" % [label, message])
		else:
			_verbose.warn("input", "✗", "%s failed: %s" % [label, message])
	action_performed.emit(action_name, result)


func _invalidate_biome_buffer_for_action(action_name: String) -> void:
	"""Invalidate biome buffer after density matrix modification.

	When actions modify the density matrix at phrame 0, the lookahead buffer
	becomes invalid and must be recomputed. This triggers high-priority emergency refill.

	Args:
		action_name: Name of action that modified the density matrix
	"""
	# Get affected biome
	var biome = _get_current_biome()
	if not biome:
		_verbose.debug("input", "🔄", "No biome to invalidate for %s" % action_name)
		return

	var biome_name = biome.get_biome_type() if biome.has_method("get_biome_type") else biome.name

	# Get batcher reference from farm
	var batcher = farm.biome_evolution_batcher if farm and "biome_evolution_batcher" in farm else null
	if not batcher:
		_verbose.debug("input", "🔄", "No batcher available for buffer invalidation")
		return

	# Invalidate buffer (triggers emergency refill with high priority)
	if batcher.has_method("invalidate_biome_buffer"):
		batcher.invalidate_biome_buffer(biome_name)
		_verbose.info("input", "🔄", "Buffer invalidated for %s (action: %s)" % [biome_name, action_name])
	else:
		_verbose.warn("input", "⚠️", "Batcher missing invalidate_biome_buffer() method")


func _get_target_biome_for_granularity() -> Dictionary:
	"""Get the target biome for granularity control (-/= keys).

	Returns: {biome: Node, name: String, reason: String}

	Logic:
	- Main game: ActiveBiomeManager.get_active_biome() (currently selected biome)
	- VisualBubbleTest: get_last_generated_biome_name() (last biome created)
	"""
	if not farm or not farm.grid:
		return {"biome": null, "name": "", "reason": "no_farm"}

	# Check if we're in VisualBubbleTest (has get_last_generated_biome_name method)
	var scene_root = get_tree().current_scene
	if scene_root and scene_root.has_method("get_last_generated_biome_name"):
		var last_biome_name = scene_root.get_last_generated_biome_name()
		if last_biome_name.is_empty():
			return {"biome": null, "name": "", "reason": "test_no_biomes_generated"}
		var biome_obj = farm.grid.get_biome(last_biome_name)
		if biome_obj:
			return {"biome": biome_obj, "name": last_biome_name, "reason": "test_last_generated"}
		else:
			return {"biome": null, "name": last_biome_name, "reason": "test_biome_not_found"}

	# Main game: use ActiveBiomeManager
	if _active_biome_mgr:
		var active_biome_name = _active_biome_mgr.get_active_biome()
		if active_biome_name.is_empty():
			return {"biome": null, "name": "", "reason": "no_active_biome"}
		var biome_obj = farm.grid.get_biome(active_biome_name)
		if biome_obj:
			return {"biome": biome_obj, "name": active_biome_name, "reason": "active_biome"}
		else:
			return {"biome": null, "name": active_biome_name, "reason": "active_biome_not_found"}

	# Fallback: no valid selection
	return {"biome": null, "name": "", "reason": "no_selection_method"}


func _invalidate_single_biome_buffer(biome_name: String, reason: String) -> void:
	"""Invalidate a single biome's lookahead buffer after granularity change."""
	if not farm:
		_verbose.debug("input", "🔄", "No farm for buffer invalidation")
		return

	var batcher = farm.biome_evolution_batcher if "biome_evolution_batcher" in farm else null
	if not batcher:
		_verbose.debug("input", "🔄", "No batcher available for buffer invalidation")
		return

	if not batcher.has_method("invalidate_biome_buffer"):
		_verbose.warn("input", "⚠️", "Batcher missing invalidate_biome_buffer() method")
		return

	batcher.invalidate_biome_buffer(biome_name)
	_verbose.debug("input", "🔄", "[%s] Buffer invalidated: %s" % [biome_name, reason])


func _decimate_single_biome_buffer(biome_name: String, decimation_factor: int) -> void:
	"""Decimate a single biome's buffer when coarsening granularity."""
	if not farm:
		_verbose.debug("input", "✂️", "No farm for buffer decimation")
		return

	var batcher = farm.biome_evolution_batcher if "biome_evolution_batcher" in farm else null
	if not batcher:
		_verbose.debug("input", "✂️", "No batcher available for buffer decimation")
		return

	if not batcher.has_method("decimate_biome_buffer"):
		# Coarser granularity still needs buffer refresh even without decimation support.
		_verbose.warn("input", "⚠️", "Batcher missing decimate_biome_buffer() - invalidating biome buffer instead")
		_invalidate_single_biome_buffer(biome_name, "granularity_increase_refresh")
		return

	var new_depth = batcher.decimate_biome_buffer(biome_name, decimation_factor)
	_verbose.debug("input", "✂️", "[%s] Buffer decimated (1/%d) - preserved %d frames" % [
		biome_name, decimation_factor, new_depth
	])


func _reset_single_biome_stride_carry(biome_name: String) -> void:
	"""Reset stride dt carry so stride/resolution changes apply deterministically."""
	if not farm:
		return
	var batcher = farm.biome_evolution_batcher if "biome_evolution_batcher" in farm else null
	if batcher and batcher.has_method("reset_stride_carry"):
		batcher.reset_stride_carry(biome_name)


func _invalidate_all_biome_buffers(reason: String) -> void:
	"""Invalidate ALL biome buffers after global parameter changes.

	When simulation parameters change (granularity, time scale), all lookahead
	buffers become invalid because they were computed with old parameters.

	Args:
		reason: Reason for invalidation (for logging)
	"""
	if not farm or not farm.grid:
		_verbose.debug("input", "🔄", "No farm/grid for buffer invalidation")
		return

	# Get batcher reference from farm
	var batcher = farm.biome_evolution_batcher if "biome_evolution_batcher" in farm else null
	if not batcher:
		_verbose.debug("input", "🔄", "No batcher available for buffer invalidation")
		return

	# Check if batcher has the method
	if not batcher.has_method("invalidate_biome_buffer"):
		_verbose.warn("input", "⚠️", "Batcher missing invalidate_biome_buffer() method")
		return

	# Invalidate ALL biomes
	var biome_count = 0
	for biome_name in farm.grid.get_biome_names():
		batcher.invalidate_biome_buffer(biome_name)
		biome_count += 1

	_verbose.info("input", "🔄", "All %d biome buffers invalidated (reason: %s)" % [biome_count, reason])


func _decimate_all_biome_buffers(decimation_factor: int) -> void:
	"""Decimate ALL biome buffers when coarsening granularity.

	When dt doubles (2x coarser), existing frames are still valid but oversampled.
	Instead of full invalidation, keep every Nth frame to preserve computed work.

	Args:
		decimation_factor: Keep every Nth frame (2 for 2x coarsening)
	"""
	if not farm or not farm.grid:
		_verbose.debug("input", "✂️", "No farm/grid for buffer decimation")
		return

	var batcher = farm.biome_evolution_batcher if "biome_evolution_batcher" in farm else null
	if not batcher:
		_verbose.debug("input", "✂️", "No batcher available for buffer decimation")
		return

	if not batcher.has_method("decimate_biome_buffer"):
		# Coarser granularity still needs buffer refresh even without decimation support.
		_verbose.warn("input", "⚠️", "Batcher missing decimate_biome_buffer() - invalidating all biome buffers instead")
		_invalidate_all_biome_buffers("granularity_increase_refresh")
		return

	var biome_count = 0
	var total_preserved = 0
	for biome_name in farm.grid.get_biome_names():
		var new_depth = batcher.decimate_biome_buffer(biome_name, decimation_factor)
		total_preserved += new_depth
		biome_count += 1

	_verbose.info("input", "✂️", "All %d biome buffers decimated (1/%d) - preserved %d frames total" % [
		biome_count, decimation_factor, total_preserved
	])


func _execute_action(action_name: String) -> Dictionary:
	"""Execute a specific action by name. Delegates to QuantumInstrument."""
	if not farm or not _instrument:
		return {"success": false, "error": "no_farm", "message": "Farm or instrument not initialized"}

	var positions = _get_selected_positions()
	var grid_pos = _get_grid_position()
	var biome_name = _get_current_biome_name()

	var result: Dictionary
	match action_name:
		"rotate_up":
			result = _instrument.action_rotate(positions, 1)
		"rotate_down":
			result = _instrument.action_rotate(positions, -1)
		"hadamard":
			result = _instrument.action_hadamard(positions)
		"drain":
			result = _instrument.action_drain(positions)
			if result.get("success", false):
				_refresh_plot_tiles(positions)
		"transfer":
			result = _instrument.action_transfer(positions)
		"pump":
			result = _instrument.action_pump(positions)
			if result.get("success", false):
				_refresh_plot_tiles(positions)
		"explore":
			if positions.is_empty():
				result = {"success": false, "error": "no_positions", "message": "No plot selected"}
			else:
				result = _instrument.action_explore(biome_name, positions[0])
		"measure":
			result = _instrument.action_measure(grid_pos)
		"reap":
			result = _instrument.action_reap()
		"pop":
			result = _instrument.action_pop(grid_pos)
		"clear_all":
			result = _instrument.action_clear_all()
		"build_gate":
			result = _instrument.action_build_gate(positions)
		"inspect":
			result = _instrument.action_inspect(positions)
		"remove_gates":
			result = _instrument.action_remove_gates(positions)
		"inject_vocabulary":
			result = _instrument.action_inject_vocabulary(biome_name)
		"discover_biome":
			result = _instrument.action_discover_biome()
			if result.get("success", false):
				_select_tool_group(3)
		"cycle_biome", "toggle_view":
			result = _instrument.action_cycle_biome()
		"remove_vocabulary":
			result = _instrument.action_remove_vocabulary(biome_name, grid_pos)
		"remove_biome":
			result = _instrument.action_remove_biome()
		_:
			_verbose.warn("input", "?", "Unknown action: %s" % action_name)
			return {"success": false, "error": "unknown_action", "message": "Unknown action: %s" % action_name}

	return result


func _get_current_biome_name() -> String:
	"""Get the current biome name from instrument or ActiveBiomeManager."""
	if _instrument and _instrument.current_biome != "":
		return _instrument.current_biome
	if _active_biome_mgr:
		return _active_biome_mgr.get_active_biome()
	return ""




func _refresh_plot_tiles(positions: Array[Vector2i]) -> void:
	"""Refresh plot tiles after stateful actions."""
	if not plot_grid_display:
		return
	for pos in positions:
		if plot_grid_display.has_method("update_tile_from_farm"):
			plot_grid_display.update_tile_from_farm(pos)






## ============================================================================
## HELPER FUNCTIONS
## ============================================================================

func _get_current_biome():
	"""Get the biome for the current selection."""
	if not farm or not farm.grid:
		return null

	var biome_name = _instrument.current_biome if _instrument.current_biome != "" else ""
	if biome_name == "":
		biome_name = _active_biome_mgr.get_active_biome() if _active_biome_mgr else "BioticFlux"

	return farm.grid.get_biome(biome_name)


func _get_grid_position() -> Vector2i:
	"""Convert current selection to grid position."""
	var plot_idx = _instrument.current_plot_idx if _instrument.current_plot_idx >= 0 else 0
	var biome_name = _instrument.current_biome if _instrument.current_biome != "" else ""

	return _get_grid_position_for(plot_idx, biome_name)


func _get_grid_position_for(plot_idx: int, biome_name: String) -> Vector2i:
	"""Convert plot + biome selection to a grid position."""
	var biome_row = farm.get_biome_row(biome_name) if farm and farm.has_method("get_biome_row") else 0
	return Vector2i(plot_idx, biome_row)


func _get_active_biome_register_count() -> int:
	"""Get register (qubit) count for the currently active biome."""
	if not farm or not farm.grid or not _active_biome_mgr:
		return 0
	var biome_name = _active_biome_mgr.get_active_biome()
	if biome_name == "":
		return 0
	if not farm.grid.has_biome(biome_name):
		return 0
	var biome = farm.grid.get_biome(biome_name)
	if biome and biome.quantum_computer and biome.quantum_computer.register_map:
		return biome.quantum_computer.register_map.num_qubits
	return 0


func _get_selected_positions() -> Array[Vector2i]:
	"""Get array of selected positions (currently just single selection)."""
	var positions: Array[Vector2i] = []
	if _instrument.current_plot_idx >= 0:
		positions.append(_get_grid_position())
	return positions



func _get_homerow_positions() -> Array[Vector2i]:
	"""Return all plot positions for the current biome row (one per qubit/column)."""
	var positions: Array[Vector2i] = []
	var row = _get_current_biome_row()
	var width = farm.grid_config.grid_width if farm and farm.grid_config else 4
	for idx in range(width):
		positions.append(Vector2i(idx, row))
	return positions


func _get_current_biome_row() -> int:
	if not farm:
		return 0
	var biome_name = _instrument.current_biome if _instrument.current_biome != "" else ""
	if biome_name == "":
		biome_name = _active_biome_mgr.get_active_biome() if _active_biome_mgr else "StarterForest"
	if biome_name == "":
		biome_name = "StarterForest"
	if farm.has_method("get_biome_row"):
		return farm.get_biome_row(biome_name)
	return 0


func _set_selection_for_grid_pos(grid_pos: Vector2i) -> void:
	"""Update current_selection to match the specified grid position."""
	if not farm:
		return
	var biome_name = farm.get_biome_for_row(grid_pos.y) if farm.has_method("get_biome_for_row") else ""
	current_selection = {
		"plot_idx": grid_pos.x,
		"biome": biome_name,
		"subspace_idx": -1
	}
	_instrument.current_plot_idx = grid_pos.x
	_instrument.current_biome = biome_name


func _restore_selection(previous_selection: Dictionary) -> void:
	"""Restore the selection state and refresh visual highlight."""
	if previous_selection and previous_selection.has("plot_idx"):
		current_selection = previous_selection.duplicate()
	else:
		current_selection = {"plot_idx": -1, "biome": "", "subspace_idx": -1}

	_instrument.current_plot_idx = int(current_selection.get("plot_idx", -1))
	_instrument.current_biome = str(current_selection.get("biome", ""))

	if plot_grid_display and farm and _instrument.current_plot_idx >= 0:
		var grid_pos = _get_grid_position()
		if grid_pos.x >= 0:
			plot_grid_display.set_selected_plot(grid_pos)
			_instrument.last_selected_position = grid_pos


func _keycode_to_string(keycode: int) -> String:
	"""Convert keycode to string representation."""
	match keycode:
		KEY_0: return "0"
		KEY_1: return "1"
		KEY_2: return "2"
		KEY_3: return "3"
		KEY_4: return "4"
		KEY_Q: return "Q"
		KEY_E: return "E"
		KEY_R: return "R"
		KEY_F: return "F"
		KEY_T: return "T"
		KEY_Y: return "Y"
		KEY_U: return "U"
		KEY_I: return "I"
		KEY_O: return "O"
		KEY_P: return "P"
		KEY_H: return "H"
		KEY_G: return "G"
		KEY_J: return "J"
		KEY_K: return "K"
		KEY_L: return "L"
		KEY_SEMICOLON: return ";"
		KEY_APOSTROPHE: return "'"
		KEY_M: return "M"
		KEY_COMMA: return ","
		KEY_PERIOD: return "."
		KEY_SLASH: return "/"
		KEY_MINUS: return "-"
		KEY_EQUAL: return "="
		_: return ""




## ============================================================================
## PUBLIC API
## ============================================================================

func get_current_selection() -> Dictionary:
	"""Get current plot selection."""
	return current_selection.duplicate()


func can_execute_action(action_key: String) -> bool:
	"""Check if action can succeed with current selection (for UI highlighting)."""
	if current_selection.get("plot_idx", -1) < 0:
		return false
	if not farm:
		return false

	var selected_positions = _get_selected_positions()
	var current_pos = _get_grid_position()
	return ActionValidator.can_execute_action(
		action_key,
		ToolConfig.get_current_group(),
		"",
		{},
		farm,
		selected_positions,
		current_pos
	)


func get_current_tool_group() -> int:
	"""Get current tool group number."""
	return ToolConfig.get_current_group()


func get_current_tool_info() -> Dictionary:
	"""Get info about current tool group."""
	var group = ToolConfig.get_current_group()
	return {
		"group": group,
		"name": ToolConfig.get_group_name(group),
		"emoji": ToolConfig.get_group_emoji(group),
		"time_scale": ToolConfig.get_group_time_scale(group),
		"mode": ToolConfig.get_group_mode_name(group),
		"mode_label": ToolConfig.get_group_mode_label(group),
		"mode_emoji": ToolConfig.get_group_mode_emoji(group)
	}


func get_actions_for_current_group() -> Dictionary:
	"""Get current action slots for the active tool group."""
	return ToolConfig.get_all_actions(ToolConfig.get_current_group())


## ============================================================================
## TIMESCALE CONTROLS (stride + resolution)
## ============================================================================

func _decrease_time_controls() -> void:
	"""Decrease stride and simulation speed together (- key)."""
	if not farm or not farm.grid:
		_verbose.warn("input", "⚠️", "Cannot adjust time controls - no farm/grid")
		return

	var target_biome_info = _get_target_biome_for_granularity()
	if not target_biome_info.has("biome") or target_biome_info.biome == null:
		_verbose.warn("input", "⚠️", "No target biome for time controls: %s" % target_biome_info.get("reason", "unknown"))
		return

	var target_biome = target_biome_info.biome
	var target_biome_name = target_biome_info.name

	var stride_result = GranularityController.decrease_stride([target_biome])
	var speed_result = GranularityController.decrease_time_scale([target_biome])
	_reset_single_biome_stride_carry(target_biome_name)

	_persist_runtime_timescale(stride_result.new_stride, speed_result.new_time_scale)

	var locked_str = " (LOCKED)" if stride_result.new_stride == 0 else ""
	_verbose.info("input", "⏪", "[%s] Time: stride %d → %d%s | sim %.5fx → %.5fx" % [
		target_biome_name,
		stride_result.current_stride,
		stride_result.new_stride,
		locked_str,
		speed_result.current_time_scale,
		speed_result.new_time_scale
	])


func _increase_time_controls() -> void:
	"""Increase stride and simulation speed together (= key)."""
	if not farm or not farm.grid:
		_verbose.warn("input", "⚠️", "Cannot adjust time controls - no farm/grid")
		return

	var target_biome_info = _get_target_biome_for_granularity()
	if not target_biome_info.has("biome") or target_biome_info.biome == null:
		_verbose.warn("input", "⚠️", "No target biome for time controls: %s" % target_biome_info.get("reason", "unknown"))
		return

	var target_biome = target_biome_info.biome
	var target_biome_name = target_biome_info.name

	var stride_result = GranularityController.increase_stride([target_biome])
	var speed_result = GranularityController.increase_time_scale([target_biome])
	_reset_single_biome_stride_carry(target_biome_name)

	_persist_runtime_timescale(stride_result.new_stride, speed_result.new_time_scale)

	var unlocked_str = " (UNLOCKED)" if stride_result.current_stride == 0 and stride_result.new_stride == 1 else ""
	_verbose.info("input", "⏩", "[%s] Time: stride %d → %d%s | sim %.5fx → %.5fx" % [
		target_biome_name,
		stride_result.current_stride,
		stride_result.new_stride,
		unlocked_str,
		speed_result.current_time_scale,
		speed_result.new_time_scale
	])

func _decrease_stride() -> void:
	"""Decrease observation stride - slower playback (- key).

	PER-BIOME CONTROL:
	- Main game: Affects only the currently selected biome (ActiveBiomeManager)
	- VisualBubbleTest: Affects only the last biome that was generated
	"""
	if not farm or not farm.grid:
		_verbose.warn("input", "⚠️", "Cannot adjust stride - no farm/grid")
		return

	var target_biome_info = _get_target_biome_for_granularity()
	if not target_biome_info.has("biome") or target_biome_info.biome == null:
		_verbose.warn("input", "⚠️", "No target biome for stride control: %s" % target_biome_info.get("reason", "unknown"))
		return

	var target_biome = target_biome_info.biome
	var target_biome_name = target_biome_info.name

	var result = GranularityController.decrease_stride([target_biome])
	_reset_single_biome_stride_carry(target_biome_name)

	# Persist to GameState so stride survives save/load
	_persist_runtime_timescale(result.new_stride, null)

	var locked_str = " (LOCKED)" if result.new_stride == 0 else ""
	_verbose.info("input", "⏪", "[%s] Stride: %d → %d%s" % [
		target_biome_name, result.current_stride, result.new_stride, locked_str
	])


func _increase_stride() -> void:
	"""Increase observation stride - faster playback (= key).

	PER-BIOME CONTROL:
	- Main game: Affects only the currently selected biome (ActiveBiomeManager)
	- VisualBubbleTest: Affects only the last biome that was generated
	"""
	if not farm or not farm.grid:
		_verbose.warn("input", "⚠️", "Cannot adjust stride - no farm/grid")
		return

	var target_biome_info = _get_target_biome_for_granularity()
	if not target_biome_info.has("biome") or target_biome_info.biome == null:
		_verbose.warn("input", "⚠️", "No target biome for stride control: %s" % target_biome_info.get("reason", "unknown"))
		return

	var target_biome = target_biome_info.biome
	var target_biome_name = target_biome_info.name

	var result = GranularityController.increase_stride([target_biome])
	_reset_single_biome_stride_carry(target_biome_name)

	# Persist to GameState so stride survives save/load
	_persist_runtime_timescale(result.new_stride, null)

	var unlocked_str = " (UNLOCKED)" if result.current_stride == 0 and result.new_stride == 1 else ""
	_verbose.info("input", "⏩", "[%s] Stride: %d → %d%s" % [
		target_biome_name, result.current_stride, result.new_stride, unlocked_str
	])


func _decrease_resolution() -> void:
	"""Decrease quantum evolution resolution - finer substeps (Shift+- key).

	PER-BIOME CONTROL:
	- Main game: Affects only the currently selected biome (ActiveBiomeManager)
	- VisualBubbleTest: Affects only the last biome that was generated
	"""
	if not farm or not farm.grid:
		_verbose.warn("input", "⚠️", "Cannot adjust resolution - no farm/grid")
		return

	# Get target biome (per-biome control, not global)
	var target_biome_info = _get_target_biome_for_granularity()
	if not target_biome_info.has("biome") or target_biome_info.biome == null:
		_verbose.warn("input", "⚠️", "No target biome for resolution control: %s" % target_biome_info.get("reason", "unknown"))
		return

	var target_biome = target_biome_info.biome
	var target_biome_name = target_biome_info.name

	# Use granularity controller on single biome
	var result = GranularityController.decrease_granularity([target_biome])
	_reset_single_biome_stride_carry(target_biome_name)

	# Persist to GameState so resolution survives save/load
	_persist_runtime_resolution(result.new_dt)

	# CRITICAL: Invalidate ONLY target biome's buffer - lookahead was computed with old dt
	_invalidate_single_biome_buffer(target_biome_name, "granularity_decrease")

	_verbose.info("input", "🔬", "[%s] Resolution: %.4fs → %.4fs (finer, buffer invalidated)" % [
		target_biome_name, result.current_dt, result.new_dt
	])


func _increase_resolution() -> void:
	"""Increase quantum evolution resolution - coarser substeps (Shift+= key).

	PER-BIOME CONTROL:
	- Main game: Affects only the currently selected biome (ActiveBiomeManager)
	- VisualBubbleTest: Affects only the last biome that was generated
	"""
	if not farm or not farm.grid:
		_verbose.warn("input", "⚠️", "Cannot adjust resolution - no farm/grid")
		return

	# Get target biome (per-biome control, not global)
	var target_biome_info = _get_target_biome_for_granularity()
	if not target_biome_info.has("biome") or target_biome_info.biome == null:
		_verbose.warn("input", "⚠️", "No target biome for resolution control: %s" % target_biome_info.get("reason", "unknown"))
		return

	var target_biome = target_biome_info.biome
	var target_biome_name = target_biome_info.name

	# Use granularity controller on single biome
	var result = GranularityController.increase_granularity([target_biome])
	_reset_single_biome_stride_carry(target_biome_name)

	# Persist to GameState so resolution survives save/load
	_persist_runtime_resolution(result.new_dt)

	# OPTIMIZATION: Decimate buffer instead of full invalidation (10x coarser = keep every 10th frame)
	_decimate_single_biome_buffer(target_biome_name, 10)

	_verbose.info("input", "🔭", "[%s] Resolution: %.4fs → %.4fs (coarser, buffer decimated)" % [
		target_biome_name, result.current_dt, result.new_dt
	])


func _persist_runtime_timescale(stride: Variant, quantum_time_scale: Variant) -> void:
	var gsm = InstrumentLocator.resolve_game_state_manager(self)
	if not gsm or not gsm.current_state:
		return
	if stride != null:
		gsm.current_state.observation_stride = int(stride)
	if quantum_time_scale != null:
		gsm.current_state.quantum_time_scale = float(quantum_time_scale)


func _persist_runtime_resolution(max_evolution_dt: float) -> void:
	var gsm = InstrumentLocator.resolve_game_state_manager(self)
	if gsm and gsm.current_state:
		gsm.current_state.max_evolution_dt = max_evolution_dt
