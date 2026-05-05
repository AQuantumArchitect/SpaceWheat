class_name QuestBoard
extends "res://UI/Core/Surface.gd"

## C — Contract Surface.
##
## Mirrors the X menu's grammar:
##   TYUI         = tabs (4 frames)
##   GHJKL;       = items within tab (homerow, left-to-right)
##   Q / E / R    = verbs on the currently-selected item (chips below body)
##   [ / ]        = cycle frames (PlayerShell-level)
##   X / ESC      = close
##
## Tabs are sort lenses onto the same market:
##   T  comfort    — share - depth desc; "easy first" (default)
##   Y  stretch    — share - depth asc;  "growth first"
##   U  magnitude  — quantity desc;      "biggest first"
##   I  ledger     — active / ready / locked (lifecycle)
##
## The market itself is character-agnostic; the player view sorts via
## MarketView geometry (share = cos angle of inventory & offer; depth = drain
## fraction). C is the player's lens onto a vast offer surface.

const InstrumentLocator = preload("res://Core/Instrumentation/InstrumentLocator.gd")
const MarketView = preload("res://Core/Markets/MarketView.gd")

# =============================================================================
# SIGNALS (preserved for OverlayManager + HUD listeners)
# =============================================================================

signal quest_accepted(quest: Dictionary)
signal quest_completed(quest_id: int, rewards: Dictionary)
signal quest_abandoned(quest_id: int)
signal board_opened
signal board_closed

# =============================================================================
# FRAME / KEY GRAMMAR
# =============================================================================

const FRAME_COMFORT := "comfort"
const FRAME_STRETCH := "stretch"
const FRAME_MAGNITUDE := "magnitude"
const FRAME_LEDGER := "ledger"

# Tab row — TYUI; matches Surface base's TYUIOP_KEYCODES indexing for direct-jump.
const TAB_ROW := [
	{"key": "T", "frame": FRAME_COMFORT,   "name": "Comfort"},
	{"key": "Y", "frame": FRAME_STRETCH,   "name": "Stretch"},
	{"key": "U", "frame": FRAME_MAGNITUDE, "name": "Magnitude"},
	{"key": "I", "frame": FRAME_LEDGER,    "name": "Ledger"},
]

# GHJKL; — homerow item row, left-to-right (matches EscapeMenu's deliberate
# divergence from HOMEROW_KEYS, which is right-to-left).
const ITEM_KEYS := ["G", "H", "J", "K", "L", ";"]
const ITEM_BY_KEYCODE := {
	KEY_G: 0,
	KEY_H: 1,
	KEY_J: 2,
	KEY_K: 3,
	KEY_L: 4,
	KEY_SEMICOLON: 5,
}
const MAX_VISIBLE_ITEMS: int = 6     # GHJKL; = 6 slots
const MARKET_FETCH_LIMIT: int = 24   # how many we ask the market for; we display top-6

# Substrate-derived sort lookup
const SORT_BY_FRAME := {
	FRAME_COMFORT:   MarketView.SortMode.COMFORT,
	FRAME_STRETCH:   MarketView.SortMode.STRETCH,
	FRAME_MAGNITUDE: MarketView.SortMode.MAGNITUDE,
}

# =============================================================================
# COLORS (copied from EscapeMenu palette for cross-surface consistency)
# =============================================================================

const COLOR_TAB_ACTIVE := Color(1.0, 0.9, 0.3, 1.0)
const COLOR_TAB_IDLE := Color(0.6, 0.7, 0.85, 0.85)
const COLOR_ITEM_ACTIVE := Color(1.0, 0.9, 0.3, 1.0)
const COLOR_ITEM_IDLE := Color(0.75, 0.82, 0.92, 0.9)
const COLOR_ITEM_EMPTY := Color(0.45, 0.5, 0.6, 0.75)
const COLOR_KEY_CHIP := Color(0.55, 0.85, 1.0, 0.95)
const COLOR_MUTED := Color(0.55, 0.6, 0.7, 0.85)
const COLOR_VALUE := Color(0.95, 0.95, 0.8, 1.0)
const COLOR_VERB_ACTIVE := Color(0.95, 0.75, 0.35, 1.0)
const COLOR_VERB_IDLE := Color(0.45, 0.5, 0.6, 0.75)
const COLOR_COMFORT_POS := Color(0.5, 0.9, 0.55, 1.0)
const COLOR_COMFORT_NEG := Color(0.95, 0.55, 0.5, 1.0)
const COLOR_COMFORT_MID := Color(0.85, 0.85, 0.6, 1.0)

# =============================================================================
# STATE
# =============================================================================

var quest_manager: Node = null
var current_biome: Node = null

# Pair-scope mode: when both names are set, fetch via MarketLattice.
# Set by N → C handoff via OverlayManager pending scope. Cleared on close.
var _pair_a_name: String = ""
var _pair_b_name: String = ""
# Active faction-biome counterparty name. Drives scoped pool when set.
# Populated from pair scope (when pair_b is a faction-biome) or from best-match default.
var _fb_name: String = ""
# True when _fb_name was auto-picked (no N→C handoff). Drives status hint.
var _fb_auto_scoped: bool = false

