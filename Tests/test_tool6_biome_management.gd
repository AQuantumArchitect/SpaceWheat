extends SceneTree

## RETIRED — QuantumInstrument refactor (2026-02-21)
##
## This test verified Tool 6 (Biome Management) via FarmInputHandler.
## Tool 6 is removed from the tool system. Biome assignment is now in
## Group 4 (Meta/Vocabulary) via BiomeHandler (UI/Handlers/BiomeHandler.gd).
## Coverage replaced by:
##   Tests/test_build_mode_actions.gd  (Tool 1 = BiomeHandler.clear_biome_assignment)

func _init():
	print("RETIRED: test_tool6_biome_management.gd — Tool 6 removed; see test_build_mode_actions.gd")
	quit(0)
