class_name MapMetaOverlay
extends "res://UI/Core/Surface.gd"

## M — Affinity Hypercube.
##
## Tabs map to the 12-D complex affinity substrate that holds every faction:
##   T  vectors    — pairwise faction relationship: A vs B per-axis disagreement
##   Y  eigenstate — factions ranked by alignment with the joint system principal axis
##   U  drift      — Farm.player_alignment vs pinned-faction.alignment (player trajectory)
##   I  bits       — raw 12-axis readout for one faction (marginals + complex coherence)
##   O  atlas      — visual-spatial cluster layout (preserved from prior M)
##
## Cross-tab state: Y selects a faction → _selected_faction_b → drives T's B side
## and I's target. T/U/I share a focused axis (GHJKL; → 0–5, W/S → 6–11).

const AlignmentGraphCls = preload("res://Core/Alignment/AlignmentGraph.gd")
const BroadGraphRef = preload("res://Core/QuantumSubstrate/BroadGraph.gd")
const NeighborhoodGraphRef = preload("res://Core/QuantumSubstrate/NeighborhoodGraph.gd")
const BroadGraphViewRef = preload("res://UI/Overlays/BroadGraphView.gd")
const NeighborhoodGraphViewRef = preload("res://UI/Overlays/NeighborhoodGraphView.gd")

# =============================================================================
# FRAMES + KEY GRAMMAR
# =============================================================================

const FRAME_VECTORS := "vectors"
const FRAME_EIGEN := "eigen"
const FRAME_DRIFT := "drift"
const FRAME_BITS := "bits"
const FRAME_ATLAS := "atlas"
const FRAME_GRAPH := "graph"

const FRAME_LABELS_LOCAL := {
	FRAME_VECTORS: "Vectors",
	FRAME_EIGEN: "Eigenstate",
	FRAME_DRIFT: "Drift",
	FRAME_BITS: "Bits",
	FRAME_ATLAS: "Atlas",
	FRAME_GRAPH: "Graph",
}

const TAB_ROW := [
	{"key": "T", "frame": FRAME_VECTORS, "name": "Vectors"},
	{"key": "Y", "frame": FRAME_EIGEN,   "name": "Eigenstate"},
	{"key": "U", "frame": FRAME_DRIFT,   "name": "Drift"},
	{"key": "I", "frame": FRAME_BITS,    "name": "Bits"},
	{"key": "O", "frame": FRAME_ATLAS,   "name": "Atlas"},
	{"key": "P", "frame": FRAME_GRAPH,   "name": "Graph"},
]

const ITEM_KEYS := ["G", "H", "J", "K", "L", ";"]
# Plot-ring keycode→slot via InputBindingRegistry.plot_index_for_keycode (shared source).

# Eigenstate sort modes — selected automatically from pinned-faction state.
# SYSTEM ranks by alignment with the joint principal axis (used when detached).
# SUBJECT ranks by affinity with the pinned faction (used when a faction is
# pinned). No chord: 1/2/3 are reserved for the active hat's axis selector.
const EIGEN_SORT_SYSTEM := 0
const EIGEN_SORT_SUBJECT := 1
const EIGEN_SORT_LABELS := {
	EIGEN_SORT_SYSTEM: "System",
	EIGEN_SORT_SUBJECT: "Subject",
}

# Atlas knobs (preserved from prior M).
const ATLAS_MIN_ZOOM: float = 0.72
const ATLAS_MAX_ZOOM: float = 1.55
const ATLAS_ZOOM_STEP: float = 0.10
const ATLAS_ROTATION_STEP: float = 12.0

# Phase clock glyphs — 8 slices around atan2(im, re).
const PHASE_GLYPHS := ["→", "↗", "↑", "↖", "←", "↙", "↓", "↘"]

# =============================================================================
# COLORS
# =============================================================================
const COLOR_MUTED := Color(0.55, 0.6, 0.7, 0.9)
const COLOR_HILITE := Color(0.95, 0.87, 0.45)
const COLOR_CARD_BG_SEL := Color(0.18, 0.16, 0.10, 0.95)
const COLOR_CARD_BORDER := Color(0.28, 0.35, 0.45, 0.7)
const COLOR_AXIS_A := Color(0.55, 0.85, 1.0, 0.95)   # blue (faction A / player)
const COLOR_AXIS_B := Color(0.95, 0.65, 0.85, 0.95)  # pink (faction B / pinned)
const COLOR_AXIS_DELTA := Color(0.95, 0.55, 0.45, 1.0)
const COLOR_PHASE := Color(0.65, 0.95, 0.85, 0.95)

# =============================================================================
# STATE
# =============================================================================

var farm: Node = null
var _active_biome: Node = null  # kept for Atlas + set_biome external contract

# Cross-tab state
var _selected_faction_b: String = ""   # set by Eigen, used by Vectors/Bits
var _selected_axis: int = 0            # 0..11
var _axis_page: int = 0                # 0 → axes 0..5; 1 → axes 6..11
var _eigen_page: int = 0
var _eigen_selected: int = 0           # absolute index into roster

# Atlas (preserved)
var _atlas_zoom: float = 1.0
var _atlas_rotation_degrees: float = 0.0
var _atlas_selected_idx: int = -1
var _atlas_selected_name: String = ""
var _atlas_selectable_nodes: Array = []
var _atlas_detail_open: bool = false
var _cluster_snapshot: Dictionary = {}

# Graph (P) — BroadGraph federation + neighborhood drill-down.
var _graph_zoom: String = "broad"        # "broad" or a biome name (drilled in)
var _broad = null                        # cached BroadGraph (rebuilt on biome change)
var _graph_selectable: Array = []        # biome names, keyboard selection order
var _graph_selected_idx: int = -1
var _graph_broad_view = null             # live BroadGraphView ref (highlight without re-render)
var _graph_neigh_view = null             # live NeighborhoodGraphView ref (drill-down, E-inspect)

# Cached per-render
var _faction_roster: Array = []        # Array[Faction], stable order

# UI nodes
var _header_label: Label
var _hint_label: Label
var _tab_row_box: HBoxContainer
var _tab_labels: Dictionary = {}
var _body_box: VBoxContainer

func _init() -> void:
	overlay_name = "map_meta"
	overlay_icon = "🗺"
	overlay_tier = 12
	panel_title = "Affinity Hypercube"
	panel_title_size = 22
	panel_size_mode = PanelSizeMode.LARGE
	show_dimmer = true
	dimmer_color = Color(0, 0, 0, 0.75)
	panel_border_color = Color(0.3, 0.5, 0.6, 0.8)
	use_scroll_container = true
	content_spacing = 8
	navigation_mode = NavigationMode.NONE
	surface_id = "M"
	frame_ids = [FRAME_VECTORS, FRAME_EIGEN, FRAME_DRIFT, FRAME_BITS, FRAME_ATLAS, FRAME_GRAPH]
	frame_id = FRAME_VECTORS
	# Initial labels — _update_action_labels() sets frame-specific richness on first render.
	set_action_info("Q", {"label": "—"})
	set_action_info("E", {"label": "—"})
	set_action_info("R", {"label": "—"})
	set_action_info("F", {"label": "—"})

func _ready() -> void:
	super._ready()
	var abm = (Engine.get_main_loop().root.get_node_or_null("/root/ActiveBiomeManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if abm and abm.has_signal("active_biome_changed"):
		abm.active_biome_changed.connect(_on_active_biome_changed)

func set_biome(biome: Node) -> void:
	# Only Atlas is biome-anchored; affinity tabs are biome-agnostic. Kept for
	# OverlayManager + PlayerShell call sites.
	if biome != _active_biome:
		_active_biome = biome
		context_id = _biome_name()
		if frame_id == FRAME_ATLAS:
			_atlas_zoom = 1.0
			_atlas_rotation_degrees = 0.0
			_atlas_selected_idx = -1
			_atlas_selected_name = ""
			_atlas_detail_open = false
		_update_action_labels()
		_rebuild()

# =============================================================================
# UI BUILD
# =============================================================================

func _build_content(container: Control) -> void:
	_header_label = Label.new()
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 14)
	_header_label.add_theme_color_override("font_color", UIStyleFactory.COLOR_HEADER)
	container.add_child(_header_label)

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 11)
	_hint_label.add_theme_color_override("font_color", COLOR_MUTED)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(_hint_label)

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

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.4, 0.4, 0.3, 0.45))
	container.add_child(sep)

	_body_box = VBoxContainer.new()
	_body_box.add_theme_constant_override("separation", 6)
	_body_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_body_box)

	_update_action_labels()
	_rebuild()

# =============================================================================
# LIFECYCLE
# =============================================================================

func _on_activated() -> void:
	_resolve_biome()
	_update_action_labels()
	_rebuild()
	super._on_activated()

