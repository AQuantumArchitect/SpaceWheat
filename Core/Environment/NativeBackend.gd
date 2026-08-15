class_name NativeBackend
extends EvolutionBackend

## C++ machinery backend — wraps the native MultiBiomeLookaheadEngine.
##
## This is the real, fast engine: it amortizes the ~20ms GDScript↔C++ crossing by
## batching all biomes × all lookahead phrames per call, and (after Phase 1) evolves the
## closed system by the EXACT unitary propagator. The batcher holds an EvolutionBackend
## and talks to it through the contract; this class forwards to the C++ engine and is
## where native-only wiring (per-biome switches) lives.

var _engine = null  # the C++ MultiBiomeLookaheadEngine instance


func _init() -> void:
	if native_available():
		_engine = ClassDB.instantiate("MultiBiomeLookaheadEngine")


## Is the native extension loaded (the C++ class registered)?
static func native_available() -> bool:
	return ClassDB.class_exists("MultiBiomeLookaheadEngine")


func backend_name() -> String:
	return "native_cpp"


func is_available() -> bool:
	return _engine != null


## Direct access to the wrapped engine (transitional — for the few async/job calls the
## contract doesn't yet cover). Prefer the contract methods.
func engine():
	return _engine


# ── registration / operators ──────────────────────────────────────────────────────
func register_biome(dim: int, h_packed: PackedFloat64Array, lindblad_triplets: Array, num_qubits: int) -> int:
	return _engine.register_biome(dim, h_packed, lindblad_triplets, num_qubits) if _engine else -1

func reregister_biome(biome_id: int, dim: int, h_packed: PackedFloat64Array, lindblad_triplets: Array, num_qubits: int) -> bool:
	if _engine and _engine.has_method("reregister_biome"):
		return _engine.reregister_biome(biome_id, dim, h_packed, lindblad_triplets, num_qubits)
	return false

func clear_biomes() -> void:
	if _engine:
		_engine.clear_biomes()

func get_biome_count() -> int:
	return _engine.get_biome_count() if _engine else 0

func set_biome_metadata(biome_id: int, metadata: Dictionary) -> void:
	if _engine and _engine.has_method("set_biome_metadata"):
		_engine.set_biome_metadata(biome_id, metadata)

func set_biome_couplings(biome_id: int, couplings: Dictionary) -> void:
	if _engine and _engine.has_method("set_biome_couplings"):
		_engine.set_biome_couplings(biome_id, couplings)

func set_biome_center(biome_id: int, center: Vector2) -> void:
	if _engine and _engine.has_method("set_biome_center"):
		_engine.set_biome_center(biome_id, center)

func set_biome_coherent(biome_id: int, on: bool) -> void:
	# The per-biome coherent switch lives on the inner QuantumEvolutionEngine; exposed via
	# the multi-biome engine only if the native build provides it. No-op otherwise (the
	# C++ default is coherent=on, correct for the shipping closed + full-open modes).
	if _engine and _engine.has_method("set_biome_coherent"):
		_engine.set_biome_coherent(biome_id, on)


# ── runtime toggles ───────────────────────────────────────────────────────────────
func set_pacing_delay_ms(ms: int) -> void:
	if _engine and _engine.has_method("set_pacing_delay_ms"):
		_engine.set_pacing_delay_ms(ms)

func set_enable_mi(on: bool) -> void:
	if _engine and _engine.has_method("set_enable_mi"):
		_engine.set_enable_mi(on)

func set_enable_force(on: bool) -> void:
	if _engine and _engine.has_method("set_enable_force"):
		_engine.set_enable_force(on)

func enable_biome_lnn(biome_id: int, hidden_size: int) -> void:
	if _engine and _engine.has_method("enable_biome_lnn"):
		_engine.enable_biome_lnn(biome_id, hidden_size)

func is_lnn_enabled(biome_id: int) -> bool:
	return _engine.is_lnn_enabled(biome_id) if (_engine and _engine.has_method("is_lnn_enabled")) else false


# ── evolution ─────────────────────────────────────────────────────────────────────
func evolve_all_lookahead(biome_rhos: Array, steps: int, dt: float, max_dt: float) -> Dictionary:
	return _engine.evolve_all_lookahead(biome_rhos, steps, dt, max_dt) if _engine else {}

func evolve_single_biome(biome_id: int, rho_packed: PackedFloat64Array, steps: int, dt: float, max_dt: float) -> Dictionary:
	return _engine.evolve_single_biome(biome_id, rho_packed, steps, dt, max_dt) if _engine else {}


# ── produce / take ────────────────────────────────────────────────────────────────
func has_async_lookahead() -> bool:
	# SPACEWHEAT_WEB_BUILD compiles submit as a blocking pretend-complete.
	# OS.has_feature("web") is the runtime twin of that ifdef.
	if _engine == null or OS.has_feature("web"):
		return false
	return _engine.has_method("submit_lookahead_job")

func submit_lookahead_job(biome_rhos: Array, steps: int, dt: float, max_dt: float) -> bool:
	if _engine == null or not _engine.has_method("submit_lookahead_job"):
		return false
	return bool(_engine.submit_lookahead_job(biome_rhos, steps, dt, max_dt))

func is_lookahead_job_running() -> bool:
	return bool(_engine.is_lookahead_job_running()) if (_engine and _engine.has_method("is_lookahead_job_running")) else false

func is_lookahead_job_complete() -> bool:
	return bool(_engine.is_lookahead_job_complete()) if (_engine and _engine.has_method("is_lookahead_job_complete")) else false

func take_completed_lookahead_job() -> Dictionary:
	if _engine and _engine.has_method("take_completed_lookahead_job"):
		var taken = _engine.take_completed_lookahead_job()
		return taken if taken is Dictionary else {}
	return {}

func cancel_lookahead_job(wait: bool = true) -> void:
	if _engine and _engine.has_method("cancel_lookahead_job"):
		_engine.cancel_lookahead_job(wait)

func set_node_positions(biome_id: int, positions: PackedVector2Array) -> void:
	if _engine and _engine.has_method("set_node_positions"):
		_engine.set_node_positions(biome_id, positions)
