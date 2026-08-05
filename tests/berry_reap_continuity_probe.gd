extends SceneTree

## Pin the collapse→reseed law at its single authority: QuantumComputer._project_qubit.
##
## Every projective collapse (Ace Strike, Reap, market exercise, measure_axis) must
## cut tracked Berry walks — the Bloch jump has no unitary path connecting its
## endpoints, so integrating a spherical triangle across it manufactures solid
## angle (fake ripeness). Historically only ProbeActions._project_register reseeded;
## Reap projected every qubit of every biome and skipped it. The fix moved the
## reseed inside _project_qubit itself; this probe drives that REAL seam:
##
##   with_reseed_delta — walk a real QuantumComputer's register along an arc,
##     project_qubit() (the real path), then feed one packet at a jumped Bloch
##     position. The reseed makes that packet a SEED (no triangle): delta ≈ 0.
##   control_delta — identical walk + identical jump on a bare BerryPhaseRegister
##     with no reseed: the spurious triangle appears. Nonzero by construction —
##     proves the test can see the failure it guards against.
##
## Run: godot --headless --script tests/berry_reap_continuity_probe.gd

const QC := preload("res://Core/QuantumSubstrate/QuantumComputer.gd")
const Register := preload("res://Core/QuantumSubstrate/BerryPhaseRegister.gd")
const ComplexM := preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const ComplexN := preload("res://Core/QuantumSubstrate/Complex.gd")

const N: int = 120
const THETA: float = PI / 3.0   # 60° cap: real curvature, well-defined walk


## One tracked qubit's packet slice [p0, p1, x, y, z, r].
func _slice(x: float, y: float, z: float) -> PackedFloat64Array:
	var p := PackedFloat64Array()
	p.append(0.0); p.append(0.0)
	p.append(x); p.append(y); p.append(z)
	p.append(1.0)
	return p


## Two-qubit packet: qubit 0 at the walk position, qubit 1 parked at north pole.
func _packet2(x: float, y: float, z: float) -> PackedFloat64Array:
	var p := _slice(x, y, z)
	p.append_array(_slice(0.0, 0.0, 1.0))
	return p


func _arc_point(i: int) -> Vector3:
	# Two-thirds of a cap circle — an OPEN arc, so accumulated phase is mid-walk
	# (the vulnerable state a Reap interrupts), not a closed loop.
	var phi: float = TAU * 0.66 * float(i) / float(N)
	return Vector3(sin(THETA) * cos(phi), sin(THETA) * sin(phi), cos(THETA))


func _init() -> void:
	# --- Real seam: QuantumComputer with 2 axes, walk, collapse, jump ---------
	var qc = QC.new()
	qc.allocate_axis(0, "🅰", "🅱")
	qc.allocate_axis(1, "🅲", "🅳")
	# ρ = |00⟩⟨00| by hand (no Hamiltonian needed; the projection is a physical
	# no-op on this state but still exercises the real _project_qubit tail).
	qc.density_matrix.set_element(0, 0, ComplexN.one())
	qc.berry_register.start_tracking(0)
	for i in range(N + 1):
		var v := _arc_point(i)
		qc.berry_register.integrate_step(_packet2(v.x, v.y, v.z), 2)
	var phase_before: float = qc.berry_register.get_phase(0)
	var projected: bool = qc.project_qubit(1, 0)
	# The post-collapse packet: qubit 0 JUMPED far off the arc (antipodal azimuth,
	# near-pole) — the discontinuity Reap creates on every tracked register.
	qc.berry_register.integrate_step(_packet2(0.0, -sin(0.2), cos(0.2)), 2)
	var phase_after: float = qc.berry_register.get_phase(0)

	# --- Control: same walk + jump on a bare register, NO reseed --------------
	var bare = Register.new()
	bare.start_tracking(0)
	for i in range(N + 1):
		var v := _arc_point(i)
		bare.integrate_step(_slice(v.x, v.y, v.z), 1)
	var bare_before: float = bare.get_phase(0)
	bare.integrate_step(_slice(0.0, -sin(0.2), cos(0.2)), 1)
	var bare_after: float = bare.get_phase(0)

	var out := {
		"schema": "berry-reap-continuity-probe/0.1",
		"projected": projected,
		"phase_before": phase_before,
		"with_reseed_delta": absf(phase_after - phase_before),
		"control_delta": absf(bare_after - bare_before),
	}
	print(JSON.stringify(out))
	quit(0)
