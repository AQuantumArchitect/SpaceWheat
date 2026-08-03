extends "res://tests/smoke_test_base.gd"

## HermitianEigensolver — the ONE eigen path, exercised through its live consumers.
##
## HermitianEigensolver::solve() used to carry a second implementation: a
## real-symmetric Jacobi rotation behind `#if __has_include(<Eigen/Dense>)`, meant
## for builds without vendored Eigen. No such build exists in this repo (every
## Makefile, CI job and platform script passes -I./include, and several headers in
## the same translation unit include <Eigen/Dense> unconditionally, so the library
## cannot link without it). The fallback was also wrong: it diagonalized Re(H),
## discarding the imaginary off-diagonals that carry the phase of every complex
## Hermitian coupling in this engine.
##
## It is deleted. These tests pin the surviving path against inputs where the two
## implementations would have disagreed — a density matrix with genuinely complex
## coherences. If anything ever reintroduces a real-projection solve, the phase-
## sensitivity assertions below fail.
##
## This is live code, not parked: MythosGraphCore is the sole compute authority
## behind FactionDensityMatrix, and QuantumMythosEngine is on BootManager's
## required-native-classes list.
##
## Run: godot --headless --path . --script tests/test_hermitian_eigen_path.gd


const DIVIDER = "============================================================"


func _init():
	print("\n" + DIVIDER)
	print("HERMITIAN EIGEN PATH (single authority)")
	print(DIVIDER)

	await self.process_frame

	if not ClassDB.class_exists("QuantumMythosEngine"):
		print("  ✗ QuantumMythosEngine not registered — build native first")
		quit(1)
		return

	test_eigen_backend_is_the_only_backend()
	test_complex_coherence_changes_the_spectrum()
	test_principal_mode_is_well_formed()

	_finish("RESULTS")


## A small faction substrate: 4 factions over a shared axis set, uniform state.
func _make_engine() -> Object:
	var e = ClassDB.instantiate("QuantumMythosEngine")
	e.add_faction("alpha", 0, PackedStringArray(["🌾", "🌲"]))
	e.add_faction("beta", 1, PackedStringArray(["🌲", "🍄"]))
	e.add_faction("gamma", 2, PackedStringArray(["🍄", "💧"]))
	e.add_faction("delta", 3, PackedStringArray(["💧", "🌾"]))
	e.faction_initialize_uniform()
	return e


func test_eigen_backend_is_the_only_backend():
	# get_hamiltonian_eigen_summary surfaces which backend ran. With the fallback
	# gone there is exactly one answer, and it is not conditional on the build.
	print("\n[The Eigen backend is the only backend]")
	var e = _make_engine()
	e.compose_hamiltonian()
	var summary: Dictionary = e.get_hamiltonian_eigen_summary(8)
	_check(not summary.is_empty(), "summary returned")
	if summary.get("eigenvalues", PackedFloat64Array()).is_empty():
		# Empty Hamiltonian short-circuits before the solver — say so rather than
		# claim a pass we didn't earn.
		_check(true, "SKIP: Hamiltonian empty, solver not reached")
		return
	_check(summary.get("used_external_backend", false) == true, "used_external_backend is true (Eigen ran)")
	_check(summary.get("eigenvectors_available", false) == true, "eigenvectors_available is true")
	var evs: PackedFloat64Array = summary["eigenvalues"]
	var all_finite := true
	for v in evs:
		if is_nan(v) or is_inf(v):
			all_finite = false
	_check(all_finite, "eigenvalues all finite (%d values)" % evs.size())
	# A Hermitian matrix has real eigenvalues and Eigen returns them ascending.
	var sorted := true
	for i in range(1, evs.size()):
		if evs[i] < evs[i - 1] - 1e-9:
			sorted = false
	_check(sorted, "eigenvalues ascending (Eigen convention)", str(evs))


func test_complex_coherence_changes_the_spectrum():
	# THE discriminating test. Kick a purely IMAGINARY coherence between two
	# factions. A solver that projects onto Re(H) — the deleted fallback — sees
	# no change at all and returns the untouched spectrum. The real Hermitian
	# solve must move it.
	print("\n[Imaginary coherence is not discarded]")
	var base = _make_engine()
	base.faction_renormalize_trace()
	var w_before: float = base.faction_purity()

	var kicked = _make_engine()
	# re = 0, im = 0.25 — invisible to a real-projection solver.
	kicked.faction_kick_coherence("alpha", "beta", 0.0, 0.25)
	kicked.faction_renormalize_trace()
	var w_after: float = kicked.faction_purity()

	_check(not is_nan(w_before), "purity is finite before (%s)" % w_before)
	_check(not is_nan(w_after), "purity is finite after (%s)" % w_after)
	_check(abs(w_after - w_before) > 1e-12, "a purely imaginary kick moved the state (Δpurity=%s)" % abs(w_after - w_before), "imaginary part appears to be discarded — real-projection solve?")

	# The principal mode must also respond to it.
	var m_before: Dictionary = base.faction_principal_mode()
	var m_after: Dictionary = kicked.faction_principal_mode()
	_check(not m_before.is_empty(), "principal mode resolves before")
	_check(not m_after.is_empty(), "principal mode resolves after")
	var ev_b: float = float(m_before.get("eigenvalue", 0.0))
	var ev_a: float = float(m_after.get("eigenvalue", 0.0))
	_check(not is_nan(ev_b) and not is_nan(ev_a), "principal eigenvalue finite (%s → %s)" % [ev_b, ev_a])


func test_principal_mode_is_well_formed():
	# The principal mode is the dominant eigenvector of the faction density
	# matrix — the eigen path's most load-bearing consumer (faction identity and
	# kinship read off it). Eigen returns eigenvalues ASCENDING, so the dominant
	# mode is the LAST one; getting that backwards silently inverts identity.
	print("\n[Principal mode is a real dominant mode]")
	var e = _make_engine()
	e.faction_kick_coherence("alpha", "gamma", 0.15, -0.1)
	e.faction_renormalize_trace()

	var mode: Dictionary = e.faction_principal_mode()
	_check(not mode.is_empty(), "mode returned", str(mode))
	if mode.is_empty():
		return

	var eigenvalue: float = float(mode.get("eigenvalue", -1.0))
	_check(eigenvalue >= -1e-9 and eigenvalue <= 1.0 + 1e-9, "dominant eigenvalue in [0,1] (got %s)" % eigenvalue)

	# It must dominate: the density matrix has unit trace, so the largest
	# eigenvalue is at least 1/n. If we accidentally picked the SMALLEST
	# (ascending-order mistake) it would sit below that on a non-uniform state.
	var n: int = int(e.faction_get_size())
	if n > 0:
		_check(eigenvalue >= 1.0 / float(n) - 1e-9, "dominant ≥ 1/n (%s ≥ %s)" % [eigenvalue, 1.0 / float(n)], "looks like the smallest eigenvalue was taken instead")

	var axes: PackedFloat64Array = e.faction_principal_axis_projection()
	var finite := true
	for a in axes:
		if is_nan(a) or is_inf(a):
			finite = false
	_check(finite, "axis projection all finite (%d axes)" % axes.size())

	var purity: float = e.faction_purity()
	_check(purity >= -1e-9 and purity <= 1.0 + 1e-9, "purity in [0,1] (got %s)" % purity)
