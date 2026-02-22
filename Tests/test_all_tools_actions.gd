extends SceneTree

## RETIRED — QuantumInstrument refactor (2026-02-21)
##
## This test verified all tool Q/E/R actions via FarmInputHandler.
## FarmInputHandler is removed. Coverage replaced by:
##   Tests/test_build_mode_actions.gd  (build-mode group actions)
##   Tests/test_play_mode_actions.gd   (play-mode probe actions)

func _init():
	print("RETIRED: test_all_tools_actions.gd — see test_build_mode_actions.gd and test_play_mode_actions.gd")
	quit(0)
