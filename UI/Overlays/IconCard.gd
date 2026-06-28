class_name IconCard
extends RefCounted

## IconCard — pure data gatherer for the icon-detail panel.
##
## Reads existing computed sources only. No mutations, no signals, no caching.
## Returns a Dictionary the caller renders with its own layout primitives.
## Sibling of FactionCard (UI/Overlays/FactionCard.gd) — same discipline.
##
## Sections returned:
##   emoji            String              — the queried emoji
##   present          bool                — true if found in IconRegistry
##   icon_name        String              — icon name (e.g. "CelestialCycle")
##   complement       String              — the other pole emoji in the icon
##   is_axial         bool                — true if emoji is one of the 12 canonical poles
##   axis_index       int                 — [0..AXIS_COUNT-1] when axial, -1 otherwise
##   axis_label       String              — "label_0 ↔ label_1" when axial
##   faction_speakers Array[String]       — factions with this emoji in their signature
##   affinity         float               — [0,1] from FactionAffinity.get_affinity
##   player_known     bool                — does farm.known_icons contain this emoji?
##   biomes_present   Array[String]       — biomes whose .icons map contains this emoji
##   atom_summary     Dictionary          — {self_energy, decay_rate, top_couplings}


const TOP_COUPLINGS_N: int = 3


## Scalar magnitude of a Hamiltonian coupling value. icons.json stores these as a
## MIX of real couplings (float/int) and complex couplings as [re, im] arrays (also
## Vector2 once merged) — so a bare float() throws "Nonexistent 'float' constructor"
## on the arrays. Convention matches NeighborhoodGraph._coupling_magnitude / Icon.gd:
## complex → sqrt(re² + im²).
static func _coupling_magnitude(v) -> float:
	if v is float or v is int:
		return absf(float(v))
	if v is Vector2:
		return v.length()
	if v is Array and v.size() >= 2:
		return sqrt(float(v[0]) * float(v[0]) + float(v[1]) * float(v[1]))
	if v is Array and v.size() == 1:
		return absf(float(v[0]))
	return 0.0


static func gather(emoji: String, farm) -> Dictionary:
	var out: Dictionary = {
		"emoji": emoji,
		"present": false,
		"icon_name": "",
		"complement": "",
		"is_axial": false,
		"axis_index": -1,
		"axis_label": "",
		"faction_speakers": [],
		"affinity": 0.0,
		"player_known": false,
		"biomes_present": [],
		"atom_summary": {},
	}
	if emoji == "" or farm == null:
		return out

	# Identity from IconRegistry (autoload alias for IconRegistry).
	var icon_registry = (Engine.get_main_loop().root.get_node_or_null("/root/IconRegistry") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if icon_registry == null:
		return out
	var icon_record: Dictionary = icon_registry.find_icon_by_emoji(emoji)
	if icon_record.is_empty():
		return out
	out["present"] = true
	out["icon_name"] = str(icon_record.get("name", ""))
	var pole0: String = str(icon_record.get("pole_0", ""))
	var pole1: String = str(icon_record.get("pole_1", ""))
	out["complement"] = pole1 if emoji == pole0 else pole0
	out["is_axial"] = bool(icon_record.get("axial", false))
	var axis_idx: int = int(icon_record.get("axis_index", -1))
	out["axis_index"] = axis_idx
	if axis_idx >= 0:
		var axis_def: Dictionary = FactionAxes.get_axis(axis_idx)
		out["axis_label"] = "%s ↔ %s" % [
			str(axis_def.get("label_0", "?")),
			str(axis_def.get("label_1", "?")),
		]

	# Atom physics summary.
	var atom = icon_registry.get_atom(emoji)
	if atom != null:
		var couplings: Array = []
		var hc = atom.hamiltonian_couplings if "hamiltonian_couplings" in atom else null
		if hc is Dictionary:
			for to_emoji in hc.keys():
				couplings.append({
					"from": emoji,
					"to": str(to_emoji),
					"weight": _coupling_magnitude(hc[to_emoji]),
				})
		couplings.sort_custom(func(a, b): return absf(float(a.weight)) > absf(float(b.weight)))
		out["atom_summary"] = {
			"self_energy": float(atom.self_energy if "self_energy" in atom else 0.0),
			"top_couplings": couplings.slice(0, TOP_COUPLINGS_N),
		}

	# Faction speakers + affinity.
	var fr = farm.faction_density.get_registry() if farm.faction_density != null else null
	if fr != null and fr.has_method("get_factions_for_emoji"):
		var speakers: Array = fr.get_factions_for_emoji(emoji)
		var names: Array[String] = []
		for f in speakers:
			if f != null and "name" in f:
				names.append(str(f.name))
		out["faction_speakers"] = names
	out["affinity"] = FactionAffinity.get_affinity(emoji, farm)

	# Player ownership.
	if "known_icons" in farm and farm.known_icons is Array:
		for p in farm.known_icons:
			if p is Dictionary and (str(p.get("north", "")) == emoji or str(p.get("south", "")) == emoji):
				out["player_known"] = true
				break

	# Biomes containing this emoji.
	if farm.grid != null and farm.grid.has_method("get_all_biomes"):
		var biomes_dict: Dictionary = farm.grid.get_all_biomes()
		for bname in biomes_dict.keys():
			var biome = biomes_dict[bname]
			if biome == null:
				continue
			var icons = biome.icons if "icons" in biome else null
			if icons is Dictionary and icons.has(emoji):
				out["biomes_present"].append(str(bname))

	return out
