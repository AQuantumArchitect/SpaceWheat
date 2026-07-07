class_name ToolSelectionRow
extends "res://UI/Widgets/SelectionButtonRow.gd"

## Bottom-row archetype hat selector. One button per archetype frame, in
## hat-row order (4=Spark .. 0=Druid). The keyboard shortcut is the matching
## hat key. See `docs/ARCHETYPE_FRAMES.md`.
##
## SelectionButtonRow's button IDs are integers, so we use the hat-row index
## (0..6) as the button id and translate to/from frame name via FRAME_ORDER.

const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const UIProgression = preload("res://UI/Core/UIProgression.gd")

## Hat-row left → right: Spark, Icon, Merchant, Captain, Ace, Operator, Druid.
const FRAME_ORDER: Array = [
	ToolConfig.FRAME_SPARK,
	ToolConfig.FRAME_ICON,
	ToolConfig.FRAME_MERCHANT,
	ToolConfig.FRAME_CAPTAIN,
	ToolConfig.FRAME_ACE,
	ToolConfig.FRAME_OPERATOR,
	ToolConfig.FRAME_DRUID,
]

const HAT_KEYS: Array = ["4", "5", "6", "7", "8", "9", "0"]

## Active archetype frame name. Empty string = Ace (no hat).
var current_frame: String = ToolConfig.FRAME_ACE

signal frame_selected(frame_name: String)


func _ready():
	# Z-index: ActionBarLayer(50) + 5 = 55 total, below quest(100)
	z_index = 5
	super._ready()
	_rebuild_buttons()
	select_frame(ToolConfig.get_current_frame())


## Frames actually rendered this rebuild (progressive disclosure). Button id i
## maps to _visible_frames[i]; hat KEYS for hidden frames still work.
var _visible_frames: Array = []


## Re-derive visibility from story progress and rebuild. Called at build time
## and again whenever a story flag fires (PlayerShell wiring).
func refresh_progression() -> void:
	_rebuild_buttons()
	select_frame(ToolConfig.get_current_frame())


func _rebuild_buttons() -> void:
	_visible_frames = []
	for frame_name in FRAME_ORDER:
		if UIProgression.is_hat_visible(frame_name):
			_visible_frames.append(frame_name)
	var button_specs: Array[Dictionary] = []
	for i in range(_visible_frames.size()):
		var frame_name: String = _visible_frames[i]
		var def: Dictionary = ToolConfig.get_frame(frame_name)
		var label_name := str(def.get("name", frame_name))
		var emoji := str(def.get("emoji", ""))
		var icon_path := str(def.get("icon", ""))
		var hat_key: String = HAT_KEYS[FRAME_ORDER.find(frame_name)]
		var desc: String = str(def.get("description", ""))
		# Every hat is always selectable — openness is a place, so the Lindblad
		# verbs grey per-plot on sealed ground (ActionValidator), never the hat.
		var label_text := ""
		if icon_path != "":
			label_text = "[%s] %s" % [hat_key, label_name]
		else:
			label_text = "[%s] %s %s" % [hat_key, emoji, label_name]
		var tip: String = "[%s] %s — %s" % [hat_key, label_name, desc] if desc != "" else ""
		button_specs.append({
			"id": i,
			"text": label_text,
			"icon_path": icon_path,
			"enabled": true,
			"tooltip": tip,
		})
	build_buttons(button_specs)
	if not button_selected.is_connected(_on_button_selected):
		button_selected.connect(_on_button_selected)


func _on_button_selected(idx: int) -> void:
	var frame_name: String = _frame_for_index(idx)
	if frame_name == "":
		return
	select_frame(frame_name)
	frame_selected.emit(frame_name)


## Select a frame by name. Empty string (FRAME_NULL) = no button highlighted.
func select_frame(frame_name: String) -> void:
	if frame_name == ToolConfig.FRAME_NULL:
		current_frame = frame_name
		set_selected(-1)
		return
	if not ToolConfig.ARCHETYPE_FRAMES.has(frame_name):
		return
	current_frame = frame_name
	var idx := _visible_frames.find(frame_name)
	# A not-yet-surfaced hat selected by key: no button to highlight — clear.
	set_selected(idx if idx >= 0 else -1)


func _frame_for_index(idx: int) -> String:
	if idx < 0 or idx >= _visible_frames.size():
		return ""
	return _visible_frames[idx]


## Apply a dim/bright mask to the hat buttons based on topology scores.
##
## `passing_hats` is a Dictionary[frame_id → score float] containing only
## hats whose score ≥ HAT_INCLUSION_THRESHOLD. Hats absent from the dict are
## dimmed. If the dict is empty (no topology data), all buttons are reset to
## full brightness (no gating signal available).
##
## Display-only — selecting a dimmed hat still works. No gating.
func set_hat_dim_mask(passing_hats: Dictionary) -> void:
	const DIM := Color(0.35, 0.35, 0.35, 0.8)
	for i in range(_visible_frames.size()):
		var frame_name: String = _visible_frames[i]
		if i >= buttons.size():
			continue
		var btn_data = buttons[i]
		if not (btn_data is Dictionary) or btn_data.get("disabled", false):
			continue
		if frame_name == current_frame:
			continue  # never dim the currently-active hat
		var bright: bool = passing_hats.is_empty() or passing_hats.has(frame_name)
		var tex = btn_data.get("texture", null)
		if tex != null:
			tex.modulate = normal_color if bright else DIM


func debug_layout() -> String:
	# Return detailed layout debug information for F3 display.
	var debug_text = ""
	debug_text += "ToolSelectionRow (archetype hat row):\n"
	debug_text += "  Position: (%.0f, %.0f)\n" % [position.x, position.y]
	debug_text += "  Actual size: %.0f × %.0f\n" % [size.x, size.y]
	debug_text += "  Custom min size: %s\n" % custom_minimum_size
	debug_text += "  Active frame: %s\n" % (current_frame if current_frame != "" else "Ace")
	debug_text += "  Buttons: %d total\n" % buttons.size()

	var button_widths = []
	for btn_data in buttons:
		button_widths.append("%.0f" % btn_data.container.size.x)
	debug_text += "  Button widths: [%s]\n" % ", ".join(button_widths)

	return debug_text
