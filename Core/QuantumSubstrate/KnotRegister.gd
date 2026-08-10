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
##                       HONESTY: an axis-relative winding DIAGNOSTIC, not an
##                       isotopy invariant of the pair — the axis is derived
##                       from the partner loop, so smooth moves that swing B's
##                       area axis can change the count without any cutting.
##                       Integer-valued ≠ topological invariant; an invariant
##                       is what survives every attack the rules allow.
## - lift_holonomy / lift_closure_defect / is_closed_upstairs:
##                       the fiber ledger. A loop closed on S² is generally
##                       NOT closed in its S³ lift — the gap between the
##                       lift's loose ends IS the holonomy (γ = Ω/2). At
##                       Ω = 2π (ripeness) the lift lands on the ANTIPODE:
##                       the spinor came home with its sign reversed. Only
##                       at Ω ≡ 0 (mod 4π) does the lift truly close.
## - concat_records:     stitch consecutive frozen records of one qubit into
##                       a longer walk — travel the loop again and the loose
##                       fiber ends rotate toward each other until they meet.
## - gauss_linking:      Gauss linking estimate of two GENUINELY CLOSED S³
##                       lifts (stereographic projection + midpoint double
##                       sum). Refuses open lifts (returns NAN): the double
##                       sum over a curve with loose ends is not a linking
##                       number. Use linking_report for the full verdict.
##
## All functions are static; loops from different qubits (even different
## biomes) compare on the shared abstract Bloch sphere.

const PROJECTION_EPS: float = 1e-3

## Max S³ angular gap between a lift's endpoints that still counts as closed.
## Must absorb base-closure slack (LOOP_CLOSE_EPS = 0.25 rad on S² lifts to
## ~0.125 rad upstairs) while staying far below π, the spinor-flip antipode.
const LIFT_CLOSE_EPS: float = 0.5


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
	# Diagnostic, not invariant: the axis is B's, so deforming B moves the
	# measuring stick. See the header note — this is a feature to teach with
	# ("The Number That Lied"), not a bug to hide.
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


static func lift_holonomy(points: PackedFloat64Array) -> float:
	# Signed fiber displacement of the loop's horizontal lift: γ = ΔΩ/2,
	# UNWRAPPED — a walk driven twice around a hemisphere reports 2π, not 0.
	# This is the angle the lift's loose end has rotated along the phase fiber
	# relative to its seed. |γ| = π is the spinor flip (e^{iπ} = −1: same
	# Bloch point, opposite sign upstairs); γ ≡ 0 (mod 2π) closes upstairs.
	var n: int = vertex_count(points)
	if n < 2:
		return 0.0
	return (points[(n - 1) * 4 + 3] - points[3]) * 0.5


static func lift_closure_defect(points: PackedFloat64Array) -> float:
	# S³ angular distance between the lift's first and last vertices, in
	# [0, π]. Zero-ish: the lift genuinely closes. ~π: the loose end sits at
	# the ANTIPODE — the spinor sign flip a ripe (Ω = 2π) loop earns. This is
	# the honest geometric gap, so it also absorbs base-closure slack.
	var n: int = vertex_count(points)
	if n < 2:
		return 0.0
	var lifted := lift_to_s3(points)
	var d: float = clampf(_dot4(lifted[0], lifted[n - 1]), -1.0, 1.0)
	return acos(d)


static func is_closed_upstairs(points: PackedFloat64Array, eps: float = LIFT_CLOSE_EPS) -> bool:
	# True when the Berry-connection lift is a genuinely closed curve in S³ —
	# the precondition for asking that curve any knot-theoretic question.
	return lift_closure_defect(points) < eps


static func concat_records(records: Array) -> PackedFloat64Array:
	# Stitch consecutive frozen loop records of ONE qubit into a single walk.
	# BerryPhaseRegister freezes a record at each base closure and reseeds the
	# path at the closing vertex with the SAME running Ω, so consecutive
	# records of a qubit are contiguous in both position and fiber: appending
	# them (dropping each record's duplicated seed vertex after the first)
	# reconstructs the longer walk. Travel the hemisphere once → open lift;
	# stitch the second traversal → the loose ends meet (Ω = 4π, γ = 2π).
	var out := PackedFloat64Array()
	for r in records:
		var pts: PackedFloat64Array = r.get("points", PackedFloat64Array()) if r is Dictionary else r
		if pts.is_empty():
			continue
		var start: int = 0
		if not out.is_empty():
			start = 1  # drop the junction vertex shared with the previous record
		for i in range(start, vertex_count(pts)):
			var b: int = i * 4
			out.append(pts[b])
			out.append(pts[b + 1])
			out.append(pts[b + 2])
			out.append(pts[b + 3])
	return out


