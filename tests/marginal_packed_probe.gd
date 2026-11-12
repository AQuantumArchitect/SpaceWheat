extends SceneTree

## The packed-store partial trace and coherence sum agree with the dim² loops
## they replaced (2026-11-12: the quest observer read every qubit through a
## Complex-allocating loop at the 10 Hz tick and the late game sank to 1 FPS).
##
## Run: godot --headless --path . --script tests/marginal_packed_probe.gd
## Prints one JSON line tagged "marginal-packed" (tests/test_observer_cost.py).

const FSM = preload("res://Core/QuantumSubstrate/FactionStateMatcher.gd")


func _init() -> void:
	var out := {"schema": "marginal-packed", "fails": [], "checked": 0}
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261112
	var glyphs := [["🌾", "🍄"], ["☀", "🌙"], ["🐺", "🦌"], ["💧", "🌊"], ["🔥", "❄"], ["🪵", "🪓"]]
	for nq in [1, 3, 6]:
		var qc = QuantumComputer.new("probe")
		for g in range(nq):
			qc.allocate_qubit(glyphs[g][0], glyphs[g][1])
		var dim: int = qc.register_map.dim()
		var m = ComplexMatrix.new(dim)
		for i in range(dim):
			for j in range(dim):
				m.set_element(i, j, Complex.new(rng.randf_range(-1, 1), rng.randf_range(-1, 1)))
		qc.density_matrix = m
		for r in range(nq):
			var got = qc.get_marginal_density_matrix(null, r)
			var want := _slow_marginal(m, dim, nq, r)
			for a in range(2):
				for b in range(2):
					var e1 = got.get_element(a, b)
					var e2 = want[a * 2 + b]
					if absf(e1.re - e2.x) > 1e-4 or absf(e1.im - e2.y) > 1e-4:
						(out["fails"] as Array).append("nq=%d r=%d (%d,%d) got %s want %s" % [nq, r, a, b, e1, e2])
			out["checked"] = int(out["checked"]) + 1
		var c_got: float = FSM._calculate_coherence(m)
		var tot := 0.0
		for i in range(dim):
			for j in range(dim):
				if i != j:
					var e = m.get_element(i, j)
					tot += e.re * e.re + e.im * e.im
		var c_want: float = clampf(tot / float(dim * (dim - 1)), 0.0, 1.0) if dim > 1 else 0.0
		if dim > 1 and absf(c_got - c_want) > 1e-9:
			(out["fails"] as Array).append("coherence nq=%d got %f want %f" % [nq, c_got, c_want])
	print(JSON.stringify(out))
	quit()


func _slow_marginal(m, dim: int, nq: int, r: int) -> Array:
	var shift := nq - 1 - r
	var tb := 1 << shift
	var mask := (dim - 1) ^ tb
	var acc := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	for i in range(dim):
		for j in range(dim):
			if (j & mask) != (i & mask):
				continue
			var e = m.get_element(i, j)
			var k := ((i >> shift) & 1) * 2 + ((j >> shift) & 1)
			acc[k] = acc[k] + Vector2(e.re, e.im)
	return acc
