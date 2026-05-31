class_name FactionBiomeMap
extends RefCounted

## FactionBiomeMap — single source of truth for which factions live in which biomes.
##
## CANONICAL GATE: factions_for_biome_by_signature() (icon gate)
##   A faction is admitted iff it identifies with an icon present in the
##   biome's qubit register map (many:many via IconRegistry._pair_to_factions).
##   Orphan icons (no faction affiliation) admit no faction — neutral zones.
##
## INVERSE GATE: biomes_for_faction() (atom-overlap; live in Farm + SocialiteCluster)
##   Uses _atoms_of_biome() + _icons_of_faction(); kept for the faction→biome
##   direction until a signature-based inverse is implemented.


static var _lexicon_cache = null

## Get the shared autoload IconRegistry, falling back to a cached instance in
## test harnesses that don't boot the autoload tree.
static func _shared_lexicon():
	var auto = (Engine.get_main_loop().root.get_node_or_null("/root/IconRegistry") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if auto != null:
		return auto
	if _lexicon_cache == null:
		_lexicon_cache = load("res://Core/Factions/IconRegistry.gd").new()
	return _lexicon_cache


## ============================================================================
## CANONICAL GATE — faction signature (icon pairs)
## ============================================================================

## PURE: extract pole pairs from a register_map. Returns [{pole_0, pole_1}, …].
## Skips qubits with empty poles. Order follows qubit index.
static func _pairs_from_register(register_map) -> Array:
	var out: Array = []
	if register_map == null:
		return out
	for q in range(register_map.num_qubits):
		var axis: Dictionary = register_map.axes.get(q, {})
		var north := str(axis.get("north", ""))
		var south := str(axis.get("south", ""))
		if north == "" or south == "":
			continue
		out.append({"pole_0": north, "pole_1": south})
	return out


## PURE: extract pole icons from a biome record (data-path). Tries
## `get_neighborhood_signature_icons()` then `get_neighborhood_icons()`.
## Pairs are normalized to {pole_0, pole_1}. Order preserved.
static func _pairs_from_biome(biome) -> Array:
	var out: Array = []
	if biome == null:
		return out
	if biome.has_method("get_neighborhood_signature_icons"):
		var icons: Array = biome.get_neighborhood_signature_icons()
		for icon in icons:
			if not (icon is Dictionary):
				continue
			var p0 := str(icon.get("pole_0", ""))
			var p1 := str(icon.get("pole_1", ""))
			if p0 != "" and p1 != "":
				out.append({"pole_0": p0, "pole_1": p1})
		if not out.is_empty():
			return out
	if biome.has_method("get_neighborhood_icons"):
		for icon in biome.get_neighborhood_icons():
			if not (icon is Dictionary):
				continue
			var p0 := str(icon.get("pole_0", ""))
			var p1 := str(icon.get("pole_1", ""))
			if p0 != "" and p1 != "":
				out.append({"pole_0": p0, "pole_1": p1})
	return out


## ADAPTER: aggregate sorted unique faction names that own any of the given
## pole pairs. Hits the IconRegistry for ownership lookups.
static func _factions_owning_pairs(pairs: Array) -> Array:
	if pairs.is_empty():
		return []
	var lexicon = _shared_lexicon()
	var seen: Dictionary = {}
	for pair in pairs:
		if not (pair is Dictionary):
			continue
		var north := str(pair.get("pole_0", ""))
		var south := str(pair.get("pole_1", ""))
		if north == "" or south == "":
			continue
		for owner in lexicon.get_factions_for_pair(north, south):
			seen[owner] = true
	var out: Array = seen.keys()
	out.sort()
	return out


## Core gate: given a register_map, return sorted faction names whose signature
## contains at least one icon matching a qubit pair. Single authoritative loop —
## all other gate functions call this.
static func admitted_names_for_register(register_map) -> Array:
	return _factions_owning_pairs(_pairs_from_register(register_map))


## Returns faction names admitted to this biome via faction signature.
##
## Live path (booted BiomeBase): reads from quantum_computer.register_map.
## Data path (Biome.gd record): reads from `get_neighborhood_signature_icons()`.
## Sorted alphabetically.
static func factions_for_biome_by_signature(biome) -> Array:
	if biome == null:
		return []
	# Live path: booted biome with a QC and register_map.
	var qc = biome.quantum_computer if "quantum_computer" in biome else null
	if qc != null and qc.register_map != null:
		return admitted_names_for_register(qc.register_map)
	# Data path: unbooted biome record.
	return _factions_owning_pairs(_pairs_from_biome(biome))


## Bulk index: {faction_name → [biome_names]} using the signature gate.
## Efficient for Bridges frame and full-network scans.
static func index_factions_to_biomes_by_signature(biomes_dict: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if biomes_dict.is_empty():
		return out
	for bname in biomes_dict:
		var admitted: Array = factions_for_biome_by_signature(biomes_dict[bname])
		for fname in admitted:
			if not out.has(fname):
				out[fname] = []
			(out[fname] as Array).append(str(bname))
	for fname in out:
		(out[fname] as Array).sort()
	return out


## ADAPTER: count pole pairs owned by `faction_name`. Used to rank biomes
## by how many of their signature icons overlap a given faction.
static func _count_pairs_owned_by(pairs: Array, faction_name: String) -> int:
	if pairs.is_empty() or faction_name.is_empty():
		return 0
	var lexicon = _shared_lexicon()
	var count: int = 0
	for pair in pairs:
		if not (pair is Dictionary):
			continue
		var north := str(pair.get("pole_0", ""))
		var south := str(pair.get("pole_1", ""))
		if north == "" or south == "":
			continue
		if faction_name in lexicon.get_factions_for_pair(north, south):
			count += 1
	return count


## Overlap count: how many signature icons this faction shares with the biome.
## Works on both live biomes (via register_map) and data biomes (via neighborhood
## icon loadout). Reuses the same pair extractors as `factions_for_biome_by_signature`.
static func signature_overlap_count(faction_name: String, biome) -> int:
	if faction_name.is_empty() or biome == null:
		return 0
	var qc = biome.quantum_computer if "quantum_computer" in biome else null
	var pairs: Array = _pairs_from_register(qc.register_map) if qc != null and qc.register_map != null else _pairs_from_biome(biome)
	return _count_pairs_owned_by(pairs, faction_name)


## Compute the set of atoms physically present in a biome.
## Live (QC) takes precedence; falls back to data-side atom_components.
static func _atoms_of_biome(biome) -> Array:
	if biome == null:
		return []
	var atoms: Dictionary = {}
	# Live QC binding (runtime BiomeBase instance)
	if biome.has_method("get") or "quantum_computer" in biome:
		var qc = biome.quantum_computer if "quantum_computer" in biome else null
		if qc != null and qc.register_map != null:
			for emoji in qc.register_map.coordinates.keys():
				atoms[str(emoji)] = true
	# Data-side declared atoms (Biome.gd or _biome_data Dictionary)
	if "atom_components" in biome and biome.atom_components is Dictionary:
		for emoji in biome.atom_components.keys():
			if emoji == "everything" or emoji.is_empty():
				continue
			atoms[str(emoji)] = true
	# Some biomes carry a Dictionary literal as _biome_data
	if biome.has_method("get") and "_biome_data" in biome and biome._biome_data is Dictionary:
		var ac = biome._biome_data.get("atom_components", {})
		if ac is Dictionary:
			for emoji in ac.keys():
				if emoji == "everything" or emoji.is_empty():
					continue
				atoms[str(emoji)] = true
	# Some biomes expose a flat `emojis` array (Biome.gd data path)
	if "emojis" in biome and biome.emojis is Array:
		for emoji in biome.emojis:
			if typeof(emoji) == TYPE_STRING and emoji != "":
				atoms[str(emoji)] = true
	return atoms.keys()


## PURE: icon emojis derived from a list of icon dicts.
## Each `icons` entry: {name, pole_0, pole_1}. Returns deduped poles in input order.
## This is the math kernel — no registry, no JSON, deterministic.
static func _icons_from_icons(icons: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for icon in icons:
		if not (icon is Dictionary):
			continue
		for pole_key in ["pole_0", "pole_1"]:
			var pole := str(icon.get(pole_key, ""))
			if pole != "" and not seen.has(pole):
				seen[pole] = true
				out.append(pole)
	return out


## ADAPTER: faction's icon emojis. Prefers .signature; falls back to owned
## icon poles via the shared IconRegistry when signature is empty.
static func _icons_of_faction(faction) -> Array:
	if faction == null:
		return []
	var sig: Array = faction.cloud if "cloud" in faction and faction.cloud is Array else []
	if not sig.is_empty():
		return sig
	if not ("name" in faction) or str(faction.name) == "":
		return []
	var icons: Array = _shared_lexicon().get_icons_for_faction(str(faction.name))
	return _icons_from_icons(icons)


## PURE: biome names whose atom set intersects the given icon set.
## - `icons`: array of icon emojis (faction signature / owned poles).
## - `biome_atoms`: {biome_name → Array of atom emojis} pre-computed.
## Returns sorted list of biome names. No registry, no JSON, deterministic.
static func _biomes_with_icon_overlap(icons: Array, biome_atoms: Dictionary) -> Array:
	if icons.is_empty() or biome_atoms.is_empty():
		return []
	var icon_set: Dictionary = {}
	for emoji in icons:
		icon_set[str(emoji)] = true
	var out: Array = []
	for bname in biome_atoms:
		var atoms: Array = biome_atoms[bname] if biome_atoms[bname] is Array else []
		for a in atoms:
			if icon_set.has(str(a)):
				out.append(str(bname))
				break
	out.sort()
	return out


## ADAPTER: for a given faction, return live biome names where the faction has
## presence. `biomes_dict` is a {name → biome} map (e.g. from
## FarmGrid.get_all_biomes()). Resolves faction + atoms via the registries,
## then delegates to the pure overlap kernel.
static func biomes_for_faction(faction_name: String, biomes_dict: Dictionary, faction_registry) -> Array:
	if faction_name == "" or biomes_dict.is_empty() or faction_registry == null:
		return []
	var faction = faction_registry.get_by_name(faction_name)
	if faction == null:
		return []
	var icons: Array = _icons_of_faction(faction)
	if icons.is_empty():
		return []
	var biome_atoms: Dictionary = {}
	for bname in biomes_dict:
		biome_atoms[str(bname)] = _atoms_of_biome(biomes_dict[bname])
	return _biomes_with_icon_overlap(icons, biome_atoms)
