extends SceneTree

## RETIRED — QuantumInstrument refactor (2026-02-21)
##
## This test verified Tool 6 (ToolConfig.get_tool(6), get_dynamic_submenu,
## plot reassignment via FarmInputHandler._action_assign_plots_to_biome).
## All three APIs are removed:
##   - Tool 6 does not exist in the new tool system
##   - ToolConfig.get_dynamic_submenu() is removed
##   - FarmInputHandler is removed (replaced by QuantumInstrumentInput + QuantumInstrument)
## Biome assignment coverage replaced by:
##   Tests/test_build_mode_actions.gd

func _init():
	print("RETIRED: test_tool6_simple.gd — Tool 6 and dynamic submenu API removed; see test_build_mode_actions.gd")
	quit(0)
