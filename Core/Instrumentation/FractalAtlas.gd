class_name FractalAtlas
extends RefCounted
## FractalAtlas — shared icon→world address space (fractal_atlas/v1).

const SCHEMA := "fractal_atlas/v1"
const DEFAULT_DEPTH_CAP := 3

var depth_cap: int = DEFAULT_DEPTH_CAP
var root_id: String = ""
var active_path: Array = []
var nodes: Dictionary = {}
var writer: String = "spacewheat"
var unload_off_path: bool = true
var world_to_biome: Dictionary = {}
var biome_to_world: Dictionary = {}


static func _sha16(text: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	return ctx.finish().hex_encode().substr(0, 16)


static func child_id(parent_world_id: String, register_id: int, pole_0: String, pole_1: String) -> String:
	var payload := "%s|%d|%s|%s" % [parent_world_id, register_id, pole_0, pole_1]
	return "icon:%s" % _sha16(payload)


static func authored_world_id(biome_name: String) -> String:
	return "world:campaign:%s" % biome_name


static func synthetic_biome_name(world_id: String) -> String:
	return "FX_%s" % _sha16(world_id)


func ensure_authored_root(biome_name: String) -> String:
	var wid: String = authored_world_id(biome_name)
	if not nodes.has(wid):
		nodes[wid] = {
			"kind": "authored_biome",
			"name": biome_name,
			"status": "live",
			"parent_id": null,
			"depth": 0,
			"poles": null,
			"qubits": [],
			"biome_name": biome_name,
		}
	world_to_biome[wid] = biome_name
	biome_to_world[biome_name] = wid
	if root_id == "":
		root_id = wid
	if active_path.is_empty():
		active_path = [wid]
	return wid


func ensure_latent_child(
	parent_world_id: String,
	register_id: int,
	icon_name: String,
	pole_0: String,
	pole_1: String
) -> String:
	if not nodes.has(parent_world_id):
		var bare: String = parent_world_id
		if bare.begins_with("world:campaign:"):
			bare = bare.substr("world:campaign:".length())
		ensure_authored_root(bare)
	var parent: Dictionary = nodes.get(parent_world_id, {})
	var parent_depth: int = int(parent.get("depth", 0))
	var cid: String = child_id(parent_world_id, register_id, pole_0, pole_1)
	var bname: String = synthetic_biome_name(cid)
	if not nodes.has(cid):
		nodes[cid] = {
			"kind": "procedural_icon_world",
			"name": "%s@%s#%d" % [icon_name, str(parent.get("name", parent_world_id)), register_id],
			"status": "latent",
			"parent_id": parent_world_id,
			"depth": parent_depth + 1,
			"poles": [pole_0, pole_1],
			"biome_name": bname,
			"seed": {
				"from_icon": icon_name,
				"pole_0": pole_0,
				"pole_1": pole_1,
				"closed": true,
			},
			"qubits": [],
		}
	world_to_biome[cid] = bname
	biome_to_world[bname] = cid
	var qubits: Array = parent.get("qubits", [])
	var found := false
	for q in qubits:
		if int(q.get("register_id", -1)) == register_id:
			q["child_id"] = cid
			q["icon_name"] = icon_name
			q["pole_0"] = pole_0
			q["pole_1"] = pole_1
			found = true
			break
	if not found:
		qubits.append({
			"register_id": register_id,
			"icon_name": icon_name,
			"pole_0": pole_0,
			"pole_1": pole_1,
			"child_id": cid,
		})
	parent["qubits"] = qubits
	nodes[parent_world_id] = parent
	return cid


func can_enter(child_world_id: String) -> Dictionary:
	if not nodes.has(child_world_id):
		return {"ok": false, "error": "unknown_world", "message": "No atlas node for %s" % child_world_id}
	var node: Dictionary = nodes[child_world_id]
	var depth: int = int(node.get("depth", 0))
	if depth > depth_cap:
		return {
			"ok": false,
			"error": "depth_cap",
			"message": "Depth %d exceeds depth_cap %d" % [depth, depth_cap],
		}
	return {"ok": true, "node": node}


func mark_live(world_id: String) -> void:
	if nodes.has(world_id):
		var n: Dictionary = nodes[world_id]
		n["status"] = "live"
		n.erase("reason")
		nodes[world_id] = n


func mark_latent(world_id: String, reason: String = "") -> void:
	if nodes.has(world_id):
		var n: Dictionary = nodes[world_id]
		n["status"] = "latent"
		if reason != "":
			n["reason"] = reason
		nodes[world_id] = n


func push_path(world_id: String) -> void:
	if active_path.is_empty() or str(active_path[active_path.size() - 1]) != world_id:
		active_path.append(world_id)


func ascend_path() -> String:
	if active_path.size() <= 1:
		return str(active_path[0]) if not active_path.is_empty() else ""
	active_path.pop_back()
	return str(active_path[active_path.size() - 1])


func current_world_id() -> String:
	if active_path.is_empty():
		return root_id
	return str(active_path[active_path.size() - 1])


func biome_for_world(world_id: String) -> String:
	return str(world_to_biome.get(world_id, ""))


func world_for_biome(biome_name: String) -> String:
	if biome_to_world.has(biome_name):
		return str(biome_to_world[biome_name])
	if biome_name.begins_with("FX_"):
		return ""
	return authored_world_id(biome_name)


func to_dict() -> Dictionary:
	return {
		"schema": SCHEMA,
		"as_of": Time.get_datetime_string_from_system(true),
		"writer": writer,
		"root_id": root_id,
		"depth_cap": depth_cap,
		"active_path": active_path.duplicate(),
		"nodes": nodes.duplicate(true),
		"world_to_biome": world_to_biome.duplicate(true),
		"honesty": {"fog": true, "null_money": true},
	}


func export_json_path(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "open_failed", "message": str(FileAccess.get_open_error())}
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()
	return {"ok": true, "path": path}


static func from_dict(data: Dictionary):
	var atlas = load("res://Core/Instrumentation/FractalAtlas.gd").new()
	if str(data.get("schema", "")) != SCHEMA and data.has("schema"):
		push_warning("FractalAtlas: unexpected schema %s" % data.get("schema"))
	atlas.depth_cap = int(data.get("depth_cap", DEFAULT_DEPTH_CAP))
	atlas.root_id = str(data.get("root_id", ""))
	atlas.writer = str(data.get("writer", "spacewheat"))
	var path = data.get("active_path", [])
	atlas.active_path.clear()
	if path is Array:
		for p in path:
			atlas.active_path.append(str(p))
	var n = data.get("nodes", {})
	if n is Dictionary:
		atlas.nodes = n.duplicate(true)
	var w2b = data.get("world_to_biome", {})
	if w2b is Dictionary:
		atlas.world_to_biome = w2b.duplicate(true)
		for wid in atlas.world_to_biome.keys():
			atlas.biome_to_world[str(atlas.world_to_biome[wid])] = str(wid)
	return atlas
