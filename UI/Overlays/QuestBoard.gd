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

const FRAME_MANIFOLD := "manifold"
const FRAME_MARKET := "market"
const FRAME_COMMITMENTS := "commitments"
const FRAME_ARC := "arc"

const TAB_ROW := [
	{"key": "T", "frame": FRAME_MANIFOLD,    "name": "Manifold"},
	{"key": "Y", "frame": FRAME_MARKET,      "name": "Market"},
	{"key": "U", "frame": FRAME_COMMITMENTS, "name": "Commitments"},
	{"key": "I", "frame": FRAME_ARC,         "name": "Arc"},
]

const ITEM_KEYS := ["G", "H", "J", "K", "L", ";"]
const ITEM_BY_KEYCODE := {
	KEY_G: 0, KEY_H: 1, KEY_J: 2, KEY_K: 3, KEY_L: 4, KEY_SEMICOLON: 5,
}
const MAX_VISIBLE_ITEMS: int = 6
const MARKET_FETCH_LIMIT: int = 24

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
const COLOR_ARC_FIRED := Color(0.5, 0.75, 0.55, 0.85)
const COLOR_ARC_UNFIRED := Color(0.85, 0.7, 0.4, 0.95)
const COLOR_ARC_HEADER := Color(0.7, 0.6, 0.85, 0.95)

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
	frame_ids = [FRAME_MANIFOLD, FRAME_MARKET, FRAME_COMMITMENTS, FRAME_ARC]
	frame_id = FRAME_MANIFOLD
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
		if quest_manager.has_signal("story_flag_fired") and not quest_manager.story_flag_fired.is_connected(_on_story_flag_changed):
			quest_manager.story_flag_fired.connect(_on_story_flag_changed)

func _on_story_flag_changed(_flag_id: String, _flag: Dictionary) -> void:
	if frame_id == FRAME_ARC:
		_render_all()

func set_biome(biome: Node) -> void:
	if biome != current_biome:
		current_biome = biome
		_offer_pool.clear()
		_selected_index = 0
		if visible:
			_render_all()

## Auto-edge bootstrap. An "edge" can be:
##   - pinned-faction ↔ best partner  (when the player is attached and the
##                                     pinned faction's biome is live)
##   - live ↔ live                     (two simulated biomes — best_live_tension_pair)
##   - live ↔ neighborhood          (live anchor × a static neighborhood spec)
##
## Priority is pinned-faction first (player-as-faction frame), then live↔live,
## then live↔neighborhood.
func _ensure_auto_edge() -> void:
	if _is_pair_scope_active():
		return
	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm == null or not farm.has_method("_ensure_market_lattice"):
		return
	var lattice = farm._ensure_market_lattice()
	if lattice == null:
		return
	var all_biomes: Dictionary = farm.grid.get_all_biomes() if farm.grid and farm.grid.has_method("get_all_biomes") else {}

	# 1. Pinned-neighborhood anchor (only when attached AND its biome is live).
	#    Reinforces the player-as-faction frame: side A is "you" by default.
	var pinned_name: String = _resolve_pinned_neighborhood_name(farm, all_biomes)
	if pinned_name != "":
		var pinned_biome = all_biomes.get(pinned_name, null)
		if pinned_biome != null:
			var partner: String = _best_partner_for(lattice, pinned_biome, all_biomes, pinned_name)
			if partner != "":
				_pair_a_name = pinned_name
				_pair_b_name = partner
				_nb_auto_scoped = true
				return

	# 2. Live ↔ live edge.
	if all_biomes.size() >= 2:
		var best_pair: Dictionary = lattice.best_live_tension_pair(all_biomes)
		if not best_pair.is_empty():
			_pair_a_name = str(best_pair.get("a", ""))
			_pair_b_name = str(best_pair.get("b", ""))
			_nb_auto_scoped = true
			return

	# 3. Live ↔ neighborhood edge — anchor on current_biome (or any live biome).
	var anchor = current_biome
	if anchor == null and not all_biomes.is_empty():
		anchor = all_biomes.values()[0]
	if anchor == null:
		return
	var neighborhood_name: String = lattice.best_neighborhood_name(anchor)
	if neighborhood_name == "":
		return
	var anchor_name: String = str(anchor.name) if "name" in anchor else ""
	if anchor.has_method("get_biome_type"):
		anchor_name = anchor.get_biome_type()
	if anchor_name == "":
		return
	_pair_a_name = anchor_name
	_pair_b_name = neighborhood_name
	_nb_auto_scoped = true

