class_name UIContextController
extends Node

## UIContextController
##
## Single authority for bottom-bar context projection.
## It watches the live gameplay/tool state plus the overlay stack and decides
## what the tool row and action row should display.

const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")

var action_bar_manager = null
var overlay_stack = null
var overlay_manager = null
var quantum_input = null
var current_farm_ui: Control = null
var current_frame: String = ToolConfig.get_current_frame()
var current_submenu_name: String = ""
var current_submenu_actions: Dictionary = {}
var _observed_overlays: Array = []
const ACTION_KEYS = ["Q", "E", "R", "F"]



func setup(action_bar_mgr, stack_mgr, overlay_mgr = null) -> void:
	action_bar_manager = action_bar_mgr
	overlay_stack = stack_mgr
	if overlay_stack and overlay_stack.has_signal("stack_changed"):
		InstrumentLocator._safe_connect(overlay_stack.stack_changed, refresh)

	_connect_toolbar_inputs()
	if overlay_mgr:
		bind_overlay_manager(overlay_mgr)

	refresh()


func reset() -> void:
	# Clear ONLY the per-GAME bindings so a fresh boot can rebind cleanly via
	# bind_quantum_input(). The shell-persistent infrastructure — action_bar_manager,
	# overlay_stack, overlay_manager (and the stack_changed / overlay observations) — is
	# created once in setup() at shell construction and PRESERVED across restarts (see
	# PlayerShell.clear_farm_ui: "action bars, layout manager are all preserved").
	#
	# Previously this nulled action_bar_manager/overlay_stack/overlay_manager, but only
	# setup() restores them and the restart path calls bind_quantum_input (not setup) — so
	# after a menu/restart boot action_bar_manager stayed null, refresh() early-returned, and
	# the action bar never repainted off frame_changed: the bar froze on Ace while the hat
	# (and the model) changed underneath. That was the "stuck on Ace, can't change hats" bug.
	if quantum_input:
		for sig_name in ["frame_changed", "frame_mode_changed", "submenu_changed", "action_performed"]:
			var cb = Callable(self, "_on_" + sig_name)
			if quantum_input.has_signal(sig_name):
				InstrumentLocator._safe_disconnect(Signal(quantum_input, sig_name), cb)
		if action_bar_manager:
			var tool_row = action_bar_manager.get_tool_row()
			if tool_row and tool_row.has_signal("frame_selected"):
				InstrumentLocator._safe_disconnect(tool_row.frame_selected,
						Callable(quantum_input, "_select_frame_hat"))
	quantum_input = null
	current_farm_ui = null
	current_frame = ToolConfig.get_current_frame()
	current_submenu_name = ""
	current_submenu_actions.clear()


func bind_overlay_manager(overlay_mgr) -> void:
	overlay_manager = overlay_mgr
	if not overlay_manager or not overlay_manager.has_method("get_registered_overlays"):
		return

	for overlay_name in overlay_manager.get_registered_overlays():
		_observe_overlay(overlay_manager.get_overlay(overlay_name))


func bind_quantum_input(instrument_input) -> void:
	if quantum_input == instrument_input or not instrument_input:
		return

	quantum_input = instrument_input
	current_frame = _resolve_current_frame()

	for pair in [
		["frame_changed", _on_frame_changed],
		["frame_mode_changed", _on_frame_mode_changed],
		["submenu_changed", _on_submenu_changed],
		["action_performed", _on_action_performed],
	]:
		if quantum_input.has_signal(pair[0]):
			InstrumentLocator._safe_connect(Signal(quantum_input, pair[0]), pair[1])

	# Wire ToolSelectionRow → QII (the single write authority for frame state).
	# Keyboard hat keys (4-0) already go through QII._unhandled_key_input;
	# button clicks now take the same path so both use identical logic.
	if action_bar_manager:
		var tool_row = action_bar_manager.get_tool_row()
		if tool_row and tool_row.has_signal("frame_selected"):
			InstrumentLocator._safe_connect(tool_row.frame_selected,
					Callable(quantum_input, "_select_frame_hat"))

	refresh()


func bind_farm_ui(farm_ui: Control) -> void:
	current_farm_ui = farm_ui
	if not current_farm_ui or not action_bar_manager:
		return

	var farm = current_farm_ui.farm if "farm" in current_farm_ui else null
	var plot_grid = current_farm_ui.plot_grid_display if "plot_grid_display" in current_farm_ui else null

	if plot_grid and plot_grid.has_signal("selection_count_changed"):
		InstrumentLocator._safe_connect(plot_grid.selection_count_changed, _on_selection_count_changed)
	if farm and farm.economy and farm.economy.has_signal("resource_changed"):
		InstrumentLocator._safe_connect(farm.economy.resource_changed, _on_resource_changed)

	refresh()


