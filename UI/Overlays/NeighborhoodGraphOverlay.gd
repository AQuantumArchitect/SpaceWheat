class_name NeighborhoodGraphOverlay
extends "res://UI/Core/OverlayBase.gd"

## NeighborhoodGraphOverlay — a GraphEdit node-flow view of ONE neighborhood's
## quantum cluster (the 4-6 qubit reservoir of the active biome).
##
## It renders a [NeighborhoodGraph] — a DERIVED view over canonical data (icons.json
## couplings + biome.atom_components webway): each realized icon is a GraphNode (its
## two emoji poles + live population bars), coherent (Hamiltonian) couplings and the
## directed webway/decay edges are connections, and node emojis shared with other
## factions get a "🌐 → N" port badge (the seam into the wider vocabulary DAG, e.g.
## The Demos' 🌾 → the farming factions). Read/inspect only for now — editing that
## writes session deltas is a later, separate step (canonical JSON stays the truth).

const NeighborhoodGraphRef = preload("res://Core/QuantumSubstrate/NeighborhoodGraph.gd")

const COLOR_COHERENT := Color(0.6, 0.45, 0.9)   # Hamiltonian coupling (purple)
const COLOR_WEBWAY := Color(0.95, 0.55, 0.25)   # Lindblad / webway flow (orange)
const COLOR_PORT := Color(0.3, 0.8, 0.55)        # shared-vocabulary port (teal)

var farm: Node = null
var _active_biome: Node = null          # live BiomeBase node (live populations)
var _graph = null                        # NeighborhoodGraph (derived)
var _graph_edit: GraphEdit = null
var _node_widgets: Dictionary = {}       # qubit -> {gnode, north_bar, south_bar, north, south}
var _refresh_accum := 0.0


func _init() -> void:
	overlay_name = "neighborhood_graph"
	overlay_icon = "🕸"
	overlay_tier = 12
	panel_title = "🕸 Neighborhood Graph"
	panel_title_size = 22
	panel_size_mode = PanelSizeMode.LARGE
	show_dimmer = true
	dimmer_color = Color(0, 0, 0, 0.8)
	panel_border_color = Color(0.4, 0.5, 0.7, 0.85)
	use_scroll_container = false   # GraphEdit fills the panel itself
	content_spacing = 4
	navigation_mode = NavigationMode.NONE


func _build_content(container: Control) -> void:
	_graph_edit = GraphEdit.new()
	_graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph_edit.custom_minimum_size = Vector2(720, 460)
	# Read/inspect view — don't let the user drag-disconnect canonical edges yet.
	_graph_edit.right_disconnects = false
	_graph_edit.show_grid = true
	container.add_child(_graph_edit)


func _on_activated() -> void:
	_resolve()
	_rebuild_graph()


func _resolve() -> void:
	if not farm:
		var gsm = (Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
		if gsm and gsm.has_method("get_active_farm"):
			farm = gsm.get_active_farm()
	_active_biome = null
	if not farm:
		return
	var abm = (Engine.get_main_loop().root.get_node_or_null("/root/ActiveBiomeManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if abm and farm.grid and farm.grid.has_method("get_biome"):
		_active_biome = farm.grid.get_biome(abm.get_active_biome())


## Build the derived graph from the canonical Biome data (source of truth) for the
## active biome; the live node only supplies population readouts in _process.
func _rebuild_graph() -> void:
	_graph = null
	if _graph_edit == null:
		return
	var biome_name := ""
	if _active_biome and _active_biome.has_method("get_biome_type"):
		biome_name = _active_biome.get_biome_type()
	var canonical = _canonical_biome(biome_name)
	if canonical != null:
		_graph = NeighborhoodGraphRef.from_biome(canonical)
		set_title("🕸 %s — neighborhood" % biome_name)
	_populate_graph()


func _canonical_biome(biome_name: String):
	if biome_name == "":
		return null
	var reg = load("res://Core/Biomes/BiomeRegistry.gd")
	if reg != null and reg.has_method("get_shared"):
		var shared = reg.get_shared()
		if shared != null and shared.has_method("get_by_name"):
			return shared.get_by_name(biome_name)
	return null


func _populate_graph() -> void:
	if _graph_edit == null:
		return
	_graph_edit.clear_connections()
	for child in _graph_edit.get_children():
		child.queue_free()
	_node_widgets.clear()
	if _graph == null or _graph.node_count() == 0:
		return

	var n := _graph.node_count()
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

		_graph_edit.add_child(gn)
		_node_widgets[q] = {
			"gnode": gn, "north_bar": north_row["bar"], "south_bar": south_row["bar"],
			"north": str(nd["north"]), "south": str(nd["south"]),
		}

	# A single sink node collects decay→🗑 outflow.
	var has_sink := false
	for e in _graph.edges:
		if str(e["kind"]) == "sink":
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
		_graph_edit.add_child(sg)

	# Edges. Coherent uses port 0 (row 0); webway/sink use port 1 (row 1).
	for e in _graph.edges:
		var from_name := "q%d" % int(e["from_qubit"])
		var kind := str(e["kind"])
		var to_q := int(e["to_qubit"])
		if kind == "coherent" and to_q >= 0:
			_graph_edit.connect_node(from_name, 0, "q%d" % to_q, 0)
		elif kind == "webway" and to_q >= 0:
			_graph_edit.connect_node(from_name, 1, "q%d" % to_q, 1)
		elif kind == "sink" and has_sink:
			_graph_edit.connect_node(from_name, 1, "sink", 0)


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
	if not visible or not is_active:
		return
	_refresh_accum += delta
	if _refresh_accum < 0.2:
		return
	_refresh_accum = 0.0
	var qc = _active_biome.quantum_computer if (_active_biome and "quantum_computer" in _active_biome) else null
	if qc == null or not qc.has_method("get_population"):
		return
	for q in _node_widgets.keys():
		var w = _node_widgets[q]
		if w["north_bar"]:
			w["north_bar"].value = clampf(float(qc.get_population(w["north"])) * 100.0, 0.0, 100.0)
		if w["south_bar"]:
			w["south_bar"].value = clampf(float(qc.get_population(w["south"])) * 100.0, 0.0, 100.0)
