class_name MapMetaOverlay
extends "res://UI/Core/Surface.gd"

## M — Biome × Faction Map.
##
## The M surface is the biome/faction relationship lens. FIELD shows the
## selected biome's native factions and standing field; ATLAS shows the
## cluster view with the selected biome at center.
##
## FIELD uses G/H/J/K/L/; for selection, E to open the selected entry's detail
## panel, and F to flatten it again. ATLAS keeps Q / R as local orbit controls
## for zooming and rotating the cluster view on this surface only.

const InstrumentLocator = preload("res://Core/Instrumentation/InstrumentLocator.gd")
const BiomeAffinityClusterView = preload("res://UI/Overlays/BiomeAffinityClusterView.gd")

const FRAME_FIELD := "field"
const FRAME_ATLAS := "atlas"

const FRAME_LABELS_LOCAL := {
	FRAME_FIELD: "Field",
	FRAME_ATLAS: "Atlas",
}

const ATLAS_MIN_ZOOM: float = 0.72
const ATLAS_MAX_ZOOM: float = 1.55
const ATLAS_ZOOM_STEP: float = 0.10
const ATLAS_ROTATION_STEP: float = 12.0

const ITEM_KEYS := ["G", "H", "J", "K", "L", ";"]
const ITEM_BY_KEYCODE := {
	KEY_G: 0,
	KEY_H: 1,
	KEY_J: 2,
	KEY_K: 3,
	KEY_L: 4,
	KEY_SEMICOLON: 5,
}

const COLOR_HEADER := Color(0.88, 0.93, 0.98)
const COLOR_BODY := Color(0.72, 0.8, 0.9)
const COLOR_MUTED := Color(0.55, 0.6, 0.7, 0.9)
const COLOR_HILITE := Color(0.95, 0.87, 0.45)
const COLOR_CARD_BG := Color(0.12, 0.14, 0.18, 0.92)
const COLOR_CARD_BORDER := Color(0.28, 0.35, 0.45, 0.7)
const COLOR_CARD_BORDER_ACTIVE := Color(0.92, 0.85, 0.42, 0.95)

var farm: Node = null
var _active_biome: Node = null
var _selected_entry: int = 0
var _field_entries: Array = []
var _field_page: int = 0
var _cluster_snapshot: Dictionary = {}
var _field_detail_open: bool = false
var _atlas_zoom: float = 1.0
var _atlas_rotation_degrees: float = 0.0
var _atlas_selected_idx: int = -1
var _atlas_selected_name: String = ""
var _atlas_selectable_nodes: Array = []
var _atlas_detail_open: bool = false

var _header_label: Label
var _hint_label: Label
var _tab_row_box: HBoxContainer
var _tab_labels: Dictionary = {}
var _body_box: VBoxContainer
var _field_box: VBoxContainer


func _init() -> void:
	overlay_name = "map_meta"
	overlay_icon = "🗺"
	overlay_tier = 12
	panel_title = "Biome Map"
	panel_title_size = 22
	panel_size_mode = PanelSizeMode.LARGE
	show_dimmer = true
	dimmer_color = Color(0, 0, 0, 0.75)
	panel_border_color = Color(0.3, 0.5, 0.6, 0.8)
	use_scroll_container = true
	content_spacing = 8
	navigation_mode = NavigationMode.CALLBACK
	surface_id = "M"
	frame_ids = [FRAME_FIELD, FRAME_ATLAS]
	frame_id = FRAME_FIELD
	action_labels = {"Q": "—", "E": "Inspect", "R": "—", "F": "—"}


func _ready() -> void:
	super._ready()
	var abm = InstrumentLocator.resolve_active_biome_manager(self)
	if abm and abm.has_signal("active_biome_changed"):
		abm.active_biome_changed.connect(_on_active_biome_changed)


func set_biome(biome: Node) -> void:
	if biome != _active_biome:
		_active_biome = biome
		context_id = _biome_name()
		_reset_view_state()
		_field_detail_open = false
		_update_action_labels()
		_rebuild()


