class_name MultiSelectToggle
extends "res://UI/Widgets/SelectionButtonRow.gd"

## Multi-select mode chip — sits on the RIGHT of the TimeBar.
##
## One checkbox SET, two doors: hold Shift and tap a plot (or Shift+G H),
## or tap this chip then tap plots. The chip is the face of that set — it
## names ⇧, shows the live count, and golds when Shift is held, sticky
## MULTI is on, or plots are already marked. Authority still lives on
## QuantumInstrumentInput; this row only displays and asks for a toggle.

const CHIP_ID := 0

signal mode_toggle_requested()

var _on: bool = false
var _count: int = 0
var _shift_held: bool = false


func _ready() -> void:
	z_index = 6
	compact = true
	compact_chip_size = Vector2(140, 38)
	alignment = BoxContainer.ALIGNMENT_END
	set_process(true)
	super._ready()
	if not button_selected.is_connected(_on_button_selected):
		button_selected.connect(_on_button_selected)
	_rebuild_buttons()
	call_deferred("_bind_qii")


func _process(_dt: float) -> void:
	# Holding Shift is the keyboard door into the same set this chip locks.
	# Gold the chip — do NOT rebuild the row (w209: Shift+H died while
	# _rebuild_buttons tore down TimeBar chips mid-toggle_check).
	var held := Input.is_key_pressed(KEY_SHIFT)
	if held == _shift_held:
		return
	_shift_held = held
	if _on or _count > 0 or _shift_held:
		set_selected(CHIP_ID)
	else:
		set_selected(-1)


func _draws_own_casing() -> bool:
	return false


func _bind_qii() -> void:
	if not is_inside_tree():
		return
	var matches := get_tree().get_nodes_in_group("quantum_instrument_input")
	if matches.is_empty():
		return
	var qii = matches[0]
	if qii.has_signal("multi_select_mode_changed") \
			and not qii.multi_select_mode_changed.is_connected(sync_from):
		qii.multi_select_mode_changed.connect(sync_from)
	if qii.has_signal("plot_checked") and not qii.plot_checked.is_connected(_on_plot_checked):
		qii.plot_checked.connect(_on_plot_checked)
	if "multi_select_mode" in qii:
		var n := 0
		if qii.has_method("get_checked_plots"):
			n = qii.get_checked_plots().size()
		sync_from(bool(qii.multi_select_mode), n)


func sync_from(on: bool, count: int = -1) -> void:
	if count < 0:
		count = _count
	if on == _on and count == _count and not buttons.is_empty():
		return
	_on = on
	_count = count
	_rebuild_buttons()


func _on_plot_checked(_pos: Vector2i, _checked: bool) -> void:
	var matches := get_tree().get_nodes_in_group("quantum_instrument_input")
	if matches.is_empty():
		return
	var qii = matches[0]
	var n := 0
	if qii.has_method("get_checked_plots"):
		n = qii.get_checked_plots().size()
	sync_from(bool(qii.multi_select_mode) if "multi_select_mode" in qii else _on, n)


func _rebuild_buttons() -> void:
	# ⇧ is the keyboard twin; MULTI is the tap lock. Same set either way.
	var live := _on or _count > 0 or _shift_held
	var label := "⇧ MULTI"
	var tip := "Same set: hold Shift and tap a plot (or Shift+G H), or tap this chip then tap plots."
	if _on:
		label = "MULTI ×%d" % _count if _count > 0 else "MULTI ⇧"
		tip = "MULTI is on — same set Shift marks. Tap plots to add or drop. Tap here to go back."
	elif _count > 0:
		label = "⇧ ×%d" % _count
		tip = "Shift-marked set (×%d). Hold Shift and tap to add, or tap this chip to keep MULTI on without holding Shift." % _count
	elif _shift_held:
		label = "⇧ MULTI"
		tip = "Shift is held — tap a plot to mark it. Same set as tapping MULTI."
	var specs: Array[Dictionary] = [
		{
			"id": CHIP_ID,
			"text": label,
			"icon_path": "",
			"enabled": true,
			"tooltip": tip,
		},
	]
	build_buttons(specs)
	for i in range(buttons.size()):
		var container: Control = buttons[i].get("container")
		if container:
			container.name = "MultiSelectChip_%d" % i
	# Gold when the set is live: sticky MULTI, a marked plot, or Shift down.
	if live:
		set_selected(CHIP_ID)
	else:
		set_selected(-1)


func _on_button_selected(_id: int) -> void:
	mode_toggle_requested.emit()
