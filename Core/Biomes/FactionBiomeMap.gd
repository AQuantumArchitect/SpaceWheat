extends RefCounted

## FactionBiomeMap — single source of truth for "which factions live in which biomes."
##
## TWO ADMISSION GATES:
##
##   factions_for_biome_by_signature() — CANONICAL (icon-pair gate)
##     A faction is admitted iff its faction signature (the set of icon pairs
##     it owns in IconLexicon) contains an icon present in the biome's qubit
##     register map. Once admitted, the faction's full atom physics runs.
##     Orphan icons (owner_faction == "") admit no faction — neutral zones.
##
##   factions_for_biome() — LEGACY (atom-overlap gate)
##     Kept for fallback and data-migration checks. A faction was "in" a biome
##     iff its atom vocabulary intersected the biome's atom set. Retained so
##     callers can compare old vs. new during transition.
##
## Atom set per biome is the union of:
##   - register_map.coordinates.keys()  (live QC's bound emojis)
##   - atom_components.keys()           (data-side declared atoms)
##
## Faction atoms (still called .signature in the GDScript field) default to
## .signature; falls back to .hamiltonian.keys() when empty.

const FactionRegistry := preload("res://Core/Factions/FactionRegistry.gd")
const IconLexicon := preload("res://Core/Factions/IconLexicon.gd")


## ============================================================================
## CANONICAL GATE — faction signature (icon pairs)
## ============================================================================

## Core gate: given a register_map, return sorted faction names whose signature
## contains at least one icon matching a qubit pair. Single authoritative loop —
## all other gate functions call this.
static func admitted_names_for_register(register_map) -> Array:
	if register_map == null:
		return []
	var lexicon := IconLexicon.new()
	var seen: Dictionary = {}
	for q in range(register_map.num_qubits):
		var pair: Dictionary = register_map.axes.get(q, {})
		var north: String = str(pair.get("north", ""))
		var south: String = str(pair.get("south", ""))
		if north == "" or south == "":
			continue
		var record = lexicon.find_icon_by_pair(north, south)
		if record == null:
			continue
		var owner: String = str(record.get("owner_faction", ""))
		if owner != "" and not seen.has(owner):
			seen[owner] = true
	var out: Array = seen.keys()
	out.sort()
	return out


## Returns faction names admitted to this biome via faction signature.
##
## Live path (booted BiomeBase): reads from quantum_computer.register_map.
## Data path (unbooted Biome.gd record): reads from the biome's icons[] array
##   (the {pole_0, pole_1} pairs baked into biomes.json).
## Sorted alphabetically.
static func factions_for_biome_by_signature(biome) -> Array:
	if biome == null:
		return []
	# Live path: booted biome with a QC and register_map.
	var qc = biome.quantum_computer if "quantum_computer" in biome else null
	if qc != null and qc.register_map != null:
		return admitted_names_for_register(qc.register_map)
	# Data path: unbooted biome record — read icon pairs from biomes.json icons[].
	if "icons" in biome and biome.icons is Array and not biome.icons.is_empty():
		var lexicon := IconLexicon.new()
		var seen: Dictionary = {}
		for icon in biome.icons:
			if not (icon is Dictionary):
				continue
			var north: String = str(icon.get("pole_0", ""))
			var south: String = str(icon.get("pole_1", ""))
			if north == "" or south == "":
				continue
			var record = lexicon.find_icon_by_pair(north, south)
			if record == null:
				continue
			var owner: String = str(record.get("owner_faction", ""))
			if owner != "" and not seen.has(owner):
				seen[owner] = true
		var out: Array = seen.keys()
		out.sort()
		return out
	return []


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


## Overlap count: how many signature icons this faction shares with the biome.
## Works on both live biomes (via register_map) and data biomes (via icons[]).
static func signature_overlap_count(faction_name: String, biome) -> int:
	if faction_name.is_empty() or biome == null:
		return 0
	# Build the icon pair list from whichever path is available.
	var pairs: Array = []
	var qc = biome.quantum_computer if "quantum_computer" in biome else null
	if qc != null and qc.register_map != null:
		var rm = qc.register_map
		for q in range(rm.num_qubits):
			var pair: Dictionary = rm.axes.get(q, {})
			pairs.append(pair)
	elif "icons" in biome and biome.icons is Array:
		for icon in biome.icons:
			if icon is Dictionary:
				pairs.append({"north": str(icon.get("pole_0", "")), "south": str(icon.get("pole_1", ""))})
	if pairs.is_empty():
		return 0
	var lexicon := IconLexicon.new()
	var count: int = 0
	for pair in pairs:
		var north: String = str(pair.get("north", ""))
		var south: String = str(pair.get("south", ""))
		if north == "" or south == "":
			continue
		var record = lexicon.find_icon_by_pair(north, south)
		if record != null and str(record.get("owner_faction", "")) == faction_name:
			count += 1
	return count


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
			atoms[str(emoji)] = true
	# Some biomes carry a Dictionary literal as _biome_data
	if biome.has_method("get") and "_biome_data" in biome and biome._biome_data is Dictionary:
		var ac = biome._biome_data.get("atom_components", {})
		if ac is Dictionary:
			for emoji in ac.keys():
				atoms[str(emoji)] = true
	# Some biomes expose a flat `emojis` array (Biome.gd data path)
	if "emojis" in biome and biome.emojis is Array:
		for emoji in biome.emojis:
			if typeof(emoji) == TYPE_STRING and emoji != "":
				atoms[str(emoji)] = true
	return atoms.keys()


