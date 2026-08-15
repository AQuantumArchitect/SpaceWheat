class_name BiomeDeterministicStepper
extends RefCounted


var batcher
var _stride_dt_carry: Dictionary = {}


func _init(p_batcher = null) -> void:
	batcher = p_batcher


func bind_batcher(p_batcher) -> void:
	batcher = p_batcher
	if batcher == null:
		_stride_dt_carry.clear()


func get_observation_stride(biome) -> int:
	if batcher == null or not batcher._is_valid_biome(biome):
		return 1
	if "observation_stride" in biome:
		return clampi(int(biome.observation_stride), 0, 256)
	return 1


func get_base_max_dt(biome) -> float:
	if batcher == null or not batcher._is_valid_biome(biome):
		return batcher.MAX_SUBSTEP_DT if batcher != null else 0.02
	if "max_evolution_dt" in biome:
		return maxf(0.000001, float(biome.max_evolution_dt))
	return batcher.MAX_SUBSTEP_DT


func get_effective_max_dt_for_stride(biome, _stride: int) -> float:
	var base_max_dt = get_base_max_dt(biome)
	return base_max_dt


func reset_stride_carry(biome_name: String = "") -> void:
	if biome_name == "":
		_stride_dt_carry.clear()
		return
	_stride_dt_carry[biome_name] = 0.0


func collect_stride_evolution_packets(biome, incoming_dt: float) -> Array:
	var packets: Array = []
	if batcher == null or incoming_dt <= 0.0 or not batcher._is_valid_biome(biome):
		return packets

	var biome_name = batcher._get_biome_name(biome)
	var stride = get_observation_stride(biome)
	if stride <= 0:
		_stride_dt_carry[biome_name] = 0.0
		return packets

	if stride <= 1:
		var carry_1x = float(_stride_dt_carry.get(biome_name, 0.0)) + incoming_dt
		packets.append({
			"dt": carry_1x,
			"max_dt": get_effective_max_dt_for_stride(biome, 1),
			"stride": 1
		})
		_stride_dt_carry[biome_name] = 0.0
		return packets

	# Stride is a fast-forward MULTIPLIER: stride× sim time flows per wall dt.
	# It used to only CHUNK time — the window (stride × INTERVAL) filled at 1×
	# real rate, so sim/wall stayed exactly 1.0 at any stride, while Farm's
	# Lindblad path DID multiply by stride: the =/- dial desynced H from L and
	# ripened nothing (fleet #6: "16× clock, zero effect"). Multiplier capped
	# at 32× per frame (native evolve cost); packets stay ONE INTERVAL each so
	# the Berry walk samples the trajectory at the same density as 1× play.
	var mult := float(mini(stride, 32))
	var carry_dt = float(_stride_dt_carry.get(biome_name, 0.0)) + incoming_dt * mult
	var stride_window_dt = batcher.EVOLUTION_INTERVAL
	if stride_window_dt <= 0.0:
		stride_window_dt = incoming_dt
	var effective_max_dt = get_effective_max_dt_for_stride(biome, stride)

	while carry_dt + 1e-9 >= stride_window_dt:
		packets.append({
			"dt": stride_window_dt,
			"max_dt": effective_max_dt,
			"stride": stride
		})
		carry_dt -= stride_window_dt

	_stride_dt_carry[biome_name] = maxf(0.0, carry_dt)
	return packets


func flush_stride_packet(biome) -> Dictionary:
	if batcher == null or not batcher._is_valid_biome(biome):
		return {}
	var stride = get_observation_stride(biome)
	if stride <= 1:
		return {}
	var biome_name = batcher._get_biome_name(biome)
	var carry_dt = float(_stride_dt_carry.get(biome_name, 0.0))
	if carry_dt <= 0.0:
		return {}
	_stride_dt_carry[biome_name] = 0.0
	return {
		"dt": carry_dt,
		"max_dt": get_effective_max_dt_for_stride(biome, stride),
		"stride": stride,
		"flushed": true
	}


