extends SceneTree

## strike_after_bell_probe.gd — the Charge lesson's strike, in Starter Forest (#90).
##
## Boots the real game headless (AppRoot path), all by hardware-style keys:
##   U (its slot)     Starter Forest
##   Ace (8) G F      explore plot G
##   E                pause the world (the player's pause; the banner's "more")
##   (prep)           project registers 0 and 1 onto |0⟩, so H + CNOT makes Φ+
##   9 ⇧G ⇧H R Q      Operator: mark G and H, Gate, Bell
##   8 G R            Ace: strike G
## and prints one line:
##
##   BELL_STRIKE {"paused", "bell": {...}, "strike": {...}, "after": {...}, "frames": [...]}
##
## `bell`/`after` read the live ρ (partial traces) and the viz cache the bubbles
## draw from, per register: p_north and Bloch z. `frames` is the viz cache vs
## live z of both registers over the 30 frames after the strike, still paused.
## Before #90 the cache kept the Bell state (z≈0, the bubble at the centre)
## while ρ sat at the poles: the strike "did nothing" until play resumed.
##
##   godot --headless --script tests/strike_after_bell_probe.gd
##
## tests/test_strike_after_bell.py runs it (RIG_UNLOCK_ALL=1: Operator is
## locked until the lesson opens it).

const BIOME := "StarterForest"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var prefix := OS.get_environment("SW_PROBE_USER_DIR_PREFIX").replace("\\", "/").to_lower()
	var user_dir := OS.get_user_data_dir().replace("\\", "/").to_lower()
	if prefix != "" and not user_dir.begins_with(prefix):
		printerr("BELL_STRIKE refusing to boot: user:// is not under SW_PROBE_USER_DIR_PREFIX")
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
		_fail("boot did not yield a farm")
		return
	var farm = app_root.game_root.farm
	var shell = app_root.get_player_shell()
	var inst = InstrumentLocator.resolve_quantum_instrument(shell)
	for e in ["🍞", "👥", "🧺", "⛰", "🍼"]:
		farm.economy.add_resource(e, 500, "probe")
	var strike := {}   # filled in place: lambdas capture locals by value
	var bell := {}
	inst.action_performed.connect(func(action: String, result: Dictionary):
		if action == "measure" and bool(result.get("success", false)):
			strike.merge(result, true)
		if action == "gate_inject" and str(result.get("gate", "")) == "bell":
			bell.merge(result, true))
	for _f in range(10): await process_frame

	var abm = get_root().get_node_or_null("/root/ActiveBiomeManager")
	if abm == null:
		_fail("no ActiveBiomeManager")
		return
	# The biome's slot key (TYUIOP), pressed like a player.
	var slot_key := ""
	for si in range(InputBindingRegistry.get_biome_keys().size()):
		if str(abm.get_biome_for_slot(si)) == BIOME:
			slot_key = str(abm.get_slot_key(si))
	if slot_key == "":
		_fail("%s has no biome slot" % BIOME)
		return
	await _press(OS.find_keycode_from_string(slot_key), 10)
	if str(abm.get_active_biome()) != BIOME:
		_fail("slot key %s did not open %s" % [slot_key, BIOME])
		return
	var forest = farm.grid.get_biome(BIOME)
	var qc = forest.quantum_computer

	# Ace: explore G (F also resumes play — explore before pausing).
	await _press(KEY_8)
	await _press(KEY_G)
	await _press(KEY_F, 8)
	var gp: Vector2i = farm.grid.get_plot_positions_for_biome(BIOME)[0]
	var plot = farm.grid.get_plot(gp)
	if plot == null or plot.terminal == null:
		_fail("F did not explore plot G of %s" % BIOME)
		return
	var reg_a: int = int(plot.terminal.bound_register_id)
	var reg_b: int = reg_a + 1

	# Pause, the player's way.
	await _press(KEY_E, 4)
	if not bool(shell.paused):
		_fail("E did not pause the world")
		return

	# |00⟩ on the pair, so the weave is exactly Φ+ = (|00⟩ + |11⟩)/√2.
	qc.project_qubit(reg_a, 0)
	qc.project_qubit(reg_b, 0)
	forest.refresh_viz_projection()

	# Operator: clear the marks ('), mark G and H, Gate (R), Bell (Q).
	await _press(KEY_9)
	if not inst.checked_plots.is_empty():
		await _press(KEY_APOSTROPHE)   # ' clears the marks
	await _press(KEY_G, 3, true)
	await _press(KEY_H, 3, true)
	await _press(KEY_R, 6)
	await _press(KEY_Q, 6)
	if not bool(bell.get("success", false)):
		_fail("Bell weave did not apply: %s" % JSON.stringify(bell))
		return
	var at_bell := _read(forest, reg_a, reg_b)
	var epoch_bell: int = int(qc.state_epoch)

	# Ace: strike G, still paused.
	await _press(KEY_8)
	await _press(KEY_G)
	await _press(KEY_R, 1)
	if strike.is_empty():
		_fail("R did not strike")
		return
	var frames: Array = []
	for f in range(31):
		if f in [0, 1, 5, 30]:
			var r := _read(forest, reg_a, reg_b)
			frames.append([f, r["a"]["cache_z"], r["a"]["live_z"], r["b"]["cache_z"], r["b"]["live_z"]])
		await process_frame
	print("BELL_STRIKE " + JSON.stringify({
		"paused": bool(shell.paused),
		"registers": [reg_a, reg_b],
		"bell": at_bell,
		"strike": {"register_id": int(strike.get("register_id", -1)),
			"outcome": str(strike.get("outcome", "")),
			"probability": float(strike.get("probability", -1.0)),
			"projective_collapse": bool(strike.get("projective_collapse", false)),
			"rho_written": int(qc.state_epoch) != epoch_bell},
		"after": _read(forest, reg_a, reg_b),
		"frames": frames,
	}))
	quit(0)


## Per register: live p_north and z (partial trace of ρ) and the viz cache's z;
## plus the pair's joint populations P(00), P(11).
func _read(biome, a: int, b: int) -> Dictionary:
	var qc = biome.quantum_computer
	var nq: int = int(qc.register_map.num_qubits)
	var p00 := 0.0
	var p11 := 0.0
	for i in range(int(qc.register_map.dim())):
		var ba := (i >> (nq - 1 - a)) & 1
		var bb := (i >> (nq - 1 - b)) & 1
		var d: float = qc.density_matrix.get_diagonal_real(i)
		if ba == 0 and bb == 0:
			p00 += d
		elif ba == 1 and bb == 1:
			p11 += d
	return {"a": _reg(biome, a), "b": _reg(biome, b), "p00": p00, "p11": p11}


func _reg(biome, q: int) -> Dictionary:
	var p0: float = float(biome.quantum_computer.get_marginal(q, 0))
	return {"p_north": p0, "live_z": 2.0 * p0 - 1.0,
		"cache_z": float(biome.viz_cache.get_bloch(q).get("z", 999.0))}


func _fail(why: String) -> void:
	printerr("BELL_STRIKE " + why)
	quit(1)


func _press(keycode: int, settle: int = 3, shift: bool = false) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.shift_pressed = shift
		ev.pressed = pressed
		get_root().push_input(ev, true)
		await process_frame
	for _i in range(settle):
		await process_frame
