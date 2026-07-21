extends Node

## MusicManager - Autoload singleton for background music
##
## Features:
## - Biome-specific tracks with crossfade transitions
## - Volume control with persistence
## - Dual AudioStreamPlayer for smooth crossfading
##
## Track-selection authority (these are LAYERED, not competing paths):
##   1. Base, on biome change: _on_biome_changed() → play_biome_track().
##        Layer 1 — direct BIOME_TRACKS[biome] lookup (authoritative when present).
##        Layer 4 — parametric _select_track_for_biome_vector(), only if iconmap_mode_enabled
##                  AND no direct mapping. Fallback: entropy_garden.
##   2. Continuous refinement, within a biome: _evaluate_iconmap_decision() may switch the
##      track based on accumulated quantum/IconMap state — gated by iconmap_mode_enabled and
##      damped by ICONMAP_HYSTERESIS so it doesn't thrash. This refines (2) on top of (1).
##   3. play_icon_track() — explicit icon-driven entry, same iconmap-similarity machinery.
##   The single switch is iconmap_mode_enabled: OFF ⇒ only Layer 1 direct mapping is used;
##   ON ⇒ the parametric/refinement layers are live above the direct mapping.
##
## Usage:
##   MusicManager.play_biome_track("BioticFlux")
##   MusicManager.set_volume(0.8)
##   MusicManager.stop()

signal volume_changed(new_volume: float)
signal track_changed(track_name: String)


## Track paths (relative to res://Assets/Audio/Music/)
const TRACKS: Dictionary = {
	# Named tracks (biome-mapped)
	"quantum_harvest": "res://Assets/Audio/Music/Quantum Harvest Dawn.mp3",
	"fungal_lattice": "res://Assets/Audio/Music/Fungal Lattice Symphony.mp3",
	"black_horizon": "res://Assets/Audio/Music/Black Horizon Whisper.mp3",
	"entropic_bread": "res://Assets/Audio/Music/Entropic Bread Rise.mp3",
	"entropy_garden": "res://Assets/Audio/Music/Entropy Garden.mp3",
	"yeast_prophet": "res://Assets/Audio/Music/Yeast Prophet_s Eclipse.mp3",
	"end_credits": "res://Assets/Audio/Music/SpaceWheat (End Credits).mp3",
	"heisenberg_township": "res://Assets/Audio/Music/Heisenberg Township, Poppenoff-ulation.mp3",
	"peripheral_arbor": "res://Assets/Audio/Music/Peripheral Arbor.mp3",
	"afterbirth_arbor": "res://Assets/Audio/Music/Afterbirth Arbor.mp3",
	"bureaucratic_abyss": "res://Assets/Audio/Music/Bureaucratic Abyss.mp3",
	"horizon_fracture": "res://Assets/Audio/Music/Horizon Fracture.mp3",
	"echoing_chasm": "res://Assets/Audio/Music/Echoing Chasm.mp3",
	"tidal_pools": "res://Assets/Audio/Music/Tidal Pools.mp3",
	"cyberdebt_megacity": "res://Assets/Audio/Music/CyberDebt Megacity.mp3",
	# Emoji-signature tracks (for IconMap parametric selection)
	"broadcast_satellite": "res://Assets/Audio/Music/📡📶🧩🛰📼⭐.mp3",  # BroadcastTower, SatelliteGraveyard
	"clinic_medicine": "res://Assets/Audio/Music/💉💊🩺🧪🧬🚫.mp3",      # Clinic
	"workshop_scrap": "res://Assets/Audio/Music/🔧🔨🪛♻️🗑🏭.mp3",      # Workshop, ScrapYard
	"market_trading": "res://Assets/Audio/Music/💰💳🐂🐻💱📦.mp3",      # MarketDistrict, TradingFloor
	"weaver_textile": "res://Assets/Audio/Music/🧵🪢🧷👘📿🪡.mp3",      # WeaversLoft
	"battlefield_war": "res://Assets/Audio/Music/⚔💥🛡💀🧨🔥.mp3",     # Battlefield, RevolutionSquare
	"harbor_water": "res://Assets/Audio/Music/💧🧊🌊⚓🪝🛶.mp3",        # Harbor, FreshwaterSpring
	"meditation_occult": "res://Assets/Audio/Music/🧘🏮🕯🧿📿⚱.mp3",   # MeditationGarden, OccultSanctum
	"ruins_ancient": "res://Assets/Audio/Music/🏰🏚️🏛🪨🥀📜.mp3",      # ForgottenCastle, Archives
	"magnetic_anomaly": "res://Assets/Audio/Music/⚡🌀⚫🧲✨🕳.mp3",    # MagneticAnomaly, PowerStation
}

## Biome to track mapping
const BIOME_TRACKS: Dictionary = {
	# Core biomes
	"BioticFlux": "quantum_harvest",
	"StellarForges": "black_horizon",
	"FungalNetworks": "fungal_lattice",
	"VolcanicWorlds": "yeast_prophet",
	"StarterForest": "peripheral_arbor",
	"Village": "heisenberg_township",
	"CyberDebtMegacity": "cyberdebt_megacity",
	"EchoingChasm": "echoing_chasm",
	"HorizonFracture": "horizon_fracture",
	"BureaucraticAbyss": "bureaucratic_abyss",
	"TidalPools": "tidal_pools",
	"GildedRot": "yeast_prophet",
	# Emoji-track biomes (new songs)
	"BroadcastTower": "broadcast_satellite",
	"SatelliteGraveyard": "broadcast_satellite",
	"Clinic": "clinic_medicine",
	"Workshop": "workshop_scrap",
	"ScrapYard": "workshop_scrap",
	"MarketDistrict": "market_trading",
	"TradingFloor": "market_trading",
	"WeaversLoft": "weaver_textile",
	"Battlefield": "battlefield_war",
	"RevolutionSquare": "battlefield_war",
	"Harbor": "harbor_water",
	"FreshwaterSpring": "harbor_water",
	"MeditationGarden": "meditation_occult",
	"OccultSanctum": "meditation_occult",
	"BindingCircle": "meditation_occult",
	"ShrineOfAshes": "meditation_occult",
	"ForgottenCastle": "ruins_ancient",
	"Archives": "ruins_ancient",
	"AbandonedQuarter": "ruins_ancient",
	"MagneticAnomaly": "magnetic_anomaly",
	"PowerStation": "magnetic_anomaly",
	"AntimatterFoundry": "magnetic_anomaly",
	# Additional biomes (from biomes_merged.json)
	"PastoralCommons": "afterbirth_arbor",
	"Apiary": "quantum_harvest",
	"OrbitalStrike": "magnetic_anomaly",
	"DemolitionSite": "workshop_scrap",
	"Woodlot": "afterbirth_arbor",
	"MirrorChamber": "magnetic_anomaly",
	"TrappersCamp": "harbor_water",
	"EnforcementPost": "workshop_scrap",
}

## Menu/special tracks
const MENU_TRACK: String = "end_credits"
const FALLBACK_TRACK: String = "entropy_garden"

## Crossfade duration in seconds
const CROSSFADE_DURATION: float = 0.8
## Minimum seconds between successive crossfade_to() calls (prevents rapid-fire thrash)
const MIN_CROSSFADE_INTERVAL: float = 0.5

