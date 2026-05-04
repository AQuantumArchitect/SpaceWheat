extends SceneTree

func _init() -> void:
	if not ClassDB.class_exists("MultiBiomeLookaheadEngine"):
		push_error("MultiBiomeLookaheadEngine missing")
		quit(1)
		return

	var engine = ClassDB.instantiate("MultiBiomeLookaheadEngine")
	if engine == null:
		push_error("MultiBiomeLookaheadEngine instantiate failed")
		quit(1)
		return

	var h := PackedFloat64Array([
		0.0, 0.0, 1.0, 0.0,
		1.0, 0.0, 0.0, 0.0,
	])
	var biome_id: int = engine.register_biome(2, h, [], 1)
	if biome_id != 0:
		push_error("unexpected biome id: %d" % biome_id)
		quit(1)
		return

	var rho := PackedFloat64Array([
		1.0, 0.0, 0.0, 0.0,
		0.0, 0.0, 0.0, 0.0,
	])
	if not engine.submit_lookahead_job([rho], 3, 0.05, 0.01):
		push_error("submit_lookahead_job returned false")
		quit(1)
		return

	var deadline_ms := Time.get_ticks_msec() + 5000
	while not engine.is_lookahead_job_complete():
		if Time.get_ticks_msec() > deadline_ms:
			push_error("async lookahead job timed out")
			engine.cancel_lookahead_job(true)
			quit(1)
			return
		await process_frame

	var result: Dictionary = engine.take_completed_lookahead_job()
	var all_results: Array = result.get("results", [])
	if all_results.size() != 1 or (all_results[0] as Array).size() != 3:
		push_error("unexpected async result shape: %s" % str(result))
		quit(1)
		return

	engine.cancel_lookahead_job(true)
	print("native async compute smoke ok")
	quit(0)
