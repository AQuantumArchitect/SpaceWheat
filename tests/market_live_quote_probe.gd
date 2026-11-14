extends SceneTree

## market_live_quote_probe.gd — does a board offer's price move while the board
## is open, and does Lock hold it?
##
## Boots the real game headless (AppRoot path, lookahead on: the player lane),
## opens the board with the player's keys (C, then Y for Market) and watches
## one live offer across board heartbeats. The biome is left evolving; a
## Hadamard on the offer's axis first puts it in superposition so H moves it
## (a fresh biome sits in its ground state, which unitary evolution holds still).
##
## One line per phase:
##
##   MARKET_TRACE {"phase": "live",   "id", "emoji", "biome", "asks": [...], "ps": [...]}
##   MARKET_TRACE {"phase": "locked", "ask", "asks": [...], "live_asks": [...], "seconds": [...]}
##   MARKET_TRACE {"phase": "refresh", "present", "ask"}           E re-deals; the lock stays
##   MARKET_TRACE {"phase": "paused", "seconds_before", "seconds_after"}   E pauses; the clock stops
##   MARKET_TRACE {"phase": "save",   "saved_locks", "restored_ask", "restored_seconds", "state_locks"}
##   MARKET_TRACE {"phase": "accept", "held_qty", "ask", "locks_after"}
##   MARKET_TRACE {"phase": "expire", "asks_after": [...]}           a lock that ran out moves again
##
##   godot --headless --script tests/market_live_quote_probe.gd
##
## tests/test_market_live_quotes.py runs it. Set SW_PROBE_USER_DIR_PREFIX to
## refuse to boot unless user:// resolves under it.

const HEARTBEATS_LIVE := 10
const HEARTBEATS_LOCKED := 6


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	printerr("MARKET_PROBE " + msg)
	quit(1)


