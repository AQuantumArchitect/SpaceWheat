#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: Quit after EXPLORE → MEASURE → POP cycle
## Validates that shutdown_session completes in reasonable time
## after probe actions have been performed (threads running, buffers active).


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var gsm = root.get_node_or_null("/root/GameStateManager")
	if gsm == null:
		printerr("no gsm")
		quit(2)
		return

	var state = gsm.save_load.new_game()
	if state == null:
		printerr("no state")
		quit(3)
		return

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

	var active_biome_manager = root.get_node_or_null("/root/ActiveBiomeManager")
	if active_biome_manager and active_biome_manager.has_method("set_biome_order"):
		active_biome_manager.set_biome_order(["StarterForest"])
		if active_biome_manager.has_method("set_active_biome"):
			active_biome_manager.set_active_biome("StarterForest")

	gsm.active_farm = gsm.session_lifecycle.create_farm()
	var farm = gsm.active_farm
	await gsm.session_lifecycle.await_farm_ready(farm)
	var boot_manager = root.get_node_or_null("/root/BootManager")
	if boot_manager == null:
		printerr("no boot manager")
		quit(4)
		return
	var biome_boot = boot_manager.boot_initial_biomes(farm, state)
	if not biome_boot.get("success", false):
		printerr("biome boot failed: %s" % str(biome_boot))
		quit(4)
		return
	if farm.has_method("finalize_initial_biome_boot") and not farm.finalize_initial_biome_boot():
		printerr("farm biome finalization failed")
		quit(4)
		return
	await gsm.apply_state_to_game(state)

	# Wait for farm systems to be ready
	var frames := 0
	while frames < 30 and (farm == null or farm.grid == null or farm.terminal_pool == null or farm.economy == null):
		await process_frame
		frames += 1

	print("\n======================================================================")
	print("TEST: Quit after EXPLORE → MEASURE → POP")
	print("======================================================================\n")

	var biome = farm.grid.get_biome("StarterForest") if farm.grid else null
	if not biome:
		printerr("  ❌ StarterForest biome not found")
		quit(4)
		return
	print("  ✅ StarterForest biome ready")

	# Let evolution run for a few frames to get threads going
	for i in range(10):
		await process_frame

	# EXPLORE
	var explore_result = ProbeActions.action_explore(farm.terminal_pool, biome, farm.economy)
	if not explore_result.get("success", false):
		printerr("  ❌ EXPLORE failed: %s" % explore_result.get("message", "unknown"))
		quit(5)
		return
	print("  ✅ EXPLORE succeeded: register=%d" % explore_result.register_id)

	var terminal = explore_result.terminal

	# Let a few more frames pass (threads may be running C++ packets)
	for i in range(5):
		await process_frame

	# MEASURE (this uses the new ensemble drain)
	var measure_result = ProbeActions.action_measure(terminal, biome, farm.economy, farm)
	if not measure_result.get("success", false):
		printerr("  ❌ MEASURE failed: %s" % measure_result.get("message", "unknown"))
		quit(6)
		return
	var has_drain = measure_result.get("ensemble_drain", false)
	var drain_eta = measure_result.get("drain_eta", -1.0)
	print("  ✅ MEASURE succeeded: outcome=%s, ensemble_drain=%s, η=%.4f" % [
		measure_result.outcome, str(has_drain), drain_eta])

	# POP
	var pop_result = ProbeActions.action_pop(terminal, farm.terminal_pool, farm.economy, farm)
	if not pop_result.get("success", false):
		printerr("  ❌ POP failed: %s" % pop_result.get("message", "unknown"))
		quit(7)
		return
	print("  ✅ POP succeeded: %s ×%d" % [pop_result.resource, pop_result.amount])

	# Let more frames pass to get evolution threads going again
	for i in range(10):
		await process_frame

	# Now attempt shutdown and time it
	print("\n  ⏱ Starting shutdown_session...")
	var t0 = Time.get_ticks_msec()

	if gsm.has_method("shutdown_session"):
		await gsm.session_lifecycle.shutdown_session(true)
	else:
		if farm:
			farm.queue_free()
		await process_frame
		await process_frame

	var elapsed = Time.get_ticks_msec() - t0
	print("  ⏱ shutdown_session completed in %d ms" % elapsed)

	if elapsed > 5000:
		print("  ❌ FAIL: Shutdown took too long (>5s)")
		quit(1)
		return
	elif elapsed > 1000:
		print("  ⚠️  WARN: Shutdown slow (%d ms > 1s)" % elapsed)
	else:
		print("  ✅ Shutdown fast (%d ms)" % elapsed)

	print("\n======================================================================")
	print("RESULTS: All actions + shutdown completed successfully")
	print("======================================================================\n")
	quit(0)
