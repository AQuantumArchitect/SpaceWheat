class_name QuantumField3D
extends SubViewportContainer
# A 3D cognifold renderer for the live farm, gated behind the 3D toggle. It reads the
# SAME `biome.viz_cache` the 2D renderer reads — per-register Bloch vectors
# (x,y,z,r,p0,p1) — and draws each register in a clean, Mini-Metro style (flat + vibrant,
# NO bloom/glow) where the EMOJI is the star:
#   • a big, clean billboarded real-emoji Sprite3D (the register's north-pole axis icon)
#     on a DARK subtle backing ball — the colour is a ring, not a filled glow;
#   • a thin biome-colour identity ring (BiomeVisualTheme, "one colour = one meaning"),
#     brighter when coherent, duller when decohered;
#   • a thin gold RIPENESS ring (gold = the global ripeness/value colour in every biome)
#     that grows with the honest VisualizationConstants.ripeness(p0,p1);
#   • the honest Bloch-vector dot at the register's real (x,y,z), length = r.
# The field drifts slowly (pausing on mouse activity) so it never reads as a dead frame.
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
const PRR = preload("res://Core/GameMechanics/PlotRegisterResolver.gd")

const CYAN := Color(0.42, 0.95, 0.88)
const R := 0.34                     # orb radius
const SHELL := 2.35                 # layout shell radius

var selected_plot_positions: Dictionary = {}
var farm_ref = null
var _sv: SubViewport
var _world: Node3D
var _pivot: Node3D
var _cam: Camera3D
var _bubbles: Array = []            # {reg, mesh, ring, sprite, dot, mat, rmat, pos, grid_pos}
var _portals: Array = []            # {mesh, sprite, name, pos} — other biomes, click to dive
var _edges: MeshInstance3D = null   # live MI correlation lines between orbs
var _vectors: MeshInstance3D = null # live Bloch state-vector lines (centre → state point)
var _dragging := false
var _press_pos := Vector2.ZERO
var _press_moved := false
var _orbit_hold_until_ms := 0     # pause idle drift briefly after any mouse activity
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
	_cam.position = Vector3(0, 1.5, 7.1)
	_cam.fov = 54.0
	_world.add_child(_cam)
	_cam.look_at(Vector3(0, -0.45, 0), Vector3.UP)   # slight top-down so Bloch spheres read as spheres

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	# Mini-Metro clarity: a clean dark canvas, bright even light so flat colours read bold,
	# and NO bloom/glow haze (vibrant colour does the work, not glow).
	env.background_color = Color(0.10, 0.11, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.80, 0.82, 0.92)
	env.ambient_light_energy = 0.85
	env.glow_enabled = false
	we.environment = env
	_world.add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-44, -32, 0)
	key.light_energy = 0.55
	_world.add_child(key)

	_pivot = Node3D.new()
	_pivot.position = Vector3(0, -0.45, 0)   # sit the field below the top HUD chrome
	_world.add_child(_pivot)

	# manifold edges: live mutual-information correlation lines, rebuilt each frame
	_edges = MeshInstance3D.new()
	_edges.mesh = ImmediateMesh.new()
	var emat := StandardMaterial3D.new()
	emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	emat.vertex_color_use_as_albedo = true
	emat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_edges.material_override = emat
	_pivot.add_child(_edges)

	# live Bloch state-vector lines + fading trails (centre → the evolving state point),
	# rebuilt every frame so the picture IS the physics simulation, not a decorative spin
	_vectors = MeshInstance3D.new()
	_vectors.mesh = ImmediateMesh.new()
	var vmat := StandardMaterial3D.new()
	vmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vmat.vertex_color_use_as_albedo = true
	vmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_vectors.material_override = vmat
	_pivot.add_child(_vectors)

	_load_emoji_registry()


# ------------------------------------------------- interface (FarmView contract)
func connect_to_farm(farm: Node) -> void:
	farm_ref = farm


