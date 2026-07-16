class_name BiomeInspectorOverlay
extends "res://UI/Core/Surface.gd"

## BiomeInspectorOverlay — B surface (pure visual microscope).
##
## B is a magnifier-only overlay: no QERF chips, no TYUIOP claims, no
## frame cycling. It mirrors the live instrument's plot selection and
## renders a richer view of that one plot (IconCard + marginals strip
## + entanglement summary + biome name). It consumes NO input at all —
## handle_input/handle_action return false so every key and chip tap
## falls through to the one gameplay dispatcher (QII); the player keeps
## acting on the plot they are magnifying.
##
## Whole-biome / matrix views moved to N. Subspace moved to V. Eigen
## and per-qubit marginals already live on M as Eigenstate / Bits.
##
## Invariant: plot_idx ≡ register_id. Grid column c in a biome is always
## register c of that biome's quantum computer.

const FRAME_SUPPORTS := "supports"

# Layout
const BAR_HEIGHT := 10
const EMOJI_SIZE := 24
const LABEL_SIZE := 11
const DETAIL_MAX_ROWS := 6

# Colors
const COLOR_COUPLING := Color(0.6, 0.45, 0.9, 0.9)
const COLOR_LINDBLAD := Color(0.9, 0.4, 0.3, 0.8)
const COLOR_ENTANGLE := Color(0.3, 0.9, 0.6, 0.8)
const COLOR_MUTED := Color(0.5, 0.55, 0.65)

# Transparent to input routing — UIContextController shows frame actions, not overlay actions.
var is_transparent_overlay: bool = true

# State
var _selected_idx := -1
var _refresh_accum := 0.0
var farm: Node = null
var _active_biome: Node = null

# UI
var _header_label: Label
var _biome_row_box: HBoxContainer  # TYUIOP biome display
var _icon_row_box: HBoxContainer   # GHJKL; icon display
var _content_box: VBoxContainer

func _init() -> void:
	overlay_name = "biome_inspector"
	overlay_icon = ""
	overlay_tier = 12
	panel_title = "🔬 Biome Microscope"
	panel_title_size = 22
	panel_size_mode = PanelSizeMode.MEDIUM
	show_dimmer = true
	dimmer_color = Color(0, 0, 0, 0.75)
	panel_border_color = Color(0.3, 0.5, 0.6, 0.8)
	use_scroll_container = false
	content_spacing = 6
	navigation_mode = NavigationMode.NONE
	# Surface contract — pure overlay: single frame, no chips, no claims.
	surface_id = "B"
	frame_ids = [FRAME_SUPPORTS]
	frame_id = FRAME_SUPPORTS
	action_labels = {"Q": "", "E": "", "R": "", "F": ""}