func run_additional_cycles(cycles: int, biome_names: Array = []) -> Dictionary:
	if batcher == null:
		return {"success": false, "error": "no_batcher", "evolved_steps": 0}

	var target_cycles = maxi(cycles, 0)
	if target_cycles <= 0:
		return {"success": true, "cycles": 0, "evolved_steps": 0}

	var requested: Dictionary = {}
	for biome_name in biome_names:
		var key = str(biome_name)
		if key != "":
			requested[key] = true

	var target_biomes: Array = []
	for biome in batcher.biomes:
		if not batcher._is_valid_biome(biome):
			continue
		var biome_name = batcher._get_biome_name(biome)
		if not requested.is_empty() and not requested.has(biome_name):
			continue
		if not biome.quantum_evolution_enabled or biome.evolution_paused:
			continue
		target_biomes.append(biome)

	if target_biomes.is_empty():
		return {
			"success": false,
			"error": "no_target_biomes",
			"message": "No eligible biomes for additional evolution cycles.",
			"cycles": target_cycles,
			"evolved_steps": 0
		}

	var evolved_steps = 0
	var consumed_buffer_steps = 0
	var direct_evolve_steps = 0
	var skipped_due_empty_buffer = 0

	for _i in range(target_cycles):
		for biome in target_biomes:
			var biome_name = batcher._get_biome_name(biome)
			if batcher.lookahead_enabled:
				if batcher._get_biome_depth(biome_name) > 0:
					batcher._apply_buffered_step(biome)
					consumed_buffer_steps += 1
					evolved_steps += 1
				else:
					skipped_due_empty_buffer += 1
			else:
				# Lookahead disabled: step the native engine synchronously — same
				# integrator authority, just without the buffered read-ahead.
				var packets = collect_stride_evolution_packets(biome, batcher.LOOKAHEAD_DT)
				if packets.is_empty():
					skipped_due_empty_buffer += 1
					continue
				for packet in packets:
					run_native_biome_cycle(
						biome,
						float(packet.get("dt", batcher.LOOKAHEAD_DT)),
						float(packet.get("max_dt", get_base_max_dt(biome)))
					)
					direct_evolve_steps += 1
					evolved_steps += 1

	return {
		"success": true,
		"cycles": target_cycles,
		"biomes": target_biomes.size(),
		"evolved_steps": evolved_steps,
		"consumed_buffer_steps": consumed_buffer_steps,
		"direct_evolve_steps": direct_evolve_steps,
		"lookahead_enabled": batcher.lookahead_enabled,
		"skipped_due_empty_buffer": skipped_due_empty_buffer
	}


