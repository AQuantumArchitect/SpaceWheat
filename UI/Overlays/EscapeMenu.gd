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

enum Tab { RUN, KEEP, NEW, BALANCE, DEV }

enum PendingAction {
	NONE,
	QUIT,
	RESTART,
	DEV_RESTART,
}

# Tab row — TYUIOP slots. We bind T/Y/U/I/O; P is honestly empty
# under the under-fill policy in KEYBOARD_GRAMMAR.md (Verbs reference
# moved to X/Guide). Balance (I) is the live economy/system tunables board.
const TAB_ROW := [
	{"key": "T", "tab": Tab.RUN,     "name": "Now",     "frame": "run"},
	{"key": "Y", "tab": Tab.KEEP,    "name": "Save",    "frame": "save_load"},
	{"key": "U", "tab": Tab.NEW,     "name": "New",     "frame": "new_game"},
	{"key": "I", "tab": Tab.BALANCE, "name": "Balance", "frame": "balance"},
	{"key": "O", "tab": Tab.DEV,     "name": "Dev",     "frame": "dev"},
]

const TAB_BY_KEYCODE := {
	KEY_T: Tab.RUN,
	KEY_Y: Tab.KEEP,
	KEY_U: Tab.NEW,
	KEY_I: Tab.BALANCE,
	KEY_O: Tab.DEV,
}

# Dev actions — navigate with GHJ/W/S, execute with R.
const DEV_ACTIONS := [
	{"id": "print_biome_registry", "label": "print biome registry", "desc": "dump all loaded biomes to console"},
	{"id": "validate_biomes",      "label": "validate biomes",      "desc": "check data integrity of exportable set"},
	{"id": "print_batcher",        "label": "print batcher metrics","desc": "snapshot batcher state to console"},
	{"id": "copy_logs",            "label": "copy logs",            "desc": "version + recent log tail → clipboard (paste in a bug report)"},
	# LAST on purpose: the cursor boots on row 0, and a save wipe must never be
	# the default-armed action of a tab reachable from the pause menu (QA:
	# a button-masher reached R→Q-confirm in three reflex presses).
	{"id": "full_reset",           "label": "full reset",           "desc": "wipe evolution state and start fresh"},
]

# GHJKL; — the homerow "slot" row, left-to-right for readability.
# (HOMEROW_KEYS is indexed right-to-left, ;=0; we deliberately diverge in X
# so slot 1 is G, slot 2 is H, etc. — the menu reads left-to-right.)
# Item labels (G-;) for display. Keycode→slot lookups go through
# InputBindingRegistry.plot_index_for_keycode (single shared ring source).
const ITEM_KEYS := ["G", "H", "J", "K", "L", ";"]

const NUM_KEEP_SLOTS := 3
# Save tab shows the 3 manual slots (rows 0-2) plus the 3-slot autosave ring
# (virtual rows 3-5, load/inspect only — the game writes them).
const NUM_KEEP_ROWS := NUM_KEEP_SLOTS + SaveStore.NUM_AUTO_SLOTS

# The scenario a fresh player drops into when there's no save to continue: "The Demos" (the
# guided tutorial). Kept in sync with SaveStore.DEFAULT_SCENARIO_ID so the menu default, a
# bare `godot` launch, headless boot, and the rig all load the same canonical starting world.
const DEFAULT_RUN_SCENARIO_ID := "demos_normal"

# Ordered list of playable scenarios shown in the New tab.
const SCENARIO_LIST := [
	{"id": "demos_normal",  "label": "The Demos",      "desc": "guided tutorial demo"},
	{"id": "new_game_easy", "label": "Easy Farm",      "desc": "open starter scenario"},
]
const FRAME_RUN := "run"
const FRAME_SAVE_LOAD := "save_load"
const FRAME_NEW_GAME := "new_game"
const FRAME_BALANCE := "balance"
const FRAME_DEV := "dev"