func _ready() -> void:
	super._ready()
	var abm = (Engine.get_main_loop().root.get_node_or_null("/root/ActiveBiomeManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if abm:
		abm.active_biome_changed.connect(_on_active_biome_changed)

func _build_content(container: Control) -> void:
	_header_label = Label.new()
	_header_label.add_theme_font_size_override("font_size", 13)
	_header_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(_header_label)

	_biome_row_box = HBoxContainer.new()
	_biome_row_box.add_theme_constant_override("separation", 14)
	_biome_row_box.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(_biome_row_box)

	var sep1 := HSeparator.new()
	sep1.add_theme_color_override("color", Color(0.3, 0.4, 0.5, 0.3))
	container.add_child(sep1)

	_icon_row_box = HBoxContainer.new()
	_icon_row_box.add_theme_constant_override("separation", 14)
	_icon_row_box.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(_icon_row_box)

	var sep2 := HSeparator.new()
	sep2.add_theme_color_override("color", Color(0.3, 0.4, 0.5, 0.4))
	container.add_child(sep2)

	_content_box = VBoxContainer.new()
	_content_box.add_theme_constant_override("separation", 8)
	_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_content_box)

# =============================================================================
# LIFECYCLE
# =============================================================================

func _on_activated() -> void:
	_resolve_biome()
	if _active_biome and _active_biome.has_method("get_biome_type"):
		context_id = _active_biome.get_biome_type()
	_selected_idx = _resolve_plot_idx()
	if _selected_idx >= 0:
		set_object_focus(_selected_idx, "plot")
	else:
		clear_object_focus()
	_rebuild()
	super._on_activated()

func _read_instrument_plot_idx() -> int:
	var qi_input := _get_quantum_input()
	if not qi_input:
		return -1
	var instrument = qi_input.get("_instrument")
	if instrument == null:
		return -1
	# The ACTIVE plot is the live cursor (current_plot_idx), not the persisted
	# last_plot_idx — B should mirror whatever plot the player is actually on.
	# Fall back to last_plot_idx (survives leaving the plot ring) then -1.
	var cur = instrument.get("current_plot_idx")
	if cur != null and int(cur) >= 0:
		return int(cur)
	var idx = instrument.get("last_plot_idx")
	return int(idx) if idx != null else -1

func _resolve_plot_idx() -> int:
	# B is a microscope — it should always be pointed at the ACTIVE plot. Only when
	# the instrument reports no plot at all do we fall back to the biome's first
	# plot (so B never shows an empty "select a plot" placeholder).
	var idx := _read_instrument_plot_idx()
	if idx >= 0:
		return idx
	return 0 if _get_num_qubits() > 0 else -1

func _process(delta: float) -> void:
	if not visible or not is_active:
		return
	var live_idx := _resolve_plot_idx()
	if live_idx != _selected_idx:
		_selected_idx = live_idx
		if _selected_idx >= 0:
			set_object_focus(_selected_idx, "plot")
		else:
			clear_object_focus()
		_rebuild()
		_refresh_accum = 0.0
		return
	# Keep the microscope live even when the plot doesn't change: marginals,
	# purity and Var(H) evolve continuously, and QERF acted on the plot beneath
	# should be reflected here. Throttled rebuild (~4 Hz) keeps it cheap.
	_refresh_accum += delta
	if _refresh_accum >= 0.25:
		_refresh_accum = 0.0
		_rebuild()

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
		if farm.grid and farm.grid.has_method("get_biome"):
			_active_biome = farm.grid.get_biome(biome_name_str)

func _on_active_biome_changed(new_biome: String, _old: String) -> void:
	if not visible or not is_active:
		return
	if farm and farm.grid and farm.grid.has_method("get_biome"):
		_active_biome = farm.grid.get_biome(new_biome)
	context_id = new_biome
	_rebuild()

# =============================================================================
# INPUT — B is GLASS. It consumes nothing; the magnified plot stays playable.
# =============================================================================

func handle_input(_event: InputEvent) -> bool:
	# OverlayBase.handle_input would claim Q/E/R/F for overlay-local verbs.
	# B is a magnifier: every key falls through to the one gameplay dispatcher
	# (QII._unhandled_key_input) so the player acts on the plot they're
	# inspecting. The 4 Hz _process rebuild reflects the action immediately.
	return false

func handle_action(_action_key: String) -> bool:
	# Chip taps mirror the keyboard: not consumed here → PlayerShell falls
	# through to instrument_input.invoke_action on the plot beneath.
	return false

func _on_unhandled_key(_keycode: int, _event: InputEvent) -> bool:
	# Pure overlay — never consume keys. TYUIOP/[/] etc. fall through to
	# whatever the underlying input router (PlayerShell / instrument) handles.
	return false

func _on_navigate(_direction: Vector2i) -> void:
	pass

func _get_quantum_input() -> Node:
	var nodes = get_tree().get_nodes_in_group("quantum_instrument_input")
	return nodes[0] if not nodes.is_empty() else null

# =============================================================================
# DISPLAY
# =============================================================================

func _rebuild() -> void:
	_rebuild_biome_row()
	_rebuild_icon_row()
	for child in _content_box.get_children():
		child.queue_free()
	_update_header()
	_build_active_plot_view()

func _rebuild_biome_row() -> void:
	if not _biome_row_box:
		return
	for c in _biome_row_box.get_children():
		c.queue_free()
	var abm = get_node_or_null("/root/ActiveBiomeManager")
	if not abm:
		return
	var active_name: String = abm.get_active_biome() if abm.has_method("get_active_biome") else ""
	var slot_count: int = abm.get_slot_count() if abm.has_method("get_slot_count") else 0
	const BIOME_KEYS: Array = ["T", "Y", "U", "I", "O", "P"]
	for i in range(slot_count):
		var bname: String = abm.get_biome_for_slot(i) if abm.has_method("get_biome_for_slot") else ""
		if bname.is_empty():
			continue
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 12)
		var key: String = BIOME_KEYS[i] if i < BIOME_KEYS.size() else "?"
		lbl.text = "[%s] %s" % [key, bname]
		lbl.add_theme_color_override("font_color",
			UIStyleFactory.COLOR_TAB_ACTIVE if bname == active_name else UIStyleFactory.COLOR_TAB_IDLE)
		_biome_row_box.add_child(lbl)

