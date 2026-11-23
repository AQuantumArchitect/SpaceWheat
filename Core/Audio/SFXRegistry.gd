extends Node

## SFXRegistry — Autoload singleton for gameplay sound effects.
##
## Data-driven: maps event IDs to AudioStreams. Sounds can be registered
## at boot or at runtime. If no audio is loaded for an event, the play
## call logs to console (useful for wiring verification before assets exist).
##
## Connects to QuantumInstrument.action_performed and ActiveBiomeManager
## to automatically play sounds for game events.

const CONFIG_PATH = "user://spacewheat_settings.cfg"

signal volume_changed(new_volume: float)

# ═══════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════

## event_id → AudioStream (null = muted and logs instead of play)
var _sounds: Dictionary = {}

## Pool of AudioStreamPlayers for overlapping SFX
var _players: Array[AudioStreamPlayer] = []
const POOL_SIZE := 6  # a rare Gather stacks three layers
const SFX_BASE_PATH := "res://Assets/Audio/SFX/"

## Volume (linear 0.0–1.0)
var _sfx_volume: float = 0.3
var _muted: bool = false

## Connection tracking
var _connected_instrument = null
var _connected_abm = null


func _log_debug(message: String) -> void:
	VerboseHelper.debug("audio", "sfx", message)


# ═══════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_player_pool()
	_load_volume_preference()
	_register_default_events()
	call_deferred("_connect_game_signals")


func _create_player_pool() -> void:
	for i in range(POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.name = "SFXPlayer_%d" % i
		player.bus = "SFX"  # Falls back to Master if the bus layout is absent
		add_child(player)
		_players.append(player)


func _register_default_events() -> void:
	# Load WAV files for all known event IDs. Falls back to null (log-only) if missing.
	var events := [
		"explore_success",
		"measure_success",
		"pop_success",
		"gate_success",
		"action_blocked",
		"action_error",
		"reap_success",
		"biome_switch",
		"menu_open",
		"menu_close",
		"fractal_descend",
		"fractal_ascend",
		# Harvest-loop juice (#60): Gather's upper layers + the quiet cues.
		"harvest_sparkle",
		"harvest_rare",
		"plant_soft",
		"ripe_ready",
	]
	var loaded := 0
	for event_id in events:
		var path: String = SFX_BASE_PATH + event_id + ".wav"
		if ResourceLoader.exists(path):
			_sounds[event_id] = load(path)
			loaded += 1
		else:
			_sounds[event_id] = null
	_log_debug("[SFXRegistry] Loaded %d/%d SFX files" % [loaded, events.size()])


# ═══════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════

func play(event_id: String, volume_scale: float = 1.0, pitch_scale: float = 1.0) -> void:
	# Play a sound for the given event. Logs if no audio is loaded.
	if _muted:
		return

	var stream = _sounds.get(event_id)
	if stream == null:
		# Placeholder mode: log so we can verify wiring
		_log_debug("[SFX] %s (no audio loaded)" % event_id)
		return

	var player = _get_free_player()
	if not player:
		return  # All players busy, skip this sound

	player.stream = stream
	player.volume_db = _volume_to_db(_sfx_volume * volume_scale)
	player.pitch_scale = clampf(pitch_scale, 0.5, 2.0)
	player.play()


func register_sound(event_id: String, stream: AudioStream) -> void:
	# Register or replace an audio stream for an event.
	_sounds[event_id] = stream


func has_event(event_id: String) -> bool:
	return _sounds.has(event_id)


# ═══════════════════════════════════════════════════════════════════════
# VOLUME
# ═══════════════════════════════════════════════════════════════════════

func set_volume(value: float) -> void:
	_sfx_volume = clampf(value, 0.0, 1.0)
	_save_volume_preference()
	volume_changed.emit(_sfx_volume)


func get_volume() -> float:
	return _sfx_volume


func set_muted(mute: bool) -> void:
	_muted = mute


func is_muted() -> bool:
	return _muted


func _volume_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)


func _load_volume_preference() -> void:
	var config = ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		_sfx_volume = config.get_value("audio", "sfx_volume", 0.7)


func _save_volume_preference() -> void:
	var config = ConfigFile.new()
	config.load(CONFIG_PATH)  # Load existing to preserve other keys
	config.set_value("audio", "sfx_volume", _sfx_volume)
	config.save(CONFIG_PATH)


# ═══════════════════════════════════════════════════════════════════════
# PLAYER POOL
# ═══════════════════════════════════════════════════════════════════════

func _get_free_player() -> AudioStreamPlayer:
	# Return the first idle player, or the oldest playing one.
	for player in _players:
		if not player.playing:
			return player
	# All busy — steal the first (oldest)
	return _players[0]


# ═══════════════════════════════════════════════════════════════════════
# GAME SIGNAL WIRING
# ═══════════════════════════════════════════════════════════════════════

func _connect_game_signals() -> void:
	# Deferred connection to game systems (waits for boot).
	# Wait for game to be ready
	await get_tree().process_frame
	await get_tree().process_frame

	# Connect to QuantumInstrument via Farm
	_try_connect_instrument()

	# Connect to ActiveBiomeManager
	var abm = get_node_or_null("/root/ActiveBiomeManager")
	if abm and abm.has_signal("active_biome_changed"):
		InstrumentLocator._safe_connect(abm.active_biome_changed, _on_biome_changed)
		_connected_abm = abm

	# Retry instrument connection when boot completes (instrument created late)
	var boot_mgr = get_node_or_null("/root/BootManager")
	if boot_mgr and boot_mgr.has_signal("game_ready"):
		InstrumentLocator._safe_connect(boot_mgr.game_ready, _on_game_ready)


