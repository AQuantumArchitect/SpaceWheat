class_name FractalWorldService
extends RefCounted
## FractalWorldService — enter/ascend/export for icon→world fractal (farm-bound).

var atlas = null
var farm: Node = null


func _init() -> void:
	var Atlas = load("res://Core/Instrumentation/FractalAtlas.gd")
	if Atlas == null:
		push_error("FractalWorldService: failed to load FractalAtlas.gd")
		return
	atlas = Atlas.new()
	if atlas == null:
		push_error("FractalWorldService: FractalAtlas.new() returned null")


func bind_farm(f: Node) -> void:
	farm = f


func ensure_root_from_active() -> String:
	if farm == null or atlas == null:
		return ""
	var abm = _abm()
	var bname: String = "StarterForest"
	if abm != null and abm.has_method("get_active_biome"):
		bname = str(abm.get_active_biome())
	elif farm.grid != null and farm.grid.has_method("get_biome_names"):
		var names = farm.grid.get_biome_names()
		if names is Array and names.size() > 0:
			bname = str(names[0])
	return atlas.ensure_authored_root(bname)


func on_inject(
	parent_biome_name: String,
	register_id: int,
	icon_name: String,
	pole_0: String,
	pole_1: String
) -> Dictionary:
	if atlas == null:
		return {"success": false, "error": "no_atlas"}
	var parent_wid: String = atlas.world_for_biome(parent_biome_name)
	if parent_wid == "" or not atlas.nodes.has(parent_wid):
		parent_wid = atlas.ensure_authored_root(parent_biome_name)
	var cid: String = atlas.ensure_latent_child(parent_wid, register_id, icon_name, pole_0, pole_1)
	export_all()
	return {
		"success": true,
		"child_id": cid,
		"parent_world_id": parent_wid,
		"register_id": register_id,
		"status": "latent",
	}


func enter_icon(parent_biome_name: String, register_id: int) -> Dictionary:
	if farm == null or farm.grid == null or atlas == null:
		return {"success": false, "error": "no_farm", "message": "Farm not bound"}
	ensure_root_from_active()
	var parent_wid: String = atlas.world_for_biome(parent_biome_name)
	if parent_wid == "":
		parent_wid = atlas.ensure_authored_root(parent_biome_name)
	var parent_node: Dictionary = atlas.nodes.get(parent_wid, {})
	var child_id: String = ""
	var poles: Array = ["", ""]
	var icon_name: String = ""
	for q in parent_node.get("qubits", []):
		if int(q.get("register_id", -1)) == register_id:
			child_id = str(q.get("child_id", ""))
			poles = [str(q.get("pole_0", "")), str(q.get("pole_1", ""))]
			icon_name = str(q.get("icon_name", poles[0]))
			break
	if child_id == "":
		var parent_biome = farm.grid.get_biome(parent_biome_name)
		if parent_biome != null and parent_biome.quantum_computer != null and parent_biome.quantum_computer.register_map != null:
			var axis = parent_biome.quantum_computer.register_map.axes.get(register_id, {})
			poles = [str(axis.get("north", "")), str(axis.get("south", ""))]
			icon_name = str(poles[0])
			if poles[0] != "" and poles[1] != "":
				child_id = atlas.ensure_latent_child(parent_wid, register_id, icon_name, poles[0], poles[1])
	if child_id == "":
		return {"success": false, "error": "no_child", "message": "No fractal child for register %d" % register_id}

	var gate: Dictionary = atlas.can_enter(child_id)
	if not bool(gate.get("ok", false)):
		return {"success": false, "error": gate.get("error", "blocked"), "message": gate.get("message", "enter blocked")}

	var node: Dictionary = atlas.nodes[child_id]
	var Atlas = load("res://Core/Instrumentation/FractalAtlas.gd")
	var biome_name: String = str(node.get("biome_name", ""))
	if biome_name == "" and Atlas:
		biome_name = Atlas.synthetic_biome_name(child_id)
	var seed: Dictionary = node.get("seed", {})
	var Proc = load("res://Core/Environment/ProceduralIconBiome.gd")
	if seed.is_empty() and Proc:
		seed = Proc.build_seed(icon_name, poles[0], poles[1])

	if not farm.grid.has_biome(biome_name):
		if Proc == null:
			return {"success": false, "error": "no_proc", "message": "ProceduralIconBiome missing"}
		var mat: Dictionary = Proc.materialize(seed, biome_name, farm)
		if not bool(mat.get("success", false)):
			return mat
		var biome = mat.get("biome")
		farm.grid.register_biome(biome_name, biome)
		if biome != null:
			biome.grid = farm.grid
		if farm.biome_evolution_batcher != null and farm.biome_evolution_batcher.has_method("register_biome"):
			farm.biome_evolution_batcher.register_biome(biome)
		if farm.has_method("refresh_grid_for_biomes"):
			farm.refresh_grid_for_biomes()
		atlas.mark_live(child_id)
	else:
		atlas.mark_live(child_id)

	atlas.push_path(child_id)
	_activate_biome(biome_name)
	export_all()
	return {
		"success": true,
		"child_id": child_id,
		"biome_name": biome_name,
		"depth": int(node.get("depth", 0)),
		"active_path": atlas.active_path.duplicate(),
		"poles": poles,
	}


