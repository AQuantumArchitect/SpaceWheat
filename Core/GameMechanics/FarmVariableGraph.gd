class_name FarmVariableGraph
extends RefCounted

## FarmVariableGraph - JSONL graph format for economy/balance variables.
##
## Each JSONL row is a node update:
##   {"op":"set","path":"action_costs.explore.🍞","value":8}
##
## This keeps tuning data externalizable and mutation-friendly while preserving
## the existing runtime patch path.

const DEFAULT_GRAPH_PATH := "res://Core/Config/FarmVariableGraph/default.jsonl"
const SUPPORTED_ROOTS: Array[String] = [
	"profile_id",
	"action_costs",
	"gate_costs",
	"quest_rewards",
	"tuning",
	"economy_variables",
]


static func load_graph_lines(path: String = DEFAULT_GRAPH_PATH) -> Array[String]:
	if path == "":
		return []
	if not FileAccess.file_exists(path):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return []
	var lines: Array[String] = []
	while not file.eof_reached():
		lines.append(file.get_line())
	return lines


static func parse_graph_lines(lines: Array) -> Dictionary:
	var patch: Dictionary = {}
	var errors: Array[String] = []

	for i in range(lines.size()):
		var raw := str(lines[i]).strip_edges()
		if raw == "" or raw.begins_with("#"):
			continue
		var row = JSON.parse_string(raw)
		if not (row is Dictionary):
			errors.append("line %d: invalid_json" % [i + 1])
			continue
		if str(row.get("op", "set")) != "set":
			errors.append("line %d: unsupported_op" % [i + 1])
			continue
		var path := str(row.get("path", ""))
		if path == "":
			errors.append("line %d: missing_path" % [i + 1])
			continue
		var value = row.get("value", null)
		if not _set_path(patch, path, value):
			errors.append("line %d: invalid_path '%s'" % [i + 1, path])

	return {
		"ok": errors.is_empty(),
		"patch": patch,
		"errors": errors,
	}


static func snapshot_to_graph_lines(snapshot: Dictionary) -> Array[String]:
	var payload: Dictionary = {}
	for root in SUPPORTED_ROOTS:
		if snapshot.has(root):
			payload[root] = snapshot[root]
	return flatten_patch_to_lines(payload)


static func flatten_patch_to_lines(patch: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	for root in SUPPORTED_ROOTS:
		if not patch.has(root):
			continue
		_flatten_value(lines, root, patch[root])
	return lines


static func _flatten_value(lines: Array[String], path: String, value) -> void:
	if value is Dictionary and not value.is_empty():
		var keys = value.keys()
		keys.sort()
		for key in keys:
			_flatten_value(lines, "%s.%s" % [path, str(key)], value[key])
		return
	var row = {
		"op": "set",
		"path": path,
		"value": value,
	}
	lines.append(JSON.stringify(row))


static func _set_path(out: Dictionary, path: String, value) -> bool:
	var parts = path.split(".", false)
	if parts.is_empty():
		return false
	var root = str(parts[0])
	if root not in SUPPORTED_ROOTS:
		return false

	if parts.size() == 1:
		out[root] = value
		return true

	var cursor = out
	for idx in range(parts.size() - 1):
		var part = str(parts[idx])
		if not cursor.has(part) or not (cursor[part] is Dictionary):
			cursor[part] = {}
		cursor = cursor[part]
	cursor[str(parts[parts.size() - 1])] = value
	return true
