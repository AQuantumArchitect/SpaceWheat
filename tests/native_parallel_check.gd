extends "res://tests/smoke_test_base.gd"

## native_parallel_check.gd — per-biome substep cap and parallel biome stepping
## in MultiBiomeLookaheadEngine.
##
## Every biome in one native call shares the call's dt (the shared clock,
## PhysicsConfig.PHRAME_SIM_DT). Since 2026-11-14:
##   - each biome's substeps are capped by its OWN resolution
##     (set_biome_max_dt), not the finest in the packet;
##   - the biomes of one call are stepped on several threads (set_max_threads),
##     with results identical to stepping them one after another.
##
## Prints PASS/FAIL lines and, for the benchmark, one line:
##   NATIVE_BENCH {"binary": "new"|"old", "cases": {name: ms}, "threads": n, ...}
## With an old binary (no set_biome_max_dt) it only benchmarks the old path.
##
##   godot --headless --script tests/native_parallel_check.gd

const DT := 0.02          # the shared clock
const STEPS := 21         # one full refill packet
const FINE := 0.001       # one biome the player resolved finely
const COARSE := 1.0       # everyone else's profiled resolution
const QUBITS := 5         # dim 32, StarterForest's size
## Environment knobs for the benchmark only (the checks use 4 + 4):
##   NATIVE_BENCH_ONLY=1, NATIVE_BENCH_OPEN=n, NATIVE_BENCH_CLOSED=n, NATIVE_BENCH_REPS=n
var N_OPEN := 4
var N_CLOSED := 4
var _reps := 3

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	print("\n=== Native per-biome cap + parallel stepping ===")
	if not ClassDB.class_exists("MultiBiomeLookaheadEngine"):
		_fail("MultiBiomeLookaheadEngine missing")
		_finish("native_parallel_check")
		return
	await process_frame
	var probe = ClassDB.instantiate("MultiBiomeLookaheadEngine")
	var new_binary: bool = probe.has_method("set_biome_max_dt") and probe.has_method("set_max_threads")
	if OS.get_environment("NATIVE_BENCH_ONLY") == "1":
		N_OPEN = int(OS.get_environment("NATIVE_BENCH_OPEN")) if OS.get_environment("NATIVE_BENCH_OPEN") != "" else 4
		N_CLOSED = int(OS.get_environment("NATIVE_BENCH_CLOSED")) if OS.get_environment("NATIVE_BENCH_CLOSED") != "" else 4
		_reps = int(OS.get_environment("NATIVE_BENCH_REPS")) if OS.get_environment("NATIVE_BENCH_REPS") != "" else 5
		_bench(new_binary)
		_finish("native_parallel_bench")
		return
	if new_binary:
		_test_threads_do_not_change_results()
		_test_each_biome_keeps_its_own_cap()
		_test_caps_reset_and_refused_while_running()
		await _test_async_parity()
	_bench(new_binary)
	_finish("native_parallel_check")


# --------------------------------------------------------------------- fixtures

func _dim() -> int:
	return 1 << QUBITS


## Random Hermitian H, packed interleaved re/im, row-major.
func _random_h(dim: int) -> PackedFloat64Array:
	var re := []
	var im := []
	for i in range(dim * dim):
		re.append(0.0)
		im.append(0.0)
	for i in range(dim):
		re[i * dim + i] = _rng.randf_range(-1.0, 1.0)
		for j in range(i + 1, dim):
			var a := _rng.randf_range(-0.3, 0.3)
			var b := _rng.randf_range(-0.3, 0.3)
			re[i * dim + j] = a
			im[i * dim + j] = b
			re[j * dim + i] = a
			im[j * dim + i] = -b
	var out := PackedFloat64Array()
	for k in range(dim * dim):
		out.append(re[k])
		out.append(im[k])
	return out


## Lowering operator on each qubit, sqrt(gamma) σ⁻: triplets (row, col, re, im).
func _decay_ops(dim: int, gamma: float) -> Array:
	var ops: Array = []
	for q in range(QUBITS):
		var t := PackedFloat64Array()
		var bit := 1 << q
		for i in range(dim):
			if i & bit:
				t.append(float(i & ~bit))
				t.append(float(i))
				t.append(sqrt(gamma))
				t.append(0.0)
		ops.append(t)
	return ops


## ρ = ½|ψ⟩⟨ψ| + ½·I/d for a random ψ: a valid, non-trivial density matrix.
func _random_rho(dim: int) -> PackedFloat64Array:
	var pr := []
	var pi := []
	var norm := 0.0
	for i in range(dim):
		var a := _rng.randf_range(-1.0, 1.0)
		var b := _rng.randf_range(-1.0, 1.0)
		pr.append(a)
		pi.append(b)
		norm += a * a + b * b
	norm = sqrt(norm)
	var out := PackedFloat64Array()
	for i in range(dim):
		for j in range(dim):
			# ψ_i ψ_j*
			var re: float = (pr[i] * pr[j] + pi[i] * pi[j]) / (norm * norm)
			var imv: float = (pi[i] * pr[j] - pr[i] * pi[j]) / (norm * norm)
			re = 0.5 * re + (0.5 / dim if i == j else 0.0)
			out.append(re)
			out.append(0.5 * imv)
	return out


