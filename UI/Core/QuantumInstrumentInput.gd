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
## Key Layout (Archetype Frames grammar — see docs/ARCHETYPE_FRAMES.md):
##   4 5 6 7 8 9 0 = Archetype hat row (Spark/Icon/Merchant/Captain/
##                   Ace/Operator/Druid). Re-press the active hat
##                   toggles back to Ace (no frame).
##   1 2 3         = Sub-mode within the active frame
##
##   T Y U I O P   = Biome selection (6 spindle slots — direct-pick)
##   G H J K L ;   = Homerow plot selection (up to 6 plots — direct-pick)
##
##   W/S = move WASD cursor layer: W=up (toward surface row), S=down (toward plot row)
##   A/D = step within current layer: surface→cycle overlay, frame→cycle hat, biome→cycle biome, plot→cycle plot
##
##   Q/E/R/F = the primary action quartet.
##   Q = screw-out: less / remove / retreat
##   E = pause + inspect + expand (also fires frame-defined inspect verb if present)
##   R = screw-in: more / add / advance
##   F = play + flatten (also fires frame-defined F verb when one is declared)
##
##   - = Decrease stride and sim speed together
##   = = Increase stride and sim speed together
##   Shift+- = Decrease resolution dt (finer substeps, 10x more accurate)
##   Shift+= = Increase resolution dt (coarser substeps, 10x faster)

# Preloads
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const GranularityController = preload("res://Core/Utilities/GranularityController.gd")

# Access autoloads safely
@onready var _verbose = get_node_or_null("/root/VerboseConfig")
@onready var _observation_frame = get_node_or_null("/root/ObservationFrame")
@onready var _chain_tracker = get_node_or_null("/root/ActionChainTracker")
@onready var _active_biome_mgr = get_node_or_null("/root/ActiveBiomeManager")

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
var _confirm_pending: Dictionary = {}  # {action, emoji, label} — awaiting QF confirm

# Signals
signal action_performed(action: String, result: Dictionary)
signal selection_changed(plot_idx: int, biome: String)
signal biome_switched(old_biome: String, new_biome: String)
## New canonical signals — frame-keyed.
signal frame_changed(frame: String)
signal frame_mode_changed(frame: String, mode_index: int, mode_label: String)
signal submenu_changed(submenu_name: String, submenu_actions: Dictionary)
signal plot_checked(grid_pos: Vector2i, is_checked: bool)  # Multi-select checkbox toggled
## Cylinder outer-ring step. Emitted when A/D fires on layer=0 (ZXCVBNM surface ring).
## PlayerShell listens and dispatches to _cycle_menu_overlay.
signal surface_ring_step_requested(delta: int)

