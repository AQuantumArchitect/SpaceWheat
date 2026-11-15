extends SceneTree

## milk_win_probe.gd — the milk endgame's win on the real game (#123).
##
## Boots a new game headless, fast-forwards to "Milk at Home" through
## CampaignFixture (the beat's ancestors replayed through the real paths),
## then, one MILK line per check:
##   before   🍼 is not at home: the win has not fired, a reap with an empty
##            🍼 wallet is refused
##   inject   plant Birth (🍼/✨) in StarterForest through the Icon verb
##            (QuantumInstrument.action_inject_icon_pair)
##   win      milk_at_home fired, its flag is the win, and the EndingOverlay
##            spawn rule opens the demo-won ceremony for it
##   reap     with 0 🍼 in the wallet the reap now succeeds; the home biome
##            covered it, and the wallet is not short afterwards
##
##   godot --headless --audio-driver Dummy --fixed-fps 10 --script tests/milk_win_probe.gd
## tests/test_milk_win.py runs it.

const HOME := "StarterForest"

var farm
var inst
var shell
var qm


func _init() -> void:
	call_deferred("_run")


func _emit(check: String, data: Dictionary) -> void:
	data["check"] = check
	print("MILK " + JSON.stringify(data))


func _run() -> void:
	var prefix := OS.get_environment("SW_PROBE_USER_DIR_PREFIX").replace("\\", "/").to_lower()
	var user_dir := OS.get_user_data_dir().replace("\\", "/").to_lower()
	if prefix != "" and not user_dir.begins_with(prefix):
		printerr("MILK refusing to boot: user:// is not under SW_PROBE_USER_DIR_PREFIX")
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
		printerr("MILK boot did not yield a farm")
		quit(1)
		return
	shell = app_root.get_player_shell()
	inst = InstrumentLocator.resolve_quantum_instrument(shell)
	qm = shell.quest_manager
	await _physics(10)

	var fired: Array = []
	qm.story_flag_fired.connect(func(fid: String, flag: Dictionary): fired.append([fid, flag]))

	var report: Dictionary = CampaignFixture.start_at_beat(farm, qm, "milk_at_home")
	await _physics(20)
	for e in ["🍞", "👥", "🧺", "🌾", "✨"]:
		farm.economy.add_resource(e, 5000, "probe")
	# Past the first season, so the reap does not ask for every plot explored.
	farm.set_reap_count(1)
	var ex: Dictionary = inst.action_explore(HOME, farm.grid.get_plot_positions_for_biome(HOME)[0])
	await _physics(5)

	# before: no 🍼 at home, an empty 🍼 wallet refuses the reap.
	farm.economy.set_resource(StapleRescue.MILK, 0, "probe")
	var refused: Dictionary = inst.action_reap()
	_emit("before", {"fixture_ok": bool(report.get("ok", false)),
		"requires_resolved": bool(report.get("requires_resolved", false)),
		"unreproduced": report.get("unreproduced", []), "explore_ok": bool(ex.get("success", false)),
		"homes": StapleRescue.home_biomes(farm), "at_home": StapleRescue.milk_at_home(farm),
		"win_fired": farm.story_flags_fired.has("milk_at_home"),
		"reap_ok": bool(refused.get("success", false)), "reap_error": str(refused.get("error", ""))})

	# inject: Birth is a word the player holds (find_the_milk's charge), planted at home.
	farm.discover_icon("🍼", "✨")
	var inj: Dictionary = inst.action_inject_icon_pair(HOME, {"north": "🍼", "south": "✨"})
	await _physics(30)
	_emit("inject", {"ok": bool(inj.get("success", false)), "error": str(inj.get("error", "")),
		"message": str(inj.get("message", "")), "at_home": StapleRescue.milk_at_home(farm),
		"home": StapleRescue.milk_home_biome(farm)})

	# win: the flag fired, it is the win, and the spawn rule opens the ceremony.
	var win_flag: Dictionary = {}
	for row in fired:
		if row[0] == "milk_at_home":
			win_flag = row[1]
	var layer := Control.new()
	layer.name = "ProbeOverlayLayer"
	get_root().add_child(layer)
	var overlay = EndingOverlay.spawn_for_flag(win_flag, layer, farm, shell)
	_emit("win", {"fired": farm.story_flags_fired.has("milk_at_home"),
		"signal": not win_flag.is_empty(), "is_win": EndingOverlay.is_win(win_flag),
		"overlay": overlay != null,
		"won_demo": bool(overlay._won_demo) if overlay != null else false,
		"title": overlay.title_lines() if overlay != null else []})
	if overlay != null:
		overlay._close()
	await _physics(5)

	# reap: 0 🍼 in the wallet, the home biome covers it.
	farm.economy.set_resource(StapleRescue.MILK, 0, "probe")
	var ex2: Dictionary = inst.action_explore(HOME, farm.grid.get_plot_positions_for_biome(HOME)[0])
	await _physics(5)
	var short_before: bool = StapleRescue.milk_short(farm)
	var reaped: Dictionary = inst.action_reap()
	_emit("reap", {"ok": bool(reaped.get("success", false)), "error": str(reaped.get("error", "")),
		"message": str(reaped.get("message", "")), "explore_ok": bool(ex2.get("success", false)),
		"short_before": short_before, "cost": reaped.get("reap_cost", {}),
		"milk_after": int(farm.economy.get_resource(StapleRescue.MILK)),
		"short_after": StapleRescue.milk_short(farm)})
	quit(0)


func _wait_farm(app_root) -> bool:
	for _i in range(3000):
		var gr = app_root.game_root if "game_root" in app_root else null
		if gr and is_instance_valid(gr) and gr._started and gr.farm != null and is_instance_valid(gr.farm):
			farm = gr.farm
			return true
		await process_frame
	return false


func _physics(n: int) -> void:
	for _i in range(n):
		await physics_frame