var _offer_pool: Array = []          # Most recent market snapshot (annotated, up to MARKET_FETCH_LIMIT)
var _selected_index: int = 0         # 0..MAX_VISIBLE_ITEMS-1; index into the visible top-N

# Locked offers freeze a snapshot dict by (faction, resource, quantity) key.
# When R rerolls the pool, locked entries are spliced back to the top.
var _locked_offers: Dictionary = {}  # key → frozen offer dict

# UI nodes
var _status_line: Label = null
var _scope_line: Label = null
var _tab_row_box: HBoxContainer = null
var _tab_labels: Dictionary = {}
var _body_box: VBoxContainer = null
var _verb_palette: PanelContainer = null
var _verb_chip_box: HBoxContainer = null
var _verb_chip_cells: Dictionary = {}
var _close_hint: Label = null


# =============================================================================
# INIT
# =============================================================================

func _init() -> void:
	name = "QuestBoard"
	panel_title = "CONTRACTS"
	panel_title_size = 24
	panel_border_color = Color(0.5, 0.4, 0.6, 0.8)
	panel_size_mode = PanelSizeMode.LARGE
	use_scroll_container = false
	overlay_name = "quests"
	overlay_icon = ""
	overlay_tier = 14
	navigation_mode = NavigationMode.NONE  # GHJKL; handles selection directly
	# Surface contract
	surface_id = "C"
	frame_ids = [FRAME_COMFORT, FRAME_STRETCH, FRAME_MAGNITUDE, FRAME_LEDGER]
	frame_id = FRAME_COMFORT
	action_labels = {"Q": "Import", "E": "Broker", "R": "Export", "F": "—"}


# =============================================================================
# EXTERNAL API (OverlayManager / TestAutorun)
# =============================================================================

func set_quest_manager(manager: Node) -> void:
	quest_manager = manager
	if quest_manager:
		if quest_manager.has_signal("quest_offered") and not quest_manager.quest_offered.is_connected(_on_quest_pool_changed):
			quest_manager.quest_offered.connect(_on_quest_pool_changed)
		if quest_manager.has_signal("active_quests_changed") and not quest_manager.active_quests_changed.is_connected(_on_quest_pool_changed):
			quest_manager.active_quests_changed.connect(_on_quest_pool_changed)
		if quest_manager.has_signal("offer_locked") and not quest_manager.offer_locked.is_connected(_on_arc_quest_injected):
			quest_manager.offer_locked.connect(_on_arc_quest_injected)


func _on_arc_quest_injected(_quest_id: int) -> void:
	if frame_id == FRAME_LEDGER:
		_render_all()


func set_biome(biome: Node) -> void:
	if biome != current_biome:
		current_biome = biome
		_offer_pool.clear()
		_selected_index = 0
		if visible:
			_render_all()


func open_board() -> void:
	visible = true
	_ensure_biome()
	_refresh_pool()
	_render_all()
	board_opened.emit()


func close_board() -> void:
	visible = false
	board_closed.emit()


# =============================================================================
# UI BUILD
# =============================================================================

func _build_content(container: Control) -> void:
	_status_line = Label.new()
	_status_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_line.add_theme_font_size_override("font_size", 12)
	_status_line.add_theme_color_override("font_color", COLOR_MUTED)
	container.add_child(_status_line)

	_scope_line = Label.new()
	_scope_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scope_line.add_theme_font_size_override("font_size", 11)
	_scope_line.add_theme_color_override("font_color", COLOR_VALUE)
	_scope_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(_scope_line)

	_build_tab_row(container)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.4, 0.35, 0.5, 0.5))
	container.add_child(sep)

	_body_box = VBoxContainer.new()
	_body_box.add_theme_constant_override("separation", 4)
	_body_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(_body_box)

	var sep2 := HSeparator.new()
	sep2.add_theme_color_override("color", Color(0.4, 0.35, 0.5, 0.3))
	container.add_child(sep2)

	_build_verb_chips(container)
	_build_close_hint(container)
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
		_tab_labels[str(entry["key"])] = lbl


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
		key_lbl.add_theme_color_override("font_color", COLOR_KEY_CHIP)
		cell.add_child(key_lbl)

		var label_lbl := Label.new()
		label_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label_lbl.add_theme_font_size_override("font_size", 11)
		cell.add_child(label_lbl)

		_verb_chip_cells[key] = {"key": key_lbl, "label": label_lbl}


func _build_close_hint(container: Control) -> void:
	_close_hint = Label.new()
	_close_hint.text = "[X] close   ·   [ ] / ] cycle tab"
	_close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_close_hint.add_theme_font_size_override("font_size", 11)
	_close_hint.add_theme_color_override("font_color", COLOR_MUTED)
	container.add_child(_close_hint)


# =============================================================================
# INPUT — TYUI (frame jump) handled by Surface base; GHJKL; (item) here.
# Q/E/R/F handled by OverlayBase; we override _on_action_q/e/r below.
# =============================================================================

