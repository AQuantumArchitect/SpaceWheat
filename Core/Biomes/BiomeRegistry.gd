class_name BiomeRegistry
extends RefCounted

## BiomeRegistry: Data-driven biome management
##
## Mirrors FactionRegistry but for biomes.
## Provides O(1) lookup by name, emoji, and tag via pre-built indexes.
##
## Usage (preferred — shared cache):
##   var biomes = BiomeRegistry.get_shared().get_all()
##   var forest = BiomeRegistry.get_shared().get_by_name("StarterForest")
##
## Tests/tools may still `BiomeRegistry.new()` for isolation. Production code
## should use `get_shared()` so canonical mutations propagate engine-wide.

const JSON_PATH = "res://Core/Biomes/data/biomes.json"

## Semantica explorer (W3b): compiled *.biome.json files under this dir, loaded
## ADDITIVELY on top of canon when RuntimeEnv.semantica_explorer() is true. Never
## touches biomes.json (crafted-artifact law) — see 🍄/🧪/semantica_compiler.py.
const SEMANTICA_DIR = "res://Core/Config/semantica"

# Process-wide shared instance. Engine code should access via `get_shared()`.
static var _shared = null

## Return the process-wide shared registry, building it on first access.
## Use this from engine/UI code so canonical mutations are visible everywhere.
static func get_shared() -> BiomeRegistry:
	if _shared == null:
		_shared = load("res://Core/Biomes/BiomeRegistry.gd").new()
	return _shared

## Drop the shared instance (forces a fresh load on next `get_shared()`).
## For tests and save-slot transitions where biomes.json has changed on disk.
static func reset_shared() -> void:
	_shared = null

# Biome storage
var _biomes: Array = []

# Pre-built indexes for O(1) lookup
var _name_index: Dictionary = {}    # name -> Biome
var _emoji_index: Dictionary = {}   # emoji -> [Biome]
var _tag_index: Dictionary = {}     # tag -> [Biome]

var _loaded: bool = false


## ========================================
## Initialization
## ========================================

func _init():
	load_biomes()


## Load all biomes from JSON
func load_biomes() -> bool:
	_biomes.clear()
	_name_index.clear()
	_emoji_index.clear()
	_tag_index.clear()
	_factions_for_biome_cache.clear()

	if not _load_biomes_from(JSON_PATH, true):
		return false

	# Semantica explorer: additive pass, OFF by default (boot-neutral). A player
	# never sets SEMANTICA_EXPLORER, so this branch is dead weight for them.
	if RuntimeEnv.semantica_explorer():
		_load_semantica_biomes()

	_build_indexes()
	_loaded = true

	return true


## Load every compiled *.biome.json under Core/Config/semantica/ (additive,
## non-canonical). Each file holds a one-element array in the same shape as a
## biomes.json record (see semantica_compiler.py). Missing dir is not an error
## (nothing compiled yet) — this is opt-in exploration data, not a required asset.
func _load_semantica_biomes() -> void:
	var dir := DirAccess.open(SEMANTICA_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".biome.json"):
			_load_biomes_from(SEMANTICA_DIR.path_join(fname), false)
		fname = dir.get_next()
	dir.list_dir_end()


## Load biomes from a single JSON file. If `required` is false, missing file
## is treated as empty.
func _load_biomes_from(path: String, required: bool) -> bool:
	# One JSON-load authority (slop knot #7); a missing optional file is
	# treated as empty (success), exactly as before.
	var res: Dictionary = preload("res://Core/Config/JsonFileLoader.gd").load_json(
		path, {"context": "BiomeRegistry", "required": required, "root": "array"})
	if res.missing and not required:
		return true
	if not res.ok:
		return false
	for biome_data in res.data:
		var biome = Biome.from_dict(biome_data)
		_biomes.append(biome)
	return true


## Build lookup indexes for O(1) access
func _build_indexes() -> void:
	for biome in _biomes:
		# Name index
		_name_index[biome.name] = biome

		# Emoji index (skip plain-ASCII strings like "everything")
		for emoji in biome.emojis:
			if emoji.is_empty() or emoji.is_valid_identifier():
				continue  # Not a real emoji
			if not _emoji_index.has(emoji):
				_emoji_index[emoji] = []
			_emoji_index[emoji].append(biome)

		# Tag index
		for tag in biome.tags:
			var norm_tag := _normalize_tag(tag)
			if norm_tag == "":
				continue
			if not _tag_index.has(norm_tag):
				_tag_index[norm_tag] = []
			_tag_index[norm_tag].append(biome)