## When the player is attached to a faction, return the live neighborhood name
## owned by that faction (if any). Otherwise empty.
func _resolve_pinned_neighborhood_name(farm, all_biomes: Dictionary) -> String:
	if farm == null or not farm.has_method("get_pinned_faction_name"):
		return ""
	var pname: String = farm.get_pinned_faction_name()
	if pname == "":
		return ""
	# A faction's neighborhood is the live biome whose data spec carries `faction == pname`.
	var br = BiomeRegistry.get_shared()
	if br == null:
		return ""
	for bname in all_biomes.keys():
		var spec = br.get_by_name(str(bname))
		if spec != null and "faction" in spec and str(spec.faction) == pname:
			return str(bname)
	return ""

## Pick the best non-self partner for the given anchor biome. Tries
## highest-tension live partner via `best_live_tension_pair` over the subset;
## falls back to the highest-tension neighborhood partner.
func _best_partner_for(lattice, anchor_biome, all_biomes: Dictionary, anchor_name: String) -> String:
	var subset: Dictionary = {}
	for bname in all_biomes.keys():
		if str(bname) != anchor_name:
			subset[bname] = all_biomes[bname]
	# Live↔live partner
	if not subset.is_empty():
		var pool: Dictionary = subset.duplicate()
		pool[anchor_name] = anchor_biome
		var best_pair: Dictionary = lattice.best_live_tension_pair(pool)
		if not best_pair.is_empty():
			var a := str(best_pair.get("a", ""))
			var b := str(best_pair.get("b", ""))
			if a == anchor_name and b != "":
				return b
			if b == anchor_name and a != "":
				return a
	# Neighborhood partner
	return lattice.best_neighborhood_name(anchor_biome)

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
	if ITEM_BY_KEYCODE.has(keycode):
		var idx: int = int(ITEM_BY_KEYCODE[keycode])
		_select(idx)
		return true
	if frame_id == FRAME_MARKET and MARKET_SORT_BY_KEY.has(keycode):
		_market_sort_mode = int(MARKET_SORT_BY_KEY[keycode])
		_selected_index = 0
		_render_all()
		return true
	if frame_id == FRAME_COMMITMENTS and COMMITMENTS_VIEW_BY_KEY.has(keycode):
		_commitments_view = str(COMMITMENTS_VIEW_BY_KEY[keycode])
		_selected_index = 0
		_render_all()
		return true
	return false

func _on_frame_changed(_new_frame_id: String, _prev_frame_id: String) -> void:
	_on_frame_changed_local()

func _on_frame_changed_local() -> void:
	_selected_index = 0
	_render_all()

# =============================================================================
# VERB ACTIONS
# =============================================================================

func _on_action_q() -> void:
	# Q = leave / change current run state.
	match frame_id:
		FRAME_COMMITMENTS:
			_abandon_selected()  # leave the commitment behind
		FRAME_ARC:
			_acknowledge_selected_arc()  # dismiss the beat
		_:
			pass

func _on_action_e() -> void:
	# E = pause + inspect / refresh.
	match frame_id:
		FRAME_MANIFOLD:
			_refresh_pool()
			_render_all()
		FRAME_MARKET:
			_refresh_pool()
			_render_all()
		FRAME_ARC:
			_render_all()
		_:
			pass

func _on_action_r() -> void:
	# R = stay / commit current run state forward.
	match frame_id:
		FRAME_MARKET:
			_accept_selected()  # commit the offer onto the run
		FRAME_COMMITMENTS:
			_complete_selected()  # commit the quest's reward forward
		FRAME_ARC:
			_accept_selected_arc()  # accept the arc/tutorial quest into active
		_:
			pass

func _on_action_f() -> void:
	pass

