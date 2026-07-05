class_name FactionCard
extends RefCounted

## FactionCard — pure data gatherer for the faction-detail panel.
##
## Reads existing computed sources only. No mutations, no signals, no caching.
## Returns a Dictionary the caller renders with its own layout primitives.
##
## Sections returned:
##   cloud               Array[String] — the faction's atoms (emojis it touches)
##   affinity            Array[{emoji, value}] — per-cloud-emoji affinity ∈[0,1]
##   biomes_of_presence  Array[String] — biome names where faction is admitted (signature gate)
##   alignment_top       Array[{from, to, weight}] — top alignment couplings by |weight|
##   standing            float — faction standing scalar ∈[-1,1] (0.0 if no entry)


const ALIGNMENT_TOP_N: int = 3


static func gather(faction_name: String, farm) -> Dictionary:
	var out: Dictionary = {
		"faction_name": faction_name,
		"cloud": [],
		"affinity": [],
		"biomes_of_presence": [],
		"alignment_top": [],
		"standing": 0.0,
		"present": false,
	}
	if faction_name == "" or farm == null:
		return out
	var registry = farm.faction_density.get_registry() if farm.faction_density != null else null
	if registry == null:
		return out
	var faction = registry.get_by_name(faction_name)
	if faction == null:
		return out
	out["present"] = true

	var cloud: Array = faction.cloud if "cloud" in faction and faction.cloud is Array else []
	out["cloud"] = cloud.duplicate()

	for emoji in cloud:
		out["affinity"].append({
			"emoji": str(emoji),
			"value": FactionAffinity.get_affinity(str(emoji), farm),
		})

	var biomes_dict: Dictionary = {}
	if farm.grid != null and farm.grid.has_method("get_all_biomes"):
		biomes_dict = farm.grid.get_all_biomes()
	if not biomes_dict.is_empty():
		out["biomes_of_presence"] = FactionBiomeMap.biomes_for_faction(
			faction_name, biomes_dict, registry,
		)

	var couplings: Dictionary = faction.alignment_couplings if "alignment_couplings" in faction else {}
	var flat: Array = []
	for from_emoji in couplings.keys():
		var inner = couplings[from_emoji]
		if not (inner is Dictionary):
			continue
		for to_emoji in inner.keys():
			flat.append({
				"from": str(from_emoji),
				"to": str(to_emoji),
				"weight": float(inner[to_emoji]),
			})
	flat.sort_custom(func(a, b): return absf(a.weight) > absf(b.weight))
	out["alignment_top"] = flat.slice(0, ALIGNMENT_TOP_N)

	if "faction_standings" in farm and farm.faction_standings.has(faction_name):
		var s = farm.faction_standings[faction_name]
		if s != null and s.has_method("scalar"):
			out["standing"] = float(s.scalar())

	return out