func run_time_skip_cycles(cycles: int, dt: float = -1.0, biome_names: Array = []) -> Dictionary:
	if batcher == null:
		return {"success": false, "error": "no_batcher", "evolved_steps": 0}

	var target_cycles = maxi(cycles, 0)
	if target_cycles <= 0:
		return {
			"success": true,
			"cycles": 0,
			"biomes": 0,
			"evolved_steps": 0,
			"skipped_biomes": 0,
			"mode": "direct"
		}

	var target_dt = maxf(0.000001, dt if dt > 0.0 else batcher.LOOKAHEAD_DT)
	var debug_time_skip = RuntimeEnv.debug_timeskip()
	var require_activity = RuntimeEnv.time_skip_require_activity()
	var requested: Dictionary = {}
	for biome_name in biome_names:
		var key = str(biome_name)
		if key != "":
			requested[key] = true

	var target_biomes: Array = []
	var skipped_biomes = 0
	for biome in batcher.biomes:
		if not batcher._is_valid_biome(biome):
			continue
		var biome_name = batcher._get_biome_name(biome)
		if not requested.is_empty() and not requested.has(biome_name):
			continue
		if not biome.quantum_evolution_enabled or biome.evolution_paused:
			skipped_biomes += 1
			continue
		if require_activity and batcher.terminal_pool and not batcher._biome_has_bound_terminals(biome, true):
			skipped_biomes += 1
			continue
		target_biomes.append(biome)

	if target_biomes.is_empty():
		return {
			"success": false,
			"error": "no_target_biomes",
			"message": "No eligible biomes for time-skip evolution.",
			"cycles": target_cycles,
			"biomes": 0,
			"evolved_steps": 0,
			"skipped_biomes": skipped_biomes,
			"mode": "direct"
		}

	if batcher.lookahead_engine == null or not batcher._engine_ready:
		return {
			"success": false,
			"error": "native_engine_unavailable",
			"message": "Time-skip requires the native engine — there is no GDScript integrator.",
			"cycles": target_cycles,
			"biomes": 0,
			"evolved_steps": 0,
			"skipped_biomes": skipped_biomes,
			"mode": "native"
		}
	if batcher.lookahead_engine.has_method("is_lookahead_job_running") \
			and batcher.lookahead_engine.is_lookahead_job_running():
		return {
			"success": false,
			"error": "async_packet_in_flight",
			"message": "Time-skip refused while compute is filling a lookahead packet.",
			"cycles": target_cycles,
			"biomes": 0,
			"evolved_steps": 0,
			"skipped_biomes": skipped_biomes,
			"mode": "native"
		}
	var mode_str = "native"
	var evolved_steps = 0
	var stride_deferred_steps = 0
	var stride_flushed_steps = 0
	for cycle_index in range(target_cycles):
		for biome in target_biomes:
			var packets = collect_stride_evolution_packets(biome, target_dt)
			if packets.is_empty():
				stride_deferred_steps += 1
				continue
			if debug_time_skip:
				var qc = biome.quantum_computer if biome else null
				var reg_dim = int(qc.register_map.dim()) if qc and qc.register_map else -1
				var rho_dim = int(qc.density_matrix.n) if qc and qc.density_matrix else -1
				var h_dim = int(qc.hamiltonian.n) if qc and qc.hamiltonian else -1
				var lindblad_count = int(qc.lindblad_operators.size()) if qc else 0
				VerboseHelper.debug("trace", "time-skip", "cycle=%d biome=%s reg_dim=%d rho_dim=%d H_dim=%d L_count=%d max_dt=%.6f target_dt=%.6f mode=%s" % [
					cycle_index,
					batcher._get_biome_name(biome),
					reg_dim,
					rho_dim,
					h_dim,
					lindblad_count,
					(biome.max_evolution_dt if "max_evolution_dt" in biome else -1.0),
					target_dt,
					mode_str
				])
			for packet in packets:
				var packet_dt = float(packet.get("dt", target_dt))
				var packet_max_dt = float(packet.get("max_dt", get_base_max_dt(biome)))
				var packet_stride = int(packet.get("stride", 1))
				run_native_biome_cycle(biome, packet_dt, packet_max_dt)
				if debug_time_skip:
					VerboseHelper.debug("trace", "time-skip", "cycle=%d biome=%s evolve_ok stride=%d packet_dt=%.6f packet_max_dt=%.6f carry_dt=%.6f" % [
						cycle_index,
						batcher._get_biome_name(biome),
						packet_stride,
						packet_dt,
						packet_max_dt,
						float(_stride_dt_carry.get(batcher._get_biome_name(biome), 0.0))
					])
				evolved_steps += 1

	for biome in target_biomes:
		var flush_packet = flush_stride_packet(biome)
		if flush_packet.is_empty():
			continue
		var flush_dt = float(flush_packet.get("dt", 0.0))
		if flush_dt <= 0.0:
			continue
		var flush_max_dt = float(flush_packet.get("max_dt", get_base_max_dt(biome)))
		run_native_biome_cycle(biome, flush_dt, flush_max_dt)
		stride_flushed_steps += 1
		evolved_steps += 1
		if debug_time_skip:
			VerboseHelper.debug("trace", "time-skip", "flush biome=%s stride=%d packet_dt=%.6f packet_max_dt=%.6f" % [
				batcher._get_biome_name(biome),
				int(flush_packet.get("stride", 1)),
				flush_dt,
				flush_max_dt
			])

	# The skip advanced ρ synchronously, so any frames still buffered for these
	# biomes were computed from the PRE-skip state — replaying them in the live
	# lane would silently REWIND the world to before the skip (observed as a
	# biome "frozen" across a time_skip: it evolved, then a stale writeback put
	# it back). Flush and re-prime each skipped biome from its post-skip state.
	for biome in target_biomes:
		batcher.invalidate_biome_buffer(batcher._get_biome_name(biome))

	batcher._mark_biome_activity_dirty()
	batcher._refresh_runtime_activity(true)

	return {
		"success": true,
		"cycles": target_cycles,
		"biomes": target_biomes.size(),
		"evolved_steps": evolved_steps,
		"stride_deferred_steps": stride_deferred_steps,
		"stride_flushed_steps": stride_flushed_steps,
		"skipped_biomes": skipped_biomes,
		"mode": mode_str,
		"dt": target_dt,
		"require_activity": require_activity
	}


