class_name EndingOverlay
extends Control

## The island_free ceremony — the campaign's political finale.
##
## When the Demos win their freedom the game used to do... nothing. This is
## the big ceremonial close the owner asked for: fade to dark, title, a
## montage of the act postcards the player earned along the way, the island's
## final physics, a credits roll, and the door line. Any input advances a
## stage; the last input returns to play — the door stays open, the game
## continues.
##
## Purely presentational (anti-gating: the flag fired before this spawned;
## nothing here touches mechanics). Sim is soft-paused for the duration and
## restored on close. Spawned by RuntimeMount's story_flag_fired listener,
## headed sessions only.

signal ceremony_finished

const STAGE_TITLE := 0
const STAGE_MONTAGE := 1
const STAGE_STATS := 2
const STAGE_CREDITS := 3
const STAGE_DOOR := 4

const POSTCARD_DIR := "user://postcards"
const MAX_MONTAGE_CARDS := 8
const MONTAGE_CARD_S := 2.4
const CREDITS_ROLL_S := 16.0

var _farm: Node = null
var _shell: Node = null
var _stage: int = -1
var _stage_token: int = 0  # invalidates queued auto-advances after manual input
var _we_paused: bool = false
var _postcards: Array = []  # ImageTexture, oldest → newest
var _content: Control = null

## The live cognifold field renderer (2D force graph OR 3D field), shown drifting
## behind the ceremony. Null in 2D-absent/headless setups → opaque backdrop fallback.
var _field: Node = null
var _field_prev_process_mode: int = -1


func begin(farm: Node, shell: Node) -> void:
	_farm = farm
	_shell = shell
	# The overlay layer doesn't impose a rect on children — size to the
	# viewport explicitly (anchors alone left this 0×0: invisible backdrop,
	# stage text clipped at the origin).
	position = Vector2.ZERO
	size = get_viewport_rect().size
	get_viewport().size_changed.connect(func():
		if is_instance_valid(self):
			size = get_viewport_rect().size
	)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 110  # above toasts (100) — the ceremony owns the screen
	process_mode = Node.PROCESS_MODE_ALWAYS

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.025, 0.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Let the live cognifold field (2D force graph or 3D field) drift behind the
	# ceremony instead of a near-opaque wall. If no renderer is reachable (headless
	# / no viz), keep the original opaque backdrop — no crash, no regression.
	var backdrop_target_a := 0.93
	_field = _resolve_field_renderer()
	if _field != null:
		backdrop_target_a = 0.6  # field clearly shows through; text keeps its heavy outline
		# Soft-pause freezes the sim, but the field's idle drift should keep breathing.
		_field_prev_process_mode = _field.process_mode
		_field.process_mode = Node.PROCESS_MODE_ALWAYS

	var fade := create_tween()
	fade.tween_property(backdrop, "color:a", backdrop_target_a, 1.2)

	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_pause_sim(true)
	_load_postcards()

	var music = get_node_or_null("/root/MusicManager")
	if music != null and music.has_method("celebrate_swell"):
		music.celebrate_swell()

	_enter_stage(STAGE_TITLE)


