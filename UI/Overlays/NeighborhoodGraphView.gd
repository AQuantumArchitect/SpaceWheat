class_name NeighborhoodGraphView
extends GraphEdit

## NeighborhoodGraphView — a reusable GraphEdit body for ONE neighborhood's quantum
## cluster (the 4-6 qubit reservoir of a biome).
##
## It renders a [NeighborhoodGraph] — a DERIVED view over canonical data (icons.json
## couplings + biome.atom_components webway): each realized icon is a GraphNode (its two
## emoji poles + live population bars), coherent (Hamiltonian) couplings and the directed
## webway/decay edges are connections, and node emojis shared with other factions get a
## "🌐 → N" port badge (the seam into the wider vocabulary DAG, e.g. The Demos' 🌾 → the
## farming factions).
##
## Read/inspect only. The host supplies a derived [NeighborhoodGraph] via populate() and
## a live QuantumComputer via set_live_source(); this view never touches canonical data.
## Shared by the standalone 🕸 NeighborhoodGraphOverlay and the M · Graph drill-down.
##
## Three edge species, one per slot row (see Core/Documentation/glossary/):
##   row 0 · coherent (H)  — authored Hamiltonian couplings, purple
##   row 1 · webway   (L)  — authored Lindblad flow, orange. SEALED in the closed
##                           game: drawn dark, carries nothing (enclave.md) — the
##                           walls are visible even when the drain is dry.
##   row 2 · entanglement  — LIVE mutual information from the density matrix, gold.
##                           Not authored: this is the loom the player actually wove
##                           (gates + shared H evolution). Edge glow ∝ MI in bits;
##                           a Bell pair saturates at 2.

const GraphViewCommon = preload("res://UI/Overlays/GraphViewCommon.gd")

const COLOR_COHERENT := Color(0.6, 0.45, 0.9)   # Hamiltonian coupling (purple)
const COLOR_WEBWAY := Color(0.95, 0.55, 0.25)   # Lindblad / webway flow (orange)
const COLOR_WEBWAY_SEALED := Color(0.95, 0.55, 0.25, 0.22)  # closed mode: drawn, dormant
const COLOR_ENTANGLE := GraphViewCommon.COLOR_ENTANGLE  # live mutual information (gold)
const COLOR_PORT := Color(0.3, 0.8, 0.55)        # shared-vocabulary port (teal)

## MI below this (bits) is treated as loom noise, not a woven edge. A Bell pair
## reads 2.0; the CNOT/partial-entangle band the tutorial targets is 0.5–1.5.
const MI_EDGE_MIN := 0.15
const MI_FULL := 2.0    # bits at which the edge glow saturates (Bell pair)

var _graph = null                        # NeighborhoodGraph (derived)
var _live_qc = null                      # live QuantumComputer for population bars
var _node_widgets: Dictionary = {}       # qubit -> {gnode, north_bar, south_bar, north, south, mi_label}
var _mi_edges: Dictionary = {}           # "i|j" (i<j) -> true, live MI connections we own
var _legend: RichTextLabel = null
var _refresh_accum := 0.0


func _init() -> void:
	GraphViewCommon.setup_graph_edit(self)


