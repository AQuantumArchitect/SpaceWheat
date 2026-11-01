extends RefCounted

## UIProgression — single authority for progressive UI disclosure.
##
## The day-one interface drowned new players (7 hats × modes + 9 menu surfaces
## before their first key press). This maps STORY PROGRESS → which chrome is
## visible. Derived entirely from farm.story_flags_fired (already persisted):
## no new save state, old saves see everything they've already reached.
##
## Phase 1 (is_*_visible): hidden buttons are not rendered, but their keys
## still work.
## Phase 2 (is_*_active — the funnel): locked keys REDIRECT instead of act.
## Same flag tables, same fail-open. RIG_UNLOCK_ALL=1 (the rig lanes' default,
## set by RigClient.start_listener) bypasses enforcement so drives/tests see
## the full grammar; the player seat pins it to 0 (player parity).
## Anti-gating law: a lock must SPEAK and point at the one live loop —
## redirect_locked() toasts the objective, rate-limited, never floods.

const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const PredicateGloss = preload("res://Core/Quests/PredicateGloss.gd")

## Every unlock table (hat → beats, menu → beats, overlay → beats, menu → min
## tutorial step) is AUTHORED in the campaign spec (Core/Campaign/campaign.json:
## a beat's on_open.unlock, plus legacy_unlocks for old saves) and compiled into
## Core/Quests/data/campaign_runtime.json. Read here through CampaignRuntime —
## no flag ids live in UI code. A name absent from a table is always available
## (fail-open); Ace + Icon + Druid are the starter kit because no beat gates them.
static func hat_unlock_flags() -> Dictionary:
	return CampaignRuntime.unlocks("hats")


static func menu_unlock_flags() -> Dictionary:
	return CampaignRuntime.unlocks("menus")


static func viz_unlock_flags() -> Dictionary:
	return CampaignRuntime.unlocks("viz")


## Menu id → minimum tutorial_step at which it surfaces (checked ALONGSIDE the
## flag table). Only Quest Board carries an entry: step 1 ("contracts") is
## literally where it's taught.
static func menu_unlock_step() -> Dictionary:
	return CampaignRuntime.menu_steps()


static func _flags() -> Dictionary:
	var gsm = Engine.get_main_loop().root.get_node_or_null("GameStateManager") if Engine.get_main_loop() else null
	var farm = gsm.get_active_farm() if (gsm and gsm.has_method("get_active_farm")) else null
	if farm != null and is_instance_valid(farm) and "story_flags_fired" in farm:
		return farm.story_flags_fired
	# No farm (visual tests, early boot): show everything — fail open.
	return {}


## flag_spec: "" = always; String = that flag must be fired; Array = ANY of
## the named flags satisfies it (relocated flag + its legacy id, so banked
## saves that fired the old road keep their chrome — the tables fail closed
## with a live farm, and a stranded hat is unrecoverable).
static func _unlocked(flag_spec, flags: Dictionary) -> bool:
	if flag_spec is Array:
		for f in flag_spec:
			if _unlocked(f, flags):
				return true
		return false
	var flag := str(flag_spec)
	return flag == "" or flags.has(flag)


static func is_hat_visible(frame_name: String) -> bool:
	var flags := _flags()
	if flags.is_empty() and _no_farm():
		return true
	return _unlocked(hat_unlock_flags().get(frame_name, ""), flags)


## Viz overlays: same table law (gauge_overlay waits on the compass lesson).
static func is_viz_visible(overlay_id: String) -> bool:
	var flags := _flags()
	if flags.is_empty() and _no_farm():
		return true
	return _unlocked(viz_unlock_flags().get(overlay_id, ""), flags)


static func is_menu_visible(menu_id: String) -> bool:
	var flags := _flags()
	if flags.is_empty() and _no_farm():
		return true
	if not _unlocked(menu_unlock_flags().get(menu_id, ""), flags):
		return false
	var steps := menu_unlock_step()
	if steps.has(menu_id):
		return current_tutorial_step() >= int(steps[menu_id])
	return true


static func _no_farm() -> bool:
	var gsm = Engine.get_main_loop().root.get_node_or_null("GameStateManager") if Engine.get_main_loop() else null
	return gsm == null or not gsm.has_method("get_active_farm") or gsm.get_active_farm() == null


# ============================================================================
# ENFORCEMENT (phase 2 — the funnel). is_*_visible answers "is it drawn?";
# is_*_active answers "does the key act?". One flag table serves both.
# ============================================================================

static func _enforcement_bypassed() -> bool:
	return RuntimeEnv.flag("RIG_UNLOCK_ALL", false)


static func is_hat_active(frame_name: String) -> bool:
	if _enforcement_bypassed():
		return true
	return is_hat_visible(frame_name)


static func is_menu_active(menu_id: String) -> bool:
	if _enforcement_bypassed():
		return true
	return is_menu_visible(menu_id)


## Escape-menu (Z) tab id → locked until Act 0 fully completes. Only the
## wander-only tabs are listed (New/Balance/Dev); Now/Save default to always-
## active (missing = unlocked, same fail-open convention as every other table
## in this file). Locked here means "gate `_show_tab()`'s target" — EscapeMenu
## owns its own Tab enum, this takes the string id it maps that enum to.
const ESCAPE_TAB_LOCKED_UNTIL_ACT0_DONE: Dictionary = {
	"new": true,
	"balance": true,
	"dev": true,
}


static func is_escape_tab_active(tab_id: String) -> bool:
	if _enforcement_bypassed():
		return true
	if not bool(ESCAPE_TAB_LOCKED_UNTIL_ACT0_DONE.get(tab_id, false)):
		return true
	return current_tutorial_step() == NO_TUTORIAL_SENTINEL


# ============================================================================
# VERB-LEVEL ENFORCEMENT (phase 3 — the funnel goes one level deeper).
# is_hat_active gates the HAT; is_verb_active gates individual Q/E/R/F keys
# WITHIN an already-unlocked hat, but ONLY during the Act-0 tutorial. Once
# Act 0 ends (current_tutorial_step() hits the no-signal sentinel) every verb
# compares true and this stops mattering — it never gates the mid/late game.
# Same fail-open law as the rest of the file: no signal = permissive.
# ============================================================================

## Sentinel current_tutorial_step() returns when there's no active TUTORIAL
## quest to read (Act 0 already complete, or no farm/quest manager yet).
## Comfortably above every VERB_UNLOCK_STEP entry (including the 90 "locked
## through Act 0" sentinel below) so the fail-open reading is "everything
## unlocked" — NOT 0, which would mean "only step-0 verbs are live."
const NO_TUTORIAL_SENTINEL := 999

## VERB_UNLOCK_STEP entries pinned here stay locked for the whole Act-0
## tutorial (steps 0-5) without picking a real step to unlock at — comfortably
## above the highest real step (5), and visually distinct from
## NO_TUTORIAL_SENTINEL so a reader can tell "locked all of Act 0" apart from
## "no signal, fully open."
const VERB_LOCKED_FOR_ACT0 := 90


## Which Act-0 tutorial step is currently live. The lane auto-accepts into
## active_quests; story_offers is still scanned so a stray unsigned tutorial
## cannot look like "Act 0 is over." Returns NO_TUTORIAL_SENTINEL only when
## no TUTORIAL quest is live in either pool.
static func current_tutorial_step() -> int:
	var qm := _quest_manager()
	if qm == null or not ("active_quests" in qm):
		return NO_TUTORIAL_SENTINEL
	for q in qm.active_quests.values():
		if q is Dictionary and str(q.get("category", "")) == "TUTORIAL":
			return int(q.get("tutorial_step", 0))
	if "story_offers" in qm:
		for q in qm.story_offers.values():
			if q is Dictionary and str(q.get("category", "")) == "TUTORIAL":
				return int(q.get("tutorial_step", 0))
	return NO_TUTORIAL_SENTINEL


## "<frame>:<key>" -> minimum tutorial_step at which that verb goes live.
## Anything NOT listed here defaults to always-active (see is_verb_active) —
## this table only carries the handful of Act-0-relevant restrictions; every
## other hat/key combo (and every verb once Act 0 ends) is fully live.
## Destructive verbs are listed EXPLICITLY even when locked for all of Act 0
## (VERB_LOCKED_FOR_ACT0), on purpose — silence here would default them open.
const VERB_UNLOCK_STEP: Dictionary = {
	# Step 0 (core_loop): Ace F (explore/fast-forward), R (strike), Q (extract).
	# ace:E (Pause) is deliberately absent — harmless utility taught in the
	# same hint, never locked. Step 1 (contracts) rides these same Ace verbs;
	# step 2 (wayfinding) is travel-only — no verb to unlock.
	"ace:F": 0,
	"ace:R": 0,
	"ace:Q": 0,

	# Step 5 (reap_season, the capstone): Ace Shift+F. Locked until the step
	# that teaches it, on purpose — reap is once-affordable early (Fibonacci 🍼
	# costs, wallet starts with 1) and reaps EVERY biome at once, so an early
	# mash must not spend the only bottle on an undeveloped field. The redirect
	# toast names the live objective, per the funnel law.
	"ace:shift+F": 5,

	# Icon F (track berry-phase) and R (incorporate/plant) are locked for ALL
	# of Act 0 — vocabulary is mid-game content (the act-3 berry chapter), and
	# Act 0 deliberately teaches only instant verbs. Verb enforcement dies with
	# Act 0, so these open the moment the tutorial ends (act-1 planting needs
	# icon:R free). icon:Q (remove_icon, destructive) and icon:E (inspect)
	# stay locked too — explicit, not omitted.
	"icon:F": VERB_LOCKED_FOR_ACT0,
	"icon:R": VERB_LOCKED_FOR_ACT0,
	"icon:Q": VERB_LOCKED_FOR_ACT0,
	"icon:E": VERB_LOCKED_FOR_ACT0,

	# Step 3 (superposition): Druid E (Hadamard). druid:Q/R (rotations) stay
	# locked for the rest of Act 0 — explicit.
	"druid:E": 3,
	"druid:Q": VERB_LOCKED_FOR_ACT0,
	"druid:R": VERB_LOCKED_FOR_ACT0,

	# Step 4 (entanglement): Operator R (build_gate — the Bell weave).
	# operator:Q (remove_gates, destructive) stays locked for the rest of
	# Act 0 — explicit.
	"operator:R": 4,
	"operator:Q": VERB_LOCKED_FOR_ACT0,
}


static func is_verb_active(frame_name: String, key: String) -> bool:
	if _enforcement_bypassed():
		return true
	var min_step: int = int(VERB_UNLOCK_STEP.get("%s:%s" % [frame_name, key], 0))
	return current_tutorial_step() >= min_step


# ============================================================================
# THE ONE LIVE OBJECTIVE — single authority shared by the HUD banner
# (ActFilament) and the locked-input redirect toast. Blind playtesters
# (masher / literalist / lost lamb) consistently failed to find the game's one
# live objective; this puts it in screen text. Returns "" only when there is
# genuinely nothing to point at (no active quest AND no pending offer — the
# earned late-game quiet), never as an act cutoff. (An island_lives early-
# return here once blacked out acts 4-8 — island_lives is act 4 of 8, not
# the endgame; the banner and spotlight must serve the whole campaign.)
# ============================================================================

const OBJECTIVE_MAX_CHARS := 70
# Menu keys come from SurfaceRooms (mirroring the campaign keymap); a path
# from wherever the player is comes from SurfaceGraph.path().
const OFFER_LINE := "📜 new offer — tap 📖 [X], then Arc [" + SurfaceRooms.KEY_OFFERS + "]"
const REDIRECT_FALLBACK := "follow the Arc — tap 📖 [X], then [" + SurfaceRooms.KEY_OFFERS + "]"


## One spelling per door — every surface that names a route composes from
## these. The ready-toast and the objective banner used to spell the claim
## route two ways ("C board" vs "Commitments (C → U)") and the older one sent
## players to the wrong screen; PlayerEventBridge preloads this script so the
## drift can't reopen. Voice rule: the click comes first, keys ride as
## bracketed accelerators — every action named here has a real hitbox
## (docs/design/MOUSE_PARITY_AUDIT.md: zero keyboard-only gaps), so copy that only
## says "press R" lies by omission to a mouse-and-trackpad player.
static func route_accept() -> String:
	return "tap 📖 [X], %s [%s], its row, then Accept [R]" % [SurfaceRooms.NAME_ARC, SurfaceRooms.KEY_OFFERS]


## Signed story beats are claimed on X → Charge; market contracts on C.
static func route_claim(q: Dictionary = {}) -> String:
	var qm = _quest_manager()
	if not q.is_empty() and qm != null and qm.has_method("is_charge_hold") and bool(qm.is_charge_hold(q)):
		return "tap 📖 [X], %s [%s], its row, then Claim [R]" % [SurfaceRooms.NAME_CHARGE, SurfaceRooms.KEY_HELD]
	return "tap 📋 [C], its row twice (Claim [R])"


## True when the live ask is a goods delivery (the mill, a market stall).
## Verb-lesson tutorials have no resource; they stay on the field.
static func _is_goods_ask(q: Dictionary) -> bool:
	if str(q.get("resource", "")).strip_edges() == "":
		return false
	return int(q.get("quantity", 0)) > 0


## Standing gates are filled on the board, same as goods. Do not leave them
## as a field label with no key (wave 9b: "Keep mill deliveries" named no
## pressable key). Still does not accept or fill for them.
static func _is_board_ask(q: Dictionary) -> bool:
	if _is_goods_ask(q):
		return true
	for pred in q.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		var t := str(pred.get("type", ""))
		if t == "standing_gte":
			return true
		# mill_wakes Hold Commerce: ⚙ is a Market stall, not a planted word.
		if t == "biome_attractor_emoji_gte" and str(pred.get("emoji", "")) == "⚙":
			return true
		if t == "biome_state_gte" and str(pred.get("atom", "")) == "⚙":
			return true
	return false


## Where a banner tap goes. Empty = the ask is on the field (label only).
## "commitments" = fill/claim. Unsigned offers never reach the banner.
static func banner_home() -> String:
	# Wave 23: plant is a field verb. C does not plant. Use the same
	# ranker the banner speaks from so Forest and the home cannot dual.
	var best := _banner_quest()
	if best.is_empty() or str(best.get("status", "")) == Quest.STATUS_STORY:
		return ""
	if _is_plant_ask(best):
		return ""
	if _is_berry_ask(best):
		return ""
	if str(best.get("status", "")) == "ready" or _is_board_ask(best):
		return "commitments"
	return ""


## Where a catalog click-through should land. Arc is a directory, not a
## verb — a row tap never accepts. Empty = stay (unsigned optional: Accept
## [R] is the sign-on). "commitments" = the contract's stall (fill/claim on
## C). "field" = close the menu and stand on the puzzle (pick the tool,
## apply it — often a tap). Same shape for Arc rows, C shortfalls, chips.
static func puzzle_home(q: Dictionary) -> String:
	if q.is_empty():
		return ""
	if str(q.get("status", "")) == Quest.STATUS_STORY:
		return ""
	var qm = _quest_manager()
	var signed: bool = qm != null and qm.has_method("is_charge_hold") and bool(qm.is_charge_hold(q))
	if str(q.get("status", "")) == "ready":
		return "charge" if signed else "commitments"
	if _is_board_ask(q) and not signed:
		return "commitments"
	return "field"


## The live objective's how-line — tutorial_hint / hint. Empty when the
## banner has nothing more to say than objective_text() already does.
static func objective_detail() -> String:
	var best := _banner_quest()
	if best.is_empty():
		return ""
	# Supply walk live: the how-line is the whole route from the table.
	var sup := _supply_need_now(best)
	if sup != "":
		return supply_refusal(sup, _supply_cost(sup))
	# Wave 21 earnest: authored plant how-to (Icon + empty plot) outran the
	# 🌱 gather walk. One live beat. Do not plant for them.
	if _is_plant_ask(best) and _sprout_short():
		return ""
	# lantern_door: authored [7] Captain [R] outran the 🦅 gather walk.
	if _is_discover_ask(best) and _eagle_short():
		return ""
	# lantern_teaching: do not dump the Arc/Druid/E/C paragraph beside the walk.
	if _is_teaching_ask(best):
		return ""
	# lantern_wakes: authored empty-plot how-to outran a full Lanternfall ring.
	if _is_plant_ask(best) and not _empty_plot_exists(_plant_ask_biome(best)):
		return ""
	var hint := str(best.get("tutorial_hint", "")).strip_edges()
	if hint == "":
		hint = str(best.get("hint", "")).strip_edges()
	return hint


## The single ranked winning quest/offer — shared by objective_text() (the
## text banner) and objective_target_key() (the visual spotlight), so both
## always agree on what "the one live objective" is. {} when there's none.
static func _best_objective() -> Dictionary:
	# One ranker: IntroVoice.live_quest. Banner, spotlight, and Arc NOW
	# cannot pick three different doors.
	return IntroVoice.live_quest()


static func _preds_still_open(q: Dictionary) -> bool:
	# Already-satisfied unsigned offers are not the live ask (wave mill_wakes:
	# Arc Accept on Long Way Home whose phase was already paid).
	var preds = q.get("state_predicates", [])
	if not (preds is Array) or preds.is_empty():
		return true
	var qm := _quest_manager()
	for pred in preds:
		if not (pred is Dictionary):
			continue
		if qm != null and qm.has_method("evaluate_predicate_score") \
				and float(qm.evaluate_predicate_score(pred)) >= 0.85:
			continue
		return true
	return false