func refresh() -> void:
	if not action_bar_manager:
		return

	action_bar_manager.select_frame(current_frame)
	action_bar_manager.render_action_projection(_build_action_projection())
	_apply_pointer_bleed_guard()


func _apply_pointer_bleed_guard() -> void:
	# Pointer twin of PlayerShell's keyboard bleed-through guard. When a real
	# (non-transparent) menu is open, hat/biome KEYS are swallowed — so their
	# CHIPS must not win clicks either. GUI picking ignores z_index: without
	# this, the tool/biome chip strips (later in the tree) silently stole
	# clicks aimed at modal content drawn above them (playtest 2: quest-board
	# tabs unclickable by mouse). The menu row (ZXCVBNM ring) and bottom QERF
	# chips stay live — ring navigation is never swallowed, and QERF chips
	# route overlay-first, acting as the modal's own verb buttons.
	var menu_open := false
	if overlay_stack and not overlay_stack.is_empty():
		var top = overlay_stack.get_top()
		var transparent: bool = top != null and ("is_transparent_overlay" in top) and top.is_transparent_overlay
		menu_open = not transparent
	for row in [action_bar_manager.get_tool_row(), action_bar_manager.get_biome_row()]:
		if row and row.has_method("set_pointer_enabled"):
			row.set_pointer_enabled(not menu_open)


func _connect_toolbar_inputs() -> void:
	if not action_bar_manager:
		return

	# frame_selected is wired to QII._select_frame_hat in bind_quantum_input
	# (QII is the single write authority for frame state — needs to exist first)
	#
	# action_pressed is NOT connected here: PlayerShell._route_action_key is
	# the single dispatch authority for chip clicks (overlay-first, then
	# QII.invoke_action — the same fallthrough as the keyboard). A second
	# connection here used to fire every clicked verb TWICE (double costs,
	# double measures) and bypassed overlay routing via the private
	# _perform_action.


func _observe_overlay(overlay) -> void:
	if not overlay or overlay in _observed_overlays:
		return

	_observed_overlays.append(overlay)
	for sig_name in ["action_performed", "slot_selection_changed", "action_labels_changed"]:
		if overlay.has_signal(sig_name):
			InstrumentLocator._safe_connect(Signal(overlay, sig_name), _refresh_from_overlay_signal)


func _refresh_action_availability() -> void:
	refresh()


func _resolve_current_frame() -> String:
	if quantum_input and quantum_input.has_method("get_current_frame"):
		return quantum_input.get_current_frame()
	return ToolConfig.get_current_frame()


func _on_frame_changed(frame_name: String) -> void:
	current_frame = frame_name
	current_submenu_name = ""
	current_submenu_actions = {}
	if current_farm_ui and current_farm_ui.has_method("_on_frame_selected"):
		current_farm_ui._on_frame_selected(frame_name)
	refresh()


func _on_frame_mode_changed(frame_name: String, _mode_idx: int, _mode_label: String) -> void:
	current_frame = frame_name
	refresh()


func _on_submenu_changed(submenu_name: String, submenu_actions: Dictionary) -> void:
	current_submenu_name = submenu_name
	current_submenu_actions = submenu_actions
	refresh()


func _on_action_performed(_action: String, _result: Dictionary) -> void:
	refresh()


func _on_selection_count_changed(_count: int) -> void:
	_refresh_action_availability()


func _on_resource_changed(_emoji, _amount) -> void:
	_refresh_action_availability()


func _refresh_from_overlay_signal(_a = null, _b = null) -> void:
	refresh()


func _build_action_projection() -> Dictionary:
	var projection := {
		"context": "frame",
		"frame": current_frame,
		"submenu_name": "",
		"actions": {}
	}

	var top_overlay = overlay_stack.get_top() if overlay_stack else null
	if top_overlay and overlay_stack.size() > 1:
		# `is_transparent_overlay` is a plain bool var present only on some overlays
		# (e.g. BiomeInspectorOverlay). Object.get() takes ONE arg, so probe the
		# property's existence with `in` before reading it — never .get(name, default).
		var transparent: bool = ("is_transparent_overlay" in top_overlay) and bool(top_overlay.is_transparent_overlay)
		if not transparent:
			projection.context = "overlay"
			projection.actions = _build_overlay_actions(top_overlay)
			return projection

	if current_submenu_name != "":
		projection.context = "submenu"
		projection.submenu_name = current_submenu_name
		projection.actions = _build_submenu_actions()
		return projection

	projection.actions = _build_frame_actions(current_frame)
	return projection


