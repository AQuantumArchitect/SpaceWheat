#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: Ace vantage (L1–L3) — strike-time terminal binding + closed-mode honesty.
##
## Proves the "unfuck the UI" gameplay core:
##   - Ace ToolConfig mapping: Q=Extract(pop) / E=Pause("") / R=Strike(measure) / F=fast_forward
##   - Selection no longer auto-binds a terminal (pool stays full until a strike)
##   - Strike (action_measure) binds a terminal ON DEMAND, then collapses
##   - Extract (action_pop) releases the terminal back to the pool
##   - Closed mode: spark_north (Plant) returns an inert blocked result

const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")

var _fail := 0


func _init() -> void:
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ %s" % msg)
	else:
		print("  ❌ %s" % msg)
		_fail += 1


func _run() -> void:
	print("\n======================================================================")
	print("TEST: Ace vantage (L1–L3) — strike-time bind + closed-mode honesty")
	print("======================================================================\n")

	# --- Pure ToolConfig assertions (no farm needed) ---
	print("[ToolConfig] Ace QERF mapping:")
	_check(str(ToolConfig.get_action("ace", "Q").get("action", "")) == "pop", "Q → pop (Extract)")
	_check(str(ToolConfig.get_action("ace", "Q").get("label", "")) == "Extract", "Q labelled 'Extract'")
	_check(str(ToolConfig.get_action("ace", "E").get("action", "")) == "", "E → '' (Pause, no tool verb)")
	_check(str(ToolConfig.get_action("ace", "R").get("action", "")) == "measure", "R → measure (Strike)")
	_check(str(ToolConfig.get_action("ace", "R").get("label", "")) == "Strike", "R labelled 'Strike'")
	_check(str(ToolConfig.get_action("ace", "F").get("action", "")) == "fast_forward", "F → fast_forward")
	# Plant must be gone from Ace.
	var ace_actions := {}
	for k in ["Q", "E", "R", "F"]:
		ace_actions[k] = str(ToolConfig.get_action("ace", k).get("action", ""))
	_check("spark_north" not in ace_actions.values(), "Plant (spark_north) removed from Ace")

	# --- Boot a farm with StarterForest ---
	var gsm = root.get_node_or_null("/root/GameStateManager")
	if gsm == null:
		printerr("no gsm"); quit(2); return
	var state = gsm.save_load.new_game()
	if state == null:
		printerr("no state"); quit(3); return
	state.unlocked_biomes.clear()
	state.unlocked_biomes.append("StarterForest")
	state.unexplored_biome_pool.clear()
	state.active_biome_name = "StarterForest"
	gsm.current_state = state
	gsm.current_scenario_id = "new_game_easy"

	var observation_frame = root.get_node_or_null("/root/ObservationFrame")
	if observation_frame:
		observation_frame.BIOME_ORDER.clear()
		observation_frame.BIOME_ORDER.append("StarterForest")
		if observation_frame.has_method("set_neutral_biome"):
			observation_frame.set_neutral_biome("StarterForest")
	var abm = root.get_node_or_null("/root/ActiveBiomeManager")
	if abm and abm.has_method("set_biome_order"):
		abm.set_biome_order(["StarterForest"])
		if abm.has_method("set_active_biome"):
			abm.set_active_biome("StarterForest")

	gsm.active_farm = gsm.session_lifecycle.create_farm()
	var farm = gsm.active_farm
	await gsm.session_lifecycle.await_farm_ready(farm)
	var boot_manager = root.get_node_or_null("/root/BootManager")
	if boot_manager == null:
		printerr("no boot manager"); quit(4); return
	var biome_boot = boot_manager.boot_initial_biomes(farm, state)
	if not biome_boot.get("success", false):
		printerr("biome boot failed: %s" % str(biome_boot)); quit(4); return
	if farm.has_method("finalize_initial_biome_boot") and not farm.finalize_initial_biome_boot():
		printerr("farm biome finalization failed"); quit(4); return
	await gsm.apply_state_to_game(state)

	var frames := 0
	while frames < 30 and (farm == null or farm.grid == null or farm.terminal_pool == null or farm.economy == null):
		await process_frame
		frames += 1

	# This manual boot path doesn't run WorldBuilder, which normally wires the
	# instrument. Wire one ourselves — the same two calls WorldBuilder makes.
	if farm.instrument == null:
		var QI = load("res://Core/Instrumentation/QuantumInstrument.gd")
		var inst = QI.new()
		inst.setup(farm)
		farm.set_instrument(inst)

	print("\n[Runtime] Boot + strike loop:")
	_check(farm.grid != null and farm.terminal_pool != null and farm.instrument != null, "farm + terminal_pool + instrument ready")

	for i in range(10):
		await process_frame

	# A live register position in StarterForest (plot_idx ≡ register_id).
	var positions = farm.grid.get_plot_positions_for_biome("StarterForest")
	_check(not positions.is_empty(), "StarterForest has live register positions (%d)" % positions.size())
	if positions.is_empty():
		_finish(); return
	var gp: Vector2i = positions[0]

	# L1: nothing is bound yet — selection/crawl never auto-binds a terminal.
	var plot0 = farm.grid.get_plot(gp)
	_check(plot0 == null or plot0.terminal == null, "no terminal bound at %s before any strike" % gp)

	# Closed mode: Plant / spark_north must be an inert blocked no-op.
	var is_closed := not BalanceConfig.dissipative_enabled()
	_check(is_closed, "demo is the closed (unitary) system")
	var plant = farm.instrument.action_spark_north([gp] as Array[Vector2i])
	_check(not plant.get("success", false) and plant.get("blocked", false), "spark_north (Plant) blocked in closed mode")
	_check(farm.grid.get_plot(gp) == null or farm.grid.get_plot(gp).terminal == null, "blocked Plant bound no terminal")

	# L1/L3: STRIKE binds a terminal on demand, then collapses (no prior explore).
	var strike = farm.instrument.action_measure(gp)
	var struck_plot = farm.grid.get_plot(gp)
	var struck_terminal = struck_plot.terminal if struck_plot else null
	_check(strike.get("success", false), "Strike (action_measure) succeeds with no prior explore — strike-time bind")
	_check(struck_terminal != null, "strike created a terminal at %s where none existed (strike-time bind)" % gp)
	_check(struck_terminal != null and struck_terminal.is_measured, "struck terminal is measured (register collapsed)")

	# L3: EXTRACT pops the struck terminal off the plot.
	var extract = farm.instrument.action_pop(gp)
	var popped_plot = farm.grid.get_plot(gp)
	_check(extract.get("success", false), "Extract (action_pop) succeeds after strike")
	_check(popped_plot == null or popped_plot.terminal == null, "extract detached the terminal from the plot")

	_finish()


func _finish() -> void:
	print("\n======================================================================")
	if _fail == 0:
		print("RESULT: ✅ ALL VANTAGE CHECKS PASSED")
	else:
		print("RESULT: ❌ %d CHECK(S) FAILED" % _fail)
	print("======================================================================\n")
	quit(1 if _fail > 0 else 0)
