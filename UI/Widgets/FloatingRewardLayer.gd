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

const ACCENT := Color(1.0, 0.8, 0.3)

var _farm: Node = null
var _quantum_viz: Node = null
var _resource_panel: Node = null
var _connected_instrument = null
var _retry_accum: float = 0.0


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


func _on_action_performed(action: String, result: Dictionary) -> void:
	if not result.get("success", false):
		return
	match action:
		"pop":
			var emoji := str(result.get("resource", ""))
			var amount := int(result.get("amount", 0))
			if emoji == "" or amount <= 0:
				return
			var from_pos := _station_position(str(result.get("biome_name", "")), int(result.get("register_id", -1)))
			# Surprisal-scaled celebration: payout is already −kT·log p, so the
			# reward size IS the rarity. One soft mapping, no thresholds.
			var rel := tanh(float(result.get("credits", amount)) / 40.0)
			_spawn_burst(from_pos, rel)
			spawn_reward(emoji, amount, from_pos, rel)
		"measure":
			# Measure snap: a quick converging tick — "the answer locked in."
			var biome := str(result.get("biome_name", ""))
			if biome == "" and _quantum_viz != null and "active_biome" in _quantum_viz:
				biome = str(_quantum_viz.active_biome)
			var pos := _station_position(biome, int(result.get("register_id", -1)))
			_spawn_burst(pos, 0.0, Color(0.45, 0.95, 1.0, 0.9), true)
		"reap":
			_cascade_reap(result)
			_surge_flow()
		"fast_forward":
			_surge_flow()


func _surge_flow() -> void:
	# Fast-forward/reap visibly spins the metro flow dots for a beat.
	if _quantum_viz != null and is_instance_valid(_quantum_viz) \
			and _quantum_viz.has_method("surge_time_flow"):
		_quantum_viz.surge_time_flow()


func _station_position(biome_name: String, register_id: int) -> Vector2:
	var viz = _quantum_viz
	if viz == null or not (is_instance_valid(viz) and viz.has_method("get_register_screen_position")):
		# 3D field path: the live renderer is held by FarmView, not passed as quantum_viz.
		var fvs = get_tree().get_nodes_in_group("farm_view")
		if fvs.size() > 0 and fvs[0].has_method("get_field_renderer"):
			viz = fvs[0].get_field_renderer()
	if viz != null and is_instance_valid(viz) and viz.has_method("get_register_screen_position"):
		var p: Vector2 = viz.get_register_screen_position(biome_name, register_id)
		if p.x >= 0.0:
			return p
	return get_viewport_rect().size * 0.5


## Expanding ring at a station — pop celebration (accent gold, size grows with
## the payout's surprisal) or measure snap (cyan, converges inward instead).
func _spawn_burst(at_global: Vector2, rel: float, color: Color = ACCENT,
		converge: bool = false) -> void:
	var ring := RingBurst.new()
	ring.color = Color(color.r, color.g, color.b, 0.9)
	add_child(ring)
	ring.position = get_global_transform().affine_inverse() * at_global
	var r_from: float = 34.0 + 26.0 * rel
	var r_to: float = 6.0
	if not converge:
		r_from = 12.0
		r_to = 40.0 + 50.0 * rel
	ring.radius = r_from
	ring.width = 2.0 + 3.0 * rel
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "radius", r_to, 0.20 if converge else 0.32) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "alpha", 0.0, 0.20 if converge else 0.32)
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
	var color: Color = Color(1.0, 0.8, 0.3, 0.9)

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
	label.add_theme_font_size_override("font_size", 20 + int(14.0 * rel))
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
	flier.scale = Vector2(0.4, 0.4)
	flier.pivot_offset = Vector2(24, 16)

	var target_global: Vector2 = from_global + Vector2(0, -120)
	if _resource_panel != null and is_instance_valid(_resource_panel) \
			and _resource_panel.has_method("get_emoji_slot_position"):
		target_global = _resource_panel.get_emoji_slot_position(emoji)
	var target_local: Vector2 = (get_global_transform().affine_inverse() * target_global) - Vector2(24, 16)

	var tw := create_tween()
	tw.tween_property(flier, "scale", Vector2(1.15, 1.15), 0.15) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.25)
	tw.set_parallel(true)
	tw.tween_property(flier, "position", target_local, 0.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(flier, "scale", Vector2(0.6, 0.6), 0.5)
	tw.set_parallel(false)
	tw.tween_callback(_on_flier_landed.bind(flier, emoji))


func _on_flier_landed(flier: Control, emoji: String) -> void:
	if _resource_panel != null and is_instance_valid(_resource_panel) \
			and _resource_panel.has_method("bounce_emoji"):
		_resource_panel.bounce_emoji(emoji)
	if is_instance_valid(flier):
		flier.queue_free()
