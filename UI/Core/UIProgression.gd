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

## Hat → the story flag that surfaces it ("" = always visible).
## Starter kit is Ace + Icon + Druid — exactly what Act-0 teaches.
## Spark is the open-regime (Lindblad) verb: useless inside the enclave, so it
## surfaces when the wet country opens.
const HAT_UNLOCK_FLAGS: Dictionary = {
	ToolConfig.FRAME_ACE: "",
	ToolConfig.FRAME_ICON: "",
	ToolConfig.FRAME_DRUID: "",
	# Any-of: loom_opens is the Act-0 superposition step's handoff (the road
	# forward); forest_listener is the legacy unlock — banked saves fired it
	# before the berry chapter moved to act 3, and losing a hat on load is the
	# exact anti-gating violation these tables must never commit.
	ToolConfig.FRAME_OPERATOR: ["loom_opens", "forest_listener"],
	ToolConfig.FRAME_MERCHANT: "village_stirs",
	# new_voices, not woodlot_door: Captain Add Biome is HOW you find the
	# Woodlot. Unlocking the hat on woodlot_door deadlocked w159 runner
	# (Find the Woodlot, [7] locked). woodlot_door stays as legacy any-of.
	ToolConfig.FRAME_CAPTAIN: ["new_voices", "woodlot_door"],
	ToolConfig.FRAME_SPARK: "edge_of_the_enclave",
}

## Menu id (MenuRegistry) → surfacing flag ("" = always; Array = ANY of —
## first entry is the live road, the rest are legacy flags banked saves hold).
const MENU_UNLOCK_FLAGS: Dictionary = {
	"play": "",
	"system": "",
	"controls": "",
	"quests": "",
	"atlas": ["first_harvest", "first_breath"],
	"biome_detail": ["loom_opens", "forest_evolving"],
	"inspector": "village_stirs",
	"map_meta": "village_stirs",
	"neighborhood_graph": "village_stirs",
}

## Menu id → minimum tutorial_step at which it surfaces (checked ALONGSIDE
## MENU_UNLOCK_FLAGS, not instead of — a menu needs both its flag AND its step
## satisfied). Only Quest Board carries an entry: nothing in tutorial step 0
## needs it, and step 1 ("contracts") is literally where it's taught.
## Missing from this table = no step gate, same fail-open law as everywhere
## else in this file.
const MENU_UNLOCK_STEP: Dictionary = {
	"quests": 1,
}


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
	return _unlocked(HAT_UNLOCK_FLAGS.get(frame_name, ""), flags)


## Viz overlay id → surfacing flag ("" = always). Same fail-open law: an
## overlay absent from the table is always drawn. Renderers check once per
## cache rebuild, not per frame.
const VIZ_UNLOCK_FLAGS: Dictionary = {
	# The gauge dial (clock-face ticks on stations) + edge fence glyphs stay
	# hidden until the compass lesson introduces the very idea of a local
	# convention — an unexplained rotating dial would read as noise (visual
	# affordance pairs with the teaching beat, not before it).
	"gauge_overlay": "turned_compass",
}


static func is_viz_visible(overlay_id: String) -> bool:
	var flags := _flags()
	if flags.is_empty() and _no_farm():
		return true
	return _unlocked(VIZ_UNLOCK_FLAGS.get(overlay_id, ""), flags)


static func is_menu_visible(menu_id: String) -> bool:
	var flags := _flags()
	if flags.is_empty() and _no_farm():
		return true
	if not _unlocked(MENU_UNLOCK_FLAGS.get(menu_id, ""), flags):
		return false
	if MENU_UNLOCK_STEP.has(menu_id):
		return current_tutorial_step() >= int(MENU_UNLOCK_STEP[menu_id])
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


## Which Act-0 tutorial step is currently live. Verb lessons auto-accept
## into active_quests; fill stalls stay in story_offers until Market Accept.
## Both pools are scanned so an unsigned mill cannot look like "Act 0 is over."
## Returns NO_TUTORIAL_SENTINEL only when no TUTORIAL quest is live in either.
static func current_tutorial_step() -> int:
	# w44: leftover Act-0 core_loop still in active_quests after Village
	# kept this at step 0 — C gated, Icon plant locked, Ace chips "-".
	# village_stirs means the funnel is over.
	if _flags().has("village_stirs"):
		return NO_TUTORIAL_SENTINEL
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
const OFFER_LINE := "📜 new offer — tap 📖 [X], then Arc [I]"
const REDIRECT_FALLBACK := "follow the Arc — tap 📖 [X], then [I]"


## One spelling per door — every surface that names a route composes from
## these. The ready-toast and the objective banner used to spell the claim
## route two ways ("C board" vs "Commitments (C → U)") and the older one sent
## players to the wrong screen; PlayerEventBridge preloads this script so the
## drift can't reopen. Voice rule: the click comes first, keys ride as
## bracketed accelerators — every action named here has a real hitbox
## (docs/MOUSE_PARITY_AUDIT.md: zero keyboard-only gaps), so copy that only
## says "press R" lies by omission to a mouse-and-trackpad player.
static func route_accept() -> String:
	return "tap 📖 [X], Arc [I], its row, then Accept [R]"


static func route_claim() -> String:
	return "tap 📋 [C], its row twice (Claim [R])"


## True when the live ask is a goods delivery (the mill, a market stall).
## Verb-lesson tutorials have no resource; they stay on the field.
static func _is_goods_ask(q: Dictionary) -> bool:
	if str(q.get("resource", "")).strip_edges() == "":
		return false
	return int(q.get("quantity", 0)) > 0


## The fill stall already in hand for this ask, or {}. Pickup is Market;
## a magically-held row must not count — only commitment_quests().
static func _held_fill_for_ask(q: Dictionary) -> Dictionary:
	var board = _quest_board()
	if board != null and board.has_method("held_fill_for"):
		var held = board.held_fill_for(str(q.get("faction", "")).strip_edges())
		if held is Dictionary and not held.is_empty():
			return held
	var qm := _quest_manager()
	if qm == null or not qm.has_method("commitment_quests"):
		return {}
	var want := str(q.get("faction", "")).strip_edges()
	var qid := int(q.get("id", -1))
	for hq in qm.commitment_quests():
		if not (hq is Dictionary):
			continue
		if str(hq.get("resource", "")).strip_edges() == "":
			continue
		if int(hq.get("quantity", 0)) <= 0:
			continue
		if qid >= 0 and int(hq.get("id", -2)) == qid:
			return hq
		if want != "" and str(hq.get("faction", "")) == want:
			return hq
	return {}


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
## "market" = pick up (Accept). "commitments" = deliver/claim a held stall.
## A Market chip must not open U with a contract the player never Accepted.
static func banner_home() -> String:
	# Wave 23: plant is a field verb. C does not plant. Use the same
	# ranker the banner speaks from so Forest and the home cannot dual.
	var best := _banner_quest()
	if best.is_empty():
		return ""
	if _is_plant_ask(best):
		return ""
	if _is_berry_ask(best):
		return ""
	if str(best.get("status", "")) == "ready":
		return "commitments"
	if _is_goods_ask(best) or _is_board_ask(best):
		if _held_fill_for_ask(best).is_empty():
			return "market"
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
	if str(q.get("status", "")) == Quest.STATUS_STORY and not _is_goods_ask(q):
		return ""
	if str(q.get("status", "")) == "ready":
		return "commitments"
	if _is_goods_ask(q) or _is_board_ask(q):
		if _held_fill_for_ask(q).is_empty():
			return "market"
		return "commitments"
	return "field"


## The live objective's how-line — tutorial_hint / hint. Empty when the
## banner has nothing more to say than objective_text() already does.
static func objective_detail() -> String:
	var best := _banner_quest()
	if best.is_empty():
		return ""
	# Wave 21 earnest: authored plant how-to (Icon + empty plot) outran the
	# 🌱 gather walk. One live beat. Do not plant for them.
	if _is_plant_ask(best) and _sprout_short():
		return ""
	# w68: authored lantern hint (🦅×21 from Forest) sat next to Arc Accept
	# / board [R]. Live walk is the only line.
	if _is_discover_ask(best) or _is_plant_ask(best) or lantern_well_live() \
			or hold_lamp_live() or teaching_claim_live() or lantern_bridge_live() \
			or knot_live() or _is_spinor_ask(best) or sixteen_live():
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


static func _unsigned_berry_offer() -> Dictionary:
	var qm := _quest_manager()
	if qm == null or not qm.has_method("get_story_offers"):
		return {}
	for q in qm.get_story_offers():
		if q is Dictionary and _is_berry_ask(q) and _preds_still_open(q):
			return q
	return {}