func _build_content(container: Control) -> void:
	_header_label = Label.new()
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 14)
	_header_label.add_theme_color_override("font_color", COLOR_HEADER)
	container.add_child(_header_label)

	_tab_row_box = HBoxContainer.new()
	_tab_row_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_tab_row_box.add_theme_constant_override("separation", 18)
	container.add_child(_tab_row_box)
	_tab_labels.clear()
	for entry in [
		{"key": "T", "frame": FRAME_FIELD, "name": "Field"},
		{"key": "Y", "frame": FRAME_ATLAS, "name": "Atlas"},
	]:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 15)
		_tab_row_box.add_child(lbl)
		_tab_labels[str(entry.get("key", ""))] = lbl

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.4, 0.4, 0.3, 0.45))
	container.add_child(sep)

	_body_box = VBoxContainer.new()
	_body_box.add_theme_constant_override("separation", 6)
	_body_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_body_box)

	_update_action_labels()
	_rebuild()


func _on_activated() -> void:
	_resolve_biome()
	if _active_biome and _active_biome.has_method("get_biome_type"):
		context_id = _active_biome.get_biome_type()
	_update_action_labels()
	_rebuild()
	super._on_activated()


func _on_active_biome_changed(new_biome: String, _old_biome: String) -> void:
	if not visible or not is_active:
		return
	if farm and farm.grid and farm.grid.has_method("get_biome"):
		_active_biome = farm.grid.get_biome(new_biome)
	context_id = new_biome
	_reset_view_state()
	_field_detail_open = false
	_update_action_labels()
	_rebuild()


func _on_frame_changed(_new_frame_id: String, _prev_frame_id: String) -> void:
	_selected_entry = 0
	_field_detail_open = false
	_field_page = 0
	_atlas_selected_idx = -1
	_atlas_selected_name = ""
	_atlas_detail_open = false
	_update_action_labels()
	_rebuild()


func _on_unhandled_key(keycode: int, _event: InputEvent) -> bool:
	if super._on_unhandled_key(keycode, _event):
		return true
	if frame_id == FRAME_FIELD:
		if ITEM_BY_KEYCODE.has(keycode):
			var page_offset: int = _field_page * ITEM_KEYS.size()
			var abs_idx: int = page_offset + int(ITEM_BY_KEYCODE[keycode])
			if abs_idx < _field_entries.size():
				_selected_entry = abs_idx
			_refresh_header()
			_render_body()
			return true
		if keycode == KEY_W:
			var max_page: int = maxi(0, (_field_entries.size() - 1) / ITEM_KEYS.size())
			_field_page = maxi(0, _field_page - 1)
			_selected_entry = clampi(_selected_entry, _field_page * ITEM_KEYS.size(), (_field_page + 1) * ITEM_KEYS.size() - 1)
			_refresh_header()
			_render_body()
			return true
		if keycode == KEY_S:
			var max_page: int = maxi(0, (_field_entries.size() - 1) / ITEM_KEYS.size())
			_field_page = mini(max_page, _field_page + 1)
			_selected_entry = clampi(_selected_entry, _field_page * ITEM_KEYS.size(), (_field_page + 1) * ITEM_KEYS.size() - 1)
			_refresh_header()
			_render_body()
			return true
	elif frame_id == FRAME_ATLAS and ITEM_BY_KEYCODE.has(keycode):
		var idx: int = int(ITEM_BY_KEYCODE[keycode])
		if idx < _atlas_selectable_nodes.size():
			_atlas_selected_idx = idx
			_atlas_selected_name = str(_atlas_selectable_nodes[idx].get("name", ""))
			_atlas_detail_open = false
			_update_action_labels()
			_render_body()
		return true
	return false


func _on_action_q() -> void:
	if frame_id != FRAME_ATLAS:
		return
	_adjust_atlas_view(-1)


func _on_action_r() -> void:
	if frame_id != FRAME_ATLAS:
		return
	_adjust_atlas_view(1)


