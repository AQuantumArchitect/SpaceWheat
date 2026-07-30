# Transparency-only subclass of the shipped 3D cognifold renderer. It draws each belief's
# SELF-FORECAST as a forward "ghost ladder": from the live Bloch state point, a warm-amber
# thread climbs the population axis to the register's predicted future state at the
# 13 / 21 / 34 / 55-minute horizons — the mirror of QuantumField3D's cyan *backward* memory
# trail. Boldness scales with the forecast's own skill, so a belief the agent can forecast
# about itself reaches out with a bright, confident ladder; one it cannot barely shows.
#
# QuantumField3D is left byte-for-byte untouched: this override only lights up when the
# viz_cache exposes a forecast gauge (UmweltVizCache.get_gauge), which the game's
# QuantumVizCache does not — so the shipped game renderer is entirely unaffected. The
# CognifoldTraceView instantiates THIS class instead of the base to point the same renderer
# at a real umwelt belief-field and watch it predict itself.
extends "res://Core/Visualization/QuantumField3D.gd"

# "where I predict I'm going" — vivid magenta, deliberately distinct from the cyan past-trail,
# the gold ripeness ring, and the teal spheres, so the self-forecast reads as its own channel.
const FORECAST_WARM := Color(0.98, 0.35, 0.95)
const RUNG_TICK := 0.055         # half-size of the 3-axis cross drawn at each horizon stop
const ACTION_COL := Color(1.0, 0.58, 0.16)   # decision layer: recommended actions (belief → act)
const MI_COL := Color(0.55, 1.0, 0.85)       # live mutual information — beliefs actually sharing info
# manifold channel: grain colours — chorus (redundancy, beliefs echo a common cause) reads warm
# and golden; conspiracy (synergy, the whole knows what no part does) reads deep and violet; flat
# (unresolved / pairwise-only) reads pale and neutral, deliberately duller than either signed grain.
const CHORUS_COL := Color(1.0, 0.85, 0.35)
const CONSPIRACY_COL := Color(0.62, 0.28, 0.95)
const FLAT_COL := Color(0.72, 0.72, 0.8)

var _fc_mesh: MeshInstance3D = null
var _cores: Dictionary = {}       # reg → inner "trust core" MeshInstance3D (reliability channel)
var _act_mesh: MeshInstance3D = null   # connector lines: driving belief → recommended action
var _act_nodes: Dictionary = {}        # action id → {marker, label}
var _mi_mesh: MeshInstance3D = null    # bright edges: real mutual information (the MI sensor firing)
var _mf_mesh: MeshInstance3D = null    # soft loops: manifold constellations (higher-order clusters)


func _ready() -> void:
	super._ready()
	# Own ImmediateMesh under the same pivot as the base's _vectors mesh, so the forecast
	# ladder shares the orb-local frame (b.pos / b.dot.position are pivot-local vertices).
	_fc_mesh = MeshInstance3D.new()
	_fc_mesh.mesh = ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fc_mesh.material_override = m
	if _pivot != null and is_instance_valid(_pivot):
		_pivot.add_child(_fc_mesh)
	else:
		add_child(_fc_mesh)
	# decision-layer connector lines (belief → recommended action)
	_act_mesh = MeshInstance3D.new()
	_act_mesh.mesh = ImmediateMesh.new()
	var am := StandardMaterial3D.new()
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	am.vertex_color_use_as_albedo = true
	am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_act_mesh.material_override = am
	if _pivot != null and is_instance_valid(_pivot):
		_pivot.add_child(_act_mesh)
	else:
		add_child(_act_mesh)
	# live mutual-information edges (the MI sensor firing) — a distinct bright channel
	_mi_mesh = MeshInstance3D.new()
	_mi_mesh.mesh = ImmediateMesh.new()
	var mim := StandardMaterial3D.new()
	mim.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mim.vertex_color_use_as_albedo = true
	mim.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mi_mesh.material_override = mim
	if _pivot != null and is_instance_valid(_pivot):
		_pivot.add_child(_mi_mesh)
	else:
		add_child(_mi_mesh)
	# manifold constellation loops (higher-order clusters, grain-coloured)
	_mf_mesh = MeshInstance3D.new()
	_mf_mesh.mesh = ImmediateMesh.new()
	var mfm := StandardMaterial3D.new()
	mfm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mfm.vertex_color_use_as_albedo = true
	mfm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mf_mesh.material_override = mfm
	if _pivot != null and is_instance_valid(_pivot):
		_pivot.add_child(_mf_mesh)
	else:
		add_child(_mf_mesh)


