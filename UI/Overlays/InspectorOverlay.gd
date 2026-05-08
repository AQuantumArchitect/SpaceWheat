class_name InspectorOverlay
extends "res://UI/Core/Surface.gd"

## InspectorOverlay — N surface (biome-to-biome Lindbladian network / selector).
##
## N is the inter-biome lens. The Network frame shows the tensor edges between
## biomes: shared atoms across qubit registers are the coupling channels, and
## any quest / story beat that lives between two biomes is anchored on one of
## those edges. Selecting an edge seeds C's pair scope so the contract board
## opens for that specific relation.
##
## Frames:
##   Network  — biome×biome tensor edges (where stories live)
##   Bridges  — factions admitted to multiple biomes (lateral structure)
##   Selector — browseable biome atlas (no scope change)
##   Live     — biomes ranked by recent chatter activity
##
## Keyboard grammar (matches KEYBOARD_GRAMMAR.md):
##   T Y U I  = direct-jump to the four frames
##   GHJKL;   = pick the focused row within the frame
##   Q ←      = screw out / retreat (clear pending C scope on Network)
##   E ↓      = pause + inspect inline detail (does NOT leave N)
##   R →      = screw in / drill into a deeper surface (open B; advance to C)
##   F ↑      = flatten any open E-snapshot
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
# Faction-edge gradient endpoints. Single-touch faction edges render at
# COLOR_EDGE_LAVENDER; bridge order k pulls toward COLOR_EDGE_AMBER along
# _bridge_intensity(k). Used by row, header, and detail-panel renderers.
const COLOR_EDGE_LAVENDER := Color(0.85, 0.65, 1.0)
const COLOR_EDGE_AMBER := Color(1.0, 0.78, 0.45)

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
	action_labels = {"Q": "—", "E": "Inspect", "R": "Open contracts", "F": "—"}


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
		# E shows "—" once detail is open (E only opens; F flattens).
		var e_label := "—" if _network_detail_open else "Inspect"
		var f_label := "Flatten" if _network_detail_open else "—"
		var r_label := "Open contracts" if (_network_selected >= 0 and _network_selected < _network_edges.size()) else "—"
		labels = {"Q": "—", "E": e_label, "R": r_label, "F": f_label}
	elif frame_id == FRAME_LIVE:
		var r_label := "Open biome" if _live_selected < _live_sorted_biomes.size() else "—"
		labels = {"Q": "—", "E": "—", "R": r_label, "F": "—"}
	elif frame_id == FRAME_MAP:
		var has_cursor := _map_biome_idx >= 0 and _map_biome_idx < _map_unlocked_biomes.size()
		var q_label := "Clear slot"
		var r_label := "Bind to slot" if has_cursor else "—"
		labels = {"Q": q_label, "E": "—", "R": r_label, "F": "—"}
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
			subtitle = "Bind biomes to TYUIOP · 1-6 slot · GHJKL; biome · R bind · Q clear"
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
				_hint_label.text = "Map binds biomes to TYUIOP keys — 1-6 picks slot, GHJKL; picks biome, R binds, Q clears."
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

