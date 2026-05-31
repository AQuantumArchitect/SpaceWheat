extends SceneTree

const AlignmentGraphCls = preload("res://Core/Alignment/AlignmentGraph.gd")

var passed := 0
var failed := 0


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
	var player_alignment = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_root: Node = Node.new()
	root.add_child(scene_root)

	var br := BiomeRegistry.new()
	var v_spec = br.get_by_name("Village")
	var h_spec = br.get_by_name("HearthKeepers")
	assert_true(v_spec != null, "Village spec available")
	assert_true(h_spec != null, "HearthKeepers spec available")
	if v_spec == null or h_spec == null:
		_cleanup(scene_root)
		quit(1)
		return

	var v_res = BiomeBuilder.build_from_spec(v_spec, scene_root, {"skip_tree_add": true})
	var h_res = BiomeBuilder.build_from_spec(h_spec, scene_root, {"skip_tree_add": true})
	assert_true(bool(v_res.get("success", false)), "Village biome builds")
	assert_true(bool(h_res.get("success", false)), "HearthKeepers biome builds")
	if not bool(v_res.get("success", false)) or not bool(h_res.get("success", false)):
		_cleanup(scene_root)
		quit(1)
		return

	var v_biome: Node = v_res.get("biome_node", null)
	var h_biome: Node = h_res.get("biome_node", null)
	scene_root.add_child(v_biome)
	scene_root.add_child(h_biome)

	var farm := FakeFarm.new()
	farm.faction_density = FactionDensityMatrix.new()
	farm.grid = FakeGrid.new()
	farm.grid.biomes = {
		"Village": v_biome,
		"HearthKeepers": h_biome,
	}
	farm.player_alignment = AlignmentGraphCls.from_uniform_superposition()
	scene_root.add_child(farm)

	var overlay: MapMetaOverlay = MapMetaOverlay.new()
	scene_root.add_child(overlay)
	await process_frame

	overlay.farm = farm
	overlay.set_biome(v_biome)
	overlay.activate()
	await process_frame

	# T — Vectors (default)
	var visible_data: Dictionary = overlay.get_visible_data()
	assert_eq(visible.get("frame_label", ""), "Vectors", "starts on Vectors")
	assert_eq(int(visible.get("selected_axis", -1)), 0, "default axis selection is 0")
	assert_eq(int(visible.get("axis_page", -1)), 0, "default axis_page is 0")
	assert_true(visible.has("pinned_faction"), "exposes pinned_faction")
	assert_true(visible.has("selected_faction_b"), "exposes selected_faction_b")
	assert_true(int(visible.get("roster_size", 0)) > 0, "roster populated")

	# Axis selection via H (slot 1) → axis 1
	overlay._on_unhandled_key(KEY_H, InputEventKey.new())
	visible = overlay.get_visible_data()
	assert_eq(int(visible.get("selected_axis", -1)), 1, "H selects axis 1 on Vectors")

	# W/S pages axes
	overlay._on_unhandled_key(KEY_S, InputEventKey.new())
	visible = overlay.get_visible_data()
	assert_eq(int(visible.get("axis_page", -1)), 1, "S advances axis_page to 1")
	overlay._on_unhandled_key(KEY_W, InputEventKey.new())
	visible = overlay.get_visible_data()
	assert_eq(int(visible.get("axis_page", -1)), 0, "W returns axis_page to 0")

	# Y — Eigenstate
	overlay._on_unhandled_key(KEY_Y, InputEventKey.new())
	visible = overlay.get_visible_data()
	assert_eq(visible.get("frame_label", ""), "Eigenstate", "Y switches to Eigenstate")
	assert_eq(visible.get("eigen_sort_mode", ""), "System", "Eigenstate defaults to System sort")

	# Sort-mode chord: [2] = Subject (pinned faction)
	overlay._on_unhandled_key(KEY_2, InputEventKey.new())
	visible = overlay.get_visible_data()
	assert_eq(visible.get("eigen_sort_mode", ""), "Subject", "[2] switches Eigenstate sort to Subject")

	# [1] returns to System
	overlay._on_unhandled_key(KEY_1, InputEventKey.new())
	visible = overlay.get_visible_data()
	assert_eq(visible.get("eigen_sort_mode", ""), "System", "[1] returns to System sort")

	# E on Eigen sets selected_faction_b and jumps to Bits
	# Pick a non-zero index first via H to simulate selection.
	overlay._on_unhandled_key(KEY_H, InputEventKey.new())
	overlay._on_action_e()
	visible = overlay.get_visible_data()
	assert_eq(visible.get("frame_label", ""), "Bits", "E on Eigen jumps to Bits")
	assert_true(str(visible.get("selected_faction_b", "")).length() > 0, "B faction set after Eigen E")

	# U — Drift
	overlay._on_unhandled_key(KEY_U, InputEventKey.new())
	visible = overlay.get_visible_data()
	assert_eq(visible.get("frame_label", ""), "Drift", "U switches to Drift")

	# O — Atlas (preserved zoom/rot)
	overlay._on_unhandled_key(KEY_O, InputEventKey.new())
	visible = overlay.get_visible_data()
	assert_eq(visible.get("frame_label", ""), "Atlas", "O switches to Atlas")
	assert_true(visible.has("cluster_snapshot"), "Atlas cluster snapshot present")
	assert_true(visible.has("atlas_state"), "Atlas state present")

	var atlas_state_before: Dictionary = visible.get("atlas_state", {})
	var zoom_before: float = float(atlas_state_before.get("zoom", 1.0))
	overlay._on_action_r()
	var after_r: Dictionary = overlay.get_visible_data()
	var atlas_state_after: Dictionary = after_r.get("atlas_state", {})
	assert_true(float(atlas_state_after.get("zoom", 0.0)) > zoom_before, "R zooms Atlas in")

	_cleanup(scene_root)
	await process_frame
	farm = null
	overlay = null
	scene_root = null

	print("M surface runtime: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)


func _cleanup(scene_root: Node) -> void:
	if scene_root and is_instance_valid(scene_root):
		scene_root.queue_free()


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