const TAB_TO_FRAME := {
	Tab.RUN: FRAME_RUN,
	Tab.KEEP: FRAME_SAVE_LOAD,
	Tab.NEW: FRAME_NEW_GAME,
	Tab.BALANCE: FRAME_BALANCE,
	Tab.DEV: FRAME_DEV,
}
const FRAME_TO_TAB := {
	FRAME_RUN: Tab.RUN,
	FRAME_SAVE_LOAD: Tab.KEEP,
	FRAME_NEW_GAME: Tab.NEW,
	FRAME_BALANCE: Tab.BALANCE,
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

# Balance tab — live economy/system tunables board + read-only action-cost inspector.
var _balance_action_idx: int = 0   # cursor into the read-only action inspector
var _balance_setting_idx: int = 0  # GHJKL; cursor into _balance_settings
var _balance_setting_page: int = 0
var _balance_settings: Array = []  # Array of {id, label, category, value_path, kind, step, min, max, default}
var _balance_biome_idx: int = 0
var _balance_snapshot: Dictionary = {}
var _balance_action_keys: Array[String] = []
var _balance_biomes: Array[String] = []
var _balance_projection: Dictionary = {}

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
	frame_ids = [FRAME_RUN, FRAME_SAVE_LOAD, FRAME_NEW_GAME, FRAME_BALANCE, FRAME_DEV]
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
		lbl.name = "MenuTab_%s" % str(entry.get("key", ""))
		lbl.add_theme_font_size_override("font_size", 15)
		# Mouse parity: tabs are tappable, same dispatch as the T/Y/U/I/O keys.
		lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		lbl.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		lbl.gui_input.connect(_on_tab_label_gui_input.bind(int(entry.get("tab", 0))))
		_tab_row_box.add_child(lbl)
		_tab_labels[str(entry.get("key", ""))] = lbl


func _on_tab_label_gui_input(event: InputEvent, tab: int) -> void:
	if _pending_action != PendingAction.NONE:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_show_tab(tab)
		accept_event()

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
		cell.name = "MenuVerb_%s" % key
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_theme_constant_override("separation", 2)
		cell.custom_minimum_size = Vector2(90, 0)
		# Mouse parity: verb chips are tappable — SAME handlers as the keys
		# (a stranger at the title has only a mouse; "[F] play" must be a
		# button, not a caption).
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		cell.gui_input.connect(_on_verb_chip_gui_input.bind(key))
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


func _on_verb_chip_gui_input(event: InputEvent, key: String) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed):
		return
	accept_event()
	match key:
		"Q": _on_action_q()
		"E": _on_action_e()
		"R": _on_action_r()
		"F": _on_action_f()

func _build_close_hint(container: Control) -> void:
	_close_hint = Label.new()
	_close_hint.text = "ESC close   ·   T Y U I tabs   ·   G H J K L ; items"
	_close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_close_hint.add_theme_font_size_override("font_size", 11)
	_close_hint.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	container.add_child(_close_hint)

func _build_confirm_group(container: Control) -> void:
	_confirm_group = VBoxContainer.new()
	_confirm_group.name = "MenuConfirmGroup"  # named so probes can assert the confirm actually armed
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
		Tab.RUN:     _build_run_body()
		Tab.KEEP:    _build_keep_body()
		Tab.NEW:     _build_new_body()
		Tab.BALANCE: _build_balance_body()
		Tab.DEV:     _build_dev_body()

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
			var keep_r := "save slot" if _keep_slot < NUM_KEEP_SLOTS else ""
			return {"Q": "load slot", "E": peek_label, "R": keep_r, "F": "flatten" if _keep_peeking else ""}
		Tab.NEW:
			var new_peek_label := "inspect ▾" if not _new_peeking else "—"
			return {"Q": "start scenario", "E": new_peek_label, "R": "", "F": "flatten" if _new_peeking else ""}
		Tab.BALANCE:
			return {"Q": "− value", "E": "reset", "R": "+ value", "F": ""}
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
	_body_box.add_child(_make_spacer(4))
	_body_box.add_child(_make_section_header("autosaves"))
	for i in range(SaveStore.NUM_AUTO_SLOTS):
		_body_box.add_child(_make_auto_slot_row(i))
	if _keep_peeking:
		_body_box.add_child(_make_spacer(6))
		if _keep_slot < NUM_KEEP_SLOTS:
			_body_box.add_child(_make_keep_peek_panel(_keep_slot))
		else:
			_body_box.add_child(_make_auto_peek_panel(_keep_slot - NUM_KEEP_SLOTS))
	_body_box.add_child(_make_spacer(4))
	var hint := _make_muted_label("GHJ slots · KL; autosaves  ·  Q load  ·  E inspect  ·  R save", 11)
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
	ClickWire.attach(row, _select_item_in_tab.bind(idx))
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

