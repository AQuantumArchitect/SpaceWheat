class_name BroadGraph
extends RefCounted

## The BROAD graph: every neighborhood's quantum cluster, federated into one
## navigable whole-world structure.
##
## A DERIVED view — it composes a [NeighborhoodGraph] per biome (no new physics,
## no cross-biome quantum coupling; Model C — one isolated QuantumComputer per
## biome — is untouched). Federation edges are the per-neighborhood vocabulary
## ports lifted to the biome level: two biomes are linked when their realized
## clusters share atoms (emoji vocabulary), the same shared-emoji seam the N
## "Biome Network" surface renders. The faction-level overlap (e.g. The Demos'
## 🌾 → the farming factions) lives inside each NeighborhoodGraph's ports.
##
## Built once on demand from canonical data (BiomeRegistry + IconRegistry +
## FactionRegistry); rebuild with `build`. Pure structure — quantitative regime
## tuning is parametric (global knobs over authored values), applied elsewhere.
##
## Shapes:
##   neighborhoods : biome_name -> NeighborhoodGraph
##   edges         : [{a, b, shared:Array[String], weight:int}]  (undirected, a<b)

const NeighborhoodGraphRef = preload("res://Core/QuantumSubstrate/NeighborhoodGraph.gd")

var neighborhoods: Dictionary = {}     # biome_name -> NeighborhoodGraph
var edges: Array = []                  # federation edges (shared vocabulary)
var _biome_vocab: Dictionary = {}      # biome_name -> {emoji: true} (realized poles)
var _emoji_biomes: Dictionary = {}     # emoji -> [biome_name, ...]


## Compose the whole-world graph. Registries are resolved once and shared across
## every neighborhood derive (avoids 100s of redundant registry instantiations).
## `biome_filter` (array of biome names) restricts composition to those biomes —
## empty means the whole registry. Use it to federate just the live/active biomes
## (the realistic runtime case; far cheaper than deriving all ~160).
static func build(biome_registry = null, icon_registry = null, faction_registry = null, biome_filter: Array = []) -> BroadGraph:
	var g := BroadGraph.new()
	var breg = biome_registry if biome_registry != null else g._resolve_biome_registry()
	var ireg = icon_registry if icon_registry != null else g._resolve_icon_registry()
	var freg = faction_registry if faction_registry != null else g._resolve_faction_registry()
	if breg == null or not breg.has_method("get_all"):
		return g

	var only: Dictionary = {}
	for name in biome_filter:
		only[str(name)] = true

	for biome in breg.get_all():
		if biome == null:
			continue
		if not only.is_empty() and not only.has(str(biome.name) if "name" in biome else ""):
			continue
		var ng = NeighborhoodGraphRef.from_biome(biome, ireg, freg)
		if ng.node_count() == 0:
			continue  # a biome that realizes no qubit cluster adds nothing
		var bname := str(ng.biome_name)
		g.neighborhoods[bname] = ng
		var vocab: Dictionary = {}
		for n in ng.nodes:
			for emoji in [str(n["north"]), str(n["south"])]:
				if emoji == "":
					continue
				vocab[emoji] = true
				if not g._emoji_biomes.has(emoji):
					g._emoji_biomes[emoji] = []
				if not (bname in g._emoji_biomes[emoji]):
					g._emoji_biomes[emoji].append(bname)
		g._biome_vocab[bname] = vocab

	g._build_federation_edges()
	return g


## Federation edges: link any two biomes whose realized clusters share atoms.
## Weight = count of shared emojis (the strength of the vocabulary seam).
func _build_federation_edges() -> void:
	var pair_shared: Dictionary = {}  # "a|b" -> [emoji,...]
	for emoji in _emoji_biomes.keys():
		var bs: Array = _emoji_biomes[emoji]
		if bs.size() < 2:
			continue
		for i in range(bs.size()):
			for j in range(i + 1, bs.size()):
				var a := str(bs[i])
				var b := str(bs[j])
				var key := "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]
				if not pair_shared.has(key):
					pair_shared[key] = []
				pair_shared[key].append(str(emoji))
	for key in pair_shared.keys():
		var parts: PackedStringArray = str(key).split("|")
		var shared: Array = pair_shared[key]
		shared.sort()
		edges.append({"a": parts[0], "b": parts[1], "shared": shared, "weight": shared.size()})


# --- Navigation API ---

func biome_count() -> int:
	return neighborhoods.size()


func edge_count() -> int:
	return edges.size()


func total_qubits() -> int:
	var n := 0
	for bname in neighborhoods.keys():
		n += neighborhoods[bname].node_count()
	return n


func total_ports() -> int:
	var n := 0
	for bname in neighborhoods.keys():
		n += neighborhoods[bname].ports.size()
	return n


func get_neighborhood(biome_name: String):
	return neighborhoods.get(biome_name, null)


## Biomes federated to `biome_name` (sharing ≥1 realized emoji), with the shared
## vocabulary: [{biome, shared:Array[String], weight:int}].
func neighbors_of(biome_name: String) -> Array:
	var out: Array = []
	for e in edges:
		if str(e["a"]) == biome_name:
			out.append({"biome": str(e["b"]), "shared": e["shared"], "weight": int(e["weight"])})
		elif str(e["b"]) == biome_name:
			out.append({"biome": str(e["a"]), "shared": e["shared"], "weight": int(e["weight"])})
	return out


## Biomes that realize a given emoji (the vocabulary contestation at scale).
func biomes_with_emoji(emoji: String) -> Array:
	return _emoji_biomes.get(emoji, []).duplicate()


func to_dict() -> Dictionary:
	var nb: Dictionary = {}
	for bname in neighborhoods.keys():
		nb[bname] = neighborhoods[bname].to_dict()
	return {
		"biomes": neighborhoods.keys(),
		"edges": edges.duplicate(true),
		"totals": {"biomes": biome_count(), "edges": edge_count(), "qubits": total_qubits(), "ports": total_ports()},
		"neighborhoods": nb,
	}


func _resolve_biome_registry():
	var root = Engine.get_main_loop().root if Engine.get_main_loop() else null
	var reg = root.get_node_or_null("/root/BiomeRegistry") if root else null
	if reg != null:
		return reg
	var cls = load("res://Core/Biomes/BiomeRegistry.gd")
	if cls != null and cls.has_method("get_shared"):
		return cls.get_shared()
	return cls.new() if cls != null else null


func _resolve_icon_registry():
	var root = Engine.get_main_loop().root if Engine.get_main_loop() else null
	var reg = root.get_node_or_null("/root/IconRegistry") if root else null
	if reg != null:
		return reg
	return load("res://Core/Factions/IconRegistry.gd").new()


func _resolve_faction_registry():
	var cls = load("res://Core/Factions/FactionRegistry.gd")
	if cls != null and cls.has_method("get_shared"):
		return cls.get_shared()
	return null
