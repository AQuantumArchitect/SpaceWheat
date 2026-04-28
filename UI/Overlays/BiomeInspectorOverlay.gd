class_name BiomeInspectorOverlay
extends "res://UI/Core/Surface.gd"

## BiomeInspectorOverlay — B surface (local construct / active plot lens).
##
## Narrowed to inspect the **active plot** only. The main view owns biome-
## level display; B is the single-plot microscope with Bloch readout. See
## `03_B_active_terminal_construct_surface_specifics.md`.
##
## Retired views (ALL_BIOMES / COUPLINGS) live as reference code in
## `UI/Overlays/MapMetaOverlay.gd`.
##
## Frames (placeholders per spec — only "supports" is live in Phase 2):
##   supports | gates | links
##
## Invariant: plot_idx ≡ register_id. Grid column c in a biome is always
## register c of that biome's quantum computer — no random mapping. This
## lets the same integer flow through the code as both the grid column
## (e.g., `farm.grid.get_plot(Vector2i(qi, biome_row))`) and the qubit
## index (e.g., `viz_cache.get_axis(qi)`) without contradiction.

## Biome Inspector — Live quantum state display
##
## Three F-cycled views:
##   QUBITS    — Per-qubit cards with live probability bars, Bloch, purity, entanglement
##   COUPLINGS — Hamiltonian coupling strengths + Lindblad decay channels
##   ALL       — Summary cards for every active biome
##
## Controls:
##   F = Cycle view    Q = Detail / Drill    WASD = Navigate cards

const InstrumentLocator = preload("res://Core/Instrumentation/InstrumentLocator.gd")
const BiomeInspectionController = preload("res://Core/Visualization/BiomeInspectionController.gd")
const BlochSphereWidgetScript = preload("res://Core/Visualization/BlochSphereWidget.gd")
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const BiomeStateViews = preload("res://Core/Visualization/BiomeStateViews.gd")


# Layout
const CARD_MIN_SIZE := Vector2(200, 100)
const BAR_HEIGHT := 10
const EMOJI_SIZE := 24
const LABEL_SIZE := 11

# B surface frames.
#   supports                      — active plot detail (Bloch + entanglement)
#   matrix / probabilities /      — biome quantum state math (migrated from N
#   subspace / eigen                in Sprint 2 via BiomeStateViews helper)
#   gates / links                 — design-intent stubs from surface_specifics
const FRAME_SUPPORTS := "supports"
const FRAME_MATRIX := "matrix"
const FRAME_PROBABILITIES := "probabilities"
const FRAME_SUBSPACE := "subspace"
const FRAME_EIGEN := "eigen"
const FRAME_GATES := "gates"
const FRAME_LINKS := "links"

const MATH_FRAMES: Array = [FRAME_MATRIX, FRAME_PROBABILITIES, FRAME_SUBSPACE, FRAME_EIGEN]

const FRAME_LABELS_LOCAL := {
	FRAME_SUPPORTS: "Supports",
	FRAME_MATRIX: "Matrix",
	FRAME_PROBABILITIES: "Probabilities",
	FRAME_SUBSPACE: "Subspace",
	FRAME_EIGEN: "Eigen",
	FRAME_GATES: "Gates",
	FRAME_LINKS: "Links",
}

# Colors (matching QubitAtlasOverlay visual language)
const COLOR_BAR_BG := Color(0.15, 0.15, 0.2, 0.8)
const COLOR_BAR_NORTH := Color(0.3, 0.55, 0.85, 0.9)
const COLOR_BAR_SOUTH := Color(0.85, 0.4, 0.25, 0.9)
const COLOR_CARD_BG := Color(0.12, 0.14, 0.18, 0.9)
const COLOR_CARD_BORDER := Color(0.25, 0.35, 0.45, 0.6)
const COLOR_CARD_SELECTED := Color(1.0, 0.9, 0.3, 0.8)
const COLOR_GLOW_HIGH := Color(0.4, 0.7, 1.0, 0.3)
const COLOR_GLOW_LOW := Color(0.2, 0.2, 0.3, 0.1)
const COLOR_COUPLING := Color(0.6, 0.45, 0.9, 0.9)
const COLOR_LINDBLAD := Color(0.9, 0.4, 0.3, 0.8)
const COLOR_ENTANGLE := Color(0.3, 0.9, 0.6, 0.8)
const COLOR_MUTED := Color(0.5, 0.55, 0.65)
const COLOR_PURITY_HIGH := Color(0.3, 0.8, 1.0)
const COLOR_PURITY_LOW := Color(0.7, 0.4, 0.3)
const COLOR_KEY_ACTIVE := Color(0.75, 0.92, 1.0, 0.9)    # explored plot — bright
const COLOR_KEY_INACTIVE := Color(0.35, 0.38, 0.48, 0.5)  # unoccupied slot — muted