func ascend() -> Dictionary:
	if farm == null or atlas == null:
		return {"success": false, "error": "no_farm", "message": "Farm not bound"}
	var leaving: String = atlas.current_world_id()
	var parent_wid: String = atlas.ascend_path()
	if parent_wid == "":
		return {"success": false, "error": "at_root", "message": "Already at fractal root"}
	var parent_biome: String = atlas.biome_for_world(parent_wid)
	if parent_biome == "" and atlas.nodes.has(parent_wid):
		parent_biome = str(atlas.nodes[parent_wid].get("biome_name", atlas.nodes[parent_wid].get("name", "")))
	if parent_biome == "":
		return {"success": false, "error": "no_parent_biome", "message": "Parent world has no biome name"}

	if atlas.unload_off_path and leaving != "" and leaving != parent_wid:
		_maybe_unload(leaving)

	_activate_biome(parent_biome)
	export_all()
	return {
		"success": true,
		"parent_world_id": parent_wid,
		"biome_name": parent_biome,
		"left_world_id": leaving,
		"active_path": atlas.active_path.duplicate(),
	}


func snapshot() -> Dictionary:
	if atlas == null:
		return {}
	return atlas.to_dict()


func export_all() -> Dictionary:
	if atlas == null:
		return {"ok": false, "error": "no_atlas"}
	var results: Array = []
	var r1: Dictionary = atlas.export_json_path("user://fractal_atlas.json")
	results.append(r1)
	var vitals: String = OS.get_environment("BUTLER_VITALS")
	if vitals == "":
		vitals = OS.get_environment("YURT_VITALS")
	if vitals != "":
		results.append(atlas.export_json_path(vitals.path_join("fractal_atlas.json")))
	return {"ok": true, "exports": results, "atlas": atlas.to_dict()}


func _activate_biome(biome_name: String) -> void:
	var abm = _abm()
	if abm == null:
		return
	var order: Array = []
	if abm.has_method("get_biome_order"):
		for b in abm.get_biome_order():
			order.append(str(b))
	if biome_name not in order:
		order.append(biome_name)
	if abm.has_method("set_biome_order"):
		abm.set_biome_order(order)
	if abm.has_method("set_active_biome"):
		abm.set_active_biome(biome_name, 1)


func _maybe_unload(world_id: String) -> void:
	if farm == null or farm.grid == null or atlas == null:
		return
	var node: Dictionary = atlas.nodes.get(world_id, {})
	if str(node.get("kind", "")) != "procedural_icon_world":
		return
	var bname: String = str(node.get("biome_name", atlas.biome_for_world(world_id)))
	if bname == "" or not farm.grid.has_biome(bname):
		return
	if world_id in atlas.active_path:
		return
	var biome = farm.grid.get_biome(bname)
	if farm.biome_evolution_batcher != null and farm.biome_evolution_batcher.has_method("unregister_biome"):
		farm.biome_evolution_batcher.unregister_biome(biome)
	farm.grid.unregister_biome(bname)
	if is_instance_valid(biome):
		biome.queue_free()
	atlas.mark_latent(world_id, "unload_off_path")
	if farm.has_method("refresh_grid_for_biomes"):
		farm.refresh_grid_for_biomes()


func _abm():
	if Engine.get_main_loop() and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("/root/ActiveBiomeManager")
	return null