func _on_active_biome_changed(new_biome: String, _old_biome: String) -> void:
	if not visible or not is_active:
		return
	if farm and farm.grid and farm.grid.has_method("get_biome"):
		_active_biome = farm.grid.get_biome(new_biome)
	context_id = new_biome
	_broad = null  # the live-biome set may have changed — rebuild federation lazily
	if frame_id == FRAME_ATLAS or frame_id == FRAME_GRAPH:
		_rebuild()

func _on_frame_changed(_new_frame_id: String, _prev_frame_id: String) -> void:
	# Most state survives across tabs (cross-tab _selected_faction_b, _selected_axis).
	# Only Atlas-local state resets on its tab return.
	if _new_frame_id == FRAME_ATLAS:
		_atlas_detail_open = false
	if _new_frame_id == FRAME_GRAPH:
		# Always enter the graph at the broad federation level.
		_graph_zoom = "broad"
		_graph_selected_idx = -1
	_update_action_labels()
	_rebuild()

# =============================================================================
# INPUT
# =============================================================================

func _on_unhandled_key(keycode: int, _event: InputEvent) -> bool:
	if super._on_unhandled_key(keycode, _event):
		return true

	# Graph keeps its own key grammar: broad → GHJKL;/W/S move the biome cursor;
	# neighborhood drill-down has no per-key selection (F returns to broad).
	if frame_id == FRAME_GRAPH:
		if _graph_zoom != "broad":
			return false
		if _graph_selectable.is_empty():
			return false
		var moved := false
		var idx: int = InputBindingRegistry.plot_index_for_keycode(keycode, 6)
		if idx >= 0:
			if idx < _graph_selectable.size():
				_graph_selected_idx = idx
				moved = true
		elif keycode == KEY_W:
			_graph_selected_idx = maxi(0, _graph_selected_idx - 1)
			moved = true
		elif keycode == KEY_S:
			_graph_selected_idx = mini(_graph_selectable.size() - 1, _graph_selected_idx + 1)
			moved = true
		if moved:
			_apply_graph_highlight()
			_update_action_labels()
			return true
		return false

	# Atlas keeps its own key grammar (G/H/J/K/L/; selects nodes).
	if frame_id == FRAME_ATLAS:
		var idx: int = InputBindingRegistry.plot_index_for_keycode(keycode, 6)
		if idx >= 0:
			if idx < _atlas_selectable_nodes.size():
				_atlas_selected_idx = idx
				_atlas_selected_name = str(_atlas_selectable_nodes[idx].get("name", ""))
				_atlas_detail_open = false
				_update_action_labels()
				_render_body()
			return true
		return false

	# Affinity tabs share axis selection (T, U, I) and roster selection (Y).
	var slot: int = InputBindingRegistry.plot_index_for_keycode(keycode, 6)
	if slot >= 0:
		match frame_id:
			FRAME_EIGEN:
				var page_offset: int = _eigen_page * ITEM_KEYS.size()
				var abs_idx: int = page_offset + slot
				if abs_idx < _faction_roster.size():
					_eigen_selected = abs_idx
					_render_body()
				return true
			FRAME_VECTORS, FRAME_DRIFT, FRAME_BITS:
				var axis_idx: int = _axis_page * ITEM_KEYS.size() + slot
				if axis_idx < AlignmentGraphCls.AXIS_COUNT:
					_selected_axis = axis_idx
					_render_body()
				return true
		return false

	# W/S — page nav. Roster pages on Eigen; axis pages elsewhere.
	if keycode == KEY_W:
		match frame_id:
			FRAME_EIGEN:
				_eigen_page = maxi(0, _eigen_page - 1)
				_eigen_selected = clampi(_eigen_selected, _eigen_page * ITEM_KEYS.size(),
					mini(_faction_roster.size() - 1, (_eigen_page + 1) * ITEM_KEYS.size() - 1))
				_render_body()
				return true
			FRAME_VECTORS, FRAME_DRIFT, FRAME_BITS:
				if _axis_page > 0:
					_axis_page = 0
					_selected_axis = clampi(_selected_axis, 0, ITEM_KEYS.size() - 1)
					_render_body()
				return true
	if keycode == KEY_S:
		match frame_id:
			FRAME_EIGEN:
				var max_page: int = maxi(0, int(float(_faction_roster.size() - 1) / float(ITEM_KEYS.size())))
				_eigen_page = mini(max_page, _eigen_page + 1)
				_eigen_selected = clampi(_eigen_selected, _eigen_page * ITEM_KEYS.size(),
					mini(_faction_roster.size() - 1, (_eigen_page + 1) * ITEM_KEYS.size() - 1))
				_render_body()
				return true
			FRAME_VECTORS, FRAME_DRIFT, FRAME_BITS:
				if _axis_page < 1 and AlignmentGraphCls.AXIS_COUNT > ITEM_KEYS.size():
					_axis_page = 1
					_selected_axis = clampi(_selected_axis, ITEM_KEYS.size(),
						AlignmentGraphCls.AXIS_COUNT - 1)
					_render_body()
				return true
	return false

# =============================================================================
# ACTIONS
# =============================================================================

func _on_action_q() -> void:
	if frame_id == FRAME_ATLAS:
		_adjust_atlas_view(-1)

func _on_action_e() -> void:
	match frame_id:
		FRAME_EIGEN:
			# Pick the focused row → set as B + jump to Bits.
			if _eigen_selected >= 0 and _eigen_selected < _faction_roster.size():
				var f = _faction_roster[_eigen_selected]
				if f != null and "name" in f:
					_selected_faction_b = str(f.name)
					set_frame(FRAME_BITS)
		FRAME_ATLAS:
			if _atlas_selected_idx < 0 or _atlas_selected_idx >= _atlas_selectable_nodes.size():
				return
			var node_data: Dictionary = _atlas_selectable_nodes[_atlas_selected_idx]
			if str(node_data.get("kind", "")) == "biome":
				_activate_biome(str(node_data.get("name", "")))
			else:
				_atlas_detail_open = not _atlas_detail_open
				_update_action_labels()
				_render_body()
		FRAME_GRAPH:
			if _graph_zoom == "broad":
				# Drill into the selected biome's neighborhood cluster.
				if _graph_selected_idx >= 0 and _graph_selected_idx < _graph_selectable.size():
					_graph_zoom = str(_graph_selectable[_graph_selected_idx])
					_update_action_labels()
					_render_body()
			else:
				# Already drilled in — E makes this the active biome for the play surface.
				_activate_biome(_graph_zoom)

# =============================================================================
# INSPECT TEXT — what E pops up as a toast (OverlayBase calls get_inspect_text
# right after _on_action_e). Touch-first: E is the canonical "more information"
# channel of the QERF plane; hover tooltips only mirror what lives here.
# Note the ordering: on Graph·broad, E drills in FIRST, so the toast explains
# the cluster the player just entered.
# =============================================================================

func get_inspect_text() -> String:
	match frame_id:
		FRAME_EIGEN:
			return _eigen_inspect_text()
		FRAME_GRAPH:
			return _graph_inspect_text()
		FRAME_BITS:
			return _bits_inspect_text()
	return ""


## E on a Bits row: the focused axis, spoken — name, authored description,
## numbers, and the canon stance word.
func _bits_inspect_text() -> String:
	var fb = _get_faction_by_name(_selected_faction_b)
	if fb == null:
		fb = _get_pinned_faction()
	if fb == null or fb.alignment == null:
		return ""
	if _selected_axis < 0 or _selected_axis >= AlignmentGraphCls.AXIS_COUNT:
		return ""
	var ag = fb.alignment
	var pt: Dictionary = ag.partial_trace_axis(_selected_axis)
	var p0 := float(pt.get("p0", 0.0))
	var p1 := float(pt.get("p1", 0.0))
	var off: Vector2 = pt.get("off", Vector2.ZERO)
	var lines: Array[String] = []
	lines.append("%s — %s" % [FactionAxes.axis_name(_selected_axis), str(fb.name)])
	var desc := FactionAxes.axis_description(_selected_axis)
	if desc != "":
		lines.append(desc)
	lines.append("p₀=%.2f · p₁=%.2f · |c|=%.2f — %s" % [p0, p1, off.length(),
			_axis_stance(_selected_axis, p0, p1, off.length())])
	return "\n".join(lines)


func _eigen_inspect_text() -> String:
	var lines: Array[String] = []
	if farm != null and ("faction_density" in farm) and farm.faction_density != null \
			and farm.faction_density.has_method("get_purity"):
		var fd = farm.faction_density
		var p: float = float(fd.get_purity())
		lines.append("You · Tr(ρ²) = %.3f — %s" % [p, _soul_gloss(p)])
		lines.append("Purity of your alignment density matrix: 1 = a committed identity; the mixed floor = a life not yet chosen.")
		var parts: Array[String] = _becoming_parts(true)
		if not parts.is_empty():
			lines.append("becoming: %s" % " · ".join(parts))
		if fd.has_method("dominant_factions"):
			var names: Array[String] = []
			for row in fd.dominant_factions(3):
				names.append("%s %.2f" % [str(row.get("name", "?")), float(row.get("weight", 0.0))])
			if not names.is_empty():
				lines.append("who holds you: %s" % " · ".join(names))
		lines.append("Only learning moves the committed mass — each new icon pumps its owner and everyone who speaks its poles. Coherences between selves fade on their own (τ=300s).")
	return "\n".join(lines)


