extends RefCounted

## A single chatty NPC. Belongs to one faction, currently focused on one
## graph node, drifts to neighbors weighted by faction charge.
##
## Per plan §SocialiteCluster:
##   - Random walk weighted by node's faction_charge for this socialite's faction
##   - Chatter probability scales with chattiness × node activity

var id: String = ""
var faction: String = ""
var current_topic_node: String = ""
var chattiness: float = 0.5      # [0, 1]
var standing_toward_player: float = 0.0  # [-1, 1]; tunes tone
var emoji: String = ""           # cached faction emoji for display


func _init(p_id: String = "", p_faction: String = "", p_emoji: String = "") -> void:
	id = p_id
	faction = p_faction
	emoji = p_emoji


## Pick a node to walk to, weighted by:
##   - 0.5 × current node (stay)
##   - 0.5 × neighbors via outgoing edges (favoring nodes with charge for our faction)
## Returns chosen node id (may be same as current).
func choose_next_topic(graph) -> String:
	if current_topic_node == "":
		return current_topic_node
	var candidates: Array = [current_topic_node]   # weighted "stay" baseline
	var weights: Array = [0.5]
	for edge in graph.get_outgoing_edges(current_topic_node):
		var to_node = graph.get_node(edge.to_node)
		if to_node == null:
			continue
		var charge_dict = to_node.faction_charge()
		var charge: float = float(charge_dict.get(faction, 0.0))
		# Always-walkable baseline + faction affinity bonus
		var w := 0.1 + charge * 2.0
		candidates.append(edge.to_node)
		weights.append(w)
	# Weighted sample
	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return current_topic_node
	var r := randf() * total
	var acc := 0.0
	for i in range(candidates.size()):
		acc += weights[i]
		if r <= acc:
			return candidates[i]
	return candidates[candidates.size() - 1]


## Whether to chatter this tick. Three soft, continuous terms — no thresholds,
## no special cases:
##   chattiness    — personality floor (fixed per socialite)
##   node_activity — narrative attention (density on the topic node)
##   liveliness    — QUANTUM state of the biome about to be voiced: the spread of
##                   its measurement distribution. A settled biome (→0) speaks
##                   rarely; a biome in rich superposition (→1) babbles.
## Liveliness is the dominant term, so cadence genuinely breathes with the physics.
func should_chatter(node_activity: float = 0.5, liveliness: float = 0.5) -> bool:
	return randf() < (chattiness * 0.3 + node_activity * 0.2 + liveliness * 0.4)


## Fallback emoji bag — used if the canonical story composer returns nothing
## (e.g. faction not yet in registry). Just the speaker's display emoji.
func fallback_emojis() -> Array:
	if emoji != "":
		return [emoji, emoji]
	return ["…"]
