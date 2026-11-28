class_name FloatingRewardLayer
extends Control

## FloatingRewardLayer — the POP celebration (Mini-Metro loop-feedback pass).
##
## On a successful pop, a "+N <emoji>" flier springs out of the popped station
## and flies to that emoji's slot in the ResourcePanel, which bounces on catch.
## Earning is VISIBLE: the loop's payoff moment happens in world space, not as
## a silent counter increment.
##
## Purely cosmetic (anti-gating law): listens to QuantumInstrument's
## action_performed — the same pattern as SFXRegistry — and never touches
## mechanics. Sits on the PlayerShell overlay layer below toasts (z 100).

const ACCENT := UIStyleFactory.COLOR_ACCENT_GOLD

## Every feel knob (sizes, timings, combo window, the big-pop threshold) and
## the player's intensity / reduced-motion settings live in FeedbackTuning.
## Harvest: orb squash-and-stretch, a Pop-Harvest badge, a spark burst and
## the "+N" flier. Planting and ripening get quiet rings and a small punch,
## so ripe plots read at a glance; harvest stays the payoff.

var _farm: Node = null
var _quantum_viz: Node = null
var _resource_panel: Node = null
var _connected_instrument = null
var _retry_accum: float = 0.0

## Ripe-plot watcher: "biome:qid" → seconds until that ripe plot's next breath.
var _ripe_accum: float = 0.0
var _ripe_biome: String = ""
var _ripe_pulse_in: Dictionary = {}
var _badge_texture: Texture2D = null

## Punctuation guards — prevent overlapping dips leaving global state stuck.
var _hitstop_active: bool = false
var _prev_time_scale: float = 1.0
var _music_ducking: bool = false
var _music_duck_base_db: float = 0.0


func setup(farm: Node, quantum_viz: Node, resource_panel: Node) -> void:
	_farm = farm
	_quantum_viz = quantum_viz
	_resource_panel = resource_panel
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_try_connect()


func _process(delta: float) -> void:
	# Instrument instances are replaced across restarts — re-resolve lazily
	# (same reason SFXRegistry re-tries; 1s throttle keeps this free).
	_retry_accum += delta
	if _retry_accum >= 1.0:
		_retry_accum = 0.0
		_try_connect()
	_ripe_accum += delta
	if _ripe_accum >= FeedbackTuning.RIPE_POLL_S:
		_poll_ripe(_ripe_accum)
		_ripe_accum = 0.0


func _try_connect() -> void:
	if _farm == null or not is_instance_valid(_farm):
		return
	var instrument = _farm.instrument if "instrument" in _farm else null
	if instrument == null or instrument == _connected_instrument:
		return
	if _connected_instrument != null and is_instance_valid(_connected_instrument):
		if _connected_instrument.action_performed.is_connected(_on_action_performed):
			_connected_instrument.action_performed.disconnect(_on_action_performed)
	if instrument.has_signal("action_performed"):
		instrument.action_performed.connect(_on_action_performed)
		_connected_instrument = instrument
		_ripe_biome = ""  # a new run: re-prime the ripe watcher silently
		_ripe_pulse_in.clear()


