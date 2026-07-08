class_name Biome
extends RefCounted


## Cached fallback for headless / test contexts where the IconRegistry autoload is absent.
static var _fallback_icon_registry = null

## Biome: A full dissipative scaffold that can be paired with a neighborhood loadout.
##
## A biome is a full terrain body. It carries terrain identity, dissipation
## terms, register capacity, and plot layout. What it does not carry is the
## Hamiltonian/icon side of a neighborhood.
##
## Factions define the emoji web (self-energies, couplings, Lindblad) at the
## individual emoji level. The neighborhood loadout selects which emoji pairs
## become live qubit axes in this biome. The full Hamiltonian assembles from
## faction contributions to those emojis, then optionally patched by the
## biome's Hamiltonian JSONL.

## ========================================
## Identity & Metadata
## ========================================

var name: String = ""
## Discoverable factions that can inhabit this bare biome.
var native_factions: Array = []
var description: String = ""
var image_path: String = ""  # res://assets/biomes/...
var music_path: String = ""  # res://assets/music/...
var discovered: bool = false  # Whether player has unlocked this biome
var discoverable: bool = true  # Whether this biome can appear in the captain-hat unexplored pool. Defaults true; neighborhoods opt out by setting false.
var plot_layout: Array = []  # Optional UI plot layout (normalized or pixel positions)

## The emojis hosted in this biome (flat list; terrain identity / register basis).
var emojis: Array = []

## ========================================
## Icon Components (Biome Quantum Parameters)
## ========================================

## Base icon components: {emoji: {quantum_params}}
## Each emoji has the same structure as in factions:
## {
##   "self_energy": float,
##   "hamiltonian": {target: coupling},
##   "lindblad_outgoing": {target: rate},
##   "lindblad_incoming": {source: rate},
##   "decay": {rate, target},
##   ... (other quantum fields)
## }
var atom_components: Dictionary = {}

## ========================================
## Faction Roster
## ========================================
##
## REMOVED: the old faction roster annotation was a curated narrative
## that drifted from physics in 96% of biomes. Now computed at registry time
## from signature ∩ biome atoms — see `Core/Biomes/FactionBiomeMap.gd` and
## `BiomeRegistry.get_factions_for_biome(name)`.

## ========================================
## Metadata
## ========================================

var tags: Array = []

## Optional authored visual seed from biomes.json ({color, label, ...}).
## Pass-through data: BiomeBuilder applies it to the runtime biome and
## BiomeVisualTheme uses `color` as the palette seed hue.
var visual_config: Dictionary = {}

## Thermodynamic regime (What Fades seam, docs/OPEN_CAMPAIGN.md):
## "" = inherit global switches; "open" = wet country (dissipative while the
## world is sealed); "closed" = inviolable enclave (unitary even after the
## door opens). Story flags may change it at runtime via regime_changes.
var regime: String = ""


## ========================================
## Methods
## ========================================

## Get all emojis this biome defines
func get_all_emojis() -> Array:
	return emojis.duplicate()


func get_native_factions() -> Array:
	return native_factions.duplicate()


## The biome's speaking faction — first native, "" when the record names none.
## One home for the whisper-speaker convention (toasts, graph cards).
func first_native_faction() -> String:
	if native_factions is Array and not native_factions.is_empty():
		return str(native_factions[0])
	return ""