func _on_action_e() -> void:
	if frame_id == FRAME_FIELD:
		_field_detail_open = not _field_detail_open
		_update_action_labels()
		_refresh_header()
		_render_body()
	elif frame_id == FRAME_ATLAS:
		if _atlas_selected_idx < 0 or _atlas_selected_idx >= _atlas_selectable_nodes.size():
			return
		var node_data: Dictionary = _atlas_selectable_nodes[_atlas_selected_idx]
		if node_data.get("kind", "") == "biome":
			_handoff_to_biome_inspector(str(node_data.get("name", "")))
		else:
			_atlas_detail_open = not _atlas_detail_open
			_update_action_labels()
			_render_body()


func _on_action_f() -> void:
	if frame_id == FRAME_FIELD and _field_detail_open:
		_field_detail_open = false
		_update_action_labels()
		_refresh_header()
		_render_body()
		return
	if frame_id == FRAME_ATLAS and _atlas_detail_open:
		_atlas_detail_open = false
		_update_action_labels()
		_render_body()
		return
	super._on_action_f()


func _rebuild() -> void:
	_resolve_biome()
	_refresh_field_entries()
	_refresh_cluster_snapshot()
	_refresh_header()
	_refresh_tab_row()
	_render_body()


func _refresh_header() -> void:
	if not _header_label:
		return
	var biome_name := _biome_name()
	var frame_label: String = str(FRAME_LABELS_LOCAL.get(frame_id, frame_id))
	var summary := _header_summary_text()
	_header_label.text = "%s · %s · [ %s ]" % [
		biome_name if biome_name != "" else "No active biome",
		"M surface",
		frame_label,
	]
	if _hint_label:
		_hint_label.text = summary


func _refresh_tab_row() -> void:
	if _tab_labels.is_empty():
		return
	for entry in [{"key": "T", "frame": FRAME_FIELD, "name": "Field"}, {"key": "Y", "frame": FRAME_ATLAS, "name": "Atlas"}]:
		var key_str := str(entry.get("key", ""))
		var frame_str := str(entry.get("frame", ""))
		var name_str := str(entry.get("name", ""))
		var lbl: Label = _tab_labels.get(key_str, null)
		if lbl == null:
			continue
		if frame_str == frame_id:
			lbl.text = "[%s] %s" % [key_str, name_str.to_upper()]
			lbl.add_theme_color_override("font_color", COLOR_HILITE)
		else:
			lbl.text = "[%s] %s" % [key_str, name_str]
			lbl.add_theme_color_override("font_color", COLOR_BODY)


func _header_summary_text() -> String:
	if frame_id == FRAME_FIELD:
		var entry: Dictionary = _current_field_entry()
		var selected_text := "pick a field entry"
		if not entry.is_empty():
			selected_text = _field_entry_summary(entry)
		var field_total: int = maxi(1, _field_entries.size())
		return "%s · field %d/%d · E toggles detail · F closes" % [
			selected_text,
			_selected_entry + 1,
			field_total,
		]
	if frame_id == FRAME_ATLAS:
		return "Atlas zoom %.2f · rotation %d° · Q zooms out / left · R zooms in / right" % [
			_atlas_zoom,
			int(round(_atlas_rotation_degrees)),
		]
	return "Field and Atlas share the same biome center."


func _update_action_labels() -> void:
	var labels: Dictionary
	if frame_id == FRAME_FIELD:
		labels = {
			"Q": "—",
			"E": "Inspect" if not _field_detail_open else "Close",
			"R": "—",
			"F": "Close" if _field_detail_open else "back",
		}
	elif frame_id == FRAME_ATLAS:
		var e_label := "—"
		if _atlas_selected_idx >= 0 and _atlas_selected_idx < _atlas_selectable_nodes.size():
			var nd: Dictionary = _atlas_selectable_nodes[_atlas_selected_idx]
			e_label = "Open biome" if nd.get("kind", "") == "biome" else ("Close" if _atlas_detail_open else "Inspect")
		labels = {
			"Q": "Zoom/Left",
			"E": e_label,
			"R": "Zoom/Right",
			"F": "Close" if _atlas_detail_open else "back",
		}
	else:
		labels = {"Q": "—", "E": "—", "R": "—", "F": "—"}
	if action_labels != labels:
		action_labels = labels
		action_labels_changed.emit()


