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

	var carry_dt = float(_stride_dt_carry.get(biome_name, 0.0)) + incoming_dt

	if stride <= 1:
		packets.append({
			"dt": carry_dt,
			"max_dt": get_effective_max_dt_for_stride(biome, 1),
			"stride": 1
		})
		_stride_dt_carry[biome_name] = 0.0
		return packets

	var stride_window_dt = batcher.EVOLUTION_INTERVAL * float(stride)
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
				var packets = collect_stride_evolution_packets(biome, batcher.LOOKAHEAD_DT)
				if packets.is_empty():
					skipped_due_empty_buffer += 1
					continue
				for packet in packets:
					run_direct_biome_cycle(
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
	var debug_time_skip = batcher._env_flag("RIG_DEBUG_TIMESKIP", false)
	var require_activity = batcher._env_flag("RIG_TIME_SKIP_REQUIRE_ACTIVITY", false)
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

	var use_native = batcher.lookahead_engine != null and batcher._engine_ready
	var mode_str = "native" if use_native else "direct"
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
				var lindblad_count = int(qc.lindblad_operators.size()) if qc and "lindblad_operators" in qc else 0
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
				if use_native:
					run_native_biome_cycle(biome, packet_dt, packet_max_dt)
				else:
					run_direct_biome_cycle(biome, packet_dt, packet_max_dt)
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
		if use_native:
			run_native_biome_cycle(biome, flush_dt, flush_max_dt)
		else:
			run_direct_biome_cycle(biome, flush_dt, flush_max_dt)
		stride_flushed_steps += 1
		evolved_steps += 1
		if debug_time_skip:
			VerboseHelper.debug("trace", "time-skip", "flush biome=%s stride=%d packet_dt=%.6f packet_max_dt=%.6f" % [
				batcher._get_biome_name(biome),
				int(flush_packet.get("stride", 1)),
				flush_dt,
				flush_max_dt
			])

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


## DEPRECATED for production — GDScript quantum compute. This runs the slow GDScript
## `QuantumComputer.evolve()` (the exact-unitary REFERENCE kernel). It is now only reached
## when NO native backend is available (degraded fallback) and serves as the correctness
## oracle the C++ backend is validated against (Tests/test_engine_equivalence.gd). The
## canonical evolver is the C++ backend via run_native_biome_cycle(). Do not route the live
## game or time-skip here when a backend exists.
func run_direct_biome_cycle(biome, dt: float, max_dt_override: float = -1.0) -> void:
	if batcher == null or not batcher._is_valid_biome(biome):
		return
	if not batcher._ensure_biome_quantum_shapes(biome):
		return

	if biome.time_tracker:
		biome.time_tracker.update(dt)

	var sim_dt = dt * biome.quantum_time_scale if "quantum_time_scale" in biome else dt
	var max_dt = max_dt_override if max_dt_override > 0.0 else get_base_max_dt(biome)
	biome.quantum_computer.evolve(sim_dt, max_dt, null)

	if biome.viz_cache:
		var packet = biome.quantum_computer.export_bloch_packet() if biome.quantum_computer.has_method("export_bloch_packet") else PackedFloat64Array()
		var num_qubits = biome.quantum_computer.register_map.num_qubits if biome.quantum_computer.register_map else 0
		if packet.size() > 0 and num_qubits > 0:
			if biome.quantum_computer.berry_register != null:
				biome.quantum_computer.berry_register.integrate_step(packet, num_qubits)
			biome.viz_cache.update_from_bloch_packet(packet, num_qubits)
	if biome.quantum_computer.has_method("get_purity"):
		biome.viz_cache.update_purity(biome.quantum_computer.get_purity())

	batcher._post_evolution_update(biome)


func run_native_biome_cycle(biome, dt: float, max_dt_override: float = -1.0) -> void:
	if batcher == null or not batcher._is_valid_biome(biome):
		return
	if not batcher._ensure_biome_quantum_shapes(biome):
		return

	var biome_name = batcher._get_biome_name(biome)
	var engine_id = batcher._biome_engine_ids.get(biome_name, -1)
	if engine_id < 0:
		run_direct_biome_cycle(biome, dt, max_dt_override)
		return

	if biome.time_tracker:
		biome.time_tracker.update(dt)

	var qc = biome.quantum_computer
	var rho_packed = qc.density_matrix._to_packed()
	var max_dt = max_dt_override if max_dt_override > 0.0 else get_base_max_dt(biome)
	var dim = int(qc.register_map.dim())

	if dim > 0 and rho_packed.size() >= dim * dim * 2:
		var trace = 0.0
		for i in range(dim):
			trace += rho_packed[i * (dim + 1) * 2]
		if trace < 1e-10:
			var fresh_packed = PackedFloat64Array()
			fresh_packed.resize(dim * dim * 2)
			var diag_val = 1.0 / float(dim)
			for i in range(dim):
				fresh_packed[i * (dim + 1) * 2] = diag_val
			qc.density_matrix._from_packed(fresh_packed, dim)
			rho_packed = fresh_packed

	var result = batcher.lookahead_engine.evolve_single_biome(engine_id, rho_packed, 1, dt, max_dt)
	var results = result.get("results", [])
	if results.size() > 0:
		var final_rho = results[results.size() - 1]
		if final_rho is PackedFloat64Array and final_rho.size() > 0:
			qc.load_packed_state(final_rho, dim, true)
	if biome.viz_cache:
		var packet = qc.export_bloch_packet() if qc.has_method("export_bloch_packet") else PackedFloat64Array()
		var num_qubits = qc.register_map.num_qubits if qc.register_map else 0
		if packet.size() > 0 and num_qubits > 0:
			if qc.berry_register != null:
				qc.berry_register.integrate_step(packet, num_qubits)
			biome.viz_cache.update_from_bloch_packet(packet, num_qubits)
		if qc.has_method("get_purity"):
			biome.viz_cache.update_purity(qc.get_purity())

	batcher._post_evolution_update(biome)
	batcher.biome_evolution_counts[biome_name] = batcher.biome_evolution_counts.get(biome_name, 0) + 1
