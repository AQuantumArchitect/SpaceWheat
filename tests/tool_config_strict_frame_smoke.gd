extends "res://tests/smoke_test_base.gd"

## Smoke test: ToolConfig rejects invalid frame names instead of silently
## keeping the previous selection.

const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")


func _init() -> void:
	print("\n=== ToolConfig strict frame smoke ===")

	ToolConfig.reset_frame_modes()

	_check(ToolConfig.select_frame(ToolConfig.FRAME_ACE), "accepts a valid frame")
	_check(ToolConfig.get_current_frame() == ToolConfig.FRAME_ACE, "valid frame updates selection")

	var previous_frame := ToolConfig.get_current_frame()
	_check(not ToolConfig.select_frame("__bogus_frame__"), "rejects an invalid frame")
	_check(ToolConfig.get_current_frame() == previous_frame, "invalid frame leaves state unchanged")

	_check(ToolConfig.set_frame_mode(ToolConfig.FRAME_ACE, 0) == 0, "valid mode selection succeeds")
	_check(ToolConfig.set_frame_mode(ToolConfig.FRAME_ACE, 9) == -1, "invalid mode selection fails explicitly")

	_finish()