# State
var _selected_idx := -1  ## Mirror of the active plot / qubit index (-1 = none)
var farm: Node = null
var _active_biome: Node = null
var _detail_visible := false

# UI references
var _header_label: Label
var _tool_context_label: Label  # live Q/E/R action hints
var _content_box: VBoxContainer
var _cards_grid: Container
var _detail_box: VBoxContainer
var _entangle_box: VBoxContainer

# Math-frame stack (matrix / probabilities / subspace / eigen).
# Built once at _build_content; visibility toggled per-frame so the eigen
# cell cache survives frame switches.
var _math_stack_box: VBoxContainer
var _math_view_nodes: Dictionary = {}  # frame_id → Control
var _state_views: BiomeStateViews = null

# Live-update tracking
var _qubit_cards: Array = []   # [{node, qubit_idx}]


func _init():
	overlay_name = "biome_detail"
	overlay_icon = ""
	overlay_tier = 14
	panel_title = "Active Plot"
	panel_title_size = 22
	panel_size_mode = PanelSizeMode.MEDIUM
	show_dimmer = true
	dimmer_color = Color(0, 0, 0, 0.75)
	panel_border_color = Color(0.3, 0.5, 0.6, 0.8)
	use_scroll_container = false
	content_spacing = 6
	navigation_mode = NavigationMode.CALLBACK
	# Surface contract
	surface_id = "B"
	frame_ids = [
		FRAME_SUPPORTS,
		FRAME_MATRIX, FRAME_PROBABILITIES, FRAME_SUBSPACE, FRAME_EIGEN,
		FRAME_GATES, FRAME_LINKS,
	]
	frame_id = FRAME_SUPPORTS
	action_labels = {"Q": "Gate↓", "E": "Gate·", "R": "Gate↑"}


func _ready() -> void:
	super._ready()
	var abm = InstrumentLocator.resolve_active_biome_manager(self)
	if abm:
		abm.active_biome_changed.connect(_on_active_biome_changed)


func _build_content(container: Control) -> void:
	_header_label = Label.new()
	_header_label.add_theme_font_size_override("font_size", 13)
	_header_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(_header_label)

	# Live tool-context hint: shows what Q/E/R will do in current tool group.
	# Updates every frame so it always reflects the active tool.
	_tool_context_label = Label.new()
	_tool_context_label.add_theme_font_size_override("font_size", 11)
	_tool_context_label.add_theme_color_override("font_color", Color(0.45, 0.58, 0.72))
	_tool_context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(_tool_context_label)

	_content_box = VBoxContainer.new()
	_content_box.add_theme_constant_override("separation", 8)
	_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_content_box)

	# Math-frame stack — built once, visibility toggled per active frame.
	_math_stack_box = VBoxContainer.new()
	_math_stack_box.add_theme_constant_override("separation", 6)
	_math_stack_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_math_stack_box.visible = false
	container.add_child(_math_stack_box)

	_state_views = BiomeStateViews.new()
	_math_view_nodes[FRAME_MATRIX] = _state_views.build_matrix_view()
	_math_view_nodes[FRAME_PROBABILITIES] = _state_views.build_bars_view()
	_math_view_nodes[FRAME_SUBSPACE] = _state_views.build_subspace_view()
	_math_view_nodes[FRAME_EIGEN] = _state_views.build_eigen_view()
	for view in _math_view_nodes.values():
		view.visible = false
		_math_stack_box.add_child(view)


