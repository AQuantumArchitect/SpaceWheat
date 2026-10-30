class_name IntroVoice
extends RefCounted

## ONE authority for plot copy: welcome, toast, banner ask, Arc postcard,
## recap, memoir. Surfaces project a Beat; they do not author a second "now".
## Growing into NarrativeSpine — class_name stays IntroVoice this step so
## existing smokes do not rot.
##
## Law: one beat, two tenses. Physics never on the face.
## Law: HUD popups are a tracker + a link.

const PredicateGloss = preload("res://Core/Quests/PredicateGloss.gd")

## Tutorial-step id → a short door title. Body/arc_beat remain the prose;
## this is only the bold beat name on the toast and the NOW card.
const TEACHES_TITLE := {
	"core_loop": "The Demos sleeps",
	"contracts": "The mill is buying",
	"wayfinding": "Past the hedge",
	"superposition": "Both poles at once",
	"entanglement": "The loom",
	"reap_season": "Reap the season",
}


static func welcome_title() -> String:
	return "You are The Demos"


static func welcome_fiction() -> PackedStringArray:
	# Identity only. The how lives on Guide. The 1D lane auto-accepts
	# onto the gold banner after dismiss — welcome does not send you
	# to Arc for a door you already hold. Optional offers wait on Arc.
	return PackedStringArray([
		"A people learning the quantum language of your own ground.",
		"Wheat and people — 🌾 / 👥 — the axis the island turns on.",
	])


static func welcome_verbs() -> Array:
	# Short names the spine agrees on. Guide (X → O) is the menu that
	# teaches them; the welcome splash does not reprint the cards.
	return [
		{
			"verb": "Explore",
			"key": "F",
			"story": "Wake a sleeping plot.",
			"how": "tap to select, tap again  ·  costs 🍞",
		},
		{
			"verb": "Strike",
			"key": "R",
			"story": "Lock an answer in — it banks on the plot.",
			"how": "tap the bubble again  ·  costs 👥",
		},
		{
			"verb": "Gather",
			"key": "Q",
			"story": "Take what collapse leaves; the plot sleeps.",
			"how": "tap the struck bubble again  ·  costs 🧺",
		},
	]


static func welcome_footer() -> String:
	return "Tap anywhere (or press F) to begin."


## True when this is the 1D lane — already accepted for the player.
## Banner is the tracker; a toast here is a second gold card.
static func is_auto_tutorial(quest: Dictionary, qm = null) -> bool:
	if qm != null and qm.has_method("tutorial_auto_accepts"):
		return bool(qm.tutorial_auto_accepts(quest))
	return str(quest.get("category", "")) == "TUTORIAL"


static func quest_title(quest: Dictionary) -> String:
	var named := str(quest.get("display_name", "")).strip_edges()
	if named != "":
		return named
	var teaches := str(quest.get("tutorial_teaches", "")).strip_edges()
	if TEACHES_TITLE.has(teaches):
		return str(TEACHES_TITLE[teaches])
	var body := str(quest.get("body", "")).strip_edges()
	if body != "":
		# "Title — rest" is the postcard law. Cutting at 42 ate the Wheel
		# down to "The Wheel Is Yours — open the Arc and…".
		var dash := body.find(" — ")
		if dash > 0:
			return body.substr(0, dash).strip_edges()
		return StoryAtlas.sentence_cut(body, 42).trim_suffix(".")
	var fac := str(quest.get("faction", "")).strip_edges()
	if fac != "":
		return fac
	return "A new door"


static func quest_hook(quest: Dictionary, max_chars: int = 160) -> String:
	var body := str(quest.get("body", "")).strip_edges()
	if body != "":
		return StoryAtlas.sentence_cut(body, max_chars)
	var hint := str(quest.get("tutorial_hint", quest.get("hint", ""))).strip_edges()
	if hint != "":
		return StoryAtlas.sentence_cut(hint, max_chars)
	return ""


static func quest_detail(quest: Dictionary) -> String:
	var hint := str(quest.get("tutorial_hint", quest.get("hint", ""))).strip_edges()
	return hint


