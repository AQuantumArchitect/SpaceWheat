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
	# woodlot_door, not island_lives: the proven campaign road discovers the
	# Woodlot (Captain's biome) right after the woodlot_door beat — island_lives
	# fires mid-campaign (act 4 of 8) and would lock the hat for the whole
	# early-middle game.
	ToolConfig.FRAME_CAPTAIN: "woodlot_door",
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
	if str(q.get("status", "")) == "ready" or _is_board_ask(q):
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
	# lantern_door: authored [7] Captain [R] outran the 🦅 gather walk.
	if _is_discover_ask(best) and _eagle_short():
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


static func objective_text() -> String:
	var qm := _quest_manager()
	if qm == null or not ("active_quests" in qm):
		return ""
	var best := _banner_quest()
	# Wave 24 literalist: gathered 🌱 3→21, then chrome-only. Unsigned plant
	# is STORY — hiding the banner after the gather walk ate Icon [5].
	# Plant is the live beat whether or not they have signed the Arc.
	if _is_plant_ask(best):
		return _plant_walk_line()
	if _is_discover_ask(best):
		return _discover_walk_line()
	# Wave first_breath: unsigned berry door painted Farm/System/Story/Board
	# + QERF with no quest line. Field walk is the live ask, like plant.
	if _is_berry_ask(best):
		return _berry_walk_line()
	# Wave mill_wakes: unsigned Hold Commerce painted Village plant, not
	# Market. Board walk is the live ask, like plant/berry.
	if _is_board_ask(best):
		return _board_walk_line(best)
	# Banner tracks accepted work only. Unaccepted offers live on the Arc —
	# a gold "go accept this" chip before the door is taken is a second
	# helping system. Hide until the player actually holds the quest.
	if best.is_empty() or str(best.get("status", "")) == Quest.STATUS_STORY:
		return ""
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
		var coast := _named_discover_target()
		if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_CAPTAIN:
			return {"key": cap, "hat": cap, "biome": coast}
		return {"key": "R", "hat": cap, "biome": coast}
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
	if status == Quest.STATUS_STORY:
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
	# a Millwright delivery. Name Accept / Refresh / Deliver from the board.
	if _is_board_ask(q):
		var walk := _board_walk_line(q)
		if walk != "":
			return walk
	if _is_plant_ask(q):
		return _plant_walk_line()
	if _is_discover_ask(q):
		return _discover_walk_line()
	if _is_berry_ask(q):
		return _berry_walk_line(q)
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
	for pred in q.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		if str(pred.get("type", "")) != "biome_evolving":
			continue
		var b := str(pred.get("biome", "")).strip_edges()
		if b != "" and not _biome_unlocked(b):
			return true
	return false


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


static func _glyph_plot_key(glyph: String) -> String:
	# Fog-honest: name a glyph bubble only when a sighted player can read it.
	# Wave 20: Forest G is 🐺🦌 — never call that a 🌱 plot. Scout unrevealed
	# live plots (H J K L) until the glyph shows. Empty columns (;) are plant seats.
	var farm = _active_farm()
	var bname := _active_biome_name()
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
	scout_cols.sort()
	if not scout_cols.is_empty():
		return _col_key(int(scout_cols[0]))
	return ""


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
	return _plot_terminal(col) != null


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
	if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_ACE:
		return false
	if _menu_open() or _in_icon_submenu():
		return false
	var col := _focused_col()
	if col < 0:
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


static func _plant_walk_line() -> String:
	# Wave 11: "Icon hat (5)" named no bracketed key. Name [5], then [R].
	# Wave 18: name the empty-plot key; short 🌱 walks Forest, not Village Q.
	# Do not plant for them.
	if _sprout_short():
		return _sprout_gather_line()
	var wearing := str(ToolConfig.get_current_frame())
	if wearing != ToolConfig.FRAME_ICON:
		return "▸ [5] Icon, [%s] empty plot, [R] opens picker" % _empty_plot_key()
	if _in_icon_submenu():
		return "▸ [Q]/[E] pick a word (need 🌱×5 + south×13)"
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