## Map frame: slot-binding editor for the TYUIOP biome row.
##
## Mirrors how Network selects an inter-biome relation (an edge) — Map selects
## which biome lives on each TYUIOP key (a vertex binding). Together they edit
## the inter-biome topology: nodes here, edges there.
##
## Keys (Map frame only):
##   1 2 3 4 5 6  pick the target slot (1=T, 2=Y, 3=U, 4=I, 5=O, 6=P)
##   GHJKL;       cursor over the unlocked biome list
##   W / S        page biomes (when more than 6 unlocked)
##   R            bind cursor biome → target slot
##   Q            clear target slot
##   E            inspect cursor biome inline (reuses biome card)
func _build_map_view() -> void:
	_ensure_slot_signal_wired()
	var biomes := _get_all_biomes()
	var abm = _resolve_abm()

	# Cache unlocked biome list (biome rebinding only operates on unlocked).
	_map_unlocked_biomes = []
	if abm != null and abm.has_method("get_biome_order"):
		_map_unlocked_biomes = abm.get_biome_order()
	if _map_unlocked_biomes.is_empty():
		# Fall back to anything BiomeRegistry knows about (covers headless).
		var names: Array = biomes.keys()
		names.sort()
		for n in names:
			_map_unlocked_biomes.append(str(n))
	_map_biome_idx = clampi(_map_biome_idx, 0, maxi(0, _map_unlocked_biomes.size() - 1))
	var slot_count: int = abm.get_slot_count() if abm != null and abm.has_method("get_slot_count") else 6
	_map_target_slot = clampi(_map_target_slot, 0, maxi(0, slot_count - 1))

	var hdr := Label.new()
	hdr.text = "TYUIOP bindings  ·  %d slots  ·  %d unlocked biomes" % [slot_count, _map_unlocked_biomes.size()]
	hdr.add_theme_font_size_override("font_size", 14)
	hdr.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	_body_box.add_child(hdr)

	var sub := Label.new()
	sub.text = "1-6 pick slot  ·  GHJKL; pick biome  ·  R bind  ·  Q clear  ·  E inspect"
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", COLOR_MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_box.add_child(sub)

	# Slot strip — one row per TYUIOP slot, target highlighted.
	_body_box.add_child(_map_make_spacer(4))
	for s in range(slot_count):
		_body_box.add_child(_make_map_slot_row(s, abm))

	# Biome list — GHJKL; cursor.
	_body_box.add_child(_map_make_spacer(8))
	if _map_unlocked_biomes.is_empty():
		var empty := Label.new()
		empty.text = "No unlocked biomes yet."
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", COLOR_MUTED)
		_body_box.add_child(empty)
		return

	var visible_count: int = mini(_map_unlocked_biomes.size(), NETWORK_HOMEROW.size())
	var page_start: int = (_map_biome_idx / NETWORK_HOMEROW.size()) * NETWORK_HOMEROW.size()
	var page_end: int = mini(page_start + NETWORK_HOMEROW.size(), _map_unlocked_biomes.size())
	visible_count = page_end - page_start
	for i in range(visible_count):
		var idx: int = page_start + i
		_body_box.add_child(_make_map_biome_row(idx, NETWORK_HOMEROW[i], biomes, abm))


func _make_map_slot_row(slot_idx: int, abm) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	var is_target := (slot_idx == _map_target_slot)
	var slot_key: String = abm.get_slot_key(slot_idx) if abm != null and abm.has_method("get_slot_key") else "?"
	var bound: String = abm.get_biome_for_slot(slot_idx) if abm != null and abm.has_method("get_biome_for_slot") else ""
	var key_lbl := Label.new()
	key_lbl.text = "[%d·%s]" % [slot_idx + 1, slot_key]
	key_lbl.add_theme_font_size_override("font_size", 12)
	key_lbl.add_theme_color_override("font_color", COLOR_KEY_CHIP if is_target else COLOR_MUTED)
	key_lbl.custom_minimum_size = Vector2(72, 0)
	hbox.add_child(key_lbl)
	var name_lbl := Label.new()
	name_lbl.text = ("▸ " if is_target else "  ") + (bound if bound != "" else "—")
	name_lbl.add_theme_font_size_override("font_size", 13)
	if is_target:
		name_lbl.add_theme_color_override("font_color", COLOR_HIGHLIGHT)
	elif bound == "":
		name_lbl.add_theme_color_override("font_color", COLOR_MUTED)
	else:
		name_lbl.add_theme_color_override("font_color", COLOR_HEADER)
	hbox.add_child(name_lbl)
	return hbox


func _make_map_biome_row(idx: int, slot_key: String, biomes: Dictionary, abm) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	var is_selected := (idx == _map_biome_idx)
	var biome_name: String = str(_map_unlocked_biomes[idx])
	var bound_to: int = -1
	if abm != null and abm.has_method("get_slot_for_biome"):
		bound_to = abm.get_slot_for_biome(biome_name)
	var key_lbl := Label.new()
	key_lbl.text = "[%s]" % slot_key
	key_lbl.add_theme_font_size_override("font_size", 12)
	key_lbl.add_theme_color_override("font_color", COLOR_KEY_CHIP if is_selected else COLOR_MUTED)
	key_lbl.custom_minimum_size = Vector2(28, 0)
	hbox.add_child(key_lbl)
	var name_lbl := Label.new()
	var marker := "▸ " if is_selected else "  "
	name_lbl.text = "%s%s" % [marker, biome_name]
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", COLOR_HIGHLIGHT if is_selected else COLOR_HEADER)
	name_lbl.custom_minimum_size = Vector2(220, 0)
	hbox.add_child(name_lbl)
	if bound_to >= 0:
		var bound_lbl := Label.new()
		var bound_key: String = abm.get_slot_key(bound_to) if abm != null and abm.has_method("get_slot_key") else "?"
		bound_lbl.text = "(on %s)" % bound_key
		bound_lbl.add_theme_font_size_override("font_size", 11)
		bound_lbl.add_theme_color_override("font_color", COLOR_MUTED)
		hbox.add_child(bound_lbl)
	return hbox


