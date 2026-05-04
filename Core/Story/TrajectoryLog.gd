extends RefCounted

## Append-only path log: every step the substrate has taken through graph state.
##
## Each entry: {
##   from_node: String,
##   to_node: String,
##   edge_id: String,
##   action_signature: Dictionary,   # what triggered it; {} if system-fired
##   speaker: String,                # "system" for QuestManager-fired, faction for socialite, "player" for QERF
##   icon_idx: int,                  # -1 if not a player action
##   verb: String,                   # "Q"/"E"/"R"/"F"/"" for system
##   phrame: int,
## }
##
## Persisted via parallel save slot on GameState (story_trajectory: Array).
## In golden cut we keep this in-memory; persistence comes later.

const KIND_SYSTEM := "system"
const KIND_PLAYER := "player"
const KIND_SOCIALITE := "socialite"

var entries: Array = []


func record(entry: Dictionary) -> void:
	# Defensive copy so callers can't mutate the log post-hoc.
	entries.append(entry.duplicate(true))


func record_system_advance(from_node: String, to_node: String, edge_id: String) -> void:
	record({
		"from_node": from_node,
		"to_node": to_node,
		"edge_id": edge_id,
		"action_signature": {},
		"speaker": KIND_SYSTEM,
		"icon_idx": -1,
		"verb": "",
		"phrame": Engine.get_physics_frames(),
	})


func record_player_action(from_node: String, to_node: String, edge_id: String, icon_idx: int, verb: String, signature: Dictionary = {}) -> void:
	record({
		"from_node": from_node,
		"to_node": to_node,
		"edge_id": edge_id,
		"action_signature": signature.duplicate(true),
		"speaker": KIND_PLAYER,
		"icon_idx": icon_idx,
		"verb": verb,
		"phrame": Engine.get_physics_frames(),
	})


func record_socialite_step(socialite_id: String, from_node: String, to_node: String, faction: String) -> void:
	record({
		"from_node": from_node,
		"to_node": to_node,
		"edge_id": "",
		"action_signature": {"socialite": socialite_id, "faction": faction},
		"speaker": KIND_SOCIALITE,
		"icon_idx": -1,
		"verb": "",
		"phrame": Engine.get_physics_frames(),
	})


func size() -> int:
	return entries.size()


func last(n: int = 5) -> Array:
	if entries.is_empty():
		return []
	var start := maxi(0, entries.size() - n)
	return entries.slice(start, entries.size())


func clear() -> void:
	entries.clear()


func serialize() -> Array:
	return entries.duplicate(true)


func deserialize(data) -> void:
	if data is Array:
		entries = (data as Array).duplicate(true)
	else:
		entries = []
