extends Control

## MilkHunterHUD - Compact overlay showing milk hunter bridge status.
##
## Displays current action, turn count, resource summary, quest state,
## vocab progress, and throughput. Connects to MilkHunterBridge signals.

const PANEL_BG_COLOR: Color = Color(0.08, 0.10, 0.18, 0.92)
const PANEL_BORDER_COLOR: Color = Color(0.3, 0.7, 0.9, 0.7)
const PANEL_PADDING: int = 8
const UPDATE_INTERVAL: int = 30  # Refresh cached stats every 30 render frames
const UIStyleFactory = preload("res://UI/Core/UIStyleFactory.gd")

var _bridge: Node = null  # MilkHunterBridge
var _status: String = "idle"
var _turn_id: int = -1
var _last_action: String = ""
var _last_resources: Dictionary = {}
var _last_quests: Array = []
var _last_vocab_count: int = 0
var _frame_counter: int = 0

# UI elements
var panel: PanelContainer
var vbox: VBoxContainer
var status_label: Label
var action_label: Label
var resources_label: Label
var quest_label: Label
var vocab_label: Label
var throughput_label: Label


func _ready() -> void:
	_build_ui()
	set_process(true)


func connect_to_bridge(bridge: Node) -> void:
	_bridge = bridge
	_status = "active"
	bridge.action_executed.connect(_on_action_executed)
	bridge.bridge_idle.connect(_on_bridge_idle)
	bridge.bridge_stopped.connect(_on_bridge_stopped)
	_update_status_label()


func _process(_delta: float) -> void:
	_frame_counter += 1
	if _frame_counter % UPDATE_INTERVAL != 0:
		return
	_update_throughput()


func _on_action_executed(turn_id: int, action: String, result: Dictionary) -> void:
	_turn_id = turn_id
	_last_action = action
	_status = "active"

	# Cache action-specific results for display
	match action:
		"resource_snapshot":
			var res_data = result.get("resources", {})
			if res_data is Dictionary and res_data.has("resources"):
				_last_resources = res_data["resources"]
		"active_quests":
			_last_quests = result.get("quests", [])
		"known_vocab_pairs":
			var pairs = result.get("pairs", [])
			_last_vocab_count = pairs.size()
		"offer_quests":
			pass  # Offers are transient, don't cache

	_update_all_labels()


func _on_bridge_idle() -> void:
	_status = "idle"
	_update_status_label()


func _on_bridge_stopped() -> void:
	_status = "stopped"
	_update_all_labels()


func _update_all_labels() -> void:
	_update_status_label()
	_update_action_label()
	_update_resources_label()
	_update_quest_label()
	_update_vocab_label()
	_update_throughput()


func _update_status_label() -> void:
	var color_prefix = ""
	match _status:
		"active":
			color_prefix = ">>>"
		"idle":
			color_prefix = "..."
		"stopped":
			color_prefix = "---"
	status_label.text = "%s %s" % [color_prefix, _status.to_upper()]


func _update_action_label() -> void:
	if _turn_id < 0:
		action_label.text = "Waiting for first action..."
		return
	action_label.text = "Turn %d: %s" % [_turn_id, _last_action]


func _update_resources_label() -> void:
	if _last_resources.is_empty():
		resources_label.text = "Resources: --"
		return
	var parts: Array = []
	var keys = _last_resources.keys()
	keys.sort()
	for key in keys:
		var val = _last_resources[key]
		if val is float:
			parts.append("%s %.0f" % [key, val])
		else:
			parts.append("%s %s" % [key, str(val)])
	resources_label.text = " ".join(parts)


func _update_quest_label() -> void:
	if _last_quests.is_empty():
		quest_label.text = "Quests: none"
		return
	quest_label.text = "Quests: %d active" % _last_quests.size()


func _update_vocab_label() -> void:
	vocab_label.text = "Vocab: %d pairs" % _last_vocab_count


func _update_throughput() -> void:
	if not _bridge:
		throughput_label.text = ""
		return
	var aps = _bridge.get_actions_per_second()
	var total = _bridge.get_actions_executed()
	throughput_label.text = "%d actions | %.1f/s" % [total, aps]


func get_snapshot() -> Dictionary:
	"""Return structured snapshot of milk hunter HUD state."""
	return {
		"status": _status,
		"turn_id": _turn_id,
		"last_action": _last_action,
		"resources": _last_resources.duplicate(),
		"vocab_count": _last_vocab_count,
	}


func _build_ui() -> void:
	anchors_preset = Control.PRESET_TOP_LEFT
	offset_left = 16
	offset_top = 52
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(260, 120)

	var scaffold = UIStyleFactory.create_hud_scaffold(PANEL_BG_COLOR, PANEL_BORDER_COLOR, PANEL_PADDING, 3)
	panel = scaffold.panel
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox = scaffold.vbox

	status_label = _create_label("... IDLE", Color(0.3, 0.7, 0.9), true)
	action_label = _create_label("Waiting for first action...", Color(0.95, 0.95, 0.95))
	resources_label = _create_label("Resources: --", Color(0.8, 0.9, 1.0))
	quest_label = _create_label("Quests: none", Color(1.0, 0.8, 0.3))
	vocab_label = _create_label("Vocab: 0 pairs", Color(0.7, 1.0, 0.7))
	throughput_label = _create_label("", Color(0.6, 0.6, 0.7))

	vbox.add_child(status_label)
	vbox.add_child(_create_separator())
	vbox.add_child(action_label)
	vbox.add_child(resources_label)
	vbox.add_child(quest_label)
	vbox.add_child(vocab_label)
	vbox.add_child(_create_separator())
	vbox.add_child(throughput_label)

	add_child(panel)


func _create_label(text_value: String, color: Color, bold: bool = false) -> Label:
	return UIStyleFactory.create_hud_label(text_value, color, 13 if bold else 11)


func _create_separator() -> HSeparator:
	return UIStyleFactory.create_hud_separator()
