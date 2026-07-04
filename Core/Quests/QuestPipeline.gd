class_name QuestPipeline
extends RefCounted

## QuestPipeline — the ONE construction path for quests, from every source.
##
## Conceptual flow (stages fill in across the rebuild phases):
##   generate(source) → parameterize(faction,biome) → type-select(complexity) →
##   build SOFT predicates → voice(faction) → reward-plan → present → track → grant/chain
##
## Phase 0 is ADAPTER-FIRST: the market and story sources feed their existing raw output through
## here, which normalizes everything to the canonical `Quest` schema. No behavior change yet —
## later phases insert the voice / type-select / predicate stages between generation and present.
##
## Every source builds quests HERE (not ad-hoc at the call site) so they are structurally
## identical and flow through the same completion path + UI.


## MARKET source: project a live MarketContract into a canonical delivery quest, deriving the
## icon-pair vocab reward from the biome's neighborhood loadout so completing the delivery teaches
## that axis. (Relocated from QuestManager._offer_from_market_lattice — same logic, now canonical.)
static func from_market_contract(contract, biome) -> Dictionary:
	if contract == null:
		return {}
	var raw: Dictionary = {}
	if contract is Dictionary:
		raw = (contract as Dictionary).duplicate(true)
	elif contract.has_method("to_quest_offer_dict"):
		raw = contract.to_quest_offer_dict()
	if raw.is_empty():
		return {}
	raw["type"] = QuestTypes.Type.DELIVERY
	raw["time_limit"] = 120.0
	var pair := _vocab_pair_for_resource(str(raw.get("resource", "")), biome)
	raw["reward_north"] = pair[0]
	raw["reward_south"] = pair[1]
	raw["reward_vocab_north"] = pair[0]
	raw["reward_vocab_south"] = pair[1]
	raw["reward_multiplier"] = 1.0
	var quest := Quest.normalize(raw, Quest.SOURCE_MARKET)
	QuestVoice.apply(quest)  # faction-voiced body/full_text (replaces the bland projection line)
	return quest


## STORY source: build a canonical story/arc quest from a story_flags.json arc_quest def.
## (Relocated from QuestManager.offer_story_quest — same fields, now canonical.)
static func from_story_def(quest_def: Dictionary, source_flag: String, quest_id: int) -> Dictionary:
	var q := Quest.make(Quest.SOURCE_STORY, {
		"id": quest_id,
		"category": "ARC",
		"source_flag": source_flag,
		"status": Quest.STATUS_STORY,
		"expires": false,
		"offered_at": Time.get_ticks_msec(),
	})
	# Merge the authored arc_quest fields verbatim (type may be a legacy string here; preserved).
	for k in quest_def:
		q[str(k)] = quest_def[k]
	return q


## Build a canonical, voiced QUANTUM quest (non-delivery, untimed) of `type_id` with its
## type-specific fields (observable/target/comparison, delta/direction, target_coherence, …).
## These teach the player to READ and STEER the quantum state — the heart of the game. The
## existing _update_*_quest trackers complete them via soft_gate once accepted.
static func quantum_quest(type_id: int, faction: String, biome_name: String, fields: Dictionary, quest_id: int) -> Dictionary:
	var q := Quest.make(Quest.SOURCE_MARKET, {
		"id": quest_id,
		"status": Quest.STATUS_OFFERED,
		"type": type_id,
		"faction": faction,
		"biome": biome_name,
		"biome_name": biome_name,
		"time_limit": -1.0,   # untimed — steer at your own pace
		"quantity": 1,
	})
	for k in fields:
		q[str(k)] = fields[k]
	QuestVoice.apply(q)
	return q


## Physics-derived suggestion: in the CLOSED system, coherence is the canonical steerable
## observable (purity≡1, entropy≡0 are degenerate). Offer a SHAPE_ACHIEVE coherence quest only
## when there's headroom to raise it (don't ask for what's already true). Deterministic — no RNG.
## Returns {} if coherence is already high. Caller supplies the live coherence reading.
static func suggest_quantum_quest(biome_name: String, faction: String, coherence: float, quest_id: int) -> Dictionary:
	if coherence >= 0.65:
		return {}
	var target := clampf(coherence + 0.15, 0.2, 0.85)
	return quantum_quest(QuestTypes.Type.SHAPE_ACHIEVE, faction, biome_name, {
		"observable": "coherence",
		"target": target,
		"comparison": ">",
		"tutorial_hint": "Raise coherence past %.2f — superpose the biome's qubits (Hadamard, then let H evolve)." % target,
	}, quest_id)


