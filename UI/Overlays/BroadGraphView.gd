class_name BroadGraphView
extends GraphEdit

## BroadGraphView — a reusable GraphEdit body for the WHOLE-WORLD federation: every
## live biome's neighborhood cluster as one node, linked by shared-vocabulary seams.
##
## It renders a [BroadGraph] — a DERIVED view (no new physics; Model C untouched). One
## GraphNode per neighborhood (biome name + qubit / port counts), federation edges where
## two biomes' realized clusters share atoms (the seam the N "Biome Network" surface
## reads, here drawn as a graph). Selecting a biome node is the drill-down seam into its
## per-neighborhood cluster (rendered by [NeighborhoodGraphView]).
##
## Read/inspect only. The host supplies a derived [BroadGraph] via populate(); keyboard
## selection runs over get_selectable_biomes() + set_highlight().

const GraphViewCommon = preload("res://UI/Overlays/GraphViewCommon.gd")

const COLOR_NODE := Color(0.45, 0.65, 0.9)       # biome cluster node (blue)
const COLOR_EDGE := Color(0.5, 0.75, 0.6)         # shared-vocabulary federation seam
const COLOR_ENTANGLE := GraphViewCommon.COLOR_ENTANGLE  # live entanglement badge (gold)

var _broad = null                          # BroadGraph (derived)
var _selectable: Array = []                # ordered biome names (keyboard nav)
var _name_to_node: Dictionary = {}         # biome_name -> GraphNode
var _mi_labels: Dictionary = {}            # biome_name -> gold ◈ badge Label
var _live_lookup := Callable()             # biome_name -> live QuantumComputer (host-supplied)
var _refresh_accum := 0.0


func _init() -> void:
	GraphViewCommon.setup_graph_edit(self)


## Host supplies biome_name → live QuantumComputer resolution; _process then pulls
## a per-biome max-MI badge from the native cache (cache-only — no eigensolves).
func set_live_lookup(lookup: Callable) -> void:
	_live_lookup = lookup


## Render the whole-world federation graph (rebuilds all nodes + connections).
func populate(broad) -> void:
	_broad = broad
	GraphViewCommon.clear_graph_nodes(self)
	_selectable.clear()
	_name_to_node.clear()
	_mi_labels.clear()
	if _broad == null:
		return

	var names: Array = _broad.neighborhoods.keys()
	names.sort()
	var n: int = names.size()
	for i in range(n):
		var bname := str(names[i])
		var ng = _broad.neighborhoods[bname]
		var gn := GraphNode.new()
		gn.name = bname
		gn.title = bname
		gn.position_offset = _layout_pos(i, n)

		var stat := Label.new()
		var nq := int(ng.node_count()) if ng != null and ng.has_method("node_count") else 0
		var nports := int(ng.ports.size()) if ng != null and "ports" in ng else 0
		stat.text = "%dq · %d🌐" % [nq, nports]
		gn.add_child(stat)
		# Live entanglement badge — filled by _process when a live QC resolves.
		var mi_lbl := Label.new()
		mi_lbl.text = ""
		mi_lbl.add_theme_font_size_override("font_size", 10)
		mi_lbl.add_theme_color_override("font_color", COLOR_ENTANGLE)
		mi_lbl.tooltip_text = "Strongest woven pair inside this cluster (mutual information, bits).\nDrill in to see which qubits carry it."
		gn.add_child(mi_lbl)
		_mi_labels[bname] = mi_lbl
		# Single slot, enabled both sides so federation edges attach either direction.
		gn.set_slot(0, true, 0, COLOR_EDGE, true, 0, COLOR_EDGE)

		var neigh: Array = _broad.neighbors_of(bname) if _broad.has_method("neighbors_of") else []
		gn.tooltip_text = _neighbor_tooltip(bname, neigh)

		add_child(gn)
		_name_to_node[bname] = gn
		_selectable.append(bname)

	# Federation edges (undirected; BroadGraph stores a<b, draw once).
	for e in _broad.edges:
		var a := str(e["a"])
		var b := str(e["b"])
		if _name_to_node.has(a) and _name_to_node.has(b):
			connect_node(a, 0, b, 0)


## Biome names in display order — the host drives keyboard selection over this.
func get_selectable_biomes() -> Array:
	return _selectable.duplicate()


## Mark one biome node as selected (visual highlight for keyboard focus).
func set_highlight(biome_name: String) -> void:
	for nm in _name_to_node.keys():
		var gn = _name_to_node[nm]
		if is_instance_valid(gn):
			gn.set_selected(str(nm) == biome_name)


## One E-press worth of detail for a federation node (touch-first: E is the
## canonical "more information" channel; the node tooltip mirrors this).
func inspect_text_for(biome_name: String) -> String:
	if _broad == null or biome_name == "":
		return ""
	var neigh: Array = _broad.neighbors_of(biome_name) if _broad.has_method("neighbors_of") else []
	var lines: Array[String] = [_neighbor_tooltip(biome_name, neigh)]
	if _live_lookup.is_valid():
		var qc = _live_lookup.call(biome_name)
		if qc != null and qc.has_method("get_cached_max_mutual_information"):
			var mi := float(qc.get_cached_max_mutual_information())
			if mi >= 0.15:
				lines.append("◈ strongest woven pair inside: %.2f bit — drill in (E) to see which qubits carry it" % mi)
	lines.append("green ━ seams: shared atoms federate two clusters' vocabularies")
	return "\n".join(lines)


func _neighbor_tooltip(bname: String, neigh: Array) -> String:
	if neigh.is_empty():
		return "%s — no shared-vocabulary neighbors" % bname
	var lines: Array = ["%s ─ federation:" % bname]
	for e in neigh:
		var shared: Array = e.get("shared", [])
		lines.append("  %s  ×%d  [%s]" % [str(e.get("biome", "")), int(e.get("weight", 0)), "".join(shared)])
	return "\n".join(lines)


## Refresh the gold ◈ badges from each live cluster's MI cache (0.5s cadence).
func _process(delta: float) -> void:
	if not visible or not _live_lookup.is_valid():
		return
	_refresh_accum += delta
	if _refresh_accum < 0.5:
		return
	_refresh_accum = 0.0
	for bname in _mi_labels.keys():
		var lbl = _mi_labels[bname]
		if lbl == null or not is_instance_valid(lbl):
			continue
		var qc = _live_lookup.call(str(bname))
		var max_mi := -1.0
		if qc != null and qc.has_method("get_cached_max_mutual_information"):
			max_mi = float(qc.get_cached_max_mutual_information())
		lbl.text = "◈ %.2f bit" % max_mi if max_mi >= 0.15 else ""


## Spread biome nodes around a ring so the federation reads as a graph, not a column.
func _layout_pos(index: int, count: int) -> Vector2:
	return GraphViewCommon.ring_layout_pos(index, count, Vector2(420, 300), 260.0, Vector2(360, 260))
