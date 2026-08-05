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

const POLL_S := 0.5
const PULSE_SCALE := Vector2(1.22, 1.22)
const PULSE_OUT_S := 0.35
const PULSE_IN_S := 0.45

var _action_bar_manager = null
var _accum: float = 0.0
var _current_key: String = ""
var _pulsing_node: Control = null
var _tween: Tween = null


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
	# rebuild frees and recreates chip nodes) — nothing to do.
	if pulse_id == _current_key and _pulsing_node != null and is_instance_valid(_pulsing_node):
		return
	_current_key = pulse_id
	_stop_pulse()
	if pulse_id == "":
		return
	var target := _resolve_target(pulse_id)
	if target != null:
		_start_pulse(target)


func _active_biome_name() -> String:
	var abm := get_node_or_null("/root/ActiveBiomeManager")
	return str(abm.active_biome) if (abm != null and "active_biome" in abm) else ""


func _resolve_target(pulse_id: String) -> Control:
	if _action_bar_manager == null:
		return null
	var row = null
	var lookup := pulse_id
	if pulse_id.begins_with("biome:"):
		row = _action_bar_manager.get("biome_selection_row")
		lookup = pulse_id.trim_prefix("biome:")
	elif pulse_id in ["Z", "X", "C", "V", "B", "N", "M"]:
		row = _action_bar_manager.get("menu_selection_row")
	else:
		row = _action_bar_manager.get("tool_selection_row")
	if row == null or not is_instance_valid(row) or not row.has_method("get_button_pulse_target"):
		return null
	return row.get_button_pulse_target(lookup)


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
