class_name InspectorOverlay
extends "res://UI/Core/Surface.gd"

## InspectorOverlay — N surface (biome network / selector).
##
## N is the inter-biome lens: Network is the active handoff path, Bridges
## summarizes lateral structure, and Selector is the browseable biome atlas.
## Selecting a network edge seeds C's pair scope; the selector page is a world
## browser that shows the same active-biome neighborhood without changing it.
##
## B owns the in-biome math; M owns the biome×faction field.

const InstrumentLocator = preload("res://Core/Instrumentation/InstrumentLocator.gd")
const BiomeRegistry = preload("res://Core/Biomes/BiomeRegistry.gd")
const MarketLatticeCls = preload("res://Core/Markets/MarketLattice.gd")
const FactionBiomeMap = preload("res://Core/Biomes/FactionBiomeMap.gd")

const FRAME_MAP := "map"
const FRAME_BRIDGES := "bridges"
const FRAME_NETWORK := "network"
const FRAME_LIVE := "live"

const FRAME_LABELS_LOCAL := {
	FRAME_MAP: "Selector",
	FRAME_BRIDGES: "Bridges",
	FRAME_NETWORK: "Network",
	FRAME_LIVE: "Live",
}

# Network-frame layout
const NETWORK_HOMEROW := ["G", "H", "J", "K", "L", ";"]
const NETWORK_KEYCODES := {
	KEY_G: 0, KEY_H: 1, KEY_J: 2, KEY_K: 3, KEY_L: 4, KEY_SEMICOLON: 5,
}
const NETWORK_MAX_VISIBLE: int = 6

const COLOR_HEADER := Color(0.85, 0.92, 1.0)
const COLOR_BODY := Color(0.7, 0.78, 0.88)
const COLOR_MUTED := Color(0.55, 0.6, 0.7)
const COLOR_HIGHLIGHT := Color(1.0, 0.95, 0.7)
const COLOR_CARD_BG := Color(0.15, 0.17, 0.22, 0.85)
const COLOR_CARD_BORDER_IDLE := Color(0.35, 0.4, 0.5, 0.6)
const COLOR_CARD_BORDER_ACTIVE := Color(0.9, 0.85, 0.4, 0.9)
const COLOR_BRIDGE_FACTION := Color(0.95, 0.85, 0.5)
const COLOR_BRIDGE_BIOMES := Color(0.7, 0.85, 1.0)

var _frame_label: Label
var _hint_label: Label
var _body_box: VBoxContainer


func _init() -> void:
	overlay_name = "inspector"
	overlay_icon = ""
	overlay_tier = 11
	panel_title = "📡 Network"
	panel_size_mode = PanelSizeMode.MEDIUM
	panel_border_color = Color(0.3, 0.5, 0.7, 0.8)
	navigation_mode = NavigationMode.CALLBACK
	content_spacing = 8
	surface_id = "N"
	frame_ids = [FRAME_NETWORK, FRAME_BRIDGES, FRAME_MAP, FRAME_LIVE]
	frame_id = FRAME_NETWORK
	action_labels = {"Q": "—", "E": "Inspect", "R": "—", "F": "—"}


func _build_content(container: Control) -> void:
	_frame_label = Label.new()
	_frame_label.add_theme_font_size_override("font_size", 16)
	_frame_label.add_theme_color_override("font_color", COLOR_HEADER)
	container.add_child(_frame_label)

	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 11)
	_hint_label.add_theme_color_override("font_color", COLOR_MUTED)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(_hint_label)

	_body_box = VBoxContainer.new()
	_body_box.add_theme_constant_override("separation", 6)
	_body_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_body_box)

	_refresh_label()
	_rebuild_body()


func _on_activated() -> void:
	super._on_activated()
	_rebuild_body()
	# Prime pending scope immediately so C always has the top tension edge ready,
	# even if the user presses C before navigating within N.
	if frame_id == FRAME_NETWORK:
		_update_pending_pair_scope()


func _on_frame_changed(_new_frame_id: String, _prev_frame_id: String) -> void:
	_network_detail_open = false
	_refresh_label()
	_update_action_labels()
	_rebuild_body()


func _update_action_labels() -> void:
	var labels: Dictionary
	if frame_id == FRAME_NETWORK:
		var f_label := "Flatten" if _network_detail_open else "—"
		labels = {"Q": "—", "E": "Inspect", "R": "—", "F": f_label}
	elif frame_id == FRAME_LIVE:
		var e_label := "Open biome" if _live_selected < _live_sorted_biomes.size() else "—"
		labels = {"Q": "—", "E": e_label, "R": "—", "F": "—"}
	else:
		labels = {"Q": "—", "E": "—", "R": "—", "F": "—"}
	action_labels = labels
	action_labels_changed.emit()