func _graph_inspect_text() -> String:
	if _graph_zoom == "broad":
		if _graph_broad_view != null and is_instance_valid(_graph_broad_view) \
				and _graph_selected_idx >= 0 and _graph_selected_idx < _graph_selectable.size():
			return _graph_broad_view.inspect_text_for(str(_graph_selectable[_graph_selected_idx]))
		return ""
	var lines: Array[String] = []
	if _graph_neigh_view != null and is_instance_valid(_graph_neigh_view):
		lines.append(str(_graph_neigh_view.inspect_text()))
	var compass := _compass_line(_graph_zoom)
	if compass != "":
		lines.append(compass)
		var wet := _regime_line(_graph_zoom)
		if wet != "":
			lines.append(wet)
		else:
			lines.append("The depths (the eigenvalues of ρ) are conserved — no unitary motion can change them. Exactly one act reaches them: measurement.")
	var knot := _knot_line(_graph_zoom)
	if knot != "":
		lines.append(knot)
	if _biome_closed_here(_graph_zoom):
		var canonical = _canonical_biome(_graph_zoom)
		if _biome_has_webway(canonical):
			var speaker := str(canonical.first_native_faction()) if canonical.has_method("first_native_faction") else ""
			var whisper := QuestVoice.webway_whisper(speaker)
			if whisper != "":
				lines.append("💬 %s“%s”" % [("%s — " % speaker) if speaker != "" else "", whisper])
	return "\n".join(lines)


## Is the named biome effectively closed? Prefers the live QC's per-biome regime
## (What Fades seam); falls back to the global switch.
func _biome_closed_here(biome_name: String) -> bool:
	var qc = _live_qc_for(biome_name)
	if qc != null and qc.has_method("is_open_here"):
		return not qc.is_open_here()
	return not BalanceConfig.dissipative_enabled()


func _on_action_r() -> void:
	if frame_id == FRAME_ATLAS:
		_adjust_atlas_view(1)

func _on_action_f() -> void:
	if frame_id == FRAME_ATLAS and _atlas_detail_open:
		_atlas_detail_open = false
		_update_action_labels()
		_render_body()
		return
	if frame_id == FRAME_GRAPH and _graph_zoom != "broad":
		# Back out of the neighborhood drill-down to the broad federation.
		_graph_zoom = "broad"
		_update_action_labels()
		_render_body()
		return
	super._on_action_f()

# =============================================================================
# RENDER PIPELINE
# =============================================================================

func _rebuild() -> void:
	_resolve_biome()
	_refresh_faction_roster()
	_normalize_selection_state()
	_refresh_header()
	_refresh_tab_row()
	_render_body()

func _refresh_faction_roster() -> void:
	_faction_roster = []
	if farm == null or not ("faction_density" in farm) or farm.faction_density == null:
		return
	var registry = farm.faction_density.get_registry()
	if registry == null:
		return
	for f in registry.get_all():
		if f != null:
			_faction_roster.append(f)

func _normalize_selection_state() -> void:
	# B defaults to first non-pinned faction if unset.
	if _selected_faction_b == "":
		var pname := _get_pinned_faction_name()
		for f in _faction_roster:
			if f != null and "name" in f and str(f.name) != pname:
				_selected_faction_b = str(f.name)
				break
	# Axis page consistency.
	_axis_page = clampi(_axis_page, 0, 1)
	_selected_axis = clampi(_selected_axis, 0, AlignmentGraphCls.AXIS_COUNT - 1)
	# Eigen pagination.
	var max_page: int = maxi(0, int(float(_faction_roster.size() - 1) / float(ITEM_KEYS.size())))
	_eigen_page = clampi(_eigen_page, 0, max_page)
	_eigen_selected = clampi(_eigen_selected, 0, max(0, _faction_roster.size() - 1))

func _refresh_header() -> void:
	if not _header_label:
		return
	var frame_label: String = str(FRAME_LABELS_LOCAL.get(frame_id, frame_id))
	var pname := _get_pinned_faction_name()
	var pin_label: String = pname if pname != "" else "Detached"
	_header_label.text = "M · Affinity Hypercube · [ %s ] · pinned: %s" % [frame_label, pin_label]
	if _hint_label:
		_hint_label.text = _hint_text_for_frame()

func _refresh_tab_row() -> void:
	if _tab_labels.is_empty():
		return
	for entry in TAB_ROW:
		var key_str := str(entry.get("key", ""))
		var lbl: Label = _tab_labels.get(key_str, null)
		if lbl == null:
			continue
		var name_str := str(entry.get("name", ""))
		if str(entry.get("frame", "")) == frame_id:
			lbl.text = "[%s] %s" % [key_str, name_str.to_upper()]
			lbl.add_theme_color_override("font_color", COLOR_HILITE)
		else:
			lbl.text = "[%s] %s" % [key_str, name_str]
			lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_BODY)

func _render_body() -> void:
	if _body_box == null:
		return
	for child in _body_box.get_children():
		child.queue_free()
	match frame_id:
		FRAME_VECTORS: _build_vectors_body()
		FRAME_EIGEN:   _build_eigen_body()
		FRAME_DRIFT:   _build_drift_body()
		FRAME_BITS:    _build_bits_body()
		FRAME_ATLAS:   _build_atlas_body()
		FRAME_GRAPH:   _build_graph_body()

func _update_action_labels() -> void:
	match frame_id:
		FRAME_VECTORS:
			set_action_info("Q", {"label": "—"})
			set_action_info("E", {"label": "—"})
			set_action_info("R", {"label": "—"})
			set_action_info("F", {"label": "—"})
		FRAME_EIGEN:
			set_action_info("Q", {"label": "—"})
			set_action_info("E", {
				"label": "Inspect",
				"emoji": "🔬",
				"hint": "Drill into eigenstate detail — switches to Bits frame",
			})
			set_action_info("R", {"label": "—"})
			set_action_info("F", {"label": "—"})
		FRAME_DRIFT:
			set_action_info("Q", {"label": "—"})
			set_action_info("E", {"label": "—"})
			set_action_info("R", {"label": "—"})
			set_action_info("F", {"label": "—"})
		FRAME_BITS:
			set_action_info("Q", {"label": "—"})
			set_action_info("E", {
				"label": "Inspect",
				"emoji": "🔬",
				"hint": "Read the focused axis — name, meaning, canon stance",
			})
			set_action_info("R", {"label": "—"})
			set_action_info("F", {"label": "—"})
		FRAME_ATLAS:
			var e_label := "—"
			var e_emoji := ""
			var e_hint := ""
			if _atlas_selected_idx >= 0 and _atlas_selected_idx < _atlas_selectable_nodes.size():
				var nd: Dictionary = _atlas_selectable_nodes[_atlas_selected_idx]
				if nd.get("kind", "") == "biome":
					e_label = "Activate"; e_emoji = "⚡"
					e_hint = "Set as active biome for the play surface"
				elif _atlas_detail_open:
					e_label = "Close"; e_emoji = "✕"
					e_hint = "Close the detail panel"
				else:
					e_label = "Inspect"; e_emoji = "🔬"
					e_hint = "Open detail view for this node"
			var f_open := _atlas_detail_open
			set_action_info("Q", {"label": "Zoom/L", "emoji": "←", "hint": "Scroll left / zoom out in the atlas"})
			set_action_info("E", {"label": e_label, "emoji": e_emoji, "hint": e_hint})
			set_action_info("R", {"label": "Zoom/R", "emoji": "→", "hint": "Scroll right / zoom in in the atlas"})
			set_action_info("F", {
				"label": "Close" if f_open else "—",
				"emoji": "✕" if f_open else "",
				"hint": "Close the atlas detail panel" if f_open else "",
			})
		FRAME_GRAPH:
			if _graph_zoom == "broad":
				var can_drill := _graph_selected_idx >= 0 and _graph_selected_idx < _graph_selectable.size()
				set_action_info("Q", {"label": "—"})
				set_action_info("E", {
					"label": "Drill in" if can_drill else "—",
					"emoji": "🔬" if can_drill else "",
					"hint": "Open the selected biome's neighborhood cluster" if can_drill else "Select a biome with GHJKL;",
				})
				set_action_info("R", {"label": "—"})
				set_action_info("F", {"label": "—"})
			else:
				set_action_info("Q", {"label": "—"})
				set_action_info("E", {"label": "Activate", "emoji": "⚡", "hint": "Set this biome active for the play surface"})
				set_action_info("R", {"label": "—"})
				set_action_info("F", {"label": "Back", "emoji": "↩", "hint": "Return to the broad federation graph"})
		_:
			set_action_info("Q", {"label": "—"})
			set_action_info("E", {"label": "—"})
			set_action_info("R", {"label": "—"})
			set_action_info("F", {"label": "—"})
	action_labels_changed.emit()

