class_name ObjectiveSpotlight
extends Node

## ObjectiveSpotlight — visual companion to the objective-text funnel.
##
## UIProgression.objective_text() only ever SPEAKS (a corner banner, a
## locked-key toast) — nothing in the always-visible chrome ever draws the
## eye toward the literal next thing to press. This polls
## UIProgression.objective_target_key() on the same 0.5s cadence ActFilament
## already uses, and loops a small pulse on whichever menu-ring (X/C) or
## hat-row chip that key names — the SAME Tween shape ContractChip already
## proves (scale-bounce, TRANS_BACK/EASE_OUT), just looped instead of
## one-shot, and on the "icon"/"label" node each row already keeps
## uncontested by hover/selected/disabled state (see the two rows'
## get_button_pulse_target()).
##
## Purely cosmetic (anti-gating law) — reads, never writes. Renders nothing
## itself; it only reaches into ActionBarManager's existing rows.

const UIProgression = preload("res://UI/Core/UIProgression.gd")
const MenuRegistry = preload("res://UI/Core/MenuRegistry.gd")

const POLL_S := 0.5
const PULSE_SCALE := Vector2(1.22, 1.22)
const PULSE_OUT_S := 0.35
const PULSE_IN_S := 0.45

var _action_bar_manager = null
var _accum: float = 0.0
var _current_key: String = ""
var _pulsing_node: Control = null
var _tween: Tween = null
# Self-heal latch: which pulse target we already tried to heal a stale menu
# row for (see _refresh) — one heal attempt per target change, not per poll.
var _healed_for_key: String = ""


func setup(action_bar_manager) -> void:
	_action_bar_manager = action_bar_manager
	_refresh()


func _process(delta: float) -> void:
	_accum += delta
	if _accum >= POLL_S:
		_accum = 0.0
		_refresh()


func _refresh() -> void:
	var target_info := UIProgression.objective_target()
	var key := str(target_info.get("key", ""))
	var biome := str(target_info.get("biome", ""))
	# One pulse at a time, the LITERAL next key: if the target lives in a
	# biome that isn't focused, the next key is that biome's tab (TYUIOP) —
	# pulse it; once focused, pulse the verb's chip.
	var pulse_id := key
	if biome != "" and biome != _active_biome_name():
		pulse_id = "biome:%s" % biome
	# Unchanged AND the pulsed node survived (a progression-triggered row
	# rebuild frees and recreates chip nodes) — nothing to do. A biome pulse
	# has no Control node: the field owns that animation and survives its own
	# rebuilds, so unchanged is unconditionally nothing-to-do (re-arming every
	# poll would reset the breath clock mid-cycle — visible stutter).
	if pulse_id == _current_key:
		if pulse_id.begins_with("biome:"):
			return
		if _pulsing_node != null and is_instance_valid(_pulsing_node):
			return
	_current_key = pulse_id
	_stop_pulse()
	if pulse_id == "":
		return
	if pulse_id.begins_with("biome:"):
		# The rail orb IS the target now — the biome bar's tab chip died with
		# the bar (2026-08-24). The field breathes the named orb; placeholders
		# breathe too, so the cue never goes dark on an unrenderable biome.
		_set_field_spotlight(pulse_id.trim_prefix("biome:"))
		return
	var target := _resolve_target(pulse_id)
	if target == null and _healed_for_key != pulse_id:
		# A menu-ring key with no chip is one of two things: genuinely gated
		# (progressive disclosure — stay dark; the banner and redirect toast
		# already speak, and pulsing a hidden chip is impossible) or a STALE
		# ROW that missed its rebuild trigger. Only the second is ours to fix:
		# refresh the row once per target change and retry. This is a UI
		# rebuild, not game-state mutation — still reads-never-writes on the
		# game. The warning makes staleness fail loudly in dev instead of
		# silently pulsing nothing while every text surface says "press C".
		_healed_for_key = pulse_id
		var menu_id := _menu_id_for_key(pulse_id)
		if menu_id != "" and UIProgression.is_menu_visible(menu_id):
			var row = _action_bar_manager.get("menu_selection_row") if _action_bar_manager != null else null
			if row != null and is_instance_valid(row) and row.has_method("refresh_progression"):
				push_warning("ObjectiveSpotlight: menu row was stale for visible '%s' — self-healed" % menu_id)
				row.refresh_progression()
				target = _resolve_target(pulse_id)
	if target != null:
		_start_pulse(target)


## Menu id for a menu-ring key label ("C" → "quests"); "" for non-menu keys.
func _menu_id_for_key(key: String) -> String:
	if not (key in ["Z", "X", "C", "V", "B", "N", "M"]):
		return ""
	for entry in MenuRegistry.TOP_LEVEL_MENUS:
		if entry is Dictionary and str(entry.get("key_label", "")) == key:
			return str(entry.get("id", ""))
	return ""


func _active_biome_name() -> String:
	var abm := get_node_or_null("/root/ActiveBiomeManager")
	return str(abm.active_biome) if (abm != null and "active_biome" in abm) else ""


func _resolve_target(pulse_id: String) -> Control:
	# biome: ids never reach here — they route to the field in _refresh.
	if _action_bar_manager == null:
		return null
	var row = null
	if pulse_id in ["Z", "X", "C", "V", "B", "N", "M"]:
		row = _action_bar_manager.get("menu_selection_row")
	else:
		row = _action_bar_manager.get("tool_selection_row")
	if row == null or not is_instance_valid(row) or not row.has_method("get_button_pulse_target"):
		return null
	return row.get_button_pulse_target(pulse_id)


## The 3D field hosts the cross-biome cue (group lookup, same idiom as
## SelectionButtonRow._live_field3d: no shared parent until AppRoot, and the
## field may not exist yet the first time this fires — then there is nothing
## to animate anyway).
func _set_field_spotlight(biome_name: String) -> void:
	var tree := get_tree()
	var field = tree.get_first_node_in_group("quantum_field_3d") if tree != null else null
	if field != null and field.has_method("set_spotlight_biome"):
		field.set_spotlight_biome(biome_name)


func _start_pulse(target: Control) -> void:
	_pulsing_node = target
	target.pivot_offset = target.size / 2.0
	_tween = target.create_tween()
	_tween.set_loops()
	_tween.tween_property(target, "scale", PULSE_SCALE, PULSE_OUT_S) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(target, "scale", Vector2.ONE, PULSE_IN_S) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_pulse() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	if _pulsing_node != null and is_instance_valid(_pulsing_node):
		_pulsing_node.scale = Vector2.ONE
	_pulsing_node = null
	_set_field_spotlight("")