func teardown() -> void:
	_clear_bubbles()
	_clear_portals()
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
	# _glow: vibrant self-light kept bold on the shaded side; _orb_base: the flat albedo.
	_glow = Color.from_hsv(hue, 0.85, 0.95)
	_orb_base = Color.from_hsv(hue, 0.82, 0.74)
	_accent = theme.get("accent", Color(0.98, 0.82, 0.30))


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
	var reg_gpos := _build_register_gridpos_map(biome)
	for i in range(n):
		var pos := _layout_pos(i, n)
		var axis = vc.get_axis(i)
		var north_e := str(axis.get("north", "")) if typeof(axis) == TYPE_DICTIONARY else ""
		var south_e := str(axis.get("south", "")) if typeof(axis) == TYPE_DICTIONARY else ""
		_spawn(i, pos, north_e, south_e, reg_gpos.get(i, Vector2i(i, 0)))


## register index -> grid position, via the SAME slot->qubit authority the 2D renderer
## uses (get_plot_biome_assignments + PlotRegisterResolver). This is what lets a tap on
## an orb dispatch through handle_bubble_tap identically to a 2D bubble tap.
func _build_register_gridpos_map(biome) -> Dictionary:
	var out := {}
	var grid = _farm_grid()
	if grid == null or not grid.has_method("get_plot_biome_assignments"):
		return out
	var bname := ""
	if biome.has_method("get_biome_type"):
		bname = str(biome.get_biome_type())
	var assignments: Dictionary = grid.get_plot_biome_assignments()
	for gpos in assignments.keys():
		if str(assignments[gpos]) != bname:
			continue
		var reg := int(PRR.resolve(farm_ref, gpos).get("register_id", int(gpos.x)))
		if reg >= 0 and not out.has(reg):
			out[reg] = gpos
	return out


func _spawn(reg: int, pos: Vector3, north_emoji: String, south_emoji: String, grid_pos: Vector2i) -> void:
	# ── BLOCH SPHERE — every element maps to a physical quantity ──────────────────
	# translucent ball = this register's STATE SPACE (the Bloch ball); tint = its biome.
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = R; sm.height = R * 2.0
	sm.radial_segments = 32; sm.rings = 20
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED   # see the far wall + the vector inside
	mat.albedo_color = Color(_glow.r, _glow.g, _glow.b, 0.12)
	mi.material_override = mat
	mi.position = pos
	_pivot.add_child(mi)

	# equator = the equal-superposition circle (the x–y phase plane), biome hue
	var eq := MeshInstance3D.new()
	var etm := TorusMesh.new(); etm.inner_radius = R - 0.004; etm.outer_radius = R + 0.004
	etm.rings = 64; etm.ring_segments = 8
	eq.mesh = etm
	var emat := StandardMaterial3D.new(); emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	emat.albedo_color = _glow
	eq.material_override = emat
	eq.position = pos
	_pivot.add_child(eq)

	# z-axis pole-to-pole = the measurement axis (faint)
	var axisline := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(0.009, R * 2.0, 0.009)
	axisline.mesh = bm
	var lmat := StandardMaterial3D.new(); lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lmat.albedo_color = Color(0.62, 0.65, 0.74, 0.4)
	axisline.material_override = lmat
	axisline.position = pos
	_pivot.add_child(axisline)

	# poles: |0⟩ = north emoji (top), |1⟩ = south emoji (bottom) — the basis observables
	var np := _pole_sprite(north_emoji, pos + Vector3(0, R + 0.12, 0), 0.5)
	var spr := _pole_sprite(south_emoji, pos + Vector3(0, -(R + 0.12), 0), 0.38)

	# THE STATE: a bright point at the real (x,y,z) inside the ball (positioned live in
	# _process); a line + fading trail are drawn from the centre by _update_vectors.
	# Its distance from centre = purity/coherence r; its motion IS the physics evolving.
	var dot := MeshInstance3D.new()
	var dm := SphereMesh.new(); dm.radius = 0.05; dm.height = 0.1
	dot.mesh = dm
	var dmat := StandardMaterial3D.new(); dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.albedo_color = Color(1, 1, 1)
	dot.material_override = dmat
	dot.position = pos
	_pivot.add_child(dot)

	# gold ripeness ring = value/ripeness (E = −kT·log p), horizontal, outside the ball
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = R + 0.12; tm.outer_radius = R + 0.155
	tm.rings = 60; tm.ring_segments = 12
	ring.mesh = tm
	var rmat := StandardMaterial3D.new(); rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = _accent
	ring.material_override = rmat
	ring.position = pos
	_pivot.add_child(ring)

	_bubbles.append({"reg": reg, "mesh": mi, "eq": eq, "axisline": axisline, "np": np,
		"spr": spr, "dot": dot, "ring": ring, "pos": pos, "grid_pos": grid_pos, "trail": []})