## The native C++ backend is the ONLY evolver. The GDScript direct cycle
## (run_direct_biome_cycle → QuantumComputer.evolve) was deleted 2026-07-06:
## it existed as a "degraded fallback" that let a build without the native
## engine limp at seconds-per-frame instead of failing. BootManager refuses
## to boot without the native classes, so an unregistered biome here is an
## authority bug (registration drift) — surface it loudly and skip the step.
func run_native_biome_cycle(biome, dt: float, max_dt_override: float = -1.0) -> void:
	if batcher == null or not batcher._is_valid_biome(biome):
		return
	if not batcher._ensure_biome_quantum_shapes(biome):
		return

	var biome_name = batcher._get_biome_name(biome)
	var engine_id = batcher._biome_engine_ids.get(biome_name, -1)
	if engine_id < 0:
		push_error("[Stepper] %s has no native engine id — biome never registered (or reregistration lost). Step skipped; NO GDScript fallback exists." % biome_name)
		return

	# Silent-twin guard: evolving against an engine slot registered at a different
	# dimension makes evolve_single_biome return nothing — the biome silently
	# freezes. Surface it loudly instead (re-register should have landed in
	# run_time_skip_cycles → _process_pending_reregisters before we got here).
	var engine_dim = int(batcher._biome_engine_dims.get(biome_name, -1))
	var qc_dim = int(biome.quantum_computer.register_map.dim()) if biome.quantum_computer and biome.quantum_computer.register_map else -1
	if engine_dim >= 0 and qc_dim > 0 and engine_dim != qc_dim:
		push_error("[Stepper] %s: engine dim %d != qc dim %d — re-register did not land; step skipped." % [biome_name, engine_dim, qc_dim])
		batcher.biome_pending_reregister[biome_name] = true
		return

	if biome.time_tracker:
		biome.time_tracker.update(dt)

	var qc = biome.quantum_computer
	var rho_packed = qc.density_matrix._to_packed()
	var max_dt = max_dt_override if max_dt_override > 0.0 else get_base_max_dt(biome)
	var dim = int(qc.register_map.dim())

	# Degenerate ρ would SIGABRT the native engine. DegenerateRho owns the test
	# (including the NaN case this site used to miss) and the replacement state.
	if dim > 0 and rho_packed.size() >= dim * dim * 2:
		if DegenerateRho.is_degenerate(rho_packed, dim):
			var fresh_packed := DegenerateRho.maximally_mixed_packed(dim)
			qc.density_matrix._from_packed(fresh_packed, dim)
			rho_packed = fresh_packed

	var result = batcher.lookahead_engine.evolve_single_biome(engine_id, rho_packed, 1, dt, max_dt)
	var results = result.get("results", [])
	if results.size() > 0:
		var final_rho = results[results.size() - 1]
		if final_rho is PackedFloat64Array and final_rho.size() > 0:
			qc.load_packed_state(final_rho, dim, true)
	_accumulate_post_evolution(biome)

	batcher._post_evolution_update(biome)
	batcher.biome_evolution_counts[biome_name] = batcher.biome_evolution_counts.get(biome_name, 0) + 1


## Post-evolution Bloch-packet fan-out: accumulate Berry phase on tracked qubits
## (path-integrate the slice the Bloch vectors just traced) AND refresh the viz cache.
## Both evolution cycles (direct + native) funnel here so the Berry integrator can
## never silently fall out of the loop again — its absence made every tracked qubit
## un-ripenable, which dead-ended the entire icon-incorporation / vocabulary arc.
func _accumulate_post_evolution(biome) -> void:
	var qc = biome.quantum_computer
	if qc == null or not qc.has_method("export_bloch_packet"):
		return
	var num_qubits = qc.register_map.num_qubits if qc.register_map else 0
	if num_qubits <= 0:
		return
	var packet = qc.export_bloch_packet()
	if packet.size() == 0:
		return
	# Berry phase: integrate the solid angle this slice traced (no-op if nothing tracked).
	if qc.berry_register:
		qc.berry_register.integrate_step(packet, num_qubits)
	# Visualization mirror.
	if biome.viz_cache:
		biome.viz_cache.update_from_bloch_packet(packet, num_qubits)
		if qc.has_method("get_purity"):
			biome.viz_cache.update_purity(qc.get_purity())
