class_name SubstrateFixtures
extends RefCounted

## Shared test fixtures for mythos-substrate tests.
## Minimal Farm-shaped stand-in with the surface FactionAffinity / rep-channel
## tests need. Use in place of instantiating the real Farm node.
##
## Usage:
##   const SubstrateFixtures = preload("res://tests/substrate_fixtures.gd")
##   var farm = SubstrateFixtures.TestFarm.new()
class TestEconomy:
	var _resources: Dictionary = {
		"🌾": 20.0, "🍞": 15.0, "💧": 30.0,
		"🪵": 12.0, "🌿": 8.0, "🍄": 6.0,
	}

	func get_all_resources() -> Dictionary:
		return _resources.duplicate()

	func get_resource(emoji: String) -> float:
		return float(_resources.get(emoji, 0.0))


class TestBiome:
	## Biome-like stub exposing the surface faction/biome read paths. Pass real
	## faction names from the live FactionRegistry so the market actually has
	## axial position and demand.
	var biome_name: String = "TestBiome"
	var _biome_data: Dictionary = {
		"native_factions": [],
		"admitted_factions": [],
		"emojis": [],
	}

	static func with_admitted(name_: String, admitted_factions: Array) -> TestBiome:
		var b = TestBiome.new()
		b.name = name_
		b._biome_data = {
			"native_factions": admitted_factions,
			"admitted_factions": admitted_factions,
			"emojis": [],
		}
		return b


class TestFarm:
	var faction_density
	var faction_standings: Dictionary = {}
	var icon_atlas
	var economy

	func _init():
		var FDM = load("res://Core/Factions/FactionDensityMatrix.gd")
		faction_density = FDM.new(null)
		var IL = load("res://Core/Factions/IconRegistry.gd")
		icon_atlas = IL.new()
		economy = TestEconomy.new()

	func _ensure_icon_atlas():
		return icon_atlas

	func get_or_create_standing(name: String):
		var FS = load("res://Core/Factions/FactionStanding.gd")
		if name == "":
			return FS.new()
		if not faction_standings.has(name):
			faction_standings[name] = FS.new()
		return faction_standings[name]

	func apply_standing_deltas(faction_name: String, deltas: Dictionary) -> void:
		if faction_name == "" or deltas == null or deltas.is_empty():
			return
		var s = get_or_create_standing(faction_name)
		for key in deltas:
			var v: float = float(deltas[key])
			match key:
				"trust": s.trust += v
				"debt": s.debt += v
				"attention": s.attention += v
				"access": s.access += v
				"legitimacy": s.legitimacy += v
				"entanglement": s.entanglement += v