# =============================================================================
# INSPECT TEXT — what E pops up as a toast (OverlayBase calls get_inspect_text).
# =============================================================================

func get_inspect_text() -> String:
	match frame_id:
		FRAME_MARKET:      return _market_inspect_text()
		FRAME_COMMITMENTS: return _commitments_inspect_text()
		FRAME_ARC:         return _arc_inspect_text()
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

func _arc_inspect_text() -> String:
	var rows: Array = _arc_rows()
	if _selected_index < 0 or _selected_index >= rows.size():
		return ""
	var entry: Dictionary = rows[_selected_index]
	var kind := str(entry.get("kind", ""))
	if kind == "arc_quest":
		var data: Dictionary = entry.get("data", {})
		var body := str(data.get("body", str(data.get("source_flag", "campaign quest"))))
		var hint := str(data.get("hint", ""))
		if hint == "":
			return body
		return "%s\nhint: %s" % [body, hint]
	var flag: Dictionary = entry.get("flag", {})
	var lines: Array[String] = []
	var _biome_name := str(flag.get("display_name", flag.get("id", "?")))
	lines.append("%s · act %d" % [name, int(flag.get("act", 0))])
	if kind == "flag_fired":
		lines.append("✓ FIRED")
		return "\n".join(lines)
	# unfired — show predicate values
	var pred_scores: Array = entry.get("pred_scores", [])
	for ps in pred_scores:
		var pred: Dictionary = ps.get("pred", {})
		var pscore: float = float(ps.get("score", 0.0))
		lines.append("· " + _predicate_value_tooltip(pred, pscore).replace("\n", "  ·  "))
	return "\n".join(lines)

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

func _render_all() -> void:
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
		_close_hint.text = "[X] close  ·  [ ] / ] cycle tab  ·  [1] Comfort↓  [2] Magnitude↓  [3] Tension↓  ·  active: %s" % sort_label
	else:
		_close_hint.text = "[X] close   ·   [ ] / ] cycle tab"

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
		child.queue_free()
	match frame_id:
		FRAME_MANIFOLD:    _build_manifold_body()
		FRAME_MARKET:      _build_market_body()
		FRAME_COMMITMENTS: _build_commitments_body()
		FRAME_ARC:         _build_arc_body()

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
			return {"Q": "Abandon", "E": "—", "R": "Complete", "F": "—"}
		FRAME_ARC:
			var rows := _arc_rows()
			if _selected_index >= 0 and _selected_index < rows.size():
				if str(rows[_selected_index].get("kind", "")) == "arc_quest":
					return {"Q": "Dismiss", "E": "Refresh", "R": "Accept", "F": "—"}
			return {"Q": "—", "E": "Refresh", "R": "—", "F": "—"}
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
		var empty_msg: String = _market_status_note
		if empty_msg == "":
			empty_msg = "no offers — load a biome with admitted factions, or press R to reroll"
		_body_box.add_child(_make_muted_label(empty_msg, 12))
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
	var view_lbl := Label.new()
	view_lbl.text = "(s=%.2f d=%.2f c%+.2f) %s" % [share, depth, comfort, _comfort_bar(comfort, 5)]
	view_lbl.add_theme_font_size_override("font_size", 11)
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
			_body_box.add_child(_make_commitment_row(rows[i], ITEM_KEYS[i], i == _selected_index))
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
	ask_lbl.text = _commitment_ask_text(quest)
	ask_lbl.add_theme_font_size_override("font_size", 16)
	ask_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_VALUE)
	ask_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(ask_lbl)

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

## The "ask" line for a commitment row: delivery shows resource×qty; quantum quests show the
## steerable objective (observable → target) so the player sees what they're aiming the state at.
func _commitment_ask_text(quest: Dictionary) -> String:
	var t = quest.get("type", QuestTypes.Type.DELIVERY)
	var ti := int(t) if (typeof(t) == TYPE_INT or typeof(t) == TYPE_FLOAT) else int(QuestTypes.Type.DELIVERY)
	if ti == int(QuestTypes.Type.DELIVERY):
		return "%s × %d" % [str(quest.get("resource", "?")), int(quest.get("quantity", 0))]
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
	return QuestTypes.get_type_name(ti)


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
	# Default "active" view.
	if quest_manager and "active_quests" in quest_manager and quest_manager.active_quests is Dictionary:
		for q in quest_manager.active_quests.values():
			rows.append(q)
	return rows

