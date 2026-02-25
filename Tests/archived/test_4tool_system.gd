extends SceneTree

## RETIRED — QuantumInstrument refactor (2026-02-21)
##
## This test relied on FarmInputHandler and the old 6-tool system (Tools 1-6).
## FarmInputHandler is removed; keyboard input is now QuantumInstrumentInput (QII).
## Coverage replaced by:
##   Tests/test_build_mode_actions.gd
##   Tests/test_play_mode_actions.gd

func _init():
	print("RETIRED: test_4tool_system.gd — see test_build_mode_actions.gd and test_play_mode_actions.gd")
	quit(0)