## Engine with N_OPEN open biomes (decay on every qubit → RK4) then N_CLOSED
## closed ones (no L → one exact step). Returns [engine, rhos].
func _make(seed_value: int) -> Array:
	_rng.seed = seed_value
	var engine = ClassDB.instantiate("MultiBiomeLookaheadEngine")
	engine.set_pacing_delay_ms(0)
	var dim := _dim()
	var rhos: Array = []
	for k in range(N_OPEN + N_CLOSED):
		var ops: Array = _decay_ops(dim, 0.8) if k < N_OPEN else []
		var id: int = engine.register_biome(dim, _random_h(dim), ops, QUBITS)
		_check(id == k, "register biome %d" % k)
		rhos.append(_random_rho(dim))
	return [engine, rhos]


func _frames(result: Dictionary, biome: int) -> Array:
	var all: Array = result.get("results", [])
	return all[biome] if biome < all.size() else []


func _same(a: Array, b: Array, eps: float = 0.0) -> bool:
	if a.size() != b.size() or a.is_empty():
		return false
	for s in range(a.size()):
		var x: PackedFloat64Array = a[s]
		var y: PackedFloat64Array = b[s]
		if x.size() != y.size():
			return false
		for i in range(x.size()):
			if absf(x[i] - y[i]) > eps:
				return false
	return true


func _max_diff(a: Array, b: Array) -> float:
	var m := 0.0
	for s in range(mini(a.size(), b.size())):
		var x: PackedFloat64Array = a[s]
		var y: PackedFloat64Array = b[s]
		for i in range(mini(x.size(), y.size())):
			m = maxf(m, absf(x[i] - y[i]))
	return m


# ------------------------------------------------------------------------ tests

func _test_threads_do_not_change_results() -> void:
	var made := _make(7)
	var engine = made[0]
	var rhos: Array = made[1]
	engine.set_max_threads(1)
	var seq: Dictionary = engine.evolve_all_lookahead(rhos, STEPS, DT, DT)
	_check(int(engine.get_last_thread_count()) == 1, "set_max_threads(1) steps on one thread")
	engine.set_max_threads(0)
	var par: Dictionary = engine.evolve_all_lookahead(rhos, STEPS, DT, DT)
	var used: int = int(engine.get_last_thread_count())
	print("  threads used (auto): %d of %d hardware" % [used, OS.get_processor_count()])
	_check(used > 1 or OS.get_processor_count() <= 2, "automatic threading uses several threads")
	var all_same := true
	for k in range(N_OPEN + N_CLOSED):
		if not _same(_frames(seq, k), _frames(par, k)):
			all_same = false
			printerr("    biome %d differs: max %.3e" % [k, _max_diff(_frames(seq, k), _frames(par, k))])
	_check(all_same, "parallel and sequential stepping give bit-identical frames")
	_check(str(seq.get("bloch_steps")) == str(par.get("bloch_steps"))
			and str(seq.get("purity_steps")) == str(par.get("purity_steps"))
			and str(seq.get("mi_steps")) == str(par.get("mi_steps")),
			"... and identical Bloch, purity and MI")


func _test_each_biome_keeps_its_own_cap() -> void:
	var made := _make(11)
	var engine = made[0]
	var rhos: Array = made[1]
	engine.set_max_threads(0)
	# Biome 0 is resolved finely; the others keep the coarse profile. The call's
	# own max_dt is the old packet minimum, which would cap everyone.
	for k in range(N_OPEN + N_CLOSED):
		engine.set_biome_max_dt(k, FINE if k == 0 else COARSE)
	_check(is_equal_approx(engine.get_biome_max_dt(0), FINE) and is_equal_approx(engine.get_biome_max_dt(1), COARSE),
			"set_biome_max_dt stores each biome's cap")
	var packet: Dictionary = engine.evolve_all_lookahead(rhos, STEPS, DT, FINE)
	var ok := true
	for k in range(N_OPEN + N_CLOSED):
		var alone: Dictionary = engine.evolve_single_biome(k, rhos[k], STEPS, DT, FINE if k == 0 else COARSE)
		if not _same(_frames(packet, k), alone.get("results", [])):
			ok = false
			printerr("    biome %d: packet != alone at its own cap (max %.3e)" % [k, _max_diff(_frames(packet, k), alone.get("results", []))])
	_check(ok, "in one packet each biome steps exactly as it does alone at its own cap")

	# The cap is real for an open biome (RK4) and moot for a closed one (exact).
	engine.set_biome_max_dt(1, FINE)
	engine.set_biome_max_dt(N_OPEN, FINE)
	var fine_all: Dictionary = engine.evolve_all_lookahead(rhos, STEPS, DT, FINE)
	_check(_max_diff(_frames(packet, 1), _frames(fine_all, 1)) > 1e-12,
			"an open biome's frames depend on its cap (it substeps)")
	_check(_same(_frames(packet, N_OPEN), _frames(fine_all, N_OPEN)),
			"a closed biome's frames don't (one exact step at any cap)")