## PlayerEventBridge composes offer toasts from this.
## Auto-accepted lane steps: no toast (banner is the tracker — no dual gold).
## Unsigned offers: gold tracker + link to Arc. Market: log only.
static func toast_for_offer(quest: Dictionary, qm = null) -> Dictionary:
	if is_auto_tutorial(quest, qm):
		return {}
	# Wave 23: plant-short banner already names Forest. A gold Arc toast
	# on top sent earnest to the picker at 🌱×3 (dual gold).
	if _offer_is_plant(quest) and _sprouts_are_short():
		return {}
	# READY / accepted live work owns the banner. Leftover unsigned catalog
	# (Five Keys, Stay Yourself) is Arc, not a second gold toast.
	var live := live_quest(qm)
	if not live.is_empty() and str(live.get("status", "")) != "story":
		return {}
	var category := str(quest.get("category", ""))
	var is_arc := category == "TUTORIAL" or str(quest.get("source_flag", "")).strip_edges() != ""
	var title := quest_title(quest)
	if is_arc:
		return {
			# No key path here: a toast outlives the surface it was raised on.
			# The line at the top names the keys from wherever you are.
			"message": "📜 [b]%s[/b]\na new door on the %s" % [title, SurfaceRooms.NAME_ARC],
			"detail": "",
			"importance": 3,
			"icon": "📜",
			"path": "X" + SurfaceRooms.KEY_OFFERS,
			"route": "arc",
		}
	# Market: log only. Do not say "here" — there is no here to tap.
	var fac := str(quest.get("faction", "")).strip_edges()
	if fac == "":
		fac = "the market"
	return {
		"message": "📜 New offer from %s" % fac,
		"detail": "",
		"importance": 1,
		"icon": "📜",
		"path": "Q",
		"route": "",
	}


## Arc selected-row postcard. Story first; the ask is one player-voice line;
## formula is never part of the face (callers that want physics use inspect).
static func flag_postcard(flag: Dictionary, pred_scores: Array = [], qm = null) -> Dictionary:
	var title := str(flag.get("display_name", flag.get("id", "?")))
	var beat := str(flag.get("arc_beat", "")).strip_edges()
	var asks: Array[String] = []
	for ps in pred_scores:
		if not (ps is Dictionary):
			continue
		var pred: Dictionary = ps.get("pred", {})
		if pred.is_empty():
			continue
		var gloss := PredicateGloss.summary(pred, qm).strip_edges()
		if gloss != "":
			asks.append(gloss)
	return {
		"title": title,
		"beat": beat,
		"asks": asks,
		"lane": StoryAtlas.lane_tag(title),
	}


static func quest_postcard(quest: Dictionary) -> Dictionary:
	return {
		"title": quest_title(quest),
		"beat": str(quest.get("body", "")).strip_edges(),
		"asks": [ask_line(quest)],
		"lane": "NOW",
	}


## The live-ask token the attention model and the spine lint share.
## One word the banner, toast, and Arc featured door must agree on
## during Act-0 step 0: "strike" (the first irreversible tap).
static func live_ask_token(quest: Dictionary) -> String:
	var teaches := str(quest.get("tutorial_teaches", "")).strip_edges()
	match teaches:
		"core_loop":
			return "strike"
		"contracts":
			return "deliver"
		"wayfinding":
			return "travel"
		"superposition":
			return "superpose"
		"entanglement":
			return "weave"
		"reap_season":
			return "reap"
	var preds = quest.get("state_predicates", [])
	if preds is Array and not preds.is_empty() and preds[0] is Dictionary:
		var g := str(preds[0].get("gate", preds[0].get("type", ""))).to_lower()
		if g == "measure":
			return "strike"
		if g == "pop":
			return "gather"
		if g != "":
			return g
	return "listen"


