extends SceneTree

## RETIRED — QuantumInstrument refactor (2026-02-21)
##
## This test traced plant submenu generation via ToolConfig.get_dynamic_submenu()
## and FarmInputHandler. Both APIs are removed:
##   - ToolConfig.get_dynamic_submenu() no longer exists
##   - FarmInputHandler is removed
##   - Biome names (BioticFlux, Market, Forest, Kitchen) have changed
## Vocabulary/icon assignment is now tested via:
##   Tests/test_build_mode_actions.gd  (Group 4 vocab injection)

func _init():
	print("RETIRED: test_plant_menu_debug.gd — dynamic submenu API removed; see test_build_mode_actions.gd")
	quit(0)