func _test_caps_reset_and_refused_while_running() -> void:
	var made := _make(13)
	var engine = made[0]
	var rhos: Array = made[1]
	engine.set_biome_max_dt(0, FINE)
	engine.clear_biomes()
	engine.register_biome(_dim(), _random_h(_dim()), [], QUBITS)
	_check(engine.get_biome_max_dt(0) <= 0.0, "clear_biomes forgets the caps")
	engine.set_biome_max_dt(0, COARSE)
	var one := [rhos[0]]
	if engine.submit_lookahead_job(one, 200, DT, DT):
		if engine.is_lookahead_job_running():
			engine.set_biome_max_dt(0, FINE)
			_check(is_equal_approx(engine.get_biome_max_dt(0), COARSE), "set_biome_max_dt is refused while a job runs")
		engine.cancel_lookahead_job(true)


func _test_async_parity() -> void:
	var made := _make(17)
	var engine = made[0]
	var rhos: Array = made[1]
	for k in range(N_OPEN + N_CLOSED):
		engine.set_biome_max_dt(k, FINE if k == 0 else COARSE)
	engine.set_max_threads(0)
	var sync_r: Dictionary = engine.evolve_all_lookahead(rhos, STEPS, DT, FINE)
	_check(engine.submit_lookahead_job(rhos, STEPS, DT, FINE), "submit an async packet")
	var deadline := Time.get_ticks_msec() + 20000
	while not engine.is_lookahead_job_complete() and Time.get_ticks_msec() < deadline:
		await process_frame
	var flat: Dictionary = engine.take_completed_lookahead_job()
	var rho_data: PackedFloat64Array = flat.get("rho", PackedFloat64Array())
	var offs: PackedInt32Array = flat.get("rho_off", PackedInt32Array())
	var ns: PackedInt32Array = flat.get("rho_n", PackedInt32Array())
	var strides: PackedInt32Array = flat.get("rho_stride", PackedInt32Array())
	var ok := offs.size() == N_OPEN + N_CLOSED
	for k in range(mini(offs.size(), N_OPEN + N_CLOSED)):
		var frames: Array = []
		for s in range(ns[k]):
			var a: int = offs[k] + s * strides[k]
			frames.append(rho_data.slice(a, a + strides[k]))
		if not _same(frames, _frames(sync_r, k)):
			ok = false
			printerr("    biome %d: async != sync (max %.3e)" % [k, _max_diff(frames, _frames(sync_r, k))])
	_check(ok, "the async packet (worker + its threads) matches the sync call")


# ---------------------------------------------------------------------- bench

func _time_ms(engine, rhos: Array, max_dt: float) -> float:
	var best := INF
	for _r in range(_reps):
		var t0 := Time.get_ticks_usec()
		engine.evolve_all_lookahead(rhos, STEPS, DT, max_dt)
		best = minf(best, float(Time.get_ticks_usec() - t0) / 1000.0)
	return best


func _bench(new_binary: bool) -> void:
	var made := _make(23)
	var engine = made[0]
	var rhos: Array = made[1]
	var cases := {}
	if new_binary:
		engine.set_max_threads(1)
	# What a packet cost before: one fine biome caps every biome in the packet.
	cases["one_thread_packet_min_cap"] = _time_ms(engine, rhos, FINE)
	# Everyone coarse (no fine biome): the floor of the old path.
	cases["one_thread_all_coarse"] = _time_ms(engine, rhos, COARSE)
	var threads := 1
	if new_binary:
		for k in range(N_OPEN + N_CLOSED):
			engine.set_biome_max_dt(k, FINE if k == 0 else COARSE)
		cases["one_thread_own_caps"] = _time_ms(engine, rhos, FINE)
		engine.set_max_threads(0)
		cases["threads_own_caps"] = _time_ms(engine, rhos, FINE)
		threads = int(engine.get_last_thread_count())
		# Balanced load: every biome at the same cap, so threads share it evenly.
		for k in range(N_OPEN + N_CLOSED):
			engine.set_biome_max_dt(k, 0.0)
		cases["threads_all_coarse"] = _time_ms(engine, rhos, COARSE)
		cases["threads_packet_min_cap"] = _time_ms(engine, rhos, FINE)
	print("NATIVE_BENCH " + JSON.stringify({
		"binary": "new" if new_binary else "old", "cases": cases, "threads": threads,
		"cpus": OS.get_processor_count(), "biomes": N_OPEN + N_CLOSED, "open": N_OPEN,
		"dim": _dim(), "steps": STEPS, "dt": DT, "fine": FINE, "coarse": COARSE,
	}))