## Render the derived cluster graph (rebuilds all nodes + connections).
func populate(graph) -> void:
	_graph = graph
	GraphViewCommon.clear_graph_nodes(self)
	_node_widgets.clear()
	_mi_edges.clear()
	if _graph == null or _graph.node_count() == 0:
		_update_legend(true)
		return

	# The webway (Lindblad flow + decay sink) is authored in every biome but SEALED
	# in the closed game: no dissipators are built, nothing decays (see
	# Core/Documentation/glossary/enclave.md + webway.md). We draw it anyway — dark, dormant —
	# so the player can see the channels the enclave is holding shut. Wet-country
	# biomes (What Fades regime seam) draw theirs LIVE.
	var closed: bool = _closed_here()
	var webway_color: Color = COLOR_WEBWAY_SEALED if closed else COLOR_WEBWAY

	var n: int = _graph.node_count()
	for nd in _graph.nodes:
		var q := int(nd["qubit"])
		var gn := GraphNode.new()
		gn.name = "q%d" % q
		gn.title = str(nd["icon_name"]) if str(nd["icon_name"]) != "" else "q%d" % q
		gn.position_offset = _layout_pos(q, n)

		var north_row = _make_pole_row(str(nd["north"]))
		gn.add_child(north_row["row"])
		var south_row = _make_pole_row(str(nd["south"]))
		gn.add_child(south_row["row"])
		# Live-MI readout row: strongest woven partner, updated by _process.
		var mi_lbl := Label.new()
		mi_lbl.text = "◈ —"
		mi_lbl.add_theme_font_size_override("font_size", 11)
		mi_lbl.add_theme_color_override("font_color", COLOR_ENTANGLE)
		mi_lbl.tooltip_text = "Mutual information with the most-entangled partner qubit (bits).\nNot authored — this is what you wove. A Bell pair reads 2.0."
		gn.add_child(mi_lbl)
		# Row 0 = coherent (H, purple); row 1 = webway (L, orange — sealed when
		# closed); row 2 = entanglement (live MI, gold).
		gn.set_slot(0, true, 0, COLOR_COHERENT, true, 0, COLOR_COHERENT)
		gn.set_slot(1, true, 1, webway_color, true, 1, webway_color)
		gn.set_slot(2, true, 2, COLOR_ENTANGLE, true, 2, COLOR_ENTANGLE)

		# Vocabulary-port badge: emojis shared with other factions → wider DAG.
		var pts: Array = _graph.ports_for(q)
		if not pts.is_empty():
			var total := 0
			for p in pts:
				total += int(p["neighbor_factions"].size())
			var badge := Label.new()
			badge.text = "🌐 → %d" % total
			badge.add_theme_color_override("font_color", COLOR_PORT)
			badge.tooltip_text = _port_tooltip(pts)
			gn.add_child(badge)

		add_child(gn)
		_node_widgets[q] = {
			"gnode": gn, "north_bar": north_row["bar"], "south_bar": south_row["bar"],
			"north": str(nd["north"]), "south": str(nd["south"]), "mi_label": mi_lbl,
		}

	# A single sink node collects decay→🗑 outflow. Sealed shut in the enclave.
	var has_sink := false
	for e in _graph.edges:
		if str(e["kind"]) == "sink":
			has_sink = true
			break
	if has_sink:
		var sg := GraphNode.new()
		sg.name = "sink"
		sg.title = "🗑 sealed" if closed else "🗑 sink"
		sg.position_offset = Vector2(360, 360)
		var lbl := Label.new()
		lbl.text = "dry" if closed else "decay"
		if closed:
			lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.6))
		sg.add_child(lbl)
		sg.tooltip_text = ("The webway's drain. Sealed here — this biome runs closed: no dissipators are built, " +
				"nothing leaks (Core/Documentation/glossary/enclave.md). The wet country runs the same channels live.") if closed else "Decay outflow — population leaving the cluster."
		sg.set_slot(0, true, 1, webway_color, false, 0, Color.WHITE)
		add_child(sg)

	# Authored edges. Coherent uses port 0; webway/sink use port 1 (sealed = drawn
	# dark). Live entanglement edges (port 2) are diffed in per _process tick.
	for e in _graph.edges:
		var from_name := "q%d" % int(e["from_qubit"])
		var kind := str(e["kind"])
		var to_q := int(e["to_qubit"])
		if kind == "coherent" and to_q >= 0:
			connect_node(from_name, 0, "q%d" % to_q, 0)
		elif kind == "webway" and to_q >= 0:
			connect_node(from_name, 1, "q%d" % to_q, 1)
		elif kind == "sink" and has_sink:
			connect_node(from_name, 1, "sink", 0)

	_update_legend(closed)


## Supply the live biome's QuantumComputer; _process pulls populations from it.
## Call BEFORE populate() so the webway draws in this biome's true regime.
func set_live_source(qc) -> void:
	_live_qc = qc


## Per-biome regime (What Fades): the wet country draws its webway LIVE while
## the rest of the world stays sealed. Falls back to the global switch when no
## live QC is attached (canonical-data-only views).
func _closed_here() -> bool:
	if _live_qc != null and _live_qc.has_method("is_open_here"):
		return not _live_qc.is_open_here()
	return not BalanceConfig.dissipative_enabled()


func _make_pole_row(emoji: String) -> Dictionary:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = emoji
	lbl.add_theme_font_size_override("font_size", 20)
	row.add_child(lbl)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	bar.custom_minimum_size = Vector2(90, 10)
	bar.show_percentage = false
	row.add_child(bar)
	return {"row": row, "bar": bar}


func _port_tooltip(ports: Array) -> String:
	var lines: Array = []
	for p in ports:
		lines.append("%s → %s" % [str(p["emoji"]), ", ".join(p["neighbor_factions"])])
	return "\n".join(lines)


## Spread nodes around a ring so the cluster reads as a graph, not a column.
func _layout_pos(index: int, count: int) -> Vector2:
	return GraphViewCommon.ring_layout_pos(index, count, Vector2(330, 210), 180.0, Vector2(300, 200))


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_accum += delta
	if _refresh_accum < 0.2:
		return
	_refresh_accum = 0.0
	var qc = _live_qc
	if qc == null or not qc.has_method("get_population"):
		return
	for q in _node_widgets.keys():
		var w = _node_widgets[q]
		if w["north_bar"]:
			w["north_bar"].value = clampf(float(qc.get_population(w["north"])) * 100.0, 0.0, 100.0)
		if w["south_bar"]:
			w["south_bar"].value = clampf(float(qc.get_population(w["south"])) * 100.0, 0.0, 100.0)
	_refresh_mi_edges(qc)


