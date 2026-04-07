class_name BalanceWorkbenchOverlay
extends "res://UI/Core/OverlayBase.gd"

const BalanceService = preload("res://Core/GameMechanics/BalanceService.gd")
const InstrumentLocator = preload("res://Core/Instrumentation/InstrumentLocator.gd")

var _farm: Node = null
var _snapshot_service = null
var _instrument = null
var _advanced_mode: bool = false
var _profile_label: Label = null
var _action_label: Label = null
var _cost_label: Label = null
var _roi_label: Label = null
var _timescale_label: RichTextLabel = null
var _easy_apply_button: Button = null
var _easy_status_label: Label = null
var _quest_label: RichTextLabel = null

var _action_keys: Array[String] = []
var _selected_action_idx: int = 0
var _timescale_biomes: Array[String] = []
var _selected_timescale_biome_idx: int = 0
var _last_projection: Dictionary = {}
var _snapshot: Dictionary = {}


func _init() -> void:
	overlay_name = "balance_workbench"
	overlay_icon = "⚖️"
	overlay_tier = 11  # Z_TIER_INFO
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


func set_snapshot_service(service) -> void:
	_snapshot_service = service


func set_quantum_instrument(inst) -> void:
	_instrument = inst


func set_advanced_mode(enabled: bool) -> void:
	_advanced_mode = enabled
	_render()


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

	var timescale_title = Label.new()
	timescale_title.text = "Timescale Objective Projection"
	timescale_title.add_theme_font_size_override("font_size", 18)
	root.add_child(timescale_title)

	_timescale_label = RichTextLabel.new()
	_timescale_label.custom_minimum_size = Vector2(0, 160)
	_timescale_label.fit_content = false
	_timescale_label.scroll_active = true
	_timescale_label.bbcode_enabled = false
	_timescale_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timescale_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_timescale_label)

	var easy_row = HBoxContainer.new()
	easy_row.add_theme_constant_override("separation", 10)
	easy_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(easy_row)

	_easy_apply_button = Button.new()
	_easy_apply_button.text = "Easy: Auto Apply Suggested Timescale"
	_easy_apply_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_easy_apply_button.pressed.connect(_on_easy_apply_pressed)
	easy_row.add_child(_easy_apply_button)

	_easy_status_label = Label.new()
	_easy_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_easy_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	easy_row.add_child(_easy_status_label)

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
	hints.text = "Q/E action nav | R/F edit in advanced mode, otherwise biome/refresh | T/Y quest ratio in advanced mode"
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
	_refresh_timescale_projection()
	_render()


func _render() -> void:
	if not _profile_label:
		return

	var profile_id = str(_snapshot.get("profile_id", "default"))
	var profile_name = str(_snapshot.get("profile_display_name", profile_id))
	_profile_label.text = "Profile: %s (%s) | Advanced: %s" % [profile_id, profile_name, "ON" if _advanced_mode else "OFF (read-only tuning)"]

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

	if _advanced_mode:
		action_labels = {
			"Q": "Prev Action",
			"E": "Next Action",
			"R": "Cost +1",
			"F": "Cost -1"
		}
	else:
		action_labels = {
			"Q": "Prev Action",
			"E": "Next Action",
			"R": "Next Biome",
			"F": "Refresh"
		}

	_render_timescale_projection()
	_render_quest_tuning()
	if _easy_apply_button:
		_easy_apply_button.disabled = _timescale_biomes.is_empty() or not bool(_last_projection.get("ok", false))


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
	if not _advanced_mode:
		_cycle_timescale_biome(1)
		return
	_apply_delta_to_selected_action(1 if not Input.is_key_pressed(KEY_SHIFT) else 5)


func _on_action_f() -> void:
	if not _advanced_mode:
		_refresh_snapshot()
		return
	_apply_delta_to_selected_action(-1 if not Input.is_key_pressed(KEY_SHIFT) else -5)


func _on_unhandled_key(keycode: int, _event: InputEvent) -> bool:
	if not _advanced_mode:
		return false
	if not InputBindingRegistry.overlay_has_shortcut(overlay_name, keycode):
		return false
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