func _build_frame_actions(frame_name: String) -> Dictionary:
	var actions: Dictionary = {}
	# Chip text runs through the SAME resolver as dispatch (QII._perform_action)
	# so a contextual chip (e.g. Ace F = Explore on an unexplored plot) never
	# shows a verb its key wouldn't fire.
	var chip_ctx = quantum_input.build_chip_context() if quantum_input and quantum_input.has_method("build_chip_context") else null
	for action_key in ACTION_KEYS:
		var action_info = ToolConfig.get_action(frame_name, action_key)
		if chip_ctx != null:
			action_info = ChipResolverRegistry.resolve(action_info, chip_ctx)
			# Price on the chip: every verb advertises what it would charge
			# (playtest 6: "all the actions need to display their costs").
			action_info = ChipResolverRegistry.annotate_cost(action_info, chip_ctx)
		actions[action_key] = _project_action_info(action_info)

	if frame_name == ToolConfig.FRAME_ACE and ToolConfig.get_frame_mode_name(frame_name) == "probe":
		_apply_probe_preview(actions)

	_apply_runtime_state(actions)
	return actions


func _build_submenu_actions() -> Dictionary:
	var actions: Dictionary = {}
	var submenu_disabled = current_submenu_actions.get("_disabled", false)
	var submenu_availability = current_submenu_actions.get("_availability", {})

	for action_key in ACTION_KEYS:
		var action_info = current_submenu_actions.get(action_key, {})
		var projected = _project_action_info(action_info)
		var action_name = str(projected.get("action", ""))
		var available = submenu_availability.get(action_key, true)
		projected.disabled = bool(projected.get("disabled", false)) or submenu_disabled or action_name == "" or not available
		actions[action_key] = projected

	_apply_runtime_state(actions)
	return actions


func _build_overlay_actions(overlay: Control) -> Dictionary:
	var actions: Dictionary = {}
	for action_key in ACTION_KEYS:
		var info = overlay.get_action_info(action_key)
		if not (info is Dictionary):
			info = {}
		actions[action_key] = _project_action_info(info)
		actions[action_key].available = not bool(actions[action_key].get("disabled", false))
	return actions


func _project_action_info(action_info: Dictionary) -> Dictionary:
	return {
		"action": str(action_info.get("action", "")),
		"label": str(action_info.get("label", "-")),
		"emoji": str(action_info.get("emoji", "")),
		"icon": str(action_info.get("icon", "")),
		"disabled": bool(action_info.get("disabled", false)),
		"dlc_locked": bool(action_info.get("dlc_locked", false)),
		"available": false,
		# Carry through a producer-supplied cost (e.g. the icon-injection submenu prices
		# each option as it builds it). Single cost authority: whoever holds the payload
		# computes the cost; the controller preserves it rather than re-deriving.
		"cost": action_info.get("cost", {}) if (action_info.get("cost") is Dictionary) else {},
		"shift_label": str(action_info.get("shift_label", "")),
		"shift_action": str(action_info.get("shift_action", "")),
		"destructive": bool(action_info.get("destructive", false)),
	}


## Verbs that are pure Lindblad drive — meaningless in the closed (unitary) system.
## In closed/shipping mode they render disabled with a 🔒 open-quantum tag (DLC teaser)
## instead of looking live and returning an inert no-op. Mirrors the runtime guard in
## QuantumInstrument._closed_system_blocked.
const CLOSED_BLOCKED_ACTIONS := [
	"spark_north", "spark_south", "drain", "pump", "lindblad_pump", "lindblad_drain",
]


