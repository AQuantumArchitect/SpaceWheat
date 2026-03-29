#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Phase 2 Save/Load Test - current headless serializer coverage
## Run with: godot --headless --script res://Tests/test_phase2_saveload.gd
##
## Verifies that explored/measured plot state survives capture/apply using the
## authoritative headless path:
##   GameStateManager.start_session() -> ProbeActions -> capture_state_from_game()
##   -> fresh session -> apply_state_to_game()

const QuantumInstrumentClass = preload("res://Core/Instrumentation/QuantumInstrument.gd")

const SEPARATOR := "======================================================================"
const TARGET_BIOME := "StarterForest"
const TARGET_EXPLORES := 3

var test_results: Array = []
var gsm = null
var farm = null
var instrument = null
var captured_state = null
var explored_records: Array = []
var measured_record: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n" + SEPARATOR)
	print("PHASE 2: SAVE/LOAD TEST")
	print("Testing: explored/measured plot serialization on current headless path")
	print(SEPARATOR + "\n")

	gsm = root.get_node_or_null("/root/GameStateManager")
	if gsm == null:
		printerr("❌ GameStateManager autoload not found")
		quit(1)
		return

	farm = await gsm.start_session(-1, "default", true)
	if not await _await_farm_ready():
		printerr("❌ Farm did not become ready")
		quit(1)
		return
	_attach_instrument()

	_seed_live_state()
	_test_capture_state_contains_register_binding()
	_test_capture_state_contains_emojis()
	_test_capture_state_contains_measured_outcome()
	_test_apply_state_restores_binding_identity()
	_test_apply_state_restores_measured_outcome()
	_print_results()

	var failed := test_results.filter(func(r): return not r.passed).size()
	if gsm:
		var active = gsm.active_farm if "active_farm" in gsm else farm
		if active and is_instance_valid(active):
			active.queue_free()
			await process_frame
			await process_frame
	quit(1 if failed > 0 else 0)


func _await_farm_ready(max_frames: int = 20) -> bool:
	var frames := 0
	while frames < max_frames:
		if farm and farm.grid and farm.terminal_pool and farm.economy:
			return true
		await process_frame
		frames += 1
	return false


func _get_target_biome():
	if not farm or not farm.grid or not farm.grid.has_biomes():
		return null
	return farm.grid.get_biome(TARGET_BIOME)


func _attach_instrument() -> void:
	instrument = QuantumInstrumentClass.new()
	instrument.setup(farm)
	farm.set_instrument(instrument)


func _seed_live_state() -> void:
	var biome = _get_target_biome()
	_begin_test("Setup Game State")

	if biome == null:
		_record_result(false, "Missing biome: %s" % TARGET_BIOME)
		return

	explored_records.clear()
	var row: int = int(farm.get_biome_row(TARGET_BIOME)) if farm.has_method("get_biome_row") else 0

	for i in range(TARGET_EXPLORES):
		var pos := Vector2i(i, row)
		var explore = instrument.action_explore(TARGET_BIOME, pos)
		if not bool(explore.get("success", false)):
			_record_result(false, "Explore %d failed: %s" % [i + 1, explore.get("error", "unknown")])
			return

		var plot = farm.grid.get_plot(pos)
		if plot == null or not plot.is_active() or plot.terminal == null:
			_record_result(false, "Explore %d did not materialize a live terminal-backed plot" % (i + 1))
			return

		explored_records.append({
			"pos": pos,
			"register_id": int(plot.bound_register_id),
			"biome_name": str(plot.bound_biome_name),
			"north_emoji": str(plot.north_emoji),
			"south_emoji": str(plot.south_emoji),
			"terminal": plot.terminal,
			"biome": biome
		})

	var first = explored_records[0]
	var measure = instrument.action_measure(first["pos"])
	if not bool(measure.get("success", false)):
		_record_result(false, "Measure failed: %s" % measure.get("error", "unknown"))
		return

	var measured_pos: Vector2i = first.get("pos", Vector2i.ZERO)
	var measured_plot = farm.grid.get_plot(measured_pos)
	measured_record = {
		"pos": measured_pos,
		"register_id": int(measured_plot.bound_register_id),
		"biome_name": str(measured_plot.bound_biome_name),
		"north_emoji": str(measured_plot.north_emoji),
		"south_emoji": str(measured_plot.south_emoji),
		"measured_outcome": str(measured_plot.measured_outcome),
		"measured_probability": float(measured_plot.measured_probability)
	}

	_record_result(true, "Seeded %d explored plots and 1 measured plot" % explored_records.size())


func _test_capture_state_contains_register_binding() -> void:
	_begin_test("Capture State - register binding")
	captured_state = gsm.capture_state_from_game()

	if captured_state == null or captured_state.plots.is_empty():
		_record_result(false, "No plots captured")
		return

	var planted := _captured_plots_by_position(captured_state)
	if planted.size() < TARGET_EXPLORES:
		_record_result(false, "Expected %d planted plots, got %d" % [TARGET_EXPLORES, planted.size()])
		return

	var missing: Array[String] = []
	for record in explored_records:
		var key = _pos_key(record["pos"])
		if not planted.has(key):
			missing.append(key)
			continue
		var plot_data = planted[key]
		if int(plot_data.get("register_id", -1)) != int(record["register_id"]):
			missing.append("%s(reg)" % key)
		elif str(plot_data.get("biome_name", "")) != str(record["biome_name"]):
			missing.append("%s(biome)" % key)

	if not missing.is_empty():
		_record_result(false, "Missing/restored binding mismatch at: %s" % ", ".join(missing))
		return

	_record_result(true, "register_id + biome_name captured correctly")