func _on_action_performed(action: String, result: Dictionary) -> void:
	if not result.get("success", false):
		return
	match action:
		"pop":
			var emoji := str(result.get("resource", ""))
			var amount := int(result.get("amount", 0))
			if emoji == "" or amount <= 0:
				return
			var biome_name := str(result.get("biome_name", ""))
			var reg := int(result.get("register_id", -1))
			var from_pos := _station_position(biome_name, reg)
			# Surprisal-scaled celebration: payout is already −kT·log p, so the
			# reward size IS the rarity. One soft mapping, no thresholds.
			var rel := FeedbackTuning.rel_for(FeedbackTuning.harvest_size(result))
			celebrate_harvest(from_pos, rel, biome_name, reg)
			spawn_reward(emoji, amount, from_pos, rel)
		"inject_icon":
			# Planting: a quiet green ring once the new orb is on screen.
			var tw := create_tween()
			tw.tween_interval(FeedbackTuning.PLANT_CUE_DELAY_S)
			tw.tween_callback(_quiet_cue.bind(str(result.get("biome", "")),
					int(result.get("qubit_index", -1)), FeedbackTuning.PLANT_COLOR, FeedbackTuning.PUNCH_PLANT))
		"measure":
			# Measure snap: a quick converging tick — "the answer locked in."
			var biome := str(result.get("biome_name", ""))
			if biome == "" and _quantum_viz != null and "active_biome" in _quantum_viz:
				biome = str(_quantum_viz.active_biome)
			var pos := _station_position(biome, int(result.get("register_id", -1)))
			if FeedbackTuning.motion() > 0.0:
				_spawn_burst(pos, 0.0, Color(0.45, 0.95, 1.0, 0.9), true)
			if str(result.get("known_tier", "none")) != "none":
				spawn_known_strike(str(result.get("outcome", "")), int(result.get("amount", 0)),
						str(result.get("known_tier", "none")), pos)
		"reap":
			_cascade_reap(result)
			_surge_flow()
		"fast_forward":
			_surge_flow()
		"enter_icon":
			_punctuate_fractal_step(FeedbackTuning.FRACTAL_DESCEND_COLOR)
		"ascend_fractal":
			_punctuate_fractal_step(FeedbackTuning.FRACTAL_ASCEND_COLOR)


func _surge_flow() -> void:
	# Fast-forward/reap visibly spins the metro flow dots for a beat.
	if _quantum_viz != null and is_instance_valid(_quantum_viz) \
			and _quantum_viz.has_method("surge_time_flow"):
		_quantum_viz.surge_time_flow()


## Big-moment punctuation — a rare hitstop + gold flash + Music-bus duck, fired
## only for genuinely surprising pops. Purely cosmetic; each dip restores itself
## reliably (timers/tweens the SceneTree owns, plus an _exit_tree failsafe) so a
## restart mid-punctuation can never leave Engine.time_scale or the bus stuck.
func _punctuate_big_pop(rel: float) -> void:
	if FeedbackTuning.motion() > 0.0:
		_hitstop()
		_screen_flash(rel)
	if FeedbackTuning.intensity() > 0.0:
		_duck_music()


## Light-touch descend/ascend punctuation — every dive earns it (unlike the
## rare pop hitstop), so deliberately no time_scale dip: a brief tinted flash
## in the portal's own hue plus a shallow, quick Music duck. Reuses the same
## self-contained flash/duck machinery (tween-owned, _exit_tree failsafe).
func _punctuate_fractal_step(hue: Color) -> void:
	if FeedbackTuning.motion() > 0.0:
		_screen_flash(0.0, hue, FeedbackTuning.FRACTAL_FLASH_PEAK * FeedbackTuning.motion())
	if FeedbackTuning.intensity() > 0.0:
		_duck_music(FeedbackTuning.FRACTAL_DUCK_DB, FeedbackTuning.FRACTAL_DUCK_HOLD_S, FeedbackTuning.FRACTAL_DUCK_RESTORE_S)


func _hitstop() -> void:
	if _hitstop_active:
		return  # never re-dip a live hitstop — that's how time_scale gets stuck
	var tree := get_tree()
	if tree == null:
		return
	_hitstop_active = true
	_prev_time_scale = Engine.time_scale
	Engine.time_scale = FeedbackTuning.HITSTOP_SCALE
	# ignore_time_scale=true so the restore fires after real HITSTOP_S, not dilated.
	var t := tree.create_timer(FeedbackTuning.HITSTOP_S, true, false, true)
	t.timeout.connect(_restore_time_scale)


func _restore_time_scale() -> void:
	if not _hitstop_active:
		return
	Engine.time_scale = _prev_time_scale
	_hitstop_active = false


