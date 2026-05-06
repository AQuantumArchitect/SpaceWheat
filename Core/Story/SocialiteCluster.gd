extends RefCounted

## Pool of socialites. Per tick: each may sample a biome it watches and emit
## the measurement outcome as chatter.
##
## NO SPECIAL CASES: chatter is a substrate measurement of a biome's QC,
## not an invented Markov walk. Each socialite picks a biome where their
## faction signature overlaps the biome's atoms, samples the QC's basis-state
## distribution, and emits the resulting emoji string.
##
## Biome length sets phrase length naturally:
##   TheDemos    (2 qubits) → 🌾👥 / 👥🌾 / 🌾🌾 / 👥👥
##   StarterForest (~6q)    → 6-emoji phrases
##   Village    (~5q)       → 5-emoji phrases

const Socialite := preload("res://Core/Story/Socialite.gd")
const FactionRegistry := preload("res://Core/Factions/FactionRegistry.gd")
const BiomeMeasurementSampler := preload("res://Core/Story/BiomeMeasurementSampler.gd")
const FactionBiomeMap := preload("res://Core/Biomes/FactionBiomeMap.gd")

# Demos is the player faction; included so player-faction state surfaces
# alongside NPC voices via the same measurement mechanism.
const SEED_SOCIALITES: Array = [
	{"faction": "The Demos",         "emoji": "👥", "chattiness": 0.6},
	{"faction": "Hearth Keepers",    "emoji": "🌿", "chattiness": 0.7},
	{"faction": "Millwright's Union", "emoji": "⚙",  "chattiness": 0.5},
	{"faction": "Granary Guilds",    "emoji": "🌾", "chattiness": 0.4},
	{"faction": "Carrion Throne",    "emoji": "💀", "chattiness": 0.3},
	{"faction": "Void Serfs",        "emoji": "📜", "chattiness": 0.6},
]

var socialites: Array = []
var _recent_chatter: Array = []   # bounded ring buffer
const _CHATTER_RING_SIZE := 32

# Lazily resolved fallback registry (used when shared_registry isn't injected).
var _faction_registry = null

# StoryEngine sets this every tick.
var shared_registry = null
var farm = null  # set by StoryEngine each tick so socialites can pick live biomes


# Phase 2 hook: when ConversationHamiltonian path is revived, StoryEngine will
# sync _recent_player_emojis here before each tick so NPC word choice responds
# to player icon actions. Not wired yet — chatter is pure biome measurement.


func size() -> int:
	return socialites.size()


func populate(graph, n: int) -> void:
	socialites.clear()
	if graph == null or graph.nodes.is_empty():
		# Substrate-graph not required for measurement-driven chatter, but the
		# original signature is preserved.
		pass
	var node_ids: Array = []
	if graph != null:
		node_ids = graph.nodes.keys()
	var seed_count := mini(n, SEED_SOCIALITES.size())
	for i in range(seed_count):
		var seed = SEED_SOCIALITES[i]
		var s := Socialite.new(
			"socialite_%d" % i,
			str(seed.get("faction", "")),
			str(seed.get("emoji", ""))
		)
		s.chattiness = float(seed.get("chattiness", 0.5))
		# Topic-node still tracked for trajectory record + UI focus context.
		if not node_ids.is_empty():
			s.current_topic_node = node_ids[i % node_ids.size()]
		socialites.append(s)


## One substrate tick. Each socialite picks a biome it can measure (signature
## overlaps biome atoms), samples the QC, emits the result.
##
## Event shapes:
##   {kind: "chatter", speaker, faction, topic_node, biome, emojis, line}
##   {kind: "step",    speaker, faction, from_node, to_node}   (legacy graph walk)
func tick(graph) -> Array:
	var events: Array = []
	for s in socialites:
		# Optional graph walk (kept for trajectory texture)
		if graph != null:
			var prev_node: String = s.current_topic_node
			var next_node: String = s.choose_next_topic(graph)
			if next_node != prev_node:
				s.current_topic_node = next_node
				events.append({
					"kind": "step",
					"speaker": s.id,
					"faction": s.faction,
					"from_node": prev_node,
					"to_node": next_node,
				})
		# Decide whether to chatter
		var topic_activity: float = 0.5
		if graph != null:
			topic_activity = float(graph.density.get(s.current_topic_node, 0.5))
		if not s.should_chatter(topic_activity):
			continue
		# Pick a biome to measure: physics-derived faction↔biome map.
		var registry = _ensure_registry()
		var biomes_dict: Dictionary = farm.grid.get_all_biomes() if (farm != null and farm.grid != null and farm.grid.has_method("get_all_biomes")) else {}
		var native_biomes: Array = FactionBiomeMap.biomes_for_faction(s.faction, biomes_dict, registry) if (registry != null and not biomes_dict.is_empty()) else []
		var picked_biome = _pick_biome_from_names(native_biomes, biomes_dict)
		var emojis: Array = []
		var marginals: Array = []
		var biome_label := ""
		if picked_biome != null:
			var sample: Dictionary = BiomeMeasurementSampler.sample_basis_with_marginals(picked_biome)
			emojis = sample.get("emojis", [])
			marginals = sample.get("marginals", [])
			biome_label = _biome_name_of(picked_biome)
		if emojis.is_empty():
			emojis = s.fallback_emojis()
		# Connections: other live biomes the speaker is also native to (excluding topic).
		var connections: Array = []
		for bname in native_biomes:
			if str(bname) != biome_label:
				connections.append(str(bname))
		var ev := {
			"kind": "chatter",
			"speaker": s.emoji,
			"faction": s.faction,
			"topic_node": s.current_topic_node,
			"biome": biome_label,
			"emojis": emojis,
			"marginals": marginals,
			"connections": connections,
			"line": " ".join(emojis),
		}
		events.append(ev)
		_push_chatter(ev)
	return events


## Pick a biome from a list of native biome names (uniform random).
## Returns the biome instance from biomes_dict, or null if none/empty.
func _pick_biome_from_names(names: Array, biomes_dict: Dictionary):
	if names.is_empty() or biomes_dict.is_empty():
		return null
	var idx := randi() % names.size()
	return biomes_dict.get(str(names[idx]), null)


func _biome_name_of(biome) -> String:
	if biome == null:
		return ""
	if biome.has_method("get_biome_type"):
		return str(biome.get_biome_type())
	if "name" in biome:
		return str(biome.name)
	return ""


func _push_chatter(ev: Dictionary) -> void:
	_recent_chatter.append(ev)
	if _recent_chatter.size() > _CHATTER_RING_SIZE:
		_recent_chatter.pop_front()


func recent_chatter(n: int = 5) -> Array:
	if _recent_chatter.is_empty():
		return []
	var start := maxi(0, _recent_chatter.size() - n)
	return _recent_chatter.slice(start, _recent_chatter.size())


func _ensure_registry():
	if shared_registry != null:
		return shared_registry
	if _faction_registry == null:
		_faction_registry = FactionRegistry.new()
	return _faction_registry
