extends SceneTree

## player_affinity_phase3.gd — Phase III verification.
##
## Run:  godot --headless --quit --script tests/player_affinity_phase3.gd
##
## Exercises the player AffinityGraph wiring directly (no full Farm boot):
##   - default = uniform superposition; all axes 0.5
##   - icon-learn rotation drifts marginals toward owner faction's bits
##   - settlement Lindblad jump pulls overlap up
##   - save round-trip preserves the substrate

const AffinityGraphCls = preload("res://Core/Affinity/AffinityGraph.gd")
const FactionRegistryCls = preload("res://Core/Factions/FactionRegistry.gd")
const HamiltonianConfig = preload("res://Core/Config/HamiltonianConfig.gd")

var _failed: int = 0
var _passed: int = 0


func _init() -> void:
	print("=== Player affinity phase III ===")
	_t_default_uniform()
	_t_learn_rotation_drift()
	_t_settlement_jump()
	_t_save_roundtrip()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  ✓ %s" % label)
	else:
		_failed += 1
		print("  ✗ %s" % label)


func _approx(a: float, b: float, eps: float = 1e-6) -> bool:
	return abs(a - b) < eps


func _t_default_uniform() -> void:
	var pa = AffinityGraphCls.from_uniform_superposition()
	for i in range(AffinityGraphCls.AXIS_COUNT):
		var pt: Dictionary = pa.partial_trace_axis(i)
		if not _approx(pt.p1, 0.5):
			_check(false, "default uniform: axis %d p1=%.4f" % [i, pt.p1])
			return
	_check(true, "default player ρ has all marginals at 0.5")


func _t_learn_rotation_drift() -> void:
	# Pick a faction and apply the same rotation Farm._pump_for_icon does.
	var reg = FactionRegistryCls.new()
	reg.load_factions()
	var f = reg.get_all()[0]
	var pa = AffinityGraphCls.from_uniform_superposition()
	var theta: float = HamiltonianConfig.PLAYER_AFFINITY_LEARN_THETA
	for _learn in range(20):
		for i in range(AffinityGraphCls.AXIS_COUNT):
			var signed_theta: float = theta if int(f.bits[i]) == 1 else -theta
			pa.rotate_axis(i, signed_theta)
	# After 20 learns, marginals should have drifted toward each bit.
	var drifted := 0
	for i in range(AffinityGraphCls.AXIS_COUNT):
		var pt: Dictionary = pa.partial_trace_axis(i)
		if int(f.bits[i]) == 1:
			if pt.p1 > 0.55: drifted += 1
		else:
			if pt.p0 > 0.55: drifted += 1
	_check(drifted >= 10,
		"after 20 learns, %d/12 axes drifted >5%% toward faction '%s'" % [drifted, f.name])
	_check(_approx(pa.purity(), 1.0, 1e-4),
		"learn rotation preserves player ρ purity (got %.6f)" % pa.purity())


func _t_settlement_jump() -> void:
	# Settlement is a UNITARY rotation toward faction.bits — not a Lindblad jump.
	# Faction affinity is a pure Hamiltonian state; the player's substrate stays
	# pure too (decoherence is a biome property, not a faction interaction).
	var reg = FactionRegistryCls.new()
	reg.load_factions()
	var f = reg.get_all()[0]
	var pa = AffinityGraphCls.from_uniform_superposition()
	var initial_overlap: float = pa.overlap(f.affinity)
	var rate: float = HamiltonianConfig.PLAYER_AFFINITY_SETTLEMENT_RATE
	# Five settlements with trust_delta=1.0 each — same rotation shape Farm uses.
	for _settle in range(5):
		var theta: float = rate * 1.0
		for i in range(AffinityGraphCls.AXIS_COUNT):
			var signed_theta: float = theta if int(f.bits[i]) == 1 else -theta
			pa.rotate_axis(i, signed_theta)
	var after_overlap: float = pa.overlap(f.affinity)
	_check(after_overlap > initial_overlap,
		"settlement rotation increases overlap with faction (%.6f → %.6f)" %
			[initial_overlap, after_overlap])
	_check(_approx(pa.trace(), 1.0, 1e-6),
		"rotated ρ has unit trace (got %.6f)" % pa.trace())
	_check(_approx(pa.purity(), 1.0, 1e-4),
		"rotated ρ stays pure (got purity=%.6f)" % pa.purity())


func _t_save_roundtrip() -> void:
	var reg = FactionRegistryCls.new()
	reg.load_factions()
	var f = reg.get_all()[0]
	var pa = AffinityGraphCls.from_uniform_superposition()
	for _settle in range(3):
		pa.lindblad_jump_toward(f.affinity, 0.05)
	var d: Dictionary = pa.to_dict()
	var pa2 = AffinityGraphCls.from_dict(d)
	_check(_approx(pa.trace(), pa2.trace(), 1e-9), "save roundtrip preserves trace")
	_check(_approx(pa.overlap(pa2), pa.purity(), 1e-9),
		"save roundtrip: overlap(orig, restored) == purity(orig)")
	# Empty dict path — used for v1/v2 → v3 migration
	var fresh = AffinityGraphCls.from_dict({})
	_check(fresh != null, "from_dict({}) does not crash")