func _render_body() -> void:
	if _body_box == null:
		return
	for child in _body_box.get_children():
		child.queue_free()
	match frame_id:
		FRAME_FIELD:
			_build_field_view()
		FRAME_ATLAS:
			_build_atlas_view()
		_:
			_build_stub_view()


func _build_field_view() -> void:
	_field_box = VBoxContainer.new()
	_field_box.add_theme_constant_override("separation", 6)
	_field_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_box.add_child(_field_box)

	var biome_name := _biome_name()
	var title := Label.new()
	title.text = "Field around %s" % (biome_name if biome_name != "" else "—")
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", COLOR_HILITE)
	_field_box.add_child(title)

	var native_factions: Array = _native_factions()
	var summary := Label.new()
	summary.text = "native factions: %d · standings: %d · selected entry: %d" % [
		native_factions.size(),
		_get_standing_count(),
		_selected_entry + 1,
	]
	summary.add_theme_font_size_override("font_size", 12)
	summary.add_theme_color_override("font_color", COLOR_MUTED)
	_field_box.add_child(summary)

	_field_box.add_child(_build_field_selection_card())

	if native_factions.is_empty():
		var empty := Label.new()
		empty.text = "No native factions loaded for this biome; standings still fill the field."
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", COLOR_MUTED)
		_field_box.add_child(empty)

	if _field_entries.is_empty():
		var none := Label.new()
		none.text = "No field entries available."
		none.add_theme_font_size_override("font_size", 12)
		none.add_theme_color_override("font_color", COLOR_MUTED)
		_field_box.add_child(none)
		return

	if _field_detail_open:
		_field_box.add_child(_build_field_detail_panel())

	var max_page: int = maxi(0, (_field_entries.size() - 1) / ITEM_KEYS.size())
	if max_page > 0:
		var page_lbl := Label.new()
		page_lbl.text = "page %d/%d  ·  W/S to scroll" % [_field_page + 1, max_page + 1]
		page_lbl.add_theme_font_size_override("font_size", 11)
		page_lbl.add_theme_color_override("font_color", COLOR_MUTED)
		_field_box.add_child(page_lbl)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field_box.add_child(grid)

	var page_start: int = _field_page * ITEM_KEYS.size()
	var page_end: int = mini(_field_entries.size(), page_start + ITEM_KEYS.size())
	for abs_i in range(page_start, page_end):
		var slot: int = abs_i - page_start
		grid.add_child(_make_field_card(_field_entries[abs_i], abs_i == _selected_entry, ITEM_KEYS[slot]))


func _build_field_selection_card() -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.16, 0.95)
	style.border_color = COLOR_CARD_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "Field selection"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", COLOR_HEADER)
	vbox.add_child(title)

	var entry := _current_field_entry()
	var body := Label.new()
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", COLOR_BODY)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if entry.is_empty():
		body.text = "Select a faction entry with G/H/J/K/L/;."
	else:
		body.text = _field_entry_summary(entry)
	vbox.add_child(body)

	var hint := Label.new()
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", COLOR_MUTED)
	hint.text = "E opens detail on the selected entry. F closes it again."
	vbox.add_child(hint)

	return card


func _build_field_detail_panel() -> Control:
	var entry := _current_field_entry()
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.13, 0.96)
	style.border_color = COLOR_CARD_BORDER_ACTIVE
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Selected detail"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", COLOR_HILITE)
	vbox.add_child(title)

	var body := Label.new()
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", COLOR_BODY)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = _field_entry_detail_text(entry)
	vbox.add_child(body)

	var hint := Label.new()
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", COLOR_MUTED)
	hint.text = "F flattens this panel. The selected entry stays pinned."
	vbox.add_child(hint)

	return panel