func _map_make_spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _resolve_abm():
	# Resolve the ActiveBiomeManager autoload — used by the Map frame.
	var n: Node = self
	while n != null:
		if n.has_node("/root/ActiveBiomeManager"):
			return n.get_node("/root/ActiveBiomeManager")
		n = n.get_parent()
	if Engine.get_main_loop() and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("ActiveBiomeManager")
	return null


func _ensure_slot_signal_wired() -> void:
	if _map_slot_signal_connected:
		return
	var abm = _resolve_abm()
	if abm == null:
		return
	if not abm.has_signal("slot_assignment_changed"):
		return
	if not abm.slot_assignment_changed.is_connected(_on_slot_assignment_changed):
		abm.slot_assignment_changed.connect(_on_slot_assignment_changed)
	_map_slot_signal_connected = true


func _on_slot_assignment_changed(_slot_idx: int, _biome_name: String) -> void:
	if frame_id == FRAME_MAP and is_active:
		_rebuild_body()




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

# Map (Selector) frame: slot-binding editor for the TYUIOP biome row.
# _map_biome_idx is the cursor position over the unlocked biome list;
# _map_target_slot is which TYUIOP slot (0..5 = T..P) the next R/Q acts on.
var _map_biome_idx: int = 0
var _map_target_slot: int = 0
var _map_unlocked_biomes: Array = []  # cached during _build_map_view
var _map_slot_signal_connected: bool = false


func _build_network_view() -> void:
	_network_edges = _compute_network_edges()
	if _network_selected >= _network_edges.size():
		_network_selected = max(0, _network_edges.size() - 1)

	# Header reports continuous geometry: edge count + mean bridge order
	# (the scorer-facing quantity), not a categorical bridge tally.
	var live_count: int = 0
	var faction_count: int = 0
	var bridge_order_sum: float = 0.0
	for e in _network_edges:
		if e.get("faction_edge", false):
			faction_count += 1
			bridge_order_sum += float(int(e.get("bridge_count", 1)))
		else:
			live_count += 1
	var mean_bridge_order: float = (bridge_order_sum / float(faction_count)) if faction_count > 0 else 1.0
	var hdr := Label.new()
	hdr.text = "Tensor edges: %d live pairs · %d faction edges (★)  ·  mean bridge order ⟨k⟩ = %.2f" % [
		live_count, faction_count, mean_bridge_order
	]
	hdr.add_theme_font_size_override("font_size", 14)
	hdr.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	_body_box.add_child(hdr)

	var sub := Label.new()
	sub.text = "GHJKL; pick edge  ·  E inline inspect  ·  R open contract board  ·  ★ color shifts toward amber as faction signature spans more live biomes"
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
	var bridge_count: int = int(edge.get("bridge_count", 1))
	# Badge: ★ for any faction-biome edge. Bridge order shows as a smooth
	# color lerp, not a separate glyph — no categorical step.
	var prefix: String = "★" if is_faction else ""
	pair_lbl.text = "%s ⊗ %s%s" % [edge.a, prefix, edge.b]
	pair_lbl.add_theme_font_size_override("font_size", 13)
	var pair_color: Color
	if is_selected:
		pair_color = COLOR_HIGHLIGHT
	elif is_faction:
		pair_color = _faction_edge_color(bridge_count)
	else:
		pair_color = COLOR_BRIDGE_FACTION
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
	var bridge_count: int = int(edge.get("bridge_count", 1))
	var header := Label.new()
	var hdr_prefix: String = "★" if is_faction else ""
	header.text = "  %s ⊗ %s%s" % [edge.a, hdr_prefix, edge.b]
	header.add_theme_font_size_override("font_size", 14)
	# Header tracks the row-badge gradient so detail-open keeps visual continuity.
	header.add_theme_color_override("font_color",
		_faction_edge_color(bridge_count) if is_faction else COLOR_HIGHLIGHT)
	vbox.add_child(header)

	# Bridge mediator: list the other live biomes this faction's signature
	# also touches. Stories on the tensor edge through this faction-biome
	# can flow between any pair of partners listed here. Threshold k>1 is
	# data-derived (a faction touching only one live biome has no partners
	# to list), not a categorical step in the scoring.
	if is_faction and bridge_count > 1:
		var partners_raw: Array = edge.get("bridge_partners", [])
		var others: Array = []
		for p in partners_raw:
			var pn := str(p)
			if pn != "" and pn != str(edge.a):
				others.append(pn)
		if not others.is_empty():
			var bridge_lbl := Label.new()
			bridge_lbl.text = "  bridge order k=%d  ·  also touches %s" % [bridge_count, " · ".join(others)]
			bridge_lbl.add_theme_font_size_override("font_size", 12)
			bridge_lbl.add_theme_color_override("font_color", _faction_edge_color(bridge_count))
			vbox.add_child(bridge_lbl)

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