static func _unsigned_board_offer() -> Dictionary:
	var qm := _quest_manager()
	if qm == null or not qm.has_method("get_story_offers"):
		return {}
	for q in qm.get_story_offers():
		if q is Dictionary and _is_board_ask(q) and _preds_still_open(q):
			return q
	return {}


static func _unsigned_plant_offer() -> Dictionary:
	var qm := _quest_manager()
	if qm == null or not qm.has_method("get_story_offers"):
		return {}
	for q in qm.get_story_offers():
		if q is Dictionary and _is_plant_ask(q) and _preds_still_open(q):
			return q
	return {}


static func _unsigned_discover_offer() -> Dictionary:
	var qm := _quest_manager()
	if qm == null or not qm.has_method("get_story_offers"):
		return {}
	for q in qm.get_story_offers():
		if q is Dictionary and _is_discover_ask(q) and _preds_still_open(q):
			return q
	return {}


static func _unsigned_teaching_offer() -> Dictionary:
	var qm := _quest_manager()
	if qm == null or not qm.has_method("get_story_offers"):
		return {}
	for q in qm.get_story_offers():
		if q is Dictionary and _is_teaching_ask(q) and _preds_still_open(q):
			return q
	return {}


static func _unsigned_berry_offer() -> Dictionary:
	var qm := _quest_manager()
	if qm == null or not qm.has_method("get_story_offers"):
		return {}
	for q in qm.get_story_offers():
		if q is Dictionary and _is_berry_ask(q) and _preds_still_open(q):
			return q
	return {}


static func _banner_quest() -> Dictionary:
	# Unsigned Watch It Fade outranks leftover accepted braid/wet Superpose.
	# live_quest Two Chores milled [0] Druid while Arc still held OPEN fade.
	# After watching_keeps the fade door is resolved. Leftover Watch It Fade
	# remashes Fast-Fwd for a session watermark. Open the Bank is the mill.
	var fade_first := {}
	if not _fade_door_resolved():
		fade_first = _unsigned_fade_offer()
		if fade_first.is_empty():
			fade_first = _accepted_fade_quest()
	if not fade_first.is_empty():
		return fade_first
	var best := _best_objective()
	if not best.is_empty() and str(best.get("status", "")) != Quest.STATUS_STORY:
		return best
	# Leftover unsigned catalog whose work is Accept (Stay Many after
	# island_free) must not lose to standing-wet Superpose or leftover
	# discover. Field offers still win when THEY are the waiting door.
	var waiting := waiting_arc_offer()
	if not waiting.is_empty() \
			and not _is_plant_ask(waiting) \
			and not _is_discover_ask(waiting) \
			and not _is_coast_field_ask(waiting) \
			and not _is_board_ask(waiting) \
			and not _is_teaching_ask(waiting) \
			and not _is_berry_ask(waiting) \
			and not _is_fade_ask(waiting):
		return waiting
	# mill_wakes Hold Commerce is a board ask. Plant must not steal it.
	var board := _unsigned_board_offer()
	if not board.is_empty():
		return board
	var plant := _unsigned_plant_offer()
	if not plant.is_empty():
		return plant
	var disc := _unsigned_discover_offer()
	if not disc.is_empty():
		return disc
	# Chart GildedRot: leftover discover stays OPEN for coherence. Mill
	# the field verb, not leftover Arc toasts and not another cull.
	var coast := _unsigned_coast_field_offer()
	if not coast.is_empty():
		return coast
	# the_gray: wait-for-fade outranks leftover berry Incorporate.
	var fade := _unsigned_fade_offer()
	if not fade.is_empty():
		return fade
	# lantern_teaching: leftover first_breath berry must not steal the lamp.
	var teach := _unsigned_teaching_offer()
	if not teach.is_empty():
		return teach
	var berry := _unsigned_berry_offer()
	if not berry.is_empty():
		return berry
	return best


## Loaded lazily: Guide reads UIProgression's state helpers, so a preload here
## would be a cycle.
static func _guide():
	return load("res://Core/Campaign/Guide.gd")


static func objective_text() -> String:
	var qm := _quest_manager()
	if qm == null or not ("active_quests" in qm):
		return ""
	# The resolver owns every beat it covers (Core/Campaign/Guide.gd, walks in
	# campaign.json). The lines below are the legacy fallback for the rest.
	var g: Dictionary = _guide().next_step()
	if not g.is_empty():
		return str(g.get("text", ""))
	# The legacy lines below assume the field. With a menu open and nothing
	# from the resolver, the one true instruction is the way back to it.
	var sg = load("res://Core/Campaign/SurfaceGraph.gd")
	if not str(sg.current()).begins_with(sg.FIELD):
		return "▸ close [%s]" % sg.close_key()
	var best := _banner_quest()
	# Watch It Fade outranks leftover demos atom_in_biome mill [J]. Fog J
	# is an unrevealed live qubit, not a plant seat and not a lantern.
	if _is_fade_ask(best) and str(best.get("status", "")) != "ready":
		return _fade_walk_line()
	# Live Demos beat trigger (Village 🏭 → village_path_industrial) outranks
	# leftover READY claims and Captain cull. Never cull Woodlot.
	var atom_plant := _live_atom_plant_line()
	if atom_plant != "":
		return atom_plant
	# READY teaching (Gear-Bench timber_rhythm) is already accepted work.
	# Board-ask Abandon used to yield leftover unsigned Arc Accept, so
	# grind mashed [R] on an OPEN row that accept_quest no-ops.
	# Claim outranks leftover catalog. Unsigned STORY still waits on Arc.
	if str(best.get("status", "")) == "ready":
		return _claim_walk_line(best)
	# Leftover teaching whose FLAG already fired: Superpose mash is H²=I
	# (The Dark State, The Bridge Holds). Unsigned leftover signs on Arc.
	# Berry leftover (Open the Bank) is still the field walk, not Claim.
	if _leftover_flag_fired_handshake(best):
		if str(best.get("status", "")) == Quest.STATUS_STORY:
			return _waiting_arc_line()
		if _is_berry_ask(best):
			return _berry_walk_line(best)
		return _claim_walk_line(best)
	# Wave 24 literalist: gathered 🌱 3→21, then chrome-only. Unsigned plant
	# is STORY — hiding the banner after the gather walk ate Icon [5].
	# Plant is the live beat whether or not they have signed the Arc.
	if _is_plant_ask(best):
		return _plant_walk_line()
	if _is_discover_ask(best):
		return _discover_walk_line()
	if _is_coast_field_ask(best):
		return _coast_field_walk_line()
	# Story overlay is the Arc chord. Leftover Accept (The Bridge Holds)
	# must not mill ESC from a later walk while X/I is already open.
	if _story_surface_open() and not waiting_arc_offer().is_empty():
		if best.is_empty() or str(best.get("status", "")) == Quest.STATUS_STORY:
			var arc_home := _waiting_arc_line()
			if arc_home != "":
				return arc_home
	# the_gray: Superpose then wait. Berry Incorporate is the later ask.
	if _is_fade_ask(best):
		return _fade_walk_line()
	# Rain on the Fields: Spark jolt in wet country. Leftover ask_line
	# was a hint paragraph with no followable key (dump farm empty, chip Q).
	if _is_spark_ask(best):
		return _spark_walk_line()
	# lantern_teaching: biome_state_gte 🪔 is not discover. Name one next key.
	if _is_teaching_ask(best):
		return _teaching_walk_line()
	# Wave first_breath: unsigned berry door painted Farm/System/Story/Board
	# + QERF with no quest line. Field walk is the live ask, like plant.
	if _is_berry_ask(best):
		return _berry_walk_line()
	# Wave mill_wakes: unsigned Hold Commerce painted Village plant, not
	# Market. Board walk is the live ask, like plant/berry.
	if _is_board_ask(best):
		var walk := _board_walk_line(best)
		# Story overlay is the Arc chord (X → I → R). Overlay ESC here
		# ping-pongs grind X/ESC and never Accepts.
		if "ESC" in walk and _story_surface_open():
			var arc := _waiting_arc_line()
			if arc != "":
				return arc
		return walk
	# Nothing accepted: the story is WAITING on an Arc offer. A beat's
	# children open only once it is accepted and claimed (spec: requires =
	# complete), so a silent banner here is the classic "nothing moves" wall.
	# Name the waiting door and the route to Accept — quietly, one line.
	if best.is_empty() or str(best.get("status", "")) == Quest.STATUS_STORY:
		# Unresolved leftover (Stay Many) outranks standing-wet Superpose.
		# Coast Superpose only when no waiting catalog row remains.
		if not waiting_arc_offer().is_empty():
			return _waiting_arc_line()
		if not _unsigned_coast_field_offer().is_empty():
			return _coast_field_walk_line()
		var wet := _standing_wet_country_line()
		if wet != "":
			return wet
		return _waiting_arc_line()
	return _decorate_objective(best)


## The Arc offer the story is waiting on. Ranked: an offer some UNFIRED beat
## requires (the critical path) beats an optional leaf (pond_breathes, an
## un-chosen village path); then earliest act. Satisfied offers count — they
## complete the moment they are accepted, and skipping them is how the Wheel
## handshake stalled.
static func waiting_arc_offer() -> Dictionary:
	var qm := _quest_manager()
	if qm == null or not qm.has_method("get_story_offers"):
		return {}
	var farm = _active_farm()
	var fired: Dictionary = farm.story_flags_fired if farm != null and "story_flags_fired" in farm else {}
	var acts := {}
	var camps := {}
	var blocking := {}
	if qm.has_method("get_all_story_flags"):
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
	var best: Dictionary = {}
	var best_rank := 0x7FFFFFFF
	for q in qm.get_story_offers():
		if not (q is Dictionary) or str(q.get("category", "")) != "ARC":
			continue
		var src := str(q.get("source_flag", ""))
		if src != "" and fired.has(src):
			# Spent leftover (child fired / claimed). Unresolved leftover
			# (Stay Many, Bring Light In) still needs Accept.
			if not qm.has_method("flag_door_is_resolved") \
					or bool(qm.flag_door_is_resolved(src)):
				continue
		# Unfired live door outranks leftover catalog. lanternfall
		# outranks loom when both open after island_free.
		var leftover := 2000 if (src != "" and fired.has(src)) else 0
		var camp := str(camps.get(src, "demos"))
		var camp_pen := 0
		if camp == "loom":
			camp_pen = 500
		elif camp == "demos":
			camp_pen = 100
		var rank := leftover + camp_pen + int(acts.get(src, 99)) \
				+ (0 if blocking.has(src) else 1000)
		if rank < best_rank:
			best_rank = rank
			best = q
	return best


static func _waiting_arc_line() -> String:
	var q := waiting_arc_offer()
	if q.is_empty():
		return ""
	var om = _overlay_manager()
	if om != null and om.has_method("is_event_home_open") and bool(om.is_event_home_open("arc")):
		# Name the waiting leftover's GHJKL; row. Blind [R] Accept plus
		# grind G-inject signed Sign and Settle (row G) while Fill the
		# Urn sat on L. SurfaceRooms: ▸ [R] Accept the [L] Teaching.
		var row := _waiting_arc_row_key()
		if row != "":
			return SurfaceRooms.row_item_cue("X", "[R] Accept", row)
		return "▸ [R] Accept the teaching"
	if _story_surface_open():
		return "▸ %s [%s], then Accept [R]" % [SurfaceRooms.NAME_ARC, SurfaceRooms.KEY_OFFERS]
	var title := str(q.get("body", "")).split(" — ")[0].strip_edges()
	var tail := " waits — 📖 [X], %s [%s], Accept [R]" % [SurfaceRooms.NAME_ARC, SurfaceRooms.KEY_OFFERS]
	var room := OBJECTIVE_MAX_CHARS - tail.length() - 2
	if title.length() > room:
		title = title.substr(0, maxi(room - 1, 8)).strip_edges() + "…"
	return "📜 " + title + tail


## Arc GHJKL; letter for waiting_arc_offer(). Same catalog as
## ControlsOverlay._arc_rows() (IntroVoice.doors_ahead). Empty when the
## waiting leftover is not in the six-row window.
static func _waiting_arc_row_key() -> String:
	var q := waiting_arc_offer()
	if q.is_empty():
		return ""
	var rows := IntroVoice.doors_ahead(6, _quest_manager(), _active_farm())
	var want_id := int(q.get("id", -1))
	var want_src := str(q.get("source_flag", "")).strip_edges()
	var keys := ["G", "H", "J", "K", "L", ";", "'"]
	for i in range(mini(rows.size(), keys.size())):
		var entry = rows[i]
		if not (entry is Dictionary):
			continue
		var data = entry.get("data", {})
		if not (data is Dictionary):
			data = {}
		if want_id >= 0 and int(data.get("id", -2)) == want_id:
			return str(keys[i])
		if want_src != "" and str(data.get("source_flag", "")) == want_src:
			return str(keys[i])
		var want_body := str(q.get("body", "")).strip_edges()
		if want_body != "" and str(data.get("body", "")).strip_edges() == want_body:
			return str(keys[i])
	return ""


## Visual companion to objective_text() — which literal key is the next thing
## to press, for UI/Widgets/ObjectiveSpotlight.gd to pulse. Reuses the SAME
## ranked objective objective_text() decorates; never a second guess. "" when
## there's no reliable structured target (tutorial steps 2/5-gather/6 and
## in-progress ARC quests carry only free-text hints, no target field — those
## fall back to text-only, same as today, rather than inventing a guess).
static func objective_target_key() -> String:
	return str(objective_target().get("key", ""))


## Full structured target: {"key": String, "biome": String} — the spotlight
## pulses the biome tab first when the target biome isn't focused, then the
## key's chip. For active ARC quests the target derives from the quest's OWN
## state_predicates via PredicateGloss.TARGETS (the same table its prose
## speaks from) — no parallel hand-authored lookup to drift. First
## UNSATISFIED predicate with a table entry wins; none → honest dark.
static func objective_target() -> Dictionary:
	# The spotlight pulses the resolver's first key — the one the banner names first.
	var g: Dictionary = _guide().next_step()
	if not g.is_empty():
		var keys: Array = g.get("keys", [])
		var k := str(keys[0]) if not keys.is_empty() else ""
		if k.to_lower().begins_with("shift+"):
			k = k.substr(6)
		return {"key": k.to_upper() if k.length() == 1 else k}
	var best := _banner_quest()
	# Wave 23: plant-short pulses Forest, not Icon 5 and not C. PredicateGloss
	# target() for gate=plant is the Icon hat — true only after 🌱×5.
	if _is_plant_ask(best) and _sprout_short():
		if _basket_short():
			var bt := _basket_pay_target()
			if not bt.is_empty():
				return bt
		return {"key": "", "biome": "StarterForest"}
	if _is_plant_ask(best) and not _in_icon_submenu() and _plant_south_short():
		var st := _supply_target(_plant_south_current())
		if not st.is_empty():
			return st
	if _is_plant_ask(best):
		var icon_hat := _hat_key_for_frame("icon")
		var plant_biome := _plant_ask_biome(best)
		if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_ICON:
			return {"key": icon_hat, "hat": icon_hat, "biome": plant_biome}
		if not _empty_plot_exists(plant_biome):
			return {"key": "Q", "hat": icon_hat, "biome": plant_biome}
		return {"key": _empty_plot_key(), "hat": icon_hat, "biome": plant_biome}
	if _is_discover_ask(best) and _eagle_short():
		# lantern_door: empty next-key while 🦅 short named Forest, no gather.
		return _eagle_gather_target()
	if _is_discover_ask(best):
		var cap := _hat_key_for_frame("captain")
		if _slots_full():
			var cull := _named_cull_target()
			if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_CAPTAIN:
				return {"key": cap, "hat": cap, "biome": cull}
			if cull != "":
				var abm := _active_biome_manager()
				if abm != null and str(abm.get_active_biome()) != cull:
					var slot := int(abm.get_slot_for_biome(cull))
					var rail := str(abm.get_slot_key(slot)).to_upper() if slot >= 0 else ""
					return {"key": rail, "hat": cap, "biome": cull}
				return {"key": "Q", "hat": cap, "biome": cull}
		# lantern_door: paid eagles + open slots still named no coast.
		# Chart names the door's biome first (what R will load).
		var coast := _chart_target_biome()
		if coast == "":
			coast = _named_discover_target()
		if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_CAPTAIN:
			return {"key": cap, "hat": cap, "biome": coast}
		return {"key": "R", "hat": cap, "biome": coast}
	if _is_teaching_ask(best):
		return _teaching_target()
	if _is_braid_ask(best):
		return _braid_target()
	if _is_berry_ask(best):
		var berry_hat := _hat_key_for_frame("icon")
		var berry_biome := _berry_ask_biome(best)
		if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_ICON:
			return {"key": berry_hat, "hat": berry_hat, "biome": berry_biome}
		if _berry_ripe():
			return {"key": "R", "hat": berry_hat, "biome": berry_biome}
		if not _berry_tracking():
			return {"key": "F", "hat": berry_hat, "biome": berry_biome}
		return {"key": "", "hat": berry_hat, "biome": berry_biome}
	if _is_board_ask(best):
		return {"key": "C", "biome": _board_ask_biome(best)}
	if best.is_empty() or str(best.get("status", "")) == Quest.STATUS_STORY:
		# The story waits on an Arc offer (objective_text names it): pulse the
		# book key that opens the Arc, nothing else.
		if not waiting_arc_offer().is_empty():
			return {"key": "X", "biome": ""}
		return {}
	var status := str(best.get("status", ""))
	if status == "ready":
		return {"key": "C", "biome": ""}
	# Goods and standing asks are filled on the board — pulse C, not a field verb.
	if _is_board_ask(best):
		return {"key": "C", "biome": ""}
	if str(best.get("category", "")) == "TUTORIAL":
		var step := int(best.get("tutorial_step", -1))
		# tutorial_arc.json's own "biome" field names where the step's mechanic
		# actually happens (from_tutorial_def copies it onto the quest dict
		# verbatim) -- dropping it here left the spotlight pulsing the verb
		# chip alone, on whatever biome the player already stood on. A player
		# who never learns to switch biomes first hits a real dead end with no
		# visual cue to leave (mouse-only campaign wave 4; now step 3
		# "wayfinding" makes the crossing itself the taught beat).
		var step_biome := str(best.get("biome", ""))
		# Pulse the VERB chip, carrying the hat so spotlight can switch first.
		# Returning the hat key as `key` left superposition pulsing 0 forever
		# (never E) — mash E on Ace paused the sim instead of Hadamarding.
		if step == 3:
			return {"key": "E", "hat": _hat_key_for_frame("druid"), "biome": step_biome}
		if step == 4:
			# Bell is a walk, not a skip. Pulse the hat, then the mark, then
			# Gate, then Bell-on-Q. Never pulse R (Gate) while they still
			# need two checks — that was the dual-[R] Weave lie.
			var bell := {"key": "", "hat": _hat_key_for_frame("operator"), "biome": step_biome}
			var n := _checked_count()
			if _in_gate_submenu() and n >= 2:
				bell["key"] = "Q"
			elif n >= 2:
				bell["key"] = "R"
			return bell
		if step == 5:
			return {"key": "F", "hat": _hat_key_for_frame("ace"), "biome": step_biome}
		for entry_key in VERB_UNLOCK_STEP:
			if int(VERB_UNLOCK_STEP[entry_key]) == step:
				var hat_key := _hat_key_for_frame(str(entry_key).split(":")[0])
				if hat_key != "":
					return {"key": hat_key, "biome": step_biome}
		# No verb entry for this step (reap/contracts ride step-0 Ace verbs;
		# wayfinding is travel-only): the biome IS the target. The spotlight
		# pulses the biome tab while the player stands elsewhere and goes
		# honestly dark once they arrive — never a guessed key.
		if step_biome != "":
			return {"key": "", "biome": step_biome}
		return {}
	# Active ARC quest: 42/72 authored state_predicates carry a biome, 13 an
	# atom — structured targets exist one level down, no new authoring needed.
	var qm2 := _quest_manager()
	for pred in best.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		if qm2 != null and qm2.has_method("evaluate_predicate_score") \
				and float(qm2.evaluate_predicate_score(pred)) >= 0.85:
			continue  # already satisfied — point at the next unsatisfied leg
		var t := PredicateGloss.target(pred)
		if not t.is_empty():
			return t
	return {}