## Volume settings
var _volume: float = 0.7  # 0.0 to 1.0
var _muted: bool = false

## Audio players for crossfading
var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer
var _inactive_player: AudioStreamPlayer

## Current state
var _current_track: String = ""
var _crossfade_tween: Tween = null
var _last_crossfade_time: float = 0.0
var _health_check_timer: float = 0.0  # 10Hz health check

## Track position preservation with ghost timer (evolution-synced)
## Ghost timer advances based on biome evolution steps, not wall-clock time.
## This keeps music synced with biome evolution - if biome is paused, music position is frozen.
var preserve_track_positions: bool = true  # Resume tracks with evolution-synced advancement
var _track_positions: Dictionary = {}  # track_key -> {position: float, evolution_count: int, biome_name: String}
const _PC = preload("res://Core/Config/PhysicsConfig.gd")
const EVOLUTION_DT: float = _PC.PHRAME_DT  # Seconds per evolution step (matches BiomeEvolutionBatcher.LOOKAHEAD_DT)

## Register-based playback control (Layer 3 - music tied to evolution)
## When true: Music only plays when active biome has explored bubbles (terminals bound)
## This syncs music with biome evolution - both pause when no bubbles
var stop_music_when_no_registers: bool = true  # Layer 3 enabled
var _last_register_check: float = 0.0
const REGISTER_CHECK_INTERVAL: float = 0.5  # Check register state every 0.5s

## Loaded streams cache
var _stream_cache: Dictionary = {}
var _disabled: bool = false

## Layer 3 intentional stop flag (prevents watchdog from restarting)
var _layer3_stopped: bool = false

## Hysteresis: require N consecutive "no evolution" observations before stopping.
## At high sim speed the global icon map can briefly read empty between batches;
## a single blip shouldn't kill the music.
var _empty_observation_count: int = 0
const EMPTY_OBSERVATIONS_TO_STOP: int = 3

## Watchdog recovery failure counter (prevents spam when audio device unavailable)
var _watchdog_recovery_failures: int = 0
const MAX_WATCHDOG_FAILURES: int = 3

## IconMap-driven music mode
var iconmap_mode_enabled: bool = true  # Enable quantum state-driven music selection

## Portfolio-driven music mode (blends economy resources with IconMap)
var portfolio_mode_enabled: bool = true  # Enable resource portfolio influence
const PORTFOLIO_BLEND_WEIGHT: float = 0.3  # How much portfolio contributes (0.0-1.0), rest is IconMap

# Sampling: accumulate and evaluate every 1 second
var _iconmap_sample_timer: float = 0.0
const ICONMAP_SAMPLE_INTERVAL: float = 1.0  # Sample and evaluate every 1 second

# Rate limiting: switch tracks at most once per 10 seconds
var _iconmap_last_switch_time: float = -100.0  # Time of last track switch (start allows immediate)
const ICONMAP_MIN_SWITCH_INTERVAL: float = 10.0  # Minimum seconds between track switches

# Accumulator for smoothing (rolling window)
var _iconmap_accumulator: Dictionary = {}  # emoji -> accumulated weight
var _iconmap_sample_count: int = 0
const ICONMAP_MAX_SAMPLES: int = 10  # Rolling window size

# Thresholds
const ICONMAP_MIN_SIMILARITY: float = 0.05  # Only switch if similarity > 5%
const ICONMAP_HYSTERESIS: float = 0.03  # New track must be 3% better to switch

## Verbose logging (set via environment variable MUSIC_VERBOSE=1)
var _verbose: bool = false

func _log_info(message: String) -> void:
	if _verbose:
		VerboseHelper.debug("audio", "music", message)


func _ready() -> void:
	_verbose = OS.get_environment("MUSIC_VERBOSE") == "1"
	if _verbose:
		_log_info("[MusicManager] _ready() called")

	process_mode = Node.PROCESS_MODE_ALWAYS  # Volume control works when paused
	_setup_audio_players()
	_connect_biome_manager()
	_connect_farm_signals()
	_load_volume_preference()

	# Monitor playback health - restart if it unexpectedly stops
	set_process(true)
	if _verbose:
		_log_info("[MusicManager] Ready - volume=%.1f, muted=%s" % [_volume, _muted])


func _process(delta: float) -> void:
	if _disabled:
		return
	_tick_health(delta)
	_tick_gating(delta)
	_tick_iconmap(delta)


func _tick_health(delta: float) -> void:
	# 10Hz watchdog: detects and recovers unexpected playback dropout.
	_health_check_timer += delta
	if _health_check_timer < 0.1:
		return
	_health_check_timer = 0.0
	if _current_track.is_empty() or _active_player.playing or _layer3_stopped:
		return
	if _crossfade_tween != null and _crossfade_tween.is_valid():
		return
	# Dropout detected — check if evolution is actually happening.
	if not _global_icon_map_has_data():
		if _verbose:
			_log_info("[MusicManager] Watchdog: dropout with nothing evolving - setting layer3_stopped")
		_layer3_stopped = true
		return
	push_warning("MusicManager: Playback stopped unexpectedly, recovering")
	_start_music_from_state()
	if not _active_player.playing:
		# _start_music_from_state went through crossfade_to which may have been rate-limited
		# or same-track blocked — fall back to bare restart of the known-good current track.
		var stream = _get_or_load_stream(_current_track)
		if stream:
			_active_player.stream = stream
			_active_player.volume_db = _volume_to_db(_volume)
			_active_player.play()
	if not _active_player.playing:
		_watchdog_recovery_failures += 1
		if _watchdog_recovery_failures == MAX_WATCHDOG_FAILURES:
			push_error("MusicManager: Audio unavailable after %d recovery attempts - suppressing watchdog" % _watchdog_recovery_failures)
		if _watchdog_recovery_failures >= MAX_WATCHDOG_FAILURES:
			_layer3_stopped = true
	else:
		_watchdog_recovery_failures = 0


func _tick_gating(delta: float) -> void:
	# Poll evolution state every REGISTER_CHECK_INTERVAL seconds.
	_last_register_check += delta
	if _last_register_check < REGISTER_CHECK_INTERVAL:
		return
	_last_register_check = 0.0
	_update_evolution_gating()


func _tick_iconmap(delta: float) -> void:
	# Accumulate IconMap/Portfolio samples and evaluate track selection every ICONMAP_SAMPLE_INTERVAL.
	if not iconmap_mode_enabled and not portfolio_mode_enabled:
		return
	_iconmap_sample_timer += delta
	if _iconmap_sample_timer < ICONMAP_SAMPLE_INTERVAL:
		return
	_iconmap_sample_timer = 0.0
	_accumulate_music_samples()
	_evaluate_iconmap_decision()


func _unhandled_key_input(event: InputEvent) -> void:
	# Global debug control: F9 = force biome track. Volume is driven by the Levels scope in the system menu.
	if _disabled:
		return

	if not event is InputEventKey or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_F9:
			# Manual music trigger for testing (F9 to avoid conflicts)
			_log_info("[MusicManager] F9 pressed - manual music trigger")
			debug_status()
			if _get_active_biome_manager():
				var biome = _get_active_biome_manager().get_active_biome()
				_log_info("[MusicManager] Force-playing track for: %s" % biome)
				play_biome_track(biome)
			else:
				_log_info("[MusicManager] No ActiveBiomeManager - playing fallback")
				crossfade_to(FALLBACK_TRACK)
			get_viewport().set_input_as_handled()