## Edge salience as a multiplicative composition of five smooth, continuous
## factors — no flat bonuses, no categorical steps. Each factor is bounded or
## monotonic in its underlying geometric quantity:
##
##   tension_signal = tension / (1 + tension)        → [0, 1), saturates
##   richness       = sqrt(shared_count)             → diminishing returns
##   bridge_factor  = 1 + ln(bridge_count)           → 1 at k=1, ~1.69 at k=2,
##                                                      ~2.10 at k=3, smooth log
##   drift_factor   = 1 + 0.5 * tanh(drift)          → (0.5, 1.5), symmetric
##   affinity_factor = 0.75 + 0.5 * affinity         → [0.75, 1.25] when known;
##                                                      else 1.0 (no penalty)
##
## Pass through `bridge_count = 1` for single-touch edges (live↔live, single
## faction-touch) and `affinity = -1` when not computed; the helper degrades
## gracefully to the remaining factors. The 0.5 boost on bridge edges and the
## 0.05*n bonus on shared atoms in earlier code were both replaced by
## bridge_factor and richness respectively — same intent, smoother gradient.
static func _edge_score(
	tension: float, shared_count: int, bridge_count: int = 1,
	drift: float = 0.0, affinity: float = -1.0
) -> float:
	var t := maxf(tension, 0.0)
	var tension_signal := t / (1.0 + t)
	var richness := sqrt(float(maxi(0, shared_count)))
	var bridge_factor := 1.0 + log(float(maxi(1, bridge_count)))
	var drift_factor := 1.0 + 0.5 * tanh(drift)
	var affinity_factor: float = 1.0
	if affinity >= 0.0:
		affinity_factor = 0.75 + 0.5 * clampf(affinity, 0.0, 1.0)
	return tension_signal * richness * bridge_factor * drift_factor * affinity_factor


## Bridge intensity as a continuous saturation of bridge_count. Returns 0 at
## k=1 (no bridge), ~0.29 at k=2, ~0.42 at k=3, asymptotic to 1. Smooth across
## all integers; used for color-lerping the row badge so the 1→2 transition
## is a gradient, not a step.
static func _bridge_intensity(bridge_count: int) -> float:
	var k := float(maxi(1, bridge_count))
	return 1.0 - 1.0 / sqrt(k)