## Faction's vocabulary emojis. Prefers .signature; falls back to .hamiltonian
## keys when signature is empty (some faction biomes don't author signature).
static func _vocabulary_of_faction(faction) -> Array:
	if faction == null:
		return []
	var sig: Array = faction.signature if "signature" in faction and faction.signature is Array else []
	if not sig.is_empty():
		return sig
	if "hamiltonian" in faction and faction.hamiltonian is Dictionary and not faction.hamiltonian.is_empty():
		return faction.hamiltonian.keys()
	return []


## Returns faction names whose vocabulary intersects this biome's atoms.
## Sorted alphabetically for stable output.
static func factions_for_biome(biome, faction_registry) -> Array:
	if biome == null or faction_registry == null:
		return []
	var atoms_arr: Array = _atoms_of_biome(biome)
	if atoms_arr.is_empty():
		return []
	var atoms: Dictionary = {}
	for a in atoms_arr:
		atoms[str(a)] = true
	var out: Array = []
	for faction in faction_registry.get_all():
		if faction == null:
			continue
		var vocab: Array = _vocabulary_of_faction(faction)
		for emoji in vocab:
			if atoms.has(str(emoji)):
				out.append(str(faction.name))
				break
	out.sort()
	return out


## Inverse direction: for a given faction, return live biome names where
## the faction has presence. `biomes_dict` is a {name → biome} map (e.g.
## from FarmGrid.get_all_biomes()).
static func biomes_for_faction(faction_name: String, biomes_dict: Dictionary, faction_registry) -> Array:
	if faction_name == "" or biomes_dict.is_empty() or faction_registry == null:
		return []
	var faction = faction_registry.get_by_name(faction_name)
	if faction == null:
		return []
	var vocab_arr: Array = _vocabulary_of_faction(faction)
	if vocab_arr.is_empty():
		return []
	var vocab: Dictionary = {}
	for emoji in vocab_arr:
		vocab[str(emoji)] = true
	var out: Array = []
	for bname in biomes_dict:
		var biome = biomes_dict[bname]
		var atoms_arr: Array = _atoms_of_biome(biome)
		for a in atoms_arr:
			if vocab.has(str(a)):
				out.append(str(bname))
				break
	out.sort()
	return out


## Returns how many atoms this faction shares with the given biome.
## Used in Bridges frame to show depth of presence, not just binary membership.
static func overlap_count_for_faction_biome(faction_name: String, biome, faction_registry) -> int:
	if faction_name.is_empty() or biome == null or faction_registry == null:
		return 0
	var faction = faction_registry.get_by_name(faction_name)
	if faction == null:
		return 0
	var vocab: Array = _vocabulary_of_faction(faction)
	if vocab.is_empty():
		return 0
	var atoms_arr: Array = _atoms_of_biome(biome)
	var atom_set: Dictionary = {}
	for a in atoms_arr:
		atom_set[str(a)] = true
	var count: int = 0
	for emoji in vocab:
		if atom_set.has(str(emoji)):
			count += 1
	return count


## Bulk: build the full {faction_name → [biome_names]} index in one pass.
## More efficient than calling biomes_for_faction per-faction when a caller
## needs the whole network (Bridges frame, all socialites at once).
static func index_factions_to_biomes(biomes_dict: Dictionary, faction_registry) -> Dictionary:
	var out: Dictionary = {}
	if biomes_dict.is_empty() or faction_registry == null:
		return out
	# Pre-compute atom sets per biome.
	var atoms_per_biome: Dictionary = {}
	for bname in biomes_dict:
		atoms_per_biome[bname] = _atoms_of_biome(biomes_dict[bname])
	# For each faction, scan all biomes.
	for faction in faction_registry.get_all():
		if faction == null:
			continue
		var vocab_arr: Array = _vocabulary_of_faction(faction)
		if vocab_arr.is_empty():
			continue
		var vocab: Dictionary = {}
		for emoji in vocab_arr:
			vocab[str(emoji)] = true
		var hits: Array = []
		for bname in biomes_dict:
			for a in atoms_per_biome[bname]:
				if vocab.has(str(a)):
					hits.append(str(bname))
					break
		if not hits.is_empty():
			hits.sort()
			out[str(faction.name)] = hits
	return out
