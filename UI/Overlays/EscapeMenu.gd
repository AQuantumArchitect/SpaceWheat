class_name EscapeMenu
extends "res://UI/Core/Surface.gd"

## Z — System Surface (Z key + ESC).
##
## Keyboard grammar matches the rest of the game:
##   TYUIO  = tabs (Now / Save / New / Settings / Dev), same row as biome select
##   GHJKL; = items within the active tab, same row as plot slots
##   Q/E/R  = verbs on the current item (rendered as chips inside the panel
##            so the off-screen action bar is never load-bearing)
##   Q ←   = less / retreat / screw-out — leaving goes left (quit, load, −value)
##   R →   = more / advance / screw-in  — entering goes right (resume, save, +value)
##   E ↓   = inspect / open detail on focused item (also pauses sim globally)
##   F ↑   = flatten: collapses whatever E opened. In quit-confirm: QF = quit
##            without saving (two deliberate keys, safer than a single confirm).
##            F is never "back" and never navigation — those belong to ESC / [ ].
##   [ / ] = cycle tabs (surface frame cycle)
##   , / . = cycle top-level menus
##   ESC   = close
##
## frame_ids = [run, save_load, new_game, accessibility, dev] — one per tab.

signal resume_pressed()

enum Tab { RUN, KEEP, NEW, DEV }

enum PendingAction {
	NONE,
	QUIT,
	RESTART,
	DEV_RESTART,
}

# Tab row — TYUIOP slots. We bind T/Y/U/O; I and P are honestly empty
# under the under-fill policy in KEYBOARD_GRAMMAR.md (Verbs reference
# moved to X/Guide; LEVELS retired into ZBalance).
const TAB_ROW := [
	{"key": "T", "tab": Tab.RUN,   "name": "Now",  "frame": "run"},
	{"key": "Y", "tab": Tab.KEEP,  "name": "Save", "frame": "save_load"},
	{"key": "U", "tab": Tab.NEW,   "name": "New",  "frame": "new_game"},
	{"key": "O", "tab": Tab.DEV,   "name": "Dev",  "frame": "dev"},
]

const TAB_BY_KEYCODE := {
	KEY_T: Tab.RUN,
	KEY_Y: Tab.KEEP,
	KEY_U: Tab.NEW,
	KEY_O: Tab.DEV,
}

# Dev actions — navigate with GHJ/W/S, execute with R.
const DEV_ACTIONS := [
	{"id": "full_reset",           "label": "full reset",           "desc": "wipe evolution state and start fresh"},
	{"id": "print_biome_registry", "label": "print biome registry", "desc": "dump all loaded biomes to console"},
	{"id": "validate_biomes",      "label": "validate biomes",      "desc": "check data integrity of exportable set"},
	{"id": "print_batcher",        "label": "print batcher metrics","desc": "snapshot batcher state to console"},
]

# GHJKL; — the homerow "slot" row, left-to-right for readability.
# (HOMEROW_KEYS is indexed right-to-left, ;=0; we deliberately diverge in X
# so slot 1 is G, slot 2 is H, etc. — the menu reads left-to-right.)
const ITEM_KEYS := ["G", "H", "J", "K", "L", ";"]
const ITEM_BY_KEYCODE := {
	KEY_G: 0,
	KEY_H: 1,
	KEY_J: 2,
	KEY_K: 3,
	KEY_L: 4,
	KEY_SEMICOLON: 5,
}

const NUM_KEEP_SLOTS := 3

# Ordered list of playable scenarios shown in the New tab.
const DEFAULT_RUN_SCENARIO_ID := "demos_normal"

const SCENARIO_LIST := [
	{"id": "demos_normal",  "label": "The Demos",      "desc": "guided tutorial demo"},
	{"id": "new_game_easy", "label": "Easy Farm",      "desc": "open starter scenario"},
]
const FRAME_RUN := "run"
const FRAME_SAVE_LOAD := "save_load"
const FRAME_NEW_GAME := "new_game"
const FRAME_DEV := "dev"

const TAB_TO_FRAME := {
	Tab.RUN: FRAME_RUN,
	Tab.KEEP: FRAME_SAVE_LOAD,
	Tab.NEW: FRAME_NEW_GAME,
	Tab.DEV: FRAME_DEV,
}
const FRAME_TO_TAB := {
	FRAME_RUN: Tab.RUN,
	FRAME_SAVE_LOAD: Tab.KEEP,
	FRAME_NEW_GAME: Tab.NEW,
	FRAME_DEV: Tab.DEV,
}

# Palette

var _current_tab: int = Tab.RUN
var _pending_action: int = PendingAction.NONE

# Tab-local selection indices.
var _keep_slot: int = 0
var _keep_peeking: bool = false  # E toggles expanded save-slot inspector
var _run_peeking: bool = false   # E toggles expanded run-stats inspector
var _new_item: int = 0           # selected scenario index in New tab
var _new_peeking: bool = false   # E toggles scenario detail panel
var _dev_action_idx: int = 0

# UI refs.
var _status_line: Label = null
var _tab_row_box: HBoxContainer = null
var _tab_labels: Dictionary = {}  # tab_key(String) → Label
var _body_box: VBoxContainer = null
var _verb_palette: PanelContainer = null
var _verb_chip_box: HBoxContainer = null
var _verb_chip_cells: Dictionary = {}  # "Q"/"E"/"R"/"F" → {key: Label, label: Label, cell: VBoxContainer}
var _close_hint: Label = null
var _confirm_group: VBoxContainer = null
var _confirm_title_label: Label = null
var _confirm_message: Label = null