func _on_unhandled_key(keycode: int, event: InputEvent) -> bool:
	if super._on_unhandled_key(keycode, event):
		_on_frame_changed_local()
		return true
	if ITEM_BY_KEYCODE.has(keycode):
		var idx: int = int(ITEM_BY_KEYCODE[keycode])
		_select(idx)
		return true
	return false


func _on_frame_changed(_new_frame_id: String, _prev_frame_id: String) -> void:
	_on_frame_changed_local()


func _on_frame_changed_local() -> void:
	# Sort frames share the pool; ledger reads quest_manager. Reset selection.
	_selected_index = 0
	_render_all()


# =============================================================================
# VERB ACTIONS
# =============================================================================

func _on_action_q() -> void:
	if frame_id == FRAME_LEDGER:
		_complete_or_claim_selected()
	else:
		_accept_selected()  # Import: pull the offered emoji toward you


func _on_action_e() -> void:
	if frame_id == FRAME_LEDGER:
		_abandon_selected()
	else:
		_toggle_lock_selected()  # Broker: hold/release this offer for inspection


func _on_action_r() -> void:
	if frame_id == FRAME_LEDGER:
		return
	# Export: go deeper into the current counterparty — fresh offers, same scope.
	_refresh_pool()
	_selected_index = 0
	_render_all()


func _on_action_f() -> void:
	# F = flatten. When a broker panel is open, collapse it.
	# When nothing is open, F is global play — PlayerShell already handled it.
	# Never drill_out (F is not "back").
	pass


# =============================================================================
# RENDER PIPELINE
# =============================================================================

func _render_all() -> void:
	_refresh_status()
	_refresh_tab_row()
	_refresh_body()
	_refresh_verb_chips()


func _refresh_status() -> void:
	if not _status_line:
		return
	var biome_name: String = str(current_biome.name) if current_biome and "name" in current_biome else "—"
	var pool_n: int = _offer_pool.size()
	var inv_norm: float = MarketView._l2_norm(_get_inventory())
	var selected_label: String = _selected_offer_label()
	var scope_label: String = _scope_mode_label()
	var page_idx: int = get_page_index()
	var page_count: int = maxi(1, get_page_count())
	_status_line.text = "%s · page %d/%d · selected: %s · |inv|=%.1f · pool=%d · %s" % [
		biome_name,
		page_idx,
		page_count,
		selected_label if selected_label != "" else "—",
		inv_norm,
		pool_n,
		frame_id,
	]
	if _scope_line:
		_scope_line.text = "selected: %s · scope: %s · source: %s" % [
			selected_label if selected_label != "" else "—",
			scope_label,
			_scope_source_label(),
		]


func _current_tab_label() -> String:
	for entry in TAB_ROW:
		if str(entry.get("frame", "")) == frame_id:
			return str(entry.get("name", frame_id))
	return str(frame_id)


func _refresh_tab_row() -> void:
	if _tab_labels.is_empty():
		return
	for entry in TAB_ROW:
		var key_str := str(entry["key"])
		var lbl: Label = _tab_labels.get(key_str, null)
		if lbl == null:
			continue
		if str(entry["frame"]) == frame_id:
			lbl.text = "[%s] %s" % [key_str, str(entry["name"]).to_upper()]
			lbl.add_theme_color_override("font_color", COLOR_TAB_ACTIVE)
		else:
			lbl.text = "[%s] %s" % [key_str, str(entry["name"])]
			lbl.add_theme_color_override("font_color", COLOR_TAB_IDLE)


func _refresh_body() -> void:
	if not _body_box:
		return
	for child in _body_box.get_children():
		child.queue_free()
	if frame_id == FRAME_LEDGER:
		_build_ledger_body()
	else:
		_build_offer_body()


func _refresh_verb_chips() -> void:
	if _verb_chip_cells.is_empty():
		return
	var labels: Dictionary = _current_verb_labels()
	for key in ["Q", "E", "R", "F"]:
		var cell: Dictionary = _verb_chip_cells.get(key, {})
		if cell.is_empty():
			continue
		var label_lbl: Label = cell["label"]
		var key_lbl: Label = cell["key"]
		var txt := str(labels.get(key, ""))
		if txt == "":
			label_lbl.text = "—"
			label_lbl.add_theme_color_override("font_color", COLOR_VERB_IDLE)
			key_lbl.add_theme_color_override("font_color", COLOR_VERB_IDLE)
		else:
			label_lbl.text = txt
			label_lbl.add_theme_color_override("font_color", COLOR_VERB_ACTIVE)
			key_lbl.add_theme_color_override("font_color", COLOR_KEY_CHIP)
	action_labels = labels
	action_labels_changed.emit()


func _current_verb_labels() -> Dictionary:
	if frame_id == FRAME_LEDGER:
		var rows := _ledger_rows()
		if _selected_index >= 0 and _selected_index < rows.size():
			if str(rows[_selected_index].get("category", "")) == "ARC":
				return {"Q": "Acknowledge", "E": "—", "R": "—", "F": "—"}
		return {"Q": "Complete", "E": "Abandon", "R": "—", "F": "—"}
	var broker_label := "Broker"
	var sel := _get_selected_offer()
	if not sel.is_empty() and _is_locked(sel):
		broker_label = "Release"
	return {"Q": "Import", "E": broker_label, "R": "Export", "F": "—"}