# =============================================================================
# LIFECYCLE
# =============================================================================

func _on_activated() -> void:
	_resolve_biome()
	if _active_biome and _active_biome.has_method("get_biome_type"):
		context_id = _active_biome.get_biome_type()
	# Poll current plot from the live instrument — no signal subscription,
	# no cached independent selection. B is a view, not a participant.
	_selected_idx = _read_instrument_plot_idx()
	if _selected_idx >= 0:
		set_object_focus(_selected_idx, "plot")
	else:
		clear_object_focus()
	_rebuild()
	super._on_activated()  # SurfaceRegistry register + snapshot emit


func _on_deactivated() -> void:
	_detail_visible = false
	super._on_deactivated()


func _read_instrument_plot_idx() -> int:
	"""Read the current plot index from the live instrument.
	Returns -1 if unavailable — B then renders 'nothing highlighted'."""
	var qi_input := _get_quantum_input()
	if not qi_input:
		return -1
	var instrument = qi_input.get("_instrument")
	if instrument == null:
		return -1
	var idx = instrument.get("current_plot_idx")
	return int(idx) if idx != null else -1


func _process(_delta: float) -> void:
	if not visible or not is_active:
		return
	_update_tool_context()
	# Every frame: re-check the instrument's current plot. If it changed under
	# us (player pressed GHJKL;), rebuild. B holds no independent selection
	# state — it only mirrors the instrument.
	var live_idx := _read_instrument_plot_idx()
	if live_idx != _selected_idx:
		_selected_idx = live_idx
		if _selected_idx >= 0:
			set_object_focus(_selected_idx, "plot")
		else:
			clear_object_focus()
		_rebuild()
	if MATH_FRAMES.has(frame_id):
		# Live refresh of the active math frame (eigen cells update in place).
		if _state_views and _active_biome:
			_state_views.set_biome(_active_biome)
			if _selected_idx >= 0:
				_state_views.set_selected(_selected_idx)
			_state_views.update_view(frame_id)
	else:
		_update_qubit_cards()


# =============================================================================
# ACTIONS — Glass Overlay Design
#
# Q/E/R dispatch quantum gate actions directly to QuantumInstrumentInput,
# acting on the currently selected qubit card.  The overlay stays open so
# you can observe the density matrix changing in real time.
#
# Enter/Space (via _activate_selected) keeps overlay-navigation actions:
#   QUBITS    → toggle per-qubit detail panel
#   ALL_BIOMES → drill into the selected biome
#
# Frame cycling is `[` / `]` (PlayerShell). F is reserved for the live tool.
# =============================================================================

func _on_frame_changed(_new_frame_id: String, _prev_frame_id: String) -> void:
	_rebuild()


func _on_action_q() -> void:
	_dispatch_quantum_action("Q")


func _on_action_e() -> void:
	_dispatch_quantum_action("E")


func _on_action_r() -> void:
	_dispatch_quantum_action("R")


func _activate_selected() -> void:
	"""Enter/Space = toggle the detail panel's expanded state."""
	_detail_visible = not _detail_visible
	_rebuild()


func _on_navigate(_direction: Vector2i) -> void:
	# B follows the farm's active plot selection. Internal nav is a no-op;
	# plot selection lives in QuantumInstrumentInput (GHJKL;).
	pass


# =============================================================================
# GLASS OVERLAY HELPERS
# =============================================================================

func _get_quantum_input() -> Node:
	"""Locate the QuantumInstrumentInput node via group membership."""
	var nodes = get_tree().get_nodes_in_group("quantum_instrument_input")
	return nodes[0] if not nodes.is_empty() else null


func _dispatch_quantum_action(key: String) -> void:
	"""Fire a quantum gate action on the instrument's currently-selected plot.
	B is a read-only viewer — it never rewrites the instrument's selection."""
	var qi_input = _get_quantum_input()
	if qi_input:
		qi_input.dispatch_action(key)


