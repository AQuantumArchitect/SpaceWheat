class_name QuestBoard
extends "res://UI/Core/Surface.gd"

## C — Contract Surface, pipeline-aligned.
##
## Tabs map one-to-one onto the manifold→market→quest→arc pipeline:
##   T  manifold     — physics tracer: live H/L/marginals/tensions per qubit pair
##   Y  market       — offer pool with provenance + sort modes (1/2/3 = comfort/magnitude/tension)
##   U  commitments  — player-accepted active quests, plus history sub-view (1=Active, 2=History)
##   I  arc          — story flags timeline: acts → beats with predicate progress
##
## Within Market, sort modes are subordinate to the tab (chord 1/2/3) rather
## than spending tab slots on what is fundamentally one data source. Within
## Commitments, the 1/2 chord toggles Active vs History (completed/failed/expired).

# =============================================================================
# SIGNALS (used by OverlayManager + HUD listeners)
# =============================================================================

signal quest_accepted(quest: Dictionary)
signal quest_completed(quest_id: int, rewards: Dictionary)
signal quest_abandoned(quest_id: int)
# =============================================================================
# FRAME / KEY GRAMMAR
# =============================================================================

const PredicateGloss = preload("res://Core/Quests/PredicateGloss.gd")
const FRAME_MANIFOLD := "manifold"
const FRAME_MARKET := "market"
const FRAME_COMMITMENTS := "commitments"

const TAB_ROW := [
	{"key": "T", "frame": FRAME_MANIFOLD,    "name": "Manifold"},
	{"key": "Y", "frame": FRAME_MARKET,      "name": "Market"},
	{"key": "U", "frame": FRAME_COMMITMENTS, "name": "Commitments"},
	# Arc (I) moved to X / ControlsOverlay — the story spine reads next to Story.
]

# Item labels (G-;); keycode→slot via InputBindingRegistry.plot_index_for_keycode.
const ITEM_KEYS := ["G", "H", "J", "K", "L", ";"]
const MAX_VISIBLE_ITEMS: int = 6
const MARKET_FETCH_LIMIT: int = 24

# Armed-abandon quest id (confirm-chord law: Q arms, F confirms, else cancels).
var _abandon_arm_qid: int = -1

# Sort modes inside Market — chord 1/2/3 toggles within the tab.
const MARKET_SORT_BY_KEY := {
	KEY_1: MarketView.SortMode.COMFORT,
	KEY_2: MarketView.SortMode.MAGNITUDE,
	KEY_3: MarketView.SortMode.TENSION,
}
const MARKET_SORT_LABELS := {
	MarketView.SortMode.COMFORT:   "Comfort↓",
	MarketView.SortMode.MAGNITUDE: "Magnitude↓",
	MarketView.SortMode.TENSION:   "Tension↓",
}

# Sub-views inside Commitments — chord 1/2 toggles within the tab.
const COMMITMENTS_VIEW_BY_KEY := {
	KEY_1: "active",
	KEY_2: "history",
}
const COMMITMENTS_VIEW_LABELS := {
	"active":  "Active",
	"history": "History",
}

# =============================================================================
# COLORS
# =============================================================================
const COLOR_COMFORT_POS := Color(0.5, 0.9, 0.55, 1.0)
const COLOR_COMFORT_NEG := Color(0.95, 0.55, 0.5, 1.0)
const COLOR_COMFORT_MID := Color(0.85, 0.85, 0.6, 1.0)

# =============================================================================
# STATE
# =============================================================================

var quest_manager: Node = null
var current_biome: Node = null

var _pair_a_name: String = ""
var _pair_b_name: String = ""
var _nb_name: String = ""
var _nb_auto_scoped: bool = false

var _offer_pool: Array = []
var _selected_index: int = 0
var _market_status_note: String = ""

var _market_sort_mode: int = MarketView.SortMode.COMFORT
var _commitments_view: String = "active"

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
	navigation_mode = NavigationMode.NONE
	surface_id = "C"
	frame_ids = [FRAME_MANIFOLD, FRAME_MARKET, FRAME_COMMITMENTS]
	frame_id = FRAME_MARKET
	action_labels = {"Q": "—", "E": "Refresh", "R": "—", "F": "—"}

# =============================================================================
# EXTERNAL API (OverlayManager / TestAutorun)
# =============================================================================

func set_quest_manager(quest_mgr: Node) -> void:
	quest_manager = quest_mgr
	if quest_manager:
		if quest_manager.has_signal("quest_offered") and not quest_manager.quest_offered.is_connected(_on_quest_pool_changed):
			quest_manager.quest_offered.connect(_on_quest_pool_changed)
		if quest_manager.has_signal("active_quests_changed") and not quest_manager.active_quests_changed.is_connected(_on_quest_pool_changed):
			quest_manager.active_quests_changed.connect(_on_quest_pool_changed)

func set_biome(biome: Node) -> void:
	if biome != current_biome:
		current_biome = biome
		_offer_pool.clear()
		_selected_index = 0
		if visible:
			_render_all()

# =============================================================================
# UI BUILD
# =============================================================================

func _build_content(container: Control) -> void:
	_status_line = Label.new()
	_status_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_line.add_theme_font_size_override("font_size", 12)
	_status_line.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	container.add_child(_status_line)

	_scope_line = Label.new()
	_scope_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scope_line.add_theme_font_size_override("font_size", 11)
	_scope_line.add_theme_color_override("font_color", UIStyleFactory.COLOR_VALUE)
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
		lbl.name = "BoardTab_%s" % str(entry["key"])
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		lbl.gui_input.connect(_on_tab_gui_input.bind(str(entry["frame"])))
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
		cell.name = "BoardVerb_%s" % key
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_theme_constant_override("separation", 2)
		cell.custom_minimum_size = Vector2(90, 0)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
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

		_verb_chip_cells[key] = {"key": key_lbl, "label": label_lbl}

func _build_close_hint(container: Control) -> void:
	_close_hint = Label.new()
	_close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_close_hint.add_theme_font_size_override("font_size", 11)
	_close_hint.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	container.add_child(_close_hint)

# =============================================================================
# INPUT
# =============================================================================

func _on_unhandled_key(keycode: int, event: InputEvent) -> bool:
	if super._on_unhandled_key(keycode, event):
		_on_frame_changed_local()
		return true
	var item_idx := InputBindingRegistry.plot_index_for_keycode(keycode, ITEM_KEYS.size())
	if item_idx >= 0:
		_select(item_idx)
		return true
	if frame_id == FRAME_MARKET and MARKET_SORT_BY_KEY.has(keycode):
		_market_sort_mode = int(MARKET_SORT_BY_KEY[keycode])
		_selected_index = 0
		_render_all()
		return true
	if frame_id == FRAME_COMMITMENTS and COMMITMENTS_VIEW_BY_KEY.has(keycode):
		_disarm_abandon(true)
		_commitments_view = str(COMMITMENTS_VIEW_BY_KEY[keycode])
		_selected_index = 0
		_render_all()
		return true
	return false

func _on_frame_changed(_new_frame_id: String, _prev_frame_id: String) -> void:
	_on_frame_changed_local()

func _on_frame_changed_local() -> void:
	_disarm_abandon(true)
	_selected_index = 0
	_render_all()

func _on_activated() -> void:
	super._on_activated()
	# The market must be LIVE the moment the board opens. The old flow only
	# filled the offer pool on an E press, so the board always opened empty —
	# with a hint that lied about R rerolling ("opens to an empty Market with
	# no explanation", playtest 2).
	_ensure_biome()
	_refresh_pool()
	_render_all()

# =============================================================================
# MOUSE PARITY — every keyboard verb has a click twin (EscapeMenu pattern).
# =============================================================================

func _on_tab_gui_input(event: InputEvent, target_frame: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		accept_event()
		set_frame(target_frame)

func _on_verb_chip_gui_input(event: InputEvent, key: String) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed):
		return
	accept_event()
	match key:
		"Q": _on_action_q()
		"E": _on_action_e()
		"R": _on_action_r()
		"F": _on_action_f()

func _on_row_gui_input(event: InputEvent, idx: int) -> void:
	# First click selects the row; a second click on the selected row fires
	# the primary verb (R: accept in Market, complete in Commitments).
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed):
		return
	accept_event()
	if idx == _selected_index:
		_on_action_r()
	else:
		_select(idx)

## Corner-toast feedback through the shell — board verbs must visibly land.
func _toast_feedback(text: String) -> void:
	var shell = InstrumentLocator.resolve_player_shell(self)
	if shell and shell.has_method("show_hint"):
		shell.show_hint(text, 2)