## `color`/`peak_override` let the fractal step reuse this for a tinted, quieter
## flash; the default (color=null) is the original warm-white/gold pop flash.
func _screen_flash(rel: float, color = null, peak_override: float = -1.0) -> void:
	# A quick full-screen flash that fades out. Self-contained: it's a child of
	# this layer, so a free takes it with us — nothing to restore.
	var base: Color = color if color is Color else Color(1.0, 0.95, 0.8)
	var flash := ColorRect.new()
	flash.color = Color(base.r, base.g, base.b, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 20  # above the fliers
	add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var peak: float = peak_override if peak_override >= 0.0 else (FeedbackTuning.FLASH_PEAK + FeedbackTuning.FLASH_PEAK_PER_REL * rel) * FeedbackTuning.motion()  # subtle; scales gently with surprisal
	var tw := create_tween()
	tw.tween_property(flash, "color:a", peak, 0.04).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "color:a", 0.0, 0.30).set_ease(Tween.EASE_IN)
	tw.tween_callback(flash.queue_free)


## Self-contained duck of the Music bus (enabled by the bus split). No coupling
## to MusicManager.celebrate_swell (that's the ending's alone). Parameterized
## so the light fractal-step punctuation can duck shallower/shorter than the
## big-pop moment without a second copy of the tween machinery.
func _duck_music(db: float = FeedbackTuning.MUSIC_DUCK_DB, hold_s: float = FeedbackTuning.MUSIC_DUCK_HOLD_S,
		restore_s: float = FeedbackTuning.MUSIC_DUCK_RESTORE_S) -> void:
	var idx := AudioServer.get_bus_index("Music")
	if idx < 0 or _music_ducking:
		return  # no Music bus (fell back to Master) or already ducking
	var tree := get_tree()
	if tree == null:
		return
	_music_ducking = true
	_music_duck_base_db = AudioServer.get_bus_volume_db(idx)
	AudioServer.set_bus_volume_db(idx, _music_duck_base_db - db)
	var tw := create_tween()
	tw.tween_interval(hold_s)
	tw.tween_method(_set_music_bus_db,
			_music_duck_base_db - db, _music_duck_base_db, restore_s)
	tw.tween_callback(_finish_music_duck)


func _set_music_bus_db(db: float) -> void:
	var idx := AudioServer.get_bus_index("Music")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)


func _finish_music_duck() -> void:
	_music_ducking = false


func _restore_music_bus() -> void:
	# Failsafe (free mid-duck): snap the Music bus back to its resting level.
	if not _music_ducking:
		return
	var idx := AudioServer.get_bus_index("Music")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, _music_duck_base_db)
	_music_ducking = false


func _exit_tree() -> void:
	# Never leave global audio/time state stuck if we're freed mid-punctuation.
	_restore_time_scale()
	_restore_music_bus()


func _station_position(biome_name: String, register_id: int, centre_fallback: bool = true) -> Vector2:
	var viz := _live_renderer()
	if viz != null and viz.has_method("get_register_screen_position"):
		var p: Vector2 = viz.get_register_screen_position(biome_name, register_id)
		if p.x >= 0.0:
			return p
	return get_viewport_rect().size * 0.5 if centre_fallback else Vector2(-1, -1)


## The live field renderer: the 2D force graph we were handed, or the 3D field
## FarmView holds (that one is not passed around as quantum_viz).
func _live_renderer() -> Node:
	var viz = _quantum_viz
	if viz == null or not (is_instance_valid(viz) and viz.has_method("get_register_screen_position")):
		# 3D field path: the live renderer is held by FarmView, not passed as quantum_viz.
		var fvs = get_tree().get_nodes_in_group("farm_view")
		if fvs.size() > 0 and fvs[0].has_method("get_field_renderer"):
			viz = fvs[0].get_field_renderer()
	if viz != null and is_instance_valid(viz):
		return viz
	return null