func _apply_runtime_state(actions: Dictionary) -> void:
	var runtime_availability = _resolve_runtime_availability()
	var closed_mode := not BalanceConfig.dissipative_enabled()
	for action_key in ACTION_KEYS:
		if not actions.has(action_key):
			continue
		var action_info: Dictionary = actions[action_key]
		# Closed-mode honesty: open-quantum-only verbs render as a locked DLC teaser.
		if closed_mode and str(action_info.get("action", "")) in CLOSED_BLOCKED_ACTIONS:
			action_info.disabled = true
			action_info.available = false
			action_info.cost = {}
			action_info.dlc_locked = true
			if not str(action_info.get("label", "")).begins_with("🔒"):
				action_info.label = "🔒 " + str(action_info.get("label", ""))
			actions[action_key] = action_info
			continue
		if bool(action_info.get("disabled", false)):
			action_info.available = false
			action_info.cost = {}
			continue

		if action_key == "F":
			# F sits unused unless the active frame defines an explicit
			# F action. Mode cycling lives on Tab, never on F.
			var f_action_name := str(action_info.get("action", ""))
			action_info.available = f_action_name != ""
			action_info.disabled = f_action_name == ""
		else:
			action_info.available = runtime_availability.get(action_key, false)
		# Only derive a cost here when the producer didn't already supply one — don't
		# re-derive from data the projection has reshaped (the source of the inject_icon
		# String/Dictionary confusion). Single cost authority: producer prices, we keep.
		if (action_info.get("cost", {}) as Dictionary).is_empty():
			action_info.cost = _get_cost_for_action(action_info)
		actions[action_key] = action_info


func _resolve_runtime_availability() -> Dictionary:
	var availability := {"Q": false, "E": false, "R": false, "F": true}
	if quantum_input and quantum_input.has_method("can_execute_action"):
		availability.Q = quantum_input.can_execute_action("Q")
		availability.E = quantum_input.can_execute_action("E")
		availability.R = quantum_input.can_execute_action("R")
		return availability

	if quantum_input and quantum_input.has_method("get_current_selection"):
		var selection = quantum_input.get_current_selection()
		var has_selection = int(selection.get("plot_idx", -1)) >= 0
		availability.Q = has_selection
		availability.E = has_selection
		availability.R = has_selection
		return availability

	return availability


func _apply_probe_preview(actions: Dictionary) -> void:
	var farm = _get_farm()
	var plot_grid = _get_plot_grid()
	if not farm or not farm.terminal_pool or not plot_grid or not plot_grid.has_method("get_selected_plots"):
		return

	var selected = plot_grid.get_selected_plots()
	if selected.is_empty() or not farm.grid:
		return

	var biome = farm.grid.get_biome_for_plot(selected[0])
	if not biome:
		return

	# R = Strike: preview the live odds you're about to collapse (top QC probability).
	var explore_preview = ProbeActions.get_explore_preview(farm.terminal_pool, biome)
	if explore_preview.can_explore and not explore_preview.top_probabilities.is_empty() and actions.has("R"):
		var top = explore_preview.top_probabilities[0]
		actions["R"].label = "Strike (%s %.0f%%)" % [top.get("emoji", "?"), top.get("probability", 0.0) * 100.0]

	# Q = Extract: preview the collapsed outcome that's ready to cash out.
	var biome_name = biome.get_biome_type() if biome.has_method("get_biome_type") else ""
	var measured_terminals = []
	for terminal in farm.terminal_pool.get_measured_terminals():
		if terminal.bound_biome_name == biome_name:
			measured_terminals.append(terminal)
	if not measured_terminals.is_empty() and actions.has("Q"):
		var measured_terminal = measured_terminals[0]
		actions["Q"].label = "Extract (%s)" % str(measured_terminal.measured_outcome if measured_terminal.measured_outcome else "?")


func _get_cost_for_action(action_info: Dictionary) -> Dictionary:
	var action_name = str(action_info.get("action", ""))
	if action_name == "":
		return {}

	var shift_action = str(action_info.get("shift_action", ""))
	if shift_action != "":
		return _get_cost_for_action_name(shift_action, action_info)
	return _get_cost_for_action_name(action_name, action_info)