## Standing weather. Toast and Self compose from this so a playtester never
## sees a ledger delta (`trust +0.12 → 0.45`) on the face. Numbers live
## behind E on Self.
static func felt_standing(faction: String, channel: String, delta: float) -> String:
	var fac := faction.strip_edges()
	if fac == "":
		fac = "the island"
	var ch := channel.strip_edges()
	if ch == "":
		ch = "name"
	var direction := "grows" if delta >= 0.0 else "slips"
	return "Your %s with the %s %s" % [ch, fac, direction]


## Snapshot of who currently holds you, for the Self face (no delta).
static func felt_standing_snapshot(faction: String, channel: String, value: float) -> String:
	var fac := faction.strip_edges()
	if fac == "":
		return "No one has taken your measure yet"
	var ch := channel.strip_edges()
	if absf(value) < 0.05:
		return "The %s have not taken your measure yet" % fac
	if value > 0.0:
		if ch != "":
			return "The %s know your name — %s" % [fac, ch]
		return "The %s know your name" % fac
	if ch != "":
		return "The %s hold you at a distance — %s" % [fac, ch]
	return "The %s hold you at a distance" % fac


# =============================================================================
# SPINE — one live beat. Banner, toast, Arc NOW, recap compose from here.
# =============================================================================

const ASK_MAX_CHARS := 70


static func live_quest(qm = null) -> Dictionary:
	if qm == null:
		qm = _quest_manager()
	if qm == null or not ("active_quests" in qm):
		return {}
	# After Act 0 there is ONE ranker for the live beat: the guidance resolver
	# (Core/Campaign/Guide.gd). The Arc's NOW row, the banner and the toasts
	# all name the same door — and that door is always row one on the Arc.
	if not _tutorial_live(qm):
		var g: Dictionary = load("res://Core/Campaign/Guide.gd").live_beat(qm)
		if not g.is_empty():
			return g
	var act_by_flag := _act_by_flag(qm)
	var best: Dictionary = {}
	var best_rank := 0x7FFFFFFF
	var pools: Array = [qm.active_quests.values()]
	if "story_offers" in qm:
		pools.append(qm.story_offers.values())
	for pool in pools:
		for q in pool:
			if not (q is Dictionary):
				continue
			var rank := _quest_rank(q, act_by_flag)
			if rank < best_rank:
				best_rank = rank
				best = q
	return best


static func _tutorial_live(qm) -> bool:
	for pool in [qm.active_quests.values(), qm.story_offers.values() if "story_offers" in qm else []]:
		for q in pool:
			if q is Dictionary and str(q.get("category", "")) == "TUTORIAL":
				return true
	return false


static func live_door(qm = null, farm = null) -> Dictionary:
	if qm == null:
		qm = _quest_manager()
	if farm == null:
		farm = _farm()
	var q := live_quest(qm)
	if not q.is_empty():
		return beat_from_quest(q, "live")
	# live_quest skips unsigned STATUS_STORY offers (banner is accepted-only).
	# Arc NOW must still be the open handshake — otherwise the next unfired
	# flag (Village, then Woodlot) becomes the live row while the Wheel is
	# sitting in story_offers. Playtest: loom → Arc → Village, looking for
	# a lumber yard that had not opened, never having reaped.
	var offer := _best_unsigned_offer(qm)
	if not offer.is_empty():
		return beat_from_quest(offer, "live")
	# Quiet until a door opens. An unfired flag with a 99% bar used to
	# become NOW and shunt into Village / Woodlot before its quest existed.
	return {}


