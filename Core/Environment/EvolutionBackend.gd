class_name EvolutionBackend
extends RefCounted

## THE MACHINERY CONTRACT — the abstraction Godot conducts through.
##
## SpaceWheat's design: Godot/GDScript is the CONDUCTOR (it picks what/when to evolve and
## reads results); it does NOT compute quantum dynamics. The MACHINERY (this backend)
## owns the state and runs the evolution. The batcher amortizes the ~20ms GDScript↔C++
## hand-off by batching many phrames per crossing (`evolve_all_lookahead`).
##
## Implementations:
##   • NativeBackend  — the C++ MultiBiomeLookaheadEngine (the real one, today)
##   • WebBackend     — WASM (different math) for the browser            [future]
##   • TorchBackend   — a tensor/torch evolver                          [future]
## All three are drop-ins behind THIS interface. The machinery does not care whether a
## state is pure or mixed — representation is its own internal concern; Godot just asks
## for observables (returned inside the evolve_* result dictionaries).
##
## A biome is registered once (operators copied in), then evolved in batches by id. The
## rho array passed to evolve_all_lookahead is indexed by registration id (slot i ↔
## biome id i); empty slots are skipped.

## Human-readable id, for logs/diagnostics.
func backend_name() -> String:
	return "abstract"

## Is this backend usable in the current runtime (library present, etc.)?
func is_available() -> bool:
	return false

# ── registration / operators ──────────────────────────────────────────────────────
func register_biome(_dim: int, _h_packed: PackedFloat64Array, _lindblad_triplets: Array, _num_qubits: int) -> int:
	return -1
## Rebuild an existing biome's operators IN PLACE (stable id) — for runtime H/L changes
## (gate inject, mode switch). Avoids orphaning engines / breaking the id↔slot mapping.
func reregister_biome(_biome_id: int, _dim: int, _h_packed: PackedFloat64Array, _lindblad_triplets: Array, _num_qubits: int) -> bool:
	return false
func clear_biomes() -> void:
	pass
func get_biome_count() -> int:
	return 0
func set_biome_metadata(_biome_id: int, _metadata: Dictionary) -> void:
	pass
func set_biome_couplings(_biome_id: int, _couplings: Dictionary) -> void:
	pass
func set_biome_center(_biome_id: int, _center: Vector2) -> void:
	pass

## Two-axis generator switch (per biome): gate the coherent −i[H,ρ] term on/off.
## Dissipation is gated implicitly by whether Lindblad operators were registered.
func set_biome_coherent(_biome_id: int, _on: bool) -> void:
	pass

# ── runtime toggles ───────────────────────────────────────────────────────────────
func set_pacing_delay_ms(_ms: int) -> void:
	pass
func set_enable_mi(_on: bool) -> void:
	pass
func set_enable_force(_on: bool) -> void:
	pass
func enable_biome_lnn(_biome_id: int, _hidden_size: int) -> void:
	pass
func is_lnn_enabled(_biome_id: int) -> bool:
	return false

# ── evolution (the batched crossing) ──────────────────────────────────────────────
## Evolve ALL registered biomes `steps` phrames in one crossing. `biome_rhos[id]` is the
## current ρ for biome id (empty = skip). Returns the lookahead result dictionary
## (results/bloch_steps/purity_steps/mi_steps/position_steps per biome).
func evolve_all_lookahead(_biome_rhos: Array, _steps: int, _dt: float, _max_dt: float) -> Dictionary:
	return {}
func evolve_single_biome(_biome_id: int, _rho_packed: PackedFloat64Array, _steps: int, _dt: float, _max_dt: float) -> Dictionary:
	return {}

# ── produce / take (compute layer mouth) ──────────────────────────────────────────
## Desktop native only. Web compiles submit as a sync pretend-complete — report false.
func has_async_lookahead() -> bool:
	return false
func submit_lookahead_job(_biome_rhos: Array, _steps: int, _dt: float, _max_dt: float) -> bool:
	return false
func is_lookahead_job_running() -> bool:
	return false
func is_lookahead_job_complete() -> bool:
	return false
func take_completed_lookahead_job() -> Dictionary:
	return {}
func cancel_lookahead_job(_wait: bool = true) -> void:
	pass
func set_node_positions(_biome_id: int, _positions: PackedVector2Array) -> void:
	pass


## Factory: the active machinery backend for this runtime. Native today; web/torch later
## select here by platform/feature. Returns null if no backend is available.
static func create() -> EvolutionBackend:
	var nb := NativeBackend.new()
	if nb.is_available():
		return nb
	return null
