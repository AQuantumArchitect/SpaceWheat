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
const LindbladHandler = preload("res://Core/Instrumentation/Handlers/LindbladHandler.gd")
const GranularityController = preload("res://Core/Utilities/GranularityController.gd")
const UIProgression = preload("res://UI/Core/UIProgression.gd")
const SpectralPreview = preload("res://Core/QuantumSubstrate/SpectralPreview.gd")
const LoopCardCls = preload("res://UI/Overlays/LoopCard.gd")

## Ace F (Fast-Forward) advances the closed evolution by this many phrames per press.
const ACE_FAST_FORWARD_PHRAMES := 4

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

var _current_submenu: Dictionary = {}  # Local UI cache for signal emission
var _in_submenu: bool = false  # Local UI cache for signal emission
var _submenu_page: int = 0  # Local UI cache for signal emission
var _confirm_pending: Dictionary = {}  # {action, emoji, label} — awaiting QF confirm

# Dispatch forensics ring: {frame, action, success} per _run_action execution.
# Read by rig `dispatch_ledger`; same action twice on one frame = double-fire.
const DISPATCH_LEDGER_CAP := 64
var dispatch_ledger: Array[Dictionary] = []

## WASD crawl ring: 0=surface 1=frame 2=biome 3=plot. Owned HERE, co-located with
## current_plot_idx (on _instrument) so the two can never desync — entering/leaving
## the plot ring (layer 3) is the same mutation that selects/clears the plot. The
## PlayerShell forwards the raw W/S/A/D + direct-pick keys and paints from the
## cursor_layer_changed signal; it no longer holds its own copy of this state.
var cursor_layer: int = 2

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
## Emitted whenever cursor_layer changes. PlayerShell connects this to repaint the
## active ring (action bar + plot grid). Keeps the painter (PlayerShell, which holds
## the chrome refs) decoupled from the owner (QII, which holds the state).
signal cursor_layer_changed(layer: int)

