extends Control

## Time-flow chip (top-left): ⏸ while E-pause holds the world, ▶ while time
## runs. TAPPABLE — mouse/touch players get a pause control (E/F are
## keyboard-only side-effect peeks). The old always-on FPS/PhHz debug readout
## now shows only in debug builds — players get one quiet glyph, not a
## profiler strip.


var _flow_label: Label
var _fps_label: Label
var _dt_label: Label
var _shell: Node = null
var _paused: bool = false


func _ready() -> void:
	_build_ui()
	_resolve_shell()
	resized.connect(queue_redraw)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND  # tap toggles pause
	if RuntimeEnv.debug_readout_enabled():
		var timer := Timer.new()
		timer.wait_time = 0.5
		timer.autostart = true
		timer.timeout.connect(_update_fps)
		add_child(timer)


func _resolve_shell() -> void:
	var n: Node = get_parent()
	while n != null:
		if n.has_signal("paused_changed"):
			_shell = n
			n.paused_changed.connect(_on_paused_changed)
			return
		n = n.get_parent()


func _on_paused_changed(is_paused: bool) -> void:
	_paused = is_paused
	if _flow_label:
		_flow_label.text = "⏸" if is_paused else "▶"
		_flow_label.add_theme_color_override("font_color",
			Color(UIStyleFactory.COLOR_ACCENT_GOLD, 0.95) if is_paused else Color(0.75, 0.82, 0.88, 0.7))


func _draw() -> void:
	# Trim backing (dressing pass): this floats over the resource strip's right
	# end and is a real tappable control — the quiet chip backing makes it read
	# as one, composed with the framed strip instead of loose over it.
	if size.x > 0.0 and size.y > 0.0:
		UIStyleFactory.draw_trim(self, Rect2(Vector2.ZERO, size))


func _gui_input(event: InputEvent) -> void:
	# Tap toggles pause — the mouse's E/F.
	if (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed):
		if _shell != null and _shell.has_method("toggle_paused"):
			_shell.toggle_paused()
			accept_event()


func _update_fps() -> void:
	if not _fps_label:
		return
	var fps := Engine.get_frames_per_second()
	var farm := InstrumentLocator.resolve_active_farm(self)
	var phz := UIStyleFactory.get_physics_fps_from_farm(farm)
	var sr := UIStyleFactory.get_slice_rate_from_farm(farm)
	var slices: float = sr.slices
	var biomes: int = sr.biomes

	if slices > 0.0:
		_fps_label.text = "FPS %d | PhHz %.1f | Evol %.0f/s [%dB]" % [fps, phz, slices, biomes]
	elif phz > 0.0:
		_fps_label.text = "FPS %d | PhHz %.1f" % [fps, phz]
	else:
		_fps_label.text = "FPS %d" % fps

	# Per-biome substep dt
	var dt_map := UIStyleFactory.get_step_dt_per_biome(farm)
	if dt_map.is_empty():
		_dt_label.text = ""
		_dt_label.visible = false
	else:
		var parts: Array[String] = []
		for biome_name in dt_map:
			var dt_ms: float = float(dt_map[biome_name])
			parts.append("%s %.1fms" % [biome_name, dt_ms])
		_dt_label.text = "dt: " + " | ".join(parts)
		_dt_label.visible = true


func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP  # the chip is tappable
	tooltip_text = "Time flow — tap (or E/F) to pause/resume"
	custom_minimum_size = Vector2(44, 30)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	add_child(row)

	_flow_label = Label.new()
	_flow_label.text = "▶"
	_flow_label.add_theme_font_size_override("font_size", 15)
	_flow_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.88, 0.7))
	_flow_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_flow_label)

	if RuntimeEnv.debug_readout_enabled():
		var vbox := VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(vbox)
		_fps_label = UIStyleFactory.create_hud_label("FPS --", UIStyleFactory.COLOR_TEXT_SUBTITLE, 11)
		vbox.add_child(_fps_label)
		_dt_label = UIStyleFactory.create_hud_label("", UIStyleFactory.COLOR_TEXT_SUBTITLE, 10)
		_dt_label.visible = false
		vbox.add_child(_dt_label)
