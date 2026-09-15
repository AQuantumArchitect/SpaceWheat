extends "res://tests/smoke_test_base.gd"

## QuestBoard item paging — the six GHJKL; keys must be able to reach EVERY row
## of a longer list, not just the first six.
##
## Regression guard for the 2026-08-10 fix: Manifold / Market / History each
## rendered exactly MAX_VISIBLE_ITEMS rows and then printed "… N more not shown".
## 2026-09-09: Market is a stall board — held pin the ring, offers fill the
## free hands (HANDS_MAX = 6). Offers no longer page independently.


class StubQuestManager:
	extends Node
	var rows: Array = []
	func commitment_quests() -> Array:
		return rows


func _init() -> void:
	call_deferred("_run")


func _make_commitments(n: int) -> Array:
	var out: Array = []
	for i in range(n):
		out.append({
			"id": 2000 + i,
			"faction": "TestFaction",
			"resource": "🌾",
			"quantity": i + 1,
			"status": "active",
			"category": "DELIVERY",
		})
	return out


func _make_offers(n: int) -> Array:
	# Distinct descending quantities so MAGNITUDE sort is a stable identity map:
	# offer i lands at index i, and a page's contents are exactly predictable.
	var out: Array = []
	for i in range(n):
		out.append({
			"id": 1000 + i,
			"faction": "TestFaction",
			"resource": "🌾",
			"quantity": n - i,
			"tension": 0.0,
			"reward_resources": {"🍞": 1.0},
		})
	return out


func _visible_row_names(board) -> Array:
	var names: Array = []
	for child in board._body_box.get_children():
		if str(child.name).begins_with("BoardRow_"):
			names.append(str(child.name))
	return names


func _quantities_on_page(board) -> Array:
	# Quantities on the live stall board (held + free-hand offers).
	var rows: Array = board._market_rows()
	var start: int = board._item_page * board.MAX_VISIBLE_ITEMS
	var out: Array = []
	for i in range(board.MAX_VISIBLE_ITEMS):
		if start + i < rows.size():
			var data = rows[start + i].get("data", {})
			out.append(int(data.get("quantity", -1)) if data is Dictionary else -1)
	return out


func _run() -> void:
	print("\n=== QuestBoard item paging smoke ===")

	var board := QuestBoard.new()
	root.add_child(board)
	await process_frame
	board.activate()
	await process_frame

	board.set_frame(QuestBoard.FRAME_MARKET)
	board._market_sort_mode = MarketView.SortMode.MAGNITUDE
	board._offer_pool = _make_offers(15)
	board._render_all()
	await process_frame

	# --- stall cap: 15 offers and empty hands fill exactly 6 stalls --------
	_check(board._current_row_count() == 6, "empty hands show 6 offer stalls, not the 15-deep pool",
		"got %d" % board._current_row_count())
	_check(board._item_page_count(6) == 1, "six stalls fit on one page",
		"got %d" % board._item_page_count(6))
	_check(board._item_page == 0, "opens on page 0")

	var page0 := _quantities_on_page(board)
	_check(page0 == [15, 14, 13, 12, 11, 10], "stalls pin the top 6 by magnitude",
		"got %s" % str(page0))
	_check(_visible_row_names(board).size() == 6, "page 0 puts 6 rows in the tree",
		"got %d" % _visible_row_names(board).size())

	# --- D does not invent a second page of offers ------------------------
	board._on_navigate(Vector2i(1, 0))
	await process_frame
	_check(board._item_page == 0, "offers past the stall cap stay off the board",
		"got %d" % board._item_page)

	# --- G-; select ABSOLUTE rows on the current page ----------------------
	board._select(1)
	await process_frame
	_check(board._selected_index == 1, "G-; selects an absolute stall",
		"got %d" % board._selected_index)
	var sel: Dictionary = board._get_selected_offer()
	_check(int(sel.get("quantity", -1)) == 14, "the selected offer is stall 2",
		"got %s" % str(sel.get("quantity", -1)))

	# --- selecting off-page drags the page to the cursor ------------------
	board._select(0)
	await process_frame
	_check(board._item_page == 0, "selecting row 0 stays on page 0",
		"got %d" % board._item_page)

	# --- a list that shrinks under the cursor must not strand the page ----
	board._item_page = 2
	board._selected_index = 14
	board._offer_pool = _make_offers(4)
	board._render_all()
	await process_frame
	_check(board._item_page == 0, "a shrunk list clamps the page back into range",
		"got %d" % board._item_page)
	_check(board._selected_index <= 3, "a shrunk list clamps the cursor too",
		"got %d" % board._selected_index)
	_check(_visible_row_names(board).size() == 4, "4 offers render 4 real rows",
		"got %d" % _visible_row_names(board).size())

	# --- the snapshot reports stalls, not the hidden pool ------------------
	board._offer_pool = _make_offers(15)
	board._render_all()
	await process_frame
	var snap: Dictionary = board.get_snapshot()
	_check(int(snap.get("total_pages", -1)) == 1, "snapshot reports 1 stall page",
		"got %s" % str(snap.get("total_pages")))
	_check(int(snap.get("row_count", -1)) == 6, "snapshot reports 6 stalls",
		"got %s" % str(snap.get("row_count")))
	_check(snap.get("slots", []).size() == 6, "snapshot exposes the six stalls",
		"got %d" % snap.get("slots", []).size())

	# --- switching tabs resets the cursor ---------------------------------
	board._item_page = 2
	board.set_frame(QuestBoard.FRAME_COMMITMENTS)
	await process_frame
	_check(board._item_page == 0, "changing tab resets to page 0", "got %d" % board._item_page)

	# --- show_commitments_focused: the HUD door lands selected + DISARMED ----
	# ContractChip's ready-glow route is navigation ONLY: the door must land on
	# Commitments, select the quest's own row, drag the page to it, and leave
	# the second-click confirm DISARMED — _select() arms it, and an armed
	# arrival would turn the player's first click into a claim.
	var stub_qm := StubQuestManager.new()
	stub_qm.rows = _make_commitments(8)
	root.add_child(stub_qm)
	board.quest_manager = stub_qm
	board.set_frame(QuestBoard.FRAME_MARKET)
	await process_frame
	board.show_commitments_focused(2006)   # 7th row → past the 6-key ring
	await process_frame
	_check(board.frame_id == QuestBoard.FRAME_COMMITMENTS,
		"door lands on Commitments (U) — the fill tab", "got %s" % board.frame_id)
	_check(board._selected_index == 6, "door selects the quest's own row (abs idx 6)",
		"got %d" % board._selected_index)
	_check(board._item_page == 1, "door drags the page to the selected row",
		"got %d" % board._item_page)
	_check(board._row_confirm_armed == false,
		"door leaves the second-click confirm DISARMED", "armed")
	_check(board._commitments_view == "active", "door defaults to live Commitments",
		"got %s" % board._commitments_view)
	board.show_commitments_focused(-1, "history")
	await process_frame
	_check(board._commitments_view == "history", "door honors the view param",
		"got %s" % board._commitments_view)
	_check(board.frame_id == QuestBoard.FRAME_COMMITMENTS,
		"history door lands on History [U]", "got %s" % board.frame_id)
	board.show_commitments_focused(-1, "nonsense")
	await process_frame
	_check(board._commitments_view == "active", "an unknown view falls back to live Commitments",
		"got %s" % board._commitments_view)
	_check(board.frame_id == QuestBoard.FRAME_COMMITMENTS,
		"unknown view still lands on Commitments (U)", "got %s" % board.frame_id)

	board.queue_free()
	stub_qm.queue_free()
	_finish("QuestBoard paging")