func _setup_audio_players() -> void:
	_player_a = AudioStreamPlayer.new()
	_player_a.name = "MusicPlayerA"
	_player_a.bus = "Music"  # Falls back to Master if the bus layout is absent
	add_child(_player_a)

	_player_b = AudioStreamPlayer.new()
	_player_b.name = "MusicPlayerB"
	_player_b.bus = "Music"
	add_child(_player_b)

	_active_player = _player_a
	_inactive_player = _player_b

	# Set initial volumes
	_apply_volume()


func _connect_biome_manager() -> void:
	# Connect to ActiveBiomeManager when available
	if _get_active_biome_manager():
		_get_active_biome_manager().active_biome_changed.connect(_on_biome_changed)
		_log_info("[MusicManager] Connected to ActiveBiomeManager.active_biome_changed")
	else:
		_log_info("[MusicManager] ActiveBiomeManager not ready, waiting...")
		# Fallback: try connecting after tree is ready
		await get_tree().process_frame
		if _get_active_biome_manager():
			_get_active_biome_manager().active_biome_changed.connect(_on_biome_changed)
			_log_info("[MusicManager] Connected to ActiveBiomeManager.active_biome_changed (deferred)")
		else:
			_log_info("[MusicManager] ERROR: ActiveBiomeManager not available!")


func _connect_farm_signals() -> void:
	# Connect to Farm signals for immediate music response to terminal changes.
	#
	# Layer 3: Music should respond immediately when:
	# - Terminal bound (bubble explored) → start music
	# - Terminal released (bubble reaped/measured) → stop music if last bubble
	# Deferred connection - Farm may not exist yet
	call_deferred("_deferred_connect_farm")


func _deferred_connect_farm() -> void:
	await get_tree().process_frame
	await get_tree().process_frame  # Wait 2 frames for Farm to be ready

	var farm = _get_active_farm()
	if not farm:
		_log_info("Farm not found - Layer 3 signals not connected")
		return

	# Connect to terminal state changes
	if farm.has_signal("terminal_bound"):
		farm.terminal_bound.connect(_on_terminal_bound)
		_log_info("Connected to Farm.terminal_bound")
	if farm.has_signal("terminal_released"):
		farm.terminal_released.connect(_on_terminal_released)
		_log_info("Connected to Farm.terminal_released")
	if farm.has_signal("terminal_measured"):
		farm.terminal_measured.connect(_on_terminal_measured)
		_log_info("Connected to Farm.terminal_measured")


func _on_terminal_bound(grid_pos: Vector2i, terminal_id: String, _emoji_pair: Dictionary) -> void:
	if _verbose:
		_log_info("[MusicManager] SIGNAL: terminal_bound - %s at %s" % [terminal_id, grid_pos])
	_update_evolution_gating()


func _on_terminal_released(grid_pos: Vector2i, terminal_id: String, _credits: int) -> void:
	if _verbose:
		_log_info("[MusicManager] SIGNAL: terminal_released - %s at %s" % [terminal_id, grid_pos])
	_update_evolution_gating()


func _on_terminal_measured(grid_pos: Vector2i, terminal_id: String, outcome: String, _prob: float) -> void:
	if _verbose:
		_log_info("[MusicManager] SIGNAL: terminal_measured - %s at %s, outcome=%s" % [terminal_id, grid_pos, outcome])
	_update_evolution_gating()


func _update_evolution_gating() -> void:
	# Single authority for Layer 3 music gating (evolution-driven stop/start).
	# Called immediately from terminal signals and polled every REGISTER_CHECK_INTERVAL.
	# Both stop and restart paths live here — no asymmetry between callers.
	if not stop_music_when_no_registers:
		return
	var has_evolution := _global_icon_map_has_data()
	var is_playing := _active_player.playing
	if _verbose:
		_log_info("[MusicManager] _update_evolution_gating: has_evolution=%s, is_playing=%s" % [
			has_evolution, is_playing])

	if has_evolution:
		_empty_observation_count = 0
		if _layer3_stopped or not is_playing:
			if _verbose:
				_log_info("[MusicManager] Evolution detected - starting music")
			_start_music_from_state()
	elif is_playing and not _layer3_stopped:
		# not _layer3_stopped: in bed mode the player keeps playing (ducked) —
		# without the guard this would re-trigger the duck every poll.
		_empty_observation_count += 1
		if _empty_observation_count >= EMPTY_OBSERVATIONS_TO_STOP:
			if _verbose:
				_log_info("[MusicManager] No global evolution - ducking to ambient bed")
			_stop_for_layer3()


func _global_icon_map_has_data() -> bool:
	# Check if anything is evolving globally.
	#
	# Primary: Check global icon map from BiomeEvolutionBatcher.
	# Fallback: If batcher has no data yet (early startup, headless), check for
	# any active terminals across all biomes as a proxy for 'something is evolving'.
	var farm = _get_active_farm()
	if not farm:
		return false

	# Primary check: global icon map
	var batcher = farm.get("biome_evolution_batcher")
	if batcher and batcher.has_method("get_global_icon_map"):
		var icon_map: Dictionary = batcher.get_global_icon_map()
		if icon_map.get("total", 0.0) > 0.0:
			return true

	# Fallback: check if any terminals are actively bound (not measured)
	if farm.terminal_pool and farm.terminal_pool.has_method("get_bound_count"):
		var bound_count: int = farm.terminal_pool.get_bound_count()
		if bound_count > 0:
			# Check if any are actually active (bound but not measured)
			for terminal in farm.terminal_pool.terminals:
				if terminal.is_bound and not terminal.is_measured:
					return true

	return false


func _get_best_biome_from_global_map() -> String:
	# Get the biome name with highest weight in the global icon map.
	# Used as fallback when IconMap accumulator doesn't have enough samples yet.
	var farm = _get_active_farm()
	if not farm:
		return ""
	var batcher = farm.get("biome_evolution_batcher")
	if not batcher or not batcher.has_method("get_global_icon_map"):
		return ""
	var icon_map: Dictionary = batcher.get_global_icon_map()
	var by_emoji: Dictionary = icon_map.get("by_emoji", {})
	if by_emoji.is_empty():
		return ""

	# Use the IconMap similarity to find best biome match
	var similarities := get_iconmap_similarities(by_emoji)
	if not similarities.is_empty() and similarities[0]["similarity"] > 0.0:
		return similarities[0]["biome"]
	return ""


# Ambient bed: a settled world is QUIET, not silent (never-silent ambience).
const BED_FRACTION := 0.18  # of the user's music volume, linear
const BED_FADE_S := 2.5
const SWELL_S := 1.2


func _stop_for_layer3() -> void:
	# Layer 3 (no explored bubbles): duck to a quiet ambient bed instead of a
	# hard stop. Activity = music still holds — settled fades to a murmur, and
	# the swell on the next explored bubble is seamless (same track position).
	_layer3_stopped = true

	# Kill any crossfade in progress
	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()
		_crossfade_tween = null

	# Save position for ghost timer (evolution-synced)
	if not _current_track.is_empty():
		_save_ghost_timer_position(_current_track)

	var tree := get_tree()
	if tree and _active_player.playing:
		var fade := tree.create_tween()
		fade.tween_property(_active_player, "volume_db",
				_volume_to_db(_volume * BED_FRACTION), BED_FADE_S)
	else:
		_active_player.stop()
	_inactive_player.stop()


