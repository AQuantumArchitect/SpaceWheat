extends "res://tests/smoke_test_base.gd"

## Pin StoryAtlas — the one authority for act/chapter/lane structure.
##
##   current_act    — CONTIGUOUS prefix, not max-act-fired (act-5's second_loop
##                    is reachable in act 2; a max rule inflated the chapter
##                    header to "Chapter IV" mid-game).
##   act_complete   — branch_group members are any-one-of (the five
##                    village_path_* doors are mutually optional; requiring all
##                    made the act-5 postcard unreachable).
##   lane_of        — parses both authored shapes ("What Survives III — X",
##                    "What Fades — Y").
##   sentence_cut   — sentence boundary, never a mid-word stump.
##
## Run: godot --headless --path . --script tests/story_atlas_smoke.gd

const FLAGS := [
	{"id": "a0", "act": 0},
	{"id": "a1", "act": 1},
	{"id": "a2", "act": 2},
	{"id": "a5_float", "act": 5},
	{"id": "b1", "act": 3, "branch_group": "door"},
	{"id": "b2", "act": 3, "branch_group": "door"},
	{"id": "s3", "act": 3},
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== StoryAtlas smoke ===")

	# current_act: contiguous prefix — the floating act-5 fire must NOT jump it.
	_check(StoryAtlas.current_act({}, FLAGS) == 0, "no flags → act 0")
	_check(StoryAtlas.current_act({"a0": 1, "a1": 1}, FLAGS) == 1, "acts 0-1 fired → act 1")
	_check(StoryAtlas.current_act({"a0": 1, "a1": 1, "a5_float": 1}, FLAGS) == 1,
			"floating act-5 fire does NOT inflate the current act",
			"got %d" % StoryAtlas.current_act({"a0": 1, "a1": 1, "a5_float": 1}, FLAGS))
	_check(StoryAtlas.current_act({"a0": 1, "a1": 1, "a2": 1, "s3": 1, "b1": 1}, FLAGS) == 3,
			"contiguous through act 3 → act 3")

	# act_complete: spine flags all required; branch group any-one-of.
	_check(not StoryAtlas.act_complete(3, {"s3": 1}, FLAGS),
			"spine fired but no door → act 3 incomplete")
	_check(StoryAtlas.act_complete(3, {"s3": 1, "b1": 1}, FLAGS),
			"spine + ONE door → act 3 complete (any-one-of)")
	_check(not StoryAtlas.act_complete(3, {"b1": 1, "b2": 1}, FLAGS),
			"doors without the spine flag → incomplete")
	_check(not StoryAtlas.act_complete(9, {}, FLAGS), "unknown act → never complete")

	# lane_of: both authored shapes.
	var with_numeral := StoryAtlas.lane_of("What Survives III — The Chain Protects Its Ends")
	_check(with_numeral["lane"] == "survives" and with_numeral["numeral"] == "III",
			"numbered lane parses", str(with_numeral))
	var bare := StoryAtlas.lane_of("What Fades — The Crossing")
	_check(bare["lane"] == "fades" and bare["numeral"] == "",
			"numeral-less lane parses", str(bare))
	_check(StoryAtlas.lane_of("First Breath")["lane"] == "", "spine flag has no lane")
	var turns := StoryAtlas.lane_of("What Turns I — The Loop Came Home")
	_check(turns["lane"] == "turns" and turns["numeral"] == "I",
			"the fourth lane (What Turns) parses", str(turns))
	_check(StoryAtlas.lane_tag("What Connects IV — The Braid Alphabet") == "Connects IV",
			"lane_tag renders short form")

	# sentence_cut: boundary-respecting.
	var long_text := "The first sentence lands cleanly here. The second sentence would run far past any reasonable banner budget and must be dropped whole."
	var cut := StoryAtlas.sentence_cut(long_text, 60)
	_check(cut.ends_with("here."), "cuts at the sentence boundary", "got: %s" % cut)
	_check(StoryAtlas.sentence_cut("short", 60) == "short", "short text passes through")

	_finish("story atlas smoke")