# =============================================================================
# VERB ACTIONS
# =============================================================================

func _on_action_q() -> void:
	# Q = leave / change current run state.
	match frame_id:
		FRAME_COMMITMENTS:
			_abandon_selected()  # leave the commitment behind
		_:
			pass

func _on_action_e() -> void:
	# E = pause + inspect / refresh.
	_disarm_abandon()
	match frame_id:
		FRAME_MANIFOLD:
			_refresh_pool()
			_render_all()
		FRAME_MARKET:
			_refresh_pool()
			_render_all()
			# Refresh must visibly land even when the list stays empty —
			# a silent E reads as a dead key (playtest 2).
			var n: int = _offer_pool.size()
			if n > 0:
				_toast_feedback("🛒 market refreshed — %d offer%s" % [n, "" if n == 1 else "s"])
			else:
				_toast_feedback("🛒 market refreshed — %s" % (_market_status_note if _market_status_note != "" else "no offers yet"))
		_:
			pass

func _on_action_r() -> void:
	# R = stay / commit current run state forward.
	_disarm_abandon()
	match frame_id:
		FRAME_MARKET:
			_accept_selected()  # commit the offer onto the run
		FRAME_COMMITMENTS:
			_complete_selected()  # commit the quest's reward forward
		_:
			pass

func _on_action_f() -> void:
	# F = pin/unpin a commitment. A locked commitment never expires, so you can accept a
	# contract you can't yet afford, go gather the deliverable, and come back to turn it in.
	# While an abandon is armed, F is its confirm (confirm-chord law).
	match frame_id:
		FRAME_COMMITMENTS:
			if _abandon_arm_qid >= 0:
				_abandon_confirmed()
			else:
				_toggle_lock_selected()
		_:
			pass

func _toggle_lock_selected() -> void:
	if quest_manager == null or not quest_manager.has_method("set_quest_locked"):
		return
	var rows: Array = _commitments_rows()
	if _selected_index < 0 or _selected_index >= rows.size():
		return
	var qid: int = int(rows[_selected_index].get("id", -1))
	if qid < 0:
		return
	quest_manager.set_quest_locked(qid, not quest_manager.is_quest_locked(qid))
	_render_all()

# =============================================================================
# INSPECT TEXT — what E pops up as a toast (OverlayBase calls get_inspect_text).
# =============================================================================

func get_inspect_text() -> String:
	match frame_id:
		FRAME_MARKET:      return _market_inspect_text()
		FRAME_COMMITMENTS: return _commitments_inspect_text()
		FRAME_MANIFOLD:    return _manifold_inspect_text()
		_:                 return ""

func _market_inspect_text() -> String:
	if _selected_index < 0:
		return ""
	var visible_list: Array = MarketView.sort_view(_offer_pool, _get_inventory(), _market_sort_mode)
	if _selected_index >= visible_list.size():
		return ""
	var offer: Dictionary = visible_list[_selected_index]
	var proj: Dictionary = offer.get("market_projection", {})
	var lines: Array[String] = []
	lines.append("%s · %s × %d" % [
		str(offer.get("faction", "?")),
		str(offer.get("resource", "?")),
		int(offer.get("quantity", 0)),
	])
	lines.append("[M %.2f s%.2f a%.2f e%+.2f]" % [
		float(proj.get("market_score", 0.0)),
		float(proj.get("scarcity", 0.0)),
		float(proj.get("alignment", 0.0)),
		float(proj.get("directional_edge", 0.0)),
	])
	# Faction↔biome resonance: how the faction's 12 axial preferences sit with
	# this biome's live quantum observables (FactionStateMatcher). Physics-derived
	# mood, not flavor dice.
	if offer.has("faction_alignment"):
		var res: float = float(offer.get("faction_alignment", 0.0))
		lines.append("resonance %.2f — %s" % [res, _resonance_gloss(res)])
		var prefs := str(offer.get("faction_preferences", ""))
		if prefs != "":
			lines.append("their axioms: %s" % prefs)
		# The scalar decomposed: the axiom that sings and the one that grates —
		# explain_alignment rows, the same terms the resonance number averages.
		var best: Dictionary = {}
		var worst: Dictionary = {}
		for r in offer.get("faction_axiom_rows", []):
			if not (r is Dictionary) or not bool(r.get("known", false)):
				continue
			if best.is_empty() or float(r.fit) > float(best.fit):
				best = r
			if worst.is_empty() or float(r.fit) < float(worst.fit):
				worst = r
		if not best.is_empty():
			lines.append("sings: %s — they want %s, it reads %s (%.2f)" % [
					str(best.channel), str(best.want), str(best.have), float(best.fit)])
		if not worst.is_empty() and str(worst.get("channel", "")) != str(best.get("channel", "")):
			lines.append("grates: %s — they want %s, it reads %s (%.2f)" % [
					str(worst.channel), str(worst.want), str(worst.have), float(worst.fit)])
	# Player↔faction kinship: how they sit with who YOU are becoming — geometric
	# mean of per-axis agreement between your identity ρ's principal axes and
	# their live alignment (FactionDensityMatrix.kinship; docs/glossary/soul.md).
	var kin_farm = InstrumentLocator.resolve_active_farm(self)
	if kin_farm != null and ("faction_density" in kin_farm) and kin_farm.faction_density != null \
			and kin_farm.faction_density.has_method("kinship"):
		var reg = kin_farm.faction_density.get_registry()
		var fac = reg.get_by_name(str(offer.get("faction", ""))) if reg != null else null
		var kin: float = kin_farm.faction_density.kinship(fac)
		if kin >= 0.0:
			lines.append("they and you: %.2f — %s" % [kin, FactionDensityMatrix.kinship_gloss(kin)])
	var explanation = offer.get("market_explanation", [])
	if explanation is Array:
		for line in explanation:
			lines.append(str(line))
	var farm = InstrumentLocator.resolve_active_farm(self)
	var card_tip: String = _faction_card_tooltip(str(offer.get("faction", "")), farm)
	if card_tip != "":
		lines.append("")
		lines.append(card_tip)
	return "\n".join(lines)

func _commitments_inspect_text() -> String:
	var rows: Array = _commitments_rows()
	if _selected_index < 0 or _selected_index >= rows.size():
		return ""
	var quest: Dictionary = rows[_selected_index]
	var farm = InstrumentLocator.resolve_active_farm(self)
	var card_tip: String = _faction_card_tooltip(str(quest.get("faction", "")), farm)
	if card_tip == "":
		return "%s · %s × %d" % [
			str(quest.get("faction", "?")),
			str(quest.get("resource", "?")),
			int(quest.get("quantity", 0)),
		]
	return card_tip

func _manifold_inspect_text() -> String:
	if current_biome == null or current_biome.quantum_computer == null:
		return ""
	var qc = current_biome.quantum_computer
	if qc.register_map == null:
		return ""
	var n: int = int(qc.register_map.num_qubits)
	if _selected_index < 0 or _selected_index >= n:
		return ""
	var pair = qc.get_emoji_pair_for_qubit(_selected_index) if qc.has_method("get_emoji_pair_for_qubit") else null
	if pair == null:
		return "qubit Q%d" % _selected_index
	var marg: Dictionary = qc.get_marginal(_selected_index, 1) if qc.has_method("get_marginal") else {}
	var p1: float = float(marg.get("p", 0.5))
	return "Q%d  ·  %s/%s\nmarginal pole_1 p = %.2f" % [_selected_index, str(pair.get("pole_0", "?")), str(pair.get("pole_1", "?")), p1]

# =============================================================================
# RENDER PIPELINE
# =============================================================================

# Rows read continuously-evolving state (berries N/M held/asked, quest progress
# bars) and froze at render-time values while the board stayed open (fleet #8:
# "berries 1/3 unchanged after the second incorporation"). Same heartbeat law
# as the action bar.
const BOARD_HEARTBEAT_S := 1.0
var _board_heartbeat_accum: float = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_board_heartbeat_accum += delta
	if _board_heartbeat_accum >= BOARD_HEARTBEAT_S:
		_board_heartbeat_accum = 0.0
		_render_all()


func _render_all() -> void:
	# A5: keep the selection valid after a row is removed (accept/claim/abandon shrink the
	# list, so a stale _selected_index would highlight the wrong row or nothing). Clamp to
	# the live row count → the cursor lands on the next/last item, not off the end.
	var _rc := _current_row_count()
	if _rc > 0:
		_selected_index = clampi(_selected_index, 0, _rc - 1)
	_refresh_status()
	_refresh_tab_row()
	_refresh_body()
	_refresh_verb_chips()
	_refresh_close_hint()

