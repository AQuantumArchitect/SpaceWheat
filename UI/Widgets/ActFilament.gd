class_name ActFilament
extends Control

## ActFilament — the game's honest XP bar, ambient in the corner.
##
## One 3px gold filament showing the LIVE soft-gate score of the nearest
## unfired story flag (the highest-scoring one — the beat about to fire).
## QuestManager already evaluates these continuously; this just projects the
## number the Arc tab shows, so progress toward the next story beat is
## glanceable without opening a menu. Tap opens X (playthrough → Arc).
##
## Purely cosmetic (anti-gating law) — reads scores, never writes.

const ACCENT := Color(1.0, 0.8, 0.3)
const POLL_S := 0.5

var _quest_manager: Node = null
var _farm: Node = null
var _overlay_manager: Node = null
var _accum: float = 0.0
var _score: float = 0.0
var _threshold: float = 0.85
var _flag_name: String = ""
var _act: int = 0
var _display_fill: float = 0.0


func setup(quest_manager: Node, farm: Node, overlay_manager: Node) -> void:
	_quest_manager = quest_manager
	_farm = farm
	_overlay_manager = overlay_manager
	custom_minimum_size = Vector2(190, 14)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh()


func _process(delta: float) -> void:
	_accum += delta
	if _accum >= POLL_S:
		_accum = 0.0
		_refresh()
	# Ease the drawn fill toward the live score — quiet, continuous motion.
	var target: float = clampf(_score / maxf(_threshold, 0.01), 0.0, 1.0)
	if absf(target - _display_fill) > 0.001:
		_display_fill = lerpf(_display_fill, target, 1.0 - exp(-4.0 * delta))
		queue_redraw()


func _refresh() -> void:
	if _quest_manager == null or not is_instance_valid(_quest_manager) \
			or not _quest_manager.has_method("get_all_story_flags"):
		visible = false
		return
	var fired := {}
	if _farm != null and is_instance_valid(_farm) and "story_flags_fired" in _farm:
		fired = _farm.story_flags_fired
	var best_score := -1.0
	var best_flag: Dictionary = {}
	for flag in _quest_manager.get_all_story_flags():
		if not (flag is Dictionary):
			continue
		var fid := str(flag.get("id", ""))
		if fid == "" or fired.has(fid):
			continue
		var s: float = _quest_manager.evaluate_flag_score(flag)
		if s > best_score:
			best_score = s
			best_flag = flag
	if best_flag.is_empty():
		visible = false  # campaign complete — the filament retires
		return
	visible = true
	_score = best_score
	_threshold = float(_quest_manager.FLAG_FIRE_THRESHOLD) \
			if "FLAG_FIRE_THRESHOLD" in _quest_manager else 0.85
	_flag_name = str(best_flag.get("display_name", best_flag.get("id", "")))
	_act = int(best_flag.get("act", 0))
	tooltip_text = "Act %d — %s  (%d%%)\nTap for the Arc" \
			% [_act, _flag_name, int(_display_fill * 100.0)]


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed):
		if _overlay_manager != null and _overlay_manager.has_method("toggle_overlay"):
			_overlay_manager.toggle_overlay("controls")
			accept_event()


func _draw() -> void:
	var w := size.x
	var y := size.y * 0.5
	# Track
	draw_line(Vector2(0, y), Vector2(w, y), Color(1, 1, 1, 0.10), 3.0, true)
	# Fill
	if _display_fill > 0.005:
		draw_line(Vector2(0, y), Vector2(w * _display_fill, y),
				Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.85), 3.0, true)
		# Tip dot — a quiet spark at the head of progress.
		draw_circle(Vector2(w * _display_fill, y), 2.5,
				Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.95))
