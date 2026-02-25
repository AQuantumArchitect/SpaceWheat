extends SceneTree

## RETIRED — QuantumInstrument refactor (2026-02-21)
##
## This test exercised the "Kitchen" biome full workflow via FarmInputHandler.
## FarmInputHandler is removed. The Kitchen biome is not loaded in headless tests
## (only StarterForest + Village load from new_game_easy.tres).
## End-to-end biome workflows are exercised via:
##   Tests/test_play_mode_actions.gd
##   Tests/test_biome_dynamics.gd

func _init():
	print("RETIRED: test_kitchen_full_workflow.gd — Kitchen biome not in headless template; see test_play_mode_actions.gd")
	quit(0)
