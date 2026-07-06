class_name BiomeStateViews
extends RefCounted

## BiomeStateViews — extracted biome state rendering (Sprint 2 of ZXCVBNM refac).
##
## Owns the four math views that previously lived on N (InspectorOverlay):
##   matrix         — raw 2^N × 2^N density matrix heatmap
##   probabilities  — per-qubit probability bars
##   subspace       — single-qubit Bloch readout (text)
##   eigen          — N×N qubit correlation matrix (population + MI)
##
## Owns its container nodes and per-view caches; the host overlay creates
## the helper, calls `build_*_view()` to mount each frame, then calls
## `set_biome()` + `update_view(frame_id)` as state changes.
##
## Sprint 2 caller: BiomeInspectorOverlay (B). N is stubbed.

# =============================================================================
# CONSTANTS
# =============================================================================

const HEATMAP_SIZE: int = 280
const MATRIX_CELL_SIZE: int = 52
const BAR_HEIGHT: int = 20
const BAR_MAX_WIDTH: int = 200

const COLOR_MI_BASE := Color(0.08, 0.12, 0.14, 1.0)
const COLOR_MI_FULL := Color(0.2, 0.95, 0.55, 1.0)
const COLOR_DIAG_LOW := Color(0.15, 0.15, 0.18, 1.0)
const COLOR_DIAG_HIGH := Color(0.92, 0.92, 0.95, 1.0)
const COLOR_CELL_BORDER := Color(0.2, 0.25, 0.3, 0.6)
const COLOR_SELECTED_BORDER := Color(1.0, 0.9, 0.3, 0.9)
const COLOR_HEADER := Color(0.7, 0.8, 0.9)
const COLOR_MUTED := Color(0.45, 0.52, 0.6)

# =============================================================================
# STATE
# =============================================================================

var biome = null
var quantum_computer = null
var register_data: Array = []  # [{index, probability, emoji, coherence}, ...]
var selected_index: int = 0

# Per-view container refs (set by build_*_view methods)
var _heatmap_grid: GridContainer = null    # FRAME_MATRIX host
var _bars_container: VBoxContainer = null  # FRAME_PROBABILITIES host
var _subspace_label: Label = null          # FRAME_SUBSPACE host
var _eigen_grid: GridContainer = null      # FRAME_EIGEN host
var _eigen_cells: Array = []               # cache for in-place update


# =============================================================================
# DATA WIRING
# =============================================================================

func set_biome(b) -> void:
	biome = b
	quantum_computer = b.quantum_computer if b and "quantum_computer" in b else null
	refresh_data()


func set_selected(idx: int) -> void:
	selected_index = idx


func refresh_data() -> void:
	# Build per-qubit register_data from register_map + viz_cache.
	register_data.clear()
	if not quantum_computer or not quantum_computer.register_map:
		return
	var rm = quantum_computer.register_map
	var num_qubits: int = rm.num_qubits
	if num_qubits == 0:
		return
	var vc = biome.viz_cache if biome and "viz_cache" in biome else null
	var vc_ready = vc != null and vc.has_metadata()
	for i in range(num_qubits):
		var axis = rm.axis(i)
		var prob := -1.0
		var coherence := 0.0
		if vc_ready:
			var snap = vc.get_snapshot(i)
			if not snap.is_empty():
				prob = snap.get("p0", -1.0)
				coherence = snap.get("r_xy", 0.0)
		register_data.append({
			"index": i,
			"probability": prob,
			"emoji": axis.get("north", "?"),
			"coherence": coherence,
		})


func register_count() -> int:
	return register_data.size()


# =============================================================================
# DISPATCH
# =============================================================================

func update_view(frame_id: String) -> void:
	match frame_id:
		"matrix":         _update_heatmap()
		"probabilities":  _update_bars()
		"subspace":       _update_subspace()
		"eigen":          _update_eigen()


# =============================================================================
# MATRIX (raw density heatmap) — FRAME_MATRIX
# =============================================================================

func build_matrix_view() -> Control:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = "Raw ρ — diagonal: grayscale V, off-diagonal: HSV(phase)"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", COLOR_HEADER)
	container.add_child(label)
	_heatmap_grid = GridContainer.new()
	_heatmap_grid.columns = 1
	container.add_child(_heatmap_grid)
	return container


