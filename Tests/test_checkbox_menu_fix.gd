extends SceneTree

## RETIRED — QuantumInstrument refactor (2026-02-21)
##
## This test verified checkbox selection updates via FarmInputHandler.
## FarmInputHandler is removed. Checkbox/selection state is now managed by
## QuantumInstrument (Core/Instrumentation/QuantumInstrument.gd).
## Multi-plot selection is exercised in:
##   Tests/test_play_mode_actions.gd

func _init():
	print("RETIRED: test_checkbox_menu_fix.gd — selection state is in QuantumInstrument; see test_play_mode_actions.gd")
	quit(0)