static func _hat_key_for_frame(frame_name: String) -> String:
	for hat_key in ToolConfig.HAT_KEY_TO_FRAME:
		if str(ToolConfig.HAT_KEY_TO_FRAME[hat_key]) == frame_name:
			return str(hat_key)
	return ""


## Lead the one live objective with the ROUTE it needs, when it needs one. The two moments a
## new player stalls (both survived the old data-shortcut probe): an OFFER awaiting the accept
## it was never taught (the contracts step, every arc offer), and a quest that has gone READY
## but sits unclaimed. Naming the route + the surface is the whole fix — spoken click-first
## from the route_* authorities above. In-progress quests keep just their hint — the bar is
## already teaching.
static func _decorate_objective(q: Dictionary) -> String:
	var status := str(q.get("status", ""))
	# Wave 19 earnest: Arc Accept while 🌱×3/5. Gather is the live beat;
	# signing the Arc does not grow sprouts. Do not plant for them.
	if _is_plant_ask(q) and _sprout_short():
		return _plant_walk_line()
	if status == Quest.STATUS_STORY:
		return "▸ to accept: " + route_accept()
	if status == "ready":
		# Wave 15: "tap C, its row twice" while Market was already open and
		# [R] still said Accept. Name one key. Fallback keeps route_claim().
		var claim := _claim_walk_line(q)
		if claim != "":
			return claim
		return "▸ to claim: " + route_claim(q)
	var travel := _travel_line(q)
	if travel != "":
		return travel
	var verb := _verb_line(q)
	if verb != "":
		return verb
	# Standing/goods live on the board. Derive the walk the same way travel
	# derives the rail key — even when the authored hint already names [C].
	# Wave 10/11: Market [Y] + first row was the apprentice (Go there), not
	# a Millwright delivery. Name Accept / Refresh / Deliver from the board.
	if _is_board_ask(q):
		var walk := _board_walk_line(q)
		if walk != "":
			return walk
	if _is_plant_ask(q):
		return _plant_walk_line()
	if _is_discover_ask(q):
		return _discover_walk_line()
	if _is_teaching_ask(q):
		return _teaching_walk_line()
	if _is_braid_ask(q):
		return _braid_walk_line()
	if _is_berry_ask(q):
		return _berry_walk_line(q)
	if _is_spark_ask(q):
		return _spark_walk_line()
	return IntroVoice.ask_line(q)


## A tutorial step whose mechanic lives in another biome has exactly one honest
## next action: go there. objective_target() already knew this — it pulses the
## biome's rail orb before the verb chip — but the TEXT did not, so the banner kept
## repeating the step's full instruction while the player stood in the wrong
## country and nothing they did could satisfy it. Both keyboard personas walled
## on precisely that: the literalist read "Cross to StarterForest…" as a
## standing order it had already obeyed, and the lost-lamb (who re-derives the
## objective every single turn, holding no memory of having crossed) reported
## LOOPING because the line never acknowledged the crossing.
##
## Scoped to TUTORIAL because that is where `biome` is a STEP-level field. Arc
## quests carry biomes per-predicate and already resolve targets through
## PredicateGloss; giving them a second, coarser travel rule would be the
## parallel authority this file exists to avoid.
static func _travel_line(q: Dictionary) -> String:
	if str(q.get("category", "")) != "TUTORIAL":
		return ""
	var want := str(q.get("biome", "")).strip_edges()
	if want == "":
		return ""
	var abm := _active_biome_manager()
	if abm == null:
		return ""
	if str(abm.get_active_biome()) == want:
		return ""
	var slot := int(abm.get_slot_for_biome(want))
	if slot < 0:
		return ""
	var key := str(abm.get_slot_key(slot)).to_upper()
	if key == "":
		# No slot key reaches it yet. Stay silent rather than name a key that
		# isn't there — a lie costs more than the missing nudge.
		return ""
	# Keyboard-first (wave 4 mill chip named C). If a menu is open, name
	# ONLY ESC — the board rebinds T/Y/U, so naming [U] while [U]
	# COMMITMENTS is still on screen is the dual-key wall (wave 7
	# literalist; wave 5's "ESC closes — then [U]" still printed [U]
	# twice). After ESC, this line becomes "[U] crosses …" with no rival.
	if _menu_open():
		return "▸ ESC closes"
	return "▸ [%s] crosses to %s" % [key, want]


## Once the player stands in the step's biome, the banner must name the
## next key the same way travel names the rail key.
##
## Wave 5: Superpose named no key. Wave 6: naming `[E] Superpose` while Ace
## still labels `[E] Pause` is the dual-key wall. Name the HAT first. After
## they wear it, E is Superpose and the banner can name `[E]`. Hats are
## toggles — once worn, stop naming the hat digit so a lost-lamb does not
## drop back to Ace. Never auto-wear: Ace E always pauses; Druid E Superposes.
##
## Wave 7 Bell: `[R] Weave` while Operator R is Gate and submenu-R is CZ.
## Name the walk: mark two plots, then `[R] Gate`, then `[Q] Bell`. Never
## apply the weave, never auto-check, never remap Ace R.
##
## Authored tutorial_hint stays English. Keys are derived, like travel.
static func _verb_line(q: Dictionary) -> String:
	if str(q.get("category", "")) != "TUTORIAL":
		return ""
	var step := int(q.get("tutorial_step", -1))
	if step != 3 and step != 4 and step != 5:
		return ""
	var tgt := objective_target()
	var key := str(tgt.get("key", "")).strip_edges().to_upper()
	var hat := str(tgt.get("hat", "")).strip_edges()
	var ask := IntroVoice.ask_line(q)
	if ask == "":
		return ""
	var need_frame := ""
	if hat != "" and ToolConfig.HAT_KEY_TO_FRAME.has(hat):
		need_frame = str(ToolConfig.HAT_KEY_TO_FRAME[hat])
	var wearing := str(ToolConfig.get_current_frame())
	if need_frame != "" and wearing != need_frame:
		return "▸ [%s] %s" % [hat.to_upper(), need_frame.capitalize()]
	# Reap is Ace Ctrl+Shift+F — never remapped onto plain F, never a hat swap.
	if step == 5:
		return "▸ Ctrl+Shift+F %s" % ask
	# Bell pair: Operator R opens Gate. Bell sits on Q once two plots are marked.
	if step == 4:
		var n := _checked_count()
		if _in_gate_submenu() and n >= 2:
			return "▸ [Q] Bell"
		if n >= 2:
			return "▸ [R] Gate"
		if n == 1:
			return "▸ Shift+%s marks the second plot" % _next_unmarked_plot_key()
		return "▸ Shift+G then Shift+H marks two plots"
	if key == "":
		return ""
	if ("[%s]" % key) in ask:
		return ask
	return "▸ [%s] %s" % [key, ask]


static func _instrument():
	# QuantumInstrument holds checked_plots + current_submenu_name.
	# PlayerShell is in group player_shell (same as _menu_open).
	var ml := Engine.get_main_loop()
	if not (ml is SceneTree):
		return null
	var tree := ml as SceneTree
	var shells := tree.get_nodes_in_group("player_shell")
	if shells.is_empty():
		return null
	var shell = shells[0]
	if shell != null and "quantum_instrument" in shell:
		return shell.quantum_instrument
	return null


static func _instrument_input():
	var ml := Engine.get_main_loop()
	if not (ml is SceneTree):
		return null
	var shells := (ml as SceneTree).get_nodes_in_group("player_shell")
	if shells.is_empty():
		return null
	var shell = shells[0]
	if shell != null and "instrument_input" in shell:
		return shell.instrument_input
	return null


static func _cull_confirm_pending() -> bool:
	# Captain Q arms Cull; any other key cancels. Grind mashed Q and
	# never F. Name the confirm key while the chord is live.
	var qii = _instrument_input()
	if qii == null or not qii.has_method("has_pending_confirm"):
		return false
	return bool(qii.has_pending_confirm())


static func _checked_count() -> int:
	var inst = _instrument()
	if inst == null or not ("checked_plots" in inst):
		return 0
	return int(inst.checked_plots.size())


static func _in_gate_submenu() -> bool:
	var inst = _instrument()
	if inst == null or not ("current_submenu_name" in inst):
		return false
	return str(inst.current_submenu_name) == "gate_selection"


static func _in_icon_submenu() -> bool:
	var inst = _instrument()
	if inst == null or not ("current_submenu_name" in inst):
		return false
	return str(inst.current_submenu_name) == "icon_injection"


static func _is_plant_ask(q: Dictionary) -> bool:
	# Icon injection is the planted word. Ace Rabi is also ledgered as
	# "plant" — that is a different verb. Count inject_icon as the door.
	for pred in q.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		if str(pred.get("type", "")) != "gate_sequence_contains":
			continue
		var g := str(pred.get("gate", "")).to_lower()
		if g == "inject_icon" or g == "plant":
			return true
	return false


static func _is_discover_ask(q: Dictionary) -> bool:
	# biome_evolving is the authored Chart ask. biome_state_gte on a
	# locked biome is the same mill (the_chain_tested: 🌉 in Lanternfall
	# after the coast was culled for Shrine). Teaching 🪔 is unlocked.
	for pred in q.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		var t := str(pred.get("type", ""))
		if t != "biome_evolving" and t != "biome_state_gte":
			continue
		var b := str(pred.get("biome", "")).strip_edges()
		if b != "" and not _biome_unlocked(b):
			return true
	return false


static func _story_flag_fired(src: String) -> bool:
	if src.strip_edges() == "":
		return false
	var farm = _active_farm()
	if farm == null or not ("story_flags_fired" in farm):
		return false
	return farm.story_flags_fired.has(src)


static func _fade_door_resolved() -> bool:
	# FLAG fires when Watch It Fade opens (parent the_crossing). Skip mill
	# fade only after a child passed through (watching_keeps) or leftover
	# teaching was claimed. A 10-key grind does not remash Fast-Fwd.
	var qm := _quest_manager()
	if qm == null or not qm.has_method("flag_door_is_resolved"):
		return false
	return bool(qm.flag_door_is_resolved("the_gray"))


static func _leftover_flag_fired_handshake(q: Dictionary) -> bool:
	# FLAG already proved the Chart. Leftover field Superpose is not the
	# mill. Fade teaching is work you complete by losing — until a child
	# has passed through, then leftover Watch It Fade is handshake Claim.
	if q.is_empty():
		return false
	var src := str(q.get("source_flag", "")).strip_edges()
	if src == "":
		return false
	if src == "the_gray":
		return _fade_door_resolved()
	return _story_flag_fired(src)


static func _is_coast_field_ask(q: Dictionary) -> bool:
	# Discover quest whose coast is already on the spindle. Remaining
	# preds are field work (Bring Light In: Superpose in GildedRot).
	# FLAG-fired leftover is handshake Claim, not Superpose mash.
	if q.is_empty() or _is_discover_ask(q):
		return false
	if _leftover_flag_fired_handshake(q):
		return false
	for pred in q.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		if str(pred.get("type", "")) != "biome_evolving":
			continue
		var b := str(pred.get("biome", "")).strip_edges()
		if b != "" and _biome_unlocked(b):
			return true
	return false


static func _unsigned_coast_field_offer() -> Dictionary:
	var qm := _quest_manager()
	if qm == null or not qm.has_method("get_story_offers"):
		return {}
	for q in qm.get_story_offers():
		if q is Dictionary and _is_coast_field_ask(q) and _preds_still_open(q):
			return q
	return {}


static func _coast_field_biome(q: Dictionary) -> String:
	for pred in q.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		if str(pred.get("type", "")) != "biome_evolving":
			continue
		var b := str(pred.get("biome", "")).strip_edges()
		if b != "":
			return b
	return ""


static func _is_fade_ask(q: Dictionary) -> bool:
	# the_gray: Superpose, then wait while the Bath drinks. Berry
	# Incorporate is a later predicate, not the mill. After watching_keeps
	# the door is resolved — leftover teaching remashes Fast-Fwd.
	if q.is_empty():
		return false
	if _fade_door_resolved():
		return false
	if str(q.get("source_flag", "")).strip_edges() == "the_gray":
		return true
	for pred in q.get("state_predicates", []):
		if pred is Dictionary and str(pred.get("type", "")) == "coherence_fell":
			return true
	return false


static func _unsigned_fade_offer() -> Dictionary:
	var qm := _quest_manager()
	if qm == null or not qm.has_method("get_story_offers"):
		return {}
	for q in qm.get_story_offers():
		if q is Dictionary and _is_fade_ask(q) and _preds_still_open(q):
			return q
	return {}


static func _accepted_fade_quest() -> Dictionary:
	# After Accept, Watch It Fade leaves story_offers. Leftover braid
	# Two Chores then milled [J] and never planted the fade pole.
	var qm := _quest_manager()
	if qm == null or not ("active_quests" in qm):
		return {}
	for q in qm.active_quests.values():
		if q is Dictionary and _is_fade_ask(q):
			return q
	return {}


static func _wait_for_fade_line() -> String:
	# Ace [F] Fast-Fwd while it fades. Ace E is pause. Do not mash
	# Druid E (H²=I undoes the Superpose the Bath is drinking).
	if _in_icon_submenu() or _menu_open():
		return "▸ ESC closes"
	if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_ACE:
		return "▸ [8] Ace — wait for the fade"
	if _sim_paused():
		return "▸ [F] Play"
	return "▸ [F] Fast-Fwd while it fades"


static var _fade_saw_equator: bool = false
static var _urn_saw_equator: bool = false


static func _col_is_pole(col: int) -> bool:
	# Known |z|>0.25 is a pole Hadamard can mint equator from. Unknown
	# bloch is not a pole — mill remashed E (H²=I) when viz flickered.
	if col < 0 or not _bloch_known(col):
		return false
	if _already_superposed(col):
		return false
	return absf(_plot_bloch_z(col)) > 0.25


static func _pole_plot_key() -> String:
	# Any occupied GildedRot plot still on a pole, including a freshly
	# planted known word. Inject does not bind a probe; mixed leftover
	# 🌹/🎭 are skipped. Empty plant seats have no axis.
	var bname := _active_biome_name()
	for i in range(PLOT_HOMEROW.length()):
		var k := _col_key(i)
		if k == "":
			continue
		var pair := _plot_axis_pair(bname, k)
		if pair == "":
			continue
		var wet := false
		for g in ["🌹", "🎭", "💃", "🍷", "🌉"]:
			if g in pair:
				wet = true
				break
		if not wet:
			continue
		if _col_is_pole(i):
			return k
	return ""


static func _equator_plot_key() -> String:
	# Already-superposed occupied plot. A new 🌉 may boot on the equator;
	# mill Fast-Fwds it instead of planting another seat.
	var bname := _active_biome_name()
	for i in range(PLOT_HOMEROW.length()):
		var k := _col_key(i)
		if k == "":
			continue
		var pair := _plot_axis_pair(bname, k)
		if pair == "":
			continue
		var wet := false
		for g in ["🌹", "🎭", "💃", "🍷", "🌉"]:
			if g in pair:
				wet = true
				break
		if not wet:
			continue
		if _already_superposed(i):
			return k
	return ""


