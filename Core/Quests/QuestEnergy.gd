class_name QuestEnergy
extends RefCounted

## A quest is a bounty on an improbable state. Its reward is the surprisal energy
## of the goal: E = −kT·log p_target (EnergyPricing). Rarer goals pay more; this is
## the same scarcity law that prices harvest, markets, and reap.
##
## Pure adapter: maps a quest's completion predicates → target probabilities →
## surprisal energy. Reads no live game state (kT is passed in).

## 1-bit floor (kT·ln2): a quest with no probability-like target still pays the
## cost of resolving one bit, never zero.
static func _floor(kT: float) -> float:
	return kT * log(2.0)


## The target probability a predicate demands, in [0,1], or 0.0 if the predicate
## has no probability-like target (handled by the caller's floor).
static func predicate_target_p(predicate: Dictionary) -> float:
	var t := str(predicate.get("type", ""))
	var v := float(predicate.get("value", 0.0))
	match t:
		"purity_at_least", "coherence_at_least", "attractor_emoji_gte", \
		"predict_population_gte", "predict_purity_gte", "population_at_least", \
		"marginal_at_least", "phase_at_least":
			return clampf(v, 0.0, 1.0)
		"entropy_at_most":
			# Lower target entropy = a more ordered (rarer) state; map S→p via e^(−S).
			return clampf(exp(-v), 0.0, 1.0)
		_:
			return 0.0


## Bounty size = Σ surprisal of the quest's predicate targets (a basket of goals
## adds, because log of a product is a sum). Falls back to the quest's `target`
## value, then to the 1-bit floor.
static func target_energy(quest: Dictionary, kT: float) -> float:
	var preds: Array = quest.get("state_predicates", [])
	var total := 0.0
	var counted := 0
	for pred in preds:
		if not (pred is Dictionary):
			continue
		var p := predicate_target_p(pred)
		if p > 0.0:
			total += EnergyPricing.surprisal_energy(p, kT)
			counted += 1
	if counted > 0:
		return total
	# No predicate target — try the quest's scalar target, else the 1-bit floor.
	var tv := float(quest.get("target", quest.get("target_value", 0.0)))
	if tv > 0.0 and tv <= 1.0:
		return EnergyPricing.surprisal_energy(tv, kT)
	return _floor(kT)
