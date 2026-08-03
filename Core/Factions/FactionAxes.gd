class_name FactionAxes
extends RefCounted

## FactionAxes — canonical table of the 12 axial-spine dimensions.
##
## Loads from data/axes.json so GDScript and Python tooling
## (tools/validate_faction_bits.py) read the same source.
##
## Order is load-bearing: index i here MUST match Faction.bits[i].
## Bit convention: value 0 = left-pole (pole_0), value 1 = right-pole (pole_1).

const AXIS_COUNT: int = 12
const JSON_PATH := "res://Core/Factions/data/axes.json"

static var AXES: Array = _load_axes()


static func _load_axes() -> Array:
	# One JSON-load authority (slop knot #7).
	var res: Dictionary = preload("res://Core/Config/JsonFileLoader.gd").load_json(
		JSON_PATH, {"context": "FactionAxes", "root": "array"})
	if not res.ok:
		return []
	var data = res.data
	if data.size() != AXIS_COUNT:
		push_warning("FactionAxes: expected %d axes, got %d" % [AXIS_COUNT, data.size()])
	return data


static func get_axis(index: int) -> Dictionary:
	if index < 0 or index >= AXES.size():
		return {}
	return AXES[index]


static func axis_name(index: int) -> String:
	return str(get_axis(index).get("name", ""))


static func axis_key(index: int) -> String:
	return str(get_axis(index).get("key", ""))


static func pole_emoji(index: int, bit: int) -> String:
	var axis = get_axis(index)
	if axis.is_empty():
		return ""
	return str(axis.get("pole_0" if bit == 0 else "pole_1", ""))


static func pole_label(index: int, bit: int) -> String:
	var axis = get_axis(index)
	if axis.is_empty():
		return ""
	return str(axis.get("label_0" if bit == 0 else "label_1", ""))


static func axis_description(index: int) -> String:
	return str(get_axis(index).get("description", ""))


## The undecided 12-vector: 0.5 on every axis. One home for the neutral
## projection/bits fallback the overlays previously each rebuilt.
static func uniform_marginals() -> Array:
	var out: Array = []
	for _i in range(AXIS_COUNT):
		out.append(0.5)
	return out
