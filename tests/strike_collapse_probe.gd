extends SceneTree

## strike_collapse_probe.gd — does a strike's collapse survive the next frames?
##
## Boots the real game headless (AppRoot path) and writes ρ three ways, reading
## the written register's north marginal (QC partial trace) over the following
## frames. One line per case:
##
##   STRIKE_TRACE {"path", "lookahead", "biome", "register", "expect", "before", "trace": [[frame, p_north], …]}
##
##   keys    the player's path: Ace (8), plot G, explore F, strike R, pushed
##           through the viewport exactly like a hardware key (TheDemos)
##   direct  QuantumInstrument.action_measure called directly (rig drivers,
##           ReelRunner, anything that skips QuantumInstrumentInput)
##   gate    an X gate through GateInjector.inject_gate (p → 1 − p)
##   raw     an X gate straight on the QuantumComputer, no helper at all
##   pump    a standing pump contract (open regime) ticked by Farm every physics
##           frame, rate 20 so it outruns any H: the north marginal goes to ~1
##
## `expect` is the p_north the write produced; `before` the p_north it replaced.
## Before 2026-11-10 the direct strike and the gate were overwritten within ~2
## frames by the batcher's stale lookahead frames; the keys path was fine only
## because QuantumInstrumentInput invalidated after player actions. Since
## 2026-11-11 the batcher notices any write to ρ itself (QuantumComputer.state_epoch)
## and nobody invalidates by hand.
##
##   godot --headless --script tests/strike_collapse_probe.gd
##
## Set SW_PROBE_USER_DIR_PREFIX to refuse to boot unless user:// resolves under it.
## tests/test_lookahead_follows_writes.py runs it with lookahead on.

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var prefix := OS.get_environment("SW_PROBE_USER_DIR_PREFIX").replace("\\", "/").to_lower()
	var user_dir := OS.get_user_data_dir().replace("\\", "/").to_lower()
	print("GLYPH_PROBE user_dir=%s" % user_dir)
	if prefix != "" and not user_dir.begins_with(prefix):
		printerr("GLYPH_PROBE refusing to boot: user:// is not under SW_PROBE_USER_DIR_PREFIX")
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
		printerr("GLYPH_PROBE boot did not yield a farm")
		quit(1)
	var app = get_root().get_node_or_null("AppRoot")
	var farm = app.game_root.farm
	var shell = app.get_player_shell()
	var inst = InstrumentLocator.resolve_quantum_instrument(shell)
	for e in ["🍞", "👥"]:
		farm.economy.add_resource(e, 5000, "probe")
	var strike := {}   # filled in place: lambdas capture locals by value
	var on_action := func(action: String, result: Dictionary):
		if action == "measure" and bool(result.get("success", false)):
			strike.merge(result, true)
	inst.action_performed.connect(on_action)
	seed(42)
	for _f in range(10): await process_frame
	var lookahead: bool = not RuntimeEnv.disable_lookahead()

	# keys: the player's strike in the active biome.
	await _press(KEY_8)
	await _press(KEY_G)
	await _press(KEY_F, 8)
	await _press(KEY_R, 1)
	var abm = get_root().get_node_or_null("/root/ActiveBiomeManager")
	if strike.is_empty() or abm == null:
		printerr("STRIKE_PROBE keys: no successful strike")
		quit(1)
		return
	await _trace("keys", lookahead, farm.grid.get_biome(str(abm.get_active_biome())), strike, -1.0)

	# direct: QuantumInstrument.action_measure, as rig drivers call it.
	strike.clear()
	var forest = farm.grid.get_all_biomes()["StarterForest"]
	var pos: Vector2i = farm.grid.get_plot_positions_for_biome("StarterForest")[1]
	inst.action_explore("StarterForest", pos)
	for _f in range(5): await process_frame
	inst.action_measure(pos)
	if strike.is_empty():
		printerr("STRIKE_PROBE direct: no successful strike")
		quit(1)
		return
	await _trace("direct", lookahead, forest, strike, -1.0)

	# gate: X through GateInjector flips the register's populations.
	var village = farm.grid.get_all_biomes()["Village"]
	var before := _p_north(village, 0)
	var lib = QuantumGateLibrary.new()
	GateInjector.inject_gate(village, 0, lib.GATES["X"]["matrix"], farm)
	await _trace("gate", lookahead, village, {"register_id": 0}, 1.0 - before, before)

	# raw: the same flip with no helper in between — QuantumComputer only.
	before = _p_north(village, 1)
	village.quantum_computer.apply_pauli_x(1)
	await _trace("raw", lookahead, village, {"register_id": 1}, 1.0 - before, before)

	# pump: a standing contract, ticked by Farm every physics frame. Farm only
	# ticks contracts once the world is open (the endgame door's switch).
	BalanceConfig.merge_physics_override({"dissipative_dynamics": true})
	var fqc = forest.quantum_computer
	fqc.regime_override = "open"
	fqc.set_register_infra_field(0, "lindblad_channel_kind", "damp")
	fqc.set_register_infra_field(0, "lindblad_pump_rate", 20.0)
	fqc.set_register_infra_field(0, "lindblad_pump_active", true)
	var pumped: Array = [[0, _p_north(forest, 0)]]
	for t in range(1, 41):
		await physics_frame
		if t in [1, 2, 5, 10, 20, 30, 40]:
			pumped.append([t, _p_north(forest, 0)])
	print("STRIKE_TRACE " + JSON.stringify({"path": "pump", "lookahead": lookahead,
		"biome": "StarterForest", "register": 0, "expect": 1.0, "before": pumped[0][1], "trace": pumped}))
	quit(0)


## Print the written register's p_north at frames 0..60 after the write.
func _trace(path: String, lookahead: bool, biome, strike: Dictionary, expect: float, before: float = -1.0) -> void:
	var reg: int = int(strike.get("register_id", 0))
	if expect < 0.0:
		var north := str(biome.quantum_computer.register_map.axes[reg]["north"])
		var outcome_north := str(strike.get("outcome", "")) == north
		var p_outcome := float(strike.get("probability", 0.5))
		expect = 1.0 if outcome_north else 0.0
		before = p_outcome if outcome_north else 1.0 - p_outcome
	var trace: Array = [[0, _p_north(biome, reg)]]
	for f in range(1, 61):
		await process_frame
		if f in [1, 2, 3, 5, 10, 20, 30, 45, 60]:
			trace.append([f, _p_north(biome, reg)])
	print("STRIKE_TRACE " + JSON.stringify({"path": path, "lookahead": lookahead,
		"biome": BiomeBase.type_name(biome), "register": reg, "expect": expect, "before": before,
		"dt": biome.max_evolution_dt, "stride": biome.observation_stride, "trace": trace}))


func _p_north(biome, q: int) -> float:
	if biome == null:
		return -1.0
	return float(biome.quantum_computer.get_marginal_density_matrix(null, q).get_element(0, 0).re)


func _press(keycode: int, settle: int = 3) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		get_root().push_input(ev, true)
		await process_frame
	for _i in range(settle):
		await process_frame