func _refresh_close_hint() -> void:
	if not _close_hint:
		return
	if frame_id == FRAME_MARKET:
		var sort_label := str(MARKET_SORT_LABELS.get(_market_sort_mode, "?"))
		_close_hint.text = "ESC close  ·  T Y U tabs  ·  [1] Comfort↓  [2] Magnitude↓  [3] Tension↓  ·  active: %s" % sort_label
	else:
		_close_hint.text = "ESC close   ·   T Y U tabs"

func _refresh_status() -> void:
	if not _status_line:
		return
	var biome_name: String = str(current_biome.name) if current_biome and "name" in current_biome else "—"
	var pool_n: int = _offer_pool.size()
	var inv_norm: float = MarketView._l2_norm(_get_inventory())
	var selected_label: String = _selected_label_for_tab()
	var page_idx: int = get_page_index()
	var page_count: int = maxi(1, get_page_count())
	_status_line.text = "%s · page %d/%d · selected: %s · |inv|=%.1f · pool=%d · %s" % [
		biome_name, page_idx, page_count,
		selected_label if selected_label != "" else "—",
		inv_norm, pool_n, frame_id,
	]
	if _market_status_note != "":
		_status_line.text += " · %s" % _market_status_note
	if _scope_line:
		_scope_line.text = "selected: %s · scope: %s · source: %s" % [
			selected_label if selected_label != "" else "—",
			_scope_mode_label(),
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
			lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_TAB_ACTIVE)
		else:
			lbl.text = "[%s] %s" % [key_str, str(entry["name"])]
			lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_TAB_IDLE)

func _refresh_body() -> void:
	if not _body_box:
		return
	for child in _body_box.get_children():
		# Detach BEFORE queue_free: doomed rows linger in-tree until end of
		# frame with the same names, so name-based lookups (probes, tools)
		# would race the freed twin of the row they meant.
		_body_box.remove_child(child)
		child.queue_free()
	match frame_id:
		FRAME_MANIFOLD:    _build_manifold_body()
		FRAME_MARKET:      _build_market_body()
		FRAME_COMMITMENTS: _build_commitments_body()

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
		if txt == "" or txt == "—":
			label_lbl.text = "—"
			label_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_ITEM_EMPTY)
			key_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_ITEM_EMPTY)
		else:
			label_lbl.text = txt
			label_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_VERB_ACTIVE)
			key_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_KEY_CHIP)
	push_action_label_strings(labels)

func _current_verb_labels() -> Dictionary:
	match frame_id:
		FRAME_MANIFOLD:
			return {"Q": "—", "E": "Refresh", "R": "—", "F": "—"}
		FRAME_MARKET:
			return {"Q": "—", "E": "Refresh", "R": "Accept", "F": "—"}
		FRAME_COMMITMENTS:
			if _abandon_arm_qid >= 0:
				return {"Q": "Cancel", "E": "—", "R": "—", "F": "⚠ Confirm Abandon"}
			var f_label := "Lock"
			var crows := _commitments_rows()
			if quest_manager and quest_manager.has_method("is_quest_locked") and _selected_index >= 0 and _selected_index < crows.size():
				if quest_manager.is_quest_locked(int(crows[_selected_index].get("id", -1))):
					f_label = "Unlock"
			return {"Q": "Abandon", "E": "—", "R": "Complete", "F": f_label}
	return {"Q": "—", "E": "—", "R": "—", "F": "—"}

# =============================================================================
# MANIFOLD BODY (T tab — physics tracer)
# =============================================================================

func _build_manifold_body() -> void:
	if _is_pair_scope_active():
		_build_manifold_edge_body()
		return
	_ensure_biome()
	if current_biome == null:
		_body_box.add_child(_make_muted_label("no neighborhood bound — load a live biome", 12))
		return
	var qc = current_biome.quantum_computer if "quantum_computer" in current_biome else null
	if qc == null or qc.register_map == null:
		_body_box.add_child(_make_muted_label("biome has no live quantum computer", 12))
		return

	# Header — biome-level scalars (purity, attractor gap)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	_body_box.add_child(header)

	var biome_name: String = str(current_biome.name) if "name" in current_biome else "—"
	var purity: float = current_biome.get_purity() if current_biome.has_method("get_purity") else -1.0
	var attractor: Dictionary = current_biome.get_attractor_state() if current_biome.has_method("get_attractor_state") else {}
	var gap: float = float(attractor.get("eigenvalue_gap", 0.0))

	var hdr_lbl := Label.new()
	hdr_lbl.add_theme_font_size_override("font_size", 12)
	hdr_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_VALUE)
	var purity_str: String = "—" if purity < 0.0 else "%.3f" % purity
	hdr_lbl.text = "%s · purity=%s · gap=%.3f · qubits=%d · %s" % [
		biome_name, purity_str, gap, int(qc.register_map.num_qubits),
		_scope_mode_label(),
	]
	header.add_child(hdr_lbl)

	# Per-qubit rows — first MAX_VISIBLE_ITEMS qubits get an item key chip.
	var num_q: int = int(qc.register_map.num_qubits)
	var rows_to_show: int = min(num_q, MAX_VISIBLE_ITEMS)
	for q in range(rows_to_show):
		_body_box.add_child(_make_manifold_row(qc, q, ITEM_KEYS[q], q == _selected_index))
	# Empty slots fill out the GHJKL; row.
	for i in range(rows_to_show, MAX_VISIBLE_ITEMS):
		_body_box.add_child(_make_empty_row(ITEM_KEYS[i]))
	if num_q > MAX_VISIBLE_ITEMS:
		_body_box.add_child(_make_muted_label("… %d more qubits not shown" % (num_q - MAX_VISIBLE_ITEMS), 10))

func _make_manifold_row(qc, qubit_idx: int, key_str: String, selected: bool) -> Control:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.10, 0.13, 0.85) if not selected else Color(0.18, 0.16, 0.10, 0.95)
	sb.border_color = Color(0.4, 0.35, 0.45, 0.5) if not selected else UIStyleFactory.COLOR_TAB_ACTIVE
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

	var pair: Dictionary = qc.get_emoji_pair_for_qubit(qubit_idx) if qc.has_method("get_emoji_pair_for_qubit") else {}
	var north: String = str(pair.get("north", ""))
	var south: String = str(pair.get("south", ""))
	var p1: float = qc.get_marginal(qubit_idx, 1) if qc.has_method("get_marginal") else 0.5
	var p0: float = 1.0 - p1

	var pair_lbl := Label.new()
	pair_lbl.text = "Q%d %s/%s" % [qubit_idx, north, south]
	pair_lbl.add_theme_font_size_override("font_size", 14)
	pair_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_TAB_ACTIVE if selected else UIStyleFactory.COLOR_ITEM_IDLE)
	pair_lbl.custom_minimum_size = Vector2(120, 0)
	hbox.add_child(pair_lbl)

	var marg_lbl := Label.new()
	marg_lbl.text = "p₀=%.2f %s · p₁=%.2f %s" % [p0, _ratio_bar(p0, 5), p1, _ratio_bar(p1, 5)]
	marg_lbl.add_theme_font_size_override("font_size", 12)
	marg_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_VALUE)
	marg_lbl.custom_minimum_size = Vector2(220, 0)
	hbox.add_child(marg_lbl)

	# Forward trace: count offers in pool whose pair matches this qubit's emojis.
	var offer_count: int = 0
	var tension_max: float = 0.0
	for offer in _offer_pool:
		var r: String = str(offer.get("resource", ""))
		if r == north or r == south:
			offer_count += 1
			tension_max = maxf(tension_max, float(offer.get("tension", 0.0)))

	var trace_lbl := Label.new()
	if offer_count > 0:
		trace_lbl.text = "→ %d offers · τ_max=%.2f" % [offer_count, tension_max]
		trace_lbl.add_theme_color_override("font_color", _tension_color(tension_max))
	else:
		trace_lbl.text = "→ —"
		trace_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	trace_lbl.add_theme_font_size_override("font_size", 11)
	trace_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(trace_lbl)

	return row