func _on_game_ready() -> void:
	# Re-try instrument connection after full boot (instrument created in boot_ui).
	_try_connect_instrument()


func _try_connect_instrument() -> void:
	# Connect to QuantumInstrument.action_performed if available.
	# Re-connects if the farm's instrument instance has been replaced.
	var farm = InstrumentLocator.resolve_active_farm(self)
	if not farm or not ("instrument" in farm) or not farm.instrument:
		return

	var instrument = farm.instrument
	if instrument == _connected_instrument:
		return  # Already connected to this exact instance

	# Disconnect the old reference if it still exists
	if _connected_instrument != null:
		if _connected_instrument.has_signal("action_performed"):
			InstrumentLocator._safe_disconnect(_connected_instrument.action_performed, _on_action_performed)
		_connected_instrument = null

	if instrument.has_signal("action_performed"):
		InstrumentLocator._safe_connect(instrument.action_performed, _on_action_performed)
		_connected_instrument = instrument
		_log_debug("[SFXRegistry] Connected to QuantumInstrument.action_performed")


func reset() -> void:
	# Clear connections for restart. Called by _reset_runtime_singletons.
	if _connected_instrument and is_instance_valid(_connected_instrument):
		if _connected_instrument.has_signal("action_performed"):
			InstrumentLocator._safe_disconnect(
				_connected_instrument.action_performed, _on_action_performed)
	_connected_instrument = null

	if _connected_abm and is_instance_valid(_connected_abm):
		if _connected_abm.has_signal("active_biome_changed"):
			InstrumentLocator._safe_disconnect(
				_connected_abm.active_biome_changed, _on_biome_changed)
	_connected_abm = null

	# Stop all playing sounds
	for player in _players:
		player.stop()


# ═══════════════════════════════════════════════════════════════════════
# SIGNAL HANDLERS
# ═══════════════════════════════════════════════════════════════════════

# Pop chain ladder (Mini-Metro/shapez trick): pops within the combo window
# step the pitch up a pentatonic degree; silence resets the ladder. Pure
# celebration: reads only the already-computed result, never mechanics.
# Every knob is in FeedbackTuning.
var _pop_chain: int = 0
var _last_pop_ms: int = -1000000


## Advance (or reset) the combo ladder for a Gather at `now_ms`; returns the step.
func _step_pop_chain(now_ms: int) -> int:
	if now_ms - _last_pop_ms <= FeedbackTuning.COMBO_WINDOW_MS:
		_pop_chain = mini(_pop_chain + 1, FeedbackTuning.COMBO_SEMITONES.size() - 1)
	else:
		_pop_chain = 0
	_last_pop_ms = now_ms
	return _pop_chain


## Layered Gather: thump always; sparkle fades in with surprisal; the bell only
## on rare payouts. The whole stack climbs the combo ladder. Intensity scales
## the upper layers; at 0 only the thump remains (the action still confirms).
func play_harvest(credits: float) -> void:
	var step := _step_pop_chain(Time.get_ticks_msec())
	var rel := FeedbackTuning.rel_for(credits)
	var pitch := pow(2.0, float(FeedbackTuning.COMBO_SEMITONES[step]) / 12.0)
	var juice := FeedbackTuning.intensity()
	play("pop_success", FeedbackTuning.HARVEST_BASE_VOL + FeedbackTuning.HARVEST_BASE_VOL_PER_REL * rel, pitch)
	if juice <= 0.0:
		return
	if rel >= FeedbackTuning.HARVEST_SPARKLE_MIN_REL:
		var sparkle_gain := (rel - FeedbackTuning.HARVEST_SPARKLE_MIN_REL) \
				/ (1.0 - FeedbackTuning.HARVEST_SPARKLE_MIN_REL)
		play("harvest_sparkle", FeedbackTuning.HARVEST_SPARKLE_VOL * sparkle_gain * juice,
				pitch * (1.0 + FeedbackTuning.HARVEST_SPARKLE_PITCH_PER_STEP * step))
	if rel >= FeedbackTuning.BIG_POP_REL:
		play("harvest_rare", FeedbackTuning.HARVEST_RARE_VOL * juice, pitch)


## A tracked plot just ripened. Called by FloatingRewardLayer's ripe watcher.
func play_ripe() -> void:
	var juice := FeedbackTuning.intensity()
	if juice > 0.0:
		play("ripe_ready", FeedbackTuning.RIPE_VOL * juice)


func _on_action_performed(action: String, result: Dictionary) -> void:
	# Map game actions to sound events.
	if result.get("success", false):
		match action:
			"explore":
				play("explore_success", FeedbackTuning.EXPLORE_VOL)
			"inject_icon", "plant":
				# Planting (an icon into a biome, or Ace's Rabi pulse) is
				# anticipation, not payoff: a quiet low pluck.
				play("plant_soft", FeedbackTuning.PLANT_VOL)
			"measure":
				play("measure_success")
			"pop":
				# Surprisal-scaled celebration: bigger payouts (rarer outcomes,
				# E = −kT·log p) land louder and stack more layers; quick chains
				# climb the pentatonic.
				play_harvest(FeedbackTuning.harvest_size(result))
			"reap":
				play("reap_success")
			"enter_icon":
				# Descending into a fractal child world — every dive, not a rare event,
				# so a plain distinct cue (no chain/pitch-ramp trick like pop's).
				play("fractal_descend")
			"ascend_fractal":
				play("fractal_ascend")
			_:
				play("gate_success")
	elif result.get("blocked", false):
		play("action_blocked")
	else:
		play("action_error")


func _on_biome_changed(_new_biome: String, _old_biome: String) -> void:
	play("biome_switch")
