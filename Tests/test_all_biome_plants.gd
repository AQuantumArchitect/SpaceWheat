extends SceneTree

## RETIRED — QuantumInstrument refactor (2026-02-21)
##
## This test verified biome-specific planting and plot inspection via
## farm.build() and FarmInputHandler. Both APIs are removed:
##   - farm.build() replaced by ProbeActions.action_explore()
##   - FarmInputHandler replaced by QuantumInstrumentInput + QuantumInstrument
## Coverage replaced by:
##   Tests/test_play_mode_actions.gd   (explore/measure/pop in StarterForest + Village)
##   Tests/test_biome_dynamics.gd       (biome-specific dynamics verification)

func _init():
	print("RETIRED: test_all_biome_plants.gd — farm.build() and FarmInputHandler removed; see test_play_mode_actions.gd")
	quit(0)
