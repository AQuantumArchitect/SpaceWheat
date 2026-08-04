class_name QuantumField3D
extends SubViewportContainer
# A 3D cognifold renderer for the live farm — the default renderer since the sprint
# flip. It reads the SAME `biome.viz_cache` the 2D renderer reads — per-register Bloch
# coords (theta/phi/r, p0/p1) — and draws each register as a legible BLOCH BALL:
#   • a translucent biome-tinted state-space ball with an equator ring (the x-y phase
#     plane) and a faint pole-to-pole measurement axis;
#   • both basis emojis as billboarded Sprite3Ds — |0⟩ north above, |1⟩ south below;
#   • the honest state DOT at the live (theta,phi,r) inside the ball — its motion IS
#     the physics — plus (under the B microscope) its vector and fading trail;
#   • a thin gold RIPENESS ring (gold = the global ripeness/value colour in every biome)
#     that grows with the honest VisualizationConstants.ripeness(p0,p1);
#   • a bright selection torus on the focused orb (set_focused_plot).
# The field drifts slowly (pausing on mouse activity or E-pause) so it never reads as a
# dead frame. Mini-Metro clarity: flat vibrant colour, no bloom/glow.
#
# Mechanics input is wired through the SAME seam the 2D renderer uses: a TAP on an orb
# emits node_clicked(grid_pos) (FarmView → handle_bubble_tap), and a SWIPE across 2+ orbs
# emits chain_swiped([grid_pos…]) (FarmView → apply_chain_gate → bell/cluster gate build).
# A left-drag that begins on EMPTY space orbits the camera instead — that is how tap, chain,
# and orbit are disambiguated from one pointer. Presents the interface FarmView expects
# (connect_to_farm / node_clicked / chain_swiped / teardown / selected_plot_positions /
# _on_plot_selection_changed) so it drops into GameRoot._mount_quantum_visualization behind
# the flag. Defensive throughout: any missing farm/viz_cache API fails to an empty field,
# never a crash.
#
# Two distinct navigation layers share this field, both docs/architecture/fractal_atlas.md
# calls "fractal" but which are genuinely different mechanics:
#   • the sibling portal rail (_rebuild_portals): every OTHER already-loaded biome as a
#     themed orb on the fixed left rail — lateral, one level, calls ActiveBiomeManager
#     directly (a navigation concern, not an economy-gated mechanic);
#   • descend/ascend (_rebuild_fractal_portals): a small indigo satellite per register
#     (enter_icon — real recursive icon→world depth, FractalAtlas/FractalWorldService/
#     ProceduralIconBiome) and a single cyan ascend portal shown only when the active
#     biome is itself a materialized fractal child. Both call farm_ref.instrument directly,
#     the same precedent the sibling rail already set.
#
# Three line/glyph channels, each a genuinely different physical quantity, never overlapping
# (parallel-track offset on the edges; local, register-attached glyphs for the arrows):
#   • MI edges (_recompute_mi_segs) — live measured correlation, symmetric, no direction.
#   • metro lines (_recompute_metro_segs) — the PERMANENT Hamiltonian coupling (icons.json),
#     static per biome, same authority + math as the 2D QuantumEdgeRenderer's metro lines.
#   • Lindblad flow arrows (_rebuild_lindblad_glyphs) — directional pump/drain cones local to
#     a register's own poles (BasePlot.lindblad_pump_active/lindblad_drain_active), not an
#     edge between two registers.

signal quantum_node_selected(node)
signal biome_selected(biome_name: String)
signal node_clicked(grid_pos: Vector2i, button_index: int)   # tap on an orb → handle_bubble_tap
signal chain_swiped(positions: Array)                        # swipe across 2+ orbs → apply_chain_gate

const BVT = preload("res://Core/Visualization/BiomeVisualTheme.gd")
const VC = preload("res://Core/Visualization/VisualizationConstants.gd")
const PRR = preload("res://Core/GameMechanics/PlotRegisterResolver.gd")

const CYAN := Color(0.42, 0.95, 0.88)
const R := 0.34                     # orb radius
const SHELL := 2.35                 # layout shell radius
const MI_STRIDE := 6                # recompute mutual-information correlations every N frames
const METRO_STRIDE := 90            # H-coupling is static per biome ("H only moves on incorporation")
const LINDBLAD_STRIDE := 24         # pump/drain flags are gameplay-driven, refresh a bit livelier
const LINE_TRACK_OFFSET := 0.055    # perpendicular push so MI/H tracks never literally overlap
const PUMP_COLOR := Color(0.45, 0.85, 0.55)   # energy flowing IN at the north pole
const DRAIN_COLOR := Color(0.95, 0.40, 0.32)  # population flowing OUT at the south pole
const FORCE_STRIDE := MI_STRIDE     # how often live MI/H attraction weights are recomputed
const DRIFT_MAX := R * 1.6          # cap on how far an orb may wander from its Fibonacci anchor —
                                     # legibility over chaos: the layout must always stay readable
const DRIFT_SMOOTH := 2.2           # exponential-smoothing rate toward the target (frame-rate independent)
const REPEL_MARGIN := R * 2.3       # minimum comfortable separation between two live orb positions

var selected_plot_positions: Dictionary = {}
var farm_ref = null
var _sv: SubViewport
var _world: Node3D
var _pivot: Node3D
var _cam: Camera3D
var _bubbles: Array = []            # {reg, mesh, ring, sprite, dot, mat, rmat, pos, grid_pos}
var _portals: Array = []            # {mesh, sprite, name, pos} — other biomes, click to dive
const DESCEND_HUE_COLOR := Color(0.55, 0.35, 0.95)  # fixed indigo — "go deeper", never a biome hue
var _descend_portals: Array = []    # {mesh, ring, sprite, biome_name, register_id} — per register, click to enter_icon
var _ascend_portal = null           # {mesh, ring, sprite} or null — only present inside a fractal child world
# Focused-plot selection (QII.selection_changed → FarmView → set_focused_plot). plot_idx ≡
# register_id (the plot-register invariant), so the ring finds its orb by register. A slot
# with no register keeps the ring hidden — the honest refusal toast is the cue there.
var _sel_plot_idx := -1
var _sel_biome := ""
var _sel_ring: MeshInstance3D = null
# B-microscope contract (mirrors QuantumForceGraph.on_overlay_changed): the default view
# is the clean metro map — deep-physics webs (live MI edges, state vectors + trails) draw
# only while the B biome microscope is open. Wired in RuntimeMount.
var show_inspection_layers: bool = false
# E-pause contract (mirrors QuantumForceGraph.set_time_flow_scale): 0 freezes the
# renderer's own idle motion so "motion means time is passing" stays honest.
var _time_scale: float = 1.0
var _edges: MeshInstance3D = null   # live MI correlation lines between orbs
var _vectors: MeshInstance3D = null # live Bloch state-vector lines (centre → state point)
var _dragging := false
var _press_pos := Vector2.ZERO
var _press_moved := false
var _orbit_hold_until_ms := 0     # pause idle drift briefly after any mouse activity
var _chain_mode := false          # a left-drag that began on an orb builds a gate chain
var _chain: Array = []            # orbs gathered by the current chain-swipe (bell/cluster)
var _chain_mesh: MeshInstance3D = null  # live gold thread through the chained orbs
var _pointer_pos := Vector2.ZERO
var _mi_frame := 0                # MI stride counter (recompute correlations every MI_STRIDE)
var _mi_segs: Array = []          # cached correlation segments: [posA, posB, color]
var _mi_dirty := true             # force an MI recompute after a rebuild
var _force_frame := 0             # force-dynamics stride counter
var _attract_pairs: Array = []    # cached [bubble_i, bubble_j, weight 0..1] — live MI + static
                                   # H-coupling combined, drives the gentle drift toward correlated partners