static func _unsigned_arc_waiting() -> bool:
	# w68: unsigned Find Lanternfall is a field walk, not Arc Accept.
	if not _unsigned_plant_offer().is_empty():
		return false
	if not _unsigned_discover_offer().is_empty():
		return false
	if lantern_well_live():
		return false
	var q := _best_objective()
	if q.is_empty():
		return not IntroVoice.live_door().is_empty()
	return str(q.get("status", "")) == Quest.STATUS_STORY


static func _banner_quest() -> Dictionary:
	var best := _best_objective()
	if not best.is_empty() and str(best.get("status", "")) != Quest.STATUS_STORY:
		return best
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
	var berry := _unsigned_berry_offer()
	if not berry.is_empty():
		return berry
	return best


## Last Ace-R well Strike result. Stays on the chip so the seat dump sees it.
static var last_lantern_strike := ""


static func objective_text() -> String:
	# w198: Story Guide [O] rebuilt the overlay while the HUD banner
	# queried the farm and killed headless Godot. Only the overlay stack
	# owns ESC — Icon submenu / board must not bury the farm door (w199
	# earnest: Ace Q/E/R/F with no named walk).
	if _overlay_stack_open():
		return "▸ ESC closes"
	# w89 named empty 🧺/🦅 even with no quest — that buried Act 0
	# (w156: true-zero chip was already Find Lanternfall). Only steal
	# the banner when lantern_door is actually minted.
	# w160-r2: chain_ends minted, Hold the Lamp Arc silent, banner still
	# named 🦅 18/21. The lamp is the live beat — Forest gather is not.
	if hold_lamp_live() or teaching_claim_live():
		return _hold_lamp_walk_line()
	if lantern_bridge_live():
		return _plant_walk_line()
	if _is_horn_ask(_best_objective()) or _is_horn_ask(_banner_quest()):
		return _horn_walk_line()
	if knot_live():
		return _knot_walk_line()
	if _is_spinor_ask(_best_objective()) or _is_spinor_ask(_banner_quest()):
		return _spinor_walk_line()
	if sixteen_live():
		return _sixteen_walk_line()
	if lantern_well_live():
		return _basket_walk_line()
	if lantern_door_fired() and _eagle_short() and not hold_lamp_live() and not lantern_bridge_live() and not teaching_claim_live() and not knot_live() and _sig_count() < 16 and not _flag_fired("the_knot"):
		return _eagle_gather_line()
	var qm := _quest_manager()
	if qm == null or not ("active_quests" in qm):
		return "▸ stand on the field"
	var best := _banner_quest()
	# Wave 24 literalist: gathered 🌱 3→21, then chrome-only. Unsigned plant
	# is STORY — hiding the banner after the gather walk ate Icon [5].
	# Plant is the live beat whether or not they have signed the Arc.
	if _is_plant_ask(best):
		return _plant_walk_line()
	if _is_discover_ask(best):
		return _discover_walk_line()
	if _is_compass_ask(best) and str(best.get("status", "")) != Quest.STATUS_STORY:
		return _compass_walk_line()
	if _is_knot_ask(best) and str(best.get("status", "")) != Quest.STATUS_STORY:
		return _knot_walk_line()
	if _is_breathe_ask(best) and str(best.get("status", "")) != Quest.STATUS_STORY:
		return _breathe_walk_line()
	if _is_lamp_ask(best) and str(best.get("status", "")) != Quest.STATUS_STORY:
		return _hold_lamp_walk_line()
	# Wave first_breath: unsigned berry door painted Farm/System/Story/Board
	# + QERF with no quest line. Field walk is the live ask, like plant.
	if _is_berry_ask(best):
		return _berry_walk_line()
	# Wave mill_wakes: unsigned Hold Commerce painted Village plant, not
	# Market. Board walk is the live ask, like plant/berry.
	if _is_board_ask(best) or _is_goods_ask(best):
		return _board_walk_line(best)
	# Returning player: offer toasts do not replay. Unsigned ARC still
	# lives on Arc. Name the door, not the in-room recipe (w39 empty HUD).
	if best.is_empty() or str(best.get("status", "")) == Quest.STATUS_STORY:
		# w61: Arc empty, wallet 0🧺 — Ace Q cannot pop. Village is the well
		# only while lantern_door is the unsigned walk.
		if hold_lamp_live() or teaching_claim_live():
			return _hold_lamp_walk_line()
		if lantern_bridge_live():
			return _plant_walk_line()
		if knot_live():
			return _knot_walk_line()
		if _is_spinor_ask(_banner_quest()) and str(_banner_quest().get("status", "")) != Quest.STATUS_STORY:
			return _spinor_walk_line()
		if sixteen_live():
			return _sixteen_walk_line()
		if lantern_well_live():
			return _basket_walk_line()
		if _unsigned_arc_waiting():
			return "▸ [X] then Arc [I]"
		# w195: generic eagle-gather stole the banner after the_knot memoir
		# (Arc empty, Wind Twice already claimed). Ledger walk is the door.
		if _flag_fired("the_knot") and not _flag_fired("ledger_opens"):
			var ledger := _ledger_walk_line()
			if ledger != "":
				return ledger
		if lantern_door_fired() and _eagle_short() and not hold_lamp_live():
			return _eagle_gather_line()
		return _discover_walk_line()
	return _decorate_objective(best)


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
	if hold_lamp_live():
		var abm_l := _active_biome_manager()
		if abm_l != null and str(abm_l.get_active_biome()) != "Lanternfall":
			return {"key": "", "biome": "Lanternfall"}
		var druid_l := _hat_key_for_frame("druid")
		if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_DRUID:
			return {"key": druid_l, "hat": druid_l, "biome": ""}
		return {"key": "E", "hat": druid_l, "biome": "Lanternfall"}
	if knot_live():
		var druid_k := _hat_key_for_frame("druid")
		if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_DRUID:
			return {"key": druid_k, "hat": druid_k, "biome": ""}
		return {"key": "E", "hat": druid_k, "biome": ""}
	var best := _banner_quest()
	# Wave 23: plant-short pulses Forest, not Icon 5 and not C. PredicateGloss
	# target() for gate=plant is the Icon hat — true only after 🌱×5.
	if _is_plant_ask(best) and _sprout_short():
		return {"key": "", "biome": "StarterForest"}
	if _is_plant_ask(best):
		var icon_hat := _hat_key_for_frame("icon")
		if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_ICON:
			return {"key": icon_hat, "hat": icon_hat, "biome": ""}
		return {"key": _empty_plot_key(), "hat": icon_hat, "biome": ""}
	if _is_compass_ask(best) and str(best.get("status", "")) != Quest.STATUS_STORY:
		if str(best.get("status", "")).to_lower() == "ready":
			return {"key": "C", "biome": ""}
		var spring := _compass_target_biome(best)
		if spring != "":
			var abm := _active_biome_manager()
			if abm != null and str(abm.get_active_biome()) != spring:
				return {"key": "", "biome": spring}
		return {"key": "C", "biome": ""}
	if _is_breathe_ask(best) and str(best.get("status", "")) != Quest.STATUS_STORY:
		if str(best.get("status", "")).to_lower() == "ready":
			return {"key": "C", "biome": ""}
		var pond := _breathe_target_biome(best)
		if pond != "":
			var abm2 := _active_biome_manager()
			if abm2 != null and str(abm2.get_active_biome()) != pond:
				return {"key": "", "biome": pond}
		var druid := _hat_key_for_frame("druid")
		if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_DRUID:
			return {"key": druid, "hat": druid, "biome": ""}
		return {"key": "E", "hat": druid, "biome": ""}
	if _is_berry_ask(best) and str(best.get("status", "")) != Quest.STATUS_STORY:
		var grove := _berry_target_biome(best)
		if grove != "":
			var abm3 := _active_biome_manager()
			if abm3 != null and str(abm3.get_active_biome()) != grove:
				return {"key": "", "biome": grove}
		var icon5 := _hat_key_for_frame("icon")
		if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_ICON:
			return {"key": icon5, "hat": icon5, "biome": ""}
		return {"key": "F", "hat": icon5, "biome": grove}
	if _is_discover_ask(best) and _eagle_short() and not hold_lamp_live():
		return {"key": "", "biome": "StarterForest"}
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
		return {"key": cap, "hat": cap, "biome": ""}
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
		# Offers wait on the Arc. No banner, no spotlight-on-X — the
		# toast already linked there; pulsing a second door is slop.
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
	if _is_goods_ask(q):
		return _board_walk_line(q)
	if status == Quest.STATUS_STORY:
		if _is_discover_ask(q):
			return _discover_walk_line()
		if _is_plant_ask(q):
			return _plant_walk_line()
		if lantern_well_live():
			return _basket_walk_line()
		return "▸ to accept: " + route_accept()
	if status == "ready":
		# Wave 15: "tap C, its row twice" while Market was already open and
		# [R] still said Accept. Name one key. Fallback keeps route_claim().
		var claim := _claim_walk_line(q)
		if claim != "":
			return claim
		return "▸ to claim: " + route_claim()
	var travel := _travel_line(q)
	if travel != "":
		return travel
	var verb := _verb_line(q)
	if verb != "":
		return verb
	# Standing/goods live on the board. Derive the walk the same way travel
	# derives the rail key — even when the authored hint already names [C].
	# Wave 10/11: Market [Y] + first row was the apprentice (Go there), not
	# a Millwright delivery. Name Accept (Y) / Deliver (U) from the board.
	if _is_board_ask(q):
		if lantern_well_live():
			return _basket_walk_line()
		var walk := _board_walk_line(q)
		if walk != "":
			return walk
	if _is_plant_ask(q):
		return _plant_walk_line()
	if _is_discover_ask(q):
		return _discover_walk_line()
	if _is_compass_ask(q) and str(q.get("status", "")) != Quest.STATUS_STORY:
		return _compass_walk_line()
	if _is_knot_ask(q) and str(q.get("status", "")) != Quest.STATUS_STORY:
		return _knot_walk_line()
	if _is_breathe_ask(q) and str(q.get("status", "")) != Quest.STATUS_STORY:
		return _breathe_walk_line()
	if _is_lamp_ask(q) and str(q.get("status", "")) != Quest.STATUS_STORY:
		return _hold_lamp_walk_line()
	if _is_berry_ask(q):
		return _berry_walk_line(q)
	# Authored hint dumps the in-room recipe. If they wandered, name the
	# door back first — never "press R" while they are looking at Market.
	var room := _wrong_room_line("field")
	if room != "":
		return room
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
	# Wandered into a menu: name the door back, not the in-room verb.
	var room := _wrong_room_line("field")
	if room != "":
		return room
	if need_frame != "" and wearing != need_frame:
		return "▸ [%s] %s" % [hat.to_upper(), need_frame.capitalize()]
	# Reap is Ace Shift+F — never remapped onto plain F, never a hat swap.
	if step == 5:
		return "▸ Shift+F %s" % ask
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
	# atom_in_biome (woodlot_wakes: plant 🪵 into Village) is the same
	# walk — Icon [5] R Plant — not a Market delivery. Wave w30: the
	# unsigned atom door hid the banner (STORY + not inject_icon → "").
	# mill_wakes: Hold Commerce is the mill plant (💨/🔨), not a 👥 stall.
	if str(q.get("source_flag", "")) == "mill_wakes":
		return true
	for pred in q.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		var t := str(pred.get("type", ""))
		if t == "gate_sequence_contains":
			var g := str(pred.get("gate", "")).to_lower()
			if g == "inject_icon" or g == "plant":
				return true
		if t == "atom_in_biome":
			if str(pred.get("atom", "")).strip_edges() != "" \
					and str(pred.get("biome", "")).strip_edges() != "":
				return true
	return false