## Expanding ring at a station — pop celebration (accent gold, size grows with
## the payout's surprisal) or measure snap (cyan, converges inward instead).
func _spawn_burst(at_global: Vector2, rel: float, color: Color = ACCENT,
		converge: bool = false) -> void:
	var ring := RingBurst.new()
	ring.color = Color(color.r, color.g, color.b, 0.9)
	add_child(ring)
	ring.position = get_global_transform().affine_inverse() * at_global
	var r_from: float = FeedbackTuning.RING_MEASURE_FROM + FeedbackTuning.RING_MEASURE_FROM_PER_REL * rel
	var r_to: float = FeedbackTuning.RING_MEASURE_TO
	if not converge:
		r_from = FeedbackTuning.RING_POP_FROM
		r_to = FeedbackTuning.RING_POP_TO + FeedbackTuning.RING_POP_TO_PER_REL * rel
	ring.radius = r_from
	ring.width = 2.0 + 3.0 * rel
	var tw := create_tween()
	tw.set_parallel(true)
	var dur: float = FeedbackTuning.RING_MEASURE_S if converge else FeedbackTuning.RING_POP_S
	tw.tween_property(ring, "radius", r_to, dur) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "alpha", 0.0, dur)
	tw.set_parallel(false)
	tw.tween_callback(ring.queue_free)


## Reap = "watch the machine you built pay out": one flier per harvested emoji,
## staggered left-to-right so the payout cascades into the resource bar.
func _cascade_reap(result: Dictionary) -> void:
	var totals: Dictionary = {}
	for key in ["flux_totals", "icon_totals"]:
		var part = result.get(key, {})
		if part is Dictionary:
			for emoji in part:
				totals[emoji] = int(totals.get(emoji, 0)) + int(part[emoji])
	if totals.is_empty():
		return
	var centre := get_viewport_rect().size * Vector2(0.5, 0.55)
	var idx := 0
	for emoji in totals:
		var amount: int = int(totals[emoji])
		if amount <= 0:
			continue
		var from := centre + Vector2((idx - totals.size() * 0.5) * 60.0, 20.0 * (idx % 2))
		var tw := create_tween()
		tw.tween_interval(0.08 * idx)
		tw.tween_callback(spawn_reward.bind(emoji, amount, from, 0.4))
		idx += 1


## The harvest celebration at the plot, sized by the payout's surprisal and
## the player's intensity. Reduced motion skips all of it (the flier still
## reports the yield).
func celebrate_harvest(at_global: Vector2, rel: float, biome_name: String = "",
		register_id: int = -1) -> void:
	var m := FeedbackTuning.motion()
	if m > 0.0:
		_punch(biome_name, register_id, (FeedbackTuning.PUNCH_BASE + FeedbackTuning.PUNCH_PER_REL * rel) * m, FeedbackTuning.PUNCH_SQUASH)
		_spawn_badge(at_global, rel, m)
		_spawn_burst(at_global, rel)
		_spawn_sparks(at_global, rel, m)
	# Rare big-moment punctuation: only the truly surprising pops.
	if rel >= FeedbackTuning.BIG_POP_REL:
		_punctuate_big_pop(rel)


func _punch(biome_name: String, register_id: int, strength: float, squash: float = 0.0) -> void:
	if register_id < 0 or strength <= 0.0:
		return
	var viz := _live_renderer()
	if viz != null and viz.has_method("punch_register"):
		viz.punch_register(biome_name, register_id, strength, squash)


