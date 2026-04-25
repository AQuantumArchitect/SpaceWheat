class_name IconLexicon
extends RefCounted

## IconLexicon — registry of pair-Icons (named two-state qubit axes).
##
## A pair-Icon is {name, pole_0, pole_1, owner_faction, biomes_present_in}.
## Two ingestion sources at boot:
##   1. factions.json icons[] — the faction's "ambassador" Icons (owner declared)
##   2. biomes.json icons[]   — placement (which biomes a pair lives in)
##
## Plus runtime: `register_anonymous(p0, p1)` for player-discovered pairs that
## no faction owns.
##
## Lookup is keyed by (pole_0, pole_1). Names are display labels and may collide
## across factions (e.g. "Circuit" appears for two distinct pairs).
##
## Distinct from `EmojiPhysicsRegistry` (autoload at
## Core/QuantumSubstrate/EmojiPhysicsRegistry.gd) which stores per-emoji
## physics. This registry is about named axes; that one is about atoms.

const FactionAxes = preload("res://Core/Factions/FactionAxes.gd")

const JSON_FACTIONS = "res://Core/Factions/data/factions.json"
const JSON_BIOMES = "res://Core/Biomes/data/biomes.json"

## (pole_0, pole_1) → Dictionary of icon record. Keyed by "p0|p1" string.
var _by_pair: Dictionary = {}

## name → Array of pair keys (multiple pairs may share a display name)
var _by_name: Dictionary = {}

## faction_name → Array of pair keys it owns
var _by_faction: Dictionary = {}

## biome_name → Array of pair keys present in it
var _by_biome: Dictionary = {}

var _world_built_count: int = 0
var _anonymous_count: int = 0


func _init() -> void:
	_load()


static func _pair_key(p0: String, p1: String) -> String:
	return "%s|%s" % [p0, p1]


func _load() -> void:
	# Pass 1: faction-owned Icons
	var faction_data = _read_json(JSON_FACTIONS)
	if faction_data is Array:
		for f in faction_data:
			var fname = str(f.get("name", ""))
			if fname == "":
				continue
			for icon in f.get("icons", []):
				if not (icon is Dictionary):
					continue
				var name = str(icon.get("name", ""))
				var p0 = str(icon.get("pole_0", ""))
				var p1 = str(icon.get("pole_1", ""))
				if name == "" or p0 == "" or p1 == "":
					continue
				_register({
					"name": name,
					"pole_0": p0,
					"pole_1": p1,
					"owner_faction": fname,
					"biomes_present_in": [],
					"anonymous": false,
				})

	# Pass 2: biome placements (annotate biomes_present_in; create owner-less if not seen)
	var biome_data = _read_json(JSON_BIOMES)
	if biome_data is Array:
		for b in biome_data:
			var bname = str(b.get("name", ""))
			if bname == "":
				continue
			for icon in b.get("icons", []):
				if not (icon is Dictionary):
					continue
				var name = str(icon.get("name", ""))
				var p0 = str(icon.get("pole_0", ""))
				var p1 = str(icon.get("pole_1", ""))
				if name == "" or p0 == "" or p1 == "":
					continue
				var key = _pair_key(p0, p1)
				if not _by_pair.has(key):
					# Biome-placed Icon with no faction owner (orphan)
					_register({
						"name": name,
						"pole_0": p0,
						"pole_1": p1,
						"owner_faction": "",
						"biomes_present_in": [],
						"anonymous": false,
					})
				if not _by_biome.has(bname):
					_by_biome[bname] = []
				if not _by_biome[bname].has(key):
					_by_biome[bname].append(key)
				if not _by_pair[key]["biomes_present_in"].has(bname):
					_by_pair[key]["biomes_present_in"].append(bname)

	# Pass 3: 12 hidden axial Icons from FactionAxes — pure substrate, no biome
	# placement, no faction owner. Some axial pole emojis (⚡ 🌊 🎭 ⬜ 🌈 🍄 🎯 🌾)
	# also appear in faction sigs as ordinary atoms; that's fine — these axial
	# records are keyed by the (pole_0, pole_1) PAIR, distinct from any faction's
	# use of either glyph alone.
	_load_axial_icons()

	_world_built_count = _by_pair.size()


func _load_axial_icons() -> void:
	for i in range(FactionAxes.AXIS_COUNT):
		var axis: Dictionary = FactionAxes.get_axis(i)
		if axis.is_empty():
			continue
		var p0 := str(axis.get("pole_0", ""))
		var p1 := str(axis.get("pole_1", ""))
		if p0 == "" or p1 == "":
			continue
		var key := _pair_key(p0, p1)
		if _by_pair.has(key):
			# Already registered as a faction-owned or biome-placed Icon; mark axial.
			_by_pair[key]["axial"] = true
			_by_pair[key]["axis_index"] = i
			continue
		_register({
			"name": "Axis_%s" % str(axis.get("key", "axis_%d" % i)),
			"pole_0": p0,
			"pole_1": p1,
			"owner_faction": "",
			"biomes_present_in": [],
			"anonymous": false,
			"axial": true,
			"axis_index": i,
		})


func _read_json(path: String) -> Variant:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("IconLexicon: cannot open %s" % path)
		return null
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("IconLexicon: JSON parse error in %s: %s" % [path, json.get_error_message()])
		return null
	return json.data


func _register(record: Dictionary) -> void:
	var key = _pair_key(record["pole_0"], record["pole_1"])
	_by_pair[key] = record
	var name = record["name"]
	if not _by_name.has(name):
		_by_name[name] = []
	if not _by_name[name].has(key):
		_by_name[name].append(key)
	var owner = record.get("owner_faction", "")
	if owner != "":
		if not _by_faction.has(owner):
			_by_faction[owner] = []
		if not _by_faction[owner].has(key):
			_by_faction[owner].append(key)