static func doors_ahead(limit: int = 6, qm = null, farm = null) -> Array:
	var rows: Array = []
	if qm == null:
		qm = _quest_manager()
	if farm == null:
		farm = _farm()
	if qm == null:
		return rows
	var live := live_door(qm, farm)
	var live_id := str(live.get("id", ""))
	# The Arc lists doors you have not signed. A signed story beat lives on
	# Charge (X → U), beside nothing else; Act 0 lessons stay here.
	if not live.is_empty() and not _is_signed_story(live.get("data", {}), qm):
		rows.append(_row_from_beat(live))
	var live_quest_id := int(live.get("data", {}).get("id", -1)) if live.get("data", {}) is Dictionary else -1
	if qm.has_method("get_story_offers"):
		var tables := _catalog_rank_tables(qm, farm)
		var offers: Array = []
		for q in qm.get_story_offers():
			if not (q is Dictionary):
				continue
			if str(q.get("category", "")) not in ["ARC", "TUTORIAL"]:
				continue
			if int(q.get("id", -2)) == live_quest_id:
				continue
			offers.append(q)
		# Mill waiting leftover (Fill the Urn) must sit in the GHJKL;
		# window. Insertion order parked it 7th of 10 while Sign and
		# Settle tied on rank and took G.
		offers.sort_custom(func(a, b):
			return _catalog_rank(a, tables) < _catalog_rank(b, tables)
		)
		for q in offers:
			rows.append({"kind": "arc_quest", "data": q, "beat": beat_from_quest(q, "ahead")})
			if rows.size() >= limit:
				return rows
	# Unfired flags are not doors. They become offers when they fire.
	# Listing a 99% Village / Woodlot row shunted players out of the loom
	# into a country whose quest did not exist yet.
	return rows


static func _is_signed_story(q, qm) -> bool:
	if not (q is Dictionary) or q.is_empty():
		return false
	if qm == null or not qm.has_method("is_charge_hold") or not ("active_quests" in qm):
		return false
	return qm.active_quests.has(int(q.get("id", -1))) and bool(qm.is_charge_hold(q))


static func remembered_count() -> int:
	var farm = _farm()
	if farm == null or not "story_flags_fired" in farm:
		return 0
	return int(farm.story_flags_fired.size())


static func memoir(limit: int = 12) -> Array:
	var out: Array = []
	var farm = _farm()
	if farm == null or not ("story_log" in farm) or not (farm.story_log is Array):
		return out
	var log: Array = farm.story_log
	var n: int = mini(log.size(), limit)
	for i in range(n):
		var entry: Dictionary = log[log.size() - 1 - i]
		if not (entry is Dictionary):
			continue
		out.append({
			"id": str(entry.get("id", "")),
			"title": str(entry.get("display_name", entry.get("id", ""))),
			"chapter": StoryAtlas.chapter_for_act(int(entry.get("act", 0))),
			"act": int(entry.get("act", 0)),
			"tense": "remembered",
			"prose": str(entry.get("arc_beat", "")).strip_edges(),
			"ask": "",
			"physics": "",
			"source": "flag",
			"live_ask": "",
		})
	return out


static func postcard(beat: Dictionary) -> Dictionary:
	return {
		"title": str(beat.get("title", "")),
		"beat": str(beat.get("prose", "")),
		"asks": [str(beat.get("ask", ""))],
		"lane": str(beat.get("lane", "")),
	}


static func inspect(beat: Dictionary) -> String:
	var lines: Array[String] = []
	var title := str(beat.get("title", "")).strip_edges()
	if title != "":
		lines.append(title)
	var prose := str(beat.get("prose", "")).strip_edges()
	if prose != "":
		lines.append(prose)
	var ask := str(beat.get("ask", "")).strip_edges()
	if ask != "":
		lines.append(ask)
	var physics := str(beat.get("physics", "")).strip_edges()
	if physics != "":
		lines.append(physics)
	return "\n".join(lines)


static func toast_for_flag(flag_id: String, flag_data: Dictionary) -> Dictionary:
	# A flag that opens a door already toasts as the offer ("waiting on the
	# Arc"). A second gold card for the same display_name was double
	# notification for one door — playtest: First Harvest + Wheel, each twice.
	var quest = flag_data.get("arc_quest")
	if quest is Dictionary and not quest.is_empty():
		return {}
	# Explicit null door (First Harvest): the Wheel is the beat. A gold
	# ✨ to Story stacked on the Wheel's 📜 to Arc — two cards, and the
	# Harvest one sent the player to the wrong room.
	if flag_data.has("arc_quest"):
		return {}
	# Handoff-only flags (explicit empty predicates, fired by tutorial
	# unlock_flags) are chrome, not a beat. ✨ The Loom Opens stacked on
	# the banner mid-lane while entanglement was already the live ask.
	if flag_data.has("predicates"):
		var preds = flag_data.get("predicates", null)
		if preds is Array and preds.is_empty():
			return {}
	var title := str(flag_data.get("display_name", flag_id))
	return {
		"message": "✨ [b]%s[/b]" % title,
		"detail": "",
		"importance": 3,
		"icon": "✨",
		"path": "X" + SurfaceRooms.KEY_STORY,
		"route": "story",
	}


