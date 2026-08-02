extends Node3D
# SpaceWheat · Cognifolds — a FRACTAL, navigable belief-field of SpaceWheat's own
# world. Root = the starting trio as concentric shells (TheDemos at the core,
# Village around it, StarterForest around that). Each sphere is a real biome emoji
# on a theme-coloured glowing orb — a bubble reinvented in 3D. Click a sphere to
# DIVE into it: the emoji maps to a biome, whose emojis become the next shell...
# all the way down. Drag to orbit · Esc / right-click to surface.

const CYAN := Color(0.37, 0.92, 0.84)
const SPHERE_R := 0.34

var world := {}
var reg := {}
var pivot: Node3D
var cam: Camera3D
var fade: ColorRect
var nodes: Array = []
var stack: Array = []
var dragging := false
var moved := false
var transitioning := false
var hovered := -1
var t_title: Label
var t_sub: Label
var t_crumb: Label


func _ready() -> void:
	cam = Camera3D.new()
	cam.position = Vector3(0, 0, 9.0)
	cam.fov = 55.0
	add_child(cam)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.038, 0.075)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.72)
	env.ambient_light_energy = 0.55
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_bloom = 0.2
	env.glow_hdr_threshold = 0.9
	we.environment = env
	add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-44, -32, 0)
	key.light_energy = 0.6
	add_child(key)

	pivot = Node3D.new()
	add_child(pivot)

	_load_world()
	_load_registry()
	_build_ui()
	stack = [{"kind": "root"}]
	_build_current()


