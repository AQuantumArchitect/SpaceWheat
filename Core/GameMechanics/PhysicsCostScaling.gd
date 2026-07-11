class_name PhysicsCostScaling
extends RefCounted

## PhysicsCostScaling — quantum observables → cost multipliers.
##
## Cost and reward share the same physics inputs (affinity, p, r). Reward
## uses `credits = p² · Tr(ρ_q²)^α · κ`; cost uses the dual surface so that
## *extracting* a sharper, less-familiar state is more expensive.
##
## Contract: all multipliers are ≥ 1.0. Physics never subsidizes an action
## below its base cost — it only taxes concentration and unfamiliarity.

const MEASURE_UNFAMILIAR_MAX: float = 2.0  # +200% at affinity=0 → 3× cost
const POP_CONCENTRATION_MAX: float = 2.0   # +200% at p=r=1      → 3× cost


## Measure: unfamiliar factions (low affinity) are harder to collapse.
##   factor = 1 + MEASURE_UNFAMILIAR_MAX · (1 - affinity)
static func scale_measure_cost(base_cost: Dictionary, affinity: float) -> Dictionary:
	var a = clampf(affinity, 0.0, 1.0)
	var factor = 1.0 + MEASURE_UNFAMILIAR_MAX * (1.0 - a)
	return _scale(base_cost, factor)


## Pop: harvesting a concentrated, coherent qubit costs more people.
##   factor = 1 + POP_CONCENTRATION_MAX · p · r
static func scale_pop_cost(base_cost: Dictionary, p_emoji: float, bloch_r: float) -> Dictionary:
	var pp = clampf(p_emoji, 0.0, 1.0)
	var rr = clampf(bloch_r, 0.0, 1.0)
	var factor = 1.0 + POP_CONCENTRATION_MAX * pp * rr
	return _scale(base_cost, factor)


static func _scale(cost: Dictionary, factor: float) -> Dictionary:
	if cost.is_empty():
		return {}
	var out: Dictionary = {}
	if factor <= 1.0:
		for emoji in cost:
			out[emoji] = int(cost[emoji])
		return out
	for emoji in cost:
		var base = int(cost[emoji])
		var scaled = int(round(float(base) * factor))
		out[emoji] = maxi(scaled, base)
	return out