static func recap() -> Dictionary:
	var door := live_door()
	var title := str(door.get("title", "")).strip_edges()
	var ask := str(door.get("ask", "")).strip_edges()
	var bits: Array[String] = []
	if title != "":
		bits.append("[b]%s[/b]" % title)
	if ask != "":
		bits.append(ask)
	var qm := _quest_manager()
	if qm != null and qm.has_method("commitment_quests"):
		var n: int = qm.commitment_quests().size()
		if n > 0:
			bits.append("%d contract%s open" % [n, "" if n == 1 else "s"])
	elif qm != null and qm.has_method("get_active_quests"):
		var n2: int = qm.get_active_quests().size()
		if n2 > 0:
			bits.append("%d contract%s open" % [n2, "" if n2 == 1 else "s"])
	return {
		"title": title,
		"ask": ask,
		"line": "🌾 " + "  ·  ".join(bits) if not bits.is_empty() else "",
	}


static func chapter_line() -> String:
	var qm := _quest_manager()
	var farm = _farm()
	var act := 0
	if farm != null and "story_flags_fired" in farm and qm != null and qm.has_method("get_all_story_flags"):
		act = StoryAtlas.current_act(farm.story_flags_fired, qm.get_all_story_flags())
	return "%s · %s" % [CampaignRuntime.campaign(StoryAtlas.MAIN_CAMPAIGN).get("title", "The Demos"), StoryAtlas.chapter_for_act(act)]


static func murmur_caption(chatter_ev: Dictionary) -> String:
	var faction := str(chatter_ev.get("faction", "")).strip_edges()
	var biome := str(chatter_ev.get("biome", "")).strip_edges()
	if faction != "" and biome != "":
		return "%s, from the %s" % [faction, biome]
	if faction != "":
		return faction
	if biome != "":
		return biome
	return "a voice on the island"


static func lens_beat() -> Dictionary:
	var engine = _story_engine()
	if engine == null or not ("graph" in engine) or engine.graph == null:
		return {}
	var focus_id := ""
	if engine.has_method("default_ui_focus"):
		focus_id = str(engine.default_ui_focus())
	if focus_id == "" or not engine.graph.nodes.has(focus_id):
		return {}
	var node = engine.graph.nodes[focus_id]
	var farm = _farm()
	var flag_fired: bool = farm != null and "story_flags_fired" in farm and farm.story_flags_fired.has(focus_id)
	return {
		"id": focus_id,
		"title": str(node.display_name) if node != null else focus_id,
		"chapter": StoryAtlas.chapter_for_act(int(node.act) if node != null else 0),
		"act": int(node.act) if node != null else 0,
		"tense": "remembered" if flag_fired else "ahead",
		"prose": str(node.arc_beat) if node != null else "",
		"ask": "",
		"physics": "",
		"source": "flag",
		"live_ask": "",
	}


static func seed_id() -> String:
	var door := live_door()
	var id := str(door.get("id", "")).strip_edges()
	if id != "":
		return id
	return "core_loop"


