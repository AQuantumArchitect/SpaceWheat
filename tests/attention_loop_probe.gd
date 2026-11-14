extends SceneTree

## attention_loop_probe.gd — Ace's attention loop on the real game (#75).
##
## Boots a new game headless and walks it, one ATTN line per check:
##   boot     every plot dark: dormant, no evolution, no music, ρ unchanged
##            across 60 s of play time (600 physics ticks at 10 Hz)
##   explore  F lights a plot: evolution steps, music plays
##   pause    the pause button stops evolution, and with it the music; music
##            follows the evolution signal, not the button (a step reported
##            while paused would start it)
##   strike   R banks and darkens: all dark again, dormant, music stops
##   gather   Q pays the bank, ρ bit-identical, the dark plot returns to fog
##   unstruck Q on a lit, never-struck plot: ρ bit-identical, nothing paid
##   save     save while dormant, load: same ρ, still dormant
##
##   godot --headless --audio-driver Dummy --fixed-fps 10 --script tests/attention_loop_probe.gd
## tests/test_attention_loop.py runs it.

var farm
var inst
var shell


func _init() -> void:
	call_deferred("_run")


func _emit(check: String, data: Dictionary) -> void:
	data["check"] = check
	print("ATTN " + JSON.stringify(data))


func _run() -> void:
	var prefix := OS.get_environment("SW_PROBE_USER_DIR_PREFIX").replace("\\", "/").to_lower()
	var user_dir := OS.get_user_data_dir().replace("\\", "/").to_lower()
	if prefix != "" and not user_dir.begins_with(prefix):
		printerr("ATTN refusing to boot: user:// is not under SW_PROBE_USER_DIR_PREFIX")
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
	if not await _wait_farm(app_root):
		printerr("ATTN boot did not yield a farm")
		quit(1)
		return
	shell = app_root.get_player_shell()
	inst = InstrumentLocator.resolve_quantum_instrument(shell)
	for e in ["🍞", "👥", "🧺"]:
		farm.economy.add_resource(e, 5000, "probe")
	var music = get_root().get_node_or_null("/root/MusicManager")
	var batcher = farm.biome_evolution_batcher
	await _frames(20)

	# boot: all dark.
	var rho0: Dictionary = _rho()
	var steps0: int = batcher.evolution_step_total
	await _physics(600)
	_emit("boot", {"lit": farm.terminal_pool.get_lit_count(), "dormant": batcher.is_attention_dormant(),
		"running": batcher.is_evolution_running(), "music": music.is_music_playing(),
		"steps": batcher.evolution_step_total - steps0, "rho_same": _rho() == rho0})

	# explore: F lights a StarterForest plot.
	var positions: Array = farm.grid.get_plot_positions_for_biome("StarterForest")
	var pos_a: Vector2i = positions[0]
	var pos_b: Vector2i = positions[1]
	var ex: Dictionary = inst.action_explore("StarterForest", pos_a)
	var steps1: int = batcher.evolution_step_total
	await _physics(40)
	_emit("explore", {"ok": bool(ex.get("success", false)), "lit": farm.terminal_pool.get_lit_count(),
		"steps": batcher.evolution_step_total - steps1, "running": batcher.is_evolution_running(),
		"music": music.is_music_playing()})

	# pause: the pause button (the time-flow chip calls this).
	var heard: Array = []
	batcher.evolution_running.connect(func(r: bool): heard.append(r))
	shell.toggle_paused()
	await _physics(30)
	var steps2: int = batcher.evolution_step_total
	await _physics(30)
	var paused_steps: int = batcher.evolution_step_total - steps2
	var paused_running: bool = batcher.is_evolution_running()
	var paused_music: bool = music.is_music_playing()
	# Causality: music is wired to the evolution layer's signal (and the
	# batcher really said "stopped"); the Python side pins that MusicManager
	# never reads the pause flag, the lit count or terminal signals.
	var follows: bool = batcher.evolution_running.is_connected(music._on_evolution_running)

	_emit("pause", {"paused": bool(shell.paused), "steps": paused_steps, "running": paused_running,
		"music": paused_music, "music_follows_signal": follows, "heard": heard})
	shell.toggle_paused()
	await _physics(40)
	var resumed_music: bool = music.is_music_playing()

	# strike: R banks and darkens; all dark = dormant.
	var st: Dictionary = inst.action_measure(pos_a)
	await _physics(30)
	var steps3: int = batcher.evolution_step_total
	var rho3: Dictionary = _rho()
	await _physics(60)
	var term = farm.grid.get_plot(pos_a).terminal
	_emit("strike", {"ok": bool(st.get("success", false)), "banked": term.banked_totals() if term else {},
		"term_lit": bool(term.lit) if term else null, "lit": farm.terminal_pool.get_lit_count(),
		"dormant": batcher.is_attention_dormant(), "steps": batcher.evolution_step_total - steps3,
		"rho_same": _rho() == rho3, "music": music.is_music_playing(), "resumed_music": resumed_music})

	# gather: Q pays the bank, ρ untouched.
	var wallet_before: Dictionary = _wallet()
	var rho4: Dictionary = _rho()
	var q: Dictionary = inst.action_pop(pos_a)
	var rho_after: Dictionary = _rho()
	_emit("gather", {"ok": bool(q.get("success", false)), "noop": bool(q.get("noop", false)),
		"banked": q.get("banked", {}), "paid": _gain(wallet_before, _wallet()),
		"rho_same": rho_after == rho4, "terminal": farm.grid.get_plot(pos_a).terminal != null})

	# unstruck: F lights plot B, Q at once — nothing banked, nothing changes.
	inst.action_explore("StarterForest", pos_b)
	var wallet_b: Dictionary = _wallet()
	var rho5: Dictionary = _rho()
	var q2: Dictionary = inst.action_pop(pos_b)
	var rho5_after: Dictionary = _rho()
	var tb = farm.grid.get_plot(pos_b).terminal
	_emit("unstruck", {"ok": bool(q2.get("success", false)), "noop": bool(q2.get("noop", false)),
		"paid": _gain(wallet_b, _wallet()), "rho_same": rho5_after == rho5,
		"still_lit": tb != null and bool(tb.lit)})

	# save while dormant, then load.
	inst.action_measure(pos_b)
	await _physics(30)
	var rho6: Dictionary = _rho()
	var dormant_before: bool = batcher.is_attention_dormant()
	var saved: bool = gsm.save_load.save_game(0)
	var loaded: bool = await gsm.save_load.load_and_apply(0)
	if not await _wait_farm(get_root().get_node("AppRoot")):
		printerr("ATTN load did not yield a farm")
		quit(1)
		return
	await _frames(20)
	var b2 = farm.biome_evolution_batcher
	var steps7: int = b2.evolution_step_total
	await _physics(60)
	var tb2 = farm.grid.get_plot(pos_b).terminal
	_emit("save", {"saved": saved, "loaded": loaded, "dormant_before": dormant_before,
		"dormant": b2.is_attention_dormant(), "lit": farm.terminal_pool.get_lit_count(),
		"steps": b2.evolution_step_total - steps7, "rho_same": _rho() == rho6,
		"rho_close": _max_diff(rho6, _rho()).values().all(func(d): return d >= 0.0 and d <= 1e-12),
		"bank_kept": tb2 != null and tb2.has_banked(), "music": music.is_music_playing()})
	quit(0)