static func _fade_plant_atom() -> String:
	# Icon picker is known_icons. 🌹/🎭 are biome-native, not taught.
	for atom in ["🌉", "🌾", "🐺", "💀"]:
		if _icon_known(atom):
			return atom
	return ""


static func _wet_workpiece_key() -> String:
	# Fresh 🌉 (ρ ⊗ |0⟩ then Hadamard) is the watermark peak. Leftover
	# 🌹 Hadamard left coherence at 0.16. After equator, mill T₂ masks.
	var lantern := _register_plot_key("GildedRot", "🌉")
	if lantern == "":
		lantern = _glyph_plot_key("🌉", "GildedRot", false)
	if lantern != "" and not _fade_saw_equator:
		return lantern
	if not _fade_saw_equator:
		var rose0 := _glyph_plot_key("🌹", "GildedRot", false)
		if rose0 != "":
			var rose_tok0 := ";" if rose0 == ";" else rose0.to_upper()
			var rose_col0 := PLOT_HOMEROW.find(rose_tok0)
			if rose_col0 >= 0 and (_col_is_pole(rose_col0) or not _bloch_known(rose_col0)):
				return rose0
		var pole0 := _pole_plot_key()
		if pole0 != "":
			return pole0
	if lantern != "":
		return lantern
	for glyph0 in ["🎭", "💃", "🍷"]:
		var g0 := _glyph_plot_key(glyph0, "GildedRot", false)
		if g0 != "":
			return g0
	var rose := _glyph_plot_key("🌹", "GildedRot", false)
	if rose != "":
		var rose_tok := ";" if rose == ";" else rose.to_upper()
		var rose_col := PLOT_HOMEROW.find(rose_tok)
		if rose_col >= 0 and _col_is_pole(rose_col):
			return rose
	for glyph in ["🎭", "💃", "🍷"]:
		var g := _glyph_plot_key(glyph, "GildedRot", false)
		if g == "":
			continue
		var tok := ";" if g == ";" else g.to_upper()
		var c := PLOT_HOMEROW.find(tok)
		if c >= 0 and _col_is_pole(c):
			return g
	var pole := _pole_plot_key()
	if pole != "":
		return pole
	var equator := _equator_plot_key()
	if equator != "":
		return equator
	for glyph in ["🎭", "💃", "🍷"]:
		var g2 := _glyph_plot_key(glyph, "GildedRot", false)
		if g2 != "":
			return g2
	if rose != "":
		return rose
	if _plot_bound(_focused_col()):
		return _col_key(_focused_col())
	return "G"


static func _bloch_of(col: int) -> Dictionary:
	var farm = _active_farm()
	var bname := _active_biome_name()
	if farm == null or farm.grid == null or bname == "" or col < 0:
		return {}
	var biome = farm.grid.get_biome(bname) if farm.grid.has_method("get_biome") else null
	if biome == null or biome.viz_cache == null or not biome.viz_cache.has_method("get_bloch"):
		return {}
	var bloch: Dictionary = biome.viz_cache.get_bloch(col)
	return bloch if bloch is Dictionary else {}


static func _bloch_known(col: int) -> bool:
	# Headless viz_cache can be empty. Empty is unknown, not mixed gray.
	return not _bloch_of(col).is_empty()


static func _off_pole(col: int) -> bool:
	# Wet-country dephasing drinks x,y toward 0 while z stays. |x|>0.25
	# then goes false and mill mashed E (H²=I). Off-pole is the fade.
	var bloch := _bloch_of(col)
	if bloch.is_empty():
		return false
	if absf(float(bloch.get("x", 0.0))) > 0.25 \
			or absf(float(bloch.get("y", 0.0))) > 0.25:
		return true
	return absf(float(bloch.get("z", 1.0))) < 0.7


static func _fade_has_drunk(q: Dictionary) -> bool:
	# coherence_fell + purity_at_most both hold. Berry is the remainder.
	var qm := _quest_manager()
	if qm == null or not qm.has_method("evaluate_predicate_score"):
		return false
	var need := 0
	var held := 0
	for pred in q.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		var t := str(pred.get("type", ""))
		if t != "coherence_fell" and t != "purity_at_most":
			continue
		need += 1
		if float(qm.evaluate_predicate_score(pred)) >= 0.85:
			held += 1
	return need > 0 and held >= need


static func _fade_walk_line() -> String:
	var q := _banner_quest()
	# Unsigned Watch It Fade: mill Accept, not overlay ESC. ESC here
	# ping-ponged grind X/I/ESC and never signed the door.
	if str(q.get("status", "")) == Quest.STATUS_STORY:
		return _waiting_arc_line()
	# Leftover 🌹/🎭 are mixed. Superpose cannot mint equator. Plant a
	# known word on an empty seat so Hadamard has a pole. Pick 🌉 inside
	# the Icon submenu — ESC here ping-ponged grind R/ESC and never planted.
	# Leftover GildedRot is already gray (coherence ~0.16). Hadamard on
	# leftover 🌹 does not peak 0.3. Plant 🌉 (ρ ⊗ |0⟩) then Superpose it.
	if not _fade_has_drunk(q) and not _atom_in_biome("GildedRot", "🌉"):
		var atom := _fade_plant_atom()
		if atom != "" and (_in_icon_submenu() or _empty_plot_exists("GildedRot")):
			return _named_atom_plant_line("GildedRot", atom)
	if _in_icon_submenu() or _menu_open():
		return "▸ ESC closes"
	var cross := _cross_to("GildedRot")
	if cross != "":
		return cross
	var col := _focused_col()
	# Leftover Superpose on 🌹 keeps biome coherence up. Strike it only
	# when 🌉 is not on the register — planted lantern is the workpiece.
	if _register_plot_key("GildedRot", "🌉") == "":
		var rose_key := _glyph_plot_key("🌹", "GildedRot", false)
		if rose_key != "":
			var rose_tok := ";" if rose_key == ";" else rose_key.to_upper()
			var rose_col := PLOT_HOMEROW.find(rose_tok)
			if rose_col >= 0 and _already_superposed(rose_col):
				if col != rose_col:
					return "▸ [%s]" % rose_tok
				if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_ACE:
					return "▸ [8] Ace — collapse the rose"
				return "▸ [R] Strike — collapse the rose"
	var want := _wet_workpiece_key()
	var token := ";" if want == ";" else want.to_upper()
	var want_col := PLOT_HOMEROW.find(token) if want != "" else -1
	if want != "" and col != want_col:
		return "▸ [%s]" % token
	# Superpose a leftover pole once so the session watermark can pass 0.3.
	# Do not latch leftover mixed 🎭 — that skipped Hadamard while coherence
	# was already 0.16. Latch only when mill names [E].
	if _fade_saw_equator and not _fade_has_drunk(q):
		return _wait_for_fade_line()
	var need_h := (_col_is_pole(col) or not _bloch_known(col)) \
			and not _already_superposed(col) and not _fade_has_drunk(q)
	if need_h:
		if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_DRUID:
			return "▸ [0] Druid"
		_fade_saw_equator = true
		return "▸ [E] Superpose"
	if not _fade_has_drunk(q):
		return _wait_for_fade_line()
	return _berry_walk_line(q)


static func _is_spark_ask(q: Dictionary) -> bool:
	# the_verbs_come_home: one Spark jolt in wet country.
	if q.is_empty():
		return false
	if str(q.get("source_flag", "")).strip_edges() == "the_verbs_come_home":
		return true
	for pred in q.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		if str(pred.get("type", "")) != "gate_sequence_contains":
			continue
		if str(pred.get("gate", "")).strip_edges().to_lower() == "spark":
			return true
	return false


static func _biome_is_open_here(name: String) -> bool:
	var farm = _active_farm()
	if farm == null or farm.grid == null or name.strip_edges() == "":
		return false
	if not farm.grid.has_method("get_biome"):
		return false
	var b = farm.grid.get_biome(name)
	if b == null or b.quantum_computer == null:
		return false
	if b.quantum_computer.has_method("is_open_here"):
		return bool(b.quantum_computer.is_open_here())
	return str(b.quantum_computer.get("regime_override")) == "open"


static func _spark_walk_line() -> String:
	# Spark hat (4), ⚡ mode: wet plot, R jolts north. Enclave chips grey.
	if _in_icon_submenu() or _menu_open():
		return "▸ ESC closes"
	var here := _active_biome_name()
	if not _biome_is_open_here(here):
		for name in ["ZenoLatch", "GildedRot", "ShrineOfAshes"]:
			if _biome_unlocked(name):
				var cross := _cross_to(name)
				if cross != "":
					return cross
				break
	if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_SPARK:
		return "▸ [4] Spark"
	if int(ToolConfig.get_frame_mode_index(ToolConfig.FRAME_SPARK)) != 0:
		return "▸ [1] ⚡"
	# Hat 4 leave_plot_ring clears current_plot_idx. Sticky last-selected
	# is not a Spark seat — mill named [R] and grind no-op mashed it.
	var live := -1
	var inst = _instrument()
	if inst != null and "current_plot_idx" in inst:
		live = int(inst.current_plot_idx)
	if live != 0:
		return "▸ [G]"
	return "▸ [R] jolt north"


static func _coast_field_walk_line() -> String:
	# Chart landed. Name one field key. Leftover [X] then Arc toasts are
	# not the mill. Slots-full cull is not the mill.
	var q := _banner_quest()
	if q.is_empty() or not _is_coast_field_ask(q):
		q = _unsigned_coast_field_offer()
	# Unsigned leftover (The Bridge Holds after the_chain_tested FLAG)
	# signs on Arc. Overlay ESC here ping-ponged grind X/I/ESC.
	if str(q.get("status", "")) == Quest.STATUS_STORY:
		return _waiting_arc_line()
	var coast := _coast_field_biome(q)
	# Plant 🌉 before overlay ESC. Icon submenu mill ESC ping-ponged
	# grind R/ESC and never planted (fade walk already does this).
	if (coast == "Lanternfall" \
			or str(q.get("source_flag", "")).strip_edges() == "the_chain_tested") \
			and not _atom_in_biome("Lanternfall", "🌉"):
		if _in_icon_submenu() or _empty_plot_exists("Lanternfall"):
			return _named_atom_plant_line("Lanternfall", "🌉")
	if _in_icon_submenu() or _menu_open():
		return "▸ ESC closes"
	if coast != "":
		var cross := _cross_to(coast)
		if cross != "":
			return cross
	var col := _focused_col()
	# Fill the Urn: gated 💀→⚱ is shut at leftover north pole. Superpose
	# once to seed the gate, then Fast-Fwd so the basin fills itself.
	# Remashing E after that is H²=I (grind froze 8× Superpose).
	var coast_name := _coast_field_biome(q)
	if coast_name == "ShrineOfAshes" \
			or str(q.get("source_flag", "")).strip_edges() == "the_basin":
		var urn := _glyph_plot_key("⚱", "ShrineOfAshes", false)
		if urn == "":
			urn = _glyph_plot_key("💀", "ShrineOfAshes", false)
		var token := "G"
		var want_col := 0
		if urn != "":
			token = ";" if urn == ";" else urn.to_upper()
			want_col = PLOT_HOMEROW.find(token)
		# Sticky last-selected is Village mill G (empty). Superpose there
		# no-ops; 💀 stays 1. Seat Shrine's leftover 💀⚱ first.
		var here := ""
		var live := -1
		var inst = _instrument()
		if inst != null:
			if "current_biome" in inst:
				here = str(inst.current_biome)
			if "current_plot_idx" in inst:
				live = int(inst.current_plot_idx)
		if here != "ShrineOfAshes" or live != want_col:
			return "▸ [%s] the urn" % token
		# One Superpose seeds the gate. Unknown bloch is not "off pole" —
		# mill skipped E and Fast-Fwd'd leftover 💀=1. Do not latch on
		# naming Superpose: grind inject/look then skipped E. After H
		# lands, off-pole mill Fast-Fwds. A remash is grind's freeze.
		if _col_is_pole(col) or not _bloch_known(col):
			if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_DRUID:
				return "▸ [0] Druid"
			return "▸ [E] Superpose — seed the urn"
		if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_ACE:
			return "▸ [8] Ace — the urn fills"
		if _sim_paused():
			return "▸ [F] Play"
		return "▸ [F] Fast-Fwd — the urn fills"
	# The Bridge Holds: FLAG fired without 🌉 on Lanternfall (🪔🗼 sat
	# on G). Fast-Fwd on the leftover lamp never made Claim READY.
	if coast_name == "Lanternfall" \
			or str(q.get("source_flag", "")).strip_edges() == "the_chain_tested":
		if not _atom_in_biome("Lanternfall", "🌉"):
			return _named_atom_plant_line("Lanternfall", "🌉")
		var br := _glyph_plot_key("🌉", "Lanternfall", false)
		if br != "":
			var br_tok := ";" if br == ";" else br.to_upper()
			var br_col := PLOT_HOMEROW.find(br_tok)
			if col != br_col:
				return "▸ [%s] the bridge" % br_tok
			if _col_is_pole(col) or not _bloch_known(col):
				if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_DRUID:
					return "▸ [0] Druid"
				return "▸ [E] Superpose — hold the bridge"
		if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_ACE:
			return "▸ [8] Ace — the bridge holds"
		if _sim_paused():
			return "▸ [F] Play"
		return "▸ [F] Fast-Fwd — the bridge holds"
	# After one Superpose the Bloch is off the pole. Remashing E is H²=I.
	var off_pole := _bloch_known(col) and not _col_is_pole(col)
	if _already_superposed(col) or off_pole:
		# the_crossing wants coherence AT LEAST 0.3 — Fast-Fwd drinks it.
		# Unsigned leftover mills Accept; fade asks wait. Do not mill
		# Druid E here (H²=I undoes the Superpose).
		if _is_fade_ask(q):
			return _wait_for_fade_line()
		if str(q.get("status", "")) == Quest.STATUS_STORY:
			var arc := _waiting_arc_line()
			if arc != "":
				return arc
		if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_ACE:
			return "▸ [8] Ace — hold the coast"
		if _sim_paused():
			return "▸ [F] Play"
		return "▸ [F] Fast-Fwd"
	if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_DRUID:
		return "▸ [0] Druid"
	return "▸ [E] Superpose"


static func _standing_wet_country_line() -> String:
	# After Chart GildedRot the leftover discover offer may not be in
	# story_offers. Standing in the wet country is Bring Light In.
	var abm := _active_biome_manager()
	if abm == null or str(abm.get_active_biome()) != "GildedRot":
		return ""
	if _in_icon_submenu() or _menu_open():
		return "▸ ESC closes"
	var col := _focused_col()
	if _already_superposed(col):
		# watching_keeps already passed through. Superposed leftover 🌹
		# is not a Fast-Fwd mill. Open the Bank berry is the walk.
		if _fade_door_resolved():
			return ""
		var q := _banner_quest()
		if _is_fade_ask(q) or not _unsigned_fade_offer().is_empty():
			return _wait_for_fade_line()
		var arc := _waiting_arc_line()
		if arc != "":
			return arc
		return _wait_for_fade_line()
	if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_DRUID:
		return "▸ [0] Druid"
	return "▸ [E] Superpose"


static func _is_teaching_ask(q: Dictionary) -> bool:
	# lantern_teaching: hold 🪔 in Lanternfall. Not mill ⚙. Not discover.
	if str(q.get("source_flag", "")).strip_edges() == "lantern_teaching":
		return true
	for pred in q.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		if str(pred.get("type", "")) != "biome_state_gte":
			continue
		var atom := str(pred.get("atom", pred.get("emoji", ""))).strip_edges()
		if atom == "🪔":
			return true
	return false


static func _is_braid_ask(q: Dictionary) -> bool:
	# Two Chores: Hadamard then CNOT. Do not treat Bell (H+CNOT) as the word.
	if str(q.get("source_flag", "")).strip_edges() == "braid_order":
		return true
	for pred in q.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		if str(pred.get("type", "")) != "gate_order":
			continue
		var word: Array = pred.get("gates", [])
		if not (word is Array) or word.size() < 2:
			continue
		var names: Array = []
		for g in word:
			names.append(str(g).strip_edges().to_lower())
		if "hadamard" in names and "cnot" in names:
			return true
	return false


static func _braid_walk_line() -> String:
	# After honest Superpose, name [9] then [R] Gate then [E] CNOT.
	# Bell sits on Q in the same picker — that restacks H and is not the word.
	if _menu_open():
		return "▸ ESC closes"
	var op := _hat_key_for_frame("operator")
	var wearing := str(ToolConfig.get_current_frame())
	if wearing != ToolConfig.FRAME_OPERATOR:
		var col := _focused_col()
		if wearing != ToolConfig.FRAME_DRUID and not _already_superposed(col):
			return "▸ [0] Druid"
		if wearing == ToolConfig.FRAME_DRUID and not _already_superposed(col):
			return "▸ [E] Superpose"
		return "▸ [%s] Operator" % op.to_upper()
	var n := _checked_count()
	if _in_gate_submenu() and n >= 2:
		return "▸ [E] CNOT"
	if n >= 2:
		return "▸ [R] Gate"
	if n == 1:
		return "▸ Shift+%s marks the second plot" % _next_unmarked_plot_key()
	return "▸ Shift+G then Shift+H marks two plots"