func _init() -> void:
	name = "EscapeMenu"
	overlay_name = "escape_menu"
	overlay_tier = 18
	panel_title = "PAUSED"
	panel_title_size = 22
	panel_size_mode = PanelSizeMode.MEDIUM
	panel_border_color = Color(0.5, 0.5, 0.3, 0.8)
	navigation_mode = NavigationMode.NONE
	use_scroll_container = false
	content_spacing = 8
	surface_id = "Z"
	frame_ids = [FRAME_RUN, FRAME_SAVE_LOAD, FRAME_NEW_GAME, FRAME_DEV]
	frame_id = TAB_TO_FRAME.get(_current_tab, FRAME_RUN)

# =============================================================================
# BUILD
# =============================================================================

func _build_content(container: Control) -> void:
	_status_line = Label.new()
	_status_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_line.add_theme_font_size_override("font_size", 12)
	_status_line.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	container.add_child(_status_line)

	_build_tab_row(container)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.4, 0.4, 0.3, 0.45))
	container.add_child(sep)

	_body_box = VBoxContainer.new()
	_body_box.add_theme_constant_override("separation", 4)
	_body_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_body_box)

	var sep2 := HSeparator.new()
	sep2.add_theme_color_override("color", Color(0.4, 0.4, 0.3, 0.3))
	container.add_child(sep2)

	_build_verb_chips(container)
	_build_close_hint(container)
	_build_confirm_group(container)
	_render_all()

func _build_tab_row(container: Control) -> void:
	_tab_row_box = HBoxContainer.new()
	_tab_row_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_tab_row_box.add_theme_constant_override("separation", 18)
	container.add_child(_tab_row_box)
	_tab_labels.clear()
	for entry in TAB_ROW:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 15)
		_tab_row_box.add_child(lbl)
		_tab_labels[str(entry.get("key", ""))] = lbl

func _build_verb_chips(container: Control) -> void:
	_verb_palette = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.85)
	sb.border_color = Color(0.5, 0.55, 0.65, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_verb_palette.add_theme_stylebox_override("panel", sb)
	container.add_child(_verb_palette)

	_verb_chip_box = HBoxContainer.new()
	_verb_chip_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_verb_chip_box.add_theme_constant_override("separation", 24)
	_verb_palette.add_child(_verb_chip_box)

	_verb_chip_cells.clear()
	for key in ["Q", "E", "R", "F"]:
		var cell := VBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_theme_constant_override("separation", 2)
		cell.custom_minimum_size = Vector2(90, 0)
		_verb_chip_box.add_child(cell)

		var key_lbl := Label.new()
		key_lbl.text = "[%s]" % key
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.add_theme_font_size_override("font_size", 16)
		key_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_KEY_CHIP)
		cell.add_child(key_lbl)

		var label_lbl := Label.new()
		label_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label_lbl.add_theme_font_size_override("font_size", 11)
		cell.add_child(label_lbl)

		_verb_chip_cells[key] = {"key": key_lbl, "label": label_lbl, "cell": cell}

func _build_close_hint(container: Control) -> void:
	_close_hint = Label.new()
	_close_hint.text = "ESC close   ·   TYUI tabs   ·   GHJKL; items   ·   [ ] cycle frames"
	_close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_close_hint.add_theme_font_size_override("font_size", 11)
	_close_hint.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	container.add_child(_close_hint)

func _build_confirm_group(container: Control) -> void:
	_confirm_group = VBoxContainer.new()
	_confirm_group.add_theme_constant_override("separation", 10)
	_confirm_group.visible = false
	container.add_child(_confirm_group)
	_confirm_title_label = Label.new()
	_confirm_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_title_label.add_theme_font_size_override("font_size", 16)
	_confirm_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_confirm_group.add_child(_confirm_title_label)
	_confirm_message = Label.new()
	_confirm_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_message.add_theme_font_size_override("font_size", 13)
	_confirm_message.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6))
	_confirm_group.add_child(_confirm_message)

# =============================================================================
# RENDER — everything rebuilds from current state
# =============================================================================

func _render_all() -> void:
	_refresh_status_line()
	_refresh_tab_row()
	_refresh_body()
	_refresh_verb_chips()

func _refresh_status_line() -> void:
	if not _status_line:
		return
	var gsm = (Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	var seed_text := "—"
	var time_text := "—"
	if gsm and gsm.get("current_state") != null:
		var st = gsm.current_state
		if "seed" in st:
			seed_text = str(st.seed)
		if "game_time" in st:
			time_text = _format_playtime(float(st.game_time))
	_status_line.text = "PAUSED  ·  seed %s  ·  %s" % [seed_text, time_text]

func _refresh_tab_row() -> void:
	if _tab_labels.is_empty():
		return
	for entry in TAB_ROW:
		var key_str := str(entry.get("key", ""))
		var tab_enum = int(entry.get("tab", Tab.RUN))
		var name_str := str(entry.get("name", ""))
		var lbl: Label = _tab_labels.get(key_str, null)
		if lbl == null:
			continue
		if tab_enum == _current_tab:
			lbl.text = "[%s] %s" % [key_str, name_str.to_upper()]
			lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_TAB_ACTIVE)
		else:
			lbl.text = "[%s] %s" % [key_str, name_str]
			lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_TAB_IDLE)

