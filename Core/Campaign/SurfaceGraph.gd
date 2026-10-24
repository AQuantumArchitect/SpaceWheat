class_name SurfaceGraph
extends RefCounted

## The UI as a graph, and where the player is on it right now.
##
## Nodes are surfaces: "field" (the farm, keys act on plots), "field:icon" and
## "field:gate" (the Icon and gate submenus on the field), "X/<tab>" and
## "C/<tab>" (the two menus and their tabs, from guide.keymap.surfaces in the
## campaign spec), and "menu:<name>" for any other overlay (Z, V, N, M, …).
## Edges are keys: a menu's `open` key from anywhere outside it, a tab key
## inside it, and `close` (ESC) from anything that is not the field.
##
## Every instruction that names keys asks this file for the path from the
## surface that is open NOW to the surface the next action lives on. Nothing
## else spells a menu path by hand, so a line can't tell you to press a tab
## key of a menu you don't have open.

const UIP := preload("res://UI/Core/UIProgression.gd")

const FIELD := "field"
const ANY_TAB := "*"   # a menu just opened onto its last-shown tab


static func _surfaces() -> Dictionary:
	var km: Dictionary = CampaignRuntime.guide().get("keymap", {})
	var s = km.get("surfaces", {})
	return s if s is Dictionary else {}


static func close_key() -> String:
	return str(CampaignRuntime.guide().get("keymap", {}).get("close", "ESC"))


## Menu ids ("X", "C") in the spec.
static func menus() -> Array:
	var out: Array = []
	for m in _surfaces():
		if not str(m).begins_with("_") and _surfaces()[m] is Dictionary:
			out.append(str(m))
	return out


static func tabs(menu: String) -> Array:
	var spec = _surfaces().get(menu, {})
	return spec.get("tabs", []) if spec is Dictionary else []


static func tab(menu: String, tab_id: String) -> Dictionary:
	for t in tabs(menu):
		if t is Dictionary and str(t.get("id", "")) == tab_id:
			return t
	return {}


## The key and display name for "X/arc"-style nodes, for text that names a
## place without walking to it ("it's on Charge [U]").
static func tab_key(node: String) -> String:
	var parts := node.split("/")
	return str(tab(parts[0], parts[1] if parts.size() > 1 else "").get("key", "")) if parts.size() > 1 else ""


static func tab_name(node: String) -> String:
	var parts := node.split("/")
	return str(tab(parts[0], parts[1] if parts.size() > 1 else "").get("name", node)) if parts.size() > 1 else node


# ------------------------------------------------------------------ where am I

## The node the player is on right now, read from the live UI.
static func current() -> String:
	if UIP._board_open():
		var board = UIP._quest_board()
		var f := str(board.get("frame_id")) if board != null else ""
		return "C/" + (f if f != "" else ANY_TAB)
	var om = UIP._overlay_manager()
	# The stack's bottom is the permanent play base (the game itself), so the
	# top only means a menu when the stack says something sits above it.
	var above: bool = om != null and om.has_method("is_overlay_active") and bool(om.is_overlay_active())
	var top = om.get_active_overlay() if above and om.has_method("get_active_overlay") else null
	if top != null:
		var oname := str(top.get("overlay_name")) if "overlay_name" in top else ""
		if oname == "controls":
			var f2 := str(top.get("frame_id")) if "frame_id" in top else ""
			return "X/" + (f2 if f2 != "" else ANY_TAB)
		# The biome microscope is transparent: field keys pass through it.
		if oname != "biome_inspector":
			return "menu:" + oname
	if UIP._in_icon_submenu():
		return "field:icon"
	if UIP._in_gate_submenu():
		return "field:gate"
	return FIELD


static func on(node: String) -> bool:
	return current() == node


# ------------------------------------------------------------------ the graph

## Outgoing edges of `node`: [{to, key, label}].
static func edges(node: String) -> Array:
	var out: Array = []
	if node != FIELD:
		out.append({"to": FIELD, "key": close_key(), "label": "close"})
	var here_menu := node.split("/")[0] if "/" in node else ""
	for m in menus():
		var spec: Dictionary = _surfaces()[m]
		if m == here_menu:
			for t in tabs(m):
				var tid := str(t.get("id", ""))
				if node != m + "/" + tid:
					out.append({"to": m + "/" + tid, "key": str(t.get("key", "")), "label": str(t.get("name", tid))})
		elif node == FIELD:
			# Opening a menu lands on its `reopens` tab, else on whatever tab it
			# last showed — a node the path must still step out of with a tab key.
			var land := str(spec.get("reopens", ANY_TAB))
			out.append({"to": m + "/" + land, "key": str(spec.get("open", "")), "label": str(spec.get("name", m))})
	return out


## Breadth-first path from the current surface (or `from`) to `target`, as
## Guide chord parts: [[label, key], ...]. [] when already there. A target of
## "X/*" means "the X menu, any tab".
static func path(target: String, from: String = "") -> Array:
	var start := from if from != "" else current()
	if _same(start, target):
		return []
	var prev := {start: null}
	var queue: Array = [start]
	while not queue.is_empty():
		var n: String = queue.pop_front()
		for e in edges(n):
			var to := str(e["to"])
			if prev.has(to):
				continue
			prev[to] = [n, [str(e["label"]), str(e["key"])]]
			if _same(to, target):
				var parts: Array = []
				var cur := to
				while prev[cur] != null:
					parts.push_front(prev[cur][1])
					cur = prev[cur][0]
				return parts
			queue.append(to)
	return [[ "close", close_key() ]]


static func _same(a: String, b: String) -> bool:
	if a == b:
		return true
	# "X/*" (just opened, tab unknown) is not yet on a specific tab, but a
	# target of "X/*" is satisfied by any X tab.
	if b.ends_with("/" + ANY_TAB) and a.split("/")[0] == b.split("/")[0] and "/" in a:
		return true
	return false