func _get_cost_for_action_name(action_name: String, action_info: Dictionary) -> Dictionary:
	match action_name:
		"inject_icon":
			# The per-icon south-pole cost (4×south) only resolves once an icon is selected in
			# the injection submenu (which prices each option, preserved through projection).
			# But the FLAT base cost (sprouts) is known WITHOUT a selection — surface it at the
			# frame level so the player can SEE that inserting vocab costs resources instead of
			# a blank chip. Pass no context → the economy returns the base injection cost
			# (get_icon_injection_cost("") = {🌱:N}); the full per-icon cost still shows in the
			# submenu. Empty south avoids the old "icon"-field String/Dictionary confusion.
			return _get_runtime_action_cost("inject_icon")
		"drain", "pump":
			var pair = _resolve_selected_axis_pair()
			if pair.is_empty():
				return {}
			var normalized = "lindblad_drain" if action_name == "drain" else "lindblad_pump"
			var ctx = {
				"north_emoji": str(pair.get("north", "")),
				"south_emoji": str(pair.get("south", ""))
			}
			# Live surprisal preview: the chip shows what the charge will BE,
			# not the flat fallback (drive_units = max(1, round(−kT·log p))).
			var units = _live_drive_units(1 if action_name == "drain" else 0)
			if units > 0:
				ctx["drive_units"] = units
			return _get_runtime_action_cost(normalized, ctx)
		"spark_north", "spark_south", "plant":
			var spark_pair = _resolve_selected_axis_pair()
			if spark_pair.is_empty():
				return {}
			var spark_ctx = {
				"north_emoji": str(spark_pair.get("north", "")),
				"south_emoji": str(spark_pair.get("south", ""))
			}
			var spark_units = _live_drive_units(1 if action_name == "spark_south" else 0)
			if spark_units > 0:
				spark_ctx["drive_units"] = spark_units
			return _get_runtime_action_cost(action_name, spark_ctx)
		_:
			return _get_runtime_action_cost(action_name)


func _live_drive_units(pole: int) -> int:
	# Surprisal units for driving the selected plot's pole (0 = north, 1 = south):
	# max(1, round(−kT·log p_pole)) at the biome's live temperature. Mirrors the
	# charge-time computation in QuantumInstrument/LindbladHandler so the chip
	# preview and the actual spend never disagree.
	var farm = _get_farm()
	if not farm or not farm.grid:
		return 0
	var plot_grid = _get_plot_grid()
	var selected: Array = []
	if plot_grid and plot_grid.has_method("get_selected_plots"):
		selected = plot_grid.get_selected_plots()
	if selected.is_empty():
		return 0
	var pos: Vector2i = selected[0]
	var biome = farm.grid.get_biome_for_plot(pos)
	if not biome or not biome.quantum_computer:
		return 0
	var plot = farm.grid.get_plot(pos)
	if not plot or not plot.is_active():
		return 0
	var emoji = str(plot.north_emoji if pole == 0 else plot.south_emoji)
	if emoji == "" or not biome.quantum_computer.has(emoji):
		return 0
	var kT = EnergyPricing.biome_temperature(biome, farm)
	var p_target = clampf(float(biome.quantum_computer.get_population(emoji)), 0.0, 1.0)
	return EnergyPricing.drive_units(p_target, kT)


func _get_runtime_action_cost(action_name: String, context: Dictionary = {}) -> Dictionary:
	var instrument = quantum_input._instrument if quantum_input and "_instrument" in quantum_input else null
	if instrument and instrument.has_method("get_action_cost"):
		return instrument.get_action_cost(action_name, context)
	var farm = _get_farm()
	return ActionCostRuntime.get_action_cost(farm, action_name, context)


func _resolve_selected_axis_pair() -> Dictionary:
	var farm = _get_farm()
	var plot_grid = _get_plot_grid()
	if not farm:
		return {}

	var selected: Array = []
	if plot_grid and plot_grid.has_method("get_selected_plots"):
		selected = plot_grid.get_selected_plots()

	var pos := GridSentinel.INVALID_POSITION
	if selected.is_empty():
		if quantum_input and quantum_input.has_method("get_current_selection") and farm.has_method("get_biome_row"):
			var selection = quantum_input.get_current_selection()
			var plot_idx = int(selection.get("plot_idx", -1))
			var biome_name = str(selection.get("biome", ""))
			if plot_idx >= 0:
				pos = Vector2i(plot_idx, farm.get_biome_row(biome_name))
	else:
		pos = selected[0]

	if pos.x < 0 or not farm.grid:
		return {}

	var plot = farm.grid.get_plot(pos)
	if plot and plot.is_active():
		var north = str(plot.north_emoji if plot.north_emoji else "")
		if north == "":
			return {}
		var south = str(plot.south_emoji if plot.south_emoji else "")
		if south == "":
			var biome = farm.grid.get_biome_for_plot(pos)
			if biome and biome.viz_cache and biome.viz_cache.has_metadata():
				var q = biome.viz_cache.get_qubit(north)
				if q >= 0:
					var axis = biome.viz_cache.get_axis(q)
					if axis is Dictionary:
						south = str(axis.get("south", ""))
		return {"north": north, "south": south}

	return {}


func _get_farm():
	return current_farm_ui.farm if current_farm_ui and "farm" in current_farm_ui else null


func _get_plot_grid():
	return current_farm_ui.plot_grid_display if current_farm_ui and "plot_grid_display" in current_farm_ui else null