## Pop-Harvest badge (the Gather tool's own icon) at the plot: stretch tall,
## squash wide, settle, fade. Bigger payouts get a bigger badge.
func _spawn_badge(at_global: Vector2, rel: float, m: float) -> void:
	if _badge_texture == null and ResourceLoader.exists(FeedbackTuning.BADGE_PATH):
		_badge_texture = load(FeedbackTuning.BADGE_PATH)
	if _badge_texture == null:
		return
	var size := FeedbackTuning.BADGE_SIZE + FeedbackTuning.BADGE_SIZE_PER_REL * rel
	var badge := TextureRect.new()
	badge.texture = _badge_texture
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.size = Vector2(size, size)
	badge.pivot_offset = Vector2(size, size) * 0.5
	badge.z_index = 4
	add_child(badge)
	badge.position = (get_global_transform().affine_inverse() * at_global) - badge.pivot_offset
	var k := 0.35 * m  # squash-and-stretch depth
	badge.scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(badge, "scale", Vector2(1.0 - k, 1.0 + k), FeedbackTuning.BADGE_STRETCH_S) \
			.set_ease(Tween.EASE_OUT)
	tw.tween_property(badge, "scale", Vector2(1.0 + k, 1.0 - k * 0.8), FeedbackTuning.BADGE_SQUASH_S)
	tw.tween_property(badge, "scale", Vector2.ONE, FeedbackTuning.BADGE_SETTLE_S) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(badge, "modulate:a", 0.0, FeedbackTuning.BADGE_FADE_S)
	tw.tween_callback(badge.queue_free)


func _spawn_sparks(at_global: Vector2, rel: float, m: float) -> void:
	var n := int(round((FeedbackTuning.PARTICLES_BASE + FeedbackTuning.PARTICLES_PER_REL * rel) * m))
	if n <= 0:
		return
	var sparks := SparkBurst.new()
	sparks.color = ACCENT
	sparks.life = FeedbackTuning.PARTICLE_LIFE_S
	sparks.gravity = FeedbackTuning.PARTICLE_GRAVITY
	sparks.dot_size = FeedbackTuning.PARTICLE_SIZE * (1.0 + 0.5 * rel)
	sparks.z_index = 3
	add_child(sparks)
	sparks.position = get_global_transform().affine_inverse() * at_global
	sparks.emit(n, FeedbackTuning.PARTICLE_SPEED + FeedbackTuning.PARTICLE_SPEED_PER_REL * rel)


## A quiet anticipatory cue: a soft ring and a small punch. Only drawn when the
## plot is actually on screen (no centred fallback for whispers).
func _quiet_cue(biome_name: String, register_id: int, color: Color, punch: float) -> void:
	var m := FeedbackTuning.motion()
	if m <= 0.0 or register_id < 0:
		return
	var pos := _station_position(biome_name, register_id, false)
	if pos.x < 0.0:
		return
	_punch(biome_name, register_id, punch * m, FeedbackTuning.PUNCH_SQUASH)
	var ring := RingBurst.new()
	ring.color = Color(color.r, color.g, color.b, 0.55 * m)
	ring.width = 2.0
	ring.radius = FeedbackTuning.RING_POP_FROM
	add_child(ring)
	ring.position = get_global_transform().affine_inverse() * pos
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "radius", FeedbackTuning.RING_QUIET_TO, FeedbackTuning.RING_QUIET_S) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "alpha", 0.0, FeedbackTuning.RING_QUIET_S)
	tw.set_parallel(false)
	tw.tween_callback(ring.queue_free)


## Ripe-plot watcher. A tracked plot whose Berry phase reaches 2π gets a soft
## chime and a violet breath, then keeps breathing every RIPE_PULSE_PERIOD_S
## until it is incorporated, so ripe plots read at a glance. Switching biome
## (or a new run) primes silently: plots that were already ripe don't chime.
func _poll_ripe(dt: float) -> void:
	var reg = _active_berry_register()
	var biome_name: String = reg[0]
	var berry = reg[1]
	if berry == null:
		_ripe_pulse_in.clear()
		_ripe_biome = biome_name
		return
	var priming := biome_name != _ripe_biome
	if priming:
		_ripe_pulse_in.clear()
		_ripe_biome = biome_name
	var still: Dictionary = {}
	for q in berry.tracked_qubits():
		var qid := int(q)
		if not berry.is_ripe(qid):
			continue
		var key := "%s:%d" % [biome_name, qid]
		if not _ripe_pulse_in.has(key):
			still[key] = FeedbackTuning.RIPE_PULSE_PERIOD_S
			if not priming:
				var sfx = get_node_or_null("/root/SFXRegistry")
				if sfx != null and sfx.has_method("play_ripe"):
					sfx.play_ripe()
				_quiet_cue(biome_name, qid, FeedbackTuning.RIPE_COLOR, FeedbackTuning.PUNCH_RIPE)
			continue
		var left: float = float(_ripe_pulse_in[key]) - dt
		if left <= 0.0:
			left = FeedbackTuning.RIPE_PULSE_PERIOD_S
			_quiet_cue(biome_name, qid, FeedbackTuning.RIPE_COLOR, 0.0)
		still[key] = left
	_ripe_pulse_in = still