func _refresh_body() -> void:
	if not _body_box:
		return
	for child in _body_box.get_children():
		child.queue_free()
	if _pending_action != PendingAction.NONE:
		return
	match _current_tab:
		Tab.RUN:    _build_run_body()
		Tab.KEEP:   _build_keep_body()
		Tab.NEW:    _build_new_body()
		Tab.DEV:    _build_dev_body()

func _refresh_verb_chips() -> void:
	if _verb_chip_cells.is_empty():
		return
	var labels := _current_verb_labels()
	for key in ["Q", "E", "R", "F"]:
		var cell = _verb_chip_cells.get(key, null)
		if cell == null:
			continue
		var label_lbl: Label = cell.get("label")
		var key_lbl: Label = cell.get("key")
		var txt := str(labels.get(key, ""))
		if txt == "":
			label_lbl.text = "—"
			label_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_ITEM_EMPTY)
			key_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_ITEM_EMPTY)
		else:
			label_lbl.text = txt
			label_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_VERB_ACTIVE)
			key_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_KEY_CHIP)
	push_action_label_strings(labels)

func _current_verb_labels() -> Dictionary:
	if _pending_action != PendingAction.NONE:
		return _confirm_verb_labels()
	match _current_tab:
		Tab.RUN:
			var run_label := "inspect ▾" if not _run_peeking else "—"
			var loaded_game := _has_loaded_game()
			# F: when peek is open, F flattens it. Otherwise F = continue
			# without saving (force-equivalent of R's "save & resume").
			var run_f := "flatten" if _run_peeking else ("continue" if loaded_game else "play")
			return {"Q": "quit", "E": run_label, "R": "save & resume" if loaded_game else "", "F": run_f}
		Tab.KEEP:
			var peek_label := "inspect ▾" if not _keep_peeking else "—"
			return {"Q": "load slot", "E": peek_label, "R": "save slot", "F": "flatten" if _keep_peeking else ""}
		Tab.NEW:
			var new_peek_label := "inspect ▾" if not _new_peeking else "—"
			return {"Q": "start scenario", "E": new_peek_label, "R": "", "F": "flatten" if _new_peeking else ""}
		Tab.DEV:
			return {"Q": "", "E": "refresh", "R": "run action", "F": ""}
	return {}

# =============================================================================
# BODY BUILDERS
# =============================================================================

func _build_run_body() -> void:
	var gsm = (Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	var last_touched_slot := _get_last_touched_slot(gsm)
	var last_touched_info := _get_last_touched_info(gsm, last_touched_slot)

	var farm = InstrumentLocator.resolve_active_farm(self)
	var biome_count := "—"
	if farm and "grid" in farm and farm.grid and farm.grid.has_method("get_all_biomes"):
		biome_count = "%d" % farm.grid.get_all_biomes().size()

	var active_q := "—"
	var done_q := "—"
	var qm = InstrumentLocator.resolve_quest_manager(self, farm)
	if qm:
		if "active_quests" in qm and qm.active_quests is Dictionary:
			active_q = "%d" % qm.active_quests.size()
		if "completed_quests" in qm and qm.completed_quests is Array:
			done_q = "%d" % qm.completed_quests.size()

	_body_box.add_child(_make_section_header("run state"))
	if last_touched_info.is_empty():
		_body_box.add_child(_make_kv_row("default run", "The Demos"))
		_body_box.add_child(_make_kv_row("scenario", DEFAULT_RUN_SCENARIO_ID))
	else:
		var slot_label := "slot %d" % (int(last_touched_slot) + 1)
		_body_box.add_child(_make_kv_row("last touched", slot_label))
		_body_box.add_child(_make_kv_row("save", str(last_touched_info.get("summary", last_touched_info.get("display_name", "saved")))))
		_body_box.add_child(_make_kv_row("save file", str(last_touched_info.get("save_file", "—")).get_file()))
		_body_box.add_child(_make_kv_row("scenario", str(last_touched_info.get("scenario", "—"))))
	_body_box.add_child(_make_spacer(4))
	_body_box.add_child(_make_section_header("this run"))
	_body_box.add_child(_make_kv_row("biomes discovered", biome_count))
	_body_box.add_child(_make_kv_row("quests active", active_q))
	_body_box.add_child(_make_kv_row("quests completed", done_q))

	# Session metadata — scenario, load-from-slot, session length.
	_body_box.add_child(_make_spacer(4))
	_body_box.add_child(_make_section_header("session"))
	var scenario_id := str(gsm.current_scenario_id) if gsm and "current_scenario_id" in gsm else "—"
	_body_box.add_child(_make_kv_row("scenario", scenario_id))
	if gsm and "session_load_slot" in gsm:
		var sls := int(gsm.session_load_slot)
		_body_box.add_child(_make_kv_row("loaded from", "slot %d" % (sls + 1) if sls >= 0 else "fresh start"))
	# Session length — millis since process start, formatted as h:mm:ss.
	var ms: int = Time.get_ticks_msec()
	var total_s: int = int(float(ms) / 1000.0)
	var hh: int = int(float(total_s) / 3600.0)
	var mm: int = int(float(total_s % 3600) / 60.0)
	var ss: int = total_s % 60
	_body_box.add_child(_make_kv_row("session length", "%d:%02d:%02d" % [hh, mm, ss]))

	if _run_peeking:
		_body_box.add_child(_make_spacer(6))
		_body_box.add_child(_make_run_inspect_panel())

func _build_keep_body() -> void:
	_body_box.add_child(_make_section_header("save slots"))
	for i in range(NUM_KEEP_SLOTS):
		_body_box.add_child(_make_keep_slot_row(i))
	if _keep_peeking:
		_body_box.add_child(_make_spacer(6))
		_body_box.add_child(_make_keep_peek_panel(_keep_slot))
	_body_box.add_child(_make_spacer(4))
	var hint := _make_muted_label("GHJ pick slot  ·  Q load  ·  E inspect  ·  R save", 11)
	_body_box.add_child(hint)

func _toggle_keep_peek() -> void:
	_keep_peeking = not _keep_peeking
	_refresh_body()
	_refresh_verb_chips()

func _toggle_run_inspect() -> void:
	_run_peeking = not _run_peeking
	_refresh_body()
	_refresh_verb_chips()

func _make_run_inspect_panel() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.13, 0.9)
	sb.border_color = Color(0.4, 0.55, 0.7, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(box)

	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm:
		var phz := UIStyleFactory.get_physics_fps_from_farm(farm)
		var sr := UIStyleFactory.get_slice_rate_from_farm(farm)
		if phz > 0.0:
			box.add_child(_make_kv_row("tick rate", "%.1f PhHz" % phz))
		if sr.slices > 0.0:
			box.add_child(_make_kv_row("evol rate", "%.0f/s [%dB]" % [sr.slices, sr.biomes]))

	var gsm = (Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if gsm and gsm.get("current_state") != null:
		var st = gsm.current_state
		if "seed" in st:
			box.add_child(_make_kv_row("world seed", str(st.seed)))

	if box.get_child_count() == 0:
		box.add_child(_make_muted_label("no physics data available", 12))

	return panel

func _make_keep_peek_panel(slot: int) -> Control:
	var gsm = (Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	var info: Dictionary = {}
	if gsm and "save_load" in gsm:
		info = gsm.save_load.peek_save_slot(slot)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.13, 0.9)
	sb.border_color = Color(0.4, 0.55, 0.7, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(box)

	if not info.get("exists", false):
		box.add_child(_make_muted_label("slot %d  —  empty" % (slot + 1), 12))
		return panel

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	var marker := str(info.get("marker_emoji", "💾"))
	var title_lbl := Label.new()
	title_lbl.text = "%s  %s" % [marker, str(info.get("display_name", "slot %d" % (slot + 1)))]
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6, 1.0))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_lbl)
	box.add_child(title_row)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.35, 0.45, 0.6, 0.4))
	box.add_child(sep)

	box.add_child(_make_kv_row("scenario", str(info.get("scenario", "—"))))
	var playtime_raw = info.get("playtime", -1.0)
	var playtime_str := _format_playtime(float(playtime_raw)) if float(playtime_raw) >= 0.0 else "—"
	box.add_child(_make_kv_row("playtime", playtime_str))
	box.add_child(_make_kv_row("grid", str(info.get("grid_size", "—"))))
	var credits_val = info.get("credits", null)
	var credits_str := "💰 %d" % int(credits_val) if credits_val != null else "—"
	box.add_child(_make_kv_row("credits", credits_str))
	var save_file := str(info.get("save_file", ""))
	if save_file != "":
		box.add_child(_make_kv_row("file", save_file.get_file()))

	return panel