## Two-column edge view: emojis tradable across the active edge, with each
## biome's marginal + tension between them. Side A and B can each be either a
## live biome (read live QC marginals) or a neighborhood spec (read Lindblad
## steady-state marginals from spec).
func _build_manifold_edge_body() -> void:
	var marg_a: Dictionary = _resolve_marginals(_pair_a_name)
	var marg_b: Dictionary = _resolve_marginals(_pair_b_name)

	# Partition emojis: shared first (most informative), then A-only, then B-only.
	var shared: Array = []
	var a_only: Array = []
	var b_only: Array = []
	var seen: Dictionary = {}
	for e in marg_a.keys():
		seen[e] = true
		if marg_b.has(e):
			shared.append(e)
		else:
			a_only.append(e)
	for e in marg_b.keys():
		if not seen.has(e):
			b_only.append(e)

	# Score shared by tension desc; A-only / B-only by marginal desc.
	shared.sort_custom(func(x, y):
		return absf(float(marg_a[x].p) - float(marg_b[x].p)) > absf(float(marg_a[y].p) - float(marg_b[y].p)))
	a_only.sort_custom(func(x, y): return float(marg_a[x].p) > float(marg_a[y].p))
	b_only.sort_custom(func(x, y): return float(marg_b[x].p) > float(marg_b[y].p))

	var ordered: Array = shared + a_only + b_only

	# Header: edge identity + total tension + shared count.
	var total_tension: float = 0.0
	for e in shared:
		total_tension += absf(float(marg_a[e].p) - float(marg_b[e].p))
	var header := Label.new()
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", UIStyleFactory.COLOR_VALUE)
	header.text = "Edge %s ⊗ %s · τ_total=%.2f · shared=%d · A-only=%d · B-only=%d" % [
		_pair_a_name, _pair_b_name, total_tension, shared.size(), a_only.size(), b_only.size(),
	]
	_body_box.add_child(header)

	# Subheader columns.
	var col_hdr := HBoxContainer.new()
	col_hdr.add_theme_constant_override("separation", 10)
	_body_box.add_child(col_hdr)
	var key_pad := Label.new()
	key_pad.custom_minimum_size = Vector2(28, 0)
	col_hdr.add_child(key_pad)
	var emoji_pad := Label.new()
	emoji_pad.custom_minimum_size = Vector2(36, 0)
	col_hdr.add_child(emoji_pad)
	var col_a := Label.new()
	col_a.text = _pair_a_name
	col_a.add_theme_font_size_override("font_size", 11)
	col_a.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	col_a.custom_minimum_size = Vector2(180, 0)
	col_hdr.add_child(col_a)
	var col_b := Label.new()
	col_b.text = _pair_b_name
	col_b.add_theme_font_size_override("font_size", 11)
	col_b.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	col_b.custom_minimum_size = Vector2(180, 0)
	col_hdr.add_child(col_b)
	var col_t := Label.new()
	col_t.text = "tension · offers"
	col_t.add_theme_font_size_override("font_size", 11)
	col_t.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	col_hdr.add_child(col_t)

	# Rows.
	for i in range(MAX_VISIBLE_ITEMS):
		if i < ordered.size():
			var emoji: String = str(ordered[i])
			_body_box.add_child(_make_edge_row(emoji, marg_a, marg_b, ITEM_KEYS[i], i == _selected_index))
		else:
			_body_box.add_child(_make_empty_row(ITEM_KEYS[i]))
	if ordered.size() > MAX_VISIBLE_ITEMS:
		_body_box.add_child(_make_muted_label("… %d more emojis not shown" % (ordered.size() - MAX_VISIBLE_ITEMS), 10))

func _make_edge_row(emoji: String, marg_a: Dictionary, marg_b: Dictionary, key_str: String, selected: bool) -> Control:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.10, 0.13, 0.85) if not selected else Color(0.18, 0.16, 0.10, 0.95)
	sb.border_color = Color(0.4, 0.35, 0.45, 0.5) if not selected else UIStyleFactory.COLOR_TAB_ACTIVE
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

	var emoji_lbl := Label.new()
	emoji_lbl.text = emoji
	emoji_lbl.add_theme_font_size_override("font_size", 16)
	emoji_lbl.custom_minimum_size = Vector2(36, 0)
	hbox.add_child(emoji_lbl)

	hbox.add_child(_make_side_label(marg_a.get(emoji, null)))
	hbox.add_child(_make_side_label(marg_b.get(emoji, null)))

	var has_a: bool = marg_a.has(emoji)
	var has_b: bool = marg_b.has(emoji)
	var tension: float = 0.0
	if has_a and has_b:
		tension = absf(float(marg_a[emoji].p) - float(marg_b[emoji].p))

	var offer_count: int = 0
	for offer in _offer_pool:
		if str(offer.get("resource", "")) == emoji:
			offer_count += 1

	var trace_lbl := Label.new()
	trace_lbl.add_theme_font_size_override("font_size", 11)
	if has_a and has_b:
		trace_lbl.text = "τ=%.2f · →%d offers" % [tension, offer_count]
		trace_lbl.add_theme_color_override("font_color", _tension_color(tension))
	elif offer_count > 0:
		trace_lbl.text = "→%d offers" % offer_count
		trace_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	else:
		trace_lbl.text = "—"
		trace_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	trace_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(trace_lbl)
	return row

func _make_side_label(side) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.custom_minimum_size = Vector2(180, 0)
	if side == null:
		lbl.text = "(—)"
		lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_ITEM_EMPTY)
	else:
		var p: float = float(side.get("p", 0.0))
		var q: int = int(side.get("q", -1))
		if q < 0:
			# Neighborhood spec — no live qubit; show steady-state marginal only.
			lbl.text = "spec  p=%.2f %s" % [p, _ratio_bar(p, 5)]
		else:
			lbl.text = "Q%d  p=%.2f %s" % [q, p, _ratio_bar(p, 5)]
		lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_VALUE)
	return lbl

## Resolve any biome name to its emoji-marginals dict. Tries live biome first
## (reads QC marginals), then falls back to neighborhood spec from BiomeRegistry
## (reads Lindblad steady-state marginals from the spec). Format:
##   {emoji → {q: int, p: float, pole: int}}
##   q = -1 indicates a static-spec source (no live qubit).
func _resolve_marginals(biome_name: String) -> Dictionary:
	if biome_name == "":
		return {}
	var live = _resolve_live_biome(biome_name)
	if live != null and "quantum_computer" in live:
		return _emoji_marginals_with_qubit(live.quantum_computer)
	# Neighborhood / static spec path.
	var br = BiomeRegistry.get_shared()
	if br == null:
		return {}
	var spec = br.get_by_name(biome_name)
	if spec == null:
		return {}
	var static_marg: Dictionary = MarketLattice._static_marginals_from_spec(spec)
	var out: Dictionary = {}
	for e in static_marg.keys():
		out[str(e)] = {"q": -1, "p": float(static_marg[e]), "pole": -1}
	return out

## {emoji → {q: qubit_idx, p: marginal_for_this_emoji, pole: 0|1}} from a live QC.
func _emoji_marginals_with_qubit(qc) -> Dictionary:
	var out: Dictionary = {}
	if qc == null or qc.register_map == null:
		return out
	var n: int = int(qc.register_map.num_qubits)
	for q in range(n):
		var pair: Dictionary = qc.get_emoji_pair_for_qubit(q) if qc.has_method("get_emoji_pair_for_qubit") else {}
		var north: String = str(pair.get("north", ""))
		var south: String = str(pair.get("south", ""))
		var p1: float = qc.get_marginal(q, 1) if qc.has_method("get_marginal") else 0.5
		if north != "":
			out[north] = {"q": q, "p": 1.0 - p1, "pole": 0}
		if south != "":
			out[south] = {"q": q, "p": p1, "pole": 1}
	return out

# =============================================================================
# MARKET BODY (Y tab — offer pool with provenance)
# =============================================================================

func _build_market_body() -> void:
	var visible_offers: Array = _get_visible_offers()
	if visible_offers.is_empty():
		# Honest empty state: say WHY (the status note from _refresh_pool names
		# the failing stage) and what actually helps. The old default said
		# "press R to reroll" — R accepts, it never rerolled anything.
		var empty_msg: String = _market_status_note
		if empty_msg == "":
			empty_msg = "no offers here yet"
		empty_msg += "\nthe market follows your active biome — walk somewhere with factions, or press E to refresh"
		_body_box.add_child(_make_muted_label(empty_msg, 12))
		return
	for i in range(MAX_VISIBLE_ITEMS):
		if i < visible_offers.size():
			var offer_row := _make_offer_row(visible_offers[i], ITEM_KEYS[i], i == _selected_index)
			offer_row.name = "BoardRow_%d" % i
			offer_row.gui_input.connect(_on_row_gui_input.bind(i))
			_body_box.add_child(offer_row)
		else:
			_body_box.add_child(_make_empty_row(ITEM_KEYS[i]))