func _hint_text_for_frame() -> String:
	match frame_id:
		FRAME_VECTORS:
			return "GHJKL; pick axis · W/S page (0–5 / 6–11) · pick B via Y · Eigenstate"
		FRAME_EIGEN:
			return "Sort follows pin state (Subject when pinned, System when detached) · GHJKL; select · W/S page · E inspect → Bits"
		FRAME_DRIFT:
			return "GHJKL; pick axis · W/S page · trade in C tugs the player"
		FRAME_BITS:
			return "GHJKL; pick axis · W/S page · pick faction via Y · Eigenstate"
		FRAME_ATLAS:
			return "GHJKL; pick node · Q/R adjust orbit · E inspect / activate biome"
		FRAME_GRAPH:
			if _graph_zoom == "broad":
				return "Whole-world federation · GHJKL; / W·S pick biome · E drill into its cluster"
			return "%s cluster · drag/scroll to pan · E activate biome · F back to federation" % _graph_zoom
	return ""

# =============================================================================
# T — VECTORS BODY
# =============================================================================

func _build_vectors_body() -> void:
	var fa = _get_pinned_faction()
	var fb = _get_faction_by_name(_selected_faction_b)
	if fa == null or fa.alignment == null or fb == null or fb.alignment == null:
		_body_box.add_child(_make_muted_label("No pinned faction this run — the pin is who you ARE (set by the scenario; The Demos by default). Pick a comparison faction via Y · Eigenstate.", 12))
		return

	var ov: float = fa.alignment.overlap(fb.alignment)
	var hdr := Label.new()
	hdr.text = "%s ⊗ %s · overlap=%.3f · norm=%.3f" % [
		str(fa.name), str(fb.name), ov, 1.0 - ov,
	]
	hdr.add_theme_font_size_override("font_size", 13)
	hdr.add_theme_color_override("font_color", COLOR_HILITE)
	_body_box.add_child(hdr)

	# Page header
	var page_lbl := Label.new()
	page_lbl.text = "axes %d..%d · W/S to flip" % [_axis_page * ITEM_KEYS.size(), mini(AlignmentGraphCls.AXIS_COUNT - 1, (_axis_page + 1) * ITEM_KEYS.size() - 1)]
	page_lbl.add_theme_font_size_override("font_size", 10)
	page_lbl.add_theme_color_override("font_color", COLOR_MUTED)
	_body_box.add_child(page_lbl)

	# 6 axis rows on the current page.
	var page_start: int = _axis_page * ITEM_KEYS.size()
	var page_end: int = mini(AlignmentGraphCls.AXIS_COUNT, page_start + ITEM_KEYS.size())
	for i in range(page_start, page_end):
		var slot: int = i - page_start
		_body_box.add_child(_make_pair_axis_row(i, fa, fb, ITEM_KEYS[slot], i == _selected_axis))

func _make_pair_axis_row(axis_i: int, fa, fb, key_str: String, selected: bool) -> Control:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_stylebox_override("panel", _row_stylebox(selected))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	hbox.add_child(_make_key_chip(key_str, selected))

	var ax_lbl := Label.new()
	ax_lbl.text = "[%d] %s/%s" % [axis_i, FactionAxes.pole_emoji(axis_i, 0), FactionAxes.pole_emoji(axis_i, 1)]
	ax_lbl.add_theme_font_size_override("font_size", 13)
	ax_lbl.add_theme_color_override("font_color", COLOR_HILITE if selected else UIStyleFactory.COLOR_BODY)
	ax_lbl.custom_minimum_size = Vector2(110, 0)
	hbox.add_child(ax_lbl)

	var pa: float = fa.alignment.axis_marginal(axis_i, 1)
	var pb: float = fb.alignment.axis_marginal(axis_i, 1)
	var delta: float = absf(pa - pb)

	var a_lbl := Label.new()
	a_lbl.text = "A p₁=%.2f %s" % [pa, _ratio_bar(pa, 5)]
	a_lbl.add_theme_font_size_override("font_size", 11)
	a_lbl.add_theme_color_override("font_color", COLOR_AXIS_A)
	a_lbl.custom_minimum_size = Vector2(150, 0)
	hbox.add_child(a_lbl)

	var b_lbl := Label.new()
	b_lbl.text = "B p₁=%.2f %s" % [pb, _ratio_bar(pb, 5)]
	b_lbl.add_theme_font_size_override("font_size", 11)
	b_lbl.add_theme_color_override("font_color", COLOR_AXIS_B)
	b_lbl.custom_minimum_size = Vector2(150, 0)
	hbox.add_child(b_lbl)

	var d_lbl := Label.new()
	d_lbl.text = "|Δ|=%.2f %s" % [delta, _ratio_bar(delta, 5)]
	d_lbl.add_theme_font_size_override("font_size", 11)
	d_lbl.add_theme_color_override("font_color", COLOR_AXIS_DELTA)
	d_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(d_lbl)
	return row

# =============================================================================
# Y — EIGENSTATE BODY
# =============================================================================

func _build_eigen_body() -> void:
	if _faction_roster.is_empty():
		_body_box.add_child(_make_muted_label("No factions in registry.", 12))
		return

	# WHO AM I BECOMING — the player's concept state, read as physics. Purity of
	# the alignment density matrix: 1 = a committed identity, low = smeared across
	# many selves. Learning moves the committed mass (each icon pumps factions);
	# coherences fade on their own (τ=300s) — the one open system in the enclave
	# (docs/glossary/soul.md).
	if farm != null and ("faction_density" in farm) and farm.faction_density != null \
			and farm.faction_density.has_method("get_purity"):
		var soul_purity: float = float(farm.faction_density.get_purity())
		var soul_lbl := Label.new()
		soul_lbl.text = "You · Tr(ρ²)=%.3f — %s" % [soul_purity, _soul_gloss(soul_purity)]
		soul_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		soul_lbl.add_theme_font_size_override("font_size", 12)
		soul_lbl.add_theme_color_override("font_color", COLOR_HILITE)
		soul_lbl.tooltip_text = "Purity of your alignment density matrix. Learning moves it — each new icon pumps its owner and everyone who speaks its poles; coherences fade on their own (τ=300s)."
		_body_box.add_child(soul_lbl)
		var becoming: Array[String] = _becoming_parts(false)
		if not becoming.is_empty():
			_body_box.add_child(_make_muted_label("becoming: %s" % " · ".join(becoming), 11))

	# Sort mode is derived from pinned-faction state — no chord.
	var sort_mode: int = EIGEN_SORT_SUBJECT if _get_pinned_faction() != null else EIGEN_SORT_SYSTEM
	var mode_lbl := Label.new()
	mode_lbl.text = "sort: %s" % str(EIGEN_SORT_LABELS.get(sort_mode, ""))
	mode_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_lbl.add_theme_font_size_override("font_size", 11)
	mode_lbl.add_theme_color_override("font_color", COLOR_MUTED)
	_body_box.add_child(mode_lbl)

	if sort_mode == EIGEN_SORT_SUBJECT:
		_build_eigen_body_subject()
	else:
		_build_eigen_body_system()


## Words for the purity of a soul. The band thresholds live in exactly one
## place — FactionDensityMatrix.band_key (which also drives the crossing
## whispers); this maps its keys to display wording.
const SOUL_GLOSS_WORDS := {
	"resolved": "resolved",
	"leaning": "leaning",
	"torn": "torn",
	"smeared": "smeared across many selves",
}

func _soul_gloss(p: float) -> String:
	return str(SOUL_GLOSS_WORDS.get(FactionDensityMatrix.band_key(p), "?"))


## "becoming:" fragments from the identity ρ's decisive axes — emoji + pole
## label, optionally with the pole confidence. One home for both the E-inspect
## text and the eigen body label.
func _becoming_parts(with_confidence: bool) -> Array[String]:
	var parts: Array[String] = []
	if farm == null or not ("faction_density" in farm) or farm.faction_density == null \
			or not farm.faction_density.has_method("decisive_axes"):
		return parts
	for row in farm.faction_density.decisive_axes(3):
		var emoji := str(row.get("emoji", ""))
		var label := str(row.get("label", "")).to_lower()
		if with_confidence:
			var conf: float = float(row.get("p", 0.5))
			if int(row.get("bit", 1)) == 0:
				conf = 1.0 - conf
			parts.append("%s %s %.2f" % [emoji, label, conf])
		else:
			parts.append("%s %s" % [emoji, label])
	return parts