var _metro_mesh: MeshInstance3D = null  # static H-coupling lines — the permanent transit map
var _metro_frame := 0
var _metro_segs: Array = []       # cached coupling segments: [posA, posB, color]
var _metro_dirty := true
var _lindblad_frame := 0
var _lindblad_glyphs: Array = []  # {shaft, head, register_id} — pump/drain flow cones, cleared on rebuild
var _last_biome := ""
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

	# (no DirectionalLight3D: every material in this renderer is UNSHADED by design —
	# the light rig that used to sit here was dead weight)

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

	# metro lines: static Hamiltonian-coupling edges — the biome's PERMANENT wiring
	# (icons.json), distinct from the live MI overlay above. Offset onto its own parallel
	# track (LINE_TRACK_OFFSET) so a coupled pair that's ALSO correlated never renders as
	# one overlapping line — see _perp_offset.
	_metro_mesh = MeshInstance3D.new()
	_metro_mesh.mesh = ImmediateMesh.new()
	var mmat := StandardMaterial3D.new()
	mmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mmat.vertex_color_use_as_albedo = true
	mmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_metro_mesh.material_override = mmat
	_pivot.add_child(_metro_mesh)

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

	# live chain-swipe thread: a gold line through the orbs the current drag has gathered
	# (2+ orbs on release builds a bell/cluster gate — the 3D equivalent of the 2D swipe).
	_chain_mesh = MeshInstance3D.new()
	_chain_mesh.mesh = ImmediateMesh.new()
	var cmat := StandardMaterial3D.new()
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cmat.vertex_color_use_as_albedo = true
	cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_chain_mesh.material_override = cmat
	_pivot.add_child(_chain_mesh)

	# THE selection ring: one bright horizontal torus that sits on whichever orb the
	# player's plot cursor focuses (keyboard G-; or tap). One shared node, moved between
	# orbs — the 3D replacement for the hidden 2D rack's cyan tile border.
	_sel_ring = MeshInstance3D.new()
	var stm := TorusMesh.new(); stm.inner_radius = R + 0.19; stm.outer_radius = R + 0.23
	stm.rings = 60; stm.ring_segments = 12
	_sel_ring.mesh = stm
	var selmat := StandardMaterial3D.new()
	selmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selmat.albedo_color = Color(0.92, 0.99, 1.0)
	_sel_ring.material_override = selmat
	_sel_ring.visible = false
	_pivot.add_child(_sel_ring)


# ------------------------------------------------- interface (FarmView contract)
func connect_to_farm(farm: Node) -> void:
	if farm_ref and farm_ref != farm:
		_disconnect_reveal_signals(farm_ref)
	farm_ref = farm
	_connect_reveal_signals(farm_ref)


func _connect_reveal_signals(farm: Node) -> void:
	if farm == null:
		return
	if farm.has_signal("plot_revealed") and not farm.plot_revealed.is_connected(_on_plot_revealed):
		farm.plot_revealed.connect(_on_plot_revealed)
	if farm.has_signal("terminal_released") and not farm.terminal_released.is_connected(_on_terminal_released):
		farm.terminal_released.connect(_on_terminal_released)


func _disconnect_reveal_signals(farm: Node) -> void:
	if farm == null:
		return
	if farm.has_signal("plot_revealed") and farm.plot_revealed.is_connected(_on_plot_revealed):
		farm.plot_revealed.disconnect(_on_plot_revealed)
	if farm.has_signal("terminal_released") and farm.terminal_released.is_connected(_on_terminal_released):
		farm.terminal_released.disconnect(_on_terminal_released)


## Cosmetic reveal state (mirrors QuantumForceGraph._is_plot_revealed). Fail OPEN
## (visible) when no farm is connected — a bare field without a farm must never
## render empty by accident.
func _is_plot_revealed(grid_pos: Vector2i) -> bool:
	if farm_ref and farm_ref.has_method("is_plot_revealed"):
		return farm_ref.is_plot_revealed(grid_pos)
	return true


func _on_plot_revealed(grid_pos: Vector2i) -> void:
	for b in _bubbles:
		if b.get("grid_pos") == grid_pos:
			_set_bubble_visible(b, true)
	_update_selection_visuals()


## HARVEST pops the bubble back to unexplored fog (mirrors
## QuantumForceGraph._on_terminal_released) — the register persists, only the
## cosmetic reveal state resets.
func _on_terminal_released(grid_pos: Vector2i, _terminal_id: String, _credits_earned: int) -> void:
	for b in _bubbles:
		if b.get("grid_pos") == grid_pos:
			_set_bubble_visible(b, false)
	_update_selection_visuals()


func _set_bubble_visible(b: Dictionary, vis: bool) -> void:
	for k in ["mesh", "eq", "axisline", "np", "spr", "dot", "ring"]:
		var node = b.get(k)
		if node != null and is_instance_valid(node):
			node.visible = vis


func teardown() -> void:
	_disconnect_reveal_signals(farm_ref)
	_clear_bubbles()
	_clear_portals()
	_clear_fractal_portals()
	farm_ref = null


## Multi-select (checkbox) channel — same signature as QuantumForceGraph's handler, fed by
## PlotGridDisplay.plot_selection_changed via FarmView. The rack still owns checkbox STATE;
## the field just mirrors it so batch verbs read against a visible set.
func _on_plot_selection_changed(grid_pos: Vector2i, is_selected: bool) -> void:
	if is_selected:
		selected_plot_positions[grid_pos] = true
	else:
		selected_plot_positions.erase(grid_pos)


## Focused-plot channel (the single cursor, keyboard G-; or tap) — fed by
## QII.selection_changed via FarmView. Drives the selection ring and which orb shows its
## descend satellite (selected-orb-only, owner default 2026-08-04: satellites on every orb
## both stole clicks from the orb's outer half and read as clutter).
func set_focused_plot(plot_idx: int, biome_name: String) -> void:
	_sel_plot_idx = plot_idx
	_sel_biome = biome_name
	_update_selection_visuals()


func _selected_bubble() -> Dictionary:
	if _sel_plot_idx < 0:
		return {}
	if _sel_biome != "" and _last_biome != "" and _sel_biome != _last_biome:
		return {}
	for b in _bubbles:
		if int(b.reg) == _sel_plot_idx:
			return b
	return {}


