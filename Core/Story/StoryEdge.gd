extends RefCounted

## A directed edge between two story nodes.
##
## Two flavors of edge in the golden cut:
##  - "predicate" — derived from story_flags.json: a → b if b's predicates include
##    `{type: "story_flag_set", id: a}`. The substrate version of a story-flag
##    dependency: when a fires, b becomes reachable.
##  - "action" — synthetic, attached to a node by the substrate. Represents a
##    player verb-and-icon expression slot. The player's QERF×123×GHJKL; presses
##    operate on these.
##
## Per plan §QERF semantics:
##   attention   ∈ ℝ      — Q lowers, R raises (lossless)
##   phase       ∈ ℝ (rad) — F rotates toward chosen Icon (lossless)
##   E forces transition (advance_to_node) — collapses superposition.

const KIND_PREDICATE := "predicate"
const KIND_ACTION := "action"

var id: String = ""
var kind: String = KIND_PREDICATE
var from_node: String = ""
var to_node: String = ""
var attention: float = 0.0
var phase: float = 0.0  # radians
var icon_axis: int = -1  # -1 = uncommitted, 0/1/2 = which Icon slot was last harmonized

## For action edges: the action signature this edge is gated by.
## { hat: String, verb: String, resource: String, biome: String }
var action_signature: Dictionary = {}

## Standing/predicate gate the player must satisfy for this edge to be "ready".
## Mirrors story_flags.json predicate shape.
var condition: Dictionary = {}

## True if E on this edge has fired (collapsed) in the current run.
var fired: bool = false


static func make_predicate_edge(from_id: String, to_id: String):
	var e = load("res://Core/Story/StoryEdge.gd").new()
	e.kind = KIND_PREDICATE
	e.from_node = from_id
	e.to_node = to_id
	e.id = "%s→%s" % [from_id, to_id]
	return e


static func make_action_edge(from_id: String, to_id: String, signature: Dictionary, condition: Dictionary = {}):
	var e = load("res://Core/Story/StoryEdge.gd").new()
	e.kind = KIND_ACTION
	e.from_node = from_id
	e.to_node = to_id
	e.action_signature = signature.duplicate(true)
	e.condition = condition.duplicate(true)
	var sig_tag = "%s/%s" % [str(signature.get("hat", "")), str(signature.get("verb", ""))]
	e.id = "%s━[%s]→%s" % [from_id, sig_tag, to_id]
	return e


## Ready when fired-yet-no AND condition (if any) passes.
## Condition evaluation is delegated to the engine because it needs farm state.
func is_locked_by_condition() -> bool:
	return not condition.is_empty()
