extends SceneTree

## harvest_juice_probe.gd — the harvest loop's feedback (#60), on the real game.
##
## Boots demos_normal headless, then:
##
##   JUICE_TRACE {"phase": "settings"}  intensity + reduced motion round-trip through
##                                      user://spacewheat_settings.cfg (audio keys kept)
##   JUICE_TRACE {"phase": "ladder"}    the Gather combo ladder climbs inside the
##                                      window and resets after it
##   JUICE_TRACE {"phase": "scale"}     a routine vs a rare harvest: sparks, badge,
##                                      hitstop; then the same rare one under
##                                      reduced motion and at intensity 0
##   JUICE_TRACE {"phase": "loop"}      a real Explore → Strike → Gather: the layer
##                                      celebrates and SFXRegistry plays the thump
##   JUICE_TRACE {"phase": "ripe"}      a tracked plot ripens: one chime, and an
##                                      already-ripe plot primes silently
##
##   godot --headless --script tests/harvest_juice_probe.gd
##
## tests/test_harvest_juice.py runs it. Set SW_PROBE_USER_DIR_PREFIX to refuse
## to boot unless user:// resolves under it.


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	printerr("JUICE_PROBE " + msg)
	quit(1)


func _trace(d: Dictionary) -> void:
	print("JUICE_TRACE " + JSON.stringify(d))


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _find(n: Node, cls):
	if is_instance_of(n, cls):
		return n
	for c in n.get_children():
		var hit = _find(c, cls)
		if hit != null:
			return hit
	return null


## [sparks emitted, badges] currently alive under the layer.
func _juice_nodes(layer: Node) -> Dictionary:
	var sparks := 0
	var bursts := 0
	var badges := 0
	for c in layer.get_children():
		if c is FloatingRewardLayer.SparkBurst:
			bursts += 1
			sparks += c._pos.size()
		elif c is TextureRect:
			badges += 1
	return {"bursts": bursts, "sparks": sparks, "badges": badges}


func _clear_juice(layer: Node) -> void:
	for c in layer.get_children():
		if c is FloatingRewardLayer.SparkBurst or c is TextureRect \
				or c is FloatingRewardLayer.RingBurst or c is ColorRect:
			c.free()


