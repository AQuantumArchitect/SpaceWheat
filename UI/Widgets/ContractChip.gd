class_name ContractChip
extends PanelContainer

## ContractChip — accepted contracts pinned in the corner of the play view.
##
## "Complete contracts" is a core loop verb, but accepted quests used to live
## three tabs deep in the C board. This chip shows up to two active contracts
## (resource × quantity + progress bar) at all times, glows when one is ready
## to claim, and plays a tick flourish on completion. Visible ONLY while
## quests are active — progressive disclosure for free.
##
## Purely cosmetic: C still opens the full board; nothing is gated here.

const MAX_ROWS := 2
const ACCENT := Color(1.0, 0.8, 0.3)

var _quest_manager: Node = null
var _rows_box: VBoxContainer


func setup(quest_manager: Node) -> void:
	_quest_manager = quest_manager
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.11, 0.82)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 6)
	add_child(_rows_box)

	if _quest_manager:
		for sig in ["active_quests_changed", "quest_accepted", "quest_ready_to_claim"]:
			if _quest_manager.has_signal(sig):
				var callable := Callable(self, "_refresh_deferred")
				if not _quest_manager.is_connected(sig, callable):
					_quest_manager.connect(sig, callable.unbind(_signal_arg_count(sig)))
		if _quest_manager.has_signal("quest_completed"):
			if not _quest_manager.quest_completed.is_connected(_on_quest_completed):
				_quest_manager.quest_completed.connect(_on_quest_completed)
	_refresh()


func _signal_arg_count(sig: String) -> int:
	match sig:
		"quest_accepted", "quest_ready_to_claim":
			return 1
		_:
			return 0


func _refresh_deferred() -> void:
	call_deferred("_refresh")


func _on_quest_completed(_quest_id: int, _rewards: Dictionary) -> void:
	# Tick flourish: flash the chip, then rebuild.
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1.4, 1.3, 0.9), 0.1)
	tw.tween_property(self, "modulate", Color.WHITE, 0.3)
	tw.tween_callback(_refresh)


func _refresh() -> void:
	for child in _rows_box.get_children():
		child.queue_free()

	var quests: Array = []
	if _quest_manager and _quest_manager.has_method("get_active_quests"):
		quests = _quest_manager.get_active_quests()
	if quests.is_empty():
		visible = false
		return
	visible = true

	var shown := 0
	for quest in quests:
		if shown >= MAX_ROWS:
			break
		if not (quest is Dictionary):
			continue
		_rows_box.add_child(_build_row(quest))
		shown += 1

	if quests.size() > MAX_ROWS:
		var more := Label.new()
		more.text = "+%d more — [C]" % (quests.size() - MAX_ROWS)
		more.add_theme_font_size_override("font_size", 12)
		more.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.8))
		_rows_box.add_child(more)


func _build_row(quest: Dictionary) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)

	var glyph := EmojiDisplay.new()
	glyph.font_size = 18
	glyph.emoji = str(quest.get("resource", ""))
	glyph.custom_minimum_size = Vector2(22, 22)
	head.add_child(glyph)

	var ready: bool = str(quest.get("status", "")) == "ready"
	var label := Label.new()
	var faction := str(quest.get("faction", ""))
	label.text = "×%d — %s" % [int(quest.get("quantity", 1)), faction] \
			if faction != "" else "×%d" % int(quest.get("quantity", 1))
	if ready:
		label.text += "  ✓ ready"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", ACCENT if ready else Color(0.92, 0.92, 0.92))
	head.add_child(label)
	row.add_child(head)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(150, 5)
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0 if ready else clampf(float(quest.get("progress", 0.0)), 0.0, 1.0)
	var fg := StyleBoxFlat.new()
	fg.bg_color = ACCENT if ready else Color(0.55, 0.75, 0.55)
	fg.set_corner_radius_all(2)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.12)
	bg.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fg)
	bar.add_theme_stylebox_override("background", bg)
	row.add_child(bar)
	return row