# Actions that modify density matrix at phrame 0 (require buffer invalidation)
const BUFFER_INVALIDATING_ACTIONS: Array[String] = [
	# Druid frame: reversible unitary rotations + Hadamard
	"rotate_up", "rotate_down", "hadamard",
	# Spark frame: instant pole shifts (strong one-shot drive/decay)
	"spark_north", "spark_south",
	# Ace frame: coherent Rabi preparation
	"plant",
	# Merchant frame: persistent Lindbladian contracts (settle stops them)
	"drain", "pump", "settle",
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
	if farm != null and farm.has_signal("identity_band_changed") \
			and not farm.identity_band_changed.is_connected(_on_identity_band_changed):
		farm.identity_band_changed.connect(_on_identity_band_changed)
	_verbose.info("input", "~", "Farm injected into QuantumInstrumentInput")


func inject_plot_grid_display(pgd_ref) -> void:
	# Inject PlotGridDisplay reference for visual selection updates.
	plot_grid_display = pgd_ref
	# Back-ref so tile taps route through the one-finger seam (handle_bubble_tap).
	if pgd_ref != null and "instrument_input" in pgd_ref:
		pgd_ref.instrument_input = self
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

## True when a live submenu or a pending destructive confirm owns the E/F keys
## (submenu slot-select uses E; the destructive-confirm chord uses F). PlayerShell's
## toast grammar (F flatten / E pause-decay) must YIELD E/F to this context, or the
## confirm chord and the inject submenu's E-slot can never receive their key.
func owns_ef_keys() -> bool:
	if not _confirm_pending.is_empty():
		return true
	return _instrument != null and _instrument.is_in_submenu()


## Whether a destructive confirm (Trim/Cull/Break) is currently armed, awaiting
## its F-confirm. Exposed so callers outside this script (e.g.
## UIContextController, deciding whether the F chip should render enabled)
## don't need to reach into the private _confirm_pending dict directly.
func has_pending_confirm() -> bool:
	return not _confirm_pending.is_empty()


## The armed confirm's display label ("Cull TheDemos", "Trim 🌾/👥", ...), or
## "" if nothing is pending.
func pending_confirm_label() -> String:
	return str(_confirm_pending.get("label", "")) if not _confirm_pending.is_empty() else ""


## Cancels an armed destructive confirm and says so out loud (silent cancels
## ate actions and confused the harvest loop). This is the ONE place that
## clears _confirm_pending outside of F actually confirming it — every
## dispatch path that isn't the F-confirm itself (keyboard's own key handler,
## mouse Q/E/R chip taps, hat switches, biome switches, ESC) funnels through
## here, so "anything but confirming cancels" can't silently diverge between
## keyboard and mouse (mouse-only campaign wave 15: a mouse tap on an
## unrelated chip left a destructive confirm armed, and a LATER unrelated F
## tap silently fired it instead of its own labeled verb).
## Public twin for tap routes (the ⚠ confirm toast's body-click, via
## PlayerShell._route_to_callable "cancel_confirm"): dismissing that toast
## used to leave the confirm ARMED with no visible prompt, so a later
## unrelated F fired it blind. No-op when nothing is pending.
func cancel_pending_confirm() -> void:
	_cancel_pending_confirm()


func _cancel_pending_confirm() -> void:
	if _confirm_pending.is_empty():
		return
	var cancelled_label := str(_confirm_pending.get("label", "action"))
	_confirm_pending = {}
	var shell := _resolve_player_shell()
	if shell and shell.has_method("show_hint"):
		shell.show_hint("[color=#88aabb]%s cancelled[/color]" % cancelled_label, 2)


func _unhandled_key_input(event: InputEvent) -> void:
	# Handle keyboard input for the quantum instrument.
	if not event is InputEventKey or not event.pressed:
		return
	if event.echo:
		return

	var key = InputBindingRegistry.get_label_for_keycode(event.keycode)

	# Any key other than F cancels a pending confirm-chord. Only destructive
	# verbs (Trim/Cull/Break) arm the chord now; safe verbs fire immediately.
	if key != "F":
		_cancel_pending_confirm()

	# Auto-close submenu when any non-action key is pressed
	if _instrument.is_in_submenu() and key not in ["Q", "E", "R", "F"]:
		_close_submenu()

	# Archetype hat row: 4, 5, 6, 7, 8, 9, 0 → frame.
	# Re-pressing the active hat falls back to ACE — the documented default
	# toolkit. It used to target FRAME_NULL, a dead state with no verbs and a
	# blank action bar (fleet: "re-press doesn't return to Ace").
	if ToolConfig.HAT_KEY_TO_FRAME.has(key):
		var hat_frame: String = ToolConfig.HAT_KEY_TO_FRAME[key]
		var target_frame: String = ToolConfig.FRAME_ACE if ToolConfig.get_current_frame() == hat_frame else hat_frame
		# Progressive disclosure (phase-2 funnel): a locked hat's key redirects
		# instead of acting. Ace/Icon/Druid never lock (starter kit); the
		# fall-back-to-Ace re-press path always passes.
		if not UIProgression.is_hat_active(target_frame):
			UIProgression.redirect_locked()
			get_viewport().set_input_as_handled()
			return
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

	# Fractal depth: ] descends into the focused register's icon world,
	# Shift+] ascends one level. Claimed from KEYBOARD_GRAMMAR.md's reserved
	# set (the doc's own rule: new features take a reserved key rather than
	# overload a bound one). Before this the whole fractal mechanic — which
	# has a real cost, a gate and save state — was reachable ONLY by clicking
	# a 3D portal satellite, so a keyboard-only player could never use it
	# (docs/CAMPAIGN_STATE_2026-08-04.md §5.4).
	if event.keycode == KEY_BRACKETRIGHT:
		if event.is_shift_pressed():
			_ascend_fractal_level()
		else:
			_descend_into_focused_register()
		get_viewport().set_input_as_handled()
		return

	# Apostrophe: bulk select / clear toggle on the active biome's plots.
	# Empty selection → check every register; non-empty → clear all checks.
	if key == "'":
		_toggle_bulk_check_active_biome()
		get_viewport().set_input_as_handled()
		return

	# Selection rows (formerly the separate _unhandled_input path): direct-pick a
	# biome (TYUIOP), plot (GHJKL;), or subspace (M,./). Disjoint from the QERF
	# quartet below, so order here is just precedence, not collision avoidance.
	if _handle_biome_row_input(event):
		get_viewport().set_input_as_handled()
		return
	if _handle_plot_row_input(event):
		get_viewport().set_input_as_handled()
		return
	if _handle_subspace_row_input(event):
		get_viewport().set_input_as_handled()
		return

	# Action keys — one dispatch authority shared with pointer chips (invoke_action).
	match key:
		"Q", "E", "R", "F":
			_dispatch_action_key(key, event.is_shift_pressed())
			get_viewport().set_input_as_handled()


## Single dispatch authority for the Q/E/R/F verb quartet. Both entry points —
## keyboard (_unhandled_key_input) and pointer/touch chips (invoke_action via
## PlayerShell._route_action_key) — MUST land here, so the "submenu owns
## Q/E/R/F while open" rule can never diverge between them (#266: chip clicks
## bypassed the submenu branch and fired the frame verb underneath the picker).
func _dispatch_action_key(key: String, shift: bool = false) -> void:
	# Keyboard's own cancel-on-any-non-F-key already ran by the time this is
	# reached via _unhandled_key_input (harmless no-op here, second time).
	# Pointer/touch chips reach this DIRECTLY with no such upstream check, so
	# without this a mouse tap on a different chip left a destructive confirm
	# silently armed for a LATER unrelated F tap to fire (mouse-only campaign
	# wave 15).
	if key != "F":
		_cancel_pending_confirm()
	match key:
		"Q", "E", "R":
			if _instrument and _instrument.is_in_submenu():
				_handle_submenu_action(key)
			elif shift:
				_perform_shift_key_action(key)
			else:
				_perform_action(key)
		"F":
			# F = confirm a pending QF destructive action, or page/close a
			# submenu, or dispatch a frame-defined F verb if one exists.
			if not _confirm_pending.is_empty():
				var pending := _confirm_pending.duplicate()
				_confirm_pending = {}
				if bool(pending.get("shift_batch", false)):
					_run_shift_batch(
						str(pending.get("shift_action_name", "")),
						pending.get("shift_positions", []),
						str(pending.get("shift_symbol", "")),
						str(pending.get("shift_log_label", "")))
				else:
					_run_action(pending["action"], pending.get("emoji", ""), pending.get("label", ""))
			elif _instrument and _instrument.is_in_submenu():
				# F pages a multi-page submenu — the picker's documented F-cycling.
				# It used to close instead, which stranded every option past the
				# first three: with >3 known icons the plant picker could never
				# offer the rest (sensor leg L2b: 🪵/🪓 unreachable on a 9-icon
				# save). ESC remains the close key (grammar: F does not unwind).
				if _instrument.current_submenu_data.get("max_pages", 1) > 1:
					_cycle_submenu_page()
				else:
					_close_submenu()
			else:
				var f_action = ToolConfig.get_action(ToolConfig.get_current_frame(), "F")
				if shift and str(f_action.get("shift_action", "")) != "":
					# This branch bypasses _perform_action/ActionValidator entirely
					# (today only Ace's Shift+F reap), so the verb-level funnel has
					# to be checked here too — gated on the BASE key (F), same as
					# the plain-F dispatch below.
					if not UIProgression.is_verb_active(ToolConfig.get_current_frame(), "F"):
						UIProgression.redirect_locked()
						return
					# The shifted verb carries its OWN funnel gate on top of the base
					# key's: Ace Shift+F (reap) unlocks at the Act-0 capstone step,
					# because reap is once-affordable early (Fibonacci 🍼 costs) and
					# reaps every biome at once — an early mash must not spend the
					# only bottle on an undeveloped field. Redirect names the live
					# objective, per the funnel law.
					if not UIProgression.is_verb_active(ToolConfig.get_current_frame(), "shift+F"):
						UIProgression.redirect_locked()
						return
					# Shift+F = the season-scale time verb (Ace: Reap Season).
					# Biome-wide — no checked-plot batch, dispatch directly.
					_run_action(str(f_action["shift_action"]), str(f_action.get("emoji", "")),
						str(f_action.get("shift_label", f_action.get("label", ""))))
				elif not f_action.is_empty():
					_perform_action("F")
				else:
					RefusalVoice.note("nothing on F in this hat")


# The biome/plot/subspace selection rows used to live in a SECOND input callback
# (`_unhandled_input`, InputMap-action driven) that raced `_unhandled_key_input`
# by Godot priority. They are now decoded by raw keycode (via InputBindingRegistry,
# the same shared ring source S3 introduced) and dispatched from the single
# `_unhandled_key_input` path — one decode, one explicit precedence. Each helper
# takes the live event so Shift state and consume signalling stay local.

func _handle_biome_row_input(event: InputEvent) -> bool:
	var i: int = InputBindingRegistry.biome_index_for_keycode(event.keycode)
	if i < 0:
		return false
	var key_label: String = InputBindingRegistry.BIOME_ACTIONS[i]
	if _active_biome_mgr:
		var slot_key = _active_biome_mgr.get_slot_key(i)
		if slot_key != "":
			key_label = slot_key
	_select_biome(i, key_label)
	return true


func _handle_plot_row_input(event: InputEvent) -> bool:
	# 6 plot slots (G H J K L ;) — the 7th ring keycode (') is bulk-select, not a plot.
	var i: int = InputBindingRegistry.plot_index_for_keycode(event.keycode, 6)
	if i < 0:
		return false
	if event.is_shift_pressed():
		# Shift+GHJKL; — toggle checkbox without moving highlight
		_toggle_check_at_plot_idx(i)
	else:
		# Plain GHJKL; — move highlight only (re-press on current plot toggles check)
		_select_plot(i, InputBindingRegistry.HOMEROW_ACTIONS[i])
	return true


func _handle_subspace_row_input(event: InputEvent) -> bool:
	var key := InputBindingRegistry.get_label_for_keycode(event.keycode)
	var i: int = int(InputBindingRegistry.SUBSPACE_ROW.get(key, -1))
	if i < 0:
		return false
	_select_subspace(i, key)
	return true


## ============================================================================
## ARCHETYPE FRAME MANAGEMENT
## ============================================================================

func _select_frame_hat(frame_name: String) -> void:
	# Select an archetype frame (hat row 4-0). Empty string = Ace.
	if not ToolConfig.select_frame(frame_name):
		_verbose.warn("input", "⚠️", "Ignored invalid frame selection '%s'" % frame_name)
		return
	# Same cancel keyboard gets for free via _unhandled_key_input's top-level
	# check — this is the single hat-switch entry for BOTH keyboard and mouse
	# (ToolSelectionRow taps land here too), so without it a mouse hat switch
	# left a pending confirm armed (mouse-only campaign wave 15).
	_cancel_pending_confirm()
	# Same for an open submenu (#511): keyboard auto-closes on any non-QERF
	# key (_unhandled_key_input's top-level check), but a mouse hat tap comes
	# straight here, bypassing it. Without this, UIContextController's OWN
	# submenu mirror still gets cleared by its frame_changed handler (so the
	# action bar visibly repaints to the new hat's chips — looks cancelled),
	# while the real instrument stayed armed underneath: the NEXT verb tap
	# dispatched through _handle_submenu_action against the stale picker
	# instead of the hat the player thinks they're using — spending
	# resources/burning a register slot on an option they never chose.
	_close_submenu()
	frame_changed.emit(frame_name)

	# Icon-hat focus: do NOT clear here. Lesson I is 5 → pick → 2 (mirror)
	# and needs the plot. Add Icon still gets an unfocused inject mode via
	# _on_mode_changed when the player actually enters inject (mode 1).

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
		RefusalVoice.note("no hat selected — 4-0 picks one, Tab cycles its modes")
		return
	var new_index = ToolConfig.cycle_frame_mode(frame_name)
	if new_index < 0:
		_verbose.debug("input", "~", "No mode cycle for frame %s (single mode)" % frame_name)
		RefusalVoice.note("this hat has one mode — Tab has nothing to cycle")
		return
	_on_mode_changed(frame_name, new_index)


func _on_mode_changed(frame_name: String, mode_index: int) -> void:
	# Shared mode-change emission.
	var mode_label = ToolConfig.get_frame_mode_label(frame_name)
	var mode_emoji = ToolConfig.get_frame_mode_emoji(frame_name)
	frame_mode_changed.emit(frame_name, mode_index, mode_label)
	_verbose.info("input", "~", "Mode: %s (%s)" % [mode_label, mode_emoji])
	# Inject (Icon mode 0) needs an unfocused plot so mouse can see Add Icon.
	# Mirror (mode 1) must KEEP the plot — that is Lesson I.
	if frame_name == ToolConfig.FRAME_ICON and mode_index == 0 and _instrument:
		_instrument.current_plot_idx = -1
		_instrument.last_selected_position = GridSentinel.INVALID_POSITION
		if plot_grid_display:
			plot_grid_display.set_selected_plot(GridSentinel.INVALID_POSITION)


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
		RefusalVoice.note("no option on %s here — F pages, ESC closes" % action_key)
		return  # Stay in submenu

	# Check if option is disabled
	if not action_data.get("enabled", true):
		_verbose.info("input", "📋", "Option disabled: %s" % action_data.get("label", ""))
		# Silent before this fix (sweep_main, first-arc pass): a disabled/
		# unaffordable option pressed indistinguishably from a working one —
		# no toast, no wallet change, no menu close. Same silent-picker class
		# marathon #9 fixed nearby for the bare-{north,south} path; this
		# disabled branch was missed.
		_toast_player("✗ %s — not available" % str(action_data.get("label", action_key)))
		return  # Stay in submenu

	var action = action_data.get("action", "")

	# Icon-injection options carry bare {north, south, cost} — no action name —
	# so selection fell through EVERY branch and closed the menu having planted
	# nothing (marathon #9: the buildout's true blocker, silent since the
	# submenu's option shape and this dispatcher diverged).
	if action == "" and action_data.has("north") and action_data.has("south"):
		var pick := {"north": str(action_data.get("north", "")),
					 "south": str(action_data.get("south", ""))}
		if pick["north"] != "" and pick["south"] != "":
			_verbose.info("input", "📋", "You selected: %s - injecting..." % action_data.get("label", ""))
			_execute_inject_icon(pick)
		_close_submenu()
		return

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
		# Refusals speak (anti-gating) — a picker that closes with no biome bound
		# must not read as "selection doesn't work".
		_toast_player("✗ the icon would not take — no biome selected")
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
		# Success speaks too (anti-gating): a silent success reads exactly like a
		# dead key — the biome grows a qubit off-screen and the player sees nothing.
		_toast_player("✓ %s/%s took root in %s — +1 qubit" % [
			str(icon.get("north", "")), str(icon.get("south", "")), str(biome.get_biome_type())])

		# Invalidate buffer (icon injection adds qubits, modifies density matrix)
		_invalidate_biome_buffer_for_action("inject_icon")

		_append_dispatch_ledger("inject_icon", true)
		# (story notification now fires inside QuantumInstrument.action_inject_icon_pair)
		action_performed.emit("inject_icon", {
			"success": true,
			"north_emoji": icon.get("north", ""),
			"south_emoji": icon.get("south", ""),
			"cost": cost,
			"biome": biome.name
		})
	else:
		_verbose.warn("input", "+", "Icon injection failed: %s" % result.get("message", result.get("error", "unknown")))
		# Refusals speak — the picker closing silently after a failed inject
		# read as "selection doesn't work" (marathon #9).
		_toast_player("✗ the icon would not take — %s" % str(result.get("message", result.get("error", "unknown reason"))))
		_append_dispatch_ledger("inject_icon", false)
		action_performed.emit("inject_icon", result)


func build_chip_context() -> ChipContext:
	# Used by _perform_action (dispatch resolution) AND UIContextController
	# (chip text) — both read the SAME context so what a chip shows is exactly
	# what its key fires.
	var biome = _get_current_biome()
	var qc = biome.quantum_computer if biome else null
	# Sticky focus, same law as _get_selected_positions(): off the plot ring
	# (hat switch / B lens clear current_plot_idx) the last-focused register is
	# still the action target — the chip must describe THAT plot.
	var qid: int = int(_instrument.current_plot_idx) if _instrument else -1
	var ctx_pos := GridSentinel.INVALID_POSITION
	if qid >= 0:
		ctx_pos = _get_grid_position()
	elif _instrument and _instrument.last_selected_position != GridSentinel.INVALID_POSITION:
		ctx_pos = _instrument.last_selected_position
		qid = ctx_pos.x
	var bound := false
	if farm and farm.grid and ctx_pos != GridSentinel.INVALID_POSITION:
		var ctx_plot = farm.grid.get_plot(ctx_pos)
		bound = ctx_plot != null and ctx_plot.terminal != null
	return ChipContext.new(qc, qid, bound, farm)


func _build_chip_context() -> ChipContext:
	return build_chip_context()


func _execute_toggle_berry_track() -> Dictionary:
	# Toggle Berry-phase tracking on the focused qubit. The integrator seeds
	# itself from the next slice's Bloch vector — no explicit seed needed.
	var biome = _get_current_biome()
	if biome == null:
		return {"success": false, "error": "no_biome",
				"message": "Track needs a biome underfoot — T Y U switch biomes."}
	var qc = biome.quantum_computer
	if qc == null or qc.berry_register == null:
		return {"success": false, "error": "no_quantum_computer",
				"message": "This biome isn't evolving yet — nothing to track."}
	var qid: int = int(_instrument.current_plot_idx) if _instrument else -1
	if qid < 0 or qid >= qc.register_map.num_qubits:
		_verbose.info("input", "⌖", "No focused qubit to track")
		return {"success": false, "error": "no_qubit",
				"message": "Track needs a focused plot — G H J K L ; picks one."}
	if qc.berry_register.is_tracked(qid):
		qc.berry_register.stop_tracking(qid)
		_verbose.info("input", "⌖", "Stopped tracking qubit %d" % qid)
		# The toggle is a trap when silent: testers pressed F to "poll" ripeness
		# and destroyed their own loop (fleet #4). Say what just happened.
		_toast_player("⌖ tracking stopped — the loop is lost. F re-tracks.")
		var stop_result := {"success": true, "tracking": false, "qubit": qid}
		_record_projection_action("toggle_berry_track", stop_result)
		return stop_result
	qc.berry_register.start_tracking(qid)
	_verbose.info("input", "⌖", "Started tracking qubit %d" % qid)
	# The un-ripenable trap speaks at TRACK time: a qubit with no transverse
	# H term keeps θ≈0 → encloses no solid angle → never ripens alone. Still
	# tracks (no gating — the state may couple later); just never silent.
	var track_msg: String
	if qc.has_method("qubit_has_transverse_term") and not qc.qubit_has_transverse_term(qid):
		track_msg = "⌖ tracking — but this axis barely precesses alone (no transverse term). Couple it — plant a word that speaks to it — or it will not ripen."
	else:
		track_msg = "⌖ tracking — time ripens the loop; Icon-hat R incorporates when ripe."
	# Teach the per-biome clock at the exact moment waiting begins, once per
	# run — fleet data says players never learned −/= existed (some pressed
	# fast-forward ~50× per berry instead of touching the dial).
	if not _clock_taught:
		_clock_taught = true
		track_msg += "  ⏩ = speeds this biome's clock (up to ×32), − slows it."
	_toast_player(track_msg)
	var start_result := {"success": true, "tracking": true, "qubit": qid}
	_record_projection_action("toggle_berry_track", start_result)
	return start_result

static var _clock_taught: bool = false


func _execute_incorporate_icon() -> Dictionary:
	# Thin adapter: Icon-hat R harvests the focused qubit's icon into the player's
	# signature. All three coupled effects (learn + harvest + story) happen atomically
	# behind the engine seam — see QuantumInstrument.action_incorporate. The UI only
	# translates the keypress into the command and mirrors the result for display.
	if _instrument == null:
		return {"success": false, "error": "no_instrument"}
	var result: Dictionary = _instrument.action_incorporate()
	# Success and refusal both speak (anti-gating law, same as inject_icon):
	# _toast_berry_whisper existed but nothing called it — the harvest was mute,
	# and a silent success reads exactly like a dead key.
	if result.get("success", false):
		var inc_n := str(result.get("north_emoji", ""))
		var inc_s := str(result.get("south_emoji", ""))
		if bool(result.get("new_icon", false)):
			_toast_berry_whisper(_get_current_biome(), inc_n, inc_s,
					float(result.get("phase", 0.0)))
		elif bool(result.get("already_known", false)):
			_toast_player("🧬 %s/%s re-harvested — phase counted, the word was already yours" % [inc_n, inc_s])
		else:
			# The berry was spent but the word did NOT join: the north emoji
			# already anchors another signature word. Saying "woven into your
			# signature" here sent hub leg L4d chasing a signature that never
			# grew (anti-gating law: no false help).
			_toast_player("✗ %s already anchors one of your words — %s/%s cannot join your signature (berry still counted)" % [inc_n, inc_n, inc_s])
	elif str(result.get("message", "")) != "":
		_toast_player("✗ %s" % str(result.get("message", "")))
	# Mirror on the QII signal too, for UI listeners (the engine emits its own). Same
	# double-emit pattern as inject_icon. Incorporate does NOT touch the biome ρ, so no
	# lookahead-buffer invalidation (it only consumes a berry entry + grows the signature).
	action_performed.emit("incorporate_icon", result)
	return result


## ============================================================================
## MAJORANA BRIDGE VERBS (Spark frame, 🌉 mode — BridgeRegister, What Connects)
## R spans (two-step: near shore, then far shore in another biome), F braids,
## Q fuses, E reads the card. Bridge ops never touch biome density matrices, so
## no lookahead buffer invalidation is needed.
## ============================================================================

## The near shore awaiting its far shore. UI state only — never serialized.
var _pending_bridge_anchor: Dictionary = {}


func _bridge_anchor_here() -> Dictionary:
	# {biome, north, south} for the focused qubit, or {} when nothing is focused.
	var biome = _get_current_biome()
	if biome == null:
		return {}
	var qc = biome.quantum_computer
	if qc == null or qc.register_map == null:
		return {}
	var qid: int = int(_instrument.current_plot_idx) if _instrument else -1
	if qid < 0 or qid >= qc.register_map.num_qubits:
		return {}
	var axis = qc.register_map.axis(qid)
	if axis == null or axis.is_empty():
		return {}
	var bname: String = BiomeBase.type_name(biome)
	return {"biome": bname, "north": str(axis.get("north", "")), "south": str(axis.get("south", ""))}


func _execute_bridge_anchor() -> Dictionary:
	if farm == null or not ("bridge_register" in farm) or farm.bridge_register == null:
		return {"success": false, "error": "no_bridge_register"}
	var here := _bridge_anchor_here()
	if here.is_empty():
		_verbose.info("input", "⚓", "No focused qubit to anchor")
		return {"success": false, "error": "no_anchor",
			"message": "⚓ focus a qubit first — the span needs an atom pair to hold"}
	if _pending_bridge_anchor.is_empty() or str(_pending_bridge_anchor.get("biome", "")) == str(here.get("biome", "")):
		_pending_bridge_anchor = here
		_toast_note("⚓ near shore set: %s (%s/%s) — anchor a far shore in another biome" % [
			str(here["biome"]), str(here["north"]), str(here["south"])])
		action_performed.emit("bridge_anchor", {"success": true, "pending": true, "anchor": here})
		_record_projection_action("bridge_anchor", {"success": true, "pending": true, "anchor": here})
		return {"success": true, "pending": true}
	var near: Dictionary = _pending_bridge_anchor
	var result: Dictionary = farm.bridge_register.build(near, here)
	if result.get("success", false):
		_pending_bridge_anchor = {}
		var ga: float = farm.bridge_register.end_rate_for(farm, str(near["biome"]), str(near["north"]), str(near["south"]))
		var gb: float = farm.bridge_register.end_rate_for(farm, str(here["biome"]), str(here["north"]), str(here["south"]))
		var g: float = BridgeRegister.KAPPA * ga * gb
		var fate: String = "immortal — a shore is sealed" if g <= 0.0 \
			else "fading at Γ = %.4f (second order — gentler than either shore alone)" % g
		_toast_note("🌉 the bridge stands: %s ⇌ %s · %s" % [str(near["biome"]), str(here["biome"]), fate])
	else:
		_toast_note("🌉 %s" % str(result.get("message", result.get("error", "the span failed"))))
	action_performed.emit("bridge_anchor", result)
	_record_projection_action("bridge_anchor", result)
	return result


func _execute_bridge_braid() -> Dictionary:
	if farm == null or not ("bridge_register" in farm) or farm.bridge_register == null:
		return {"success": false, "error": "no_bridge_register"}
	var bname := _get_current_biome_name()
	var spans: Array = farm.bridge_register.bridges_at(bname)
	if spans.is_empty():
		return {"success": false, "error": "no_bridge_here",
			"message": "🪢 no bridge anchored in %s" % bname}
	var bridge: Dictionary = spans[0]
	var end: String = "a" if str(bridge.get("biome_a", "")) == bname else "b"
	var result: Dictionary = farm.bridge_register.braid(int(bridge.get("id", -1)), end)
	if result.get("success", false):
		var odds: Dictionary = result.get("odds", {})
		var gate: String = "S" if end == "a" else "√X"
		_toast_note("🪢 braid %s at %s — parity now %d%% even (the far shore speaks %s; the word's order matters)" % [
			gate, bname, int(round(float(odds.get("even", 0.0)) * 100.0)), "√X" if end == "a" else "S"])
	action_performed.emit("bridge_braid", result)
	_record_projection_action("bridge_braid", result)
	return result


func _execute_bridge_fuse() -> Dictionary:
	if farm == null or not ("bridge_register" in farm) or farm.bridge_register == null:
		return {"success": false, "error": "no_bridge_register"}
	var bname := _get_current_biome_name()
	var spans: Array = farm.bridge_register.bridges_at(bname)
	if spans.is_empty():
		return {"success": false, "error": "no_bridge_here",
			"message": "⚛ no bridge anchored in %s to fuse" % bname}
	var bridge: Dictionary = spans[0]
	var result: Dictionary = farm.bridge_register.fuse(int(bridge.get("id", -1)), randf())
	if not result.get("success", false):
		return result
	# Surprisal payout at the mean of the two shores' temperatures, split across
	# both anchor atoms — the nonlocal harvest pays both shores at once.
	var p: float = float(result.get("probability", 1.0))
	var kt_a: float = EnergyPricing.biome_temperature(farm.grid.get_biome(str(result.get("biome_a", ""))), farm)
	var kt_b: float = EnergyPricing.biome_temperature(farm.grid.get_biome(str(result.get("biome_b", ""))), farm)
	var reward: int = maxi(1, int(round(EnergyPricing.surprisal_energy(p, (kt_a + kt_b) * 0.5))))
	var half: int = maxi(1, int(round(reward * 0.5)))
	if _instrument != null and _instrument.has_method("add_resource"):
		_instrument.add_resource(str(result.get("north_a", "")), half, "bridge_fusion")
		if reward - half > 0:
			_instrument.add_resource(str(result.get("north_b", "")), reward - half, "bridge_fusion")
	result["credits"] = reward
	var speaker := _native_speaker_for(_get_current_biome())
	var line: String = QuestVoice.bridge_whisper(speaker)
	if line != "":
		_toast_whisper("⚛ fusion: parity %s (p = %.2f) — +%d paid across both shores" % [
			str(result.get("outcome", "?")), p, reward], speaker, line)
	else:
		_toast_note("⚛ fusion: parity %s (p = %.2f) — +%d paid across both shores. The bridge is spent; looking closed it." % [
			str(result.get("outcome", "?")), p, reward])
	action_performed.emit("bridge_fuse", result)
	_record_projection_action("bridge_fuse", result)
	return result


func _execute_bridge_inspect() -> Dictionary:
	if farm == null or not ("bridge_register" in farm) or farm.bridge_register == null:
		return {"success": false, "error": "no_bridge_register"}
	var bname := _get_current_biome_name()
	var spans: Array = farm.bridge_register.bridges_at(bname)
	if spans.is_empty():
		if not _pending_bridge_anchor.is_empty():
			_toast_note("⚓ pending near shore: %s (%s/%s) — anchor a far shore in another biome" % [
				str(_pending_bridge_anchor.get("biome", "")),
				str(_pending_bridge_anchor.get("north", "")),
				str(_pending_bridge_anchor.get("south", ""))])
			return {"success": true, "pending": true}
		_toast_note("🌉 no bridge anchored in %s — Spark 🌉 R spans one" % bname)
		return {"success": false, "error": "no_bridge_here"}
	var bridge: Dictionary = spans[0]
	var odds: Dictionary = farm.bridge_register.parity_odds(int(bridge.get("id", -1)))
	var g: float = float(bridge.get("gamma", 0.0))
	var fate: String = "immortal (a shore is sealed)" if g <= 0.0 else "Γ = %.4f — second-order fade" % g
	_toast_note("🌉 %s ⇌ %s · parity %d%% even · coherence %.2f · %s · age %.0fs · braids %d" % [
		str(bridge.get("biome_a", "")), str(bridge.get("biome_b", "")),
		int(round(float(odds.get("even", 0.0)) * 100.0)), float(odds.get("coherence", 0.0)),
		fate, float(bridge.get("age", 0.0)),
		int(bridge.get("braids_a", 0)) + int(bridge.get("braids_b", 0))])
	return {"success": true, "bridge": bridge, "odds": odds}


## Compass (Operator 🧭) + mirror (Icon 🪞) verbs — thin adapter over the
## engine seam. All logic and quest-projection notification live on
## QuantumInstrument.action_*; here we only dispatch and speak the result
## (anti-gating law: a refused verb SAYS so).
const _GAUGE_VERB_ICONS := {
	"gauge_flip": "🧭", "wilson_inspect": "🔍", "gauge_fix": "🪮",
	"gauge_scramble": "🎲", "mark_reference": "⌂", "unmark_reference": "🪞",
	"interfere": "🪞",
}


## Quest-projection seam for UI-side verbs (bridge, berry toggle) with no
## engine action_* — without this, no history predicate can see them.
## Records successes only; refusals are toast-and-forget.
func _record_projection_action(action_name: String, payload: Dictionary) -> void:
	if _instrument == null or not payload.get("success", false):
		return
	if _instrument.has_method("record_projection_action"):
		_instrument.record_projection_action(action_name, payload)


func _execute_gauge_verb(action_name: String) -> Dictionary:
	if _instrument == null:
		return {"success": false, "error": "no_instrument"}
	var result: Dictionary = {}
	match action_name:
		"gauge_flip":
			result = _instrument.action_gauge_flip()
		"wilson_inspect":
			result = _instrument.action_wilson_inspect()
		"gauge_fix":
			result = _instrument.action_gauge_fix()
		"gauge_scramble":
			result = _instrument.action_gauge_scramble()
		"mark_reference":
			result = _instrument.action_mark_reference()
		"unmark_reference":
			result = _instrument.action_unmark_reference()
		"interfere":
			result = _instrument.action_interfere()
	var msg := str(result.get("message", ""))
	if msg != "":
		_toast_note("%s %s" % [str(_GAUGE_VERB_ICONS.get(action_name, "🧭")), msg])
	return result


## ============================================================================
## FRACTAL DEPTH — keyboard twin of the 3D portal satellites
## ============================================================================

## ] — descend into the focused register's icon world. Routes through the SAME
## instrument action the 3D descend portal taps (QuantumField3D._try_pick), so
## the cost, the incorporation gate and the depth cap stay one authority.
func _descend_into_focused_register() -> void:
	if _instrument == null or _active_biome_mgr == null:
		RefusalVoice.note("no live instrument — nothing to descend into")
		return
	var bname: String = str(_active_biome_mgr.get_active_biome())
	var qid: int = int(_instrument.current_plot_idx)
	if qid < 0:
		RefusalVoice.note("pick a register first (G-;) — ] descends into the one you're holding")
		return
	var result: Dictionary = _instrument.action_enter_icon(bname, qid)
	if bool(result.get("success", false)):
		_toast_note("🌀 descended into %s" % str(result.get("biome_name", "the icon")))
	else:
		# Server-side refusals (depth cap, unaffordable, ungated) must speak —
		# the 3D path already toasts them; the keyboard path must not be quieter.
		RefusalVoice.note(str(result.get("message", "the depths end here — this world descends no further")))


## Shift+] — ascend one fractal level (free; only descent charges).
func _ascend_fractal_level() -> void:
	if _instrument == null:
		RefusalVoice.note("no live instrument — nothing to ascend from")
		return
	var result: Dictionary = _instrument.action_ascend_fractal()
	if bool(result.get("success", false)):
		_toast_note("🌀 surfaced to %s" % str(result.get("biome_name", "the world above")))
	else:
		RefusalVoice.note(str(result.get("message", "already at the surface — nothing above this world")))


## Plain mechanics note through the PlayerShell hint channel (no voice line).
func _toast_note(head: String) -> void:
	var ps: Node = _resolve_player_shell()
	if ps != null and ps.has_method("show_hint"):
		ps.show_hint(head, 2, "")


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


func _maybe_toast_trade_whisper(result: Dictionary, verb: String) -> void:
	# A contract speaks when SIGNED (persistent channel installed), not while
	# it flows. Speaker: the biome's native faction — the country you contract in.
	if int(result.get("persistent_enabled", 0)) <= 0:
		return
	var biome = null
	if farm and farm.grid and farm.grid.has_method("get_biome"):
		biome = farm.grid.get_biome(_get_current_biome_name())
	var speaker := _native_speaker_for(biome)
	var line: String = QuestVoice.trade_whisper(speaker)
	var kind := str(result.get("channel_kind", "damp"))
	_toast_whisper("🤝 contract opened — %s %s channel · F settles" % [verb, kind], speaker, line)


func _toast_whisper(head: String, speaker: String, line: String) -> void:
	if line == "":
		return
	var ps: Node = _resolve_player_shell()
	if ps == null or not ps.has_method("show_hint"):
		return
	ps.show_hint("%s\n💬 %s“%s”" % [head, ("%s — " % speaker) if speaker != "" else "", line], 2, "")


## First native faction of the biome's canonical definition ("" if none).
func _native_speaker_for(biome) -> String:
	if biome == null:
		return ""
	var bname: String = BiomeBase.type_name(biome)
	var reg = load("res://Core/Biomes/BiomeRegistry.gd")
	if reg != null and reg.has_method("get_shared"):
		var shared = reg.get_shared()
		var canonical = shared.get_by_name(bname) if (shared != null and shared.has_method("get_by_name")) else null
		if canonical != null and canonical.has_method("first_native_faction"):
			return canonical.first_native_faction()
	return ""


## The moment a Berry loop is incorporated — the harvest is no longer mute.
func _toast_berry_whisper(biome, north: String, south: String, phase: float) -> void:
	var speaker := _native_speaker_for(biome)
	_toast_whisper("🧬 %s/%s woven into your signature · Ω = %+.2f rad" % [north, south, phase],
			speaker, QuestVoice.whisper("berry", speaker))


## The soul crossed a purity band (Farm.identity_band_changed): the identity ρ
## resolved upward or blurred downward past 0.2 / 0.5 / 0.8. Speaker: whoever
## holds the most of the player — the faction with the largest diagonal weight
## marks the change in its own voice (Core/Documentation/glossary/soul.md).
func _on_identity_band_changed(prev_band: String, new_band: String, purity: float, rising: bool) -> void:
	var speaker := ""
	if farm != null and ("faction_density" in farm) and farm.faction_density != null \
			and farm.faction_density.has_method("dominant_factions"):
		var top: Array = farm.faction_density.dominant_factions(1)
		if top.size() > 0:
			speaker = str(top[0].get("name", ""))
	var line: String = QuestVoice.self_resolve_whisper(speaker) if rising \
			else QuestVoice.self_fade_whisper(speaker)
	_toast_whisper("🧿 who you are: %s → %s · Tr(ρ²) = %.2f" % [prev_band, new_band, purity],
			speaker, line)


## An IMPROBABLE Born outcome (p below this) is the scar that taught you most —
## the surprisal payout law made audible (Core/Documentation/glossary/measurement.md).
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
		_append_dispatch_ledger("build_gate", false)
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

	_append_dispatch_ledger("build_gate", bool(result.get("success", false)))
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
		RefusalVoice.note("no biome in slot %s yet — Captain hat (7): R discovers one" % key)
		return

	var old_biome = _active_biome_mgr.get_active_biome()

	# Switch active biome, then repoint the Focus (same slot, keep checks, no action).
	_active_biome_mgr.set_active_biome(new_biome)
	confirm_biome_switch(old_biome, new_biome, key)


## Shared tail for any biome-switch trigger (TYUIOP direct-pick here, and mouse
## tab clicks via PlayerShell — see BiomeSelectionRow.biome_confirmed). Repoints
## the Focus and confirms the switch in text (fleet: 4 of 6 testers couldn't
## tell it worked) — without this, a mouse click landing on the biome tab bar
## switches biomes with zero visible feedback (mouse-only campaign wave 5).
func confirm_biome_switch(old_biome: String, new_biome: String, key: String) -> void:
	# Same cancel keyboard gets for free via _unhandled_key_input's top-level
	# check — this is the shared tail for BOTH keyboard (TYUIOP) and mouse
	# (BiomeSelectionRow tap) biome switches, so without it a mouse biome
	# switch left a pending confirm armed (mouse-only campaign wave 15).
	_cancel_pending_confirm()
	# Same for an open submenu (#511) — see _select_frame_hat's matching call
	# for the full failure mode. A mouse biome-tab tap reaches this directly,
	# bypassing keyboard's top-level auto-close.
	_close_submenu()
	_apply_biome_switch(old_biome, new_biome, key)
	if new_biome != old_biome:
		_toast_player("→ %s" % new_biome)


func _apply_biome_switch(old_biome: String, new_biome: String, key: String) -> void:
	# Centralized biome switch. Updates the Focus biome and repoints the cursor to
	# the SAME slot letter (G/H/J/K/L/;) in the new biome, clamped to its register
	# count. Keeps the multi-select checkboxes and fires NO action — selection is a
	# free, transient cursor move. Shared by the TYUIOP direct-pick and the WASD
	# biome-ring crawl, so the Focus never goes stale on a switch.
	_instrument.current_biome = new_biome
	var reg_count := _get_active_biome_register_count()
	if reg_count > 0:
		var slot := int(_instrument.current_plot_idx)
		if slot < 0:
			slot = 0
		slot = clampi(slot, 0, reg_count - 1)
		_instrument.current_plot_idx = slot
		var gp := _get_grid_position_for(slot, new_biome)
		_instrument.last_selected_position = gp
		if plot_grid_display and gp.x >= 0:
			plot_grid_display.set_selected_plot(gp)
		selection_changed.emit(slot, new_biome)
	else:
		_instrument.current_plot_idx = -1
	if _chain_tracker:
		_chain_tracker.record_observation(key, -1, new_biome, 0)
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
		RefusalVoice.note("no plot on that key here")
		return
	# Allow focusing an EMPTY plot the biome owns (assigned plots ≥ registers): an
	# empty plot is where you PLANT (inject) a new icon — Icon-R there opens the
	# injection submenu. Only reject plots the biome doesn't own at all.
	var plot_count = _get_active_biome_plot_count()
	if plot_count > 0 and plot_idx >= plot_count:
		_verbose.debug("input", "•", "Plot %d exceeds biome plots (%d)" % [plot_idx, plot_count])
		RefusalVoice.note("this biome has %d plot%s — G H J K L ; left to right" % [plot_count, "" if plot_count == 1 else "s"])
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
		# Focus/toggle is not exploration — reveal only fires from the real
		# Explore action (action_explore), not from touching the plot.
		if target_grid_pos.x >= 0:
			toggle_check(target_grid_pos)
		_verbose.debug("input", "~", "Plot %d in %s remains highlighted" % [plot_idx, biome_name])
		return

	# First tap on a different plot moves the highlight (Focus) there.
	_focus_plot(plot_idx, biome_name)
	_verbose.debug("input", "~", "Plot %d in %s" % [plot_idx, biome_name])


func _focus_plot(plot_idx: int, biome_name: String) -> Vector2i:
	# Pure Focus move — the shared tail of every deliberate plot pick (keyboard
	# GHJKL; and bubble taps). The instrument fields are the single source of
	# truth for the selection — no shadow dict. Selection is a free, transient
	# cursor move: it does NOT bind a terminal or fire any action (the live
	# bubble already renders from the QC; the terminal is created at strike-time
	# by Measure). plot_idx ≡ register_id. NO checkbox semantics here — the
	# second-tap check toggle belongs to _select_plot alone.
	var target_grid_pos = _get_grid_position_for(plot_idx, biome_name)
	_instrument.current_plot_idx = plot_idx
	_instrument.last_plot_idx = plot_idx
	_instrument.current_biome = biome_name
	_instrument.last_selected_position = target_grid_pos

	_verbose.debug("input", "📍", "SELECTION DEBUG: plot_idx=%d, biome=%s → grid_pos=%s" % [plot_idx, biome_name, target_grid_pos])

	if plot_grid_display and farm and target_grid_pos.x >= 0:
		plot_grid_display.set_selected_plot(target_grid_pos)
		_verbose.debug("input", "~", "Visual selection: %s" % target_grid_pos)

	# Empty ground is INVISIBLE under the 3D renderer: no orb exists for a
	# register-less plot, and the 2D rack that used to draw one is hidden in 3D
	# mode (PlotGridDisplay.visible == false), so set_selected_plot() above
	# paints nothing anyone can see. The focus really moved — F would explore
	# HERE now — but the screen is byte-identical, which is a silent state
	# change, the exact thing the anti-gating law forbids.
	#
	# It bites on the player's very first instruction: Act 0 says "Pick a plot
	# with G H J K L ; — or just tap it", the starting biome has ONE register,
	# and pressing H..; moves the cursor onto empty ground in total silence.
	# The keyboard literalist and the lost-lamb both stalled right here; the
	# lamb, re-deriving its objective every turn, correctly called it LOOPING.
	if plot_idx >= _get_active_biome_register_count():
		var plot_keys := InputBindingRegistry.get_plot_keys()
		var plot_key := str(plot_keys[plot_idx]).to_upper() if plot_idx < plot_keys.size() else "?"
		RefusalVoice.note("%s is empty ground — nothing grows here yet" % plot_key)

	# Focus is a free cursor move, not exploration — the bubble wakes only when
	# the player actually takes the Explore action (QuantumInstrument.action_explore),
	# not on mere focus/select/tap.

	selection_changed.emit(plot_idx, biome_name)
	return target_grid_pos


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


## Single mutation point for cursor_layer (the WASD crawl ring). Idempotent.
## Drives the plot-ring enter/leave lifecycle so cursor_layer==3 ⇔ a plot is
## selected, then emits cursor_layer_changed for PlayerShell to repaint. This is
## the one place the ring state changes — PlayerShell forwards here instead of
## holding its own copy.
func set_cursor_layer(layer: int, keep_plot_selection: bool = false) -> void:
	layer = clampi(layer, 0, 3)
	if cursor_layer == layer:
		return
	var old_layer := cursor_layer
	cursor_layer = layer
	# Plot ring lifecycle: entering → auto-select plot 0; leaving via the WASD
	# crawl → clear selection. Direct picks (hat/biome keys) pass
	# keep_plot_selection=true: switching tools must not drop the workpiece —
	# clearing here made the first verb after EVERY hat switch fail while the
	# chip row still rendered the last-focused plot (fleet #4: "chip says
	# Incorporate, R says blocked" — two authorities disagreed on focus).
	if old_layer != 3 and layer == 3:
		enter_plot_ring()
	elif old_layer == 3 and layer != 3 and not keep_plot_selection:
		leave_plot_ring()
	cursor_layer_changed.emit(layer)


## Step the ring by ±delta (wraps across all 4 layers). Used by W/S spin.
func change_cursor_layer(delta: int) -> void:
	set_cursor_layer(posmod(cursor_layer + delta, 4))


## ESCAPE: unwind exactly ONE gameplay level, innermost first. Returns true if it
## consumed the ESC (so PlayerShell does NOT then open the system menu); false when
## there's nothing left to unwind and ESC should fall through to the system menu.
## Order: open submenu → pending destructive confirm → plot-ring selection.
## (Overlay-stack unwinding is handled by PlayerShell before this is reached.)
func try_escape_unwind() -> bool:
	# 1. A submenu is the innermost modal — close it first.
	if _instrument and _instrument.is_in_submenu():
		_close_submenu()
		return true
	# 2. A pending destructive confirm — cancel it (loud, same as a non-F key).
	if has_pending_confirm():
		_cancel_pending_confirm()
		return true
	# 3. The plot ring — step up to the biome ring; the leave_plot_ring lifecycle
	#    clears the selection.
	if cursor_layer == 3:
		set_cursor_layer(2)
		return true
	# 3b. A plot is still selected while off the plot ring (e.g. kept across a biome
	#     switch) — set_cursor_layer would no-op, so deselect directly.
	if _instrument and int(_instrument.current_plot_idx) >= 0:
		leave_plot_ring()
		return true
	return false


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
	if plot_grid_display and plot_grid_display.has_method("clear_selection"):
		plot_grid_display.clear_selection()


func cycle_frame_hat(delta: int) -> void:
	# Step through FRAME_IDS by ±1, wrapping. Bound to TAB and to the
	# WASD frame-layer step.
	ToolConfig.cycle_frame(delta)
	# Progressive disclosure (phase-2 funnel): the cycle SKIPS locked hats —
	# a silent skip, not a toast (a wheel gesture must not flood). Bounded:
	# Ace is always active, so this terminates within one lap.
	var guard := 0
	while guard < ToolConfig.FRAME_IDS.size() \
			and not UIProgression.is_hat_active(ToolConfig.get_current_frame()):
		ToolConfig.cycle_frame(delta)
		guard += 1
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
			_apply_biome_switch(old_biome, new_biome, "D" if delta > 0 else "A")
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

	# Reset current selection state (instrument is the single source of truth)
	_instrument.current_plot_idx = -1
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
## Routes through _dispatch_action_key — the SAME authority as the keyboard —
## so an open submenu's Q/E/R chips select options (and F closes) instead of
## firing the frame verb hidden underneath the picker (#266).
func invoke_action(action_key: String, shift: bool = false) -> void:
	_dispatch_action_key(action_key, shift)


## Public entry point for a bubble tap (mouse/touch) — the tap IS the farming
## gesture. Focuses the tapped plot, then fires hat-INDEPENDENT Ace verbs:
## True when a stacked overlay above the gameplay base should block field
## taps. The biome microscope ("biome_detail") is the lens exception.
func _tap_blocked_by_overlay() -> bool:
	var shell = InstrumentLocator.resolve_player_shell(self)
	if shell == null or not ("overlay_stack" in shell) or shell.overlay_stack == null:
		return false
	var stack = shell.overlay_stack
	if stack.is_empty():
		return false
	var top = stack.get_top()
	if top == null:
		return false
	return str(top.get("overlay_name")) != "biome_detail"


## measure on a live bubble, pop on a measured one (a tap must never arm
## Captain-cull or a keyboard-F confirm chord). Dispatch goes through the SAME
## validator + _run_action tail as the keyboard, so refusal toasts, lookahead
## buffer invalidation, whispers and action_performed behave identically —
## one mechanics authority (anti-gating law). A tap on a non-active biome's
## station only switches + focuses; it never fires a verb on a biome the
## player isn't looking at.
func handle_bubble_tap(grid_pos: Vector2i, shift: bool = false) -> Dictionary:
	if not farm or not _instrument or not _active_biome_mgr or not farm.grid:
		return {"success": false, "error": "not_ready", "message": ""}

	# Modality: with an overlay open the field is background, not a target.
	# TouchInputManager classifies raw _input events, so GUI consumption alone
	# can't protect the world — the ONE mechanics seam enforces it. Single
	# designed exception: the biome microscope (B) is a lens over the live
	# farm, so bubbles stay interactive under it.
	if _tap_blocked_by_overlay():
		return {"success": false, "error": "overlay_open", "message": ""}

	# A tap is "any other input" — cancel a pending destructive confirm,
	# through the ONE cancel authority so it says so out loud (a bare direct
	# clear here used to cancel silently, the exact keyboard/mouse divergence
	# _cancel_pending_confirm's own doc-comment forbids).
	_cancel_pending_confirm()

	var biome_name: String = ""
	if farm.grid.has_method("get_plot_biome_assignment"):
		biome_name = str(farm.grid.get_plot_biome_assignment(grid_pos))
	if biome_name == "":
		return {"success": false, "error": "no_biome", "message": ""}

	if _chain_tracker:
		_chain_tracker.record_observation("tap", grid_pos.x, biome_name, 0)

	var active_biome: String = _active_biome_mgr.get_active_biome()
	if biome_name != active_biome:
		# Miniature tap: bring that biome forward and focus the tapped plot.
		_active_biome_mgr.set_active_biome(biome_name)
		_apply_biome_switch(active_biome, biome_name, "tap")
		_focus_plot(grid_pos.x, biome_name)
		return {"success": true, "action": "focus_biome"}

	# Same range guards as the keyboard pick (_select_plot).
	if farm.grid_config and grid_pos.x >= farm.grid_config.grid_width:
		return {"success": false, "error": "out_of_range", "message": ""}
	var plot_count = _get_active_biome_plot_count()
	if plot_count > 0 and grid_pos.x >= plot_count:
		return {"success": false, "error": "out_of_range", "message": ""}

	# Shift-tap = the mouse twin of Shift+GHJKL; (_toggle_check_at_plot_idx):
	# toggle the multi-select checkbox WITHOUT moving focus or running the
	# Ace verb cycle below. Without this, hats that build a selection (e.g.
	# Operator's Bell weave — "hold Shift and tap two plot keys") had no
	# mouse path at all, the true Act-1 mouse-only ceiling (wave 6, earnest).
	if shift:
		toggle_check(grid_pos)
		return {"success": true, "action": "toggle_check", "checked": grid_pos in _instrument.checked_plots}

	# Selection FIRST, so the verb targets exactly what was tapped and every
	# downstream reader (action bar, B overlay) agrees with the tap. Focus
	# alone does not reveal — the bubble wakes only on the actual Explore
	# dispatch below (mirrors _focus_plot's own doc comment).
	_focus_plot(grid_pos.x, biome_name)

	var verb := predict_tap_verb(grid_pos)

	if not ActionValidator.can_execute_action_name(
		verb, farm, _get_selected_positions(), _get_grid_position()
	):
		_verbose.info("input", "•", "tap %s blocked%s" % [verb, _get_block_reason(verb)])
		return {"success": false, "blocked": true, "action": verb}

	match verb:
		"explore":
			return _run_action("explore", "🧭", "Explore")
		"measure":
			return _run_action("measure", "📊", "Strike")
		_:
			return _run_action("pop", "🎉", "Extract")


## What a tap on grid_pos would fire RIGHT NOW: measure on a live bubble, pop on
## a measured one, explore otherwise. All from farm ground truth (plot.terminal),
## via the terminal's OWN state-query methods (can_explore/can_measure/can_pop) —
## NOT a hand-rolled is_bound/is_measured check. MEASURE calls release_register()
## as part of its execution (Terminal.gd), which intentionally sets is_bound=false
## while KEEPING is_measured=true (the register frees for reuse; the terminal
## keeps its frozen snapshot so it can still be popped) — a struck-but-unbound
## terminal is exactly can_pop()'s documented case. Gating on "is_bound" first, as
## this used to, excludes that case entirely and falls through to "explore": every
## mouse Strike immediately re-Explored instead of advancing to Extract, so the
## loop could never complete by tap alone. Mouse-only campaign, 2026-08-05.
## Pure read, no dispatch — handle_bubble_tap's own verb comes from here, and
## UIContextController calls it too to preview which Ace chip a tap would fire,
## so a click and its own preview can never name two different verbs.
func predict_tap_verb(grid_pos: Vector2i) -> String:
	if not farm or not farm.grid:
		return "explore"
	var plot = farm.grid.get_plot(grid_pos)
	var terminal = plot.terminal if plot else null
	if terminal == null:
		return "explore"
	if terminal.can_pop():
		return "pop"
	if terminal.can_measure():
		return "measure"
	return "explore"


## predict_tap_verb for whatever plot handle_bubble_tap would actually land on —
## the live cursor, or (off the plot ring) the last-focused register, exactly
## _get_selected_positions()'s own fallback. This is the position a plain tap
## acts on, NOT the Shift-click multi-select set (UIContextController's own
## _apply_probe_preview keys off that, separately, for its odds/outcome text).
func predict_tap_verb_for_focus() -> String:
	if not _instrument:
		return "explore"
	var positions := _get_selected_positions()
	if positions.is_empty():
		return "explore"
	return predict_tap_verb(positions[0])


func _perform_action(action_key: String) -> void:
	# Execute the action mapped to Q/E/R for the current archetype frame.

	# Args:
	# action_key: "Q" (DOWN), "E" (NEUTRAL), or "R" (UP)
	var current_frame_name: String = ToolConfig.get_current_frame()
	# Progressive disclosure (phase-3 funnel): a verb not yet unlocked within
	# an already-unlocked hat redirects instead of acting — same shape as the
	# hat-select guard in _unhandled_key_input. Act-0-only; every other verb
	# and every verb once Act 0 ends compares true here.
	if not UIProgression.is_verb_active(current_frame_name, action_key):
		UIProgression.redirect_locked()
		return
	var action_info = ToolConfig.get_action(current_frame_name, action_key)
	# Apply contextual chip resolver so dispatch matches what the chip displayed.
	# Resolvers may override `action` (and strip `submenu`) based on sim state.
	action_info = ChipResolverRegistry.resolve(action_info, _build_chip_context())

	if action_info.is_empty():
		_verbose.debug("input", "~", "No action for %s in frame %s" % [action_key, current_frame_name])
		RefusalVoice.note("nothing on %s in this hat" % action_key)
		return

	if bool(action_info.get("disabled", false)):
		# Refusals speak (anti-gating law): a resolver-disabled chip's key must
		# say WHY and what to do instead — the silent return here was the act-2
		# wall (Icon-hat R on a full untracked plot did nothing, and three relay
		# legs never found the incorporate/plant ritual). A disabled chip with
		# NO authored reason still speaks (generic), never dies silently.
		var disabled_reason := str(action_info.get("reason", ""))
		if disabled_reason != "":
			_toast_player("✗ %s" % disabled_reason)
		else:
			RefusalVoice.refuse(str(action_info.get("label", action_key)), "not available here")
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
		RefusalVoice.note("nothing on %s in this mode" % action_key)
		return

	if not ActionValidator.can_execute_action_name(
		action_name, farm, _get_selected_positions(), _get_grid_position()
	):
		_verbose.info("input", "•", "%s blocked%s" % [
			action_info.get("label", action_name),
			_get_block_reason(action_name)
		])
		# Refusals speak (anti-gating law). This branch was verbose-only —
		# marathon #5 lost three legs to Captain-R 'Add Biome' silently
		# refusing on an unaffordable discovery (21🦅 vs 4 held).
		_toast_player("%s refused — %s" % [
			str(action_info.get("label", action_name)), _block_reason_for_player(action_name)])
		return

	if action_info.get("destructive", false):
		_confirm_pending = {
			"action": action_name,
			"emoji": emoji,
			"label": action_info.get("label", action_name),
		}
		var shell := _resolve_player_shell()
		if shell and shell.has_method("show_hint"):
			# Trimming moves the gap too — the island_free hint promises the
			# player can "unseat a heavy word"; show the what-if at the confirm.
			var gap_note := ""
			if action_name == "remove_icon":
				var trim_biome = _get_current_biome()
				var qid: int = int(_instrument.current_plot_idx) if _instrument else -1
				if trim_biome != null and trim_biome.has_method("spectral_gap_now") and qid >= 0:
					var cur: float = trim_biome.spectral_gap_now()
					var after: float = SpectralPreview.preview_gap_without(trim_biome, qid)
					if cur >= 0.0 and after >= 0.0:
						var arrow := "▼" if after < cur - 0.005 else ("▲" if after > cur + 0.005 else "→")
						gap_note = "  ·  gap %.2f→%.2f %s" % [cur, after, arrow]
			shell.show_hint(
				"[color=#ff9966]⚠ %s[/color]%s  —  press [b]F[/b] to confirm; any other key or tap cancels" \
				% [action_info.get("label", action_name), gap_note], 3, "", "cancel_confirm")
		return

	_run_action(action_name, emoji if emoji != "" else action_name, action_info.get("label", action_name))


func _get_block_reason(_action_name: String) -> String:
	return ""


## Player-words reason the validator refused an action — checks the same
## authorities the validator consulted, so the toast tells the truth.
func _block_reason_for_player(action_name: String) -> String:
	match action_name:
		"discover_biome":
			if farm and farm.has_method("can_discover_biome"):
				var gate: Dictionary = farm.can_discover_biome()
				var gmsg := str(gate.get("message", ""))
				# "Insufficient resources" without the number cost marathon #6
				# three legs — name the cost and the holdings.
				if not bool(gate.get("ok", false)) and gmsg != "" and gmsg != "Insufficient resources":
					return gmsg
			var short := _cost_shortfall_words("discover_biome")
			if short != "":
				return short
			return "no unexplored biome in reach"
		"remove_biome":
			# Cull refusals are RULES, not shortfalls — "you cannot cull your own
			# home", "seed country", "need at least two biomes". Quoting the
			# generic fallback here made the hard identity rule read as though no
			# guard existed at all, which is how a tester concludes the rule is
			# missing and files it as a bug. Same shape as discover_biome above.
			if farm and farm.has_method("can_remove_biome"):
				var cull_gate: Dictionary = farm.can_remove_biome()
				var cull_msg := str(cull_gate.get("message", ""))
				if not bool(cull_gate.get("ok", false)) and cull_msg != "":
					return cull_msg
			var short_cull := _cost_shortfall_words(action_name)
			if short_cull != "":
				return short_cull
			return "nothing valid to act on here"
		"inject_icon", "remove_icon":
			var short2 := _cost_shortfall_words(action_name)
			if short2 != "":
				return short2
			return "nothing valid to act on here"
		"explore":
			return "no unbound plot to explore here"
		"measure":
			# "F explores first" is FALSE HELP when nothing is focused — in that
			# state F fast-forwards instead (L1e sensor wall: the advice loops).
			if not _has_focused_plot():
				return "no plot selected — G H J K L ; picks one, then F explores it"
			var track_hint := _tracked_elsewhere_hint()
			if track_hint != "":
				return track_hint
			return "nothing live to strike — F explores first"
		"pop", "reap":
			if not _has_focused_plot():
				return "no plot selected — G H J K L ; picks one"
			return "nothing measured to extract here — R strikes first"
		_:
			return "not possible on this plot right now"


## Ace-hat R ("Strike") and Icon-hat R ("Incorporate") are different verbs
## sharing one key. A player following the tutorial copy ("Icon hat (5) ...
## R incorporates") who never actually switched hats hits "nothing live to
## strike" on every press with no signal that the fix is a hat swap, not an
## explore (wave-2 sensor wall: 32 presses, no cost ever charged). Name the
## other hat's verb when the focused qubit is mid-track.
func _tracked_elsewhere_hint() -> String:
	var biome = _get_current_biome()
	if biome == null or biome.quantum_computer == null or biome.quantum_computer.berry_register == null:
		return ""
	var qid: int = int(_instrument.current_plot_idx) if _instrument else -1
	if qid >= 0 and biome.quantum_computer.berry_register.is_tracked(qid):
		return "this plot is being tracked — switch to Icon hat (5), R incorporates there"
	return ""


## True when a plot is focused AND maps to a real register in the current
## biome — the same validity shape _bridge_anchor_here uses. Everything the
## Ace verbs can act on requires this; refusal copy branches on it.
func _has_focused_plot() -> bool:
	var biome = _get_current_biome()
	if biome == null or biome.quantum_computer == null or biome.quantum_computer.register_map == null:
		return false
	var qid: int = int(_instrument.current_plot_idx) if _instrument else -1
	return qid >= 0 and qid < biome.quantum_computer.register_map.num_qubits


## "needs 21🦅 — you hold 4" for an unaffordable action; "" when affordable.
func _cost_shortfall_words(action_name: String) -> String:
	var pf: Dictionary = ActionCostRuntime.preflight_action(farm, action_name)
	if bool(pf.get("ok", true)):
		return ""
	var cost: Dictionary = ActionCostRuntime.get_action_cost(farm, action_name, {})
	if cost.is_empty():
		return str(pf.get("message", "it costs more than you hold"))
	var econ = farm.get("economy") if farm else null
	var parts: Array[String] = []
	for emoji in cost:
		var need := int(round(float(cost[emoji])))
		var have := int(econ.get_resource(emoji)) if econ else 0
		if have < need:
			parts.append("%d%s (you hold %d)" % [need, str(emoji), have])
	if parts.is_empty():
		return str(pf.get("message", "it costs more than you hold"))
	return "needs " + ", ".join(parts)


func _perform_shift_key_action(action_key: String) -> void:
	# Apply the Q/E/R action across all checked plots (multi-select batch operation).

	# For gate actions (Druid frame: unitary gates), uses batch injection with single buffer invalidation.
	# Selection order is preserved - gates are applied in the order plots were checked.
	var current_frame_name: String = ToolConfig.get_current_frame()
	# Progressive disclosure (phase-3 funnel): structurally separate dispatch
	# path from _perform_action (Shift+Q/E/R bulk-apply), so it needs its own
	# verb-lock guard — same table, same redirect.
	if not UIProgression.is_verb_active(current_frame_name, action_key):
		UIProgression.redirect_locked()
		return
	var action_info = ToolConfig.get_action(current_frame_name, action_key)
	if action_info.is_empty():
		RefusalVoice.note("nothing on Shift+%s in this hat" % action_key)
		return

	# Use shift_action if defined, otherwise use normal action
	var action_name = action_info.get("shift_action", action_info.get("action", ""))
	if action_name == "":
		RefusalVoice.note("nothing on Shift+%s in this mode" % action_key)
		return

	var symbol = "⇧%s" % action_key
	var log_label = action_info.get("shift_label", action_info.get("label", action_name))

	# Use checked plots instead of entire homerow (ORDER PRESERVED from selection)
	var positions = _instrument.checked_plots.duplicate()
	if positions.is_empty():
		# Honest refusal (anti-gating law): a silent mass-op reads as a dead key.
		_toast_player("%s needs checked plots — Shift+click plots (or Shift+G H J K L ;) to mark them first." % log_label)
		return

	# Destructive bulk actions confirm before firing — same QF confirm chord the
	# singular (non-shift) path already uses (_perform_action, above). Before this
	# fix Shift+Q on Icon's remove_icon (destructive) mass-fired on every checked
	# plot with zero confirmation. Arm the SAME _confirm_pending mechanism, scaled
	# to the batch; F re-enters via _dispatch_action_key's confirm branch.
	if action_info.get("destructive", false):
		_confirm_pending = {
			"shift_batch": true,
			"shift_action_name": action_name,
			"shift_positions": positions,
			"shift_symbol": symbol,
			"shift_log_label": log_label,
			"label": "%s ×%d" % [log_label, positions.size()],
		}
		var shell := _resolve_player_shell()
		if shell and shell.has_method("show_hint"):
			shell.show_hint(
				"[color=#ff9966]⚠ %s ×%d[/color]  —  press [b]F[/b] to confirm; any other key or tap cancels" \
				% [log_label, positions.size()], 3, "", "cancel_confirm")
		return

	_run_shift_batch(action_name, positions, symbol, log_label)


## The actual batch-apply body (gate path + non-gate path), shared by the
## immediate (non-destructive) dispatch and the QF-confirmed destructive one.
func _run_shift_batch(action_name: String, positions: Array, symbol: String, log_label: String) -> void:
	var original_selection := {
		"plot_idx": int(_instrument.current_plot_idx),
		"biome": str(_instrument.current_biome),
	}

	# BATCH GATE PATH: For Druid frame (unitary) gate actions, use batch injection
	# This applies all gates in selection order with SINGLE buffer invalidation
	if _is_gate_action(action_name):
		_perform_batch_gate_action(action_name, positions, symbol, log_label)
		_restore_selection(original_selection)
		return

	# NON-GATE PATH: Apply the action across checked positions
	_verbose.info("input", symbol, "Batch %s on %d checked plots" % [log_label, positions.size()])

	var fired := 0
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
		fired += 1
		_refresh_plot_tiles([pos])
	_restore_selection(original_selection)
	if fired == 0:
		# Every checked plot refused — say so instead of pretending nothing happened.
		_toast_player("%s: no valid targets among %d checked plots." % [log_label, positions.size()])
	elif fired < positions.size():
		# Partial batch: a silent skip reads as "the feature only did one" (QA2).
		_toast_player("%s: %d of %d checked plots — %d skipped (not valid targets)." % [
				log_label, fired, positions.size(), positions.size() - fired])


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
		# A mass-op that does nothing must SAY so (anti-gating law) — this was a
		# verbose-only bail: no toast, no action_performed, a silent Shift+verb.
		_verbose.warn("input", "⚠️", "No valid qubits for batch gate")
		var first_resolved: Dictionary = PlotRegisterResolver.resolve(farm, positions[0]) if positions.size() > 0 else {}
		var nq := int(first_resolved.get("num_qubits", 0))
		var bname := str(first_resolved.get("biome_name", ""))
		var msg := "No qubits under the checked plots"
		if bname != "" and nq > 0:
			msg = "%s holds %d qubit%s — the checked slots are beyond them" % [
				bname, nq, "" if nq == 1 else "s"]
		var refusal := {"success": false, "error": "no_valid_qubits", "message": msg}
		_toast_refusal(log_label, refusal)
		action_performed.emit(action_name, refusal)
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
	# Delegates to the ONE slot→qubit authority shared with the display and
	# GateActionHandler (this used to be a third private resolution path).
	return PlotRegisterResolver.resolve(farm, pos).get("biome")


func _get_qubit_for_position(pos: Vector2i, _biome) -> int:
	return int(PlotRegisterResolver.resolve(farm, pos).get("register_id", -1))


## Dispatch forensics: one ledger entry per verb execution. Probes read this
## (rig `dispatch_ledger`) to assert exactly-once dispatch per input — the
## double-dispatch bug class becomes directly observable instead of inferred
## from wallet drain. Two entries with the same action on the same frame is
## the double-fire signature. Submenu-routed actions (build_gate, inject_icon)
## went through _execute_build_gate/_execute_inject_icon, which only emitted
## action_performed — never wrote here, so a mouse-only Bell weave or icon
## injection was invisible to this ledger (mouse-only campaign wave 7,
## lost-lamb: real entanglement succeeded with zero dispatch_ledger entry).
func _append_dispatch_ledger(action_name: String, success: bool) -> void:
	dispatch_ledger.append({
		"frame": Engine.get_process_frames(),
		"action": action_name,
		"success": success,
	})
	if dispatch_ledger.size() > DISPATCH_LEDGER_CAP:
		dispatch_ledger.pop_front()


func _run_action(action_name: String, log_symbol: String, action_label: String) -> Dictionary:
	# Execute an action and emit logging + signal.
	var result = _execute_action(action_name)

	_append_dispatch_ledger(action_name, bool(result.get("success", false)))

	# Invalidate buffer if action modified density matrix at phrame 0
	if result.get("success", false) and action_name in BUFFER_INVALIDATING_ACTIONS:
		_invalidate_biome_buffer_for_action(action_name)

	_log_action_result(action_name, log_symbol, action_label, result)

	# Surface EVERY failed action to the player as a toast — feedback is never gated.
	# (The old allowlist of error codes both missed cases and was buggy: it checked
	# "insufficient_funds" while ProbeActions returns "insufficient_resources", so cost
	# failures like "Need ❄️ to measure" never showed.) If a started action fails and
	# carries a message, the player sees it.
	if not bool(result.get("success", true)):
		_toast_refusal(action_label, result)
	return result


## The ONE player-facing refusal toast (anti-gating law: a refused verb must SAY so).
## Handlers ship honest reasons in result.message; if one arrives empty, the fallback
## still names the verb — "H-Gate blocked" with no reason was itself a law violation.
##
## The raw `error` code used to be appended here so a silent handler stayed
## debuggable from the player's chair. It came out because three Spark verbs
## toasted authored English and THEN returned a message-less error, and
## PlayerShell stacks toasts rather than replacing: the player read
## "🪢 no bridge anchored in Village" and "Span refused (no_bridge_here)" at the
## same time. Those handlers now carry their sentence in `message`, and the code
## still reaches the log below — the player's chair is not the debugger's chair.
func _toast_refusal(action_label: String, result: Dictionary) -> void:
	var msg := str(result.get("message", ""))
	if msg == "" or msg == "unknown":
		_verbose.warn("input", "✗", "%s refused with no message; error=%s" % [
			action_label, str(result.get("error", "none"))])
		msg = "%s isn't available right now" % action_label
	var shell := _resolve_player_shell()
	if shell and shell.has_method("show_hint"):
		shell.show_hint("[color=#ff9966]✗ %s[/color]" % msg, 3)


func _run_cleanup_action(action_name: String, log_symbol: String, action_label: String) -> void:
	# Execute a cleanup version of an action (e.g., pop cleanup).
	var result = _execute_cleanup_action(action_name)
	_log_action_result(action_name, log_symbol, action_label, result)
	if not bool(result.get("success", true)):
		_toast_refusal(action_label, result)


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
		# Player-facing refusal toast lives in ONE place — _toast_refusal, fired
		# from the _run_action/_run_cleanup_action tails. This used to also toast
		# here, which double-toasted every message-carrying refusal (gray + orange).
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

	var biome_name = BiomeBase.type_name(biome)

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
		"plant":
			result = _instrument.action_plant(positions)
			if result.get("success", false):
				_refresh_plot_tiles(positions)
		"drain":
			result = _instrument.action_drain(positions, _merchant_channel_kind())
			if result.get("success", false):
				_refresh_plot_tiles(positions)
				_maybe_toast_trade_whisper(result, "📤 export")
		"pump":
			result = _instrument.action_pump(positions, _merchant_channel_kind())
			if result.get("success", false):
				_refresh_plot_tiles(positions)
				_maybe_toast_trade_whisper(result, "📥 import")
		"settle":
			result = _instrument.action_settle(positions)
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
		"fast_forward":
			# Ace F — let H spin the odds forward (advance the closed evolution).
			result = _instrument.time_skip(ACE_FAST_FORWARD_PHRAMES)
			# Visible pulse: silent fast-forward reads as "F is broken" (fleet).
			if result.get("success", true):
				_toast_player("⏩ the odds spin forward")
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
		"bridge_anchor":
			result = _execute_bridge_anchor()
		"bridge_braid":
			result = _execute_bridge_braid()
		"bridge_fuse":
			result = _execute_bridge_fuse()
		"bridge_inspect":
			result = _execute_bridge_inspect()
		"gauge_flip", "wilson_inspect", "gauge_fix", "gauge_scramble", \
		"mark_reference", "unmark_reference", "interfere":
			result = _execute_gauge_verb(action_name)
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
			# (story notification now fires inside QuantumInstrument.action_remove_icon)
		"remove_biome":
			result = MacroActions.dispatch(_instrument, MacroActions.KIND_REMOVE_BIOME)
		"inspect_qubit":
			result = _execute_inspect_qubit()
		"read_price":
			result = _execute_read_price()
		"jolt_inspect":
			result = _execute_jolt_inspect()
		"forecast_biome_discovery":
			result = _execute_discovery_forecast()
		_:
			_verbose.warn("input", "?", "Unknown action: %s" % action_name)
			return {"success": false, "error": "unknown_action", "message": "Unknown action: %s" % action_name}

	return result


func _execute_inspect_qubit() -> Dictionary:
	# Icon inject-mode E: the LoopCard for this biome (same gatherer Operator
	# 🧭 E uses). Do not promise a V-surface zoom that does not exist.
	var biome = _get_current_biome()
	if biome == null:
		return {"success": false, "error": "no_biome", "message": "no biome under the cursor"}
	var card: Dictionary = LoopCardCls.gather(biome, farm)
	var card_text := LoopCardCls.format_text(card)
	var biome_name := _get_current_biome_name()
	var plot_idx: int = _instrument.current_plot_idx if _instrument else -1
	if card_text == "":
		card_text = "no loop ledger yet — track a qubit (F) or read fences on Operator 🧭"
	_toast_note("🔍 %s" % card_text)
	return {
		"success": true,
		"biome": biome_name,
		"plot_idx": plot_idx,
		"loop_card": card,
		"message": card_text,
	}


func _merchant_channel_kind() -> String:
	# The Merchant sub-mode (1/2/3) IS the channel: thermal / dephase / damp.
	var kind := ToolConfig.get_frame_mode_name(ToolConfig.FRAME_MERCHANT)
	return kind if kind in ["thermal", "dephase", "damp"] else "damp"


func _axis_gauge(pos: Vector2i) -> Dictionary:
	# Shared readout behind the Spark gauge and the Merchant order book:
	# axis pair, pole populations, live kT, surprisal unit prices, regime.
	if not farm or not farm.grid:
		return {}
	var biome = farm.grid.get_biome_for_plot(pos)
	if not biome or not biome.quantum_computer:
		return {}
	var pair: Dictionary = LindbladHandler._resolve_axis_pair(farm, pos)
	var north := str(pair.get("north", ""))
	var south := str(pair.get("south", ""))
	if north == "" and south == "":
		return {}
	var qc = biome.quantum_computer
	var kT: float = EnergyPricing.biome_temperature(biome, farm)
	var p_n: float = clampf(float(qc.get_population(north)), 0.0, 1.0) if north != "" else 0.0
	var p_s: float = clampf(float(qc.get_population(south)), 0.0, 1.0) if south != "" else 0.0
	var bloch_r := -1.0
	var binding: Dictionary = LindbladHandler._resolve_axis_binding(farm, pos, biome)
	var reg := int(binding.get("register_id", -1))
	if reg >= 0 and qc.has_method("export_bloch_packet"):
		var packet: PackedFloat64Array = qc.export_bloch_packet()
		if packet.size() >= (reg + 1) * 9:
			bloch_r = packet[reg * 9 + 5]
	return {
		"biome": biome,
		"biome_name": BiomeBase.type_name(biome),
		"north": north, "south": south,
		"p_north": p_n, "p_south": p_s,
		"kT": kT,
		"units_north": EnergyPricing.drive_units(p_n, kT) if north != "" else 0,
		"units_south": EnergyPricing.drive_units(p_s, kT) if south != "" else 0,
		"open": bool(qc.is_open_here()),
		"bloch_r": bloch_r,
	}


func _execute_jolt_inspect() -> Dictionary:
	# Spark ⚡ E — the jolt gauge: pole odds, Bloch radius, kT, cost each way.
	var shell := _resolve_player_shell()
	if not shell or not shell.has_method("show_hint"):
		return {"success": false, "error": "no_player_shell", "message": "PlayerShell unavailable"}
	var gauge := _axis_gauge(_get_grid_position())
	if gauge.is_empty():
		return {"success": false, "error": "no_axis", "message": "No plot with a live axis selected"}
	var seal_txt := "" if bool(gauge.open) else " · [color=#8899aa]sealed — the enclave holds[/color]"
	var r_txt := (" · r %.2f" % float(gauge.bloch_r)) if float(gauge.bloch_r) >= 0.0 else ""
	var text := "[color=#ffe080]⚡ %s — jolt gauge[/color] · kT %.1f%s%s\n  ↑ %s p %.2f costs %d× %s · ↓ %s p %.2f costs %d× %s" % [
		str(gauge.biome_name), float(gauge.kT), r_txt, seal_txt,
		str(gauge.north), float(gauge.p_north), int(gauge.units_north), str(gauge.north),
		str(gauge.south), float(gauge.p_south), int(gauge.units_south), str(gauge.south)]
	shell.show_hint(text)
	return {"success": true, "gauge": gauge}


func _execute_read_price() -> Dictionary:
	# Merchant E — the order book: pole odds, kT, unit prices both directions,
	# and the native faction's standing factor. Read-only — prices are honest
	# without touching ρ; the collapse verb stays with Ace.
	var shell := _resolve_player_shell()
	if not shell or not shell.has_method("show_hint"):
		return {"success": false, "error": "no_player_shell", "message": "PlayerShell unavailable"}
	var gauge := _axis_gauge(_get_grid_position())
	if gauge.is_empty():
		return {"success": false, "error": "no_axis", "message": "No plot with a live axis selected"}
	var seal_txt := "" if bool(gauge.open) else " · [color=#8899aa]sealed — contracts need wet country[/color]"
	var lines: PackedStringArray = []
	lines.append("[color=#cfe6ff]🤝 %s — order book[/color] · kT %.1f%s" % [
		str(gauge.biome_name), float(gauge.kT), seal_txt])
	lines.append("  import 📥 %s: 4📜 + %d× %s · export 📤 stakes 4🧺 + %d× %s, pays as it drains" % [
		str(gauge.north), int(gauge.units_north), str(gauge.north),
		int(gauge.units_south), str(gauge.south)])
	var faction := ""
	var biome = gauge.get("biome", null)
	if biome and biome.has_method("first_native_faction"):
		faction = str(biome.first_native_faction())
	if faction != "":
		lines.append("  %s standing ×%.2f on contract prices" % [
			faction, PriceModel.standing_factor(faction, farm)])
	shell.show_hint("\n".join(lines))
	return {"success": true, "gauge": gauge}


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


func _resolve_player_shell() -> Node:
	var nodes := get_tree().get_nodes_in_group("player_shell") if is_inside_tree() else []
	return nodes[0] if not nodes.is_empty() else null


## Player-facing toast (anti-gating law: refusals are spoken; confirmations
## for otherwise-invisible state changes too). Logs when no shell exists (rig).
func _toast_player(message: String) -> void:
	var shell := _resolve_player_shell()
	if shell and shell.has_method("show_hint"):
		shell.show_hint(message, 2)
	_verbose.info("input", "•", message)


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

	# Boot ordering: connect_to_quantum_input reaches here via
	# build_chip_context with farm bound but _instrument not yet — two
	# SCRIPT ERRORs on every boot. The active biome is the honest answer
	# until the instrument exists.
	var biome_name: String = ""
	if _instrument and _instrument.current_biome != "":
		biome_name = _instrument.current_biome
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


func _get_active_biome_plot_count() -> int:
	# Number of grid plots the active biome owns (≥ register count — the extra,
	# register-less plots are empty slots where new icons can be planted/injected).
	if not farm or not farm.grid or not _active_biome_mgr:
		return 0
	var biome_name = _active_biome_mgr.get_active_biome()
	if biome_name == "" or not farm.grid.has_method("get_plot_positions_for_biome"):
		return 0
	return farm.grid.get_plot_positions_for_biome(biome_name).size()


func _get_selected_positions() -> Array[Vector2i]:
	# Single-plot action target. On the plot ring, use the live cursor. Off the ring
	# — e.g. right after jumping to the frame layer to pick a hat, which runs
	# leave_plot_ring() and clears current_plot_idx — fall back to the last-focused
	# register so the natural "highlight a plot → switch to Druid → Hadamard it" flow
	# still lands on the qubit you were looking at instead of silently no-opping.
	# Register-first: there is always a focused qubit. This mirrors _get_grid_position()'s
	# off-ring fallback, so plot-targeted gates behave like measure (which never no-ops off-ring).
	var positions: Array[Vector2i] = []
	if _instrument.current_plot_idx >= 0:
		positions.append(_get_grid_position())
	elif _instrument.last_selected_position != GridSentinel.INVALID_POSITION:
		positions.append(_instrument.last_selected_position)
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
	# Point the Focus (instrument fields) at the specified grid pos. Used by the
	# shift-batch loop to walk checked plots; the instrument is the single source.
	if not farm:
		return
	var biome_name = farm.get_biome_for_row(grid_pos.y) if farm.has_method("get_biome_for_row") else ""
	_instrument.current_plot_idx = grid_pos.x
	_instrument.current_biome = biome_name


func _restore_selection(previous_selection: Dictionary) -> void:
	# Restore the Focus from a {plot_idx, biome} snapshot and refresh the highlight.
	_instrument.current_plot_idx = int(previous_selection.get("plot_idx", -1))
	_instrument.current_biome = str(previous_selection.get("biome", ""))

	if plot_grid_display and farm and _instrument.current_plot_idx >= 0:
		var grid_pos = _get_grid_position()
		if grid_pos.x >= 0:
			plot_grid_display.set_selected_plot(grid_pos)
			_instrument.last_selected_position = grid_pos




## ============================================================================
## PUBLIC API
## ============================================================================

func get_current_selection() -> Dictionary:
	# Derive the current selection from the instrument (the single Focus source).
	return {
		"plot_idx": int(_instrument.current_plot_idx) if _instrument else -1,
		"biome": str(_instrument.current_biome) if _instrument else "",
		"subspace_idx": -1,
	}


func can_execute_action(action_key: String) -> bool:
	# Check if action can succeed with current selection (for UI highlighting).
	if (int(_instrument.current_plot_idx) if _instrument else -1) < 0:
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
	if _instrument:
		_instrument.current_plot_idx = plot_idx
		_instrument.current_biome = biome_name
	# Glass-overlay navigation is a cursor move, not exploration — reveal only
	# fires from the real Explore action (action_explore).
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
	# The clock is a player control, not a dev dial — say it (fleet #5: 50+
	# fast-forwards per berry because nobody knew = existed). Stride is the
	# REAL multiplier (quantum_time_scale is vestigial); live cap ×32.
	_toast_player("⏪ %s clock ×%d — = speeds it back up" % [target_biome_name, maxi(1, mini(stride_result.new_stride, 32))])


## One step of the biome clock, signed. The pointer twin of `−` / `=` — the
## clock chips call THIS rather than reaching for either private method, so the
## two input paths share one entry and cannot drift.
func step_time_controls(delta: int) -> void:
	if delta >= 0:
		_increase_time_controls()
	else:
		_decrease_time_controls()


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
	_toast_player("⏩ %s clock ×%d — loops ripen faster (- slows it)" % [target_biome_name, maxi(1, mini(stride_result.new_stride, 32))])

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