func _run() -> void:
	var prefix := OS.get_environment("SW_PROBE_USER_DIR_PREFIX").replace("\\", "/").to_lower()
	var user_dir := OS.get_user_data_dir().replace("\\", "/").to_lower()
	if prefix != "" and not user_dir.begins_with(prefix):
		printerr("MARKET_PROBE refusing to boot: user:// is not under SW_PROBE_USER_DIR_PREFIX")
		quit(2)
		return
	var app_root = load("res://scenes/AppRoot.gd").new()
	app_root.name = "AppRoot"
	get_root().add_child(app_root)
	var gsm = get_root().get_node_or_null("GameStateManager")
	if gsm and gsm.pending_boot:
		gsm.pending_boot.requested = true
		gsm.pending_boot.slot = -1
		gsm.pending_boot.scenario_id = "demos_normal"
	var booted := false
	for _i in range(3000):
		var gr = app_root.game_root if "game_root" in app_root else null
		if gr and is_instance_valid(gr) and gr._started and gr.farm != null:
			booted = true
			break
		await process_frame
	if not booted:
		_fail("boot did not yield a farm")
		return
	var farm = app_root.game_root.farm
	var shell = app_root.get_player_shell()
	seed(7)
	for _f in range(10):
		await process_frame
	# Stand in the Village: its neighbourhood deals the Millwright's stalls.
	var abm = get_root().get_node_or_null("/root/ActiveBiomeManager")
	if abm and farm.grid.has_biome("Village"):
		abm.set_active_biome("Village")
	for _f in range(5):
		await process_frame
	if shell and "paused" in shell and shell.paused:
		shell._set_global_paused(false)

	# Open the board on Market with the player's keys.
	await _press(KEY_C, 5)
	await _press(KEY_Y, 5)
	var board = get_root().get_tree().get_first_node_in_group("quest_board")
	if board == null or not board.visible or board.frame_id != "market":
		_fail("the board did not open on Market (visible=%s frame=%s)" % [
			str(board.visible if board else null), str(board.frame_id if board else null)])
		return
	if board._offer_pool.is_empty():
		board._refresh_pool()
		board._render_all()
	var lattice = farm._ensure_market_lattice()

	# Pick a live offer (not a table-priced trade) and superpose its axis.
	var pick := {}
	for row in board._market_rows():
		var d = row.get("data", {})
		if d is Dictionary and not bool(d.get("supply_trade", false)) and d.has("market_offer_id"):
			pick = d
			break
	if pick.is_empty():
		_fail("no live offer on the Market board (pool=%d note=%s)" % [board._offer_pool.size(), board._market_status_note])
		return
	var oid = pick.get("id")
	var c = lattice.get_contract(int(pick["market_offer_id"]))
	var biome = farm.grid.get_biome(c.biome_name) if farm.grid.has_biome(c.biome_name) else lattice._resolve_biome_by_name(c.biome_name)
	var qc = biome.quantum_computer
	var q: int = qc.qubit(c.resource)
	var lib = QuantumGateLibrary.new()
	GateInjector.inject_gate(biome, q, lib.GATES["H"]["matrix"], farm)

	# live: the ask follows ρ while the board is open.
	var asks: Array = []
	var ps: Array = []
	for _h in range(HEARTBEATS_LIVE):
		await _heartbeat()
		var row := _row(board, oid)
		if row.is_empty():
			_fail("the watched offer left the board during live pricing")
			return
		asks.append(int(row.get("quantity", -1)))
		ps.append(snappedf(float(c.quote_p), 0.0001))
	print("MARKET_TRACE " + JSON.stringify({"phase": "live", "id": oid, "emoji": c.resource,
		"biome": c.biome_name, "asks": asks, "ps": ps}))

	# locked: select the row, press F. The ask holds; the live ask keeps moving.
	_select_row(board, oid)
	await _press(KEY_F, 3)
	if not lattice.is_locked(int(pick["market_offer_id"])):
		_fail("F did not lock the selected offer")
		return
	var locked_ask := int(_row(board, oid).get("quantity", -1))
	var l_asks: Array = []
	var live_asks: Array = []
	var seconds: Array = []
	for _h in range(HEARTBEATS_LOCKED):
		await _heartbeat()
		var row := _row(board, oid)
		l_asks.append(int(row.get("quantity", -1)))
		live_asks.append(int(row.get("live_ask", -1)))
		seconds.append(snappedf(float(row.get("lock_seconds_left", -1.0)), 0.01))
	print("MARKET_TRACE " + JSON.stringify({"phase": "locked", "ask": locked_ask, "asks": l_asks,
		"live_asks": live_asks, "seconds": seconds}))

	# refresh: E re-deals the board (and pauses time). The locked row stays.
	await _press(KEY_E, 3)
	var after := _row(board, oid)
	print("MARKET_TRACE " + JSON.stringify({"phase": "refresh", "present": not after.is_empty(),
		"ask": int(after.get("quantity", -1)), "locked": bool(after.get("locked", false))}))

	# paused: E paused the sim, so the lock clock holds.
	var s_before := float(lattice.get_contract(int(pick["market_offer_id"])).lock_seconds_left)
	for _f in range(40):
		await physics_frame
	var s_after := float(lattice.get_contract(int(pick["market_offer_id"])).lock_seconds_left)
	print("MARKET_TRACE " + JSON.stringify({"phase": "paused", "was_paused": bool(shell.paused),
		"seconds_before": snappedf(s_before, 0.01), "seconds_after": snappedf(s_after, 0.01)}))
	shell._set_global_paused(false)

	# save: the lock rides the save (market_state) and comes back whole.
	var serializer = GameStateSerializer.new()
	var state = serializer.capture_state_from_farm(farm, GameState.new(), "demos_normal")
	# Through the disk format: write the GameState resource, read it back.
	var path := "user://market_probe_state.tres"
	var save_err := ResourceSaver.save(state, path)
	var loaded = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) if save_err == OK else null
	var saved: Dictionary = loaded.market_state if loaded != null else {}
	var fresh = MarketLattice.new(farm)
	fresh.from_save_dict(saved)
	var rc = fresh.get_contract(int(pick["market_offer_id"]))
	print("MARKET_TRACE " + JSON.stringify({"phase": "save",
		"disk_ok": save_err == OK and loaded != null,
		"saved_locks": saved.get("locks", []).size(),
		"state_locks": state.market_state.get("locks", []).size() if state.market_state is Dictionary else -1,
		"restored_locked": rc != null and rc.is_locked(),
		"restored_ask": rc.ask() if rc != null else -1,
		"restored_view_qty": int(rc.locked_view.get("quantity", -1)) if rc != null else -1,
		"restored_seconds": snappedf(rc.lock_seconds_left, 0.01) if rc != null else -1.0,
		"version": state.save_version}))

	# accept: R on the locked row takes the locked ask and frees the slot.
	_select_row(board, oid)
	var ask_at_accept := int(_row(board, oid).get("quantity", -1))
	await _press(KEY_R, 3)
	var qm = board.quest_manager
	var held = qm.active_quests.get(oid, {}) if qm else {}
	print("MARKET_TRACE " + JSON.stringify({"phase": "accept", "held": not held.is_empty(),
		"held_qty": int(held.get("quantity", -1)), "ask": ask_at_accept,
		"locks_after": lattice.locked_count(), "held_locked_field": held.has("locked")}))

	# expire: lock another live offer, run its clock out, watch it move again.
	var other := {}
	for row in board._market_rows():
		var d = row.get("data", {})
		if d is Dictionary and not bool(d.get("supply_trade", false)) and d.has("market_offer_id") \
				and d.get("id") != oid:
			other = d
			break
	if other.is_empty():
		print("MARKET_TRACE " + JSON.stringify({"phase": "expire", "skipped": true}))
	else:
		var ocid := int(other["market_offer_id"])
		var oc = lattice.get_contract(ocid)
		var obiome = lattice._resolve_biome_by_name(oc.biome_name)
		GateInjector.inject_gate(obiome, obiome.quantum_computer.qubit(oc.resource), lib.GATES["H"]["matrix"], farm)
		lattice.lock(ocid, other)
		lattice.tick_locks(MarketLattice.LOCK_SECONDS + 1.0)
		var o_asks: Array = []
		for _h in range(HEARTBEATS_LIVE):
			await _heartbeat()
			o_asks.append(int(_row(board, other.get("id")).get("quantity", -1)))
		print("MARKET_TRACE " + JSON.stringify({"phase": "expire", "skipped": false,
			"unlocked": not lattice.is_locked(ocid), "asks_after": o_asks,
			"emoji": oc.resource, "biome": oc.biome_name, "p": snappedf(oc.quote_p, 0.0001),
			"p_prior": oc.p_prior, "prior_biome": oc.prior_biome, "kT": snappedf(oc.quote_kT, 0.01),
			"standing": PriceModel.standing_factor(oc.faction, farm), "faction": oc.faction}))
	quit(0)


func _row(board, offer_id) -> Dictionary:
	for o in board._offer_pool:
		if o is Dictionary and o.get("id", null) == offer_id:
			return o
	return {}


func _select_row(board, offer_id) -> void:
	var rows: Array = board._market_rows()
	for i in range(rows.size()):
		var d = rows[i].get("data", {})
		if d is Dictionary and d.get("id", null) == offer_id:
			board._select(i)
			return


## One board heartbeat of wall time (the board's _process requotes on it).
func _heartbeat() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1100:
		await process_frame


func _press(keycode: int, settle: int = 3) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		get_root().push_input(ev, true)
		await process_frame
	for _i in range(settle):
		await process_frame
