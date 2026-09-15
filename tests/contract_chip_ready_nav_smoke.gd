extends "res://tests/smoke_test_base.gd"

## ContractChip ClickLadder (2026-09-09) — tracker + link. First tap is HOME
## (OverlayManager.open_board_on_commitments); second scoots. The how lives
## on the board, not on the chip. A null overlay_manager skips HOME.

class StubQM:
	extends Node
	var rows: Array = []
	func commitment_quests() -> Array:
		return rows


class StubOM:
	extends Node
	var calls: Array = []
	func open_board_on_commitments(quest_id: int = -1, view: String = "active") -> void:
		calls.append([quest_id, view])


func _init() -> void:
	call_deferred("_run")


func _tap() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev


func _quest_rows(chip) -> Array:
	var out: Array = []
	for child in chip._rows_box.get_children():
		if child is VBoxContainer:
			out.append(child)
	return out


func _run() -> void:
	print("\n=== ContractChip ready-nav smoke ===")

	var qm := StubQM.new()
	qm.rows = [
		{"id": 3001, "faction": "TestFaction", "status": "ready",
			"display_name": "ready predicate", "category": "ARC"},
		{"id": 3002, "faction": "TestFaction", "resource": "🌾", "quantity": 2,
			"status": "active", "biome": "TestBiome", "category": "DELIVERY"},
	]
	root.add_child(qm)
	var om := StubOM.new()
	root.add_child(om)

	var chip := ContractChip.new()
	root.add_child(chip)
	chip.setup(qm, om)
	await process_frame
	await process_frame

	var rows := _quest_rows(chip)
	_check(rows.size() == 2, "chip renders both quest rows", "got %d" % rows.size())
	if rows.size() == 2:
		_check(str(rows[0].tooltip_text).contains("[C] opens the board"),
			"face names the C key, not tap", "got %s" % rows[0].tooltip_text)
		# Click 1: HOME — opens the board on this quest.
		rows[0].gui_input.emit(_tap())
		await process_frame
		_check(om.calls.size() == 1, "first tap opens the board door",
			"got %d calls" % om.calls.size())
		if om.calls.size() == 1:
			_check(int(om.calls[0][0]) == 3001, "door receives the ready quest's id",
				"got %s" % str(om.calls[0][0]))
			_check(str(om.calls[0][1]) == "active", "door lands on live Commitments",
				"got %s" % str(om.calls[0][1]))
		rows = _quest_rows(chip)
		_check(str(rows[0].tooltip_text).contains("tap again to go there")
				or str(rows[0].tooltip_text).contains("tap to go there"),
			"after home, the chip invites the scoot", "got %s" % rows[0].tooltip_text)

		# Other row's first tap is also HOME (its own door), not a reprint.
		rows = _quest_rows(chip)
		rows[1].gui_input.emit(_tap())
		await process_frame
		_check(om.calls.size() == 2, "other row's first tap opens its board door",
			"got %d calls" % om.calls.size())

	# Null overlay_manager (old mocks / partial boots): never reaches the door.
	var bare := ContractChip.new()
	root.add_child(bare)
	bare.setup(qm)
	await process_frame
	await process_frame
	var bare_rows := _quest_rows(bare)
	if bare_rows.size() >= 1:
		bare_rows[0].gui_input.emit(_tap())
		await process_frame
	_check(om.calls.size() == 2, "null overlay_manager never reaches the door",
		"got %d calls" % om.calls.size())

	chip.queue_free()
	bare.queue_free()
	qm.queue_free()
	om.queue_free()
	_finish("ContractChip ready-nav")
