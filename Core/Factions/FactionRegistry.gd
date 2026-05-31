class_name FactionRegistry
extends RefCounted

## FactionRegistry: Data-driven faction management
##
## JSON-backed faction loading with indexed lookups.
## Provides O(1) lookup by emoji, name, and tag via pre-built indexes.
##
## Usage (preferred — shared cache):
##   var registry = FactionRegistry.get_shared()
##   var factions = registry.get_all()
##   var verdant = registry.get_by_name("Verdant Pulse")
##
## Tests/tools may still `FactionRegistry.new()` for isolation. Production code
## should use `get_shared()` so a single JSON parse serves the whole session.

const JSON_PATH = "res://Core/Factions/data/factions.json"

# Process-wide shared instance. Engine code should access via `get_shared()`.
static var _shared = null


## Return the process-wide shared registry, building it on first access.
## Use this from engine/UI code so factions.json is parsed once per session.
static func get_shared() -> FactionRegistry:
	if _shared == null:
		_shared = load("res://Core/Factions/FactionRegistry.gd").new()
	return _shared


## Drop the shared instance (forces a fresh load on next `get_shared()`).
## For tests and save-slot transitions where factions.json has changed on disk.
static func reset_shared() -> void:
	_shared = null

# Faction storage
var _factions: Array = []

# Pre-built indexes for O(1) lookup
var _emoji_index: Dictionary = {}   # emoji -> [Faction]
var _name_index: Dictionary = {}    # name -> Faction
var _tag_index: Dictionary = {}     # tag -> [Faction]
var _ring_index: Dictionary = {}    # ring -> [Faction]

var _loaded: bool = false


## ========================================
## Initialization
## ========================================

func _init():
	load_factions()


## Load all factions from JSON
func load_factions() -> bool:
	_factions.clear()
	_emoji_index.clear()
	_name_index.clear()
	_tag_index.clear()
	_ring_index.clear()

	var file = FileAccess.open(JSON_PATH, FileAccess.READ)
	if not file:
		push_error("FactionRegistry: Could not open %s" % JSON_PATH)
		return false

	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()

	if err != OK:
		push_error("FactionRegistry: JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return false

	var data = json.data
	if not data is Array:
		push_error("FactionRegistry: Expected array at root of JSON")
		return false

	# Load each faction
	for faction_data in data:
		var faction = Faction.from_dict(faction_data)
		_factions.append(faction)

	_build_indexes()
	_loaded = true

	return true


## Build lookup indexes for O(1) access
func _build_indexes() -> void:
	for faction in _factions:
		# Name index
		_name_index[faction.name] = faction

		# Ring index
		if not _ring_index.has(faction.ring):
			_ring_index[faction.ring] = []
		_ring_index[faction.ring].append(faction)

		# Emoji index
		for emoji in faction.cloud:
			if not _emoji_index.has(emoji):
				_emoji_index[emoji] = []
			_emoji_index[emoji].append(faction)

		# Tag index
		for tag in faction.tags:
			if not _tag_index.has(tag):
				_tag_index[tag] = []
			_tag_index[tag].append(faction)


## ========================================
## Query API
## ========================================

## Get all factions
func get_all() -> Array:
	return _factions


## Get faction by exact name
func get_by_name(faction_name: String) -> Faction:
	return _name_index.get(faction_name, null)


## Find all factions that speak a given emoji (O(1) lookup)
func get_factions_for_emoji(emoji: String) -> Array:
	return _emoji_index.get(emoji, [])


## Get all unique emojis across all factions
func get_all_emojis() -> Array:
	return _emoji_index.keys()


## Get emoji contestation map (which factions share each emoji)
func get_emoji_contestation() -> Dictionary:
	var result: Dictionary = {}
	for emoji in _emoji_index:
		result[emoji] = []
		for faction in _emoji_index[emoji]:
			result[emoji].append(faction.name)
	return result


## ========================================
## Debug Utilities
## ========================================

## Print summary of all factions
func debug_print_all() -> void:
	print("\n========== FACTION REGISTRY ==========")
	print("Loaded: %d factions" % _factions.size())
	print("Unique emojis: %d" % _emoji_index.size())

	print("\nBy ring:")
	for ring in _ring_index:
		print("  %s: %d factions" % [ring, _ring_index[ring].size()])

	print("\nMost contested emojis:")
	var contestation = get_emoji_contestation()
	var sorted_emojis = contestation.keys()
	sorted_emojis.sort_custom(func(a, b): return contestation[a].size() > contestation[b].size())

	for i in range(min(10, sorted_emojis.size())):
		var emoji = sorted_emojis[i]
		print("  %s: %d factions" % [emoji, contestation[emoji].size()])

	print("=======================================\n")


## Validate all factions
func validate_all() -> bool:
	var all_valid = true
	for faction in _factions:
		if not faction.validate():
			all_valid = false
	return all_valid
