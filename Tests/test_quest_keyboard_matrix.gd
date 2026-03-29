#!/usr/bin/env -S godot -s
extends SceneTree

const TEST_NAME := "QUEST KEYBOARD MATRIX"

var _boot = null
var _player_shell = null
var _overlay_manager = null
var _quest_board = null
var _instrument = null
var _scene_instance: Node = null
var _action_events: Array = []
var _failures: Array[String] = []
var _passes: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("")
	print(TEST_NAME)
	if DisplayServer.get_name() == "headless" or OS.has_feature("server"):
		print("SKIP: run headed for keyboard coverage")
		quit(0)
		return

	if not await _boot_game():
		quit(1)
		return

	_connect_board_signals()
	_seed_resources()

	await _test_open_close()
	await _test_slot_hotkeys()
	await _test_directional_navigation()
	await _test_qerf_actions()
	await _test_deliver_and_claim()
	await _test_browser_keys()

	print("")
	print("Quest keyboard summary: %d passed, %d failed" % [_passes, _failures.size()])
	for failure in _failures:
		print("FAIL: %s" % failure)
	await _cleanup_scene()
	quit(1 if not _failures.is_empty() else 0)


func _boot_game() -> bool:
	var scene = load("res://scenes/FarmView.tscn")
	if not scene:
		_fail("FarmView.tscn not found")
		return false

	_scene_instance = scene.instantiate()
	get_root().add_child(_scene_instance)

	_boot = get_root().get_node_or_null("/root/BootManager")
	if not _boot:
		_fail("BootManager not found")
		return false

	await _boot.game_ready
	await _await_frames(6)

	_player_shell = _find_node(get_root(), "PlayerShell")
	if not _player_shell:
		_fail("PlayerShell not found")
		return false

	_overlay_manager = _player_shell.get("overlay_manager")
	if not _overlay_manager:
		_fail("OverlayManager missing on PlayerShell")
		return false

	_quest_board = _overlay_manager.get_overlay("quests") if _overlay_manager.has_method("get_overlay") else _overlay_manager.get("quest_board")
	if not _quest_board:
		_fail("QuestBoard overlay not found")
		return false

	_instrument = _player_shell.get("quantum_instrument")
	if not _instrument and _boot and "quantum_instrument" in _boot:
		_instrument = _boot.quantum_instrument
	if not _instrument:
		_fail("QuantumInstrument not available")
		return false

	_pass("booted live quest UI path")
	return true


func _connect_board_signals() -> void:
	if _quest_board and _quest_board.has_signal("action_performed"):
		var cb := Callable(self, "_on_action_performed")
		if not _quest_board.action_performed.is_connected(cb):
			_quest_board.action_performed.connect(cb)


func _seed_resources() -> void:
	if not _instrument:
		return
	if _instrument.has_method("set_resource"):
		_instrument.set_resource("🌲", 12, "quest_keyboard_test")
		_instrument.set_resource("🐇", 12, "quest_keyboard_test")
		_pass("seeded deterministic quest resources")


func _test_open_close() -> void:
	await _press_key(KEY_C)
	_assert_true(_quest_board.visible, "C opens quest board")

	await _press_key(KEY_ESCAPE)
	_assert_true(not _quest_board.visible, "ESC closes quest board")

	await _press_key(KEY_C)
	_assert_true(_quest_board.visible, "C reopens quest board")


func _test_slot_hotkeys() -> void:
	var key_expectations := {
		KEY_U: 0,
		KEY_I: 1,
		KEY_O: 2,
		KEY_P: 3,
	}
	for keycode in key_expectations.keys():
		await _press_key(int(keycode))
		var snapshot = _board_snapshot()
		_assert_equal(int(snapshot.get("selected_slot", -1)), int(key_expectations[keycode]), "%s selects slot %d" % [_key_name(int(keycode)), int(key_expectations[keycode])])