# =============================================================================
# ARC BODY (I tab — story flags timeline)
# =============================================================================

func _build_arc_body() -> void:
	var rows: Array = _arc_rows()
	if rows.is_empty():
		_body_box.add_child(_make_muted_label("no story flags loaded", 12))
		return
	for i in range(MAX_VISIBLE_ITEMS):
		if i < rows.size():
			_body_box.add_child(_make_arc_row(rows[i], ITEM_KEYS[i], i == _selected_index))
		else:
			_body_box.add_child(_make_empty_row(ITEM_KEYS[i]))
	if rows.size() > MAX_VISIBLE_ITEMS:
		_body_box.add_child(_make_muted_label("… %d more arc beats not shown" % (rows.size() - MAX_VISIBLE_ITEMS), 10))

## Builds Arc tab rows. Order:
##   1. Story arc offers (player can acknowledge to dismiss)
##   2. On-edge unfired flags (relevant to current pair), score desc
##   3. Off-edge unfired flags, score desc
##   4. On-edge fired flags
##   5. Off-edge fired flags
##
## Edge relevance is inferred from each flag's predicate biome fields.
func _arc_rows() -> Array:
	var rows: Array = []
	if quest_manager == null:
		return rows
	if quest_manager.has_method("get_story_offers"):
		for q in quest_manager.get_story_offers():
			if q is Dictionary and str(q.get("category", "")) in ["ARC", "TUTORIAL"]:
				rows.append({"kind": "arc_quest", "data": q})

	if not quest_manager.has_method("get_all_story_flags"):
		return rows

	var farm = InstrumentLocator.resolve_active_farm(self)
	var fired_set: Dictionary = {}
	if farm != null and "story_flags_fired" in farm:
		fired_set = farm.story_flags_fired

	var edge_set: Dictionary = {}
	if _pair_a_name != "":
		edge_set[_pair_a_name] = true
	if _pair_b_name != "":
		edge_set[_pair_b_name] = true

	var unfired_on: Array = []
	var unfired_off: Array = []
	var fired_on: Array = []
	var fired_off: Array = []

	for flag in quest_manager.get_all_story_flags():
		var fid := str(flag.get("id", ""))
		var biomes: Array = _flag_biomes(flag)
		var on_edge: bool = false
		if not edge_set.is_empty():
			for b in biomes:
				if edge_set.has(b):
					on_edge = true
					break
		if fired_set.has(fid):
			var entry := {"kind": "flag_fired", "flag": flag, "on_edge": on_edge}
			if on_edge:
				fired_on.append(entry)
			else:
				fired_off.append(entry)
		else:
			var score: float = quest_manager.evaluate_flag_score(flag)
			var pred_scores: Array = []
			for pred in flag.get("predicates", []):
				if pred is Dictionary:
					pred_scores.append({
						"pred": pred,
						"score": quest_manager.evaluate_predicate_score(pred),
					})
			var entry: Dictionary = {
				"kind": "flag_unfired",
				"flag": flag,
				"score": score,
				"pred_scores": pred_scores,
				"on_edge": on_edge,
			}
			if on_edge:
				unfired_on.append(entry)
			else:
				unfired_off.append(entry)

	var by_score = func(a, b): return float(a.score) > float(b.score)
	unfired_on.sort_custom(by_score)
	unfired_off.sort_custom(by_score)

	for u in unfired_on: rows.append(u)
	for u in unfired_off: rows.append(u)
	for f in fired_on: rows.append(f)
	for f in fired_off: rows.append(f)
	return rows

## Biome names referenced by a flag's predicates. Used to determine whether
## the flag "lives on" the active edge.
func _flag_biomes(flag: Dictionary) -> Array:
	var seen: Dictionary = {}
	for pred in flag.get("predicates", []):
		if not (pred is Dictionary):
			continue
		var b: String = str(pred.get("biome", ""))
		if b != "":
			seen[b] = true
	return seen.keys()

