extends SceneTree

## RETIRED — QuantumInstrument refactor (2026-02-21)
##
## Duplicate of test_all_tools_actions.gd. Both relied on FarmInputHandler.
## FarmInputHandler is removed. Coverage replaced by:
##   Tests/test_build_mode_actions.gd
##   Tests/test_play_mode_actions.gd

func _init():
	print("RETIRED: test_all_tools_and_actions.gd — see test_build_mode_actions.gd and test_play_mode_actions.gd")
	quit(0)
