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