func _refresh_label() -> void:
	if _frame_label:
		var idx := frame_ids.find(frame_id)
		var total := frame_ids.size()
		var page_text := "%d/%d" % [idx + 1 if idx >= 0 else 1, total if total > 0 else 1]
		var subtitle := "TYUI jump · [ / ] cycle"
		if frame_id == FRAME_NETWORK and _network_selected >= 0 and _network_selected < _network_edges.size():
			var edge: Dictionary = _network_edges[_network_selected]
			var edge_b := str(edge.get("b", ""))
			if bool(edge.get("faction_edge", false)):
				edge_b = "★%s" % edge_b
			subtitle = "Selected %s ⊗ %s · C opens contracts" % [
				str(edge.get("a", "")),
				edge_b,
			]
		elif frame_id == FRAME_MAP:
			subtitle = "Browse biomes · Network seeds C"
		_frame_label.text = "[ %s ]  page %s  ·  %s" % [
			FRAME_LABELS_LOCAL.get(frame_id, frame_id),
			page_text,
			subtitle,
		]
	if _hint_label:
		match frame_id:
			FRAME_NETWORK:
				_hint_label.text = _network_hint_text()
			FRAME_BRIDGES:
				_hint_label.text = "Bridges show which factions are admitted across multiple biomes."
			FRAME_MAP:
				_hint_label.text = "Browse biomes here; use Network to seed C with a relation."
			FRAME_LIVE:
				_hint_label.text = "Ranked by recent chatter activity. E opens the biome inspector."
			_:
				_hint_label.text = ""


func _rebuild_body() -> void:
	if _body_box == null:
		return
	for child in _body_box.get_children():
		child.queue_free()
	match frame_id:
		FRAME_NETWORK: _build_network_view()
		FRAME_BRIDGES: _build_bridges_view()
		FRAME_MAP:     _build_map_view()
		FRAME_LIVE:    _build_live_view()
		_:             _build_stub_view()
	_refresh_label()


# =============================================================================
# SELECTOR — biome cards / pair-scope handoff page
# =============================================================================

func _build_map_view() -> void:
	var biomes := _get_all_biomes()
	var active_name := _get_active_biome_name()

	var hdr := Label.new()
	hdr.text = "Known biomes: %d    Active: %s" % [biomes.size(), active_name if active_name != "" else "—"]
	hdr.add_theme_font_size_override("font_size", 14)
	hdr.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	_body_box.add_child(hdr)

	var sub := Label.new()
	sub.text = "Browse biomes here; use Network to seed C with a relation."
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", COLOR_MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_box.add_child(sub)

	if biomes.is_empty():
		var empty := Label.new()
		empty.text = "No biomes loaded."
		empty.add_theme_color_override("font_color", COLOR_MUTED)
		_body_box.add_child(empty)
		return

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_box.add_child(grid)

	var names: Array = biomes.keys()
	names.sort()
	for bname in names:
		grid.add_child(_make_biome_card(bname, biomes[bname], bname == active_name))


func _make_biome_card(bname: String, biome, is_active: bool) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 56)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_CARD_BG
	if is_active:
		style.border_color = COLOR_CARD_BORDER_ACTIVE
		style.set_border_width_all(2)
	else:
		style.border_color = COLOR_CARD_BORDER_IDLE
		style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	var title := Label.new()
	var prefix := "● " if is_active else "  "
	title.text = "%s%s" % [prefix, bname]
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", COLOR_HIGHLIGHT if is_active else COLOR_HEADER)
	vbox.add_child(title)

	var stats := Label.new()
	var nq := 0
	var purity := -1.0
	var vc = null
	if biome and "viz_cache" in biome:
		vc = biome.viz_cache
	if vc:
		if vc.has_method("get_num_qubits"):
			nq = vc.get_num_qubits()
		if vc.has_method("get_purity"):
			purity = vc.get_purity()
	stats.text = "%d qubits    purity %s" % [nq, "%.0f%%" % (purity * 100.0) if purity >= 0.0 else "—"]
	stats.add_theme_font_size_override("font_size", 11)
	stats.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	vbox.add_child(stats)

	return card


# =============================================================================
# BRIDGES — factions admitted to multiple biomes (lateral structure)
# =============================================================================

func _build_bridges_view() -> void:
	var biomes := _get_all_biomes()
	if biomes.is_empty():
		var empty := Label.new()
		empty.text = "No biomes loaded — no bridges to compute."
		empty.add_theme_color_override("font_color", COLOR_MUTED)
		_body_box.add_child(empty)
		return

	var faction_to_biomes: Dictionary = _index_factions_by_biome(biomes)
	var bridges: Array = []
	for faction_name in faction_to_biomes.keys():
		var biome_list: Array = faction_to_biomes[faction_name]
		if biome_list.size() >= 2:
			bridges.append({"faction": faction_name, "biomes": biome_list})
	bridges.sort_custom(func(a, b): return int(a.biomes.size()) > int(b.biomes.size()))

	var hdr := Label.new()
	hdr.text = "Bridges: %d factions admitted to 2+ biomes  (of %d known)" % [bridges.size(), faction_to_biomes.size()]
	hdr.add_theme_font_size_override("font_size", 14)
	hdr.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	_body_box.add_child(hdr)

	var sub := Label.new()
	sub.text = "Sorted by admitted span. Icon overlap marks the lateral structure of the world."
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", COLOR_MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_box.add_child(sub)

	if bridges.is_empty():
		var none := Label.new()
		none.text = "No admitted faction spans multiple biomes yet."
		none.add_theme_font_size_override("font_size", 12)
		none.add_theme_color_override("font_color", COLOR_MUTED)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body_box.add_child(none)
		return

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	_body_box.add_child(spacer)

	for entry in bridges:
		_body_box.add_child(_make_bridge_row(entry.faction, entry.biomes))


