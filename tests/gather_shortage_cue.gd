extends SceneTree

## Issue #87: out of the gather fee, the Guide's cue follows STATE, not path.
## Boots the real game (fresh demos_normal, Act 0 core loop) and:
##   1. drains 🧺: the banner turns to the 🧺 trade at once, before any press;
##   2. opens the Village Market and leaves without buying: the cue stands,
##      and a stale "trade not on the ring" mark does not hide it;
##   3. restores 🧺: the cue clears and the lap (Explore) is back;
##   4. strands the wallet (0🧺 · 3👥 · 0🌾, no trade payable): the gather fee
##      is waived, and a real Explore → Strike → Gather pays out for free;
##   5. sweeps small wallets: every staple verb is payable, rescuable through
##      Village trades, or free. No wallet is a dead end.
##
## Run: godot --headless --path . --script tests/gather_shortage_cue.gd
## Prints one JSON line tagged "gather-shortage-cue" (tests/test_gather_shortage_cue.py).

const UIProgression = preload("res://UI/Core/UIProgression.gd")
const Guide = preload("res://Core/Campaign/Guide.gd")

var _out := {"schema": "gather-shortage-cue", "fails": [], "cues": {}}


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	(_out["fails"] as Array).append(msg)


func _finish() -> void:
	_out["ok"] = (_out["fails"] as Array).is_empty()
	print(JSON.stringify(_out))
	quit(0 if _out["ok"] else 1)


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _cue(tag: String) -> Dictionary:
	var g: Dictionary = Guide.next_step()
	(_out["cues"] as Dictionary)[tag] = {"text": str(g.get("text", "")), "short": Guide.shortage,
			"banner": UIProgression.objective_text()}
	return g


func _put(econ, emoji: String, n: int) -> void:
	econ.set_resource(emoji, n, "gather_shortage_cue")