# =============================================================================
# OFFER BODY (comfort / stretch / magnitude tabs)
# =============================================================================

func _build_offer_body() -> void:
	var visible_offers: Array = _get_visible_offers()
	if visible_offers.is_empty():
		_body_box.add_child(_make_muted_label(
			"no offers — load a biome with admitted factions, or press R to reroll", 12))
		return
	for i in range(MAX_VISIBLE_ITEMS):
		if i < visible_offers.size():
			_body_box.add_child(_make_offer_row(visible_offers[i], ITEM_KEYS[i], i == _selected_index))
		else:
			_body_box.add_child(_make_empty_row(ITEM_KEYS[i]))


func _make_offer_row(offer: Dictionary, key_str: String, selected: bool) -> Control:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.10, 0.13, 0.85) if not selected else Color(0.18, 0.16, 0.10, 0.95)
	sb.border_color = Color(0.4, 0.35, 0.45, 0.5) if not selected else COLOR_ITEM_ACTIVE
	sb.border_width_left = 4 if selected else 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	hbox.add_child(_make_key_chip(key_str, selected))

	var faction_lbl := Label.new()
	faction_lbl.text = str(offer.get("faction", "?"))
	faction_lbl.add_theme_font_size_override("font_size", 13)
	faction_lbl.add_theme_color_override("font_color", COLOR_ITEM_ACTIVE if selected else COLOR_ITEM_IDLE)
	faction_lbl.custom_minimum_size = Vector2(170, 0)
	faction_lbl.clip_text = true
	hbox.add_child(faction_lbl)

	var ask_lbl := Label.new()
	ask_lbl.text = "%s × %d" % [str(offer.get("resource", "?")), int(offer.get("quantity", 0))]
	ask_lbl.add_theme_font_size_override("font_size", 16)
	ask_lbl.add_theme_color_override("font_color", COLOR_VALUE)
	ask_lbl.custom_minimum_size = Vector2(120, 0)
	hbox.add_child(ask_lbl)

	# Substrate quartet — engine's view of the offer.
	#   M = market_score (overall bid quality), s = scarcity (supply pressure),
	#   a = alignment (faction↔biome axial overlap), e = directional_edge
	#   (mythos lean — positive = with the spectral wind, negative = against).
	var proj: Dictionary = offer.get("market_projection", {})
	var subs_lbl := Label.new()
	subs_lbl.text = "[M %.2f s%.2f a%.2f e%+.2f]" % [
		float(proj.get("market_score", 0.0)),
		float(proj.get("scarcity", 0.0)),
		float(proj.get("alignment", 0.0)),
		float(proj.get("directional_edge", 0.0)),
	]
	subs_lbl.add_theme_font_size_override("font_size", 11)
	subs_lbl.add_theme_color_override("font_color", COLOR_MUTED)
	subs_lbl.custom_minimum_size = Vector2(180, 0)
	# Surface the engine's reasoning as a hover tooltip.
	var explanation = offer.get("market_explanation", [])
	if explanation is Array and not explanation.is_empty():
		var lines: PackedStringArray = []
		for line in explanation:
			lines.append(str(line))
		subs_lbl.tooltip_text = "\n".join(lines)
	hbox.add_child(subs_lbl)

	# View geometry
	var share: float = float(offer.get("view_share", 0.0))
	var depth: float = float(offer.get("view_depth", 0.0))
	var comfort: float = float(offer.get("view_comfort", 0.0))
	var view_lbl := Label.new()
	view_lbl.text = "(s=%.2f d=%.2f c%+.2f) %s" % [share, depth, comfort, _comfort_bar(comfort, 5)]
	view_lbl.add_theme_font_size_override("font_size", 11)
	view_lbl.add_theme_color_override("font_color", _comfort_color(comfort))
	view_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(view_lbl)

	if _is_locked(offer):
		var lock_lbl := Label.new()
		lock_lbl.text = "🔒"
		lock_lbl.add_theme_font_size_override("font_size", 13)
		hbox.add_child(lock_lbl)

	return row


func _make_empty_row(key_str: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_make_key_chip(key_str, false, true))
	var lbl := Label.new()
	lbl.text = "—"
	lbl.add_theme_color_override("font_color", COLOR_ITEM_EMPTY)
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)
	return row


# =============================================================================
# LEDGER BODY (I tab)
# =============================================================================

func _build_ledger_body() -> void:
	var rows: Array = _ledger_rows()
	if rows.is_empty():
		_body_box.add_child(_make_muted_label(
			"no active or ready contracts — accept some via T/Y/U", 12))
		return
	for i in range(MAX_VISIBLE_ITEMS):
		if i < rows.size():
			_body_box.add_child(_make_ledger_row(rows[i], ITEM_KEYS[i], i == _selected_index))
		else:
			_body_box.add_child(_make_empty_row(ITEM_KEYS[i]))