func _update_heatmap() -> void:
	if not _heatmap_grid or not quantum_computer:
		return
	for child in _heatmap_grid.get_children():
		child.queue_free()
	var num_qubits: int = quantum_computer.register_map.num_qubits
	if num_qubits == 0:
		return
	var dim: int = mini(1 << num_qubits, 32)
	_heatmap_grid.columns = dim
	var cell_px: int = maxi(4, int(float(HEATMAP_SIZE) / float(dim)))
	var rho = quantum_computer.get_density_matrix()
	var colors: PackedColorArray = rho.get_heatmap_colors(dim) if rho else PackedColorArray()
	var has_colors: bool = colors.size() >= dim * dim
	var stride: int = 1 << (register_data.size() - selected_index - 1) if selected_index >= 0 else -1
	for i in range(dim):
		for j in range(dim):
			var cell := Panel.new()
			cell.custom_minimum_size = Vector2(cell_px, cell_px)
			var style := StyleBoxFlat.new()
			style.bg_color = colors[i * dim + j] if has_colors else Color(0.1, 0.1, 0.1, 1.0)
			if stride > 0 and (int(float(i) / float(stride)) % 2 == 0 or int(float(j) / float(stride)) % 2 == 0):
				style.border_color = Color(1.0, 0.9, 0.3, 0.5)
				style.set_border_width_all(1)
			cell.add_theme_stylebox_override("panel", style)
			_heatmap_grid.add_child(cell)


# =============================================================================
# PROBABILITIES (per-qubit bars) — FRAME_PROBABILITIES
# =============================================================================

func build_bars_view() -> Control:
	_bars_container = VBoxContainer.new()
	_bars_container.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = "Register Probabilities (diagonal of ρ)"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", COLOR_HEADER)
	_bars_container.add_child(label)
	return _bars_container


func _update_bars() -> void:
	if not _bars_container:
		return
	# Clear all but the header label (idx 0)
	var children := _bars_container.get_children()
	for i in range(children.size()):
		if i > 0:
			children[i].queue_free()
	if register_data.is_empty():
		var msg := Label.new()
		msg.text = "No biome data — biome not found or still loading" if not biome else "Waiting for quantum state..."
		msg.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
		msg.add_theme_font_size_override("font_size", 13)
		_bars_container.add_child(msg)
		return
	for i in range(register_data.size()):
		_bars_container.add_child(_make_bar_row(i, register_data[i]))


func _make_bar_row(index: int, reg: Dictionary) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var emoji_label := Label.new()
	emoji_label.text = reg.get("emoji", "?")
	emoji_label.custom_minimum_size = Vector2(30, 0)
	emoji_label.add_theme_font_size_override("font_size", 16)
	hbox.add_child(emoji_label)
	var index_label := Label.new()
	index_label.text = "[%d]" % index
	index_label.custom_minimum_size = Vector2(30, 0)
	index_label.add_theme_font_size_override("font_size", 12)
	index_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	hbox.add_child(index_label)
	var bar := Panel.new()
	var prob: float = reg.get("probability", -1.0)
	var has_prob := prob >= 0.0
	bar.custom_minimum_size = Vector2(BAR_MAX_WIDTH * prob if has_prob else 0.0, BAR_HEIGHT)
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.3, 0.6, 0.9, 0.8) if has_prob else Color(0.35, 0.38, 0.45, 0.8)
	if index == selected_index:
		bar_style.bg_color = Color(0.9, 0.7, 0.2, 0.9)
	bar_style.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("panel", bar_style)
	hbox.add_child(bar)
	var prob_label := Label.new()
	prob_label.text = "%.1f%%" % (prob * 100.0) if has_prob else "—"
	prob_label.add_theme_font_size_override("font_size", 12)
	prob_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	hbox.add_child(prob_label)
	return hbox


# =============================================================================
# SUBSPACE (single-qubit Bloch text) — FRAME_SUBSPACE
# =============================================================================

func build_subspace_view() -> Control:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = "Subspace — Single-Qubit Bloch Projection"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", COLOR_HEADER)
	container.add_child(label)
	var sub := Label.new()
	sub.text = "WASD to focus a register"
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", COLOR_MUTED)
	container.add_child(sub)
	_subspace_label = Label.new()
	_subspace_label.add_theme_font_size_override("font_size", 14)
	_subspace_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	_subspace_label.text = "(no focus)"
	container.add_child(_subspace_label)
	return container