## Look up an Icon by ordered pair. Returns {} if not registered.
func find_icon_by_pair(pole_0: String, pole_1: String) -> Dictionary:
	var key = _pair_key(pole_0, pole_1)
	if _by_pair.has(key):
		return _by_pair[key]
	# Also try reverse pair (pole-order is sometimes swapped between contexts)
	var rev = _pair_key(pole_1, pole_0)
	if _by_pair.has(rev):
		return _by_pair[rev]
	return {}


## Look up by name. Returns Array of records (a name may map to multiple pairs).
func get_icons_by_name(name: String) -> Array:
	var keys = _by_name.get(name, [])
	var out: Array = []
	for k in keys:
		out.append(_by_pair[k])
	return out


## Single record by name; returns first if multiple, {} if none.
func get_icon(name: String) -> Dictionary:
	var icons = get_icons_by_name(name)
	return icons[0] if not icons.is_empty() else {}


func get_icons_for_faction(faction_name: String) -> Array:
	var keys = _by_faction.get(faction_name, [])
	var out: Array = []
	for k in keys:
		out.append(_by_pair[k])
	return out


func get_icons_in_biome(biome_name: String) -> Array:
	var keys = _by_biome.get(biome_name, [])
	var out: Array = []
	for k in keys:
		out.append(_by_pair[k])
	return out


## Register a player-discovered pair with no faction owner.
## Returns the new record (or existing if already registered).
func register_anonymous(pole_0: String, pole_1: String) -> Dictionary:
	var existing = find_icon_by_pair(pole_0, pole_1)
	if not existing.is_empty():
		return existing
	var record = {
		"name": "Anon(%s/%s)" % [pole_0, pole_1],
		"pole_0": pole_0,
		"pole_1": pole_1,
		"owner_faction": "",
		"biomes_present_in": [],
		"anonymous": true,
	}
	_register(record)
	_anonymous_count += 1
	return record


## All world-built Icons (faction-owned or biome-placed at boot).
func get_all_world_built() -> Array:
	var out: Array = []
	for key in _by_pair:
		var r = _by_pair[key]
		if not r.get("anonymous", false):
			out.append(r)
	return out


## All runtime-discovered (anonymous) Icons.
func get_all_discovered() -> Array:
	var out: Array = []
	for key in _by_pair:
		var r = _by_pair[key]
		if r.get("anonymous", false):
			out.append(r)
	return out


## ============================================================================
## Player-discovery query API
## ============================================================================
##
## VocabularyEvolution.discovered_vocabulary is the source of truth for which
## pole-pairs the player has actually encountered. These helpers translate that
## list into pair-icon records so quests/UI can ask "does the player know the
## icon named 'Combat'?" or "which named axes have been unlocked so far?".
##
## The discovered list shape is Array[{north, south, ...}] as produced by
## VocabularyEvolution.get_discovered_vocabulary(). Order of poles is treated
## as unordered — a pair stored (a, b) matches a discovery (b, a).


## Convert a discovered-vocabulary array to a set of "p0|p1" keys, with both
## orderings included so lookups don't have to retry. Use as the input to
## `is_pair_discovered` / `filter_discovered_records`.
static func discovered_set_from_vocabulary(vocab: Array) -> Dictionary:
	var out: Dictionary = {}
	for entry in vocab:
		if not (entry is Dictionary):
			continue
		var n = str(entry.get("north", ""))
		var s = str(entry.get("south", ""))
		if n == "" or s == "":
			continue
		out[_pair_key(n, s)] = true
		out[_pair_key(s, n)] = true
	return out


## Returns true if the player has discovered the pair (in either order).
func is_pair_discovered(pole_0: String, pole_1: String, discovered: Dictionary) -> bool:
	if discovered.has(_pair_key(pole_0, pole_1)):
		return true
	return discovered.has(_pair_key(pole_1, pole_0))


## Pair-icon records the player has discovered (named axes only — anonymous
## entries are excluded since their lookup is already implicit).
func filter_discovered_records(discovered: Dictionary) -> Array:
	var out: Array = []
	for key in _by_pair:
		var r = _by_pair[key]
		if r.get("anonymous", false):
			continue
		if is_pair_discovered(r["pole_0"], r["pole_1"], discovered):
			out.append(r)
	return out


## Pair-icon records the player has NOT discovered yet — useful for UI that
## shows a censored "????" name until the pair is unlocked.
func filter_undiscovered_records(discovered: Dictionary) -> Array:
	var out: Array = []
	for key in _by_pair:
		var r = _by_pair[key]
		if r.get("anonymous", false):
			continue
		if not is_pair_discovered(r["pole_0"], r["pole_1"], discovered):
			out.append(r)
	return out


func get_all() -> Array:
	var out: Array = []
	for key in _by_pair:
		out.append(_by_pair[key])
	return out


func size() -> int:
	return _by_pair.size()


func summary() -> String:
	var owned = 0
	var orphans = 0
	var axial = 0
	for key in _by_pair:
		var r = _by_pair[key]
		if r.get("anonymous", false):
			continue
		if r.get("axial", false):
			axial += 1
			continue
		if r.get("owner_faction", "") != "":
			owned += 1
		else:
			orphans += 1
	return "IconLexicon: %d total (%d faction-owned + %d biome-orphan + %d axial + %d anonymous)" % [
		_by_pair.size(), owned, orphans, axial, _anonymous_count
	]