func _make_keep_slot_row(idx: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var key_str: String = ITEM_KEYS[idx] if idx < ITEM_KEYS.size() else str(idx + 1)
	row.add_child(_make_key_chip(key_str))

	var name_lbl := Label.new()
	name_lbl.text = "slot %d" % (idx + 1)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.custom_minimum_size = Vector2(90, 0)
	row.add_child(name_lbl)

	var detail := Label.new()
	detail.text = _slot_detail_text(idx)
	detail.add_theme_font_size_override("font_size", 12)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detail)

	var selected := idx == _keep_slot
	var c := UIStyleFactory.COLOR_TAB_ACTIVE if selected else UIStyleFactory.COLOR_ITEM_IDLE
	if _slot_detail_text(idx) == "empty":
		c = UIStyleFactory.COLOR_ITEM_EMPTY if not selected else UIStyleFactory.COLOR_TAB_ACTIVE
	name_lbl.add_theme_color_override("font_color", c)
	detail.add_theme_color_override("font_color", c)
	if selected:
		name_lbl.text = "▸ " + name_lbl.text
	return row

func _slot_detail_text(slot: int) -> String:
	var gsm = (Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	var last_touched := _get_last_touched_slot(gsm)
	var marker := " ★" if last_touched == slot else ""
	if gsm and "save_load" in gsm:
		var info = gsm.save_load.peek_save_slot(slot)
		if info and typeof(info) == TYPE_DICTIONARY and info.get("exists", false):
			return "%s%s" % [str(info.get("summary", "saved")), marker]
		return "empty"
	if last_touched == slot:
		return "last touched ★"
	return "—"

func _build_new_body() -> void:
	_body_box.add_child(_make_section_header("new game"))
	for i in range(SCENARIO_LIST.size()):
		_body_box.add_child(_make_scenario_row(i))
	if _new_peeking:
		_body_box.add_child(_make_spacer(6))
		_body_box.add_child(_make_scenario_peek_panel(_new_item))
	_body_box.add_child(_make_spacer(4))
	var hint := _make_muted_label("GH pick  ·  E inspect  ·  R start", 11)
	_body_box.add_child(hint)

func _make_scenario_row(idx: int) -> Control:
	var entry: Dictionary = SCENARIO_LIST[idx]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var key_str: String = ITEM_KEYS[idx] if idx < ITEM_KEYS.size() else "?"
	row.add_child(_make_key_chip(key_str))
	var name_lbl := Label.new()
	name_lbl.text = str(entry.get("label", entry.get("id", "—")))
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)
	var desc_lbl := Label.new()
	desc_lbl.text = str(entry.get("desc", ""))
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	row.add_child(desc_lbl)
	var selected := idx == _new_item
	var c := UIStyleFactory.COLOR_TAB_ACTIVE if selected else UIStyleFactory.COLOR_ITEM_IDLE
	name_lbl.add_theme_color_override("font_color", c)
	if selected:
		name_lbl.text = "▸ " + name_lbl.text
	return row