func _make_ledger_row(quest: Dictionary, key_str: String, selected: bool) -> Control:
	var is_arc: bool = str(quest.get("category", "")) == "ARC"
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	if is_arc:
		sb.bg_color = Color(0.08, 0.12, 0.10, 0.92) if not selected else Color(0.12, 0.20, 0.14, 0.95)
		sb.border_color = Color(0.3, 0.6, 0.4, 0.6) if not selected else Color(0.5, 0.9, 0.55, 0.95)
	else:
		sb.bg_color = Color(0.10, 0.10, 0.13, 0.85) if not selected else Color(0.18, 0.16, 0.10, 0.95)
		sb.border_color = Color(0.4, 0.35, 0.45, 0.5) if not selected else COLOR_ITEM_ACTIVE
	sb.border_width_left = 4 if selected else 2 if is_arc else 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	hbox.add_child(_make_key_chip(key_str, selected))

	if is_arc:
		# Campaign arc quest — badge + body; hint expands on selection
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(vbox)

		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 6)
		vbox.add_child(top_row)

		var arc_badge := Label.new()
		arc_badge.text = "[ARC]"
		arc_badge.add_theme_font_size_override("font_size", 11)
		arc_badge.add_theme_color_override("font_color", Color(0.5, 0.9, 0.55, 0.9))
		top_row.add_child(arc_badge)

		var body_lbl := Label.new()
		body_lbl.text = str(quest.get("body", str(quest.get("source_flag", "campaign quest"))))
		body_lbl.add_theme_font_size_override("font_size", 12)
		body_lbl.add_theme_color_override("font_color", COLOR_ITEM_ACTIVE if selected else COLOR_ITEM_IDLE)
		body_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body_lbl.clip_text = not selected
		body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if selected else TextServer.AUTOWRAP_OFF
		top_row.add_child(body_lbl)

		if selected:
			var hint_str: String = str(quest.get("hint", ""))
			if hint_str != "":
				var hint_lbl := Label.new()
				hint_lbl.text = "hint: %s" % hint_str
				hint_lbl.add_theme_font_size_override("font_size", 11)
				hint_lbl.add_theme_color_override("font_color", COLOR_MUTED)
				hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				vbox.add_child(hint_lbl)
			var ack_lbl := Label.new()
			ack_lbl.text = "Q to acknowledge · this quest stays here until dismissed"
			ack_lbl.add_theme_font_size_override("font_size", 10)
			ack_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.55, 0.5))
			vbox.add_child(ack_lbl)
	else:
		var status_lbl := Label.new()
		status_lbl.text = "[%s]" % str(quest.get("status", "?")).to_upper()
		status_lbl.add_theme_font_size_override("font_size", 11)
		status_lbl.add_theme_color_override("font_color", _status_color(quest.get("status", "")))
		status_lbl.custom_minimum_size = Vector2(70, 0)
		hbox.add_child(status_lbl)

		var faction_lbl := Label.new()
		faction_lbl.text = str(quest.get("faction", "?"))
		faction_lbl.add_theme_font_size_override("font_size", 13)
		faction_lbl.add_theme_color_override("font_color", COLOR_ITEM_ACTIVE if selected else COLOR_ITEM_IDLE)
		faction_lbl.custom_minimum_size = Vector2(170, 0)
		faction_lbl.clip_text = true
		hbox.add_child(faction_lbl)

		var ask_lbl := Label.new()
		ask_lbl.text = "%s × %d" % [str(quest.get("resource", "?")), int(quest.get("quantity", 0))]
		ask_lbl.add_theme_font_size_override("font_size", 16)
		ask_lbl.add_theme_color_override("font_color", COLOR_VALUE)
		ask_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(ask_lbl)

	return row


func _ledger_rows() -> Array:
	var rows: Array = []
	# Arc quests (campaign story missions) appear first — they're persistent guidance.
	if quest_manager and "locked_offers" in quest_manager and quest_manager.locked_offers is Dictionary:
		for q in quest_manager.locked_offers.values():
			if str(q.get("category", "")) == "ARC":
				rows.append(q)
	if quest_manager and "active_quests" in quest_manager and quest_manager.active_quests is Dictionary:
		for q in quest_manager.active_quests.values():
			rows.append(q)
	for key in _locked_offers:
		var locked: Dictionary = _locked_offers[key].duplicate()
		locked["status"] = "locked"
		rows.append(locked)
	return rows


# =============================================================================
# MARKET POOL + VIEW
# =============================================================================