## Rung-1 sibling, the AMPLITUDE ask — the flavor material/direct factions prefer
## (QUEST_SYSTEM_PLAN stage 3 "type-select", chosen by the caller from
## FactionStateMatcher.calculate_operator_weights). Push a specific atom's
## population: SHAPE_ACHIEVE on the per-atom "population:<emoji>" observable
## (get_biome_observables). The caller picks an atom the faction speaks and
## supplies its current marginal; {} when there's no headroom to ask for.
static func suggest_amplitude_quest(biome_name: String, faction: String, atom: String, marginal: float, quest_id: int) -> Dictionary:
	if atom == "" or marginal < 0.0 or marginal >= 0.55:
		return {}
	var target := clampf(marginal + 0.15, 0.2, 0.7)
	return quantum_quest(QuestTypes.Type.SHAPE_ACHIEVE, faction, biome_name, {
		"observable": "population:%s" % atom,
		"target": target,
		"comparison": ">",
		"tutorial_hint": "Grow %s past %.2f — rotate its axis toward that pole and let H carry it there." % [atom, target],
	}, quest_id)


## Rung-1 sibling, the RATIO ask — the flavor subtle/relational factions prefer
## (weights.ratio from calculate_operator_weights). Hold one atom's population
## above another's: SHAPE_ACHIEVE on the derived "balance:A/B" observable
## (= p_A/(p_A+p_B); resolved by the tracker from the per-atom populations).
## The caller picks the most CONTESTED pair the faction speaks (balance nearest
## 0.5) and orients A = the current leader — the ask is to commit the tie.
## {} when the pair is already decided or inputs are missing.
static func suggest_ratio_quest(biome_name: String, faction: String, atom_a: String, atom_b: String, balance: float, quest_id: int) -> Dictionary:
	if atom_a == "" or atom_b == "" or atom_a == atom_b or balance < 0.0 or balance >= 0.62:
		return {}
	var target := clampf(balance + 0.15, 0.55, 0.85)
	return quantum_quest(QuestTypes.Type.SHAPE_ACHIEVE, faction, biome_name, {
		"observable": "balance:%s/%s" % [atom_a, atom_b],
		"target": target,
		"comparison": ">",
		"tutorial_hint": "The pair is contested. Keep %s above %s — push their balance past %.2f (measure %s down, or drive %s up)." % [atom_a, atom_b, target, atom_b, atom_a],
	}, quest_id)


## Physics-derived suggestion, rung two of the quantum curriculum: entanglement. Offered
## when coherence is already mastered (see the call site's ladder) and the biome has
## correlation headroom. Uses the standard SHAPE_ACHIEVE tracker on the
## max_mutual_information observable (bits; Bell pair = 2.0). Deterministic — no RNG.
## max_mi < 0 means the observable is unavailable (no native MI cache) → no offer.
static func suggest_entanglement_quest(biome_name: String, faction: String, max_mi: float, num_qubits: int, quest_id: int) -> Dictionary:
	if num_qubits < 2 or max_mi < 0.0 or max_mi >= 0.65:
		return {}
	var target := clampf(max_mi + 0.4, 0.5, 1.5)
	return quantum_quest(QuestTypes.Type.SHAPE_ACHIEVE, faction, biome_name, {
		"observable": "max_mutual_information",
		"target": target,
		"comparison": ">",
		"tutorial_hint": "Weave two qubits — a Bell or CNOT gate in the Operator frame — and push mutual information past %.2f. Watch the thread between the bubbles." % target,
	}, quest_id)


## TUTORIAL source: build a canonical Act-0 onboarding quest from an authored spec. Like
## from_story_def but tagged tutorial (category TUTORIAL). Authored body/hint are preserved.
static func from_tutorial_def(quest_def: Dictionary, quest_id: int) -> Dictionary:
	var q := Quest.make(Quest.SOURCE_TUTORIAL, {
		"id": quest_id,
		"category": "TUTORIAL",
		"status": Quest.STATUS_STORY,
		"expires": false,
		"offered_at": Time.get_ticks_msec(),
	})
	for k in quest_def:
		q[str(k)] = quest_def[k]
	return q


## Find the icon pair (north, south) whose pole contains `res_emoji` in the biome's loadout.
## Returns ["", ""] if none found.
static func _vocab_pair_for_resource(res_emoji: String, biome) -> Array:
	if res_emoji == "" or biome == null:
		return ["", ""]
	var bname: String = ""
	if biome.has_method("get_biome_type"):
		bname = str(biome.get_biome_type())
	if bname == "" and "name" in biome:
		bname = str(biome.name)
	if bname == "":
		return ["", ""]
	var breg = BiomeRegistry.get_shared()
	var bdef = breg.get_by_name(bname) if bname != "" else null
	if bdef == null or not bdef.has_method("get_neighborhood_icons"):
		return ["", ""]
	for icon in bdef.get_neighborhood_icons():
		var p0: String = str(icon.get("pole_0", ""))
		var p1: String = str(icon.get("pole_1", ""))
		if p0 == res_emoji or p1 == res_emoji:
			return [p0, p1]
	return ["", ""]