## What the contract PAYS, in player language. Icon contracts teach a word;
## resource contracts pay their pre-rolled bundle (top entries, biggest first).
func _offer_reward_text(offer: Dictionary) -> String:
	var icon_n := str(offer.get("reward_icon_north", offer.get("reward_north", "")))
	var icon_s := str(offer.get("reward_icon_south", offer.get("reward_south", "")))
	if icon_n != "" and icon_s != "":
		return "teaches %s%s" % [icon_n, icon_s]
	var rewards = offer.get("reward_resources", {})
	if rewards is Dictionary and not rewards.is_empty():
		var entries: Array = []
		for emoji in rewards:
			entries.append({"emoji": str(emoji), "amount": float(rewards[emoji])})
		entries.sort_custom(func(a, b): return a.amount > b.amount)
		var parts: PackedStringArray = []
		for e in entries.slice(0, 3):
			parts.append("%s×%d" % [e.emoji, int(round(e.amount))])
		if entries.size() > 3:
			parts.append("…")
		return "pays " + " ".join(parts)
	return "pays ?"


func _make_offer_row(offer: Dictionary, key_str: String, selected: bool) -> Control:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.10, 0.13, 0.85) if not selected else Color(0.18, 0.16, 0.10, 0.95)
	sb.border_color = Color(0.4, 0.35, 0.45, 0.5) if not selected else UIStyleFactory.COLOR_TAB_ACTIVE
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

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	row.add_child(vbox)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(top_hbox)

	top_hbox.add_child(_make_key_chip(key_str, selected))

	var faction_lbl := Label.new()
	faction_lbl.text = str(offer.get("faction", "?"))
	faction_lbl.add_theme_font_size_override("font_size", 13)
	faction_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_TAB_ACTIVE if selected else UIStyleFactory.COLOR_ITEM_IDLE)
	faction_lbl.custom_minimum_size = Vector2(160, 0)
	faction_lbl.clip_text = true
	top_hbox.add_child(faction_lbl)

	var ask_lbl := Label.new()
	ask_lbl.text = "%s × %d" % [str(offer.get("resource", "?")), int(offer.get("quantity", 0))]
	ask_lbl.add_theme_font_size_override("font_size", 16)
	ask_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_VALUE)
	ask_lbl.custom_minimum_size = Vector2(110, 0)
	top_hbox.add_child(ask_lbl)

	var share: float = float(offer.get("view_share", 0.0))
	var depth: float = float(offer.get("view_depth", 0.0))
	var comfort: float = float(offer.get("view_comfort", 0.0))
	# The DEAL must read as a deal: give → get. The payout was never rendered
	# ("(s=0.91 d=0.07 c+0.84)" dev-speak instead), so a stranger could not
	# trade toward the resource they needed — the whole trade loop was blind.
	# The raw stats live on in the tooltip (and E-inspect keeps the details).
	var view_lbl := Label.new()
	view_lbl.text = "→ %s   %s" % [_offer_reward_text(offer), _comfort_bar(comfort, 5)]
	view_lbl.tooltip_text = "share %.2f · depth %.2f · comfort %+.2f" % [share, depth, comfort]
	view_lbl.add_theme_font_size_override("font_size", 13)
	view_lbl.add_theme_color_override("font_color", _comfort_color(comfort))
	view_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(view_lbl)

	# Provenance line — biome / qubit pair / tension. Traces back to T.
	var biome_a: String = str(offer.get("pair_a", ""))
	var biome_b: String = str(offer.get("pair_b", str(offer.get("biome", ""))))
	var tension: float = float(offer.get("tension", 0.0))
	var prov_lbl := Label.new()
	prov_lbl.add_theme_font_size_override("font_size", 10)
	prov_lbl.add_theme_color_override("font_color", _tension_color(tension))
	if biome_a != "" and biome_b != "":
		prov_lbl.text = "    from %s ⊗ %s · τ=%.2f" % [biome_a, biome_b, tension]
	else:
		prov_lbl.text = "    from %s · τ=%.2f" % [biome_b, tension]
	vbox.add_child(prov_lbl)

	# Substrate quartet kept on tooltip.
	var proj: Dictionary = offer.get("market_projection", {})
	var quartet_tip := "[M %.2f s%.2f a%.2f e%+.2f]" % [
		float(proj.get("market_score", 0.0)),
		float(proj.get("scarcity", 0.0)),
		float(proj.get("alignment", 0.0)),
		float(proj.get("directional_edge", 0.0)),
	]
	var explanation = offer.get("market_explanation", [])
	if explanation is Array and not explanation.is_empty():
		var lines: PackedStringArray = []
		for line in explanation:
			lines.append(str(line))
		quartet_tip += "\n" + "\n".join(lines)
	# Append faction-card summary so the player sees who's offering.
	var farm = InstrumentLocator.resolve_active_farm(self)
	var card_tip: String = _faction_card_tooltip(str(offer.get("faction", "")), farm)
	if card_tip != "":
		quartet_tip += "\n\n" + card_tip
	row.tooltip_text = quartet_tip

	return row

# =============================================================================
# COMMITMENTS BODY (U tab — only player-accepted, no ARC)
# =============================================================================

func _build_commitments_body() -> void:
	# View toggle hint: shows current sub-view + 1/2 chord.
	var view_label: String = str(COMMITMENTS_VIEW_LABELS.get(_commitments_view, "?"))
	var hint := Label.new()
	hint.text = "%s   ·   1=Active  2=History" % view_label
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	_body_box.add_child(hint)

	var rows: Array = _commitments_rows()
	if rows.is_empty():
		var empty_msg: String = "no past contracts yet" if _commitments_view == "history" \
			else "no active or ready contracts — accept some via Y (Market)"
		_body_box.add_child(_make_muted_label(empty_msg, 12))
		return
	for i in range(MAX_VISIBLE_ITEMS):
		if i < rows.size():
			var c_row := _make_commitment_row(rows[i], ITEM_KEYS[i], i == _selected_index)
			c_row.name = "BoardRow_%d" % i
			c_row.gui_input.connect(_on_row_gui_input.bind(i))
			_body_box.add_child(c_row)
		else:
			_body_box.add_child(_make_empty_row(ITEM_KEYS[i]))
	if rows.size() > MAX_VISIBLE_ITEMS:
		_body_box.add_child(_make_muted_label(
			"… %d more not shown" % (rows.size() - MAX_VISIBLE_ITEMS), 10))

func _make_commitment_row(quest: Dictionary, key_str: String, selected: bool) -> Control:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.10, 0.13, 0.85) if not selected else Color(0.18, 0.16, 0.10, 0.95)
	sb.border_color = Color(0.4, 0.35, 0.45, 0.5) if not selected else UIStyleFactory.COLOR_TAB_ACTIVE
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

	var status: String = str(quest.get("status", "")).to_lower()
	var is_history: bool = status in ["completed", "failed", "expired"]

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	row.add_child(vbox)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(hbox)

	hbox.add_child(_make_key_chip(key_str, selected))

	var status_lbl := Label.new()
	if is_history:
		match status:
			"completed": status_lbl.text = "✅"
			"failed":    status_lbl.text = "❌"
			"expired":   status_lbl.text = "⌛"
			_:           status_lbl.text = "·"
		status_lbl.add_theme_font_size_override("font_size", 14)
		status_lbl.custom_minimum_size = Vector2(28, 0)
	else:
		status_lbl.text = "[%s]" % status.to_upper()
		status_lbl.add_theme_font_size_override("font_size", 11)
		status_lbl.add_theme_color_override("font_color", _status_color(quest.get("status", "")))
		status_lbl.custom_minimum_size = Vector2(70, 0)
	hbox.add_child(status_lbl)

	var faction_lbl := Label.new()
	faction_lbl.text = str(quest.get("faction", "?"))
	faction_lbl.add_theme_font_size_override("font_size", 13)
	faction_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_TAB_ACTIVE if selected else UIStyleFactory.COLOR_ITEM_IDLE)
	faction_lbl.custom_minimum_size = Vector2(170, 0)
	faction_lbl.clip_text = true
	hbox.add_child(faction_lbl)

	var ask_lbl := Label.new()
	ask_lbl.text = _commitment_ask_text(quest, not is_history)
	ask_lbl.add_theme_font_size_override("font_size", 16)
	ask_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_VALUE)
	ask_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(ask_lbl)

	# Timed contracts died in silence — the deadline lived nowhere on this
	# board, and failure surfaced only in History as "timeout" (two sweep
	# runners burned contracts on it). The heartbeat re-render makes this a
	# live countdown for free.
	if not is_history and quest_manager != null and quest_manager.has_method("get_quest_time_remaining"):
		var left: float = quest_manager.get_quest_time_remaining(int(quest.get("id", -1)))
		if left >= 0.0:
			var clock_lbl := Label.new()
			clock_lbl.text = "⌛ %d:%02d" % [int(left) / 60, int(left) % 60]
			clock_lbl.add_theme_font_size_override("font_size", 12)
			clock_lbl.add_theme_color_override("font_color",
				UIStyleFactory.COLOR_MUTED if left > 30.0 else Color(0.9, 0.45, 0.35))
			hbox.add_child(clock_lbl)

	# History tail: reward summary for completions, reason for failures.
	if is_history:
		var tail: String = ""
		if status == "completed":
			tail = _format_reward_summary(quest.get("reward_payload", {}))
		elif status == "failed":
			tail = "reason: %s" % str(quest.get("failure_reason", "?"))
		elif status == "expired":
			tail = "expired"
		if tail != "":
			var tail_lbl := Label.new()
			tail_lbl.text = "    " + tail
			tail_lbl.add_theme_font_size_override("font_size", 11)
			tail_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
			vbox.add_child(tail_lbl)

	# Active non-delivery quests: soft progress bar — watching it fill IS the teaching.
	if not is_history:
		var prog := float(quest.get("progress", quest.get("predicate_score", 0.0)))
		var qt = quest.get("type", 0)
		var qti := int(qt) if (typeof(qt) == TYPE_INT or typeof(qt) == TYPE_FLOAT) else int(QuestTypes.Type.DELIVERY)
		if qti != int(QuestTypes.Type.DELIVERY) and prog > 0.0:
			var filled := int(round(clampf(prog, 0.0, 1.0) * 10.0))
			var bar := Label.new()
			bar.text = "    [%s%s] %d%%" % ["█".repeat(filled), "░".repeat(10 - filled), int(round(prog * 100.0))]
			bar.add_theme_font_size_override("font_size", 11)
			bar.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
			vbox.add_child(bar)

	# Tutorial hint sub-line (Act-0 onboarding — tells the player exactly what to do).
	var hint := str(quest.get("tutorial_hint", ""))
	if hint != "":
		var hint_lbl := Label.new()
		hint_lbl.text = "    💡 " + hint
		hint_lbl.add_theme_font_size_override("font_size", 10)
		hint_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
		vbox.add_child(hint_lbl)

	# Tooltip: faction-card summary so hovering shows who's behind the contract.
	var farm = InstrumentLocator.resolve_active_farm(self)
	var card_tip: String = _faction_card_tooltip(str(quest.get("faction", "")), farm)
	if card_tip != "":
		row.tooltip_text = card_tip

	return row

