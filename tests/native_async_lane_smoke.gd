extends "res://tests/smoke_test_base.gd"

## Async compute lane: parity with sync evolve, exclusive-while-running,
## and take does not write live positions (stale packet cannot poison the buffer).
##
## Run: godot --headless --path . --script tests/native_async_lane_smoke.gd


func _init() -> void:
	print("\n=== Native async lane ===")
	if not ClassDB.class_exists("MultiBiomeLookaheadEngine"):
		_fail("MultiBiomeLookaheadEngine missing")
		_finish("native_async_lane_smoke")
		return

	await process_frame
	await _test_parity()
	_test_exclusive()
	await _test_take_does_not_commit_positions()
	_test_buffer_generation()
	_finish("native_async_lane_smoke")


func _packed_h2() -> PackedFloat64Array:
	return PackedFloat64Array([
		0.0, 0.0, 1.0, 0.0,
		1.0, 0.0, 0.0, 0.0,
	])


func _packed_rho2() -> PackedFloat64Array:
	return PackedFloat64Array([
		1.0, 0.0, 0.0, 0.0,
		0.0, 0.0, 0.0, 0.0,
	])


func _make_engine():
	var engine = ClassDB.instantiate("MultiBiomeLookaheadEngine")
	_check(engine != null, "instantiate MultiBiomeLookaheadEngine")
	return engine


