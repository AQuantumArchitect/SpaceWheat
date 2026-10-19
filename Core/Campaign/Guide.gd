class_name Guide
extends RefCounted

## The guidance resolver: the live campaign beat + the game and UI state →
## the next press. The banner (UIProgression.objective_text), the key
## spotlight and the guide toasts all read next_step(); none of them write
## their own "▸ [KEY]" lines for a beat this resolver covers.
##
## HOW each kind of objective is done is data: campaign.json `guide.walks`
## (one ordered step list per objective predicate type) and `guide.keymap`
## (the only place keys are spelled). Each step kind below is implemented
## once: it is either already done in the current state, or it renders the
## chord that does it from HERE (which overlay is open, which hat is worn,
## which plot is focused). The first step not done is the answer. Docs:
## docs/design/GUIDANCE_FROM_THE_SPEC.md.
##
## next_step() returns {} when it does not cover the live beat (Act 0's
## lessons, objective types with no walk yet); the caller falls back to the
## legacy banner line. Coverage is measured by 🍄/🧪/banner_follow.py.

const SATISFIED := 0.85
const BERRY_ROWS := 6
const UIP = preload("res://UI/Core/UIProgression.gd")
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const GranularityController = preload("res://Core/Utilities/GranularityController.gd")

# ---------------------------------------------------------------- keymap

static func _km() -> Dictionary:
	var g := CampaignRuntime.guide()
	var k = g.get("keymap", {})
	return k if k is Dictionary else {}


static func _walks() -> Dictionary:
	var w = CampaignRuntime.guide().get("walks", {})
	return w if w is Dictionary else {}


static func _verb(name: String) -> String:
	return str(_km().get("verbs", {}).get(name, ""))


static func _hat_key(hat: String) -> String:
	return str(_km().get("hats", {}).get(hat, ""))


static func _hat_name(hat: String) -> String:
	return str(_km().get("hat_names", {}).get(hat, hat.capitalize()))


static func _row_key(i: int) -> String:
	var rows: Array = _km().get("rows", [])
	return str(rows[i]) if i >= 0 and i < rows.size() else ""


static func _plot_key(col: int) -> String:
	var plots: Array = _km().get("plots", [])
	return str(plots[col]) if col >= 0 and col < plots.size() else ""


# ---------------------------------------------------------------- chords

## A step's render: the keys in pressing order plus the words between them.
## text reads "▸ <words with [KEY]s>" — the same keys, the same order.
static func _chord(parts: Array, beat: Dictionary = {}, why: String = "") -> Dictionary:
	var keys: Array = []
	var words: Array = []
	for p in parts:
		if p is Array:  # [label, key]; "shift+F" renders SHIFT [F]
			var label := str(p[0])
			var key := str(p[1])
			keys.append(key)
			if key.to_lower().begins_with("shift+"):
				words.append(("%s SHIFT [%s]" % [label, key.substr(6)]).strip_edges())
			else:
				words.append(("%s [%s]" % [label, key]).strip_edges())
		else:
			words.append(str(p))
	return {"text": "▸ " + ", ".join(words), "keys": keys,
			"beat": str(beat.get("source_flag", "")), "why": why}


static func _wait(text: String, beat: Dictionary, why: String) -> Dictionary:
	return {"text": "▸ " + text, "keys": [], "beat": str(beat.get("source_flag", "")),
			"why": why, "wait": true}


## Prefix that clears whatever overlay is open, when the next part of the
## chord needs the field (or a different overlay).
static func _close_first() -> Array:
	if UIP._menu_open() or UIP._in_icon_submenu() or UIP._in_gate_submenu():
		return [["close", str(_km().get("close", "ESC"))]]
	return []


static func _overlay_manager():
	var shell := UIP._shell()
	if shell == null or not ("overlay_manager" in shell):
		return null
	return shell.overlay_manager


# ---------------------------------------------------------------- ranking

## THE live beat: the one campaign quest (offer or accepted) the player should
## work on now. A ready claim first (cheap, and it opens doors), then the
## critical path — beats some campaign ENDING requires, transitively — then the
## earliest act; an accepted quest beats an unsigned one of the same rank.
## Optional branches (the pond, the forest's deeper verses) wait their turn.
static func live_beat(qm = null) -> Dictionary:
	if qm == null:
		qm = UIP._quest_manager()
	if qm == null or not ("active_quests" in qm):
		return {}
	var farm = UIP._active_farm()
	var fired: Dictionary = farm.story_flags_fired if farm != null and "story_flags_fired" in farm else {}
	var acts := {}
	var requires := {}
	if qm.has_method("get_all_story_flags"):
		for f in qm.get_all_story_flags():
			if not (f is Dictionary):
				continue
			var fid := str(f.get("id", ""))
			acts[fid] = int(f.get("act", 0))
			var req: Array = []
			for p in f.get("predicates", []):
				if p is Dictionary and str(p.get("type", "")) == "story_flag_set":
					req.append(str(p.get("id", "")))
			requires[fid] = req
	var blocking := _critical_path(requires, fired)
	var best: Dictionary = {}
	var best_rank := 0x7FFFFFFF
	var pools: Array = [qm.active_quests.values()]
	if qm.has_method("get_story_offers"):
		pools.append(qm.get_story_offers())
	for pool in pools:
		for q in pool:
			if not (q is Dictionary):
				continue
			var src := str(q.get("source_flag", ""))
			if src == "" or str(q.get("category", "")) == "TUTORIAL":
				continue
			var unsigned := str(q.get("status", "")) == Quest.STATUS_STORY
			var rank := int(acts.get(src, 99)) * 10
			if not blocking.has(src):
				rank += 1000
			if unsigned:
				rank += 1
			if _is_ready(q):
				rank -= 2000
			if rank < best_rank:
				best_rank = rank
				best = q
	return best