static func beat_from_quest(quest: Dictionary, tense: String) -> Dictionary:
	var teaches := str(quest.get("tutorial_teaches", "")).strip_edges()
	var source_flag := str(quest.get("source_flag", "")).strip_edges()
	var id := teaches if teaches != "" else (source_flag if source_flag != "" else str(quest.get("id", "")))
	var cat := str(quest.get("category", ""))
	var status := str(quest.get("status", "")).strip_edges()
	var kind := "live_tutorial" if cat == "TUTORIAL" and tense == "live" else "arc_quest"
	if cat == "TUTORIAL" and status == "story":
		kind = "arc_quest"
	# READY / accepted live work is NOW. Arc G must not paint OPEN+[R] Accept
	# on a quest accept_quest already holds (timber_rhythm handshake).
	if tense == "live" and status != "" and status != "story":
		kind = "live_tutorial"
	return {
		"id": id,
		"title": quest_title(quest),
		"chapter": StoryAtlas.chapter_for_act(0 if cat == "TUTORIAL" else 0),
		"act": 0,
		"tense": tense,
		"prose": str(quest.get("body", "")).strip_edges(),
		"ask": ask_line(quest),
		# math_note is the designer's note on the gate (thresholds, history);
		# it is not written for the player and went stale. Not shown.
		"physics": "",
		"source": "tutorial" if cat == "TUTORIAL" else "flag",
		"live_ask": live_ask_token(quest),
		"kind": kind,
		"data": quest,
		"lane": "NOW" if kind == "live_tutorial" else "",
	}


static func ask_line(quest: Dictionary) -> String:
	var hint := str(quest.get("tutorial_hint", "")).strip_edges()
	if hint == "":
		hint = str(quest.get("hint", "")).strip_edges()
	if hint != "":
		return StoryAtlas.sentence_cut(hint, ASK_MAX_CHARS)
	var gloss := _first_unsatisfied_gloss(quest)
	if gloss != "":
		return StoryAtlas.sentence_cut(gloss, ASK_MAX_CHARS)
	var body := str(quest.get("body", "")).strip_edges()
	if body != "":
		return StoryAtlas.sentence_cut(body, ASK_MAX_CHARS)
	return ""


static func _next_spine_flag_beat(qm = null, farm = null) -> Dictionary:
	if qm == null:
		qm = _quest_manager()
	if farm == null:
		farm = _farm()
	if qm == null or not qm.has_method("get_all_story_flags"):
		return {}
	var fired: Dictionary = {}
	if farm != null and "story_flags_fired" in farm:
		fired = farm.story_flags_fired
	var all_flags: Array = qm.get_all_story_flags()
	var unfired: Array = []
	for flag in all_flags:
		if not (flag is Dictionary):
			continue
		var fid := str(flag.get("id", ""))
		if fid == "" or fired.has(fid):
			continue
		unfired.append(flag)
	unfired.sort_custom(func(a, b):
		var aa := int(a.get("act", 99))
		var ab := int(b.get("act", 99))
		if aa != ab:
			return aa < ab
		var a_lane: bool = StoryAtlas.lane_of(str(a.get("display_name", "")))["lane"] != ""
		var b_lane: bool = StoryAtlas.lane_of(str(b.get("display_name", "")))["lane"] != ""
		if a_lane != b_lane:
			return b_lane
		if qm.has_method("evaluate_flag_score"):
			return float(qm.evaluate_flag_score(a)) > float(qm.evaluate_flag_score(b))
		return false
	)
	for flag in unfired:
		var aq = flag.get("arc_quest")
		if not (aq is Dictionary) or aq.is_empty():
			continue
		if not _flag_parents_resolved(flag, fired, qm):
			continue
		return beat_from_flag(flag, "live", qm)
	return {}


static func beat_from_flag(flag: Dictionary, tense: String, qm = null) -> Dictionary:
	var title := str(flag.get("display_name", flag.get("id", "?")))
	var pred_scores: Array = []
	var asks: Array[String] = []
	if qm != null:
		for pred in flag.get("predicates", []):
			if not (pred is Dictionary):
				continue
			var score := 0.0
			if qm.has_method("evaluate_predicate_score"):
				score = float(qm.evaluate_predicate_score(pred))
			pred_scores.append({"pred": pred, "score": score})
			if score < 0.85:
				var g := PredicateGloss.summary(pred, qm).strip_edges()
				if g != "":
					asks.append(g)
	var ask := asks[0] if not asks.is_empty() else ""
	return {
		"id": str(flag.get("id", "")),
		"title": title,
		"chapter": StoryAtlas.chapter_for_flag(flag),
		"act": int(flag.get("act", 0)),
		"tense": tense,
		"prose": str(flag.get("arc_beat", "")).strip_edges(),
		"ask": ask,
		"physics": "",
		"source": "flag",
		"live_ask": live_ask_token(flag),
		"kind": "flag_unfired" if tense != "remembered" else "flag_fired",
		"flag": flag,
		"pred_scores": pred_scores,
		"score": float(qm.evaluate_flag_score(flag)) if (qm != null and qm.has_method("evaluate_flag_score")) else 0.0,
		"lane": StoryAtlas.lane_tag(title),
		"data": {},
	}


