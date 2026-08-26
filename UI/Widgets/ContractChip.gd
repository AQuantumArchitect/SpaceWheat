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
const ACCENT := UIStyleFactory.COLOR_ACCENT_GOLD

# The COMMITMENTS board's row letters (QuestBoard.ITEM_KEYS) — the chip labels
# its rows with the same letters so "the second quest" in this corner and
# "row H on the board" are one thing, not two orderings to reconcile.
const BOARD_KEYS := ["G", "H", "J", "K", "L", ";"]

const PredicateGloss = preload("res://Core/Quests/PredicateGloss.gd")

var _quest_manager: Node = null
var _overlay_manager: Node = null
var _rows_box: VBoxContainer


## overlay_manager is optional (old tests/mocks pass only the quest manager):
## with it, a READY row's tap opens the board on its own Commitments row —
## the glow used to invite a click that could only focus a biome.
func setup(quest_manager: Node, overlay_manager: Node = null) -> void:
	_quest_manager = quest_manager
	_overlay_manager = overlay_manager
	# Rows are tappable (tap → focus the contract's biome); the panel itself
	# stops mouse so taps don't leak through to the field behind it.
	mouse_filter = Control.MOUSE_FILTER_STOP

	# The shared trim recipe, not a hand-rolled near-miss of it (casing pass
	# 2026-08-25: this chip carried its own bg color, close to but not equal to
	# COLOR_TRIM_INK, and no border at all — the one top-corner region with no
	# bounding box).
	var style := UIStyleFactory.create_trim_style()
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
					# unbind(n) requires n >= 1 — a 0-arg signal connects the callable as-is.
					var argc := _signal_arg_count(sig)
					_quest_manager.connect(sig, callable.unbind(argc) if argc > 0 else callable)
		if _quest_manager.has_signal("quest_completed"):
			if not _quest_manager.quest_completed.is_connected(_on_quest_completed):
				_quest_manager.quest_completed.connect(_on_quest_completed)
		if _quest_manager.has_signal("quest_accepted"):
			if not _quest_manager.quest_accepted.is_connected(_on_quest_accepted):
				_quest_manager.quest_accepted.connect(_on_quest_accepted)
	_refresh()


func _on_quest_accepted(_quest_id) -> void:
	# Accept lands HERE: a quick pulse so the eye follows the contract to its
	# pinned home in the corner.
	pivot_offset = size / 2.0
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.10, 1.10), 0.10) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.22)


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

	# Same list, same order, as the COMMITMENTS board: commitment_quests()
	# filters out auto-advancing tutorial steps (contract purity), which was
	# the real cause of the old "oldest quest pinned here forever" problem —
	# the reverse() that papered over it made the chip's "quest two" a
	# DIFFERENT row than the board's row H. One list, one order, shared
	# letters. has_method fallback keeps test mocks working.
	var quests: Array = []
	if _quest_manager and _quest_manager.has_method("commitment_quests"):
		quests = _quest_manager.commitment_quests()
	elif _quest_manager and _quest_manager.has_method("get_active_quests"):
		quests = _quest_manager.get_active_quests()
	if quests.is_empty():
		visible = false
		return
	visible = true

	var shown := 0
	for i in range(quests.size()):
		if shown >= MAX_ROWS:
			break
		var quest = quests[i]
		if not (quest is Dictionary):
			continue
		var key_str: String = BOARD_KEYS[i] if i < BOARD_KEYS.size() else "·"
		_rows_box.add_child(_build_row(quest, key_str))
		shown += 1

	if quests.size() > MAX_ROWS:
		var more := Label.new()
		more.text = "+%d more — [C]" % (quests.size() - MAX_ROWS)
		more.add_theme_font_size_override("font_size", 12)
		more.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.8))
		_rows_box.add_child(more)


func _build_row(quest: Dictionary, key_str: String = "") -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)

	if key_str != "":
		var key_lbl := Label.new()
		key_lbl.text = "[%s]" % key_str
		key_lbl.add_theme_font_size_override("font_size", 12)
		key_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85, 0.9))
		head.add_child(key_lbl)

	var ready: bool = str(quest.get("status", "")) == "ready"
	var faction := str(quest.get("faction", ""))
	var resource := str(quest.get("resource", ""))
	var label := Label.new()
	if resource != "":
		var glyph := EmojiDisplay.new()
		glyph.font_size = 18
		glyph.emoji = resource
		glyph.custom_minimum_size = Vector2(22, 22)
		head.add_child(glyph)
		label.text = "×%d — %s" % [int(quest.get("quantity", 1)), faction] \
				if faction != "" else "×%d" % int(quest.get("quantity", 1))
	else:
		# Predicate/state quest: no deliverable to glyph — gloss the ask
		# instead of rendering a blank emoji and a meaningless "×1".
		var gloss := ""
		var preds = quest.get("state_predicates", [])
		if preds is Array and not preds.is_empty() and preds[0] is Dictionary:
			gloss = PredicateGloss.summary(preds[0], _quest_manager)
			if preds.size() > 1:
				gloss += " …"
		if gloss == "":
			gloss = str(quest.get("display_name", "commitment"))
		label.text = "%s — %s" % [gloss, faction] if faction != "" else gloss
	if ready:
		label.text += "  ✓ ready"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", ACCENT if ready else Color(0.92, 0.92, 0.92))
	head.add_child(label)
	row.add_child(head)

	# "Where do I go?" — the contract's biome, tappable to focus it. A READY
	# row's tap goes further: to its own row on the board's Commitments tab,
	# where the claim waits on a deliberate click (chip taps stay navigation-
	# only). Biome-less predicate quests used to be dead rows here; their
	# ready state is tappable now too.
	var biome := str(quest.get("biome", ""))
	if biome != "":
		var where := Label.new()
		where.text = "→ %s" % biome
		where.add_theme_font_size_override("font_size", 11)
		where.add_theme_color_override("font_color", Color(0.72, 0.80, 0.88, 0.85))
		row.add_child(where)
	if ready or biome != "":
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.tooltip_text = "Tap to claim on the board" if ready else "Tap to focus %s" % biome
		row.gui_input.connect(_on_row_gui_input.bind(biome, int(quest.get("id", -1)), ready))

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


func _on_row_gui_input(event: InputEvent, biome: String, qid: int = -1, ready: bool = false) -> void:
	# Tap a contract row → bring its biome forward (navigation only, no verb).
	# A READY row navigates further: to its own board row — the door disarms
	# the board's second-click confirm on the way in, so the claim there is
	# still a deliberate, separate click.
	if (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed):
		if ready and _overlay_manager != null \
				and _overlay_manager.has_method("open_board_on_commitments"):
			_overlay_manager.open_board_on_commitments(qid)
			accept_event()
			return
		if biome != "":
			var abm := get_node_or_null("/root/ActiveBiomeManager")
			if abm != null and abm.has_method("set_active_biome"):
				abm.set_active_biome(biome)
				accept_event()
