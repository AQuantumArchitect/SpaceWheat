extends SceneTree

## The fence-ledger probe: gauge freedom changes the bookkeeping, never the
## loop. Drives the REAL GaugeField substrate:
##
##   1. Z₂ fences: gauge_flip at a plot flips its incident fences; every
##      closed-loop product W(C) = Π u_ij survives (g² = 1).
##   2. U(1): random gauge scrambles at every node leave every Wilson phase
##      untouched to machine precision.
##   3. Tree lesson: on a cycle-free graph gauge_fix_tree erases EVERYTHING;
##      add one chord and exactly β₁ = 1 number survives, equal (up to
##      orientation) to the cycle's Wilson phase.
##
## Run: godot --headless --script tests/gauge_field_probe.gd

const Gauge := preload("res://Core/QuantumSubstrate/GaugeField.gd")


func _ring_plus_tail():
	# A—B—C—D—A ring with a tail E hanging off C: V=5, E=5, β₁=1.
	var g = Gauge.new()
	g.add_edge("A", "B", 0.7)
	g.add_edge("B", "C", -1.1)
	g.add_edge("C", "D", 2.0)
	g.add_edge("D", "A", 0.3)
	g.add_edge("C", "E", 1.4)
	return g


func _init() -> void:
	var checks: Dictionary = {}
	var cycle: Array = ["A", "B", "C", "D"]

	# --- 1. the Z₂ fence game ------------------------------------------------
	var z2 = Gauge.new()
	z2.set_edge_sign("A", "B", 1)
	z2.set_edge_sign("B", "C", -1)
	z2.set_edge_sign("C", "D", -1)
	z2.set_edge_sign("D", "A", 1)
	var w_before: int = z2.wilson_sign(cycle)
	z2.gauge_flip("B")
	checks["flip_changes_local_fences"] = z2.edge_sign("A", "B") == -1 and z2.edge_sign("B", "C") == 1
	checks["z2_wilson_survives_flip"] = z2.wilson_sign(cycle) == w_before
	z2.gauge_flip("C")
	z2.gauge_flip("A")
	checks["z2_wilson_survives_any_flips"] = z2.wilson_sign(cycle) == w_before

	# --- 2. U(1): scramble every clock, the loop remembers -------------------
	var u1 = _ring_plus_tail()
	var phi_before: float = u1.wilson_phase(cycle)
	var edge_before: float = u1.edge_phase("A", "B")
	u1.random_gauge(47)
	checks["u1_edges_changed"] = absf(wrapf(u1.edge_phase("A", "B") - edge_before, -PI, PI)) > 1e-3
	checks["u1_wilson_invariant"] = absf(wrapf(u1.wilson_phase(cycle) - phi_before, -PI, PI)) < 1e-9

	# --- 3. trees erase completely; cycles refuse ----------------------------
	var tree = Gauge.new()
	tree.add_edge("A", "B", 0.9)
	tree.add_edge("B", "C", -2.2)
	tree.add_edge("C", "D", 1.3)
	tree.add_edge("C", "E", 0.4)
	checks["tree_betti_zero"] = tree.betti_1() == 0
	var fixed_tree: Dictionary = tree.gauge_fix_tree()
	var all_zero := true
	for pair in [["A", "B"], ["B", "C"], ["C", "D"], ["C", "E"]]:
		if absf(tree.edge_phase(pair[0], pair[1])) > 1e-9:
			all_zero = false
	checks["tree_gauges_away_entirely"] = all_zero and (fixed_tree["residual"] as Array).is_empty()

	var ring = _ring_plus_tail()
	checks["ring_betti_one"] = ring.betti_1() == 1
	checks["ring_one_fundamental_cycle"] = ring.fundamental_cycles().size() == 1
	var phi_ring: float = ring.wilson_phase(cycle)
	var fixed_ring: Dictionary = ring.gauge_fix_tree()
	var residual: Array = fixed_ring["residual"]
	checks["ring_one_survivor"] = residual.size() == 1
	var survivor: float = absf(float(residual[0].get("phase", 0.0))) if residual.size() == 1 else NAN
	checks["survivor_is_the_wilson_phase"] = residual.size() == 1 and absf(survivor - absf(phi_ring)) < 1e-9
	checks["wilson_survives_the_fixing"] = absf(wrapf(ring.wilson_phase(cycle) - phi_ring, -PI, PI)) < 1e-9

	var ok := true
	for k in checks.keys():
		if not bool(checks[k]):
			ok = false
	print(JSON.stringify({
		"schema": "gauge-field-probe/0.1",
		"pass": ok,
		"checks": checks,
		"numbers": {
			"ring_wilson_phase": phi_ring,
			"ring_survivor_abs": survivor,
		},
	}))
	quit(0 if ok else 1)
