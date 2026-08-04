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

## Hat → the story flag that surfaces it ("" = always visible).
## Starter kit is Ace + Icon + Druid — exactly what Act-0 teaches.
## Spark is the open-regime (Lindblad) verb: useless inside the enclave, so it
## surfaces when the wet country opens.
const HAT_UNLOCK_FLAGS: Dictionary = {
	ToolConfig.FRAME_ACE: "",
	ToolConfig.FRAME_ICON: "",
	ToolConfig.FRAME_DRUID: "",
	ToolConfig.FRAME_OPERATOR: "forest_listener",
	ToolConfig.FRAME_MERCHANT: "village_stirs",
	# woodlot_door, not island_lives: the proven campaign road discovers the
	# Woodlot (Captain's biome) right after the woodlot_door beat — island_lives
	# is the ENDGAME flag and would lock the hat for the whole middle game.
	ToolConfig.FRAME_CAPTAIN: "woodlot_door",
	ToolConfig.FRAME_SPARK: "edge_of_the_enclave",
}

## Menu id (MenuRegistry) → surfacing flag ("" = always).
const MENU_UNLOCK_FLAGS: Dictionary = {
	"play": "",
	"system": "",
	"controls": "",
	"quests": "",
	"atlas": "first_breath",
	"biome_detail": "forest_evolving",
	"inspector": "village_stirs",
	"map_meta": "village_stirs",
	"neighborhood_graph": "village_stirs",
}


static func _flags() -> Dictionary:
	var gsm = Engine.get_main_loop().root.get_node_or_null("GameStateManager") if Engine.get_main_loop() else null
	var farm = gsm.get_active_farm() if (gsm and gsm.has_method("get_active_farm")) else null
	if farm != null and is_instance_valid(farm) and "story_flags_fired" in farm:
		return farm.story_flags_fired
	# No farm (visual tests, early boot): show everything — fail open.
	return {}


static func _unlocked(flag: String, flags: Dictionary) -> bool:
	return flag == "" or flags.has(flag)


static func is_hat_visible(frame_name: String) -> bool:
	var flags := _flags()
	if flags.is_empty() and _no_farm():
		return true
	return _unlocked(str(HAT_UNLOCK_FLAGS.get(frame_name, "")), flags)


static func is_menu_visible(menu_id: String) -> bool:
	var flags := _flags()
	if flags.is_empty() and _no_farm():
		return true
	return _unlocked(str(MENU_UNLOCK_FLAGS.get(menu_id, "")), flags)


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
## tutorial (steps 0-6) without picking a real step to unlock at — comfortably
## above the highest real step (6), and visually distinct from
## NO_TUTORIAL_SENTINEL so a reader can tell "locked all of Act 0" apart from
## "no signal, fully open."
const VERB_LOCKED_FOR_ACT0 := 90


## Which Act-0 tutorial step is currently live — the same active-TUTORIAL-quest
## lookup _objective_rank() already does (reused, not reinvented). Returns
## NO_TUTORIAL_SENTINEL when there's no active TUTORIAL quest to read.
static func current_tutorial_step() -> int:
	var qm := _quest_manager()
	if qm == null or not ("active_quests" in qm):
		return NO_TUTORIAL_SENTINEL
	for q in qm.active_quests.values():
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
	# same hint, never locked.
	"ace:F": 0,
	"ace:R": 0,
	"ace:Q": 0,

	# Step 1 (vocabulary): Icon F (track berry-phase), R (incorporate icon).
	# icon:Q (remove_icon, destructive) and icon:E (inspect) stay locked for
	# the rest of Act 0 — explicit, not omitted.
	"icon:F": 1,
	"icon:R": 1,
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
# live objective; this puts it in screen text. Returns "" when there is
# nothing to point at (island_lives fired = late-game chrome stays clean,
# or no farm/quest manager yet).
# ============================================================================

const OBJECTIVE_MAX_CHARS := 70
const OFFER_LINE := "📜 new offer — X then I (Arc)"
const REDIRECT_FALLBACK := "follow the Arc (X → I)"


static func objective_text() -> String:
	var flags := _flags()
	if flags.has("island_lives"):
		return ""
	var qm := _quest_manager()
	if qm == null or not ("active_quests" in qm):
		return ""
	var act_by_flag := _act_by_flag(qm)
	var best: Dictionary = {}
	var best_rank := 0x7FFFFFFF
	# Candidate pool: ACTIVE tutorial/arc quests, plus tutorial-chain OFFERS.
	# Predicate-driven tutorial steps auto-accept (QuestManager), so they live in
	# active_quests; the contracts step (5) still waits in story_offers for a real
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
	if not best.is_empty():
		return _decorate_objective(best)
	if ("story_offers" in qm) and not qm.story_offers.is_empty():
		return OFFER_LINE
	return ""


## Lead the one live objective with the KEY it needs, when it needs one. The two moments a new
## player stalls (both survived the old data-shortcut probe): an OFFER awaiting the R-accept it
## was never taught (the contracts step, every arc offer), and a quest that has gone READY but
## sits unclaimed. Naming the key + the surface is the whole fix. In-progress quests keep just
## their hint — the bar is already teaching.
static func _decorate_objective(q: Dictionary) -> String:
	var status := str(q.get("status", ""))
	if status == Quest.STATUS_STORY:
		return "▸ press R to accept it on the Arc tab (X → I)"
	if status == "ready":
		return "▸ press R to claim it in Commitments (C → U)"
	return _short_line(q)


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


static func _short_line(q: Dictionary) -> String:
	var t := str(q.get("tutorial_hint", "")).strip_edges()
	if t == "":
		t = str(q.get("hint", "")).strip_edges()
	if t == "":
		t = str(q.get("body", "")).strip_edges()
	t = t.replace("\n", " ")
	if t.length() > OBJECTIVE_MAX_CHARS:
		# Cut at a SENTENCE boundary when one exists, else a word boundary —
		# a mid-clause cut ("…or just…") read as a broken instruction to the
		# round-6 literalist. A complete short sentence beats a longer stump.
		var head := t.substr(0, OBJECTIVE_MAX_CHARS + 30)
		var dot := head.rfind(". ", OBJECTIVE_MAX_CHARS + 29)
		if dot >= 20:
			t = head.substr(0, dot + 1)
		else:
			var cut := t.substr(0, OBJECTIVE_MAX_CHARS - 1)
			var sp := cut.rfind(" ")
			t = (cut.substr(0, sp) if sp >= 20 else cut).strip_edges() + "…"
	return t


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


# ============================================================================
# THE REDIRECT TOAST — what a locked key says instead of acting. Rate-limited
# to one toast per 3s no matter how fast keys are mashed (anti-gating law:
# speak and point, never flood).
# ============================================================================

const REDIRECT_COOLDOWN_MS := 3000
static var _last_redirect_ms: int = -REDIRECT_COOLDOWN_MS


static func redirect_locked() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_redirect_ms < REDIRECT_COOLDOWN_MS:
		return
	_last_redirect_ms = now
	var obj := objective_text()
	if obj == "":
		obj = REDIRECT_FALLBACK
	var shell := _shell()
	if shell != null and shell.has_method("show_hint"):
		shell.show_hint("🔒 not yet — now: %s" % obj, 2)