func _update_subspace() -> void:
	if not _subspace_label:
		return
	if register_data.is_empty() or selected_index < 0 or selected_index >= register_data.size():
		_subspace_label.text = "(no focus)"
		return
	var reg: Dictionary = register_data[selected_index]
	var emoji: String = reg.get("emoji", "?")
	var idx: int = reg.get("index", -1)
	var vc = biome.viz_cache if biome and "viz_cache" in biome else null
	if not vc or not vc.has_metadata():
		_subspace_label.text = "q%d %s — (state not ready)" % [idx, emoji]
		return
	var snap: Dictionary = vc.get_snapshot(idx)
	if snap.is_empty():
		_subspace_label.text = "q%d %s — (no Bloch data)" % [idx, emoji]
		return
	var p0: float = snap.get("p0", -1.0)
	var p1: float = snap.get("p1", -1.0)
	var r_xy: float = snap.get("r_xy", 0.0)
	var theta: float = snap.get("theta", PI / 2.0)
	var phi: float = snap.get("phi", 0.0)
	var purity: float = snap.get("purity", -1.0)
	_subspace_label.text = (
		"q%d %s\n"
		+ "P(north) = %s   P(south) = %s\n"
		+ "r_xy     = %.3f (equatorial coherence)\n"
		+ "theta    = %.3f rad   phi = %.3f rad\n"
		+ "purity   = %s"
	) % [idx, emoji, _fmt_prob_or_unknown(p0), _fmt_prob_or_unknown(p1), r_xy, theta, phi, _fmt_prob_or_unknown(purity)]


# =============================================================================
# EIGEN (N×N population + MI grid) — FRAME_EIGEN
# =============================================================================

func build_eigen_view() -> Control:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = "Qubit Correlation Matrix"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", COLOR_HEADER)
	container.add_child(label)
	var sub := Label.new()
	sub.text = "diagonal = population %   off-diagonal = mutual information"
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", COLOR_MUTED)
	container.add_child(sub)
	_eigen_grid = GridContainer.new()
	_eigen_grid.add_theme_constant_override("h_separation", 2)
	_eigen_grid.add_theme_constant_override("v_separation", 2)
	container.add_child(_eigen_grid)
	return container


func _update_eigen() -> void:
	if not _eigen_grid or not quantum_computer:
		return
	var nq: int = quantum_computer.register_map.num_qubits
	if nq == 0:
		return
	var rm = quantum_computer.register_map
	var need_rebuild: bool = _eigen_cells.size() != nq * nq
	if need_rebuild:
		for child in _eigen_grid.get_children():
			child.queue_free()
		_eigen_cells.clear()
		_eigen_grid.columns = nq + 1
		# Column headers: blank corner + emoji per qubit
		var corner := Control.new()
		corner.custom_minimum_size = Vector2(30, 24)
		_eigen_grid.add_child(corner)
		for j in range(nq):
			var col_lbl := Label.new()
			col_lbl.text = rm.axis(j).get("north", "?")
			col_lbl.add_theme_font_size_override("font_size", 18)
			col_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col_lbl.custom_minimum_size = Vector2(MATRIX_CELL_SIZE, 24)
			_eigen_grid.add_child(col_lbl)
		# Data rows
		for i in range(nq):
			var row_lbl := Label.new()
			row_lbl.text = rm.axis(i).get("north", "?")
			row_lbl.add_theme_font_size_override("font_size", 18)
			row_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row_lbl.custom_minimum_size = Vector2(30, MATRIX_CELL_SIZE)
			_eigen_grid.add_child(row_lbl)
			for j in range(nq):
				var cell_panel := PanelContainer.new()
				cell_panel.custom_minimum_size = Vector2(MATRIX_CELL_SIZE, MATRIX_CELL_SIZE)
				var cell_style := StyleBoxFlat.new()
				cell_style.set_corner_radius_all(4)
				cell_style.set_content_margin_all(2)
				cell_style.border_color = COLOR_CELL_BORDER
				cell_style.set_border_width_all(1)
				cell_panel.add_theme_stylebox_override("panel", cell_style)
				var cell_label := Label.new()
				cell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				cell_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				cell_label.add_theme_font_size_override("font_size", 11)
				cell_panel.add_child(cell_label)
				_eigen_grid.add_child(cell_panel)
				_eigen_cells.append({"panel": cell_panel, "label": cell_label, "row": i, "col": j})
	# Value + color update
	var vc = biome.viz_cache if biome and "viz_cache" in biome else null
	var vc_ready: bool = vc != null and vc.has_metadata()
	for entry in _eigen_cells:
		var i: int = entry.row
		var j: int = entry.col
		var panel: PanelContainer = entry.panel
		var lbl: Label = entry.label
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if not style:
			continue
		var flat_idx: int = i * nq + j
		var is_selected: bool = (flat_idx == selected_index)
		if i == j:
			var prob := -1.0
			if vc_ready:
				var snap = vc.get_snapshot(i)
				if not snap.is_empty():
					prob = snap.get("p0", -1.0)
			lbl.text = "%d%%" % int(prob * 100.0) if prob >= 0.0 else "—"
			lbl.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0) if prob > 0.55 else Color(0.85, 0.88, 0.92))
			style.bg_color = COLOR_DIAG_LOW.lerp(COLOR_DIAG_HIGH, prob) if prob >= 0.0 else Color(0.12, 0.13, 0.15, 1.0)
		else:
			# Native MI cache only — the GDScript per-pair recompute is gone (2026-07-06).
			var mi: float = quantum_computer.get_cached_mutual_information(i, j)
			var t: float = clampf(mi / 1.5, 0.0, 1.0)
			lbl.text = "%.2f" % mi if mi >= 0.01 else ""
			lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0) if t > 0.3 else Color(0.4, 0.5, 0.55))
			style.bg_color = COLOR_MI_BASE.lerp(COLOR_MI_FULL, t)
		if is_selected:
			style.border_color = COLOR_SELECTED_BORDER
			style.set_border_width_all(2)
		else:
			style.border_color = COLOR_CELL_BORDER
			style.set_border_width_all(1)