func _make_auto_slot_row(auto_idx: int) -> Control:
	var virtual_idx := NUM_KEEP_SLOTS + auto_idx
	var row := HBoxContainer.new()
	ClickWire.attach(row, _select_item_in_tab.bind(virtual_idx))
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var key_str: String = ITEM_KEYS[virtual_idx] if virtual_idx < ITEM_KEYS.size() else str(virtual_idx + 1)
	row.add_child(_make_key_chip(key_str))

	var name_lbl := Label.new()
	name_lbl.text = "auto %d" % (auto_idx + 1)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.custom_minimum_size = Vector2(90, 0)
	row.add_child(name_lbl)

	var detail := Label.new()
	detail.text = _auto_slot_detail_text(auto_idx)
	detail.add_theme_font_size_override("font_size", 12)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detail)

	var selected := virtual_idx == _keep_slot
	var c := UIStyleFactory.COLOR_TAB_ACTIVE if selected else UIStyleFactory.COLOR_ITEM_IDLE
	if detail.text == "empty":
		c = UIStyleFactory.COLOR_ITEM_EMPTY if not selected else UIStyleFactory.COLOR_TAB_ACTIVE
	name_lbl.add_theme_color_override("font_color", c)
	detail.add_theme_color_override("font_color", c)
	if selected:
		name_lbl.text = "▸ " + name_lbl.text
	return row


func _auto_slot_detail_text(auto_idx: int) -> String:
	if not SaveStore.auto_save_exists(auto_idx):
		return "empty"
	var mtime := FileAccess.get_modified_time(SaveStore.get_auto_save_path(auto_idx))
	var dt := Time.get_datetime_dict_from_unix_time(mtime)
	var stamp := "%02d/%02d %02d:%02d" % [dt.month, dt.day, dt.hour, dt.minute]
	var star := " ★" if SaveStore.newest_auto_slot() == auto_idx else ""
	return "%s%s" % [stamp, star]


func _make_auto_peek_panel(auto_idx: int) -> Control:
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
	if not SaveStore.auto_save_exists(auto_idx):
		box.add_child(_make_muted_label("auto %d  —  empty" % (auto_idx + 1), 12))
		return panel
	var path := SaveStore.get_auto_save_path(auto_idx)
	box.add_child(_make_kv_row("written", _auto_slot_detail_text(auto_idx).trim_suffix(" ★")))
	box.add_child(_make_kv_row("file", path.get_file()))
	box.add_child(_make_muted_label("written automatically on story beats + every 5 min · Q loads it", 11))
	return panel


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
	ClickWire.attach(row, _select_item_in_tab.bind(idx))
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
	_body_box.add_child(_make_kv_row("version", "v%s · %s" % [
		str(ProjectSettings.get_setting("application/config/version", "dev")),
		OS.get_name()
	]))
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
	ClickWire.attach(row, _select_item_in_tab.bind(idx))
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
		"copy_logs":
			var report := _gather_log_report()
			DisplayServer.clipboard_set(report)
			print("📋 Log report copied to clipboard (%d chars) — paste it in your bug report" % report.length())
			_refresh_body()

## Build the clipboard payload for a bug report: version + platform header,
## then the tail of the engine log (push_error/warnings land there via
## debug/file_logging). Read-only — never writes anything to disk.
func _gather_log_report() -> String:
	var lines: Array = []
	lines.append("SpaceWheat v%s" % str(ProjectSettings.get_setting("application/config/version", "dev")))
	lines.append("%s · Godot %s" % [OS.get_name(), str(Engine.get_version_info().get("string", "?"))])
	lines.append("")
	var log_path := "user://logs/godot.log"
	if FileAccess.file_exists(log_path):
		var f := FileAccess.open(log_path, FileAccess.READ)
		if f:
			var log_lines := f.get_as_text().split("\n")
			var start := maxi(0, log_lines.size() - 200)
			lines.append("--- godot.log (last %d of %d lines) ---" % [log_lines.size() - start, log_lines.size()])
			for i in range(start, log_lines.size()):
				lines.append(log_lines[i])
	else:
		lines.append("(no engine log at %s)" % log_path)
	return "\n".join(lines)

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
	# Historical quirk kept: no autowrap on the value column here.
	return OverlayChrome.kv_row(key, value, 140, false)

func _make_key_chip(key_text: String) -> Label:
	return OverlayChrome.key_chip(key_text)

func _make_muted_label(text: String, icon_size: int) -> Label:
	return OverlayChrome.muted_label(text, icon_size)

func _make_spacer(h: int) -> Control:
	return OverlayChrome.spacer(h)

# =============================================================================
# BODY: BALANCE — live economy/system tunables + read-only action cost inspector.
# =============================================================================