# The base calls _update_vectors() unqualified from _process, so this override dispatches;
# we let it draw the state vectors + past trail, then lay the forward forecast ladder on top.
func _update_vectors() -> void:
	super._update_vectors()
	_draw_forecasts()
	_update_trust_cores()
	_update_actions()
	_update_mi_edges()
	_update_manifold()


func _draw_forecasts() -> void:
	if _fc_mesh == null or not (_fc_mesh.mesh is ImmediateMesh):
		return
	var fm: ImmediateMesh = _fc_mesh.mesh
	fm.clear_surfaces()
	var biome = _get_active_biome()
	if biome == null:
		return
	var vc = biome.viz_cache
	if vc == null or not vc.has_method("get_gauge") or not vc.has_method("get_snapshot"):
		return   # game viz_cache has no forecast gauge → nothing to draw, renderer unaffected
	var began := false
	for b in _bubbles:
		if not is_instance_valid(b.dot):
			continue
		var gauge = vc.get_gauge(b.reg)
		if typeof(gauge) != TYPE_DICTIONARY:
			continue
		var ladder = gauge.get("forecast", [])
		if typeof(ladder) != TYPE_ARRAY or ladder.is_empty():
			continue   # this belief has no self-forecast (yet) — draw nothing forward
		# Order the rungs by horizon so the polyline reaches outward in time.
		var rungs: Array = ladder.duplicate()
		rungs.sort_custom(func(a, c):
			return float(a.get("horizon_min", 0.0)) < float(c.get("horizon_min", 0.0)))
		var snap = vc.get_snapshot(b.reg)
		if typeof(snap) != TYPE_DICTIONARY:
			continue
		var rb := float(snap.get("r_bloch", 1.0))    # confidence = Bloch radius (held across the forecast)
		var ph := float(snap.get("phi", 0.0))        # phase (forecaster predicts population, not phase)
		if not began:
			fm.surface_begin(Mesh.PRIMITIVE_LINES)
			began = true
		var prev: Vector3 = b.dot.position
		var n := rungs.size()
		for idx in range(n):
			var e = rungs[idx]
			var zraw = e.get("z_pred", null)
			if zraw == null:
				continue
			# z_pred is the predicted Bloch z-component (population axis). Slide along the
			# fixed-phase meridian on the current confidence shell to that predicted height.
			var zc := clampf(float(zraw), -rb, rb)
			var eqr := R * sqrt(max(0.0, rb * rb - zc * zc))
			var pt: Vector3 = b.pos + Vector3(eqr * cos(ph), zc * R, eqr * sin(ph))
			# boldness = forecast skill (null skill → faint); farther horizons fade.
			var sk = e.get("skill", null)
			var skill := (float(sk) if sk != null else 0.0)
			var horizon_fade := 1.0 - 0.4 * (float(idx) / float(max(1, n - 1)))
			var a := clampf(lerpf(0.35, 0.95, clampf(skill, 0.0, 1.0)) * horizon_fade, 0.12, 0.98)
			var col := Color(FORECAST_WARM.r, FORECAST_WARM.g, FORECAST_WARM.b, a)
			# reach: previous stop → this stop (faint at the tail, full at the new tip)
			fm.surface_set_color(Color(col.r, col.g, col.b, a * 0.7))
			fm.surface_add_vertex(prev)
			fm.surface_set_color(col)
			fm.surface_add_vertex(pt)
			# a 3-axis cross marks each horizon stop (readable from any camera angle); the
			# FINAL horizon — where the belief predicts it will settle — gets a bigger cross
			# so the ladder reads as a thread reaching to a destination, not a blob of ticks.
			var tick := RUNG_TICK * (1.7 if idx == n - 1 else 0.55)
			for axis in [Vector3(tick, 0, 0), Vector3(0, tick, 0), Vector3(0, 0, tick)]:
				fm.surface_set_color(col)
				fm.surface_add_vertex(pt - axis)
				fm.surface_set_color(col)
				fm.surface_add_vertex(pt + axis)
			prev = pt
	if began:
		fm.surface_end()


