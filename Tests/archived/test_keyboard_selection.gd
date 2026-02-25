extends SceneTree

## RETIRED — QuantumInstrument refactor (2026-02-21)
##
## This test verified WASD keyboard navigation updates current_selection in
## FarmInputHandler. FarmInputHandler is removed; selection/navigation is in
## QuantumInstrument and QuantumInstrumentInput.
## Coverage replaced by:
##   Tests/test_play_mode_actions.gd

func _init():
	print("RETIRED: test_keyboard_selection.gd — see test_play_mode_actions.gd")
	quit(0)