func _make_arc_row(entry: Dictionary, key_str: String, selected: bool) -> Control:
	var kind := str(entry.get("kind", ""))
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_width_left = 4 if selected else 1
	if kind == "arc_quest":
		sb.bg_color = Color(0.08, 0.12, 0.10, 0.92) if not selected else Color(0.12, 0.20, 0.14, 0.95)
		sb.border_color = Color(0.3, 0.6, 0.4, 0.6) if not selected else Color(0.5, 0.9, 0.55, 0.95)
	elif kind == "flag_fired":
		sb.bg_color = Color(0.08, 0.10, 0.10, 0.85) if not selected else Color(0.12, 0.16, 0.14, 0.95)
		sb.border_color = Color(0.3, 0.5, 0.4, 0.45) if not selected else COLOR_ARC_FIRED
	else:
		sb.bg_color = Color(0.10, 0.10, 0.13, 0.85) if not selected else Color(0.18, 0.16, 0.10, 0.95)
		sb.border_color = Color(0.5, 0.45, 0.35, 0.5) if not selected else COLOR_ARC_UNFIRED
	row.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	row.add_child(vbox)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(top_hbox)
	top_hbox.add_child(_make_key_chip(key_str, selected))

	if kind == "arc_quest":
		var data: Dictionary = entry.get("data", {})
		var badge := Label.new()
		badge.text = "[QUEST]"
		badge.add_theme_font_size_override("font_size", 11)
		badge.add_theme_color_override("font_color", Color(0.5, 0.9, 0.55, 0.95))
		badge.custom_minimum_size = Vector2(60, 0)
		top_hbox.add_child(badge)
		var body_lbl := Label.new()
		body_lbl.text = str(data.get("body", str(data.get("source_flag", "campaign quest"))))
		body_lbl.add_theme_font_size_override("font_size", 12)
		body_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_TAB_ACTIVE if selected else UIStyleFactory.COLOR_ITEM_IDLE)
		body_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if selected else TextServer.AUTOWRAP_OFF
		body_lbl.clip_text = not selected
		top_hbox.add_child(body_lbl)
		if selected:
			var hint_str: String = str(data.get("hint", data.get("tutorial_hint", "")))
			if hint_str != "":
				var hint_lbl := Label.new()
				hint_lbl.text = "    hint: %s" % hint_str
				hint_lbl.add_theme_font_size_override("font_size", 11)
				hint_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
				hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				vbox.add_child(hint_lbl)
		return row

	var flag: Dictionary = entry.get("flag", {})
	var act_n: int = int(flag.get("act", 0))
	var act_lbl := Label.new()
	act_lbl.text = "act %d" % act_n
	act_lbl.add_theme_font_size_override("font_size", 11)
	act_lbl.add_theme_color_override("font_color", COLOR_ARC_HEADER)
	act_lbl.custom_minimum_size = Vector2(48, 0)
	top_hbox.add_child(act_lbl)

	var name_lbl := Label.new()
	name_lbl.text = str(flag.get("display_name", flag.get("id", "?")))
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_TAB_ACTIVE if selected else UIStyleFactory.COLOR_ITEM_IDLE)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(name_lbl)

	if bool(entry.get("on_edge", false)):
		var edge_badge := Label.new()
		edge_badge.text = "⊗"
		edge_badge.add_theme_font_size_override("font_size", 11)
		edge_badge.add_theme_color_override("font_color", Color(0.5, 0.85, 0.95, 0.95))
		edge_badge.tooltip_text = "on this edge"
		top_hbox.add_child(edge_badge)

	if kind == "flag_fired":
		var fired_lbl := Label.new()
		fired_lbl.text = "✓ FIRED"
		fired_lbl.add_theme_font_size_override("font_size", 11)
		fired_lbl.add_theme_color_override("font_color", COLOR_ARC_FIRED)
		top_hbox.add_child(fired_lbl)
		return row

	# Unfired — show score + per-predicate breakdown.
	var score: float = float(entry.get("score", 0.0))
	var score_lbl := Label.new()
	score_lbl.text = "%.2f / 0.85 %s" % [score, _ratio_bar(score / 0.85, 6)]
	score_lbl.add_theme_font_size_override("font_size", 11)
	score_lbl.add_theme_color_override("font_color", _score_color(score))
	top_hbox.add_child(score_lbl)

	if selected:
		var pred_scores: Array = entry.get("pred_scores", [])
		for ps in pred_scores:
			var pred: Dictionary = ps.get("pred", {})
			var ps_score: float = float(ps.get("score", 0.0))
			var pred_lbl := Label.new()
			pred_lbl.text = "    %s · %.2f %s" % [_predicate_summary(pred), ps_score, _ratio_bar(ps_score, 5)]
			pred_lbl.add_theme_font_size_override("font_size", 10)
			pred_lbl.add_theme_color_override("font_color", _score_color(ps_score))
			pred_lbl.tooltip_text = _predicate_value_tooltip(pred, ps_score)
			pred_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
			vbox.add_child(pred_lbl)

	return row