func _make_field_card(entry: Dictionary, selected: bool, key_label: String) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 54)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_CARD_BG
	style.border_color = COLOR_CARD_BORDER_ACTIVE if selected else COLOR_CARD_BORDER
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	var top := Label.new()
	top.text = "[%s] %s%s" % [key_label, str(entry.get("name", "")), "  · native" if bool(entry.get("native", false)) else ""]
	top.add_theme_font_size_override("font_size", 13)
	top.add_theme_color_override("font_color", COLOR_HEADER if selected else COLOR_BODY)
	vbox.add_child(top)

	var bottom := Label.new()
	bottom.text = "scalar %.2f" % float(entry.get("score", 0.0))
	bottom.add_theme_font_size_override("font_size", 11)
	bottom.add_theme_color_override("font_color", COLOR_MUTED)
	vbox.add_child(bottom)

	return card


func _build_atlas_view() -> void:
	_body_box.add_child(_build_atlas_status_card())

	var cluster := BiomeAffinityClusterView.new()
	cluster.custom_minimum_size = Vector2(560, 560)
	cluster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cluster.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cluster.set_scope(farm, _biome_name(), _active_biome)
	cluster.set_view_state(_atlas_zoom, _atlas_rotation_degrees)
	cluster.refresh()
	_cluster_snapshot = cluster.get_cluster_snapshot()
	_atlas_selectable_nodes = cluster.get_selectable_nodes()
	if _atlas_selected_idx >= _atlas_selectable_nodes.size():
		_atlas_selected_idx = -1
		_atlas_selected_name = ""
	if _atlas_selected_name != "":
		cluster.set_highlight_name(_atlas_selected_name)
	_body_box.add_child(cluster)

	if _atlas_detail_open and _atlas_selected_idx >= 0 and _atlas_selected_idx < _atlas_selectable_nodes.size():
		_body_box.add_child(_build_atlas_node_detail_panel(_atlas_selectable_nodes[_atlas_selected_idx]))


func _build_atlas_status_card() -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.16, 0.95)
	style.border_color = COLOR_CARD_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "Atlas state"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", COLOR_HEADER)
	vbox.add_child(title)

	var body := Label.new()
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", COLOR_BODY)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = _atlas_status_text()
	vbox.add_child(body)

	var hint := Label.new()
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", COLOR_MUTED)
	hint.text = "Q / R adjust the orbit and zoom of this atlas only."
	vbox.add_child(hint)

	return card


func _build_atlas_node_detail_panel(node_data: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.13, 0.96)
	style.border_color = COLOR_CARD_BORDER_ACTIVE
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)

	var kind: String = str(node_data.get("kind", ""))
	var name: String = str(node_data.get("name", ""))
	var score: float = float(node_data.get("score", 0.0))

	var title := Label.new()
	title.text = "%s: %s" % [kind.capitalize(), name]
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", COLOR_HILITE)
	vbox.add_child(title)

	var score_lbl := Label.new()
	score_lbl.text = "affinity score: %.2f" % score
	score_lbl.add_theme_font_size_override("font_size", 12)
	score_lbl.add_theme_color_override("font_color", COLOR_BODY)
	vbox.add_child(score_lbl)

	if kind == "faction":
		var standing_lbl := Label.new()
		standing_lbl.text = "standing scalar: %.3f" % _standing_scalar(name)
		standing_lbl.add_theme_font_size_override("font_size", 12)
		standing_lbl.add_theme_color_override("font_color", COLOR_BODY)
		vbox.add_child(standing_lbl)
		var native_lbl := Label.new()
		native_lbl.text = "native to this biome: %s" % ("yes" if bool(node_data.get("native", false)) else "no")
		native_lbl.add_theme_font_size_override("font_size", 11)
		native_lbl.add_theme_color_override("font_color", COLOR_MUTED)
		vbox.add_child(native_lbl)

	var hint := Label.new()
	hint.text = "F closes · E on a biome node opens its inspector"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", COLOR_MUTED)
	vbox.add_child(hint)

	return panel


func _handoff_to_biome_inspector(biome_name: String) -> void:
	if biome_name == "" or not farm:
		return
	var biome = null
	if farm.grid and farm.grid.has_method("get_biome"):
		biome = farm.grid.get_biome(biome_name)
	if biome == null:
		return
	var n: Node = self
	while n != null:
		if n.has_method("open_overlay") and n.has_method("set_pending_pair_scope"):
			if "biome_inspector" in n and n.biome_inspector != null and n.biome_inspector.has_method("set_biome"):
				n.biome_inspector.set_biome(biome)
			n.open_overlay("biome_detail")
			return
		n = n.get_parent()