## Returns the icons currently associated with this neighborhood record.
##
## The canonical icon authority lives on factions. This accessor keeps the
## neighborhood loadout shape in one place for current readers.
func get_neighborhood_icons() -> Array:
	var lexicon = (Engine.get_main_loop().root.get_node_or_null("/root/IconRegistry") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if lexicon == null:
		if _fallback_icon_registry == null:
			_fallback_icon_registry = load("res://Core/Factions/IconRegistry.gd").new()
		lexicon = _fallback_icon_registry
	var basis: Dictionary = {}
	for e in emojis:
		basis[EmojiUtil.normalize(str(e))] = true
	var claimed: Dictionary = {}  # emoji -> true once bound to an icon
	var seen: Dictionary = {}
	var out: Array = []
	for fname in native_factions:
		for icon in lexicon.get_icons_for_faction(str(fname)):
			if not (icon is Dictionary):
				continue
			var p0 := EmojiUtil.normalize(str(icon.get("pole_0", "")))
			var p1 := EmojiUtil.normalize(str(icon.get("pole_1", "")))
			if p0 == "" or p1 == "":
				continue
			if not basis.has(p0) or not basis.has(p1):
				continue
			# Each emoji maps to exactly one qubit; skip icons that share a pole
			# with an already-placed icon (within-faction overlaps like Swift Herd's
			# Herd+Flight both using 🐇 — only the first encountered wins).
			if claimed.has(p0) or claimed.has(p1):
				continue
			var key := "%s|%s" % [p0, p1] if p0 < p1 else "%s|%s" % [p1, p0]
			if seen.has(key):
				continue
			seen[key] = true
			claimed[p0] = true
			claimed[p1] = true
			var entry := {"name": str(icon.get("name", "")), "pole_0": p0, "pole_1": p1}
			out.append(entry)
	return out


## Canonical neighborhood signature: the icons (dual-emoji axes) associated
## with this biome record. Each entry is {pole_0, pole_1} — the same shape the
## IconRegistry keys on. Market and overlays read this; faction presence is
## still computed from atoms via FactionBiomeMap.
func get_neighborhood_signature_icons() -> Array:
	var out: Array = []
	for icon in get_neighborhood_icons():
		if not (icon is Dictionary):
			continue
		var p0: String = str(icon.get("pole_0", ""))
		var p1: String = str(icon.get("pole_1", ""))
		if p0 == "" or p1 == "":
			continue
		out.append({"pole_0": p0, "pole_1": p1})
	return out


## Get quantum component for an emoji
func get_atom_component(emoji: String) -> Dictionary:
	if not emoji in emojis:
		return {}
	return atom_components.get(emoji, {})


## Mutate the biome record to grow its basis by one icon pair.
##
## biomes.json is mutable canonical (per the emoji-graph-spaghetti vision):
## player actions that add atoms write directly into the in-memory biome.
## Saves serialize the full canonical state - there is no overlay sidecar.
##
## When `north` or `south` matches an emoji declared in `atom_components` but
## not in `emojis`, this is a *primed-term activation*: the term was authored
## as biome-owned data and only fires once both endpoints are in basis. After
## this mutation, the next substrate rebuild will pick up the now-satisfied
## terms automatically (LindbladBuilder.build_from_atoms filters by basis).
##
## Returns true on success. Returns false (no mutation) on duplicate-atom or
## invalid-input. Caller is responsible for triggering the substrate rebuild
## (BiomeBase.expand_quantum_system or equivalent). Drift is detected at
## tick time by `BiomeBase._check_for_orphan_atoms`, which fires a warning
## once per biome per session if the registry mutation wasn't paired with a
## substrate grow.
func add_atom_pair(north: String, south: String, icon_name: String = "") -> bool:
	if north == "" or south == "":
		return false
	if north == south:
		return false
	if north in emojis or south in emojis:
		return false

	emojis.append(north)
	emojis.append(south)

	var _icon_name_fallback: String = icon_name if icon_name != "" else "%s%s" % [north, south]
	# Seed empty atom_components entries so primed terms keyed BY these atoms
	# (terms whose source is north or south) have a place to live. Existing
	# entries keyed by other atoms with target ∈ {north, south} need no edit;
	# they activate naturally once the basis includes them.
	if not atom_components.has(north):
		atom_components[north] = {}
	if not atom_components.has(south):
		atom_components[south] = {}

	return true


## Validate that all couplings reference defined emojis
func validate() -> bool:
	var valid = true
	var icon_set: Array = get_neighborhood_icons()

	# Validate neighborhood icons: each pole must appear in the emojis list.
	for icon in icon_set:
		var p0 := str(icon.get("pole_0", ""))
		var p1 := str(icon.get("pole_1", ""))
		if p0 == "" or p1 == "":
			push_error("Biome %s: icon %s missing poles" % [name, icon.get("name","?")])
			valid = false

	var seen_emojis: Dictionary = {}
	for emoji in emojis:
		if seen_emojis.has(emoji):
			push_error("Biome %s: duplicate emoji %s in emojis list" % [name, emoji])
			valid = false
		else:
			seen_emojis[emoji] = true

	# atom_components keys should normally be declared emojis. This is a WARNING, not an error
	# (unlike missing icon poles above, which is malformed) because an auxiliary/primed term may
	# legitimately reference an emoji not yet realized in this biome's basis.
	for emoji in atom_components:
		if emoji not in emojis:
			push_warning("Biome %s: auxiliary icon_component %s is not in emojis list" % [name, emoji])

	# A Hamiltonian coupling whose target isn't in this biome's emojis is an EXTERNAL
	# (cross-biome) coupling — valid by design, not a problem — so it's accepted silently.
	# (A push_warning here was self-contradictory: it flagged "(external target OK)" as a
	# warning, spamming the log. If typo-detection on targets is wanted later, validate against
	# the global emoji registry — Biome.validate has no registry handle today.)

	return valid


## ========================================
## Serialization (JSON Data-Driven Support)
## ========================================

## Convert biome to dictionary for JSON export
func to_dict() -> Dictionary:
	var data: Dictionary = {
		"name": name,
		"native_factions": native_factions,
		"description": description,
		"image_path": image_path,
		"music_path": music_path,
		"discovered": discovered,
		"discoverable": discoverable,
		"plot_layout": plot_layout,
		"emojis": emojis,
		"atom_components": atom_components,
		"tags": tags,
	}

	return data


## Load biome from dictionary (JSON import)
func load_from_dict(data: Dictionary) -> void:
	name = data.get("name", "")
	native_factions = data.get("native_factions", [])
	description = data.get("description", "")
	image_path = data.get("image_path", "")
	music_path = data.get("music_path", "")
	discovered = data.get("discovered", false)
	discoverable = data.get("discoverable", true)
	plot_layout = data.get("plot_layout", [])
	# Normalize variation selectors so emoji keys match faction sig strings.
	emojis = EmojiUtil.normalize_array(data.get("emojis", []))
	atom_components = _normalize_atom_components(data.get("atom_components", {}))
	tags = _normalize_tags(data.get("tags", []))
	regime = str(data.get("regime", ""))
	var vc = data.get("visual_config", {})
	visual_config = vc if vc is Dictionary else {}


static func _normalize_tags(raw: Array) -> Array:
	if raw.is_empty():
		return raw
	var result: Array = []
	var seen: Dictionary = {}
	for tag in raw:
		var normalized := str(tag)
		if normalized == "" or seen.has(normalized):
			continue
		seen[normalized] = true
		result.append(normalized)
	return result


## Normalize variation selectors on icon pole strings so they match the
## (already-normalized) emojis list. Without this, an icon authored with
## VS-16 (e.g. "🕵️") fails validation against the bare emojis list ("🕵").
static func _normalize_icon_poles(raw: Array) -> Array:
	if raw.is_empty():
		return raw
	var result: Array = []
	for entry in raw:
		if not (entry is Dictionary):
			result.append(entry)
			continue
		var copy: Dictionary = entry.duplicate()
		if copy.has("pole_0"):
			copy["pole_0"] = EmojiUtil.normalize(str(copy["pole_0"]))
		if copy.has("pole_1"):
			copy["pole_1"] = EmojiUtil.normalize(str(copy["pole_1"]))
		result.append(copy)
	return result


## Normalize all emoji keys inside atom_components.
## Structure: {emoji: {field: {emoji: value} | scalar | {rate, target}}}
static func _normalize_atom_components(raw: Dictionary) -> Dictionary:
	if raw.is_empty():
		return raw
	var result: Dictionary = {}
	for emoji_key in raw:
		var nkey: String = EmojiUtil.normalize(str(emoji_key))
		var comp = raw[emoji_key]
		if not comp is Dictionary:
			result[nkey] = comp
			continue
		var nc: Dictionary = {}
		for field in comp:
			var val = comp[field]
			match field:
				"lindblad_outgoing", "lindblad_incoming", "hamiltonian":
					nc[field] = EmojiUtil.normalize_keys(val if val is Dictionary else {})
				"decay":
					nc[field] = EmojiUtil.normalize_decay(val if val is Dictionary else {})
				_:
					nc[field] = val
		result[nkey] = nc
	return result


## Create biome from dictionary (static factory)
static func from_dict(data: Dictionary) -> Biome:
	var biome = load("res://Core/Biomes/Biome.gd").new()
	biome.load_from_dict(data)
	return biome


## Debug representation
func _to_string() -> String:
	return "Biome<%s>(%d emojis)" % [name, emojis.size()]