## [active biome name, its BerryPhaseRegister or null].
func _active_berry_register() -> Array:
	var abm = get_node_or_null("/root/ActiveBiomeManager")
	if abm == null or not abm.has_method("get_active_biome"):
		return ["", null]
	var biome_name := str(abm.get_active_biome())
	if _farm == null or not is_instance_valid(_farm) or not ("grid" in _farm) \
			or _farm.grid == null or not _farm.grid.has_method("get_biome"):
		return [biome_name, null]
	var biome = _farm.grid.get_biome(biome_name)
	if biome == null or not ("quantum_computer" in biome) or biome.quantum_computer == null:
		return [biome_name, null]
	var berry = biome.quantum_computer.berry_register
	if berry == null or not berry.has_method("tracked_qubits"):
		return [biome_name, null]
	return [biome_name, berry]


## Inner drawing node for the harvest spark burst: radial sparks that arc
## under a little gravity and fade. Self-freeing; no particle server needed
## (keeps the Web-Slim build's renderer happy).
class SparkBurst extends Node2D:
	var color: Color = UIStyleFactory.COLOR_ACCENT_GOLD
	var life: float = 0.5
	var gravity: float = 200.0
	var dot_size: float = 2.5
	var _age: float = 0.0
	var _pos: PackedVector2Array = PackedVector2Array()
	var _vel: PackedVector2Array = PackedVector2Array()

	func emit(count: int, speed: float) -> void:
		for i in range(count):
			var a := TAU * (float(i) + randf() * 0.6) / float(count)
			_pos.append(Vector2.ZERO)
			_vel.append(Vector2(cos(a), sin(a)) * speed * randf_range(0.55, 1.0))
		set_process(true)

	func _process(delta: float) -> void:
		_age += delta
		if _age >= life:
			queue_free()
			return
		for i in range(_pos.size()):
			_vel[i] = _vel[i] * (1.0 - 2.5 * delta) + Vector2(0.0, gravity * delta)
			_pos[i] += _vel[i] * delta
		queue_redraw()

	func _draw() -> void:
		var t := clampf(_age / life, 0.0, 1.0)
		var c := Color(color.r, color.g, color.b, (1.0 - t) * 0.95)
		var r := dot_size * (1.0 - 0.6 * t)
		for p in _pos:
			draw_circle(p, r, c)


## Inner drawing node for _spawn_burst — a single animated ring.
class RingBurst extends Node2D:
	var radius: float = 10.0:
		set(v):
			radius = v
			queue_redraw()
	var alpha: float = 1.0:
		set(v):
			alpha = v
			queue_redraw()
	var width: float = 2.0
	var color: Color = Color(UIStyleFactory.COLOR_ACCENT_GOLD, 0.9)

	func _draw() -> void:
		if alpha <= 0.01:
			return
		var c := Color(color.r, color.g, color.b, color.a * alpha)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, c, width, true)