static func _braid_target() -> Dictionary:
	var op := _hat_key_for_frame("operator")
	var out := {"key": "", "hat": op, "biome": ""}
	if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_OPERATOR:
		var col := _focused_col()
		if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_DRUID \
				and not _already_superposed(col):
			out["key"] = "0"
			out["hat"] = "0"
			return out
		if str(ToolConfig.get_current_frame()) == ToolConfig.FRAME_DRUID \
				and not _already_superposed(col):
			out["key"] = "E"
			out["hat"] = "0"
			return out
		out["key"] = op
		return out
	var n := _checked_count()
	if _in_gate_submenu() and n >= 2:
		out["key"] = "E"
	elif n >= 2:
		out["key"] = "R"
	return out


static func _is_berry_ask(q: Dictionary) -> bool:
	for pred in q.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		var t := str(pred.get("type", ""))
		if t == "berry_consumed_count_gte" or t == "berry_total_phase_gte":
			return true
	return false


static func _berry_ask_biome(q: Dictionary) -> String:
	for pred in q.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		var t := str(pred.get("type", ""))
		if t == "berry_consumed_count_gte" or t == "berry_total_phase_gte":
			return str(pred.get("biome", "")).strip_edges()
	return ""


static func _biome_unlocked(bname: String) -> bool:
	var abm := _active_biome_manager()
	if abm == null or not abm.has_method("get_slot_for_biome"):
		return false
	return int(abm.get_slot_for_biome(bname)) >= 0


const PLOT_HOMEROW := "GHJKL;"


static func _active_farm():
	var gsm = Engine.get_main_loop().root.get_node_or_null("GameStateManager") if Engine.get_main_loop() else null
	return gsm.get_active_farm() if (gsm and gsm.has_method("get_active_farm")) else null


static func _sprout_have() -> float:
	var farm = _active_farm()
	if farm == null or not ("economy" in farm) or farm.economy == null:
		return 0.0
	if not farm.economy.has_method("get_resource"):
		return 0.0
	return float(farm.economy.get_resource("🌱"))


static func _sprout_short() -> bool:
	# Match can_afford: plant costs 5 🌱 credits, not a gather-on-Village lie.
	# No farm yet: do not pretend they are short (that would gold-banner Forest
	# before the mill door).
	var farm = _active_farm()
	if farm == null or not ("economy" in farm) or farm.economy == null:
		return false
	if not farm.economy.has_method("get_resource"):
		return false
	return _sprout_have() < 5.0


static func _col_key(col: int) -> String:
	if col < 0 or col >= PLOT_HOMEROW.length():
		return ""
	var k := PLOT_HOMEROW.substr(col, 1)
	return k if k == ";" else k.to_upper()


static func _cross_to(want: String) -> String:
	if _menu_open():
		return "▸ ESC closes"
	var abm := _active_biome_manager()
	if abm == null:
		return ""
	if str(abm.get_active_biome()) == want:
		return ""
	var slot := int(abm.get_slot_for_biome(want))
	if slot < 0:
		return ""
	var key := str(abm.get_slot_key(slot)).to_upper()
	if key == "":
		return ""
	return "▸ [%s] crosses to %s" % [key, want]


static func _empty_plot_exists(biome_name: String = "") -> bool:
	# lantern_wakes: Lanternfall's five lamps fill the ring. J is not empty
	# just because _empty_plot_key falls back to J. Do not plant for them.
	var farm = _active_farm()
	var abm := _active_biome_manager()
	if farm == null or farm.grid == null:
		return false
	var bname := biome_name.strip_edges()
	if bname == "" and abm != null:
		bname = str(abm.get_active_biome())
	if bname == "":
		return false
	var biome = farm.grid.get_biome(bname) if farm.grid.has_method("get_biome") else null
	var nq := 0
	if biome != null and biome.quantum_computer != null and biome.quantum_computer.register_map != null:
		nq = int(biome.quantum_computer.register_map.num_qubits)
	if not farm.grid.has_method("get_plot_biome_assignments"):
		return false
	var assignments: Dictionary = farm.grid.get_plot_biome_assignments()
	for pos in assignments.keys():
		if str(assignments[pos]) != bname:
			continue
		var col := int(pos.x) if pos is Vector2i else int(pos.x)
		if col >= nq:
			return true
	return false


static func _plant_ask_biome(q: Dictionary) -> String:
	for pred in q.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		var t := str(pred.get("type", ""))
		if t == "gate_sequence_contains":
			var g := str(pred.get("gate", "")).to_lower()
			if g == "inject_icon" or g == "plant":
				var b := str(pred.get("biome", "")).strip_edges()
				if b != "":
					return b
		if t == "atom_in_biome":
			var b2 := str(pred.get("biome", "")).strip_edges()
			if b2 != "":
				return b2
	return ""


static func _empty_plot_key() -> String:
	# Wave 18 literalist: "empty plot" named no key. Empty = column past
	# the biome's live qubits (plot_glance `empty`). Do not plant for them.
	var farm = _active_farm()
	var abm := _active_biome_manager()
	if farm == null or abm == null or farm.grid == null:
		return "J"
	var bname := str(abm.get_active_biome())
	var biome = farm.grid.get_biome(bname) if farm.grid.has_method("get_biome") else null
	var nq := 0
	if biome != null and biome.quantum_computer != null and biome.quantum_computer.register_map != null:
		nq = int(biome.quantum_computer.register_map.num_qubits)
	var inst = _instrument()
	if inst != null and "current_plot_idx" in inst and int(inst.current_plot_idx) >= nq:
		var focused := _col_key(int(inst.current_plot_idx))
		if focused != "":
			return focused
	if farm.grid.has_method("get_plot_biome_assignments"):
		var cols: Array = []
		var assignments: Dictionary = farm.grid.get_plot_biome_assignments()
		for pos in assignments.keys():
			if str(assignments[pos]) != bname:
				continue
			var col := int(pos.x) if pos is Vector2i else int(pos.x)
			if col >= nq:
				cols.append(col)
		cols.sort()
		if not cols.is_empty():
			var k := _col_key(int(cols[0]))
			if k != "":
				return k
	return _col_key(nq) if _col_key(nq) != "" else "J"


static func _sprout_plot_key() -> String:
	return _glyph_plot_key("🌱")


static func _glyph_plot_key(glyph: String, biome_name: String = "", scout: bool = true) -> String:
	# Fog-honest: name a glyph bubble only when a sighted player can read it.
	# Wave 20: Forest G is 🐺🦌 — never call that a 🌱 plot. Scout unrevealed
	# live plots (H J K L) until the glyph shows. Empty columns (;) are plant seats.
	# scout=false: fade mill. Fog J is not a 🌉.
	var farm = _active_farm()
	var bname := biome_name.strip_edges()
	if bname == "":
		bname = _active_biome_name()
	if farm == null or farm.grid == null or bname == "":
		return ""
	var biome = farm.grid.get_biome(bname) if farm.grid.has_method("get_biome") else null
	if biome == null:
		return ""
	var nq := 0
	if biome.quantum_computer != null and biome.quantum_computer.register_map != null:
		nq = int(biome.quantum_computer.register_map.num_qubits)
	var revealed: Dictionary = {}
	if "revealed_plots" in farm:
		for rp in farm.revealed_plots:
			revealed[rp] = true
	if not farm.grid.has_method("get_plot_biome_assignments"):
		return ""
	var assignments: Dictionary = farm.grid.get_plot_biome_assignments()
	var sprout_cols: Array = []
	var scout_cols: Array = []
	for pos in assignments.keys():
		if str(assignments[pos]) != bname:
			continue
		var col := int(pos.x)
		if col < 0 or col >= nq:
			continue
		if revealed.has(pos) and biome.viz_cache != null and biome.viz_cache.has_method("get_axis"):
			var axis: Dictionary = biome.viz_cache.get_axis(col)
			var pair := str(axis.get("north", "")) + str(axis.get("south", ""))
			if glyph in pair:
				sprout_cols.append(col)
				continue
		if not revealed.has(pos):
			scout_cols.append(col)
	sprout_cols.sort()
	if not sprout_cols.is_empty():
		return _col_key(int(sprout_cols[0]))
	if not scout:
		return ""
	scout_cols.sort()
	if not scout_cols.is_empty():
		return _col_key(int(scout_cols[0]))
	return ""


static func _focused_col() -> int:
	# eagle_overhead: Icon inject can clear current_plot_idx while look.field
	# still names Village G. Sticky last-selected is the workpiece F/R hit.
	var inst = _instrument()
	if inst == null:
		return -1
	if "current_plot_idx" in inst:
		var qid := int(inst.current_plot_idx)
		if qid >= 0:
			return qid
	if "last_selected_position" in inst:
		var pos = inst.last_selected_position
		if pos is Vector2i and int(pos.x) >= 0:
			return int(pos.x)
	return -1


static func _live_plot_key() -> String:
	# Hat switch 5 clears current_plot_idx. Sticky last-selected is not a
	# focused plant seat — mill must name GHJKL; again before Icon R.
	var inst = _instrument()
	if inst == null or not ("current_plot_idx" in inst):
		return ""
	return _col_key(int(inst.current_plot_idx))


static func _active_biome_name() -> String:
	var abm := _active_biome_manager()
	if abm == null:
		return ""
	return str(abm.get_active_biome())


static func _plot_at(col: int):
	# ChipContext.bind reads farm.grid.get_plot(pos).terminal — match that.
	# Wave 20: terminal_pool.get_terminal_for_register missed a measured 🌱
	# plot, so the banner said [F] Explore after Strike had already landed.
	var farm = _active_farm()
	var bname := _active_biome_name()
	if farm == null or farm.grid == null or col < 0 or bname == "":
		return null
	if not farm.grid.has_method("get_plot_biome_assignments"):
		return null
	var assignments: Dictionary = farm.grid.get_plot_biome_assignments()
	for p in assignments.keys():
		if int(p.x) != col:
			continue
		if str(assignments[p]) != bname:
			continue
		return farm.grid.get_plot(p)
	return null


static func _plot_terminal(col: int):
	var plot = _plot_at(col)
	if plot != null and plot.terminal != null:
		return plot.terminal
	# lantern_door: Strike calls release_register (is_bound→false). The
	# frozen measure still sits in the pool until Q. Plot.terminal can lag
	# that snapshot; look up by grid pos (bound OR measured).
	var farm = _active_farm()
	if farm == null or farm.terminal_pool == null:
		return null
	if not farm.terminal_pool.has_method("get_terminal_at_grid_pos"):
		return null
	if plot == null or not ("grid_position" in plot):
		return null
	return farm.terminal_pool.get_terminal_at_grid_pos(plot.grid_position)


static func _plot_bound(col: int) -> bool:
	# Occupied: a live probe or a frozen measure waiting for Q. Strike
	# frees the register; the snapshot still owns the plot.
	return _plot_terminal(col) != null


static func _plot_measured(col: int) -> bool:
	var term = _plot_terminal(col)
	return term != null and (bool(term.is_measured) or (term.has_method("has_banked") and term.has_banked()))


static func _measured_glyph(col: int) -> String:
	var term = _plot_terminal(col)
	if term != null and str(term.measured_outcome) != "":
		return str(term.measured_outcome)
	var plot = _plot_at(col)
	if plot == null:
		return ""
	if plot.has_method("get_measured_outcome"):
		return str(plot.get_measured_outcome())
	if "measured_outcome" in plot:
		return str(plot.measured_outcome)
	return ""


static func _sprout_is_south(col: int) -> bool:
	# Fog-honest: only when the player can read both poles.
	var farm = _active_farm()
	if farm == null or not ("revealed_plots" in farm):
		return false
	var revealed := false
	for rp in farm.revealed_plots:
		if int(rp.x) == col:
			revealed = true
			break
	if not revealed:
		return false
	var bname := _active_biome_name()
	if farm.grid == null or bname == "":
		return false
	var biome = farm.grid.get_biome(bname) if farm.grid.has_method("get_biome") else null
	if biome == null or biome.viz_cache == null or not biome.viz_cache.has_method("get_axis"):
		return false
	var axis: Dictionary = biome.viz_cache.get_axis(col)
	var north := str(axis.get("north", ""))
	var south := str(axis.get("south", ""))
	return "🌱" in south and "🌱" not in north


static func _plot_bloch_z(col: int) -> float:
	# Sighted lean: the bubble's north/south tilt. Missing cache → 0
	# (do not Superpose-guess).
	var farm = _active_farm()
	var bname := _active_biome_name()
	if farm == null or farm.grid == null or bname == "":
		return 0.0
	var biome = farm.grid.get_biome(bname) if farm.grid.has_method("get_biome") else null
	if biome == null or biome.viz_cache == null or not biome.viz_cache.has_method("get_bloch"):
		return 0.0
	var bloch: Dictionary = biome.viz_cache.get_bloch(col)
	if bloch.is_empty():
		return 0.0
	return float(bloch.get("z", 0.0))


static func _biased_against_sprout(col: int) -> bool:
	if not _sprout_is_south(col):
		return false
	return _plot_bloch_z(col) > 0.35


static func _already_superposed(col: int) -> bool:
	var farm = _active_farm()
	var bname := _active_biome_name()
	if farm == null or farm.grid == null or bname == "":
		return false
	var biome = farm.grid.get_biome(bname) if farm.grid.has_method("get_biome") else null
	if biome == null or biome.viz_cache == null or not biome.viz_cache.has_method("get_bloch"):
		return false
	var bloch: Dictionary = biome.viz_cache.get_bloch(col)
	if bloch.is_empty():
		return false
	# Dawn kick is Ry(0.35) → |x|≈0.34. That is not Hadamard. 0.25 milled
	# wait-for-fade on a planted 🌉 and never peaked the watermark.
	return absf(float(bloch.get("x", 0.0))) > 0.5 \
			or absf(float(bloch.get("y", 0.0))) > 0.5


static func _sim_paused() -> bool:
	var ml := Engine.get_main_loop()
	if not (ml is SceneTree):
		return false
	var shells := (ml as SceneTree).get_nodes_in_group("player_shell")
	if shells.is_empty():
		return false
	var shell = shells[0]
	return shell != null and ("paused" in shell) and bool(shell.paused)


static func ace_f_keeps_fast_fwd() -> bool:
	# Ace F on an unbound leftover plot remaps to Explore (chip resolver).
	# Fill the Urn needs time-skip so the gated 💀→⚱ basin can tick.
	# Berry Track already Fast-Fwds the ripen; Explore would drop the loop.
	if _berry_tracking():
		return true
	var q := _banner_quest()
	if q.is_empty():
		q = _unsigned_coast_field_offer()
	if str(q.get("source_flag", "")).strip_edges() == "the_basin":
		return true
	if _coast_field_biome(q) == "ShrineOfAshes":
		return true
	# The Bridge Holds: planted 🌉 is unbound fog. Explore steals F;
	# Fast-Fwd never dephases so Claim never READY.
	if str(q.get("source_flag", "")).strip_edges() == "the_chain_tested":
		return true
	if _coast_field_biome(q) == "Lanternfall":
		return true
	return false


static func ace_f_would_explore() -> bool:
	# Toast must not own F when Ace F is Explore (wave 19 dual-F).
	if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_ACE:
		return false
	if _menu_open() or _in_icon_submenu():
		return false
	# Live berry Track: Ace F Fast-Fwds the ripen. Explore would drop the loop.
	if _berry_tracking():
		return false
	# Fill the Urn: leftover 💀 is unbound fog. Explore steals F; the
	# gated basin never ticks. Keep Fast-Fwd.
	if ace_f_keeps_fast_fwd():
		return false
	var col := _focused_col()
	if col < 0:
		return false
	# lantern_door: after Strike, is_bound drops. Q harvests. Do not Explore.
	if _plot_measured(col):
		return false
	return not _plot_bound(col)


static func _sprout_gather_line() -> String:
	# Wave 18 earnest: Ace Q on Village 👥🌾 paid people, not seeds.
	# 🌱 lives in StarterForest. One next key. Do not gather for them.
	# Wave 19: name Explore only when Ace F actually Explores (unbound).
	if _in_icon_submenu() or _menu_open():
		return "▸ ESC closes"
	if _sim_paused():
		return "▸ [F] Play"
	# Short 🌱 with a payable 🌱 trade: walk that trade, not baskets.
	if _trade_walk_ok("🌱"):
		var walk := _supply_walk_line("🌱")
		if walk != "":
			return walk
	# Gather costs 🧺 — restock before the walk spends the last basket.
	if _basket_short():
		var basket := _basket_pay_line()
		if basket != "":
			return basket
	var have := int(_sprout_have())
	var need := "🌱 %d/5" % have
	var cross := _cross_to("StarterForest")
	if cross != "":
		return cross + " for " + need
	var wearing := str(ToolConfig.get_current_frame())
	# Druid Superpose is the even-coin on 💀🌱. Ace never Superposes.
	if wearing != ToolConfig.FRAME_ACE and wearing != ToolConfig.FRAME_DRUID:
		return "▸ [8] Ace for " + need
	var want := _sprout_plot_key()
	var focused := _focused_col()
	var token := ";" if want == ";" else want.to_upper()
	var want_col := PLOT_HOMEROW.find(token) if want != "" else -1
	# Wave 23 literalist: banner [F] Explore vs Ace [F] Fast-Fwd on a
	# marked plot. Only name Explore when Ace F actually Explores.
	if want != "" and focused != want_col:
		return "▸ [%s] for %s" % [want, need]
	if not _plot_bound(focused):
		if ace_f_would_explore():
			return "▸ [F] Explore for " + need
		if want != "":
			return "▸ [%s] for %s" % [want, need]
		return "▸ pick a sleeping 🌱 plot"
	if not _plot_measured(focused):
		# 💀🌱 — Superpose evens the coin. Name Druid from Ace only while
		# the Bloch is still north-heavy and not already on the equator
		# (wave 25 hat-toggle: Superpose then Ace then Druid again).
		if _biased_against_sprout(focused) and not _already_superposed(focused):
			if wearing != ToolConfig.FRAME_DRUID:
				return "▸ [0] Druid for " + need
			return "▸ [E] Superpose for " + need
		if wearing == ToolConfig.FRAME_DRUID:
			return "▸ [8] Ace for " + need
		return "▸ [R] Strike for " + need
	# Wave 23: J is 💀🌱. A 💀 strike is not a 🌱 gather. One next key.
	var got := _measured_glyph(focused)
	if "🌱" in got:
		return "▸ [Q] gather 🌱 (%d/5)" % have
	if got != "":
		return "▸ [Q] take %s" % got
	return "▸ [Q] gather"


