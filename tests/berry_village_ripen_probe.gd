extends SceneTree

## Issue #126: time to ripen Village's 🔥/❄ walk, before and after the
## tracked-biome clock boost. Boots the real game on the native engine, tracks
## the 🔥 qubit, and measures in one of two lanes:
##
##   press: Ace F exactly as QuantumInstrumentInput's fast_forward runs it —
##          time_skip(120) until ripe, at most 900 phrames per press — and
##          counts presses (plus phrames and wall ms) to ripe.
##   live:  no skips; the game's own clock runs for up to N real seconds and
##          we read the wall time at which the walk ripens.
##
## Args (after --): <lane> <boost|json> [live_seconds]
##   boost "json" keeps biomes.json's value; an integer overrides it (1 = before).
##
## Run: godot --headless --audio-driver Dummy --path . --script tests/berry_village_ripen_probe.gd -- press 1

const PRESS_PHRAMES: int = 120      # QuantumInstrumentInput.ACE_FAST_FORWARD_PHRAMES
const PRESS_CAP: int = 900          # QuantumInstrumentInput BERRY_RIPEN_CAP
const MAX_PRESSES: int = 30


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var lane: String = args[0] if args.size() > 0 else "press"
	var boost_arg: String = args[1] if args.size() > 1 else "json"
	var live_seconds: float = float(args[2]) if args.size() > 2 else 120.0

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
		printerr("VILLAGE_RIPEN boot did not yield a farm")
		quit(1)
		return
	var inst = InstrumentLocator.resolve_quantum_instrument(app_root.get_player_shell())
	var village = farm.grid.get_biome("Village")
	var json_boost: int = int(village.berry_track_boost)
	if boost_arg != "json":
		village.berry_track_boost = int(boost_arg)
	var qc = village.quantum_computer
	var q: int = qc.qubit("🔥")
	var reg = qc.berry_register
	# Track needs the biome underfoot, so the player is in the Village.
	var abm = get_root().get_node_or_null("ActiveBiomeManager")
	abm.set_active_biome("Village")
	var stride_before: int = village.evolution_stride()
	reg.start_tracking(q)
	var stride_tracked: int = village.evolution_stride()
	# Stepping to the Forest drops the boost; stepping back restores it.
	abm.set_active_biome("StarterForest")
	var stride_left: int = village.evolution_stride()
	abm.set_active_biome("Village")
	# No other biome's clock moves while Village tracks.
	var others := {}
	for bname in farm.grid.get_biome_names():
		var b = farm.grid.get_biome(str(bname))
		if b != null and b != village and b.has_method("evolution_stride"):
			others[str(bname)] = b.evolution_stride()
	# A save taken mid-track records the player's stride, not the boost.
	var saved = load("res://Core/GameState/GameStateSerializer.gd").new() \
			.capture_state_from_farm(farm, null, "probe")
	var out := {
		"lane": lane,
		"boost": int(village.berry_track_boost),
		"json_boost": json_boost,
		"stride_untracked": stride_before,
		"stride_tracked": stride_tracked,
		"stride_tracked_biome_left": stride_left,
		"village_observation_stride_tracked": int(village.observation_stride),
		"threshold": reg.get_ripe_threshold(q),
		"other_strides_tracked": others,
		"saved_stride_tracked": int(saved.observation_stride),
		"primary_biome": str(farm.grid.get_primary_biome().name),
	}

	if lane == "press":
		var presses := 0
		var phrames := 0
		var press_ms: Array = []
		var omega_per_press: Array = []
		while presses < MAX_PRESSES and not reg.is_ripe(q):
			var used := 0
			var t0 := Time.get_ticks_msec()
			while used < PRESS_CAP and not reg.is_ripe(q):
				inst.time_skip(PRESS_PHRAMES)
				used += PRESS_PHRAMES
			press_ms.append(Time.get_ticks_msec() - t0)
			phrames += used
			presses += 1
			omega_per_press.append(reg.get_phase(q))
		out["presses_to_ripe"] = presses
		out["phrames"] = phrames
		out["press_ms"] = press_ms
		out["omega_per_press"] = omega_per_press
	else:
		# A fresh boot has every plot dark, so the world is dormant (#75) and
		# nothing evolves, boosted or not. Lift the gate to time the clock.
		farm.biome_evolution_batcher.attention_gate_enabled = false
		var t0 := Time.get_ticks_msec()
		var ripe_at := -1.0
		while Time.get_ticks_msec() - t0 < int(live_seconds * 1000.0):
			await process_frame
			if reg.is_ripe(q):
				ripe_at = (Time.get_ticks_msec() - t0) / 1000.0
				break
		out["live_seconds_budget"] = live_seconds
		out["ripe_at_s"] = ripe_at
		out["evolutions"] = int(farm.biome_evolution_batcher.biome_evolution_counts.get("Village", -1))

	out["omega"] = reg.get_phase(q)
	out["ripe"] = reg.is_ripe(q)
	reg.stop_tracking(q)
	out["stride_after_untrack"] = village.evolution_stride()
	print("VILLAGE_RIPEN " + JSON.stringify(out))
	quit(0)