## ========================================
## Query API
## ========================================

## Get all biomes
func get_all() -> Array:
	return _biomes


## Mutate canonical biome by adding an icon pair (atoms-as-canonical path).
## Updates the live `Biome` instance and the `_emoji_index` so subsequent
## queries reflect the new basis. The biome's primed Lindblad terms with
## endpoints in the new pair will activate on next substrate rebuild.
##
## Returns true on success. Caller is responsible for triggering the substrate
## rebuild (typically via BiomeBase.add_atom_pair → expand_quantum_system).
func add_atom_pair_to_biome(biome_name: String, north: String, south: String, icon_name: String = "") -> bool:
	var biome = _name_index.get(biome_name, null)
	if biome == null:
		return false
	var ok: bool = biome.add_atom_pair(north, south, icon_name)
	if not ok:
		return false
	_factions_for_biome_cache.erase(biome_name)
	# Update emoji index for the two new atoms.
	for emoji in [north, south]:
		if emoji.is_empty() or emoji.is_valid_identifier():
			continue
		if not _emoji_index.has(emoji):
			_emoji_index[emoji] = []
		if not _emoji_index[emoji].has(biome):
			_emoji_index[emoji].append(biome)
	return true


## Get biomes intended for player-facing runtime/export use.
## Internal helper records (for example "_orphan_lindblads") are excluded.
func get_exportable_biomes() -> Array:
	var exportable: Array = []
	for biome in _biomes:
		if biome == null:
			continue
		if biome.name.begins_with("_"):
			continue
		exportable.append(biome)
	return exportable


## Get biome by exact name
func get_by_name(biome_name: String) -> Biome:
	return _name_index.get(biome_name, null)


## Get faction names that have presence in a biome (signature ∩ atoms).
## Replaces the deleted faction roster field — computed from physics.
## Lazy cache; invalidate via reset_shared() on registry rebuild.
const _FactionBiomeMap = preload("res://Core/Biomes/FactionBiomeMap.gd")
var _factions_for_biome_cache: Dictionary = {}

func get_factions_for_biome(biome_name: String) -> Array:
	# Faction signature gate. IconRegistry owns the authority via FactionBiomeMap.
	var biome = _name_index.get(biome_name, null)
	if biome == null:
		return []
	if _factions_for_biome_cache.has(biome_name):
		return _factions_for_biome_cache[biome_name]
	var result: Array = _FactionBiomeMap.factions_for_biome_by_signature(biome)
	_factions_for_biome_cache[biome_name] = result
	return result


## Find all biomes that contain a given emoji
func get_biomes_for_emoji(emoji: String) -> Array:
	return _emoji_index.get(emoji, [])


## Get all biomes with a given tag
func get_biomes_by_tag(tag: String) -> Array:
	return _tag_index.get(_normalize_tag(tag), [])


## Get all unique emojis across all biomes
func get_all_emojis() -> Array:
	return _emoji_index.keys()


## Get emoji distribution map (which biomes contain each emoji)
func get_emoji_distribution() -> Dictionary:
	var result: Dictionary = {}
	for emoji in _emoji_index:
		result[emoji] = []
		for biome in _emoji_index[emoji]:
			result[emoji].append(biome.name)
	return result


## ========================================
## Debug Utilities
## ========================================

static func _normalize_tag(tag) -> String:
	return str(tag)

## Print summary of all biomes
func debug_print_all() -> void:
	print("\n========== BIOME REGISTRY ==========")
	print("Loaded: %d biomes" % _biomes.size())
	print("Unique emojis: %d" % _emoji_index.size())

	print("\nBiomes:")
	for biome in _biomes:
		var discovered = "✓" if biome.discovered else "✗"
		print("  %s %s: %d emojis" % [discovered, biome.name, biome.emojis.size()])

	print("\nEmoji distribution:")
	var distribution = get_emoji_distribution()
	var sorted_emojis = distribution.keys()
	sorted_emojis.sort_custom(func(a, b): return distribution[a].size() > distribution[b].size())

	for i in range(min(10, sorted_emojis.size())):
		var emoji = sorted_emojis[i]
		print("  %s: %d biomes" % [emoji, distribution[emoji].size()])

	print("==================================\n")


## Validate all biomes
func validate_all() -> bool:
	var all_valid = true
	for biome in _biomes:
		if not biome.validate():
			all_valid = false
	return all_valid


## Validate only the exportable/player-facing biome set.
func validate_exportable() -> bool:
	var all_valid = true
	for biome in get_exportable_biomes():
		if not biome.validate():
			all_valid = false
	return all_valid