## Still the Pond / compass-gap beats. Map Graph is the reader; Ace Strike
## deepens the gap. Do not measure for them. Wave w32 earnest: Graph E on
## federation showed coupling help, no 🧭 numbers, and the banner said ESC
## because Map counted as "wrong room".
static func _is_compass_ask(q: Dictionary) -> bool:
	for pred in q.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		var t := str(pred.get("type", ""))
		if t == "biome_eigenvalue_gap_gte" or t == "eigenvalue_gap_gte":
			return true
	return false


static func _is_knot_ask(q: Dictionary) -> bool:
	if q.is_empty():
		return false
	for pred in q.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		var t := str(pred.get("type", ""))
		if t == "biome_loops_linked" or t == "loops_linked" or t == "winding_gte":
			return true
	return false


static func _is_spinor_ask(q: Dictionary) -> bool:
	if q.is_empty():
		return false
	for pred in q.get("state_predicates", []):
		if pred is Dictionary and str(pred.get("type", "")) == "spinor_read":
			return true
	return false


static func _spinor_walk_line() -> String:
	# Ask the Loop: Icon 🪞, stay-home on a different plot, compare. One key.
	# w170: inject R Incorporate sat next to mirror R Stay Home.
	# w173: Arc OPEN [R] Accept vs farm stay-home. Close Arc first.
	var q := _best_objective()
	if q.is_empty() or not _is_spinor_ask(q):
		q = _banner_quest()
	var st := str(q.get("status", "")).to_lower()
	if st == "ready":
		return _claim_walk_line(q)
	if st == "story" or st == "offered":
		return "▸ [X] then Arc [I]"
	if _in_icon_submenu() or _menu_open() or _overlay_open("quests"):
		return "▸ ESC closes"
	if _sim_paused():
		return "▸ [F] Play"
	var room := _wrong_room_line("field")
	if room != "":
		return room
	var wearing := str(ToolConfig.get_current_frame())
	if wearing != ToolConfig.FRAME_ICON:
		return "▸ [5] Icon"
	if str(ToolConfig.get_frame_mode_name(ToolConfig.FRAME_ICON)) != "mirror":
		return "▸ [2] 🪞"
	# w172: "other plot" is not a key. Stay-home is a different homerow
	# from the focused traveler. Name it.
	# w174: after stay-home, toast said bring traveler; ▸ still stay-home.
	var inst = _instrument()
	var href: Dictionary = {}
	if inst != null and inst.has_method("get_mirror_reference"):
		var raw_ref = inst.get_mirror_reference()
		if raw_ref is Dictionary:
			href = raw_ref
	var focused := _focused_col()
	var home_q: int = -1
	if not href.is_empty():
		home_q = int(href.get("register_id", href.get("qid", -1)))
	# w179: register_id -1 was treated as traveler, so [R] Stay Home
	# never printed. No mark → stay-home first.
	if href.is_empty() or home_q < 0:
		var stay: String = "H"
		if focused <= 0:
			stay = "G"
		elif focused < PLOT_HOMEROW.length():
			stay = PLOT_HOMEROW.substr(focused, 1)
		return "▸ [R] stay-home on [%s]" % stay
	if focused == home_q:
		var other: String = "H" if home_q == 0 else "G"
		return "▸ [%s] traveler" % other
	return "▸ [E] Compare"


static func sixteen_live() -> bool:
	# Sixteen Words. Do not drown in leftover Superpose (w170 runner).
	# w175: Ask the Loop is STATUS_STORY (awaiting Accept). _banner_quest
	# skips STORY so sixteen stole [F] Track after a −1 Compare.
	if knot_live():
		return false
	var best := _best_objective()
	if _is_spinor_ask(best) or _is_knot_ask(best):
		return false
	# Unsigned Ask the Loop is STATUS_STORY — live_quest skips it, so
	# sixteen stole eagles 13/21 (w186).
	var door: Dictionary = IntroVoice.live_door()
	var data = door.get("data", {}) if not door.is_empty() else {}
	if data is Dictionary and (_is_spinor_ask(data) or _is_knot_ask(data)):
		return false
	if _flag_fired("edge_of_the_enclave"):
		return false
	if not _flag_fired("the_knot"):
		return false
	return _sig_count() < 16


static func _sig_count() -> int:
	var farm = _active_farm()
	if farm == null:
		return 0
	if farm.has_method("get_known_icons"):
		return int(farm.get_known_icons().size())
	if "known_icons" in farm and farm.known_icons != null:
		return int(farm.known_icons.size())
	return 0


static func _sixteen_walk_line() -> String:
	if _in_icon_submenu() or _menu_open():
		return "▸ ESC closes"
	var room := _wrong_room_line("field")
	if room != "":
		return room
	var n := _sig_count()
	# w173: after a cull, slot is open; Add Biome still costs 🦅×21.
	# Do not keep naming Captain if a slot is free — gather eagles or Track.
	if n >= 13:
		# w194–w196: cull / eagles / [7] Captain stole the banner. If
		# BloodLedger is already seated, the word-door is Icon Incorporate.
		# Hat 7 while Network Whole was open killed the headless seat.
		var ledger := _ledger_walk_line()
		if ledger != "":
			return ledger
		if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_CAPTAIN:
			if not is_hat_visible(ToolConfig.FRAME_CAPTAIN):
				return "▸ [5] Icon"
			return "▸ [7] Captain"
		var want := _pressured_discover_name()
		if want == "":
			want = "BloodLedger"
		return "▸ [R] Add Biome — %s" % want
	var wearing := str(ToolConfig.get_current_frame())
	if wearing != ToolConfig.FRAME_ICON:
		return "▸ [5] Icon"
	if str(ToolConfig.get_frame_mode_name(ToolConfig.FRAME_ICON)) != "inject":
		return "▸ [1] Icon"
	return "▸ [F] Track (%d/16)" % n


static func _knot_target_biome(q: Dictionary = {}) -> String:
	if q.is_empty():
		q = _banner_quest()
	for pred in q.get("state_predicates", []):
		if pred is Dictionary:
			var b := str(pred.get("biome", "")).strip_edges()
			if b != "":
				return b
	return "StarterForest"


