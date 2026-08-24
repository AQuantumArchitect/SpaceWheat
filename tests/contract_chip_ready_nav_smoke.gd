extends "res://tests/smoke_test_base.gd"

## ContractChip ready-glow navigation (Wave 2.2) — the chip "glows when one is
## ready to claim", but its tap could only focus a biome: the one always-on
## ready indicator invited a click that couldn't reach the claim. Now a READY
## row's tap opens the quest board on its own Commitments row through
## OverlayManager.open_board_on_commitments (navigation ONLY — the claim stays
## a deliberate click on the board), while a non-ready row keeps the old
## biome-focus behavior and a null overlay_manager (old mocks) degrades to it.

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
		# READY row (biome-less predicate quest — a dead row before this fix):
		# tap routes to the board with its own quest id, and does NOT claim.
		rows[0].gui_input.emit(_tap())
		await process_frame
		_check(om.calls.size() == 1, "ready row tap opens the board door",
			"got %d calls" % om.calls.size())
		if om.calls.size() == 1:
			_check(int(om.calls[0][0]) == 3001, "door receives the ready quest's id",
				"got %s" % str(om.calls[0][0]))
			_check(str(om.calls[0][1]) == "active", "door lands on the active view",
				"got %s" % str(om.calls[0][1]))
		_check(str(rows[0].tooltip_text) == "Tap to claim on the board",
			"ready row says where its tap goes", "got %s" % rows[0].tooltip_text)

		# Non-ready row: biome-focus behavior, no board door.
		rows[1].gui_input.emit(_tap())
		await process_frame
		_check(om.calls.size() == 1, "non-ready row tap does NOT open the board",
			"got %d calls" % om.calls.size())
		_check(str(rows[1].tooltip_text) == "Tap to focus TestBiome",
			"non-ready row keeps the biome-focus tooltip", "got %s" % rows[1].tooltip_text)

	# Null overlay_manager (old mocks / partial boots): ready tap degrades to
	# the biome path without erroring.
	var bare := ContractChip.new()
	root.add_child(bare)
	bare.setup(qm)
	await process_frame
	await process_frame
	var bare_rows := _quest_rows(bare)
	if bare_rows.size() >= 1:
		bare_rows[0].gui_input.emit(_tap())
		await process_frame
	_check(om.calls.size() == 1, "null overlay_manager never reaches the door",
		"got %d calls" % om.calls.size())

	chip.queue_free()
	bare.queue_free()
	qm.queue_free()
	om.queue_free()
	_finish("ContractChip ready-nav")