func _run() -> void:
	var prefix := OS.get_environment("SW_PROBE_USER_DIR_PREFIX").replace("\\", "/").to_lower()
	var user_dir := OS.get_user_data_dir().replace("\\", "/").to_lower()
	if prefix != "" and not user_dir.begins_with(prefix):
		printerr("JUICE_PROBE refusing to boot: user:// is not under SW_PROBE_USER_DIR_PREFIX")
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
	var sfx = get_root().get_node_or_null("SFXRegistry")
	var layer = _find(get_root(), FloatingRewardLayer)
	if layer == null or sfx == null or inst == null:
		_fail("no FloatingRewardLayer / SFXRegistry / instrument")
		return
	seed(11)
	await _frames(10)

	# settings
	sfx.set_volume(0.4)
	FeedbackTuning.set_intensity(0.5)
	FeedbackTuning.set_reduced_motion(true)
	FeedbackTuning.reload()
	var cfg := ConfigFile.new()
	cfg.load(FeedbackTuning.CONFIG_PATH)
	_trace({"phase": "settings", "intensity": FeedbackTuning.intensity(),
		"reduced_motion": FeedbackTuning.reduced_motion(), "motion": FeedbackTuning.motion(),
		"file_intensity": float(cfg.get_value("feedback", "intensity", -1.0)),
		"file_reduced": bool(cfg.get_value("feedback", "reduced_motion", false)),
		"file_sfx_volume": float(cfg.get_value("audio", "sfx_volume", -1.0))})
	FeedbackTuning.set_intensity(1.0)
	FeedbackTuning.set_reduced_motion(false)

	# ladder
	var w := FeedbackTuning.COMBO_WINDOW_MS
	var steps: Array = []
	sfx._last_pop_ms = -1000000
	var t := 1000000
	for dt in [0, w / 2, w / 2, w / 2, w * 3, 10]:
		t += int(dt)
		steps.append(sfx._step_pop_chain(t))
	_trace({"phase": "ladder", "steps": steps, "window_ms": w})

	# scale
	var centre: Vector2 = layer.get_viewport_rect().size * 0.5
	_clear_juice(layer)
	layer.celebrate_harvest(centre, 0.1)
	var routine := _juice_nodes(layer)
	_clear_juice(layer)
	layer.celebrate_harvest(centre, 0.95)
	var rare := _juice_nodes(layer)
	var rare_dip := Engine.time_scale
	await _frames(2)
	await create_timer(0.3, true, false, true).timeout
	var restored := Engine.time_scale
	_clear_juice(layer)
	FeedbackTuning.set_reduced_motion(true)
	layer.celebrate_harvest(centre, 0.95)
	var reduced := _juice_nodes(layer)
	var reduced_scale := Engine.time_scale
	FeedbackTuning.set_reduced_motion(false)
	FeedbackTuning.set_intensity(0.0)
	layer.celebrate_harvest(centre, 0.95)
	var off := _juice_nodes(layer)
	FeedbackTuning.set_intensity(1.0)
	await create_timer(0.3, true, false, true).timeout
	_clear_juice(layer)
	_trace({"phase": "scale", "routine": routine, "rare": rare, "rare_time_scale": rare_dip,
		"restored_time_scale": restored, "reduced": reduced, "reduced_time_scale": reduced_scale,
		"off": off})

	# loop: Explore → Strike → Gather on a StarterForest plot.
	for e in ["🍞", "👥", "⛰", "🌾", "🧺"]:
		farm.economy.add_resource(e, 5000, "probe")
	var abm = get_root().get_node_or_null("ActiveBiomeManager")
	if abm != null:
		abm.set_active_biome("StarterForest")
		await _frames(5)
	var pops: Array = []
	var on_action := func(action: String, result: Dictionary):
		if action == "pop":
			pops.append(result)
	inst.action_performed.connect(on_action)
	var positions: Array = farm.grid.get_plot_positions_for_biome("StarterForest")
	var pos: Vector2i = positions[0]
	for p in sfx._players:
		p.stream = null
	inst.action_explore("StarterForest", pos)
	await _frames(5)
	inst.action_measure(pos)
	await _frames(5)
	_clear_juice(layer)
	inst.action_pop(pos)
	var after_pop := _juice_nodes(layer)
	var streams: Array = []
	for p in sfx._players:
		if p.stream != null:
			streams.append(p.stream.resource_path.get_file())
	var pop_ok := pops.size() > 0 and bool(pops[0].get("success", false))
	_trace({"phase": "loop", "popped": pop_ok,
		"size": FeedbackTuning.harvest_size(pops[0]) if pops.size() > 0 else -1.0,
		"juice": after_pop, "streams": streams})
	await create_timer(0.3, true, false, true).timeout

	# ripe: an already-ripe plot primes silently; a fresh ripening chimes once.
	var berry = layer._active_berry_register()[1]
	var ripe_rows := {}
	if berry != null:
		berry.start_tracking(0)
		berry._state[0]["accumulated"] = TAU * 2.0
		layer._ripe_biome = ""  # as if we had just arrived in this biome
		for p in sfx._players:
			p.stream = null
		layer._poll_ripe(0.25)
		ripe_rows["primed_streams"] = _played(sfx)
		berry.start_tracking(1)
		berry._state[1]["accumulated"] = TAU * 2.0
		layer._poll_ripe(0.25)
		ripe_rows["fresh_streams"] = _played(sfx)
		ripe_rows["watching"] = layer._ripe_pulse_in.size()
	_trace({"phase": "ripe", "has_register": berry != null, "rows": ripe_rows})
	quit(0)


func _played(sfx) -> Array:
	var out: Array = []
	for p in sfx._players:
		if p.stream != null:
			out.append(p.stream.resource_path.get_file())
			p.stream = null
	return out
