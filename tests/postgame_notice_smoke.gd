extends "res://tests/smoke_test_base.gd"

## The Demos ending warns before the post-game (owner decision 2026-10-18:
## no gate, but say it plainly). Drives the real CampaignRuntime, StoryAtlas
## and EndingOverlay door stage against the compiled campaign_runtime.json.
## Run: godot --headless --script tests/postgame_notice_smoke.gd

const EndingOverlayScript = preload("res://UI/Overlays/EndingOverlay.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== Post-game notice smoke ===")
	var unfinished: Array = CampaignRuntime.in_development_after("island_free")
	_check(unfinished.has("What Fades") and unfinished.has("The Loom"),
			"both post-game campaigns are flagged in development", str(unfinished))
	_check(not CampaignRuntime.is_in_development("demos"), "the main campaign is not")

	var notice: String = EndingOverlayScript.post_game_notice(unfinished)
	_check("What Fades" in notice and "The Loom" in notice and "in development" in notice,
			"the ending notice names both and says in development", notice)

	var head_main := StoryAtlas.header_for_flag({"campaign": "demos", "campaign_act": 2, "act_title": "Two Countries"})
	_check(not ("in development" in head_main), "main-campaign headers carry no label", head_main)
	var head_post := StoryAtlas.header_for_flag({"campaign": "lanternfall", "campaign_act": 1, "act_title": "Lantern Country"})
	_check(head_post.begins_with("What Fades (in development)"), "post-game headers say in development", head_post)

	# The door stage really shows it (built headless, no farm needed).
	var overlay = EndingOverlayScript.new()
	overlay._content = Control.new()
	overlay.add_child(overlay._content)
	root.add_child(overlay)
	overlay._build_door_stage()
	var texts: Array = []
	for box in overlay._content.get_children():
		for child in box.get_children():
			if child is Label:
				texts.append(child.text)
	var joined := " | ".join(PackedStringArray(texts))
	_check("The door stays open." in joined, "door stage still opens the door", joined)
	_check(notice in texts, "door stage shows the post-game notice", joined)
	overlay.queue_free()
	_finish("Post-game notice smoke")
