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
	var existing = action_info.get("cost")
	if existing is Dictionary and not existing.is_empty():
		return action_info
	var action_name := str(action_info.get("action", ""))
	if action_name == "":
		return action_info
	var cost: Dictionary = ActionCostRuntime.get_action_cost(ctx.farm, action_name, {})
	if action_name == "measure" and not cost.is_empty():
		var axis: Dictionary = ctx.focused_axis()
		if not axis.is_empty():
			var pair_affinity = FactionAffinity.get_pair_affinity(
				str(axis.get("north", "")), str(axis.get("south", "")), ctx.farm)
			cost = PhysicsCostScaling.scale_measure_cost(cost, pair_affinity)
	if cost.is_empty():
		return action_info
	# Whole-unit resources: the JSONL board stores values as floats (1.0);
	# the badge must read "1", matching what the wallet loses.
	var display_cost: Dictionary = {}
	for emoji in cost:
		display_cost[emoji] = int(round(float(cost[emoji])))
	var out: Dictionary = action_info.duplicate(true)
	out["cost"] = display_cost
	return out