func _pole_sprite(e: String, at: Vector3, sz: float) -> Sprite3D:
	var tex := _emoji_tex(e)
	if tex == null:
		return null
	var sp := Sprite3D.new()
	sp.texture = tex
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.shaded = false
	sp.no_depth_test = true
	sp.pixel_size = sz / float(max(8, tex.get_width()))
	sp.position = at
	_pivot.add_child(sp)
	return sp


func _clear_bubbles() -> void:
	for b in _bubbles:
		for k in ["mesh", "eq", "axisline", "np", "spr", "dot", "ring"]:
			if b.get(k) != null and is_instance_valid(b[k]):
				b[k].queue_free()
	_bubbles.clear()


# ------------------------------------------------------- fractal biome portals
## Every OTHER loaded biome becomes a small themed portal orb ringed around the field.
## Clicking one dives into it (set_active_biome) — the fractal navigation from the demo.
func _rebuild_portals(active_name: String) -> void:
	_clear_portals()
	var grid = _farm_grid()
	if grid == null or not grid.has_method("get_all_biomes"):
		return
	var others := []
	for bb in grid.get_all_biomes().values():
		if not _biome_ok(bb):
			continue
		var nm := str(bb.get_biome_type()) if bb.has_method("get_biome_type") else ""
		if nm == "" or nm == active_name:
			continue
		others.append(bb)
	var n := others.size()
	for i in range(n):
		# a fixed vertical "travel rail" down the empty left side — never occluded by the
		# field or its bloom, always clickable to dive into that biome
		var t := (float(i) + 0.5) / float(max(1, n))   # 0..1, centered
		var pos := Vector3(-4.9, 0.8 - t * 3.6, 0.0)
		_spawn_portal(others[i], pos)


func _spawn_portal(biome, pos: Vector3) -> void:
	var nm := str(biome.get_biome_type()) if biome.has_method("get_biome_type") else ""
	var theme: Dictionary = BVT.get_theme(nm)
	var hue: float = float(theme.get("base", Color(0.1, 0.1, 0.1)).h)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.19; sm.height = 0.38
	sm.radial_segments = 20; sm.rings = 12
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.from_hsv(hue, 0.5, 0.11)   # dark backing; colour is the ring
	mat.metallic = 0.0; mat.roughness = 0.75
	mat.rim_enabled = false
	mi.material_override = mat
	mi.position = pos
	_world.add_child(mi)   # on _world, NOT _pivot: portals stay a fixed nav ring, don't orbit

	# thin biome-colour identity ring (matches the field orbs' look)
	var pring := MeshInstance3D.new()
	var ptm := TorusMesh.new(); ptm.inner_radius = 0.205; ptm.outer_radius = 0.235
	ptm.rings = 44; ptm.ring_segments = 14
	pring.mesh = ptm
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Color.from_hsv(hue, 0.8, 0.85)
	pring.material_override = pmat
	pring.position = pos
	pring.rotation_degrees = Vector3(90, 0, 0)
	_world.add_child(pring)

	var emoji := ""
	if ("viz_cache" in biome) and biome.viz_cache != null and biome.viz_cache.get_num_qubits() > 0:
		var axis = biome.viz_cache.get_axis(0)
		emoji = str(axis.get("north", "")) if typeof(axis) == TYPE_DICTIONARY else ""
	var sp: Sprite3D = null
	var tex := _emoji_tex(emoji)
	if tex != null:
		sp = Sprite3D.new()
		sp.texture = tex
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.shaded = false
		sp.no_depth_test = true
		sp.pixel_size = 0.46 / float(max(8, tex.get_width()))   # bigger, clean icon
		sp.position = pos
		_world.add_child(sp)

	_portals.append({"mesh": mi, "hue_ring": pring, "sprite": sp, "name": nm, "pos": pos})