static func _knot_walk_line() -> String:
	# Wind Twice. Unsigned = Accept on Arc. Ace never Superposes — the
	# authored walk after Accept is Icon Track, not Druid (w184 runner:
	# banner named [0] while Ace stayed Ace and Captain stole the HUD).
	var q := _banner_quest()
	if q.is_empty():
		var door: Dictionary = IntroVoice.live_door()
		var data = door.get("data", {}) if not door.is_empty() else {}
		if data is Dictionary:
			q = data
	if str(q.get("status", "")).to_lower() == "ready":
		return _claim_walk_line(q)
	if q.is_empty() or str(q.get("status", "")) == Quest.STATUS_STORY:
		return "▸ [X] then Arc [I]"
	var room := _wrong_room_line("field")
	if room != "":
		return room
	var want := _knot_target_biome(q)
	var cross := _cross_to(want)
	if cross != "":
		return cross
	if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_ICON:
		return "▸ [5] Icon"
	return "▸ [F] Track"


static func _ledger_walk_line() -> String:
	# Sixteen Words after Wind Twice is claimed: mint ledger_opens on
	# BloodLedger. Do not point at an empty Arc (w190 runner).
	if _flag_fired("ledger_opens") or _flag_fired("edge_of_the_enclave"):
		return ""
	if _in_icon_submenu() or _menu_open():
		return "▸ ESC closes"
	var farm = _active_farm()
	var seated := false
	var of = farm.get_node_or_null("/root/ObservationFrame") if farm != null else null
	if of != null and of.has_method("get_unlocked_biomes"):
		seated = "BloodLedger" in of.get_unlocked_biomes()
	if not seated:
		if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_CAPTAIN:
			if not is_hat_visible(ToolConfig.FRAME_CAPTAIN):
				return "▸ [8] Ace"
			return "▸ [7] Captain"
		# Cost is on the press (toast). Do not steal the banner to a
		# rabbit-farm eagle walk (w195).
		return "▸ [R] Add Biome — BloodLedger"
	if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_ICON:
		return "▸ [5] Icon"
	return "▸ [R] Incorporate"


static func _compass_target_biome(q: Dictionary = {}) -> String:
	if q.is_empty():
		q = _banner_quest()
	for pred in q.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		if str(pred.get("type", "")) in ["biome_eigenvalue_gap_gte", "eigenvalue_gap_gte"]:
			var b := str(pred.get("biome", "")).strip_edges()
			if b != "":
				return b
	return "FreshwaterSpring"


static func _compass_need_gap(q: Dictionary) -> float:
	for pred in q.get("state_predicates", []):
		if pred is Dictionary and str(pred.get("type", "")) in ["biome_eigenvalue_gap_gte", "eigenvalue_gap_gte"]:
			return float(pred.get("value", 0.35))
	return 0.35


static func _compass_need_motion(q: Dictionary) -> float:
	for pred in q.get("state_predicates", []):
		if pred is Dictionary and str(pred.get("type", "")) == "dynamics_at_most":
			return float(pred.get("value", 0.2))
	return 0.2


static func _is_horn_ask(q: Dictionary) -> bool:
	if q.is_empty():
		return false
	for pred in q.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		if str(pred.get("type", "")) == "biome_state_lte" and str(pred.get("atom", "")) == "📯":
			return true
	return false


static func _horn_walk_line() -> String:
	# The Middle Cannot Hold: let 📯 decay. Do not Strike it.
	if _in_icon_submenu() or _menu_open():
		return "▸ ESC closes"
	if _sim_paused():
		return "▸ [F] Play"
	var room := _wrong_room_line("field")
	if room != "":
		return room
	var cross := _cross_to("Lanternfall")
	if cross != "":
		return cross
	return "▸ [F] Play — let 📯 go dark"


static func _overlay_manager():
	var shell := _shell()
	if shell == null or not ("overlay_manager" in shell):
		return null
	return shell.overlay_manager


static func _overlay_open(name: String) -> bool:
	var om = _overlay_manager()
	if om == null or not ("overlays" in om) or om.overlay_stack == null:
		return false
	var ov = om.overlays.get(name)
	return ov != null and om.overlay_stack.has_overlay(ov)


static func _map_overlay():
	var om = _overlay_manager()
	if om == null or not ("map_meta_overlay" in om):
		return null
	return om.map_meta_overlay


static func _biome_gap(biome_name: String) -> float:
	var farm = _active_farm()
	if farm == null or farm.grid == null or not farm.grid.has_method("get_biome"):
		return -1.0
	var biome = farm.grid.get_biome(biome_name)
	if biome == null:
		return -1.0
	var attractor: Dictionary = {}
	if biome.has_method("get_attractor_state"):
		attractor = biome.get_attractor_state()
	elif "quantum_computer" in biome and biome.quantum_computer != null \
			and biome.quantum_computer.has_method("get_attractor_state"):
		attractor = biome.quantum_computer.get_attractor_state()
	if attractor.is_empty():
		return -1.0
	return float(attractor.get("eigenvalue_gap", -1.0))


static func _biome_motion(biome_name: String) -> float:
	var farm = _active_farm()
	var qm := _quest_manager()
	if farm == null or farm.grid == null or qm == null:
		return -1.0
	if not farm.grid.has_method("get_biome") or not qm.has_method("get_biome_observables"):
		return -1.0
	var biome = farm.grid.get_biome(biome_name)
	if biome == null:
		return -1.0
	var obs: Dictionary = qm.get_biome_observables(biome)
	return float(obs.get("dynamics", -1.0))


## One next key. Map Graph is the reader (🧭 lives there). Ace Strike on
## the field deepens the gap. Numbers always print so screen_text has them.
## Neighborhood Graph [ is not this compass. Do not measure for them.
static func _compass_walk_line() -> String:
	# Standing in the spring is looking. Map [M] / Graph [P] dual-bind
	# biome tabs (w34). Do not name them. Dynamics is retired. Unsigned
	# offers stay on Arc. Do not measure for them.
	var q := _banner_quest()
	if str(q.get("status", "")).to_lower() == "ready":
		return _claim_walk_line(q)
	var want := _compass_target_biome(q)
	var room := _wrong_room_line("field")
	if room != "":
		return room
	var cross := _cross_to(want)
	if cross != "":
		return cross
	return "▸ [C] then [R] Claim"


static func _is_breathe_ask(q: Dictionary) -> bool:
	for pred in q.get("state_predicates", []):
		if pred is Dictionary and str(pred.get("type", "")) == "coherence_at_least":
			return true
	return false


static func _breathe_target_biome(q: Dictionary = {}) -> String:
	if q.is_empty():
		q = _banner_quest()
	for pred in q.get("state_predicates", []):
		if pred is Dictionary and str(pred.get("type", "")) == "coherence_at_least":
			var b := str(pred.get("biome", "")).strip_edges()
			if b != "":
				return b
	return "FreshwaterSpring"


static func _breathe_walk_line() -> String:
	# Make It Breathe: Superpose on the spring. Do not Superpose for them.
	# Arc toast is not the work once they hold the quest (w35).
	var q := _banner_quest()
	if str(q.get("status", "")).to_lower() == "ready":
		return _claim_walk_line(q)
	var room := _wrong_room_line("field")
	if room != "":
		return room
	var want := _breathe_target_biome(q)
	var cross := _cross_to(want)
	if cross != "":
		return cross
	var wearing := str(ToolConfig.get_current_frame())
	if wearing != ToolConfig.FRAME_DRUID:
		return "▸ [0] Druid"
	return "▸ [E] Superpose"


static func _is_lamp_ask(q: Dictionary) -> bool:
	for pred in q.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		if str(pred.get("type", "")) == "biome_state_gte" and str(pred.get("atom", "")) == "🪔":
			return true
	return false


static func _hold_lamp_walk_line() -> String:
	# Hold the Lamp: Druid on the Lanternfall beacon, Superpose, let it run.
	# Do not Superpose for them. One next key.
	var q := _banner_quest()
	if str(q.get("status", "")).to_lower() == "ready":
		return _claim_walk_line(q)
	if _in_icon_submenu() or _menu_open():
		if teaching_claim_live() and _in_icon_submenu():
			return "▸ ESC closes"
		return "▸ ESC closes"
	if _sim_paused():
		return "▸ [F] Play"
	var room := _wrong_room_line("field")
	if room != "":
		return room
	var cross := _cross_to("Lanternfall")
	if cross != "":
		return cross
	var want := _glyph_plot_key("🪔", "Lanternfall")
	if want == "":
		want = "H"
	var focused := _focused_col()
	var token := ";" if want == ";" else want.to_upper()
	var want_col := PLOT_HOMEROW.find(token) if want != "" else -1
	if want != "" and focused != want_col:
		return "▸ [%s] for 🪔" % want
	# w161-r1: Superpose on an unrevealed beacon did nothing. Ace Explore
	# binds the plot; Druid E is not Explore.
	var wearing := str(ToolConfig.get_current_frame())
	if not _plot_bound(focused):
		if wearing != ToolConfig.FRAME_ACE:
			return "▸ [8] Ace"
		return "▸ [F] Explore"
	if wearing != ToolConfig.FRAME_DRUID:
		return "▸ [0] Druid"
	return "▸ [E] Superpose"