# =============================================================================
# DETAIL TEXT (used by host overlay's details panel)
# =============================================================================

func describe_selection(frame_id: String) -> String:
	if frame_id == "eigen":
		return _describe_eigen_cell()
	return _describe_register()


func _describe_eigen_cell() -> String:
	if not quantum_computer or register_data.is_empty():
		return "WASD to select a cell"
	var nq: int = quantum_computer.register_map.num_qubits
	if nq == 0 or selected_index < 0 or selected_index >= nq * nq:
		return "WASD to select a cell"
	var row: int = int(float(selected_index) / float(nq))
	var col: int = selected_index % nq
	var rm = quantum_computer.register_map
	var emoji_r: String = rm.axis(row).get("north", "?")
	var emoji_c: String = rm.axis(col).get("north", "?")
	if row == col:
		var prob := -1.0
		var coherence := 0.0
		var purity := -1.0
		var vc = biome.viz_cache if biome and "viz_cache" in biome else null
		if vc and vc.has_metadata():
			var snap = vc.get_snapshot(row)
			if not snap.is_empty():
				prob = snap.get("p0", -1.0)
				coherence = snap.get("r_xy", 0.0)
		if quantum_computer.has_method("get_marginal_purity"):
			purity = quantum_computer.get_marginal_purity(null, row)
		var p_txt := _fmt_prob_or_unknown(prob)
		var purity_txt := _fmt_prob_or_unknown(purity)
		return "q%d %s | P(north)=%s | Coherence=%.3f | Purity=%s" % [
			row, emoji_r, p_txt, coherence, purity_txt,
		]
	var mi: float = quantum_computer.get_cached_mutual_information(row, col)
	var strength := "none"
	if mi > 1.0:
		strength = "STRONG"
	elif mi > 0.3:
		strength = "moderate"
	elif mi > 0.05:
		strength = "weak"
	return "q%d %s <-> q%d %s | MI=%.3f (%s entanglement)" % [
		row, emoji_r, col, emoji_c, mi, strength,
	]


func _describe_register() -> String:
	if selected_index < 0 or selected_index >= register_data.size():
		return "WASD to select a register, E for details"
	var reg: Dictionary = register_data[selected_index]
	var prob: float = reg.get("probability", -1.0)
	return "Register %d: %s | P=%s | Coherence=%.3f" % [
		selected_index,
		reg.get("emoji", "?"),
		_fmt_prob_or_unknown(prob),
		reg.get("coherence", 0.0),
	]


func _fmt_prob_or_unknown(value: float) -> String:
	if value < 0.0:
		return "—"
	return "%.1f%%" % (value * 100.0)
