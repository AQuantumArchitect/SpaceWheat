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
	if action != "pop":
		return
	if not result.get("success", false):
		return
	var emoji := str(result.get("resource", ""))
	var amount := int(result.get("amount", 0))
	if emoji == "" or amount <= 0:
		return
	var from_pos := _station_position(str(result.get("biome_name", "")), int(result.get("register_id", -1)))
	spawn_reward(emoji, amount, from_pos)


func _station_position(biome_name: String, register_id: int) -> Vector2:
	if _quantum_viz != null and is_instance_valid(_quantum_viz) \
			and _quantum_viz.has_method("get_register_screen_position"):
		var p: Vector2 = _quantum_viz.get_register_screen_position(biome_name, register_id)
		if p.x >= 0.0:
			return p
	return get_viewport_rect().size * 0.5


func spawn_reward(emoji: String, amount: int, from_global: Vector2) -> void:
	var flier := HBoxContainer.new()
	flier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flier.z_index = 5

	var label := Label.new()
	label.text = "+%d" % amount
	label.add_theme_font_size_override("font_size", 26)
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