static func _is_berry_ask(q: Dictionary) -> bool:
	# loop_remembers is phase-only (berry_total_phase_gte). w50 literalist
	# got Arc [R] Accept as the only named key; harvest-late had no farm walk.
	for pred in q.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		var t := str(pred.get("type", ""))
		if t == "berry_consumed_count_gte" or t == "berry_total_phase_gte":
			return true
	return false


static func _berry_target_biome(q: Dictionary = {}) -> String:
	if q.is_empty():
		q = _banner_quest()
	for pred in q.get("state_predicates", []):
		if pred is Dictionary:
			var t := str(pred.get("type", ""))
			if t == "berry_consumed_count_gte" or t == "berry_total_phase_gte":
				var b := str(pred.get("biome", "")).strip_edges()
				if b != "":
					return b
	return "StarterForest"


static func _berry_walk_line(q: Dictionary = {}) -> String:
	# first_breath live door: one next key. Do not dump F / = / R / X.
	# Do not incorporate for them. Unsigned berry still paints (like plant).
	if _in_icon_submenu() or _menu_open():
		return "▸ ESC closes"
	if q.is_empty():
		q = _banner_quest()
	if str(q.get("status", "")).to_lower() == "ready":
		return _claim_walk_line(q)
	var room := _wrong_room_line("field")
	if room != "":
		return room
	var want := _berry_ask_biome(q)
	if want == "":
		want = _berry_target_biome(q)
	if want != "":
		var cross := _cross_to(want)
		if cross != "":
			return cross
	var wearing := str(ToolConfig.get_current_frame())
	if wearing != ToolConfig.FRAME_ICON:
		return "▸ [5] Icon"
	# Icon F is Track; while a loop is live, F would stop it. Ace F Plays.
	if _sim_paused() and _berry_tracking():
		return "▸ [8] Ace"
	if not _plot_bound(_focused_col()):
		return "▸ [G] a living plot"
	if not _berry_tracking():
		return "▸ [F] Track"
	if _berry_ripe():
		return "▸ [R] Incorporate"
	if _sim_paused():
		return "▸ [F] Play"
	return "▸ wait — loop ripens (~90s)"


static func _plant_target_biome(q: Dictionary = {}) -> String:
	if q.is_empty():
		q = _banner_quest()
	if str(q.get("source_flag", "")) == "mill_wakes":
		return "Village"
	for pred in q.get("state_predicates", []):
		if pred is Dictionary and str(pred.get("type", "")) == "atom_in_biome":
			var b := str(pred.get("biome", "")).strip_edges()
			if b != "":
				return b
	if lantern_bridge_live():
		return "Lanternfall"
	return ""


static func _plant_atom_seated() -> bool:
	var atom := _plant_target_atom()
	var biome_name := _plant_target_biome()
	if atom == "" or biome_name == "":
		return false
	var farm = _active_farm()
	if farm == null or farm.grid == null or not farm.grid.has_method("get_biome"):
		return false
	var biome = farm.grid.get_biome(biome_name)
	if biome == null or biome.quantum_computer == null \
			or biome.quantum_computer.register_map == null:
		return false
	return biome.quantum_computer.register_map.coordinates.has(atom)


static func _plant_target_atom(q: Dictionary = {}) -> String:
	if q.is_empty():
		q = _banner_quest()
	if str(q.get("source_flag", "")) == "mill_wakes":
		return "💨"
	for pred in q.get("state_predicates", []):
		if pred is Dictionary and str(pred.get("type", "")) == "atom_in_biome":
			var a := str(pred.get("atom", "")).strip_edges()
			if a != "":
				return a
	if lantern_bridge_live():
		return "🌉"
	return ""


static func _is_discover_ask(q: Dictionary) -> bool:
	for pred in q.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		if str(pred.get("type", "")) != "biome_evolving":
			continue
		var b := str(pred.get("biome", "")).strip_edges()
		if b == "":
			continue
		# w84: TYUIOP slot is not "found". ensure_slotted / a 6-wide
		# ring made Lanternfall look unlocked, so the gold banner hid
		# and Accept on Arc stayed OPEN. Atoms in the biome are found.
		if _biome_has_atoms(b):
			continue
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


static func _biome_has_atoms(bname: String) -> bool:
	# Empty grid qubits are not a found country. atom_count_in is the
	# evolving/loaded check PredicateGloss already uses.
	var qm := _quest_manager()
	if qm != null and qm.has_method("atom_count_in"):
		return int(qm.atom_count_in(bname)) > 0
	return false


const PLOT_HOMEROW := "GHJKL;"


static func _active_farm():
	var gsm = Engine.get_main_loop().root.get_node_or_null("GameStateManager") if Engine.get_main_loop() else null
	return gsm.get_active_farm() if (gsm and gsm.has_method("get_active_farm")) else null


static func _basket_have() -> float:
	var farm = _active_farm()
	if farm == null or not ("economy" in farm) or farm.economy == null:
		return 0.0
	if not farm.economy.has_method("get_resource"):
		return 0.0
	return float(farm.economy.get_resource("🧺"))


static func _basket_short() -> bool:
	# Gather (Ace Q) costs 1🧺. Empty wallet cannot cash a strike.
	# No economy read → treat as short so the well walk still names.
	return _basket_have() < 1.0


static func _flag_fired(flag: String) -> bool:
	var farm = _active_farm()
	if farm == null or not ("story_flags_fired" in farm):
		return false
	var fired = farm.story_flags_fired
	return fired != null and fired.has(flag)


static func lantern_door_fired() -> bool:
	return _flag_fired("lantern_door")


static func hold_lamp_live() -> bool:
	# chain_ends mints Hold the Lamp. lantern_teaching claims it.
	# w160-r2: flag fired, Arc silent, banner still named 🦅 18/21.
	return _flag_fired("chain_ends") and not _flag_fired("lantern_teaching")


static func lantern_bridge_live() -> bool:
	# Light the Bridge is Icon-plant 🌉 until 🌉 sits in Lanternfall.
	# w165: lantern_wakes minted on Teaching claim, steal died, 🦅 ate
	# the banner while the bridge was still unplanted.
	return _flag_fired("lantern_teaching") and not _bridge_seated()


static func teaching_claim_live() -> bool:
	# The Teaching: hold 🪔 then Claim. 🌉 is the reward, not a plant yet.
	return _flag_fired("lantern_teaching") and not _sig_has("🌉") and not _bridge_seated()


static func _bridge_seated() -> bool:
	var farm = _active_farm()
	if farm == null or farm.grid == null or not farm.grid.has_method("get_biome"):
		return false
	var biome = farm.grid.get_biome("Lanternfall")
	if biome == null or biome.quantum_computer == null \
			or biome.quantum_computer.register_map == null:
		return false
	return biome.quantum_computer.register_map.coordinates.has("🌉")


static func knot_live() -> bool:
	# Only while Wind Twice is the in-progress quest. w170 runner: steal
	# stayed on after winding 2 and drowned Sixteen Words / GildedRot.
	if not _flag_fired("the_knot") or _flag_fired("the_span"):
		return false
	# live_quest skips unsigned STATUS_STORY, so Wind Twice sitting in
	# story_offers looked empty and sixteen stole Captain (w183).
	if _is_knot_ask(_best_objective()) or _is_knot_ask(_banner_quest()):
		return true
	var door: Dictionary = IntroVoice.live_door()
	var data = door.get("data", {}) if not door.is_empty() else {}
	return data is Dictionary and _is_knot_ask(data)


static func _sig_has(glyph: String) -> bool:
	var farm = _active_farm()
	if farm == null or not farm.has_method("get_known_icons"):
		return false
	for ic in farm.get_known_icons():
		var blob := ""
		if ic is Dictionary:
			blob = str(ic.get("north", "")) + str(ic.get("south", "")) \
					+ str(ic.get("pole_0", "")) + str(ic.get("pole_1", ""))
		else:
			blob = str(ic)
		if glyph in blob:
			return true
	return false


static func lantern_well_live() -> bool:
	# Village 🧺 is the lantern_door beat — not every empty wallet.
	# Act 0 (w156 runner) had [R] Find Lanternfall before a first strike.
	# w164: earnest at the_knot still had Ace R = Find Lanternfall.
	return lantern_door_fired() and _basket_short() and not _flag_fired("chain_ends")