func _wait_farm(app_root) -> bool:
	for _i in range(3000):
		var gr = app_root.game_root if "game_root" in app_root else null
		if gr and is_instance_valid(gr) and gr._started and gr.farm != null and is_instance_valid(gr.farm):
			farm = gr.farm
			return true
		await process_frame
	return false


## Every biome's ρ as exact doubles (re, im per element): == is bit-identical.
func _rho() -> Dictionary:
	var out := {}
	var biomes: Dictionary = farm.grid.get_all_biomes()
	for name in biomes:
		var qc = biomes[name].quantum_computer
		if qc == null or qc.density_matrix == null:
			continue
		var m = qc.density_matrix
		var flat := PackedFloat64Array()
		for i in range(m.n):
			for j in range(m.n):
				var c = m.get_element(i, j)
				flat.append(c.re)
				flat.append(c.im)
		out[str(name)] = flat
	return out


func _max_diff(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := {}
	for k in a:
		var x: PackedFloat64Array = a[k]
		var y: PackedFloat64Array = b.get(k, PackedFloat64Array())
		var m := 0.0
		if x.size() != y.size():
			m = -1.0
		else:
			for i in range(x.size()):
				m = maxf(m, absf(x[i] - y[i]))
		out[k] = m
	return out


func _wallet() -> Dictionary:
	var out := {}
	for e in ["🌱", "🌿", "🍂", "💀", "🍄", "🌾", "🐺", "🐇", "🍞", "👥", "🧺"]:
		out[e] = int(farm.economy.get_resource(e)) if farm.economy.has_method("get_resource") else 0
	return out


func _gain(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := {}
	for e in b:
		var d := int(b[e]) - int(a.get(e, 0))
		if d != 0:
			out[e] = d
	return out


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _physics(n: int) -> void:
	for _i in range(n):
		await physics_frame
