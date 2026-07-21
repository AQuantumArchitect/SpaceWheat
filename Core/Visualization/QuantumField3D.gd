class_name QuantumField3D
extends SubViewportContainer
# Phase A (view-only): a 3D cognifold renderer for the live farm, gated behind the
# SW_FIELD_3D toggle. It reads the SAME `biome.viz_cache` the 2D renderer reads —
# per-register Bloch vectors (x,y,z,r,p0,p1) — and draws each register as a glowing
# 3D bubble:
#   • an emissive SphereMesh, glowing in the biome's THEME HUE (BiomeVisualTheme —
#     "one colour = one meaning"), its energy driven by coherence/purity r;
#   • a billboarded real-emoji Sprite3D (the register's north-pole axis icon);
#   • a golden RIPENESS ring (TorusMesh) — gold is the global ripeness/value colour in
#     EVERY biome, so it stays gold here; its brightness + girth track the honest
#     VisualizationConstants.ripeness(p0,p1);
#   • the honest Bloch-vector dot at the register's real (x,y,z), length = r.
# The field breathes and slowly orbits so it never reads as a dead screenshot.
#
# NO mechanics input is wired here yet (Phase B), so it can never misfire a game
# action; the 2D renderer stays the shippable default. Presents the interface FarmView
# expects (connect_to_farm / node_clicked / chain_swiped / teardown /
# selected_plot_positions / _on_plot_selection_changed) so it drops into
# GameRoot._mount_quantum_visualization behind the flag. Defensive throughout: any
# missing farm/viz_cache API fails to an empty field, never a crash.

signal quantum_node_selected(node)
signal biome_selected(biome_name: String)
signal node_clicked(grid_pos: Vector2i, button_index: int)   # declared; not emitted yet (Phase B)
signal chain_swiped(positions: Array)                        # declared; not emitted yet (Phase B)

const BVT = preload("res://Core/Visualization/BiomeVisualTheme.gd")
const VC = preload("res://Core/Visualization/VisualizationConstants.gd")

const CYAN := Color(0.42, 0.95, 0.88)
const R := 0.34                     # orb radius
const SHELL := 2.35                 # layout shell radius

var selected_plot_positions: Dictionary = {}
var farm_ref = null
var _sv: SubViewport
var _world: Node3D
var _pivot: Node3D
var _cam: Camera3D
var _bubbles: Array = []            # {reg, mesh, ring, sprite, dot, mat, rmat, pos}
var _dragging := false
var _last_biome := ""
var _reg_tex: Dictionary = {}       # emoji -> Texture2D cache
var _emoji_reg: Dictionary = {}
# current biome theme colours
var _glow := Color(0.96, 0.80, 0.36)
var _orb_base := Color(0.14, 0.11, 0.05)
var _accent := Color(0.96, 0.80, 0.36)


func _ready() -> void:
	stretch = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sv = SubViewport.new()
	_sv.own_world_3d = true
	_sv.transparent_bg = false
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv.msaa_3d = Viewport.MSAA_4X
	add_child(_sv)

	_world = Node3D.new()
	_sv.add_child(_world)
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 0, 7.3)
	_cam.fov = 54.0
	_world.add_child(_cam)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.028, 0.032, 0.062)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.52, 0.54, 0.70)
	env.ambient_light_energy = 0.5
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_strength = 1.1
	env.glow_bloom = 0.28
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.82
	we.environment = env
	_world.add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-44, -32, 0)
	key.light_energy = 0.55
	_world.add_child(key)

	_pivot = Node3D.new()
	_pivot.position = Vector3(0, -0.45, 0)   # sit the field below the top HUD chrome
	_world.add_child(_pivot)
	_load_emoji_registry()


# ------------------------------------------------- interface (FarmView contract)
func connect_to_farm(farm: Node) -> void:
	farm_ref = farm


func teardown() -> void:
	_clear_bubbles()
	farm_ref = null


func _on_plot_selection_changed(_selected) -> void:
	pass   # Phase B


# ----------------------------------------------------------- farm/biome access
func _farm_grid():
	if farm_ref == null or not is_instance_valid(farm_ref):
		return null
	return farm_ref.grid if ("grid" in farm_ref) else null


