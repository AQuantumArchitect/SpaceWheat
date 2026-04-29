class_name ToolSelectionRow
extends "res://UI/Widgets/SelectionButtonRow.gd"

## Bottom-row archetype hat selector. One button per archetype frame, in
## hat-row order (4=Spark .. 0=Druid). The keyboard shortcut is the matching
## hat key. See `docs/ARCHETYPE_FRAMES.md`.
##
## SelectionButtonRow's button IDs are integers, so we use the hat-row index
## (0..6) as the button id and translate to/from frame name via FRAME_ORDER.

const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")

## Hat-row left → right: Spark, Icon, Socialite, Captain, Scientist, Operator, Druid.
const FRAME_ORDER: Array = [
	ToolConfig.FRAME_SPARK,
	ToolConfig.FRAME_ICON,
	ToolConfig.FRAME_SOCIALITE,
	ToolConfig.FRAME_CAPTAIN,
	ToolConfig.FRAME_SCIENTIST,
	ToolConfig.FRAME_OPERATOR,
	ToolConfig.FRAME_DRUID,
]

const HAT_KEYS: Array = ["4", "5", "6", "7", "8", "9", "0"]

## Active archetype frame name. Empty string = Ace (no hat).
var current_frame: String = ToolConfig.FRAME_SCIENTIST

# Legacy alias signal kept so any older int-listener stays wired.
signal tool_selected(tool_num: int)
# New canonical signal — fired alongside the legacy one.
signal frame_selected(frame_name: String)


func _ready():
	# Z-index: ActionBarLayer(50) + 5 = 55 total, below quest(100)
	z_index = 5
	super._ready()
	_rebuild_buttons()
	select_frame(ToolConfig.get_current_frame())


func _rebuild_buttons() -> void:
	var button_specs: Array[Dictionary] = []
	for i in range(FRAME_ORDER.size()):
		var frame_name: String = FRAME_ORDER[i]
		var def: Dictionary = ToolConfig.get_frame(frame_name)
		var label_name := str(def.get("name", frame_name))
		var emoji := str(def.get("emoji", ""))
		var icon_path := str(def.get("icon", ""))
		var hat_key: String = HAT_KEYS[i]
		var label_text := ""
		if icon_path != "":
			label_text = "[%s] %s" % [hat_key, label_name]
		else:
			label_text = "[%s] %s %s" % [hat_key, emoji, label_name]
		button_specs.append({
			"id": i,
			"text": label_text,
			"icon_path": icon_path,
			"enabled": true,
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


## Select a frame by name. Empty string = Ace (no button highlighted).
func select_frame(frame_name: String) -> void:
	if frame_name == ToolConfig.FRAME_ACE:
		current_frame = frame_name
		set_selected(-1)
		return
	if not ToolConfig.ARCHETYPE_FRAMES.has(frame_name):
		return
	current_frame = frame_name
	var idx := FRAME_ORDER.find(frame_name)
	if idx >= 0:
		set_selected(idx)


func select_tool(_tool_num: int) -> void:
	pass  # Retired — call select_frame(String) directly.


func set_tool_enabled(frame_or_tool, enabled: bool) -> void:
	var frame_name: String = frame_or_tool if frame_or_tool is String else ""
	if frame_name == "":
		return
	var idx := FRAME_ORDER.find(frame_name)
	if idx >= 0:
		set_button_enabled(idx, enabled)


func _frame_for_index(idx: int) -> String:
	if idx < 0 or idx >= FRAME_ORDER.size():
		return ""
	return FRAME_ORDER[idx]


func debug_layout() -> String:
	"""Return detailed layout debug information for F3 display."""
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
