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
		# A blank chip reads as broken (fleet ×2) — name the prerequisite instead.
		# `reason` is the refusal toast _perform_action speaks when the key is
		# pressed anyway (anti-gating law: three relay legs farmed act 1
		# perfectly and never found incorporation — the silent R was the wall).
		return {"action": "", "label": "Track first (F)", "disabled": true,
				"reason": "nothing to incorporate here — track this loop (F) until it ripens, or pick an empty plot (G H J K L ;) and press R to plant a new icon (costs 🌱)"}
	if register.is_ripe(qid):
		return {"action": "incorporate_icon", "label": "Incorporate", "disabled": false}
	# Live ripeness percent: "Not ready" with no meter made every ripening
	# question unanswerable (fleets #4–#7) — a moving number says "keep
	# waiting"; a crawling one says "slow loop, speed the clock (=)".
	var threshold: float = maxf(0.0001, float(register.get_ripe_threshold(qid)))
	var pct: int = clampi(int(round(absf(float(register.get_phase(qid))) / threshold * 100.0)), 0, 99)
	return {"action": "", "label": "Ripening %d%%" % pct, "disabled": true,
			"reason": "the loop is still ripening (%d%%) — R incorporates when it reaches 100%%; time ripens it (= speeds the clock)" % pct}