func _rebuild_icon_row() -> void:
	if not _icon_row_box:
		return
	for c in _icon_row_box.get_children():
		c.queue_free()
	if not _active_biome or not _active_biome.viz_cache:
		return
	var vc = _active_biome.viz_cache
	var nq: int = vc.get_num_qubits() if vc.has_method("get_num_qubits") else 0
	const PLOT_KEYS: Array = ["G", "H", "J", "K", "L", ";"]
	for i in range(min(nq, PLOT_KEYS.size())):
		var axis: Dictionary = vc.get_axis(i) if vc.has_method("get_axis") else {}
		var north_emoji := str(axis.get("north", ""))
		var rec: Dictionary = IconRegistry.find_icon_by_emoji(north_emoji)
		var icon_name := str(rec.get("name", north_emoji))
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.text = "[%s] %s" % [PLOT_KEYS[i], icon_name]
		lbl.add_theme_color_override("font_color",
			UIStyleFactory.COLOR_TAB_ACTIVE if i == _selected_idx else UIStyleFactory.COLOR_TAB_IDLE)
		_icon_row_box.add_child(lbl)

func _update_header() -> void:
	if not _active_biome:
		_header_label.text = "No active biome"
		return
	_header_label.text = "%s · plot %d" % [_biome_display_name(), _selected_idx]

func _build_active_plot_view() -> void:
	if not _active_biome:
		_content_box.add_child(_muted_label(
			"No active biome.\nSelect a biome on the farm and re-open B.", 13))
		return
	var nq = _get_num_qubits()
	if nq == 0:
		_content_box.add_child(_muted_label(
			"Biome has no qubits to inspect.", 13))
		return

	# Biome-level math — how this whole biome behaves (shown regardless of plot selection).
	_build_biome_physics_section()

	if _selected_idx < 0 or _selected_idx >= nq:
		_content_box.add_child(_muted_label(
			"No plot highlighted.\nGHJKL; works while this overlay is open — pick a plot without closing it.", 13))
		return

	var vc = _active_biome.viz_cache if _active_biome else null
	var qc = _active_biome.quantum_computer if _active_biome else null

	var north := "?"
	var south := "?"
	var current_emoji := ""
	var p_north: float = 0.5
	var p_south: float = 0.5
	if vc:
		var axis: Dictionary = vc.get_axis(_selected_idx)
		north = str(axis.get("north", "?"))
		south = str(axis.get("south", "?"))
	if qc and qc.has_method("get_marginal"):
		# get_marginal(qubit, pole) returns a FLOAT probability (pole 0 = north, 1 = south).
		p_north = float(qc.get_marginal(_selected_idx, 0))
		p_south = float(qc.get_marginal(_selected_idx, 1))
	current_emoji = north if p_north >= p_south else south

	# Live strip — biome-local marginals + purity + entanglement count.
	var strip := _make_card_panel(_content_box, _selected_plot_label(), "Live state of the active plot")
	strip.add_child(_make_kv_row("poles", "%s / %s  ·  p=%.2f / %.2f" % [north, south, p_north, p_south]))
	if qc:
		strip.add_child(_make_kv_row("purity", _format_percent(float(qc.get_marginal_purity(null, _selected_idx)))))
		strip.add_child(_make_kv_row("links", _plot_entanglement_summary(_selected_idx)))

	# Marginals bar — visual N/S split.
	_content_box.add_child(_make_marginals_strip(p_north, p_south, north, south))

	# IconCard for the current emoji — pass the plot's other pole so the card
	# describes THIS plot's word, not the registry's first icon holding the emoji.
	var current_complement: String = south if current_emoji == north else north
	var card_dict: Dictionary = IconCard.gather(current_emoji, farm, current_complement)
	if bool(card_dict.get("present", false)):
		_render_icon_card(card_dict)

	_build_entanglement_section()