func _update_selection_visuals() -> void:
	var b := _selected_bubble()
	var has_orb: bool = (not b.is_empty()) and is_instance_valid(b.get("mesh")) and b.mesh.visible
	if _sel_ring != null and is_instance_valid(_sel_ring):
		_sel_ring.visible = has_orb
		if has_orb:
			_sel_ring.position = b.pos
	_update_descend_visibility()


## Descend satellites show ONLY on the focused, revealed orb — they exist as an affordance
## for "descend into THIS register", not as a permanent constellation.
func _update_descend_visibility() -> void:
	var sel := _selected_bubble()
	var sel_reg: int = int(sel.reg) if not sel.is_empty() else -2147483648
	for dp in _descend_portals:
		var b := _bubble_for_reg(int(dp.register_id))
		var vis: bool = (not b.is_empty()) and is_instance_valid(b.get("mesh")) \
			and b.mesh.visible and int(dp.register_id) == sel_reg
		for k in ["mesh", "ring", "sprite"]:
			var node = dp.get(k)
			if node != null and is_instance_valid(node):
				node.visible = vis


func _bubble_for_reg(reg: int) -> Dictionary:
	for b in _bubbles:
		if int(b.reg) == reg:
			return b
	return {}


## B-microscope contract (same signature as QuantumForceGraph's): deep-physics webs
## (MI edges, state vectors + trails) draw only while B is open.
func on_overlay_changed(overlay_name: String, is_open: bool) -> void:
	if overlay_name == "biome_detail":
		show_inspection_layers = is_open
		_mi_dirty = true


## E-pause contract (same signature as QuantumForceGraph's): 0 freezes the renderer's
## idle drift so a paused game LOOKS paused.
func set_time_flow_scale(s: float) -> void:
	_time_scale = s


## Route a renderer-side refusal (e.g. the fractal depth cap) to the player as a toast —
## a click that does nothing and says nothing is a silent hindrance (anti-gating law).
func _toast(msg: String) -> void:
	if msg == "":
		return
	var tree := get_tree()
	var app = tree.get_first_node_in_group("app_root") if tree else null
	var shell = app.player_shell if app != null and ("player_shell" in app) else null
	if shell != null and shell.has_method("show_hint"):
		shell.show_hint("[color=#8899aa]•[/color] %s" % msg)


## Centre the field on the PLAY AREA, not the window: ~283px of top chrome (resource bar
## + 3 action rows) vs ~72px bottom at 720p means the window centre sits well above the
## usable strip's centre, sliding top orbs under the HUD. Camera h/v_offset pans the frame
## so the pivot projects at UILayoutManager.get_play_area_center() — unproject_position
## includes the offsets, so picking stays exact. The standalone cognifold instrument has
## no shell/layout manager and keeps the plain window-centred frame.
func _update_camera_framing() -> void:
	if _cam == null or size.y < 4.0:
		return
	var lm = _layout_manager_ref()
	if lm == null or not lm.has_method("get_play_area_center"):
		return
	var pc: Vector2 = lm.get_play_area_center()
	var vc: Vector2 = size * 0.5
	var dist := _cam.position.length()   # camera → pivot origin
	var world_per_px := 2.0 * dist * tan(deg_to_rad(_cam.fov * 0.5)) / size.y
	# camera pans opposite to where the subject should appear: play-centre right of the
	# window centre → camera left; play-centre BELOW (screen y grows down) → camera up.
	_cam.h_offset = -(pc.x - vc.x) * world_per_px
	_cam.v_offset = (pc.y - vc.y) * world_per_px


var _lm_cache: Node = null
func _layout_manager_ref() -> Node:
	if _lm_cache != null and is_instance_valid(_lm_cache):
		return _lm_cache
	var tree := get_tree()
	if tree == null:
		return null
	var fv = tree.get_first_node_in_group("farm_view")
	var shell = fv.shell if fv != null and ("shell" in fv) else null
	_lm_cache = shell.layout_manager if shell != null and ("layout_manager" in shell) else null
	return _lm_cache


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
func _emoji_tex(e: String) -> Texture2D:
	if e == "":
		return null
	return EmojiRegistry.shared().get_texture(e)


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
	# The Fibonacci spiral is only centroid-balanced for large n — a 4-register biome's
	# raw layout sits ~0.29 units left of origin, and the pivot spin then ORBITS that
	# offset around the screen centre (the picture visibly wanders). Subtract the
	# centroid so the cloud is centred on the pivot it rotates about.
	var raw: Array = []
	var centroid := Vector3.ZERO
	for i in range(n):
		var p := _layout_pos(i, n)
		raw.append(p)
		centroid += p
	if n > 0:
		centroid /= float(n)
	for i in range(n):
		var pos: Vector3 = raw[i] - centroid
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

	var b := {"reg": reg, "mesh": mi, "eq": eq, "axisline": axisline, "np": np,
		"spr": spr, "dot": dot, "ring": ring, "pos": pos, "anchor": pos, "grid_pos": grid_pos,
		"trail": [], "north_e": north_emoji, "south_e": south_emoji}
	_bubbles.append(b)
	# Explore-on-action (owner ruling 2026-08-02): a register stays hidden until
	# the player actually explores its plot — mirrors QuantumForceGraph's own
	# reveal gate so 2D and 3D agree on what "explored" means.
	_set_bubble_visible(b, _is_plot_revealed(grid_pos))


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
	_mi_segs.clear()
	_mi_dirty = true
	_metro_segs.clear()
	_metro_dirty = true
	_attract_pairs.clear()
	_clear_lindblad_glyphs()


# ------------------------------------------------------- fractal biome portals
## Every OTHER loaded biome becomes a small themed portal orb ringed around the field.
## Clicking one dives into it (set_active_biome) — the fractal navigation from the demo.
func _rebuild_portals(active_name: String) -> void:
	_clear_portals()
	_clear_fractal_portals()
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
		# field or its bloom, always clickable to dive into that biome. x=−4.2 mirrors the
		# ascend portal's +4.2 (the old −4.9 sat ~76% out toward the left edge and read as
		# a lopsided composition with ≥2 biomes loaded).
		var t := (float(i) + 0.5) / float(max(1, n))   # 0..1, centered
		var pos := Vector3(-4.2, 0.8 - t * 3.6, 0.0)
		_spawn_portal(others[i], pos)

	_rebuild_fractal_portals(active_name)


## Fractal icon→world nav (FractalAtlas/FractalWorldService/ProceduralIconBiome): a small
## indigo "descend" satellite next to every register (enter_icon on tap, real recursive
## depth — not the lateral sibling dive above), plus a single ascend portal when the active
## biome is itself a materialized fractal child (ProceduralIconBiome stamps
## biome.set_meta("fractal_world", true) on every world it builds). Descend satellites are
## children of _pivot (they orbit WITH their register); the ascend portal is fixed on _world
## like the sibling rail, since "leave this world" isn't tied to any one register.
## Depth-cap enforcement stays server-side in FractalAtlas/FractalWorldService — the
## renderer doesn't duplicate the cap check; a refused descend (success=false) surfaces
## the server's message as a toast in _try_pick (polish pass 2026-08-04).
func _rebuild_fractal_portals(active_name: String) -> void:
	for reg in _bubbles:
		_spawn_descend_portal(int(reg.reg), reg.pos, active_name, str(reg.get("north_e", "")))

	var biome = _get_active_biome()
	if biome != null and biome.has_meta("fractal_world") and bool(biome.get_meta("fractal_world")):
		_spawn_ascend_portal()
	# Satellites spawn hidden; selection + reveal state decide which one shows.
	_update_selection_visuals()