static func _icon_known(atom: String) -> bool:
	var farm = _active_farm()
	if farm == null or not ("known_icons" in farm):
		return false
	var want := atom.strip_edges()
	if want == "":
		return false
	for pair in farm.known_icons:
		if pair is Dictionary:
			if str(pair.get("north", "")) == want or str(pair.get("south", "")) == want:
				return true
		elif pair is Array:
			for g in pair:
				if str(g) == want:
					return true
		elif want in str(pair):
			return true
	return false


static func _atom_in_biome(biome: String, atom: String) -> bool:
	return _register_plot_key(biome, atom) != ""


static func _register_plot_key(biome: String, atom: String) -> String:
	# RegisterMap is truth. Viz cache lags inject and scouts fog.
	var farm = _active_farm()
	if farm == null or farm.grid == null or not farm.grid.has_method("get_biome"):
		return ""
	var b = farm.grid.get_biome(biome)
	if b == null or b.get("quantum_computer") == null:
		return ""
	var qc = b.quantum_computer
	if qc == null or qc.register_map == null:
		return ""
	var want := atom.strip_edges()
	if want == "" or not qc.register_map.coordinates.has(want):
		return ""
	var qid := -1
	if qc.register_map.has_method("qubit"):
		qid = int(qc.register_map.qubit(want))
	else:
		qid = int(qc.register_map.coordinates[want].get("qubit", -1))
	if qid < 0:
		return ""
	return _col_key(qid)


static func _live_atom_plant_line() -> String:
	# First unfired in-lane flag whose story_flag_set prereqs are met and
	# whose remaining predicate is atom_in_biome — compiled from campaign
	# flags, not a second walk table. 🏭 must already be a known word.
	var qm := _quest_manager()
	var farm = _active_farm()
	if qm == null or farm == null or not qm.has_method("get_all_story_flags"):
		return ""
	if not ("story_flags_fired" in farm):
		return ""
	var fired: Dictionary = farm.story_flags_fired
	for flag in qm.get_all_story_flags():
		if not (flag is Dictionary):
			continue
		if str(flag.get("campaign", "demos")) != "demos":
			continue
		var fid := str(flag.get("id", ""))
		if fid == "" or fired.has(fid):
			continue
		var atom := ""
		var biome := ""
		var prereqs_met := true
		for pred in flag.get("predicates", []):
			if not (pred is Dictionary):
				continue
			var t := str(pred.get("type", ""))
			if t == "story_flag_set" and not fired.has(str(pred.get("id", ""))):
				prereqs_met = false
				break
			if t == "atom_in_biome":
				atom = str(pred.get("atom", "")).strip_edges()
				biome = str(pred.get("biome", "")).strip_edges()
		if not prereqs_met or atom == "" or biome == "":
			continue
		if _atom_in_biome(biome, atom):
			continue
		if not _icon_known(atom):
			return ""
		return _named_atom_plant_line(biome, atom)
	return ""


static func _icon_pick_line(atom: String) -> String:
	var inst = _instrument()
	if inst == null or not ("current_submenu_data" in inst):
		return "▸ [R] plant %s" % atom
	var data = inst.current_submenu_data
	if not (data is Dictionary):
		return "▸ [R] plant %s" % atom
	var actions = data.get("actions", {})
	if actions is Dictionary:
		for k in ["Q", "E", "R"]:
			if not actions.has(k):
				continue
			var act = actions[k]
			if not (act is Dictionary):
				continue
			var blob := str(act.get("label", ""))
			var icon = act.get("icon", {})
			if icon is Dictionary:
				blob += str(icon.get("north", "")) + str(icon.get("south", ""))
			if atom in blob:
				return "▸ [%s] plant %s" % [k, atom]
	if int(data.get("max_pages", 1)) > 1:
		return "▸ [F] page for %s" % atom
	return "▸ [R] plant %s" % atom


static func _named_atom_plant_line(biome: String, atom: String) -> String:
	var cross := _cross_to(biome)
	if cross != "":
		return cross
	if _in_icon_submenu():
		return _icon_pick_line(atom)
	if _menu_open():
		return "▸ ESC closes"
	var slot := _empty_plot_key() if _empty_plot_exists(biome) else _blank_plant_key(biome)
	if slot == "":
		slot = _non_mill_plot_key(biome)
	if slot == "":
		slot = "G"
	if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_ICON:
		return "▸ [5] Icon then plant %s" % atom
	if _live_plot_key() != slot:
		return "▸ [%s] then plant %s" % [slot, atom]
	return "▸ [R] plant %s" % atom


static func _plot_axis_pair(biome: String, key: String) -> String:
	var farm = _active_farm()
	if farm == null or farm.grid == null or not farm.grid.has_method("get_biome"):
		return ""
	var b = farm.grid.get_biome(biome)
	if b == null:
		return ""
	var cache = b.viz_cache if "viz_cache" in b else null
	if cache == null or not cache.has_method("get_axis"):
		return ""
	var keys := "GHJKL;"
	var col := keys.find(key) if key == ";" else keys.find(key.to_upper())
	if col < 0:
		return ""
	var axis: Dictionary = cache.get_axis(col)
	return str(axis.get("north", "")) + str(axis.get("south", ""))


static func _fog_plant_key(biome: String) -> String:
	var farm = _active_farm()
	if farm == null or farm.grid == null or not farm.grid.has_method("get_plot_biome_assignments"):
		return ""
	var revealed: Dictionary = {}
	if "revealed_plots" in farm:
		for rp in farm.revealed_plots:
			revealed[rp] = true
	var cols: Array = []
	var assignments: Dictionary = farm.grid.get_plot_biome_assignments()
	for pos in assignments.keys():
		if str(assignments[pos]) != biome:
			continue
		if revealed.has(pos):
			continue
		var col := int(pos.x) if pos is Vector2i else int(pos.x)
		cols.append(col)
	cols.sort()
	if cols.is_empty():
		return ""
	return _col_key(int(cols[0]))


static func _blank_plant_key(biome: String) -> String:
	# Village G/J/L on the timber wall: blank axis or unbound. Skip mill ⚙/🏭.
	# Bound leftover-axis fog is Track first — that is not a plant seat.
	var farm = _active_farm()
	if farm == null or farm.grid == null or not farm.grid.has_method("get_biome"):
		return ""
	var b = farm.grid.get_biome(biome)
	if b == null or b.quantum_computer == null or b.quantum_computer.register_map == null:
		return ""
	if not farm.grid.has_method("get_plot_biome_assignments"):
		return ""
	var rm = b.quantum_computer.register_map
	var pool = farm.terminal_pool if "terminal_pool" in farm else null
	var assignments: Dictionary = farm.grid.get_plot_biome_assignments()
	var blanks: Array = []
	var unbounds: Array = []
	for pos in assignments.keys():
		if str(assignments[pos]) != biome:
			continue
		var col := int(pos.x) if pos is Vector2i else int(pos.x)
		if col < 0:
			continue
		var ax: Dictionary = rm.axis(col) if rm.has_method("axis") else {}
		var north := str(ax.get("north", ""))
		var south := str(ax.get("south", ""))
		var pair := north + south
		if "⚙" in pair or "🏭" in pair:
			continue
		var bound := false
		if pool != null and pool.has_method("is_register_bound"):
			bound = bool(pool.is_register_bound(col, biome))
		if north == "" or south == "":
			blanks.append(col)
		elif not bound:
			unbounds.append(col)
	blanks.sort()
	unbounds.sort()
	if not blanks.is_empty():
		return _col_key(int(blanks[0]))
	if not unbounds.is_empty():
		return _col_key(int(unbounds[0]))
	return ""


static func _non_mill_plot_key(biome: String) -> String:
	var farm = _active_farm()
	if farm == null or farm.grid == null or not farm.grid.has_method("get_biome"):
		return "G"
	var b = farm.grid.get_biome(biome)
	if b == null:
		return "G"
	var nq := 0
	if b.quantum_computer != null and b.quantum_computer.register_map != null:
		nq = int(b.quantum_computer.register_map.num_qubits)
	var cache = b.viz_cache if "viz_cache" in b else null
	var revealed: Dictionary = {}
	if "revealed_plots" in farm:
		for rp in farm.revealed_plots:
			revealed[rp] = true
	if not farm.grid.has_method("get_plot_biome_assignments"):
		return "K"
	var assignments: Dictionary = farm.grid.get_plot_biome_assignments()
	var empty_key := ""
	for pos in assignments.keys():
		if str(assignments[pos]) != biome:
			continue
		var col := int(pos.x) if pos is Vector2i else int(pos.x)
		if col < 0 or col >= nq:
			continue
		if not revealed.has(pos):
			continue
		var pair := ""
		if cache != null and cache.has_method("get_axis"):
			var axis: Dictionary = cache.get_axis(col)
			pair = str(axis.get("north", "")) + str(axis.get("south", ""))
		if "⚙" in pair or "🏭" in pair:
			continue
		var k := _col_key(col)
		if k == "":
			continue
		if pair == "":
			if empty_key == "":
				empty_key = k
			continue
		if empty_key == "":
			return k
	if empty_key != "":
		return empty_key
	return "G"


static func _plant_walk_line() -> String:
	# Wave 11: "Icon hat (5)" named no bracketed key. Name [5], then [R].
	# Wave 18: name the empty-plot key; short 🌱 walks Forest, not Village Q.
	# lantern_wakes: a full Lanternfall ring is not an empty J. Name [Q] unseat.
	# Do not plant for them.
	if _sprout_short():
		return _sprout_gather_line()
	# The word they tried to plant needs 13 of its south pole (🪓 for 🪵/🪓,
	# 🌊 for 💧/🌊) — those come from a standing trade, not a plot.
	if not _in_icon_submenu() and _plant_south_short():
		var south_walk := _supply_walk_line(_plant_south_current())
		if south_walk != "":
			return south_walk
	if _in_icon_submenu() or _menu_open():
		if _in_icon_submenu():
			return "▸ [Q]/[E] pick a word (need 🌱×5 + south×13)"
		return "▸ ESC closes"
	var plant_biome := _plant_ask_biome(_banner_quest())
	if plant_biome != "":
		var cross := _cross_to(plant_biome)
		if cross != "":
			return cross
	var wearing := str(ToolConfig.get_current_frame())
	if wearing != ToolConfig.FRAME_ICON:
		if not _empty_plot_exists(plant_biome):
			return "▸ [5] Icon — [Q] unseats"
		return "▸ [5] Icon, [%s] empty plot, [R] opens picker" % _empty_plot_key()
	if not _empty_plot_exists(plant_biome):
		return "▸ [Q] unseats"
	return "▸ [%s] empty plot, [R] opens picker" % _empty_plot_key()


static func _berry_register():
	var farm = _active_farm()
	var bname := _active_biome_name()
	if farm == null or farm.grid == null or bname == "":
		return null
	if not farm.grid.has_method("get_biome"):
		return null
	var biome = farm.grid.get_biome(bname)
	if biome == null or biome.quantum_computer == null:
		return null
	return biome.quantum_computer.berry_register


static func _berry_tracking() -> bool:
	var reg = _berry_register()
	if reg == null or not reg.has_method("is_tracked"):
		return false
	var qid := _focused_col()
	if qid < 0:
		return false
	return bool(reg.is_tracked(qid))


static func _berry_ripe() -> bool:
	var reg = _berry_register()
	if reg == null or not reg.has_method("is_ripe"):
		return false
	var qid := _focused_col()
	if qid < 0:
		return false
	return bool(reg.is_ripe(qid))


static func _active_nq() -> int:
	var farm = _active_farm()
	var bname := _active_biome_name()
	if farm == null or farm.grid == null or bname == "":
		return 0
	var biome = farm.grid.get_biome(bname) if farm.grid.has_method("get_biome") else null
	if biome == null or biome.quantum_computer == null \
			or biome.quantum_computer.register_map == null:
		return 0
	return int(biome.quantum_computer.register_map.num_qubits)


static func _berry_qubit_live(col: int) -> bool:
	# Track walks a register qubit. Occupied leftover 🌹 has no probe;
	# _plot_bound mashed [G] forever. Empty plant seats cannot Track.
	return col >= 0 and col < _active_nq()


static func _living_berry_plot_key() -> String:
	var want := _berry_ask_biome(_banner_quest())
	if want == "":
		want = _active_biome_name()
	var rose := _glyph_plot_key("🌹", want, false)
	if rose != "":
		return rose
	var nq := _active_nq()
	if nq <= 0:
		return "G"
	return _col_key(0)


static func _berry_walk_line(q: Dictionary = {}) -> String:
	# first_breath live door: one next key. Do not dump F / = / R / X.
	# Do not incorporate for them. Unsigned berry still paints (like plant).
	if _in_icon_submenu() or _menu_open():
		return "▸ ESC closes"
	if q.is_empty():
		q = _banner_quest()
	var want := _berry_ask_biome(q)
	if want != "":
		# the_rite: GildedRot was culled to Chart later coasts. Cross is
		# empty off-spindle; mill Superpose on leftover 🔭 is the wrong
		# country. Chart (cull first if TYUIOP is full). Never cull Woodlot.
		if not _biome_unlocked(want):
			if _slots_full():
				return _cull_walk_line()
			var wearing_chart := str(ToolConfig.get_current_frame())
			if wearing_chart != ToolConfig.FRAME_CAPTAIN:
				return "▸ [7] Captain, then [R] Chart %s" % want
			return "▸ [R] Chart %s" % want
		var cross := _cross_to(want)
		if cross != "":
			return cross
	var wearing := str(ToolConfig.get_current_frame())
	# Live Track: Ace F ripens. Icon F would stop the loop. Do not
	# ping-pong [5] Icon / [8] Ace (10-key freeze). A keyless ripen
	# wait aborted grind (no_followable_key).
	if _berry_tracking() and not _berry_ripe():
		if wearing != ToolConfig.FRAME_ACE:
			return "▸ [8] Ace — loop ripens"
		if _sim_paused():
			return "▸ [F] Play"
		return "▸ [F] Fast-Fwd — loop ripens (~90s)"
	if wearing != ToolConfig.FRAME_ICON:
		return "▸ [5] Icon"
	# Leftover 🌹 is a live qubit with no probe. Naming [G] while G is
	# already focused mashed G (10-key freeze). Track does not need a
	# bound terminal.
	if not _berry_qubit_live(_focused_col()):
		var live := _living_berry_plot_key()
		if live == "" or live == "G" or live == "g":
			return "▸ [G] a living plot"
		var tok := ";" if live == ";" else live.to_upper()
		return "▸ [%s] a living plot" % tok
	if not _berry_tracking():
		return "▸ [F] Track"
	if _berry_ripe():
		return "▸ [R] Incorporate"
	if wearing != ToolConfig.FRAME_ACE:
		return "▸ [8] Ace — loop ripens"
	if _sim_paused():
		return "▸ [F] Play"
	return "▸ [F] Fast-Fwd — loop ripens (~90s)"


static func _eagle_have() -> float:
	var farm = _active_farm()
	if farm == null or not ("economy" in farm) or farm.economy == null:
		return 0.0
	if not farm.economy.has_method("get_resource"):
		return 0.0
	return float(farm.economy.get_resource("🦅"))


static func _eagle_short() -> bool:
	# lantern_door: empty/unreadable wallet never named the 🧺 supply walk.
	# No farm yet is not a wallet. Mute economy is 0 eagles, so short.
	var farm = _active_farm()
	if farm == null:
		return false
	return _eagle_have() < float(_chart_eagles())


## Chart / Add Biome price in 🦅 — the campaign spec's chart_cost.
static func _chart_eagles() -> int:
	return int(CampaignRuntime.chart_cost().get("🦅", 21))


# =============================================================================
# SUPPLY WALK — generated from the campaign resource table
# (CampaignRuntime.resources(): low_water, plots, standing trades). One next
# key, never a trade made for them. _basket_* below are the 🧺 instances.
# =============================================================================

## South pole of the word the player last tried to plant, noted by the input
## layer when a plant was refused for cost; cleared when a word takes root.
static var _plant_south_note: String = ""
static var _plant_south_farm: int = 0


static func note_plant_south(south: String) -> void:
	_plant_south_note = str(south).strip_edges()
	var farm = _active_farm()
	_plant_south_farm = farm.get_instance_id() if farm != null else 0


## The noted south pole, only for the farm it was noted on (a restart or load
## forgets it) and only while the banner is still a plant ask.
static func _plant_south_current() -> String:
	if _plant_south_note == "":
		return ""
	var farm = _active_farm()
	if farm == null or farm.get_instance_id() != _plant_south_farm:
		_plant_south_note = ""
		return ""
	return _plant_south_note


static func _wallet(emoji: String) -> float:
	var farm = _active_farm()
	if farm == null or not ("economy" in farm) or farm.economy == null:
		return 0.0
	if not farm.economy.has_method("get_resource"):
		return 0.0
	return float(farm.economy.get_resource(emoji))


