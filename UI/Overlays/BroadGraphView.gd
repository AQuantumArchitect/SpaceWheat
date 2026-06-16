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

const COLOR_NODE := Color(0.45, 0.65, 0.9)       # biome cluster node (blue)
const COLOR_EDGE := Color(0.5, 0.75, 0.6)         # shared-vocabulary federation seam

var _broad = null                          # BroadGraph (derived)
var _selectable: Array = []                # ordered biome names (keyboard nav)
var _name_to_node: Dictionary = {}         # biome_name -> GraphNode


func _init() -> void:
	right_disconnects = false
	show_grid = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


## Render the whole-world federation graph (rebuilds all nodes + connections).
func populate(broad) -> void:
	_broad = broad
	clear_connections()
	# Free only the GraphNodes we added — NOT every child. GraphEdit keeps an internal,
	# non-internal `connection_layer` child; queue_free-ing it corrupts the GraphEdit
	# ("connections_layer is missing" on the next scroll/redraw).
	for child in get_children():
		if child is GraphNode:
			child.queue_free()
	_selectable.clear()
	_name_to_node.clear()
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


func _neighbor_tooltip(bname: String, neigh: Array) -> String:
	if neigh.is_empty():
		return "%s — no shared-vocabulary neighbors" % bname
	var lines: Array = ["%s ─ federation:" % bname]
	for e in neigh:
		var shared: Array = e.get("shared", [])
		lines.append("  %s  ×%d  [%s]" % [str(e.get("biome", "")), int(e.get("weight", 0)), "".join(shared)])
	return "\n".join(lines)


## Spread biome nodes around a ring so the federation reads as a graph, not a column.
func _layout_pos(index: int, count: int) -> Vector2:
	if count <= 1:
		return Vector2(360, 260)
	var center := Vector2(420, 300)
	var radius := 260.0
	var ang := TAU * float(index) / float(count) - PI / 2.0
	return center + Vector2(cos(ang), sin(ang)) * radius