func spawn_reward(emoji: String, amount: int, from_global: Vector2, rel: float = 0.3) -> void:
	var flier := HBoxContainer.new()
	flier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flier.z_index = 5

	var label := Label.new()
	label.text = "+%d" % amount
	# Surprisal-scaled: a rare payout arrives visibly larger. Soft, no thresholds.
	label.add_theme_font_size_override("font_size", FeedbackTuning.FLIER_FONT + int(FeedbackTuning.FLIER_FONT_PER_REL * rel))
	label.add_theme_color_override("font_color", ACCENT)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	flier.add_child(label)

	var glyph := EmojiDisplay.new()
	glyph.font_size = 26
	glyph.emoji = emoji
	glyph.custom_minimum_size = Vector2(30, 30)
	flier.add_child(glyph)

	add_child(flier)
	# Position via local transform (this layer is full-rect at origin, but stay
	# robust to any offset).
	flier.position = (get_global_transform().affine_inverse() * from_global) - Vector2(24, 44)
	flier.pivot_offset = Vector2(24, 16)

	if FeedbackTuning.motion() <= 0.0:
		# Reduced motion (or feedback off): the yield is still information, so
		# the number appears where it was earned and fades; nothing flies.
		var still := create_tween()
		still.tween_interval(FeedbackTuning.FLIER_INPLACE_S * 0.6)
		still.tween_property(flier, "modulate:a", 0.0, FeedbackTuning.FLIER_INPLACE_S * 0.4)
		still.tween_callback(flier.queue_free)
		return
	flier.scale = Vector2(0.4, 0.4)

	var target_global: Vector2 = from_global + Vector2(0, -120)
	if _resource_panel != null and is_instance_valid(_resource_panel) \
			and _resource_panel.has_method("get_emoji_slot_position"):
		target_global = _resource_panel.get_emoji_slot_position(emoji)
	var target_local: Vector2 = (get_global_transform().affine_inverse() * target_global) - Vector2(24, 16)

	var tw := create_tween()
	tw.tween_property(flier, "scale", Vector2(1.15, 1.15), FeedbackTuning.FLIER_SPRING_S) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(FeedbackTuning.FLIER_HOLD_S)
	tw.set_parallel(true)
	tw.tween_property(flier, "position", target_local, FeedbackTuning.FLIER_FLY_S) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(flier, "scale", Vector2(0.6, 0.6), FeedbackTuning.FLIER_FLY_S)
	tw.set_parallel(false)
	tw.tween_callback(_on_flier_landed.bind(flier, emoji))


## A strike on a plot that shares your vocabulary (#105): the banked amount and
## the multiplier it paid, in the known-word glow's colour, rising off the plot. The
## strike banks (Q pays), so the flier fades in place instead of flying to
## the resource bar.
func spawn_known_strike(emoji: String, amount: int, tier: String, from_global: Vector2) -> void:
	if amount <= 0:
		return
	var kc: Color = QuantumVisualGrammar.COLOR_KNOWN_WORD
	var flier := HBoxContainer.new()
	flier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flier.z_index = 5
	var label := Label.new()
	label.text = known_strike_text(amount, tier)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", kc)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	flier.add_child(label)
	if emoji != "":
		var glyph := EmojiDisplay.new()
		glyph.font_size = 24
		glyph.emoji = emoji
		glyph.custom_minimum_size = Vector2(28, 28)
		flier.add_child(glyph)
	add_child(flier)
	flier.position = (get_global_transform().affine_inverse() * from_global) - Vector2(40, 70)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(flier, "position:y", flier.position.y - 50.0, 1.4) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(flier, "modulate:a", 0.0, 0.6).set_delay(0.9)
	tw.set_parallel(false)
	tw.tween_callback(flier.queue_free)


## "+12  ×6 known word" / "+12  ×2 shared emoji": the tier the strike paid.
static func known_strike_text(amount: int, tier: String) -> String:
	return "+%d  %s" % [amount, ProbeActions.tier_label(tier)]


func _on_flier_landed(flier: Control, emoji: String) -> void:
	if _resource_panel != null and is_instance_valid(_resource_panel) \
			and _resource_panel.has_method("bounce_emoji"):
		_resource_panel.bounce_emoji(emoji)
	if is_instance_valid(flier):
		flier.queue_free()
