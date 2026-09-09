class_name IntroVoice
extends RefCounted

## ONE authority for the first-minute voice: welcome, the first toast, and
## the Arc postcard. WelcomeOverlay, PlayerEventBridge, and ControlsOverlay
## compose from here so the banner, the toast, and the Arc featured door
## cannot name three different first verbs.
##
## Law: the face speaks story. Physics (formula, act numbers, 0.00/0.85)
## lives behind E / the expanded toast, never on the default card.

const UIProgression = preload("res://UI/Core/UIProgression.gd")
const PredicateGloss = preload("res://Core/Quests/PredicateGloss.gd")

const TAP_FOR_MORE := "tap for more"
const TAP_AGAIN_ARC := "tap again to open the Arc"

## Tutorial-step id → a short door title. Body/arc_beat remain the prose;
## this is only the bold beat name on the toast and the NOW card.
const TEACHES_TITLE := {
	"core_loop": "The Demos sleeps",
	"contracts": "The mill is buying",
	"wayfinding": "Past the hedge",
	"superposition": "Both poles at once",
	"entanglement": "The loom",
	"reap_season": "First Harvest",
}


static func welcome_title() -> String:
	return "You are The Demos"


static func welcome_fiction() -> PackedStringArray:
	return PackedStringArray([
		"A people learning the quantum language of your own ground.",
		"Wheat and people — 🌾 / 👥 — the axis the island turns on.",
		"The factions past the hedge keep older words. They teach the ones who keep their contracts.",
	])


static func welcome_verbs() -> Array:
	# Three cards. Story first, how second, key as an accelerator.
	return [
		{
			"verb": "Explore",
			"key": "F",
			"story": "Wake a sleeping plot.",
			"how": "tap it  ·  costs 🍞",
		},
		{
			"verb": "Strike",
			"key": "R",
			"story": "Lock an answer in.",
			"how": "tap the bubble  ·  costs 👥",
		},
		{
			"verb": "Gather",
			"key": "Q",
			"story": "Take what collapse leaves.",
			"how": "tap the frozen bubble  ·  costs 🧺",
		},
	]


static func welcome_footer() -> String:
	return "The gold banner names your one live task. Tap anywhere (or press F) to begin."


## True when this offer is an auto-accepted tutorial step — the player
## cannot Accept it; the bar is already the teacher. The toast must not
## say "tap here to accept".
static func is_auto_tutorial(quest: Dictionary, qm = null) -> bool:
	if qm != null and qm.has_method("tutorial_auto_advances"):
		return bool(qm.tutorial_auto_advances(quest))
	if str(quest.get("category", "")) != "TUTORIAL":
		return false
	var preds = quest.get("state_predicates", [])
	return preds is Array and not preds.is_empty()


static func quest_title(quest: Dictionary) -> String:
	var teaches := str(quest.get("tutorial_teaches", "")).strip_edges()
	if TEACHES_TITLE.has(teaches):
		return str(TEACHES_TITLE[teaches])
	var body := str(quest.get("body", "")).strip_edges()
	if body != "":
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


## PlayerEventBridge composes the first (and later) offer toasts from this.
## Market offers stay log-only (importance 1). Tutorial/arc offers are gold
## story beats; auto-accepted steps never say "accept".
static func toast_for_offer(quest: Dictionary, qm = null) -> Dictionary:
	var category := str(quest.get("category", ""))
	var is_arc := category == "TUTORIAL" or str(quest.get("source_flag", "")).strip_edges() != ""
	var title := quest_title(quest)
	var hook := quest_hook(quest, 180)
	var detail := quest_detail(quest)
	if is_arc:
		if is_auto_tutorial(quest, qm):
			if hook == "":
				hook = "The country is waiting."
			var msg := "🌾 [b]%s[/b]\n%s" % [title, hook]
			if detail == "":
				detail = "The gold banner names the next tap. " + TAP_FOR_MORE.capitalize() + "."
			return {
				"message": msg,
				"detail": detail,
				"importance": 3,
				"icon": "🌾",
				"path": "Q",
				"route": "arc",
			}
		# A real accept-door (contracts step, later arc offers).
		if hook == "":
			hook = "A new offer is waiting on the Arc."
		var accept_line := "Tap here to read & accept — or %s." % UIProgression.route_accept()
		if detail != "":
			detail = "%s\n%s" % [detail, accept_line]
		else:
			detail = accept_line
		return {
			"message": "📜 [b]%s[/b]\n%s" % [title, hook],
			"detail": detail,
			"importance": 3,
			"icon": "📜",
			"path": "Q",
			"route": "arc",
		}
	# Market: log only. Do not say "here" — there is no here to tap.
	var fac := str(quest.get("faction", "")).strip_edges()
	if fac == "":
		fac = "the market"
	return {
		"message": "📜 New offer from %s — to read & accept: %s" % [fac, UIProgression.route_accept()],
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
		"asks": [str(quest.get("tutorial_hint", quest.get("hint", ""))).strip_edges()],
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
