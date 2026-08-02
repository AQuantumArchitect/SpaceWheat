extends SceneTree

## Emit the solid angle BerryPhaseRegister accumulates over canonical Bloch loops,
## as JSON, so a cross-repo agreement test can compare it against umwelt's two
## independent geometric-phase implementations.
##
## Nothing here reimplements the math: it drives the REAL register through its
## real entry point. integrate_step accepts any per-qubit layout
## [p0, p1, x, y, z, r, ...] with stride >= 6 (BerryPhaseRegister.gd:71-77), so a
## synthetic unit-radius Bloch walk is a legitimate input — no quantum state needed.
##
## Run: godot --headless --script tests/berry_solid_angle_probe.gd

const Register := preload("res://Core/QuantumSubstrate/BerryPhaseRegister.gd")

const N: int = 240          # samples per revolution; well above LOOP_MIN_POINTS


func _packet(x: float, y: float, z: float) -> PackedFloat64Array:
	var p := PackedFloat64Array()
	p.append(0.0)   # p0 — unread by integrate_step
	p.append(0.0)   # p1 — unread by integrate_step
	p.append(x)
	p.append(y)
	p.append(z)
	p.append(1.0)   # |r| = 1: a pure state, where gamma = -omega/2 is exact
	return p


func _walk(points: Array) -> Dictionary:
	var reg = Register.new()
	reg.start_tracking(0)
	for pt in points:
		reg.integrate_step(_packet(pt[0], pt[1], pt[2]), 1)
	return {"omega": reg.get_phase(0), "frozen_loops": reg.frozen_loop_count()}


## A circle of constant polar angle theta, wound `turns` times in azimuth.
func _cap(theta: float, turns: float) -> Array:
	var pts: Array = []
	var steps: int = int(round(N * turns))
	for i in range(steps + 1):
		var phi: float = TAU * turns * float(i) / float(steps)
		pts.append([sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta)])
	return pts


## Out along a meridian arc and back the SAME way: long path, zero enclosed area.
## This is the discriminator between a geometric quantity and a dissipative one.
func _retrace(theta: float) -> Array:
	var pts: Array = []
	for i in range(N + 1):
		var phi: float = PI * float(i) / float(N)
		pts.append([sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta)])
	for i in range(N, -1, -1):
		var phi: float = PI * float(i) / float(N)
		pts.append([sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta)])
	return pts


func _init() -> void:
	var out := {
		"schema": "berry-solid-angle-probe/0.1",
		"samples_per_turn": N,
		"cases": {
			# equator: encloses a hemisphere -> |omega| = 2pi
			"equator_1turn": _walk(_cap(PI / 2.0, 1.0)),
			# two windings of the same circle -> twice the solid angle (linearity)
			"equator_2turn": _walk(_cap(PI / 2.0, 2.0)),
			# polar cap at theta=pi/3 -> omega = 2pi(1 - cos theta) = pi
			"cap_60deg": _walk(_cap(PI / 3.0, 1.0)),
			# a tighter cap -> 2pi(1 - cos 30) = 2pi(1 - sqrt3/2) ~= 0.8418
			"cap_30deg": _walk(_cap(PI / 6.0, 1.0)),
			# THE DISCRIMINATOR: same arc length as a half-turn, zero area enclosed.
			# Geometric -> 0. Dissipative/path-length-driven -> nonzero.
			"retrace_60deg": _walk(_retrace(PI / 3.0)),
		},
	}
	print(JSON.stringify(out))
	quit(0)
