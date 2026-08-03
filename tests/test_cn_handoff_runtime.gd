extends SceneTree

const MockQuestOverlay = preload("res://tests/MockQuestOverlay.gd")

var passed := 0
var failed := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var overlay_mgr = OverlayManager.new()
	root.add_child(overlay_mgr)
	overlay_mgr.setup(null, null)

	var fake_quests := MockQuestOverlay.new()
	overlay_mgr.register_overlay("quests", fake_quests)

	overlay_mgr.set_pending_pair_scope("StarterForest", "Village")
	assert_true(overlay_mgr._pending_pair_scope.size() == 2, "pending pair scope stored")

	var opened := overlay_mgr.open_overlay("quests")
	assert_true(opened, "quests overlay opens")
	assert_eq(fake_quests.pair_scope_history.size(), 1, "pair scope delivered once")
	assert_eq(fake_quests.pair_scope_history[0], ["StarterForest", "Village"], "pair scope payload")
	assert_true(overlay_mgr._pending_pair_scope.is_empty(), "pending pair scope cleared")
	assert_eq(fake_quests.clear_calls, 0, "clear_pair_scope not used when handoff exists")

	overlay_mgr.open_overlay("quests")
	assert_eq(fake_quests.clear_calls, 1, "clear_pair_scope used when no handoff exists")

	var qb_script = load("res://UI/Overlays/QuestBoard.gd")
	var quest_board = qb_script.new()
	root.add_child(quest_board)
	await process_frame

	var biome = Node.new()
	biome.name = "StarterForest"
	quest_board.current_biome = biome
	quest_board.set_pair_scope("StarterForest", "Village")
	var visible = quest_board.get_visible_data()
	assert_eq(visible.get("scope_source", ""), "N handoff", "quest board scope source")
	assert_true(str(visible.get("scope_mode", "")).contains("StarterForest × Village"), "quest board scope mode")

	fake_quests.free()
	quest_board.queue_free()
	overlay_mgr.queue_free()
	await process_frame
	fake_quests = null
	quest_board = null
	overlay_mgr = null
	qb_script = null
	biome = null

	print("CN handoff runtime: %d passed, %d failed" % [passed, failed])
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
