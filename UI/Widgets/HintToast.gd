class_name HintToast
extends PanelContainer

## HintToast — small corner pop-up for ephemeral player-facing dialogue.
## A Socialite "Tip" press summons one; it fades in, lingers a few seconds,
## then fades out and frees itself. Multiple toasts stack vertically.

const FADE_IN_SEC := 0.18
const HOLD_SEC := 4.5
const FADE_OUT_SEC := 0.6

const COLOR_PANEL := Color(0.08, 0.10, 0.16, 0.92)
const COLOR_BORDER := Color(0.55, 0.85, 1.0, 0.85)
const COLOR_TEXT := Color(0.92, 0.95, 1.0, 1.0)

var _label: RichTextLabel = null
var _tween: Tween = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(280, 0)
	modulate = Color(1, 1, 1, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.add_theme_color_override("default_color", COLOR_TEXT)
	_label.add_theme_font_size_override("normal_font_size", 13)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func show_text(bbcode: String) -> void:
	if _label:
		_label.text = bbcode
	_run_lifecycle()


func _run_lifecycle() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_SEC)
	_tween.tween_interval(HOLD_SEC)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_SEC)
	_tween.tween_callback(queue_free)
