class_name ChipResolverRegistry
extends Object

## Resolves contextual action_info patches for chip rendering and dispatch.
## ToolConfig action entries opt in by adding `"chip_resolver": "<name>"`.
## Both UIContextController (chip text) and the action dispatcher consult this,
## so a resolver that overrides `action` will route through to the right handler.

const IconChipResolvers = preload("res://Core/UI/IconChipResolvers.gd")
const ChipContext = preload("res://Core/UI/ChipContext.gd")


static func resolve(action_info: Dictionary, ctx) -> Dictionary:
	if action_info.is_empty() or not action_info.has("chip_resolver"):
		return action_info
	var name: String = str(action_info["chip_resolver"])
	var patch: Dictionary = {}
	match name:
		"icon.r_state":
			patch = IconChipResolvers.resolve_r(ctx)
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