func _build_stub_view() -> void:
	var note := Label.new()
	note.text = "Frame '%s' not implemented." % FRAME_LABELS_LOCAL.get(frame_id, frame_id)
	note.add_theme_color_override("font_color", COLOR_MUTED)
	_body_box.add_child(note)


func _refresh_field_entries() -> void:
	_field_entries.clear()
	for fname in _native_factions():
		_field_entries.append({
			"kind": "faction",
			"name": str(fname),
			"score": _standing_scalar(str(fname)),
			"native": true,
		})
	for entry in _top_standing_entries():
		if _has_field_entry(str(entry.get("name", ""))):
			continue
		_field_entries.append(entry)
	var max_page: int = maxi(0, (_field_entries.size() - 1) / ITEM_KEYS.size())
	_field_page = clampi(_field_page, 0, max_page)
	_selected_entry = clampi(_selected_entry, 0, max(0, _field_entries.size() - 1))


func _refresh_cluster_snapshot() -> void:
	if frame_id != FRAME_ATLAS:
		return
	var cluster := BiomeAffinityClusterView.new()
	cluster.set_scope(farm, _biome_name(), _active_biome)
	cluster.set_view_state(_atlas_zoom, _atlas_rotation_degrees)
	cluster.refresh()
	_cluster_snapshot = cluster.get_cluster_snapshot()
	cluster.free()


func _resolve_biome() -> void:
	if not farm:
		var gsm = InstrumentLocator.resolve_game_state_manager(self)
		if gsm and gsm.has_method("get_active_farm"):
			farm = gsm.get_active_farm()
	if not farm:
		return
	var abm = InstrumentLocator.resolve_active_biome_manager(self)
	if abm:
		var name = abm.get_active_biome()
		if name != "" and farm.grid and farm.grid.has_method("get_biome"):
			var resolved = farm.grid.get_biome(name)
			if resolved != null:
				_active_biome = resolved


func _biome_name() -> String:
	if _active_biome and _active_biome.has_method("get_biome_type"):
		return str(_active_biome.get_biome_type())
	return ""


func _native_factions() -> Array:
	if not _active_biome:
		return []
	return _active_biome.get_admitted_factions()


func _standing_scalar(faction_name: String) -> float:
	if not farm or not ("faction_standings" in farm):
		return 0.0
	var standing = farm.faction_standings.get(faction_name, null)
	if standing == null:
		return 0.0
	if standing is Dictionary:
		return float(standing.get("scalar", 0.0))
	if standing is Object and standing.has_method("scalar"):
		return float(standing.scalar())
	return float(standing) if standing is float or standing is int else 0.0


func _get_standing_count() -> int:
	if not farm or not ("faction_standings" in farm):
		return 0
	return farm.faction_standings.size()