func _test_directional_navigation() -> void:
	await _press_key(KEY_U)
	await _press_key(KEY_RIGHT)
	_assert_selected_slot(1, "RIGHT moves U -> I")
	await _press_key(KEY_DOWN)
	_assert_selected_slot(3, "DOWN moves I -> P")
	await _press_key(KEY_LEFT)
	_assert_selected_slot(2, "LEFT moves P -> O")
	await _press_key(KEY_UP)
	_assert_selected_slot(0, "UP moves O -> U")

	await _press_key(KEY_S)
	_assert_selected_slot(2, "S moves U -> O")
	await _press_key(KEY_D)
	_assert_selected_slot(3, "D moves O -> P")
	await _press_key(KEY_W)
	_assert_selected_slot(1, "W moves P -> I")
	await _press_key(KEY_A)
	_assert_selected_slot(0, "A moves I -> U")


func _test_qerf_actions() -> void:
	await _ensure_board_open()
	var snapshot = _board_snapshot()
	var slots: Array = snapshot.get("slots", [])
	if slots.is_empty():
		_fail("quest board has no slots")
		return

	var offered_index := _find_slot_index(slots, "offered")
	if offered_index < 0:
		_fail("no offered quest slot found for Q/E/R testing")
		return

	await _select_board_slot(offered_index)
	var pre_q_snapshot = _board_snapshot()
	var pre_q_state = _slot_state(pre_q_snapshot, offered_index)
	_action_events.clear()
	await _press_key(KEY_Q)
	var post_q_snapshot = _board_snapshot()
	var post_q_state = _slot_state(post_q_snapshot, offered_index)
	_assert_true(pre_q_state == "offered", "Q test starts from offered quest")
	_assert_true(post_q_state != "offered", "Q accepts offered quest")
	_assert_action_event("quest_action_q", "Q emits quest action event")

	snapshot = _board_snapshot()
	slots = snapshot.get("slots", [])
	var lock_index := _find_slot_index(slots, "offered")
	if lock_index < 0:
		_fail("no offered quest slot found for E/R testing after Q accept")
		return

	await _select_board_slot(lock_index)
	var tree_before_lock := _resource_amount("🌲")
	_action_events.clear()
	await _press_key(KEY_E)
	var locked_snapshot = _board_snapshot()
	_assert_true(_slot_locked(locked_snapshot, lock_index), "E locks offered quest")
	_assert_equal(_resource_amount("🌲"), tree_before_lock - 1, "locking spends 1 🌲")
	_assert_action_event("quest_action_e", "E emits quest action event")

	var tree_before_unlock := _resource_amount("🌲")
	_action_events.clear()
	await _press_key(KEY_E)
	var unlocked_snapshot = _board_snapshot()
	_assert_true(not _slot_locked(unlocked_snapshot, lock_index), "E unlocks locked quest")
	_assert_equal(_resource_amount("🌲"), tree_before_unlock, "unlock is free")
	_assert_action_event("quest_action_e", "unlock emits quest action event")

	var rabbits_before_r := _resource_amount("🐇")
	_action_events.clear()
	await _press_key(KEY_R)
	var rerolled_snapshot = _board_snapshot()
	_assert_equal(_resource_amount("🐇"), rabbits_before_r - 1, "R refresh spends 1 🐇")
	_assert_true(_slot_state(rerolled_snapshot, lock_index) == "offered", "R keeps selected slot offered")
	_assert_action_event("quest_action_r", "R emits quest action event")

	var page_before = int(rerolled_snapshot.get("current_page", 0))
	var total_pages = maxi(1, int(rerolled_snapshot.get("total_pages", 1)))
	_action_events.clear()
	await _press_key(KEY_F)
	var paged_snapshot = _board_snapshot()
	_assert_equal(int(paged_snapshot.get("current_page", -1)), (page_before + 1) % total_pages, "F advances quest page")
	_assert_action_event("quest_next_page", "F emits page action event")

	await _ensure_board_open()
	var before_refresh_all = _board_snapshot()
	var unlocked_offers := _count_all_unlocked_offers()
	if unlocked_offers <= 0:
		_fail("no unlocked offers found for Shift+R test")
		return
	var rabbits_before_all := _resource_amount("🐇")
	await _press_key(KEY_R, true)
	var after_refresh_all = _board_snapshot()
	_assert_equal(_resource_amount("🐇"), rabbits_before_all - unlocked_offers, "Shift+R spends 1 🐇 per unlocked offer")
	_assert_true(after_refresh_all is Dictionary and not after_refresh_all.is_empty(), "Shift+R keeps board snapshot valid")