static func _berry_walk_line(q: Dictionary = {}) -> String:
	# first_breath live door: one next key. Do not dump F / = / R / X.
	# Do not incorporate for them. Unsigned berry still paints (like plant).
	if _in_icon_submenu() or _menu_open():
		return "▸ ESC closes"
	if q.is_empty():
		q = _banner_quest()
	var want := _berry_ask_biome(q)
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
	return "▸ wait — loop ripens (~90s)"


static func _eagle_have() -> float:
	var farm = _active_farm()
	if farm == null or not ("economy" in farm) or farm.economy == null:
		return 0.0
	if not farm.economy.has_method("get_resource"):
		return 0.0
	return float(farm.economy.get_resource("🦅"))


static func _eagle_short() -> bool:
	# lantern_door: empty/unreadable wallet never named Village 🧺 [Q].
	# No farm yet is not a wallet. Mute economy is 0 eagles, so short.
	var farm = _active_farm()
	if farm == null:
		return false
	return _eagle_have() < 21.0


static func _basket_have() -> float:
	var farm = _active_farm()
	if farm == null or not ("economy" in farm) or farm.economy == null:
		return 0.0
	if not farm.economy.has_method("get_resource"):
		return 0.0
	return float(farm.economy.get_resource("🧺"))


static func _basket_short() -> bool:
	# Match pop cost: gather costs 1🧺, flat. Strike does not mint it.
	# lantern_door: mute wallet is 0🧺 — fail toward Village 🧺 [Q].
	var farm = _active_farm()
	if farm == null:
		return false
	return _basket_have() < 1.0


static func _eagle_gather_target() -> Dictionary:
	# Same walk as _eagle_gather_line: Forest rail, [8] Ace, then [R]/[Q].
	# Spotlight must name the chip, not Forest with a blank key.
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
	if not _plot_bound(focused):
		if ace_f_would_explore():
			return {"key": "F", "hat": ace, "biome": forest}
		if want != "":
			return {"key": token, "hat": ace, "biome": forest}
		return {"key": "", "hat": ace, "biome": forest}
	if not _plot_measured(focused):
		return {"key": "R", "hat": ace, "biome": forest}
	return {"key": "Q", "hat": ace, "biome": forest}


static func _basket_pay_target() -> Dictionary:
	# Same walk as _basket_pay_line: Village rail, [8] Ace, 🧺 plot, then [Q].
	# Q pays the basket. Do not spotlight Strike.
	var village := "Village"
	var ace := _hat_key_for_frame("ace")
	if _in_icon_submenu() or _menu_open():
		return {"key": "", "hat": ace, "biome": village}
	if _sim_paused():
		return {"key": "F", "hat": ace, "biome": village}
	var abm := _active_biome_manager()
	if abm != null and str(abm.get_active_biome()) != village:
		var slot := int(abm.get_slot_for_biome(village))
		var rail := str(abm.get_slot_key(slot)).to_upper() if slot >= 0 else ""
		return {"key": rail, "hat": ace, "biome": village}
	if str(ToolConfig.get_current_frame()) != ToolConfig.FRAME_ACE:
		return {"key": ace, "hat": ace, "biome": village}
	var want := _glyph_plot_key("🧺")
	var focused := _focused_col()
	var token := ";" if want == ";" else want.to_upper()
	var want_col := PLOT_HOMEROW.find(token) if want != "" else -1
	if want != "" and focused != want_col:
		return {"key": token, "hat": ace, "biome": village}
	if not _plot_bound(focused):
		if ace_f_would_explore():
			return {"key": "F", "hat": ace, "biome": village}
		if want != "":
			return {"key": token, "hat": ace, "biome": village}
		return {"key": "", "hat": ace, "biome": village}
	return {"key": "Q", "hat": ace, "biome": village}


static func _eagle_gather_line() -> String:
	# Wave 25 earnest: Captain R refused 21🦅 with 0 on hand. Same walk as
	# sprouts: Forest, Ace, the 🦅 plot (H is 🦅🐇). Do not discover for them.
	if _in_icon_submenu() or _menu_open():
		return "▸ ESC closes"
	if _sim_paused():
		return "▸ [F] Play"
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
	if not _plot_bound(focused):
		if ace_f_would_explore():
			return "▸ [F] Explore for " + need
		if want != "":
			return "▸ [%s] for %s" % [want, need]
		return "▸ pick a sleeping 🦅 plot"
	if not _plot_measured(focused):
		return "▸ [R] Strike for " + need
	var got := _measured_glyph(focused)
	if "🦅" in got:
		return "▸ [Q] gather 🦅 (%d/21)" % have
	if got != "":
		return "▸ [Q] take %s" % got
	return "▸ [Q] gather"