func _spawn_descend_portal(register_id: int, base_pos: Vector3, biome_name: String, north_emoji: String = "") -> void:
	# Push the satellite further out along the same radial direction as its register orb —
	# purely geometric, no extra layout math needed.
	var dir := base_pos.normalized() if base_pos.length() > 0.01 else Vector3(0, 1, 0)
	var pos := base_pos + dir * 0.42

	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.09; sm.height = 0.18
	sm.radial_segments = 14; sm.rings = 8
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = DESCEND_HUE_COLOR.darkened(0.35)
	mi.material_override = mat
	mi.position = pos
	mi.visible = false   # selected-orb-only: _update_descend_visibility decides
	_pivot.add_child(mi)

	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 0.10; tm.outer_radius = 0.125
	tm.rings = 32; tm.ring_segments = 10
	ring.mesh = tm
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = DESCEND_HUE_COLOR
	ring.material_override = rmat
	ring.position = pos
	ring.visible = false
	_pivot.add_child(ring)

	# label the satellite with the register's icon so it reads as "descend into THIS
	# register's world" instead of a meaningless indigo dot
	var sp: Sprite3D = null
	var tex := _emoji_tex(north_emoji)
	if tex != null:
		sp = Sprite3D.new()
		sp.texture = tex
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.shaded = false
		sp.no_depth_test = true
		sp.pixel_size = 0.16 / float(max(8, tex.get_width()))
		sp.position = pos
		sp.visible = false
		_pivot.add_child(sp)

	_descend_portals.append({"mesh": mi, "ring": ring, "sprite": sp, "pos": pos, "biome_name": biome_name, "register_id": register_id})


func _spawn_ascend_portal() -> void:
	var pos := Vector3(4.2, 1.6, 0.0)   # mirrors the sibling rail's −4.2
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.20; sm.height = 0.40
	sm.radial_segments = 20; sm.rings = 12
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = CYAN.darkened(0.55)
	mi.material_override = mat
	mi.position = pos
	_world.add_child(mi)

	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 0.215; tm.outer_radius = 0.25
	tm.rings = 44; tm.ring_segments = 14
	ring.mesh = tm
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = CYAN
	ring.material_override = rmat
	ring.position = pos
	ring.rotation_degrees = Vector3(90, 0, 0)
	_world.add_child(ring)

	# "go back up" needs a glyph, not just a cyan dot
	var sp: Sprite3D = null
	var tex := _emoji_tex("⬆")
	if tex != null:
		sp = Sprite3D.new()
		sp.texture = tex
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.shaded = false
		sp.no_depth_test = true
		sp.pixel_size = 0.28 / float(max(8, tex.get_width()))
		sp.position = pos
		_world.add_child(sp)

	_ascend_portal = {"mesh": mi, "ring": ring, "sprite": sp, "pos": pos}


func _clear_fractal_portals() -> void:
	for p in _descend_portals:
		for k in ["mesh", "ring", "sprite"]:
			if p.get(k) != null and is_instance_valid(p[k]):
				p[k].queue_free()
	_descend_portals.clear()
	if _ascend_portal != null:
		for k in ["mesh", "ring", "sprite"]:
			if _ascend_portal.get(k) != null and is_instance_valid(_ascend_portal[k]):
				_ascend_portal[k].queue_free()
		_ascend_portal = null


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
	# Force sizing: if anchor resolution left us collapsed, re-assert the full-rect
	# anchors (the authority for our rect). The old fallback copied win.size — PHYSICAL
	# window pixels — into the 1280×720 canvas_items space, which shifted the render
	# down-right and zoomed it ~1.5× whenever it fired, permanently.
	if size.x < 4.0 or size.y < 4.0:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	elif _sv != null and Vector2(_sv.size) != size:
		# stretch=true must keep the render target in lockstep with the container —
		# any divergence breaks centring AND picking together (unproject vs ev.position).
		_sv.size = Vector2i(size)

	_update_camera_framing()

	# _rebuild() below reads _is_plot_revealed(), which fails OPEN (visible) when
	# farm_ref is null — correct for the standalone cognifold instrument (no farm,
	# nothing to explore) but wrong here: FarmView's connect_to_farm() lands a few
	# frames after this node starts ticking, so the first rebuild used to fire with
	# farm_ref still unset and every plot came up pre-revealed, permanently (a
	# biome only rebuilds again on biome change). Wait for the real connection.
	if farm_ref == null:
		return

	var biome = _get_active_biome()
	if biome == null:
		return
	var bname := ""
	if biome.has_method("get_biome_type"):
		bname = str(biome.get_biome_type())
	if bname != _last_biome or _bubbles.is_empty():
		var switched := _last_biome != "" and bname != _last_biome
		_last_biome = bname
		_apply_theme(bname)
		_rebuild(biome)
		_rebuild_portals(bname)
		if switched:
			# soften the hard cut on biome switch / descend / ascend — a short fade-in
			# instead of the whole world teleporting between frames
			modulate.a = 0.35
			var tw := create_tween()
			tw.tween_property(self, "modulate:a", 1.0, 0.28)
		if OS.has_environment("SW_FIELD_3D_DEBUG"):
			print("[QF3D] rebuilt biome=", bname, " registers=", _bubbles.size(), " portals=", _portals.size())

	# Gentle continuous drift so the 3D never freezes; a brief hold after a mouse action so a
	# click doesn't fight a moving target. The PRIMARY motion is the physics (state points
	# below). E-pause (_time_scale 0) freezes this too — motion means time is passing.
	if not _dragging and _time_scale > 0.0 and Time.get_ticks_msec() > _orbit_hold_until_ms:
		_pivot.rotate_object_local(Vector3.UP, dt * 0.08 * _time_scale)

	var vc = biome.viz_cache
	_apply_force_dynamics(vc, dt)
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
		# (only while time flows and the orb is revealed — a paused/hidden register
		# must not accumulate a ghost trail)
		if _time_scale > 0.0 and is_instance_valid(b.mesh) and b.mesh.visible:
			var tr: Array = b.trail
			tr.append(b.dot.position)
			if tr.size() > 110:
				tr.pop_front()
		# ripeness (value) grows the gold ring
		var rip := clampf(VC.ripeness(p0, p1), 0.0, 1.0)
		b.ring.scale = Vector3.ONE * (0.92 + 0.35 * rip)
	_update_edges(vc)
	_update_vectors()
	_draw_chain()

	_lindblad_frame += 1
	if (_lindblad_frame % LINDBLAD_STRIDE) == 0:
		_rebuild_lindblad_glyphs()


