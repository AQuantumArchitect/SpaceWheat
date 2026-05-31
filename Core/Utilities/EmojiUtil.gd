class_name EmojiUtil
extends RefCounted

## EmojiUtil — canonical emoji string normalization
##
## Unicode variation selectors (U+FE0E, U+FE0F) make visually identical
## emoji different strings. This silently breaks dictionary key lookups:
##   "⚙" (U+2699)        ≠  "⚙️" (U+2699 + U+FE0F)
##   "❄" (U+2744)        ≠  "❄️" (U+2744 + U+FE0F)
##   "☀" (U+2600)        ≠  "☀️" (U+2600 + U+FE0F)
##
## All emoji strings entering the system from JSON must be normalized.
## Call normalize() at data load time in Faction.load_from_dict() and
## Biome.load_from_dict() so all downstream code can assume clean strings.

## Strip variation selectors from a single emoji string.
static func normalize(s: String) -> String:
	return s.replace("\uFE0F", "").replace("\uFE0E", "")


## Normalize each string in an array (e.g. signature, emojis).
static func normalize_array(arr: Array) -> Array:
	var result: Array = []
	for item in arr:
		result.append(normalize(str(item)))
	return result


## Normalize all keys of a flat {emoji: value} dict.
static func normalize_keys(d: Dictionary) -> Dictionary:
	if d.is_empty():
		return d
	var result: Dictionary = {}
	for key in d:
		result[normalize(str(key))] = d[key]
	return result


## Normalize keys at both levels of a nested {emoji: {emoji: value}} dict.
static func normalize_nested_keys(d: Dictionary) -> Dictionary:
	if d.is_empty():
		return d
	var result: Dictionary = {}
	for outer_key in d:
		var nkey: String = normalize(str(outer_key))
		var inner = d[outer_key]
		if inner is Dictionary:
			result[nkey] = normalize_keys(inner)
		else:
			result[nkey] = inner
	return result


## Normalize decay: {emoji_key: {rate, target}}.
## Outer keys and "target" values are emojis.
static func normalize_decay(d: Dictionary) -> Dictionary:
	if d.is_empty():
		return d
	var result: Dictionary = {}
	for outer_key in d:
		var nkey: String = normalize(str(outer_key))
		var entry = d[outer_key]
		if entry is Dictionary and "target" in entry:
			var ne: Dictionary = entry.duplicate()
			ne["target"] = normalize(str(ne["target"]))
			result[nkey] = ne
		else:
			result[nkey] = entry
	return result