## Ceremony hook (EndingOverlay): lift the current track a few dB, hold, and
## settle back. No track change, no state change — a swell, not a cue.
func celebrate_swell(amount_db: float = 3.0, rise_s: float = 2.5, hold_s: float = 5.0) -> void:
	if _active_player == null or not _active_player.playing:
		return
	var tree := get_tree()
	if tree == null:
		return
	var base_db := _volume_to_db(_volume)
	var tw := tree.create_tween()
	tw.tween_property(_active_player, "volume_db", base_db + amount_db, rise_s)
	tw.tween_interval(hold_s)
	tw.tween_property(_active_player, "volume_db", base_db, rise_s)


func _start_music_from_state() -> void:
	# Restart music using current evolution/biome state. All restart paths converge here.
	# Clears layer3 stop flag and watchdog counter before attempting playback.
	_layer3_stopped = false
	_watchdog_recovery_failures = 0
	if _iconmap_sample_count >= 3:
		_evaluate_iconmap_decision()
	if _active_player.playing:
		# Bed mode (ducked, still playing) → swell back to full.
		var tree := get_tree()
		if tree:
			var swell := tree.create_tween()
			swell.tween_property(_active_player, "volume_db", _volume_to_db(_volume), SWELL_S)
		return
	if not _active_player.playing:
		var best_biome := _get_best_biome_from_global_map()
		# ABM fallback: handles early-boot case where batcher icon map is still empty.
		if best_biome.is_empty() and _get_active_biome_manager():
			best_biome = _get_active_biome_manager().get_active_biome()
		if not best_biome.is_empty():
			play_biome_track(best_biome)


func _save_ghost_timer_position(track_key: String) -> void:
	if not preserve_track_positions or not _active_player.playing:
		return
	var current_pos := _active_player.get_playback_position()
	var biome_name := ""
	var evolution_count := 0
	if _get_active_biome_manager():
		biome_name = _get_active_biome_manager().get_active_biome()
		evolution_count = _get_biome_evolution_count(biome_name)
	_track_positions[track_key] = {
		"position": current_pos,
		"evolution_count": evolution_count,
		"biome_name": biome_name
	}
	if _verbose:
		_log_info("[MusicManager] Ghost timer: saved %s at %.1fs (evo=%d, biome=%s)" % [
			track_key, current_pos, evolution_count, biome_name])


func _get_biome_evolution_count(biome_name: String) -> int:
	# Query BiomeEvolutionBatcher for cumulative evolution count.
	var farm = _get_active_farm()
	if not farm:
		return 0

	var batcher = farm.get("biome_evolution_batcher")
	if not batcher or not batcher.has_method("get_biome_evolution_count"):
		return 0

	return batcher.get_biome_evolution_count(biome_name)


func _biome_has_active_terminals(farm, biome_name: String) -> bool:
	# Check if biome has terminals that are BOUND but NOT MEASURED.
	#
	# Active terminals = exploring bubbles (not frozen/measured)
	if not farm.terminal_pool or not farm.terminal_pool.has_method("get_terminals_in_biome"):
		return false

	var terminals = farm.terminal_pool.get_terminals_in_biome(biome_name)
	var active_count := 0
	var measured_count := 0
	var unbound_count := 0

	for terminal in terminals:
		if terminal.is_bound and not terminal.is_measured:
			active_count += 1
		elif terminal.is_measured:
			measured_count += 1
		else:
			unbound_count += 1

	var has_active = active_count > 0
	if _verbose:
		_log_info("[MusicManager] _biome_has_active_terminals(%s): active=%d, measured=%d, unbound=%d → %s" % [
			biome_name, active_count, measured_count, unbound_count, has_active])
	return has_active


func _on_biome_changed(new_biome: String, old_biome: String) -> void:
	if _verbose:
		_log_info("[MusicManager] Biome changed: %s → %s" % [old_biome, new_biome])
	if new_biome.is_empty() or _disabled:
		return
	_layer3_stopped = false
	play_biome_track(new_biome)


func _accumulate_music_samples() -> void:
	# Accumulate samples from IconMap and/or Portfolio for music selection.
	#
	# Called every ICONMAP_SAMPLE_INTERVAL (1 second).
	# Maintains a rolling window of ICONMAP_MAX_SAMPLES for smoothing.
	# IconMap and Portfolio are independent - either can contribute alone.
	var had_iconmap := false
	var had_portfolio := false

	# If at max samples, decay existing values to make room (exponential moving average)
	if _iconmap_sample_count >= ICONMAP_MAX_SAMPLES:
		var decay: float = float(ICONMAP_MAX_SAMPLES - 1) / float(ICONMAP_MAX_SAMPLES)
		for emoji in _iconmap_accumulator.keys():
			_iconmap_accumulator[emoji] *= decay
		_iconmap_sample_count = ICONMAP_MAX_SAMPLES - 1

	# Try to accumulate IconMap sample
	if iconmap_mode_enabled:
		had_iconmap = _accumulate_iconmap_sample()

	# Accumulate portfolio sample (independent of IconMap success)
	if portfolio_mode_enabled:
		had_portfolio = _accumulate_portfolio_sample()

	# Only count as a sample if we got data from at least one source
	if had_iconmap or had_portfolio:
		_iconmap_sample_count += 1

	# Verbose logging
	if VerboseHelper.get_config():
		var biome_name := ""
		if _get_active_biome_manager():
			biome_name = _get_active_biome_manager().get_active_biome()
		var top_emojis := _get_top_accumulated_emojis(3)
		var sources: Array = []
		if had_iconmap:
			sources.append("IconMap")
		if had_portfolio:
			sources.append("Portfolio")
		var mode_str := "+".join(sources) if not sources.is_empty() else "(no data)"
		VerboseHelper.debug("music", "🎵", "%s sample #%d from %s: %s" % [
			mode_str, _iconmap_sample_count, biome_name if not biome_name.is_empty() else "?", top_emojis
		])


func _accumulate_iconmap_sample() -> bool:
	# Accumulate a single IconMap sample from the global icon map (all biomes).
	#
	# Returns true if data was accumulated, false if no IconMap data available.
	# Uses BiomeEvolutionBatcher.get_global_icon_map() which aggregates across
	# all evolving biomes - music reflects global state, not the viewed biome.
	var farm = _get_active_farm()
	if not farm:
		return false

	var batcher = farm.get("biome_evolution_batcher")
	if not batcher or not batcher.has_method("get_global_icon_map"):
		return false

	var icon_map: Dictionary = batcher.get_global_icon_map()
	if icon_map.is_empty():
		return false

	var by_emoji: Dictionary = icon_map.get("by_emoji", {})
	if by_emoji.is_empty():
		return false

	# Accumulate IconMap data
	for emoji in by_emoji.keys():
		var weight: float = float(by_emoji[emoji])
		if _iconmap_accumulator.has(emoji):
			_iconmap_accumulator[emoji] += weight
		else:
			_iconmap_accumulator[emoji] = weight

	return true