func _test_deliver_and_claim() -> void:
	await _ensure_board_open()

	if not await _assign_slot_quest_by_type(0, true):
		_fail("could not assign delivery quest for deliver coverage")
	else:
		await _select_board_slot(0)
		var delivery_slot = _slot_dict(0)
		var delivery_resource = str(delivery_slot.get("resource", ""))
		var delivery_qty = int(delivery_slot.get("quantity", 0))
		_action_events.clear()
		await _press_key(KEY_Q)
		var active_snapshot = _board_snapshot()
		_assert_true(_slot_state(active_snapshot, 0) == "active", "Q turns delivery offer active")
		if delivery_resource != "" and delivery_qty > 0 and _instrument and _instrument.has_method("set_resource"):
			_instrument.set_resource(delivery_resource, delivery_qty, "quest_keyboard_test_deliver")
		_action_events.clear()
		await _press_key(KEY_Q)
		var delivered_snapshot = _board_snapshot()
		_assert_true(_slot_state(delivered_snapshot, 0) != "active", "Q delivers active delivery quest")
		_assert_action_event("quest_action_q", "Q emits quest action for delivery")

	if not await _assign_slot_quest_by_type(1, false):
		_fail("could not assign non-delivery quest for claim coverage")
	else:
		await _select_board_slot(1)
		var claim_slot = _slot_dict(1)
		var claim_quest_id = int(claim_slot.get("quest_id", -1))
		_action_events.clear()
		await _press_key(KEY_Q)
		var accepted_snapshot = _board_snapshot()
		var accepted_state = _slot_state(accepted_snapshot, 1)
		_assert_true(accepted_state == "active" or accepted_state == "ready", "Q turns non-delivery offer active or ready")
		if _quest_board and _quest_board.quest_manager and claim_quest_id >= 0:
			_quest_board.quest_manager.mark_quest_ready(claim_quest_id, "quest_keyboard_test")
			await _await_frames(2)
		var ready_reached = await _wait_for_slot_state(1, "ready", 12)
		_assert_true(ready_reached, "non-delivery quest reaches ready state")
		_action_events.clear()
		await _press_key(KEY_Q)
		var claimed_snapshot = _board_snapshot()
		_assert_true(_slot_state(claimed_snapshot, 1) != "ready", "Q claims ready non-delivery quest")
		_assert_action_event("quest_action_q", "Q emits quest action for claim")


func _test_browser_keys() -> void:
	await _ensure_board_open()
	await _press_key(KEY_C)
	var browser = _browser_ref()
	if browser and browser.visible:
		_pass("C opens faction browser from quest board")
	else:
		_fail("C should open faction browser from quest board")
		await _ensure_board_open()
		_quest_board.open_faction_browser()
		await _await_frames(3)
		browser = _browser_ref()

	if not browser or not browser.visible:
		_fail("faction browser unavailable for keyboard coverage")
		return

	var browser_snapshot = browser.get_snapshot()
	var faction_count = int(browser_snapshot.get("faction_count", 0))
	_assert_true(faction_count > 0, "browser shows accessible factions")

	if faction_count > 1:
		await _press_key(KEY_P)
		_assert_equal(int(browser.get_snapshot().get("selected_index", -1)), 1, "browser P moves selection +1")
		await _press_key(KEY_U)
		_assert_equal(int(browser.get_snapshot().get("selected_index", -1)), 0, "browser U moves selection -1")

	var before_i = int(browser.get_snapshot().get("selected_index", 0))
	await _press_key(KEY_I)
	_assert_equal(int(browser.get_snapshot().get("selected_index", 0)), maxi(before_i - 3, 0), "browser I moves -3")

	var before_o = int(browser.get_snapshot().get("selected_index", 0))
	await _press_key(KEY_O)
	_assert_equal(int(browser.get_snapshot().get("selected_index", 0)), mini(before_o + 3, maxi(faction_count - 1, 0)), "browser O moves +3")

	var before_pg = int(browser.get_snapshot().get("selected_index", 0))
	await _press_key(KEY_PAGEDOWN)
	var after_pg = int(browser.get_snapshot().get("selected_index", 0))
	_assert_equal(after_pg, mini(before_pg + 3, maxi(faction_count - 1, 0)), "browser PgDown moves +3")
	await _press_key(KEY_PAGEUP)
	_assert_true(int(browser.get_snapshot().get("selected_index", 0)) <= after_pg, "browser PgUp moves back or clamps")

	await _press_key(KEY_C)
	_assert_true(not browser.visible, "browser C closes faction browser")

	_quest_board.open_faction_browser()
	await _await_frames(3)
	browser = _browser_ref()
	_assert_true(browser and browser.visible, "browser can reopen programmatically for select test")
	await _press_key(KEY_ESCAPE)
	_assert_true(not _browser_ref().visible, "ESC closes faction browser")

	_quest_board.open_faction_browser()
	await _await_frames(3)
	browser = _browser_ref()
	_assert_true(browser and browser.visible, "browser can reopen programmatically for select/enter test")
	await _press_key(KEY_ENTER)
	_assert_true(not _browser_ref().visible, "Enter selects faction and closes browser")

	await _ensure_board_open()