## Diff the gold entanglement edges against the LIVE mutual-information cache.
## Cache-only on purpose: without the native MI cache we draw nothing rather than
## trigger the expensive per-pair GDScript eigensolve fallback at UI rate.
func _refresh_mi_edges(qc) -> void:
	if not (qc.has_method("has_cached_mi") and qc.has_method("get_cached_mutual_information")):
		return
	var best_mi: Dictionary = {}      # qubit -> [mi, partner]
	var want: Dictionary = {}         # "i|j" -> mi
	if qc.has_cached_mi():
		var n: int = _node_widgets.size()
		if "register_map" in qc and qc.register_map != null:
			n = mini(n, int(qc.register_map.num_qubits))
		for i in range(n):
			for j in range(i + 1, n):
				var mi := float(qc.get_cached_mutual_information(i, j))
				if mi >= MI_EDGE_MIN:
					want["%d|%d" % [i, j]] = mi
				for q in [i, j]:
					var other: int = j if q == i else i
					var cur: float = float(best_mi[q][0]) if best_mi.has(q) else 0.0
					if mi > cur:
						best_mi[q] = [mi, other]

	# Drop edges that unwove; add the newly woven; set glow ∝ bits on the rest.
	for key in _mi_edges.keys():
		if not want.has(key):
			var pq: PackedStringArray = str(key).split("|")
			disconnect_node("q%s" % pq[0], 2, "q%s" % pq[1], 2)
			_mi_edges.erase(key)
	for key in want.keys():
		var pq: PackedStringArray = str(key).split("|")
		var a := "q%s" % pq[0]
		var b := "q%s" % pq[1]
		if not _mi_edges.has(key):
			if not (has_node(NodePath(a)) and has_node(NodePath(b))):
				continue
			connect_node(a, 2, b, 2)
			_mi_edges[key] = true
		set_connection_activity(a, 2, b, 2, clampf(float(want[key]) / MI_FULL, 0.0, 1.0))

	# Per-node readout: the strongest woven partner, in bits.
	for q in _node_widgets.keys():
		var lbl = _node_widgets[q].get("mi_label")
		if lbl == null:
			continue
		if best_mi.has(q) and float(best_mi[q][0]) >= MI_EDGE_MIN:
			lbl.text = "◈ %.2f bit ↔ q%d" % [float(best_mi[q][0]), int(best_mi[q][1])]
		else:
			lbl.text = "◈ —"


## One E-press worth of detail for the whole cluster view. Touch-first: E is the
## canonical "more information" channel (QERF plane); hover tooltips are optional
## desktop sugar and must never be the only home of a fact.
func inspect_text() -> String:
	var lines: Array[String] = []
	if _graph != null and _graph.node_count() > 0:
		lines.append("%s — %d-qubit neighborhood cluster" % [str(_graph.biome_name), _graph.node_count()])
	var closed: bool = _closed_here()
	lines.append("purple ━ coupling (H): authored, conservative — population sloshes, nothing is lost")
	if closed:
		lines.append("orange ━ webway (L): authored channels, SEALED — nothing flows while the enclave holds (Act 2 opens them)")
	else:
		lines.append("orange ━ webway (L): LIVE directed Lindblad flow — this is wet country; the Bath drinks here")
	lines.append("gold ━ entanglement: LIVE mutual information you wove (bits; a Bell pair reads 2.0)")
	lines.append("◈ row on each node: its most-entangled partner right now")
	if _live_qc != null and _live_qc.has_method("get_cached_max_mutual_information"):
		var mi := float(_live_qc.get_cached_max_mutual_information())
		if mi >= 0.0:
			lines.append("strongest woven pair: %.2f bit" % mi)
		else:
			lines.append("(entanglement readout needs the native MI cache — none in this build)")
	return "\n".join(lines)


## Fixed legend overlay (survives populate(), which only frees GraphNodes).
func _update_legend(closed: bool) -> void:
	if _legend == null:
		_legend = RichTextLabel.new()
		_legend.bbcode_enabled = true
		_legend.fit_content = true
		_legend.scroll_active = false
		_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_legend.custom_minimum_size = Vector2(300, 0)
		_legend.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_legend.position = Vector2(8, 4)
		add_child(_legend)
	var webway_note := "webway (L · sealed)" if closed else "webway (L)"
	_legend.text = "[color=#9973e6]━[/color] coupling (H)   [color=#f28c40]━[/color] %s   [color=#ffd643]━[/color] entanglement (live MI)" % webway_note