func _predicate_summary(pred: Dictionary) -> String:
	var t := str(pred.get("type", "?"))
	match t:
		"signature_size_gte":
			return "signature ≥ %d" % int(pred.get("value", 0))
		"berry_consumed_count_gte":
			return "berries[%s] ≥ %d" % [str(pred.get("biome", "")), int(pred.get("value", 0))]
		"berry_total_phase_gte":
			return "phase[%s] ≥ %.2f" % [str(pred.get("biome", "")), float(pred.get("value", 0.0))]
		"standing_gte":
			return "standing %s.%s ≥ %.2f" % [str(pred.get("faction", "")), str(pred.get("channel", "trust")), float(pred.get("value", 0.0))]
		"biome_state_gte":
			return "%s.%s ≥ %.2f" % [str(pred.get("biome", "")), str(pred.get("atom", "")), float(pred.get("value", 0.0))]
		"biome_state_lte":
			return "%s.%s ≤ %.2f" % [str(pred.get("biome", "")), str(pred.get("atom", "")), float(pred.get("value", 0.0))]
		"soul_purity_gte":
			return "you · Tr(ρ²) ≥ %.2f" % float(pred.get("value", 0.5))
		"biome_evolving":
			return "%s evolving" % str(pred.get("biome", ""))
		"story_flag_set":
			return "flag '%s' set" % str(pred.get("id", ""))
		"atom_count_gte":
			return "%s atoms ≥ %d" % [str(pred.get("biome", "")), int(pred.get("value", 0))]
		"atom_in_biome":
			return "%s ∋ %s" % [str(pred.get("biome", "")), str(pred.get("atom", ""))]
		"biome_attractor_emoji_gte":
			return "%s attractor[%s] ≥ %.2f" % [str(pred.get("biome", "")), str(pred.get("emoji", "")), float(pred.get("value", 0.0))]
		"biome_eigenvalue_gap_gte":
			return "%s gap ≥ %.2f" % [str(pred.get("biome", "")), float(pred.get("value", 0.0))]
		"biome_purity_trending":
			return "%s purity↑" % str(pred.get("biome", ""))
		_:
			return t

## Tooltip for a predicate row — reports the *current* measured value alongside
## the threshold. Returns multi-line text. When a value can't be read (missing
## biome, no farm, etc.) we fall back to the score-only summary.
## 3-line tooltip summarizing a faction's nature via FactionCard:
##   {name}  ·  standing {±0.NN}
##   speaks: {sig emojis}
##   biomes: {biomes_of_presence}
## Returns "" if the faction can't be resolved.
func _faction_card_tooltip(quest_name: String, farm) -> String:
	if quest_name == "" or farm == null:
		return ""
	var card: Dictionary = FactionCard.gather(quest_name, farm)
	if not bool(card.get("present", false)):
		return ""
	var standing: float = float(card.get("standing", 0.0))
	var sig_arr: Array = card.get("signature", [])
	var biomes_arr: Array = card.get("biomes_of_presence", [])
	var lines: Array[String] = []
	lines.append("%s  ·  standing %+.2f" % [quest_name, standing])
	if not sig_arr.is_empty():
		lines.append("speaks: " + " ".join(sig_arr))
	if not biomes_arr.is_empty():
		lines.append("biomes: " + ", ".join(biomes_arr))
	return "\n".join(lines)