## Sort by alignment with the joint system's principal axis (synthetic-overlap).
func _build_eigen_body_system() -> void:
	var projection: Array = _get_principal_axis_projection()
	var principal_mode: Dictionary = _get_principal_mode()
	# The synthetic identity-side state lives in one home now:
	# FactionDensityMatrix.principal_graph() (same construction, shared with kinship).
	var synthetic = null
	if farm != null and ("faction_density" in farm) and farm.faction_density != null \
			and farm.faction_density.has_method("principal_graph"):
		synthetic = farm.faction_density.principal_graph()

	var ranked: Array = []
	for f in _faction_roster:
		if f == null or f.alignment == null:
			continue
		var ov: float = f.alignment.overlap(synthetic) if synthetic != null else 0.0
		ranked.append({"f": f, "score": ov, "hamming": -1, "kind": "system"})
	ranked.sort_custom(func(a, b): return float(a.score) > float(b.score))

	var hdr := Label.new()
	var eigval: float = float(principal_mode.get("eigenvalue", 0.0))
	hdr.text = "System eigenstate · eigenvalue=%.3f · projection=[%s]" % [eigval, _format_axis_projection(projection)]
	hdr.add_theme_font_size_override("font_size", 12)
	hdr.add_theme_color_override("font_color", COLOR_HILITE)
	hdr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_box.add_child(hdr)

	_render_eigen_rows(ranked)

## Sort by affinity (overlap) with the pinned faction. Each row also shows
## the static hamming distance on initial bits.
func _build_eigen_body_subject() -> void:
	var subject = _get_pinned_faction()
	if subject == null:
		_body_box.add_child(_make_muted_label("(detached) — pin a faction to see its eigenstate.", 12))
		return
	if subject.alignment == null:
		_body_box.add_child(_make_muted_label("Subject has no alignment — registry not loaded?", 12))
		return
	var subject_name: String = str(subject.name) if "name" in subject else "?"

	var subject_bits: PackedByteArray = subject.bits if "bits" in subject else PackedByteArray()

	var ranked: Array = []
	for f in _faction_roster:
		if f == null or f.alignment == null:
			continue
		if f == subject:
			continue  # skip self
		var aff: float = subject.alignment.overlap(f.alignment)
		var ham: int = -1
		if "bits" in f:
			ham = _hamming_distance(subject_bits, f.bits)
		ranked.append({"f": f, "score": aff, "hamming": ham, "kind": "subject"})
	ranked.sort_custom(func(a, b): return float(a.score) > float(b.score))

	var hdr := Label.new()
	hdr.text = "Subject: %s · roster: %d · sort: affinity desc" % [subject_name, ranked.size()]
	hdr.add_theme_font_size_override("font_size", 12)
	hdr.add_theme_color_override("font_color", COLOR_HILITE)
	_body_box.add_child(hdr)

	_render_eigen_rows(ranked)

func _render_eigen_rows(ranked: Array) -> void:
	var max_page: int = maxi(0, int(float(ranked.size() - 1) / float(ITEM_KEYS.size())))
	var page_lbl := Label.new()
	page_lbl.text = "page %d/%d · W/S" % [_eigen_page + 1, max_page + 1]
	page_lbl.add_theme_font_size_override("font_size", 10)
	page_lbl.add_theme_color_override("font_color", COLOR_MUTED)
	_body_box.add_child(page_lbl)

	var page_start: int = _eigen_page * ITEM_KEYS.size()
	var page_end: int = mini(ranked.size(), page_start + ITEM_KEYS.size())
	for abs_i in range(page_start, page_end):
		var slot: int = abs_i - page_start
		_body_box.add_child(_make_eigen_row(ranked[abs_i], ITEM_KEYS[slot], abs_i == _eigen_selected))

func _make_eigen_row(entry: Dictionary, key_str: String, selected: bool) -> Control:
	var f = entry.get("f", null)
	var score: float = float(entry.get("score", 0.0))
	var hamming: int = int(entry.get("hamming", -1))
	var kind: String = str(entry.get("kind", "system"))
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_stylebox_override("panel", _row_stylebox(selected))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	hbox.add_child(_make_key_chip(key_str, selected))

	var sig_glyph: String = ""
	if f != null and "cloud" in f and f.cloud.size() > 0:
		sig_glyph = str(f.cloud[0])
	var glyph_lbl := Label.new()
	glyph_lbl.text = sig_glyph if sig_glyph != "" else " "
	glyph_lbl.add_theme_font_size_override("font_size", 16)
	glyph_lbl.custom_minimum_size = Vector2(28, 0)
	hbox.add_child(glyph_lbl)

	var name_lbl := Label.new()
	name_lbl.text = str(f.name) if f != null and "name" in f else "?"
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", COLOR_HILITE if selected else UIStyleFactory.COLOR_BODY)
	name_lbl.custom_minimum_size = Vector2(170, 0)
	name_lbl.clip_text = true
	hbox.add_child(name_lbl)

	# Primary scalar — affinity in subject mode, alignment-with-system in system mode.
	var score_lbl := Label.new()
	var score_label_text := "aff" if kind == "subject" else "align"
	score_lbl.text = "%s=%.3f %s" % [score_label_text, score, _ratio_bar(score, 6)]
	score_lbl.add_theme_font_size_override("font_size", 11)
	score_lbl.add_theme_color_override("font_color", COLOR_AXIS_A)
	score_lbl.custom_minimum_size = Vector2(160, 0)
	hbox.add_child(score_lbl)

	# Hamming column (only in subject mode; static lore-baseline distance).
	if hamming >= 0:
		var ham_lbl := Label.new()
		ham_lbl.text = "ham=%d" % hamming
		ham_lbl.add_theme_font_size_override("font_size", 11)
		ham_lbl.add_theme_color_override("font_color", _hamming_color(hamming))
		ham_lbl.custom_minimum_size = Vector2(56, 0)
		hbox.add_child(ham_lbl)

	# 12-bit corner identity.
	var bits_lbl := Label.new()
	if f != null and f.alignment != null:
		var bits: PackedByteArray = f.alignment.principal_bits()
		bits_lbl.text = _bits_to_str(bits)
	else:
		bits_lbl.text = ""
	bits_lbl.add_theme_font_size_override("font_size", 11)
	bits_lbl.add_theme_color_override("font_color", COLOR_MUTED)
	bits_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(bits_lbl)

	return row

# =============================================================================
# U — DRIFT BODY
# =============================================================================

func _build_drift_body() -> void:
	if farm == null or not ("player_alignment" in farm) or farm.player_alignment == null:
		_body_box.add_child(_make_muted_label("Farm.player_alignment not bound.", 12))
		return

	var player_ag = farm.player_alignment
	var pname := _get_pinned_faction_name()
	var pinned = _get_pinned_faction()
	var pinned_ag = pinned.alignment if (pinned != null and pinned.alignment != null) else null

	var hdr := Label.new()
	hdr.add_theme_font_size_override("font_size", 13)
	hdr.add_theme_color_override("font_color", COLOR_HILITE)
	if pinned_ag != null:
		var ov: float = player_ag.overlap(pinned_ag)
		hdr.text = "Pinned: %s · drift=%.3f · player_purity=%.3f · pinned_purity=%.3f" % [
			pname, 1.0 - ov, player_ag.purity(), pinned_ag.purity(),
		]
	else:
		hdr.text = "Detached · player_purity=%.3f" % player_ag.purity()
	_body_box.add_child(hdr)

	# Page nav
	var page_lbl := Label.new()
	page_lbl.text = "axes %d..%d · W/S" % [_axis_page * ITEM_KEYS.size(), mini(AlignmentGraphCls.AXIS_COUNT - 1, (_axis_page + 1) * ITEM_KEYS.size() - 1)]
	page_lbl.add_theme_font_size_override("font_size", 10)
	page_lbl.add_theme_color_override("font_color", COLOR_MUTED)
	_body_box.add_child(page_lbl)

	var page_start: int = _axis_page * ITEM_KEYS.size()
	var page_end: int = mini(AlignmentGraphCls.AXIS_COUNT, page_start + ITEM_KEYS.size())
	for i in range(page_start, page_end):
		var slot: int = i - page_start
		_body_box.add_child(_make_drift_axis_row(i, player_ag, pinned_ag, ITEM_KEYS[slot], i == _selected_axis))

