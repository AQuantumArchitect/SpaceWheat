extends SceneTree


var passed := 0
var failed := 0
var _finished := false


class FakePlayerProgress:
	extends Node

	func get_signature_icons() -> Array:
		return [
			{"north": "🌾", "south": "🪨"},
			{"north": "🌾", "south": "🌙"},
			{"north": "🪨", "south": "🌙"},
		]


class FakeGameStateManager:
	extends Node

	signal icon_discovered(north: String, south: String)
	signal icon_removed(north: String, south: String)

	var player_progress: FakePlayerProgress = null
	var _active_farm: Node = null

	func get_active_farm() -> Node:
		return _active_farm


class FakeActiveBiomeManager:
	extends Node

	signal active_biome_changed(new_biome: String, old_biome: String)

	var _active_biome: String = ""

	func get_active_biome() -> String:
		return _active_biome


class FakeAtomRegistry:
	extends Node

	var atoms: Dictionary = {}


class FakeGrid:
	extends Node

	var biomes: Dictionary = {}

	func get_all_biomes() -> Dictionary:
		return biomes

	func get_biome(_name: String):
		return biomes.get(_name, null)

	func has_biome(_name: String) -> bool:
		return biomes.has(_name)


class FakeFarm:
	extends Node

	var faction_density: FactionDensityMatrix = null
	var grid: FakeGrid = null
	var faction_standings: Dictionary = {}


func _init() -> void:
	call_deferred("_run")
	call_deferred("_arm_watchdog")


func _arm_watchdog() -> void:
	# Fail-safe: an uncaught script error inside _run() (e.g. an overlay class
	# failing to compile under this harness's autoload timing — the 2026-08
	# BiomeInspectorOverlay bare-IconRegistry hang) aborts _run without ever
	# reaching quit(), leaving the tree ticking forever. Quit red instead.
	var t := create_timer(90.0)
	t.timeout.connect(func() -> void:
		if not _finished:
			printerr("headless surface smoke: watchdog fired — _run() never finished (uncaught error?)")
			quit(1)
	)


