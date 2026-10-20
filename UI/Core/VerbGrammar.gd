class_name VerbGrammar
extends Object

## One grammar for the QERF dock, MULTI, and Reap.
##
## QERF is one bar. MULTI (or Shift held) swaps that bar to the batch verbs
## so the chips name what a click fires. Reap is not a QERF verb — it lives
## on the season button (Ctrl+Shift+Space). Toasts, chips, unlock keys, and
## tests read this file.

const BalanceService = preload("res://Core/GameMechanics/BalanceService.gd")

const REAP_KEYCODE := KEY_SPACE
const REAP_CHORD := "Ctrl+Shift+Space"
const REAP_LABEL := "Reap"
const REAP_PULSE := "REAP"
const REAP_UNLOCK_KEY := "reap"

const MASS_EXPLORE_TOAST := "SHIFT [F] to multi explore"
const MASS_EXPLORE_WALK := "▸ SHIFT [F] to multi explore"
const MASS_STRIKE_WALK := "▸ SHIFT [R] to multi strike"
const MASS_MARK_WALK := "▸ MULTI or Shift+G H marks plots"
const MASS_GATHER_LABEL := "Mass Gather"
const MASS_EXPLORE_LABEL := "Mass Explore"
const MASS_STRIKE_LABEL := "Mass Strike"


static func mass_explore_toast() -> String:
	return MASS_EXPLORE_TOAST


static func mass_explore_walk() -> String:
	return MASS_EXPLORE_WALK


static func mass_strike_walk() -> String:
	return MASS_STRIKE_WALK


static func mass_mark_walk() -> String:
	return MASS_MARK_WALK


static func reap_chord() -> String:
	return REAP_CHORD


static func reap_walk() -> String:
	return "▸ %s %s" % [REAP_CHORD, REAP_LABEL]


static func is_reap_chord(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var k := event as InputEventKey
	return k.pressed and not k.echo and k.keycode == REAP_KEYCODE \
			and k.ctrl_pressed and k.shift_pressed


static func is_multi_live(qii) -> bool:
	if qii != null and "multi_select_mode" in qii and bool(qii.multi_select_mode):
		return true
	return Input.is_key_pressed(KEY_SHIFT)


static func project_chip(action_info: Dictionary, multi_live: bool) -> Dictionary:
	if action_info.is_empty():
		return action_info
	var out: Dictionary = action_info.duplicate(true)
	if not multi_live:
		out["shift_label"] = ""
		return out
	var shift_action := str(out.get("shift_action", "")).strip_edges()
	var shift_label := str(out.get("shift_label", "")).strip_edges()
	if shift_action != "":
		out["action"] = shift_action
	if shift_label != "":
		out["label"] = shift_label
	elif str(out.get("action", "")).strip_edges() != "":
		var base := str(out.get("label", "")).strip_edges()
		if base != "" and base != "-" and base != "—" and not base.begins_with("Mass "):
			out["label"] = "Mass %s" % base
	out["shift_label"] = ""
	return out


static func reap_cost(farm) -> Dictionary:
	var n := 0
	if farm != null and farm.has_method("get_reap_count"):
		n = int(farm.get_reap_count())
	elif farm != null and "reap_count" in farm:
		n = int(farm.reap_count)
	return BalanceService.get_reap_cost(farm, n)