func _update_tool_context() -> void:
	"""Update the frame-context hint label and action_labels from ToolConfig."""
	if not _tool_context_label:
		return
	var frame_name: String = ToolConfig.get_current_frame()
	var q_lbl: String = ToolConfig.get_action_label(frame_name, "Q")
	var e_lbl: String = ToolConfig.get_action_label(frame_name, "E")
	var r_lbl: String = ToolConfig.get_action_label(frame_name, "R")
	var q_str := q_lbl if q_lbl != "" else "—"
	var e_str := e_lbl if e_lbl != "" else "—"
	var r_str := r_lbl if r_lbl != "" else "—"
	_tool_context_label.text = "Q:%s  E:%s  R:%s  ·  Enter:Detail" % [q_str, e_str, r_str]
	action_labels.Q = q_str
	action_labels.E = e_str
	action_labels.R = r_str


# =============================================================================
# DATA RESOLUTION
# =============================================================================

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
		if farm.grid and farm.grid.has_method("get_biome"):
			_active_biome = farm.grid.get_biome(name)


func _on_active_biome_changed(new_biome: String, _old: String) -> void:
	if not visible or not is_active:
		return
	if farm and farm.grid and farm.grid.has_method("get_biome"):
		_active_biome = farm.grid.get_biome(new_biome)
	context_id = new_biome
	_rebuild()


func _get_biome_by_name(bname: String) -> Node:
	if farm and farm.grid and farm.grid.has_method("get_biome"):
		return farm.grid.get_biome(bname)
	return null


# =============================================================================
# DISPLAY BUILD
# =============================================================================

func _rebuild() -> void:
	_clear_content()
	_update_header()
	_apply_frame_visibility()

	if MATH_FRAMES.has(frame_id):
		# Math frames live in _math_stack_box (built once); ensure data is fresh.
		if _state_views and _active_biome:
			_state_views.set_biome(_active_biome)
			if _selected_idx >= 0:
				_state_views.set_selected(_selected_idx)
			_state_views.update_view(frame_id)
	elif frame_id == FRAME_SUPPORTS:
		_build_active_plot_view()
	else:
		_build_frame_stub()

	action_labels.Q = "Detail"


func _apply_frame_visibility() -> void:
	"""Toggle which container is visible for the current frame.
	Math frames share _math_stack_box (one child visible); others use _content_box."""
	if not _math_stack_box:
		return
	var is_math: bool = MATH_FRAMES.has(frame_id)
	_math_stack_box.visible = is_math
	if _content_box:
		_content_box.visible = not is_math
	for fid in _math_view_nodes.keys():
		var node: Control = _math_view_nodes[fid]
		if node:
			node.visible = (fid == frame_id)


func _clear_content() -> void:
	for child in _content_box.get_children():
		child.queue_free()
	_qubit_cards.clear()
	_cards_grid = null
	_detail_box = null
	_entangle_box = null


func _update_header() -> void:
	if not _active_biome:
		_header_label.text = "No active biome"
		return
	var frame_label: String = FRAME_LABELS_LOCAL.get(frame_id, frame_id)
	_header_label.text = "%s · plot %d · [ %s ]" % [
		_biome_display_name(), _selected_idx, frame_label]


func _build_frame_stub() -> void:
	"""Placeholder for not-yet-implemented frames (gates, links)."""
	var lbl = Label.new()
	var frame_label: String = FRAME_LABELS_LOCAL.get(frame_id, frame_id)
	lbl.text = "Frame '%s' not yet implemented.\nUse [ or ] to cycle back to Supports." % frame_label
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
	_content_box.add_child(lbl)


