extends SceneTree


var passed := 0
var failed := 0


class FakePlayerProgress:
	extends Node

	func get_signature_icons() -> Array:
		return [
			{"north": "🌾", "south": "🪨"},
			{"north": "🌾", "south": "🌙"},
			{"north": "🪨", "south": "🌙"},
		]


class FakeGSM:
	extends Node

	signal icon_discovered(north: String, south: String)
	signal icon_removed(north: String, south: String)

	var player_progress: FakePlayerProgress = null


class FakeAtomRegistry:
	extends Node

	var atoms: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_root := Node.new()
	root.add_child(scene_root)

	var gsm := FakeGSM.new()
	gsm.name = "GameStateManager"
	gsm.player_progress = FakePlayerProgress.new()
	gsm.add_child(gsm.player_progress)
	scene_root.add_child(gsm)

	var atom_registry := FakeAtomRegistry.new()
	atom_registry.name = "IconRegistry"
	atom_registry.atoms = {
		"🌾": {"trophic_level": 0},
		"🪨": {"trophic_level": 1},
		"🌙": {"trophic_level": 2},
	}
	scene_root.add_child(atom_registry)

	var overlay: QubitAtlasOverlay = QubitAtlasOverlay.new()
	scene_root.add_child(overlay)
	await process_frame

	overlay.activate()
	await process_frame

	var visible: Dictionary = overlay.get_visible_data()
	assert_eq(visible.get("frame_label", ""), "Lexicon", "frame label is lexicon")
	assert_eq(int(visible.get("page_index", -1)), 1, "page index starts at first page")
	assert_true(int(visible.get("page_count", -1)) >= 1, "page count is exposed")
	assert_true(int(visible.get("known_icon_count", -1)) >= 0, "known icon count is exposed")
	overlay._on_action_f()
	visible = overlay.get_visible_data()
	assert_true(int(visible.get("page_index", -1)) >= 1, "F keeps page index valid")

	overlay._on_action_q()
	visible = overlay.get_visible_data()
	assert_true(int(visible.get("page_index", -1)) >= 1, "Q keeps page index valid")

	var snapshot: Dictionary = overlay.get_snapshot()
	assert_true(snapshot.has("frame_label"), "snapshot carries visible data payload")

	scene_root.queue_free()
	await process_frame
	scene_root = null
	overlay = null
	atom_registry = null
	gsm = null

	print("V surface runtime: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)


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
