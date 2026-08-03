extends "res://tests/smoke_test_base.gd"

## faction_icon_adoption_smoke.gd
##
## Verifies the Verdant Pulse / Mycelial Web icon adoption pass:
##   - faction signatures stay duplicate-free
##   - the absorbed orphan pairs are now owned by the intended factions
##   - IconRegistry resolves those pairs with the new owners

const FactionRegistryCls = preload("res://Core/Factions/FactionRegistry.gd")
const IconRegistryCls = preload("res://Core/Factions/IconRegistry.gd")


func _init() -> void:
	print("\n=== Faction icon adoption smoke ===")
	var freg = FactionRegistryCls.new()
	var lex = IconRegistryCls.new()

	_check(_signatures_are_unique(freg), "all faction signatures are duplicate-free")
	_check(_adopted_icon_owner(lex, "🌱", "🌲", "Verdant Pulse"), "Succession adopted by Verdant Pulse")
	_check(_adopted_icon_owner(lex, "🍂", "🌿", "Verdant Pulse"), "Humus adopted by Verdant Pulse")
	_check(_adopted_icon_owner(lex, "🍄", "💀", "Mycelial Web"), "Mycelium adopted by Mycelial Web")
	_check(_faction_has_icons(lex, "Verdant Pulse", 5), "Verdant Pulse owns 5 icon pairs after adoption")
	_check(_faction_has_icons(lex, "Mycelial Web", 4), "Mycelial Web owns 4 icon pairs after adoption")

	_finish()


func _signatures_are_unique(reg) -> bool:
	var ok := true
	for faction in reg.get_all():
		var seen: Dictionary = {}
		for emoji in faction.cloud:
			var key := str(emoji)
			if key == "" or seen.has(key):
				push_error("duplicate signature emoji in %s: %s" % [faction.name, key])
				ok = false
				break
			seen[key] = true
	return ok


func _adopted_icon_owner(lex, p0: String, p1: String, expected_owner: String) -> bool:
	var factions = lex.get_factions_for_pair(p0, p1)
	if factions.is_empty():
		push_error("icon pair %s|%s has no faction owner" % [p0, p1])
		return false
	return expected_owner in factions


func _faction_has_icons(lex, faction_name: String, expected_min: int) -> bool:
	var icons: Array = lex.get_icons_for_faction(faction_name)
	return icons.size() >= expected_min