func _build_balance_body() -> void:
	_refresh_balance_snapshot()
	_ensure_balance_settings_loaded()

	# === SETTINGS LIST (Q − value · E reset · R + value · GHJKL; pick) ===
	_body_box.add_child(_make_section_header("settings"))
	var page_size: int = ITEM_KEYS.size()
	var page_start: int = _balance_setting_page * page_size
	var page_end: int = mini(page_start + page_size, _balance_settings.size())
	for i in range(page_start, page_end):
		_body_box.add_child(_make_balance_setting_row(i, i - page_start))
	var page_count: int = max(1, int(ceil(float(_balance_settings.size()) / float(page_size))))
	if page_count > 1:
		_body_box.add_child(_make_muted_label(
			"Q − value  ·  R + value  ·  E reset  ·  GHJKL; pick  ·  A/D page (%d/%d)" % [
				_balance_setting_page + 1, page_count], 11))
	else:
		_body_box.add_child(_make_muted_label(
			"Q − value  ·  R + value  ·  E reset  ·  GHJKL; pick", 11))
	_body_box.add_child(_make_spacer(6))

	# === BELOW: read-only action-cost inspector (kept for context) ===
	if _balance_snapshot.is_empty():
		_body_box.add_child(_make_muted_label("(action cost inspector unavailable — no active farm)", 11))
		return
	_body_box.add_child(_make_section_header("profile"))
	var profile_id := str(_balance_snapshot.get("profile_id", "default"))
	var profile_name := str(_balance_snapshot.get("profile_display_name", profile_id))
	_body_box.add_child(_make_kv_row("id", profile_id))
	_body_box.add_child(_make_kv_row("name", profile_name))

	_body_box.add_child(_make_spacer(4))
	_body_box.add_child(_make_section_header("actions"))

	if _balance_action_keys.is_empty():
		_body_box.add_child(_make_muted_label("no actions configured.", 12))
	else:
		var total := _balance_action_keys.size()
		var act_page_size := ITEM_KEYS.size()
		var act_page := int(float(_balance_action_idx) / float(act_page_size))
		var start := act_page * act_page_size
		var end: int = mini(start + act_page_size, total)
		for i in range(start, end):
			_body_box.add_child(_make_balance_action_row(i, i - start))
		var pages := int(ceil(float(total) / float(act_page_size)))
		_body_box.add_child(_make_muted_label(
			"action (%d/%d, p%d/%d) — read-only inspector" % [_balance_action_idx + 1, total, act_page + 1, pages],
			11,
		))

	_body_box.add_child(_make_spacer(4))
	_body_box.add_child(_make_section_header("selected action detail"))
	if _balance_action_idx < _balance_action_keys.size():
		var action: String = _balance_action_keys[_balance_action_idx]
		var costs: Dictionary = _balance_snapshot.get("action_costs", {})
		_body_box.add_child(_make_kv_row("cost", _format_cost(costs.get(action, {}))))
		var roi_notes: Dictionary = _balance_snapshot.get("roi_notes", {})
		_body_box.add_child(_make_kv_row("roi", str(roi_notes.get(action, "—"))))

	var quest: Dictionary = _balance_snapshot.get("quest_rewards", {})
	var quest_ratio = quest.get("resource_reward_base_ratio", null)
	if quest_ratio != null:
		_body_box.add_child(_make_kv_row("quest reward ratio", "%.2f" % float(quest_ratio)))

	if not _balance_biomes.is_empty():
		_body_box.add_child(_make_spacer(4))
		_body_box.add_child(_make_section_header("timescale"))
		var biome_name: String = _balance_biomes[_balance_biome_idx]
		_body_box.add_child(_make_kv_row(
			"biome",
			"%s  (%d/%d)" % [biome_name, _balance_biome_idx + 1, _balance_biomes.size()],
		))
		if bool(_balance_projection.get("ok", false)):
			var stride := int(_balance_projection.get("recommended_stride", -1))
			var dt := float(_balance_projection.get("recommended_dt", -1.0))
			var top := str(_balance_projection.get("top_emoji", ""))
			var top_p := float(_balance_projection.get("top_probability", 0.0))
			if stride >= 0 and dt > 0.0:
				_body_box.add_child(_make_kv_row("recommend", "stride %d  dt %.4f" % [stride, dt]))
			if top != "":
				_body_box.add_child(_make_kv_row("top target", "%s  p=%.3f" % [top, top_p]))
		else:
			_body_box.add_child(_make_muted_label("projection unavailable", 11))

