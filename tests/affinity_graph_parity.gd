extends SceneTree

## affinity_graph_parity.gd — Phase I substrate verification.
##
## Run:  godot --headless --quit --script tests/affinity_graph_parity.gd
##
## Verifies AlignmentGraph corner-state behaviour matches the existing
## Faction.bits encoding bit-for-bit, plus invariants on rotation, mixing,
## and serialization.

const AG = preload("res://Core/Alignment/AlignmentGraph.gd")

var _failed: int = 0
var _passed: int = 0


func _init() -> void:
	print("=== AlignmentGraph parity ===")
	_t_corner_round_trip()
	_t_diagonal_one_hot()
	_t_partial_trace_corner()
	_t_overlap_corner_pairs()
	_t_overlap_self_purity()
	_t_uniform_marginals()
	_t_rotate_axis_norm()
	_t_lindblad_jump_endpoints()
	_t_lindblad_compact_rank()
	_t_serialize_round_trip()
	_t_principal_bits_corner()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  ✓ %s" % label)
	else:
		_failed += 1
		push_error("  ✗ %s" % label)
		print("  ✗ %s" % label)


func _approx(a: float, b: float, eps: float = 1e-9) -> bool:
	return abs(a - b) < eps


func _make_bits(seed_val: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(AG.AXIS_COUNT)
	var s := seed_val
	for i in range(AG.AXIS_COUNT):
		b[i] = s & 1
		s = (s * 1103515245 + 12345) & 0x7fffffff
		s >>= 1
	return b


# --- tests ---

func _t_corner_round_trip() -> void:
	for seed in [0, 1, 42, 0xfff, 0xa5a]:
		var bits := _make_bits(seed)
		var g = AG.from_corner(bits)
		var read = g.principal_bits()
		var ok := true
		for i in range(AG.AXIS_COUNT):
			if read[i] != bits[i]:
				ok = false
				break
		_check(ok, "corner ↔ principal_bits round-trip seed=%d" % seed)


func _t_diagonal_one_hot() -> void:
	var bits := _make_bits(7)
	var g = AG.from_corner(bits)
	_check(_approx(g.corner_weight(bits), 1.0), "corner: diag at bits == 1")
	var other := _make_bits(99)
	var same := true
	for i in range(AG.AXIS_COUNT):
		if other[i] != bits[i]:
			same = false
			break
	if not same:
		_check(_approx(g.corner_weight(other), 0.0), "corner: diag elsewhere == 0")


func _t_partial_trace_corner() -> void:
	var bits := _make_bits(13)
	var g = AG.from_corner(bits)
	for axis_i in range(AG.AXIS_COUNT):
		var pt = g.partial_trace_axis(axis_i)
		var expect_p1 := 1.0 if bits[axis_i] == 1 else 0.0
		var expect_p0 := 1.0 - expect_p1
		var ok := _approx(pt.p0, expect_p0) and _approx(pt.p1, expect_p1) \
			and _approx(pt.off.x, 0.0) and _approx(pt.off.y, 0.0)
		if not ok:
			print("    axis %d: p0=%.6f p1=%.6f off=(%.6f,%.6f) expect p1=%.1f" %
				[axis_i, pt.p0, pt.p1, pt.off.x, pt.off.y, expect_p1])
			_failed += 1
			return
	_passed += 1
	print("  ✓ partial_trace on corner = pure marginal on each axis")


func _t_overlap_corner_pairs() -> void:
	var b1 := _make_bits(1)
	var b2 := _make_bits(2)
	var g1 = AG.from_corner(b1)
	var g2 = AG.from_corner(b2)
	var same = AG.from_corner(b1)
	_check(_approx(g1.overlap(g1), 1.0), "overlap(self_corner) == 1")
	_check(_approx(g1.overlap(same), 1.0), "overlap(equal_corner) == 1")
	var same_bits := true
	for i in range(AG.AXIS_COUNT):
		if b1[i] != b2[i]:
			same_bits = false
			break
	if not same_bits:
		_check(_approx(g1.overlap(g2), 0.0), "overlap(distinct_corners) == 0")


func _t_overlap_self_purity() -> void:
	var bits := _make_bits(5)
	var g = AG.from_corner(bits)
	_check(_approx(g.purity(), 1.0), "corner state purity == 1")


func _t_uniform_marginals() -> void:
	var g = AG.from_uniform_superposition()
	_check(_approx(g.trace(), 1.0, 1e-6), "uniform: trace == 1")
	_check(_approx(g.purity(), 1.0, 1e-6), "uniform: pure state purity == 1")
	for axis_i in range(AG.AXIS_COUNT):
		var pt = g.partial_trace_axis(axis_i)
		if not (_approx(pt.p0, 0.5, 1e-6) and _approx(pt.p1, 0.5, 1e-6)):
			print("    axis %d marginal: p0=%.6f p1=%.6f" % [axis_i, pt.p0, pt.p1])
			_failed += 1
			return
	_passed += 1
	print("  ✓ uniform: every axis marginal == 0.5/0.5")


func _t_rotate_axis_norm() -> void:
	var bits := _make_bits(3)
	var g = AG.from_corner(bits)
	g.rotate_axis(0, PI / 4.0)
	g.rotate_axis(5, PI / 3.0)
	g.rotate_axis(11, PI * 0.7)
	_check(_approx(g.trace(), 1.0, 1e-6), "rotate_axis preserves trace (got %.12f)" % g.trace())
	_check(_approx(g.purity(), 1.0, 1e-6), "rotate_axis preserves purity (got %.12f)" % g.purity())


func _t_lindblad_jump_endpoints() -> void:
	var b1 := _make_bits(11)
	var b2 := _make_bits(22)
	var same := true
	for i in range(AG.AXIS_COUNT):
		if b1[i] != b2[i]:
			same = false
			break
	if same:
		b2[0] = 1 - b2[0]
	var g = AG.from_corner(b1)
	var t = AG.from_corner(b2)
	g.lindblad_jump_toward(t, 0.0)
	_check(_approx(g.corner_weight(b1), 1.0), "lindblad rate=0 is identity")
	g.lindblad_jump_toward(t, 1.0)
	_check(_approx(g.corner_weight(b2), 1.0), "lindblad rate=1 jumps fully to target")
	var g2 = AG.from_corner(b1)
	g2.lindblad_jump_toward(t, 0.25)
	var w1 = g2.corner_weight(b1)
	var w2 = g2.corner_weight(b2)
	_check(_approx(w1, 0.75) and _approx(w2, 0.25),
		"lindblad rate=0.25 mixes 0.75/0.25")
	_check(_approx(g2.trace(), 1.0, 1e-9), "lindblad mixture preserves trace")


func _t_lindblad_compact_rank() -> void:
	var g = AG.from_corner(_make_bits(0))
	for i in range(64):
		var t = AG.from_corner(_make_bits(i + 100))
		g.lindblad_jump_toward(t, 0.1)
	_check(g.rank() <= AG.K_MAX,
		"rank capped at K_MAX (got %d)" % g.rank())
	_check(_approx(g.trace(), 1.0, 1e-6),
		"compacted state still has unit trace (got %.6f)" % g.trace())


func _t_serialize_round_trip() -> void:
	var g = AG.from_corner(_make_bits(17))
	g.rotate_axis(2, 0.4)
	g.rotate_axis(7, -0.9)
	var t = AG.from_corner(_make_bits(31))
	g.lindblad_jump_toward(t, 0.3)
	var d = g.to_dict()
	var g2 = AG.from_dict(d)
	_check(_approx(g.trace(), g2.trace(), 1e-9), "serialize: trace preserved")
	_check(_approx(g.purity(), g2.purity(), 1e-9), "serialize: purity preserved")
	_check(_approx(g.overlap(g2), g.purity(), 1e-9),
		"serialize: overlap(g, g2) == purity(g)")


func _t_principal_bits_corner() -> void:
	for seed in [0xa5a, 0x3c3, 0x111, 0xeee]:
		var bits := _make_bits(seed)
		var g = AG.from_corner(bits)
		var read = g.principal_bits()
		var ok := true
		for i in range(AG.AXIS_COUNT):
			if read[i] != bits[i]:
				ok = false
				break
		if not ok:
			_failed += 1
			return
	_passed += 1
	print("  ✓ principal_bits matches input on multiple corner seeds")
