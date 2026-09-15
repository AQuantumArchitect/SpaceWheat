extends "res://tests/smoke_test_base.gd"

## ClickLadder — one meaning for a click on information chips.
## HUD popups skip DETAIL (tracker + link: home then scoot). DETAIL remains
## for unique copy that has no menu home. Action chips stay immediate.


class StubOM:
	extends Node
	var homes: Array = []
	var scoots: Array = []
	func open_controls_on_arc() -> void:
		homes.append("arc")
	func open_board_on_commitments(quest_id: int = -1, view: String = "active") -> void:
		homes.append(["board", quest_id, view])
	func scoot_toward(biome: String = "") -> void:
		scoots.append(biome)
	func toggle_overlay(_name: String) -> void:
		pass


class HeldStub:
	extends Node
	var rows: Array = []
	func commitment_quests() -> Array:
		return rows


func _init() -> void:
	call_deferred("_run")


func _tap() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev


func _run() -> void:
	print("\n=== ClickLadder smoke ===")
	_check_ladder_unit()
	await _check_banner()
	_check_market_stalls()
	await _check_session_chrome_reset()
	_finish("ClickLadder smoke")


func _check_ladder_unit() -> void:
	var ladder := ClickLadder.new()
	_check(ladder.next_action() == "expand", "face with detail expands")
	ladder.commit("expand")
	_check(ladder.prompt() == ClickLadder.home_prompt("the Arc"),
		"after expand, prompt names the home")
	_check(ladder.next_action() == "home", "second click is home")
	ladder.commit("home")
	_check(ladder.next_action() == "scoot", "third click is scoot")
	ladder.commit("scoot")
	_check(ladder.next_action() == "flatten", "after scoot the ladder is done")

	var no_detail := ClickLadder.new()
	no_detail.has_detail = false
	_check(no_detail.next_action() == "home", "no-detail face skips expand")
	_check(no_detail.prompt() == ClickLadder.tap_home("the Arc"),
		"no-detail face invites the home, not tap-again")
	no_detail.commit("home")
	no_detail.has_scoot = false
	_check(no_detail.next_action() == "flatten", "home without scoot flattens")

	var board := ClickLadder.new()
	board.has_detail = false
	board.home_name = "the board"
	_check(board.prompt() == "[C] opens the board",
		"board home names the C key for keyboard players")
	_check(ClickLadder.tap_home("the Arc") == "tap to open the Arc",
		"Arc (unmapped) keeps the tap line")
	_check(ClickLadder.tap_home("the board") == "[C] opens the board",
		"tap_home('the board') resolves to C")


func _check_banner() -> void:
	var om := StubOM.new()
	root.add_child(om)
	var banner := ActFilament.new()
	root.add_child(banner)
	banner.setup(null, null, om)
	await process_frame
	banner._gui_input(_tap())
	_check(om.homes.is_empty(), "field-ask banner is a label — tap does not open Arc")
	_check(om.scoots.is_empty(), "banner does not scoot")
	banner.queue_free()
	om.queue_free()


func _check_market_stalls() -> void:
	var board := QuestBoard.new()
	root.add_child(board)
	var stub := HeldStub.new()
	stub.rows = [
		{"id": 1, "faction": "Mill", "resource": "🌾", "quantity": 2, "status": "active"},
		{"id": 2, "faction": "Mill", "resource": "🍞", "quantity": 1, "status": "ready"},
	]
	root.add_child(stub)
	board.quest_manager = stub
	board._offer_pool = []
	for i in range(10):
		board._offer_pool.append({
			"id": 100 + i, "faction": "Test", "resource": "🪵", "quantity": 10 - i,
			"reward_resources": {"🍞": 1.0},
		})
	board.set_frame(QuestBoard.FRAME_MARKET)
	board._render_all()
	var rows: Array = board._market_rows()
	_check(rows.size() == 6, "2 held + 4 free stalls (not 10 offers)",
		"got %d" % rows.size())
	_check(str(rows[0].get("kind", "")) == "held", "held pin the first stalls")
	_check(str(rows[2].get("kind", "")) == "offer", "offers fill remaining stalls")
	_check(board._held_count() == 2, "hands 2/6")
	stub.rows = stub.rows + stub.rows + stub.rows  # 6 held
	rows = board._market_rows()
	_check(rows.size() == 6, "full hands show no offers", "got %d" % rows.size())
	for r in rows:
		_check(str(r.get("kind", "")) == "held", "every stall is held when hands are full")
	board.queue_free()
	stub.queue_free()


func _check_session_chrome_reset() -> void:
	# Restart used to stack a second ContractChip on the old one. clear_farm_ui
	# must free the session chrome so RuntimeMount can mint a fresh banner.
	var shell_scene: PackedScene = load("res://UI/PlayerShell.tscn")
	if shell_scene == null:
		_check(false, "PlayerShell.tscn loads")
		return
	var shell = shell_scene.instantiate()
	root.add_child(shell)
	await process_frame
	var layer := shell.get_node_or_null("OverlayLayer")
	_check(layer != null, "PlayerShell has OverlayLayer")
	if layer == null:
		shell.queue_free()
		return
	var chip := ContractChip.new()
	chip.name = "ContractChip"
	layer.add_child(chip)
	var banner := ActFilament.new()
	banner.name = "ActFilament"
	layer.add_child(banner)
	await process_frame
	shell.clear_farm_ui()
	await process_frame
	_check(layer.get_node_or_null("ContractChip") == null,
		"clear_farm_ui frees the contract chip")
	_check(layer.get_node_or_null("ActFilament") == null,
		"clear_farm_ui frees the gold banner")
	shell.queue_free()