## Every unfired beat a campaign ending needs, transitively (the endings
## come from the spec: campaigns[].ending).
static func _critical_path(requires: Dictionary, fired: Dictionary) -> Dictionary:
	var out := {}
	var stack: Array = []
	for c in CampaignRuntime.campaigns():
		if c is Dictionary and str(c.get("ending", "")) != "":
			stack.append(str(c.get("ending", "")))
	while not stack.is_empty():
		var fid: String = stack.pop_back()
		if out.has(fid):
			continue
		out[fid] = true
		for r in requires.get(fid, []):
			stack.append(r)
	return out


static func _is_ready(q: Dictionary) -> bool:
	return str(q.get("status", "")).to_lower() == "ready"


# ---------------------------------------------------------------- resolver

static func next_step() -> Dictionary:
	if UIP.current_tutorial_step() != UIP.NO_TUTORIAL_SENTINEL:
		return _tutorial_step()
	var q := live_beat()
	if q.is_empty():
		return _auto_beat_step()
	if str(q.get("status", "")) == Quest.STATUS_STORY:
		return _door_accept(q)
	if _is_ready(q):
		return _door_claim(q)
	var open := _open_predicates(q)
	if open.is_empty():
		return _door_claim(q)  # satisfied; the quest flips to ready on its own tick
	return _across(open, q)


## One next step across a beat's open predicates. Each predicate offers the
## first step of its walk; an action (a key that changes the game) beats a
## wait, and a wait beats a setup (a hat or a trip). So two predicates that
## want different hats never trade the hat back and forth: whichever can act
## in the current hat acts, and the other waits its turn. A held collapse
## (steer's "hold") is idle, ranked below everything.
static func _across(preds: Array, q: Dictionary) -> Dictionary:
	var wait := {}
	var setup := {}
	var idle := {}  # a held collapse: nothing to do, and nothing lost by doing something else
	for pred in preds:
		var walk = _walks().get(str(pred.get("type", "")), null)
		if not (walk is Array):
			continue
		for step in walk:
			var r := _step(str(step), pred, q)
			if r.is_empty():
				continue
			var why := str(r.get("why", ""))
			if why == "hold":
				if idle.is_empty():
					idle = r
			elif why == "hat" or why == "travel":
				if setup.is_empty():
					setup = r
			elif (r.get("keys", []) as Array).is_empty():
				if wait.is_empty():
					wait = r
			else:
				return r
			break
	if not wait.is_empty():
		return wait
	if not setup.is_empty():
		return setup
	return idle


## No door is open, but a beat with no offer (it fires on its objective
## alone) may be waiting with its requires met: walk its objective.
static func _auto_beat_step() -> Dictionary:
	var qm = UIP._quest_manager()
	var farm = UIP._active_farm()
	if qm == null or farm == null or not qm.has_method("get_all_story_flags"):
		return {}
	var fired: Dictionary = farm.story_flags_fired if "story_flags_fired" in farm else {}
	for f in qm.get_all_story_flags():
		if not (f is Dictionary) or fired.has(str(f.get("id", ""))) or f.get("arc_quest") is Dictionary:
			continue
		var preds: Array = []
		var ready := true
		for p in f.get("predicates", []):
			if not (p is Dictionary):
				continue
			if str(p.get("type", "")) == "story_flag_set":
				if not fired.has(str(p.get("id", ""))):
					ready = false
			else:
				preds.append(p)
		if not ready or preds.is_empty():
			continue
		var pseudo := {"source_flag": str(f.get("id", "")), "state_predicates": preds}
		var r := _across(_open_predicates(pseudo), pseudo)
		if not r.is_empty():
			return r
	return {}


## Act 0: the live lesson's walk is `walks["lesson:<teaches>"]`.
static func _tutorial_step() -> Dictionary:
	var qm = UIP._quest_manager()
	if qm == null:
		return {}
	var q: Dictionary = {}
	var best := 0x7FFFFFFF
	for pool in [qm.active_quests.values(), qm.get_story_offers() if qm.has_method("get_story_offers") else []]:
		for t in pool:
			if t is Dictionary and str(t.get("category", "")) == "TUTORIAL" \
					and int(t.get("tutorial_step", 0)) < best:
				best = int(t.get("tutorial_step", 0))
				q = t
	if q.is_empty():
		return {}
	var walk = _walks().get("lesson:" + str(q.get("tutorial_teaches", "")), null)
	if not (walk is Array):
		return {}
	var pred: Dictionary = {}
	var open := _open_predicates(q)
	if not open.is_empty():
		pred = open[0]
	for step in walk:
		var r := _step(str(step), pred, q)
		if not r.is_empty():
			return r
	return {}


