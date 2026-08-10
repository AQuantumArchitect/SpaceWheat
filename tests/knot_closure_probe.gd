extends SceneTree

## The "closed downstairs ≠ closed upstairs" probe, driven through the REAL
## register entry points (no math reimplemented here):
##
##   1. One ripe equator loop (Ω ≈ 2π): the Bloch walk closes onto its seed,
##      but its Berry lift lands at the S³ ANTIPODE — holonomy ≈ π, spinor
##      sign −1, closure defect ≈ π. gauss_linking must REFUSE it (NAN).
##   2. The same loop traveled twice (Ω ≈ 4π): stitching the two consecutive
##      frozen records (KnotRegister.concat_records) yields a walk whose lift
##      genuinely closes — defect below LIFT_CLOSE_EPS, spinor sign back to +1.
##   3. A pair of genuinely-closed lifts (equator ×2 vs a 45°-tilted great
##      circle ×2) is a legal linking question: gauss_linking returns a
##      finite number. (A small cap needs 2π/Ω traversals to close upstairs,
##      but each base re-closure reseeds up to LOOP_CLOSE_EPS further along
##      the walk — many-turn stitches drift open. Hemisphere loops close in
##      two turns with a single reseed.)
##
## Run: godot --headless --script tests/knot_closure_probe.gd

const Register := preload("res://Core/QuantumSubstrate/BerryPhaseRegister.gd")
const Knot := preload("res://Core/QuantumSubstrate/KnotRegister.gd")

const N: int = 240  # samples per revolution; well above LOOP_MIN_POINTS


func _packet(x: float, y: float, z: float) -> PackedFloat64Array:
	var p := PackedFloat64Array()
	p.append(0.0)
	p.append(0.0)
	p.append(x)
	p.append(y)
	p.append(z)
	p.append(1.0)
	return p


func _drive(reg, points: Array) -> void:
	for pt in points:
		reg.integrate_step(_packet(pt[0], pt[1], pt[2]), 1)


func _cap(theta: float, turns: float) -> Array:
	var pts: Array = []
	var steps: int = int(round(N * turns))
	for i in range(steps + 1):
		var phi: float = TAU * turns * float(i) / float(steps)
		pts.append([sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta)])
	return pts


func _tilted_great_circle(tilt: float, turns: float) -> Array:
	# The equator rotated about x̂ by `tilt`: still a hemisphere per turn
	# (Ω = 2π), but a genuinely different curve — avoids the poles for tilt < π/2.
	var pts: Array = []
	var steps: int = int(round(N * turns))
	for i in range(steps + 1):
		var phi: float = TAU * turns * float(i) / float(steps)
		var y: float = sin(phi) * cos(tilt)
		var z: float = sin(phi) * sin(tilt)
		pts.append([cos(phi), y, z])
	return pts


func _init() -> void:
	var checks: Dictionary = {}

	# --- 1. one ripe loop: home downstairs, antipode upstairs ----------------
	var reg = Register.new()
	reg.start_tracking(0)
	_drive(reg, _cap(PI / 2.0, 1.0))
	var loops: Array = reg.frozen_loops()
	checks["one_turn_froze_one_record"] = loops.size() == 1
	var rec: Dictionary = loops[0] if loops.size() >= 1 else {}
	var pts: PackedFloat64Array = rec.get("points", PackedFloat64Array())
	var defect_1: float = Knot.lift_closure_defect(pts)
	checks["record_omega_near_2pi"] = absf(float(rec.get("omega", 0.0)) - TAU) < 0.4
	checks["record_holonomy_near_pi"] = absf(float(rec.get("holonomy", 0.0)) - PI) < 0.2
	checks["record_spinor_flip"] = bool(rec.get("spinor_flip", false))
	checks["record_open_upstairs"] = not bool(rec.get("closed_upstairs", true))
	checks["lift_defect_near_pi"] = absf(defect_1 - PI) < 0.3
	checks["live_spinor_sign_flipped"] = reg.get_spinor_sign(0) == -1
	checks["gauss_refuses_open_lift"] = is_nan(Knot.gauss_linking(pts, pts))

	# --- 2. the same loop twice: the loose ends meet -------------------------
	var reg2 = Register.new()
	reg2.start_tracking(0)
	_drive(reg2, _cap(PI / 2.0, 2.0))
	var loops2: Array = reg2.frozen_loops()
	checks["two_turns_froze_two_records"] = loops2.size() == 2
	var stitched: PackedFloat64Array = Knot.concat_records(loops2)
	var hol_2: float = Knot.lift_holonomy(stitched)
	var defect_2: float = Knot.lift_closure_defect(stitched)
	checks["stitched_holonomy_near_2pi"] = absf(hol_2 - TAU) < 0.4
	checks["stitched_closed_upstairs"] = Knot.is_closed_upstairs(stitched)
	checks["live_spinor_sign_home"] = reg2.get_spinor_sign(0) == 1

	# --- 3. two genuinely closed lifts: linking is a legal question ----------
	var reg3 = Register.new()
	reg3.start_tracking(0)
	_drive(reg3, _tilted_great_circle(PI / 4.0, 2.0))  # hemisphere per turn ×2 → closes upstairs
	var stitched_tilt: PackedFloat64Array = Knot.concat_records(reg3.frozen_loops())
	checks["tilted_x2_closed_upstairs"] = Knot.is_closed_upstairs(stitched_tilt)
	var report: Dictionary = Knot.linking_report(stitched, stitched_tilt)
	checks["closed_pair_link_is_finite"] = report.get("valid", false) and not is_nan(float(report.get("lk", NAN)))
	var report_open: Dictionary = Knot.linking_report(pts, stitched_tilt)
	checks["open_pair_link_refused"] = (not report_open.get("valid", true)) and is_nan(float(report_open.get("lk", 0.0)))

	var ok := true
	for k in checks.keys():
		if not bool(checks[k]):
			ok = false
	print(JSON.stringify({
		"schema": "knot-closure-probe/0.1",
		"pass": ok,
		"checks": checks,
		"numbers": {
			"record_omega": rec.get("omega", 0.0),
			"record_holonomy": rec.get("holonomy", 0.0),
			"one_turn_defect": defect_1,
			"stitched_holonomy": hol_2,
			"stitched_defect": defect_2,
			"lk_closed_pair": report.get("lk", NAN),
		},
	}))
	quit(0 if ok else 1)