func _build_active_plot_view() -> void:
	"""Build the single-plot view for the active plot only."""
	if not _active_biome:
		return
	var nq = _get_num_qubits()
	if nq == 0:
		return
	# No highlighted plot → show nothing. B mirrors the instrument's selection;
	# if the instrument has no selection, B has nothing to display.
	if _selected_idx < 0 or _selected_idx >= nq:
		var lbl = Label.new()
		lbl.text = "No plot highlighted.\nUse GHJKL; to select a plot."
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content_box.add_child(lbl)
		return

	# Single qubit card for the active plot.
	var card = _build_qubit_card(_selected_idx)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content_box.add_child(card)
	_qubit_cards.append({"node": card, "qubit_idx": _selected_idx})
	_update_selection()

	# Detail panel (Bloch + numeric) — always present for the active plot.
	_detail_box = VBoxContainer.new()
	_detail_box.add_theme_constant_override("separation", 4)
	_content_box.add_child(_detail_box)
	_detail_visible = true
	_rebuild_detail()

	# Local entanglement section (pairs involving the active plot only).
	_build_entanglement_section()


# =============================================================================
# ACTIVE PLOT VIEW (the only live frame in Phase 2)
# =============================================================================


func _build_qubit_card(qi: int) -> PanelContainer:
	"""Compact card: [key]  N-emoji  prob-bar  S-emoji  purity.
	The Bloch sphere lives only in the detail panel below."""
	var vc = _active_biome.viz_cache if _active_biome else null
	var axis = vc.get_axis(qi) if vc else {"north": "?", "south": "?"}

	var card = PanelContainer.new()
	card.custom_minimum_size = CARD_MIN_SIZE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_card_style(false))

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(hbox)

	# Homerow key badge
	var homerow_keys = InputBindingRegistry.HOMEROW_KEYS
	if qi < homerow_keys.size():
		var key_lbl = Label.new()
		key_lbl.name = "KeyLabel"
		key_lbl.text = "[%s]" % homerow_keys[qi]
		key_lbl.add_theme_font_size_override("font_size", LABEL_SIZE + 2)
		var color = COLOR_KEY_ACTIVE if _is_plot_explored(qi) else COLOR_KEY_INACTIVE
		key_lbl.add_theme_color_override("font_color", color)
		hbox.add_child(key_lbl)

	# North emoji
	var n_lbl = Label.new()
	n_lbl.text = axis.get("north", "?")
	n_lbl.add_theme_font_size_override("font_size", EMOJI_SIZE)
	hbox.add_child(n_lbl)

	# Probability bar (inline, expands)
	var bar = _create_prob_bar()
	bar.name = "ProbBar"
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(bar)

	# South emoji
	var s_lbl = Label.new()
	s_lbl.text = axis.get("south", "?")
	s_lbl.add_theme_font_size_override("font_size", EMOJI_SIZE)
	hbox.add_child(s_lbl)

	# Purity (inline)
	var pur_lbl = Label.new()
	pur_lbl.name = "PurityLabel"
	pur_lbl.add_theme_font_size_override("font_size", LABEL_SIZE)
	pur_lbl.custom_minimum_size = Vector2(70, 0)
	hbox.add_child(pur_lbl)

	return card