static func _open_predicates(q: Dictionary) -> Array:
	var qm = UIP._quest_manager()
	var out: Array = []
	for pred in q.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		if qm != null and qm.has_method("evaluate_predicate_score") \
				and float(qm.evaluate_predicate_score(pred)) >= SATISFIED:
			continue
		out.append(pred)
	return out


static func _step(step: String, pred: Dictionary, q: Dictionary) -> Dictionary:
	var parts := step.split(":", true, 1)
	var kind := parts[0]
	var arg := parts[1] if parts.size() > 1 else ""
	match kind:
		"travel":
			return _travel(str(pred.get("biome", "")), q)
		"hat":
			return _hat(arg, q)
		"berry":
			return _berry(q)
		"deliver_to":
			return _deliver_to(str(pred.get("faction", "")), q)
		"chart":
			return _chart(str(pred.get("biome", "")), q)
		"gate":
			return _gate(pred, q)
		"plant_atom":
			return _plant(str(pred.get("biome", "")), str(pred.get("atom", pred.get("emoji", ""))), false, q)
		"plant_new":
			return _plant(str(pred.get("biome", _km().get("plant_home", "Village"))), "", true, q)
		"learn_word":
			return _learn_word(q)
		"take_door":
			return _take_any_door(pred.get("ids", []), q)
		"go":
			return _travel(arg, q)
		"strike":
			return _strike_once(arg, q)
		"deliver_lesson":
			return _deliver_lesson(q)
		"plot_verb":
			return _plot_verb(arg, q)
		"pair_gate":
			return _pair_gate(arg, q)
		"reap":
			return _reap(arg, q)
		"measure":
			return _strike_once(UIP._active_biome_name(), q)
		"superpose":
			return _superpose(q)
		"evolve":
			return _evolve(str(pred.get("biome", "")), q)
		"steer":
			return _steer(str(pred.get("biome", "")), str(pred.get("emoji", pred.get("atom", ""))), q)
	return {}


# ---------------------------------------------------------------- doors

static func _door_accept(q: Dictionary) -> Dictionary:
	var title := _title(q)
	var idx := _arc_row_index(q)
	var row: Array = []
	if idx >= 0 and idx < BERRY_ROWS:
		row = [[title, _row_key(idx)]]
	var om = _overlay_manager()
	var arc_open: bool = om != null and om.has_method("is_event_home_open") and bool(om.is_event_home_open("arc"))
	if arc_open:
		return _chord(row + [["Accept", _verb("accept")]], q, "accept")
	var surf: Dictionary = _km().get("surfaces", {}).get("arc", {})
	var opens: Array = surf.get("open", ["X", "I"])
	var parts: Array = _close_first()
	parts.append(["📖", str(opens[0])])
	parts.append([str(surf.get("name", "Arc")), str(opens[1])])
	return _chord(parts + row + [["Accept", _verb("accept")]], q, "accept")


static func _door_claim(q: Dictionary) -> Dictionary:
	return _board_row_chord("commitments", _commitment_index(q), _title(q), "Claim", _verb("claim"), q, "claim")


static func _board_row_chord(surface: String, idx: int, label: String, verb_label: String,
		verb_key: String, q: Dictionary, why: String) -> Dictionary:
	var surf: Dictionary = _km().get("surfaces", {}).get(surface, {})
	var opens: Array = surf.get("open", ["C", "U"])
	var board = UIP._quest_board()
	var on_tab: bool = UIP._board_open() and board != null and "frame_id" in board \
			and str(board.frame_id) == surface
	var parts: Array = []
	if not on_tab:
		if UIP._board_open():
			parts.append([str(surf.get("name", surface.capitalize())), str(opens[1])])
		else:
			parts += _close_first()
			parts.append(["board", str(opens[0])])
			parts.append([str(surf.get("name", surface.capitalize())), str(opens[1])])
	if idx >= BERRY_ROWS:
		for _p in range(idx / BERRY_ROWS):
			parts.append(["next page", str(_km().get("page_next", "D"))])
	if idx >= 0:
		parts.append([label, _row_key(idx % BERRY_ROWS)])
	parts.append([verb_label, verb_key])
	return _chord(parts, q, why)


static func _arc_row_index(q: Dictionary) -> int:
	var rows: Array = IntroVoice.doors_ahead(BERRY_ROWS)
	for i in range(rows.size()):
		var data = rows[i].get("data", {})
		if data is Dictionary and int(data.get("id", -1)) == int(q.get("id", -2)):
			return i
	return -1


static func _commitment_index(q: Dictionary) -> int:
	var qm = UIP._quest_manager()
	if qm == null or not qm.has_method("commitment_quests"):
		return -1
	var rows: Array = qm.commitment_quests()
	for i in range(rows.size()):
		if rows[i] is Dictionary and int(rows[i].get("id", -1)) == int(q.get("id", -2)):
			return i
	return -1


static func _title(q: Dictionary) -> String:
	var t := str(q.get("display_name", "")).strip_edges()
	if t == "":
		t = str(q.get("body", "")).split(" — ")[0].strip_edges()
	return t


# ---------------------------------------------------------------- field steps

