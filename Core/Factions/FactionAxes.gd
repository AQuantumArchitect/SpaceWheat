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
	var file = FileAccess.open(JSON_PATH, FileAccess.READ)
	if not file:
		push_error("FactionAxes: cannot open %s" % JSON_PATH)
		return []
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("FactionAxes: JSON parse error: %s" % json.get_error_message())
		return []
	var data = json.data
	if not (data is Array):
		push_error("FactionAxes: expected Array at root of %s" % JSON_PATH)
		return []
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
