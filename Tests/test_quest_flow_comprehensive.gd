extends Node

## Comprehensive Quest Flow Test
## Tests both DELIVERY and SHAPE_ACHIEVE quest flows
## Run with: godot --path . Tests/TestQuestFlowComprehensive.tscn

var farm = null
var player_shell = null
var quest_board = null
var quest_manager = null
var log_lines = []
var test_passed = 0
var test_failed = 0


func _ready() -> void:
	_log("=" .repeat(60))
	_log("COMPREHENSIVE QUEST FLOW TEST")
	_log("=" .repeat(60))
	_log("")

	await _wait_for_boot()

	if not _verify_systems():
		_log("❌ FAILED: Missing systems")
		await get_tree().create_timer(1.0).timeout
		get_tree().quit()
		return

	_give_resources()

	await get_tree().create_timer(1.0).timeout

	# Run all tests
	await _test_delivery_quest_flow()
	await _test_shape_achieve_quest_flow()
	await _test_action_labels()
	await _test_abandon_flow()
	await _test_claim_and_reject()

	# Summary
	_log("")
	_log("=" .repeat(60))
	_log("TEST SUMMARY")
	_log("=" .repeat(60))
	_log("  Passed: %d" % test_passed)
	_log("  Failed: %d" % test_failed)
	_log("  Total:  %d" % (test_passed + test_failed))
	_log("")
	if test_failed == 0:
		_log("✅ ALL TESTS PASSED!")
	else:
		_log("❌ SOME TESTS FAILED")
	_log("=" .repeat(60))

	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


func _log(msg: String) -> void:
	print(msg)
	log_lines.append(msg)


func _assert(condition: bool, test_name: String, details: String = "") -> void:
	if condition:
		_log("  ✅ PASS: %s" % test_name)
		test_passed += 1
	else:
		_log("  ❌ FAIL: %s" % test_name)
		if details:
			_log("     Details: %s" % details)
		test_failed += 1


func _wait_for_boot() -> void:
	_log("Waiting for boot...")
	var frames = 0
	while frames < 300:
		await get_tree().process_frame
		frames += 1
		if GameStateManager.active_farm:
			farm = GameStateManager.active_farm
		if not player_shell:
			player_shell = _find_player_shell()
		if farm and player_shell:
			break

	for i in range(60):
		await get_tree().process_frame

	_log("Boot complete after %d frames" % frames)


func _find_player_shell() -> Node:
	for node in get_tree().root.get_children():
		if node.name == "PlayerShell":
			return node
		if "quest_manager" in node and "overlay_manager" in node:
			return node
		var child_ps = node.get_node_or_null("PlayerShell")
		if child_ps:
			return child_ps
		for child in node.get_children():
			if child.name == "PlayerShell":
				return child
			if "quest_manager" in child and "overlay_manager" in child:
				return child
			var grandchild_ps = child.get_node_or_null("PlayerShell")
			if grandchild_ps:
				return grandchild_ps
	return null


func _verify_systems() -> bool:
	_log("")
	_log("Verifying systems...")

	if not farm:
		farm = GameStateManager.active_farm
	_log("  Farm: %s" % ("✓" if farm else "❌"))

	if not player_shell:
		_log("  PlayerShell: ❌ NOT FOUND")
		return false
	_log("  PlayerShell: ✓")

	if "quest_manager" in player_shell:
		quest_manager = player_shell.quest_manager
	_log("  QuestManager: %s" % ("✓" if quest_manager else "❌"))

	if "overlay_manager" in player_shell and player_shell.overlay_manager:
		if "quest_board" in player_shell.overlay_manager:
			quest_board = player_shell.overlay_manager.quest_board
	_log("  QuestBoard: %s" % ("✓" if quest_board else "❌"))

	return farm != null and quest_manager != null and quest_board != null


func _give_resources() -> void:
	if farm and farm.economy:
		farm.economy.add_resource("🌾", 5000, "test")
		farm.economy.add_resource("🍂", 5000, "test")
		farm.economy.add_resource("👥", 5000, "test")
		farm.economy.add_resource("💰", 5000, "test")
		_log("Added 5000 credits of starter resources")


