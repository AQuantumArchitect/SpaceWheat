extends SceneTree

## merchant_channel_probe.gd — Merchant channels are contracts on the C board.
##
## Boots the real game headless (lookahead on), opens the Village's regime
## (qc.regime_override = "open", the way What Fades opens a biome before the
## door) and walks a channel through the board and the hat:
##
##   CHANNEL_TRACE {"phase": "offers"}   Market lists channel offers on open ground
##   CHANNEL_TRACE {"phase": "lock"}     F locks one; its stake holds
##   CHANNEL_TRACE {"phase": "sign"}     R signs it through the hat's verb, at the locked stake
##   CHANNEL_TRACE {"phase": "flow"}     it shows on Commitments and credits the wallet as it drains
##   CHANNEL_TRACE {"phase": "hat"}      Merchant R (action_pump) signs another, same record
##   CHANNEL_TRACE {"phase": "order_book"}  Merchant E quotes what the board quotes
##   CHANNEL_TRACE {"phase": "save"}     channels ride market_state through a .tres
##   CHANNEL_TRACE {"phase": "old_save"} a flag with no record gets one (sync_channels)
##   CHANNEL_TRACE {"phase": "close"}    Q then F on Commitments closes one: free, standing unchanged
##   CHANNEL_TRACE {"phase": "sealed"}   sealed ground lists no channel offers and refuses signing
##
##   godot --headless --script tests/merchant_channel_probe.gd
##
## tests/test_merchant_channels.py runs it. Set SW_PROBE_USER_DIR_PREFIX to
## refuse to boot unless user:// resolves under it.

