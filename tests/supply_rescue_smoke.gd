extends SceneTree

## Supply rescue — a broke player can always get out of the 🧺 hole at the
## Village market. Boots the real game (fresh demos_normal), drains 🧺 to 0,
## reads the refusal/banner words, crosses to the Village, opens the board on
## Market, finds the standing 🧺 trade (campaign resources table), accepts it,
## delivers it, and ends holding exactly the trade's payout.
##
## Run: godot --headless --path . --script tests/supply_rescue_smoke.gd
## Prints one JSON line tagged "supply-rescue" (tests/test_supply_trades.py).

const UIProgression = preload("res://UI/Core/UIProgression.gd")

var _out := {"schema": "supply-rescue", "fails": []}


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	(_out["fails"] as Array).append(msg)


func _wait_group(group_name: String, frames: int) -> Node:
	for _i in range(frames):
		var nodes = get_nodes_in_group(group_name)
		if nodes.size() > 0:
			return nodes[0]
		await process_frame
	return null


func _finish() -> void:
	_out["ok"] = (_out["fails"] as Array).is_empty()
	print(JSON.stringify(_out))
	quit(0 if _out["ok"] else 1)


func _run() -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var shell = await _wait_group("player_shell", 600)
	if shell == null:
		_fail("no player_shell")
		_finish()
		return
	var farm = null
	for _i in range(600):
		var gsm = root.get_node_or_null("/root/GameStateManager")
		farm = gsm.get_active_farm() if gsm and gsm.has_method("get_active_farm") else null
		if farm != null and farm.economy != null and farm.grid != null and farm.grid.has_biome("Village") \
				and shell.quest_manager != null and shell.overlay_manager != null \
				and shell.overlay_manager.get_overlay("quests") != null:
			break
		await process_frame
	if farm == null or farm.economy == null:
		_fail("no farm/economy")
		_finish()
		return
	for _i in range(30):
		await process_frame
	var econ = farm.economy
	var qm = shell.quest_manager
	var om = shell.overlay_manager
	var abm = root.get_node_or_null("/root/ActiveBiomeManager")

	# --- the table says what the rescue is -------------------------------
	var trade := CampaignRuntime.rescue_trade("🧺")
	_out["trade"] = trade
	if trade.is_empty():
		_fail("campaign resources table has no Village 🧺 trade")
		_finish()
		return
	var give := CampaignRuntime.trade_give(trade)
	var get_n := int(trade.get("get", 0))

	# --- drain 🧺 to zero --------------------------------------------------
	var b0 := int(econ.get_resource("🧺"))
	_out["baskets_start"] = b0
	if b0 > 0:
		econ.remove_resource("🧺", b0, "supply_rescue_smoke")
	_out["baskets_drained"] = int(econ.get_resource("🧺"))
	if int(econ.get_resource("🧺")) != 0:
		_fail("could not drain 🧺")
	for g in give:
		if int(econ.get_resource(g)) < int(give[g]):
			econ.add_resource(g, int(give[g]), "supply_rescue_smoke")
	var give_before := {}
	for g in give:
		give_before[g] = int(econ.get_resource(g))

	# --- refusal + banner name the trade walk -------------------------------
	var refusal: String = UIProgression.supply_refusal("🧺", UIProgression.gather_price(), true)
	_out["refusal"] = refusal
	if "Village" not in refusal or "🧺 trade" not in refusal:
		_fail("broke refusal does not name the Village 🧺 trade: %s" % refusal)
	if "plot" in refusal or "[Q]" in refusal:
		_fail("refusal still steers to a 🧺 plot / Q: %s" % refusal)
	if not UIProgression._basket_short():
		_fail("0🧺 does not read as basket-short")
	var walk_far: String = UIProgression._basket_pay_line()
	_out["walk_far"] = walk_far
	if abm != null and str(abm.get_active_biome()) != "Village":
		if "Village" not in walk_far:
			_fail("away from the Village the walk does not name it: %s" % walk_far)

	# --- cross to the Village and open the board on Market ------------------
	if abm != null and abm.has_method("set_active_biome"):
		abm.set_active_biome("Village")
	for _i in range(10):
		await process_frame
	_out["walk_village"] = UIProgression._basket_pay_line()
	if "[C]" not in str(_out["walk_village"]):
		_fail("in the Village the walk does not name [C]: %s" % str(_out["walk_village"]))
	var board = om.get_overlay("quests")
	if not om._overlay_is_open("quests"):
		om.toggle_overlay("quests")
	for _i in range(5):
		await process_frame
	_out["walk_board"] = UIProgression._basket_pay_line()
	board.set_frame("market")
	board._refresh_pool()
	board._render_all()
	for _i in range(3):
		await process_frame
	_out["walk_market"] = UIProgression._basket_pay_line()

	var row_i := -1
	var offer: Dictionary = {}
	var rows: Array = board._market_rows()
	for i in range(rows.size()):
		var d = rows[i].get("data", {})
		if d is Dictionary and bool(d.get("supply_trade", false)) and str(d.get("supply_emoji", "")) == "🧺":
			row_i = i
			offer = d
			break
	_out["rows"] = rows.size()
	if row_i < 0:
		_fail("Village Market has no 🧺 standing trade row")
		_finish()
		return
	_out["offer_id"] = int(offer.get("id", -1))
	if int(offer.get("id", -1)) != QuestPipeline.supply_offer_id("🧺", "Village"):
		_fail("supply offer id is not the stable (🧺, Village) id")
	var rr: Dictionary = offer.get("reward_resources", {})
	if int(rr.get("🧺", 0)) != get_n:
		_fail("offer advertises %s, table says 🧺×%d" % [str(rr), get_n])

	# Re-rolling the board never duplicates the trade.
	board._refresh_pool()
	board._refresh_pool()
	var n_same := 0
	for o in board._offer_pool:
		if int(o.get("id", -2)) == int(offer.get("id", -1)):
			n_same += 1
	if n_same != 1:
		_fail("re-rolled board carries the 🧺 trade %d times" % n_same)
	# Every Village standing trade is on the ring (paged past six if need be).
	var want_trades: Array = CampaignRuntime.trades_for_biome("Village")
	var on_ring := {}
	for r in board._market_rows():
		var rd = r.get("data", {})
		if rd is Dictionary and bool(rd.get("supply_trade", false)):
			# One staple can carry two trades (🌾-priced and the 🐇 rescue):
			# key by emoji + what it asks for.
			var g: Dictionary = rd.get("give", {}) if rd.get("give", {}) is Dictionary else {}
			var gk := str(g.keys()[0]) if not g.is_empty() else str(rd.get("resource", ""))
			on_ring[str(rd.get("supply_emoji", "")) + "|" + gk] = true
	_out["village_trades"] = want_trades.size()
	_out["village_trades_on_ring"] = on_ring.size()
	for t in want_trades:
		var tg: Dictionary = CampaignRuntime.trade_give(t)
		var tk := str(t.get("emoji", "")) + "|" + (str(tg.keys()[0]) if not tg.is_empty() else "")
		if not on_ring.has(tk):
			_fail("Village board is missing the standing %s trade" % str(t.get("emoji", "")))

	# A refused plant names its south pole's trade (🪓 for 🪵/🪓).
	var axes := int(econ.get_resource("🪓"))
	if axes > 0:
		econ.remove_resource("🪓", axes, "supply_rescue_smoke")
	UIProgression.note_plant_south("🪓")
	if not UIProgression._plant_south_short():
		_fail("0🪓 after a refused 🪵/🪓 plant does not read as short")
	var axe_walk: String = UIProgression._supply_walk_line("🪓")
	_out["axe_walk"] = axe_walk
	_out["axe_refusal"] = UIProgression.supply_refusal("🪓", 13, true)
	if "🪓" not in axe_walk or "[" not in axe_walk:
		_fail("🪓 walk does not name a key toward the 🪓 trade: %s" % axe_walk)
	if "Village" not in str(_out["axe_refusal"]) or "🪓 trade" not in str(_out["axe_refusal"]):
		_fail("🪓 refusal does not name the Village 🪓 trade: %s" % str(_out["axe_refusal"]))
	UIProgression.note_plant_south("")

	# --- accept ------------------------------------------------------------
	rows = board._market_rows()
	for i in range(rows.size()):
		var d2 = rows[i].get("data", {})
		if d2 is Dictionary and int(d2.get("id", -1)) == int(offer.get("id", -1)):
			row_i = i
	board._select(row_i)
	_out["cue_offer"] = board.supply_walk_cue("🧺")
	board._on_action_r()
	var qid := int(offer.get("id", -1))
	if not qm.active_quests.has(qid):
		_fail("accept did not hold the trade")
		_finish()
		return
	# Accepted → it is a held stall now, not a second offer.
	board._refresh_pool()
	for o in board._offer_pool:
		if int(o.get("id", -2)) == qid:
			_fail("accepted trade is still offered")
			break

	# --- deliver -----------------------------------------------------------
	rows = board._market_rows()
	var held_i := -1
	for i in range(rows.size()):
		var d3 = rows[i].get("data", {})
		if str(rows[i].get("kind", "")) == "held" and d3 is Dictionary and int(d3.get("id", -1)) == qid:
			held_i = i
	if held_i < 0:
		_fail("held trade not on the Market ring")
		_finish()
		return
	board._select(held_i)
	_out["cue_held"] = board.supply_walk_cue("🧺")
	board._on_action_r()
	var b_end := int(econ.get_resource("🧺"))
	_out["baskets_end"] = b_end
	if qm.active_quests.has(qid):
		_fail("deliver did not settle the trade: %s" % str(qm.get("last_complete_error")))
	if b_end != get_n:
		_fail("ended with 🧺×%d, expected exactly the trade's 🧺×%d" % [b_end, get_n])
	for g in give:
		if int(econ.get_resource(g)) != int(give_before[g]) - int(give[g]):
			_fail("%s not charged exactly %d" % [g, int(give[g])])
	# The standing trade is back on the board at once.
	var back := false
	for o in board._offer_pool:
		if int(o.get("id", -2)) == qid:
			back = true
	if not back:
		_fail("standing trade did not return to the board after completion")
	_finish()