func _cleanup_scene() -> void:
	if _scene_instance and is_instance_valid(_scene_instance):
		if _scene_instance.get_parent():
			_scene_instance.get_parent().remove_child(_scene_instance)
		_scene_instance.queue_free()
		await _await_frames(4)


func _find_node(root: Node, target_name: String) -> Node:
	if root.name == target_name:
		return root
	for child in root.get_children():
		var found = _find_node(child, target_name)
		if found:
			return found
	return null


func _resolve_quantum_input():
	if not _player_shell:
		return null
	var direct = _player_shell.get_node_or_null("QuantumInstrumentInput")
	if direct:
		return direct
	return _player_shell.find_child("QuantumInstrumentInput", true, false)


func _route_key_event(event: InputEventKey) -> void:
	var viewport: Viewport = get_root()
	if _player_shell and _player_shell.has_method("_input"):
		_player_shell._input(event)
		if viewport and viewport.is_input_handled():
			return
	var qinput = _resolve_quantum_input()
	if qinput and qinput.has_method("_unhandled_key_input"):
		qinput._unhandled_key_input(event)
		if viewport and viewport.is_input_handled():
			return
	if qinput and qinput.has_method("_input"):
		qinput._input(event)


func _press_key(keycode: int, shift: bool = false, settle_frames: int = 3) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	press.echo = false
	press.shift_pressed = shift
	_route_key_event(press)

	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	release.echo = false
	release.shift_pressed = shift
	_route_key_event(release)

	await _await_frames(settle_frames)


func _await_frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _board_snapshot() -> Dictionary:
	if _quest_board and _quest_board.visible and _quest_board.has_method("get_snapshot"):
		var snapshot = _quest_board.get_snapshot()
		return snapshot if snapshot is Dictionary else {}
	return {}


func _browser_ref():
	if _quest_board and "faction_browser" in _quest_board:
		return _quest_board.faction_browser
	return null


func _ensure_board_open() -> void:
	if _quest_board and _quest_board.visible:
		return
	await _press_key(KEY_C)
	await _await_frames(2)


func _select_board_slot(slot_index: int) -> void:
	match slot_index:
		0:
			await _press_key(KEY_U)
		1:
			await _press_key(KEY_I)
		2:
			await _press_key(KEY_O)
		3:
			await _press_key(KEY_P)


func _resource_amount(emoji: String) -> int:
	if not _instrument or not _instrument.has_method("get_resource_snapshot"):
		return 0
	var snapshot = _instrument.get_resource_snapshot()
	if not (snapshot is Dictionary):
		return 0
	var resources = snapshot.get("resources", {})
	if not (resources is Dictionary):
		return 0
	return int(resources.get(emoji, 0))


func _get_browser_quest_index(want_delivery: bool) -> int:
	var browser = _browser_ref()
	if not browser:
		return -1
	for i in range(browser.faction_items.size()):
		var item = browser.faction_items[i]
		if not item or not ("quest_data" in item):
			continue
		var quest_type = int(item.quest_data.get("type", 0))
		if want_delivery and quest_type == 0:
			return i
		if not want_delivery and quest_type != 0:
			return i
	return -1


