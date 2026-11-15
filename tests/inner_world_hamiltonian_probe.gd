extends SceneTree

## inner_world_hamiltonian_probe.gd — does an inner (fractal) world carry H?
##
## Boots the real game headless (AppRoot, demos_normal), opens the 🦅/🐇 inner
## world from register 0 of the active biome (the fractal service's own inject +
## enter path, with the incorporation ledger and wallet funded), and reports:
##
##   INNER_H {...}   H of the inner world: dimension, max |H_ij|, Hermiticity
##                   error, Lindblad count, regime, the viz cache's H couplings
##   INNER_DORMANT {...} every plot dark: inner steps and drift (both must be 0)
##   INNER_EVO {...} max drift of ρ's diagonal over N frames, and purity
##   OUTER_EVO {...} the same for the outer biome before descending (no regression)
##   PAIR_ATOMS {...} H of a world opened from a pair whose library record has
##                   no physics (assembled from its atoms instead)
##   INNER_LOAD {...} after save → drop the world → load: was it rebuilt, with
##                   the same H and the same ρ?
##
##   godot --headless --script tests/inner_world_hamiltonian_probe.gd
##
## tests/test_inner_world_hamiltonian.py runs it.

const FRAMES := 120


func _init() -> void:
	call_deferred("_run")


func _diag(qc) -> Array:
	var r = qc.get_density_matrix()
	var out: Array = []
	for i in range(r.n):
		out.append(r.get_element(i, i).re)
	return out


func _drift(a: Array, b: Array) -> float:
	var d := 0.0
	for i in range(mini(a.size(), b.size())):
		d = maxf(d, absf(float(a[i]) - float(b[i])))
	return d


func _h_stats(H) -> Dictionary:
	if H == null:
		return {"n": 0, "max_abs": 0.0, "herm_err": 0.0}
	var mx := 0.0
	var herm := 0.0
	for i in range(H.n):
		for j in range(H.n):
			var a = H.get_element(i, j)
			var b = H.get_element(j, i)
			mx = maxf(mx, a.abs())
			herm = maxf(herm, absf(a.re - b.re) + absf(a.im + b.im))
	return {"n": H.n, "max_abs": mx, "herm_err": herm}


func _h_diff(A, B) -> float:
	if A == null or B == null or A.n != B.n:
		return INF
	var d := 0.0
	for i in range(A.n):
		for j in range(A.n):
			var a = A.get_element(i, j)
			var b = B.get_element(i, j)
			d = maxf(d, absf(a.re - b.re) + absf(a.im - b.im))
	return d


func _viz_h_terms(biome) -> int:
	var n := 0
	if biome.viz_cache == null or biome.quantum_computer == null:
		return 0
	for emoji in biome.quantum_computer.register_map.coordinates.keys():
		n += (biome.viz_cache.get_hamiltonian_couplings(emoji) as Dictionary).size()
	return n


func _emit(tag: String, d: Dictionary) -> void:
	print("%s %s" % [tag, JSON.stringify(d)])


