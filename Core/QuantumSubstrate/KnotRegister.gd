class_name KnotRegister
extends RefCounted

## Pair invariants between frozen Berry loop records (BerryPhaseRegister).
##
## A frozen loop is a closed decimated polyline on the unit Bloch sphere,
## stored stride-4 as [x, y, z, omega] per vertex, where omega is the running
## accumulated solid angle — the fiber coordinate of the loop's horizontal
## lift under the Berry connection.
##
## Two loops on S² cannot link: linking needs three dimensions and the sphere
## hasn't the room. The honest invariants live one floor up — on S³, where the
## global phase the Bloch projection forgets still turns — and these functions
## are their computable shadows (docs/ENGINE_FRONTIER.md, Machine 2):
##
## - area_axis:          the loop's signed-area vector (its enclosed-area normal)
## - winding_about_axis: signed turn count of a loop around any axis
## - mutual_winding:     integer — how many times loop A winds about loop B's
##                       area axis. Robust to decimation; the quest currency.
## - gauss_linking:      EXPERIMENTAL — Gauss linking estimate of the two loops'
##                       Berry-connection lifts to S³ (stereographic projection
##                       + midpoint Gauss double sum). Approximate near-contact;
##                       no quest gates on it.
##
## All functions are static; loops from different qubits (even different
## biomes) compare on the shared abstract Bloch sphere.

const PROJECTION_EPS: float = 1e-3


static func vertex_count(points: PackedFloat64Array) -> int:
	return int(points.size() / 4.0)


static func vertex(points: PackedFloat64Array, i: int) -> Vector3:
	var b: int = i * 4
	return Vector3(points[b], points[b + 1], points[b + 2])


static func area_axis(points: PackedFloat64Array) -> Vector3:
	# Signed area vector: sum of successive cross products around the loop.
	# Robust where the plain vertex mean fails (great circles average to zero).
	var n: int = vertex_count(points)
	if n < 3:
		return Vector3.ZERO
	var acc := Vector3.ZERO
	for i in range(n):
		acc += vertex(points, i).cross(vertex(points, (i + 1) % n))
	if acc.length() < 1e-9:
		return Vector3.ZERO
	return acc.normalized()


static func winding_about_axis(points: PackedFloat64Array, axis: Vector3) -> float:
	# Signed number of turns the loop makes around `axis`. Vertices projecting
	# too close to the axis contribute nothing (their azimuth is undefined).
	var n: int = vertex_count(points)
	if n < 3 or axis.length() < 1e-9:
		return 0.0
	var az := axis.normalized()
	var u := az.cross(Vector3.UP)
	if u.length() < 1e-6:
		u = az.cross(Vector3.RIGHT)
	u = u.normalized()
	var v := az.cross(u)
	var total := 0.0
	var have_prev := false
	var prev_ang := 0.0
	for i in range(n):
		var p := vertex(points, i)
		var pu := p.dot(u)
		var pv := p.dot(v)
		if sqrt(pu * pu + pv * pv) < PROJECTION_EPS:
			continue
		var ang := atan2(pv, pu)
		if have_prev:
			total += wrapf(ang - prev_ang, -PI, PI)
		prev_ang = ang
		have_prev = true
	return total / TAU


static func mutual_winding(points_a: PackedFloat64Array, points_b: PackedFloat64Array) -> int:
	# How many times loop A winds about loop B's area axis. The pair teacher:
	# 0 = an unlinked dance, ±1 = a simple link, ±2 = doubly wound.
	var axis := area_axis(points_b)
	if axis == Vector3.ZERO:
		return 0
	return int(roundf(winding_about_axis(points_a, axis)))


static func max_mutual_winding(loops: Array) -> int:
	# Strongest pair invariant across an array of frozen loop records
	# ({points: PackedFloat64Array, ...}). Signed; callers usually take abs.
	var best := 0
	for i in range(loops.size()):
		for j in range(i + 1, loops.size()):
			var pa: PackedFloat64Array = loops[i].get("points", PackedFloat64Array())
			var pb: PackedFloat64Array = loops[j].get("points", PackedFloat64Array())
			var w := mutual_winding(pa, pb)
			if absi(w) > absi(best):
				best = w
	return best


static func lift_to_s3(points: PackedFloat64Array) -> Array:
	# Horizontal lift under the Berry connection: Bloch (θ, φ) with fiber angle
	# ω/2 gives |ψ⟩ = e^{iω/2}(cos(θ/2), e^{iφ} sin(θ/2)) ∈ S³ ⊂ R⁴.
	# Returned as [a_re, a_im, b_re, b_im] per vertex.
	var n: int = vertex_count(points)
	var out: Array = []
	for i in range(n):
		var b: int = i * 4
		var z: float = clampf(points[b + 2], -1.0, 1.0)
		var theta: float = acos(z)
		var phi: float = atan2(points[b + 1], points[b])
		var half: float = theta * 0.5
		var g: float = points[b + 3] * 0.5
		out.append([
			cos(half) * cos(g),
			cos(half) * sin(g),
			sin(half) * cos(phi + g),
			sin(half) * sin(phi + g),
		])
	return out