static func _travel(biome: String, q: Dictionary) -> Dictionary:
	if biome == "" or UIP._active_biome_name() == biome:
		return {}
	var abm := UIP._active_biome_manager()
	if abm == null:
		return {}
	var slot := int(abm.get_slot_for_biome(biome))
	if slot < 0:
		return _chart(biome, q)
	var key := str(abm.get_slot_key(slot)).to_upper()
	return _chord(_close_first() + [["to " + biome, key]], q, "travel")


## The plot the field cursor is on right now. Ace's F/R/Q act on this one
## (no focus: F fast-forwards instead of exploring); Icon's track/incorporate
## also accept the sticky last plot, which UIP._focused_col() reports.
static func _live_col() -> int:
	var inst = UIP._instrument()
	if inst == null or not ("current_plot_idx" in inst):
		return -1
	return int(inst.current_plot_idx)


static func _hat(hat: String, q: Dictionary) -> Dictionary:
	if str(ToolConfig.get_current_frame()) == hat:
		return {}
	return _chord(_close_first() + [[_hat_name(hat) + " hat", _hat_key(hat)]], q, "hat")


## Berry ritual on the active biome: incorporate a ripe loop, else track a
## qubit that is not tracked yet (any qubit — tracking needs a focused
## register column, not an explored plot), else let time ripen the loops.
static func _berry(q: Dictionary, only: Array = []) -> Dictionary:
	var reg = UIP._berry_register()
	var biome := UIP._active_biome_name()
	var farm = UIP._active_farm()
	if reg == null or farm == null or farm.grid == null:
		return {}
	var qc = farm.grid.get_biome(biome).quantum_computer
	var nq: int = int(qc.register_map.num_qubits) if qc != null and qc.register_map != null else 0
	var focused := UIP._focused_col()
	var n := mini(nq, BERRY_ROWS)
	for col in range(n):
		if not only.is_empty() and not (col in only):
			continue
		if bool(reg.is_ripe(col)):
			var parts: Array = _close_first()
			if focused != col:
				parts.append(["plot", _plot_key(col)])
			parts.append(["Incorporate", _verb("incorporate")])
			return _chord(parts, q, "incorporate")
	var pick := -1
	for col in range(n):
		if not only.is_empty() and not (col in only):
			continue
		if bool(reg.is_tracked(col)):
			continue
		if qc.has_method("qubit_has_transverse_term") and not qc.qubit_has_transverse_term(col):
			continue
		pick = col
		break
	if pick >= 0:
		var parts: Array = _close_first()
		if focused != pick:
			parts.append(["plot", _plot_key(pick)])
		parts.append(["Track", _verb("track")])
		return _chord(parts, q, "track")
	if UIP._sim_paused():
		return _chord(_close_first() + [["Ace hat", _hat_key("ace")], ["resume", "E"]], q, "resume")
	var stride := int(GranularityController.get_current_stride([farm.grid.get_biome(biome)]))
	if stride < int(_km().get("clock_max_stride", 32)):
		return _chord(_close_first() + ["loops ripening", ["faster clock", _verb("faster")]], q, "clock")
	return _wait("loops ripening — wait", q, "ripen")


## Standing is earned by keeping a faction's contracts. On that faction's
## board: deliver a held contract the wallet covers; gather for one it does
## not; drop one that is far out of reach; else take the most keepable offer.
static func _deliver_to(faction: String, q: Dictionary) -> Dictionary:
	if faction == "":
		return {}
	var home := str(_km().get("boards", {}).get(faction, "Village"))
	var qm = UIP._quest_manager()
	var held: Array = []
	if qm != null and qm.has_method("commitment_quests"):
		for c in qm.commitment_quests():
			if c is Dictionary and str(c.get("source_flag", "")) == "" \
					and str(c.get("faction", "")) == faction and str(c.get("resource", "")) != "":
				held.append(c)
	for c in held:
		var res := str(c.get("resource", ""))
		var need := int(c.get("quantity", 0))
		var have := int(UIP._wallet(res))
		if have >= need:
			return _market_held_chord(c, home, ["Deliver", _verb("deliver")], q, "deliver")
		if need - have <= int(_km().get("reach", 12)):
			return _gather(res, need, q)
		return _market_held_chord(c, home, ["Abandon", "Q"], q, "abandon", ["confirm", "F"])
	var t := _travel(home, q)
	if not t.is_empty():
		return t
	var board = UIP._quest_board()
	if not (UIP._board_open() and board != null and str(board.get("frame_id")) == "market"):
		return _open_surface("market", q)
	var rows: Array = board._market_rows()
	var best := -1
	var best_short := 1 << 30
	for i in range(rows.size()):
		var r: Dictionary = rows[i]
		var d = r.get("data", {})
		if str(r.get("kind", "")) != "offer" or not (d is Dictionary) or bool(d.get("supply_trade", false)):
			continue
		if str(d.get("faction", "")) != faction:
			continue
		var res := str(d.get("resource", ""))
		var short := int(d.get("quantity", 0)) - int(UIP._wallet(res))
		if short < best_short:
			best_short = short
			best = i
	if best >= 0 and best_short <= int(_km().get("reach", 12)):
		var d: Dictionary = rows[best].get("data", {})
		return _chord(_page_to(best) + [["%s %s×%d" % [faction, str(d.get("resource", "")),
				int(d.get("quantity", 0))], _row_key(best % BERRY_ROWS)], ["Accept", _verb("accept")]],
				q, "take contract")
	return _chord(["no keepable %s contract" % faction, ["Refresh", _verb("refresh")]], q, "refresh")