func _await_complete(engine, label: String, timeout_ms: int = 5000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not engine.is_lookahead_job_complete():
		if Time.get_ticks_msec() > deadline:
			_fail("%s timed out" % label)
			engine.cancel_lookahead_job(true)
			return false
		await process_frame
	return true


func _rho_close(a: PackedFloat64Array, b: PackedFloat64Array, eps: float = 1e-9) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if abs(a[i] - b[i]) > eps:
			return false
	return true


func _test_parity() -> void:
	var sync_engine = _make_engine()
	if sync_engine == null:
		return
	_check(sync_engine.register_biome(2, _packed_h2(), [], 1) == 0, "sync register")
	var sync_result: Dictionary = sync_engine.evolve_all_lookahead([_packed_rho2()], 3, 0.05, 0.05)
	var sync_steps: Array = sync_result.get("results", [])

	var async_engine = _make_engine()
	if async_engine == null:
		return
	_check(async_engine.register_biome(2, _packed_h2(), [], 1) == 0, "async register")
	_check(async_engine.submit_lookahead_job([_packed_rho2()], 3, 0.05, 0.05), "submit for parity")
	if not await _await_complete(async_engine, "parity job"):
		return
	var async_result: Dictionary = async_engine.take_completed_lookahead_job()
	_check(str(async_result.get("layout", "")) == "flat", "take is a flat packet")
	var unpacker := BiomeEvolutionBatcher.new()
	var async_steps: Array = unpacker._unpack_flat_f64(async_result, "rho", 0)

	_check(sync_steps.size() == 1, "sync lane returns one biome")
	if sync_steps.is_empty():
		return
	var s: Array = sync_steps[0]
	var a: Array = async_steps
	_check(s.size() == 3 and a.size() == 3, "both lanes return 3 phrames")
	var matched := s.size() == a.size()
	for i in range(mini(s.size(), a.size())):
		if not _rho_close(s[i], a[i]):
			matched = false
			break
	_check(matched, "sync evolve_all and submit/take match within 1e-9")
	var flat_buf = unpacker._ensure_lookahead_buffer("parity")
	flat_buf.adopt_flat_from_result(async_result, 0)
	_check(flat_buf.layout == "flat", "buffer keeps the packet flat")
	_check(flat_buf.frames.is_empty(), "flat merge does not unpack into Array-of-Array")
	_check(flat_buf.depth() == 3, "flat depth is the step count")
	var step0: PackedFloat64Array = flat_buf.step_rho(0)
	_check(step0.size() == a[0].size() and _rho_close(step0, a[0]), "step_rho slices phrame 0")
	async_engine.cancel_lookahead_job(true)
	sync_engine.cancel_lookahead_job(true)


func _test_exclusive() -> void:
	var engine = _make_engine()
	if engine == null:
		return
	_check(engine.register_biome(2, _packed_h2(), [], 1) == 0, "exclusive register")
	# Sleep between steps so the worker is still running when we poke it.
	if engine.has_method("set_pacing_delay_ms"):
		engine.set_pacing_delay_ms(20)
	_check(engine.submit_lookahead_job([_packed_rho2()], 4, 0.05, 0.05), "submit for exclusive")
	_check(engine.is_lookahead_job_running(), "job running after submit")
	if engine.is_lookahead_job_running():
		var refused: Dictionary = engine.evolve_single_biome(0, _packed_rho2(), 1, 0.05, 0.05)
		_check(refused.is_empty(), "evolve_single refused while running")
		_check(not bool(engine.reregister_biome(0, 2, _packed_h2(), [], 1)), "reregister refused while running")
		_check(int(engine.register_biome(2, _packed_h2(), [], 1)) < 0, "register refused while running")
		var blocked: Dictionary = engine.evolve_all_lookahead([_packed_rho2()], 1, 0.05, 0.05)
		_check(blocked.is_empty(), "evolve_all refused while running")
	engine.cancel_lookahead_job(true)
	if engine.has_method("set_pacing_delay_ms"):
		engine.set_pacing_delay_ms(0)


func _test_take_does_not_commit_positions() -> void:
	var engine = _make_engine()
	if engine == null:
		return
	_check(engine.register_biome(2, _packed_h2(), [], 1) == 0, "positions register")
	var seed := PackedVector2Array()
	seed.append(Vector2(1000.0, 2000.0))
	engine.set_node_positions(0, seed)

	_check(engine.submit_lookahead_job([_packed_rho2()], 3, 0.05, 0.05), "submit first positions job")
	if not await _await_complete(engine, "positions job 1"):
		return
	var first: Dictionary = engine.take_completed_lookahead_job()
	var unpacker := BiomeEvolutionBatcher.new()
	var first_pos: Array = unpacker._unpack_flat_vec2(first, "pos", 0)
	_check(not first_pos.is_empty() and first_pos[0] is PackedVector2Array, "first job produced positions")

	# take must not have written live positions. A second 1-step job should
	# warm-start from the seed, not from the first job's last step.
	_check(engine.submit_lookahead_job([_packed_rho2()], 1, 0.05, 0.05), "submit second positions job")
	if not await _await_complete(engine, "positions job 2"):
		return
	var second: Dictionary = engine.take_completed_lookahead_job()
	var second_pos: Array = unpacker._unpack_flat_vec2(second, "pos", 0)
	if second_pos.is_empty() or not (second_pos[0] is PackedVector2Array):
		_fail("second job produced no positions")
		engine.cancel_lookahead_job(true)
		return
	var start: PackedVector2Array = second_pos[0]
	# Force layout moves, but the first step of job 2 should still be near the
	# seed if it started there — and far from origin. Compare against seed.
	_check(start.size() >= 1, "second job first step has a node")
	if start.size() >= 1:
		var dseed := start[0].distance_to(Vector2(1000.0, 2000.0))
		_check(dseed < 250.0, "second job started from seed (take did not commit)", "dist=%.1f" % dseed)
	engine.cancel_lookahead_job(true)


func _test_buffer_generation() -> void:
	var batcher := BiomeEvolutionBatcher.new()
	_check(batcher.use_phase_lnn == false, "phase-shadow LNN stays off")
	var buf = batcher._ensure_lookahead_buffer("StarterForest")
	_check(buf.generation == 0, "fresh buffer generation is 0")
	_check(buf.awaiting_packet == false, "fresh buffer is not awaiting")
	buf.awaiting_packet = true
	buf.reset_frames()
	_check(buf.generation == 1, "reset_frames bumps generation")
	_check(buf.awaiting_packet == false, "reset_frames clears awaiting")
	buf.clear()
	_check(buf.generation == 2, "clear also bumps generation")
	# Cover law only when an async backend is attached; stall law otherwise.
	_check(batcher._affordable_batch_size(21, 6) == 1, "no-engine stall law still first-packet=1")
	if NativeBackend.native_available() and not OS.has_feature("web"):
		batcher.lookahead_engine = NativeBackend.new()
		if batcher._has_async_lookahead():
			_check(batcher._affordable_batch_size(13, 6) == 1, "async first packet is still 1")
			batcher._avg_ms_per_step = 6.0
			_check(batcher._affordable_batch_size(13, 1) == 8,
				"async 1-biome floor(50/6)=8")
			_check(batcher._affordable_batch_size(13, 6) == 1,
				"async 6-biome multiplies: floor(50/(6*6))=1")