func _make_bridge_row(faction_name: String, biomes_for_faction: Array) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	var span_lbl := Label.new()
	span_lbl.text = "×%d" % biomes_for_faction.size()
	span_lbl.add_theme_font_size_override("font_size", 12)
	span_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	span_lbl.custom_minimum_size = Vector2(32, 0)
	hbox.add_child(span_lbl)

	var faction_lbl := Label.new()
	faction_lbl.text = faction_name
	faction_lbl.add_theme_font_size_override("font_size", 13)
	faction_lbl.add_theme_color_override("font_color", COLOR_BRIDGE_FACTION)
	faction_lbl.custom_minimum_size = Vector2(180, 0)
	hbox.add_child(faction_lbl)

	var biomes_lbl := Label.new()
	# Augment each biome name with signature icon overlap count.
	var all_biomes := _get_all_biomes()
	var biome_parts: Array = []
	for bname in biomes_for_faction:
		var biome_obj = all_biomes.get(str(bname), null)
		if biome_obj != null:
			var cnt: int = FactionBiomeMap.signature_overlap_count(faction_name, biome_obj)
			biome_parts.append("%s×%d" % [str(bname), cnt])
		else:
			biome_parts.append(str(bname))
	biomes_lbl.text = ", ".join(biome_parts)
	biomes_lbl.add_theme_font_size_override("font_size", 12)
	biomes_lbl.add_theme_color_override("font_color", COLOR_BRIDGE_BIOMES)
	biomes_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	biomes_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hbox.add_child(biomes_lbl)

	return hbox


func _index_factions_by_biome(biomes: Dictionary) -> Dictionary:
	# Faction signature gate: faction admitted to biome iff it owns an icon whose
	# pair is in the biome's register map.
	if biomes.is_empty():
		return {}
	return FactionBiomeMap.index_factions_to_biomes_by_signature(biomes)


func _admitted_faction_names(biome) -> Array:
	if biome == null:
		return []
	# Prefer the cached BiomeBase accessor; fall back for data-path biomes.
	if biome.has_method("get_admitted_factions"):
		return biome.get_admitted_factions()
	return FactionBiomeMap.factions_for_biome_by_signature(biome)


func _resolve_faction_registry():
	# Prefer the farm-owned shared registry so runtime mutations are visible.
	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm != null and "faction_density" in farm and farm.faction_density != null and farm.faction_density.has_method("get_registry"):
		return farm.faction_density.get_registry()
	return null


# =============================================================================
# DATA RESOLVERS
# =============================================================================

func _get_all_biomes() -> Dictionary:
	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm == null or not ("grid" in farm) or farm.grid == null:
		return {}
	if farm.grid.has_method("get_all_biomes"):
		return farm.grid.get_all_biomes()
	return {}


func _get_active_biome_name() -> String:
	var abm = InstrumentLocator.resolve_active_biome_manager(self)
	if abm and abm.has_method("get_active_biome"):
		return str(abm.get_active_biome())
	return ""


# =============================================================================
# NETWORK — biome ⊗ biome trade edges, ranked by tension × shared_count
# =============================================================================

var _network_edges: Array = []
var _network_selected: int = 0
var _network_detail_open: bool = false

var _live_selected: int = 0
var _live_sorted_biomes: Array = []


func _build_network_view() -> void:
	_network_edges = _compute_network_edges()
	if _network_selected >= _network_edges.size():
		_network_selected = max(0, _network_edges.size() - 1)

	var live_count: int = 0
	var faction_count: int = 0
	for e in _network_edges:
		if e.get("faction_edge", false):
			faction_count += 1
		else:
			live_count += 1
	var hdr := Label.new()
	hdr.text = "Trade edges: %d live pairs · %d faction-biome connections (★)" % [live_count, faction_count]
	hdr.add_theme_font_size_override("font_size", 14)
	hdr.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	_body_box.add_child(hdr)

	var sub := Label.new()
	sub.text = "GHJKL; selects · E inspects · press C to open the contract board for the selected relation"
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", COLOR_MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_box.add_child(sub)

	_body_box.add_child(_build_network_summary_card(live_count, faction_count))

	if _network_edges.is_empty():
		var empty := Label.new()
		empty.text = "No biome pairs to trade yet. Add at least two biomes to see relations."
		empty.add_theme_color_override("font_color", COLOR_MUTED)
		_body_box.add_child(empty)
		return

	_body_box.add_child(_build_network_selection_card())

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	_body_box.add_child(spacer)

	var visible: int = int(min(_network_edges.size(), NETWORK_MAX_VISIBLE))
	for i in range(visible):
		_body_box.add_child(_make_network_row(_network_edges[i], NETWORK_HOMEROW[i], i == _network_selected))

	if _network_detail_open and _network_selected < _network_edges.size():
		_body_box.add_child(_make_network_detail_panel(_network_edges[_network_selected]))

	# Keep pending pair scope in sync with the current selection so C always
	# opens to the highest-tension edge even when the user hasn't visited N.
	_update_pending_pair_scope()