## The page presses that bring row `idx` into view, from the page the board
## shows now (a board that is about to open starts on page one).
static func _page_to(idx: int) -> Array:
	var out: Array = []
	var board = UIP._quest_board()
	var cur := int(board.get("_item_page")) if UIP._board_open() and board != null else 0
	var want := idx / BERRY_ROWS
	for _p in range(absi(want - cur)):
		if want > cur:
			out.append(["next page", str(_km().get("page_next", "D"))])
		else:
			out.append(["previous page", str(_km().get("page_prev", "A"))])
	return out


static func _open_surface(surface: String, q: Dictionary) -> Dictionary:
	var surf: Dictionary = _km().get("surfaces", {}).get(surface, {})
	var opens: Array = surf.get("open", ["C", "Y"])
	var parts: Array = []
	if UIP._board_open():
		parts.append([str(surf.get("name", surface)), str(opens[1])])
	else:
		parts += _close_first()
		parts.append(["board", str(opens[0])])
		parts.append([str(surf.get("name", surface)), str(opens[1])])
	return _chord(parts, q, "open " + surface)


## A held contract is a row on the Market tab of its board (held stalls come
## first there): travel, open, select it, then the verb.
static func _market_held_chord(c: Dictionary, home: String, verb: Array, q: Dictionary,
		why: String, tail: Array = []) -> Dictionary:
	var t := _travel(home, q)
	if not t.is_empty():
		return t
	var board = UIP._quest_board()
	if not (UIP._board_open() and board != null and str(board.get("frame_id")) == "market"):
		return _open_surface("market", q)
	var rows: Array = board._market_rows()
	for i in range(rows.size()):
		var d = rows[i].get("data", {})
		if str(rows[i].get("kind", "")) == "held" and d is Dictionary and int(d.get("id", -1)) == int(c.get("id", -2)):
			var parts: Array = _page_to(i) + [["%s %s×%d" % [str(c.get("faction", "")), str(c.get("resource", "")),
					int(c.get("quantity", 0))], _row_key(i % BERRY_ROWS)], verb]
			if not tail.is_empty():
				parts.append(tail)
			return _chord(parts, q, why)
	return {}


## Gather `res` up to `need` on a biome whose registers carry it (the spec's
## resources table): Ace hat, a plot showing the glyph, Explore → Strike →
## Gather. Each press is one step, read from the focused plot's state.
## Strikes that came up the other pole, per resource. After MISS_CAP misses
## in a row the land is leaning away from it, so the market trade is the route.
static var _misses := {}
static var _counted := {}   # this measurement was already counted (next_step runs every frame)
const MISS_CAP := 3

static func _gather(res: String, need: int, q: Dictionary, depth: int = 0) -> Dictionary:
	var info := CampaignRuntime.resource(res)
	var plots: Array = info.get("plots", [])
	var abm := UIP._active_biome_manager()
	var where := ""
	if UIP._active_biome_name() in plots:
		where = UIP._active_biome_name()
	else:
		for b in plots:
			if abm != null and int(abm.get_slot_for_biome(str(b))) >= 0:
				where = str(b)
				break
	if where == "":
		where = _biome_carrying(res)
	if where == "" or (int(_misses.get(res, 0)) >= MISS_CAP and not _trade_ruled_out(res)):
		var sup := _supply(res, q, depth)
		if not sup.is_empty():
			return sup
		if where == "":
			return _wait("no %s on the market ring yet — wait for it to turn" % res, q, "no route " + res)
	var t := _travel(where, q)
	if not t.is_empty():
		return t
	var h := _hat("ace", q)
	if not h.is_empty():
		return h
	var col := _live_col()
	var label := "gather %s %d/%d" % [res, int(UIP._wallet(res)), need]
	if col >= 0 and UIP._plot_measured(col):
		var got := UIP._measured_glyph(col)
		if got == res:
			_misses[res] = 0
		elif got != "" and not _counted.get(res, false):
			_misses[res] = int(_misses.get(res, 0)) + 1
		_counted[res] = true
		return _cost_or(["gather", "🧺"], _chord(_close_first() + [label, ["Gather", _verb("gather")]], q, "gather"), q, depth)
	_counted[res] = false
	if col >= 0 and UIP._plot_bound(col):
		return _cost_or(["strike", "👥"], _chord(_close_first() + [label, ["Strike", _verb("strike")]], q, "strike"), q, depth)
	var key := UIP._glyph_plot_key(res)
	if key == "":
		key = _plot_key(0)
	var parts: Array = _close_first() + [label]
	if col < 0 or _plot_key(col) != key:
		parts.append(["plot", key])
	parts.append(["Explore", _verb("explore")])
	return _chord(parts, q, "explore")