## Ace Q gather price in 🧺 (flat; the action-cost table is the authority).
static func gather_price() -> int:
	var farm = _active_farm()
	if farm != null:
		var c: Dictionary = ActionCostRuntime.get_action_cost(farm, "pop", {})
		if c.has("🧺"):
			return maxi(1, int(round(float(c["🧺"]))))
	return 1


static func _trade_affordable(t: Dictionary) -> bool:
	var give := CampaignRuntime.trade_give(t)
	if give.is_empty():
		return false
	for g in give:
		if _wallet(str(g)) < float(give[g]):
			return false
	return true


## The standing trade the walk takes for `emoji`: the one on the board the
## player stands at when its ask is in hand, else the Village rescue. When
## that ask is itself short and has an affordable Village trade, walk THAT
## first (one level: 🧺 asks 👥, 👥 trades for 🌾). {} = no trade anywhere.
static func _supply_step(emoji: String) -> Dictionary:
	var here := _active_biome_name()
	var t: Dictionary = CampaignRuntime.trade_in(emoji, here) if here != "" else {}
	if t.is_empty() or not _trade_affordable(t):
		var rescue := CampaignRuntime.rescue_trade(emoji)
		if not rescue.is_empty():
			t = rescue
	if t.is_empty():
		var all := CampaignRuntime.supply_trades(emoji)
		if not all.is_empty():
			t = all[0]
	if t.is_empty() or _trade_affordable(t):
		return t
	var give := CampaignRuntime.trade_give(t)
	for g in give:
		if _wallet(str(g)) >= float(give[g]):
			continue
		var sub := CampaignRuntime.rescue_trade(str(g))
		if not sub.is_empty() and _trade_affordable(sub):
			return sub
	return t


## Short for a spend of `cost`×`emoji`: unaffordable, or — for a spend SMALLER
## than the resource's low-water reserve (gather: 1🧺 against 3) — a spend
## that would leave the wallet under the reserve while the trade that
## restocks it is in hand (restock BEFORE bottoming out). One-shot spends as
## big as their reserve (13🪓, 21🦅, 5🌱) switch only when unaffordable: a
## reserve the size of the spend would send the player round in circles.
## No farm yet is not a wallet; a mute economy reads 0, so short.
static func _supply_short(emoji: String, cost: int) -> bool:
	var farm = _active_farm()
	if farm == null:
		return false
	var have := _wallet(emoji)
	if have < float(cost):
		return true
	var lw := CampaignRuntime.low_water(emoji)
	if cost >= lw or have - float(cost) >= float(lw):
		return false
	var t := _supply_step(emoji)
	return not t.is_empty() and str(t.get("emoji", "")) == emoji and _trade_affordable(t)


static func _rail_key_for(biome_name: String) -> String:
	var abm := _active_biome_manager()
	if abm == null or biome_name == "" or str(abm.get_active_biome()) == biome_name:
		return ""
	var slot := int(abm.get_slot_for_biome(biome_name))
	return str(abm.get_slot_key(slot)).to_upper() if slot >= 0 else ""


static func _board_open() -> bool:
	var ml := Engine.get_main_loop()
	if not (ml is SceneTree):
		return false
	var shells := (ml as SceneTree).get_nodes_in_group("player_shell")
	if shells.is_empty():
		return false
	var shell = shells[0]
	if shell == null or not ("overlay_manager" in shell) or shell.overlay_manager == null:
		return false
	var om = shell.overlay_manager
	return om.has_method("is_event_home_open") and bool(om.is_event_home_open("board"))


## The whole route, live rail key included:
##   "Village [Y] → [C] board → Market → the 🧺 trade (👥×6 → 🧺×4)"
static func supply_route_line(emoji: String) -> String:
	var t := _supply_step(emoji)
	if t.is_empty():
		return CampaignRuntime.supply_route_words(emoji)
	return CampaignRuntime.supply_route_words(str(t.get("emoji", emoji)),
			_rail_key_for(str(t.get("biome", ""))), t)


## The supply walk's ONE next key (banner line). "" when the table has no
## trade for `emoji` (callers keep their own gather walk).
static func _supply_walk_line(emoji: String) -> String:
	var t := _supply_step(emoji)
	if t.is_empty():
		return ""
	var e := str(t.get("emoji", emoji))
	var biome := str(t.get("biome", ""))
	var tag := "the %s trade (%s)" % [e, CampaignRuntime.trade_words(t)]
	if _board_open():
		if _active_biome_name() == biome:
			var board = _quest_board()
			if board != null and board.has_method("supply_walk_cue"):
				var cue := str(board.supply_walk_cue(e)).strip_edges()
				if cue != "":
					return cue
		return "▸ ESC closes"
	if _in_icon_submenu() or _menu_open():
		return "▸ ESC closes"
	var cross := _cross_to(biome)
	if cross != "":
		return "%s — %s" % [cross, tag]
	if _active_biome_name() != biome:
		return "▸ " + CampaignRuntime.supply_route_words(e, "", t)
	return "▸ [C] opens the board — %s" % tag


static func _first_key(line: String) -> String:
	var a := line.find("[")
	var b := line.find("]", a + 1)
	if a < 0 or b <= a + 1:
		return ""
	return line.substr(a + 1, b - a - 1)


## Spotlight twin of _supply_walk_line: {key, biome}.
static func _supply_target(emoji: String) -> Dictionary:
	var t := _supply_step(emoji)
	if t.is_empty():
		return {}
	return {"key": _first_key(_supply_walk_line(emoji)), "biome": str(t.get("biome", ""))}


## Toast / detail words for a starved spend: the whole route from the table.
## strict = only when the spend is unaffordable — a refusal for some OTHER
## reason keeps its own true reason (a low wallet is not why Strike failed).
static func supply_refusal(emoji: String, cost: int, strict: bool = false) -> String:
	if _active_farm() == null:
		return ""
	var have := int(_wallet(emoji))
	var out := have < cost
	if strict and not out:
		return ""
	if not out and not _supply_short(emoji, cost):
		return ""
	var route := supply_route_line(emoji)
	if out:
		if route == "":
			return "needs %s" % emoji
		return "needs %s (you hold %d) — %s" % [emoji, have, route]
	return "%s low (%d left) — restock: %s" % [emoji, have, route]


## Which resource the banner is supply-walking right now ("" = none).
static func _supply_need_now(q: Dictionary) -> String:
	if q.is_empty():
		return ""
	if _is_plant_ask(q):
		if _sprout_short():
			return _need_or_basket("🌱")
		if _plant_south_short():
			return _plant_south_current()
		return ""
	if _is_discover_ask(q) and _eagle_short():
		return _need_or_basket("🦅")
	return ""


## Which resource to walk when `emoji` is short. Playtest 2026-10-29: out of
## 🦅, the banner sent the player for 🧺 — it always walked baskets (the
## gather fee) even when the missing resource has its OWN market trade the
## player can pay for (🦅: 10🌾 → 7🦅 at the Village). The direct trade is the
## honest route; baskets are named only when there is no payable trade for
## `emoji` and the gather that would mint it can't be paid. "" = callers keep
## their own gather walk.
static func _need_or_basket(emoji: String) -> String:
	if _trade_walk_ok(emoji):
		return emoji
	return "🧺" if _basket_short() else ""


## True when the trade table has a trade that pays `emoji` itself and the
## player can afford it right now.
static func _trade_walk_ok(emoji: String) -> bool:
	var t := _supply_step(emoji)
	return not t.is_empty() and str(t.get("emoji", "")) == emoji and _trade_affordable(t)


## True while a live quest is asking for `emoji` — the banner's quest or any
## accepted one. Owner ruling 2026-10-29: the 🌱 🔥 🔨 🪓 🌊 🦅 rescue trades
## stand on the board only then ("not before, and not after"). 🦅: a Chart
## ask (_is_discover_ask). 🌱: a plant ask (planting costs 5🌱). 🔥: a
## Superpose ask (gate hadamard). Pole costs: an objective that plants the
## north pole whose south is `emoji` (atom_in_biome 💨 → asks 🔨), or a plant
## the player just tried that needed it (_plant_south_current).
static func quest_requests_resource(emoji: String) -> bool:
	if emoji == "":
		return false
	if _plant_south_current() == emoji:
		return true
	var north := CampaignRuntime.plant_north_for(emoji)
	for q in _live_quests():
		if emoji == "🦅" and _is_discover_ask(q):
			return true
		if emoji == "🌱" and _is_plant_ask(q):
			return true
		if emoji == "🔥" and _quest_asks_gate(q, "hadamard"):
			return true
		if north != "" and _quest_plants_atom(q, north):
			return true
	return false


## The banner's quest plus every accepted quest (deduplicated by id).
static func _live_quests() -> Array:
	var out: Array = []
	var seen := {}
	var banner := _banner_quest()
	if not banner.is_empty():
		out.append(banner)
		seen[banner.get("id", -1)] = true
	var qm := _quest_manager()
	if qm != null and "active_quests" in qm:
		for q in qm.active_quests.values():
			if q is Dictionary and not seen.has(q.get("id", -1)):
				out.append(q)
	return out


static func _quest_asks_gate(q: Dictionary, gate: String) -> bool:
	for key in ["state_predicates", "predicates"]:
		for pred in q.get(key, []):
			if pred is Dictionary and str(pred.get("type", "")) == "gate_sequence_contains" \
					and str(pred.get("gate", "")).to_lower() == gate:
				return true
	return false


static func _quest_plants_atom(q: Dictionary, atom: String) -> bool:
	for key in ["state_predicates", "predicates"]:
		for pred in q.get(key, []):
			if pred is Dictionary and str(pred.get("type", "")) == "atom_in_biome" \
					and str(pred.get("atom", "")) == atom:
				return true
	return false


static func _plant_south_short() -> bool:
	var south := _plant_south_current()
	if south == "" or CampaignRuntime.supply_trades(south).is_empty():
		return false
	return _supply_short(south, EconomyConstants.ICON_INJECTION_SOUTH_COST)


static func _supply_cost(emoji: String) -> int:
	if emoji == "🧺":
		return gather_price()
	if emoji == "🦅":
		return _chart_eagles()
	if emoji == "🌱":
		return 5
	if emoji == _plant_south_current():
		return EconomyConstants.ICON_INJECTION_SOUTH_COST
	return 1


# ── 🧺: gather (Ace Q) pays a flat basket. The Village has no 🧺 register;
# its board's standing 🧺 trade is the restock and the rescue. ──

static func _basket_short() -> bool:
	return _supply_short("🧺", gather_price())


static func _eagle_gather_target() -> Dictionary:
	# Same walk as _eagle_gather_line: Forest rail, [8] Ace, then [R]/[Q].
	# Spotlight must name the chip, not Forest with a blank key.
	if _trade_walk_ok("🦅"):
		var tgt := _supply_target("🦅")
		if not tgt.is_empty():
			return tgt
	# lantern_door: 🧺 short — Q gather still named Strike. Strike does not pay.
	if _basket_short():
		return _basket_pay_target()
	var forest := "StarterForest"
	var ace := _hat_key_for_frame("ace")
	if _in_icon_submenu() or _menu_open():
		return {"key": "", "hat": ace, "biome": forest}
	if _sim_paused():
		return {"key": "F", "hat": ace, "biome": forest}
	var abm := _active_biome_manager()
	if abm != null and str(abm.get_active_biome()) != forest:
		var slot := int(abm.get_slot_for_biome(forest))
		var rail := str(abm.get_slot_key(slot)).to_upper() if slot >= 0 else ""
		return {"key": rail, "hat": ace, "biome": forest}
	if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_ACE:
		return {"key": ace, "hat": ace, "biome": forest}
	var want := _glyph_plot_key("🦅")
	var focused := _focused_col()
	var token := ";" if want == ";" else want.to_upper()
	var want_col := PLOT_HOMEROW.find(token) if want != "" else -1
	if want != "" and focused != want_col:
		return {"key": token, "hat": ace, "biome": forest}
	# lantern_door: after Strike, is_bound drops and Ace F named Explore.
	# The one next key stays [Q] until the eagle lands.
	if _plot_measured(focused):
		return {"key": "Q", "hat": ace, "biome": forest}
	if not _plot_bound(focused):
		if ace_f_would_explore():
			return {"key": "F", "hat": ace, "biome": forest}
		if want != "":
			return {"key": token, "hat": ace, "biome": forest}
		return {"key": "", "hat": ace, "biome": forest}
	return {"key": "R", "hat": ace, "biome": forest}


static func _basket_pay_target() -> Dictionary:
	return _supply_target("🧺")


static func _eagle_gather_line() -> String:
	# Wave 25 earnest: Captain R refused 21🦅 with 0 on hand. Same walk as
	# sprouts: Forest, Ace, the 🦅 plot (H is 🦅🐇). Do not discover for them.
	if _in_icon_submenu() or _menu_open():
		return "▸ ESC closes"
	if _sim_paused():
		return "▸ [F] Play"
	# Short 🦅 with a payable 🦅 trade: walk that trade, not baskets.
	if _trade_walk_ok("🦅"):
		var walk := _supply_walk_line("🦅")
		if walk != "":
			return walk
	# lantern_door: 🧺 0, banner still named Strike. Strike does not mint 🧺.
	if _basket_short():
		return _basket_pay_line()
	var have := int(_eagle_have())
	var need := "🦅 %d/21" % have
	var cross := _cross_to("StarterForest")
	if cross != "":
		return cross + " for " + need
	var wearing := str(ToolConfig.get_current_frame())
	if wearing != ToolConfig.FRAME_ACE:
		return "▸ [8] Ace for " + need
	var want := _glyph_plot_key("🦅")
	var focused := _focused_col()
	var token := ";" if want == ";" else want.to_upper()
	var want_col := PLOT_HOMEROW.find(token) if want != "" else -1
	if want != "" and focused != want_col:
		return "▸ [%s] for %s" % [want, need]
	# lantern_door: after Strike, is_bound drops. Banner named [F] Explore;
	# F cleared the measure with no 🦅. Name [Q] until the eagle lands.
	if _plot_measured(focused):
		var got := _measured_glyph(focused)
		if "🦅" in got:
			return "▸ [Q] gather 🦅 (%d/21)" % have
		if got != "":
			return "▸ [Q] take %s" % got
		return "▸ [Q] gather"
	if not _plot_bound(focused):
		if ace_f_would_explore():
			return "▸ [F] Explore for " + need
		if want != "":
			return "▸ [%s] for %s" % [want, need]
		return "▸ pick a sleeping 🦅 plot"
	return "▸ [R] Strike for " + need


static func _basket_pay_line() -> String:
	# 🧺 supply walk. Strike costs 👥 and does not mint 🧺. One next key.
	return _supply_walk_line("🧺")


static func _named_discover_target() -> String:
	# Live Chart ask that is not yet on the spindle. lantern_door wants
	# Lanternfall via biome_evolving; the_chain_tested via biome_state_gte
	# after the coast was culled. Do not discover for them.
	var q := _banner_quest()
	if q.is_empty() or not _is_discover_ask(q):
		return ""
	for pred in q.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		var t := str(pred.get("type", ""))
		if t != "biome_evolving" and t != "biome_state_gte":
			continue
		var b := str(pred.get("biome", "")).strip_edges()
		if b != "" and not _biome_unlocked(b):
			return b
	return ""


static func _chart_target_biome() -> String:
	# The biome Captain R will CHART (open story door, not on the spindle).
	# Farm.chart_target is the one authority — chip, refusal and banner agree.
	var farm = _active_farm()
	if farm == null or not farm.has_method("chart_target_biome"):
		return ""
	return str(farm.chart_target_biome()).strip_edges()


static func _discover_walk_line() -> String:
	# Captain R charts the open door's biome (deterministic, 🦅×21); with no
	# open door it is the random Add Biome. Hint F=compass was a lie (Captain
	# E is Compass, F is Play). Gather 🦅 first. Do not chart for them.
	# lantern_door: slots full made ▸ still [R] with no named cull.
	# lantern_door: unreadable wallet is eagle-short — fail toward the gather.
	if _eagle_short():
		return _eagle_gather_line()
	var q := _banner_quest()
	# Unsigned leftover (The Bridge Holds) signs on Arc. Overlay ESC
	# ping-ponged grind X/I/ESC and never Accepted.
	if str(q.get("status", "")) == Quest.STATUS_STORY:
		return _waiting_arc_line()
	if _in_icon_submenu() or _menu_open():
		return "▸ ESC closes"
	if _slots_full():
		return _cull_walk_line()
	var chart := _chart_target_biome()
	var coast := chart if chart != "" else _named_discover_target()
	var wearing := str(ToolConfig.get_current_frame())
	if chart != "":
		if wearing != ToolConfig.FRAME_CAPTAIN:
			return "▸ [7] Captain, then [R] Chart %s" % chart
		return "▸ [R] Chart %s" % chart
	if wearing != ToolConfig.FRAME_CAPTAIN:
		if coast != "":
			return "▸ [7] Captain, then [R] Add Biome for %s" % coast
		return "▸ [7] Captain, then [R] Add Biome"
	if coast != "":
		return "▸ [R] Add Biome — %s" % coast
	return "▸ [R] Add Biome"


static func _teaching_walk_line() -> String:
	# lantern_teaching: one next key. Unsigned Arc accept; rail; [0] Druid;
	# [E] Superpose until 🪔 55%; then [C] claim. Do not dump the paragraph.
	var q := _banner_quest()
	if str(q.get("status", "")) == Quest.STATUS_STORY:
		if _menu_open():
			return "▸ [R] Accept"
		return "▸ [X] Arc"
	if str(q.get("status", "")) == "ready":
		return _claim_walk_line(q)
	if _in_icon_submenu() or _menu_open():
		return "▸ ESC closes"
	var cross := _cross_to("Lanternfall")
	if cross != "":
		return cross
	if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_DRUID:
		return "▸ [0] Druid"
	var want := _glyph_plot_key("🪔")
	var focused := _focused_col()
	var token := ";" if want == ";" else want.to_upper()
	var want_col := PLOT_HOMEROW.find(token) if want != "" else -1
	if want != "" and focused != want_col:
		return "▸ [%s] the beacon" % token
	return "▸ [E] Superpose"


