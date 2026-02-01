class_name EmojiRegistry
extends RefCounted

## EmojiRegistry: Unified emoji collection from all sources
##
## Replaces duplicated emoji collection logic (~130 lines) in
## BootManager and TestBootManager.
##
## Provides single source of truth for emoji atlas building by
## collecting emojis from:
## - BiomeRegistry: All biomes in biomes_merged.json
## - FactionRegistry: All factions in factions_merged.json
##
## Usage:
##   var registry = EmojiRegistry.new()
##   var all_emojis = registry.get_all_emojis()
##   var biome_emojis = registry.get_biome_emojis()
##   var faction_emojis = registry.get_faction_emojis()

const BiomeRegistry = preload("res://Core/Biomes/BiomeRegistry.gd")
const FactionRegistry = preload("res://Core/Factions/FactionRegistry.gd")

# Emoji storage
var _biome_emojis: Dictionary = {}   # emoji -> true (from biomes)
var _faction_emojis: Dictionary = {}  # emoji -> true (from factions)
var _all_emojis: Dictionary = {}      # emoji -> true (union of both)

var _loaded: bool = false


## ========================================
## Initialization
## ========================================

func _init():
	load_emojis()


## Load all emojis from BiomeRegistry and FactionRegistry
func load_emojis() -> bool:
	_biome_emojis.clear()
	_faction_emojis.clear()
	_all_emojis.clear()

	# Load from BiomeRegistry
	var biome_registry = BiomeRegistry.new()
	var biome_emoji_list = biome_registry.get_all_emojis()
	for emoji in biome_emoji_list:
		_biome_emojis[emoji] = true
		_all_emojis[emoji] = true

	# Load from FactionRegistry
	var faction_registry = FactionRegistry.new()
	var all_factions = faction_registry.get_all()

	for faction in all_factions:
		# Get emojis from signature (primary emojis this faction speaks)
		for emoji in faction.signature:
			_faction_emojis[emoji] = true
			_all_emojis[emoji] = true

		# Get emojis from self_energies
		for emoji in faction.self_energies.keys():
			_faction_emojis[emoji] = true
			_all_emojis[emoji] = true

		# Get emojis from hamiltonian (source and target emojis)
		for source_emoji in faction.hamiltonian.keys():
			_faction_emojis[source_emoji] = true
			_all_emojis[source_emoji] = true
			for target_emoji in faction.hamiltonian[source_emoji].keys():
				_faction_emojis[target_emoji] = true
				_all_emojis[target_emoji] = true

		# Get emojis from alignment couplings (emoji and observable emojis)
		for emoji in faction.alignment_couplings.keys():
			_faction_emojis[emoji] = true
			_all_emojis[emoji] = true
			for observable_emoji in faction.alignment_couplings[emoji].keys():
				_faction_emojis[observable_emoji] = true
				_all_emojis[observable_emoji] = true

		# Get emojis from lindblad_outgoing (source and target emojis)
		for source_emoji in faction.lindblad_outgoing.keys():
			_faction_emojis[source_emoji] = true
			_all_emojis[source_emoji] = true
			for target_emoji in faction.lindblad_outgoing[source_emoji].keys():
				_faction_emojis[target_emoji] = true
				_all_emojis[target_emoji] = true

		# Get emojis from lindblad_incoming (target and source emojis)
		for target_emoji in faction.lindblad_incoming.keys():
			_faction_emojis[target_emoji] = true
			_all_emojis[target_emoji] = true
			for source_emoji in faction.lindblad_incoming[target_emoji].keys():
				_faction_emojis[source_emoji] = true
				_all_emojis[source_emoji] = true

		# Get emojis from gated_lindblad (target, source, and gate emojis)
		for target_emoji in faction.gated_lindblad.keys():
			_faction_emojis[target_emoji] = true
			_all_emojis[target_emoji] = true
			for gate_def in faction.gated_lindblad[target_emoji]:
				if "source" in gate_def:
					_faction_emojis[gate_def["source"]] = true
					_all_emojis[gate_def["source"]] = true
				if "gate" in gate_def:
					_faction_emojis[gate_def["gate"]] = true
					_all_emojis[gate_def["gate"]] = true

		# Get emojis from decay (emoji and decay target)
		for emoji in faction.decay.keys():
			_faction_emojis[emoji] = true
			_all_emojis[emoji] = true
			var decay_info = faction.decay[emoji]
			if decay_info is Dictionary and "target" in decay_info:
				var target = decay_info["target"]
				if target != "":
					_faction_emojis[target] = true
					_all_emojis[target] = true

	_loaded = true
	return true


## ========================================
## Query API
## ========================================

## Get all unique emojis from all sources
func get_all_emojis() -> Array:
	return _all_emojis.keys()


## Get emojis from biomes only
func get_biome_emojis() -> Array:
	return _biome_emojis.keys()


## Get emojis from factions only
func get_faction_emojis() -> Array:
	return _faction_emojis.keys()


## Get total emoji count
func get_emoji_count() -> int:
	return _all_emojis.size()


## Check if an emoji is registered
func has_emoji(emoji: String) -> bool:
	return _all_emojis.has(emoji)


## ========================================
## Debug Utilities
## ========================================

## Print summary of emoji sources
func debug_print_summary() -> void:
	print("\n========== EMOJI REGISTRY ==========")
	print("Total unique emojis: %d" % _all_emojis.size())
	print("From biomes: %d" % _biome_emojis.size())
	print("From factions: %d" % _faction_emojis.size())
	print("====================================\n")