## Junction tolerance for stitching consecutive records: a freeze closes onto
## its seed and reseeds AT the triggering vertex, which sits within
## BerryPhaseRegister.LOOP_CLOSE_EPS (0.25 rad) of that seed — so honest
## junctions land inside 0.3 rad. A broken walk (decoherence, collapse)
## reseeds wherever the state actually is, which almost never does.
const STITCH_JUNCTION_EPS: float = 0.3


static func closed_lift_curves(records: Array, eps: float = LIFT_CLOSE_EPS) -> Array:
	# Per qubit, the longest contiguous stitch of its frozen records whose
	# Berry lift genuinely closes in S³. Returns [{qubit, points, holonomy}].
	#
	# Scans contiguous SUBRUNS, not just whole runs: a hemisphere loop walked
	# twice closes (Ω = 4π), but keep walking and the running stitch reopens —
	# the closed curve is a window inside the walk, and over-walking must not
	# hide it. Runs break where consecutive records fail the junction check
	# (the walk was cut between them; stitching across a cut would be a lie).
	# O(runs²) on ≤ FROZEN_LOOP_CAP records — trivial.
	var by_qubit: Dictionary = {}
	for r in records:
		if not (r is Dictionary):
			continue
		var q: int = int(r.get("qubit", -1))
		if not by_qubit.has(q):
			by_qubit[q] = []
		by_qubit[q].append(r)
	var out: Array = []
	for q in by_qubit.keys():
		var runs: Array = _contiguous_runs(by_qubit[q])
		var best := PackedFloat64Array()
		for run in runs:
			for i in range(run.size()):
				for j in range(i, run.size()):
					var stitched := concat_records(run.slice(i, j + 1))
					if vertex_count(stitched) < 3:
						continue
					if lift_closure_defect(stitched) < eps and vertex_count(stitched) > vertex_count(best):
						best = stitched
		if vertex_count(best) >= 3:
			out.append({"qubit": q, "points": best, "holonomy": lift_holonomy(best)})
	return out


static func _contiguous_runs(records: Array) -> Array:
	# Split one qubit's records (FIFO order) into maximal stitchable runs:
	# consecutive records whose junction vertices coincide on the sphere.
	var runs: Array = []
	var current: Array = []
	for r in records:
		var pts: PackedFloat64Array = r.get("points", PackedFloat64Array())
		if pts.is_empty():
			continue
		if current.is_empty():
			current = [r]
			continue
		var prev_pts: PackedFloat64Array = current[current.size() - 1].get("points", PackedFloat64Array())
		var last := vertex(prev_pts, vertex_count(prev_pts) - 1)
		var first := vertex(pts, 0)
		var dot: float = clampf(last.dot(first), -1.0, 1.0)
		if acos(dot) <= STITCH_JUNCTION_EPS:
			current.append(r)
		else:
			runs.append(current)
			current = [r]
	if not current.is_empty():
		runs.append(current)
	return runs


static func gauss_linking(points_a: PackedFloat64Array, points_b: PackedFloat64Array) -> float:
	# Gauss linking estimate of the two loops' S³ lifts: stereographic
	# projection from a pole far from both curves, then the midpoint-rule
	# Gauss double sum over segment pairs. Returns a float near an integer
	# for well-separated curves; degrades near contact.
	#
	# REFUSES OPEN LIFTS (returns NAN). A loop closed on the Bloch sphere is
	# generally open upstairs — its loose fiber ends separated by exactly its
	# holonomy — and the double sum over an implicitly-wrapped open curve is
	# not a linking number of anything. Close it upstairs first (walk the
	# loop again; concat_records), then ask. Quests gate on mutual_winding.
	if not is_closed_upstairs(points_a) or not is_closed_upstairs(points_b):
		return NAN
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


static func linking_report(points_a: PackedFloat64Array, points_b: PackedFloat64Array) -> Dictionary:
	# The full verdict on a pair of walks, for cards and quests:
	#   holonomy_a/b  — unwrapped fiber displacement γ = ΔΩ/2 of each lift
	#   defect_a/b    — S³ angular gap between each lift's loose ends [0, π]
	#   closed_a/b    — whether each lift genuinely closes upstairs
	#   valid         — both closed: the linking number is a real question
	#   lk            — Gauss estimate when valid, NAN otherwise
	var da := lift_closure_defect(points_a)
	var db := lift_closure_defect(points_b)
	var ca := da < LIFT_CLOSE_EPS
	var cb := db < LIFT_CLOSE_EPS
	return {
		"holonomy_a": lift_holonomy(points_a),
		"holonomy_b": lift_holonomy(points_b),
		"defect_a": da,
		"defect_b": db,
		"closed_a": ca,
		"closed_b": cb,
		"valid": ca and cb,
		"lk": gauss_linking(points_a, points_b) if (ca and cb) else NAN,
	}


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