func _open_quest_board() -> void:
	# Ensure biome is set (use biotic_flux_biome as default)
	if farm and "biotic_flux_biome" in farm and farm.biotic_flux_biome:
		if not quest_board.current_biome:
			quest_board.set_biome(farm.biotic_flux_biome)

	# Ensure quest manager is set
	if quest_manager and not quest_board.quest_manager:
		quest_board.set_quest_manager(quest_manager)

	quest_board.open_board()
	await get_tree().create_timer(0.3).timeout

	# If all slots are empty, something went wrong - try to debug
	var all_empty = true
	for i in range(4):
		if quest_board.quest_slots[i].state != 0:
			all_empty = false
			break

	if all_empty:
		_log("  ⚠️ All slots empty, checking quest generation...")
		_log("    quest_manager: %s" % quest_manager)
		_log("    current_biome: %s" % quest_board.current_biome)
		if quest_board.current_biome:
			var quests = quest_manager.offer_all_faction_quests(quest_board.current_biome)
			_log("    Available quests: %d" % quests.size())

	# Debug: show slot states
	_log("  Slot states:")
	for i in range(4):
		var slot = quest_board.quest_slots[i]
		var type_str = "DELIVERY" if slot.quest_data.get("type", 0) == 0 else "SHAPE"
		var state_str = ["EMPTY", "OFFERED", "ACTIVE", "READY"][slot.state] if slot.state < 4 else "?"
		_log("    [%d] %s - %s: %s" % [
			i, state_str, type_str, slot.quest_data.get("faction", "(none)")
		])


func _close_quest_board() -> void:
	quest_board.close_board()
	await get_tree().create_timer(0.2).timeout


# =============================================================================
# TEST: DELIVERY QUEST FLOW
# =============================================================================

func _test_delivery_quest_flow() -> void:
	_log("")
	_log("=" .repeat(50))
	_log("TEST: DELIVERY Quest Flow")
	_log("=" .repeat(50))

	await _open_quest_board()

	# Find a DELIVERY quest slot
	var delivery_slot = null
	var delivery_slot_index = -1
	for i in range(4):
		var slot = quest_board.quest_slots[i]
		if slot.state == 1 and slot.quest_data.get("type", 0) == 0:  # OFFERED + DELIVERY
			delivery_slot = slot
			delivery_slot_index = i
			break

	if not delivery_slot:
		_log("  ⚠️ No DELIVERY quest found in slots, skipping...")
		await _close_quest_board()
		return

	_log("  Found DELIVERY quest in slot %d: %s" % [delivery_slot_index, delivery_slot.quest_data.get("faction", "?")])

	# Test 1: Accept quest
	quest_board.select_slot(delivery_slot_index)
	var quest_id = delivery_slot.quest_data.get("id", -1)
	quest_board.action_q_on_selected()  # Accept
	await get_tree().create_timer(0.3).timeout

	_assert(delivery_slot.state == 2, "DELIVERY: Accept changes state to ACTIVE",
		"state=%d, expected=2" % delivery_slot.state)
	_assert(quest_manager.active_quests.has(quest_id), "DELIVERY: Quest added to active_quests")

	# Test 2: Check action labels
	var labels = quest_board.get_action_labels()
	_assert(labels.get("Q") == "Deliver", "DELIVERY ACTIVE: Q label is 'Deliver'",
		"got '%s'" % labels.get("Q", "?"))
	_assert(labels.get("E") == "Abandon", "DELIVERY ACTIVE: E label is 'Abandon'",
		"got '%s'" % labels.get("E", "?"))

	# Test 3: Deliver quest (complete)
	var completed_before = quest_manager.completed_quests.size()
	quest_board.action_q_on_selected()  # Deliver
	await get_tree().create_timer(0.3).timeout

	var completed_after = quest_manager.completed_quests.size()
	_assert(completed_after > completed_before, "DELIVERY: Quest completed after Deliver",
		"completed: %d -> %d" % [completed_before, completed_after])
	_assert(not quest_manager.active_quests.has(quest_id), "DELIVERY: Quest removed from active_quests")

	await _close_quest_board()


# =============================================================================
# TEST: SHAPE_ACHIEVE QUEST FLOW
# =============================================================================

