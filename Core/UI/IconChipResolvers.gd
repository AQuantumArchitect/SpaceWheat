class_name IconChipResolvers
extends Object

## Chip-text resolvers for the Icon archetype frame. Pure projections from
## ChipContext (sim-side state) to action_info patches. No state stored here.



static func resolve_r(ctx: ChipContext) -> Dictionary:
	# Four-state contextual chip for Icon-hat R:
	#   nothing focused / empty plot → static "Add Icon" (default action_info; submenu opens picker)
	#   full + untracked             → blank (R has no work; F is for tracking)
	#   full + tracked + unripe      → "Not ready" (visible feedback for engaged player)
	#   full + tracked + ripe        → "Incorporate" (harvest the learned icon)
	if ctx == null or not ctx.has_focused_qubit():
		return {}
	var register = ctx.get_berry_register()
	if register == null:
		return {}
	var qid: int = ctx.qubit_index
	if not register.is_tracked(qid):
		return {"action": "", "label": "", "disabled": true}
	if register.is_ripe(qid):
		return {"action": "incorporate_icon", "label": "Incorporate", "disabled": false}
	return {"action": "", "label": "Not ready", "disabled": true}