func _make_drift_axis_row(axis_i: int, player_ag, pinned_ag, key_str: String, selected: bool) -> Control:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_stylebox_override("panel", _row_stylebox(selected))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)
	hbox.add_child(_make_key_chip(key_str, selected))

	var ax_lbl := Label.new()
	ax_lbl.text = "[%d] %s/%s" % [axis_i, FactionAxes.pole_emoji(axis_i, 0), FactionAxes.pole_emoji(axis_i, 1)]
	ax_lbl.add_theme_font_size_override("font_size", 13)
	ax_lbl.add_theme_color_override("font_color", COLOR_HILITE if selected else UIStyleFactory.COLOR_BODY)
	ax_lbl.custom_minimum_size = Vector2(110, 0)
	hbox.add_child(ax_lbl)

	var pp: float = player_ag.axis_marginal(axis_i, 1)
	var p_lbl := Label.new()
	p_lbl.text = "player p₁=%.2f %s" % [pp, _ratio_bar(pp, 5)]
	p_lbl.add_theme_font_size_override("font_size", 11)
	p_lbl.add_theme_color_override("font_color", COLOR_AXIS_A)
	p_lbl.custom_minimum_size = Vector2(170, 0)
	hbox.add_child(p_lbl)

	if pinned_ag != null:
		var pf: float = pinned_ag.axis_marginal(axis_i, 1)
		var pin_lbl := Label.new()
		pin_lbl.text = "pinned p₁=%.2f %s" % [pf, _ratio_bar(pf, 5)]
		pin_lbl.add_theme_font_size_override("font_size", 11)
		pin_lbl.add_theme_color_override("font_color", COLOR_AXIS_B)
		pin_lbl.custom_minimum_size = Vector2(170, 0)
		hbox.add_child(pin_lbl)

		var d_lbl := Label.new()
		var delta: float = absf(pp - pf)
		d_lbl.text = "|Δ|=%.2f %s" % [delta, _ratio_bar(delta, 5)]
		d_lbl.add_theme_font_size_override("font_size", 11)
		d_lbl.add_theme_color_override("font_color", COLOR_AXIS_DELTA)
		d_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(d_lbl)
	else:
		var det_lbl := Label.new()
		det_lbl.text = "(detached)"
		det_lbl.add_theme_color_override("font_color", COLOR_MUTED)
		det_lbl.add_theme_font_size_override("font_size", 11)
		det_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(det_lbl)
	return row

# =============================================================================
# I — BITS BODY
# =============================================================================

func _build_bits_body() -> void:
	var fb = _get_faction_by_name(_selected_faction_b)
	if fb == null:
		fb = _get_pinned_faction()
	if fb == null or fb.alignment == null:
		_body_box.add_child(_make_muted_label("No faction selected — use Y · Eigenstate to pick one.", 12))
		return

	var ag = fb.alignment
	var bits: PackedByteArray = ag.principal_bits()
	var hdr := Label.new()
	hdr.text = "%s · purity=%.3f · rank=%d · principal_bits=%s" % [
		str(fb.name), ag.purity(), ag.rank(), _bits_to_str(bits),
	]
	hdr.add_theme_font_size_override("font_size", 13)
	hdr.add_theme_color_override("font_color", COLOR_HILITE)
	_body_box.add_child(hdr)

	# Page nav
	var page_lbl := Label.new()
	page_lbl.text = "axes %d..%d · W/S" % [_axis_page * ITEM_KEYS.size(), mini(AlignmentGraphCls.AXIS_COUNT - 1, (_axis_page + 1) * ITEM_KEYS.size() - 1)]
	page_lbl.add_theme_font_size_override("font_size", 10)
	page_lbl.add_theme_color_override("font_color", COLOR_MUTED)
	_body_box.add_child(page_lbl)

	var page_start: int = _axis_page * ITEM_KEYS.size()
	var page_end: int = mini(AlignmentGraphCls.AXIS_COUNT, page_start + ITEM_KEYS.size())
	for i in range(page_start, page_end):
		var slot: int = i - page_start
		_body_box.add_child(_make_bits_axis_row(i, ag, ITEM_KEYS[slot], i == _selected_axis))

func _make_bits_axis_row(axis_i: int, ag, key_str: String, selected: bool) -> Control:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_stylebox_override("panel", _row_stylebox(selected))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)
	hbox.add_child(_make_key_chip(key_str, selected))

	var pt: Dictionary = ag.partial_trace_axis(axis_i)
	var p0: float = float(pt.get("p0", 0.0))
	var p1: float = float(pt.get("p1", 0.0))
	var off: Vector2 = pt.get("off", Vector2.ZERO)
	var coh_mag: float = off.length()
	var phase_glyph: String = _phase_glyph(off)

	var ax_lbl := Label.new()
	ax_lbl.text = "[%d] %s/%s" % [axis_i, FactionAxes.pole_emoji(axis_i, 0), FactionAxes.pole_emoji(axis_i, 1)]
	ax_lbl.add_theme_font_size_override("font_size", 13)
	ax_lbl.add_theme_color_override("font_color", COLOR_HILITE if selected else UIStyleFactory.COLOR_BODY)
	ax_lbl.custom_minimum_size = Vector2(110, 0)
	hbox.add_child(ax_lbl)

	var p0_lbl := Label.new()
	p0_lbl.text = "p₀=%.2f %s" % [p0, _ratio_bar(p0, 5)]
	p0_lbl.add_theme_font_size_override("font_size", 11)
	p0_lbl.add_theme_color_override("font_color", COLOR_AXIS_A)
	p0_lbl.custom_minimum_size = Vector2(140, 0)
	hbox.add_child(p0_lbl)

	var p1_lbl := Label.new()
	p1_lbl.text = "p₁=%.2f %s" % [p1, _ratio_bar(p1, 5)]
	p1_lbl.add_theme_font_size_override("font_size", 11)
	p1_lbl.add_theme_color_override("font_color", COLOR_AXIS_B)
	p1_lbl.custom_minimum_size = Vector2(140, 0)
	hbox.add_child(p1_lbl)

	var coh_lbl := Label.new()
	coh_lbl.text = "|c|=%.2f %s %s" % [coh_mag, _ratio_bar(coh_mag, 5), phase_glyph]
	coh_lbl.add_theme_font_size_override("font_size", 11)
	coh_lbl.add_theme_color_override("font_color", COLOR_PHASE)
	coh_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(coh_lbl)

	# Canon stance word — the numbers, read aloud (same family as the soul gloss).
	var stance_lbl := Label.new()
	stance_lbl.text = _axis_stance(axis_i, p0, p1, coh_mag)
	stance_lbl.add_theme_font_size_override("font_size", 11)
	stance_lbl.add_theme_color_override("font_color", COLOR_HILITE if selected else COLOR_MUTED)
	stance_lbl.custom_minimum_size = Vector2(150, 0)
	hbox.add_child(stance_lbl)
	return row


## Canon words for one axis of a 12-axis alignment state — the same family as
## the soul gloss. "Woven" wins when off-diagonal coherence carries the axis
## (a superposed stance is not the same as a torn one); otherwise the leading
## pole's label with commitment strength.
func _axis_stance(axis_i: int, p0: float, p1: float, coh_mag: float) -> String:
	if coh_mag >= 0.35:
		return "woven %s↔%s" % [FactionAxes.pole_emoji(axis_i, 0), FactionAxes.pole_emoji(axis_i, 1)]
	var lead_bit := 0 if p0 >= p1 else 1
	var lead_p := maxf(p0, p1)
	var word := FactionAxes.pole_label(axis_i, lead_bit)
	if lead_p >= 0.75:
		return "resolved: %s" % word
	if lead_p >= 0.6:
		return "leaning %s" % word
	return "torn"

# =============================================================================
# O — ATLAS BODY (preserved; cluster visualization)
# =============================================================================

func _build_atlas_body() -> void:
	_body_box.add_child(_build_atlas_status_card())

	var cluster := BiomeAlignmentClusterView.new()
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

	var biome_name: String = _biome_name()
	var body := Label.new()
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", UIStyleFactory.COLOR_BODY)
	body.text = "%s · biomes %d / factions %d · zoom %.2f · rot %d°" % [
		biome_name if biome_name != "" else "—",
		int(_cluster_snapshot.get("biome_count", 0)),
		int(_cluster_snapshot.get("faction_count", 0)),
		_atlas_zoom,
		int(round(_atlas_rotation_degrees)),
	]
	vbox.add_child(body)

	var hint := Label.new()
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", COLOR_MUTED)
	hint.text = "Q / R adjust orbit. GHJKL; selects a node. E inspects."
	vbox.add_child(hint)
	return card

func _build_atlas_node_detail_panel(node_data: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.13, 0.96)
	style.border_color = UIStyleFactory.COLOR_CARD_BORDER_ACTIVE
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
	var _node_name: String = str(node_data.get("name", ""))
	var score: float = float(node_data.get("score", 0.0))

	var title := Label.new()
	title.text = "%s: %s" % [kind.capitalize(), name]
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", COLOR_HILITE)
	vbox.add_child(title)

	var score_lbl := Label.new()
	score_lbl.text = "affinity score: %.2f" % score
	score_lbl.add_theme_font_size_override("font_size", 12)
	score_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_BODY)
	vbox.add_child(score_lbl)

	var hint := Label.new()
	hint.text = "F closes · E on a biome activates it (sets the live biome)"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", COLOR_MUTED)
	vbox.add_child(hint)
	return panel