func _make_marginals_strip(p_north: float, p_south: float, north: String, south: String) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var n_lbl := Label.new()
	n_lbl.text = north
	n_lbl.add_theme_font_size_override("font_size", EMOJI_SIZE)
	hbox.add_child(n_lbl)

	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_constant_override("separation", 0)

	var bg := StyleBoxFlat.new()
	bg.bg_color = UIStyleFactory.COLOR_BAR_BG
	bg.set_corner_radius_all(3)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", bg)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar.add_child(panel)

	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 1)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(inner)

	var nf := ColorRect.new()
	nf.color = UIStyleFactory.COLOR_BAR_NORTH
	nf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nf.size_flags_stretch_ratio = maxf(p_north, 0.02)
	inner.add_child(nf)

	var sf := ColorRect.new()
	sf.color = UIStyleFactory.COLOR_BAR_SOUTH
	sf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sf.size_flags_stretch_ratio = maxf(p_south, 0.02)
	inner.add_child(sf)

	hbox.add_child(bar)

	var s_lbl := Label.new()
	s_lbl.text = south
	s_lbl.add_theme_font_size_override("font_size", EMOJI_SIZE)
	hbox.add_child(s_lbl)

	return hbox

func _render_icon_card(card: Dictionary) -> void:
	var emoji: String = str(card.get("emoji", ""))
	var icon_name: String = str(card.get("icon_name", ""))
	var complement: String = str(card.get("complement", ""))

	var header_text: String = "icon · %s" % icon_name if icon_name != "" else "icon"
	_content_box.add_child(_make_section_header(header_text))
	if complement != "":
		var pair_lbl := Label.new()
		pair_lbl.text = "%s ↔ %s" % [emoji, complement]
		pair_lbl.add_theme_font_size_override("font_size", 14)
		pair_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_BODY)
		_content_box.add_child(pair_lbl)

	if bool(card.get("is_axial", false)):
		var axis_lbl := Label.new()
		axis_lbl.text = "axis: %s" % str(card.get("axis_label", ""))
		axis_lbl.add_theme_font_size_override("font_size", 11)
		axis_lbl.add_theme_color_override("font_color", COLOR_MUTED)
		_content_box.add_child(axis_lbl)

	var aff: float = float(card.get("affinity", 0.0))
	var known: bool = bool(card.get("player_known", false))
	var aff_lbl := Label.new()
	aff_lbl.text = "affinity %.2f   ·   %s" % [aff, "known ✓" if known else "unknown"]
	aff_lbl.add_theme_font_size_override("font_size", 11)
	aff_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_BODY)
	_content_box.add_child(aff_lbl)

	var speakers: Array = card.get("faction_speakers", [])
	if not speakers.is_empty():
		var sp_lbl := Label.new()
		sp_lbl.text = "spoken by  " + ", ".join(speakers)
		sp_lbl.add_theme_font_size_override("font_size", 11)
		sp_lbl.add_theme_color_override("font_color", COLOR_MUTED)
		_content_box.add_child(sp_lbl)

	var biomes: Array = card.get("biomes_present", [])
	if not biomes.is_empty():
		var bio_lbl := Label.new()
		bio_lbl.text = "in biomes  " + ", ".join(biomes)
		bio_lbl.add_theme_font_size_override("font_size", 11)
		bio_lbl.add_theme_color_override("font_color", COLOR_MUTED)
		_content_box.add_child(bio_lbl)

	var atom: Dictionary = card.get("atom_summary", {})
	if not atom.is_empty():
		var phys_lbl := Label.new()
		phys_lbl.text = "ε=%.2f   ·   γ=%.3f" % [
			float(atom.get("self_energy", 0.0)),
			float(atom.get("decay_rate", 0.0)),
		]
		phys_lbl.add_theme_font_size_override("font_size", 11)
		phys_lbl.add_theme_color_override("font_color", COLOR_COUPLING)
		_content_box.add_child(phys_lbl)
		var top: Array = atom.get("top_couplings", [])
		for entry in top:
			var w: float = float(entry.get("weight", 0.0))
			var sign_str: String = "+" if w >= 0.0 else "−"
			var coup_lbl := Label.new()
			coup_lbl.text = "  %s → %s   %s%.2f" % [
				str(entry.get("from", "")), str(entry.get("to", "")),
				sign_str, absf(w),
			]
			coup_lbl.add_theme_font_size_override("font_size", 11)
			coup_lbl.add_theme_color_override("font_color", COLOR_MUTED)
			_content_box.add_child(coup_lbl)