func _refresh_timescale_projection() -> void:
	_last_projection = {}
	_timescale_biomes.clear()
	if _instrument and _instrument.has_method("get_grid_snapshot"):
		var grid = _instrument.get_grid_snapshot()
		if bool(grid.get("ok", false)):
			var biomes = grid.get("biomes", [])
			if biomes is Array:
				for biome_name in biomes:
					var b = str(biome_name)
					if b != "":
						_timescale_biomes.append(b)
	elif _farm and "grid" in _farm and _farm.grid and _farm.grid.has_biomes():
		_timescale_biomes = _farm.grid.get_biome_names()
		_timescale_biomes.sort()

	if _timescale_biomes.is_empty():
		return
	_selected_timescale_biome_idx = clampi(_selected_timescale_biome_idx, 0, _timescale_biomes.size() - 1)
	var biome_name = _timescale_biomes[_selected_timescale_biome_idx]

	if _instrument and _instrument.has_method("recommend_timescale"):
		_last_projection = _instrument.recommend_timescale(biome_name, 8)
		if _last_projection.is_empty() and _instrument.has_method("get_timescale_projection"):
			_last_projection = _instrument.get_timescale_projection(biome_name, 8)
		return

	# Fallback when farm instrument is unavailable: show top global probabilities only.
	if _farm and "biome_evolution_batcher" in _farm and _farm.biome_evolution_batcher:
		var batcher = _farm.biome_evolution_batcher
		if batcher.has_method("get_global_icon_map"):
			var global_map = batcher.get_global_icon_map()
			var by_emoji = global_map.get("by_emoji", {})
			var total = max(1e-9, float(global_map.get("total", 1.0)))
			var rows: Array = []
			if by_emoji is Dictionary:
				for emoji in by_emoji.keys():
					var p = float(by_emoji[emoji]) / total
					rows.append({"emoji": str(emoji), "probability": p})
				rows.sort_custom(func(a, b): return float(a.get("probability", 0.0)) > float(b.get("probability", 0.0)))
			_last_projection = {"ok": true, "biome": biome_name, "emoji_rankings": rows.slice(0, min(8, rows.size()))}


func _cycle_timescale_biome(delta: int) -> void:
	if _timescale_biomes.is_empty():
		return
	_selected_timescale_biome_idx = posmod(_selected_timescale_biome_idx + delta, _timescale_biomes.size())
	_refresh_timescale_projection()
	_render_timescale_projection()


func _render_timescale_projection() -> void:
	if not _timescale_label:
		return
	if _timescale_biomes.is_empty():
		_timescale_label.text = "No biome data available."
		return
	var biome_name = _timescale_biomes[_selected_timescale_biome_idx]
	var rows = _last_projection.get("emoji_rankings", [])
	var lines: Array[String] = []
	lines.append("Biome: %s (%d/%d)" % [biome_name, _selected_timescale_biome_idx + 1, _timescale_biomes.size()])
	if bool(_last_projection.get("ok", false)):
		var stride = int(_last_projection.get("recommended_stride", -1))
		var dt = float(_last_projection.get("recommended_dt", -1.0))
		var wait_p = int(_last_projection.get("recommended_wait_phrames", -1))
		if stride >= 0 and dt > 0.0:
			lines.append("Rec: stride=%d dt=%.4f wait=%d phrames" % [stride, dt, wait_p])
		var top = str(_last_projection.get("top_emoji", ""))
		if top != "":
			lines.append("Top target: %s (p=%.3f)" % [top, float(_last_projection.get("top_probability", 0.0))])
	else:
		lines.append("Projection unavailable.")
	lines.append("")
	lines.append("Likely emoji choices (sorted by probability):")
	if rows is Array:
		var limit = min(8, rows.size())
		for i in range(limit):
			var row = rows[i]
			if not (row is Dictionary):
				continue
			lines.append("%d. %s p=%.3f score=%.3f floor=%.0f have=%.1f" % [
				i + 1,
				str(row.get("emoji", "?")),
				float(row.get("probability", 0.0)),
				float(row.get("objective_score", 0.0)),
				float(row.get("resource_floor", 0.0)),
				float(row.get("resource_have", 0.0))
			])
	_timescale_label.text = "\n".join(lines)


func _on_easy_apply_pressed() -> void:
	if _timescale_biomes.is_empty():
		_set_easy_status("No biome available.")
		return
	var biome_name = _timescale_biomes[_selected_timescale_biome_idx]

	if not _instrument:
		_set_easy_status("Quantum instrument unavailable.")
		_render()
		return

	var apply_result = _instrument.auto_apply_timescale(biome_name, 8)
	if bool(apply_result.get("ok", false)):
		var stride = int(apply_result.get("recommended_stride", 1))
		var dt = float(apply_result.get("recommended_dt", 0.02))
		_set_easy_status("Applied to %s: stride=%d dt=%.4f" % [biome_name, stride, dt])
		# Persist global timescale defaults through save state path (best-effort).
		var gsm = InstrumentLocator.resolve_game_state_manager(self)
		if gsm and "current_state" in gsm and gsm.current_state:
			gsm.current_state.observation_stride = stride
			gsm.current_state.max_evolution_dt = dt
	else:
		_set_easy_status("Apply failed on %s." % biome_name)
	_refresh_timescale_projection()
	_render()


func _set_easy_status(message: String) -> void:
	if _easy_status_label:
		_easy_status_label.text = message


func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return "(none)"
	var parts: Array[String] = []
	var keys = cost.keys()
	keys.sort()
	for emoji in keys:
		parts.append("%s%d" % [str(emoji), int(cost[emoji])])
	return " ".join(parts)
