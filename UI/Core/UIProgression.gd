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


## Which Act-0 tutorial step is currently live — the same active-TUTORIAL-quest
## lookup _objective_rank() already does (reused, not reinvented). Also scans
## story_offers: the manual contracts step waits there for a real R-accept,
## and while it did, this used to return the sentinel — the whole funnel
## (menus, verbs, escape tabs) briefly believed Act 0 was over, then slammed
## shut again on accept. Returns NO_TUTORIAL_SENTINEL only when no TUTORIAL
## quest is live in either pool.
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
const OFFER_LINE := "📜 new offer — tap the gold banner for the Arc [X→I]"
const REDIRECT_FALLBACK := "follow the Arc — tap the gold banner [X→I]"


## One spelling per door — every surface that names a route composes from
## these. The ready-toast and the objective banner used to spell the claim
## route two ways ("C board" vs "Commitments (C → U)") and the older one sent
## players to the wrong screen; PlayerEventBridge preloads this script so the
## drift can't reopen. Voice rule: the click comes first, keys ride as
## bracketed accelerators — every action named here has a real hitbox
## (docs/MOUSE_PARITY_AUDIT.md: zero keyboard-only gaps), so copy that only
## says "press R" lies by omission to a mouse-and-trackpad player.
static func route_accept() -> String:
	return "tap the gold banner [X→I], its row, then Accept [R]"


static func route_claim() -> String:
	return "tap 📋 [C], Commitments [U], its row twice (Claim [R])"


## The single ranked winning quest/offer — shared by objective_text() (the
## text banner) and objective_target_key() (the visual spotlight), so both
## always agree on what "the one live objective" is. {} when there's none.
static func _best_objective() -> Dictionary:
	var qm := _quest_manager()
	if qm == null or not ("active_quests" in qm):
		return {}
	var act_by_flag := _act_by_flag(qm)
	var best: Dictionary = {}
	var best_rank := 0x7FFFFFFF
	# Candidate pool: ACTIVE tutorial/arc quests, plus tutorial-chain OFFERS.
	# Predicate-driven tutorial steps auto-accept (QuestManager), so they live in
	# active_quests; the contracts step (1) still waits in story_offers for a real
	# R-accept, and it IS the live objective then. Market contracts are the ContractChip's job.
	var pools: Array = [qm.active_quests.values()]
	if "story_offers" in qm:
		pools.append(qm.story_offers.values())
	for pool in pools:
		for q in pool:
			if not (q is Dictionary):
				continue
			var rank := _objective_rank(q, act_by_flag)
			if rank < best_rank:
				best_rank = rank
				best = q
	return best


static func objective_text() -> String:
	var qm := _quest_manager()
	if qm == null or not ("active_quests" in qm):
		return ""
	var best := _best_objective()
	if not best.is_empty():
		return _decorate_objective(best)
	if ("story_offers" in qm) and not qm.story_offers.is_empty():
		return OFFER_LINE
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
	var best := _best_objective()
	if best.is_empty():
		# Mirror objective_text's OFFER_LINE fallback: an arc offer waiting
		# with no active quest means the next key IS X — the banner says
		# "X then I" and the spotlight must pulse the same key, not go dark.
		var qm := _quest_manager()
		if qm != null and ("story_offers" in qm) and not qm.story_offers.is_empty():
			return {"key": "X", "biome": ""}
		return {}
	var status := str(best.get("status", ""))
	if status == Quest.STATUS_STORY:
		return {"key": "X", "biome": ""}
	if status == "ready":
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
	if status == Quest.STATUS_STORY:
		return "▸ to accept: " + route_accept()
	if status == "ready":
		return "▸ to claim: " + route_claim()
	var travel := _travel_line(q)
	if travel != "":
		return travel
	return _short_line(q)


## A tutorial step whose mechanic lives in another biome has exactly one honest
## next action: go there. objective_target() already knew this — it pulses the
## biome tab before the verb chip — but the TEXT did not, so the banner kept
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
		# No tab reaches it yet. Stay silent rather than name a key that isn't
		# there — a lie costs more than the missing nudge.
		return ""
	return "▸ tap the %s tab to cross to %s — this step happens there" % [key, want]


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
	# ARC: lead with the live unsatisfied predicate gloss (number + verb).
	# Authored hints are paragraphs; they truncate into a first sentence that
	# names a hat and drops the lever (#515 / island_stops_asking).
	var t := ""
	if str(q.get("category", "")) == "ARC":
		t = _first_unsatisfied_gloss(q)
	if t == "":
		t = str(q.get("tutorial_hint", "")).strip_edges()
	if t == "":
		t = str(q.get("hint", "")).strip_edges()
	if t == "":
		t = str(q.get("body", "")).strip_edges()
	return _clip_banner(t.replace("\n", " "))


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