func _accumulate_portfolio_sample() -> bool:
	# Accumulate economy resources into the music selection vector.
	#
	# Blends resource amounts with IconMap samples using PORTFOLIO_BLEND_WEIGHT.
	# Resources are normalized by total holdings to create a portfolio distribution.
	# Returns true if data was accumulated, false otherwise.
	var farm = _get_active_farm()
	if not farm:
		return false

	var economy = farm.get_node_or_null("FarmEconomy")
	if not economy or not economy.has_method("get_all_resources"):
		return false

	var resources: Dictionary = economy.get_all_resources()
	if resources.is_empty():
		return false

	# Compute total resource value for normalization
	var total: float = 0.0
	for emoji in resources.keys():
		var val = resources[emoji]
		if val > 0:
			total += float(val)

	if total < 1.0:
		return false  # No meaningful resources

	# Add normalized portfolio to accumulator, scaled by blend weight
	# IconMap contributes (1 - PORTFOLIO_BLEND_WEIGHT), portfolio contributes PORTFOLIO_BLEND_WEIGHT
	var scale_val: float = PORTFOLIO_BLEND_WEIGHT / (1.0 - PORTFOLIO_BLEND_WEIGHT + 0.001)

	var portfolio_emojis: Array = []
	for emoji in resources.keys():
		var val = resources[emoji]
		if val > 0:
			var normalized_weight: float = float(val) / total * scale_val
			if _iconmap_accumulator.has(emoji):
				_iconmap_accumulator[emoji] += normalized_weight
			else:
				_iconmap_accumulator[emoji] = normalized_weight
			portfolio_emojis.append(emoji)

	if VerboseHelper.get_config() and not portfolio_emojis.is_empty():
		var top_3 := _get_top_portfolio_emojis(resources, 3)
		VerboseHelper.debug("music", "💰", "Portfolio contribution: %s (weight %.0f%%)" % [
			top_3, PORTFOLIO_BLEND_WEIGHT * 100
		])

	return not portfolio_emojis.is_empty()


func _get_top_portfolio_emojis(resources: Dictionary, count: int) -> String:
	# Get string of top N emojis from portfolio for logging.
	var pairs: Array = []
	for emoji in resources.keys():
		var val = resources[emoji]
		if val > 0:
			pairs.append({"emoji": emoji, "amount": val})
	pairs.sort_custom(func(a, b): return a["amount"] > b["amount"])

	var parts: Array = []
	for i in range(min(count, pairs.size())):
		parts.append("%s:%d" % [pairs[i]["emoji"], pairs[i]["amount"]])
	return " ".join(parts)


func _evaluate_iconmap_decision() -> void:
	# Evaluate accumulated IconMap data and decide whether to switch tracks.
	#
	# Called every ICONMAP_SAMPLE_INTERVAL (1 second).
	# Uses rolling average over last ICONMAP_MAX_SAMPLES.
	# Rate-limits actual switches to once per ICONMAP_MIN_SWITCH_INTERVAL.
	if _iconmap_sample_count < 3:
		return  # Not enough samples yet

	# Compute averaged IconMap from accumulator
	var averaged_iconmap: Dictionary = {}
	for emoji in _iconmap_accumulator.keys():
		averaged_iconmap[emoji] = _iconmap_accumulator[emoji] / float(_iconmap_sample_count)

	# Get similarities
	var similarities := get_iconmap_similarities(averaged_iconmap)
	if similarities.is_empty():
		return

	var best = similarities[0]
	if best["similarity"] < ICONMAP_MIN_SIMILARITY:
		return  # No strong match

	var best_track: String = best["track"]

	# If we're already playing the best track, nothing to do
	if best_track == _current_track:
		return

	# Hysteresis: find similarity of current track and require new to be better by threshold
	var current_similarity: float = 0.0
	for sim in similarities:
		if sim["track"] == _current_track:
			current_similarity = sim["similarity"]
			break

	# Only switch if new track is significantly better
	if best["similarity"] <= current_similarity + ICONMAP_HYSTERESIS:
		return  # Not enough improvement

	# Rate limit: check if enough time has passed since last switch
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _iconmap_last_switch_time < ICONMAP_MIN_SWITCH_INTERVAL:
		if VerboseHelper.get_config():
			VerboseHelper.debug("music", "⏳", "IconMap wants %s (%.1f%%) but rate-limited (%.1fs left)" % [
				best_track,
				best["similarity"] * 100,
				ICONMAP_MIN_SWITCH_INTERVAL - (now - _iconmap_last_switch_time)
			])
		return  # Too soon since last switch

	# Switch!
	_iconmap_last_switch_time = now

	if VerboseHelper.get_config():
		var top_emojis := _get_top_accumulated_emojis(4)
		VerboseHelper.info("music", "🎶", "IconMap switch: %s → %s (%.1f%% via %s) | Top: %s" % [
			_current_track if not _current_track.is_empty() else "(none)",
			best_track,
			best["similarity"] * 100,
			best["biome"],
			top_emojis
		])

	crossfade_to(best_track)


func _reset_iconmap_accumulator() -> void:
	# Clear the IconMap accumulator for fresh sampling.
	_iconmap_accumulator.clear()
	_iconmap_sample_count = 0


func _get_top_accumulated_emojis(count: int) -> String:
	# Get string of top N emojis from accumulator for logging.
	if _iconmap_accumulator.is_empty() or _iconmap_sample_count == 0:
		return "(empty)"

	# Sort by accumulated weight
	var pairs: Array = []
	for emoji in _iconmap_accumulator.keys():
		pairs.append({"emoji": emoji, "weight": _iconmap_accumulator[emoji]})
	pairs.sort_custom(func(a, b): return a["weight"] > b["weight"])

	# Build string
	var parts: Array = []
	for i in range(min(count, pairs.size())):
		var avg: float = pairs[i]["weight"] / float(_iconmap_sample_count)
		parts.append("%s:%.2f" % [pairs[i]["emoji"], avg])

	return " ".join(parts)


## ============================================================================
## PUBLIC API
## ============================================================================

func play_biome_track(biome_name: String) -> void:
	# Play the track associated with a biome.
	#
	# Layer 1: Direct biome→track lookup from BIOME_TRACKS.
	# Layer 4 (optional): If iconmap_mode is enabled and no direct mapping, use parametric selection.
	# Fallback: entropy_garden
	if _verbose:
		_log_info("[MusicManager] play_biome_track(%s)" % biome_name)
	if _disabled:
		_log_info("DISABLED - skipping")
		return

	# Layer 1: Direct biome→track mapping
	if BIOME_TRACKS.has(biome_name):
		var track_key = BIOME_TRACKS[biome_name]
		_log_info("Layer 1: %s -> %s" % [biome_name, track_key])
		crossfade_to(track_key)
		return

	# Layer 4 (only if enabled): Parametric selection based on biome vector
	if iconmap_mode_enabled:
		_log_info("Layer 4: No mapping for %s, trying parametric..." % biome_name)
		_ensure_cache_loaded()
		if _biome_vectors.has(biome_name):
			var best_track := _select_track_for_biome_vector(biome_name)
			if not best_track.is_empty():
				_log_info("Layer 4 selected: %s" % best_track)
				crossfade_to(best_track)
				return

	# Fallback - no mapping found
	_log_info("Fallback: %s has no track mapping, using %s" % [biome_name, FALLBACK_TRACK])
	crossfade_to(FALLBACK_TRACK)