func _make_balance_setting_row(idx: int, slot_idx: int) -> Control:
	var row := HBoxContainer.new()
	ClickWire.attach(row, _select_item_in_tab.bind(slot_idx))
	row.add_theme_constant_override("separation", 10)
	var key_str: String = ITEM_KEYS[slot_idx] if slot_idx < ITEM_KEYS.size() else "?"
	row.add_child(_make_key_chip(key_str))

	var setting: Dictionary = _balance_settings[idx]
	var cat_lbl := Label.new()
	cat_lbl.text = str(setting.get("category", ""))
	cat_lbl.add_theme_font_size_override("font_size", 11)
	cat_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	cat_lbl.custom_minimum_size = Vector2(70, 0)
	row.add_child(cat_lbl)

	var name_lbl := Label.new()
	name_lbl.text = str(setting.get("label", setting.get("id", "—")))
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var value_lbl := Label.new()
	value_lbl.text = _balance_setting_format(setting)
	value_lbl.add_theme_font_size_override("font_size", 13)
	value_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_VALUE)
	row.add_child(value_lbl)

	var selected := idx == _balance_setting_idx
	var c := UIStyleFactory.COLOR_TAB_ACTIVE if selected else UIStyleFactory.COLOR_ITEM_IDLE
	name_lbl.add_theme_color_override("font_color", c)
	if selected:
		name_lbl.text = "▸ " + name_lbl.text
	return row

func _make_balance_action_row(idx: int, slot_idx: int) -> Control:
	var row := HBoxContainer.new()
	ClickWire.attach(row, _select_item_in_tab.bind(slot_idx))
	row.add_theme_constant_override("separation", 10)
	var key_str: String = ITEM_KEYS[slot_idx] if slot_idx < ITEM_KEYS.size() else "?"
	row.add_child(_make_key_chip(key_str))

	var action_name: String = _balance_action_keys[idx]
	var name_lbl := Label.new()
	name_lbl.text = action_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var costs: Dictionary = _balance_snapshot.get("action_costs", {})
	var cost_lbl := Label.new()
	cost_lbl.text = _format_cost(costs.get(action_name, {}))
	# Measure's authored cost is a BASE scaled by pair affinity at the plot
	# (ProbeActions → PhysicsCostScaling) — showing the bare base read as a
	# lie to a tester who paid 3👥 against "measure: 👥1". Say the rule.
	if action_name == "measure" and cost_lbl.text != "":
		cost_lbl.text += "  (base — scales with pair affinity)"
	cost_lbl.add_theme_font_size_override("font_size", 12)
	cost_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_VALUE)
	row.add_child(cost_lbl)

	var selected := idx == _balance_action_idx
	var c := UIStyleFactory.COLOR_TAB_ACTIVE if selected else UIStyleFactory.COLOR_ITEM_IDLE
	name_lbl.add_theme_color_override("font_color", c)
	if selected:
		name_lbl.text = "▸ " + name_lbl.text
	return row

# =============================================================================
# BALANCE — settings tunables (Q − value / R + value / E reset)
# =============================================================================

# Static catalog of tunables Balance exposes. value_path is read/written
# through GameState.balance_workbench_config (defaults from BalanceConfig).
# music_volume rides alongside as a non-config tunable handled directly via
# MusicManager. Every economy/physics knob is DERIVED from BalanceConfig.TUNABLES
# via board_specs() — the single source of truth. open_only rows (Lindbladian-only)
# are filtered out in the closed system.
const _MUSIC_ROW := {"id": "music_volume", "label": "Music volume", "category": "Audio", "value_path": [], "kind": "music_pct", "step": 5, "min": 0, "max": 100, "default": 70}

func _ensure_balance_settings_loaded() -> void:
	if _balance_settings.is_empty():
		_balance_settings = [_MUSIC_ROW.duplicate(true)]
		var closed: bool = not BalanceConfig.dissipative_enabled()
		for d in BalanceConfig.board_specs():
			if closed and bool(d.get("open_only", false)):
				continue  # dead knob in the closed system
			_balance_settings.append(d.duplicate(true))
	_balance_setting_idx = clampi(_balance_setting_idx, 0, max(0, _balance_settings.size() - 1))
	var page_size: int = ITEM_KEYS.size()
	var max_page: int = max(0, int(float(_balance_settings.size() - 1) / float(page_size)))
	_balance_setting_page = clampi(_balance_setting_page, 0, max_page)

