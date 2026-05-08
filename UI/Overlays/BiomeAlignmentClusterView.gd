class_name BiomeAffinityClusterView
extends Control

const FactionAxes = preload("res://Core/Factions/FactionAxes.gd")
const AffinityGraphCls = preload("res://Core/Affinity/AffinityGraph.gd")

const MAX_FACTIONS: int = 12
const MAX_BIOMES: int = 8
const MIN_SCORE: float = 0.05

const COLOR_CENTER := Color(0.90, 0.78, 0.36, 0.95)
const COLOR_CENTER_GLOW := Color(1.0, 0.92, 0.55, 0.22)
const COLOR_FACTION := Color(0.45, 0.72, 0.96, 0.92)
const COLOR_FACTION_HOT := Color(0.98, 0.87, 0.42, 0.95)
const COLOR_BIOME := Color(0.57, 0.84, 0.68, 0.92)
const COLOR_BIOME_HOT := Color(0.98, 0.69, 0.36, 0.95)
const COLOR_LINK := Color(0.72, 0.80, 0.92, 0.18)
const COLOR_LINK_HOT := Color(0.93, 0.88, 0.45, 0.34)
const COLOR_MUTED := Color(0.55, 0.60, 0.70)
const COLOR_RING := Color(0.35, 0.40, 0.50, 0.28)
const COLOR_TEXT := Color(0.90, 0.93, 0.98)

var _farm: Node = null
var _biome = null
var _biome_name: String = ""
var _center_affinity = null
var _center_bits: Array = []
var _center_color: Color = COLOR_CENTER
var _center_label: String = ""

var _center_node := {}
var _faction_nodes: Array = []
var _biome_nodes: Array = []
var _snapshot: Dictionary = {}
var _view_zoom: float = 1.0
var _view_rotation_degrees: float = 0.0
var _highlight_name: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(560, 560)


func set_scope(farm: Node, biome_name: String, biome) -> void:
	_farm = farm
	_biome_name = biome_name
	_biome = biome
	_rebuild()


func refresh() -> void:
	_rebuild()


func get_cluster_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func set_view_state(zoom: float, rotation_degrees: float) -> void:
	_view_zoom = clampf(zoom, 0.72, 1.55)
	_view_rotation_degrees = fposmod(rotation_degrees, 360.0)
	if not _center_node.is_empty():
		_layout_nodes()
		_build_snapshot()
		queue_redraw()


func set_highlight_name(name: String) -> void:
	_highlight_name = name
	queue_redraw()