# =============================================================================
# HELPERS — affinity / faction
# =============================================================================

func _get_pinned_faction_name() -> String:
	var local_farm = InstrumentLocator.resolve_active_farm(self)
	if local_farm == null or not local_farm.has_method("get_pinned_faction_name"):
		return ""
	return local_farm.get_pinned_faction_name()

func _get_pinned_faction():
	var pname := _get_pinned_faction_name()
	if pname == "":
		return null  # Detached. Caller renders "(detached)".
	return _get_faction_by_name(pname)

func _get_faction_by_name(faction_search_name: String):
	if faction_search_name == "":
		return null
	for f in _faction_roster:
		if f != null and "name" in f and str(f.name) == faction_search_name:
			return f
	return null

func _get_principal_axis_projection() -> Array:
	if farm == null or not ("faction_density" in farm) or farm.faction_density == null:
		return FactionAxes.uniform_marginals()
	if not farm.faction_density.has_method("get_principal_axis_projection"):
		return FactionAxes.uniform_marginals()
	var arr = farm.faction_density.get_principal_axis_projection()
	if arr is Array and arr.size() == AlignmentGraphCls.AXIS_COUNT:
		return arr
	return FactionAxes.uniform_marginals()

func _get_principal_mode() -> Dictionary:
	if farm == null or not ("faction_density" in farm) or farm.faction_density == null:
		return {}
	if not farm.faction_density.has_method("get_principal_mode"):
		return {}
	return farm.faction_density.get_principal_mode()

# =============================================================================
# HELPERS — render primitives
# =============================================================================