func _refresh_pool() -> void:
	_offer_pool.clear()
	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm == null:
		return

	# Path 1: both sides are live biomes — use live QC tensor.
	if _is_pair_scope_active() and farm.has_method("_ensure_market_lattice"):
		var lattice = farm._ensure_market_lattice()
		var biome_a = _resolve_live_biome(_pair_a_name)
		var biome_b = _resolve_live_biome(_pair_b_name)
		if lattice and biome_a and biome_b:
			var raw: Array = lattice.propose_pair_offers(biome_a, biome_b, MARKET_FETCH_LIMIT)
			_offer_pool = _adapt_contracts_for_view(raw)
			MarketView.annotate(_offer_pool, _get_inventory())
			return

	_ensure_biome()
	if current_biome == null:
		return

	if not farm.has_method("_ensure_market_lattice"):
		_fallback_legacy_pool(farm)
		return

	var lattice = farm._ensure_market_lattice()
	if lattice == null:
		_fallback_legacy_pool(farm)
		return

	# Path 2: faction-biome scope — current biome ⊗ one specific faction-biome.
	# _fb_name is set from pair scope (when pair_b is a faction-biome) or from
	# the best-match default chosen below.
	if _fb_name == "" and _is_pair_scope_active():
		# pair_b didn't resolve as a live biome; treat it as a faction-biome name.
		_fb_name = _pair_b_name
		_fb_auto_scoped = false

	if _fb_name == "" and not _is_pair_scope_active():
		# No scope at all — try the highest-tension live biome pair first.
		var all_biomes: Dictionary = farm.grid.get_all_biomes() if farm.grid and farm.grid.has_method("get_all_biomes") else {}
		var best_pair: Dictionary = lattice.best_live_tension_pair(all_biomes)
		if not best_pair.is_empty():
			_pair_a_name = str(best_pair.get("a", ""))
			_pair_b_name = str(best_pair.get("b", ""))
			var biome_a = _resolve_live_biome(_pair_a_name)
			var biome_b = _resolve_live_biome(_pair_b_name)
			if biome_a and biome_b:
				var raw: Array = lattice.propose_pair_offers(biome_a, biome_b, MARKET_FETCH_LIMIT)
				if not raw.is_empty():
					_offer_pool = _adapt_contracts_for_view(raw)
					MarketView.annotate(_offer_pool, _get_inventory())
					_fb_auto_scoped = true
					return
			_pair_a_name = ""
			_pair_b_name = ""

	if _fb_name == "":
		# Fall back to top-tension faction-biome for the current biome.
		_fb_name = lattice.best_faction_biome_name(current_biome)
		_fb_auto_scoped = _fb_name != ""

	if _fb_name != "":
		var raw: Array = lattice.propose_faction_biome_offers_scoped(current_biome, _fb_name, MARKET_FETCH_LIMIT)
		if not raw.is_empty():
			_offer_pool = _adapt_contracts_for_view(raw)
			MarketView.annotate(_offer_pool, _get_inventory())
			return

	_fallback_legacy_pool(farm)


func _fallback_legacy_pool(farm) -> void:
	if not farm.has_method("_ensure_contract_market"):
		return
	var market = farm._ensure_contract_market()
	if market == null:
		return
	var raw: Array = market.propose_offers(current_biome, MARKET_FETCH_LIMIT)
	MarketView.annotate(raw, _get_inventory())
	_offer_pool = raw


func _is_pair_scope_active() -> bool:
	return _pair_a_name != "" and _pair_b_name != ""


func _resolve_live_biome(bname: String):
	if bname == "":
		return null
	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm == null or not ("grid" in farm) or farm.grid == null:
		return null
	if farm.grid.has_method("get_all_biomes"):
		return farm.grid.get_all_biomes().get(bname, null)
	return null


## Adapt MarketLattice's MarketContract records to the quest-dict shape that
## the existing offer-row UI consumes. Pair-mode contracts carry tension/shared
## metadata that the row can surface.
func _adapt_contracts_for_view(contracts: Array) -> Array:
	var out: Array = []
	for c in contracts:
		if c == null:
			continue
		var pair_a: String = str(c.get_meta("pair_a", "")) if c.has_meta("pair_a") else ""
		var pair_b: String = str(c.get_meta("pair_b", "")) if c.has_meta("pair_b") else ""
		var tension: float = float(c.get_meta("tension", 0.0)) if c.has_meta("tension") else 0.0
		var shared: bool = bool(c.get_meta("shared", false)) if c.has_meta("shared") else false
		# Display: show the *expected* cost. Actual debit uses QuantumRounding
		# (P(round up) = fractional part), so 2.7 cost is paid as 3 with prob 0.7,
		# 2 with prob 0.3 — preserved-in-expectation, gives the quantum feel.
		var qty_float: float = c.cost_amount
		var qty: int = int(round(qty_float))
		var quest: Dictionary = {
			"id": c.id,
			"status": "offered",
			"biome": c.biome_name,
			"biome_name": c.biome_name,
			"faction": c.faction,
			"resource": c.resource,
			"quantity": qty,
			"reward_resources": {c.resource: qty},
			"reward_multiplier": 1.0,
			"market_projection": {
				"resource": c.resource,
				"base_cost": qty,
				"effective_cost": qty,
				"multiplier": 1.0 + tension,
				"market_score": tension,
				"directional_edge": tension,
				"scarcity": 1.0 - tension,
				"alignment": 1.0 if shared else 0.0,
			},
			"_alignment": 1.0 if shared else 0.0,
			"_intensity": tension,
			"_complexity": 0.5,
			"_urgency": tension,
			"_variety": 0.5,
			"body": "%s ⊗ %s · deliver %s · pay ~%.1f %s in %s" % [pair_a, pair_b, c.resource, qty_float, c.cost_emoji, c.biome_name],
			"full_text": "%s offers %s on %s. Pay ~%.2f %s (stochastic round). Exercise pops the qubit. Tension %.3f." % [
				c.faction, c.resource, c.biome_name, qty_float, c.cost_emoji, tension
			],
			"source": "market_lattice_pair",
			"market_offer_id": c.id,
			"pair_a": pair_a,
			"pair_b": pair_b,
			"tension": tension,
			"cost_emoji": c.cost_emoji,
			"cost_amount": c.cost_amount,
		}
		out.append(quest)
	return out