func _top_standing_entries() -> Array:
	var entries: Array = []
	if not farm or not ("faction_standings" in farm):
		return entries
	for fname in farm.faction_standings.keys():
		entries.append({
			"kind": "faction",
			"name": str(fname),
			"score": _standing_scalar(str(fname)),
			"native": false,
		})
	entries.sort_custom(func(a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	return entries


func _has_field_entry(name: String) -> bool:
	for entry in _field_entries:
		if str(entry.get("name", "")) == name:
			return true
	return false


func _current_field_entry() -> Dictionary:
	if _selected_entry < 0 or _selected_entry >= _field_entries.size():
		return {}
	var entry: Dictionary = _field_entries[_selected_entry]
	return entry


func _field_entry_summary(entry: Dictionary) -> String:
	if entry.is_empty():
		return ""
	var native_text := "native" if bool(entry.get("native", false)) else "ranked"
	return "[%s] %s · %s · score %.2f" % [
		_selected_field_key_label(),
		str(entry.get("name", "")),
		native_text,
		float(entry.get("score", 0.0)),
	]


func _field_entry_detail_text(entry: Dictionary) -> String:
	if entry.is_empty():
		return "No field entry is selected."
	var kind := str(entry.get("kind", ""))
	var source := "native field" if bool(entry.get("native", false)) else "standing field"
	return "name: %s\nkind: %s\nsource: %s\nscore: %.3f\nslot: %s" % [
		str(entry.get("name", "")),
		kind if not kind.is_empty() else "—",
		source,
		float(entry.get("score", 0.0)),
		_selected_field_key_label(),
	]


func _selected_field_key_label() -> String:
	var slot: int = _selected_entry - (_field_page * ITEM_KEYS.size())
	if slot >= 0 and slot < ITEM_KEYS.size():
		return ITEM_KEYS[slot]
	return "?"


func _atlas_status_text() -> String:
	var biome_name: String = _biome_name()
	var biome_label: String = biome_name if biome_name != "" else "No active biome"
	var field_count: int = _field_entries.size()
	var cluster_count: int = int(_cluster_snapshot.get("biome_count", 0))
	var faction_count: int = int(_cluster_snapshot.get("faction_count", 0))
	var selected_text := ""
	if _atlas_selected_idx >= 0 and _atlas_selected_idx < _atlas_selectable_nodes.size():
		var nd: Dictionary = _atlas_selectable_nodes[_atlas_selected_idx]
		selected_text = " · [%s] %s" % [ITEM_KEYS[_atlas_selected_idx], str(nd.get("name", "?"))]
	return "%s · nodes %d biomes / %d factions · zoom %.2f · rot %d°%s" % [
		biome_label,
		int(cluster_count),
		int(faction_count),
		_atlas_zoom,
		int(round(_atlas_rotation_degrees)),
		selected_text,
	]


func _reset_view_state() -> void:
	_atlas_zoom = 1.0
	_atlas_rotation_degrees = 0.0


func _adjust_atlas_view(direction: int) -> void:
	if direction == 0:
		return
	_atlas_zoom = clampf(_atlas_zoom + (ATLAS_ZOOM_STEP * float(direction)), ATLAS_MIN_ZOOM, ATLAS_MAX_ZOOM)
	_atlas_rotation_degrees = fposmod(_atlas_rotation_degrees + (ATLAS_ROTATION_STEP * float(direction)), 360.0)
	_refresh_header()
	_render_body()


func get_visible_data() -> Dictionary:
	var selected_entry: Dictionary = _current_field_entry()
	var payload: Dictionary = {
		"frame_label": FRAME_LABELS_LOCAL.get(frame_id, frame_id),
		"selected_biome": _biome_name(),
		"native_factions": _native_factions(),
		"native_faction_count": _native_factions().size(),
		"standing_count": _get_standing_count(),
		"field_entry_count": _field_entries.size(),
		"field_detail_open": _field_detail_open,
		"selected_entry_index": _selected_entry,
		"selected_entry_label": _selected_field_key_label(),
		"selected_entry_kind": _current_field_entry().get("kind", ""),
		"atlas_zoom": _atlas_zoom,
		"atlas_rotation_degrees": _atlas_rotation_degrees,
	}
	if frame_id == FRAME_FIELD:
		payload["selected_entry"] = selected_entry
		payload["selected_entry_summary"] = _field_entry_summary(selected_entry)
		payload["selected_entry_detail"] = _field_entry_detail_text(selected_entry)
	if frame_id == FRAME_ATLAS:
		payload["cluster_snapshot"] = _cluster_snapshot.duplicate(true)
		payload["atlas_state"] = {
			"zoom": _atlas_zoom,
			"rotation_degrees": _atlas_rotation_degrees,
		}
	return payload


func get_transitions() -> Array:
	return [
		{"surface_id": "farm", "reason": "return to live instrument"},
		{"surface_id": "B", "reason": "inspect the active biome at plot scale"},
		{"surface_id": "N", "reason": "inspect the biome network"},
		{"surface_id": "V", "reason": "read atoms / icons / signature / affinity"},
	]