func _build_biome_physics_section() -> void:
	# The closed-native "how does this biome work" math: its Hamiltonian's spectral gap
	# (rigid one-mode attractor vs plural many-mode) and energy variance Var(H) (how far the
	# live state sits from a stationary eigenstate). These are exactly the quantities the
	# campaign's finale reads — the player can watch their island become plural here.
	var qc = _active_biome.quantum_computer if _active_biome else null
	if not qc:
		return
	var body := _make_card_panel(_content_box, "How this biome behaves",
		"Closed-system character — set by composition, conserved under evolution")

	if qc.has_method("get_hamiltonian_spectral_gap"):
		var gap: float = qc.get_hamiltonian_spectral_gap()
		var gap_word: String
		var gap_color: Color
		if gap >= 0.6:
			gap_word = "rigid — one dominant mode imposed"
			gap_color = COLOR_LINDBLAD
		elif gap <= 0.45:
			gap_word = "plural — many modes coexist"
			gap_color = COLOR_ENTANGLE
		else:
			gap_word = "between — settling toward one mode"
			gap_color = UIStyleFactory.COLOR_BODY
		body.add_child(_make_kv_row("H-gap  E₁−E₀", "%.3f   ·   %s" % [gap, gap_word], gap_color))
		# Visual gap bar — wide gap fills the bar (rigid); narrow = plural.
		body.add_child(_make_ratio_bar(clampf(gap, 0.0, 1.0), gap_color))

	if qc.has_method("get_energy_variance"):
		var v: float = qc.get_energy_variance()
		var v_word := "settled — near a stationary eigenstate" if v < 0.05 else "restless — broad energy spread, marginals swing"
		body.add_child(_make_kv_row("Var(H)", "%.3f   ·   %s" % [v, v_word]))

	body.add_child(_make_kv_row("qubits", "%d  (atoms %d)" % [_get_num_qubits(), _get_num_qubits() * 2]))


func _make_ratio_bar(ratio: float, fill_color: Color) -> Control:
	var bar := PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = UIStyleFactory.COLOR_BAR_BG
	bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("panel", bg)
	bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 0)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar.add_child(inner)
	var fill := ColorRect.new()
	fill.color = fill_color
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.size_flags_stretch_ratio = maxf(ratio, 0.02)
	inner.add_child(fill)
	var rest := ColorRect.new()
	rest.color = Color(0, 0, 0, 0)
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rest.size_flags_stretch_ratio = maxf(1.0 - ratio, 0.02)
	inner.add_child(rest)
	return bar


func _build_entanglement_section() -> void:
	if not _active_biome:
		return
	var qc = _active_biome.quantum_computer if _active_biome else null
	if not qc or _get_num_qubits() < 2:
		return

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	_content_box.add_child(box)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	box.add_child(sep)

	var title := Label.new()
	title.text = "Entanglement"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", COLOR_ENTANGLE)
	box.add_child(title)

	var vc = _active_biome.viz_cache if _active_biome else null
	var nq = _get_num_qubits()
	var shown := 0
	for i in range(nq):
		for j in range(i + 1, nq):
			# viz_cache MI (precomputed by the lookahead); qc fallback reads the same
			# native cache. The GDScript per-pair recompute was deleted (2026-07-06).
			var mi = vc.get_mutual_information(i, j) if vc else qc.get_cached_mutual_information(i, j)
			if mi < 0.1:
				continue
			var axis_i = vc.get_axis(i) if vc else {}
			var axis_j = vc.get_axis(j) if vc else {}
			var lbl := Label.new()
			lbl.text = "q%d (%s) ↔ q%d (%s)  MI=%.2f" % [
				i, axis_i.get("north", "?"),
				j, axis_j.get("north", "?"), mi]
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color", COLOR_ENTANGLE)
			box.add_child(lbl)
			shown += 1

	if shown == 0:
		box.add_child(_muted_label("No significant entanglement (MI < 0.1)", 11))

