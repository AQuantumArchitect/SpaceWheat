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


## Act headers come from the campaign spec (Core/Campaign/campaign.json →
## campaign_runtime.json): each campaign's acts carry their own titles, so a
## reorder re-titles the HUD with no code change. Global act numbers: the main
## campaign (The Demos) owns 0..6; the post-game campaigns share 7+ (their own
## act 1 = global 7), so a flag's own campaign/campaign_act is the precise key.
const MAIN_CAMPAIGN := "demos"
const POSTGAME_ACT_BASE := 7


static func chapter_for_act(act: int) -> String:
	if act >= POSTGAME_ACT_BASE:
		return "After the Ending"
	var title := CampaignRuntime.act_title(MAIN_CAMPAIGN, act)
	return "Act %d — %s" % [act, title] if title != "" else "Act %d" % act


## "Act 2 — Two Countries" for a compiled story flag, in its own campaign.
static func chapter_for_flag(flag: Dictionary) -> String:
	var title := str(flag.get("act_title", ""))
	var n := int(flag.get("campaign_act", flag.get("act", 0)))
	if title == "":
		return chapter_for_act(int(flag.get("act", 0)))
	return "Act %d — %s" % [n, title]


## "The Demos" / "What Fades" / "The Loom" for a compiled story flag.
static func campaign_title_for_flag(flag: Dictionary) -> String:
	var c := CampaignRuntime.campaign(str(flag.get("campaign", MAIN_CAMPAIGN)))
	return str(c.get("title", "The Demos")) if not c.is_empty() else "The Demos"


## "The Demos · Act 2 — Two Countries"; post-game campaigns still being built
## say so: "What Fades (in development) · Act 1 — Lantern Country".
static func header_for_flag(flag: Dictionary) -> String:
	var title := campaign_title_for_flag(flag)
	if CampaignRuntime.is_in_development(str(flag.get("campaign", MAIN_CAMPAIGN))):
		title += " (in development)"
	return "%s · %s" % [title, chapter_for_flag(flag)]


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
		# The main campaign's act counter; post-game campaigns keep their own.
		if str(flag.get("campaign", MAIN_CAMPAIGN)) != MAIN_CAMPAIGN:
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


## Is an act COMPLETE (optionally within one campaign — post-game campaigns
## share global act numbers)? Every flag of that act with no `branch_group` fired,
## AND at least one member fired per branch group present in the act. Branch
## groups are mutually-optional alternatives (the five village_path_* doors
## share "village_door") — requiring ALL of them made the act-5 postcard
## unreachable on any normal playthrough.
static func act_complete(act: int, fired: Dictionary, all_flags: Array, campaign: String = "") -> bool:
	var saw_any := false
	var group_satisfied := {}   # branch_group -> bool (any member fired)
	for flag in all_flags:
		if not (flag is Dictionary) or int(flag.get("act", -1)) != act:
			continue
		if campaign != "" and str(flag.get("campaign", MAIN_CAMPAIGN)) != campaign:
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