## A loaded biome whose register carries `glyph` (active biome first).
static func _biome_carrying(glyph: String) -> String:
	var farm = UIP._active_farm()
	var abm := UIP._active_biome_manager()
	if farm == null or farm.grid == null or abm == null:
		return ""
	var names: Array = [UIP._active_biome_name()]
	for b in ["Village", "TheDemos", "StarterForest", "Woodlot", "FreshwaterSpring"]:
		if not b in names:
			names.append(b)
	for b in names:
		if int(abm.get_slot_for_biome(str(b))) < 0:
			continue
		var biome = farm.grid.get_biome(str(b))
		if biome != null and biome.quantum_computer != null and biome.quantum_computer.register_map != null \
				and biome.quantum_computer.register_map.has(glyph):
			return str(b)
	return ""


## The step itself if its spend is covered; else the supply walk for it.
static func _cost_or(spend: Array, step: Dictionary, q: Dictionary, depth: int) -> Dictionary:
	var res := str(spend[1])
	if depth < 2 and UIP._wallet(res) < 1.0:
		return _supply(res, q, depth + 1)
	return step


## A resource no biome here grows: its standing trade on a board (the spec's
## `trades`) — the rescue that keeps an empty wallet from being a dead end.
## A trade found missing on the open market ring is ruled out for a while,
## so a gather that falls back to it does not open, close and reopen the
## board. (The ring is re-dealt when it opens, so a closed read can't decide.)
static var _no_trade_until := {}
const NO_TRADE_MS := 90000

static func _trade_ruled_out(res: String) -> bool:
	return Time.get_ticks_msec() < int(_no_trade_until.get(res, 0))


static func _supply(res: String, q: Dictionary, depth: int) -> Dictionary:
	var trades: Array = CampaignRuntime.supply_trades(res)
	if trades.is_empty():
		return {}
	var tr: Dictionary = trades[0]
	var home := str(tr.get("biome", "Village"))
	var t := _travel(home, q)
	if not t.is_empty():
		return t
	if _trade_ruled_out(res):
		return {}
	var board = UIP._quest_board()
	if board == null:
		return {}
	if not (UIP._board_open() and str(board.get("frame_id")) == "market"):
		return _open_surface("market", q)
	var rows: Array = board._market_rows()
	for i in range(rows.size()):
		var d = rows[i].get("data", {})
		if not (d is Dictionary) or not bool(d.get("supply_trade", false)):
			continue
		if str(d.get("supply_emoji", "")) != res:
			continue
		var give: Dictionary = d.get("give", {}) if d.get("give", {}) is Dictionary else {}
		if give.is_empty() and str(d.get("resource", "")) != "":
			give = {str(d.get("resource", "")): int(d.get("quantity", 0))}  # as QuestManager settles it
		for g in give:
			if UIP._wallet(str(g)) < float(give[g]) and depth < 2:
				return _gather(str(g), int(give[g]), q, depth + 1)
		var verb: Array = ["Deliver", _verb("deliver")] if str(rows[i].get("kind", "")) == "held" \
				else ["Accept", _verb("accept")]
		return _chord(_page_to(i) + [["trade for %s" % res, _row_key(i % BERRY_ROWS)], verb], q, "supply " + res)
	_no_trade_until[res] = Time.get_ticks_msec() + NO_TRADE_MS
	return {}


## Chart a story biome: Captain's R while its door is open, paid in 🦅.
static func _chart(biome: String, q: Dictionary) -> Dictionary:
	var abm := UIP._active_biome_manager()
	if biome == "" or (abm != null and int(abm.get_slot_for_biome(biome)) >= 0):
		return {}
	var cost := int(CampaignRuntime.chart_cost().get("🦅", 21))
	if UIP._wallet("🦅") < float(cost):
		return _gather("🦅", cost, q)
	var parts: Array = _close_first()
	if str(ToolConfig.get_current_frame()) != "captain":
		parts.append([_hat_name("captain") + " hat", _hat_key("captain")])
	parts.append(["Chart " + biome, _verb("chart")])
	return _chord(parts, q, "chart")


## gate_sequence_contains inject_icon: plant a known word in an empty plot.
static func _gate(pred: Dictionary, q: Dictionary) -> Dictionary:
	var gate := str(pred.get("gate", "")).to_lower()
	if gate == "reap":
		return _reap(str(_km().get("reap_home", "TheDemos")), q)
	if gate != "inject_icon" and gate != "plant":
		return {}
	return _plant(str(_km().get("plant_home", "Village")), "", false, q)


