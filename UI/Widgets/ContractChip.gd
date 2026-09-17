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
var _ladders: Dictionary = {}  # quest id -> ClickLadder


## overlay_manager is optional (old tests/mocks pass only the quest manager):
## with it, clicks climb ClickLadder as a tracker + link — the board row,
## then scoot to the contract's biome. The how lives on C; this chip does
## not reprint it. A missing overlay_manager skips HOME and scoots on the
## first tap when a biome is named.
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

	# ClickLadder: every row is tappable. First tap opens the board on this
	# row; second scoots to the biome. Tracker only — no how-line reprint.
	var biome := str(quest.get("biome", ""))
	var qid: int = int(quest.get("id", -1))
	if biome != "":
		var where := Label.new()
		where.text = "→ %s" % biome
		where.add_theme_font_size_override("font_size", 11)
		where.add_theme_color_override("font_color", Color(0.72, 0.80, 0.88, 0.85))
		row.add_child(where)
	var plant := _row_is_plant(quest)
	var ladder: ClickLadder = _ladder_for(qid, plant)
	# Wave 23: board does not plant. [C] opens the board was dual gold
	# against the Forest banner, and lost-lamb looped C on PLANT ×1.
	var cue := "" if plant else ladder.prompt()
	if cue != "":
		var cue_lbl := Label.new()
		cue_lbl.text = cue
		cue_lbl.add_theme_font_size_override("font_size", 10)
		cue_lbl.add_theme_color_override("font_color", Color(0.70, 0.82, 0.92, 0.9))
		row.add_child(cue_lbl)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if plant:
		row.tooltip_text = ""
	else:
		row.tooltip_text = cue if cue != "" else ClickLadder.tap_home("the board")
	row.gui_input.connect(_on_row_gui_input.bind(biome, qid, ready))

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


func _row_is_plant(quest: Dictionary) -> bool:
	for pred in quest.get("state_predicates", []):
		if not (pred is Dictionary):
			continue
		if str(pred.get("type", "")) != "gate_sequence_contains":
			continue
		var g := str(pred.get("gate", "")).to_lower()
		if g == "inject_icon" or g == "plant":
			return true
	return false


func _ladder_for(qid: int, plant: bool = false) -> ClickLadder:
	if not _ladders.has(qid):
		var ladder := ClickLadder.new()
		ladder.home_name = "the board"
		ladder.home_key = "C"
		ladder.has_detail = false
		# Board does not plant. Mill/standing still climb to C.
		ladder.has_home = (not plant) and _overlay_manager != null \
				and _overlay_manager.has_method("open_board_on_commitments")
		ladder.has_scoot = not plant
		_ladders[qid] = ladder
	return _ladders[qid]


func _on_row_gui_input(event: InputEvent, biome: String, qid: int = -1, ready: bool = false) -> void:
	if not ((event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed)):
		return
	accept_event()
	var ladder := _ladder_for(qid)
	var action := ladder.next_action()
	ladder.commit(action)
	match action:
		"home":
			if _overlay_manager != null \
					and _overlay_manager.has_method("open_board_on_commitments"):
				_overlay_manager.open_board_on_commitments(qid)
			_refresh()
		"scoot":
			if biome != "":
				var abm := get_node_or_null("/root/ActiveBiomeManager")
				if abm != null and abm.has_method("set_active_biome"):
					abm.set_active_biome(biome)
			elif _overlay_manager != null and _overlay_manager.has_method("scoot_toward"):
				_overlay_manager.scoot_toward()
			ladder.reset()
			_refresh()
		_:
			if ready and _overlay_manager != null \
					and _overlay_manager.has_method("open_board_on_commitments"):
				_overlay_manager.open_board_on_commitments(qid)
			elif biome != "":
				var abm2 := get_node_or_null("/root/ActiveBiomeManager")
				if abm2 != null and abm2.has_method("set_active_biome"):
					abm2.set_active_biome(biome)
