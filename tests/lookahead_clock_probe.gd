extends SceneTree

## lookahead_clock_probe.gd — how much simulated time does each biome get?
##
## Boots the real game headless (AppRoot path, demos_normal) with whatever lane
## the environment selects, then watches the batcher for WINDOW_TICKS physics
## ticks without touching anything. Every packet the batcher starts is logged
## with the biomes it carries, its phrame count and the dt it is evolved at
## (the packet minimum of max_evolution_dt). Prints:
##
##   CLOCK_BIOME {"biome", "max_evolution_dt", "stride", "dim", "open", "paused",
##                "frames", "sim_s", "sim_per_wall", "by_dt": {dt: frames}}
##   CLOCK_PACKET {"dt", "steps", "biomes": [...], "count"}     (one per distinct shape)
##   CLOCK_SUMMARY {"lane", "wall_s", "phrames", "packets_seen", "packets_total",
##                  "live_phrames", "native_ms_per_packet"}
##
## sim_s is the simulated time forecast for that biome in the window (frames ×
## packet dt). The buffer plays those frames one phrame per tick, so over a
## long window this is the sim time the player sees.
##
##   godot --headless --script tests/lookahead_clock_probe.gd

const WINDOW_TICKS := 300

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var prefix := OS.get_environment("SW_PROBE_USER_DIR_PREFIX").replace("\\", "/").to_lower()
	var user_dir := OS.get_user_data_dir().replace("\\", "/").to_lower()
	if prefix != "" and not user_dir.begins_with(prefix):
		printerr("CLOCK_PROBE refusing to boot: user:// is not under SW_PROBE_USER_DIR_PREFIX")
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
	var farm = null
	for _i in range(3000):
		var gr = app_root.game_root if "game_root" in app_root else null
		if gr and is_instance_valid(gr) and gr._started and gr.farm != null:
			farm = gr.farm
			break
		await process_frame
	if farm == null:
		printerr("CLOCK_PROBE boot did not yield a farm")
		quit(1)
		return
	var b = farm.biome_evolution_batcher
	for _f in range(30): await physics_frame

	var frames := {}      # biome -> frames forecast in the window
	var sim := {}         # biome -> sim seconds forecast
	var by_dt := {}       # biome -> {dt_str: frames}
	var shapes := {}      # "dt|steps|a,b,c" -> count
	var last_started: int = int(b._packet_started_at_ms)
	var last_phrame: int = int(b._last_phrame_wall_ms)
	var phrames := 0
	var seen := 0
	var packets0: int = int(b._packets_total)
	var live0: int = int(b.live_phrames_total)
	var native0: float = float(b._native_ms_total)
	var wall0 := Time.get_ticks_msec()
	# CLOCK_DISTURB=<biome>: flip that biome's first register every 30 ticks (a
	# raw gate, like a strike or a rig driver), so its refills go out on their own.
	# CLOCK_DISTURB_ONCE=1: flip it at the start only.
	var disturb_name := OS.get_environment("CLOCK_DISTURB")
	var disturb = b._get_biome_by_name(disturb_name) if disturb_name != "" else null
	var every := 1000000 if OS.get_environment("CLOCK_DISTURB_ONCE") == "1" else 30
	for _t in range(WINDOW_TICKS):
		if disturb != null and _t % every == 0:
			disturb.quantum_computer.apply_pauli_x(0)
		await physics_frame
		if int(b._last_phrame_wall_ms) != last_phrame:
			last_phrame = int(b._last_phrame_wall_ms)
			phrames += 1
		var started: int = int(b._packet_started_at_ms)
		if started != last_started and started > 0 and not b._active_packet_request.is_empty():
			last_started = started
			seen += 1
			var req: Dictionary = b._active_packet_request
			var flags: Array = req.get("active_flags", [])
			var steps: int = int(req.get("num_steps", 0))
			var dt: float = float(b._get_packet_dt_for_active_flags(flags))
			var names: Array = []
			for id in range(flags.size()):
				if bool(flags[id]):
					names.append(str(b._engine_id_to_biome.get(id, "?")))
			names.sort()
			var key := "%s|%d|%s" % [str(dt), steps, ",".join(names)]
			shapes[key] = int(shapes.get(key, 0)) + 1
			for n in names:
				frames[n] = int(frames.get(n, 0)) + steps
				sim[n] = float(sim.get(n, 0.0)) + steps * dt
				var h: Dictionary = by_dt.get(n, {})
				h[str(dt)] = int(h.get(str(dt), 0)) + steps
				by_dt[n] = h
	var wall_s := float(Time.get_ticks_msec() - wall0) / 1000.0

	for biome in b.biomes:
		if not b._is_valid_biome(biome):
			continue
		var n: String = b._get_biome_name(biome)
		var qc = biome.quantum_computer
		print("CLOCK_BIOME " + JSON.stringify({
			"biome": n,
			"max_evolution_dt": float(biome.max_evolution_dt),
			"stride": int(biome.observation_stride),
			"dim": int(qc.register_map.dim()) if qc and qc.register_map else 0,
			"open": qc.is_open_here() if qc else false,
			"paused": bool(b.biome_paused.get(n, false)),
			"frames": int(frames.get(n, 0)),
			"sim_s": float(sim.get(n, 0.0)),
			"sim_per_wall": float(sim.get(n, 0.0)) / maxf(wall_s, 0.001),
			"by_dt": by_dt.get(n, {}),
		}))
	for key in shapes:
		var parts: PackedStringArray = str(key).split("|")
		print("CLOCK_PACKET " + JSON.stringify({"dt": float(parts[0]), "steps": int(parts[1]),
			"biomes": parts[2].split(","), "count": shapes[key]}))
	var packets: int = int(b._packets_total) - packets0
	print("CLOCK_SUMMARY " + JSON.stringify({
		"lane": "lookahead" if b.lookahead_enabled else "direct", "disturb": disturb_name,
		"wall_s": wall_s, "phrames": phrames, "packets_seen": seen, "packets_total": packets,
		"live_phrames": int(b.live_phrames_total) - live0,
		"native_ms_per_packet": (float(b._native_ms_total) - native0) / maxf(1.0, float(packets)),
	}))
	quit(0)