## Reliability channel: a pale "trust core" nested at each belief's centre, sized by how much
## the agent trusts its EVIDENCE for that belief (observation-trust α) — distinct from its
## confidence in the belief (the Bloch radius). A belief with a strong core is well-evidenced;
## a tiny core is held on thin evidence. Beliefs with NO trust estimate (reliability == null,
## honestly) show no core at all — the field admits "I have no trust reading here" rather than
## faking one. Cores live at b.pos (the sphere centre), inside the shell, so they never fight
## the surface state-point, the ripeness ring, or the forecast ladder.
func _update_trust_cores() -> void:
	var biome = _get_active_biome()
	if biome == null:
		return
	var vc = biome.viz_cache
	if vc == null or not vc.has_method("get_gauge"):
		return
	for b in _bubbles:
		var gauge = vc.get_gauge(b.reg)
		var rel = gauge.get("reliability", null) if typeof(gauge) == TYPE_DICTIONARY else null
		var core = _cores.get(b.reg, null)
		if rel == null:
			if core != null and is_instance_valid(core):
				core.visible = false
			continue
		if core == null or not is_instance_valid(core):
			core = MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 1.0
			sm.height = 2.0
			sm.radial_segments = 12
			sm.rings = 6
			core.mesh = sm
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(0.96, 0.98, 1.0, 0.55)
			core.material_override = mat
			core.position = b.pos
			if _pivot != null and is_instance_valid(_pivot):
				_pivot.add_child(core)
			else:
				add_child(core)
			_cores[b.reg] = core
		core.visible = true
		# reliability 0 → a bare seed, 1 → ~0.6·R (stays well inside the rb·R shell)
		core.scale = Vector3.ONE * ((0.08 + 0.55 * clampf(float(rel), 0.0, 1.0)) * R)


## Decision layer — "why did it act": each output tendril's recommendation floats as an amber
## marker above the belief that DRIVES it, wired down by a connector line, labelled with the
## recommended value. Shadow recommendations (the agent decides but dispatches nothing) render
## ghostly — the honest "it decided, but held". So you can read belief → decision at a glance.
func _update_actions() -> void:
	if _act_mesh == null or not (_act_mesh.mesh is ImmediateMesh):
		return
	var am: ImmediateMesh = _act_mesh.mesh
	am.clear_surfaces()
	var biome = _get_active_biome()
	if biome == null:
		return
	var vc = biome.viz_cache
	if vc == null or not vc.has_method("get_actions"):
		return
	var orb := {}
	for b in _bubbles:
		orb[b.reg] = b.pos
	var seen := {}
	var began := false
	for a in vc.get_actions():
		if typeof(a) != TYPE_DICTIONARY:
			continue
		var dr = a.get("driving_register", null)
		if dr == null or not orb.has(int(dr)):
			continue
		var aid := str(a.get("id", ""))
		seen[aid] = true
		var base: Vector3 = orb[int(dr)]
		var marker_pos: Vector3 = base + Vector3(0.0, R * 2.6, 0.0)
		var rec = _act_nodes.get(aid, null)
		if rec == null:
			rec = _make_action_node()
			_act_nodes[aid] = rec
		var shadow: bool = bool(a.get("shadow", true))
		var kind := str(a.get("kind", ""))
		var val := float(a.get("value", 0.0))
		var vtxt := ("ON" if val >= 0.5 else "OFF") if kind == "binary" else ("%.0f" % val)
		rec.marker.position = marker_pos
		rec.marker.visible = true
		rec.marker.transparency = 0.55 if shadow else 0.0
		rec.label.position = marker_pos + Vector3(0.0, R * 0.75, 0.0)
		rec.label.text = "%s → %s%s" % [aid, vtxt, ("  ·shadow" if shadow else "")]
		rec.label.modulate = Color(1.0, 0.72, 0.4, 0.7 if shadow else 1.0)
		rec.label.visible = true
		# connector: driving belief (faint) → action marker (bright); dashed-feel via short gap
		var col := ACTION_COL
		var a_end := 0.45 if shadow else 0.95
		if not began:
			am.surface_begin(Mesh.PRIMITIVE_LINES)
			began = true
		am.surface_set_color(Color(col.r, col.g, col.b, 0.12))
		am.surface_add_vertex(base)
		am.surface_set_color(Color(col.r, col.g, col.b, a_end))
		am.surface_add_vertex(marker_pos)
	if began:
		am.surface_end()
	for aid in _act_nodes:
		if not seen.has(aid):
			_act_nodes[aid].marker.visible = false
			_act_nodes[aid].label.visible = false


func _make_action_node() -> Dictionary:
	var marker := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(R * 0.5, R * 0.5, R * 0.5)
	marker.mesh = bx
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = ACTION_COL
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker.material_override = m
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 44
	label.pixel_size = 0.0022
	label.outline_size = 10
	label.modulate = Color(1.0, 0.72, 0.4, 1.0)
	if _pivot != null and is_instance_valid(_pivot):
		_pivot.add_child(marker)
		_pivot.add_child(label)
	else:
		add_child(marker)
		add_child(label)
	return {"marker": marker, "label": label}