func _build_network_summary_card(live_count: int, faction_count: int) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_CARD_BG
	sb.border_color = COLOR_CARD_BORDER_IDLE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var active_name := _get_active_biome_name()
	var biome_lbl := _make_summary_block("Active biome", active_name if active_name != "" else "—")
	row.add_child(biome_lbl)

	var edge_total := live_count + faction_count
	var network_lbl := _make_summary_block("Visible relations", "%d total" % edge_total)
	row.add_child(network_lbl)

	var handoff_text := "Ready" if (_network_selected >= 0 and _network_selected < _network_edges.size()) else "Pick a relation"
	var handoff_lbl := _make_summary_block("C handoff", handoff_text)
	row.add_child(handoff_lbl)

	return panel


func _build_network_selection_card() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.16, 0.95)
	sb.border_color = Color(0.42, 0.55, 0.72, 0.85)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Selection"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", COLOR_HEADER)
	vbox.add_child(title)

	var body := Label.new()
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", COLOR_BODY)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _network_selected >= 0 and _network_selected < _network_edges.size():
		var edge: Dictionary = _network_edges[_network_selected]
		body.text = "%s" % _network_relation_summary(edge)
	else:
		body.text = "Use G/H/J/K/L/; to pick a relation."
	vbox.add_child(body)

	var hint := Label.new()
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", COLOR_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "C transfers the selected relation into the contract board. E opens or closes the detail panel."
	vbox.add_child(hint)

	return panel


func _make_summary_block(title_text: String, value_text: String) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 1)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", COLOR_MUTED)
	box.add_child(title)

	var value := Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 13)
	value.add_theme_color_override("font_color", COLOR_HIGHLIGHT)
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(value)

	return box


func _network_relation_summary(edge: Dictionary) -> String:
	var edge_b := str(edge.get("b", ""))
	if bool(edge.get("faction_edge", false)):
		edge_b = "★%s" % edge_b
	var shared_list: Array = edge.get("shared", [])
	return "%s ⊗ %s\nshared axes: %d   tension: %.3f" % [
		str(edge.get("a", "")),
		edge_b,
		shared_list.size(),
		float(edge.get("tension", 0.0)),
	]


func _network_hint_text() -> String:
	if _network_selected < 0 or _network_selected >= _network_edges.size():
		return "Select an edge with G/H/J/K/L/;."
	var edge: Dictionary = _network_edges[_network_selected]
	var edge_b := str(edge.get("b", ""))
	if bool(edge.get("faction_edge", false)):
		edge_b = "★%s" % edge_b
	return "Selected: %s ⊗ %s · C opens the contract board" % [
		str(edge.get("a", "")),
		edge_b,
	]


func _make_network_row(edge: Dictionary, key_label: String, is_selected: bool) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	var key_lbl := Label.new()
	key_lbl.text = "[%s]" % key_label
	key_lbl.add_theme_font_size_override("font_size", 12)
	key_lbl.add_theme_color_override("font_color", COLOR_KEY_CHIP if is_selected else COLOR_MUTED)
	key_lbl.custom_minimum_size = Vector2(28, 0)
	hbox.add_child(key_lbl)

	var pair_lbl := Label.new()
	var is_faction: bool = bool(edge.get("faction_edge", false))
	pair_lbl.text = "%s ⊗ %s" % [edge.a, edge.b]
	if is_faction:
		pair_lbl.text = "%s ⊗ ★%s" % [edge.a, edge.b]
	pair_lbl.add_theme_font_size_override("font_size", 13)
	var pair_color: Color = COLOR_HIGHLIGHT if is_selected else (Color(0.85, 0.65, 1.0) if is_faction else COLOR_BRIDGE_FACTION)
	pair_lbl.add_theme_color_override("font_color", pair_color)
	pair_lbl.custom_minimum_size = Vector2(260, 0)
	hbox.add_child(pair_lbl)

	var shared_lbl := Label.new()
	shared_lbl.text = "shared: %s" % " ".join(edge.shared)
	shared_lbl.add_theme_font_size_override("font_size", 12)
	shared_lbl.add_theme_color_override("font_color", COLOR_BRIDGE_BIOMES)
	shared_lbl.custom_minimum_size = Vector2(220, 0)
	hbox.add_child(shared_lbl)

	var tension_lbl := Label.new()
	var drift: float = float(edge.get("tension_drift", 0.0))
	var drift_valid: bool = bool(edge.get("tension_drift_valid", false))
	var drift_glyph: String = ""
	if drift_valid:
		drift_glyph = " ↑" if drift > 0.01 else (" ↓" if drift < -0.01 else " →")
	tension_lbl.text = "tension %.3f%s" % [edge.tension, drift_glyph]
	tension_lbl.add_theme_font_size_override("font_size", 12)
	tension_lbl.add_theme_color_override("font_color", COLOR_BODY)
	tension_lbl.custom_minimum_size = Vector2(100, 0)
	hbox.add_child(tension_lbl)

	if edge.has("affinity"):
		var aff_lbl := Label.new()
		aff_lbl.text = "affinity %.2f" % float(edge.affinity)
		aff_lbl.add_theme_font_size_override("font_size", 12)
		var aff_val: float = float(edge.affinity)
		aff_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.7) if aff_val > 0.5 else COLOR_MUTED)
		hbox.add_child(aff_lbl)

	return hbox