static func _basket_pay_line() -> String:
	# lantern_door: 🦅 gather costs 🧺. Strike costs 👥 and does not mint it.
	# Village 🧺 [Q] pays a basket. One next key. Do not gather for them.
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
	var want := _glyph_plot_key("🧺")
	var focused := _focused_col()
	var token := ";" if want == ";" else want.to_upper()
	var want_col := PLOT_HOMEROW.find(token) if want != "" else -1
	if want != "" and focused != want_col:
		return "▸ [%s] for %s" % [want, need]
	if not _plot_bound(focused):
		if ace_f_would_explore():
			return "▸ [F] Explore for " + need
		if want != "":
			return "▸ [%s] for %s" % [want, need]
		return "▸ pick a sleeping 🧺 plot"
	var got := _measured_glyph(focused)
	if "🧺" in got or got == "":
		return "▸ [Q] gather 🧺 (%d/1)" % have
	return "▸ [Q] take %s" % got


static func _named_discover_target() -> String:
	# Live biome_evolving ask that is not yet on the spindle. lantern_door
	# wants Lanternfall; the flag predicates carry no biome, so the banner
	# must read the arc quest. Do not discover for them.
	var q := _banner_quest()
	if q.is_empty() or not _is_discover_ask(q):
		return ""
	for pred in q.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		if str(pred.get("type", "")) != "biome_evolving":
			continue
		var b := str(pred.get("biome", "")).strip_edges()
		if b != "" and not _biome_unlocked(b):
			return b
	return ""


static func _discover_walk_line() -> String:
	# Captain R is Add Biome. Hint F=compass was a lie (Captain E is Compass,
	# F is Play). Gather 🦅 first. Do not discover for them.
	# lantern_door: slots full made ▸ still [R] with no named cull.
	# lantern_door: unreadable wallet is eagle-short — fail toward the gather.
	if _eagle_short():
		return _eagle_gather_line()
	if _in_icon_submenu() or _menu_open():
		return "▸ ESC closes"
	if _slots_full():
		return _cull_walk_line()
	var coast := _named_discover_target()
	var wearing := str(ToolConfig.get_current_frame())
	if wearing != ToolConfig.FRAME_CAPTAIN:
		if coast != "":
			return "▸ [7] Captain — Add Biome for %s" % coast
		return "▸ [7] Captain, [R] Add Biome"
	if coast != "":
		return "▸ [R] Add Biome — %s" % coast
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
	if _in_icon_submenu() or _menu_open():
		return "▸ ESC closes"
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


static func eagle_short_refusal() -> String:
	# Captain-R Add Biome while 🦅 short. Name the gather walk, not a dead [R].
	# lantern_door: 🧺 short is the live gate — Strike does not mint a basket.
	if _basket_short():
		return basket_short_refusal()
	if not _eagle_short():
		return ""
	var rest := _eagle_gather_line().replace("▸ ", "").strip_edges()
	if rest == "" or rest == "ESC closes":
		return "needs 21🦅"
	return "needs 21🦅 — %s" % rest


static func basket_short_refusal() -> String:
	# Ace Q / Strike / Explore while 🧺 is 0. Name Village 🧺 [Q], not Strike.
	if not _basket_short():
		return ""
	var rest := _basket_pay_line().replace("▸ ", "").strip_edges()
	if rest == "" or rest == "ESC closes":
		return "needs 🧺"
	return "needs 🧺 — %s" % rest


static func slots_full_refusal() -> String:
	# Captain-R Add Biome when the spindle is full. Name the cull, not a dead [R].
	var rest := _cull_walk_line().replace("▸ ", "").strip_edges()
	if rest == "" or rest == "ESC closes":
		return "Biome slots full"
	return "slots full — %s" % rest


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
			if _menu_open() and "Abandon" not in short:
				return "▸ ESC closes"
			if _menu_open() and "Abandon" in short:
				return short.replace("▸ [C] then ", "▸ ")
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
