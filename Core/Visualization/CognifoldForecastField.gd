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

var _fc_mesh: MeshInstance3D = null
var _cores: Dictionary = {}       # reg → inner "trust core" MeshInstance3D (reliability channel)


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


# The base calls _update_vectors() unqualified from _process, so this override dispatches;
# we let it draw the state vectors + past trail, then lay the forward forecast ladder on top.
func _update_vectors() -> void:
	super._update_vectors()
	_draw_forecasts()
	_update_trust_cores()


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