func _make_scenario_peek_panel(idx: int) -> Control:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 4)
	if idx < 0 or idx >= SCENARIO_LIST.size():
		return panel
	var entry: Dictionary = SCENARIO_LIST[idx]
	var scenario_id: String = str(entry.get("id", ""))
	panel.add_child(_make_section_header(str(entry.get("label", scenario_id))))
	var save_store_class = load("res://Core/GameState/SaveStore.gd")
	if not save_store_class:
		panel.add_child(_make_muted_label("(could not load scenario)", 11))
		return panel
	var state = save_store_class.load_scenario(scenario_id)
	if not state:
		panel.add_child(_make_muted_label("scenario file missing", 11))
		return panel
	# Show starting economy summary
	var credits_text := ""
	if state.all_emoji_credits:
		var top: Array = []
		for emoji in state.all_emoji_credits:
			var amt = int(state.all_emoji_credits[emoji])
			if amt > 0:
				top.append("%s×%d" % [emoji, amt])
			if top.size() >= 6:
				break
		credits_text = "  ".join(top)
	panel.add_child(_make_kv_row("credits", credits_text if credits_text != "" else "—"))
	panel.add_child(_make_kv_row("grid", "%d×%d" % [state.grid_width, state.grid_height]))
	panel.add_child(_make_kv_row("biomes", "%d unlocked  ·  %d in pool" % [
		state.unlocked_biomes.size(), state.unexplored_biome_pool.size()
	]))
	return panel

func _toggle_new_peek() -> void:
	_new_peeking = not _new_peeking
	_refresh_body()
	_refresh_verb_chips()

func _start_new_scenario() -> void:
	if _new_item < 0 or _new_item >= SCENARIO_LIST.size():
		return
	var entry: Dictionary = SCENARIO_LIST[_new_item]
	var scenario_id: String = str(entry.get("id", ""))
	if scenario_id == "":
		return
	var gsm = (Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if not gsm or not ("session_lifecycle" in gsm):
		return
	deactivate()
	gsm.session_lifecycle.request_fresh_restart(false, scenario_id)

func _build_dev_body() -> void:
	# ── Live system metrics ──────────────────────────────────────────────────
	_body_box.add_child(_make_section_header("system"))
	var fps := int(Engine.get_frames_per_second())
	var proc_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var phys_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var mem_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / 1_000_000.0
	var obj_count := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var node_count := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_body_box.add_child(_make_kv_row("fps", "%d" % fps))
	_body_box.add_child(_make_kv_row("process / physics", "%.2f ms  /  %.2f ms" % [proc_ms, phys_ms]))
	_body_box.add_child(_make_kv_row("memory", "%.1f MB" % mem_mb))
	_body_box.add_child(_make_kv_row("objects / nodes", "%d / %d" % [obj_count, node_count]))

	# ── Batcher metrics ──────────────────────────────────────────────────────
	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm and "biome_evolution_batcher" in farm and farm.biome_evolution_batcher:
		var batcher = farm.biome_evolution_batcher
		if batcher.has_method("get_performance_metrics"):
			var m: Dictionary = batcher.get_performance_metrics()
			_body_box.add_child(_make_spacer(4))
			_body_box.add_child(_make_section_header("batcher"))
			var batch_avg := float(m.get("avg_batch_time_ms", 0.0))
			var frame_avg := float(m.get("avg_frame_time_ms", 0.0))
			_body_box.add_child(_make_kv_row("batch / frame avg", "%.2f ms  /  %.2f ms" % [batch_avg, frame_avg]))
			_body_box.add_child(_make_kv_row("buffer state", str(m.get("buffer_state", "—"))))
			_body_box.add_child(_make_kv_row("biomes", "%d active  %d paused" % [int(m.get("biomes_active", 0)), int(m.get("biomes_paused", 0))]))
			_body_box.add_child(_make_kv_row("packets pending", "%d" % int(m.get("packets_pending", 0))))
			var stall_warns := int(m.get("watchdog_stall_warnings", 0))
			if stall_warns > 0:
				_body_box.add_child(_make_kv_row("⚠ stall warnings", "%d" % stall_warns))

	# ── Dev actions ──────────────────────────────────────────────────────────
	_body_box.add_child(_make_spacer(4))
	_body_box.add_child(_make_section_header("actions"))
	for i in range(DEV_ACTIONS.size()):
		_body_box.add_child(_make_dev_action_row(i))
	_body_box.add_child(_make_spacer(4))
	_body_box.add_child(_make_muted_label("GHJ pick  ·  W/S nav  ·  E refresh metrics  ·  R run", 11))

func _make_dev_action_row(idx: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var key_str: String = ITEM_KEYS[idx] if idx < ITEM_KEYS.size() else "?"
	row.add_child(_make_key_chip(key_str))

	var action: Dictionary = DEV_ACTIONS[idx]
	var name_lbl := Label.new()
	name_lbl.text = str(action.get("label", "—"))
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.custom_minimum_size = Vector2(130, 0)
	row.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = str(action.get("desc", ""))
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(desc_lbl)

	var selected := idx == _dev_action_idx
	var c := UIStyleFactory.COLOR_TAB_ACTIVE if selected else UIStyleFactory.COLOR_ITEM_IDLE
	name_lbl.add_theme_color_override("font_color", c)
	if selected:
		name_lbl.text = "▸ " + name_lbl.text
	return row

func _execute_dev_action(idx: int) -> void:
	if idx >= DEV_ACTIONS.size():
		return
	var action_id: String = str(DEV_ACTIONS[idx].get("id", ""))
	match action_id:
		"full_reset":
			_request_confirm(PendingAction.DEV_RESTART)
		"print_biome_registry":
			var reg := BiomeRegistry.get_shared()
			reg.debug_print_all()
			_refresh_body()
		"validate_biomes":
			var reg2 := BiomeRegistry.get_shared()
			var ok := reg2.validate_exportable()
			print("BiomeRegistry.validate_exportable() → %s" % ("OK" if ok else "FAIL"))
			_refresh_body()
		"print_batcher":
			var farm = InstrumentLocator.resolve_active_farm(self)
			if farm and "biome_evolution_batcher" in farm and farm.biome_evolution_batcher:
				var m: Dictionary = farm.biome_evolution_batcher.get_performance_metrics()
				print("=== BATCHER METRICS ===")
				var keys := m.keys()
				keys.sort()
				for k in keys:
					print("  %s: %s" % [k, str(m[k])])
			_refresh_body()

# =============================================================================
# SMALL RENDER HELPERS
# =============================================================================

func _make_section_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text.to_upper()
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.7, 0.85, 0.75))
	return lbl