func _test_capture_state_contains_emojis() -> void:
	_begin_test("Capture State - emojis")

	if captured_state == null:
		captured_state = gsm.capture_state_from_game()

	var planted := _captured_plots_by_position(captured_state)
	var bad: Array[String] = []
	for record in explored_records:
		var key = _pos_key(record["pos"])
		var plot_data = planted.get(key, {})
		if str(plot_data.get("north_emoji", "")) != str(record["north_emoji"]):
			bad.append("%s(north)" % key)
		elif str(plot_data.get("south_emoji", "")) != str(record["south_emoji"]):
			bad.append("%s(south)" % key)

	if not bad.is_empty():
		_record_result(false, "Emoji mismatch at: %s" % ", ".join(bad))
		return

	_record_result(true, "north/south emojis captured correctly")


func _test_capture_state_contains_measured_outcome() -> void:
	_begin_test("Capture State - measured_outcome")

	if captured_state == null:
		captured_state = gsm.capture_state_from_game()

	var planted := _captured_plots_by_position(captured_state)
	if measured_record.is_empty():
		_record_result(false, "No measured record from setup")
		return
	var measured_pos: Vector2i = measured_record.get("pos", Vector2i.ZERO)
	var key = _pos_key(measured_pos)
	var plot_data = planted.get(key, {})
	if str(plot_data.get("measured_outcome", "")) != str(measured_record["measured_outcome"]):
		_record_result(false, "Measured outcome missing or wrong for %s" % key)
		return

	_record_result(true, "measured_outcome captured correctly")


func _test_apply_state_restores_binding_identity() -> void:
	_begin_test("Apply State - binding identity")

	instrument = null
	if gsm and gsm.active_farm and is_instance_valid(gsm.active_farm):
		gsm.active_farm.queue_free()
		gsm.active_farm = null
		await process_frame
		await process_frame

	var restored_farm = gsm._create_farm()
	gsm.active_farm = restored_farm
	farm = restored_farm
	if restored_farm == null or not await _await_farm_ready(40):
		_record_result(false, "Fresh restore farm did not become ready")
		return
	_attach_instrument()

	gsm.current_state = captured_state
	gsm.apply_state_to_game(captured_state)
	await process_frame

	var bad: Array[String] = []
	for record in explored_records:
		var plot = farm.grid.get_plot(record["pos"])
		if plot == null or not plot.is_active():
			bad.append("%s(missing)" % _pos_key(record["pos"]))
			continue
		if int(plot.bound_register_id) != int(record["register_id"]):
			bad.append("%s(reg)" % _pos_key(record["pos"]))
		elif str(plot.bound_biome_name) != str(record["biome_name"]):
			bad.append("%s(biome)" % _pos_key(record["pos"]))
		elif str(plot.north_emoji) != str(record["north_emoji"]):
			bad.append("%s(north)" % _pos_key(record["pos"]))
		elif str(plot.south_emoji) != str(record["south_emoji"]):
			bad.append("%s(south)" % _pos_key(record["pos"]))

	if not bad.is_empty():
		_record_result(false, "Restore mismatch at: %s" % ", ".join(bad))
		return

	_record_result(true, "Bound plot identity restored correctly")


func _test_apply_state_restores_measured_outcome() -> void:
	_begin_test("Apply State - measured outcome")

	if measured_record.is_empty():
		_record_result(false, "No measured record from setup")
		return
	var measured_pos: Vector2i = measured_record.get("pos", Vector2i.ZERO)
	var plot = farm.grid.get_plot(measured_pos)
	if plot == null:
		_record_result(false, "Measured plot missing after restore at %s (plot=%s active=%s reg=%s biome=%s measured=%s outcome=%s)" % [
			_pos_key(measured_pos),
			str(plot != null),
			str(plot.is_active() if plot else false),
			str(plot.bound_register_id if plot else -1),
			str(plot.bound_biome_name if plot else ""),
			str(plot.is_measured if plot else false),
			str(plot.measured_outcome if plot else "")
		])
		return

	if not plot.is_measured:
		_record_result(false, "Measured flag not restored")
		return

	if str(plot.measured_outcome) != str(measured_record["measured_outcome"]):
		_record_result(false, "Measured outcome mismatch: got %s expected %s" % [
			str(plot.measured_outcome),
			str(measured_record["measured_outcome"])
		])
		return

	_record_result(true, "Measured outcome restored correctly")


func _captured_plots_by_position(state) -> Dictionary:
	var out := {}
	for plot_data in state.plots:
		if not bool(plot_data.get("is_planted", false)):
			continue
		var pos = plot_data.get("position", Vector2i.ZERO)
		out[_pos_key(pos)] = plot_data
	return out


func _pos_key(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x, pos.y]


func _begin_test(name: String) -> void:
	print("\nTEST: %s" % name)


func _record_result(passed: bool, details: String) -> void:
	test_results.append({
		"passed": passed,
		"details": details
	})
	print("  %s %s" % ["PASS" if passed else "FAIL", details])


func _print_results() -> void:
	print("\n" + SEPARATOR)
	print("RESULTS")
	print(SEPARATOR)

	var passed := test_results.filter(func(r): return r.passed).size()
	var failed := test_results.size() - passed
	print("Passed: %d" % passed)
	print("Failed: %d" % failed)

	for result in test_results:
		if not result.passed:
			print("  FAIL: %s" % result.details)
