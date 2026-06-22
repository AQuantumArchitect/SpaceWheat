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


## MARKET source: project a live MarketContract into a canonical delivery quest.
##
## DELIVER/market contracts reward RESOURCES tied to the OFFERING faction's Hamiltonian
## couplings — so the market can hand back resources the player's own biome can't POP
## (its whole purpose: access to scarce vocabulary like 🔨). Icon-teaching is NOT the
## market's job — that lives in the physics-driven STORY quests (familiarity → icon).
## The resource plan is pre-rolled here so the offer advertises exactly what completion
## grants (generate_reward consumes a pre-rolled reward_resources verbatim).
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
	raw["reward_multiplier"] = 1.0
	# No icon reward — market quests pay in resources, derived from the faction's
	# coupling-cloud (can include resources the player has no mass in yet).
	raw.erase("reward_north")
	raw.erase("reward_south")
	raw.erase("reward_icon_north")
	raw.erase("reward_icon_south")
	var faction_dict := FactionDatabase.get_faction_by_name(str(raw.get("faction", "")))
	var planned := QuestRewards.plan_resource_rewards(raw, faction_dict)
	if not planned.is_empty():
		raw["reward_resources"] = planned
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

