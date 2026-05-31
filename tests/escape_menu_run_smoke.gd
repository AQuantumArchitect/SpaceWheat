extends SceneTree


var passed: int = 0
var failed: int = 0


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
	_check(str(verbs.get("F", "")) == "close", "Run tab treats F as close when no game is loaded")

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
		menu._show_tab(EscapeMenu.Tab.RUN)
		menu._refresh_body()
		await process_frame
		labels = _collect_label_texts(menu)
		_check(_has_text(labels, "last touched"), "Run tab switches to last-touched save when one exists")
		_check(_has_text(labels, "slot 2"), "Run tab reports the touched slot")
		_check(_has_text(labels, "scenario"), "Run tab reports the scenario for the touched slot")

	print("Result: %d passed, %d failed" % [passed, failed])
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


func _check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
		print("  PASS  %s" % label)
	else:
		failed += 1
		print("  FAIL  %s" % label)


func _fail(label: String) -> void:
	_check(false, label)


func _finish() -> void:
	quit(0 if failed == 0 else 1)


func _clear_save_dir() -> void:
	SaveStore.ensure_save_dir()
	var dir = DirAccess.open(SaveStore.SAVE_DIR)
	if not dir:
		return
	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while name != "":
		if name != "." and name != "..":
			dir.remove(name)
		name = dir.get_next()
	dir.list_dir_end()