func get_selectable_nodes() -> Array:
	var all_nodes: Array = []
	all_nodes.append_array(_faction_nodes)
	all_nodes.append_array(_biome_nodes)
	all_nodes.sort_custom(func(a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	return all_nodes.slice(0, mini(6, all_nodes.size()))


func get_view_state() -> Dictionary:
	return {
		"zoom": _view_zoom,
		"rotation_degrees": _view_rotation_degrees,
	}


func reset_view_state() -> void:
	set_view_state(1.0, 0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_nodes()
		queue_redraw()


func _rebuild() -> void:
	_center_affinity = _live_biome_affinity(_biome, _farm)
	_center_bits = _biome_bits(_biome)
	_center_color = _biome_color(_biome)
	_center_label = _display_biome_name(_biome_name, _biome)

	_center_node = {}
	_faction_nodes.clear()
	_biome_nodes.clear()
	_snapshot = {}

	if _biome == null:
		queue_redraw()
		return

	_center_node = {
		"kind": "center",
		"name": _center_label,
		"score": 1.0,
		"radius": 34.0,
		"color": _center_color,
		"position": Vector2.ZERO,
	}

	var faction_rows: Array = []
	var biome_rows: Array = []

	var density = _farm.faction_density if _farm and "faction_density" in _farm else null
	var registry = density.get_registry() if density and density.has_method("get_registry") else null
	if density and registry:
		for fname in density.get_faction_names():
			var faction = registry.get_by_name(str(fname))
			if faction == null:
				continue
			var score := _faction_score(faction)
			var native_boost := 0.0
			if _biome_native_factions().has(str(faction.name)):
				native_boost = 0.15
			score = clampf(score + native_boost, 0.0, 1.0)
			if score < MIN_SCORE:
				continue
			faction_rows.append({
				"kind": "faction",
				"name": str(faction.name),
				"score": score,
				"radius": lerpf(9.0, 21.0, score),
				"color": COLOR_FACTION.lerp(COLOR_FACTION_HOT, score),
				"native": native_boost > 0.0,
				"target": faction,
			})

	var biomes := _get_all_biomes()
	for bname in biomes.keys():
		if str(bname) == _biome_name:
			continue
		var other_biome = biomes[bname]
		var score := _biome_score(other_biome)
		if score < MIN_SCORE:
			continue
		biome_rows.append({
			"kind": "biome",
			"name": str(bname),
			"score": score,
			"radius": lerpf(8.0, 18.0, score),
			"color": COLOR_BIOME.lerp(COLOR_BIOME_HOT, score),
			"target": other_biome,
		})

	faction_rows.sort_custom(func(a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	biome_rows.sort_custom(func(a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))

	_faction_nodes = faction_rows.slice(0, min(MAX_FACTIONS, faction_rows.size()))
	_biome_nodes = biome_rows.slice(0, min(MAX_BIOMES, biome_rows.size()))
	_layout_nodes()
	_build_snapshot()
	queue_redraw()


func _layout_nodes() -> void:
	if _center_node.is_empty():
		return

	var sz := size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return

	var center := sz * 0.5
	_center_node["position"] = center

	var base := minf(sz.x, sz.y)
	var faction_radius := base * 0.22
	var biome_radius := base * 0.38

	for i in range(_faction_nodes.size()):
		var node: Dictionary = _faction_nodes[i]
		var t := 0.0 if _faction_nodes.size() <= 1 else float(i) / float(_faction_nodes.size())
		var angle := TAU * t + 0.1
		var score := float(node.get("score", 0.0))
		var dist := faction_radius * lerpf(0.95, 0.58, score)
		node["position"] = center + Vector2(cos(angle), sin(angle)) * dist
		_faction_nodes[i] = node

	for i in range(_biome_nodes.size()):
		var node = _biome_nodes[i]
		var t := 0.0 if _biome_nodes.size() <= 1 else float(i) / float(_biome_nodes.size())
		var angle := TAU * t + 0.55
		var score := float(node.get("score", 0.0))
		var dist := biome_radius * lerpf(0.98, 0.68, score)
		node["position"] = center + Vector2(cos(angle), sin(angle)) * dist
		_biome_nodes[i] = node

	_apply_view_transform(center)


func _apply_view_transform(center: Vector2) -> void:
	var radians := deg_to_rad(_view_rotation_degrees)
	for i in range(_faction_nodes.size()):
		var node: Dictionary = _faction_nodes[i]
		var pos: Vector2 = node.get("position", center)
		var offset := (pos - center).rotated(radians) * _view_zoom
		node["position"] = center + offset
		_faction_nodes[i] = node
	for i in range(_biome_nodes.size()):
		var node: Dictionary = _biome_nodes[i]
		var pos: Vector2 = node.get("position", center)
		var offset := (pos - center).rotated(radians) * _view_zoom
		node["position"] = center + offset
		_biome_nodes[i] = node


func _build_snapshot() -> void:
	_snapshot = {
		"selected_biome": _biome_name,
		"selected_biome_label": _center_label,
		"selected_biome_native_factions": _biome_native_factions(),
		"faction_count": _faction_nodes.size(),
		"biome_count": _biome_nodes.size(),
		"view_state": get_view_state(),
		"top_factions": _snapshot_nodes(_faction_nodes),
		"top_biomes": _snapshot_nodes(_biome_nodes),
	}


func _snapshot_nodes(nodes: Array) -> Array:
	var out: Array = []
	for node in nodes:
		out.append({
			"name": node.get("name", ""),
			"score": node.get("score", 0.0),
			"kind": node.get("kind", ""),
		})
	return out


func _draw() -> void:
	var sz := size
	var center := sz * 0.5
	var base := minf(sz.x, sz.y)
	var faction_radius := base * 0.22
	var biome_radius := base * 0.38

	draw_arc(center, faction_radius, 0.0, TAU, 96, COLOR_RING, 1.0, true)
	draw_arc(center, biome_radius, 0.0, TAU, 96, COLOR_RING, 1.0, true)

	if _center_node.is_empty():
		_draw_empty(center)
		return

	_draw_center(center)
	_draw_links(center)
	_draw_bubbles(_faction_nodes)
	_draw_bubbles(_biome_nodes)


func _draw_empty(center: Vector2) -> void:
	var font = get_theme_default_font()
	if font == null:
		return
	draw_string(font, center + Vector2(-120, 0), "no active biome", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_MUTED)


func _draw_center(center: Vector2) -> void:
	var radius := float(_center_node.get("radius", 34.0))
	draw_circle(center, radius + 8.0, COLOR_CENTER_GLOW)
	draw_circle(center, radius, _center_color)
	var font = get_theme_default_font()
	if font:
		draw_string(font, center + Vector2(-radius, 6.0), _short_name(_center_label),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.12, 0.13, 0.16, 0.95))


func _draw_links(center: Vector2) -> void:
	for node in _faction_nodes:
		_draw_link(center, node)
	for node in _biome_nodes:
		_draw_link(center, node)

	for faction_node in _faction_nodes:
		for biome_node in _biome_nodes:
			var score := _pair_score(faction_node.get("target", null), biome_node.get("target", null))
			if score < 0.25:
				continue
			var color := COLOR_LINK_HOT if score > 0.55 else COLOR_LINK
			color.a = lerpf(0.08, 0.30, score)
			draw_line(
				faction_node.get("position", center),
				biome_node.get("position", center),
				color,
				lerpf(0.8, 2.0, score),
				true
			)


func _draw_link(center: Vector2, node: Dictionary) -> void:
	var score := float(node.get("score", 0.0))
	var color: Color = node.get("color", COLOR_LINK)
	color.a = lerpf(0.10, 0.38, score)
	draw_line(center, node.get("position", center), color, lerpf(0.8, 2.1, score), true)


func _draw_bubbles(nodes: Array) -> void:
	var font = get_theme_default_font()
	for idx in range(nodes.size()):
		var node: Dictionary = nodes[idx]
		var pos: Vector2 = node.get("position", Vector2.ZERO)
		var radius: float = float(node.get("radius", 10.0))
		var score: float = float(node.get("score", 0.0))
		var color: Color = node.get("color", COLOR_LINK)
		var glow := color
		glow.a = 0.12
		draw_circle(pos, radius + 4.0, glow)
		draw_circle(pos, radius, color)
		if node.get("native", false):
			draw_circle(pos, radius + 2.5, Color(1.0, 0.94, 0.6, 0.18))
		if _highlight_name != "" and str(node.get("name", "")) == _highlight_name:
			draw_arc(pos, radius + 5.0, 0.0, TAU, 48, Color(1.0, 0.97, 0.55, 0.92), 2.5, true)
		if font and (score > 0.42 or idx < 4):
			var label_pos := pos + Vector2(radius + 4.0, -radius - 2.0)
			draw_string(font, label_pos, _short_name(str(node.get("name", ""))),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COLOR_TEXT)


func _faction_score(faction) -> float:
	if faction == null:
		return 0.0
	if _center_affinity != null and faction.affinity != null:
		return clampf(float(faction.affinity.overlap(_center_affinity)), 0.0, 1.0)
	var faction_bits := _bits_to_array(faction.get_axial_bits() if faction.has_method("get_axial_bits") else [])
	return _axial_overlap(faction_bits, _center_bits)


func _biome_score(biome) -> float:
	if biome == null:
		return 0.0
	if biome == _biome:
		return 1.0
	var other_name := ""
	if biome.has_method("get_biome_type"):
		other_name = str(biome.get_biome_type())
	elif "biome_name" in biome:
		other_name = str(biome.biome_name)
	elif "name" in biome:
		other_name = str(biome.name)
	if not _biome_name.is_empty() and other_name == _biome_name:
		return 1.0
	var other_affinity = _live_biome_affinity(biome, _farm)
	if _center_affinity != null and other_affinity != null:
		return clampf(float(_center_affinity.overlap(other_affinity)), 0.0, 1.0)
	var other_bits := _biome_bits(biome)
	return _axial_overlap(other_bits, _center_bits)


func _pair_score(faction, biome) -> float:
	if faction == null or biome == null:
		return 0.0
	if faction.affinity != null:
		var other_affinity = _live_biome_affinity(biome, _farm)
		if other_affinity != null:
			return clampf(float(faction.affinity.overlap(other_affinity)), 0.0, 1.0)
	var faction_bits := _bits_to_array(faction.get_axial_bits() if faction.has_method("get_axial_bits") else [])
	var biome_bits := _biome_bits(biome)
	return _axial_overlap(faction_bits, biome_bits)


func _live_biome_affinity(biome, farm) -> Object:
	if biome == null or farm == null:
		return null
	if not biome.has_method("get_signature_pairs"):
		return null
	var pairs: Array = biome.get_signature_pairs()
	if pairs.is_empty():
		return null
	var lex = farm._ensure_icon_lexicon() if farm.has_method("_ensure_icon_lexicon") else null
	if lex == null and "icon_lexicon" in farm:
		lex = farm.icon_lexicon
	if lex == null:
		return null
	var density = farm.faction_density if "faction_density" in farm else null
	if density == null or not density.has_method("get_registry"):
		return null
	var registry = density.get_registry()
	if registry == null:
		return null
	var owners: Array = []
	for pair in pairs:
		var icon: Dictionary = lex.find_icon_by_pair(str(pair.pole_0), str(pair.pole_1))
		var owner: String = str(icon.get("owner_faction", "")) if not icon.is_empty() else ""
		if owner != "":
			owners.append(owner)
	if owners.is_empty():
		return null
	var first_f = registry.get_by_name(owners[0])
	if first_f == null or first_f.affinity == null:
		return null
	var bg = AffinityGraphCls.from_dict(first_f.affinity.to_dict())
	for i in range(1, owners.size()):
		var f = registry.get_by_name(owners[i])
		if f != null and f.affinity != null:
			bg.lindblad_jump_toward(f.affinity, 1.0 / float(i + 1))
	return bg


func _biome_bits(biome) -> Array:
	var out: Array = []
	if biome == null:
		return out
	var live_affinity = biome.affinity if "affinity" in biome else null
	if live_affinity != null and live_affinity.has_method("principal_bits"):
		var packed: PackedByteArray = live_affinity.principal_bits()
		for bit in packed:
			out.append(float(bit))
		if out.size() == AffinityGraphCls.AXIS_COUNT:
			return out
	var native := _biome_native_factions()
	if native.is_empty():
		return _neutral_bits()
	var density = _farm.faction_density if _farm and "faction_density" in _farm else null
	var registry = density.get_registry() if density and density.has_method("get_registry") else null
	if registry == null:
		return _neutral_bits()
	var sums: Array = []
	for i in range(FactionAxes.AXIS_COUNT):
		sums.append(0.0)
	var counted := 0
	for fname in native:
		var faction = registry.get_by_name(str(fname))
		if faction == null:
			continue
		var bits = faction.get_axial_bits() if faction.has_method("get_axial_bits") else PackedByteArray()
		for i in range(mini(bits.size(), FactionAxes.AXIS_COUNT)):
			sums[i] += float(bits[i])
		counted += 1
	if counted <= 0:
		return _neutral_bits()
	for i in range(FactionAxes.AXIS_COUNT):
		out.append(sums[i] / float(counted))
	return out


func _biome_native_factions() -> Array:
	if _biome == null:
		return []
	return _biome.get_admitted_factions()


func _neutral_bits() -> Array:
	var out: Array = []
	for _i in range(FactionAxes.AXIS_COUNT):
		out.append(0.5)
	return out


func _bits_to_array(bits) -> Array:
	var out: Array = []
	if bits == null:
		return out
	for i in range(bits.size()):
		out.append(float(bits[i]))
	return out


func _axial_overlap(a: Array, b: Array) -> float:
	var n: int = mini(a.size(), b.size())
	if n <= 0:
		return 0.0
	var diff_sum: float = 0.0
	for i in range(n):
		diff_sum += absf(float(a[i]) - float(b[i]))
	return clampf(1.0 - (diff_sum / float(n)), 0.0, 1.0)


func _get_all_biomes() -> Dictionary:
	if _farm == null or not ("grid" in _farm) or _farm.grid == null:
		return {}
	if _farm.grid.has_method("get_all_biomes"):
		return _farm.grid.get_all_biomes()
	return {}


func _biome_color(biome) -> Color:
	var fallback := Color(0.85, 0.75, 0.40, 0.90)
	if biome == null:
		return fallback
	if "_biome_data" in biome and biome._biome_data is Dictionary:
		var vc = biome._biome_data.get("visual_config", {})
		if vc is Dictionary and vc.has("color"):
			var color_arr: Array = vc.get("color", [])
			if color_arr.size() >= 4:
				return Color(float(color_arr[0]), float(color_arr[1]), float(color_arr[2]), float(color_arr[3]))
	if "visual_config" in biome and biome.visual_config is Dictionary:
		var vc2: Dictionary = biome.visual_config
		if vc2.has("color"):
			var color_arr2: Array = vc2.get("color", [])
			if color_arr2.size() >= 4:
				return Color(float(color_arr2[0]), float(color_arr2[1]), float(color_arr2[2]), float(color_arr2[3]))
	return fallback


func _display_biome_name(biome_name: String, biome) -> String:
	if biome != null:
		if "visual_config" in biome and biome.visual_config is Dictionary and biome.visual_config.has("label"):
			return str(biome.visual_config.get("label", biome_name))
		if "_biome_data" in biome and biome._biome_data is Dictionary:
			var vc = biome._biome_data.get("visual_config", {})
			if vc is Dictionary and vc.has("label"):
				return str(vc.get("label", biome_name))
	if biome_name.is_empty():
		return "selected biome"
	return biome_name


func _short_name(full: String) -> String:
	if full.length() <= 14:
		return full
	return "%s…" % full.left(13)