func _run() -> void:
	var prefix := OS.get_environment("SW_PROBE_USER_DIR_PREFIX").replace("\\", "/").to_lower()
	var user_dir := OS.get_user_data_dir().replace("\\", "/").to_lower()
	if prefix != "" and not user_dir.begins_with(prefix):
		printerr("INNER_PROBE refusing to boot: user:// is not under SW_PROBE_USER_DIR_PREFIX")
		quit(2)
		return
	var app_root = load("res://scenes/AppRoot.gd").new()
	app_root.name = "AppRoot"
	get_root().add_child(app_root)
	var gsm = get_root().get_node_or_null("GameStateManager")
	if gsm and gsm.pending_boot:
		gsm.pending_boot.requested = true
		gsm.pending_boot.slot = -1
		gsm.pending_boot.scenario_id = "demos_normal"
	var booted := false
	for _i in range(3000):
		var gr = app_root.game_root if "game_root" in app_root else null
		if gr and is_instance_valid(gr) and gr._started and gr.farm != null:
			booted = true
			break
		await process_frame
	if not booted:
		printerr("INNER_PROBE boot did not yield a farm")
		quit(1)
		return
	var farm = app_root.game_root.farm
	var inst = farm.instrument
	var batcher = farm.biome_evolution_batcher
	var abm = get_root().get_node("/root/ActiveBiomeManager")
	for _f in range(10):
		await process_frame

	# --- Outer biome: still evolves (no regression). ---
	var outer_name := str(abm.get_active_biome())
	var outer_qc = farm.grid.get_biome(outer_name).quantum_computer
	# Attention rule (#75): a world with no lit plot is dormant. Light one
	# outer plot so the outer biome is attended while we measure it.
	var outer_pos: Array = farm.grid.get_plot_positions_for_biome(outer_name)
	var outer_ex: Dictionary = {}
	if not outer_pos.is_empty():
		outer_ex = inst.action_explore(outer_name, outer_pos[outer_pos.size() - 1])  # not register 0: that one opens the inner world
	var o0 := _diag(outer_qc)
	for _f in range(FRAMES):
		await process_frame
	_emit("OUTER_EVO", {"biome": outer_name, "drift": _drift(o0, _diag(outer_qc)),
		"purity": outer_qc.get_purity(), "lit": farm.terminal_pool.get_lit_count(),
		"explored": bool(outer_ex.get("success", false))})
	# Back to all-dark before descending, so the inner world starts unattended.
	for t in farm.terminal_pool.terminals:
		if t.is_bound and bool(t.lit):
			t.darken()

	# --- Open the 🦅/🐇 inner world through the fractal service. ---
	var north := "🦅"
	var south := "🐇"
	inst._fractal().on_inject(outer_name, 0, north, north, south)
	farm.incorporated_icons.append({"north": north, "south": south})
	for e in [south, "🌱"]:
		farm.economy.add_resource(e, 5000, "probe")
	var res: Dictionary = inst.action_enter_icon(outer_name, 0)
	if not bool(res.get("success", false)):
		printerr("INNER_PROBE enter_icon failed: %s" % str(res))
		quit(1)
		return
	var inner_name := str(res.get("biome_name", ""))
	var inner = farm.grid.get_biome(inner_name)
	var qc = inner.quantum_computer
	var hs := _h_stats(qc.hamiltonian)
	hs["biome"] = inner_name
	hs["dim"] = qc.register_map.dim()
	hs["lindblad"] = qc.lindblad_operators.size()
	hs["open"] = qc.is_open_here()
	hs["viz_h_terms"] = _viz_h_terms(inner)
	hs["active"] = str(abm.get_active_biome()) == inner_name
	_emit("INNER_H", hs)

	# All dark = dormant: the inner world takes no steps and ρ does not move.
	var d0 := _diag(qc)
	var dsteps0: int = int(batcher.get_biome_evolution_count(inner_name))
	for _f in range(FRAMES):
		await process_frame
	_emit("INNER_DORMANT", {
		"lit": farm.terminal_pool.get_lit_count(),
		"dormant": batcher.is_attention_dormant(),
		"steps": int(batcher.get_biome_evolution_count(inner_name)) - dsteps0,
		"drift": _drift(d0, _diag(qc)),
	})

	# Attend to the inner world: light a plot in it, then measure.
	var inner_pos: Array = farm.grid.get_plot_positions_for_biome(inner_name)
	var inner_ex: Dictionary = inst.action_explore(inner_name,
		inner_pos[0] if not inner_pos.is_empty() else GridSentinel.INVALID_POSITION)
	var r0 := _diag(qc)
	var min_purity := 1.0
	for f in range(FRAMES):
		await process_frame
		if f % 10 == 0:
			min_purity = minf(min_purity, qc.get_purity())
	_emit("INNER_EVO", {
		"drift": _drift(r0, _diag(qc)),
		"purity": qc.get_purity(),
		"min_purity": min_purity,
		"steps": int(batcher.get_biome_evolution_count(inner_name)) - dsteps0,
		"lit": farm.terminal_pool.get_lit_count(),
		"explored": bool(inner_ex.get("success", false)),
	})

	# --- A pair with no physics in its library record: H from its atoms. ---
	var Proc = load("res://Core/Environment/ProceduralIconBiome.gd")
	var reg = get_root().get_node("/root/IconRegistry")
	var bare := {}
	for r in reg.get_all():
		var p0 := str(r.get("pole_0", ""))
		var p1 := str(r.get("pole_1", ""))
		if p0 == "" or p1 == "" or p0 == p1 or bool(r.get("anonymous", false)):
			continue
		if Proc.has_physics(reg.get_icon_physics_by_pair(p0, p1)):
			continue
		if reg.get_atom(p0) == null or reg.get_atom(p1) == null:
			continue
		bare = {"pole_0": p0, "pole_1": p1}
		break
	if not bare.is_empty():
		var m: Dictionary = Proc.materialize(Proc.build_seed(bare.pole_0, bare.pole_0, bare.pole_1), "FX_probe_bare", null)
		var bqc = m.get("quantum_computer")
		var bs := _h_stats(bqc.hamiltonian if bqc else null)
		bs["pair"] = "%s/%s" % [bare.pole_0, bare.pole_1]
		bs["lindblad"] = bqc.lindblad_operators.size() if bqc else -1
		bs["purity"] = bqc.get_purity() if bqc else 0.0
		_emit("PAIR_ATOMS", bs)
		var bb = m.get("biome")
		if bb:
			bb.free()
	else:
		_emit("PAIR_ATOMS", {"pair": "", "n": 0})

	# --- Save → drop the inner world (a fresh session never boots it) → load. ---
	var H_before = qc.hamiltonian
	var sig_before := str(qc.physics_signature)
	var state = gsm.capture_state_from_game()
	var saved_rho: Array = _diag(qc)
	inst.action_ascend_fractal()
	await process_frame
	if farm.grid.has_biome(inner_name):
		var b = farm.grid.get_biome(inner_name)
		batcher.unregister_biome(b)
		farm.grid.unregister_biome(inner_name)
		b.queue_free()
		farm.refresh_grid_for_biomes()
	for _f in range(5):
		await process_frame
	var gone: bool = not farm.grid.has_biome(inner_name)
	await gsm.apply_state_to_game(state)
	var back = farm.grid.get_biome(inner_name) if farm.grid.has_biome(inner_name) else null
	var loaded := {"dropped": gone, "rebuilt": back != null}
	if back != null and back.quantum_computer != null:
		var lqc = back.quantum_computer
		loaded["same_signature"] = str(lqc.physics_signature) == sig_before
		loaded["h_diff"] = _h_diff(H_before, lqc.hamiltonian)
		loaded["rho_diff"] = _drift(saved_rho, _diag(lqc))
		loaded["lindblad"] = lqc.lindblad_operators.size()
		loaded["in_batcher"] = batcher.biomes.has(back)
	_emit("INNER_LOAD", loaded)
	quit(0)