func _select_track_for_biome_vector(biome_name: String) -> String:
	# Find best matching track for a biome using its emoji vector.
	#
	# Compares the biome's vector against all OTHER biomes that have dedicated tracks,
	# returning the track with highest cos² similarity.
	_ensure_cache_loaded()

	if not _biome_vectors.has(biome_name):
		return ""

	var source_data: Dictionary = _biome_vectors[biome_name]
	var source_emojis: Array = source_data["emojis"]
	var source_weights: Array = source_data["weights"]

	var best_track := ""
	var best_similarity := -1.0

	# Compare against biomes that have dedicated tracks
	for target_biome in BIOME_TRACKS.keys():
		if target_biome == biome_name:
			continue  # Skip self
		if not _biome_vectors.has(target_biome):
			continue

		var target_data: Dictionary = _biome_vectors[target_biome]
		var target_emojis: Array = target_data["emojis"]
		var target_weights: Array = target_data["weights"]

		# Build lookup for target
		var target_map: Dictionary = {}
		for i in range(target_emojis.size()):
			target_map[target_emojis[i]] = float(target_weights[i])

		# Compute dot product
		var dot := 0.0
		for i in range(source_emojis.size()):
			var emoji: String = source_emojis[i]
			if target_map.has(emoji):
				dot += float(source_weights[i]) * target_map[emoji]

		var cos2: float = dot * dot

		if cos2 > best_similarity:
			best_similarity = cos2
			best_track = BIOME_TRACKS[target_biome]

	return best_track


func play_icon_track(icon: String) -> void:
	# Play the track associated with an icon/emoji.
	#
	# Parametrically selects the best matching track using the icon's
	# faction associations from _icon_vectors (cosine similarity on eigenvectors).
	#
	# Args:
	# icon: Emoji string (e.g., "🌾", "🍄")
	if _disabled:
		return

	# Parametric selection based on icon's faction associations
	_ensure_cache_loaded()
	if _icon_vectors.has(icon):
		var icon_data: Dictionary = _icon_vectors[icon]
		var icon_emojis: Array = icon_data["emojis"]
		var icon_weights: Array = icon_data["weights"]

		# Build an iconmap from this icon's associations
		var icon_map: Dictionary = {}
		for i in range(icon_emojis.size()):
			icon_map[icon_emojis[i]] = icon_weights[i]

		# Use the iconmap similarity to find best biome
		var similarities := get_iconmap_similarities(icon_map)
		if not similarities.is_empty() and similarities[0]["similarity"] > 0.01:
			crossfade_to(similarities[0]["track"])
			return

	# No match found - don't change music (could also use FALLBACK_TRACK)