func _run() -> void:
	var scene_root := Node.new()
	root.add_child(scene_root)

	var gsm := FakeGameStateManager.new()
	gsm.name = "GameStateManager"
	gsm.player_progress = FakePlayerProgress.new()
	gsm.player_progress.name = "PlayerProgress"
	gsm.add_child(gsm.player_progress)
	root.add_child(gsm)

	var abm := FakeActiveBiomeManager.new()
	abm.name = "ActiveBiomeManager"
	root.add_child(abm)

	var atom_registry := FakeAtomRegistry.new()
	atom_registry.name = "IconRegistry"
	atom_registry.atoms = {
		"🌾": {"trophic_level": 0},
		"🪨": {"trophic_level": 1},
		"🌙": {"trophic_level": 2},
	}
	root.add_child(atom_registry)

	var br := BiomeRegistry.new()
	var village_spec = br.get_by_name("Village")
	var hearth_spec = br.get_by_name("HearthKeepers")
	if village_spec == null or hearth_spec == null:
		_fail("required biome specs unavailable")
		_cleanup(scene_root, gsm, abm, atom_registry)
		_finished = true
		quit(1)
		return

	var village_res = BiomeBuilder.build_from_spec(village_spec, scene_root, {"skip_tree_add": true})
	var hearth_res = BiomeBuilder.build_from_spec(hearth_spec, scene_root, {"skip_tree_add": true})
	if not bool(village_res.get("success", false)) or not bool(hearth_res.get("success", false)):
		_fail("biomes failed to build")
		_cleanup(scene_root, gsm, abm, atom_registry)
		_finished = true
		quit(1)
		return

	var village = village_res.get("biome_node", null)
	var hearth = hearth_res.get("biome_node", null)
	scene_root.add_child(village)
	scene_root.add_child(hearth)

	var farm := FakeFarm.new()
	farm.faction_density = FactionDensityMatrix.new()
	farm.grid = FakeGrid.new()
	farm.grid.biomes = {
		"Village": village,
		"HearthKeepers": hearth,
	}
	farm.faction_standings = {
		"Village": 0.72,
		"HearthKeepers": 0.42,
		"Woodlot": 0.11,
	}
	scene_root.add_child(farm)
	gsm._active_farm = farm
	abm._active_biome = "Village"

	await process_frame

	var atlas := QubitAtlasOverlay.new()
	scene_root.add_child(atlas)
	await process_frame
	atlas.activate()
	await process_frame
	var atlas_visible: Dictionary = atlas.get_visible_data()
	assert_eq(atlas_visible.get("frame_label", ""), "Lexicon", "V uses Lexicon label")
	assert_true(int(atlas_visible.get("known_icon_count", -1)) >= 0, "V snapshot exposes known icon count")
	var atlas_page_before: int = int(atlas_visible.get("page_index", 0))
	atlas._on_action_f()
	await process_frame
	var atlas_visible_after: Dictionary = atlas.get_visible_data()
	var atlas_page_after: int = int(atlas_visible_after.get("page_index", 0))
	if int(atlas_visible_after.get("page_count", 1)) > 1:
		assert_true(atlas_page_after == atlas_page_before, "V page action is a no-op on Lexicon")
	assert_true(atlas_visible_after.has("known_icon_count"), "V snapshot carries known icon count")
	assert_true(atlas.get_snapshot().has("frame_label"), "V snapshot carries visible data payload")

	var biome_detail := BiomeInspectorOverlay.new()
	scene_root.add_child(biome_detail)
	biome_detail.farm = farm
	biome_detail._active_biome = village
	biome_detail.context_id = str(village.get_biome_type()) if village.has_method("get_biome_type") else str(village.name)
	await process_frame
	biome_detail.activate()
	await process_frame
	biome_detail.set_frame("whole")
	await process_frame
	var whole_visible: Dictionary = biome_detail.get_visible_data()
	assert_true(whole_visible.has("scope_mode"), "B whole exposes scope mode")
	biome_detail.set_frame("links")
	await process_frame
	var links_visible: Dictionary = biome_detail.get_visible_data()
	assert_true(links_visible.has("scope_mode"), "B links exposes scope mode")

	var map_meta := MapMetaOverlay.new()
	scene_root.add_child(map_meta)
	map_meta.farm = farm
	map_meta.set_biome(village)
	await process_frame
	map_meta.activate()
	await process_frame
	var vectors_visible: Dictionary = map_meta.get_visible_data()
	assert_eq(vectors_visible.get("frame_label", ""), "Vectors", "M starts on Vectors")
	assert_true(vectors_visible.has("pinned_faction"), "M exposes pinned_faction")
	assert_true(vectors_visible.has("selected_axis"), "M exposes selected_axis")
	map_meta.set_frame("atlas")
	await process_frame
	var atlas_visible_m: Dictionary = map_meta.get_visible_data()
	assert_true(atlas_visible_m.has("cluster_snapshot"), "M atlas exposes cluster snapshot")
	assert_true(atlas_visible_m.has("atlas_state"), "M atlas exposes atlas state")

	var network := InspectorOverlay.new()
	scene_root.add_child(network)
	await process_frame
	network.activate()
	await process_frame
	network.set_frame("map")
	await process_frame
	var map_visible: Dictionary = network.get_visible_data()
	assert_eq(map_visible.get("handoff_target", ""), "C", "N map keeps C handoff target")
	assert_true(str(map_visible.get("network_hint", "")).length() > 0, "N map exposes network hint")
	network.set_frame("bridges")
	await process_frame
	var bridges_visible: Dictionary = network.get_visible_data()
	assert_true(bridges_visible.has("bridge_count"), "N bridges exposes bridge count")
	assert_true(bridges_visible.has("network_hint"), "N bridges exposes network hint")

	_cleanup(scene_root, gsm, abm, atom_registry)
	await process_frame
	_finished = true
	print("headless surface smoke: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)


func _cleanup(scene_root: Node, gsm: Node, abm: Node, atom_registry: Node) -> void:
	if scene_root and is_instance_valid(scene_root):
		scene_root.queue_free()
	if gsm and is_instance_valid(gsm):
		gsm.queue_free()
	if abm and is_instance_valid(abm):
		abm.queue_free()
	if atom_registry and is_instance_valid(atom_registry):
		atom_registry.queue_free()


func assert_eq(actual, expected, msg: String) -> void:
	if actual == expected:
		passed += 1
		print("  ✓ %s" % msg)
	else:
		failed += 1
		print("  ✗ %s" % msg)
		print("    Expected: %s" % str(expected))
		print("    Actual:   %s" % str(actual))


func assert_true(condition: bool, msg: String) -> void:
	if condition:
		passed += 1
		print("  ✓ %s" % msg)
	else:
		failed += 1
		print("  ✗ %s" % msg)


func _fail(msg: String) -> void:
	push_error(msg)
	failed += 1