## The "ask" line for a commitment row: delivery shows held/asked progress; quantum quests show
## the steerable objective (observable → target) so the player sees what they're aiming the state at.
func _commitment_ask_text(quest: Dictionary, show_held: bool = false) -> String:
	var t = quest.get("type", QuestTypes.Type.DELIVERY)
	var ti := int(t) if (typeof(t) == TYPE_INT or typeof(t) == TYPE_FLOAT) else int(QuestTypes.Type.DELIVERY)
	if ti == int(QuestTypes.Type.DELIVERY):
		var emoji := str(quest.get("resource", "?"))
		var qty := int(quest.get("quantity", 0))
		# "× 11" alone read as a cycle count to playtesters — held/asked names the goal.
		if show_held:
			var held := 0
			var held_farm = InstrumentLocator.resolve_active_farm(self)
			if held_farm and held_farm.economy:
				held = int(held_farm.economy.get_resource_units(emoji))
			return "%s %d/%d held" % [emoji, held, qty]
		return "%s × %d" % [emoji, qty]
	if quest.has("observable"):
		var obs_label := str(quest.get("observable", "?"))
		# Player-facing names for internal observable keys.
		if obs_label == "max_mutual_information":
			obs_label = "entanglement (MI)"
		elif obs_label.begins_with("population:"):
			obs_label = "%s population" % obs_label.trim_prefix("population:")
		elif obs_label.begins_with("balance:"):
			var pr := obs_label.trim_prefix("balance:").split("/")
			if pr.size() == 2:
				obs_label = "%s over %s" % [pr[0], pr[1]]
		return "%s → %.2f" % [obs_label, float(quest.get("target", 0.0))]
	if quest.has("target_coherence"):
		return "coherence → %.2f" % float(quest.get("target_coherence", 0.0))
	# Composed (multi) asks: predicates joined as threads of one weave.
	var preds = quest.get("state_predicates", [])
	if preds is Array and not preds.is_empty():
		var parts: Array[String] = []
		for p in preds:
			if p is Dictionary:
				parts.append(PredicateGloss.summary(p, quest_manager))
		if not parts.is_empty():
			return " ∧ ".join(parts)
	return QuestTypes.get_type_name(ti)


func _faction_card_tooltip(quest_name: String, farm) -> String:
	if quest_name == "" or farm == null:
		return ""
	var card: Dictionary = FactionCard.gather(quest_name, farm)
	if not bool(card.get("present", false)):
		return ""
	var standing: float = float(card.get("standing", 0.0))
	var cloud_arr: Array = card.get("cloud", [])
	var biomes_arr: Array = card.get("biomes_of_presence", [])
	var lines: Array[String] = []
	lines.append("%s  ·  standing %+.2f" % [quest_name, standing])
	if not cloud_arr.is_empty():
		lines.append("speaks: " + " ".join(cloud_arr))
	if not biomes_arr.is_empty():
		lines.append("biomes: " + ", ".join(biomes_arr))
	return "\n".join(lines)


## Words for a faction's resonance with a biome — the alignment of its 12 axial
## preferences against the biome's live quantum observables, in [0, 1].
func _resonance_gloss(a: float) -> String:
	if a >= 0.75:
		return "this place sings to them"
	if a >= 0.55:
		return "at ease here"
	if a >= 0.35:
		return "wary of this place"
	return "restless — the biome grates on their axioms"


## Compact reward-payload summary for history rows.
func _format_reward_summary(rewards) -> String:
	if not (rewards is Dictionary):
		return ""
	var parts: Array[String] = []
	var resource_rewards = rewards.get("resource_rewards", {})
	if resource_rewards is Dictionary:
		for k in resource_rewards:
			parts.append("%s×%d" % [str(k), int(resource_rewards[k])])
	var learned_pairs = rewards.get("learned_pairs", [])
	if learned_pairs is Array:
		for p in learned_pairs:
			if p is Dictionary:
				parts.append("%s/%s" % [str(p.get("north", "?")), str(p.get("south", "?"))])
	return "→ " + ", ".join(parts) if not parts.is_empty() else ""

func _commitments_rows() -> Array:
	var rows: Array = []
	if _commitments_view == "history":
		if quest_manager:
			if "completed_quests" in quest_manager and quest_manager.completed_quests is Array:
				for q in quest_manager.completed_quests:
					rows.append(q)
			if "failed_quests" in quest_manager and quest_manager.failed_quests is Array:
				for q in quest_manager.failed_quests:
					rows.append(q)
		# Newest first by terminal timestamp.
		rows.sort_custom(func(a, b):
			var ta: int = int(a.get("completed_at", a.get("failed_at", 0)))
			var tb: int = int(b.get("completed_at", b.get("failed_at", 0)))
			return ta > tb
		)
		return rows
	# Default "active" view. Insertion (dict) order is a CONTRACT: the arc
	# claim flow re-selects index 0 after a list shift (apprentice Mill
	# mechanic), and reordering broke the campaign (act3_5 mill_wakes went
	# dark when this was briefly newest-first). The just-accepted contract is
	# surfaced by the accept toast + ContractChip pin instead.
	if quest_manager and "active_quests" in quest_manager and quest_manager.active_quests is Dictionary:
		for q in quest_manager.active_quests.values():
			rows.append(q)
	return rows

# =============================================================================
# MARKET POOL + VIEW (preserved logic, sort uses _market_sort_mode)
# =============================================================================