const LindbladHandler = preload("res://Core/Instrumentation/Handlers/LindbladHandler.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	printerr("CHANNEL_PROBE " + msg)
	quit(1)


func _trace(d: Dictionary) -> void:
	print("CHANNEL_TRACE " + JSON.stringify(d))


func _run() -> void:
	var prefix := OS.get_environment("SW_PROBE_USER_DIR_PREFIX").replace("\\", "/").to_lower()
	var user_dir := OS.get_user_data_dir().replace("\\", "/").to_lower()
	if prefix != "" and not user_dir.begins_with(prefix):
		printerr("CHANNEL_PROBE refusing to boot: user:// is not under SW_PROBE_USER_DIR_PREFIX")
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
	var inst = InstrumentLocator.resolve_quantum_instrument(shell)
	seed(11)
	for _f in range(10):
		await process_frame
	var abm = get_root().get_node_or_null("/root/ActiveBiomeManager")
	if abm and farm.grid.has_biome("Village"):
		abm.set_active_biome("Village")
	var village = farm.grid.get_biome("Village")
	var qc = village.quantum_computer
	qc.regime_override = "open"
	for e in ["📜", "🧺"]:
		farm.economy.add_resource(e, 5000, "probe")
	for q in range(int(qc.register_map.num_qubits)):
		var pair: Dictionary = qc.get_emoji_pair_for_qubit(q)
		for k in ["north", "south"]:
			if str(pair.get(k, "")) != "":
				farm.economy.add_resource(str(pair[k]), 5000, "probe")
	for _f in range(5):
		await process_frame
	if shell and "paused" in shell and shell.paused:
		shell._set_global_paused(false)
	var lattice = farm._ensure_market_lattice()

	# offers: the Market tab on open ground lists channels.
	await _press(KEY_C, 5)
	await _press(KEY_Y, 5)
	var board = get_root().get_tree().get_first_node_in_group("quest_board")
	if board == null or not board.visible or board.frame_id != "market":
		_fail("the board did not open on Market")
		return
	board._refresh_pool()
	board._render_all()
	var offers: Array = []
	for row in board._market_rows():
		var d = row.get("data", {})
		if d is Dictionary and bool(d.get("channel_offer", false)):
			offers.append(d)
	var dirs := {}
	for o in offers:
		dirs[str(o.get("direction", ""))] = true
	var pick := {}
	for o in offers:
		if str(o.get("direction", "")) == "export" and str(o.get("channel_kind", "")) == "thermal":
			pick = o
			break
	_trace({"phase": "offers", "count": offers.size(), "directions": dirs.keys(),
		"issuer": str(pick.get("faction", "")), "native": lattice.channel_issuer(village),
		"kind": str(pick.get("channel_kind", ""))})
	if pick.is_empty():
		_fail("no thermal export channel offer on the open Village board")
		return
	var oid = pick.get("id")
	var reg := int(pick.get("register_id", -1))
	var north := str(pick.get("north", ""))
	var south := str(pick.get("south", ""))

	# lock: F holds the stake.
	_select_row(board, oid)
	await _press(KEY_F, 3)
	var locked_stake := int(_row(board, oid).get("quantity", -1))
	var held_stakes: Array = []
	for _h in range(3):
		await _heartbeat()
		held_stakes.append(int(_row(board, oid).get("quantity", -1)))
	var hat_quote: Dictionary = lattice.channel_quote(village, reg, "export", "thermal")
	_trace({"phase": "lock", "locked": lattice.is_locked(int(oid)), "stake": locked_stake,
		"stakes": held_stakes, "hat_quote_stake": int(hat_quote.get("stake", -1)),
		"hat_quote_locked": bool(hat_quote.get("locked", false))})

	# sign: R on the locked row signs it through action_drain, at the locked stake.
	var wallet_s_before := int(farm.economy.get_resource(south))
	var fee_before := int(farm.economy.get_resource("🧺"))
	_select_row(board, oid)
	await _press(KEY_R, 3)
	var ch = lattice.get_channel(BiomeBase.type_name(village), reg)
	var infra: Dictionary = qc.register_infrastructure.get(reg, {})
	_trace({"phase": "sign", "signed": ch != null,
		"drain_flag": bool(infra.get("lindblad_drain_active", false)),
		"faction": ch.faction if ch else "", "direction": ch.channel_direction if ch else "",
		"kind": ch.channel_kind if ch else "",
		"signed_stake": int(ch.signed_cost.get(south, -1)) if ch else -1, "locked_stake": locked_stake,
		"wallet_stake_paid": wallet_s_before - int(farm.economy.get_resource(south)),
		"fee_paid": fee_before - int(farm.economy.get_resource("🧺")),
		"locks_after": lattice.locked_count(), "offer_left_board": _row(board, oid).is_empty()})
	if ch == null:
		_fail("R did not sign the channel")
		return

	# flow: on Commitments, credited climbs as the channel drains north.
	await _press(KEY_U, 5)
	var credited: Array = []
	var statuses: Array = []
	var wallet_n0 := int(farm.economy.get_resource(north))
	for _h in range(6):
		await _heartbeat()
		var crow := _channel_row(board, ch.id)
		credited.append(int(crow.get("credited", -1)))
		statuses.append(str(crow.get("status", "")))
	_trace({"phase": "flow", "on_commitments": not _channel_row(board, ch.id).is_empty(),
		"credited": credited, "statuses": statuses,
		"wallet_north_gain": int(farm.economy.get_resource(north)) - wallet_n0,
		"takes_no_hand": board._held_count() == 0})

	# hat: Merchant R on another register — the same contract record.
	var reg2 := -1
	var pos2 := GridSentinel.INVALID_POSITION
	for p in farm.grid.get_plot_positions_for_biome("Village"):
		var r2 := int(LindbladHandler._resolve_axis_binding(farm, p, village).get("register_id", -1))
		if r2 >= 0 and r2 != reg:
			reg2 = r2
			pos2 = p
			break
	var hat_result: Dictionary = {}
	if reg2 >= 0:
		var ps: Array[Vector2i] = [pos2]
		hat_result = inst.action_pump(ps, "thermal")
	var ch2 = lattice.get_channel(ch.biome_name, reg2)
	_trace({"phase": "hat", "success": bool(hat_result.get("success", false)), "signed": ch2 != null,
		"direction": ch2.channel_direction if ch2 else "", "faction": ch2.faction if ch2 else "",
		"channels": lattice.get_channels().size(),
		"on_commitments": ch2 != null and not _channel_row(board, ch2.id).is_empty()})

	# order_book: Merchant E on a free register quotes what the board quotes.
	var reg3 := -1
	var pos3 := GridSentinel.INVALID_POSITION
	for p in farm.grid.get_plot_positions_for_biome("Village"):
		var r3 := int(LindbladHandler._resolve_axis_binding(farm, p, village).get("register_id", -1))
		if r3 >= 0 and r3 != reg and r3 != reg2:
			reg3 = r3
			pos3 = p
			break
	var qii = get_root().get_tree().get_first_node_in_group("quantum_instrument_input")
	var book: Dictionary = {}
	var board_stake := -2
	if qii != null and reg3 >= 0:
		qii._instrument.current_biome = "Village"
		qii._instrument.current_plot_idx = pos3.x
		book = qii._execute_read_price()
		var bq: Dictionary = lattice.channel_quote(village, reg3, "export", str(book.get("kind", "thermal")))
		board_stake = int(bq.get("stake", -1))
	_trace({"phase": "order_book", "ok": bool(book.get("success", false)),
		"register": int(book.get("register_id", -1)), "expected_register": reg3,
		"book_export_stake": int(book.get("quote_export", {}).get("stake", -1)),
		"board_export_stake": board_stake,
		"book_faction": str(book.get("quote_export", {}).get("faction", ""))})

	# save: channels ride market_state, through the disk format.
	var serializer = GameStateSerializer.new()
	var state = serializer.capture_state_from_farm(farm, GameState.new(), "demos_normal")
	var path := "user://channel_probe_state.tres"
	var err := ResourceSaver.save(state, path)
	var loaded = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) if err == OK else null
	var fresh = MarketLattice.new(farm)
	fresh.from_save_dict(loaded.market_state if loaded != null else {})
	var restored = fresh.get_channel(ch.biome_name, reg)
	_trace({"phase": "save", "disk_ok": loaded != null,
		"saved": (loaded.market_state.get("channels", []).size() if loaded != null else -1),
		"restored": fresh.get_channels().size(),
		"restored_faction": restored.faction if restored else "",
		"restored_direction": restored.channel_direction if restored else "",
		"restored_stake": int(restored.signed_cost.get(south, -1)) if restored else -1})

	# old_save: a lattice with no channel records (a v7 save) reconciles from the flags.
	var bare = MarketLattice.new(farm)
	var added: int = bare.sync_channels()
	var synth = bare.get_channel(ch.biome_name, reg)
	_trace({"phase": "old_save", "added": added, "channels": bare.get_channels().size(),
		"faction": synth.faction if synth else "", "signed_at": synth.signed_at if synth else -1,
		"direction": synth.channel_direction if synth else ""})

	# close: Q arms, F confirms, on the channel's Commitments row.
	var standing_before := _standing(farm, ch.faction)
	var wallet_before: Dictionary = {"📜": int(farm.economy.get_resource("📜")), "🧺": int(farm.economy.get_resource("🧺"))}
	_select_channel_row(board, ch.id)
	await _press(KEY_Q, 3)
	await _press(KEY_F, 3)
	var infra_after: Dictionary = qc.register_infrastructure.get(reg, {})
	_trace({"phase": "close", "closed": lattice.get_channel(ch.biome_name, reg) == null,
		"flag_cleared": not bool(infra_after.get("lindblad_drain_active", false)),
		"left_commitments": _channel_row(board, ch.id).is_empty(),
		"standing_same": _standing(farm, ch.faction) == standing_before,
		"fee_free": int(farm.economy.get_resource("📜")) == wallet_before["📜"] \
				and int(farm.economy.get_resource("🧺")) == wallet_before["🧺"],
		"channels_left": lattice.get_channels().size()})

	# sealed: the enclave lists no channel offers and refuses signing.
	qc.regime_override = "closed"
	await _press(KEY_Y, 3)
	board._refresh_pool()
	board._render_all()
	var sealed_offers := 0
	for row in board._market_rows():
		var d = row.get("data", {})
		if d is Dictionary and bool(d.get("channel_offer", false)):
			sealed_offers += 1
	var refused: Dictionary = {}
	if reg3 >= 0:
		var ps3: Array[Vector2i] = [pos3]
		refused = inst.action_drain(ps3, "thermal")
	_trace({"phase": "sealed", "offers": sealed_offers,
		"refused": not bool(refused.get("success", true)), "sealed_count": int(refused.get("sealed", 0))})
	quit(0)


func _standing(farm, faction: String) -> Dictionary:
	if faction == "" or not ("faction_standings" in farm) or farm.faction_standings == null:
		return {}
	var s = farm.faction_standings.get(faction)
	return s.to_dict() if s != null and s.has_method("to_dict") else {}


func _row(board, offer_id) -> Dictionary:
	for o in board._offer_pool:
		if o is Dictionary and o.get("id", null) == offer_id:
			return o
	return {}


func _channel_row(board, cid) -> Dictionary:
	for q in board._channel_rows():
		if q.get("id", null) == cid:
			return q
	return {}


func _select_row(board, offer_id) -> void:
	var rows: Array = board._market_rows()
	for i in range(rows.size()):
		var d = rows[i].get("data", {})
		if d is Dictionary and d.get("id", null) == offer_id:
			board._select(i)
			return


func _select_channel_row(board, cid) -> void:
	var rows: Array = board._commitments_rows()
	for i in range(rows.size()):
		if rows[i] is Dictionary and rows[i].get("id", null) == cid:
			board._select(i)
			return


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