## Plant a word into `biome`: the one whose poles include `atom` when named,
## else one that brings new atoms when `fresh`, else the picker's first.
## Pays first (the word's own cost, from the picker's options), then Icon
## hat, an empty plot, R opens the picker, and the picker key for the word.
static func _plant(biome: String, atom: String, fresh: bool, q: Dictionary) -> Dictionary:
	var farm = UIP._active_farm()
	if farm == null or farm.grid == null:
		return {}
	var inst = UIP._instrument()
	if UIP._in_icon_submenu() and inst != null:
		var data: Dictionary = inst.current_submenu_data
		var actions: Dictionary = data.get("actions", {})
		for key in ["Q", "E", "R"]:
			var a = actions.get(key, {})
			if a is Dictionary and _word_fits(a.get("icon", {}), atom) and bool(a.get("can_afford", true)):
				return _chord([[str(a.get("label", "word")), key]], q, "pick word")
		if int(data.get("max_pages", 1)) > 1:
			return _chord([["more words", "F"]], q, "picker page")
		return _chord(_close_first(), q, "no fitting word here")
	var target = farm.grid.get_biome(biome) if biome != "" else null
	if target != null and atom != "" and target.quantum_computer != null \
			and target.quantum_computer.register_map != null and target.quantum_computer.register_map.has(atom):
		return {}  # already planted; what the predicate still wants is a later step (steer)
	if target != null:
		var opts: Array = load("res://UI/Core/Submenus/IconInjectionSubmenu.gd")._collect_options(target, farm)
		var want: Dictionary = {}
		for o in opts:
			if not (o is Dictionary):
				continue
			if atom != "" and not _word_fits(o, atom):
				continue
			if fresh and atom == "":
				var coords: Dictionary = target.quantum_computer.register_map.coordinates
				if coords.has(str(o.get("north", ""))) and coords.has(str(o.get("south", ""))):
					continue
			want = o
			break
		if want.is_empty():
			return {}
		var cost: Dictionary = load("res://UI/Core/Submenus/IconInjectionSubmenu.gd")._get_injection_cost(
				farm, str(want.get("south", "")))
		for res in cost:
			if UIP._wallet(str(res)) < float(cost[res]):
				return _gather(str(res), int(cost[res]), q)
	var t := _travel(biome, q)
	if not t.is_empty():
		return t
	if not UIP._empty_plot_exists(biome):
		return {}
	var h := _hat("icon", q)
	if not h.is_empty():
		return h
	var key := UIP._empty_plot_key()
	var parts: Array = _close_first()
	if _plot_key(UIP._focused_col()) != key:
		parts.append(["empty plot", key])
	parts.append(["Plant", _verb("plant")])
	return _chord(parts, q, "plant")


static func _word_fits(icon: Dictionary, atom: String) -> bool:
	if atom == "":
		return true
	return str(icon.get("north", "")) == atom or str(icon.get("south", "")) == atom


## Learn a word you do not know yet: the berry ritual on a register whose
## word is not in your signature (Village first, then the other lands).
static func _learn_word(q: Dictionary) -> Dictionary:
	var farm = UIP._active_farm()
	var abm := UIP._active_biome_manager()
	if farm == null or farm.grid == null or abm == null:
		return {}
	var names: Array = [UIP._active_biome_name(), "Village", "StarterForest", "TheDemos", "Woodlot", "FreshwaterSpring"]
	for b in names:
		if int(abm.get_slot_for_biome(str(b))) < 0:
			continue
		if not _unknown_cols(str(b)).is_empty():
			var t := _travel(str(b), q)
			if not t.is_empty():
				return t
			var h := _hat("icon", q)
			if not h.is_empty():
				return h
			return _berry(q, _unknown_cols(str(b)))
	return {}


static func _unknown_cols(biome: String) -> Array:
	var farm = UIP._active_farm()
	var out: Array = []
	var b = farm.grid.get_biome(biome)
	if b == null or b.quantum_computer == null or b.quantum_computer.register_map == null:
		return out
	# A word joins the signature only if its NORTH pole is neither pole of a
	# word you already hold (Farm.discover_icon) — so "unknown" means an
	# unanchored north, not merely an unseen pair.
	var anchored: Dictionary = {}
	for ic in (farm.known_icons if "known_icons" in farm else []):
		if ic is Dictionary:
			anchored[str(ic.get("north", ""))] = true
			anchored[str(ic.get("south", ""))] = true
	var rm = b.quantum_computer.register_map
	for col in range(mini(int(rm.num_qubits), BERRY_ROWS)):
		var ax: Dictionary = rm.axis(col)
		if not anchored.has(str(ax.get("north", ""))):
			out.append(col)
	return out


## story_flag_any over door beats: accept the first of them on the Arc.
static func _take_any_door(ids: Array, q: Dictionary) -> Dictionary:
	var qm = UIP._quest_manager()
	if qm == null or not qm.has_method("get_story_offers"):
		return {}
	for o in qm.get_story_offers():
		if o is Dictionary and str(o.get("source_flag", "")) in ids:
			return _door_accept(o)
	return {}


# ---------------------------------------------------------------- Act 0 steps

## One measurement in `biome`: Ace, a plot, Explore, Strike.
static func _strike_once(biome: String, q: Dictionary) -> Dictionary:
	var t := _travel(biome, q)
	if not t.is_empty():
		return t
	var h := _hat("ace", q)
	if not h.is_empty():
		return h
	var col := _live_col()
	if col >= 0 and UIP._plot_measured(col):
		return _chord(_close_first() + [["Gather", _verb("gather")]], q, "gather")
	if col >= 0 and UIP._plot_bound(col):
		return _chord(_close_first() + [["Strike", _verb("strike")]], q, "strike")
	var parts: Array = _close_first()
	if col < 0:
		parts.append(["plot", _plot_key(0)])
	parts.append(["Explore", _verb("explore")])
	return _chord(parts, q, "explore")