func _clear_portals() -> void:
	for p in _portals:
		for k in ["mesh", "hue_ring", "sprite"]:
			if p.get(k) != null and is_instance_valid(p[k]):
				p[k].queue_free()
	_portals.clear()


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
		_rebuild_portals(bname)
		if OS.has_environment("SW_FIELD_3D_DEBUG"):
			print("[QF3D] rebuilt biome=", bname, " registers=", _bubbles.size(), " portals=", _portals.size())

	# Gentle continuous drift so the 3D never freezes; a brief hold after a mouse action so a
	# click doesn't fight a moving target. The PRIMARY motion is the physics (state points below).
	if not _dragging and Time.get_ticks_msec() > _orbit_hold_until_ms:
		_pivot.rotate_object_local(Vector3.UP, dt * 0.08)

	var vc = biome.viz_cache
	for b in _bubbles:
		var snap = vc.get_snapshot(b.reg)
		if typeof(snap) != TYPE_DICTIONARY:
			continue
		var p0 := float(snap.get("p0", 0.5))
		var p1 := float(snap.get("p1", 0.5))
		# THE honest state point, from the LIVE spherical Bloch coords: theta = polar angle
		# (0 → |0⟩ north pole, π → |1⟩ south), phi = phase, r_bloch = purity (1 = pure state
		# on the surface). Its motion IS the simulation evolving. Bloch z (population axis) →
		# world Y (up), so the poles line up with the |0⟩/|1⟩ emoji.
		var rb := float(snap.get("r_bloch", 1.0))
		var th := float(snap.get("theta", 0.0))
		var ph := float(snap.get("phi", 0.0))
		var st := sin(th)
		var bloch := Vector3(st * cos(ph), cos(th), st * sin(ph)) * (rb * R)
		b.dot.position = b.pos + bloch
		if b.dot.scale.x > 1.01:   # decay the pick-flash
			b.dot.scale = b.dot.scale.lerp(Vector3.ONE, min(1.0, dt * 6.0))
		# record the trajectory so the state's precession leaves a visible fading arc
		var tr: Array = b.trail
		tr.append(b.dot.position)
		if tr.size() > 110:
			tr.pop_front()
		# ripeness (value) grows the gold ring
		var rip := clampf(VC.ripeness(p0, p1), 0.0, 1.0)
		b.ring.scale = Vector3.ONE * (0.92 + 0.35 * rip)
	_update_edges(vc)
	_update_vectors()


## Draw each register's live state vector (centre → the real Bloch point) plus a fading
## trail of its recent trajectory — so the moving picture IS the physics simulation.
func _update_vectors() -> void:
	if _vectors == null or not (_vectors.mesh is ImmediateMesh):
		return
	var vm: ImmediateMesh = _vectors.mesh
	vm.clear_surfaces()
	if _bubbles.is_empty():
		return
	vm.surface_begin(Mesh.PRIMITIVE_LINES)
	for b in _bubbles:
		if not is_instance_valid(b.dot):
			continue
		# state vector: faint at the centre, bright cyan at the tip
		vm.surface_set_color(Color(0.55, 0.6, 0.7, 0.35))
		vm.surface_add_vertex(b.pos)
		vm.surface_set_color(CYAN)
		vm.surface_add_vertex(b.dot.position)
		# trajectory trail: recent state points, fading with age
		var tr: Array = b.trail
		for k in range(1, tr.size()):
			var a := float(k) / float(tr.size())
			var col := Color(CYAN.r, CYAN.g, CYAN.b, a * 0.55)
			vm.surface_set_color(col)
			vm.surface_add_vertex(tr[k - 1])
			vm.surface_set_color(col)
			vm.surface_add_vertex(tr[k])
	vm.surface_end()