## Live mutual-information edges: a bright mint line between two beliefs that ACTUALLY share
## information right now (the fast MI sensor firing), brightness ∝ bits. Distinct from the steel
## coupling edges (learned potential). Empty when the field is at rest — it lights up only where
## real correlation lives, so a glowing edge here means "these two beliefs are entangled in what
## they know" at this moment.
func _update_mi_edges() -> void:
	if _mi_mesh == null or not (_mi_mesh.mesh is ImmediateMesh):
		return
	var mm: ImmediateMesh = _mi_mesh.mesh
	mm.clear_surfaces()
	var biome = _get_active_biome()
	if biome == null:
		return
	var vc = biome.viz_cache
	if vc == null or not vc.has_method("get_mi_edges"):
		return
	var mis = vc.get_mi_edges()
	if typeof(mis) != TYPE_ARRAY or mis.is_empty():
		return
	var orb := {}
	for b in _bubbles:
		orb[b.reg] = b.pos
	mm.surface_begin(Mesh.PRIMITIVE_LINES)
	for e in mis:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var i := int(e.get("i", -1))
		var j := int(e.get("j", -1))
		if not orb.has(i) or not orb.has(j):
			continue
		var w := float(e.get("weight", 0.0))                 # bits
		var a := clampf(0.45 + 0.55 * w, 0.45, 1.0)          # brighter with more shared information
		var col := Color(MI_COL.r, MI_COL.g, MI_COL.b, a)
		# drawn twice with a hair of offset so a live MI edge reads thicker than a coupling line
		for off in [Vector3.ZERO, Vector3(0.0, 0.012, 0.0)]:
			mm.surface_set_color(col)
			mm.surface_add_vertex(orb[i] + off)
			mm.surface_set_color(col)
			mm.surface_add_vertex(orb[j] + off)
	mm.surface_end()

## Manifold channel: which beliefs are moving together as a CLUSTER, not just pairwise — a soft
## closed loop drawn through every belief sharing a constellation (umwelt's `get_gauge().
## constellation`, grouped by `node` — the register field that names its manifold cluster), tinted
## by that cluster's grain: gold for chorus (redundancy — they echo a common cause), violet for
## conspiracy (synergy — the whole knows what no part does), pale for flat (unresolved/pairwise-
## only). Brightness tracks the cluster's own max_corr_norm. A lone belief has no constellation
## (null) and draws nothing — same "honestly null-when-absent" convention as the trust cores.
func _update_manifold() -> void:
	if _mf_mesh == null or not (_mf_mesh.mesh is ImmediateMesh):
		return
	var mf: ImmediateMesh = _mf_mesh.mesh
	mf.clear_surfaces()
	var biome = _get_active_biome()
	if biome == null:
		return
	var vc = biome.viz_cache
	if vc == null or not vc.has_method("get_manifold_clusters") or not vc.has_method("get_gauge"):
		return
	var clusters = vc.get_manifold_clusters()
	if typeof(clusters) != TYPE_ARRAY or clusters.is_empty():
		return
	var meta := {}   # cluster name → cluster dict (grain, max_corr_norm)
	for cl in clusters:
		if typeof(cl) == TYPE_DICTIONARY:
			meta[str(cl.get("name", ""))] = cl
	var groups := {}   # "node|constellation_id" → Array[Vector3]
	for b in _bubbles:
		if not is_instance_valid(b.dot):
			continue
		var gauge = vc.get_gauge(b.reg)
		if typeof(gauge) != TYPE_DICTIONARY:
			continue
		var cons = gauge.get("constellation", null)
		if cons == null:
			continue
		var node := str(gauge.get("node", ""))
		var gk := "%s|%d" % [node, int(cons)]
		if not groups.has(gk):
			groups[gk] = {"node": node, "pts": []}
		(groups[gk].pts as Array).append(b.pos)
	var began := false
	for gk in groups:
		var g = groups[gk]
		var pts: Array = g.pts
		if pts.size() < 2:
			continue
		var cl = meta.get(g.node, {})
		var grain := str(cl.get("grain", "flat"))
		var col := FLAT_COL
		if grain == "chorus":
			col = CHORUS_COL
		elif grain == "conspiracy":
			col = CONSPIRACY_COL
		var strength := clampf(float(cl.get("max_corr_norm", 0.3)), 0.0, 1.0)
		var a := clampf(0.18 + 0.45 * strength, 0.18, 0.65)
		var draw_col := Color(col.r, col.g, col.b, a)
		if not began:
			mf.surface_begin(Mesh.PRIMITIVE_LINES)
			began = true
		var n := pts.size()
		for idx in range(n):
			mf.surface_set_color(draw_col)
			mf.surface_add_vertex(pts[idx])
			mf.surface_set_color(draw_col)
			mf.surface_add_vertex(pts[(idx + 1) % n])
	if began:
		mf.surface_end()