func _refresh_pool() -> void:
	_offer_pool.clear()
	_market_status_note = ""
	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm == null:
		_market_status_note = "market unavailable: no active farm"
		return

	if not farm.has_method("_ensure_market_lattice"):
		_market_status_note = "market unavailable: neighborhood lattice required"
		return

	var lattice = farm._ensure_market_lattice()
	if lattice == null:
		_market_status_note = "market unavailable: neighborhood lattice required"
		return

	# Explicit pair scope — opt-in only (OverlayManager / neighborhood-graph hands the board a
	# specific live↔live edge via set_pair_scope). The auto-scope below never sets these fields.
	if _is_pair_scope_active():
		var biome_a = _resolve_live_biome(_pair_a_name)
		var biome_b = _resolve_live_biome(_pair_b_name)
		if biome_a == null or biome_b == null:
			_market_status_note = "pair market unavailable: live biome missing"
			return
		var pair_offers: Array = lattice.propose_pair_offers(biome_a, biome_b, MARKET_FETCH_LIMIT)
		if pair_offers.is_empty():
			_market_status_note = "pair market empty: no offers for %s × %s" % [_pair_a_name, _pair_b_name]
			return
		_offer_pool = _adapt_contracts_for_view(pair_offers)
		MarketView.annotate(_offer_pool, _get_inventory())
		return

	_ensure_biome()
	if current_biome == null:
		_market_status_note = "market unavailable: no current neighborhood"
		return

	# Neighborhood-primary: ONE market across the active biome's neighborhood. This is the
	# market the player sees wherever they stand — the local faction offers (Millwright /
	# Hearth / …). It is NOT overridden by a live↔live tension pair just because a second
	# biome happens to be evolving; that cross-biome edge is opt-in (set_pair_scope) or the
	# fallback below when the active biome has no neighborhood at all.
	_nb_name = lattice.best_neighborhood_name(current_biome)
	_nb_auto_scoped = _nb_name != ""
	if _nb_name != "":
		var raw: Array = lattice.propose_neighborhood_offers_scoped(current_biome, _nb_name, MARKET_FETCH_LIMIT)
		if raw.is_empty():
			_market_status_note = "market empty: no neighborhood offers for %s" % _nb_name
			return
		_offer_pool = _adapt_contracts_for_view(raw)
		MarketView.annotate(_offer_pool, _get_inventory())
		return

	# Fallback: the active biome has no neighborhood spec — fall back to the highest-tension
	# live↔live edge so the board is never empty. Uses local vars only; does NOT pin a
	# persistent pair scope (so a neighborhood reappearing isn't shadowed by a stale pair).
	var all_biomes: Dictionary = farm.grid.get_all_biomes() if farm.grid and farm.grid.has_method("get_all_biomes") else {}
	var best_pair: Dictionary = lattice.best_live_tension_pair(all_biomes)
	if not best_pair.is_empty():
		var fb_a = _resolve_live_biome(str(best_pair.get("a", "")))
		var fb_b = _resolve_live_biome(str(best_pair.get("b", "")))
		if fb_a != null and fb_b != null:
			var fb_offers: Array = lattice.propose_pair_offers(fb_a, fb_b, MARKET_FETCH_LIMIT)
			if not fb_offers.is_empty():
				_offer_pool = _adapt_contracts_for_view(fb_offers)
				MarketView.annotate(_offer_pool, _get_inventory())
				return
	_market_status_note = "market unavailable: no neighborhood partner"

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

func _adapt_contracts_for_view(contracts: Array) -> Array:
	# Route every contract through the ONE canonical construction path so the
	# keyboard market is identical to the offer_all_faction_quests pool: DELIVER
	# contracts pre-roll coupling-tied RESOURCE rewards (incl. scarce ones like 🔨)
	# and get faction-voiced text. Previously this only called to_quest_offer_dict(),
	# so the board market silently lacked reward_resources — the player could never
	# earn scarce resources by keyboard even though the rig pool had them.
	var out: Array = []
	for c in contracts:
		if c == null:
			continue
		var quest: Dictionary = QuestPipeline.from_market_contract(c, current_biome)
		if quest.is_empty():
			continue
		out.append(quest)
	return out

func set_pair_scope(name_a: String, name_b: String) -> void:
	_pair_a_name = name_a
	_pair_b_name = name_b
	_nb_name = ""
	_nb_auto_scoped = false
	_offer_pool.clear()
	_selected_index = 0
	if _body_box != null:
		_refresh_pool()
		_render_all()

func clear_pair_scope() -> void:
	if _pair_a_name == "" and _pair_b_name == "" and _nb_name == "":
		return
	_pair_a_name = ""
	_pair_b_name = ""
	_nb_name = ""
	_nb_auto_scoped = false
	_offer_pool.clear()
	_selected_index = 0

func _get_visible_offers() -> Array:
	var sorted: Array = MarketView.sort_view(_offer_pool, _get_inventory(), _market_sort_mode)
	return sorted

func _get_selected_offer() -> Dictionary:
	if frame_id != FRAME_MARKET:
		return {}
	var visible_offers: Array = _get_visible_offers()
	if _selected_index < 0 or _selected_index >= visible_offers.size():
		return {}
	return visible_offers[_selected_index]

func _selected_label_for_tab() -> String:
	match frame_id:
		FRAME_MANIFOLD:
			_ensure_biome()
			if current_biome == null:
				return ""
			var qc = current_biome.quantum_computer if "quantum_computer" in current_biome else null
			if qc == null or qc.register_map == null:
				return ""
			if _selected_index < 0 or _selected_index >= int(qc.register_map.num_qubits):
				return ""
			var pair: Dictionary = qc.get_emoji_pair_for_qubit(_selected_index) if qc.has_method("get_emoji_pair_for_qubit") else {}
			return "Q%d %s/%s" % [_selected_index, str(pair.get("north", "")), str(pair.get("south", ""))]
		FRAME_MARKET:
			var offer: Dictionary = _get_selected_offer()
			if offer.is_empty():
				return ""
			return "%s × %d" % [str(offer.get("resource", "?")), int(offer.get("quantity", 0))]
		FRAME_COMMITMENTS:
			var rows: Array = _commitments_rows()
			if _selected_index < 0 or _selected_index >= rows.size():
				return ""
			return "%s × %d" % [str(rows[_selected_index].get("resource", "?")), int(rows[_selected_index].get("quantity", 0))]
	return ""

func _get_inventory() -> Dictionary:
	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm == null or farm.economy == null:
		return {}
	return farm.economy.get_all_resources()

func _get_economy():
	var farm = InstrumentLocator.resolve_active_farm(self)
	return farm.economy if farm else null