## Draw each register's live state vector (centre → the real Bloch point) plus a fading
## trail of its recent trajectory — so the moving picture IS the physics simulation.
func _update_vectors() -> void:
	if _vectors == null or not (_vectors.mesh is ImmediateMesh):
		return
	var vm: ImmediateMesh = _vectors.mesh
	vm.clear_surfaces()
	if _bubbles.is_empty():
		return
	# deep-physics web: vectors + trails draw only under the B microscope (the state
	# DOT itself stays always-on — it's the primary "physics is alive" signal)
	if not show_inspection_layers:
		return
	vm.surface_begin(Mesh.PRIMITIVE_LINES)
	for b in _bubbles:
		if not is_instance_valid(b.dot):
			continue
		# reveal gate: an unexplored register draws no web
		if not is_instance_valid(b.mesh) or not b.mesh.visible:
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


## Feel the dynamics: each orb drifts a bounded distance off its static Fibonacci anchor
## toward whichever partners it's live-correlated with (MI) or permanently coupled to
## (H, icons.json) — the "Position (distance) = Mutual Info" idea QuantumForceGraph's own
## docstring always aspired to but never implemented. DRIFT_MAX + the anchor-relative target
## keep this legible (gentle breathing, never a chaotic bounce); REPEL_MARGIN keeps orbs from
## visually colliding when two both drift toward a shared neighbourhood.
func _apply_force_dynamics(vc, dt: float) -> void:
	if _bubbles.size() < 2:
		return
	_force_frame += 1
	if _mi_dirty or (_force_frame % FORCE_STRIDE) == 0:
		_attract_pairs = _recompute_attraction(vc)

	var targets: Array = []
	for i in range(_bubbles.size()):
		var b = _bubbles[i]
		var pull := Vector3.ZERO
		for pair in _attract_pairs:
			if pair[0] == i:
				pull += (_bubbles[pair[1]].anchor - b.anchor) * pair[2]
			elif pair[1] == i:
				pull += (_bubbles[pair[0]].anchor - b.anchor) * pair[2]
		if pull.length() > DRIFT_MAX:
			pull = pull.normalized() * DRIFT_MAX
		targets.append(b.anchor + pull)

	# Mild pairwise repulsion on the TARGET positions (not the live ones) so two orbs both
	# drifting toward a shared correlated neighbour never overlap.
	for i in range(_bubbles.size()):
		for j in range(_bubbles.size()):
			if i == j:
				continue
			var delta: Vector3 = targets[i] - targets[j]
			var dist := delta.length()
			if dist < REPEL_MARGIN and dist > 0.001:
				targets[i] += delta.normalized() * (REPEL_MARGIN - dist) * 0.5

	# Attraction is one-sided (everything pulls inward toward partners), so the cloud's
	# centre of mass migrates off the pivot origin — and the pivot spin then swings that
	# offset around the screen (visible wander). Cancel the mean displacement so the
	# cloud breathes in place: relative attraction preserved, COM pinned to the origin.
	var com_drift := Vector3.ZERO
	for i in range(_bubbles.size()):
		com_drift += targets[i] - _bubbles[i].anchor
	com_drift /= float(_bubbles.size())
	for i in range(_bubbles.size()):
		targets[i] -= com_drift

	var smoothing := 1.0 - exp(-DRIFT_SMOOTH * dt)
	for i in range(_bubbles.size()):
		var b = _bubbles[i]
		b.pos = b.pos.lerp(targets[i], smoothing)
		_reposition_bubble_visuals(b)


## Move every fixed-offset visual (the Bloch ball, equator ring, axis line, ripeness ring,
## pole sprites) to the orb's current live position. The inner state dot keeps updating from
## b.pos in the main _process loop, same as before.
func _reposition_bubble_visuals(b: Dictionary) -> void:
	var pos: Vector3 = b.pos
	for k in ["mesh", "eq", "axisline", "ring"]:
		var node = b.get(k)
		if node != null and is_instance_valid(node):
			node.position = pos
	var np = b.get("np")
	if np != null and is_instance_valid(np):
		np.position = pos + Vector3(0, R + 0.12, 0)
	var spr = b.get("spr")
	if spr != null and is_instance_valid(spr):
		spr.position = pos + Vector3(0, -(R + 0.12), 0)
	# the register's descend satellite rides with its orb (it used to stay parked at the
	# spawn-time anchor while the orb drifted away from it)
	var dir := pos.normalized() if pos.length() > 0.01 else Vector3(0, 1, 0)
	for dp in _descend_portals:
		if int(dp.register_id) == int(b.reg):
			var dpos := pos + dir * 0.42
			for k in ["mesh", "ring", "sprite"]:
				var node = dp.get(k)
				if node != null and is_instance_valid(node):
					node.position = dpos
			dp.pos = dpos
	# the selection ring rides with the focused orb
	if _sel_ring != null and is_instance_valid(_sel_ring) and _sel_ring.visible \
			and _sel_plot_idx == int(b.reg):
		_sel_ring.position = pos


## Combine live MI (primary, 0.7 weight) and static H-coupling magnitude (secondary, 0.3
## weight — same normalization trick as _recompute_metro_segs) into per-bubble-index-pair
## attraction weights. Index pairs, not positions, so the cache stays valid while orbs drift.
func _recompute_attraction(vc) -> Array:
	var pairs: Array = []
	if _bubbles.size() < 2:
		return pairs
	var has_mi: bool = vc.has_method("get_mutual_information")
	var coupling_by_pair: Dictionary = {}
	if vc.has_method("get_hamiltonian_couplings") and vc.has_method("get_qubit"):
		var idx_by_reg: Dictionary = {}
		for i in range(_bubbles.size()):
			idx_by_reg[int(_bubbles[i].reg)] = i
		for emoji in vc.get_emojis():
			var q_src: int = vc.get_qubit(emoji)
			if q_src < 0 or not idx_by_reg.has(q_src):
				continue
			var couplings: Dictionary = vc.get_hamiltonian_couplings(emoji)
			for target_emoji in couplings:
				var q_tgt: int = vc.get_qubit(target_emoji)
				if q_tgt < 0 or q_tgt == q_src or not idx_by_reg.has(q_tgt):
					continue
				var mag := _coupling_magnitude(couplings[target_emoji])
				if mag < 0.001:
					continue
				var key := Vector2i(mini(q_src, q_tgt), maxi(q_src, q_tgt))
				coupling_by_pair[key] = maxf(float(coupling_by_pair.get(key, 0.0)), mag)

	var coup_ref := 1e-6
	if not coupling_by_pair.is_empty():
		var mags: Array = coupling_by_pair.values()
		mags.sort()
		coup_ref = maxf(float(mags[mags.size() / 2]), 1e-6)

	for i in range(_bubbles.size()):
		for j in range(i + 1, _bubbles.size()):
			var w := 0.0
			if has_mi:
				var mi := float(vc.get_mutual_information(_bubbles[i].reg, _bubbles[j].reg))
				w += clampf(mi * 3.0, 0.0, 1.0) * 0.7
			var key := Vector2i(mini(int(_bubbles[i].reg), int(_bubbles[j].reg)),
				maxi(int(_bubbles[i].reg), int(_bubbles[j].reg)))
			if coupling_by_pair.has(key):
				w += clampf(float(coupling_by_pair[key]) / coup_ref, 0.0, 1.0) * 0.3
			if w > 0.02:
				pairs.append([i, j, w])
	return pairs


