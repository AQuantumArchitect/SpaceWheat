extends "res://tests/smoke_test_base.gd"

## DegenerateRho — the shared "is this ρ safe to hand the native engine" authority.
##
## This logic existed three times (BiomeDeterministicStepper's time-skip cycle, and
## BiomeEvolutionBatcher's status gather + packet queue). All three agreed on the
## 1e-10 epsilon; only one of the three tested for NaN. Since every comparison
## against NaN is false, `trace < 1e-10` reads a NaN trace as healthy — so two of
## the three guards passed NaN straight through to the SIGABRT they exist to stop.
## These tests pin the unified behaviour, NaN included.
##
## Run: godot --headless --path . --script tests/test_degenerate_rho.gd


const DIVIDER = "============================================================"


func _init():
	print("\n" + DIVIDER)
	print("DEGENERATE RHO GUARD")
	print(DIVIDER)

	await self.process_frame

	test_healthy_rho_is_not_degenerate()
	test_zero_trace_is_degenerate()
	test_nan_trace_is_degenerate()
	test_undersized_buffer_is_not_mistaken_for_zero_trace()
	test_maximally_mixed_is_a_real_state()

	_finish("RESULTS")


func _packed(dim: int) -> PackedFloat64Array:
	var p := PackedFloat64Array()
	p.resize(dim * dim * 2)
	p.fill(0.0)
	return p


func test_healthy_rho_is_not_degenerate():
	print("\n[A trace-1 state passes]")
	var dim := 4
	var rho := DegenerateRho.maximally_mixed_packed(dim)
	# Give it some coherence too — off-diagonals must not affect the trace.
	rho[(0 * dim + 1) * 2] = 0.1
	rho[(1 * dim + 0) * 2] = 0.1
	var tr := DegenerateRho.packed_trace(rho, dim)
	_check(abs(tr - 1.0) < 1e-12, "trace == 1.0 (got %s)" % tr)
	_check(not DegenerateRho.is_degenerate(rho, dim), "not degenerate")


func test_zero_trace_is_degenerate():
	print("\n[A collapsed (all-zero) ρ is caught]")
	var dim := 4
	var rho := _packed(dim)
	_check(DegenerateRho.packed_trace(rho, dim) == 0.0, "trace == 0.0")
	_check(DegenerateRho.is_degenerate(rho, dim), "flagged degenerate")

	# And just above the epsilon it is NOT flagged — the threshold is a real edge,
	# not a vague "small" test.
	var tiny := _packed(dim)
	tiny[0] = 1e-9
	_check(not DegenerateRho.is_degenerate(tiny, dim), "trace 1e-9 is above threshold, not flagged")
	var tinier := _packed(dim)
	tinier[0] = 1e-11
	_check(DegenerateRho.is_degenerate(tinier, dim), "trace 1e-11 is below threshold, flagged")


func test_nan_trace_is_degenerate():
	# THE hole this consolidation closes. `NAN < 1e-10` is false, so the two sites
	# that only threshold-tested declared a NaN density matrix perfectly healthy
	# and shipped it to the native engine.
	print("\n[A NaN trace is caught (the hole two of three sites had)]")
	var dim := 4
	var rho := DegenerateRho.maximally_mixed_packed(dim)
	rho[0] = NAN
	var tr := DegenerateRho.packed_trace(rho, dim)
	_check(is_nan(tr), "trace is NaN")
	_check(not (tr < DegenerateRho.TRACE_EPSILON), "bare threshold test would MISS it (NAN < eps is false)")
	_check(DegenerateRho.is_degenerate_trace(tr), "is_degenerate_trace catches it")
	_check(DegenerateRho.is_degenerate(rho, dim), "is_degenerate catches it")


func test_undersized_buffer_is_not_mistaken_for_zero_trace():
	# An undersized ρ is a different failure from a collapsed ρ. packed_trace must
	# not report 0.0 (which would read as "collapsed") or walk off the buffer.
	print("\n[An undersized buffer reports NaN, not a fake zero]")
	var short := _packed(2)  # 2×2 data
	var tr := DegenerateRho.packed_trace(short, 4)  # asked as 4×4
	_check(is_nan(tr), "trace is NaN, not 0.0", "got %s" % tr)
	_check(DegenerateRho.is_degenerate(short, 4), "still flagged unusable")
	_check(is_nan(DegenerateRho.packed_trace(short, 0)), "dim 0 reports NaN")


func test_maximally_mixed_is_a_real_state():
	print("\n[The replacement state is a legal density matrix]")
	for dim in [2, 4, 8, 16]:
		var rho := DegenerateRho.maximally_mixed_packed(dim)
		_check(rho.size() == dim * dim * 2, "dim=%d correct packed size" % dim, "got %d" % rho.size())
		var tr := DegenerateRho.packed_trace(rho, dim)
		_check(abs(tr - 1.0) < 1e-12, "dim=%d trace == 1" % dim, "got %s" % tr)
		# Purity of I/d is 1/d — maximally mixed, exactly.
		var purity := 0.0
		for i in rho.size() / 2:
			purity += rho[i * 2] * rho[i * 2] + rho[i * 2 + 1] * rho[i * 2 + 1]
		_check(abs(purity - 1.0 / float(dim)) < 1e-12, "dim=%d purity == 1/dim" % dim, "got %s" % purity)
		_check(not DegenerateRho.is_degenerate(rho, dim), "dim=%d not degenerate" % dim)

	_check(DegenerateRho.maximally_mixed_packed(0).is_empty(), "dim=0 yields an empty array")