# Actions that modify density matrix at phrame 0 (require buffer invalidation)
const BUFFER_INVALIDATING_ACTIONS: Array[String] = [
	# Druid frame: reversible unitary rotations + Hadamard
	"rotate_up", "rotate_down", "hadamard",
	# Spark frame: instant pole shifts (strong one-shot drive/decay)
	"spark_north", "spark_south",
	# Merchant frame: persistent Lindbladian contracts
	"drain", "pump",
	# Operator frame: entangling gates
	"measure", "build_gate", "remove_gates",
# Icon frame: icon injection/removal (adds/removes qubits via icon assignment)
	"inject_icon", "remove_icon"
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
	# Inject farm reference for action execution.
	farm = farm_ref
	_verbose.info("input", "~", "Farm injected into QuantumInstrumentInput")


func inject_plot_grid_display(pgd_ref) -> void:
	# Inject PlotGridDisplay reference for visual selection updates.
	plot_grid_display = pgd_ref
	_verbose.info("input", "~", "PlotGridDisplay injected into QuantumInstrumentInput")


func inject_instrument(inst) -> void:
	# Inject QuantumInstrument reference for game mechanics delegation.
	_instrument = inst
	# Forward instrument's plot_check_changed to QII's plot_checked signal
	if _instrument.has_signal("plot_check_changed"):
		_instrument.plot_check_changed.connect(func(pos, checked): plot_checked.emit(pos, checked))
	_verbose.info("input", "~", "QuantumInstrument injected into QuantumInstrumentInput")


## ============================================================================
## SELECTION STATE (for save/load)
## ============================================================================

func get_checked_plots() -> Array[Vector2i]:
	# Get current checked plot positions (for save/load).
	if _instrument:
		return _instrument.get_checked_plots()
	return []


func set_checked_plots(positions: Array) -> void:
	# Set checked plot positions (for save/load restoration).
	if _instrument:
		_instrument.set_checked_plots(positions)
	_verbose.debug("input", "✅", "Restored %d checked plots from save" % positions.size())


## ============================================================================
## INPUT HANDLING
## ============================================================================

func _unhandled_key_input(event: InputEvent) -> void:
	# Handle keyboard input for the quantum instrument.
	if not event is InputEventKey or not event.pressed:
		return
	if event.echo:
		return

	var key = _keycode_to_string(event.keycode)

	# Any key other than F cancels a pending confirm-chord.
	if not _confirm_pending.is_empty() and key != "F":
		_confirm_pending = {}

	# Auto-close submenu when any non-action key is pressed
	if _instrument.is_in_submenu() and key not in ["Q", "E", "R", "F"]:
		_close_submenu()

	# Archetype hat row: 4, 5, 6, 7, 8, 9, 0 → frame.
	# Re-pressing the active hat toggles back to Ace (no frame).
	if ToolConfig.HAT_KEY_TO_FRAME.has(key):
		var hat_frame: String = ToolConfig.HAT_KEY_TO_FRAME[key]
		var target_frame: String = ToolConfig.FRAME_NULL if ToolConfig.get_current_frame() == hat_frame else hat_frame
		_select_frame_hat(target_frame)
		get_viewport().set_input_as_handled()
		return

	# Direct sub-mode select within current frame: 1, 2, 3 → modes 0..2
	if key in ["1", "2", "3"]:
		var slot_idx := int(key) - 1
		var current_frame_name: String = ToolConfig.get_current_frame()
		if current_frame_name == ToolConfig.FRAME_NULL:
			# No active frame → default to Ace so sub-mode keys are never silent.
			current_frame_name = ToolConfig.FRAME_ACE
			_select_frame_hat(current_frame_name)
		var applied = ToolConfig.set_frame_mode(current_frame_name, slot_idx)
		if applied >= 0:
			_on_mode_changed(current_frame_name, applied)
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

	# Apostrophe: bulk select / clear toggle on the active biome's plots.
	# Empty selection → check every register; non-empty → clear all checks.
	if key == "'":
		_toggle_bulk_check_active_biome()
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
			# F = confirm a pending QF destructive action, or close submenu,
			# or dispatch a frame-defined F verb if one exists.
			if not _confirm_pending.is_empty():
				var pending := _confirm_pending.duplicate()
				_confirm_pending = {}
				_run_action(pending["action"], pending.get("emoji", ""), pending.get("label", ""))
			elif _instrument.is_in_submenu():
				_close_submenu()
			else:
				var f_action = ToolConfig.get_action(ToolConfig.get_current_frame(), "F")
				if not f_action.is_empty():
					_perform_action("F")
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# Handle InputMap actions for biome/plot/subspace selection.

	# Uses `_unhandled_input` (not `_input`) so that any overlay that consumes
	# an event via `Viewport.set_input_as_handled()` — e.g. the X system menu
	# while it's open — reliably shields gameplay selection. This is the
	# standard Godot pattern for gameplay-layer input that should defer to UI.
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

		if event.is_shift_pressed():
			# Shift+GHJKL; — toggle checkbox without moving highlight
			_toggle_check_at_plot_idx(i)
		else:
			# Plain GHJKL; — move highlight only (re-press on current plot toggles check)
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
## ARCHETYPE FRAME MANAGEMENT
## ============================================================================

func _select_frame_hat(frame_name: String) -> void:
	# Select an archetype frame (hat row 4-0). Empty string = Ace.
	if not ToolConfig.select_frame(frame_name):
		_verbose.warn("input", "⚠️", "Ignored invalid frame selection '%s'" % frame_name)
		return
	frame_changed.emit(frame_name)

	if frame_name == ToolConfig.FRAME_NULL:
		_verbose.info("input", "~", "Frame: Ace (default toolkit)")
		return
	var label = ToolConfig.get_frame_name_label(frame_name)
	var mode_label = ToolConfig.get_frame_mode_label(frame_name)
	var display = label
	if mode_label != "":
		display = "%s [%s]" % [label, mode_label]
	_verbose.info("input", "~", "Frame: %s" % display)


func _cycle_mode() -> void:
	# Cycle to the next sub-mode in the current frame. Bound to Tab in
	# PlayerShell.
	var frame_name: String = ToolConfig.get_current_frame()
	if frame_name == ToolConfig.FRAME_NULL:
		_verbose.debug("input", "~", "No active frame to cycle")
		return
	var new_index = ToolConfig.cycle_frame_mode(frame_name)
	if new_index < 0:
		_verbose.debug("input", "~", "No mode cycle for frame %s (single mode)" % frame_name)
		return
	_on_mode_changed(frame_name, new_index)


func _on_mode_changed(frame_name: String, mode_index: int) -> void:
	# Shared mode-change emission.
	var mode_label = ToolConfig.get_frame_mode_label(frame_name)
	var mode_emoji = ToolConfig.get_frame_mode_emoji(frame_name)
	frame_mode_changed.emit(frame_name, mode_index, mode_label)
	_verbose.info("input", "~", "Mode: %s (%s)" % [mode_label, mode_emoji])


## ============================================================================
## CONTEXT BUILDING (for headless state)
## ============================================================================

func _build_context_dict() -> Dictionary:
	# Build context dictionary for headless state operations.
	var biome = _get_current_biome()
	var grid_pos = _instrument.last_selected_position

	return {
		"farm": farm,
		"biome": biome,
		"position": grid_pos,
		"economy": farm.economy if farm else null,
		"selection": _instrument.checked_plots  # Use headless state
	}


## ============================================================================
## SUBMENU HANDLING
## ============================================================================

func _open_submenu_for_action(action_info: Dictionary) -> void:
	# Open a submenu for an action.

	# Args:
	# action_info: Action info dictionary from ToolConfig containing "submenu" field
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
	if submenu_name == "icon_injection":
		_verbose.info("input", "📋", "Opened icon injection submenu")
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
	# Generate the icon injection submenu dynamically.
	var IconInjectionSubmenu = preload("res://UI/Core/Submenus/IconInjectionSubmenu.gd")
	if not farm:
		_verbose.warn("input", "📋", "Farm not available")
		return {}

	var biome = _get_current_biome()
	if not biome:
		_verbose.warn("input", "📋", "No current biome")
		return {}

	return IconInjectionSubmenu.generate_submenu(biome, farm, _submenu_page)


func _generate_gate_selection_submenu() -> Dictionary:
	# Generate the gate selection submenu dynamically based on _instrument.checked_plots.
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
	# Cycle to next page in paginated submenu (F key).
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
	# Close the active submenu and reset all submenu state.
	_instrument.exit_submenu()
	_in_submenu = false
	_current_submenu = {}
	submenu_changed.emit("", {})


func _handle_submenu_action(action_key: String) -> void:
	# Handle Q/E/R actions while in a submenu.

	# Args:
	# action_key: "Q", "E", or "R"
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

	# Handle icon_injection submenu actions
	if action == "inject_icon":
		var icon = action_data.get("icon", {})
		var label = action_data.get("label", "")
		if not icon.is_empty():
			_verbose.info("input", "📋", "You selected: %s - injecting..." % label)
			_execute_inject_icon(icon)

	# Handle gate_selection submenu actions
	elif action == "build_gate":
		var gate_type = action_data.get("gate_type", "bell")
		var label = action_data.get("label", gate_type)
		var qubits_required = action_data.get("qubits_required", 2)
		_verbose.info("input", "⚛️", "Building %s gate (requires %d qubits)" % [label, qubits_required])
		_execute_build_gate(gate_type)

	_close_submenu()


func _execute_inject_icon(icon: Dictionary) -> void:
	# Execute signature injection with user-selected pair.

	# Args:
	# icon: {north: String, south: String}
	var biome = _get_current_biome()
	if not biome:
		_verbose.warn("input", "+", "No biome for icon injection")
		return
	var result = MacroActions.dispatch(_instrument, MacroActions.KIND_INJECT_ICON_PAIR, {
		"biome_name": biome.get_biome_type(),
		"icon": icon,
	})
	var cost = result.get("cost", {})
	if result.get("success", false):
		_verbose.info("input", "+", "Injected icon %s/%s into %s" % [
			icon.get("north", ""),
			icon.get("south", ""),
			biome.name
		])

		# Invalidate buffer (icon injection adds qubits, modifies density matrix)
		_invalidate_biome_buffer_for_action("inject_icon")

		# Phase 2: notify the story substrate that the player faction's
		# socialites engaged with these emojis.
		_notify_story_engine([icon.get("north", ""), icon.get("south", "")], "inject")

		action_performed.emit("inject_icon", {
			"success": true,
			"north_emoji": icon.get("north", ""),
			"south_emoji": icon.get("south", ""),
			"cost": cost,
			"biome": biome.name
		})
	else:
		_verbose.warn("input", "+", "Icon injection failed: %s" % result.get("message", result.get("error", "unknown")))
		action_performed.emit("inject_icon", result)


# =============================================================================
# PHASE 2: STORY ENGINE NOTIFICATION
# =============================================================================
# Icon-hat actions are the player faction's socialite interface; report the
# emojis touched into the trajectory + conversation Hamiltonian memory so
# NPC chatter responds to player moves.

func _notify_story_engine(emojis: Array, kind: String) -> void:
	var clean: Array = []
	for e in emojis:
		var s := str(e)
		if s != "":
			clean.append(s)
	if clean.is_empty():
		return
	var story_engine = get_tree().root.get_node_or_null("/root/StoryEngine")
	if story_engine != null and story_engine.has_method("note_player_action"):
		story_engine.note_player_action(clean, kind)


func _build_chip_context() -> ChipContext:
	# Used by both _perform_action (dispatch resolution) and any UI mirror that
	# wants to reason about the focused qubit's contextual state.
	var biome = _get_current_biome()
	var qc = biome.quantum_computer if biome else null
	var qid: int = int(current_selection.get("plot_idx", -1))
	return ChipContext.new(qc, qid)


func _execute_toggle_berry_track() -> Dictionary:
	# Toggle Berry-phase tracking on the focused qubit. The integrator seeds
	# itself from the next slice's Bloch vector — no explicit seed needed.
	var biome = _get_current_biome()
	if biome == null:
		return {"success": false, "error": "no_biome"}
	var qc = biome.quantum_computer
	if qc == null or qc.berry_register == null:
		return {"success": false, "error": "no_quantum_computer"}
	var qid: int = int(current_selection.get("plot_idx", -1))
	if qid < 0 or qid >= qc.register_map.num_qubits:
		_verbose.info("input", "⌖", "No focused qubit to track")
		return {"success": false, "error": "no_qubit"}
	if qc.berry_register.is_tracked(qid):
		qc.berry_register.stop_tracking(qid)
		_verbose.info("input", "⌖", "Stopped tracking qubit %d" % qid)
		return {"success": true, "tracking": false, "qubit": qid}
	qc.berry_register.start_tracking(qid)
	_verbose.info("input", "⌖", "Started tracking qubit %d" % qid)
	return {"success": true, "tracking": true, "qubit": qid}


func _execute_incorporate_icon() -> Dictionary:
	# Harvest the focused qubit's icon into the player's signature.
	# Routes through the same canonical Farm.discover_icon path as inject so
	# downstream sync to GameState happens identically.
	var biome = _get_current_biome()
	if biome == null:
		return {"success": false, "error": "no_biome"}
	var qc = biome.quantum_computer
	if qc == null or qc.berry_register == null:
		return {"success": false, "error": "no_quantum_computer"}
	var qid: int = int(current_selection.get("plot_idx", -1))
	if qid < 0 or qid >= qc.register_map.num_qubits:
		return {"success": false, "error": "no_qubit"}
	if not qc.berry_register.is_ripe(qid):
		_verbose.info("input", "🧬", "Qubit %d not ripe yet" % qid)
		return {"success": false, "error": "not_ripe"}
	var axis = qc.register_map.axis(qid)
	if axis == null or axis.is_empty():
		return {"success": false, "error": "no_axis"}
	var north: String = str(axis.get("north", ""))
	var south: String = str(axis.get("south", ""))
	if north == "" or south == "":
		return {"success": false, "error": "axis_missing_emoji"}
	var icon = {"north": north, "south": south}
	var biome_name = biome.get_biome_type() if biome.has_method("get_biome_type") else biome.name
	var result = MacroActions.dispatch(_instrument, MacroActions.KIND_INJECT_ICON_PAIR, {
		"biome_name": biome_name,
		"icon": icon,
	})
	if result.get("success", false):
		var berry_phase: float = qc.berry_register.get_phase(qid)
		qc.berry_register.consume(qid)
		_verbose.info("input", "🧬", "Incorporated %s/%s from qubit %d" % [north, south, qid])
		_toast_berry_whisper(biome, north, south, berry_phase)
		# Phase 2: trajectory + conv-H memory entry for the incorporation.
		_notify_story_engine([north, south], "incorporate")
		action_performed.emit("incorporate_icon", {
			"success": true,
			"north_emoji": north,
			"south_emoji": south,
			"qubit": qid,
			"biome": biome.name,
		})
	else:
		_verbose.warn("input", "🧬", "Incorporate failed: %s" % result.get("message", result.get("error", "unknown")))
		action_performed.emit("incorporate_icon", result)
	return result


## Whisper plumbing — the world's speaking moments (QuestVoice registers), all
## toasted through PlayerShell. Words only, no mechanics; fails silently
## headless (no shell in the tree).

## Toast one faction whisper: head line + attributed voice line.
## The rite's ceremony (What Fades, Chapter V): fires ONLY when the reap was paid
## from wet country (sink flux + entropy bank, kT·ΔS) — the extraction was real.
## Speaker: the active biome's native faction, same convention as berry whispers.
func _maybe_toast_reap_whisper(result: Dictionary) -> void:
	if not result.get("success", false):
		return
	var rite: int = int(result.get("rite_credits", 0))
	if rite <= 0:
		return
	var biome = null
	if farm and farm.grid and farm.grid.has_method("get_biome"):
		biome = farm.grid.get_biome(_get_current_biome_name())
	var speaker := _native_speaker_for(biome)
	var line: String = QuestVoice.reap_whisper(speaker)
	_toast_whisper("⚖️ the rite: +%d from the season's entropy bank (kT·ΔS)" % rite, speaker, line)


func _toast_whisper(head: String, speaker: String, line: String) -> void:
	if line == "":
		return
	var ps: Node = self
	while ps != null and not (ps is PlayerShell):
		ps = ps.get_parent()
	if ps == null or not ps.has_method("show_hint"):
		return
	ps.show_hint("%s\n💬 %s“%s”" % [head, ("%s — " % speaker) if speaker != "" else "", line], 2, "")


## First native faction of the biome's canonical definition ("" if none).
func _native_speaker_for(biome) -> String:
	if biome == null:
		return ""
	var bname: String = biome.get_biome_type() if biome.has_method("get_biome_type") else str(biome.name)
	var reg = load("res://Core/Biomes/BiomeRegistry.gd")
	if reg != null and reg.has_method("get_shared"):
		var shared = reg.get_shared()
		var canonical = shared.get_by_name(bname) if (shared != null and shared.has_method("get_by_name")) else null
		if canonical != null and ("native_factions" in canonical) and canonical.native_factions is Array \
				and not canonical.native_factions.is_empty():
			return str(canonical.native_factions[0])
	return ""


## The moment a Berry loop is incorporated — the harvest is no longer mute.
func _toast_berry_whisper(biome, north: String, south: String, phase: float) -> void:
	var speaker := _native_speaker_for(biome)
	_toast_whisper("🧬 %s/%s woven into your signature · Ω = %+.2f rad" % [north, south, phase],
			speaker, QuestVoice.whisper("berry", speaker))


## An IMPROBABLE Born outcome (p below this) is the scar that taught you most —
## the surprisal payout law made audible (docs/glossary/measurement.md).
const MEASURE_WHISPER_MAX_P := 0.10

func _maybe_toast_measure_whisper(result: Dictionary) -> void:
	if not result.get("success", false):
		return
	var p := float(result.get("probability", 1.0))
	if p <= 0.0 or p >= MEASURE_WHISPER_MAX_P:
		return
	var biome = _get_current_biome()
	var speaker := _native_speaker_for(biome)
	_toast_whisper("🎯 collapsed to %s against the odds — p = %.2f, paid in surprisal" % [str(result.get("outcome", "?")), p],
			speaker, QuestVoice.whisper("measure", speaker))


func _execute_build_gate(gate_type: String) -> void:
	# Execute gate building with the specified gate type.

	# Args:
	# gate_type: Type of gate to build (bell, cnot, cz, swap, ghz, cluster)
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
	# Apply gate from chain swipe gesture.
	# Populates _instrument.checked_plots, then executes gate build.
	# Default: bell (2 bubbles) or cluster (3+ bubbles).
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
	# Select a biome from the TYUIOP row.

	# Args:
	# biome_idx: Which biome (0-5) was selected (T=0, Y=1, U=2, I=3, O=4, P=5)
	# key: The key that was pressed (for logging)
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
	# Select or toggle a plot in the current biome.

	# Args:
	# plot_idx: Which plot index was selected (0..N-1)
	# key: The key that was pressed (for chain tracking)
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
	_instrument.last_plot_idx = plot_idx
	_instrument.current_biome = biome_name
	_instrument.last_selected_position = target_grid_pos

	_verbose.debug("input", "📍", "SELECTION DEBUG: plot_idx=%d, biome=%s → grid_pos=%s" % [plot_idx, biome_name, target_grid_pos])

	if plot_grid_display and farm and target_grid_pos.x >= 0:
		plot_grid_display.set_selected_plot(target_grid_pos)
		_verbose.debug("input", "~", "Visual selection: %s" % target_grid_pos)

	# Auto-bind: selecting a plot surfaces its terminal (the old "Explore" verb,
	# now folded into selection). Free and best-effort — the bind is just looking;
	# you pay energy at Harvest (Q) / Plant (R), not to select.
	if _instrument and target_grid_pos.x >= 0:
		_instrument.action_explore(biome_name, target_grid_pos)

	selection_changed.emit(plot_idx, biome_name)
	_verbose.debug("input", "~", "Plot %d in %s" % [plot_idx, biome_name])


## ============================================================================
## CRAWL STEP — WASD plot navigation in main game.
## ============================================================================

func step_active_plot(delta: int) -> void:
	# Advance the active plot by ±1, wrapping within the active biome's
	# register count. Mirrors the direct GHJKL; jump but in delta form so
	# WASD can crawl horizontally.
	if not _instrument:
		return
	var register_count := _get_active_biome_register_count()
	if register_count <= 0:
		return
	var current_idx: int = int(_instrument.current_plot_idx)
	if current_idx < 0:
		current_idx = 0
	var new_idx := wrapi(current_idx + delta, 0, register_count)
	var key_label := "D" if delta > 0 else "A"
	_select_plot(new_idx, key_label)


## Called by PlayerShell when WASD cursor enters the plot ring (layer 3).
## Auto-selects plot 0 if no plot is currently selected; keeps existing selection if one is set.
func enter_plot_ring() -> void:
	if not _instrument:
		return
	if int(_instrument.current_plot_idx) >= 0:
		return
	_select_plot(0, "enter")


## Called by PlayerShell when WASD cursor leaves the plot ring.
## Clears the active plot — plot selection is only valid while on the plot ring.
func leave_plot_ring() -> void:
	if _instrument:
		_instrument.current_plot_idx = -1
	current_selection["plot_idx"] = -1
	if plot_grid_display and plot_grid_display.has_method("clear_selection"):
		plot_grid_display.clear_selection()


func cycle_frame_hat(delta: int) -> void:
	# Step through FRAME_IDS by ±1, wrapping. Bound to TAB and to the
	# WASD frame-layer step.
	ToolConfig.cycle_frame(delta)
	frame_changed.emit(ToolConfig.get_current_frame())
	_verbose.debug("input", "~", "Frame → %s" % ToolConfig.get_current_frame())


func step_active_layer(layer: int, delta: int) -> void:
	# A/D crawl dispatched by PlayerShell's cursor_layer.
	# 0 (surface) → surface_ring_step_requested  → PlayerShell cycles overlay
	# 1 (frame)   → cycle_frame_hat              → frame_changed
	# 2 (biome)   → cycle biome                  → biome_switched
	# 3 (plot)    → step_active_plot             → selection_changed
	match layer:
		0:
			surface_ring_step_requested.emit(delta)
		1:
			cycle_frame_hat(delta)
		2:
			if not _active_biome_mgr:
				return
			var old_biome: String = _active_biome_mgr.get_active_biome()
			if delta > 0:
				_active_biome_mgr.cycle_next()
			else:
				_active_biome_mgr.cycle_prev()
			var new_biome: String = _active_biome_mgr.get_active_biome()
			biome_switched.emit(old_biome, new_biome)
		3:
			step_active_plot(delta)


## ============================================================================
## MULTI-SELECT SYSTEM (Checkboxes)
## ============================================================================

func _toggle_check_at_plot_idx(plot_idx: int) -> void:
	# Toggle checkbox for a plot by index in the active biome (Shift+GHJKL;).
	if not _active_biome_mgr:
		return
	var biome_name = _active_biome_mgr.get_active_biome()
	var grid_pos = _get_grid_position_for(plot_idx, biome_name)
	if grid_pos.x < 0:
		return
	toggle_check(grid_pos)
	_verbose.debug("input", "☑", "Shift-toggled plot %d in %s" % [plot_idx, biome_name])


func toggle_check(grid_pos: Vector2i) -> void:
	# Toggle checkmark for multi-select at given grid grid_pos.

	# Args:
	# grid_pos: Grid grid_pos to toggle (Vector2i(plot_idx, biome_row))
	if grid_pos.x < 0 or grid_pos.y < 0:
		return  # Invalid grid_pos

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
	# Clear all checkmarks (useful for batch operation completion).
	for pos in _instrument.checked_plots.duplicate():  # Duplicate to avoid modification during iteration
		plot_checked.emit(pos, false)
	_instrument.checked_plots.clear()
	_verbose.debug("input", "☐", "Cleared all checkmarks")


func _toggle_bulk_check_active_biome() -> void:
	# Apostrophe (`'`) handler: toggle bulk-check across the active biome's
	# registers. If anything is checked → clear all. If nothing is checked
	# → check every register.
	if _instrument.checked_plots.size() > 0:
		clear_all_checks()
		return
	if not _active_biome_mgr:
		return
	var biome_name: String = _active_biome_mgr.get_active_biome()
	if biome_name == "":
		return
	var register_count: int = _get_active_biome_register_count()
	for plot_idx in range(register_count):
		var grid_pos: Vector2i = _get_grid_position_for(plot_idx, biome_name)
		if grid_pos.x < 0:
			continue
		if grid_pos in _instrument.checked_plots:
			continue
		_instrument.checked_plots.append(grid_pos)
		plot_checked.emit(grid_pos, true)
	_verbose.debug("input", "☑", "Bulk-checked %d plots in %s" % [_instrument.checked_plots.size(), biome_name])


func _clear_checks_and_cycle_biome() -> void:
	# Shift+4E: Full quantum reset + cycle to next biome (fresh start).

	# Performs:
	# - Clear all checkmarks
	# - Deselect all plots
	# - Reset selection state
	# - Reset quantum simulation (if available)
	# - Cycle to next biome
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
	# Select a subspace within the current biome (reserved for future).

	# Args:
	# subspace_idx: Which subspace (0-3) was selected
	# key: The key that was pressed (for logging)
	_verbose.debug("input", "~", "Subspace selection reserved for future (idx: %d)" % subspace_idx)


## ============================================================================
## ACTION EXECUTION
## ============================================================================

## Public entry point for action invocation from non-keyboard sources (button tap, touch).
## Mirrors the keyboard path in _input() for Q/E/R/F.
func invoke_action(action_key: String) -> void:
	_perform_action(action_key)


func _perform_action(action_key: String) -> void:
	# Execute the action mapped to Q/E/R for the current archetype frame.

	# Args:
	# action_key: "Q" (DOWN), "E" (NEUTRAL), or "R" (UP)
	var current_frame_name: String = ToolConfig.get_current_frame()
	var action_info = ToolConfig.get_action(current_frame_name, action_key)
	# Apply contextual chip resolver so dispatch matches what the chip displayed.
	# Resolvers may override `action` (and strip `submenu`) based on sim state.
	action_info = ChipResolverRegistry.resolve(action_info, _build_chip_context())

	if action_info.is_empty():
		_verbose.debug("input", "~", "No action for %s in frame %s" % [action_key, current_frame_name])
		return

	if bool(action_info.get("disabled", false)):
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

	if action_info.get("destructive", false):
		_confirm_pending = {
			"action": action_name,
			"emoji": emoji,
			"label": action_info.get("label", action_name),
		}
		var shell := _resolve_player_shell()
		if shell and shell.has_method("show_hint"):
			shell.show_hint(
				"[color=#ff9966]⚠ %s[/color]  —  press [b]F[/b] to confirm, any other key cancels" \
				% action_info.get("label", action_name), 3)
		return

	_run_action(action_name, emoji if emoji != "" else action_name, action_info.get("label", action_name))


func _get_block_reason(_action_name: String) -> String:
	return ""


func _perform_shift_key_action(action_key: String) -> void:
	# Apply the Q/E/R action across all checked plots (multi-select batch operation).

	# For gate actions (Druid frame: unitary gates), uses batch injection with single buffer invalidation.
	# Selection order is preserved - gates are applied in the order plots were checked.
	var current_frame_name: String = ToolConfig.get_current_frame()
	var action_info = ToolConfig.get_action(current_frame_name, action_key)
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

	# BATCH GATE PATH: For Druid frame (unitary) gate actions, use batch injection
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
			continue
		if action_name == "pop":
			_run_cleanup_action(action_name, symbol, log_label)
		else:
			_run_action(action_name, symbol, log_label)
		_refresh_plot_tiles([pos])
	_restore_selection(original_selection)


func _is_gate_action(action_name: String) -> bool:
	# Check if action is a unitary gate operation (eligible for batch injection).
	return action_name in ["hadamard", "rotate_up", "rotate_down"]


func _perform_batch_gate_action(action_name: String, positions: Array, symbol: String, log_label: String) -> void:
	# Apply gate action to multiple qubits using batch injection.

	# Gates are applied in selection order (first checked = first gate applied).
	# Buffer invalidation happens ONCE at the end, not per-gate.

	# Args:
	# action_name: Gate action (hadamard, rotate_up, rotate_down)
	# positions: Array[Vector2i] of grid positions in selection order
	# symbol: Log symbol
	# log_label: Human-readable label
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
	# Map action name to gate library name.
	match action_name:
		"hadamard":
			return "H"
		"rotate_up", "rotate_down":
			# Get axis from Druid frame's sub-mode (X, Y, or Z)
			var axis = ToolConfig.get_frame_mode_name(ToolConfig.FRAME_DRUID)
			if axis == "":
				axis = "X"
			return "R" + axis.to_lower()  # Rx, Ry, or Rz
		_:
			return ""


func _get_biome_for_position(pos: Vector2i):
	# Get biome for a grid grid_pos.
	if not farm or not farm.grid:
		return null
	var biome_name = farm.get_biome_for_row(pos.y) if farm.has_method("get_biome_for_row") else ""
	if biome_name == "":
		return null
	return farm.grid.get_biome(biome_name)


func _get_qubit_for_position(pos: Vector2i, biome) -> int:
	# Get qubit index for a grid grid_pos via plot/terminal binding.
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
	# Execute an action and emit logging + signal.
	var result = _execute_action(action_name)

	# Invalidate buffer if action modified density matrix at phrame 0
	if result.get("success", false) and action_name in BUFFER_INVALIDATING_ACTIONS:
		_invalidate_biome_buffer_for_action(action_name)

	_log_action_result(action_name, log_symbol, action_label, result)
	return result


func _run_cleanup_action(action_name: String, log_symbol: String, action_label: String) -> void:
	# Execute a cleanup version of an action (e.g., pop cleanup).
	var result = _execute_cleanup_action(action_name)
	_log_action_result(action_name, log_symbol, action_label, result)


func _execute_cleanup_action(action_name: String) -> Dictionary:
	# Execute cleanup variants for actions that require special handling.

	# NOTE: Currently just calls _execute_action() for all actions.
	# Previously had special handling for pop cleanup, now unified into standard action dispatch.
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
	# Invalidate biome buffer after density matrix modification.

	# When actions modify the density matrix at phrame 0, the lookahead buffer
	# becomes invalid and must be recomputed. This triggers high-priority emergency refill.

	# Args:
	# action_name: Name of action that modified the density matrix
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
	batcher.invalidate_biome_buffer(biome_name)
	_verbose.info("input", "🔄", "Buffer invalidated for %s (action: %s)" % [biome_name, action_name])


func _get_target_biome_for_granularity() -> Dictionary:
	# Get the target biome for granularity control (-/= keys).

	# Returns: {biome: Node, name: String, reason: String}

	# Logic:
	# - Main game: ActiveBiomeManager.get_active_biome() (currently selected biome)
	# - Generator/test scene with get_last_generated_biome_name(): last biome created
	if not farm or not farm.grid:
		return {"biome": null, "name": "", "reason": "no_farm"}

	# Support generator/test scenes that expose the last created biome.
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
	# Invalidate a single biome's lookahead buffer after granularity change.
	if not farm:
		_verbose.debug("input", "🔄", "No farm for buffer invalidation")
		return

	var batcher = farm.biome_evolution_batcher if "biome_evolution_batcher" in farm else null
	if not batcher:
		_verbose.debug("input", "🔄", "No batcher available for buffer invalidation")
		return

	batcher.invalidate_biome_buffer(biome_name)
	_verbose.debug("input", "🔄", "[%s] Buffer invalidated: %s" % [biome_name, reason])


func _decimate_single_biome_buffer(biome_name: String, decimation_factor: int) -> void:
	# Decimate a single biome's buffer when coarsening granularity.
	if not farm:
		_verbose.debug("input", "✂️", "No farm for buffer decimation")
		return

	var batcher = farm.biome_evolution_batcher if "biome_evolution_batcher" in farm else null
	if not batcher:
		_verbose.debug("input", "✂️", "No batcher available for buffer decimation")
		return

	var new_depth = batcher.decimate_biome_buffer(biome_name, decimation_factor)
	_verbose.debug("input", "✂️", "[%s] Buffer decimated (1/%d) - preserved %d frames" % [
		biome_name, decimation_factor, new_depth
	])


func _reset_single_biome_stride_carry(biome_name: String) -> void:
	# Reset stride dt carry so stride/resolution changes apply deterministically.
	if not farm:
		return
	var batcher = farm.biome_evolution_batcher if "biome_evolution_batcher" in farm else null
	if batcher:
		batcher.reset_stride_carry(biome_name)


func _invalidate_all_biome_buffers(reason: String) -> void:
	# Invalidate ALL biome buffers after global parameter changes.

	# When simulation parameters change (granularity, time scale), all lookahead
	# buffers become invalid because they were computed with old parameters.

	# Args:
	# reason: Reason for invalidation (for logging)
	if not farm or not farm.grid:
		_verbose.debug("input", "🔄", "No farm/grid for buffer invalidation")
		return

	# Get batcher reference from farm
	var batcher = farm.biome_evolution_batcher if "biome_evolution_batcher" in farm else null
	if not batcher:
		_verbose.debug("input", "🔄", "No batcher available for buffer invalidation")
		return

	# Invalidate ALL biomes
	var biome_count = 0
	for biome_name in farm.grid.get_biome_names():
		batcher.invalidate_biome_buffer(biome_name)
		biome_count += 1

	_verbose.info("input", "🔄", "All %d biome buffers invalidated (reason: %s)" % [biome_count, reason])


func _decimate_all_biome_buffers(decimation_factor: int) -> void:
	# Decimate ALL biome buffers when coarsening granularity.

	# When dt doubles (2x coarser), existing frames are still valid but oversampled.
	# Instead of full invalidation, keep every Nth frame to preserve computed work.

	# Args:
	# decimation_factor: Keep every Nth frame (2 for 2x coarsening)
	if not farm or not farm.grid:
		_verbose.debug("input", "✂️", "No farm/grid for buffer decimation")
		return

	var batcher = farm.biome_evolution_batcher if "biome_evolution_batcher" in farm else null
	if not batcher:
		_verbose.debug("input", "✂️", "No batcher available for buffer decimation")
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
	# Execute a specific action by name. Delegates to QuantumInstrument.
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
		"spark_north":
			result = _instrument.action_spark_north(positions)
			if result.get("success", false):
				_refresh_plot_tiles(positions)
		"spark_south":
			result = _instrument.action_spark_south(positions)
			if result.get("success", false):
				_refresh_plot_tiles(positions)
		"drain":
			result = _instrument.action_drain(positions)
			if result.get("success", false):
				_refresh_plot_tiles(positions)
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
			_maybe_toast_measure_whisper(result)
		"reap":
			result = _instrument.action_reap()
			_maybe_toast_reap_whisper(result)
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
		"toggle_berry_track":
			result = _execute_toggle_berry_track()
		"incorporate_icon":
			result = _execute_incorporate_icon()
		"inject_icon":
			result = MacroActions.dispatch(_instrument, MacroActions.KIND_INJECT_ICON, {"biome_name": biome_name})
		"discover_biome":
			result = MacroActions.dispatch(_instrument, MacroActions.KIND_DISCOVER_BIOME)
			if result.get("success", false):
				_select_frame_hat(ToolConfig.FRAME_ACE)
		"cycle_biome", "toggle_view":
			result = _instrument.action_cycle_biome()
		"remove_icon":
			result = MacroActions.dispatch(_instrument, MacroActions.KIND_REMOVE_ICON, {"biome_name": biome_name, "grid_pos": grid_pos})
			if result.get("success", false):
				# Phase 2: emojis withdrawn from social fabric — tell the substrate.
				var icon: Dictionary = result.get("removed_icon", {})
				_notify_story_engine([icon.get("north", ""), icon.get("south", "")], "remove")
		"remove_biome":
			result = MacroActions.dispatch(_instrument, MacroActions.KIND_REMOVE_BIOME)
		"inspect_qubit":
			result = _execute_inspect_qubit()
		"merchant_hint":
			result = _execute_merchant_hint()
		"forecast_biome_discovery":
			result = _execute_discovery_forecast()
		_:
			_verbose.warn("input", "?", "Unknown action: %s" % action_name)
			return {"success": false, "error": "unknown_action", "message": "Unknown action: %s" % action_name}

	return result


## Rotating pool of one-line hints the Merchant "Tip" verb whispers into
## the corner toast. Lightweight by design — the quest layer can
## replace this with context-aware lines later.
const _MARKET_QUIP_TEMPLATES: Array[String] = [
	"The market whispers: [b]%s[/b] is thin on the ground. Worth stocking up.",
	"Scarce right now: [b]%s[/b]. A well-timed acquisition could pay off.",
	"I'm hearing [b]%s[/b] is harder to come by than it looks. Just saying.",
	"Low reserves on [b]%s[/b]. The smart money moves early.",
]

var _market_quip_idx: int = 0


func _execute_inspect_qubit() -> Dictionary:
	# Open qubit detail view for the currently selected plot (Icon frame 5E).
	# Eventually opens the V-surface focused on this qubit; shows a toast until wired.
	var shell := _resolve_player_shell()
	if not shell or not shell.has_method("show_hint"):
		return {"success": false, "error": "no_player_shell", "message": "PlayerShell unavailable"}
	var biome_name := _get_current_biome_name()
	var plot_idx: int = _instrument.current_plot_idx if _instrument else -1
	var pos := _get_grid_position()
	var tip := "[color=#d4c5ff]🔍 Qubit:[/color] [b]%s[/b] plot %d (%s)" % [biome_name, plot_idx, pos]
	shell.show_hint(tip)
	return {"success": true, "biome": biome_name, "plot_idx": plot_idx}


func _execute_merchant_hint() -> Dictionary:
	# Scan local biome emojis vs wallet; surface the most depleted as a toast tip.
	var shell := _resolve_player_shell()
	if not shell or not shell.has_method("show_hint"):
		return {"success": false, "error": "no_player_shell", "message": "PlayerShell unavailable"}

	var hint_text := _build_market_tip()
	shell.show_hint("[color=#cfe6ff]🤝 Merchant:[/color] " + hint_text)
	return {"success": true, "hint": hint_text}


func _execute_discovery_forecast() -> Dictionary:
	# Show discovery compass — top unexplored biomes ranked by player affinity overlap.
	var shell := _resolve_player_shell()
	if not shell or not shell.has_method("show_hint"):
		return {"success": false, "error": "no_player_shell", "message": "PlayerShell unavailable"}
	if not farm or not farm.has_method("compute_discovery_forecast"):
		return {"success": false, "error": "no_farm", "message": "Farm unavailable"}

	var forecast: Dictionary = farm.compute_discovery_forecast()
	if forecast.is_empty():
		shell.show_hint("[color=#a8d5a2]🧭 Compass:[/color] All biomes already discovered.")
		return {"success": true}

	# Sort by probability descending, locked entries last.
	var entries: Array = []
	for biome_name in forecast.keys():
		var entry = forecast[biome_name]
		entries.append({
			"name": biome_name,
			"prob": float(entry.get("probability", 0.0)),
			"locked": bool(entry.get("locked", false)),
		})
	entries.sort_custom(func(a, b): return float(a.prob) > float(b.prob))

	var lines: PackedStringArray = ["[color=#a8d5a2]🧭 Compass:[/color]"]
	var shown := 0
	for e in entries:
		if shown >= 4:
			break
		var label: String
		if e.locked:
			label = "  %s · [color=#666666]locked[/color]" % e.name
		else:
			var pct: int = int(float(e.prob) * 100.0)
			label = "  %s · [color=#ffe080]%d%%[/color]" % [e.name, pct]
		lines.append(label)
		shown += 1

	shell.show_hint("\n".join(lines))
	return {"success": true, "forecast": forecast}


func _build_market_tip() -> String:
	# Find the most depleted emoji among biome poles + merchant contract resources.
	# Gather candidate emojis: all poles in active biomes
	var candidates: Array[String] = []
	if farm and farm.grid:
		for biome_name in farm.grid.get_biome_names():
			var biome = farm.grid.get_biome(biome_name)
			if biome and biome.viz_cache:
				for emoji in biome.viz_cache.get_emojis():
					if emoji != "" and not candidates.has(emoji):
						candidates.append(emoji)
	# Also include the merchant contract tokens themselves
	for token in ["🧺", "🤝", "📜"]:
		if not candidates.has(token):
			candidates.append(token)

	if candidates.is_empty():
		return "Nothing to report — the markets are quiet today."

	# Find which candidate has the lowest balance in the wallet
	var economy = ActionCostRuntime.resolve_economy(farm)
	var wallet: Dictionary = economy.emoji_credits if economy and "emoji_credits" in economy else {}
	var poorest_emoji := candidates[0]
	var poorest_amount: float = float(wallet.get(poorest_emoji, 0))
	for emoji in candidates:
		var amount := float(wallet.get(emoji, 0))
		if amount < poorest_amount:
			poorest_amount = amount
			poorest_emoji = emoji

	var template: String = _MARKET_QUIP_TEMPLATES[_market_quip_idx % _MARKET_QUIP_TEMPLATES.size()]
	_market_quip_idx += 1
	return template % poorest_emoji


func _resolve_player_shell() -> Node:
	var nodes := get_tree().get_nodes_in_group("player_shell") if is_inside_tree() else []
	return nodes[0] if not nodes.is_empty() else null


func _get_current_biome_name() -> String:
	# Get the current biome name from instrument or ActiveBiomeManager.
	if _instrument and _instrument.current_biome != "":
		return _instrument.current_biome
	if _active_biome_mgr:
		return _active_biome_mgr.get_active_biome()
	return ""




func _refresh_plot_tiles(positions: Array[Vector2i]) -> void:
	# Refresh plot tiles after stateful actions.
	if not plot_grid_display:
		return
	for pos in positions:
		if plot_grid_display.has_method("update_tile_from_farm"):
			plot_grid_display.update_tile_from_farm(pos)






## ============================================================================
## HELPER FUNCTIONS
## ============================================================================

func _get_current_biome():
	# Get the biome for the current selection.
	if not farm or not farm.grid:
		return null

	var biome_name = _instrument.current_biome if _instrument.current_biome != "" else ""
	if biome_name == "":
		biome_name = _active_biome_mgr.get_active_biome() if _active_biome_mgr else "BioticFlux"

	return farm.grid.get_biome(biome_name)


func _get_grid_position() -> Vector2i:
	# Convert current selection to grid grid_pos.
	var plot_idx = _instrument.current_plot_idx if _instrument.current_plot_idx >= 0 else 0
	var biome_name = _instrument.current_biome if _instrument.current_biome != "" else ""

	return _get_grid_position_for(plot_idx, biome_name)


func _get_grid_position_for(plot_idx: int, biome_name: String) -> Vector2i:
	# Convert plot + biome selection to a grid grid_pos.
	var biome_row = farm.get_biome_row(biome_name) if farm and farm.has_method("get_biome_row") else 0
	return Vector2i(plot_idx, biome_row)


func _get_active_biome_register_count() -> int:
	# Get register (qubit) count for the currently active biome.
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
	# Get array of selected positions (currently just single selection).
	var positions: Array[Vector2i] = []
	if _instrument.current_plot_idx >= 0:
		positions.append(_get_grid_position())
	return positions



func _get_homerow_positions() -> Array[Vector2i]:
	# Return all plot positions for the current biome row (one per qubit/column).
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
		biome_name = _active_biome_mgr.get_active_biome() if _active_biome_mgr else ""
	if biome_name == "" and farm and farm.grid and farm.grid.has_biomes():
		var loaded_names = farm.grid.get_biome_names()
		if not loaded_names.is_empty():
			biome_name = str(loaded_names[0])
	if farm.has_method("get_biome_row"):
		return farm.get_biome_row(biome_name)
	return 0


func _set_selection_for_grid_pos(grid_pos: Vector2i) -> void:
	# Update current_selection to match the specified grid grid_pos.
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
	# Restore the selection state and refresh visual highlight.
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
	# Convert keycode to string representation.
	match keycode:
		KEY_0: return "0"
		KEY_1: return "1"
		KEY_2: return "2"
		KEY_3: return "3"
		KEY_4: return "4"
		KEY_5: return "5"
		KEY_6: return "6"
		KEY_7: return "7"
		KEY_8: return "8"
		KEY_9: return "9"
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
	# Get current plot selection.
	return current_selection.duplicate()


func can_execute_action(action_key: String) -> bool:
	# Check if action can succeed with current selection (for UI highlighting).
	if current_selection.get("plot_idx", -1) < 0:
		return false
	if not farm:
		return false

	var selected_positions = _get_selected_positions()
	var current_pos = _get_grid_position()
	return ActionValidator.can_execute_action(
		action_key,
		ToolConfig.get_current_frame(),
		"",
		{},
		farm,
		selected_positions,
		current_pos
	)


func get_current_frame() -> String:
	# Get the active archetype frame name. Empty string = Ace.
	return ToolConfig.get_current_frame()


func get_current_tool_info() -> Dictionary:
	# Get info about the active archetype frame.
	var frame_name: String = ToolConfig.get_current_frame()
	return {
		"frame": frame_name,
		"name": ToolConfig.get_frame_name_label(frame_name),
		"emoji": ToolConfig.get_frame_emoji(frame_name),
		"time_scale": ToolConfig.get_frame_time_scale(frame_name),
		"mode": ToolConfig.get_frame_mode_name(frame_name),
		"mode_label": ToolConfig.get_frame_mode_label(frame_name),
		"mode_emoji": ToolConfig.get_frame_mode_emoji(frame_name)
	}


func get_actions_for_current_frame() -> Dictionary:
	# Get current action slots for the active archetype frame.
	return ToolConfig.get_all_actions(ToolConfig.get_current_frame())



## ============================================================================
## GLASS OVERLAY API
## Called from overlays (e.g. BiomeInspectorOverlay) to sync selection and
## dispatch quantum actions without requiring homerow key presses.
## ============================================================================

func set_active_selection(plot_idx: int, biome_name: String) -> void:
	# Set the active plot/biome selection without visual checkbox side-effects.

	# Called from glass overlays when the user navigates qubit cards with WASD.
	# Updates instrument state so subsequent dispatch_action() fires on the
	# correct qubit.
	current_selection = {"plot_idx": plot_idx, "biome": biome_name, "subspace_idx": -1}
	if _instrument:
		_instrument.current_plot_idx = plot_idx
		_instrument.current_biome = biome_name
	selection_changed.emit(plot_idx, biome_name)


func dispatch_action(key: String) -> void:
	# Dispatch a Q/E/R/F quantum action from a glass overlay.

	# Equivalent to the player pressing the key in the main gameplay view.
	# The overlay must have called set_active_selection() first so the correct
	# plot/biome is targeted.
	if key == "F":
		# F cycles the tool group — handle separately so overlays can call it too
		var result = _instrument.action_cycle_group() if _instrument and _instrument.has_method("action_cycle_group") else {}
		if not result.is_empty():
			_verbose.info("input", "🔄", "Tool group cycled from overlay")
		return
	_perform_action(key)


## ============================================================================
## TIMESCALE CONTROLS (stride + resolution)
## ============================================================================

func _decrease_time_controls() -> void:
	# Decrease stride and simulation speed together (- key).
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
	# Increase stride and simulation speed together (= key).
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
	# Decrease observation stride - slower playback (- key).

	# PER-BIOME CONTROL:
	# - Main game: Affects only the currently selected biome (ActiveBiomeManager)
	# - Generator/test scene: affects only the last biome that was generated
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
	# Increase observation stride - faster playback (= key).

	# PER-BIOME CONTROL:
	# - Main game: Affects only the currently selected biome (ActiveBiomeManager)
	# - Generator/test scene: affects only the last biome that was generated
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
	# Decrease quantum evolution resolution - finer substeps (Shift+- key).

	# PER-BIOME CONTROL:
	# - Main game: Affects only the currently selected biome (ActiveBiomeManager)
	# - Generator/test scene: affects only the last biome that was generated
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
	# Increase quantum evolution resolution - coarser substeps (Shift+= key).

	# PER-BIOME CONTROL:
	# - Main game: Affects only the currently selected biome (ActiveBiomeManager)
	# - Generator/test scene: affects only the last biome that was generated
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
	var gsm = get_node_or_null("/root/GameStateManager")
	if not gsm or not gsm.current_state:
		return
	if stride != null:
		gsm.current_state.observation_stride = int(stride)
	if quantum_time_scale != null:
		gsm.current_state.quantum_time_scale = float(quantum_time_scale)


func _persist_runtime_resolution(max_evolution_dt: float) -> void:
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.current_state:
		gsm.current_state.max_evolution_dt = max_evolution_dt
