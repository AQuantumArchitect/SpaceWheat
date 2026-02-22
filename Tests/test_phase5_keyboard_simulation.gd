extends SceneTree

## RETIRED — QuantumInstrument refactor (2026-02-21)
##
## This test simulated keyboard InputEventKey events through FarmInputHandler.
## FarmInputHandler is removed. Keyboard simulation via QuantumInstrumentInput (QII)
## is out of scope for headless tests (QII is a UI-layer Node not present headless).
## Functional keyboard routing is covered by:
##   Tests/test_play_mode_actions.gd

func _init():
	print("RETIRED: test_phase5_keyboard_simulation.gd — see test_play_mode_actions.gd")
	quit(0)