func _make_kv_row(key: String, value: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var k := Label.new()
	k.text = key
	k.add_theme_font_size_override("font_size", 12)
	k.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	k.custom_minimum_size = Vector2(140, 0)
	row.add_child(k)
	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 13)
	v.add_theme_color_override("font_color", UIStyleFactory.COLOR_VALUE)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	return row

func _make_key_chip(key_text: String) -> Label:
	var lbl := Label.new()
	lbl.text = "[%s]" % key_text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_KEY_CHIP)
	lbl.custom_minimum_size = Vector2(32, 0)
	return lbl

func _make_muted_label(text: String, icon_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", icon_size)
	lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl

func _make_spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

# =============================================================================
# TAB SWITCHING (mirrored into Surface.frame_id)
# =============================================================================

func _show_tab(tab: int) -> void:
	if _current_tab == tab and frame_id == TAB_TO_FRAME.get(tab, frame_id):
		return
	_keep_peeking = false
	_run_peeking = false
	_current_tab = tab
	var target_frame: String = TAB_TO_FRAME.get(tab, FRAME_RUN)
	if frame_id != target_frame:
		var prev := frame_id
		frame_id = target_frame
		frame_changed.emit(target_frame, prev)
		_emit_snapshot()
	_render_all()

func _on_frame_changed(new_frame_id: String, _prev_frame_id: String) -> void:
	var target_tab: int = FRAME_TO_TAB.get(new_frame_id, Tab.RUN)
	if _current_tab != target_tab:
		_current_tab = target_tab
		_render_all()

# =============================================================================
# QERF DISPATCH
# =============================================================================

func _on_action_q() -> void:
	if _pending_action != PendingAction.NONE:
		_confirm_save_and_act()
		return
	match _current_tab:
		Tab.RUN:    _request_confirm(PendingAction.QUIT)    # Q = screw out = quit
		Tab.KEEP:   _load_from_selected_slot()
		Tab.NEW:    _start_new_scenario()                    # Q = leave current run for a new one
		Tab.DEV:    pass  # honest empty

func _on_action_e() -> void:
	if _pending_action != PendingAction.NONE:
		if _pending_action == PendingAction.QUIT:
			_dismiss_confirm()
		else:
			_confirm_act_only()
		return
	match _current_tab:
		Tab.RUN:    _toggle_run_inspect()
		Tab.KEEP:
			if not _keep_peeking:    # E only opens; F flattens (grammar §E)
				_toggle_keep_peek()
		Tab.NEW:
			if not _new_peeking:
				_toggle_new_peek()
		Tab.DEV:    _refresh_body()  # re-snapshot all live metrics

func _on_action_r() -> void:
	if _pending_action != PendingAction.NONE:
		# R = resume/retreat from confirm in all cases.
		# QQ = save&quit, QF = quit-without-saving; R is always "go back in".
		_dismiss_confirm()
		return
	match _current_tab:
		Tab.RUN:    _save_and_resume()                      # R = screw in = enter game
		Tab.KEEP:   _save_to_selected_slot()
		Tab.NEW:    pass                                     # R empty — no current run to commit forward yet
		Tab.DEV:    _execute_dev_action(_dev_action_idx)

func _on_action_f() -> void:
	# QF chord: if we're in a quit-confirm, F = quit without saving.
	if _pending_action == PendingAction.QUIT:
		_confirm_act_only()
		return
	# Flatten: collapse whatever E opened. Only one panel can be open at a time.
	if _run_peeking:
		_toggle_run_inspect()
		return
	if _keep_peeking:
		_toggle_keep_peek()
		return
	if _new_peeking:
		_toggle_new_peek()
		return
	# Run tab: F = universal continue. Resume if a game is live; otherwise
	# load the last-touched slot, or start the default scenario.
	if _current_tab == Tab.RUN:
		_continue_or_play()
		return
	# Otherwise: no-op. The chip shows "—". Sim is already paused; nothing to page.

# =============================================================================
# SELECTOR KEYS — TYUI (tabs) / GHJKL; (items)
# =============================================================================

func _on_unhandled_key(keycode: int, _event: InputEvent) -> bool:
	if _pending_action != PendingAction.NONE:
		return false

	# Tab jump — TYUI.
	if TAB_BY_KEYCODE.has(keycode):
		_show_tab(int(TAB_BY_KEYCODE[keycode]))
		return true

	# Item selection within the active tab — GHJKL;.
	if ITEM_BY_KEYCODE.has(keycode):
		var slot := int(ITEM_BY_KEYCODE[keycode])
		_select_item_in_tab(slot)
		return true

	# Swallow any other homerow/top-row keys so gameplay doesn't leak under the modal.
	if _is_consumed_keyboard_row(keycode):
		return true
	return false

func _is_consumed_keyboard_row(keycode: int) -> bool:
	for kc in ITEM_BY_KEYCODE.keys():
		if kc == keycode:
			return true
	for kc in TAB_BY_KEYCODE.keys():
		if kc == keycode:
			return true
	return false

func _select_item_in_tab(slot: int) -> void:
	match _current_tab:
		Tab.KEEP:
			if slot < NUM_KEEP_SLOTS and _keep_slot != slot:
				_keep_slot = slot
				_refresh_body()
		Tab.NEW:
			if slot < SCENARIO_LIST.size() and _new_item != slot:
				_new_item = slot
				_refresh_body()
		Tab.DEV:
			if slot < DEV_ACTIONS.size() and _dev_action_idx != slot:
				_dev_action_idx = slot
				_refresh_body()
		_:
			pass

func _on_navigate(direction: Vector2i) -> void:
	# Per KEYBOARD_GRAMMAR.md "Selection layer":
	#   W/S = step OUTER (tabs)
	#   A/D = step INNER (items within active tab)
	if _pending_action != PendingAction.NONE:
		return
	if direction.y != 0:
		# W/S cycles tabs.
		var n := TAB_ROW.size()
		_show_tab(wrapi(_current_tab + signi(direction.y), 0, n))
		return
	if direction.x == 0:
		return
	var step: int = signi(direction.x)
	match _current_tab:
		Tab.KEEP:
			_keep_slot = wrapi(_keep_slot + step, 0, NUM_KEEP_SLOTS)
			_refresh_body()
		Tab.NEW:
			_new_item = wrapi(_new_item + step, 0, SCENARIO_LIST.size())
			_refresh_body()
		Tab.DEV:
			_dev_action_idx = wrapi(_dev_action_idx + step, 0, DEV_ACTIONS.size())
			_refresh_body()
		_:
			pass

# =============================================================================
# CONFIRM MODAL
# =============================================================================

func _request_confirm(action: int) -> void:
	_pending_action = action
	if _confirm_title_label:
		_confirm_title_label.text = _confirm_title(action)
	_confirm_message.text = _confirm_body(action)
	_refresh_body()
	_confirm_group.visible = true
	_tab_row_box.visible = false
	_refresh_verb_chips()

func _confirm_title(action: int) -> String:
	match action:
		PendingAction.QUIT:          return "QUIT GAME?"
		PendingAction.RESTART:       return "RESTART?"
		PendingAction.DEV_RESTART:   return "FULL RESET?"
		_: return "CONFIRM?"

func _confirm_body(action: int) -> String:
	match action:
		PendingAction.QUIT:          return "Unsaved progress will be lost."
		PendingAction.RESTART:       return "Reloads the session checkpoint.\nProgress since then will be lost."
		PendingAction.DEV_RESTART:   return "Signature evolution will be cleared\nand a fresh game will begin."
		_: return ""

func _confirm_verb_labels() -> Dictionary:
	match _pending_action:
		PendingAction.QUIT:          return {"Q": "save & quit", "E": "cancel", "R": "resume", "F": "quit without saving"}
		PendingAction.RESTART:       return {"Q": "save & restart", "E": "restart anyway", "R": "cancel", "F": ""}
		PendingAction.DEV_RESTART:   return {"Q": "confirm reset", "E": "", "R": "cancel", "F": ""}
		_: return {"Q": "confirm", "E": "", "R": "cancel", "F": ""}

func _dismiss_confirm() -> void:
	_pending_action = PendingAction.NONE
	_confirm_group.visible = false
	_tab_row_box.visible = true
	_render_all()

func _confirm_save_and_act() -> void:
	var action := _pending_action
	match action:
		PendingAction.QUIT, PendingAction.RESTART:
			_autosave_before_action(action)
			_execute_pending_action()
		PendingAction.DEV_RESTART:
			_execute_pending_action()
		_:
			_dismiss_confirm()

func _confirm_act_only() -> void:
	match _pending_action:
		PendingAction.QUIT, PendingAction.RESTART, PendingAction.DEV_RESTART:
			_execute_pending_action()
		_:
			_dismiss_confirm()

func _execute_pending_action() -> void:
	var action := _pending_action
	_pending_action = PendingAction.NONE
	match action:
		PendingAction.QUIT:
			deactivate()
			var gsm = (Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
			if gsm and "session_lifecycle" in gsm:
				gsm.session_lifecycle.request_application_quit()
		PendingAction.RESTART:
			deactivate()
			var gsm2 = (Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
			if gsm2 and "session_lifecycle" in gsm2:
				gsm2.session_lifecycle.request_restart()
		PendingAction.DEV_RESTART:
			deactivate()
			var gsm3 = (Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
			if gsm3 and "session_lifecycle" in gsm3:
				gsm3.session_lifecycle.request_fresh_restart(true)

func _autosave_before_action(action: int) -> void:
	var gsm = (Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if not gsm or not ("save_load" in gsm):
		return
	var slot := _pick_auto_save_slot(gsm, action)
	gsm.save_load.save_game(slot)

func _pick_auto_save_slot(gsm, action: int) -> int:
	if action == PendingAction.RESTART:
		var touched := _get_last_touched_slot(gsm)
		if touched >= 0:
			return touched
		var checkpoint = gsm.get("session_load_slot") if gsm.get("session_load_slot") != null else -1
		if int(checkpoint) >= 0:
			return int(checkpoint)
		return 0
	var last = gsm.get("last_saved_slot") if gsm.get("last_saved_slot") != null else -1
	return int(last) if int(last) >= 0 else 0

# =============================================================================
# ACTIONS PER TAB
# =============================================================================

func _on_resume_pressed() -> void:
	deactivate()
	resume_pressed.emit()

func _continue_or_play() -> void:
	# ZTF = continue. With a live game: close menu and resume.
	# Without one: load the T tab's "last touched" save, or start the default scenario.
	if _has_loaded_game():
		_on_resume_pressed()
		return
	var gsm = (Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if gsm == null:
		return
	var slot := _get_last_touched_slot(gsm)
	if slot >= 0 and not _get_last_touched_info(gsm, slot).is_empty() and "save_load" in gsm:
		deactivate()
		await gsm.save_load.load_and_apply(slot)
		return
	if "session_lifecycle" in gsm:
		deactivate()
		gsm.session_lifecycle.request_fresh_restart(false, DEFAULT_RUN_SCENARIO_ID)

func _save_and_resume() -> void:
	var gsm = (Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if gsm and _has_loaded_game() and "save_load" in gsm:
		var slot := _get_last_touched_slot(gsm)
		if slot < 0:
			slot = 0
		gsm.save_load.save_game(slot)
	_on_resume_pressed()

func _has_loaded_game() -> bool:
	var gsm = (Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	return bool(gsm and gsm.active_farm and gsm.current_state)

func _save_to_selected_slot() -> void:
	var gsm = (Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if not gsm or not ("save_load" in gsm):
		return
	gsm.save_load.save_game(_keep_slot)
	_refresh_body()

func _load_from_selected_slot() -> void:
	var gsm = (Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if not gsm or not ("save_load" in gsm):
		return
	deactivate()
	await gsm.save_load.load_and_apply(_keep_slot)

func _get_last_touched_slot(gsm) -> int:
	if not gsm:
		return -1
	if gsm.has_method("find_best_save_slot"):
		return int(gsm.find_best_save_slot())
	var last_active: int = int(gsm.get("last_active_slot")) if gsm.get("last_active_slot") != null else -1
	if int(last_active) >= 0:
		return int(last_active)
	var last_saved: int = int(gsm.get("last_saved_slot")) if gsm.get("last_saved_slot") != null else -1
	return int(last_saved) if int(last_saved) >= 0 else -1

func _get_last_touched_info(gsm, slot: int) -> Dictionary:
	if slot < 0 or not gsm or not ("save_load" in gsm):
		return {}
	var info = gsm.save_load.peek_save_slot(slot)
	if info and typeof(info) == TYPE_DICTIONARY and info.get("exists", false):
		return info
	return {}

func _format_playtime(seconds: float) -> String:
	var total := int(max(0.0, seconds))
	var h := int(float(total) / 3600.0)
	var m := int(float(total % 3600) / 60.0)
	var s := total % 60
	if h > 0:
		return "%dh %02dm %02ds" % [h, m, s]
	return "%dm %02ds" % [m, s]

# =============================================================================
# ACTIVATION HOOKS
# =============================================================================

func _on_activated() -> void:
	super._on_activated()
	if _pending_action != PendingAction.NONE:
		_dismiss_confirm()
	_keep_peeking = false
	_run_peeking = false
	# Cursor stays where the user last left it; the last-saved slot is marked
	# with ★ in its detail line so the player can see it without us moving
	# focus under their hand.
	_current_tab = Tab.RUN
	frame_id = TAB_TO_FRAME.get(Tab.RUN, FRAME_RUN)
	_render_all()
	if is_inside_tree():
		call_deferred("_apply_pause", true)

func _on_deactivated() -> void:
	super._on_deactivated()
	if is_inside_tree():
		call_deferred("_apply_pause", false)

func _apply_pause(paused: bool) -> void:
	if not is_inside_tree():
		return
	if paused and get_tree().get_nodes_in_group("game_root").is_empty():
		return  # Don't freeze the scene tree at the title screen
	get_tree().paused = paused

func hide_menu() -> void:
	deactivate()

# =============================================================================
# SURFACE CONTRACT
# =============================================================================

func get_visible_data() -> Dictionary:
	var save_slots: Array = []
	for i in range(NUM_KEEP_SLOTS):
		save_slots.append({
			"slot_index": i,
			"selected": i == _keep_slot,
			"detail": _slot_detail_text(i),
		})
	return {
		"tab": _current_tab,
		"frame_label": frame_id,
		"save_slots": save_slots,
	}

func get_transitions() -> Array:
	return [
		{"surface_id": "farm", "reason": "resume to previous surface"},
	]
