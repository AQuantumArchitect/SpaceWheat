extends SceneTree

## Issue #124, live half: boot the real game, track Village's 🔥/❄ qubit and
## step it through the same time_skip seam Ace F uses, one phrame at a time, on
## the native engine. Emits the per-slice turn, the lowest |r|, the closest
## approach to either pole and Ω — the preconditions for suspects (b), (c), (a).
##
## Run: godot --headless --audio-driver Dummy --path . --script tests/berry_fire_ice_live_probe.gd

const PHRAMES: int = 4500   # five Ace-F presses' worth (BERRY_RIPEN_CAP = 900 each)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var app_root = load("res://scenes/AppRoot.gd").new()
	app_root.name = "AppRoot"
	get_root().add_child(app_root)
	var gsm = get_root().get_node_or_null("GameStateManager")
	if gsm and gsm.pending_boot:
		gsm.pending_boot.requested = true
		gsm.pending_boot.slot = -1
		gsm.pending_boot.scenario_id = "new_game_easy"
	var farm = null
	for _i in range(3000):
		var gr = app_root.game_root if "game_root" in app_root else null
		if gr and is_instance_valid(gr) and gr._started and gr.farm != null:
			farm = gr.farm
			break
		await process_frame
	if farm == null:
		printerr("FIRE_ICE_PROBE boot did not yield a farm")
		quit(1)
		return
	var inst = InstrumentLocator.resolve_quantum_instrument(app_root.get_player_shell())
	var qc = farm.grid.get_biome("Village").quantum_computer
	var q: int = qc.qubit("🔥")
	qc.berry_register.start_tracking(q)
	var prev := Vector3.ZERO
	var max_turn := 0.0
	var sum_turn := 0.0
	var min_r := 9.0
	var min_pole := 9.0
	var omega_at: Array = []
	for i in range(PHRAMES):
		inst.time_skip(1)
		var p: PackedFloat64Array = qc.export_bloch_packet()
		var v := Vector3(p[q * 9 + 2], p[q * 9 + 3], p[q * 9 + 4]).normalized()
		min_r = minf(min_r, p[q * 9 + 5])
		min_pole = minf(min_pole, minf(v.angle_to(Vector3.BACK), v.angle_to(Vector3.FORWARD)))
		if i > 0:
			var a: float = prev.angle_to(v)
			max_turn = maxf(max_turn, a)
			sum_turn += a
		prev = v
		if (i + 1) % 900 == 0:
			omega_at.append(qc.berry_register.get_phase(q))
	print("FIRE_ICE " + JSON.stringify({
		"phrames": PHRAMES,
		"max_turn": max_turn,
		"mean_turn": sum_turn / float(PHRAMES - 1),
		"min_r": min_r,
		"min_pole_dist": min_pole,
		"omega_every_900": omega_at,
		"omega": qc.berry_register.get_phase(q),
		"ripe": qc.berry_register.is_ripe(q),
	}))
	quit(0)