static func _row_from_beat(beat: Dictionary) -> Dictionary:
	var kind := str(beat.get("kind", ""))
	if kind == "live_tutorial" or kind == "arc_quest":
		return {"kind": kind, "data": beat.get("data", {}), "beat": beat}
	return _row_from_flag(beat.get("flag", {}), kind, _quest_manager(), beat)


static func _row_from_flag(flag: Dictionary, kind: String, qm = null, beat: Dictionary = {}) -> Dictionary:
	if beat.is_empty() and not flag.is_empty():
		beat = beat_from_flag(flag, "ahead" if kind != "flag_fired" else "remembered", qm)
	return {
		"kind": kind,
		"flag": flag if not flag.is_empty() else beat.get("flag", {}),
		"score": float(beat.get("score", 0.0)),
		"pred_scores": beat.get("pred_scores", []),
		"beat": beat,
	}


static func _flag_parents_resolved(flag: Dictionary, fired: Dictionary, qm = null) -> bool:
	for pred in flag.get("predicates", []):
		if not (pred is Dictionary):
			continue
		if str(pred.get("type", "")) != "story_flag_set":
			continue
		var pid := str(pred.get("id", ""))
		if pid == "" or not fired.has(pid):
			return false
		if qm != null and qm.has_method("flag_door_is_resolved") \
				and not bool(qm.flag_door_is_resolved(pid)):
			return false
	return true


static func _unsigned_still_open(q: Dictionary, qm) -> bool:
	# Skip already-satisfied unsigned offers so Arc NOW is the live door
	# (mill_wakes: Accept on paid Long Way Home named no farm key).
	var preds = q.get("state_predicates", [])
	if not (preds is Array) or preds.is_empty():
		return true
	for pred in preds:
		if not (pred is Dictionary):
			continue
		if qm != null and qm.has_method("evaluate_predicate_score") \
				and float(qm.evaluate_predicate_score(pred)) >= 0.85:
			continue
		return true
	return false


static func _catalog_rank_tables(qm, farm = null) -> Dictionary:
	if farm == null:
		farm = _farm()
	var fired: Dictionary = farm.story_flags_fired if farm != null and "story_flags_fired" in farm else {}
	var acts := {}
	var camps := {}
	var blocking := {}
	if qm != null and qm.has_method("get_all_story_flags"):
		for f in qm.get_all_story_flags():
			if not (f is Dictionary):
				continue
			var fid := str(f.get("id", ""))
			acts[fid] = int(f.get("act", 0))
			camps[fid] = str(f.get("campaign", "demos"))
			if fired.has(fid):
				continue
			for p in f.get("predicates", []):
				if p is Dictionary and str(p.get("type", "")) == "story_flag_set":
					blocking[str(p.get("id", ""))] = true
	return {"fired": fired, "acts": acts, "camps": camps, "blocking": blocking}


## Same rank as UIProgression.waiting_arc_offer: leftover lanternfall
## that a live child still needs (Fill the Urn / the_basin) beats a
## leftover sibling (Sign and Settle) that tied on act+campaign.
static func _catalog_rank(q: Dictionary, tables: Dictionary) -> int:
	var src := str(q.get("source_flag", ""))
	var fired: Dictionary = tables.get("fired", {})
	var leftover := 2000 if (src != "" and fired.has(src)) else 0
	var camps: Dictionary = tables.get("camps", {})
	var camp := str(camps.get(src, "demos"))
	var camp_pen := 0
	if camp == "loom":
		camp_pen = 500
	elif camp == "demos":
		camp_pen = 100
	var blocking: Dictionary = tables.get("blocking", {})
	var acts: Dictionary = tables.get("acts", {})
	return leftover + camp_pen + int(acts.get(src, 99)) \
			+ (0 if blocking.has(src) else 1000)