func _predicate_value_tooltip(pred: Dictionary, score: float) -> String:
	var t := str(pred.get("type", "?"))
	var farm = InstrumentLocator.resolve_active_farm(self)
	var status := "fired ✓" if score >= 1.0 else ("close" if score >= 0.7 else "not yet")
	var head := "%s   ·   %s" % [_predicate_summary(pred), status]

	match t:
		"signature_size_gte":
			var threshold: int = int(pred.get("value", 0))
			var current: int = 0
			if farm and farm.has_method("get_known_emojis"):
				current = farm.get_known_emojis().size()
			return "%s\ncurrent: %d   ·   need: %d   ·   gap: %d" % [head, current, threshold, max(0, threshold - current)]

		"berry_consumed_count_gte", "berry_total_phase_gte":
			var biome_name: String = str(pred.get("biome", ""))
			var biome = _resolve_live_biome(biome_name)
			var qc = biome.quantum_computer if biome and "quantum_computer" in biome else null
			var berry = qc.berry_register if qc and "berry_register" in qc else null
			if berry == null:
				return "%s\n(biome '%s' not loaded)" % [head, biome_name]
			if t == "berry_consumed_count_gte":
				var threshold_c: int = int(pred.get("value", 0))
				var current_c: int = berry.get_consumed_count() if berry.has_method("get_consumed_count") else 0
				return "%s\ncurrent: %d   ·   need: %d" % [head, current_c, threshold_c]
			else:
				var threshold_p: float = float(pred.get("value", 0.0))
				var current_p: float = berry.get_consumed_phase() if berry.has_method("get_consumed_phase") else 0.0
				return "%s\ncurrent: %.2f rad   ·   need: %.2f rad" % [head, current_p, threshold_p]

		"standing_gte":
			var fname: String = str(pred.get("faction", ""))
			var ch: String = str(pred.get("channel", "trust"))
			var threshold_s: float = float(pred.get("value", 0.0))
			var current_s: float = 0.0
			if farm and "faction_standings" in farm and farm.faction_standings is Dictionary:
				var s = farm.faction_standings.get(fname, null)
				if s != null and ch in s:
					current_s = float(s.get(ch))
			return "%s\ncurrent: %+.2f   ·   need: %+.2f" % [head, current_s, threshold_s]

		"story_flag_set":
			var fid: String = str(pred.get("id", ""))
			var fired: bool = false
			if farm and "story_flags_fired" in farm and farm.story_flags_fired is Dictionary:
				fired = farm.story_flags_fired.has(fid)
			return "%s\n%s" % [head, "fired ✓" if fired else "not yet fired"]

		"soul_purity_gte":
			var threshold_sp: float = float(pred.get("value", 0.5))
			if farm and ("faction_density" in farm) and farm.faction_density != null \
					and farm.faction_density.has_method("get_purity"):
				var current_sp: float = float(farm.faction_density.get_purity())
				return "%s\ncurrent: %.3f   ·   need: %.3f\nYour alignment purity decays toward the mixed state (τ=300s) unless your choices keep renewing it." % [head, current_sp, threshold_sp]
			return "%s\n(alignment state unavailable)" % head

		_:
			return "%s\nscore: %.2f / 1.00" % [head, score]

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

	var all_biomes: Dictionary = farm.grid.get_all_biomes() if farm.grid and farm.grid.has_method("get_all_biomes") else {}
	var best_pair: Dictionary = lattice.best_live_tension_pair(all_biomes)
	if not best_pair.is_empty():
		_pair_a_name = str(best_pair.get("a", ""))
		_pair_b_name = str(best_pair.get("b", ""))
		_nb_name = ""
		_nb_auto_scoped = false
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

	_nb_name = lattice.best_neighborhood_name(current_biome)
	_nb_auto_scoped = _nb_name != ""
	if _nb_name == "":
		_market_status_note = "market unavailable: no neighborhood partner"
		return

	var raw: Array = lattice.propose_neighborhood_offers_scoped(current_biome, _nb_name, MARKET_FETCH_LIMIT)
	if raw.is_empty():
		_market_status_note = "market empty: no neighborhood offers for %s" % _nb_name
		return
	_offer_pool = _adapt_contracts_for_view(raw)
	MarketView.annotate(_offer_pool, _get_inventory())

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
	var out: Array = []
	for c in contracts:
		if c == null:
			continue
		var quest: Dictionary = {}
		if c.has_method("to_quest_offer_dict"):
			quest = c.to_quest_offer_dict()
		elif c is Dictionary:
			quest = c.duplicate(true)
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
		FRAME_ARC:
			var rows: Array = _arc_rows()
			if _selected_index < 0 or _selected_index >= rows.size():
				return ""
			var entry: Dictionary = rows[_selected_index]
			if str(entry.get("kind", "")) == "arc_quest":
				return str(entry.get("data", {}).get("source_flag", "arc quest"))
			return str(entry.get("flag", {}).get("display_name", ""))
	return ""

