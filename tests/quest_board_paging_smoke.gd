extends "res://tests/smoke_test_base.gd"

## QuestBoard item paging — the six GHJKL; keys must be able to reach EVERY row
## of a longer list, not just the first six.
##
## Regression guard for the 2026-08-10 fix: Manifold / Market / Commitments each
## rendered exactly MAX_VISIBLE_ITEMS rows and then printed "… N more not shown".
## Rows past the sixth were never added to the scene tree at all, so no amount of
## scrolling reached them — with MARKET_FETCH_LIMIT = 24 that could strand 18
## contracts behind a dead-end message.


func _init() -> void:
	call_deferred("_run")


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
	# The quantity of each offer the current page is actually rendering, read
	# back out of the live list + page offset (the same slice the keys address).
	var offers: Array = board._get_visible_offers()
	var start: int = board._item_page * board.MAX_VISIBLE_ITEMS
	var out: Array = []
	for i in range(board.MAX_VISIBLE_ITEMS):
		if start + i < offers.size():
			out.append(int(offers[start + i].get("quantity", -1)))
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

	# --- the list length is told truthfully -------------------------------
	_check(board._current_row_count() == 15, "row count reports the full list (15)",
		"got %d" % board._current_row_count())
	_check(board._item_page_count(15) == 3, "15 rows over a 6-key ring = 3 pages",
		"got %d" % board._item_page_count(15))
	_check(board._item_page == 0, "opens on page 0")

	# --- page 0 shows rows 1-6 --------------------------------------------
	var page0 := _quantities_on_page(board)
	_check(page0 == [15, 14, 13, 12, 11, 10], "page 0 renders offers 1-6",
		"got %s" % str(page0))
	_check(_visible_row_names(board).size() == 6, "page 0 puts 6 rows in the tree",
		"got %d" % _visible_row_names(board).size())

	# --- D pages forward, and drags the cursor with it --------------------
	board._on_navigate(Vector2i(1, 0))
	await process_frame
	_check(board._item_page == 1, "A/D navigate steps to page 1", "got %d" % board._item_page)
	_check(board._selected_index == 6, "cursor follows onto the new page (absolute idx 6)",
		"got %d" % board._selected_index)
	var page1 := _quantities_on_page(board)
	_check(page1 == [9, 8, 7, 6, 5, 4], "page 1 renders offers 7-12", "got %s" % str(page1))

	# --- the tail page is reachable, and clamps ---------------------------
	board._on_navigate(Vector2i(1, 0))
	await process_frame
	var page2 := _quantities_on_page(board)
	_check(board._item_page == 2, "page 2 reachable", "got %d" % board._item_page)
	_check(page2 == [3, 2, 1], "page 2 renders the remaining 3 offers", "got %s" % str(page2))
	board._on_navigate(Vector2i(1, 0))
	await process_frame
	_check(board._item_page == 2, "paging past the end clamps instead of wrapping to empty",
		"got %d" % board._item_page)

	# --- G-; select ABSOLUTE rows on the current page ----------------------
	# Slot 1 (H) on page 2 = absolute index 13, the second-to-last offer — a row
	# the pre-fix board could never address with any key.
	board._select(board._item_page * board.MAX_VISIBLE_ITEMS + 1)
	await process_frame
	_check(board._selected_index == 13, "G-; selects an absolute row on the current page",
		"got %d" % board._selected_index)
	var sel: Dictionary = board._get_selected_offer()
	_check(int(sel.get("quantity", -1)) == 2, "the selected offer is the 14th of 15",
		"got %s" % str(sel.get("quantity", -1)))

	# --- selecting off-page drags the page to the cursor ------------------
	board._select(0)
	await process_frame
	_check(board._item_page == 0, "selecting row 0 pulls the page back to 0",
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

	# --- the snapshot stops lying about page counts ------------------------
	board._offer_pool = _make_offers(15)
	board._render_all()
	await process_frame
	var snap: Dictionary = board.get_snapshot()
	_check(int(snap.get("total_pages", -1)) == 3, "snapshot reports 3 item pages",
		"got %s" % str(snap.get("total_pages")))
	_check(int(snap.get("row_count", -1)) == 15, "snapshot reports the full row count",
		"got %s" % str(snap.get("row_count")))
	_check(snap.get("slots", []).size() == 15, "snapshot exposes every row as a slot",
		"got %d" % snap.get("slots", []).size())

	# --- switching tabs resets the cursor ---------------------------------
	board._item_page = 2
	board.set_frame(QuestBoard.FRAME_COMMITMENTS)
	await process_frame
	_check(board._item_page == 0, "changing tab resets to page 0", "got %d" % board._item_page)

	board.queue_free()
	_finish("QuestBoard paging")
