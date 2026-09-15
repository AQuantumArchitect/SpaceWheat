class_name ChipResolverRegistry
extends Object

## Resolves contextual action_info patches for chip rendering and dispatch.
## ToolConfig action entries opt in by adding `"chip_resolver": "<name>"`.
## Both UIContextController (chip text) and the action dispatcher consult this,
## so a resolver that overrides `action` will route through to the right handler.



static func resolve(action_info: Dictionary, ctx) -> Dictionary:
	if action_info.is_empty() or not action_info.has("chip_resolver"):
		return action_info
	var entry_name: String = str(action_info["chip_resolver"])
	var patch: Dictionary = {}
	match entry_name:
		"icon.r_state":
			patch = IconChipResolvers.resolve_r(ctx)
		"ace.f_explore":
			patch = AceChipResolvers.resolve_f(ctx)
		_:
			return action_info
	if patch.is_empty():
		return action_info
	var out: Dictionary = action_info.duplicate(true)
	for key in patch.keys():
		out[key] = patch[key]
	# When the resolver overrides `action`, the submenu metadata is no longer
	# meaningful — the dispatcher should NOT open the original picker.
	if patch.has("action") and patch["action"] != action_info.get("action", ""):
		out.erase("submenu")
	return out


## Display-only cost annotation: attach the price a chip's action would charge,
## read from the SAME ActionCostRuntime authority the dispatchers preflight
## against (measure additionally physics-scaled by pair unfamiliarity, exactly
## as action_measure charges it). Producer-supplied costs (e.g. the injection
## submenu) win; free actions stay badge-less.
static func annotate_cost(action_info: Dictionary, ctx) -> Dictionary:
	if action_info.is_empty() or ctx == null or ctx.farm == null:
		return action_info
	var out: Dictionary = action_info

	# Shift-variant price rides in the shift hint text — "(Reap Season 1🍼)" —
	# so F and Shift+F stop looking identical (fleet: the 🍼 cost ambushed
	# every tester who found reap).
	var shift_action := str(action_info.get("shift_action", ""))
	var shift_label := str(action_info.get("shift_label", ""))
	if shift_action != "" and shift_label != "":
		var shift_cost: Dictionary = _shift_action_cost(ctx.farm, shift_action)
		if not shift_cost.is_empty():
			out = action_info.duplicate(true)
			out["shift_label"] = "⇧ %s %s" % [shift_label, _format_cost_inline(shift_cost)]

	var existing = action_info.get("cost")
	if existing is Dictionary and not existing.is_empty():
		return out
	var action_name := str(action_info.get("action", ""))
	if action_name == "":
		return out
	var cost: Dictionary = ActionCostRuntime.get_action_cost(ctx.farm, action_name, {})
	# (No measure branch: strike is flat 1👥 since 2026-08-25 — the badge and
	# the wallet read the same number with nothing in between to scale it.)
	if cost.is_empty():
		return out
	# Whole-unit resources: the JSONL board stores values as floats (1.0);
	# the badge must read "1", matching what the wallet loses.
	var display_cost: Dictionary = {}
	for emoji in cost:
		display_cost[emoji] = int(round(float(cost[emoji])))
	if out == action_info:
		out = action_info.duplicate(true)
	out["cost"] = display_cost
	return out


## What a shift verb would charge — the SAME authorities the dispatchers use:
## reap is sequence-priced by reap count (BalanceService); everything else
## reads the action_costs board.
static func _shift_action_cost(farm, shift_action: String) -> Dictionary:
	if shift_action == "reap":
		var reap_count := 0
		if farm != null and farm.has_method("get_reap_count"):
			reap_count = int(farm.get_reap_count())
		elif farm != null and "reap_count" in farm:
			reap_count = int(farm.reap_count)
		return BalanceService.get_reap_cost(farm, reap_count)
	return ActionCostRuntime.get_action_cost(farm, shift_action, {})


static func _format_cost_inline(cost: Dictionary) -> String:
	# Signed: a bare "1🍼" reads ambiguous (cost or reward?); "−1🍼" is honest —
	# this is what the wallet loses (d1-03, literalist care pass). Delegates to
	# the one formatter authority, pinning this convention (slop knot #13).
	return preload("res://Core/UI/CostFormat.gd").format_cost(
		cost, {"sorted": true, "pair": "neg_tight"})
