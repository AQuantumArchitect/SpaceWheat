class_name ReapButton
extends Control

## Season button — the top-bar face of Reap.
##
## Reap is not a QERF verb. This chip is the pointer door; the keyboard
## twin is VerbGrammar.REAP_CHORD (Ctrl+Shift+Space), written under the
## label. Authority lives on QuantumInstrumentInput.request_reap.

const VerbGrammar = preload("res://UI/Core/VerbGrammar.gd")
const UIProgression = preload("res://UI/Core/UIProgression.gd")
const CostFormat = preload("res://Core/UI/CostFormat.gd")

signal reap_requested()

var _chip: Panel = null
var _title: Label = null
var _chord: Label = null
var _cost: Label = null
var _unlocked: bool = true
var _pointer_enabled: bool = true
var layout_manager = null


func _ready() -> void:
	z_index = 6
	mouse_filter = MOUSE_FILTER_IGNORE
	_build()


func set_layout_manager(mgr) -> void:
	layout_manager = mgr


func set_pointer_enabled(on: bool) -> void:
	# w370: BoardTab_U shares pixels with this center TimeBar chip. GUI
	# picking is tree order. Mute the chip while a real overlay is up so
	# Commitments U is Commitments, not Reap-pause.
	_pointer_enabled = on
	if _chip != null:
		_chip.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE


func get_button_pulse_target(_id: String = "") -> Control:
	return _title if _title != null and is_instance_valid(_title) else _chip


func sync_unlocked(unlocked: bool, farm = null) -> void:
	_unlocked = unlocked
	if _title == null:
		return
	if unlocked:
		_title.text = VerbGrammar.REAP_LABEL
		_chip.modulate = Color(1, 1, 1, 1)
		_chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		_title.text = "🔒 %s" % VerbGrammar.REAP_LABEL
		_chip.modulate = Color(0.55, 0.55, 0.55, 1)
		_chip.mouse_default_cursor_shape = Control.CURSOR_ARROW
	_refresh_cost(farm)


func _refresh_cost(farm) -> void:
	if _cost == null:
		return
	if farm == null or not ("economy" in farm) or farm.economy == null:
		_cost.text = ""
		return
	var cost: Dictionary = VerbGrammar.reap_cost(farm)
	if cost.is_empty():
		_cost.text = ""
		return
	_cost.text = CostFormat.format_cost(cost, {"sorted": true, "pair": "neg_tight"})


func _build() -> void:
	_chip = Panel.new()
	_chip.name = "ReapChip"
	_chip.mouse_filter = MOUSE_FILTER_STOP if _pointer_enabled else MOUSE_FILTER_IGNORE
	_chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var style := StyleBoxFlat.new()
	style.bg_color = UIStyleFactory.COLOR_CHIP_BG
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = UIStyleFactory.COLOR_ACCENT_GOLD
	_chip.add_theme_stylebox_override("panel", style)
	_chip.set_anchors_preset(Control.PRESET_CENTER)
	_chip.offset_left = -92
	_chip.offset_right = 92
	_chip.offset_top = -18
	_chip.offset_bottom = 18
	add_child(_chip)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 10
	col.offset_right = -10
	col.offset_top = 1
	col.offset_bottom = -1
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_chip.add_child(col)

	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)

	_title = Label.new()
	_title.text = VerbGrammar.REAP_LABEL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 15)
	_title.add_theme_color_override("font_color", UIStyleFactory.COLOR_ACCENT_GOLD)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_title)

	_cost = Label.new()
	_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost.add_theme_font_size_override("font_size", 13)
	_cost.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	_cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_cost)

	_chord = Label.new()
	_chord.text = VerbGrammar.REAP_CHORD
	_chord.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chord.add_theme_font_size_override("font_size", 10)
	_chord.add_theme_color_override("font_color", UIStyleFactory.COLOR_TEXT_MUTED)
	_chord.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_chord)

	_chip.gui_input.connect(_on_chip_gui_input)


func _on_chip_gui_input(event: InputEvent) -> void:
	if not _pointer_enabled:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or mb.pressed:
		return
	if not _unlocked:
		UIProgression.redirect_locked(VerbGrammar.REAP_LABEL)
		get_viewport().set_input_as_handled()
		return
	reap_requested.emit()
	get_viewport().set_input_as_handled()
