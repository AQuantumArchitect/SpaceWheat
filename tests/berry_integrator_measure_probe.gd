extends SceneTree

## Issue #124 measurement: feed the REAL BerryPhaseRegister.integrate_step three
## families of Bloch walks at several step sizes and emit Ω as JSON, so the
## pytest side can hold it against the closed form and name which suspect is real:
##   (a) a step through −ẑ (the apex's antipode) is singular,
##   (b) aliasing once a slice turns ≥ π,
##   (c) |r| < BERRY_EPSILON resets the walk.
##
##   great circle through both poles — a resonant 🔥↔❄ hop (suspect a)
##   constant-latitude circle at 60°, 120°, 170°, N samples per turn
##   Luke's fire/ice loop — the shape measured live in Village: a small circle
##     of angular radius LUKE_RHO about −x̂, never near a pole, stepped at the
##     measured 0.0036 rad/slice and then ever faster (suspect b)
##   a decoherence dip mid-loop (suspect c)
##
## Run: godot --headless --script tests/berry_integrator_measure_probe.gd

const Register := preload("res://Core/QuantumSubstrate/BerryPhaseRegister.gd")

const STEPS_PER_TURN: Array = [240, 24, 8, 4]
const LUKE_RHO: float = 0.33                      # rad; live Village 🔥 loop radius about −x̂
const LUKE_DPSI: Array = [0.011, 0.5, 2.0, 3.0, 3.5, 4.5]  # rad of turn about the axis per slice


func _packet(v: Vector3, r: float = 1.0) -> PackedFloat64Array:
	var p := PackedFloat64Array()
	p.append(0.0)
	p.append(0.0)
	p.append(v.x * r)
	p.append(v.y * r)
	p.append(v.z * r)
	p.append(r)
	return p


func _walk(points: Array, radii: Array = []) -> float:
	var reg = Register.new()
	reg.start_tracking(0)
	for i in range(points.size()):
		var r: float = float(radii[i]) if i < radii.size() else 1.0
		reg.integrate_step(_packet(points[i], r), 1)
	return reg.get_phase(0)


## A circle of angular radius rho about `axis`, `turns` windings, `dpsi` per slice.
func _circle(axis: Vector3, rho: float, turns: float, dpsi: float, phase0: float = 0.0) -> Array:
	var a := axis.normalized()
	var u := a.cross(Vector3(0.0, 0.0, 1.0))
	if u.length() < 1e-9:
		u = a.cross(Vector3(1.0, 0.0, 0.0))
	u = u.normalized()
	var w := a.cross(u)
	var pts: Array = []
	var steps: int = int(round(TAU * turns / dpsi))
	for i in range(steps + 1):
		var psi: float = phase0 + dpsi * float(i)
		pts.append(a * cos(rho) + (u * cos(psi) + w * sin(psi)) * sin(rho))
	return pts


## Great circle in the x–z plane through both poles; starts on the equator.
func _pole_circle(n: int, turns: float, reverse: bool) -> Array:
	var pts: Array = []
	var steps: int = int(round(n * turns))
	for i in range(steps + 1):
		var t: float = TAU * float(i) / float(n)
		if reverse:
			t = -t
		pts.append(Vector3(cos(t), 0.0, sin(t)))
	return pts


func _init() -> void:
	var cases := {}
	for n in STEPS_PER_TURN:
		cases["pole_circle_n%d" % n] = {"omega": _walk(_pole_circle(n, 1.0, false)), "analytic_abs": TAU}
		cases["pole_circle_rev_n%d" % n] = {"omega": _walk(_pole_circle(n, 1.0, true)), "analytic_abs": TAU}
		cases["pole_circle_3turn_n%d" % n] = {"omega": _walk(_pole_circle(n, 3.0, false)), "analytic_abs": 3.0 * TAU}
		for deg in [60, 120, 170]:
			var th: float = deg_to_rad(float(deg))
			cases["latitude_%d_n%d" % [deg, n]] = {
				"omega": _walk(_circle(Vector3(0, 0, 1), th, 1.0, TAU / float(n))),
				"analytic_abs": TAU * (1.0 - cos(th)),
			}
	# Out to the south pole and back along the same meridian: zero area.
	var down: Array = _pole_circle(240, 0.5, false)
	var back: Array = down.duplicate()
	back.reverse()
	cases["pole_retrace"] = {"omega": _walk(down + back), "analytic_abs": 0.0}
	# Seeded exactly on the south pole (a ground state), then a resonant hop
	# for 1.25 turns: the seed step counts 0, the return pass is mid-slice.
	var south_seed: Array = []
	for i in range(297):
		var t: float = TAU * float(i) / 237.3
		south_seed.append(Vector3(sin(t), 0.0, -cos(t)))
	cases["pole_circle_south_seed"] = {"omega": _walk(south_seed), "analytic_abs": TAU}
	for dpsi in LUKE_DPSI:
		cases["luke_loop_dpsi%.3f" % dpsi] = {
			"omega": _walk(_circle(Vector3(-1, 0, 0), LUKE_RHO, 3.0, float(dpsi))),
			"analytic_abs": 3.0 * TAU * (1.0 - cos(LUKE_RHO)),
			"dpsi": float(dpsi),
		}
	# Decoherence dip: |r| falls under BERRY_EPSILON for a stretch mid-loop.
	var dip: Array = _circle(Vector3(0, 0, 1), PI / 2.0, 1.0, TAU / 240.0)
	var radii: Array = []
	for i in range(dip.size()):
		radii.append(0.01 if i >= 100 and i < 110 else 1.0)
	cases["equator_with_decoherence_dip"] = {
		"omega": _walk(dip, radii),
		"analytic_abs": TAU,   # the walk freezes, then one triangle bridges the gap
	}
	print(JSON.stringify({"schema": "berry-integrator-measure/0.1", "luke_rho": LUKE_RHO, "cases": cases}))
	quit(0)