## Rebuild the manifold edges from live mutual information: a line between two orbs whose
## registers are correlated, brightness ∝ MI. Product (uncorrelated) states draw nothing.
func _update_edges(vc) -> void:
	if _edges == null or not (_edges.mesh is ImmediateMesh):
		return
	var em: ImmediateMesh = _edges.mesh
	em.clear_surfaces()
	if not vc.has_method("get_mutual_information") or _bubbles.size() < 2:
		return
	var segs := []
	for i in range(_bubbles.size()):
		for j in range(i + 1, _bubbles.size()):
			var mi := float(vc.get_mutual_information(_bubbles[i].reg, _bubbles[j].reg))
			if mi > 0.02:
				segs.append([i, j, mi])
	if segs.is_empty():
		return
	em.surface_begin(Mesh.PRIMITIVE_LINES)
	for s in segs:
		# crisp, clean correlation line (Mini-Metro line, not a glow) — light steel-blue,
		# more opaque the stronger the correlation
		var a := clampf(float(s[2]) * 3.0, 0.3, 0.95)
		var col := Color(0.62, 0.82, 0.95, a)
		em.surface_set_color(col)
		em.surface_add_vertex(_bubbles[s[0]].pos)
		em.surface_set_color(col)
		em.surface_add_vertex(_bubbles[s[1]].pos)
	em.surface_end()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouse:
		_orbit_hold_until_ms = Time.get_ticks_msec() + 1500
	# A short press that doesn't drag = a TAP → pick an orb → node_clicked(grid_pos)
	# (FarmView routes it to handle_bubble_tap, exactly like a 2D bubble tap). A press
	# that moves past the threshold becomes an ORBIT drag and never dispatches an action.
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_press_pos = ev.position
			_press_moved = false
			_dragging = false
		else:
			if not _press_moved:
				_try_pick(ev.position, ev.button_index)
			_dragging = false
	elif ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if not _press_moved and ev.position.distance_to(_press_pos) > 7.0:
			_press_moved = true
			_dragging = true
		if _dragging:
			_pivot.rotate_object_local(Vector3.UP, ev.relative.x * 0.008)
			_pivot.rotate_object_local(Vector3.RIGHT, ev.relative.y * 0.008)


func _try_pick(screen_pos: Vector2, button: int) -> void:
	if _cam == null:
		return
	# Portals first: a click on another biome's orb dives into it (fractal navigation).
	var bestp = null
	var bestp_d := 60.0
	for p in _portals:
		if not is_instance_valid(p.mesh):
			continue
		var wpp: Vector3 = p.mesh.global_position
		if _cam.is_position_behind(wpp):
			continue
		var dp := _cam.unproject_position(wpp).distance_to(screen_pos)
		if dp < bestp_d:
			bestp_d = dp
			bestp = p
	if bestp != null:
		var abm = get_node_or_null("/root/ActiveBiomeManager")
		if abm != null and abm.has_method("set_active_biome"):
			abm.set_active_biome(str(bestp.name))
		biome_selected.emit(str(bestp.name))
		return
	var best = null
	var best_d := 72.0   # px hit radius
	for b in _bubbles:
		if not is_instance_valid(b.mesh):
			continue
		var wp: Vector3 = b.mesh.global_position
		if _cam.is_position_behind(wp):
			continue
		var d := _cam.unproject_position(wp).distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = b
	if best != null and best.has("grid_pos"):
		# brief pick flash so the tap reads even before the game's own feedback lands
		if best.get("dot") != null and is_instance_valid(best.dot):
			best.dot.scale = Vector3.ONE * 2.2
		node_clicked.emit(best.grid_pos, button)


## Screen position of a register's orb — FloatingRewardLayer uses this to anchor world-space
## reward fliers/bursts to the 3D orbs. Returns (-1,-1) when the register has no visible orb
## (the reward layer then falls back to a centred spawn).
func get_register_screen_position(_biome_name: String, register_id: int) -> Vector2:
	if _cam != null:
		for b in _bubbles:
			if int(b.reg) == register_id and is_instance_valid(b.mesh):
				if not _cam.is_position_behind(b.mesh.global_position):
					return _cam.unproject_position(b.mesh.global_position)
	return Vector2(-1, -1)


## dev-only: simulate a real tap on register `idx` by unprojecting its orb to screen and
## running the actual pick geometry (exercises unproject → nearest → node_clicked → the
## FarmView → handle_bubble_tap chain). Returns the grid_pos tapped, or (-9,-9) on failure.
func dev_tap_register(idx: int) -> Vector2i:
	if idx < 0 or idx >= _bubbles.size():
		return Vector2i(-9, -9)
	var b = _bubbles[idx]
	if not is_instance_valid(b.mesh) or _cam == null:
		return Vector2i(-9, -9)
	_try_pick(_cam.unproject_position(b.mesh.global_position), MOUSE_BUTTON_LEFT)
	return b.grid_pos


## dev-only: simulate a click on portal `idx` (dives into that biome). Returns its name.
func dev_tap_portal(idx: int) -> String:
	if idx < 0 or idx >= _portals.size():
		return "<none>"
	var p = _portals[idx]
	if not is_instance_valid(p.mesh) or _cam == null:
		return "<none>"
	_try_pick(_cam.unproject_position(p.mesh.global_position), MOUSE_BUTTON_LEFT)
	return str(p.name)
