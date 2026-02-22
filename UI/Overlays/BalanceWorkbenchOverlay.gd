class_name BalanceWorkbenchOverlay
extends OverlayBase

const BalanceService = preload("res://Core/GameMechanics/BalanceService.gd")

var _farm: Node = null
var _profile_label: Label = null
var _action_label: Label = null
var _cost_label: Label = null
var _roi_label: Label = null
var _quest_label: RichTextLabel = null

var _action_keys: Array[String] = []
var _selected_action_idx: int = 0
var _snapshot: Dictionary = {}


func _init() -> void:
	overlay_name = "balance_workbench"
	overlay_icon = "⚖️"
	panel_title = "Balance Workbench"
	panel_size_mode = PanelSizeMode.CUSTOM
	panel_size = Vector2(860, 620)
	show_dimmer = true
	navigation_mode = NavigationMode.NONE
	action_labels = {
		"Q": "Prev Action",
		"E": "Next Action",
		"R": "Cost +1",
		"F": "Cost -1"
	}


func set_farm(farm_ref: Node) -> void:
	_farm = farm_ref


func _build_content(container: Control) -> void:
	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(root)

	_profile_label = Label.new()
	root.add_child(_profile_label)

	_action_label = Label.new()
	_action_label.add_theme_font_size_override("font_size", 20)
	root.add_child(_action_label)

	_cost_label = Label.new()
	_cost_label.add_theme_font_size_override("font_size", 18)
	root.add_child(_cost_label)

	_roi_label = Label.new()
	_roi_label.add_theme_font_size_override("font_size", 16)
	root.add_child(_roi_label)

	var quest_title = Label.new()
	quest_title.text = "Quest Reward Tuning"
	quest_title.add_theme_font_size_override("font_size", 18)
	root.add_child(quest_title)

	_quest_label = RichTextLabel.new()
	_quest_label.custom_minimum_size = Vector2(0, 180)
	_quest_label.fit_content = false
	_quest_label.scroll_active = true
	_quest_label.bbcode_enabled = false
	_quest_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quest_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_quest_label)

	var hints = Label.new()
	hints.text = "Keys: [ and ] select resource in action | Shift+R/F = +/-5 | T/Y tune quest ratio"
	hints.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hints)

	_refresh_snapshot()


func _on_activated() -> void:
	_refresh_snapshot()


func _refresh_snapshot() -> void:
	_snapshot = BalanceService.get_snapshot(_farm)
	var action_costs = _snapshot.get("action_costs", {})
	var keys: Array[String] = []
	for key in action_costs.keys():
		keys.append(str(key))
	_action_keys = keys
	_action_keys.sort()
	if _selected_action_idx >= _action_keys.size():
		_selected_action_idx = 0
	_render()


func _render() -> void:
	if not _profile_label:
		return

	var profile_id = str(_snapshot.get("profile_id", "default"))
	var profile_name = str(_snapshot.get("profile_display_name", profile_id))
	_profile_label.text = "Profile: %s (%s)" % [profile_id, profile_name]

	if _action_keys.is_empty():
		_action_label.text = "Action: n/a"
		_cost_label.text = "Cost: n/a"
		_roi_label.text = "ROI: n/a"
	else:
		var action = _action_keys[_selected_action_idx]
		var action_costs: Dictionary = _snapshot.get("action_costs", {})
		var cost = action_costs.get(action, {})
		_action_label.text = "Action: %s (%d/%d)" % [action, _selected_action_idx + 1, _action_keys.size()]
		_cost_label.text = "Cost: %s" % _format_cost(cost)

		var roi_notes = _snapshot.get("roi_notes", {})
		var note = str(roi_notes.get(action, "No ROI note configured"))
		_roi_label.text = "ROI Hint: %s" % note

	_render_quest_tuning()


func _render_quest_tuning() -> void:
	if not _quest_label:
		return
	var quest = _snapshot.get("quest_rewards", {})
	var quest_notes = _snapshot.get("quest_notes", {})
	var lines: Array[String] = []
	for key in quest.keys():
		lines.append("%s: %s" % [key, str(quest[key])])
	lines.sort()
	if not lines.is_empty():
		lines.append("")
	for key in quest_notes.keys():
		lines.append("note[%s]: %s" % [key, str(quest_notes[key])])
	lines.sort()
	_quest_label.text = "\n".join(lines)


func _on_action_q() -> void:
	if _action_keys.is_empty():
		return
	_selected_action_idx = posmod(_selected_action_idx - 1, _action_keys.size())
	_render()


func _on_action_e() -> void:
	if _action_keys.is_empty():
		return
	_selected_action_idx = posmod(_selected_action_idx + 1, _action_keys.size())
	_render()


func _on_action_r() -> void:
	_apply_delta_to_selected_action(1 if not Input.is_key_pressed(KEY_SHIFT) else 5)


func _on_action_f() -> void:
	_apply_delta_to_selected_action(-1 if not Input.is_key_pressed(KEY_SHIFT) else -5)


func _on_unhandled_key(keycode: int, _event: InputEvent) -> bool:
	if keycode == KEY_T:
		_apply_quest_ratio_delta(0.05)
		return true
	if keycode == KEY_Y:
		_apply_quest_ratio_delta(-0.05)
		return true
	return false


func _apply_delta_to_selected_action(delta: int) -> void:
	if _action_keys.is_empty() or delta == 0:
		return
	var action = _action_keys[_selected_action_idx]
	var action_costs: Dictionary = _snapshot.get("action_costs", {})
	var current_cost: Dictionary = action_costs.get(action, {})
	if current_cost.is_empty():
		return
	var keys = current_cost.keys()
	keys.sort()
	var first_emoji = str(keys[0])
	var current_value = int(current_cost.get(first_emoji, 0))
	var next_value = max(0, current_value + delta)
	var patch = {
		"action_costs": {
			action: {
				first_emoji: next_value
			}
		}
	}
	BalanceService.apply_patch(_farm, patch, "ui.balance_workbench")
	_refresh_snapshot()


func _apply_quest_ratio_delta(delta: float) -> void:
	if delta == 0.0:
		return
	var quest = _snapshot.get("quest_rewards", {})
	var current = float(quest.get("resource_reward_base_ratio", 0.4))
	var next_value = clamp(current + delta, 0.05, 3.0)
	var patch = {
		"quest_rewards": {
			"resource_reward_base_ratio": next_value
		}
	}
	BalanceService.apply_patch(_farm, patch, "ui.balance_workbench")
	_refresh_snapshot()


func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return "(none)"
	var parts: Array[String] = []
	var keys = cost.keys()
	keys.sort()
	for emoji in keys:
		parts.append("%s%d" % [str(emoji), int(cost[emoji])])
	return " ".join(parts)