func crossfade_to(track_key: String) -> void:
	# Crossfade to a new track
	if _verbose:
		_log_info("[MusicManager] crossfade_to(%s)" % track_key)
	_layer3_stopped = false  # Clear intentional stop flag
	if _disabled:
		_log_info("DISABLED - skipping crossfade")
		return

	if track_key == _current_track and _active_player.playing:
		_log_info("Already playing %s - skipping" % track_key)
		return

	# Prevent rapid successive crossfades (minimum MIN_CROSSFADE_INTERVAL between calls)
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_crossfade_time < MIN_CROSSFADE_INTERVAL:
		_log_info("Rate limited - skipping crossfade")
		return
	_last_crossfade_time = now

	if not TRACKS.has(track_key):
		push_warning("MusicManager: Unknown track '%s'" % track_key)
		_log_info("ERROR: Unknown track '%s'" % track_key)
		return

	var stream = _get_or_load_stream(track_key)
	if not stream:
		_log_info("ERROR: Failed to load stream for '%s'" % track_key)
		return

	if _verbose:
		_log_info("[MusicManager] Starting crossfade to '%s'" % track_key)

	var previous_track := _current_track

	# Save playback position + evolution count of current track (ghost timer)
	if not previous_track.is_empty():
		_save_ghost_timer_position(previous_track)

	# Cancel any existing crossfade
	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()

	# Swap players
	var old_player = _active_player
	_active_player = _inactive_player
	_inactive_player = old_player

	# Setup new track
	_active_player.stream = stream
	_active_player.volume_db = -80.0  # Start silent
	_active_player.play()

	# Calculate virtual position using evolution-synced ghost timer
	if preserve_track_positions and _track_positions.has(track_key):
		var track_info: Dictionary = _track_positions[track_key]
		var saved_pos: float = track_info.get("position", 0.0)
		var saved_evo: int = track_info.get("evolution_count", 0)
		var saved_biome: String = track_info.get("biome_name", "")

		# Get current evolution count for the saved biome
		var current_evo := _get_biome_evolution_count(saved_biome)
		var evo_steps := current_evo - saved_evo

		# Calculate where the track "would be" based on evolution steps
		var elapsed_time := float(evo_steps) * EVOLUTION_DT
		var virtual_pos := saved_pos + elapsed_time

		# Handle looping - wrap around track length
		var track_length := stream.get_length()
		if track_length > 0:
			virtual_pos = fmod(virtual_pos, track_length)
			if virtual_pos < 0.0:
				virtual_pos += track_length

		_active_player.seek(maxf(0.0, virtual_pos))
		_log_info("Ghost timer: %s advanced %d evo steps (%.1fs) -> now at %.1fs" % [
			track_key, evo_steps, elapsed_time, virtual_pos])

	# Crossfade tween
	_crossfade_tween = create_tween()
	_crossfade_tween.set_parallel(true)

	# Fade in new track (ease out for smooth start)
	var target_db = _volume_to_db(_volume)
	_crossfade_tween.tween_property(_active_player, "volume_db", target_db, CROSSFADE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Fade out old track (ease in for smooth finish)
	_crossfade_tween.tween_property(_inactive_player, "volume_db", -80.0, CROSSFADE_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_crossfade_tween.chain().tween_callback(_inactive_player.stop)

	_current_track = track_key
	track_changed.emit(track_key)

	# Info log for all track changes
	if VerboseHelper.get_config():
		var from_str := previous_track if not previous_track.is_empty() else "(none)"
		VerboseHelper.info("music", "🎶", "Now playing: %s (was: %s)" % [track_key, from_str])


func stop(fade_out: bool = true) -> void:
	# Stop music playback
	if _disabled:
		return

	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()

	if fade_out and _active_player.playing:
		var tween = create_tween()
		tween.tween_property(_active_player, "volume_db", -80.0, 1.0)
		tween.chain().tween_callback(_active_player.stop)
	else:
		_active_player.stop()
		_inactive_player.stop()

	_current_track = ""


func set_volume(value: float) -> void:
	# Set music volume (0.0 to 1.0)
	if _disabled:
		return

	_volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	_save_volume_preference()
	volume_changed.emit(_volume)


func get_volume() -> float:
	# Get current volume (0.0 to 1.0)
	return _volume


func set_muted(muted: bool) -> void:
	# Mute/unmute music
	if _disabled:
		return

	_muted = muted
	_apply_volume()


func is_muted() -> bool:
	return _muted


func is_playing() -> bool:
	if _disabled or not _active_player:
		return false
	return _active_player.playing


func reset() -> void:
	# Reset music manager completely - stop all playback and clear state
	if _disabled:
		return

	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()

	_player_a.stop()
	_player_b.stop()
	_player_a.stream = null
	_player_b.stream = null
	_current_track = ""
	_stream_cache.clear()
	_last_crossfade_time = 0.0
	_health_check_timer = 0.0
	_track_positions.clear()  # Clear saved positions on reset


func debug_test_audio() -> void:
	# DEBUG: Test if audio playback works. Call from console: MusicManager.debug_test_audio()
	_log_info("[MusicManager] DEBUG: Testing audio playback...")
	_log_info("[MusicManager] _disabled=%s, _active_player=%s" % [_disabled, _active_player != null])
	if _disabled:
		_log_info("[MusicManager] DISABLED - cannot play")
		return
	_log_info("[MusicManager] Playing fallback track: %s" % FALLBACK_TRACK)
	crossfade_to(FALLBACK_TRACK)


func debug_status() -> void:
	# DEBUG: Print current music manager status.
	_log_info("[MusicManager] === STATUS ===")
	_log_info("  disabled: %s" % _disabled)
	_log_info("  current_track: '%s'" % _current_track)
	_log_info("  volume: %.2f (muted: %s)" % [_volume, _muted])
	_log_info("  active_player.playing: %s" % (str(_active_player.playing) if _active_player else "N/A"))
	_log_info("  iconmap_mode: %s" % iconmap_mode_enabled)
	_log_info("  register_gating: %s" % stop_music_when_no_registers)
	if _get_active_biome_manager():
		_log_info("  ActiveBiomeManager: connected, current='%s'" % _get_active_biome_manager().get_active_biome())
	else:
		_log_info("  ActiveBiomeManager: NOT AVAILABLE")


## ============================================================================
## INTERNAL
## ============================================================================

func _get_or_load_stream(track_key: String) -> AudioStream:
	if _disabled:
		return null

	if _stream_cache.has(track_key):
		return _stream_cache[track_key]

	var path = TRACKS.get(track_key, "")
	if path.is_empty():
		push_warning("MusicManager: Track key '%s' not found in TRACKS" % track_key)
		return null

	if not ResourceLoader.exists(path):
		push_error("MusicManager: Track file not found: %s" % path)
		return null

	var stream = load(path) as AudioStream
	if stream:
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		_stream_cache[track_key] = stream
	else:
		push_error("MusicManager: Failed to load stream from: %s" % path)
	return stream


func _play_instant(stream: AudioStream, track_key: String) -> void:
	_layer3_stopped = false  # Clear intentional stop flag
	_active_player.stream = stream
	_active_player.volume_db = _volume_to_db(_volume)
	_active_player.play()
	_current_track = track_key
	track_changed.emit(track_key)


func _apply_volume() -> void:
	if _disabled:
		return

	var db = -80.0 if _muted else _volume_to_db(_volume)
	if _active_player and _active_player.playing:
		_active_player.volume_db = db


func _volume_to_db(linear: float) -> float:
	# Convert linear volume (0-1) to decibels
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)


func _save_volume_preference() -> void:
	# Save volume to user preferences
	if _disabled:
		return

	var config = ConfigFile.new()
	var path = "user://settings.cfg"
	config.load(path)  # Ignore error if file doesn't exist
	config.set_value("audio", "music_volume", _volume)
	config.save(path)


func _load_volume_preference() -> void:
	# Load volume from user preferences
	if _disabled:
		return

	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err == OK:
		_volume = config.get_value("audio", "music_volume", 0.7)


func _is_headless() -> bool:
	return RuntimeEnv.is_headless()


## ============================================================================
## ICONMAP-BASED MUSIC SELECTION (Cached)
## ============================================================================
## Uses cos²(θ) similarity between IconMap state and biome vectors to select
## the most harmonically appropriate track based on current quantum state.
##
## Vectors are computed from biomes_merged.json and cached. Cache auto-rebuilds
## when source files change.

const BIOMES_JSON_PATH := "res://Core/Biomes/data/biomes_merged.json"
const FACTIONS_JSON_PATH := "res://Core/Factions/data/factions_merged.json"
const CACHE_PATH := "user://cache/music_vectors.json"
## Bump this when the vector-building logic changes to force cache invalidation
const CACHE_VERSION := 2

## Cached data (loaded on demand, rebuilt when sources change)
var _emoji_index: Array = []  # Unified emoji space
var _biome_vectors: Dictionary = {}  # biome_name -> {emojis: [], weights: []}
var _icon_vectors: Dictionary = {}  # emoji -> {emojis: [], weights: []} for parametric track selection
var _cache_loaded: bool = false
var _source_hashes: Dictionary = {}  # path -> hash for change detection


func _ensure_cache_loaded() -> void:
	# Lazy-load the vector cache, rebuilding if sources changed.
	if _cache_loaded:
		return

	var needs_rebuild := false

	# Check if cache exists
	if not FileAccess.file_exists(CACHE_PATH):
		needs_rebuild = true
	else:
		# Load cache and check source hashes
		var cache := _load_cache()
		if cache.is_empty():
			needs_rebuild = true
		elif cache.get("version", 0) != CACHE_VERSION:
			needs_rebuild = true  # Logic changed - must rebuild
		else:
			_source_hashes = cache.get("source_hashes", {})
			if _check_sources_changed():
				needs_rebuild = true
			else:
				# Cache is valid, use it
				_emoji_index = cache.get("emoji_index", [])
				_biome_vectors = cache.get("biome_vectors", {})
				_icon_vectors = cache.get("icon_vectors", {})
				_cache_loaded = true
				return

	if needs_rebuild:
		_rebuild_cache()

	_cache_loaded = true


func _check_sources_changed() -> bool:
	# Check if source JSON files have changed since cache was built.
	var sources := [BIOMES_JSON_PATH, FACTIONS_JSON_PATH]
	for path in sources:
		var current_hash := _compute_file_hash(path)
		var cached_hash: String = _source_hashes.get(path, "")
		if current_hash != cached_hash:
			return true
	return false


func _get_active_farm() -> Node:
	return InstrumentLocator.resolve_active_farm(self)


func _get_active_biome_manager() -> Node:
	return ActiveBiomeManager


func _compute_file_hash(path: String) -> String:
	# Compute a simple hash of file contents for change detection.
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return ""
	var content := file.get_as_text()
	file.close()
	# Use content length + first/last 100 chars as quick hash
	var hash_str := "%d:%s:%s" % [
		content.length(),
		content.substr(0, 100),
		content.substr(max(0, content.length() - 100))
	]
	return hash_str.md5_text()


func _load_cache() -> Dictionary:
	# Load cached vectors from disk.
	if not FileAccess.file_exists(CACHE_PATH):
		return {}
	var file := FileAccess.open(CACHE_PATH, FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	return json.data if json.data is Dictionary else {}


func _save_cache() -> void:
	# Save computed vectors to disk cache.
	# Ensure cache directory exists
	var cache_dir := ProjectSettings.globalize_path("user://cache")
	if not DirAccess.dir_exists_absolute(cache_dir):
		DirAccess.make_dir_recursive_absolute(cache_dir)

	var cache := {
		"version": CACHE_VERSION,
		"source_hashes": _source_hashes,
		"emoji_index": _emoji_index,
		"biome_vectors": _biome_vectors,
		"icon_vectors": _icon_vectors,
		"built_at": Time.get_datetime_string_from_system()
	}

	var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(cache, "\t"))
		file.close()


func _rebuild_cache() -> void:
	# Rebuild vector cache from source JSON files.
	_log_info("MusicManager: Rebuilding vector cache...")

	# Reset
	_emoji_index = []
	_biome_vectors = {}
	_icon_vectors = {}
	_source_hashes = {}

	# Build from biomes
	var biomes := _load_json_array(BIOMES_JSON_PATH)
	_source_hashes[BIOMES_JSON_PATH] = _compute_file_hash(BIOMES_JSON_PATH)

	# Build from factions (for icon vectors)
	var factions := _load_json_array(FACTIONS_JSON_PATH)
	_source_hashes[FACTIONS_JSON_PATH] = _compute_file_hash(FACTIONS_JSON_PATH)

	# Collect all emojis into unified index
	var emoji_set: Dictionary = {}

	for biome in biomes:
		for emoji in biome.get("emojis", []):
			if not emoji.is_empty() and not emoji.is_valid_identifier():
				emoji_set[emoji] = true
		for emoji in biome.get("atom_components", {}).keys():
			if not emoji.is_empty() and not emoji.is_valid_identifier():
				emoji_set[emoji] = true

	for faction in factions:
		for emoji in faction.get("cloud", []):
			if not emoji.is_empty() and not emoji.is_valid_identifier():
				emoji_set[emoji] = true
		for emoji in faction.get("hamiltonian", {}).keys():
			if not emoji.is_empty() and not emoji.is_valid_identifier():
				emoji_set[emoji] = true

	_emoji_index = emoji_set.keys()
	_emoji_index.sort()

	# Build biome vectors
	for biome in biomes:
		var _name: String = biome.get("name", "")
		if _name.is_empty():
			continue

		var vec := _build_normalized_vector(
			biome.get("emojis", []),
			biome.get("atom_components", {})
		)
		_biome_vectors[_name] = vec

	# Build icon vectors from factions (aggregate by emoji)
	var emoji_aggregates: Dictionary = {}  # emoji -> {emojis: Set, weights: Dict}

	for faction in factions:
		var cloud: Array = faction.get("cloud", [])
		var hamiltonian: Dictionary = faction.get("hamiltonian", {})
		var _self_energies: Dictionary = faction.get("self_energies", {})

		# Each emoji in the cloud gets associated with all other emojis in this faction
		for emoji in cloud:
			if not emoji_aggregates.has(emoji):
				emoji_aggregates[emoji] = {"emojis": {}, "weights": {}}

			# Add all cloud emojis
			for other in cloud:
				emoji_aggregates[emoji]["emojis"][other] = true
				var weight: float = emoji_aggregates[emoji]["weights"].get(other, 0.0)
				emoji_aggregates[emoji]["weights"][other] = weight + 1.0

			# Add hamiltonian connections with their strengths
			if hamiltonian.has(emoji):
				var targets: Dictionary = hamiltonian[emoji]
				for target in targets.keys():
					emoji_aggregates[emoji]["emojis"][target] = true
					var val = targets[target]
					var strength := 0.0
					if val is float or val is int:
						strength = abs(float(val))
					elif val is Array and val.size() > 0:
						strength = abs(float(val[0]))
					var existing: float = emoji_aggregates[emoji]["weights"].get(target, 0.0)
					emoji_aggregates[emoji]["weights"][target] = existing + strength

	# Normalize icon vectors
	for emoji in emoji_aggregates.keys():
		var agg: Dictionary = emoji_aggregates[emoji]
		var emojis: Array = agg["emojis"].keys()
		var weights: Array = []
		for e in emojis:
			weights.append(agg["weights"].get(e, 1.0))

		# Normalize
		var norm := 0.0
		for w in weights:
			norm += w * w
		norm = sqrt(norm)
		if norm > 0.001:
			for i in range(weights.size()):
				weights[i] /= norm

		_icon_vectors[emoji] = {"emojis": emojis, "weights": weights}

	# Save to disk
	_save_cache()
	_log_info("MusicManager: Cache rebuilt - %d biomes, %d icons, %d emoji dimensions" % [
		_biome_vectors.size(), _icon_vectors.size(), _emoji_index.size()
	])


func _build_normalized_vector(emojis: Array, atom_components: Dictionary) -> Dictionary:
	# Build a normalized vector from emoji list and atom_components weights.
	var result_emojis: Array = []
	var result_weights: Array = []

	# Start with equal weights for all emojis (skip plain-ASCII keys like "everything")
	var weight_map: Dictionary = {}
	for emoji in emojis:
		if not emoji.is_empty() and not emoji.is_valid_identifier():
			weight_map[emoji] = 1.0

	# Override with self_energy from atom_components if available
	for emoji in atom_components.keys():
		if emoji.is_empty() or emoji.is_valid_identifier():
			continue  # Skip non-emoji keys
		var comp = atom_components[emoji]
		var weight := 1.0
		if comp is Dictionary and comp.has("self_energy"):
			weight = abs(float(comp["self_energy"])) + 0.1
		weight_map[emoji] = weight

	# Convert to arrays
	for emoji in weight_map.keys():
		result_emojis.append(emoji)
		result_weights.append(weight_map[emoji])

	# Normalize
	var norm := 0.0
	for w in result_weights:
		norm += w * w
	norm = sqrt(norm)
	if norm > 0.001:
		for i in range(result_weights.size()):
			result_weights[i] /= norm

	return {"emojis": result_emojis, "weights": result_weights}


func _load_json_array(path: String) -> Array:
	# Load a JSON file that contains an array.
	if not FileAccess.file_exists(path):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return []
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return []
	return json.data if json.data is Array else []


func get_iconmap_similarities(icon_map: Dictionary) -> Array:
	# Get similarity scores for all biomes against an IconMap.
	#
	# Returns: Array of {biome: String, similarity: float, track: String} sorted by similarity
	var results: Array = []

	if icon_map.is_empty():
		return results

	_ensure_cache_loaded()

	# Normalize the icon_map
	var icon_norm := 0.0
	for emoji in icon_map.keys():
		var val: float = float(icon_map[emoji])
		icon_norm += val * val
	icon_norm = sqrt(icon_norm)
	if icon_norm < 0.001:
		return results

	for biome_name in _biome_vectors.keys():
		var biome_data: Dictionary = _biome_vectors[biome_name]
		var emojis: Array = biome_data["emojis"]
		var weights: Array = biome_data["weights"]

		var dot := 0.0
		for i in range(emojis.size()):
			var emoji: String = emojis[i]
			if icon_map.has(emoji):
				var icon_weight: float = float(icon_map[emoji]) / icon_norm
				dot += icon_weight * float(weights[i])

		var cos2: float = dot * dot
		results.append({
			"biome": biome_name,
			"similarity": cos2,
			"track": BIOME_TRACKS.get(biome_name, FALLBACK_TRACK)
		})

	results.sort_custom(func(a, b): return a["similarity"] > b["similarity"])
	return results
