class_name StoryAtlas
extends RefCounted

## The ONE authority for the campaign's act/chapter/lane structure — pure
## static functions over story-flag data, no state, no scene access. Lives in
## Core/Story so both Core consumers (PlayerEventBridge, RuntimeMount's
## postcard) and UI consumers (ActFilament, ControlsOverlay's chapter header)
## derive the same answers from the same rules.
##
## Everything here is DERIVED from data that already exists (a flag's `act`
## and `display_name`, the optional `branch_group` field) — no parallel
## hand-authored tables to drift.

const LANE_PREFIXES := {
	"What Survives": "survives",
	"What Connects": "connects",
	"What Fades": "fades",
	"What Turns": "turns",
}


## The Demos' four-movement spine, keyed off an act number (single source = act).
## (Moved verbatim from ControlsOverlay so Core-side consumers can speak it.)
static func chapter_for_act(act: int) -> String:
	if act <= 1:
		return "Chapter I — Vocabulary"
	elif act <= 3:
		return "Chapter II — The Village"
	elif act == 4:
		return "Chapter III — The Island & Its People"
	return "Chapter IV — The Empire & The Escape"


## Parse a flag's display_name for its narrative lane. 22 flags carry
## "What Survives/Connects/Fades <numeral> — <title>" prefixes; everything
## else is spine. Returns {"lane": "survives"|"connects"|"fades"|"",
## "numeral": "I".."V"|""}. Pinned by test_story_flags_lint so a display_name
## rename fails loudly instead of silently dropping a flag off its lane.
static func lane_of(display_name: String) -> Dictionary:
	for prefix in LANE_PREFIXES:
		if display_name.begins_with(prefix):
			var rest := display_name.substr(prefix.length()).strip_edges()
			var numeral := rest.split(" ")[0].strip_edges() if rest != "" else ""
			if not numeral in ["I", "II", "III", "IV", "V"]:
				numeral = ""
			return {"lane": LANE_PREFIXES[prefix], "numeral": numeral}
	return {"lane": "", "numeral": ""}


## Short display tag for a lane row ("Survives III"), "" for spine flags.
static func lane_tag(display_name: String) -> String:
	var info := lane_of(display_name)
	if info["lane"] == "":
		return ""
	var word: String = str(info["lane"]).capitalize()
	return word if info["numeral"] == "" else "%s %s" % [word, info["numeral"]]


## The player's current act: the highest N such that every act 0..N (that
## exists in the flag data) has at least one fired flag — a CONTIGUOUS prefix.
## Max-act-fired inflates: act-5's second_loop requires only an act-1 flag, so
## a player who closes a second loop in act 2 would read as "act 5" under a
## max rule (the Arc chapter header had exactly this bug).
static func current_act(fired: Dictionary, all_flags: Array) -> int:
	var acts_present := {}
	var acts_fired := {}
	for flag in all_flags:
		if not (flag is Dictionary):
			continue
		var act := int(flag.get("act", 0))
		acts_present[act] = true
		if fired.has(str(flag.get("id", ""))):
			acts_fired[act] = true
	var current := 0
	var sorted_acts := acts_present.keys()
	sorted_acts.sort()
	for act in sorted_acts:
		if acts_fired.has(act):
			current = int(act)
		else:
			break
	return current


## Is an act COMPLETE? Every flag of that act with no `branch_group` fired,
## AND at least one member fired per branch group present in the act. Branch
## groups are mutually-optional alternatives (the five village_path_* doors
## share "village_door") — requiring ALL of them made the act-5 postcard
## unreachable on any normal playthrough.
static func act_complete(act: int, fired: Dictionary, all_flags: Array) -> bool:
	var saw_any := false
	var group_satisfied := {}   # branch_group -> bool (any member fired)
	for flag in all_flags:
		if not (flag is Dictionary) or int(flag.get("act", -1)) != act:
			continue
		saw_any = true
		var flag_fired: bool = fired.has(str(flag.get("id", "")))
		var group := str(flag.get("branch_group", ""))
		if group == "":
			if not flag_fired:
				return false
		else:
			group_satisfied[group] = bool(group_satisfied.get(group, false)) or flag_fired
	if not saw_any:
		return false
	for group in group_satisfied:
		if not group_satisfied[group]:
			return false
	return true


## Cut prose at a sentence boundary when one exists inside the budget, else a
## word boundary — never a mid-word stump. (The rule _short_line proved on the
## objective banner, shared here for beat toasts.)
static func sentence_cut(text: String, max_chars: int) -> String:
	var t := text.strip_edges().replace("\n", " ")
	if t.length() <= max_chars:
		return t
	var head := t.substr(0, max_chars + 30)
	var dot := head.rfind(". ", max_chars + 29)
	if dot >= 20:
		return head.substr(0, dot + 1)
	var cut := t.substr(0, max_chars - 1)
	var sp := cut.rfind(" ")
	return (cut.substr(0, sp) if sp >= 20 else cut).strip_edges() + "…"