static func _best_unsigned_offer(qm) -> Dictionary:
	if qm == null or not qm.has_method("get_story_offers"):
		return {}
	var farm = _farm()
	var tables := _catalog_rank_tables(qm, farm)
	var fired: Dictionary = tables.get("fired", {})
	var best: Dictionary = {}
	var best_rank := 0x7FFFFFFF
	for q in qm.get_story_offers():
		if not (q is Dictionary):
			continue
		var cat := str(q.get("category", ""))
		if cat not in ["ARC", "TUTORIAL"]:
			continue
		var src := str(q.get("source_flag", ""))
		if not _unsigned_still_open(q, qm):
			# Preds already hold. Skip unless leftover still needs Accept
			# so children can open (Bring Light In → the_gray).
			if src == "" or not fired.has(src):
				continue
			if qm.has_method("flag_door_is_resolved") \
					and bool(qm.flag_door_is_resolved(src)):
				continue
		if cat == "TUTORIAL":
			var trank := int(q.get("tutorial_step", 0))
			if trank < best_rank:
				best_rank = trank
				best = q
			continue
		var rank := _catalog_rank(q, tables)
		if rank < best_rank:
			best_rank = rank
			best = q
	return best


static func _quest_rank(q: Dictionary, act_by_flag: Dictionary) -> int:
	var cat := str(q.get("category", ""))
	if cat == "TUTORIAL":
		return int(q.get("tutorial_step", 0))
	if cat == "ARC" and str(q.get("status", "")) != "story":
		return 1000 + int(act_by_flag.get(str(q.get("source_flag", "")), 99))
	return 0x7FFFFFFF


static func _act_by_flag(qm: Node) -> Dictionary:
	var out := {}
	if qm != null and qm.has_method("get_all_story_flags"):
		for flag in qm.get_all_story_flags():
			if flag is Dictionary:
				out[str(flag.get("id", ""))] = int(flag.get("act", 0))
	return out


static func _first_unsatisfied_gloss(q: Dictionary) -> String:
	var qm := _quest_manager()
	for pred in q.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		if qm != null and qm.has_method("evaluate_predicate_score") \
				and float(qm.evaluate_predicate_score(pred)) >= 0.85:
			continue
		var g := str(PredicateGloss.summary(pred, qm)).strip_edges()
		if g != "":
			return g
	return ""


static func _offer_is_plant(quest: Dictionary) -> bool:
	for pred in quest.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		if str(pred.get("type", "")) != "gate_sequence_contains":
			continue
		var g := str(pred.get("gate", "")).to_lower()
		if g == "inject_icon" or g == "plant":
			return true
	return false


static func _sprouts_are_short() -> bool:
	# Lazy load: UIProgression already talks to IntroVoice. A preload cycle
	# would compile-bomb the HUD smokes.
	var Prog = load("res://UI/Core/UIProgression.gd")
	return Prog != null and bool(Prog._sprout_short())


static func _quest_manager() -> Node:
	var ml = Engine.get_main_loop()
	if not (ml is SceneTree):
		return null
	var shells: Array = (ml as SceneTree).get_nodes_in_group("player_shell")
	if shells.is_empty():
		return null
	var shell = shells[0]
	return shell.quest_manager if "quest_manager" in shell else null


static func _farm() -> Variant:
	var ml = Engine.get_main_loop()
	if not (ml is SceneTree):
		return null
	var gsm = (ml as SceneTree).root.get_node_or_null("/root/GameStateManager")
	if gsm != null and gsm.has_method("get_active_farm"):
		return gsm.get_active_farm()
	return null


static func _story_engine():
	var ml = Engine.get_main_loop()
	if not (ml is SceneTree):
		return null
	return (ml as SceneTree).root.get_node_or_null("/root/StoryEngine")