func _set_browser_selection(target_index: int) -> void:
	var browser = _browser_ref()
	if not browser:
		return
	browser.selected_faction_index = clampi(target_index, 0, browser.faction_items.size() - 1)
	browser._update_selection()


func _assign_slot_quest_by_type(slot_index: int, want_delivery: bool) -> bool:
	await _ensure_board_open()
	await _select_board_slot(slot_index)
	if not _quest_board:
		return false
	for _attempt in range(6):
		_quest_board.open_faction_browser()
		await _await_frames(3)
		var browser = _browser_ref()
		if not browser or not browser.visible:
			return false
		var target_index = _get_browser_quest_index(want_delivery)
		if target_index >= 0:
			_set_browser_selection(target_index)
			await _press_key(KEY_ENTER)
			await _await_frames(3)
			var slot = _slot_dict(slot_index)
			var quest_type = int(slot.get("type", 0))
			return quest_type == 0 if want_delivery else quest_type != 0
		browser.close_browser()
		await _await_frames(2)
	return false


func _find_slot_index(slots: Array, state_name: String) -> int:
	for slot in slots:
		if slot is Dictionary and str(slot.get("state", "")) == state_name:
			return int(slot.get("index", -1))
	return -1


func _slot_state(snapshot: Dictionary, slot_index: int) -> String:
	var slots: Array = snapshot.get("slots", [])
	for slot in slots:
		if slot is Dictionary and int(slot.get("index", -1)) == slot_index:
			return str(slot.get("state", ""))
	return ""


func _slot_dict(slot_index: int) -> Dictionary:
	var slots: Array = _board_snapshot().get("slots", [])
	for slot in slots:
		if slot is Dictionary and int(slot.get("index", -1)) == slot_index:
			return slot
	return {}


func _slot_locked(snapshot: Dictionary, slot_index: int) -> bool:
	var slots: Array = snapshot.get("slots", [])
	for slot in slots:
		if slot is Dictionary and int(slot.get("index", -1)) == slot_index:
			return bool(slot.get("is_locked", false))
	return false


func _count_unlocked_offers(snapshot: Dictionary) -> int:
	var slots: Array = snapshot.get("slots", [])
	var count := 0
	for slot in slots:
		if slot is Dictionary and str(slot.get("state", "")) == "offered" and not bool(slot.get("is_locked", false)):
			count += 1
	return count


func _count_all_unlocked_offers() -> int:
	if _quest_board and _quest_board.has_method("_count_unlocked_offers_all_pages"):
		return int(_quest_board._count_unlocked_offers_all_pages())
	return _count_unlocked_offers(_board_snapshot())


func _assert_selected_slot(expected: int, label: String) -> void:
	var snapshot = _board_snapshot()
	_assert_equal(int(snapshot.get("selected_slot", -1)), expected, label)


func _wait_for_slot_state(slot_index: int, expected_state: String, frames: int) -> bool:
	for _i in range(frames):
		if _slot_state(_board_snapshot(), slot_index) == expected_state:
			return true
		await _await_frames(1)
	return _slot_state(_board_snapshot(), slot_index) == expected_state


func _assert_action_event(action_name: String, label: String) -> void:
	_assert_true(action_name in _action_events, label)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		_pass(label)
	else:
		_fail(label)


func _assert_equal(actual, expected, label: String) -> void:
	if actual == expected:
		_pass(label)
	else:
		_fail("%s (expected=%s actual=%s)" % [label, str(expected), str(actual)])


func _pass(label: String) -> void:
	_passes += 1
	print("PASS: %s" % label)


func _fail(label: String) -> void:
	_failures.append(label)
	printerr("FAIL: %s" % label)


func _on_action_performed(action: String, _data: Dictionary) -> void:
	_action_events.append(action)


func _key_name(keycode: int) -> String:
	match keycode:
		KEY_U: return "U"
		KEY_I: return "I"
		KEY_O: return "O"
		KEY_P: return "P"
		_: return str(keycode)
