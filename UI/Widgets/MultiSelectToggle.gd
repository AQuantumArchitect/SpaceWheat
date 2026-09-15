class_name MultiSelectToggle
extends "res://UI/Widgets/SelectionButtonRow.gd"

## Multi-select mode chip — sits on the RIGHT of the TimeBar.
##
## 3D orbs had no mouse path into the checkbox set except Shift-tap, which a
## pointer player never discovers. This chip is the door: it SAYS whether
## multi-select is on, and tapping it flips the mode. While on, a tap on an
## orb adds/drops it instead of firing Explore/Strike/Gather.
##
## Authority: the bit lives on QuantumInstrumentInput. This row only displays
## it and asks for a toggle, so keyboard Shift-tap and the chip cannot drift.

const CHIP_ID := 0

signal mode_toggle_requested()

var _on: bool = false
var _count: int = 0


func _ready() -> void:
	z_index = 6
	compact = true
	compact_chip_size = Vector2(118, 38)
	alignment = BoxContainer.ALIGNMENT_END
	super._ready()
	if not button_selected.is_connected(_on_button_selected):
		button_selected.connect(_on_button_selected)
	_rebuild_buttons()
	call_deferred("_bind_qii")


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
	var label := "one"
	var tip := "Tap to pick several plots at once. Then weave, strike, or gather them together."
	if _on:
		label = "MULTI ×%d" % _count if _count > 0 else "MULTI"
		tip = "MULTI-SELECT is on. Tap plots to add or drop them. Tap here to go back to one."
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
	# Persistent mode wears the gold underline + warm lift, like a selected hat.
	if _on:
		set_selected(CHIP_ID)
	else:
		set_selected(-1)


func _on_button_selected(_id: int) -> void:
	mode_toggle_requested.emit()