## Rebuild the manifold edges from live mutual information: a line between two orbs whose
## registers are correlated, brightness ∝ MI. Product (uncorrelated) states draw nothing.
## get_mutual_information is O(n²) over registers, so the correlation set is recomputed only
## every MI_STRIDE frames (the 2D renderer caches MI at a ~6-frame stride too); the cached
## segments still redraw every frame so orbit/drift stays smooth.
func _update_edges(vc) -> void:
	_mi_frame += 1
	if _mi_dirty or (_mi_frame % MI_STRIDE) == 0:
		# live MI is a deep-physics web — recomputed and drawn only under the B
		# microscope (metro lines below stay: they're the permanent transit map)
		_mi_segs = _recompute_mi_segs(vc) if show_inspection_layers else []
		_mi_dirty = false
	if _edges != null and _edges.mesh is ImmediateMesh:
		_draw_segs(_edges.mesh, _mi_segs)

	_metro_frame += 1
	if _metro_dirty or (_metro_frame % METRO_STRIDE) == 0:
		_metro_segs = _recompute_metro_segs(vc)
		_metro_dirty = false
	if _metro_mesh != null and _metro_mesh.mesh is ImmediateMesh:
		_draw_segs(_metro_mesh.mesh, _metro_segs)


func _draw_segs(mesh: ImmediateMesh, segs: Array) -> void:
	mesh.clear_surfaces()
	if segs.is_empty():
		return
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for s in segs:
		var col: Color = s[2]
		mesh.surface_set_color(col)
		mesh.surface_add_vertex(s[0])
		mesh.surface_set_color(col)
		mesh.surface_add_vertex(s[1])
	mesh.surface_end()


## A pair of edges between the SAME two orbs (one MI, one H-coupling) would otherwise render
## as one indistinguishable overlapping line. Push each line class onto its own small parallel
## "track", perpendicular to the edge, the same fix the 2D metro renderer already uses.
func _perp_offset(a: Vector3, b: Vector3) -> Vector3:
	var dir := (b - a).normalized()
	if dir.length() < 0.001:
		return Vector3.ZERO
	var reference := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	return dir.cross(reference).normalized() * LINE_TRACK_OFFSET


## Recompute the correlation segments as [posA, posB, color] (positions in the orbs' stable
## pivot-local space, so the cache stays valid between strides while orbs hold position).
func _recompute_mi_segs(vc) -> Array:
	var segs: Array = []
	if not vc.has_method("get_mutual_information") or _bubbles.size() < 2:
		return segs
	for i in range(_bubbles.size()):
		for j in range(i + 1, _bubbles.size()):
			# reveal gate: edges only between orbs the player has actually explored
			if not _bubble_shown(_bubbles[i]) or not _bubble_shown(_bubbles[j]):
				continue
			var mi := float(vc.get_mutual_information(_bubbles[i].reg, _bubbles[j].reg))
			if mi > 0.02:
				# crisp, clean correlation line (Mini-Metro line, not a glow) — light
				# steel-blue, more opaque the stronger the correlation
				var a := clampf(mi * 3.0, 0.3, 0.95)
				var pa: Vector3 = _bubbles[i].pos
				var pb: Vector3 = _bubbles[j].pos
				var off := _perp_offset(pa, pb)
				segs.append([pa + off, pb + off, Color(0.62, 0.82, 0.95, a)])
	return segs


func _bubble_shown(b: Dictionary) -> bool:
	return is_instance_valid(b.get("mesh")) and b.mesh.visible


## Static Hamiltonian-coupling edges — the biome's PERMANENT wiring (icons.json), not a live
## measurement. Same authority the 2D metro-line renderer uses (QuantumEdgeRenderer.gd
## _rebuild_metro_cache): viz_cache.get_hamiltonian_couplings(emoji), aggregated to qubit
## pairs by max |J|, colored from BiomeVisualTheme's global line_palette.
func _recompute_metro_segs(vc) -> Array:
	var segs: Array = []
	if not vc.has_method("get_hamiltonian_couplings") or not vc.has_method("get_qubit") or _bubbles.size() < 2:
		return segs
	var pos_by_reg: Dictionary = {}
	for b in _bubbles:
		if _bubble_shown(b):   # reveal gate: no transit lines into unexplored fog
			pos_by_reg[int(b.reg)] = b.pos

	var strength_by_pair: Dictionary = {}  # Vector2i(min,max) qubit -> max |J|
	for emoji in vc.get_emojis():
		var q_src: int = vc.get_qubit(emoji)
		if q_src < 0 or not pos_by_reg.has(q_src):
			continue
		var couplings: Dictionary = vc.get_hamiltonian_couplings(emoji)
		for target_emoji in couplings:
			var q_tgt: int = vc.get_qubit(target_emoji)
			if q_tgt < 0 or q_tgt == q_src or not pos_by_reg.has(q_tgt):
				continue
			var mag := _coupling_magnitude(couplings[target_emoji])
			if mag < 0.001:
				continue
			var key := Vector2i(mini(q_src, q_tgt), maxi(q_src, q_tgt))
			strength_by_pair[key] = maxf(float(strength_by_pair.get(key, 0.0)), mag)

	if strength_by_pair.is_empty():
		return segs
	var mags: Array = strength_by_pair.values()
	mags.sort()
	var j_ref: float = maxf(float(mags[mags.size() / 2]), 1e-6)

	var theme: Dictionary = BVT.get_theme(_last_biome)
	var palette: Array = theme.get("line_palette", [Color(0.9, 0.78, 0.45)])
	var idx := 0
	for key in strength_by_pair:
		var rel: float = float(strength_by_pair[key]) / j_ref
		var alpha := clampf(0.35 + 0.5 * tanh(rel), 0.35, 0.85)
		var col: Color = palette[idx % palette.size()]
		col.a = alpha
		var pa: Vector3 = pos_by_reg[key.x]
		var pb: Vector3 = pos_by_reg[key.y]
		var off := _perp_offset(pa, pb)
		segs.append([pa - off, pb - off, col])
		idx += 1
	return segs


func _coupling_magnitude(value) -> float:
	if value is float or value is int:
		return absf(float(value))
	if value is Vector2:
		return value.length()
	if value is String and value.is_valid_float():
		return absf(value.to_float())
	return 0.0