static func _basket_walk_line() -> String:
	# Village Commerce 🧺|💰 is the basket well. One next key. Do not
	# gather for them. WindMill stays a quest plant, not a boot qubit.
	if _in_icon_submenu() or _menu_open():
		return "▸ ESC closes"
	if _sim_paused():
		return "▸ [F] Play"
	var have := int(_basket_have())
	var need := "🧺 %d/1" % have
	var cross := _cross_to("Village")
	if cross != "":
		return cross + " for " + need
	var wearing := str(ToolConfig.get_current_frame())
	if wearing != ToolConfig.FRAME_ACE:
		return "▸ [8] Ace for " + need
	# w76: scout named [;] (empty plant seat) so want was never "" and
	# the Village Commerce heal never ran. Heal first, then name.
	var farm = _active_farm()
	if farm != null and farm.has_method("ensure_village_commerce"):
		farm.ensure_village_commerce()
	var want := _glyph_plot_key("🧺", "Village")
	if want == "":
		return "▸ no 🧺 plot seated"
	var focused := _focused_col()
	var token := ";" if want == ";" else want.to_upper()
	var want_col := PLOT_HOMEROW.find(token) if want != "" else -1
	# w77: focused Village 🧺💰 but banner stayed [K] because the
	# column index missed. If the focused axis is already 🧺, walk it.
	if want != "" and focused != want_col and not _focused_is_glyph("🧺"):
		return "▸ [%s] for %s" % [want, need]
	if not _plot_bound(focused):
		if ace_f_would_explore():
			return "▸ [F] Explore for " + need
		return "▸ [%s] for %s" % [want, need]
	if not _plot_measured(focused):
		return "▸ %s for %s" % [ToolConfig.action_cue(ToolConfig.FRAME_ACE, "R"), need]
	var got := _measured_glyph(focused)
	if "🧺" in got:
		return "▸ %s 🧺" % ToolConfig.action_cue(ToolConfig.FRAME_ACE, "Q")
	if got != "":
		return "▸ %s take %s" % [ToolConfig.action_cue(ToolConfig.FRAME_ACE, "Q"), got]
	return "▸ %s" % ToolConfig.action_cue(ToolConfig.FRAME_ACE, "Q")


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


static func plot_idx_from_key(key: String) -> int:
	var token := str(key).strip_edges()
	if token == "":
		return -1
	if token != ";":
		token = token.to_upper()
	return PLOT_HOMEROW.find(token)


static func _cross_to(want: String) -> String:
	if _menu_open():
		return "▸ ESC closes"
	var abm := _active_biome_manager()
	if abm == null:
		return ""
	if str(abm.get_active_biome()) == want:
		return ""
	var slot := int(abm.get_slot_for_biome(want))
	if slot < 0 and abm.has_method("ensure_slotted"):
		slot = int(abm.ensure_slotted(want))
	if slot < 0:
		# w71: empty string meant "you're there" AND "can't go". Earnest
		# hunted 🧺 on the wrong biome. Name the miss.
		# w174: after Lanternfall cull, "not in TYUIOP" is a dead end.
		# Name Captain Add Biome.
		if want == "Lanternfall":
			if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_CAPTAIN:
				return "▸ [7] Captain"
			return "▸ [R] Add Biome"
		if want == "StarterForest":
			return "▸ Forest not in TYUIOP"
		return "▸ %s not in TYUIOP" % want
	var key := str(abm.get_slot_key(slot)).to_upper()
	if key == "":
		return "▸ %s not in TYUIOP" % want
	# TYUIOP is the biome row. Y/U/I are also Market / Commitments / Arc
	# once C or X is open. Name "biome" so mill-taught Y does not open
	# the board. w56 literalist: ▸ Y↔U for 🧺 0/1.
	if key == "Y" or key == "U" or key == "I":
		return "▸ biome [%s] %s" % [key, want]
	return "▸ [%s] crosses to %s" % [key, want]


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
	if inst != null and "current_plot_idx" in inst:
		var idx := int(inst.current_plot_idx)
		# w51 earnest: banner [J] empty while Village J was a live qubit —
		# Icon R said Track first (F), not Plant.
		if idx >= nq and not _plot_bound(idx):
			var focused := _col_key(idx)
			if focused != "":
				return focused
	if farm.grid.has_method("get_plot_biome_assignments"):
		var cols: Array = []
		var assignments: Dictionary = farm.grid.get_plot_biome_assignments()
		for pos in assignments.keys():
			if str(assignments[pos]) != bname:
				continue
			var col := int(pos.x) if pos is Vector2i else int(pos.x)
			if col >= nq and not _plot_bound(col):
				cols.append(col)
		cols.sort()
		if not cols.is_empty():
			var k := _col_key(int(cols[0]))
			if k != "":
				return k
	var fallback := nq
	while fallback < 6 and _plot_bound(fallback):
		fallback += 1
	# w55: nq=6 named [;] as empty while every homerow plot was bound.
	# Icon R then said Track first. No empty seat is honest silence.
	if fallback >= 6 or _plot_bound(fallback):
		return ""
	return _col_key(fallback)


static func _sprout_plot_key() -> String:
	return _glyph_plot_key("🌱")


static func _glyph_plot_key(glyph: String, biome_name: String = "") -> String:
	# Fog-honest: name a glyph bubble only when a sighted player can read it.
	# Wave 20: Forest G is 🐺🦌 — never call that a 🌱 plot. Scout unrevealed
	# live plots (H J K L) until the glyph shows. Empty columns (;) are plant seats.
	var farm = _active_farm()
	var bname := str(biome_name).strip_edges()
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
	var assigned: Dictionary = {}
	var sprout_cols: Array = []
	var scout_cols: Array = []
	for pos in assignments.keys():
		if str(assignments[pos]) != bname:
			continue
		var col := int(pos.x)
		if col < 0 or col >= PLOT_HOMEROW.length():
			continue
		assigned[col] = true
		if col >= nq:
			continue
		var rm_pair := ""
		if biome.quantum_computer != null and biome.quantum_computer.register_map != null:
			var axr: Dictionary = biome.quantum_computer.register_map.axis(col) if biome.quantum_computer.register_map.has_method("axis") else {}
			rm_pair = str(axr.get("north", "")) + str(axr.get("south", ""))
		if revealed.has(pos) and biome.viz_cache != null and biome.viz_cache.has_method("get_axis"):
			var axis: Dictionary = biome.viz_cache.get_axis(col)
			var pair := str(axis.get("north", "")) + str(axis.get("south", ""))
			if _pole_has_glyph(pair, glyph):
				sprout_cols.append(col)
				continue
		# Empty [;] is a plant seat, not a hidden 🧺. Only scout a
		# column whose register actually carries the glyph.
		if _pole_has_glyph(rm_pair, glyph):
			scout_cols.append(col)
	sprout_cols.sort()
	if not sprout_cols.is_empty():
		return _col_key(int(sprout_cols[0]))
	scout_cols.sort()
	if not scout_cols.is_empty():
		return _col_key(int(scout_cols[0]))
	# w65: viz_cache missed Commerce 🧺|💰 so the walk defaulted to G
	# (wrong plot). Register axis is the well.
	# w73: axes named [;] for a qubit with no Village plot. Only
	# assigned homerow columns are gatherable.
	if biome.quantum_computer != null and biome.quantum_computer.register_map != null:
		var rm = biome.quantum_computer.register_map
		var found: Array = []
		if "axes" in rm:
			for q in rm.axes.keys():
				var ax: Dictionary = rm.axes[q] if rm.axes[q] is Dictionary else {}
				var pair := str(ax.get("north", "")) + str(ax.get("south", ""))
				if _pole_has_glyph(pair, glyph) and assigned.has(int(q)) and int(q) < nq:
					found.append(int(q))
		for i in range(int(rm.num_qubits)):
			if found.has(i):
				continue
			var ax2: Dictionary = rm.axis(i) if rm.has_method("axis") else {}
			var pair2 := str(ax2.get("north", "")) + str(ax2.get("south", ""))
			if _pole_has_glyph(pair2, glyph) and assigned.has(i) and i < nq:
				found.append(i)
		found.sort()
		if not found.is_empty():
			return _col_key(int(found[0]))
	return ""


static func _pole_has_glyph(pair: String, glyph: String) -> bool:
	var p := pair.replace("\uFE0F", "").replace("\uFE0E", "")
	var g := glyph.replace("\uFE0F", "").replace("\uFE0E", "")
	return g != "" and p.contains(g)


static func _focused_col() -> int:
	var inst = _instrument()
	if inst == null or not ("current_plot_idx" in inst):
		return -1
	return int(inst.current_plot_idx)


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
	if plot == null:
		return null
	return plot.terminal


static func _plot_bound(col: int) -> bool:
	var term = _plot_terminal(col)
	if term == null:
		return false
	return bool(term.is_bound)


