class_name MenuSelectionRow
extends "res://UI/Widgets/SelectionButtonRow.gd"

## MenuSelectionRow — Top bar that surfaces every surface-ring menu as a button,
## using the same SelectionButtonRow chrome as the other action bar rows.
## One button per entry in MenuRegistry.TOP_LEVEL_MENUS; clicking toggles
## the corresponding overlay. Keyless entries (e.g. FarmView) render first.


## Button id → menu entry. Lets us look up the overlay name on selection.
var _entry_by_id: Dictionary = {}

var overlay_manager: Node = null


func _ready() -> void:
	compact = true  # emoji-only chips hugging the right corner (Apple-minimal)
	alignment = BoxContainer.ALIGNMENT_END
	super._ready()
	_rebuild_buttons()

	if not button_selected.is_connected(_on_button_selected):
		button_selected.connect(_on_button_selected)


func set_overlay_manager(mgr: Node) -> void:
	overlay_manager = mgr
	if overlay_manager and overlay_manager.has_signal("overlay_changed"):
		overlay_manager.overlay_changed.connect(_on_overlay_changed)


func _on_overlay_changed(overlay_name: String, is_open: bool) -> void:
	for btn_id in _entry_by_id:
		if str(_entry_by_id[btn_id].get("overlay_name", "")) == overlay_name:
			set_selected(btn_id if is_open else -1)
			return
	set_selected(-1)


const UIProgression = preload("res://UI/Core/UIProgression.gd")


## Re-derive menu visibility from story progress and rebuild the row.
func refresh_progression() -> void:
	_rebuild_buttons()


func _rebuild_buttons() -> void:
	_entry_by_id.clear()
	var specs: Array[Dictionary] = []
	var idx := 0

	# Emoji-only chips; the name + key live in the tooltip (Apple-minimal).
	# Keyless entries first (e.g. FarmView), then strict ZXCVBNM order.
	for entry in MenuRegistry.TOP_LEVEL_MENUS:
		if str(entry.get("key_label", "")) != "":
			continue
		if not UIProgression.is_menu_visible(str(entry.get("id", ""))):
			continue
		var emoji := str(entry.get("button_emoji", ""))
		var display := str(entry.get("display_name", ""))
		specs.append({"id": idx, "text": emoji if emoji != "" else display,
				"enabled": true, "tooltip": display})
		_entry_by_id[idx] = entry
		idx += 1

	var key_order: Array = ["Z", "X", "C", "V", "B", "N", "M"]
	var by_key: Dictionary = {}
	for entry in MenuRegistry.TOP_LEVEL_MENUS:
		by_key[str(entry.get("key_label", ""))] = entry
	for key in key_order:
		if not by_key.has(key):
			continue
		var entry: Dictionary = by_key[key]
		if not UIProgression.is_menu_visible(str(entry.get("id", ""))):
			continue
		var emoji := str(entry.get("button_emoji", ""))
		var display := str(entry.get("display_name", ""))
		specs.append({"id": idx, "text": emoji if emoji != "" else key,
				"enabled": true, "tooltip": "%s [%s]" % [display, key]})
		_entry_by_id[idx] = entry
		idx += 1

	build_buttons(specs)


func _on_button_selected(button_id: int) -> void:
	if not overlay_manager or not _entry_by_id.has(button_id):
		return
	var entry: Dictionary = _entry_by_id[button_id]
	# "play" group: close all registered overlays → FarmView becomes top.
	if str(entry.get("menu_group", "")) == "play":
		if overlay_manager.has_method("close_all_overlays"):
			overlay_manager.close_all_overlays()
		return  # _on_overlay_changed fires for each closed overlay → clears selection
	var overlay_name := str(entry.get("overlay_name", ""))
	if overlay_name == "":
		return
	if overlay_manager.has_method("toggle_overlay"):
		overlay_manager.toggle_overlay(overlay_name)
	# Selection state is set reactively by _on_overlay_changed.