# ------------------------------------------------------ Lindblad flow arrows
## Directional pump/drain glyphs, genuinely local — unlike H-coupling/MI, these are NOT edges
## between two different registers. A pump drives population toward a register's OWN north
## pole (energy flowing in from outside); a drain pulls it out at the register's OWN south
## pole (population leaving). viz_cache.get_lindblad_outgoing() looks like the right read
## contract but is confirmed dead plumbing (BiomeBase._seed_viz_couplings deliberately never
## populates it) — so this bypasses viz_cache and reads the same live BasePlot infra flags
## BiomeEvolutionBatcher._biome_has_persistent_lindblad_channels already reads directly.
func _rebuild_lindblad_glyphs() -> void:
	_clear_lindblad_glyphs()
	if farm_ref == null or not is_instance_valid(farm_ref) or not ("grid" in farm_ref) or farm_ref.grid == null:
		return
	var grid = farm_ref.grid
	for b in _bubbles:
		if not _bubble_shown(b):   # reveal gate: no flow arrows on unexplored registers
			continue
		var plot = grid.get_plot(b.grid_pos)
		if plot == null:
			continue
		var pos: Vector3 = b.pos
		if bool(plot.lindblad_pump_active):
			# arrow sits just outside the north pole sprite, apex pointing DOWN into it
			_spawn_lindblad_glyph(pos + Vector3(0, R + 0.42, 0), pos + Vector3(0, R + 0.24, 0), PUMP_COLOR, int(b.reg))
		if bool(plot.lindblad_drain_active):
			# arrow sits just outside the south pole sprite, apex pointing further away from it
			_spawn_lindblad_glyph(pos - Vector3(0, R + 0.24, 0), pos - Vector3(0, R + 0.42, 0), DRAIN_COLOR, int(b.reg))


func _spawn_lindblad_glyph(tail: Vector3, tip: Vector3, color: Color, register_id: int) -> void:
	var dir := (tip - tail).normalized()
	if dir.length() < 0.001:
		return

	var shaft := MeshInstance3D.new()
	var scm := CylinderMesh.new()
	scm.top_radius = 0.012; scm.bottom_radius = 0.012
	scm.height = tail.distance_to(tip) * 0.6
	scm.radial_segments = 8
	shaft.mesh = scm
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = color
	shaft.material_override = smat
	shaft.position = tail.lerp(tip, 0.3)
	_pivot.add_child(shaft)

	var head := MeshInstance3D.new()
	var hcm := CylinderMesh.new()
	hcm.top_radius = 0.0; hcm.bottom_radius = 0.055; hcm.height = 0.16
	hcm.radial_segments = 10
	head.mesh = hcm
	var hmat := StandardMaterial3D.new()
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hmat.albedo_color = color
	hmat.emission_enabled = true
	hmat.emission = color
	hmat.emission_energy_multiplier = 1.3
	head.material_override = hmat
	head.position = tip
	# CylinderMesh's apex (top_radius=0) faces local +Y by default; flip to face `dir`.
	if dir.y < 0:
		head.rotation_degrees = Vector3(180, 0, 0)
	_pivot.add_child(head)

	_lindblad_glyphs.append({"shaft": shaft, "head": head, "register_id": register_id})


func _clear_lindblad_glyphs() -> void:
	for g in _lindblad_glyphs:
		for k in ["shaft", "head"]:
			if g.get(k) != null and is_instance_valid(g[k]):
				g[k].queue_free()
	_lindblad_glyphs.clear()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouse:
		_orbit_hold_until_ms = Time.get_ticks_msec() + 1500
		_pointer_pos = ev.position
	# ONE pointer, three gestures, disambiguated by where the press lands and whether it moves:
	#   • press+release on an orb, no drag → TAP → node_clicked(grid_pos) → handle_bubble_tap
	#   • press on an orb, drag across 2+ orbs → CHAIN → chain_swiped([grid_pos…]) → bell/cluster
	#   • press on EMPTY space, drag → ORBIT the camera (never dispatches a game action)
	# A right-click on an orb picks it too (same as a tap; FarmView ignores the button).
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_press_pos = ev.position
			_press_moved = false
			_dragging = false
			var hit := _orb_at(ev.position)
			if not hit.is_empty():
				# press began ON an orb → this drag builds a gate chain, not an orbit
				_chain_mode = true
				_chain = [hit]
				_flash_orb(hit)
			else:
				_chain_mode = false
				_chain = []
		else:
			if _chain_mode and _chain.size() >= 2:
				_emit_chain()
			elif not _press_moved:
				_try_pick(ev.position, ev.button_index)
			_end_chain()
			_dragging = false
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
		_try_pick(ev.position, ev.button_index)
	elif ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if not _press_moved and ev.position.distance_to(_press_pos) > 7.0:
			_press_moved = true
		if _chain_mode:
			# extend the chain when the pointer crosses onto a NEW orb (dedup consecutive,
			# matching the 2D drag-chain: a node re-enters only if it isn't the current tail)
			var hit := _orb_at(ev.position)
			if not hit.is_empty() and (_chain.is_empty() or int(hit.reg) != int((_chain.back() as Dictionary).reg)):
				_chain.append(hit)
				_flash_orb(hit)
		elif _press_moved:
			_dragging = true
			_pivot.rotate_object_local(Vector3.UP, ev.relative.x * 0.008)
			_pivot.rotate_object_local(Vector3.RIGHT, ev.relative.y * 0.008)


## Resolution-relative screen-pixel hit radii (so picking survives high-DPI / 4K, where a
## fixed pixel radius would be far too small). Scale gently with the viewport height.
func _orb_hit_radius() -> float:
	return maxf(56.0, size.y * 0.07)


func _portal_hit_radius() -> float:
	return maxf(46.0, size.y * 0.055)


## Nearest register orb to a screen point within the orb hit radius (bubbles only, no
## portals — you chain registers, not biomes). Returns the bubble dict, or {} if none.
func _orb_at(screen_pos: Vector2) -> Dictionary:
	if _cam == null:
		return {}
	var best := {}
	var best_d := _orb_hit_radius()
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
	return best


## Brief scale pop on an orb's state dot so it reads as "picked up" by the chain; the pop
## decays back to 1.0 in _process (same path as the tap pick-flash).
func _flash_orb(b: Dictionary) -> void:
	if b.get("dot") != null and is_instance_valid(b.dot):
		b.dot.scale = Vector3.ONE * 1.8


## Emit the gathered chain as an Array[Vector2i] of grid positions — the exact payload the
## 2D renderer emits, so FarmView._on_chain_swiped → apply_chain_gate builds bell (2) / cluster
## (3+) identically to a 2D swipe.
func _emit_chain() -> void:
	var positions: Array[Vector2i] = []
	for b in _chain:
		if (b as Dictionary).has("grid_pos"):
			positions.append(b.grid_pos)
	if positions.size() >= 2:
		chain_swiped.emit(positions)


func _end_chain() -> void:
	_chain_mode = false
	_chain = []
	if _chain_mesh != null and _chain_mesh.mesh is ImmediateMesh:
		(_chain_mesh.mesh as ImmediateMesh).clear_surfaces()


## Draw the live gold thread through the orbs the current chain-swipe has gathered (in the
## orbs' own pivot-local space, so it tracks them; orbit is frozen while chaining). Cleared
## when no chain is active.
func _draw_chain() -> void:
	if _chain_mesh == null or not (_chain_mesh.mesh is ImmediateMesh):
		return
	var cm: ImmediateMesh = _chain_mesh.mesh
	cm.clear_surfaces()
	if not _chain_mode or _chain.size() < 2:
		return
	# bright near-white gold so the live thread reads distinctly against the static gold
	# ripeness rings it passes through
	var gold := Color(1.0, 0.95, 0.72, 0.96)
	cm.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(1, _chain.size()):
		var a: Vector3 = (_chain[i - 1] as Dictionary).pos
		var b: Vector3 = (_chain[i] as Dictionary).pos
		cm.surface_set_color(gold)
		cm.surface_add_vertex(a)
		cm.surface_set_color(gold)
		cm.surface_add_vertex(b)
	cm.surface_end()