## Called by OverlayManager when transferring scope from N → C.
func set_pair_scope(name_a: String, name_b: String) -> void:
	_pair_a_name = name_a
	_pair_b_name = name_b
	_fb_name = ""  # resolved lazily in _refresh_pool
	_fb_auto_scoped = false
	_offer_pool.clear()
	_selected_index = 0
	if _body_box != null:
		_refresh_pool()
		_render_all()


func clear_pair_scope() -> void:
	if _pair_a_name == "" and _pair_b_name == "" and _fb_name == "":
		return
	_pair_a_name = ""
	_pair_b_name = ""
	_fb_name = ""
	_fb_auto_scoped = false
	_offer_pool.clear()
	_selected_index = 0


func _get_visible_offers() -> Array:
	var mode: int = SORT_BY_FRAME.get(frame_id, MarketView.SortMode.COMFORT)
	var sorted: Array = MarketView.sort_view(_offer_pool, _get_inventory(), mode)
	if _locked_offers.is_empty():
		return sorted
	var locked: Array = []
	var unlocked: Array = []
	for o in sorted:
		if _is_locked(o):
			locked.append(o)
		else:
			unlocked.append(o)
	return locked + unlocked


func _get_selected_offer() -> Dictionary:
	var visible_offers: Array = _get_visible_offers()
	if _selected_index < 0 or _selected_index >= visible_offers.size():
		return {}
	return visible_offers[_selected_index]


func _selected_offer_label() -> String:
	var offer: Dictionary = _get_selected_offer()
	if offer.is_empty():
		return ""
	return "%s × %d" % [str(offer.get("resource", "?")), int(offer.get("quantity", 0))]


func _get_inventory() -> Dictionary:
	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm == null or farm.economy == null:
		return {}
	return farm.economy.get_all_resources()


func _ensure_biome() -> void:
	if current_biome != null:
		return
	var abm = InstrumentLocator.resolve_active_biome_manager(self)
	if abm and abm.has_method("get_active_biome_node"):
		current_biome = abm.get_active_biome_node()


# =============================================================================
# VERB DISPATCHERS
# =============================================================================

func _accept_selected() -> void:
	var offer: Dictionary = _get_selected_offer()
	if offer.is_empty() or quest_manager == null:
		return
	if quest_manager.has_method("accept_quest"):
		var qid: int = int(offer.get("id", -1))
		if qid >= 0 and quest_manager.accept_quest(qid):
			quest_accepted.emit(offer)


func _toggle_lock_selected() -> void:
	var offer: Dictionary = _get_selected_offer()
	if offer.is_empty():
		return
	var key := _lock_key(offer)
	if _locked_offers.has(key):
		_locked_offers.erase(key)
	else:
		_locked_offers[key] = offer.duplicate(true)  # snapshot freeze
	_render_all()


func _complete_or_claim_selected() -> void:
	if quest_manager == null:
		return
	var rows: Array = _ledger_rows()
	if _selected_index < 0 or _selected_index >= rows.size():
		return
	var quest: Dictionary = rows[_selected_index]
	# Arc quests: Q = acknowledge (dismiss guidance note)
	if str(quest.get("category", "")) == "ARC":
		var qid: int = int(quest.get("id", -1))
		if qid >= 0 and "locked_offers" in quest_manager:
			quest_manager.locked_offers.erase(qid)
		_render_all()
		return
	var qid: int = int(quest.get("id", -1))
	if qid < 0:
		return
	var status := str(quest.get("status", ""))
	if status == "ready" and quest_manager.has_method("claim_quest"):
		if quest_manager.claim_quest(qid):
			quest_completed.emit(qid, {})
	elif quest_manager.has_method("complete_quest"):
		if quest_manager.complete_quest(qid):
			quest_completed.emit(qid, {})


func _abandon_selected() -> void:
	if quest_manager == null:
		return
	var rows: Array = _ledger_rows()
	if _selected_index < 0 or _selected_index >= rows.size():
		return
	var quest: Dictionary = rows[_selected_index]
	# Arc quests: E is a no-op — hint is shown inline when selected.
	if str(quest.get("category", "")) == "ARC":
		return
	var qid: int = int(quest.get("id", -1))
	if qid < 0:
		var key := _lock_key(quest)
		_locked_offers.erase(key)
		_render_all()
		return
	if quest_manager.has_method("fail_quest"):
		quest_manager.fail_quest(qid, "player_action")
		quest_abandoned.emit(qid)


# =============================================================================
# HELPERS
# =============================================================================

func _select(idx: int) -> void:
	_selected_index = clampi(idx, 0, MAX_VISIBLE_ITEMS - 1)
	_refresh_body()
	_refresh_verb_chips()