const COLOR_KEY_CHIP := Color(0.55, 0.85, 1.0, 0.95)
const COLOR_DETAIL_BG := Color(0.08, 0.10, 0.14, 0.92)
const COLOR_FACTION_EDGE := Color(0.85, 0.65, 1.0)


func _make_network_detail_panel(edge: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_DETAIL_BG
	sb.border_color = Color(0.4, 0.5, 0.7, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var is_faction: bool = bool(edge.get("faction_edge", false))
	var header := Label.new()
	header.text = "  %s ⊗ %s%s" % [edge.a, "★" if is_faction else "", edge.b]
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", COLOR_FACTION_EDGE if is_faction else COLOR_HIGHLIGHT)
	vbox.add_child(header)

	var tension_lbl := Label.new()
	tension_lbl.text = "  tension: %.4f    shared axes: %d" % [edge.tension, edge.shared.size()]
	tension_lbl.add_theme_font_size_override("font_size", 12)
	tension_lbl.add_theme_color_override("font_color", COLOR_BODY)
	vbox.add_child(tension_lbl)

	# Per-shared-emoji marginals from both sides.
	var biomes := _get_all_biomes()
	var marg_a: Dictionary = _emoji_marginals_for_biome(biomes.get(str(edge.a), null))
	var marg_b_dict: Dictionary = {}
	if is_faction:
		var br = BiomeRegistry.get_shared()
		for fb in br.get_biomes_by_tag("faction_biome"):
			if fb.name == str(edge.b):
				marg_b_dict = MarketLatticeCls._static_marginals_from_spec(fb)
				break
	else:
		marg_b_dict = _emoji_marginals_for_biome(biomes.get(str(edge.b), null))

	for emoji in edge.shared:
		var pa: float = float(marg_a.get(emoji, 0.5))
		var pb: float = float(marg_b_dict.get(emoji, 0.5))
		var delta: float = pb - pa
		var row_lbl := Label.new()
		row_lbl.text = "  %s  %s=%.2f  %s=%.2f  Δ=%+.2f" % [
			emoji, str(edge.a).left(8), pa, str(edge.b).left(8), pb, delta]
		row_lbl.add_theme_font_size_override("font_size", 11)
		var delta_color := Color(0.5, 0.9, 0.55) if delta > 0.05 else (Color(0.95, 0.55, 0.5) if delta < -0.05 else COLOR_MUTED)
		row_lbl.add_theme_color_override("font_color", delta_color)
		vbox.add_child(row_lbl)

	# Bridge factions — those admitted to BOTH biomes in this edge (signature gate).
	if not is_faction:
		var biome_a_obj = biomes.get(str(edge.a), null)
		var biome_b_obj = biomes.get(str(edge.b), null)
		if biome_a_obj != null and biome_b_obj != null:
			var fa: Array = _admitted_faction_names(biome_a_obj)
			var fb: Array = _admitted_faction_names(biome_b_obj)
			var bridges_shared: Array = []
			for f in fa:
				if fb.has(f):
					bridges_shared.append(str(f))
			if not bridges_shared.is_empty():
				var bridge_lbl := Label.new()
				bridge_lbl.text = "  admitted bridges: %s" % ", ".join(bridges_shared)
				bridge_lbl.add_theme_font_size_override("font_size", 11)
				bridge_lbl.add_theme_color_override("font_color", COLOR_BRIDGE_FACTION)
				bridge_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				vbox.add_child(bridge_lbl)

	# Purity of both biomes.
	var purity_parts: Array = []
	for bname in [str(edge.a), str(edge.b)]:
		var bm = biomes.get(bname, null)
		if bm != null and "viz_cache" in bm and bm.viz_cache != null and bm.viz_cache.has_method("get_purity"):
			var p: float = float(bm.viz_cache.get_purity())
			purity_parts.append("%s %.0f%%" % [bname.left(10), p * 100.0])
	if not purity_parts.is_empty():
		var purity_lbl := Label.new()
		purity_lbl.text = "  purity: %s" % " · ".join(purity_parts)
		purity_lbl.add_theme_font_size_override("font_size", 11)
		purity_lbl.add_theme_color_override("font_color", COLOR_MUTED)
		vbox.add_child(purity_lbl)

	# Score formula (make the hidden ranking legible).
	var score_lbl := Label.new()
	var score_val: float = float(edge.get("score", 0.0))
	score_lbl.text = "  rank score: tension %.3f + overlap ×%d = %.3f" % [
		float(edge.get("tension", 0.0)), edge.shared.size(), score_val]
	score_lbl.add_theme_font_size_override("font_size", 10)
	score_lbl.add_theme_color_override("font_color", COLOR_MUTED)
	vbox.add_child(score_lbl)

	var hint := Label.new()
	hint.text = "  F flattens · press C to open the contract board for this relation"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", COLOR_MUTED)
	vbox.add_child(hint)

	return panel


func _compute_network_edges() -> Array:
	var biomes := _get_all_biomes()
	var bnames: Array = biomes.keys()
	bnames.sort()

	var marg_cache: Dictionary = {}
	for bname in bnames:
		marg_cache[bname] = _emoji_marginals_for_biome(biomes[bname])

	var edges: Array = []

	# Live biome pairs.
	for i in range(bnames.size()):
		for j in range(i + 1, bnames.size()):
			var a = bnames[i]
			var bb = bnames[j]
			var ma: Dictionary = marg_cache.get(a, {})
			var mb: Dictionary = marg_cache.get(bb, {})
			var shared: Array = []
			var tension: float = 0.0
			for emoji in ma.keys():
				if mb.has(emoji):
					shared.append(emoji)
					tension += abs(float(ma[emoji]) - float(mb[emoji]))
			if shared.is_empty():
				continue
			var affinity: float = _compute_biome_affinity_score(biomes.get(a, null), biomes.get(bb, null))
			# 1-step tension lookahead via batcher buffer — O(1) per atom.
			var biome_a_obj = biomes.get(a, null)
			var biome_b_obj = biomes.get(bb, null)
			var pred_tension: float = 0.0
			var pred_valid: bool = false
			if biome_a_obj != null and biome_a_obj.has_method("predict_population") and biome_b_obj != null and biome_b_obj.has_method("predict_population"):
				pred_valid = true
				for atom in shared:
					var pa: float = biome_a_obj.predict_population(atom, 1)
					var pb: float = biome_b_obj.predict_population(atom, 1)
					if pa < 0.0 or pb < 0.0:
						pred_valid = false
						break
					pred_tension += absf(pa - pb)
			edges.append({
				"a": a, "b": bb,
				"shared": shared, "tension": tension,
				"tension_drift": pred_tension - tension if pred_valid else 0.0,
				"tension_drift_valid": pred_valid,
				"affinity": affinity,
				"score": tension + 0.05 * float(shared.size()),
				"faction_edge": false,
			})

	# Faction-biome edges for the active biome only (keeps count bounded).
	var active_name := _get_active_biome_name()
	if active_name != "" and marg_cache.has(active_name):
		var marg_active: Dictionary = marg_cache[active_name]
		var br = BiomeRegistry.get_shared()
		for fb in br.get_biomes_by_tag("faction_biome"):
			var marg_fb: Dictionary = MarketLatticeCls._static_marginals_from_spec(fb)
			var shared: Array = []
			var tension: float = 0.0
			for emoji in marg_active.keys():
				if marg_fb.has(emoji):
					shared.append(emoji)
					tension += abs(float(marg_active[emoji]) - float(marg_fb[emoji]))
			if shared.is_empty():
				continue
			edges.append({
				"a": active_name, "b": fb.name,
				"shared": shared, "tension": tension,
				"score": tension + 0.05 * float(shared.size()),
				"faction_edge": true,
			})

	edges.sort_custom(func(x, y): return float(x.score) > float(y.score))
	return edges


func _compute_biome_affinity_score(biome_a, biome_b) -> float:
	if biome_a == null or biome_b == null:
		return 0.0
	var aff_a = biome_a.affinity if "affinity" in biome_a else null
	var aff_b = biome_b.affinity if "affinity" in biome_b else null
	if aff_a != null and aff_b != null and aff_a.has_method("overlap"):
		return clampf(float(aff_a.overlap(aff_b)), 0.0, 1.0)
	const FBM = preload("res://Core/Biomes/FactionBiomeMap.gd")
	var fa: Array = FBM.factions_for_biome_by_signature(biome_a)
	var fb: Array = FBM.factions_for_biome_by_signature(biome_b)
	if fa.is_empty() or fb.is_empty():
		return 0.0
	var shared: int = 0
	for f in fa:
		if fb.has(f):
			shared += 1
	return float(shared) / float(maxi(fa.size(), fb.size()))


func _emoji_marginals_for_biome(biome) -> Dictionary:
	var out: Dictionary = {}
	if biome == null:
		return out
	var qc = biome.quantum_computer if "quantum_computer" in biome else null
	if qc == null or qc.register_map == null:
		return out
	var n = qc.register_map.num_qubits
	for q in range(n):
		var pair: Dictionary = qc.get_emoji_pair_for_qubit(q) if qc.has_method("get_emoji_pair_for_qubit") else {}
		var north = str(pair.get("north", ""))
		var south = str(pair.get("south", ""))
		var p1: float = qc.get_marginal(q, 1) if qc.has_method("get_marginal") else 0.5
		if north != "":
			out[north] = 1.0 - p1
		if south != "":
			out[south] = p1
	return out


func _on_unhandled_key(keycode: int, _event) -> bool:
	if NETWORK_KEYCODES.has(keycode):
		var idx: int = int(NETWORK_KEYCODES[keycode])
		if frame_id == FRAME_NETWORK:
			if idx < _network_edges.size():
				_network_selected = idx
				_network_detail_open = false
				_update_action_labels()
				_update_pending_pair_scope()
				_rebuild_body()
			return true
		elif frame_id == FRAME_LIVE:
			if idx < _live_sorted_biomes.size():
				_live_selected = idx
				_update_action_labels()
				_rebuild_body()
			return true
	return false


func _on_action_q() -> void:
	pass  # honest empty — Q is screw-out but N.network has no lesser/retreat action


func _on_action_e() -> void:
	if frame_id == FRAME_NETWORK:
		if _network_edges.is_empty():
			return
		_network_detail_open = not _network_detail_open
		_update_action_labels()
		_rebuild_body()
	elif frame_id == FRAME_LIVE:
		if _live_selected < _live_sorted_biomes.size():
			_handoff_to_biome_inspector(str(_live_sorted_biomes[_live_selected]))


func _on_action_f() -> void:
	if frame_id == FRAME_NETWORK and _network_detail_open:
		_network_detail_open = false
		_update_action_labels()
		_rebuild_body()
	# When detail is not open, F is global play — PlayerShell peek already handled it.
	# Do NOT call _drill_out() — F is never "back."


func _update_pending_pair_scope() -> void:
	if _network_selected < 0 or _network_selected >= _network_edges.size():
		return
	var edge: Dictionary = _network_edges[_network_selected]
	var om = _resolve_overlay_manager()
	if om != null and om.has_method("set_pending_pair_scope"):
		om.set_pending_pair_scope(str(edge.a), str(edge.b))


func _resolve_overlay_manager():
	var n: Node = self
	while n != null:
		if n.has_method("set_pending_pair_scope"):
			return n
		n = n.get_parent()
	return null


func _build_live_view() -> void:
	var se = get_node_or_null("/root/StoryEngine")
	if se == null or not ("cluster" in se) or se.cluster == null:
		var none := Label.new()
		none.text = "StoryEngine not available — no live chatter yet."
		none.add_theme_color_override("font_color", COLOR_MUTED)
		_body_box.add_child(none)
		return

	var events: Array = se.cluster.recent_chatter(20)

	var biome_data: Dictionary = {}
	for ev in events:
		var bname: String = str(ev.get("biome", ""))
		if bname == "":
			continue
		if not biome_data.has(bname):
			biome_data[bname] = {"count": 0, "factions": {}, "emoji_sample": []}
		var entry: Dictionary = biome_data[bname]
		entry["count"] = int(entry.get("count", 0)) + 1
		var faction: String = str(ev.get("faction", ""))
		var speaker: String = str(ev.get("speaker", ""))
		if faction != "":
			entry["factions"][faction] = speaker
		var emojis: Array = ev.get("emojis", [])
		var sample: Array = entry["emoji_sample"]
		for e in emojis:
			if sample.size() >= 3:
				break
			sample.append(str(e))
		biome_data[bname] = entry

	_live_sorted_biomes = biome_data.keys()
	_live_sorted_biomes.sort_custom(func(a, b): return int(biome_data[a]["count"]) > int(biome_data[b]["count"]))
	_live_selected = clampi(_live_selected, 0, maxi(0, _live_sorted_biomes.size() - 1))

	var hdr := Label.new()
	hdr.text = "Live chatter: %d events across %d biomes" % [events.size(), _live_sorted_biomes.size()]
	hdr.add_theme_font_size_override("font_size", 14)
	hdr.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	_body_box.add_child(hdr)

	var sub := Label.new()
	sub.text = "GHJKL; selects · E opens biome inspector for selected biome"
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", COLOR_MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_box.add_child(sub)

	if _live_sorted_biomes.is_empty():
		var empty := Label.new()
		empty.text = "No chatter yet — wait for the first StoryEngine tick (1 Hz)."
		empty.add_theme_color_override("font_color", COLOR_MUTED)
		_body_box.add_child(empty)
		return

	var active_name := _get_active_biome_name()
	var visible_count: int = mini(_live_sorted_biomes.size(), NETWORK_MAX_VISIBLE)
	for i in range(visible_count):
		var bname: String = str(_live_sorted_biomes[i])
		_body_box.add_child(
			_make_live_row(bname, biome_data[bname], i == _live_selected, NETWORK_HOMEROW[i], bname == active_name)
		)
	_update_action_labels()


func _make_live_row(biome_name: String, entry: Dictionary, is_selected: bool, key_label: String, is_active: bool) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	var key_lbl := Label.new()
	key_lbl.text = "[%s]" % key_label
	key_lbl.add_theme_font_size_override("font_size", 12)
	key_lbl.add_theme_color_override("font_color", COLOR_KEY_CHIP if is_selected else COLOR_MUTED)
	key_lbl.custom_minimum_size = Vector2(28, 0)
	hbox.add_child(key_lbl)

	var name_lbl := Label.new()
	name_lbl.text = ("● " if is_active else "  ") + biome_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", COLOR_HIGHLIGHT if is_selected else COLOR_HEADER)
	name_lbl.custom_minimum_size = Vector2(200, 0)
	hbox.add_child(name_lbl)

	var emojis: Array = entry.get("emoji_sample", [])
	var emoji_lbl := Label.new()
	emoji_lbl.text = " ".join(emojis)
	emoji_lbl.add_theme_font_size_override("font_size", 14)
	emoji_lbl.custom_minimum_size = Vector2(90, 0)
	hbox.add_child(emoji_lbl)

	var count_lbl := Label.new()
	count_lbl.text = "×%d" % int(entry.get("count", 0))
	count_lbl.add_theme_font_size_override("font_size", 12)
	count_lbl.add_theme_color_override("font_color", COLOR_BRIDGE_BIOMES)
	count_lbl.custom_minimum_size = Vector2(40, 0)
	hbox.add_child(count_lbl)

	var faction_names: Array = entry.get("factions", {}).keys()
	var faction_lbl := Label.new()
	faction_lbl.text = ", ".join(faction_names)
	faction_lbl.add_theme_font_size_override("font_size", 11)
	faction_lbl.add_theme_color_override("font_color", COLOR_BRIDGE_FACTION)
	faction_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	faction_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hbox.add_child(faction_lbl)

	return hbox


func _handoff_to_biome_inspector(biome_name: String) -> void:
	var biomes := _get_all_biomes()
	var biome = biomes.get(biome_name, null)
	if biome == null:
		return
	var om = _resolve_overlay_manager()
	if om == null or not om.has_method("open_overlay"):
		return
	if "biome_inspector" in om and om.biome_inspector != null and om.biome_inspector.has_method("set_biome"):
		om.biome_inspector.set_biome(biome)
	om.open_overlay("biome_detail")


func _build_stub_view() -> void:
	var note := Label.new()
	note.text = "Frame '%s' not implemented." % FRAME_LABELS_LOCAL.get(frame_id, frame_id)
	note.add_theme_color_override("font_color", COLOR_MUTED)
	_body_box.add_child(note)


# =============================================================================
# SURFACE CONTRACT
# =============================================================================

func get_visible_data() -> Dictionary:
	var biomes := _get_all_biomes()
	var active_name := _get_active_biome_name()
	var payload: Dictionary = {
		"frame_label": FRAME_LABELS_LOCAL.get(frame_id, frame_id),
		"biome_count": biomes.size(),
		"active_biome": active_name,
		"page_index": max(0, frame_ids.find(frame_id)) + 1,
		"page_count": frame_ids.size(),
	}
	payload["network_edge_count"] = _network_edges.size() if frame_id == FRAME_NETWORK else 0
	payload["network_live_count"] = _network_live_count() if frame_id == FRAME_NETWORK else 0
	payload["network_faction_count"] = _network_faction_count() if frame_id == FRAME_NETWORK else 0
	if frame_id == FRAME_NETWORK and _network_selected >= 0 and _network_selected < _network_edges.size():
		var edge: Dictionary = _network_edges[_network_selected]
		var shared_list: Array = edge.get("shared", [])
		payload["selected_edge"] = {
			"a": str(edge.get("a", "")),
			"b": str(edge.get("b", "")),
			"faction_edge": bool(edge.get("faction_edge", false)),
			"tension": float(edge.get("tension", 0.0)),
			"shared_count": shared_list.size(),
		}
		payload["handoff_target"] = "C"
		payload["handoff_ready"] = true
		payload["selected_edge_label"] = "%s ⊗ %s" % [
			str(edge.get("a", "")),
			"★%s" % str(edge.get("b", "")) if bool(edge.get("faction_edge", false)) else str(edge.get("b", "")),
		]
		payload["selected_edge_summary"] = _network_relation_summary(edge)
		payload["network_hint"] = _network_hint_text()
	elif frame_id == FRAME_MAP:
		payload["handoff_target"] = "C"
		payload["handoff_ready"] = false
		payload["network_hint"] = "Browse biomes here; use Network to seed C with a relation."
	elif frame_id == FRAME_BRIDGES:
		payload["network_hint"] = "Bridges show which factions travel across multiple biomes."
	if frame_id == FRAME_BRIDGES:
		var faction_to_biomes := _index_factions_by_biome(biomes)
		var bridge_count := 0
		for k in faction_to_biomes.keys():
			if (faction_to_biomes[k] as Array).size() >= 2:
				bridge_count += 1
		payload["bridge_count"] = bridge_count
		payload["faction_count"] = faction_to_biomes.size()
	return payload


func get_transitions() -> Array:
	return [
		{"surface_id": "farm", "reason": "return to live instrument"},
		{"surface_id": "B", "reason": "drill into the active biome's state + math"},
		{"surface_id": "M", "reason": "global faction field"},
		{"surface_id": "C", "reason": "biome's market offers"},
	]


func _network_live_count() -> int:
	var count: int = 0
	for edge in _network_edges:
		if not bool(edge.get("faction_edge", false)):
			count += 1
	return count


func _network_faction_count() -> int:
	var count: int = 0
	for edge in _network_edges:
		if bool(edge.get("faction_edge", false)):
			count += 1
	return count
