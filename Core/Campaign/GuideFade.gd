extends RefCounted
const UIProgression = preload("res://UI/Core/UIProgression.gd")
## When the ▸ banner speaks (owner call 2026-11-09). Through the tutorial it
## always does. After that it waits: it hides while the player is making
## progress and comes back once they have gone `fade_after_s[act]` seconds
## without any — actions don't count, only progress (a flag fired, a quest
## accepted, readied or claimed). The wait grows with the share of the story
## told, so by the end the banner only turns up after minutes of being lost.
##
## Modes: "always" (every headless seat by default: strict followers and
## playtest bots read the banner every look), "fade" (headed default),
## "off". SW_GUIDE_MODE overrides the default; mode_override overrides both.

const DEFAULT_FADE_AFTER_S: Array = [15, 30, 45, 60, 90, 120, 180, 240, 300]

static var mode_override: String = ""
static var _sig: String = ""
static var _since_ms: int = 0


static func mode() -> String:
	if mode_override in ["always", "fade", "off"]:
		return mode_override
	var env := OS.get_environment("SW_GUIDE_MODE").strip_edges().to_lower()
	if env in ["always", "fade", "off"]:
		return env
	return "always" if RuntimeEnv.is_headless() else "fade"


## True when the banner should show its line right now.
static func speaks(qm, farm) -> bool:
	var m := mode()
	if m == "always":
		return true
	if m == "off":
		return false
	var now := Time.get_ticks_msec()
	var sig := _signature(qm, farm)
	if sig != _sig:
		_sig = sig
		_since_ms = now
	var wait := delay_s(qm, farm)
	return wait <= 0.0 or now - _since_ms >= int(wait * 1000.0)


## Seconds of no progress before the banner returns, for where the player is.
static func delay_s(qm, farm) -> float:
	if UIProgression.current_tutorial_step() != UIProgression.NO_TUTORIAL_SENTINEL:
		return 0.0
	var table = CampaignRuntime.guide().get("fade_after_s", DEFAULT_FADE_AFTER_S)
	if not (table is Array) or table.is_empty():
		table = DEFAULT_FADE_AFTER_S
	var idx := int(floor(progress(qm, farm) * float(table.size() - 1) + 0.0001))
	return float(table[clampi(idx, 0, table.size() - 1)])


## Share of the story flags fired, 0..1. Campaign act numbers restart per
## campaign (Lanternfall's act 1 comes after The Demos' act 6), so the whole
## story's fired fraction is the one monotonic "how far along" there is.
static func progress(qm, farm) -> float:
	if qm == null or farm == null or not ("story_flags_fired" in farm) or not ("_story_flags" in qm):
		return 0.0
	var total := 0
	var fired := 0
	for f in qm._story_flags:
		if f is Dictionary:
			total += 1
			if farm.story_flags_fired.has(str(f.get("id", ""))):
				fired += 1
	return float(fired) / float(maxi(total, 1))


static func _signature(qm, farm) -> String:
	var flags: int = farm.story_flags_fired.size() if farm != null and "story_flags_fired" in farm else 0
	var done: int = qm.completed_quests.size() if qm != null and "completed_quests" in qm else 0
	var held := 0
	var ready := 0
	if qm != null and "active_quests" in qm:
		held = qm.active_quests.size()
		for q in qm.active_quests.values():
			if q is Dictionary and str(q.get("status", "")) == "ready":
				ready += 1
	return "%d|%d|%d|%d" % [flags, done, held, ready]