func _is_locked(offer: Dictionary) -> bool:
	return _locked_offers.has(_lock_key(offer))


func _lock_key(offer: Dictionary) -> String:
	return "%s|%s|%d" % [
		str(offer.get("faction", "")),
		str(offer.get("resource", "")),
		int(offer.get("quantity", 0)),
	]


func _on_quest_pool_changed() -> void:
	if visible:
		_render_all()


func _make_key_chip(key_str: String, selected: bool = false, empty: bool = false) -> Label:
	var lbl := Label.new()
	lbl.text = "[%s]" % key_str
	lbl.add_theme_font_size_override("font_size", 14)
	if empty:
		lbl.add_theme_color_override("font_color", COLOR_ITEM_EMPTY)
	elif selected:
		lbl.add_theme_color_override("font_color", COLOR_ITEM_ACTIVE)
	else:
		lbl.add_theme_color_override("font_color", COLOR_KEY_CHIP)
	lbl.custom_minimum_size = Vector2(28, 0)
	return lbl


func _make_muted_label(text: String, size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", COLOR_MUTED)
	return lbl


func _comfort_bar(comfort: float, length: int) -> String:
	var filled: int = int(round(absf(comfort) * float(length)))
	filled = clampi(filled, 0, length)
	var bar := ""
	for i in range(length):
		bar += "▮" if i < filled else "▯"
	return bar


func _comfort_color(comfort: float) -> Color:
	if comfort > 0.05:
		return COLOR_COMFORT_POS
	if comfort < -0.05:
		return COLOR_COMFORT_NEG
	return COLOR_COMFORT_MID


func _status_color(status: String) -> Color:
	match status:
		"ready": return Color(0.5, 1.0, 0.5)
		"active": return Color(0.6, 0.85, 1.0)
		"locked": return Color(0.95, 0.75, 0.35)
		_: return COLOR_MUTED


# =============================================================================
# Surface API surface — get_visible_data (C contract snapshot)
# =============================================================================

func get_visible_data() -> Dictionary:
	var selected_offer: Dictionary = _get_selected_offer()
	var payload := build_surface_visible_data(
		_current_tab_label(),
		_selected_index,
		_selected_offer_label(),
		"%s · %s" % [_scope_mode_label(), _scope_source_label()],
		{
			"pool_size": _offer_pool.size(),
			"locked_count": _locked_offers.size(),
			"biome": str(current_biome.name) if current_biome and "name" in current_biome else "",
		}
	)
	payload["selected_offer"] = selected_offer
	payload["scope_mode"] = _scope_mode_label()
	payload["scope_source"] = _scope_source_label()
	payload["scope_counterparty"] = _scope_counterparty_name()
	payload["scope_pair_a"] = _pair_a_name
	payload["scope_pair_b"] = _pair_b_name
	payload["scope_auto"] = _fb_auto_scoped
	return payload


func get_snapshot() -> Dictionary:
	# Rig-facing snapshot: slot states + selection for player_input navigation.
	var visible: Array = _get_visible_offers()
	var slots: Array = []
	for i in range(visible.size()):
		var offer = visible[i]
		slots.append({
			"index": i,
			"state": str(offer.get("status", "offered")) if offer is Dictionary else "offered",
			"offer": offer,
		})
	if quest_manager and quest_manager.has_method("get_active_quests"):
		for q in quest_manager.get_active_quests():
			if q is Dictionary:
				slots.append({
					"index": slots.size(),
					"state": str(q.get("status", "active")),
					"quest_id": int(q.get("id", -1)),
				})
	return {
		"frame_id": frame_id,
		"page_index": get_page_index(),
		"page_count": get_page_count(),
		"selected_index": _selected_index,
		"selected_label": _selected_offer_label(),
		"surface_hint": "%s · %s" % [_scope_mode_label(), _scope_source_label()],
		"pool_size": _offer_pool.size(),
		"total_pages": 1,
		"current_page": 0,
		"slots": slots,
		"locked_count": _locked_offers.size(),
		"scope_mode": _scope_mode_label(),
		"scope_source": _scope_source_label(),
		"scope_counterparty": _scope_counterparty_name(),
	}


func get_transitions() -> Array:
	return [
		{"surface_id": "farm", "reason": "return to live instrument"},
		{"surface_id": "M", "reason": "manage active/ready contracts (canonical lifecycle view)"},
		{"surface_id": "V", "reason": "explain faction symbols and standings"},
	]


func _scope_counterparty_name() -> String:
	if _fb_name != "":
		return _fb_name
	if _pair_b_name != "":
		return _pair_b_name
	return ""


func _scope_source_label() -> String:
	if _pair_a_name != "" and _pair_b_name != "":
		return "N handoff"
	if _fb_name != "" and _fb_auto_scoped:
		return "auto (N to choose)"
	if _fb_name != "":
		return "N handoff"
	return "current biome"


func _scope_mode_label() -> String:
	var counterparty := _scope_counterparty_name()
	if counterparty == "":
		return "current biome"
	return "%s × %s" % [str(current_biome.name) if current_biome and "name" in current_biome else "—", counterparty]
