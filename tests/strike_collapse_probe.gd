extends SceneTree

## strike_collapse_probe.gd — does a strike's collapse survive the next frames?
##
## Boots the real game headless (AppRoot path), explores one StarterForest plot,
## strikes it, and prints every register's north marginal (QC partial trace)
## before, in the same frame, and every 10 frames after. Found while tuning the
## glyph chatter (docs/history/2026-11-10_GLYPH_CHATTER_EXPERIMENTS.md): with
## lookahead on (the player default) the collapse is overwritten within ~10
## frames; with RIG_DISABLE_LOOKAHEAD=1 it persists and evolves on.
##
##   godot --headless --script tests/strike_collapse_probe.gd
##   RIG_DISABLE_LOOKAHEAD=1 godot --headless --script tests/strike_collapse_probe.gd
##
## Set SW_PROBE_USER_DIR_PREFIX to refuse to boot unless user:// resolves under it.
## Not run by pytest: it is a repro, not a gate.

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
	var inst = InstrumentLocator.resolve_quantum_instrument(app.get_player_shell())
	for e in ["🍞", "👥"]:
		farm.economy.add_resource(e, 5000, "probe")
	var b = farm.grid.get_all_biomes()["StarterForest"]
	var qc = b.quantum_computer
	var pos: Vector2i = farm.grid.get_plot_positions_for_biome("StarterForest")[1]
	print("EXPLORE ", inst.action_explore("StarterForest", pos))
	for _f in range(5): await process_frame
	var line := func(tag):
		var s: String = str(tag)
		for q in range(int(qc.register_map.num_qubits)):
			s += " %s%.3f" % [qc.register_map.axes[q]["north"], float(qc.get_marginal_density_matrix(null, q).get_element(0, 0).re)]
		print(s)
	line.call("before")
	var r = inst.action_measure(pos)
	print("STRIKE ", r)
	line.call("same frame")
	for k in range(6):
		for _f in range(10): await process_frame
		line.call("+%d0f" % (k + 1))
	quit(0)