func _get_active_biome():
	# Authority: ActiveBiomeManager owns the active biome NAME; Farm.grid (a FarmGrid)
	# maps name -> biome object with the live viz_cache.
	var grid = _farm_grid()
	if grid == null:
		return null
	var abm = get_node_or_null("/root/ActiveBiomeManager")
	if abm != null and abm.has_method("get_active_biome") and grid.has_method("get_biome"):
		var b = grid.get_biome(abm.get_active_biome())
		if _biome_ok(b):
			return b
	if grid.has_method("get_all_biomes"):
		for bb in grid.get_all_biomes().values():
			if _biome_ok(bb):
				return bb
	return null


func _biome_ok(b) -> bool:
	return b != null and is_instance_valid(b) and ("viz_cache" in b) and b.viz_cache != null \
		and b.viz_cache.has_metadata() and b.viz_cache.get_num_qubits() > 0


# ------------------------------------------------------------------- rendering
func _load_emoji_registry() -> void:
	var f := FileAccess.open("res://Assets/emoji_registry.json", FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	for grp in ["twemoji", "custom"]:
		if d.has(grp) and typeof(d[grp]) == TYPE_DICTIONARY:
			for k in d[grp]:
				_emoji_reg[k] = d[grp][k]


func _emoji_tex(e: String) -> Texture2D:
	if e == "":
		return null
	if _reg_tex.has(e):
		return _reg_tex[e]
	var tex: Texture2D = null
	for cand in [e, e + "️", e.replace("️", "")]:
		if _emoji_reg.has(cand):
			var p: String = _emoji_reg[cand]
			if ResourceLoader.exists(p):
				tex = load(p)
				break
	_reg_tex[e] = tex
	return tex


func _apply_theme(biome_name: String) -> void:
	# Orb glows in the biome's theme hue; the ripeness ring stays the global gold accent.
	var theme: Dictionary = BVT.get_theme(biome_name)
	var hue: float = float(theme.get("base", Color(0.1, 0.1, 0.1)).h)
	_glow = Color.from_hsv(hue, 0.72, 1.0)
	_orb_base = Color.from_hsv(hue, 0.55, 0.15)
	_accent = theme.get("accent", Color(0.96, 0.80, 0.36))


func _layout_pos(i: int, n: int) -> Vector3:
	if n <= 1:
		return Vector3.ZERO
	# fibonacci sphere shell; scale gently with count so orbs never crowd
	var scale := SHELL * (0.66 + 0.035 * float(min(n, 12)))
	var y := 1.0 - (float(i) / float(n - 1)) * 2.0
	var rr := sqrt(max(0.0, 1.0 - y * y))
	var phi := float(i) * PI * (3.0 - sqrt(5.0))
	# compress the vertical spread so the top orbs clear the HUD chrome
	return Vector3(cos(phi) * rr * scale, y * scale * 0.8, sin(phi) * rr * scale)


func _rebuild(biome) -> void:
	_clear_bubbles()
	var vc = biome.viz_cache
	var n: int = vc.get_num_qubits()
	for i in range(n):
		var pos := _layout_pos(i, n)
		var axis = vc.get_axis(i)
		var emoji := str(axis.get("north", "")) if typeof(axis) == TYPE_DICTIONARY else ""
		_spawn(i, pos, emoji)


func _spawn(reg: int, pos: Vector3, emoji: String) -> void:
	# emissive orb, glowing in the biome hue
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = R; sm.height = R * 2.0
	sm.radial_segments = 32; sm.rings = 18
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _orb_base
	mat.emission_enabled = true
	mat.emission = _glow
	mat.emission_energy_multiplier = 1.3
	mat.metallic = 0.15; mat.roughness = 0.38
	mat.rim_enabled = true; mat.rim = 0.75; mat.rim_tint = 0.3
	mi.material_override = mat
	mi.position = pos
	_pivot.add_child(mi)

	# golden ripeness ring (global gold — value/ripeness reads the same in every biome)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = R + 0.075; tm.outer_radius = R + 0.135
	tm.rings = 40; tm.ring_segments = 12
	ring.mesh = tm
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.emission_enabled = true; rmat.emission = _accent; rmat.emission_energy_multiplier = 1.6
	rmat.albedo_color = Color(_accent.r, _accent.g, _accent.b, 0.85)
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = rmat
	ring.position = pos
	ring.rotation_degrees = Vector3(76, 0, 0)
	_pivot.add_child(ring)

	# billboarded real-emoji sprite
	var sp: Sprite3D = null
	var tex := _emoji_tex(emoji)
	if tex != null:
		sp = Sprite3D.new()
		sp.texture = tex
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.shaded = false
		sp.no_depth_test = true
		sp.pixel_size = 0.56 / float(max(8, tex.get_width()))
		sp.position = pos
		_pivot.add_child(sp)

	# honest Bloch-vector dot
	var dot := MeshInstance3D.new()
	var dm := SphereMesh.new(); dm.radius = 0.052; dm.height = 0.104
	dot.mesh = dm
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.emission_enabled = true; dmat.emission = CYAN; dmat.emission_energy_multiplier = 3.2
	dmat.albedo_color = CYAN
	dot.material_override = dmat
	_pivot.add_child(dot)

	_bubbles.append({"reg": reg, "mesh": mi, "ring": ring, "sprite": sp, "dot": dot,
		"mat": mat, "rmat": rmat, "pos": pos})


func _clear_bubbles() -> void:
	for b in _bubbles:
		for k in ["mesh", "ring", "sprite", "dot"]:
			if b.get(k) != null and is_instance_valid(b[k]):
				b[k].queue_free()
	_bubbles.clear()


func _process(dt: float) -> void:
	# Force sizing: if anchor resolution left us collapsed, drive size from the window
	# so the SubViewport has a real render target.
	var win := get_window()
	if win != null and (size.x < 4.0 or size.y < 4.0):
		size = Vector2(win.size)

	var biome = _get_active_biome()
	if biome == null:
		return
	var bname := ""
	if biome.has_method("get_biome_type"):
		bname = str(biome.get_biome_type())
	if bname != _last_biome or _bubbles.is_empty():
		_last_biome = bname
		_apply_theme(bname)
		_rebuild(biome)
		if OS.has_environment("SW_FIELD_3D_DEBUG"):
			print("[QF3D] rebuilt biome=", bname, " registers=", _bubbles.size())

	if not _dragging:
		_pivot.rotate_object_local(Vector3.UP, dt * 0.11)

	var vc = biome.viz_cache
	var t := Time.get_ticks_msec() * 0.001
	for b in _bubbles:
		var snap = vc.get_snapshot(b.reg)
		if typeof(snap) != TYPE_DICTIONARY:
			continue
		var p0 := float(snap.get("p0", 0.5))
		var p1 := float(snap.get("p1", 0.5))
		var br := float(snap.get("r", 0.5))
		# honest Bloch vector: the dot sits at the real (x,y,z), out to length r.
		var dir := Vector3(float(snap.get("x", 0.0)), float(snap.get("z", 0.0)), float(snap.get("y", 0.0)))
		if dir.length() < 0.001:
			dir = Vector3.UP
		b.dot.position = b.pos + dir.normalized() * (R + 0.07 + 0.32 * clampf(br, 0.0, 1.0))
		# orb emission tracks coherence/purity
		b.mat.emission_energy_multiplier = 0.85 + 2.2 * clampf(br, 0.0, 1.0)
		# honest ripeness: gold ring brightens + fattens as the register ripens
		var rip := clampf(VC.ripeness(p0, p1), 0.0, 1.0)
		b.rmat.emission_energy_multiplier = 0.5 + 3.0 * rip
		var ring_s: float = 0.9 + 0.35 * rip + 0.04 * sin(t * 2.3 + float(b.reg) * 1.1)
		b.ring.scale = Vector3.ONE * ring_s
		b.ring.rotate_object_local(Vector3.UP, dt * (0.3 + 0.8 * rip))
		# idle breathe
		var s: float = 1.0 + 0.045 * sin(t * 1.5 + b.pos.x * 1.7)
		b.mesh.scale = Vector3.ONE * s


func _gui_input(ev: InputEvent) -> void:
	# view-only orbit; NO mechanics dispatch (Phase B wires picking -> node_clicked)
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_dragging = ev.pressed
	elif ev is InputEventMouseMotion and _dragging:
		_pivot.rotate_object_local(Vector3.UP, ev.relative.x * 0.008)
		_pivot.rotate_object_local(Vector3.RIGHT, ev.relative.y * 0.008)
