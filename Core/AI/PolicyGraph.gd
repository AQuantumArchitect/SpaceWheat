class_name PolicyGraph
extends RefCounted

## PolicyGraph - JSONL graph format for policy topology and dynamics.
##
## Mirrors FarmVariableGraph so policy tuning/mutation can use the same
## externalized graph workflow as economy tuning.

const DEFAULT_GRAPH_PATH := "res://Core/Config/PolicyGraph/default.jsonl"
const SUPPORTED_ROOTS: Array[String] = [
	"profile_id",
	"action_priors",
	"action_params",
	"action_limits",
	"reward_terms",
	"dynamics",
]


static func default_graph(policy_kind: String = "ucb", profile_id: String = "default") -> Dictionary:
	var graph := {
		"profile_id": profile_id,
		"action_priors": {
			"quest_cycle": {
				"base": 0.7,
				"active_quest": 0.3,
				"affordable": 0.25,
				"unknown_vocab": 1.25,
				"bonus": 0.0,
				"stagnation_scale": 0.45,
				"stagnation_cap": 6.0,
			},
			"probe_cycle": {
				"base": 1.0,
				"resource_pressure": 0.8,
				"biome_pressure": 0.25,
				"deficit_flux": 4.0,
				"surplus_flux": 0.5,
			},
			"lindblad_drain": {
				"base": 0.9,
				"inactive_bonus": 1.0,
				"active_scale": 0.0,
				"deficit_flux": 5.0,
				"surplus_flux": 1.0,
			},
			"discover_biome": {
				"base": 0.7,
				"min_eagles": 8.0,
				"max_biomes": 6.0,
				"eagle_divisor": 16.0,
				"eagle_cap": 2.0,
				"forecast_scale": 1.0,
			},
			"lock_offer": {
				"base": 0.5,
				"discovery_affinity": 6.0,
				"novelty": 1.5,
			},
			"time_skip": {
				"base": 0.4,
				"active_drain_scale": 0.35,
			},
			"victory_lap_partial": {
				"base": 8.5,
			},
			"channel_drain": {
				"enabled": false,
				"base": 0.6,
				"active_drain_scale": 0.2,
				"min_gradient": 0.05,
			},
		},
		"action_params": {
			"time_skip": {
				"phrames_no_drain": 4,
				"phrames_mid_drain": 10,
				"phrames_high_drain": 16,
				"mid_drain_threshold": 4,
			},
			"victory_lap_partial": {
				"max_registers": 8,
				"milk_spend": 0,
				"phase_window": 1,
			},
		},
		"action_limits": {
			"default": {
				"enabled": true,
				"min_loop": 1,
				"max_per_loop": 1,
				"max_total_locks": 2,
				"loop_mod": 1,
				"pairs_soft_cap": 20,
				"min_known_biomes": 2,
				"critical_pressure_cap": 2.5,
				"fail_streak_trigger": 2,
				"cooldown_loops": 2,
			},
			"lock_offer": {},
		},
		"reward_terms": {
			"resource": 0.08,
			"pair": 42.0,
			"active_quest": 5.0,
			"biome": 8.0,
			"drain": 2.5,
			"lock": 3.0,
			"milk_bonus": 120.0,
			"execution_penalty": -4.0,
			"reward_min": -120.0,
			"reward_max": 220.0,
		},
		"dynamics": {
			"apply_stagnation_penalty": true,
			"stagnation_penalty_scale": 1.5,
			"stagnation_penalty_cap": 24.0,
		},
	}
	if policy_kind == "quantum_register":
		graph["action_priors"]["quest_cycle"]["base"] = 2.0
		graph["action_priors"]["quest_cycle"]["stagnation_scale"] = 0.15
		graph["action_priors"]["quest_cycle"]["stagnation_cap"] = 1.5
		graph["action_priors"]["probe_cycle"]["base"] = 0.5
		graph["action_priors"]["lindblad_drain"]["base"] = 0.4
		graph["action_priors"]["lindblad_drain"]["inactive_bonus"] = 0.0
		graph["action_priors"]["lindblad_drain"]["active_scale"] = 0.15
		graph["action_priors"]["channel_drain"]["enabled"] = true
		graph["reward_terms"]["execution_penalty"] = -8.0
		graph["dynamics"]["apply_stagnation_penalty"] = false
	return graph


static func action_limits_for_action(graph: Dictionary, action_name: String) -> Dictionary:
	var action_limits = graph.get("action_limits", {})
	if not (action_limits is Dictionary):
		action_limits = {}
	var defaults = action_limits.get("default", {})
	if not (defaults is Dictionary):
		defaults = {}
	var out = defaults.duplicate(true)
	var specific = action_limits.get(action_name, {})
	if specific is Dictionary:
		_merge_into(out, specific)
	return out


static func profile_graph_path(profile_id: String = "default", policy_kind: String = "ucb") -> String:
	var safe_profile := str(profile_id).strip_edges()
	if safe_profile == "":
		safe_profile = "default"
	var safe_kind := str(policy_kind).strip_edges()
	if safe_kind == "":
		safe_kind = "ucb"
	var candidates: Array[String] = [
		"res://Core/Config/PolicyGraph/%s/%s.jsonl" % [safe_kind, safe_profile],
		"res://Core/Config/PolicyGraph/%s.jsonl" % [safe_profile],
	]
	for path in candidates:
		if FileAccess.file_exists(path):
			return path
	return DEFAULT_GRAPH_PATH


static func load_resolved_graph(policy_kind: String = "ucb", profile_id: String = "default", extra_lines: Array = []) -> Dictionary:
	var graph := default_graph(policy_kind, profile_id)
	var profile_lines = load_graph_lines(profile_graph_path(profile_id, policy_kind))
	if not profile_lines.is_empty():
		var profile_result = apply_graph_lines(graph, profile_lines)
		if bool(profile_result.get("ok", false)):
			graph = profile_result.get("graph", graph)
	if extra_lines is Array and not extra_lines.is_empty():
		var extra_result = apply_graph_lines(graph, extra_lines)
		if bool(extra_result.get("ok", false)):
			graph = extra_result.get("graph", graph)
	return graph


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


static func apply_patch(base_graph: Dictionary, patch: Dictionary) -> Dictionary:
	var merged = base_graph.duplicate(true)
	_merge_into(merged, patch)
	return merged


static func apply_graph_lines(base_graph: Dictionary, lines: Array) -> Dictionary:
	if lines.is_empty():
		return {
			"ok": true,
			"graph": base_graph.duplicate(true),
			"errors": [],
		}
	var parsed = parse_graph_lines(lines)
	if not bool(parsed.get("ok", false)):
		return {
			"ok": false,
			"graph": base_graph.duplicate(true),
			"errors": parsed.get("errors", []),
		}
	return {
		"ok": true,
		"graph": apply_patch(base_graph, parsed.get("patch", {})),
		"errors": parsed.get("errors", []),
	}


static func _flatten_value(lines: Array[String], path: String, value) -> void:
	if value is Dictionary and not value.is_empty():
		var keys = value.keys()
		keys.sort()
		for key in keys:
			_flatten_value(lines, "%s.%s" % [path, str(key)], value[key])
		return
	lines.append(JSON.stringify({
		"op": "set",
		"path": path,
		"value": value,
	}))


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


static func _merge_into(target: Dictionary, patch: Dictionary) -> void:
	for key in patch.keys():
		var skey = str(key)
		var value = patch[key]
		if value is Dictionary:
			var child = target.get(skey, {})
			if not (child is Dictionary):
				child = {}
			_merge_into(child, value)
			target[skey] = child
		else:
			target[skey] = value