func _try_pick(screen_pos: Vector2, button: int) -> void:
	if _cam == null:
		return
	# Ascend first: the one fixed portal that leaves the current fractal child world.
	if _ascend_portal != null and is_instance_valid(_ascend_portal.mesh):
		var wpa: Vector3 = _ascend_portal.mesh.global_position
		if not _cam.is_position_behind(wpa) and _cam.unproject_position(wpa).distance_to(screen_pos) < _portal_hit_radius():
			if farm_ref != null and is_instance_valid(farm_ref) and ("instrument" in farm_ref) and farm_ref.instrument != null:
				var asc: Dictionary = farm_ref.instrument.action_ascend_fractal()
				if bool(asc.get("success", false)):
					biome_selected.emit(str(asc.get("biome_name", "")))
			_consume_tap()
			return
	# Sibling portals next: their rail lives in empty space, no orb overlap to arbitrate.
	var bestp = null
	var bestp_d := _portal_hit_radius()
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
		_consume_tap()
		return
	# Orb vs descend satellite: the satellite sits only ~0.42 units off its orb, well inside
	# the orb's own hit radius, so strict ordering either steals the orb's outer half (the
	# old bug: every outer-edge click dove into a fractal world) or makes the satellite
	# unclickable. NEAREST-WINS between the two, and only VISIBLE satellites compete (they
	# render on the focused, revealed orb only).
	var best = null
	var best_d := _orb_hit_radius()   # resolution-relative px hit radius
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
	var bestd = null
	var bestd_d := _portal_hit_radius() * 0.75
	for dp2 in _descend_portals:
		if not is_instance_valid(dp2.mesh) or not dp2.mesh.visible:
			continue
		var wpd: Vector3 = dp2.mesh.global_position
		if _cam.is_position_behind(wpd):
			continue
		var dd := _cam.unproject_position(wpd).distance_to(screen_pos)
		if dd < bestd_d:
			bestd_d = dd
			bestd = dp2
	if bestd != null and (best == null or bestd_d < best_d):
		# Descend: enter_icon for that register — real recursive depth.
		if farm_ref != null and is_instance_valid(farm_ref) and ("instrument" in farm_ref) and farm_ref.instrument != null:
			var desc: Dictionary = farm_ref.instrument.action_enter_icon(str(bestd.biome_name), int(bestd.register_id))
			if bool(desc.get("success", false)):
				biome_selected.emit(str(desc.get("biome_name", "")))
			else:
				# depth cap (or any other server-side refusal) used to be a silent no-op
				_toast(str(desc.get("message", "The depths end here — this world descends no further")))
		_consume_tap()
		return
	if best != null and best.has("grid_pos"):
		# brief pick flash so the tap reads even before the game's own feedback lands
		if best.get("dot") != null and is_instance_valid(best.dot):
			best.dot.scale = Vector3.ONE * 2.2
		node_clicked.emit(best.grid_pos, button)
		_consume_tap()


## Join the tap-arbitration protocol the 2D handlers already speak: marking the tap consumed
## stops any later (deferred) handler — e.g. a hidden-but-listening rack — from dispatching
## the SAME click a second time against a different plot.
func _consume_tap() -> void:
	var tim = get_node_or_null("/root/TouchInputManager")
	if tim != null and tim.has_method("consume_current_tap"):
		tim.consume_current_tap()


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


## ------------------------------------------------------ rig/harness surface
## Renderer-agnostic mirror of the 2D rig's per-bubble read, so automated drives (the act
## campaign, tap_to_farm probe) can enumerate + target orbs under the 3D field. `visible`
## now mirrors the SAME reveal-on-first-touch state the 2D renderer's node.visible carries
## (b.mesh.visible is kept live by _set_bubble_visible / _is_plot_revealed, the same authority
## _spawn seeds a new orb from) — the 3D field used to report a blanket true here ("3D shows
## all registers"), which was true of the RENDER but not of the rig surface's honesty; fixed
## per task #405. terminal-measured state is still not tracked in the field (measured=false)
## — a known follow-up. The authoritative reveal/measured data lives on the farm, which the
## rig reads separately.
func rig_bubble_state() -> Array:
	var out: Array = []
	for b in _bubbles:
		if not is_instance_valid(b.mesh):
			continue
		var sp := Vector2(-1, -1)
		if _cam != null and not _cam.is_position_behind(b.mesh.global_position):
			sp = _cam.unproject_position(b.mesh.global_position)
		out.append({
			"pos": [int(b.grid_pos.x), int(b.grid_pos.y)],
			"visible": bool(b.mesh.visible),
			"measured": false,
			"biome": _last_biome,
			"register_id": int(b.reg),
			"axis": "%s%s" % [str(b.get("north_e", "")), str(b.get("south_e", ""))],
			"screen_pos": [int(sp.x), int(sp.y)],
		})
	return out


## Rig tap support: the live screen position of the orb at a grid position (or (-1,-1) if it
## has no visible orb). The rig injects a synthetic mouse press+release at this point, which
## _gui_input picks up as a TAP → node_clicked → handle_bubble_tap, exactly like the 2D path.
func rig_screen_pos_for_grid(grid_pos: Vector2i) -> Vector2:
	if _cam == null:
		return Vector2(-1, -1)
	for b in _bubbles:
		if b.has("grid_pos") and b.grid_pos == grid_pos and is_instance_valid(b.mesh):
			if not _cam.is_position_behind(b.mesh.global_position):
				return _cam.unproject_position(b.mesh.global_position)
	return Vector2(-1, -1)


## dev-only: simulate a chain-swipe across the given register indices (into _bubbles),
## emitting chain_swiped exactly as a real drag would → FarmView._on_chain_swiped →
## apply_chain_gate builds a bell (2) / cluster (3+) gate. Returns the grid positions
## chained, so the screenshot harness can log the dispatch.
func dev_chain(regs: Array) -> Array:
	var positions: Array[Vector2i] = []
	_chain = []
	for r in regs:
		var idx := int(r)
		if idx < 0 or idx >= _bubbles.size():
			continue
		var b = _bubbles[idx]
		_chain.append(b)
		_flash_orb(b)
		if b.has("grid_pos"):
			positions.append(b.grid_pos)
	_chain_mode = true   # keep the gold thread drawn for the capture
	if positions.size() >= 2:
		chain_swiped.emit(positions)
	return positions


## dev-only: simulate a click on portal `idx` (dives into that biome). Returns its name.
func dev_tap_portal(idx: int) -> String:
	if idx < 0 or idx >= _portals.size():
		return "<none>"
	var p = _portals[idx]
	if not is_instance_valid(p.mesh) or _cam == null:
		return "<none>"
	_try_pick(_cam.unproject_position(p.mesh.global_position), MOUSE_BUTTON_LEFT)
	return str(p.name)
