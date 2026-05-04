extends RefCounted

## (No class_name — use const preload pattern from sibling files.)

## A node in the story graph — one story flag, situation, or topic.
##
## Nodes carry a faction-charge vector: which factions care about this node
## and in which standing channels. The substrate uses this to weight socialite
## random-walks and to gate edges.
##
## Identity is the flag id (from story_flags.json) for seeded nodes;
## synthetic nodes (e.g. socialite-emergent topics) get a "topic_<hash>" id.

var id: String = ""
var display_name: String = ""
var act: int = 0
var arc_beat: String = ""

## Predicates required to fire this node (mirrors story_flags.json shape).
var predicates: Array = []

## { faction_name: { channel: float } }
var standing_grants: Dictionary = {}

## Optional arc quest dict (passes through to QuestManager).
var arc_quest = null

## Optional conditional beat array (Village identity flag uses this).
var conditional_beat: Array = []


static func from_flag(flag: Dictionary):
	var n = load("res://Core/Story/StoryNode.gd").new()
	n.id = str(flag.get("id", ""))
	n.display_name = str(flag.get("display_name", n.id))
	n.act = int(flag.get("act", 0))
	n.arc_beat = str(flag.get("arc_beat", ""))
	n.predicates = (flag.get("predicates", []) as Array).duplicate(true)
	n.standing_grants = (flag.get("standing_grants", {}) as Dictionary).duplicate(true)
	n.arc_quest = flag.get("arc_quest")
	n.conditional_beat = (flag.get("conditional_beat", []) as Array).duplicate(true)
	return n


## Faction-charge vector derived from standing_grants.
## Returns { faction_name: total_grant_magnitude } — used by socialite walk weighting.
func faction_charge() -> Dictionary:
	var charge: Dictionary = {}
	for faction_name in standing_grants:
		var channels: Dictionary = standing_grants[faction_name]
		var total := 0.0
		for ch in channels:
			total += abs(float(channels[ch]))
		charge[faction_name] = total
	return charge