func _row_stylebox(selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_CARD_BG_SEL if selected else UIStyleFactory.COLOR_CARD_BG
	sb.border_color = UIStyleFactory.COLOR_CARD_BORDER_ACTIVE if selected else COLOR_CARD_BORDER
	sb.border_width_left = 4 if selected else 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

func _make_key_chip(key_str: String, selected: bool) -> Label:
	var lbl := Label.new()
	lbl.text = "[%s]" % key_str
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", COLOR_HILITE if selected else COLOR_AXIS_A)
	lbl.custom_minimum_size = Vector2(28, 0)
	return lbl

func _make_muted_label(text: String, icon_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", icon_size)
	lbl.add_theme_color_override("font_color", COLOR_MUTED)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl

func _ratio_bar(ratio: float, length: int) -> String:
	var clamped: float = clampf(ratio, 0.0, 1.0)
	var filled: int = int(round(clamped * float(length)))
	filled = clampi(filled, 0, length)
	var bar := ""
	for i in range(length):
		bar += "▮" if i < filled else "▯"
	return bar

func _phase_glyph(off: Vector2) -> String:
	if off.length_squared() < 1e-12:
		return "·"
	var theta: float = atan2(off.y, off.x)
	# Bucket into 8 slices; rotate by π/8 so the bands center on cardinal arrows.
	var idx: int = int(round((theta + PI) / (PI / 4.0))) % PHASE_GLYPHS.size()
	return PHASE_GLYPHS[idx]

## Hamming distance on initial bit corners. -1 if either array is malformed.
func _hamming_distance(a: PackedByteArray, b: PackedByteArray) -> int:
	if a.size() != b.size() or a.size() == 0:
		return -1
	var d: int = 0
	for i in range(a.size()):
		if a[i] != b[i]:
			d += 1
	return d

## Color stops for hamming readout: 0 = strongest ally, 12 = perfect mirror.
func _hamming_color(h: int) -> Color:
	if h <= 2:
		return Color(0.55, 0.95, 0.6, 0.95)   # green — natural ally
	if h <= 5:
		return Color(0.85, 0.9, 0.55, 0.95)   # warm — neutral
	if h <= 8:
		return Color(0.95, 0.75, 0.45, 0.95)  # amber — disagreement
	return Color(0.95, 0.5, 0.5, 0.95)        # red — opposition

func _bits_to_str(bits: PackedByteArray) -> String:
	var out := ""
	for i in range(bits.size()):
		out += "1" if bits[i] != 0 else "0"
	return out

func _format_axis_projection(projection: Array) -> String:
	var parts: PackedStringArray = []
	for v in projection:
		parts.append("%.2f" % float(v))
	return ",".join(parts)

# =============================================================================
# HELPERS — Atlas (preserved)
# =============================================================================

func _adjust_atlas_view(direction: int) -> void:
	if direction == 0:
		return
	_atlas_zoom = clampf(_atlas_zoom + (ATLAS_ZOOM_STEP * float(direction)), ATLAS_MIN_ZOOM, ATLAS_MAX_ZOOM)
	_atlas_rotation_degrees = fposmod(_atlas_rotation_degrees + (ATLAS_ROTATION_STEP * float(direction)), 360.0)
	_render_body()

# =============================================================================
# P — GRAPH BODY (BroadGraph federation ⟷ neighborhood drill-down)
# =============================================================================

func _build_graph_body() -> void:
	_graph_broad_view = null
	_graph_neigh_view = null
	_body_box.add_child(_build_graph_status_card())

	if _graph_zoom == "broad":
		if _broad == null:
			_broad = BroadGraphRef.build(null, null, null, _live_biome_filter())
		var view = BroadGraphViewRef.new()
		view.custom_minimum_size = Vector2(640, 520)
		_body_box.add_child(view)
		view.populate(_broad)
		# Live entanglement badges: resolve each federation node to its live QC.
		view.set_live_lookup(_live_qc_for)
		_graph_broad_view = view
		_graph_selectable = view.get_selectable_biomes()
		if _graph_selected_idx >= _graph_selectable.size():
			_graph_selected_idx = -1
		if _graph_selected_idx < 0 and not _graph_selectable.is_empty():
			# Default the cursor to the active biome if it's in the federation.
			var ai: int = _graph_selectable.find(_biome_name())
			_graph_selected_idx = ai if ai >= 0 else 0
		if _graph_selected_idx >= 0:
			view.set_highlight(str(_graph_selectable[_graph_selected_idx]))
	else:
		var nview = NeighborhoodGraphViewRef.new()
		nview.custom_minimum_size = Vector2(640, 520)
		_body_box.add_child(nview)
		# Live source BEFORE populate: the webway draws in this biome's true
		# regime (wet country LIVE, sealed elsewhere — What Fades seam).
		nview.set_live_source(_live_qc_for(_graph_zoom))
		var canonical = _canonical_biome(_graph_zoom)
		if canonical != null:
			nview.populate(NeighborhoodGraphRef.from_biome(canonical))
		_graph_neigh_view = nview


func _build_graph_status_card() -> Control:
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
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	var body := Label.new()
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", UIStyleFactory.COLOR_BODY)
	if _graph_zoom == "broad":
		var bcount: int = _broad.biome_count() if _broad != null else 0
		var ecount: int = _broad.edge_count() if _broad != null else 0
		var qcount: int = _broad.total_qubits() if _broad != null else 0
		var sel: String = str(_graph_selectable[_graph_selected_idx]) if (_graph_selected_idx >= 0 and _graph_selected_idx < _graph_selectable.size()) else "—"
		body.text = "Federation · biomes %d · seams %d · qubits %d · ▶ %s" % [bcount, ecount, qcount, sel]
	else:
		var seal := " · webway sealed" if _biome_closed_here(_graph_zoom) else " · 🌊 wet country"
		body.text = "%s · neighborhood cluster (live%s)" % [_graph_zoom, seal]
	vbox.add_child(body)

	# The eigenstate compass: what the biome most IS right now, and how decidedly
	# (dominant eigenstate of ρ + eigenvalue gap). Press E for the conservation law.
	if _graph_zoom != "broad":
		var compass := _compass_line(_graph_zoom)
		if compass != "":
			var cl := Label.new()
			cl.text = compass
			cl.add_theme_font_size_override("font_size", 11)
			cl.add_theme_color_override("font_color", UIStyleFactory.COLOR_BODY)
			cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(cl)
		# Wet-country passport (What Fades): this biome runs open — say so where
		# the player is already reading.
		var wet := _regime_line(_graph_zoom)
		if wet != "":
			var wl2 := Label.new()
			wl2.text = wet
			wl2.add_theme_font_size_override("font_size", 11)
			wl2.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
			wl2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(wl2)
		# Knot card (What Connects): frozen loop records + the pair invariant.
		var knot := _knot_line(_graph_zoom)
		if knot != "":
			var kl := Label.new()
			kl.text = knot
			kl.add_theme_font_size_override("font_size", 11)
			kl.add_theme_color_override("font_color", UIStyleFactory.COLOR_BODY)
			kl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(kl)

	# Standing at sealed channels, a native faction has something to say about
	# them (QuestVoice.webway_whisper — words only, no mechanics).
	if _graph_zoom != "broad" and _biome_closed_here(_graph_zoom):
		var canonical = _canonical_biome(_graph_zoom)
		if _biome_has_webway(canonical):
			var speaker := str(canonical.first_native_faction()) if canonical.has_method("first_native_faction") else ""
			var whisper := QuestVoice.webway_whisper(speaker)
			if whisper != "":
				var wl := Label.new()
				wl.text = "💬 %s“%s”" % [("%s — " % speaker) if speaker != "" else "", whisper]
				wl.add_theme_font_size_override("font_size", 11)
				wl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
				wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				wl.tooltip_text = "The webway: this biome's authored Lindblad channels — sealed here, where the country runs closed (dark orange edges below). In the wet country the same channels run live."
				vbox.add_child(wl)
	return card


## Does the canonical biome author any Lindblad channels (webway/decay) at all?
func _biome_has_webway(canonical) -> bool:
	if canonical == null or not ("atom_components" in canonical) or not (canonical.atom_components is Dictionary):
		return false
	for k in canonical.atom_components.keys():
		var comp = canonical.atom_components[k]
		if comp is Dictionary and (comp.has("lindblad_outgoing") or comp.has("lindblad_incoming") or comp.has("decay")):
			return true
	return false


## Highlight the selected biome node without rebuilding the whole body.
func _apply_graph_highlight() -> void:
	if _graph_broad_view != null and is_instance_valid(_graph_broad_view) \
			and _graph_selected_idx >= 0 and _graph_selected_idx < _graph_selectable.size():
		_graph_broad_view.set_highlight(str(_graph_selectable[_graph_selected_idx]))


## Live/unlocked biomes — the realistic, cheap federation scope (vs all ~160).
func _live_biome_filter() -> Array:
	var abm = (Engine.get_main_loop().root.get_node_or_null("/root/ActiveBiomeManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if abm and abm.has_method("get_biome_order"):
		var order: Array = abm.get_biome_order()
		if not order.is_empty():
			return order
	var active := _biome_name()
	return [active] if active != "" else []


## Canonical Biome data (source of truth for cluster topology).
func _canonical_biome(biome_name: String):
	if biome_name == "":
		return null
	var reg = load("res://Core/Biomes/BiomeRegistry.gd")
	if reg != null and reg.has_method("get_shared"):
		var shared = reg.get_shared()
		if shared != null and shared.has_method("get_by_name"):
			return shared.get_by_name(biome_name)
	return null


## The eigenstate compass — the biome's dominant eigenstate of ρ ("the deep
## state": what this place most IS) and the eigenvalue gap (how decidedly).
## The old design docs called for exactly this instrument (EXOTIC_TOPOLOGY.md
## "observation tools"); the campaign's Pond chapter teaches what it reads.
## Returns "" when no live QC / native eigensolver is available.
func _compass_line(biome_name: String) -> String:
	var qc = _live_qc_for(biome_name)
	if qc == null or not qc.has_method("get_attractor_state"):
		return ""
	var attractor: Dictionary = qc.get_attractor_state()
	if attractor.is_empty():
		return ""
	var order: Array = attractor.get("emojis", [])
	if order.is_empty():
		return ""
	var top := str(order[0])
	var p := float(attractor.get(top, 0.0))
	var gap := float(attractor.get("eigenvalue_gap", 0.0))
	# In wet country the compass is LITERAL: dissipation contracts toward the
	# deep state, so the needle points where the biome is actually going.
	if qc.has_method("is_open_here") and qc.is_open_here():
		var pull := "falling in"
		if gap >= 0.5:
			pull = "already settling"
		elif gap < 0.2:
			pull = "drifting, basin shallow"
		return "🧭 deep state: %s %.0f%% · gap %.2f — %s (wet country: the needle is destiny here)" % [top, p * 100.0, gap, pull]
	var gloss := "torn between depths"
	if gap >= 0.5:
		gloss = "decided"
	elif gap >= 0.2:
		gloss = "leaning"
	return "🧭 deep state: %s %.0f%% · gap %.2f — %s" % [top, p * 100.0, gap, gloss]


## One-line thermodynamic passport for the biome's E-inspect card. "" when closed
## country (the enclave's law is stated elsewhere — no need to restate the default).
func _regime_line(biome_name: String) -> String:
	var qc = _live_qc_for(biome_name)
	if qc == null or not qc.has_method("is_open_here") or not qc.is_open_here():
		return ""
	var purity := -1.0
	if qc.has_method("get_purity"):
		purity = float(qc.get_purity())
	var head := "🌊 wet country — the Bath drinks here. Phase fades first (T₂), population follows (T₁)."
	if purity >= 0.0 and purity < 0.999:
		return head + " Tr(ρ²) = %.3f and falling unless watched — measurement pins what it touches (Zeno)." % purity
	return head + " What you do not watch, fades; measurement pins what it touches (Zeno)."


## One-line knot card: frozen Berry loop records + the strongest pair invariant.
## "" while the record is empty — the line appears the moment a first loop closes.
func _knot_line(biome_name: String) -> String:
	var qc = _live_qc_for(biome_name)
	if qc == null or not ("berry_register" in qc) or qc.berry_register == null:
		return ""
	var loops: Array = qc.berry_register.frozen_loops()
	if loops.is_empty():
		return ""
	if loops.size() == 1:
		var omega := float(loops[0].get("omega", 0.0))
		return "🪢 the record: 1 closed loop banked (Ω = %.2f) — close another and compare their turns." % omega
	var w: int = KnotRegister.max_mutual_winding(loops)
	if absi(w) >= 1:
		return ("🪢 the record: %d closed loops — mutual winding %+d: LINKED. Nothing links on the sphere; " +
			"the link lives one floor up, where the phase turns. (Any two answers of a qubit are linked circles — Hopf.)") % [loops.size(), w]
	return "🪢 the record: %d closed loops — mutual winding 0: the dances pass without turning about each other." % loops.size()


## Live QuantumComputer for a biome's population bars (null if not instantiated).
func _live_qc_for(biome_name: String):
	if farm and farm.grid and farm.grid.has_method("get_biome"):
		var b = farm.grid.get_biome(biome_name)
		if b != null and "quantum_computer" in b:
			return b.quantum_computer
	return null


func _activate_biome(biome_name: String) -> void:
	# E on Atlas (biome node): make this biome the active one. The live
	# instrument and B's pure-overlay magnifier follow via ABM's
	# active_biome_changed signal — no direct overlay poke.
	if biome_name == "":
		return
	var abm = (Engine.get_main_loop().root.get_node_or_null("/root/ActiveBiomeManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if abm != null and abm.has_method("set_active_biome"):
		abm.set_active_biome(biome_name)

# =============================================================================
# HELPERS — biome resolution (kept for Atlas)
# =============================================================================

func _resolve_biome() -> void:
	if not farm:
		var gsm = (Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
		if gsm and gsm.has_method("get_active_farm"):
			farm = gsm.get_active_farm()
	if not farm:
		return
	var abm = (Engine.get_main_loop().root.get_node_or_null("/root/ActiveBiomeManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if abm:
		var biome_name_str = abm.get_active_biome()
		if biome_name_str != "" and farm.grid and farm.grid.has_method("get_biome"):
			var resolved = farm.grid.get_biome(biome_name_str)
			if resolved != null:
				_active_biome = resolved

func _biome_name() -> String:
	if _active_biome and _active_biome.has_method("get_biome_type"):
		return str(_active_biome.get_biome_type())
	return ""

# =============================================================================
# Surface API
# =============================================================================

func get_visible_data() -> Dictionary:
	var pname := _get_pinned_faction_name()
	var payload: Dictionary = {
		"frame_label": FRAME_LABELS_LOCAL.get(frame_id, frame_id),
		"surface_id": "M",
		"selected_biome": _biome_name(),
		"pinned_faction": pname,
		"selected_faction_b": _selected_faction_b,
		"selected_axis": _selected_axis,
		"axis_page": _axis_page,
		"eigen_page": _eigen_page,
		"eigen_selected": _eigen_selected,
		"eigen_sort_mode": str(EIGEN_SORT_LABELS.get(EIGEN_SORT_SUBJECT if _get_pinned_faction() != null else EIGEN_SORT_SYSTEM, "")),
		"roster_size": _faction_roster.size(),
	}
	if frame_id == FRAME_ATLAS:
		payload["cluster_snapshot"] = _cluster_snapshot.duplicate(true)
		payload["atlas_state"] = {
			"zoom": _atlas_zoom,
			"rotation_degrees": _atlas_rotation_degrees,
			"selected_idx": _atlas_selected_idx,
			"selected_name": _atlas_selected_name,
		}
	return payload

func get_transitions() -> Array:
	return [
		{"surface_id": "farm", "reason": "return to live instrument"},
		{"surface_id": "C", "reason": "trade contracts on biome edges"},
		{"surface_id": "N", "reason": "inspect the biome network"},
		{"surface_id": "V", "reason": "read atoms / icons / signature / affinity"},
	]