func _ensure_biome() -> void:
	# The neighborhood market follows the player: ALWAYS re-resolve to the ACTIVE biome
	# (where the player currently stands) so switching biomes re-scopes the board. A sticky
	# current_biome was pinning the market to whatever biome was first touched, which left
	# the player seeing one biome's neighborhood market everywhere.
	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm == null:
		return
	# Primary focus signal: the ActiveBiomeManager's active biome (the biome-row TYUIOP keys
	# drive this in both live play and headless drive). Re-resolve every refresh.
	var bname := ""
	var abm = (Engine.get_main_loop().root.get_node_or_null("/root/ActiveBiomeManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if abm and abm.has_method("get_active_biome"):
		bname = str(abm.get_active_biome())
	# Fallbacks: instrument's selected biome, then the farm's neutral/current biome.
	if bname == "":
		var inst = InstrumentLocator.resolve_quantum_instrument(self)
		if inst and "current_biome" in inst:
			bname = str(inst.current_biome)
	var obs = farm.observation_frame if "observation_frame" in farm else null
	if bname == "" and obs and obs.has_method("get_neutral_biome"):
		bname = str(obs.get_neutral_biome())
	if bname != "" and farm.grid and farm.grid.has_biome(bname):
		current_biome = farm.grid.get_biome(bname)

# =============================================================================
# VERB DISPATCHERS
# =============================================================================

func _accept_selected() -> void:
	var offer: Dictionary = _get_selected_offer()
	if offer.is_empty() or quest_manager == null:
		return
	if quest_manager.has_method("accept_quest"):
		# The lattice can re-propose a contract the player already holds —
		# name that case honestly instead of blaming the cost.
		var offer_id = offer.get("id", -1)
		if "active_quests" in quest_manager and quest_manager.active_quests.has(offer_id):
			_toast_feedback("• already accepted — it's in Commitments [U]")
			return
		if quest_manager.accept_quest(offer):
			quest_accepted.emit(offer)
			# Accepting must CHANGE something on screen (playtest 2: "pressing
			# R had no visual effect on the contract itself"). Re-pull the pool
			# (the accepted offer leaves the market) and say where it went.
			_refresh_pool()
			_render_all()
			_toast_feedback("✓ contract accepted — now in Commitments [U]")
		else:
			_toast_feedback("✗ couldn't accept this contract")

func _complete_selected() -> void:
	# A refused R must SAY why (anti-gating law) — this used to fail in total
	# silence, which played as "the trade system is broken" (playtest 4: the
	# core deliver verb settled nothing and said nothing).
	if quest_manager == null:
		return
	var rows: Array = _commitments_rows()
	if _selected_index < 0 or _selected_index >= rows.size():
		return
	var quest: Dictionary = rows[_selected_index]
	var qid: int = int(quest.get("id", -1))
	if qid < 0:
		return
	var status := str(quest.get("status", ""))
	var qt = quest.get("type", QuestTypes.Type.DELIVERY)
	var qti := int(qt) if (typeof(qt) == TYPE_INT or typeof(qt) == TYPE_FLOAT) else int(QuestTypes.Type.DELIVERY)
	var is_delivery: bool = qti == int(QuestTypes.Type.DELIVERY)

	if is_delivery:
		var ask_emoji := str(quest.get("resource", ""))
		var ask_qty := int(quest.get("quantity", 0))
		var held := 0
		var econ = _get_economy()
		if econ:
			held = int(econ.get_resource(ask_emoji))
		if held < ask_qty:
			_toast_feedback("• deliver needs %s×%d — you hold %d" % [ask_emoji, ask_qty, held])
			return
		if quest_manager.has_method("complete_quest") and quest_manager.complete_quest(qid):
			quest_completed.emit(qid, {})
			_render_all()
			_toast_feedback("✓ delivered %s×%d — payout is in your stores" % [ask_emoji, ask_qty])
		else:
			var why := str(quest_manager.get("last_complete_error")) if "last_complete_error" in quest_manager else ""
			_toast_feedback("✗ delivery failed — %s" % (why if why != "" else "the market could not settle this contract"))
		return

	if status == "ready" and quest_manager.has_method("claim_quest"):
		if quest_manager.claim_quest(qid):
			quest_completed.emit(qid, {})
			_render_all()
			_toast_feedback("✓ claimed — reward granted")
		else:
			_toast_feedback("✗ claim failed")
	else:
		_toast_feedback("• not ready yet — its bar fills as the live state approaches the ask")

func _abandon_selected() -> void:
	# Confirm-chord law: Abandon FAILS the quest (standing penalty) and was
	# a single instant Q press — the sweep runner nuked a commitment with no
	# takeback. Q arms, ONLY F confirms, any other key cancels.
	if quest_manager == null:
		return
	var rows: Array = _commitments_rows()
	if _selected_index < 0 or _selected_index >= rows.size():
		return
	var quest: Dictionary = rows[_selected_index]
	var qid: int = int(quest.get("id", -1))
	if qid < 0:
		return
	if _abandon_arm_qid == qid:
		_disarm_abandon()
		return
	_abandon_arm_qid = qid
	_toast_feedback("⚠ abandon %s — counts as FAILED. F confirms · any other key cancels" \
			% str(quest.get("faction", "this commitment")))
	_refresh_verb_chips()


func _disarm_abandon(silent: bool = false) -> void:
	if _abandon_arm_qid < 0:
		return
	_abandon_arm_qid = -1
	if not silent:
		_toast_feedback("abandon cancelled")
	_refresh_verb_chips()


func _abandon_confirmed() -> void:
	var qid: int = _abandon_arm_qid
	_abandon_arm_qid = -1
	if quest_manager != null and quest_manager.has_method("fail_quest"):
		quest_manager.fail_quest(qid, "player_action")
		quest_abandoned.emit(qid)
	_render_all()

# =============================================================================
# HELPERS
# =============================================================================

func _current_row_count() -> int:
	# Row count for the ACTIVE frame (the list _selected_index indexes into).
	match frame_id:
		FRAME_MARKET:
			return MarketView.sort_view(_offer_pool, _get_inventory(), _market_sort_mode).size()
		FRAME_COMMITMENTS:
			return _commitments_rows().size()
		_:
			return MAX_VISIBLE_ITEMS


func _select(idx: int) -> void:
	_disarm_abandon()
	_selected_index = clampi(idx, 0, MAX_VISIBLE_ITEMS - 1)
	_refresh_body()
	_refresh_verb_chips()

func _on_quest_pool_changed(_quest: Dictionary = {}) -> void:
	if visible:
		_render_all()

func _make_key_chip(key_str: String, selected: bool = false, empty: bool = false) -> Label:
	var lbl := Label.new()
	lbl.text = "[%s]" % key_str
	lbl.add_theme_font_size_override("font_size", 14)
	if empty:
		lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_ITEM_EMPTY)
	elif selected:
		lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_TAB_ACTIVE)
	else:
		lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_KEY_CHIP)
	lbl.custom_minimum_size = Vector2(28, 0)
	return lbl

func _make_empty_row(key_str: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_make_key_chip(key_str, false, true))
	var lbl := Label.new()
	lbl.text = "—"
	lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_ITEM_EMPTY)
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)
	return row

func _make_muted_label(text: String, icon_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", icon_size)
	lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	return lbl

func _comfort_bar(comfort: float, length: int) -> String:
	var filled: int = int(round(absf(comfort) * float(length)))
	filled = clampi(filled, 0, length)
	var bar := ""
	for i in range(length):
		bar += "▮" if i < filled else "▯"
	return bar

func _ratio_bar(ratio: float, length: int) -> String:
	var clamped: float = clampf(ratio, 0.0, 1.0)
	var filled: int = int(round(clamped * float(length)))
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

func _tension_color(tension: float) -> Color:
	if tension > 0.4:
		return Color(0.95, 0.55, 0.5, 1.0)
	if tension > 0.15:
		return Color(0.95, 0.75, 0.35, 1.0)
	return UIStyleFactory.COLOR_MUTED

func _status_color(status: String) -> Color:
	match status:
		"ready": return Color(0.5, 1.0, 0.5)
		"active": return Color(0.6, 0.85, 1.0)
		"story": return Color(0.95, 0.75, 0.35)
		_: return UIStyleFactory.COLOR_MUTED

# =============================================================================
# Surface API
# =============================================================================

func get_visible_data() -> Dictionary:
	var selected_offer: Dictionary = _get_selected_offer()
	var payload := build_surface_visible_data(
		_current_tab_label(),
		_selected_index,
		_selected_label_for_tab(),
		"%s · %s" % [_scope_mode_label(), _scope_source_label()],
		{
			"pool_size": _offer_pool.size(),
			"biome": str(current_biome.name) if current_biome and "name" in current_biome else "",
			"market_sort": str(MARKET_SORT_LABELS.get(_market_sort_mode, "")),
		}
	)
	payload["selected_offer"] = selected_offer
	payload["scope_mode"] = _scope_mode_label()
	payload["scope_source"] = _scope_source_label()
	payload["scope_counterparty"] = _scope_counterparty_name()
	payload["scope_pair_a"] = _pair_a_name
	payload["scope_pair_b"] = _pair_b_name
	payload["scope_auto"] = _nb_auto_scoped
	return payload

func get_snapshot() -> Dictionary:
	var slots: Array = []
	match frame_id:
		FRAME_MARKET:
			var visible_list: Array = _get_visible_offers()
			for i in range(visible_list.size()):
				var offer = visible_list[i]
				slots.append({
					"index": i,
					"state": str(offer.get("status", "offered")) if offer is Dictionary else "offered",
					"offer": offer,
				})
		FRAME_COMMITMENTS:
			var rows: Array = _commitments_rows()
			for i in range(rows.size()):
				slots.append({
					"index": i,
					"state": str(rows[i].get("status", "active")),
					"quest_id": int(rows[i].get("id", -1)),
				})
		FRAME_MANIFOLD:
			_ensure_biome()
			if current_biome != null:
				var qc = current_biome.quantum_computer if "quantum_computer" in current_biome else null
				if qc != null and qc.register_map != null:
					for i in range(int(qc.register_map.num_qubits)):
						slots.append({"index": i, "qubit": i})
	return {
		"frame_id": frame_id,
		"page_index": get_page_index(),
		"page_count": get_page_count(),
		"selected_index": _selected_index,
		"selected_label": _selected_label_for_tab(),
		"surface_hint": "%s · %s" % [_scope_mode_label(), _scope_source_label()],
		"pool_size": _offer_pool.size(),
		"total_pages": 1,
		"current_page": 0,
		"slots": slots,
		"market_sort": str(MARKET_SORT_LABELS.get(_market_sort_mode, "")),
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
	if _nb_name != "":
		return _nb_name
	if _pair_b_name != "":
		return _pair_b_name
	return ""

func _scope_source_label() -> String:
	if _pair_a_name != "" and _pair_b_name != "":
		return "N handoff"
	if _nb_name != "" and _nb_auto_scoped:
		return "auto (N to choose)"
	if _nb_name != "":
		return "N handoff"
	return "current biome"

func _scope_mode_label() -> String:
	var counterparty := _scope_counterparty_name()
	if counterparty == "":
		# Neighborhood-auto-scoped market = the live biome trading with its neighborhood.
		return "live ↔ neighborhood" if _nb_auto_scoped else "current biome"
	return "%s × %s" % [str(current_biome.name) if current_biome and "name" in current_biome else "—", counterparty]