func _rebuild_detail() -> void:
	for child in _detail_box.get_children():
		child.queue_free()

	if not _detail_visible or _qubit_cards.is_empty():
		return

	var nq = _get_num_qubits()
	var qi = clampi(_selected_idx, 0, maxi(nq - 1, 0))
	var vc = _active_biome.viz_cache if _active_biome else null
	var qc = _active_biome.quantum_computer if _active_biome else null
	if not vc or not qc:
		return

	var axis = vc.get_axis(qi)
	var bloch = vc.get_bloch(qi)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	_detail_box.add_child(sep)

	# Horizontal layout: [Bloch sphere | readouts column] — exploit rectangle.
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.add_child(row)

	# Left: Bloch sphere (the only one — card view is compact)
	var detail_sphere = BlochSphereWidgetScript.new()
	detail_sphere.name = "DetailBlochSphere"
	detail_sphere.custom_minimum_size = Vector2(160, 160)
	detail_sphere.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	detail_sphere.show_axis_labels = true
	detail_sphere.show_coords = true
	detail_sphere.trail_max = 800
	detail_sphere.heat_decay = 0.9998
	detail_sphere.update_state(
		bloch.get("x", 0.0), bloch.get("y", 0.0), bloch.get("z", 0.0),
		bloch.get("r", 0.0))
	row.add_child(detail_sphere)
	if detail_sphere.has_method("set_pole_emojis"):
		detail_sphere.set_pole_emojis(
			str(axis.get("north", "")), str(axis.get("south", "")))

	# Right: readouts column
	var readouts = VBoxContainer.new()
	readouts.add_theme_constant_override("separation", 4)
	readouts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	readouts.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(readouts)

	var title = Label.new()
	title.text = "q%d  %s / %s" % [qi, axis.get("north", "?"), axis.get("south", "?")]
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	readouts.add_child(title)

	# Marginal purity
	var mp = qc.get_marginal_purity(null, qi) if qc else 0.0
	var mp_lbl = Label.new()
	mp_lbl.text = "Marginal purity: %.1f%%" % (mp * 100)
	mp_lbl.add_theme_font_size_override("font_size", 12)
	mp_lbl.add_theme_color_override("font_color", COLOR_PURITY_HIGH.lerp(COLOR_PURITY_LOW, 1.0 - mp))
	readouts.add_child(mp_lbl)

	# Berry loops (if any)
	if detail_sphere.has_method("get_berry_loops"):
		var loops = detail_sphere.get_berry_loops()
		if loops > 0:
			var berry_lbl = Label.new()
			berry_lbl.text = "Berry loops: %d" % loops
			berry_lbl.add_theme_font_size_override("font_size", 12)
			berry_lbl.add_theme_color_override("font_color", Color(0.25, 1.0, 0.5))
			readouts.add_child(berry_lbl)

	# Couplings for this qubit
	var north_e = axis.get("north", "")
	var couplings = vc.get_hamiltonian_couplings(north_e)
	if couplings.size() > 0:
		readouts.add_child(_muted_label("Hamiltonian couplings:"))
		for target in couplings:
			var c_row = _muted_label("  %s <-> %s  J=%.4f" % [north_e, target, couplings[target]])
			c_row.add_theme_color_override("font_color", COLOR_COUPLING)
			readouts.add_child(c_row)

	# Lindblad channels
	var lindblad = vc.get_lindblad_outgoing(north_e)
	if lindblad.size() > 0:
		readouts.add_child(_muted_label("Lindblad channels:"))
		for target in lindblad:
			var l_row = _muted_label("  %s -> %s  gamma=%.4f" % [north_e, target, lindblad[target]])
			l_row.add_theme_color_override("font_color", COLOR_LINDBLAD)
			readouts.add_child(l_row)


func _build_entanglement_section() -> void:
	if not _active_biome:
		return

	var gates = _active_biome.bell_gates if "bell_gates" in _active_biome else []
	var qc = _active_biome.quantum_computer if _active_biome else null
	if gates.is_empty() and (not qc or _get_num_qubits() < 2):
		return

	_entangle_box = VBoxContainer.new()
	_entangle_box.add_theme_constant_override("separation", 3)
	_content_box.add_child(_entangle_box)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	_entangle_box.add_child(sep)

	var title = Label.new()
	title.text = "Entanglement"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", COLOR_ENTANGLE)
	_entangle_box.add_child(title)

	var vc = _active_biome.viz_cache if _active_biome else null
	var nq = _get_num_qubits()

	# Show all pairs with MI > 0.1
	var shown := 0
	for i in range(nq):
		for j in range(i + 1, nq):
			var mi = qc.get_mutual_information(i, j) if qc else 0.0
			if mi < 0.1:
				continue
			var axis_i = vc.get_axis(i) if vc else {}
			var axis_j = vc.get_axis(j) if vc else {}
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			_entangle_box.add_child(row)

			var lbl = Label.new()
			lbl.text = "q%d (%s) <-> q%d (%s)  MI=%.2f" % [
				i, axis_i.get("north", "?"),
				j, axis_j.get("north", "?"), mi]
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color", COLOR_ENTANGLE)
			row.add_child(lbl)
			shown += 1

	if shown == 0:
		var none_lbl = _muted_label("No significant entanglement (MI < 0.1)")
		_entangle_box.add_child(none_lbl)