# =============================================================================
# UI HELPERS
# =============================================================================

func _muted_label(text: String, font_size: int = 12) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", COLOR_MUTED)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl

func _make_section_header(title: String) -> Label:
	var lbl := Label.new()
	lbl.text = title.to_upper()
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.92))
	return lbl

func _make_card_panel(parent: Control, title: String, subtitle: String = "") -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UIStyleFactory.COLOR_CARD_BG
	style.border_color = UIStyleFactory.COLOR_CARD_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	panel.add_child(body)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.88, 0.93, 0.98))
	body.add_child(title_lbl)

	if subtitle != "":
		var sub_lbl := Label.new()
		sub_lbl.text = subtitle
		sub_lbl.add_theme_font_size_override("font_size", 11)
		sub_lbl.add_theme_color_override("font_color", COLOR_MUTED)
		sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(sub_lbl)

	return body

func _make_kv_row(label_text: String, value_text: String, value_color: Color = UIStyleFactory.COLOR_BODY) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", COLOR_MUTED)
	lbl.custom_minimum_size = Vector2(120, 0)
	row.add_child(lbl)

	var val := Label.new()
	val.text = value_text if value_text != "" else "—"
	val.add_theme_font_size_override("font_size", 12)
	val.add_theme_color_override("font_color", value_color)
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(val)

	return row

func _format_percent(value: float) -> String:
	if value < 0.0:
		return "—"
	return "%.1f%%" % (value * 100.0)

func _selected_plot_label() -> String:
	var nq := _get_num_qubits()
	if _selected_idx < 0 or _selected_idx >= nq or not _active_biome or not _active_biome.viz_cache:
		return "no plot selected"
	var axis = _active_biome.viz_cache.get_axis(_selected_idx)
	return "q%d  %s / %s" % [_selected_idx, str(axis.get("north", "?")), str(axis.get("south", "?"))]

func _plot_entanglement_summary(qi: int) -> String:
	var qc = _active_biome.quantum_computer if _active_biome else null
	if not qc:
		return "—"
	var vc = _active_biome.viz_cache if _active_biome else null
	var total := 0
	for j in range(_get_num_qubits()):
		if j == qi:
			continue
		var mi = vc.get_mutual_information(qi, j) if vc else qc.get_cached_mutual_information(qi, j)
		if mi > 0.05:
			total += 1
	return "%d linked plot(s)" % total

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

# =============================================================================
# SURFACE CONTRACT
# =============================================================================

func get_visible_data() -> Dictionary:
	var selected_label := _selected_plot_label()
	var hint := "Active plot microscope — pure overlay, mirrors farm selection."
	var payload: Dictionary = {
		"scope_mode": "plot",
		"active_plot_idx": _selected_idx,
	}
	if _active_biome and _active_biome.viz_cache and _selected_idx >= 0 and _selected_idx < _get_num_qubits():
		var axis: Dictionary = _active_biome.viz_cache.get_axis(_selected_idx)
		payload["plot_emoji"] = str(axis.get("north", ""))
		payload["plot_axis"] = axis
	return build_surface_visible_data(
		"Active",
		_selected_idx,
		selected_label,
		hint,
		payload,
	)

func get_transitions() -> Array:
	return [
		{"surface_id": "farm", "reason": "return to live instrument"},
		{"surface_id": "N", "reason": "biome network · whole · matrix"},
		{"surface_id": "V", "reason": "vocabulary · subspace"},
		{"surface_id": "M", "reason": "eigen · marginals (Bits)"},
	]
