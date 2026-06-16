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

const COLOR_COHERENT := Color(0.6, 0.45, 0.9)   # Hamiltonian coupling (purple)
const COLOR_WEBWAY := Color(0.95, 0.55, 0.25)   # Lindblad / webway flow (orange)
const COLOR_PORT := Color(0.3, 0.8, 0.55)        # shared-vocabulary port (teal)

var _graph = null                        # NeighborhoodGraph (derived)
var _live_qc = null                      # live QuantumComputer for population bars
var _node_widgets: Dictionary = {}       # qubit -> {gnode, north_bar, south_bar, north, south}
var _refresh_accum := 0.0


func _init() -> void:
	# Read/inspect view — don't let the user drag-disconnect canonical edges yet.
	right_disconnects = false
	show_grid = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


## Render the derived cluster graph (rebuilds all nodes + connections).
func populate(graph) -> void:
	_graph = graph
	clear_connections()
	# Free only the GraphNodes we added — NOT every child. GraphEdit keeps an internal,
	# non-internal `connection_layer` child; queue_free-ing it corrupts the GraphEdit
	# ("connections_layer is missing" on the next scroll/redraw).
	for child in get_children():
		if child is GraphNode:
			child.queue_free()
	_node_widgets.clear()
	if _graph == null or _graph.node_count() == 0:
		return

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
		# Row 0 = coherent (H) port (purple); Row 1 = webway (L) port (orange).
		gn.set_slot(0, true, 0, COLOR_COHERENT, true, 0, COLOR_COHERENT)
		gn.set_slot(1, true, 1, COLOR_WEBWAY, true, 1, COLOR_WEBWAY)

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
			"north": str(nd["north"]), "south": str(nd["south"]),
		}

	# Webway (Lindblad) flow and the decay sink only exist in the open system. In the
	# closed (unitary) system there are no dissipators, so we draw coherent edges only.
	var closed: bool = not BalanceConfig.dissipative_enabled()

	# A single sink node collects decay→🗑 outflow (open system only).
	var has_sink := false
	for e in _graph.edges:
		if not closed and str(e["kind"]) == "sink":
			has_sink = true
			break
	if has_sink:
		var sg := GraphNode.new()
		sg.name = "sink"
		sg.title = "🗑 sink"
		sg.position_offset = Vector2(360, 360)
		var lbl := Label.new()
		lbl.text = "decay"
		sg.add_child(lbl)
		sg.set_slot(0, true, 1, COLOR_WEBWAY, false, 0, Color.WHITE)
		add_child(sg)

	# Edges. Coherent uses port 0 (row 0); webway/sink use port 1 (row 1).
	for e in _graph.edges:
		var from_name := "q%d" % int(e["from_qubit"])
		var kind := str(e["kind"])
		var to_q := int(e["to_qubit"])
		if kind == "coherent" and to_q >= 0:
			connect_node(from_name, 0, "q%d" % to_q, 0)
		elif kind == "webway" and to_q >= 0 and not closed:
			connect_node(from_name, 1, "q%d" % to_q, 1)
		elif kind == "sink" and has_sink:
			connect_node(from_name, 1, "sink", 0)


## Supply the live biome's QuantumComputer; _process pulls populations from it.
func set_live_source(qc) -> void:
	_live_qc = qc


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
	if count <= 1:
		return Vector2(300, 200)
	var center := Vector2(330, 210)
	var radius := 180.0
	var ang := TAU * float(index) / float(count) - PI / 2.0
	return center + Vector2(cos(ang), sin(ang)) * radius


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