# =============================================================================
# LIVE UPDATE
# =============================================================================

func _update_qubit_cards() -> void:
	if not _active_biome:
		return
	var vc = _active_biome.viz_cache if _active_biome else null
	var qc = _active_biome.quantum_computer if _active_biome else null
	if not vc:
		return

	for info in _qubit_cards:
		var qi: int = info.qubit_idx
		var card: PanelContainer = info.node
		var bloch = vc.get_bloch(qi)
		var p0 = bloch.get("p0", 0.5)
		var p1 = bloch.get("p1", 0.5)

		# Update probability bar
		_set_prob_bar(card, maxf(p0, 0.02), maxf(p1, 0.02))

		# Purity label
		var pur_lbl = _find_child_named(card, "PurityLabel")
		if pur_lbl and qc:
			var mp = qc.get_marginal_purity(null, qi)
			pur_lbl.text = "Purity %d%%" % int(mp * 100)
			pur_lbl.add_theme_color_override("font_color",
				COLOR_PURITY_HIGH.lerp(COLOR_PURITY_LOW, 1.0 - clampf(mp, 0, 1)))

		# Glow
		_apply_glow(card, qi)

	# Update detail sphere if visible
	if _detail_visible and _detail_box:
		var detail_sphere = _find_child_named(_detail_box, "DetailBlochSphere")
		if detail_sphere and detail_sphere.has_method("update_state"):
			var nq = _get_num_qubits()
			var sel_qi = clampi(_selected_idx, 0, maxi(nq - 1, 0))
			var sel_bloch = vc.get_bloch(sel_qi)
			detail_sphere.update_state(
				sel_bloch.get("x", 0.0), sel_bloch.get("y", 0.0), sel_bloch.get("z", 0.0),
				sel_bloch.get("r", 0.0))

	# Update header purity
	var p = _get_purity()
	_header_label.text = "%s    %d qubits    Purity %d%%" % [
		_biome_display_name(), _get_num_qubits(), int(p * 100)]


# =============================================================================
# SELECTION
# =============================================================================

func _update_selection() -> void:
	for entry in _qubit_cards:
		var card: PanelContainer = entry.node
		card.add_theme_stylebox_override("panel", _make_card_style(true))


func _scroll_to_selected() -> void:
	"""Legacy helper retained for callers — single-plot view doesn't scroll."""
	if _selected_idx < 0 or _selected_idx >= _qubit_cards.size():
		return
	var scroll = _content_box.get_node_or_null("QubitScroll")
	if not scroll:
		return
	var card: Control = _qubit_cards[_selected_idx].node
	# Scroll so the card's left edge is at most at the scroll position
	var card_x = card.position.x
	var card_w = card.size.x
	var scroll_w = scroll.size.x
	var current = scroll.scroll_horizontal
	if card_x < current:
		scroll.scroll_horizontal = int(card_x)
	elif card_x + card_w > current + scroll_w:
		scroll.scroll_horizontal = int(card_x + card_w - scroll_w)


# =============================================================================
# SHARED UI HELPERS
# =============================================================================

func _create_prob_bar() -> HBoxContainer:
	var bar = HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_constant_override("separation", 0)

	var bg = StyleBoxFlat.new()
	bg.bg_color = COLOR_BAR_BG
	bg.set_corner_radius_all(3)

	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", bg)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar.add_child(panel)

	var inner = HBoxContainer.new()
	inner.add_theme_constant_override("separation", 1)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(inner)

	var nf = ColorRect.new()
	nf.name = "NorthFill"
	nf.color = COLOR_BAR_NORTH
	nf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nf.size_flags_stretch_ratio = 0.5
	inner.add_child(nf)

	var sf = ColorRect.new()
	sf.name = "SouthFill"
	sf.color = COLOR_BAR_SOUTH
	sf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sf.size_flags_stretch_ratio = 0.5
	inner.add_child(sf)

	return bar