static func _teaching_target() -> Dictionary:
	# Same walk as _teaching_walk_line. Spotlight names one chip.
	var q := _banner_quest()
	var druid := _hat_key_for_frame("druid")
	var coast := "Lanternfall"
	if str(q.get("status", "")) == Quest.STATUS_STORY:
		if _menu_open():
			return {"key": "R", "hat": druid, "biome": ""}
		return {"key": "X", "hat": druid, "biome": ""}
	if str(q.get("status", "")) == "ready":
		return {"key": "C", "hat": druid, "biome": coast}
	if _in_icon_submenu() or _menu_open():
		return {"key": "", "hat": druid, "biome": coast}
	var abm := _active_biome_manager()
	if abm != null and str(abm.get_active_biome()) != coast:
		var slot := int(abm.get_slot_for_biome(coast))
		var rail := str(abm.get_slot_key(slot)).to_upper() if slot >= 0 else ""
		return {"key": rail, "hat": druid, "biome": coast}
	if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_DRUID:
		return {"key": druid, "hat": druid, "biome": coast}
	var want := _glyph_plot_key("🪔")
	var focused := _focused_col()
	var token := ";" if want == ";" else want.to_upper()
	var want_col := PLOT_HOMEROW.find(token) if want != "" else -1
	if want != "" and focused != want_col:
		return {"key": token, "hat": druid, "biome": coast}
	return {"key": "E", "hat": druid, "biome": coast}


static func teaching_wrong_hat_refusal() -> String:
	# Ace/Icon R and E are not the lamp. Name [0] Druid. Do not excite for them.
	var q := _banner_quest()
	if q.is_empty() or not _is_teaching_ask(q):
		return ""
	if str(q.get("status", "")) == Quest.STATUS_STORY:
		return ""
	if str(q.get("status", "")) == "ready":
		return ""
	if str(ToolConfig.get_current_frame()) == ToolConfig.FRAME_DRUID:
		return ""
	var rest := _teaching_walk_line().replace("▸ ", "").strip_edges()
	if rest == "" or rest == "ESC closes":
		return "The Teaching holds the lamp — [0] Druid"
	return "The Teaching holds the lamp — %s" % rest


static func _slots_full() -> bool:
	var abm := _active_biome_manager()
	if abm == null or not abm.has_method("has_open_biome_slot"):
		return false
	return not bool(abm.has_open_biome_slot())


static func _named_cull_target() -> String:
	var farm = _active_farm()
	if farm == null or not farm.has_method("named_cull_target"):
		return ""
	var gate = farm.named_cull_target()
	if not (gate is Dictionary) or not bool(gate.get("ok", false)):
		return ""
	return str(gate.get("biome_name", "")).strip_edges()


static func _cull_walk_line() -> String:
	# One next key. Name the cull target. Do not cull for them.
	# Captain Q is Cull; F confirm stays on the destructive chord.
	var want := _named_cull_target()
	if want == "Woodlot":
		var plant := _live_atom_plant_line()
		if plant != "":
			return plant
		# Demos 40/40: leftover discover mill named keep Woodlot with no
		# followable key. Unsigned Arc is the live catalog. Never cull Woodlot.
		# Menu-open ESC here ping-ponged grind X/I/ESC and never Accepted.
		var arc := _waiting_arc_line()
		if arc != "":
			return arc
		# island_free / Demos 40/40: leftover OPEN Arc rows are fired flags.
		# Keep Woodlot (never cull). An empty board last-resort [C]
		# ping-ponged grind C/ESC and never named a door.
		var board := _unsigned_board_offer()
		if not board.is_empty():
			return _board_walk_line(board)
		if _in_icon_submenu() or _menu_open():
			return "▸ ESC closes"
		return "▸ slots full — keep Woodlot"
	if _cull_confirm_pending():
		if want == "":
			return "▸ [F] confirms cull"
		return "▸ [F] confirms cull %s" % want
	if _in_icon_submenu() or _menu_open():
		return "▸ ESC closes"
	if want == "":
		return "▸ slots full — no named cull"
	var wearing := str(ToolConfig.get_current_frame())
	if wearing != ToolConfig.FRAME_CAPTAIN:
		return "▸ [7] Captain — cull %s" % want
	var cross := _cross_to(want)
	if cross != "":
		return cross
	return "▸ [Q] culls %s" % want


static func eagle_short_refusal() -> String:
	# Captain-R Chart / Add Biome while 🦅 short. Name the gather walk, not a dead [R].
	# Only when 🦅 really is short — a full spindle keeps its own (cull) reason.
	# Baskets are named only when the gather itself is unaffordable.
	if not _eagle_short():
		return ""
	# A payable 🦅 trade is the route — not the 🧺 that gathering would cost.
	if _trade_walk_ok("🦅"):
		var direct := supply_refusal("🦅", _chart_eagles())
		if direct != "":
			return direct
	var basket := supply_refusal("🧺", gather_price(), true)
	if basket != "":
		return basket
	var rest := _eagle_gather_line().replace("▸ ", "").strip_edges()
	var need := "needs %d🦅" % _chart_eagles()
	if rest == "" or rest == "ESC closes":
		return need
	return "%s — %s" % [need, rest]


static func basket_short_refusal() -> String:
	# Banner-side: unaffordable OR under the 🧺 reserve. Names the trade walk.
	return supply_refusal("🧺", gather_price())


static func slots_full_refusal() -> String:
	# Captain-R Chart / Add Biome when the spindle is full. Name the cull, not a dead [R].
	var rest := _cull_walk_line().replace("▸ ", "").strip_edges()
	if rest == "" or rest == "ESC closes":
		return "Biome slots full"
	return "slots full — %s" % rest


static func plant_full_refusal() -> String:
	# lantern_wakes: Icon R Track-first on a full Lanternfall ring. Name [Q]
	# unseat, then plant. Do not skip to Middle Cannot Hold.
	var q := _banner_quest()
	if q.is_empty() or not _is_plant_ask(q):
		return ""
	if _sprout_short():
		return ""
	if _empty_plot_exists(_plant_ask_biome(q)):
		return ""
	var rest := _plant_walk_line().replace("▸ ", "").strip_edges()
	if rest == "" or rest == "ESC closes":
		return "ring full — [Q] unseats"
	return rest


static func _quest_board():
	var ml := Engine.get_main_loop()
	if not (ml is SceneTree):
		return null
	var nodes := (ml as SceneTree).get_nodes_in_group("quest_board")
	if nodes.is_empty():
		return null
	return nodes[0]


static func _board_ask_biome(q: Dictionary) -> String:
	var b := str(q.get("biome", "")).strip_edges()
	if b != "":
		return b
	# Millwright standing is a Village board. Wave 13 lost-lamb Refresh'd
	# Demos stalls forever. Do not guess a biome for tutorial goods.
	if str(q.get("category", "")) == "ARC" \
			and "Millwright" in str(q.get("faction", "")):
		return "Village"
	return ""


static func _claim_walk_line(q: Dictionary) -> String:
	if not _menu_open():
		return "▸ [C] then [R] Claim"
	var board = _quest_board()
	if board != null and board.has_method("claim_walk_cue"):
		var cue := str(board.claim_walk_cue(q)).strip_edges()
		if cue != "":
			return cue
	return "▸ [U] then [R] Claim"


static func _board_walk_line(q: Dictionary) -> String:
	# Village first (when that's the stall's country), then [C]. Board open
	# on the wrong biome: ESC only — Y is Market, not Village, while C is up.
	var want := _board_ask_biome(q)
	if want != "":
		var abm := _active_biome_manager()
		if abm != null and str(abm.get_active_biome()) != want:
			if _menu_open():
				return "▸ ESC closes"
			var slot := int(abm.get_slot_for_biome(want))
			if slot >= 0:
				var key := str(abm.get_slot_key(slot)).to_upper()
				if key != "":
					return "▸ [%s] crosses to %s" % [key, want]
	var board = _quest_board()
	if board != null and board.has_method("fill_shortfall_cue"):
		var short := str(board.fill_shortfall_cue(q)).strip_edges()
		if short != "":
			# Unpayable held fill (have*2 < need) names [Q] Abandon. That
			# chip fails the stall. Unsigned Arc / waiting door is the mill.
			if "Abandon" in short:
				if _menu_open():
					return "▸ ESC closes"
				var arc := _waiting_arc_line()
				if arc != "":
					return arc
			else:
				if _menu_open():
					return "▸ ESC closes"
				return short
	if not _menu_open():
		return "▸ [C] opens the board"
	if board != null and board.has_method("board_walk_cue"):
		var cue := str(board.board_walk_cue(q)).strip_edges()
		if cue != "":
			return cue
	return "▸ Market [Y] takes a delivery"


static func _next_unmarked_plot_key() -> String:
	var keys := "GHJKL;"
	var marked := {}
	var inst = _instrument()
	if inst != null and "checked_plots" in inst:
		for pos in inst.checked_plots:
			if pos is Vector2i:
				marked[int(pos.x)] = true
	for i in range(keys.length()):
		if not marked.has(i):
			var k := keys.substr(i, 1)
			if k == ";":
				return ";"
			return k.to_upper()
	return "G"


static func _overlay_manager():
	# Wave 5: find_child("OverlayManager") missed the runtime instance
	# (added in code, not a scene child). PlayerShell lives in group
	# "player_shell"; its overlay_manager knows the stack.
	var ml := Engine.get_main_loop()
	if not (ml is SceneTree):
		return null
	var tree := ml as SceneTree
	var shell: Node = null
	var shells := tree.get_nodes_in_group("player_shell")
	if not shells.is_empty():
		shell = shells[0]
	if shell == null and tree.root != null:
		shell = tree.root.get_node_or_null("/root/FarmView/PlayerShell")
	if shell == null or not ("overlay_manager" in shell):
		return null
	return shell.overlay_manager


static func _story_surface_open() -> bool:
	var om = _overlay_manager()
	if om == null or not om.has_method("is_event_home_open"):
		return false
	return bool(om.is_event_home_open("arc")) \
		or bool(om.is_event_home_open("story")) \
		or bool(om.is_event_home_open("self")) \
		or bool(om.is_event_home_open("guide"))


static func _menu_open() -> bool:
	var om = _overlay_manager()
	if om == null:
		return false
	if om.has_method("is_event_home_open") and bool(om.is_event_home_open("board")):
		return true
	return om.has_method("is_overlay_active") and bool(om.is_overlay_active())


static func _active_biome_manager() -> Node:
	var ml := Engine.get_main_loop()
	if not (ml is SceneTree):
		return null
	return (ml as SceneTree).root.get_node_or_null("/root/ActiveBiomeManager")


## Rank = earliest tutorial step, then earliest-act arc quest. Non-candidates
## (market contracts, uncategorized) rank unreachable.
static func _objective_rank(q: Dictionary, act_by_flag: Dictionary) -> int:
	var cat := str(q.get("category", ""))
	if cat == "TUTORIAL":
		return int(q.get("tutorial_step", 0))
	if cat == "ARC" and str(q.get("status", "")) != Quest.STATUS_STORY:
		# Active arc quests only — arc OFFERS need the Arc (X → Y) acknowledgement first.
		return 1000 + int(act_by_flag.get(str(q.get("source_flag", "")), 99))
	return 0x7FFFFFFF


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


static func _clip_banner(t: String) -> String:
	# Cut at a SENTENCE boundary when one exists, else a word boundary —
	# a mid-clause cut ("…or just…") read as a broken instruction to the
	# round-6 literalist. A complete short sentence beats a longer stump.
	if t.length() <= OBJECTIVE_MAX_CHARS:
		return t
	var head := t.substr(0, OBJECTIVE_MAX_CHARS + 30)
	var dot := head.rfind(". ", OBJECTIVE_MAX_CHARS + 29)
	if dot >= 20:
		return head.substr(0, dot + 1)
	var cut := t.substr(0, OBJECTIVE_MAX_CHARS - 1)
	var sp := cut.rfind(" ")
	return (cut.substr(0, sp) if sp >= 20 else cut).strip_edges() + "…"


static func _short_line(q: Dictionary) -> String:
	# Alias of the spine ask — kept so older tests that name this helper
	# still compose from one author.
	return IntroVoice.ask_line(q)


static func _shell() -> Node:
	var ml = Engine.get_main_loop()
	if not (ml is SceneTree):
		return null
	var shells: Array = (ml as SceneTree).get_nodes_in_group("player_shell")
	return shells[0] if not shells.is_empty() else null


static func _quest_manager() -> Node:
	var shell := _shell()
	if shell == null or not ("quest_manager" in shell):
		return null
	return shell.quest_manager


static func _act_by_flag(qm: Node) -> Dictionary:
	var out := {}
	if qm.has_method("get_all_story_flags"):
		for flag in qm.get_all_story_flags():
			if flag is Dictionary:
				out[str(flag.get("id", ""))] = int(flag.get("act", 0))
	return out


## The nearest unfired story beat's display name — the objective portal's
## "Next:" line (ActFilament). Frontier rule: the lowest-act unfired beat
## whose story_flag_set prereqs are ALL satisfied — a door the player can
## actually walk toward now, not a distant rumor. Data order breaks ties
## (same file-order tiebreak the Arc tab uses). "" when nothing is ahead
## (story finished) or before a farm exists. Read-only, same authority
## chain as objective_text() — never a second guess about the CURRENT
## objective, only about what stands behind it.
static func next_objective_title() -> String:
	var qm := _quest_manager()
	if qm == null or not qm.has_method("get_all_story_flags"):
		return ""
	var gsm = Engine.get_main_loop().root.get_node_or_null("GameStateManager") if Engine.get_main_loop() else null
	var farm = gsm.get_active_farm() if (gsm and gsm.has_method("get_active_farm")) else null
	if farm == null or not ("story_flags_fired" in farm):
		return ""
	var fired: Dictionary = farm.story_flags_fired
	# Lane discipline: "Next:" stays inside the campaigns the player has
	# ENTERED (a lane is entered once any of its flags has fired; demos is
	# home). Without this, a cross-lane beat whose prereqs happen to be
	# demos flags (e.g. a loom act-5 door off a demos act-3 flag) could
	# headline the HUD mid-Demos — accurate, but disorienting. The Arc tab
	# still shows the whole sky; only this one-liner goes in-lane, and it
	# falls back to the out-of-lane winner when no in-lane candidate exists.
	var entered: Dictionary = {"demos": true}
	for flag in qm.get_all_story_flags():
		if flag is Dictionary and fired.has(str(flag.get("id", ""))):
			entered[str(flag.get("campaign", "demos"))] = true
	var best_name := ""
	var best_act := 0x7FFFFFFF
	var fallback_name := ""
	var fallback_act := 0x7FFFFFFF
	for flag in qm.get_all_story_flags():
		if not (flag is Dictionary):
			continue
		var fid := str(flag.get("id", ""))
		if fid == "" or fired.has(fid):
			continue
		var prereqs_met := true
		for pred in flag.get("predicates", []):
			if pred is Dictionary and str(pred.get("type", "")) == "story_flag_set" \
					and not fired.has(str(pred.get("id", ""))):
				prereqs_met = false
				break
		if not prereqs_met:
			continue
		var act := int(flag.get("act", 99))
		if entered.has(str(flag.get("campaign", "demos"))):
			if act < best_act:
				best_act = act
				best_name = str(flag.get("display_name", fid))
		elif act < fallback_act:
			fallback_act = act
			fallback_name = str(flag.get("display_name", fid))
	return best_name if best_name != "" else fallback_name


# ============================================================================
# THE REDIRECT TOAST — what a locked key says instead of acting. Rate-limited
# to one toast per 3s no matter how fast keys are mashed (anti-gating law:
# speak and point, never flood).
# ============================================================================

const REDIRECT_COOLDOWN_MS := 3000
static var _last_redirect_ms: int = -REDIRECT_COOLDOWN_MS


static func redirect_locked(what: String = "") -> void:
	var now := Time.get_ticks_msec()
	if now - _last_redirect_ms < REDIRECT_COOLDOWN_MS:
		return
	_last_redirect_ms = now
	var obj := objective_text()
	if obj == "":
		obj = REDIRECT_FALLBACK
	# Name WHAT is locked when the caller knows (playtest 2026-08-24: five
	# straight reap refusals read as a BUG because "🔒 not yet" never said the
	# reap itself was the story-gated thing with a road that unlocks it). And
	# the lock toast is a DOOR: when the live objective is an offer awaiting
	# accept (or a quest gone ready), a body-tap opens the exact surface the
	# words point at (route ids resolve in PlayerShell).
	var route := ""
	var status := str(_best_objective().get("status", ""))
	if status == Quest.STATUS_STORY:
		route = "arc"
	elif status == "ready":
		var qm_r = _quest_manager()
		var best_r := _best_objective()
		route = "charge" if qm_r != null and qm_r.has_method("is_charge_hold") and bool(qm_r.is_charge_hold(best_r)) else "commitments"
	var line := ("🔒 %s unlocks further down Act 0 — now: %s" % [what, obj]) if what != "" \
			else ("🔒 not yet — now: %s" % obj)
	var shell := _shell()
	if shell != null and shell.has_method("show_hint"):
		shell.show_hint(line, 2, "", route)