func _test_shape_achieve_quest_flow() -> void:
	_log("")
	_log("=" .repeat(50))
	_log("TEST: SHAPE_ACHIEVE Quest Flow")
	_log("=" .repeat(50))

	await _open_quest_board()

	# Find a SHAPE_ACHIEVE quest slot
	var shape_slot = null
	var shape_slot_index = -1
	for i in range(4):
		var slot = quest_board.quest_slots[i]
		if slot.state == 1 and slot.quest_data.get("type", 0) == 1:  # OFFERED + SHAPE_ACHIEVE
			shape_slot = slot
			shape_slot_index = i
			break

	if not shape_slot:
		_log("  ⚠️ No SHAPE_ACHIEVE quest found in slots, skipping...")
		await _close_quest_board()
		return

	_log("  Found SHAPE_ACHIEVE quest in slot %d: %s" % [shape_slot_index, shape_slot.quest_data.get("faction", "?")])

	# Test 1: Accept quest
	quest_board.select_slot(shape_slot_index)
	var quest_id = shape_slot.quest_data.get("id", -1)
	quest_board.action_q_on_selected()  # Accept
	await get_tree().create_timer(0.3).timeout

	_assert(shape_slot.state == 2, "SHAPE_ACHIEVE: Accept changes state to ACTIVE",
		"state=%d, expected=2" % shape_slot.state)

	# Test 2: Check action labels
	var labels = quest_board.get_action_labels()
	_assert(labels.get("Q") == "Tracking", "SHAPE_ACHIEVE ACTIVE: Q label is 'Tracking'",
		"got '%s'" % labels.get("Q", "?"))
	_assert(labels.get("E") == "Abandon", "SHAPE_ACHIEVE ACTIVE: E label is 'Abandon'",
		"got '%s'" % labels.get("E", "?"))

	# Test 3: Pressing Q on ACTIVE shape quest does nothing
	var active_before = quest_manager.active_quests.size()
	quest_board.action_q_on_selected()  # Should do nothing (tracking)
	await get_tree().create_timer(0.3).timeout

	_assert(shape_slot.state == 2, "SHAPE_ACHIEVE: Q on ACTIVE keeps state ACTIVE",
		"state=%d" % shape_slot.state)

	# Test 4: Manually simulate quest becoming ready
	_log("  Simulating quest ready to claim...")
	quest_manager.mark_quest_ready(quest_id, "test_conditions_met")
	await get_tree().create_timer(0.3).timeout

	_assert(shape_slot.state == 3, "SHAPE_ACHIEVE: mark_quest_ready changes slot to READY",
		"state=%d, expected=3" % shape_slot.state)

	# Test 5: Check READY labels
	labels = quest_board.get_action_labels()
	_assert(labels.get("Q") == "Claim", "SHAPE_ACHIEVE READY: Q label is 'Claim'",
		"got '%s'" % labels.get("Q", "?"))
	_assert(labels.get("E") == "Reject", "SHAPE_ACHIEVE READY: E label is 'Reject'",
		"got '%s'" % labels.get("E", "?"))

	# Test 6: Claim quest
	var completed_before = quest_manager.completed_quests.size()
	quest_board.action_q_on_selected()  # Claim
	await get_tree().create_timer(0.3).timeout

	var completed_after = quest_manager.completed_quests.size()
	_assert(completed_after > completed_before, "SHAPE_ACHIEVE: Quest completed after Claim",
		"completed: %d -> %d" % [completed_before, completed_after])

	await _close_quest_board()


# =============================================================================
# TEST: ACTION LABELS
# =============================================================================