static func basket_well_grid_pos() -> Vector2i:
	# The Village 🧺 column the gold banner named. Strike/Explore/Gather
	# must hit this plot, not Forest G, when the live door is the well.
	var want := _glyph_plot_key("🧺", "Village")
	if want == "":
		return Vector2i(-1, -1)
	var token := ";" if want == ";" else want.to_upper()
	var col := PLOT_HOMEROW.find(token)
	if col < 0:
		return Vector2i(-1, -1)
	var farm = _active_farm()
	if farm == null or farm.grid == null or not farm.grid.has_method("get_plot_biome_assignments"):
		return Vector2i(-1, -1)
	var assignments: Dictionary = farm.grid.get_plot_biome_assignments()
	for pos in assignments.keys():
		if int(pos.x) == col and str(assignments[pos]) == "Village":
			return pos
	return Vector2i(-1, -1)


static func _focused_is_glyph(glyph: String) -> bool:
	var col := _focused_col()
	if col < 0:
		return false
	var farm = _active_farm()
	var bname := _active_biome_name()
	if farm == null or farm.grid == null or bname == "":
		return false
	var biome = farm.grid.get_biome(bname) if farm.grid.has_method("get_biome") else null
	if biome == null or biome.quantum_computer == null or biome.quantum_computer.register_map == null:
		return false
	var ax: Dictionary = biome.quantum_computer.register_map.axis(col)
	return _pole_has_glyph(str(ax.get("north", "")) + str(ax.get("south", "")), glyph)


static func _plot_measured(col: int) -> bool:
	var term = _plot_terminal(col)
	return term != null and bool(term.is_measured)


static func _measured_glyph(col: int) -> String:
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
	return absf(float(bloch.get("x", 0.0))) > 0.25 \
			or absf(float(bloch.get("y", 0.0))) > 0.25


static func _sim_paused() -> bool:
	var ml := Engine.get_main_loop()
	if not (ml is SceneTree):
		return false
	var shells := (ml as SceneTree).get_nodes_in_group("player_shell")
	if shells.is_empty():
		return false
	var shell = shells[0]
	return shell != null and ("paused" in shell) and bool(shell.paused)


static func ace_f_would_explore() -> bool:
	# Toast must not own F when Ace F is Explore (wave 19 dual-F).
	# w181: horn walk named [F] Play; Ace F still Explored the 📯 plot
	# and kept it alive (Zeno). Fast-Fwd is the settle.
	if _is_horn_ask(_best_objective()) or _is_horn_ask(_banner_quest()):
		return false
	if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_ACE:
		return false
	if _menu_open() or _in_icon_submenu():
		return false
	var col := _focused_col()
	if col < 0:
		return false
	# w157: measured-but-unbound still named Explore; F cleared the strike.
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
	if lantern_well_live():
		return _basket_walk_line()
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
	if lantern_well_live():
		return _basket_walk_line()
	var got := _measured_glyph(focused)
	if "🌱" in got:
		return "▸ [Q] gather 🌱 (%d/5)" % have
	if got != "":
		return "▸ [Q] take %s" % got
	return "▸ [Q] gather"


static func _plant_walk_line() -> String:
	# Wave 11: "Icon hat (5)" named no bracketed key. Name [5], then [R].
	# Wave 18: name the empty-plot key; short 🌱 walks Forest, not Village Q.
	# Wave w30: atom_in_biome plant (🪵 Village) must cross first — standing
	# in Woodlot with an empty banner sent earnest to Captain 7.
	# One next key. If they wandered into a menu, ESC first — do not dump
	# the in-picker recipe while they are looking at Market. Do not plant
	# for them.
	if _sprout_short() and not lantern_bridge_live():
		return _sprout_gather_line()
	if _in_icon_submenu():
		return _plant_picker_line()
	var room := _wrong_room_line("field")
	if room != "":
		return room
	# w54 earnest: planted 🌉, Light the Bridge stayed OPEN needing Accept,
	# banner still [;] empty. The word is in — Accept/Claim is the door.
	if _plant_atom_seated():
		var q := _banner_quest()
		var status := str(q.get("status", ""))
		if status == "ready":
			var claim := _claim_walk_line(q)
			if claim != "":
				return claim
			return "▸ to claim: " + route_claim()
		return "▸ [X] then Arc [I]"
	var want_biome := _plant_target_biome()
	if want_biome != "":
		var cross := _cross_to(want_biome)
		if cross != "":
			return cross
	var wearing := str(ToolConfig.get_current_frame())
	if wearing != ToolConfig.FRAME_ICON:
		return "▸ [5] Icon"
	var want := _empty_plot_key()
	if want == "":
		# w160-r2 runner: Village ring full, Trim asked 13🐺 at 0.
		# Bound plots harvest-free a seat. Do not send Icon Q (Trim).
		if wearing != ToolConfig.FRAME_ACE:
			return "▸ [8] Ace to free a plot"
		return "▸ [Q] gather to empty a plot"
	var focused := _focused_col()
	var token := ";" if want == ";" else want.to_upper()
	var want_col := PLOT_HOMEROW.find(token) if want != "" else -1
	if want != "" and focused != want_col:
		return "▸ [%s] empty plot" % want
	return "▸ %s" % ToolConfig.action_cue(ToolConfig.FRAME_ICON, "R")


## Picker Q/E/R are the three visible words. Name the one key that is 💧
## (or [F] if it is on a later page). Wave w32 literalist: "pick 💧" named
## no bracket. Do not plant for them.
static func _plant_picker_line() -> String:
	var atom := _plant_target_atom()
	var actions: Dictionary = {}
	var inst = _instrument()
	if inst != null and "current_submenu_data" in inst \
			and inst.current_submenu_data is Dictionary:
		var raw = inst.current_submenu_data.get("actions", {})
		if raw is Dictionary:
			actions = raw
	for key in ["Q", "E", "R"]:
		var a = actions.get(key, {})
		if not (a is Dictionary):
			continue
		var blob := "%s%s%s" % [
			str(a.get("north", "")), str(a.get("south", "")), str(a.get("label", ""))]
		if atom != "" and atom in blob:
			return "▸ [%s] pick %s" % [key, atom]
	if atom != "":
		if teaching_claim_live() and atom == "🌉":
			return "▸ ESC closes"
		if not actions.is_empty():
			return "▸ [F] more for %s" % atom
		return "▸ [Q] pick %s" % atom
	return "▸ [Q] pick a word"


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


static func _eagle_have() -> float:
	var farm = _active_farm()
	if farm == null or not ("economy" in farm) or farm.economy == null:
		return 0.0
	if not farm.economy.has_method("get_resource"):
		return 0.0
	return float(farm.economy.get_resource("🦅"))


static func _eagle_short() -> bool:
	# No economy read → treat as short so Forest 🦅 still names.
	return _eagle_have() < 21.0


static func _eagle_gather_line() -> String:
	# Wave 25 earnest: Captain R refused 21🦅 with 0 on hand. Same walk as
	# sprouts: Forest, Ace, the 🦅 plot (H is 🦅🐇). Do not discover for them.
	if _in_icon_submenu() or _menu_open():
		return "▸ ESC closes"
	if _sim_paused():
		return "▸ [F] Play"
	# w58: Forest↔Village ping-pong. Gather 🦅 costs 🧺, so Village is
	# the live beat — do not name Forest until the wallet can cash Q.
	# w156: only while lantern_door is minted (Act 0 is not a 🧺 walk).
	if lantern_well_live():
		return _basket_walk_line()
	var have := int(_eagle_have())
	var need := "🦅 %d/21" % have
	var cross := _cross_to("StarterForest")
	if cross != "":
		return cross + " for " + need
	var wearing := str(ToolConfig.get_current_frame())
	if wearing != ToolConfig.FRAME_ACE:
		return "▸ [8] Ace for " + need
	var want := _glyph_plot_key("🦅", "StarterForest")
	# w60: banner needed 🦅×21 with no gather key. H is 🦅🐇.
	if want == "":
		want = "H"
	var focused := _focused_col()
	var token := ";" if want == ";" else want.to_upper()
	var want_col := PLOT_HOMEROW.find(token) if want != "" else -1
	if want != "" and focused != want_col:
		return "▸ [%s] for %s" % [want, need]
	# w157: R measured 🦅🐇 then banner named [F] Explore; F cleared the
	# strike. Harvest beats re-explore.
	if _plot_measured(focused):
		var got := _measured_glyph(focused)
		if "🦅" in got:
			return "▸ [Q] gather 🦅 (%d/21)" % have
		# w160-r2: 🦅🐇 collapsed to 🐇, banner named [Q] take 🐇 as the
		# door, 🧺 drained 19→15, wallet stuck 18/21. A miss is not the door.
		if got != "":
			# w180 tap-lamb: ActionBtn_Q is Gather. "miss 🐇" still
			# harvested rabbits. Clear the plot, then Strike for 🦅.
			return "▸ [Q] clear %s" % got
		return "▸ [Q] gather"
	if not _plot_bound(focused):
		if ace_f_would_explore():
			return "▸ [F] Explore for " + need
		return "▸ [%s] for %s" % [want, need]
	if not _plot_measured(focused):
		return "▸ [R] Strike for " + need
	return "▸ [Q] gather"


