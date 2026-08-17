extends "res://tests/smoke_test_base.gd"


class EconStub:
	var emoji_credits: Dictionary = {}


class FarmStub:
	extends Node
	var economy = EconStub.new()
	var story_flags_fired: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== Escape menu run smoke ===")

	var gsm = root.get_node_or_null("/root/GameStateManager")
	if gsm == null:
		_fail("GameStateManager autoload available")
		_finish()
		return

	_clear_save_dir()

	# Start from a clean state: no touched save slot yet.
	gsm.last_active_slot = -1
	if "session_load_slot" in gsm:
		gsm.session_load_slot = -1

	var menu := EscapeMenu.new()
	root.add_child(menu)
	await process_frame
	menu.activate()
	await process_frame

	var labels := _collect_label_texts(menu)
	_check(_has_text(labels, "default run"), "Run tab shows a default-run row when no saves exist")
	_check(_has_text(labels, "The Demos"), "Run tab defaults to The Demos")
	_check(_has_text(labels, "demos_normal"), "Run tab exposes the demos scenario id")
	var verbs := menu._current_verb_labels()
	_check(str(verbs.get("R", "")) == "", "Run tab blanks R when no game is loaded")
	_check(str(verbs.get("F", "")) == "play", "Run tab treats F as play when no game is loaded")

	menu._show_tab(EscapeMenu.Tab.NEW)
	await process_frame
	labels = _collect_label_texts(menu)
	_check(_first_index(labels, "The Demos") >= 0, "New tab exposes The Demos")
	_check(_first_index(labels, "Easy Farm") >= 0, "New tab exposes the easy-start scenario")
	_check(_first_index(labels, "The Demos") < _first_index(labels, "Easy Farm"), "The Demos is first in the New tab")

	var demo_state = SaveStore.load_scenario("demos_normal")
	_check(demo_state != null, "demo scenario loads for save-slot projection")
	if demo_state != null:
		var save_result = SaveStore.save_state(demo_state, 1)
		_check(save_result == OK, "demo scenario can be written to slot 2")
		gsm.last_active_slot = 1
		if "session_load_slot" in gsm:
			gsm.session_load_slot = 1
		_check(menu._pick_auto_save_slot(gsm, EscapeMenu.PendingAction.RESTART) == 1, "Restart autosave prefers the last touched slot")
		# QUIT used to read a property that does not exist (`last_saved_slot`),
		# so it always resolved to 0 — a save-and-quit from slot 2 overwrote
		# slot 1. Both actions must target the slot the run came from.
		_check(menu._pick_auto_save_slot(gsm, EscapeMenu.PendingAction.QUIT) == 1, "Quit autosave targets the last touched slot, not slot 0")
		menu._show_tab(EscapeMenu.Tab.RUN)
		menu._refresh_body()
		await process_frame
		labels = _collect_label_texts(menu)
		_check(_has_text(labels, "last touched"), "Run tab switches to last-touched save when one exists")
		_check(_has_text(labels, "slot 2"), "Run tab reports the touched slot")
		_check(_has_text(labels, "scenario"), "Run tab reports the scenario for the touched slot")

	# --- Autosave ring (Save tab) ---
	menu._show_tab(EscapeMenu.Tab.KEEP)
	await process_frame
	labels = _collect_label_texts(menu)
	_check(_has_text(labels, "autosaves"), "Save tab shows the autosaves section")
	_check(_has_text(labels, "auto 1"), "Save tab lists autosave ring slots")

	_check(SaveStore.pick_next_auto_slot() == 0, "Empty ring rotates from slot 0")
	if demo_state != null:
		_check(SaveStore.save_state_to_path(demo_state, SaveStore.get_auto_save_path(0)) == OK, "Ring slot 0 writes")
		_check(SaveStore.pick_next_auto_slot() == 1, "Ring rotation advances past written slots")
		_check(SaveStore.newest_auto_slot() == 0, "Newest-autosave lookup finds the fresh write")

	menu._keep_slot = EscapeMenu.NUM_KEEP_SLOTS  # first auto row
	var keep_verbs := menu._current_verb_labels()
	_check(str(keep_verbs.get("R", "x")) == "", "R (save) blanks on read-only autosave rows")
	_check(str(keep_verbs.get("Q", "")) == "load slot", "Q (load) stays live on autosave rows")
	menu._keep_slot = 0

	# --- Quit-confirm session summary ---
	gsm.session_baseline = {}
	_check(menu._confirm_body(EscapeMenu.PendingAction.QUIT) == "Unsaved progress will be lost.",
		"Quit confirm falls back to the plain warning without a baseline")

	var stub := FarmStub.new()
	stub.story_flags_fired = {"first_breath": 1, "village_stirs": 2}
	stub.economy.emoji_credits = {"🌾": 50, "💰": 12, "🐺": 3, "🌱": 2}
	root.add_child(stub)
	var prev_farm = gsm.active_farm
	gsm.active_farm = stub
	gsm.session_baseline = {
		"wallet": {"🌾": 9, "💰": 12, "🌱": 5},
		"flags": {"first_breath": 1},
		"start_ms": Time.get_ticks_msec() - 120000,
	}
	var body: String = menu._confirm_body(EscapeMenu.PendingAction.QUIT)
	_check(body.begins_with("This session:"), "Quit confirm leads with the session card when a baseline exists")
	_check(body.find("⏱ 2 min") >= 0, "Session card reports elapsed minutes")
	_check(body.find("🚩 1 story beat") >= 0, "Session card counts only flags fired this session")
	_check(body.find("🌾+41") >= 0, "Session card shows the top resource gain")
	_check(body.find("🐺+3") >= 0, "Session card shows smaller gains")
	_check(body.find("🌱") < 0, "Spent resources do not appear as gains")
	_check(body.find("💰") < 0, "Unchanged resources do not appear as gains")
	_check(body.find("Unsaved progress will be lost.") >= 0, "Quit confirm keeps the unsaved warning")
	gsm.active_farm = prev_farm
	gsm.session_baseline = {}
	stub.queue_free()

	# --- No-brainer save-continue safety net (2026-08-17) ---
	# The title screen's F/R/Enter/Space/click now bypass save detection
	# entirely (AppRoot._input / _start_fresh_demo) — RUN tab's F here is
	# the DELIBERATE "continue" a player only reaches by opening X on
	# purpose. It still must not silently drop that player into a save
	# with nothing in it: _save_looks_meaningful gates that into a
	# redirect confirm instead of a silent load. NOT game_time (dead —
	# exported but never incremented anywhere in the codebase, always
	# 0.0) — story_flags_fired.size(), since Act 0 fires first_harvest
	# within the first real minute of play.
	_check(menu._save_looks_meaningful({"compatible": true, "flags_fired": 0}) == false,
		"a save with no flags fired does not look meaningful")
	_check(menu._save_looks_meaningful({"compatible": true, "flags_fired": 3}) == true,
		"a save with flags fired looks meaningful")
	_check(menu._save_looks_meaningful({"compatible": false, "flags_fired": 99}) == false,
		"an incompatible save never looks meaningful, however many flags it claims")

	_clear_save_dir()
	var empty_scenario := SaveStore.load_scenario("demos_normal")
	if empty_scenario != null:
		_check(empty_scenario.story_flags_fired.is_empty(),
			"a freshly loaded scenario template starts with no flags fired")
		_check(SaveStore.save_state(empty_scenario, 0) == OK, "empty-progress save writes to slot 0")
		gsm.last_active_slot = -1
		if "session_load_slot" in gsm:
			gsm.session_load_slot = -1
		gsm.active_farm = null
		gsm.current_state = null
		menu._show_tab(EscapeMenu.Tab.RUN)
		# _continue_or_play must NOT reach load_and_apply here — that tears
		# down and restarts the whole app (AppRoot.restart_from_pending_boot),
		# which this bare-EscapeMenu smoke has no AppRoot to survive.
		await menu._continue_or_play()
		_check(menu._pending_action == EscapeMenu.PendingAction.EMPTY_SAVE_REDIRECT,
			"RUN tab F on a flagless save arms the redirect confirm instead of silently loading it")
		var redirect_verbs := menu._confirm_verb_labels()
		_check(str(redirect_verbs.get("F", "")) == "start The Demos",
			"the redirect confirm's F starts The Demos")
		_check(str(redirect_verbs.get("Q", "")) == "cancel", "the redirect confirm's Q cancels, never confirms")
		menu._dismiss_confirm()

	_finish()


func _collect_label_texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	_collect_label_texts_recursive(node, out)
	return out


func _collect_label_texts_recursive(node: Node, out: Array[String]) -> void:
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		_collect_label_texts_recursive(child, out)


func _has_text(texts: Array[String], needle: String) -> bool:
	for text in texts:
		if str(text).find(needle) >= 0:
			return true
	return false


func _first_index(texts: Array[String], needle: String) -> int:
	for i in range(texts.size()):
		if str(texts[i]).find(needle) >= 0:
			return i
	return -1



func _clear_save_dir() -> void:
	SaveStore.ensure_save_dir()
	var dir = DirAccess.open(SaveStore.SAVE_DIR)
	if not dir:
		return
	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while entry_name != "":
		if entry_name != "." and entry_name != "..":
			dir.remove(entry_name)
		entry_name = dir.get_next()
	dir.list_dir_end()