func _test_action_labels() -> void:
	_log("")
	_log("=" .repeat(50))
	_log("TEST: Action Labels")
	_log("=" .repeat(50))

	await _open_quest_board()

	# Test OFFERED state labels
	var offered_slot = null
	for i in range(4):
		var slot = quest_board.quest_slots[i]
		if slot.state == 1:  # OFFERED
			offered_slot = slot
			quest_board.select_slot(i)
			break

	if offered_slot:
		var labels = quest_board.get_action_labels()
		_assert(labels.get("Q") == "Accept", "OFFERED: Q label is 'Accept'",
			"got '%s'" % labels.get("Q", "?"))
		var expected_e = "Reroll" if not offered_slot.is_locked else "—"
		_assert(labels.get("E") == expected_e, "OFFERED: E label is '%s'" % expected_e,
			"got '%s'" % labels.get("E", "?"))
	else:
		_log("  ⚠️ No OFFERED slot found")

	# Test EMPTY state labels (if any)
	var empty_slot = null
	for i in range(4):
		var slot = quest_board.quest_slots[i]
		if slot.state == 0:  # EMPTY
			empty_slot = slot
			quest_board.select_slot(i)
			break

	if empty_slot:
		var labels = quest_board.get_action_labels()
		_assert(labels.get("Q") == "—", "EMPTY: Q label is '—'",
			"got '%s'" % labels.get("Q", "?"))
		_assert(labels.get("E") == "—", "EMPTY: E label is '—'",
			"got '%s'" % labels.get("E", "?"))

	await _close_quest_board()


# =============================================================================
# TEST: ABANDON FLOW
# =============================================================================

func _test_abandon_flow() -> void:
	_log("")
	_log("=" .repeat(50))
	_log("TEST: Abandon Flow")
	_log("=" .repeat(50))

	await _open_quest_board()

	# Find and accept an OFFERED quest
	var slot = null
	var slot_index = -1
	for i in range(4):
		var s = quest_board.quest_slots[i]
		if s.state == 1:  # OFFERED
			slot = s
			slot_index = i
			break

	if not slot:
		_log("  ⚠️ No OFFERED slot found, skipping...")
		await _close_quest_board()
		return

	quest_board.select_slot(slot_index)
	var quest_id = slot.quest_data.get("id", -1)
	quest_board.action_q_on_selected()  # Accept
	await get_tree().create_timer(0.3).timeout

	_assert(slot.state == 2, "ABANDON: Quest accepted (state=ACTIVE)")

	# Abandon
	var failed_before = quest_manager.failed_quests.size()
	quest_board.action_e_on_selected()  # Abandon
	await get_tree().create_timer(0.3).timeout

	var failed_after = quest_manager.failed_quests.size()
	_assert(failed_after > failed_before, "ABANDON: Quest added to failed_quests",
		"failed: %d -> %d" % [failed_before, failed_after])
	_assert(not quest_manager.active_quests.has(quest_id), "ABANDON: Quest removed from active_quests")

	await _close_quest_board()


# =============================================================================
# TEST: CLAIM AND REJECT
# =============================================================================

func _test_claim_and_reject() -> void:
	_log("")
	_log("=" .repeat(50))
	_log("TEST: Claim and Reject")
	_log("=" .repeat(50))

	# Test reject flow
	await _open_quest_board()

	# Find a SHAPE_ACHIEVE quest
	var shape_slot = null
	var shape_slot_index = -1
	for i in range(4):
		var slot = quest_board.quest_slots[i]
		if slot.state == 1 and slot.quest_data.get("type", 0) == 1:
			shape_slot = slot
			shape_slot_index = i
			break

	if not shape_slot:
		_log("  ⚠️ No SHAPE_ACHIEVE quest found, skipping reject test...")
		await _close_quest_board()
		return

	quest_board.select_slot(shape_slot_index)
	var quest_id = shape_slot.quest_data.get("id", -1)

	# Accept
	quest_board.action_q_on_selected()
	await get_tree().create_timer(0.3).timeout

	# Manually mark ready
	quest_manager.mark_quest_ready(quest_id, "test")
	await get_tree().create_timer(0.3).timeout

	_assert(shape_slot.state == 3, "REJECT: Quest is READY")

	# Reject
	var failed_before = quest_manager.failed_quests.size()
	var completed_before = quest_manager.completed_quests.size()
	quest_board.action_e_on_selected()  # Reject
	await get_tree().create_timer(0.3).timeout

	var failed_after = quest_manager.failed_quests.size()
	var completed_after = quest_manager.completed_quests.size()

	_assert(failed_after > failed_before, "REJECT: Quest added to failed_quests",
		"failed: %d -> %d" % [failed_before, failed_after])
	_assert(completed_after == completed_before, "REJECT: Quest NOT added to completed_quests",
		"completed: %d -> %d" % [completed_before, completed_after])
	_assert(not quest_manager.active_quests.has(quest_id), "REJECT: Quest removed from active_quests")

	await _close_quest_board()