# ---------------------------------------------------------------- data loading
func _load_world() -> void:
	var f := FileAccess.open("res://scenes/cognifold_world.json", FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if typeof(d) == TYPE_DICTIONARY:
			world = d
	if not world.has("biomes"):
		world = {"root": [], "biomes": {}, "emoji_to_biome": {}}


func _load_registry() -> void:
	var f := FileAccess.open("res://Assets/emoji_registry.json", FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	for grp in ["twemoji", "custom"]:  # custom last -> overrides
		if d.has(grp) and typeof(d[grp]) == TYPE_DICTIONARY:
			for k in d[grp]:
				reg[k] = d[grp][k]


func _emoji_tex(e: String) -> Texture2D:
	for cand in [e, e + "️", e.replace("️", "")]:
		if reg.has(cand):
			var p: String = reg[cand]
			if ResourceLoader.exists(p):
				return load(p)
	return null


# ------------------------------------------------------------ level construction
func _clear_nodes() -> void:
	for nd in nodes:
		for k in ["mesh", "ring", "sprite", "dot"]:
			if nd.get(k) != null:
				nd[k].queue_free()
	nodes.clear()


func _build_current() -> void:
	_clear_nodes()
	var desc: Dictionary = stack.back()
	if desc.kind == "root":
		var shells: Array = world.get("root", [])
		var radii := [1.15, 2.75, 4.35]
		for si in range(shells.size()):
			var b = world["biomes"].get(shells[si], null)
			if b == null:
				continue
			_shell(b.get("emojis", []), radii[min(si, 2)], float(b.get("hue", 0.115)))
		_set_titles("SPACEWHEAT", "the starting world — a cognifold you can enter")
	else:
		var b = world["biomes"].get(desc.name, {"emojis": [], "hue": 0.115, "desc": ""})
		_fib_field(b.get("emojis", []), float(b.get("hue", 0.115)))
		_set_titles(str(desc.name).to_upper(), str(b.get("desc", "")))
	_update_crumb()


func _shell(emojis: Array, radius: float, hue: float) -> void:
	var n := emojis.size()
	for i in range(n):
		var pos: Vector3
		if n == 1:
			pos = Vector3.ZERO
		else:
			var y := 1.0 - (float(i) / float(max(1, n - 1))) * 2.0
			var rr := sqrt(max(0.0, 1.0 - y * y))
			var phi := float(i) * PI * (3.0 - sqrt(5.0))
			pos = Vector3(cos(phi) * rr, y, sin(phi) * rr) * radius
		_spawn(str(emojis[i]), pos, hue)


func _fib_field(emojis: Array, hue: float) -> void:
	var n := emojis.size()
	for i in range(n):
		var y := 1.0 - (float(i) / float(max(1, n - 1))) * 1.7
		var rr := sqrt(max(0.0, 1.0 - y * y))
		var phi := float(i) * PI * (3.0 - sqrt(5.0))
		var pos := Vector3(cos(phi) * rr, y, sin(phi) * rr) * 3.0
		if n == 1:
			pos = Vector3.ZERO
		_spawn(str(emojis[i]), pos, hue)


func _spawn(emoji: String, pos: Vector3, hue: float) -> void:
	var col := Color.from_hsv(hue, 0.62, 1.0)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = SPHERE_R
	sm.height = SPHERE_R * 2.0
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col.darkened(0.55)
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.25
	mat.metallic = 0.2
	mat.roughness = 0.4
	mat.rim_enabled = true
	mat.rim = 0.7
	mi.material_override = mat
	mi.position = pos
	pivot.add_child(mi)

	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = SPHERE_R + 0.09
	tm.outer_radius = SPHERE_R + 0.15
	ring.mesh = tm
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = Color(col.r, col.g, col.b, 0.8)
	rmat.emission_enabled = true
	rmat.emission = col
	rmat.emission_energy_multiplier = 1.8
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = rmat
	ring.position = pos
	ring.rotation_degrees = Vector3(78, 0, 0)
	pivot.add_child(ring)

	var sp: Sprite3D = null
	var tex := _emoji_tex(emoji)
	if tex != null:
		sp = Sprite3D.new()
		sp.texture = tex
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.shaded = false
		sp.no_depth_test = true
		sp.pixel_size = 0.62 / float(max(8, tex.get_width()))
		sp.position = pos
		pivot.add_child(sp)

	var dot := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.055
	dm.height = 0.11
	dot.mesh = dm
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.albedo_color = CYAN
	dmat.emission_enabled = true
	dmat.emission = CYAN
	dmat.emission_energy_multiplier = 3.0
	dot.material_override = dmat
	pivot.add_child(dot)

	var target = world.get("emoji_to_biome", {}).get(emoji, "")
	nodes.append({
		"mesh": mi, "ring": ring, "sprite": sp, "dot": dot, "pos": pos, "col": col,
		"emoji": emoji, "target": target, "mat": mat,
		"belief": Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized(),
		"conf": randf_range(0.5, 0.9), "flash": 0.0,
	})


# --------------------------------------------------------------------- runtime
func _process(dt: float) -> void:
	if not dragging and not transitioning:
		pivot.rotate_object_local(Vector3.UP, dt * 0.11)
	var mp := get_viewport().get_mouse_position()
	hovered = _pick(mp) if not dragging else -1
	var t := Time.get_ticks_msec() * 0.001
	for i in range(nodes.size()):
		var nd: Dictionary = nodes[i]
		nd.belief = nd.belief.rotated(Vector3.UP, dt * 0.25 * (1.0 - nd.flash)).normalized()
		nd.conf = lerpf(nd.conf, 0.32, dt * 0.12)
		nd.flash = maxf(0.0, nd.flash - dt * 1.6)
		var hv := 1.0 if i == hovered else 0.0
		nd.mat.emission_energy_multiplier = 0.9 + 1.9 * clampf(nd.conf, 0.0, 1.0) + 2.6 * hv + 3.0 * nd.flash
		var s: float = 1.0 + 0.045 * sin(t * 1.6 + float(nd.pos.x) * 1.7) + 0.22 * hv + 0.5 * nd.flash
		nd.mesh.scale = Vector3.ONE * s
		if nd.sprite != null:
			nd.sprite.scale = Vector3.ONE * (1.0 + 0.22 * hv)
		nd.ring.rotate_object_local(Vector3.UP, dt * (0.6 + 1.4 * hv))
		var gl: float = SPHERE_R + 0.08 + 0.34 * clampf(nd.conf, 0.0, 1.0)
		nd.dot.position = nd.pos + nd.belief * gl


func _pick(sp: Vector2) -> int:
	var best := -1
	var bd := 54.0
	for i in range(nodes.size()):
		var gp: Vector3 = nodes[i].mesh.global_position
		if cam.is_position_behind(gp):
			continue
		var d := cam.unproject_position(gp).distance_to(sp)
		if d < bd:
			bd = d
			best = i
	return best


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		_back()
	elif ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
			_back()
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				dragging = true
				moved = false
			else:
				dragging = false
				if not moved:
					var idx := _pick(ev.position)
					if idx >= 0:
						_enter(idx)
	elif ev is InputEventMouseMotion and dragging:
		if ev.relative.length() > 1.5:
			moved = true
		pivot.rotate_object_local(Vector3.UP, ev.relative.x * 0.008)
		pivot.rotate_object_local(Vector3.RIGHT, ev.relative.y * 0.008)


func _enter(idx: int) -> void:
	if transitioning:
		return
	var nd: Dictionary = nodes[idx]
	nd.flash = 1.0
	var target = nd.target
	if target == null or str(target) == "" or not world["biomes"].has(target):
		return
	_go({"kind": "biome", "name": target}, true)


func _back() -> void:
	if transitioning or stack.size() <= 1:
		return
	_go(null, false)


func _go(desc, push: bool) -> void:
	transitioning = true
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.3)
	tw.parallel().tween_property(pivot, "scale", Vector3.ONE * (2.3 if push else 0.42), 0.3)
	tw.tween_callback(func():
		if push:
			stack.append(desc)
		else:
			stack.pop_back()
		pivot.scale = Vector3.ONE
		_build_current())
	tw.tween_property(fade, "color:a", 0.0, 0.4)
	tw.tween_callback(func(): transitioning = false)


# --------------------------------------------------------------------------- UI
func _mk(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _set_titles(name: String, sub: String) -> void:
	t_title.text = name
	t_sub.text = sub


func _update_crumb() -> void:
	var parts := ["SpaceWheat"]
	for i in range(1, stack.size()):
		parts.append(str(stack[i].get("name", "")))
	t_crumb.text = "  ›  ".join(parts)


func _build_ui() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 1
	add_child(cl)
	t_title = _mk("SPACEWHEAT", 40, Color(0.96, 0.80, 0.36))
	t_title.position = Vector2(38, 26)
	cl.add_child(t_title)
	t_sub = _mk("", 17, Color(0.72, 0.70, 0.85))
	t_sub.position = Vector2(40, 78)
	cl.add_child(t_sub)
	var hint := _mk("drag to orbit  ·  click a sphere to dive in  ·  Esc to surface", 15, Color(0.55, 0.62, 0.72))
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	hint.offset_left = -560
	hint.offset_top = 32
	hint.offset_right = -34
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cl.add_child(hint)
	t_crumb = _mk("SpaceWheat", 16, Color(0.60, 0.66, 0.78))
	t_crumb.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	t_crumb.offset_left = 40
	t_crumb.offset_top = -54
	t_crumb.offset_bottom = -28
	cl.add_child(t_crumb)

	var fl := CanvasLayer.new()
	fl.layer = 2
	add_child(fl)
	fade = ColorRect.new()
	fade.color = Color(0.02, 0.02, 0.05, 0.0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.add_child(fade)