## A lesson that is a delivery (resource × quantity): gather it, then claim.
static func _deliver_lesson(q: Dictionary) -> Dictionary:
	var res := str(q.get("resource", ""))
	var need := int(q.get("quantity", 0))
	if res == "" or need <= 0:
		return {}
	if UIP._wallet(res) < float(need):
		return _gather(res, need, q)
	return _door_claim(q)


## Select a plot (the focused one if any) and press the hat's verb key.
static func _plot_verb(key: String, q: Dictionary) -> Dictionary:
	var parts: Array = _close_first()
	if _live_col() < 0:
		parts.append(["plot", _plot_key(0)])
	parts.append([str(_km().get("verb_labels", {}).get(key, "do it")), key])
	return _chord(parts, q, "verb " + key)


## Two marked plots, then the gate: Operator hat, SHIFT-mark G and H, R opens
## the gate picker, `gate_key` picks the gate.
static func _pair_gate(gate_key: String, q: Dictionary) -> Dictionary:
	var inst = UIP._instrument()
	if UIP._in_gate_submenu():
		return _chord([["Bell pair", gate_key]], q, "pick gate")
	# Exactly two marks, both on THIS biome's ring: marks left from other
	# lessons (Ace G marks too) make a cross-biome pair that never weaves.
	var marks: Array = inst.checked_plots if inst != null and "checked_plots" in inst else []
	var rows := {}
	for m in marks:
		if m is Vector2i:
			rows[m.y] = true
	var good: bool = marks.size() == 2 and rows.size() == 1 and _marks_here(marks)
	var parts: Array = []
	if not good:
		if not marks.is_empty():
			parts.append(["clear marks", str(_km().get("clear_marks", "'"))])
		parts.append(["mark", "shift+" + _plot_key(0)])
		parts.append(["mark", "shift+" + _plot_key(1)])
	parts.append(["Build gate", "R"])
	return _chord(parts, q, "pair gate")


static func _marks_here(marks: Array) -> bool:
	var farm = UIP._active_farm()
	if farm == null or farm.grid == null or not farm.grid.has_method("get_plot_biome_assignments"):
		return false
	var a: Dictionary = farm.grid.get_plot_biome_assignments()
	for m in marks:
		if not (m is Vector2i) or str(a.get(m, "")) != UIP._active_biome_name():
			return false
	return true


## Reap the season in `biome`: Ace hat, then SHIFT+F.
static func _reap(biome: String, q: Dictionary) -> Dictionary:
	var t := _travel(biome, q)
	if not t.is_empty():
		return t
	var h := _hat("ace", q)
	if not h.is_empty():
		return h
	var parts: Array = _close_first()
	if _live_col() < 0:
		parts.append(["plot", _plot_key(0)])
	parts.append(["Reap the season", "shift+F"])
	return _chord(parts, q, "reap")


## Put coherence back: Druid hat, Hadamard [E] on the next plot in the ring.
static func _superpose(q: Dictionary) -> Dictionary:
	var h := _hat("druid", q)
	if not h.is_empty():
		return h
	var col := (_live_col() + 1) % BERRY_ROWS
	return _chord(_close_first() + [["plot", _plot_key(col)], ["Hadamard", "E"]], q, "superpose")


## Let a biome evolve and read itself: stand in it and run its clock fast.
static func _evolve(biome: String, q: Dictionary) -> Dictionary:
	var t := _travel(biome, q)
	if not t.is_empty():
		return t
	var farm = UIP._active_farm()
	var b = farm.grid.get_biome(UIP._active_biome_name()) if farm != null and farm.grid != null else null
	if b != null and int(GranularityController.get_current_stride([b])) < int(_km().get("clock_max_stride", 32)):
		return _chord(["let it evolve", ["faster clock", _verb("faster")]], q, "clock")
	return _wait("let it evolve — wait", q, "evolve")


## Pull a biome's attractor toward `emoji`: measure its qubit until the
## outcome IS that emoji, and hold it there (a collapse is the strongest
## nudge a player has). Another outcome is gathered away and struck again.
static func _steer(biome: String, emoji: String, q: Dictionary) -> Dictionary:
	var t := _travel(biome, q)
	if not t.is_empty():
		return t
	var h := _hat("ace", q)
	if not h.is_empty():
		return h
	var farm = UIP._active_farm()
	var b = farm.grid.get_biome(biome) if farm != null and farm.grid != null else null
	if b == null or b.quantum_computer == null or b.quantum_computer.register_map == null:
		return {}
	var col := int(b.quantum_computer.register_map.qubit(emoji))
	if col < 0 or col >= BERRY_ROWS:
		return {}
	var parts: Array = _close_first()
	if _live_col() != col:
		parts.append(["plot", _plot_key(col)])
	if UIP._plot_measured(col):
		if UIP._measured_glyph(col) == emoji:
			return _wait("%s holds at %s — wait for it to settle" % [emoji, biome], q, "hold")
		parts.append(["release", _verb("gather")])
		return _chord(parts, q, "release")
	if UIP._plot_bound(col):
		parts.append(["Strike for " + emoji, _verb("strike")])
		return _chord(parts, q, "steer")
	parts.append(["Explore", _verb("explore")])
	return _chord(parts, q, "explore")