func _set_prob_bar(card: PanelContainer, p_north: float, p_south: float) -> void:
	var bar = _find_child_named(card, "ProbBar")
	if not bar:
		return
	var panel = bar.get_child(0) if bar.get_child_count() > 0 else null
	var inner = panel.get_child(0) if panel and panel.get_child_count() > 0 else null
	if inner and inner.get_child_count() >= 2:
		inner.get_child(0).size_flags_stretch_ratio = p_north
		inner.get_child(1).size_flags_stretch_ratio = p_south


func _apply_glow(card: PanelContainer, qi: int) -> void:
	var qc = _active_biome.quantum_computer if _active_biome else null
	if not qc:
		return
	var mp = qc.get_marginal_purity(null, qi)
	var t = clampf((mp - 0.5) * 2.0, 0.0, 1.0)
	var is_selected = (_qubit_cards.size() > _selected_idx and _qubit_cards[_selected_idx].node == card)
	var style = _make_card_style(is_selected)
	style.shadow_color = COLOR_GLOW_LOW.lerp(COLOR_GLOW_HIGH, t)
	style.shadow_size = int(t * 6)
	card.add_theme_stylebox_override("panel", style)


func _make_card_style(selected: bool) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_CARD_BG
	style.border_color = COLOR_CARD_SELECTED if selected else COLOR_CARD_BORDER
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	return style


func _muted_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", COLOR_MUTED)
	return lbl


func _find_child_named(node: Node, child_name: String) -> Node:
	if node.name == child_name:
		return node
	for child in node.get_children():
		var found = _find_child_named(child, child_name)
		if found:
			return found
	return null


func _short_name(bname: String) -> String:
	if bname.is_empty():
		return "?"
	var result = ""
	for i in range(bname.length()):
		var c = bname[i]
		if i > 0 and c == c.to_upper() and c != c.to_lower():
			result += " "
		result += c
	return result


func _biome_display_name() -> String:
	if _active_biome and _active_biome.has_method("get_biome_type"):
		return _short_name(_active_biome.get_biome_type())
	return "Unknown"


func _get_num_qubits() -> int:
	var vc = _active_biome.viz_cache if _active_biome else null
	return vc.get_num_qubits() if vc else 0


func _get_purity() -> float:
	var vc = _active_biome.viz_cache if _active_biome else null
	return vc.get_purity() if vc else 0.0


func _is_plot_explored(qubit_idx: int) -> bool:
	"""Return true if a terminal is bound at the plot column for this qubit index."""
	if not farm or not _active_biome or not _active_biome.has_method("get_biome_type"):
		return false
	var biome_row: int = farm.biome_row_map.get(_active_biome.get_biome_type(), -1)
	if biome_row < 0 or not farm.grid:
		return false
	var plot = farm.grid.get_plot(Vector2i(qubit_idx, biome_row))
	return plot != null and plot.has_terminal()


func _on_unhandled_key(keycode: int, event: InputEvent) -> bool:
	# First let Surface base try TYUIOP → direct-frame-jump.
	if super._on_unhandled_key(keycode, event):
		return true
	# GHJKL: explicitly do NOT consume these — they fall through to
	# QuantumInstrumentInput._input() for live plot selection while the overlay is open.
	return false


# =============================================================================
# SURFACE CONTRACT
# =============================================================================

func get_visible_data() -> Dictionary:
	"""Surface-contract payload for B (active plot lens)."""
	var nq := _get_num_qubits()
	var emoji := ""
	var axis := {}
	if _active_biome and _active_biome.viz_cache and _selected_idx >= 0 and _selected_idx < nq:
		axis = _active_biome.viz_cache.get_axis(_selected_idx)
		emoji = axis.get("north", "")
	return {
		"biome_id": context_id,
		"active_plot_idx": _selected_idx,
		"plot_emoji": emoji,
		"num_qubits": nq,
		"frame_label": FRAME_LABELS_LOCAL.get(frame_id, frame_id),
	}


func get_transitions() -> Array:
	return [
		{"surface_id": "farm", "reason": "return to live instrument"},
		{"surface_id": "N", "reason": "read biome state"},
		{"surface_id": "V", "reason": "explain symbols / axis"},
	]