static func _discover_walk_line() -> String:
	# Captain R is Add Biome. Hint F=compass was a lie (Captain E is Compass,
	# F is Play). Gather 🦅 first. Do not discover for them.
	# lantern_door: slots full made ▸ still [R] with no named cull.
	# w52 literalist: slots full still printed [R] Add Biome — name the cull.
	if hold_lamp_live() or teaching_claim_live():
		return _hold_lamp_walk_line()
	if lantern_bridge_live():
		return _plant_walk_line()
	if knot_live():
		return _knot_walk_line()
	if _is_spinor_ask(_best_objective()) or _is_spinor_ask(_banner_quest()):
		return _spinor_walk_line()
	if sixteen_live():
		return _sixteen_walk_line()
	# w177: after 16 words, Captain Add Biome is not the live door.
	# w190: Wind Twice / Ask the Loop are already in the quest ledger as
	# completed; Arc is empty until edge_of_the_enclave fires. The walk is
	# BloodLedger Incorporate (ledger_opens), not an empty Arc tab.
	if _sig_count() >= 16 and not sixteen_live():
		var ledger := _ledger_walk_line()
		if ledger != "":
			return ledger
		return "▸ [X] then Arc [I]"
	if _eagle_short():
		return _eagle_gather_line()
	if _in_icon_submenu():
		return "▸ ESC closes"
	var room := _wrong_room_line("field")
	if room != "":
		return room
	if _slots_full():
		return _cull_walk_line()
	var wearing := str(ToolConfig.get_current_frame())
	if wearing != ToolConfig.FRAME_CAPTAIN:
		# w181 tap-lamb: banner [7] with chips only Icon/Ace/Druid.
		if not is_hat_visible(ToolConfig.FRAME_CAPTAIN):
			if _eagle_short():
				return _eagle_gather_line()
			return "▸ [8] Ace"
		return "▸ [7] Captain"
	var cull := _cull_walk_line()
	if cull != "":
		return cull
	var want := _pressured_discover_name()
	if want == "" and _flag_fired("the_knot") and _sig_count() >= 13:
		want = "BloodLedger"
	if want != "":
		return "▸ [R] Add Biome — %s" % want
	return "▸ [R] Add Biome"


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
	# Empty when slots are open so discover can name Add Biome.
	if not _slots_full():
		return ""
	if _in_icon_submenu() or _menu_open():
		return "▸ ESC closes"
	var qii = _instrument_input()
	if qii != null and qii.has_method("has_pending_confirm") and qii.has_pending_confirm():
		var label := str(qii.pending_confirm_label()) if qii.has_method("pending_confirm_label") else "cull"
		if label == "":
			label = "cull"
		return "▸ [F] confirm %s" % label
	var want := _named_cull_target()
	if want == "":
		return "▸ slots full — no named cull"
	var wearing := str(ToolConfig.get_current_frame())
	if wearing != ToolConfig.FRAME_CAPTAIN:
		return "▸ [7] Captain — cull %s" % want
	var cross := _cross_to(want)
	if cross != "":
		return cross
	return "▸ [Q] culls %s" % want


static func slots_full_refusal() -> String:
	# Captain-R Add Biome when the spindle is full. Name the cull, not a dead [R].
	var rest := _cull_walk_line().replace("▸ ", "").strip_edges()
	if rest == "" or rest == "ESC closes":
		return "Biome slots full"
	return "slots full — %s" % rest


static func _pressured_discover_name() -> String:
	# w53: banner said Lamplighters (faction) with no picker; Add Biome
	# spent 🦅 on Woodlot / VolcanicWorlds / RevolutionSquare.
	# w187: after cull, do not name last_removed — that redraw crashes Godot.
	var farm = _active_farm()
	if farm == null:
		return ""
	var of = farm.get_node_or_null("/root/ObservationFrame")
	if of == null or not of.has_method("get_unexplored_biomes"):
		return ""
	var skip := str(farm.last_removed_biome) if "last_removed_biome" in farm else ""
	var pool: Array = []
	for raw in of.get_unexplored_biomes():
		if str(raw) != skip:
			pool.append(raw)
	return str(BiomeDiscoveryForecastService.first_pressured(farm, pool))


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
	# Carry Water is a Hearth kitchen stall. Spring Market is Wildwood 🌿.
	if str(q.get("category", "")) == "ARC" \
			and "Hearth" in str(q.get("faction", "")):
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
			if _menu_open() and "Abandon" not in short:
				return "▸ ESC closes"
			if _menu_open() and "Abandon" in short:
				return short.replace("▸ [C] then ", "▸ ")
			return short
	if not _menu_open():
		# C opens the room that has work. Empty hands → Market pickup;
		# a held fill stall → Commitments deliver. Name the next key.
		if board != null and board.has_method("held_fill_for"):
			var held = board.held_fill_for(str(q.get("faction", "")).strip_edges())
			if held is Dictionary and not held.is_empty():
				var verb := QuestBoard.VERB_CLAIM if str(held.get("status", "")).to_lower() == "ready" else QuestBoard.VERB_DELIVER
				return "▸ [C] then %s" % ToolConfig.cue("R", verb)
		return "▸ [C] then Market [Y]"
	if board != null and board.has_method("board_walk_cue"):
		var cue := str(board.board_walk_cue(q)).strip_edges()
		if cue != "":
			return cue
	return "▸ Market [Y] picks up"


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


## True when a menu is up that is NOT the room this ask is done in.
## `home` is "field" (any overlay is off-track), "board" (C is the room),
## or "arc" (X is the room). Wandered-off toasts name the door back —
## never the in-room verb.
static func _wrong_room_line(home: String = "field") -> String:
	if _in_icon_submenu() and home != "icon_picker":
		return "▸ ESC closes"
	if not _menu_open():
		return ""
	if home == "board":
		var ml := Engine.get_main_loop()
		if ml is SceneTree:
			var shells := (ml as SceneTree).get_nodes_in_group("player_shell")
			if not shells.is_empty():
				var shell = shells[0]
				if shell != null and ("overlay_manager" in shell) and shell.overlay_manager != null:
					var om = shell.overlay_manager
					if om.has_method("is_event_home_open") and bool(om.is_event_home_open("board")):
						return ""
		return "▸ ESC closes"
	if home == "arc":
		var ml2 := Engine.get_main_loop()
		if ml2 is SceneTree:
			var shells2 := (ml2 as SceneTree).get_nodes_in_group("player_shell")
			if not shells2.is_empty():
				var shell2 = shells2[0]
				if shell2 != null and ("overlay_manager" in shell2) and shell2.overlay_manager != null:
					var om2 = shell2.overlay_manager
					if om2.has_method("is_event_home_open") and bool(om2.is_event_home_open("arc")):
						return ""
		return "▸ ESC closes"
	if home == "map":
		if _overlay_open("map_meta"):
			return ""
		return "▸ ESC closes"
	return "▸ ESC closes"


static func _overlay_stack_open() -> bool:
	var ml := Engine.get_main_loop()
	if not (ml is SceneTree):
		return false
	var tree := ml as SceneTree
	var shell: Node = null
	var shells := tree.get_nodes_in_group("player_shell")
	if not shells.is_empty():
		shell = shells[0]
	if shell == null and tree.root != null:
		shell = tree.root.get_node_or_null("/root/FarmView/PlayerShell")
	if shell == null or not ("overlay_manager" in shell) or shell.overlay_manager == null:
		return false
	var om = shell.overlay_manager
	return om.has_method("is_overlay_active") and bool(om.is_overlay_active())


static func _menu_open() -> bool:
	# Wave 5: find_child("OverlayManager") missed the runtime instance
	# (added in code, not a scene child). PlayerShell lives in group
	# "player_shell"; its overlay_manager knows the stack.
	var ml := Engine.get_main_loop()
	if not (ml is SceneTree):
		return false
	var tree := ml as SceneTree
	var shell: Node = null
	var shells := tree.get_nodes_in_group("player_shell")
	if not shells.is_empty():
		shell = shells[0]
	if shell == null and tree.root != null:
		shell = tree.root.get_node_or_null("/root/FarmView/PlayerShell")
	if shell == null or not ("overlay_manager" in shell) or shell.overlay_manager == null:
		return false
	var om = shell.overlay_manager
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
		# Active arc quests only — arc OFFERS need the X→I acknowledgement first.
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
		route = "commitments"
	var line := ("🔒 %s unlocks further down Act 0 — now: %s" % [what, obj]) if what != "" \
			else ("🔒 not yet — now: %s" % obj)
	var shell := _shell()
	if shell != null and shell.has_method("show_hint"):
		shell.show_hint(line, 2, "", route)
