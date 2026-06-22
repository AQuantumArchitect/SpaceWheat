class_name Quest
extends RefCounted

## Quest — the ONE canonical quest schema.
##
## A quest is a plain Dictionary (serializable, signal-friendly) but its shape is defined HERE,
## in one place, instead of being assembled ad-hoc at each construction site. Every source
## (market, story arc, tutorial) produces quests through `Quest.make()` so they are structurally
## identical and flow through the same QuestPipeline + UI + completion path.
##
## Design notes:
## - Defaults are "absent-equivalent" ("" / 0 / -1 / {} / [] / false / null) so consumers using
##   `dict.get(field, x)` behave exactly as before normalization (Phase 0 = no behavior change).
## - `type` is a QuestTypes.Type int. `source` is one of the SOURCE_* constants.
## - Completion is SOFT continuous everywhere (state_predicates → smooth_and ≥ threshold, or a
##   type-specific soft progress in [0,1]). See [[feedback_soft_continuous_geometry]].

const SOURCE_MARKET := "market"      # procedural, physics-derived contract offers
const SOURCE_STORY := "story"        # authored arc beats (story_flags.json arc_quest)
const SOURCE_TUTORIAL := "tutorial"  # authored Act-0 onboarding chain

const STATUS_OFFERED := "offered"    # in the market/offer pool, not yet taken
const STATUS_STORY := "story"        # a story/tutorial offer awaiting acknowledgement/accept
const STATUS_ACTIVE := "active"      # accepted, in progress
const STATUS_READY := "ready"        # non-delivery quest whose predicates are satisfied; claimable
const STATUS_COMPLETED := "completed"
const STATUS_FAILED := "failed"


## The canonical default quest. Every field a quest can carry lives here exactly once.
static func defaults() -> Dictionary:
	return {
		# ── Identity ──
		"id": -1,
		"source": SOURCE_MARKET,            # SOURCE_*
		"status": STATUS_OFFERED,           # STATUS_*
		"category": "",                     # "" | "ARC"
		"source_flag": "",                  # story flag id that spawned this (story/tutorial)

		# ── Type & completion ──
		"type": QuestTypes.Type.DELIVERY,   # QuestTypes.Type
		"resource": "",                     # delivered/measured emoji
		"quantity": 1,
		"time_limit": -1.0,                 # seconds; -1 = unlimited
		"expires": false,
		"state_predicates": [],             # soft-gate predicates for non-delivery completion

		# ── Presentation ──
		"faction": "",
		"biome": "",
		"biome_name": "",
		"body": "",                         # short line
		"full_text": "",                    # voiced narrative line

		# ── Icon / vocabulary reward ──
		"reward_north": "",
		"reward_south": "",
		"reward_icon_north": "",
		"reward_icon_south": "",
		"reward_icon_weight": 0.0,
		"reward_icon_probability": 0.0,

		# ── Resource reward ──
		"reward_resources": {},
		"reward_multiplier": 1.0,

		# ── Progress / tracking (non-delivery) ──
		"progress": 0.0,
		"elapsed": 0.0,
		"initial_value": 0.0,
		"predicate_score": 0.0,

		# ── Timing ──
		"offered_at": 0,
		"accepted_at": 0,
		"completed_at": 0,
		"failed_at": 0,
		"ready_at": 0,
		"completion_reason": "",
		"failure_reason": "",

		# ── Market ──
		"market_projection": {},
		"market_offer_id": -1,
		"tension": 0.0,
		"pair_a": "",
		"pair_b": "",
		"cost_emoji": "",
		"cost_amount": 0.0,

		# ── Faction context ──
		"faction_signature": [],
		"biome_new": false,
		"contains_new_vocab": false,

		# ── Pipeline parameters (FactionStateMatcher-derived) ──
		"_alignment": 0.0,
		"_intensity": 0.0,
		"_complexity": 0.5,
		"_urgency": 0.0,
		"_variety": 0.5,

		# ── Chain / branching (rebuild) ──
		"chain_prereqs": [],                # quest/flag ids that must be done first
		"chain_unlocks": [],               # quest specs unlocked on completion (linear chain)
		"chain_branch": [],                # [{when: predicate, unlock: spec}] faction-siding branches

		# ── Tutorial (rebuild) ──
		"tutorial_teaches": "",             # mechanic id this quest introduces
		"tutorial_hint": "",                # actionable hint shown to the player
		"tutorial_step": -1,                # ordinal in the Act-0 chain (-1 = not tutorial)

		# ── Reward objects (filled at completion) ──
		"reward": null,
		"reward_payload": {},
	}


## Build a canonical quest from a source + field overrides. The single construction entry.
static func make(source: String, fields: Dictionary = {}) -> Dictionary:
	var q := defaults()
	q["source"] = source
	for k in fields:
		q[str(k)] = fields[k]
	return q


## Fill any missing canonical fields on an already-built quest dict (adapter use). Existing
## values are preserved; only absent keys get their default. Returns the same dict (mutated).
static func normalize(quest: Dictionary, source: String = "") -> Dictionary:
	var d := defaults()
	for k in d:
		if not quest.has(k):
			quest[k] = d[k]
	if source != "":
		quest["source"] = source
	return quest


## Convenience predicates.
static func is_delivery(quest: Dictionary) -> bool:
	return int(quest.get("type", QuestTypes.Type.DELIVERY)) == QuestTypes.Type.DELIVERY

static func is_tutorial(quest: Dictionary) -> bool:
	return str(quest.get("source", "")) == SOURCE_TUTORIAL
