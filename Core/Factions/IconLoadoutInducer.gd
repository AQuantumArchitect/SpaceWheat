class_name IconLoadoutInducer
extends RefCounted

## IconLoadoutInducer — pick the icons that should populate a bare biome
## under a given connection faction.
##
## Vocabulary (locked):
##   atom        = single emoji
##   cloud       = set of atoms
##   icon        = two-pole physics record
##   signature   = set of icons
##   sibling     = pole-share between icons
##   family(a)   = icons whose poles include a
##
## ============================================================================
## PARAMETRIC KNOB — 5-step icon-selection rule
## ============================================================================
##   0. PREFILTER (knob, NEW) — candidate must be a member of the faction's
##      signature OR be in family_of_cloud(union_of_clouds(faction.signature)).
##      Plain English: the faction's own icons, plus any icon whose poles touch
##      an atom in any of the faction's icons' clouds.
##
##   1. POLE-FIT — keep candidates whose {pole_0, pole_1} ⊆ biome.cloud
##      (biome.atom_components.keys()).
##
##   2. PARTITION by ownership:
##        owned    = candidates whose icon is owned by `faction.name`
##        orphan   = candidates with no owner (get_factions_for_pair returns [])
##        foreign  = the rest
##
##   3. ACCEPT = owned ∪ orphan        (foreign excluded — keeps the
##                                       neighborhood "about" this faction)
##
##   4. SCORE — +2 per pole that matches an atom in any faction-signature-icon
##      pole, else +1; +1 owned bonus; sort desc; cap at max_icons.
##
## Future rounds may move these knobs to JSON for designer sweeps. Composer is
## downstream and never sees these rules.
##
## NOTE: `Faction.signature` on disk is currently `Array[atom]`. Use
## `IconRegistry.get_icons_for_faction(faction.name)` to get the actual
## signature (set of icons). Rename of the field is tracked separately —
## see memory/feedback_terms_atom_cloud_signature.md.



## Induce an icon loadout for `bare_biome` under `faction`.
##
## Returns Array of {name, pole_0, pole_1} ready for
## BiomeBuilder.build_neighborhood_loadout(..., {"neighborhood_icons": <this>}).
##
## `lexicon` may be passed in; otherwise the autoload IconRegistry is resolved.
func induce(faction, bare_biome, max_icons: int = 8, lexicon = null) -> Array:
	if faction == null or bare_biome == null:
		return []
	if lexicon == null:
		lexicon = (Engine.get_main_loop().root.get_node_or_null("/root/IconRegistry") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if lexicon == null:
		lexicon = (Engine.get_main_loop().root.get_node_or_null("/root/IconRegistry") if Engine.get_main_loop() and Engine.get_main_loop().root else null)

	var biome_atoms := _biome_atom_set(bare_biome)
	if biome_atoms.is_empty():
		return []

	var faction_name: String = str(faction.name) if "name" in faction else ""

	# Faction's actual signature (set of icons). Pulled from the registry
	# rather than the on-disk `faction.signature` atom array.
	var faction_signature: Array = []
	if faction_name != "":
		faction_signature = lexicon.get_icons_for_faction(faction_name)

	# Step 0: PREFILTER — candidate set is faction's own signature plus all
	# icons whose poles touch atoms in the faction-signature's combined cloud.
	var relations := IconRelations.new()
	var family := IconFamily.new()
	var faction_cloud: Dictionary = relations.union_of_clouds(faction_signature)
	var allowed := _build_icon_key_set(faction_signature)
	if not faction_cloud.is_empty():
		var via_cloud: Array = family.family_of_cloud(faction_cloud, lexicon)
		for ic in via_cloud:
			allowed[_icon_key(ic)] = true

	# Atoms that count for "+2 per pole match" in scoring: poles of the
	# faction's signature icons.
	var sig_pole_atoms: Dictionary = {}
	for ic in faction_signature:
		if ic is Dictionary:
			var p0 := str(ic.get("pole_0", ""))
			var p1 := str(ic.get("pole_1", ""))
			if p0 != "":
				sig_pole_atoms[p0] = true
			if p1 != "":
				sig_pole_atoms[p1] = true

	# If the faction has no signature, the prefilter set is empty → no
	# induction is possible. Return empty so the BiomeBuilder fallback path
	# can take over (or so the topology output flags an empty neighborhood).
	if allowed.is_empty():
		return []

	# Steps 1–4: scan candidates, partition, score.
	var scored: Array = []
	for record in lexicon.get_all():
		if not (record is Dictionary):
			continue
		if record.get("anonymous", false):
			continue
		var p0 := str(record.get("pole_0", ""))
		var p1 := str(record.get("pole_1", ""))
		if p0 == "" or p1 == "":
			continue
		# Step 0 enforcement.
		if not allowed.has(_icon_key(record)):
			continue
		# Step 1: pole-fit.
		if not (biome_atoms.has(p0) and biome_atoms.has(p1)):
			continue

		# Step 2: ownership partition.
		var owners: Array = lexicon.get_factions_for_pair(p0, p1)
		var is_owned := faction_name != "" and owners.has(faction_name)
		var is_orphan := owners.is_empty()
		# Step 3: accept owned ∪ orphan.
		if not (is_owned or is_orphan):
			continue

		# Step 4: score.
		var score := 0
		score += 2 if sig_pole_atoms.has(p0) else 1
		score += 2 if sig_pole_atoms.has(p1) else 1
		if is_owned:
			score += 1

		scored.append({
			"score":  score,
			"name":   str(record.get("name", "%s/%s" % [p0, p1])),
			"pole_0": p0,
			"pole_1": p1,
		})

	scored.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))

	var cap := max_icons
	if cap <= 0:
		cap = scored.size()
	var out: Array = []
	for entry in scored.slice(0, cap):
		out.append({
			"name":   entry["name"],
			"pole_0": entry["pole_0"],
			"pole_1": entry["pole_1"],
		})
	return out


## Build the cloud (atom set) of a bare biome. Returns Dictionary[atom → true]
## so the hot loop above can do O(1) `has` checks.
func _biome_atom_set(biome) -> Dictionary:
	var out: Dictionary = {}
	if biome == null:
		return out
	if "atom_components" in biome and biome.atom_components is Dictionary:
		for atom in biome.atom_components.keys():
			if atom == "everything" or atom.is_empty():
				continue
			out[str(atom)] = true
	if "emojis" in biome and biome.emojis is Array:
		for atom in biome.emojis:
			if typeof(atom) == TYPE_STRING and atom != "":
				out[str(atom)] = true
	# Live BiomeBase: register_map provides the active atom set.
	if "quantum_computer" in biome and biome.quantum_computer != null:
		var qc = biome.quantum_computer
		if qc.register_map != null:
			for atom in qc.register_map.coordinates.keys():
				out[str(atom)] = true
	return out


func _icon_key(record: Dictionary) -> String:
	return "%s|%s" % [str(record.get("pole_0", "")), str(record.get("pole_1", ""))]


func _build_icon_key_set(icons: Array) -> Dictionary:
	var out: Dictionary = {}
	for ic in icons:
		if ic is Dictionary:
			out[_icon_key(ic)] = true
	return out