## Faction-edge color along the lavender→amber gradient. k=1 sits at lavender
## (single-touch), higher k pulls toward amber along _bridge_intensity.
static func _faction_edge_color(bridge_count: int) -> Color:
	return COLOR_EDGE_LAVENDER.lerp(COLOR_EDGE_AMBER, _bridge_intensity(bridge_count))


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
			var drift_val: float = (pred_tension - tension) if pred_valid else 0.0
			edges.append({
				"a": a, "b": bb,
				"shared": shared, "tension": tension,
				"tension_drift": drift_val,
				"tension_drift_valid": pred_valid,
				"affinity": affinity,
				"bridge_count": 1,  # live↔live: no faction mediator
				"score": _edge_score(tension, shared.size(), 1, drift_val, affinity),
				"faction_edge": false,
			})

	# Faction-biome edges. Emit (live_biome ↔ faction_biome) for every live
	# biome whose qubit register shares at least one atom with the faction
	# signature. When a single faction's signature touches 2+ live biomes,
	# both sides of that faction are "bridge" edges — the faction_biome is
	# a tensor mediator between physical biomes that don't share atoms
	# directly. This is where inter-biome stories anchor.
	var br = BiomeRegistry.get_shared()
	for fb in br.get_biomes_by_tag("faction_biome"):
		var marg_fb: Dictionary = MarketLatticeCls._static_marginals_from_spec(fb)
		# First pass per faction-biome: collect which live biomes it touches.
		var touched: Array = []  # [{biome, shared, tension}]
		for bname in bnames:
			var marg_live: Dictionary = marg_cache.get(bname, {})
			var shared_atoms: Array = []
			var tens: float = 0.0
			for emoji in marg_live.keys():
				if marg_fb.has(emoji):
					shared_atoms.append(emoji)
					tens += abs(float(marg_live[emoji]) - float(marg_fb[emoji]))
			if not shared_atoms.is_empty():
				touched.append({"biome": bname, "shared": shared_atoms, "tension": tens})
		if touched.is_empty():
			continue
		# bridge_count is the continuous quantity: how many live biomes this
		# faction's signature touches. The score's bridge_factor (1 + ln(k))
		# rises smoothly with k — no step at the 1→2 boundary.
		var bridge_count: int = touched.size()
		var bridge_partners: Array = []
		for t in touched:
			bridge_partners.append(str(t.biome))
		for t in touched:
			edges.append({
				"a": str(t.biome), "b": fb.name,
				"shared": t.shared, "tension": t.tension,
				"score": _edge_score(t.tension, t.shared.size(), bridge_count),
				"faction_edge": true,
				"bridge_count": bridge_count,
				"bridge_partners": bridge_partners,
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
		elif frame_id == FRAME_MAP:
			if idx < _map_unlocked_biomes.size():
				_map_biome_idx = idx
				_update_action_labels()
				_rebuild_body()
			return true
	# Map frame: number row 1..6 picks the target TYUIOP slot.
	if frame_id == FRAME_MAP:
		var slot_num: int = -1
		match keycode:
			KEY_1: slot_num = 0
			KEY_2: slot_num = 1
			KEY_3: slot_num = 2
			KEY_4: slot_num = 3
			KEY_5: slot_num = 4
			KEY_6: slot_num = 5
		if slot_num >= 0:
			_map_target_slot = slot_num
			_update_action_labels()
			_rebuild_body()
			return true
	return false


func _on_action_q() -> void:
	# Map frame: Q = screw-out / clear the target TYUIOP slot.
	if frame_id == FRAME_MAP:
		var abm = _resolve_abm()
		if abm != null and abm.has_method("clear_slot"):
			abm.clear_slot(_map_target_slot)
		# Body rebuilds on slot_assignment_changed signal.


func _on_action_e() -> void:
	# E = pause + inspect inline. Only opens panels; never closes them (F flattens).
	if frame_id == FRAME_NETWORK:
		if _network_edges.is_empty():
			return
		if not _network_detail_open:
			_network_detail_open = true
			_update_action_labels()
			_rebuild_body()


func _on_action_r() -> void:
	# R = screw in. On Network: open contracts. On Live: drill into B. On Map:
	# bind the cursor biome to the target TYUIOP slot (commit the binding).
	if frame_id == FRAME_NETWORK:
		# Advance to the contract board (C) with this edge already scoped.
		if _network_selected < 0 or _network_selected >= _network_edges.size():
			return
		_update_pending_pair_scope()
		var om = _resolve_overlay_manager()
		if om != null and om.has_method("show_overlay"):
			om.show_overlay("contracts")
		elif om != null and om.has_method("toggle_overlay"):
			om.toggle_overlay("contracts")
	elif frame_id == FRAME_LIVE:
		if _live_selected < _live_sorted_biomes.size():
			_handoff_to_biome_inspector(str(_live_sorted_biomes[_live_selected]))
	elif frame_id == FRAME_MAP:
		if _map_biome_idx < 0 or _map_biome_idx >= _map_unlocked_biomes.size():
			return
		var biome_name := str(_map_unlocked_biomes[_map_biome_idx])
		var abm = _resolve_abm()
		if abm != null and abm.has_method("set_slot_assignment"):
			abm.set_slot_assignment(_map_target_slot, biome_name)
		# Body rebuilds on slot_assignment_changed signal.


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
	sub.text = "GHJKL; pick biome  ·  R drill into B (biome inspector)"
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