func _get_inventory() -> Dictionary:
	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm == null or farm.economy == null:
		return {}
	return farm.economy.get_all_resources()

func _ensure_biome() -> void:
	if current_biome != null:
		return
	var abm = (Engine.get_main_loop().root.get_node_or_null("/root/ActiveBiomeManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
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
		if quest_manager.accept_quest(offer):
			quest_accepted.emit(offer)

func _complete_selected() -> void:
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
	if status == "ready" and quest_manager.has_method("claim_quest"):
		if quest_manager.claim_quest(qid):
			quest_completed.emit(qid, {})
	elif quest_manager.has_method("complete_quest"):
		if quest_manager.complete_quest(qid):
			quest_completed.emit(qid, {})

func _abandon_selected() -> void:
	if quest_manager == null:
		return
	var rows: Array = _commitments_rows()
	if _selected_index < 0 or _selected_index >= rows.size():
		return
	var quest: Dictionary = rows[_selected_index]
	var qid: int = int(quest.get("id", -1))
	if qid < 0:
		return
	if quest_manager.has_method("fail_quest"):
		quest_manager.fail_quest(qid, "player_action")
		quest_abandoned.emit(qid)

## Accept the selected arc/tutorial offer into active quests (R in the Arc tab). Without this,
## arc and tutorial offers could only be dismissed, never worked on — they would dead-end.
func _accept_selected_arc() -> void:
	if quest_manager == null:
		return
	var rows: Array = _arc_rows()
	if _selected_index < 0 or _selected_index >= rows.size():
		return
	var entry: Dictionary = rows[_selected_index]
	if str(entry.get("kind", "")) != "arc_quest":
		return
	var data: Dictionary = entry.get("data", {})
	if quest_manager.has_method("accept_quest") and quest_manager.accept_quest(data):
		_render_all()


func _acknowledge_selected_arc() -> void:
	if quest_manager == null:
		return
	var rows: Array = _arc_rows()
	if _selected_index < 0 or _selected_index >= rows.size():
		return
	var entry: Dictionary = rows[_selected_index]
	if str(entry.get("kind", "")) != "arc_quest":
		return
	var data: Dictionary = entry.get("data", {})
	var qid: int = int(data.get("id", -1))
	if qid >= 0 and quest_manager.has_method("dismiss_story_offer"):
		quest_manager.dismiss_story_offer(qid)
	_render_all()

# =============================================================================
# HELPERS
# =============================================================================

func _select(idx: int) -> void:
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

func _score_color(score: float) -> Color:
	if score >= 0.85:
		return COLOR_COMFORT_POS
	if score >= 0.5:
		return Color(0.85, 0.85, 0.5, 1.0)
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
		FRAME_ARC:
			var rows: Array = _arc_rows()
			for i in range(rows.size()):
				slots.append({"index": i, "kind": str(rows[i].get("kind", ""))})
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
		return "current biome"
	return "%s × %s" % [str(current_biome.name) if current_biome and "name" in current_biome else "—", counterparty]
