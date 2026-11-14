extends "res://tests/smoke_test_base.gd"

## One answer to "which hats does the player have": ToolConfig (keyboard,
## cycle) and UIProgression (mouse tabs) agree, a locked hat's number key does
## nothing, and firing its beat reveals it at once. No farm = fail open.

const UIProgressionScript = preload("res://UI/Core/UIProgression.gd")
const ToolConfigScript = preload("res://Core/GameState/ToolConfig.gd")


class FarmStub:
	extends Node
	var story_flags_fired: Dictionary = {}
	var terminal_pool = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== Hat availability smoke ===")
	var gsm = root.get_node_or_null("/root/GameStateManager")
	if gsm == null:
		_fail("GameStateManager autoload available")
		_finish("Hat availability smoke")
		return
	var prev_farm = gsm.active_farm
	var prev_frame: String = ToolConfigScript.current_frame

	gsm.active_farm = null
	_check(ToolConfigScript.available_frame_ids().size() == ToolConfigScript.FRAME_IDS.size(),
		"no farm: every hat available (fail open)")

	var farm := FarmStub.new()
	root.add_child(farm)
	gsm.active_farm = farm
	farm.story_flags_fired = {"_x": true}  # a live farm, nothing fired
	ToolConfigScript.current_frame = ToolConfigScript.FRAME_ACE

	_check(ToolConfigScript.available_frame_ids() == [ToolConfigScript.FRAME_ACE],
		"new game: only Ace is available")
	for fid in ToolConfigScript.FRAME_IDS:
		_check(ToolConfigScript.is_frame_available(fid) == UIProgressionScript.is_hat_visible(fid),
			"keyboard and tabs agree on %s" % fid)
	for fid in [ToolConfigScript.FRAME_DRUID, ToolConfigScript.FRAME_ICON]:
		_check(not ToolConfigScript.select_frame(fid), "locked %s: select refused" % fid)
		_check(ToolConfigScript.get_current_frame() == ToolConfigScript.FRAME_ACE,
			"locked %s: frame unchanged" % fid)

	farm.story_flags_fired["druid_opens"] = true
	_check(ToolConfigScript.is_frame_available(ToolConfigScript.FRAME_DRUID), "druid_opens reveals the Druid")
	_check(UIProgressionScript.is_hat_visible(ToolConfigScript.FRAME_DRUID), "…and its tab")
	_check(ToolConfigScript.select_frame(ToolConfigScript.FRAME_DRUID), "…and its key works")
	_check(not ToolConfigScript.is_frame_available(ToolConfigScript.FRAME_ICON), "Icon stays hidden")

	farm.story_flags_fired["village_stirs"] = true
	_check(ToolConfigScript.is_frame_available(ToolConfigScript.FRAME_ICON), "village_stirs reveals the Icon")

	ToolConfigScript.current_frame = prev_frame
	gsm.active_farm = prev_farm
	_finish("Hat availability smoke")
