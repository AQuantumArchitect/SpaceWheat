extends RefCounted

## Shared GraphEdit plumbing for the two derived graph views (slop knot #21):
## BroadGraphView (whole-world federation) and NeighborhoodGraphView (one
## cluster). Static composition helpers — deliberately NOT a base class; each
## view keeps its own class identity and only delegates the mechanical parts.

const COLOR_ENTANGLE := Color(1.0, 0.84, 0.25)  # live mutual information (gold)


static func setup_graph_edit(ge: GraphEdit) -> void:
	# Read/inspect views — don't let the user drag-disconnect canonical edges.
	ge.right_disconnects = false
	ge.show_grid = true
	ge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ge.size_flags_vertical = Control.SIZE_EXPAND_FILL


static func clear_graph_nodes(ge: GraphEdit) -> void:
	# Free only the GraphNodes the view added — NOT every child. GraphEdit
	# keeps an internal, non-internal `connection_layer` child; queue_free-ing
	# it corrupts the GraphEdit ("connections_layer is missing" on the next
	# scroll/redraw). remove_child BEFORE queue_free: the free is deferred,
	# and while old same-named nodes are still in the tree the new ones get
	# auto-renamed on add_child — every connect_node would then bind to a
	# dying node and the edges would silently vanish at frame end.
	ge.clear_connections()
	for child in ge.get_children():
		if child is GraphNode:
			ge.remove_child(child)
			child.queue_free()


static func ring_layout_pos(index: int, count: int, center: Vector2, radius: float, single: Vector2) -> Vector2:
	# Spread nodes around a ring so the view reads as a graph, not a column.
	if count <= 1:
		return single
	var ang := TAU * float(index) / float(count) - PI / 2.0
	return center + Vector2(cos(ang), sin(ang)) * radius