func _run() -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var shell = null
	for _i in range(600):
		var nodes = get_nodes_in_group("player_shell")
		if not nodes.is_empty():
			shell = nodes[0]
			break
		await process_frame
	var farm = null
	for _i in range(600):
		var gsm = root.get_node_or_null("/root/GameStateManager")
		farm = gsm.get_active_farm() if gsm and gsm.has_method("get_active_farm") else null
		if shell != null and farm != null and farm.economy != null and farm.grid != null \
				and farm.grid.has_biome("Village") and shell.quest_manager != null \
				and shell.overlay_manager != null and shell.overlay_manager.get_overlay("quests") != null:
			break
		await process_frame
	if farm == null or farm.economy == null or shell == null:
		_fail("no farm/economy/shell")
		_finish()
		return
	await _frames(30)
	var econ = farm.economy
	var om = shell.overlay_manager
	var abm = root.get_node_or_null("/root/ActiveBiomeManager")
	_out["tutorial_step"] = UIProgression.current_tutorial_step()
	var home := str(abm.get_active_biome()) if abm != null else ""

	# --- 1. drain 🧺: the way out shows before any refused press -------------
	var base := _cue("full")
	if Guide.shortage != "":
		_fail("full wallet already reads short: %s" % str(base.get("text", "")))
	_put(econ, "🧺", 0)
	await _frames(2)
	var g1 := _cue("drained")
	if Guide.shortage != "🧺":
		_fail("0🧺: the banner does not walk to baskets: %s" % str(g1.get("text", "")))
	var t1 := str(g1.get("text", ""))
	if "🧺" not in t1 or "[" not in t1:
		_fail("0🧺 cue names no basket or key: %s" % t1)
	for verb in ["Gather [", "Strike [", "Explore ["]:
		if verb in t1:
			_fail("0🧺 cue still names a lap verb (%s): %s" % [verb, t1])
	if UIProgression.objective_text() != t1:
		_fail("banner (%s) is not the Guide's cue (%s)" % [UIProgression.objective_text(), t1])
	var routes := UIProgression.shortage_routes()
	_out["routes"] = routes
	if "Village" not in routes or "🧺 trade" not in routes or "baskets" not in routes:
		_fail("hover routes do not name the Village 🧺 trade in words: %s" % routes)

	# --- 2. visit the Market, leave without buying ------------------------------
	if abm != null:
		abm.set_active_biome("Village")
	await _frames(5)
	om.open_board_on_supply("🧺")
	await _frames(5)
	var g2 := _cue("on_market")
	if Guide.shortage != "🧺":
		_fail("on the Market the cue lost the basket walk: %s" % str(g2.get("text", "")))
	if not ("Accept" in str(g2.get("text", "")) or "Deliver" in str(g2.get("text", ""))):
		_fail("on the Market the cue does not name the trade row: %s" % str(g2.get("text", "")))
	# A stale path mark ("not on the ring") must not hide a guaranteed rescue.
	Guide._no_trade_until["🧺|Village"] = Time.get_ticks_msec() + 600000
	var board = om.get_overlay("quests")
	if om._overlay_is_open("quests"):
		om.toggle_overlay("quests")
	await _frames(5)
	if abm != null and home != "":
		abm.set_active_biome(home)
	await _frames(5)
	var g3 := _cue("after_market")
	if Guide.shortage != "🧺" or "🧺" not in str(g3.get("text", "")):
		_fail("after leaving the Market unbought the cue is gone: %s" % str(g3.get("text", "")))
	await _frames(30)
	var g3b := _cue("after_market_later")
	if Guide.shortage != "🧺":
		_fail("the cue faded with time while 🧺 is still 0: %s" % str(g3b.get("text", "")))
	Guide._no_trade_until.erase("🧺|Village")

	# --- 3. 🧺 back: the cue clears ---------------------------------------------
	_put(econ, "🧺", 4)
	await _frames(2)
	var g4 := _cue("restored")
	if Guide.shortage != "":
		_fail("🧺×4 in hand and the cue still walks to baskets: %s" % str(g4.get("text", "")))

	# --- 4. stranded: no trade payable, the fee is waived -----------------------
	_put(econ, "🧺", 0)
	_put(econ, "👥", 3)
	_put(econ, "🌾", 0)
	await _frames(2)
	if not StapleRescue.stranded("🧺", 1, econ):
		_fail("0🧺 · 3👥 · 0🌾 does not read as stranded")
	if econ.get_action_cost("pop").has("🧺"):
		_fail("stranded wallet still charged 🧺 for Gather: %s" % str(econ.get_action_cost("pop")))
	if UIProgression.gather_price() != 0:
		_fail("stranded gather_price() is %d, not 0" % UIProgression.gather_price())
	var g5 := _cue("stranded")
	if Guide.shortage == "🧺":
		_fail("stranded: the cue walks to a trade the wallet can't pay: %s" % str(g5.get("text", "")))
	if "free" not in str(g5.get("text", "")):
		_fail("stranded: the cue does not say the gather is free: %s" % str(g5.get("text", "")))
	var inst = farm.instrument
	var biome_name := "TheDemos"
	var positions: Array = farm.grid.get_plot_positions_for_biome(biome_name)
	if inst == null or positions.is_empty():
		_fail("no instrument / no %s plots to drive" % biome_name)
	else:
		if abm != null:
			abm.set_active_biome(biome_name)
		await _frames(3)
		var gathered := false
		for gp in positions:
			var ex: Dictionary = inst.action_explore(biome_name, gp)
			if not bool(ex.get("success", false)):
				continue
			var st: Dictionary = inst.action_measure(gp)
			if not bool(st.get("success", false)):
				_fail("stranded strike refused: %s" % str(st.get("message", "")))
				break
			var before := {"👥": int(econ.get_resource("👥")), "🌾": int(econ.get_resource("🌾"))}
			var pop: Dictionary = inst.action_pop(gp)
			_out["stranded_pop"] = {"success": pop.get("success", false), "message": str(pop.get("message", "")),
					"resource": str(pop.get("resource", "")), "before": before}
			if not bool(pop.get("success", false)):
				_fail("stranded gather refused: %s" % str(pop.get("message", "")))
			elif int(econ.get_resource("🧺")) != 0:
				_fail("stranded gather moved 🧺 to %d" % int(econ.get_resource("🧺")))
			gathered = true
			break
		if not gathered:
			_fail("could not explore any %s plot to drive the stranded lap" % biome_name)
	# A payable chain brings the fee back: 4🌾 buys 👥, 👥 buys 🧺.
	_put(econ, "🧺", 0)
	_put(econ, "👥", 3)
	_put(econ, "🌾", 4)
	if StapleRescue.stranded("🧺", 1, econ):
		_fail("4🌾 (🌾→👥→🧺 payable) still reads as stranded")
	if not econ.get_action_cost("pop").has("🧺"):
		_fail("the gather fee did not come back once a trade chain was payable")

	# --- 5. no wallet is a dead end ---------------------------------------------
	var dead: Array = []
	var checked := 0
	for b in [0, 1]:
		for p in [0, 1, 3, 6]:
			for w in [0, 1, 3, 4]:
				for br in [0, 1]:
					_put(econ, "🧺", b)
					_put(econ, "👥", p)
					_put(econ, "🌾", w)
					_put(econ, "🍞", br)
					for verb in ["pop", "measure", "explore"]:
						checked += 1
						var cost: Dictionary = econ.get_action_cost(verb)
						if econ.can_afford_cost(cost):
							continue
						var staple := StapleRescue.staple_for(verb)
						# Not payable and not free: a Village chain must reach it.
						if StapleRescue.stranded(staple, int(cost.get(staple, 1)), econ):
							dead.append("%s with 🧺%d 👥%d 🌾%d 🍞%d" % [verb, b, p, w, br])
	_out["sweep_checked"] = checked
	if not dead.is_empty():
		_fail("dead-end wallets: %s" % str(dead))
	_finish()