func _input(event: InputEvent) -> void:
	var pressed: bool = \
		(event is InputEventKey and event.pressed and not event.echo) or \
		(event is InputEventMouseButton and event.pressed) or \
		(event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if _stage >= STAGE_DOOR:
		_close()
	else:
		_enter_stage(_stage + 1)


func _enter_stage(stage: int) -> void:
	_stage = stage
	_stage_token += 1
	for child in _content.get_children():
		child.queue_free()
	_pause_sim(true)  # re-assert; idempotent (guards against stray unpause peeks)
	match stage:
		STAGE_TITLE:
			_build_title_stage()
			_auto_advance(4.0)
		STAGE_MONTAGE:
			if _postcards.is_empty():
				_enter_stage(STAGE_STATS)
				return
			_build_montage_stage()
			_auto_advance(MONTAGE_CARD_S * _postcards.size() + 1.0)
		STAGE_STATS:
			_build_stats_stage()
			_auto_advance(7.0)
		STAGE_CREDITS:
			_build_credits_stage()
			_auto_advance(CREDITS_ROLL_S + 1.5)
		STAGE_DOOR:
			_build_door_stage()
			# No auto-advance — the player closes the door line themselves.


func _auto_advance(delay_s: float) -> void:
	var token := _stage_token
	get_tree().create_timer(delay_s).timeout.connect(func():
		if is_instance_valid(self) and token == _stage_token:
			if _stage >= STAGE_DOOR:
				return
			_enter_stage(_stage + 1)
	)


func _resolve_field_renderer() -> Node:
	# Read-only access to FarmView's live renderer via its group (never edit FarmView).
	var fvs = get_tree().get_nodes_in_group("farm_view")
	if fvs.size() > 0 and fvs[0].has_method("get_field_renderer"):
		var f = fvs[0].get_field_renderer()
		if f != null and is_instance_valid(f):
			return f
	return null


func _restore_field() -> void:
	# Hand the field's process_mode back exactly as we found it.
	if _field != null and is_instance_valid(_field) and _field_prev_process_mode != -1:
		_field.process_mode = _field_prev_process_mode
	_field_prev_process_mode = -1


func _close() -> void:
	_pause_sim(false)
	_restore_field()
	ceremony_finished.emit()
	if _shell != null and _shell.has_method("show_hint"):
		_shell.show_hint("🚪 The door stays open.", 4)
	queue_free()


func _exit_tree() -> void:
	# Failsafe: if we're freed without a clean _close (e.g. restart), still hand
	# the field's process_mode back.
	_restore_field()


func _pause_sim(value: bool) -> void:
	if _shell == null or not ("paused" in _shell) or not _shell.has_method("toggle_paused"):
		return
	if value and not _shell.paused:
		_shell.toggle_paused()
		_we_paused = true
	elif not value and _we_paused and _shell.paused:
		_shell.toggle_paused()
		_we_paused = false


# =============================================================================
# STAGES
# =============================================================================

func _build_title_stage() -> void:
	var box := _centered_vbox()
	box.add_child(_big_label("The Demos are free.", 44, Color(0.98, 0.92, 0.62)))
	var sub := _big_label("Your island never collapsed.", 20, Color(0.85, 0.9, 0.82, 0.0))
	box.add_child(sub)
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(sub, "modulate:a", 1.0, 1.2)
	sub.modulate.a = 0.0


func _build_montage_stage() -> void:
	var caption := _big_label("the acts you witnessed", 16, Color(0.8, 0.85, 0.78, 0.8))
	_content.add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	caption.offset_top = 40.0
	caption.offset_bottom = 70.0

	var frame := TextureRect.new()
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(frame)
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_top = 80.0
	frame.offset_bottom = -60.0
	frame.offset_left = 80.0
	frame.offset_right = -80.0

	var tw := create_tween()
	for tex in _postcards:
		tw.tween_callback(func():
			frame.texture = tex
			frame.modulate.a = 0.0
		)
		tw.tween_property(frame, "modulate:a", 1.0, 0.5)
		tw.tween_interval(MONTAGE_CARD_S - 1.0)
		tw.tween_property(frame, "modulate:a", 0.0, 0.5)


func _build_stats_stage() -> void:
	var box := _centered_vbox()
	box.add_child(_big_label("the island, measured", 18, Color(0.8, 0.85, 0.78, 0.85)))
	box.add_child(_spacer(14))
	for line in _stats_lines():
		box.add_child(_big_label(line, 22, Color(0.92, 0.95, 0.88)))
	box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.9)


