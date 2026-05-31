class_name FactionDatabase
extends RefCounted

## Faction Database — static utility API over FactionRegistry.
##
## Data lives in Core/Factions/data/factions.json (single source of truth).
## This class provides the dict-shaped API the quest system depends on plus
## vocabulary helpers that operate on those dicts.


static var _cache: Array = []


## Return all factions as dicts compatible with the quest-system API.
## Cached after first load — call invalidate_cache() if registry reloads.
static func get_all() -> Array:
	if not _cache.is_empty():
		return _cache
	var reg := FactionRegistry.get_shared()
	for faction in reg.get_all():
		_cache.append({
			"name":        faction.name,
			"description": faction.description,
			"domain":      faction.domain,
			"ring":        faction.ring,
			"motto":       faction.motto,
			"sig":         Array(faction.cloud),
			"bits":        Array(faction.bits),
		})
	return _cache


static func invalidate_cache() -> void:
	_cache.clear()


## ── Lookup helpers ──────────────────────────────────────────────────────────

static func get_faction_by_name(faction_name: String) -> Dictionary:
	for faction in get_all():
		if faction.name == faction_name:
			return faction
	return {}

static func get_factions_by_ring(ring: String) -> Array:
	var result := []
	for faction in get_all():
		if faction.ring == ring:
			result.append(faction)
	return result

static func get_factions_by_domain(domain: String) -> Array:
	var result := []
	for faction in get_all():
		if faction.domain == domain:
			result.append(faction)
	return result


## ── Vocabulary helpers ───────────────────────────────────────────────────────

static func get_faction_emoji(faction: Dictionary) -> String:
	var sig = faction.get("sig", [])
	return sig[0] if sig.size() > 0 else "❓"

static func get_faction_signature_string(faction: Dictionary) -> String:
	return "".join(faction.get("sig", []))

static func _get_axial_emojis(bits: Array) -> Array:
	var result: Array = []
	for i in range(min(bits.size(), FactionAxes.AXES.size())):
		var axis = FactionAxes.AXES[i]
		var emoji = axis.get("1" if bits[i] == 1 else "0", "")
		if emoji != "":
			result.append(emoji)
	return result

static func get_faction_vocabulary(faction: Dictionary) -> Dictionary:
	var signature: Array = faction.get("sig", faction.get("signature", []))
	var axial: Array = _get_axial_emojis(faction.get("bits", []))
	var all := signature.duplicate()
	for emoji in axial:
		if emoji not in all:
			all.append(emoji)
	return {"signature": signature, "axial": axial, "all": all}

static func get_vocabulary_overlap(icon_a: Array, icon_b: Array) -> Array:
	var result: Array = []
	for emoji in icon_a:
		if emoji in icon_b and emoji not in result:
			result.append(emoji)
	return result

static func get_faction_banner_path(faction: Dictionary) -> String:
	var faction_name: String = faction.get("name", "")
	if faction_name.is_empty():
		return ""
	var path := "res://Assets/UI/Factions/Banners/%s.svg" % faction_name
	return path if ResourceLoader.exists(path) else ""