func _balance_setting_value(setting: Dictionary) -> Variant:
	var kind: String = str(setting.get("kind", "float"))
	if kind == "music_pct":
		var music = get_node_or_null("/root/MusicManager")
		if music and music.has_method("get_volume"):
			return int(round(float(music.get_volume()) * 100.0))
		return int(setting.get("default", 70))
	var path: Array = setting.get("value_path", [])
	if path.is_empty():
		return setting.get("default", 0.0)
	var gsm = (Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if gsm and "balance_workbench_config" in gsm:
		var cfg = gsm.balance_workbench_config
		if typeof(cfg) == TYPE_DICTIONARY:
			var node = cfg
			for key in path:
				if typeof(node) != TYPE_DICTIONARY or not node.has(key):
					return setting.get("default", 0.0)
				node = node[key]
			return node
	return setting.get("default", 0.0)

func _balance_setting_set_value(setting: Dictionary, value: Variant) -> void:
	var kind: String = str(setting.get("kind", "float"))
	if kind == "music_pct":
		var music = get_node_or_null("/root/MusicManager")
		if music and music.has_method("set_volume"):
			music.set_volume(clampf(float(value) / 100.0, 0.0, 1.0))
		return
	var path: Array = setting.get("value_path", [])
	if path.is_empty():
		return
	var gsm = get_node_or_null("/root/GameStateManager")
	if not gsm or not ("current_state" in gsm) or not gsm.current_state:
		return
	if gsm.current_state.has_method("set_balance_config_value"):
		gsm.current_state.set_balance_config_value(path, value)
	# Apply LIVE to the running economy too — not just the saved config — so board edits
	# take effect immediately. Builds the same nested patch the rig balance_patch uses and
	# routes it through BalanceService.apply_patch → FarmEconomy overrides.
	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm:
		var patch: Dictionary = {}
		var cursor: Dictionary = patch
		for i in range(path.size() - 1):
			cursor[str(path[i])] = {}
			cursor = cursor[str(path[i])]
		cursor[str(path[path.size() - 1])] = value
		BalanceService.apply_patch(farm, patch)

func _balance_setting_format(setting: Dictionary) -> String:
	var kind: String = str(setting.get("kind", "float"))
	var v = _balance_setting_value(setting)
	match kind:
		"music_pct":
			return "%d%%" % int(v)
		"int":
			return "%d" % int(v)
		"float":
			return "%.2f" % float(v)
		_:
			return str(v)

func _nudge_balance_setting(direction: int) -> void:
	_ensure_balance_settings_loaded()
	if _balance_settings.is_empty():
		return
	var setting: Dictionary = _balance_settings[_balance_setting_idx]
	var kind: String = str(setting.get("kind", "float"))
	var step: float = float(setting.get("step", 1.0))
	var lo = setting.get("min", 0.0)
	var hi = setting.get("max", 100.0)
	var current = _balance_setting_value(setting)
	var next
	match kind:
		"music_pct", "int":
			next = clampi(int(current) + direction * int(step), int(lo), int(hi))
		_:
			next = clampf(float(current) + direction * step, float(lo), float(hi))
	_balance_setting_set_value(setting, next)
	_refresh_body()

func _reset_balance_setting() -> void:
	_ensure_balance_settings_loaded()
	if _balance_settings.is_empty():
		return
	var setting: Dictionary = _balance_settings[_balance_setting_idx]
	_balance_setting_set_value(setting, setting.get("default", 0.0))
	_refresh_body()

func _refresh_balance_snapshot() -> void:
	var farm = InstrumentLocator.resolve_active_farm(self)
	if not farm:
		_balance_snapshot = {}
		_balance_action_keys = []
		_balance_biomes = []
		_balance_projection = {}
		return
	_balance_snapshot = BalanceService.get_snapshot(farm)
	var keys: Array[String] = []
	var costs: Dictionary = _balance_snapshot.get("action_costs", {})
	for k in costs.keys():
		keys.append(str(k))
	keys.sort()
	_balance_action_keys = keys
	if _balance_action_idx >= _balance_action_keys.size():
		_balance_action_idx = 0

	_balance_biomes = []
	if "grid" in farm and farm.grid and farm.grid.has_method("get_biome_names"):
		for n in farm.grid.get_biome_names():
			_balance_biomes.append(str(n))
		_balance_biomes.sort()
	if _balance_biome_idx >= _balance_biomes.size():
		_balance_biome_idx = 0
	_refresh_balance_projection()

func _refresh_balance_projection() -> void:
	_balance_projection = {}
	if _balance_biomes.is_empty():
		return
	var biome_name: String = _balance_biomes[_balance_biome_idx]
	var inst = InstrumentLocator.resolve_quantum_instrument(self)
	if not inst:
		return
	if inst.has_method("recommend_timescale"):
		_balance_projection = inst.recommend_timescale(biome_name, 8)
	if _balance_projection.is_empty() and inst.has_method("get_timescale_projection"):
		_balance_projection = inst.get_timescale_projection(biome_name, 8)

func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return "(none)"
	var parts: Array[String] = []
	var keys = cost.keys()
	keys.sort()
	for emoji in keys:
		# Signed: a bare "🍼1" read ambiguous (cost or reward?); "🍼−1" is honest —
		# this is the dev-inspector's "cost" row, the same badge law as the live bar (d1-03).
		parts.append("%s−%d" % [str(emoji), int(cost[emoji])])
	return " ".join(parts)

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
		if _pending_action == PendingAction.DEV_RESTART:
			# Q is the game's most-mashed verb — it must never confirm a save
			# wipe. Only the deliberate F confirms a full reset; Q backs out.
			_dismiss_confirm()
			return
		_confirm_save_and_act()
		return
	match _current_tab:
		Tab.RUN:     _request_confirm(PendingAction.QUIT)    # Q = screw out = quit
		Tab.KEEP:    _load_from_selected_slot()
		Tab.NEW:     _start_new_scenario()                    # Q = leave current run for a new one
		Tab.BALANCE: _nudge_balance_setting(-1)              # Q = − value
		Tab.DEV:     pass  # honest empty

func _on_action_e() -> void:
	if _pending_action != PendingAction.NONE:
		if _pending_action == PendingAction.QUIT or _pending_action == PendingAction.DEV_RESTART:
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
		Tab.BALANCE: _reset_balance_setting()  # E = reset selected tunable to default
		Tab.DEV:    _refresh_body()  # re-snapshot all live metrics

func _on_action_r() -> void:
	if _pending_action != PendingAction.NONE:
		# R = resume/retreat from confirm in all cases.
		# QQ = save&quit, QF = quit-without-saving; R is always "go back in".
		_dismiss_confirm()
		return
	match _current_tab:
		Tab.RUN:     _save_and_resume()                      # R = screw in = enter game
		Tab.KEEP:    _save_to_selected_slot()
		Tab.NEW:     pass                                     # R empty — no current run to commit forward yet
		Tab.BALANCE: _nudge_balance_setting(1)              # R = + value
		Tab.DEV:     _execute_dev_action(_dev_action_idx)

func _on_action_f() -> void:
	# QF chord: if we're in a quit-confirm, F = quit without saving.
	# DEV_RESTART: F is the ONLY confirm for a full reset (two deliberate keys).
	if _pending_action == PendingAction.QUIT or _pending_action == PendingAction.DEV_RESTART:
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
	var slot := InputBindingRegistry.plot_index_for_keycode(keycode, ITEM_KEYS.size())
	if slot >= 0:
		_select_item_in_tab(slot)
		return true

	# Swallow any other homerow/top-row keys so gameplay doesn't leak under the modal.
	if _is_consumed_keyboard_row(keycode):
		return true
	return false

func _is_consumed_keyboard_row(keycode: int) -> bool:
	if InputBindingRegistry.plot_index_for_keycode(keycode, ITEM_KEYS.size()) >= 0:
		return true
	for kc in TAB_BY_KEYCODE.keys():
		if kc == keycode:
			return true
	return false

func _select_item_in_tab(slot: int) -> void:
	match _current_tab:
		Tab.KEEP:
			if slot < NUM_KEEP_ROWS and _keep_slot != slot:
				_keep_slot = slot
				_refresh_body()
				_refresh_verb_chips()  # R blanks on read-only autosave rows
		Tab.NEW:
			if slot < SCENARIO_LIST.size() and _new_item != slot:
				_new_item = slot
				_refresh_body()
		Tab.BALANCE:
			_ensure_balance_settings_loaded()
			var page_size := ITEM_KEYS.size()
			var global_idx := _balance_setting_page * page_size + slot
			if global_idx < _balance_settings.size() and _balance_setting_idx != global_idx:
				_balance_setting_idx = global_idx
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
			_keep_slot = wrapi(_keep_slot + step, 0, NUM_KEEP_ROWS)
			_refresh_body()
			_refresh_verb_chips()
		Tab.NEW:
			_new_item = wrapi(_new_item + step, 0, SCENARIO_LIST.size())
			_refresh_body()
		Tab.BALANCE:
			# A/D pages the settings list when there are more entries than
			# GHJKL; can show in one row.
			_ensure_balance_settings_loaded()
			var page_size: int = ITEM_KEYS.size()
			var max_page: int = max(0, int(float(_balance_settings.size() - 1) / float(page_size)))
			_balance_setting_page = clampi(_balance_setting_page + step, 0, max_page)
			_balance_setting_idx = clampi(_balance_setting_idx,
				_balance_setting_page * page_size,
				mini((_balance_setting_page + 1) * page_size, _balance_settings.size()) - 1)
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
		PendingAction.QUIT:
			var summary := _session_summary_text()
			if summary == "":
				return "Unsaved progress will be lost."
			return summary + "\n\nUnsaved progress will be lost."
		PendingAction.RESTART:       return "Reloads the session checkpoint.\nProgress since then will be lost."
		PendingAction.DEV_RESTART:   return "Signature evolution will be cleared\nand a fresh game will begin."
		_: return ""


## One-line earned-this-session card shown in the quit confirm. Diffs live farm
## state against gsm.session_baseline (captured at session boot); returns ""
## when no baseline exists so the confirm falls back to the plain warning.
func _session_summary_text() -> String:
	var gsm = (Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if gsm == null or not (gsm.get("session_baseline") is Dictionary) or gsm.session_baseline.is_empty():
		return ""
	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm == null:
		return ""
	var base: Dictionary = gsm.session_baseline
	var parts: Array = []

	var elapsed_min := int((Time.get_ticks_msec() - int(base.get("start_ms", 0))) / 60000.0)
	parts.append("⏱ <1 min" if elapsed_min < 1 else "⏱ %d min" % elapsed_min)

	var flags_before: Dictionary = base.get("flags", {})
	var beats := 0
	if "story_flags_fired" in farm and farm.story_flags_fired is Dictionary:
		for fid in farm.story_flags_fired.keys():
			if not flags_before.has(fid):
				beats += 1
	if beats > 0:
		parts.append("🚩 %d story beat%s" % [beats, "" if beats == 1 else "s"])

	var qm = InstrumentLocator.resolve_quest_manager(self, farm)
	if qm and "completed_quests" in qm and qm.completed_quests is Array:
		# The ledger persists across loads (save v6) — diff against the session
		# baseline so this line credits THIS session, not the whole save.
		var done: int = qm.completed_quests.size() - int(base.get("completed_quests", 0))
		if done > 0:
			parts.append("📜 %d contract%s" % [done, "" if done == 1 else "s"])

	var wallet_before: Dictionary = base.get("wallet", {})
	var economy = farm.get("economy")
	if economy != null and economy.get("emoji_credits") is Dictionary:
		var gains: Array = []
		for emoji in economy.emoji_credits.keys():
			var delta: float = float(economy.emoji_credits[emoji]) - float(wallet_before.get(emoji, 0))
			if delta >= 1.0:
				gains.append([delta, str(emoji)])
		gains.sort_custom(func(a, b): return a[0] > b[0])
		var top: Array = []
		for i in range(mini(3, gains.size())):
			top.append("%s+%d" % [gains[i][1], int(gains[i][0])])
		if not top.is_empty():
			parts.append(" ".join(top))

	return "This session: " + " · ".join(parts)

func _confirm_verb_labels() -> Dictionary:
	match _pending_action:
		PendingAction.QUIT:          return {"Q": "save & quit", "E": "cancel", "R": "resume", "F": "quit without saving"}
		PendingAction.RESTART:       return {"Q": "save & restart", "E": "restart anyway", "R": "cancel", "F": ""}
		PendingAction.DEV_RESTART:   return {"Q": "", "E": "", "R": "cancel", "F": "confirm reset"}
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
	if _keep_slot >= NUM_KEEP_SLOTS:
		return  # autosave rows are written by the game; R chip is blank here
	gsm.save_load.save_game(_keep_slot)
	_refresh_body()

func _load_from_selected_slot() -> void:
	var gsm = (Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if not gsm or not ("save_load" in gsm):
		return
	if _keep_slot >= NUM_KEEP_SLOTS:
		var auto_idx := _keep_slot - NUM_KEEP_SLOTS
		if not SaveStore.auto_save_exists(auto_idx):
			return
		deactivate()
		await gsm.save_load.load_and_apply_path(SaveStore.get_auto_save_path(auto_idx))
		return
	# Pre-beta saves are refused at load — say so HERE instead of tearing the
	# session down first and falling back.
	var peek: Dictionary = gsm.save_load.peek_save_slot(_keep_slot)
	if bool(peek.get("exists", false)) and not bool(peek.get("compatible", true)):
		print("slot %d holds a pre-beta save this version can't load" % (_keep_slot + 1))
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
	var auto_slots: Array = []
	for i in range(SaveStore.NUM_AUTO_SLOTS):
		auto_slots.append({
			"auto_index": i,
			"selected": (NUM_KEEP_SLOTS + i) == _keep_slot,
			"detail": _auto_slot_detail_text(i),
		})
	return {
		"tab": _current_tab,
		"frame_label": frame_id,
		"save_slots": save_slots,
		"auto_slots": auto_slots,
	}

func get_transitions() -> Array:
	return [
		{"surface_id": "farm", "reason": "resume to previous surface"},
	]