func _stats_lines() -> Array:
	var lines: Array = []
	if _farm != null:
		if "story_log" in _farm and _farm.story_log is Array:
			lines.append("🚩 %d story beats witnessed" % _farm.story_log.size())
		if "known_icons" in _farm and _farm.known_icons is Array:
			lines.append("🧬 %d icons in your signature" % _farm.known_icons.size())
	var qm = InstrumentLocator.resolve_quest_manager(self, _farm)
	if qm != null and "completed_quests" in qm and qm.completed_quests is Array:
		lines.append("📜 %d contracts honored" % qm.completed_quests.size())
	var gap := _active_biome_gap()
	if gap >= 0.0:
		lines.append("🕊 spectral gap %.3f — plural, and standing" % gap)
	if lines.is_empty():
		lines.append("an island, still breathing")
	return lines


func _active_biome_gap() -> float:
	if _farm == null or not ("grid" in _farm) or _farm.grid == null:
		return -1.0
	var abm = get_node_or_null("/root/ActiveBiomeManager")
	var biome_name: String = str(abm.active_biome) if (abm != null and "active_biome" in abm) else ""
	if biome_name == "" or not _farm.grid.has_method("get_biome"):
		return -1.0
	var biome = _farm.grid.get_biome(biome_name)
	if biome == null:
		return -1.0
	var qc = biome.get("quantum_computer")
	if qc != null and qc.has_method("get_hamiltonian_spectral_gap"):
		return float(qc.get_hamiltonian_spectral_gap())
	return -1.0


func _build_credits_stage() -> void:
	# A real roll: the block scrolls bottom → top over CREDITS_ROLL_S.
	var roll := VBoxContainer.new()
	roll.alignment = BoxContainer.ALIGNMENT_CENTER
	roll.add_theme_constant_override("separation", 18)
	roll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for entry in _credit_entries():
		roll.add_child(_big_label(entry[0], entry[1], Color(0.92, 0.94, 0.86)))
	_content.add_child(roll)
	# Unanchored, full-width, sized to content — position.y is free to tween.
	var roll_h := roll.get_combined_minimum_size().y
	roll.size = Vector2(size.x, roll_h)
	roll.position = Vector2(0, size.y)
	var tw := create_tween()
	tw.tween_property(roll, "position:y", -roll_h - 40.0, CREDITS_ROLL_S)


func _credit_entries() -> Array:
	# [text, font_size] — owner reviews this text before launch (W1 owner ask).
	return [
		["🌾 SPACEWHEAT 🌾", 36],
		["a game about farming a density matrix", 16],
		["", 12],
		["made by", 14],
		["Luke Spooner", 26],
		["", 12],
		["built with", 14],
		["Claude · Anthropic", 22],
		["", 12],
		["physics", 14],
		["one honest Hamiltonian, evolved without shortcuts", 18],
		["Godot Engine · native C++ quantum core", 16],
		["", 12],
		["and The Demos", 14],
		["— who were never yours, and are now their own —", 18],
		["", 20],
		["the campaign closes. the world does not.", 16],
	]


func _build_door_stage() -> void:
	var box := _centered_vbox()
	box.add_child(_big_label("🚪", 52, Color(0.98, 0.92, 0.62)))
	box.add_child(_spacer(10))
	box.add_child(_big_label("The door stays open.", 28, Color(0.95, 0.9, 0.7)))
	box.add_child(_spacer(18))
	box.add_child(_big_label("tap anywhere to return to your island", 14, Color(0.75, 0.8, 0.72, 0.85)))
	box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 1.0)


# =============================================================================
# HELPERS
# =============================================================================

func _load_postcards() -> void:
	_postcards.clear()
	var dir := DirAccess.open(POSTCARD_DIR)
	if dir == null:
		return
	var names: Array = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".png"):
			names.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	names.sort()  # timestamped filenames → chronological
	if names.size() > MAX_MONTAGE_CARDS:
		names = names.slice(names.size() - MAX_MONTAGE_CARDS)
	for n in names:
		var img := Image.load_from_file(ProjectSettings.globalize_path("%s/%s" % [POSTCARD_DIR, n]))
		if img != null:
			_postcards.append(ImageTexture.create_from_image(img))


func _centered_vbox() -> VBoxContainer:
	# Full-rect box with centered alignment: labels fill the width and the
	# column centers vertically — no dependence on anchor-point growth.
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return box


func _big_label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _spacer(h: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s