static func gauss_linking(points_a: PackedFloat64Array, points_b: PackedFloat64Array) -> float:
	# EXPERIMENTAL. Gauss linking estimate of the two loops' S³ lifts:
	# stereographic projection from a pole far from both curves, then the
	# midpoint-rule Gauss double sum over segment pairs. Returns a float near
	# an integer for well-separated curves; degrades near contact. Display and
	# curiosity only — quests gate on mutual_winding.
	var la := lift_to_s3(points_a)
	var lb := lift_to_s3(points_b)
	if la.size() < 3 or lb.size() < 3:
		return 0.0
	var pole := _far_pole(la, lb)
	var ca := _stereographic(la, pole)
	var cb := _stereographic(lb, pole)
	var lk := 0.0
	var na := ca.size()
	var nb := cb.size()
	for i in range(na):
		var a1: Vector3 = ca[i]
		var a2: Vector3 = ca[(i + 1) % na]
		var da := a2 - a1
		var ma := (a1 + a2) * 0.5
		for j in range(nb):
			var b1: Vector3 = cb[j]
			var b2: Vector3 = cb[(j + 1) % nb]
			var db := b2 - b1
			var mb := (b1 + b2) * 0.5
			var r := ma - mb
			var rl := r.length()
			if rl < 1e-6:
				continue
			lk += da.cross(db).dot(r) / (rl * rl * rl)
	return lk / (4.0 * PI)


static func _dot4(a: Array, b: Array) -> float:
	return float(a[0]) * float(b[0]) + float(a[1]) * float(b[1]) \
		+ float(a[2]) * float(b[2]) + float(a[3]) * float(b[3])


static func _far_pole(la: Array, lb: Array) -> Array:
	# Pick, among the eight axis poles of S³, the one farthest (min chordal
	# proximity) from every vertex of both lifted curves — a safe projection
	# center for stereographic coordinates.
	var candidates: Array = [
		[1.0, 0.0, 0.0, 0.0], [-1.0, 0.0, 0.0, 0.0],
		[0.0, 1.0, 0.0, 0.0], [0.0, -1.0, 0.0, 0.0],
		[0.0, 0.0, 1.0, 0.0], [0.0, 0.0, -1.0, 0.0],
		[0.0, 0.0, 0.0, 1.0], [0.0, 0.0, 0.0, -1.0],
	]
	var all_points: Array = la + lb
	var best: Array = candidates[0]
	var best_gap := -2.0
	for c in candidates:
		var gap := 2.0
		for p in all_points:
			var d: float = 1.0 - _dot4(c, p)
			if d < gap:
				gap = d
		if gap > best_gap:
			best_gap = gap
			best = c
	return best


static func _stereographic(pts: Array, pole: Array) -> Array:
	# Orthonormal basis of the pole's orthogonal complement (Gram–Schmidt over
	# R⁴), then p ↦ (p·e_k) / (1 − p·pole) per axis.
	var basis: Array = []
	var seeds: Array = [
		[1.0, 0.0, 0.0, 0.0], [0.0, 1.0, 0.0, 0.0],
		[0.0, 0.0, 1.0, 0.0], [0.0, 0.0, 0.0, 1.0],
	]
	for s in seeds:
		if basis.size() == 3:
			break
		var v: Array = [
			float(s[0]) - float(pole[0]) * _dot4(s, pole),
			float(s[1]) - float(pole[1]) * _dot4(s, pole),
			float(s[2]) - float(pole[2]) * _dot4(s, pole),
			float(s[3]) - float(pole[3]) * _dot4(s, pole),
		]
		for e in basis:
			var d := _dot4(v, e)
			v = [
				float(v[0]) - float(e[0]) * d,
				float(v[1]) - float(e[1]) * d,
				float(v[2]) - float(e[2]) * d,
				float(v[3]) - float(e[3]) * d,
			]
		var l := sqrt(_dot4(v, v))
		if l > 1e-6:
			basis.append([float(v[0]) / l, float(v[1]) / l, float(v[2]) / l, float(v[3]) / l])
	var out: Array = []
	for p in pts:
		var denom: float = 1.0 - _dot4(p, pole)
		if absf(denom) < 1e-9:
			denom = 1e-9
		out.append(Vector3(_dot4(p, basis[0]), _dot4(p, basis[1]), _dot4(p, basis[2])) / denom)
	return out
