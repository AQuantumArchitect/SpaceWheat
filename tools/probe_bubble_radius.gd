extends SceneTree

## Headless probe (#119, #113): the bubble footprint (rings) is always MAX_RADIUS;
## the Bloch radius is carried separately (1.0 in the closed system, else |r|).
## Run: godot --headless --path . --script tools/probe_bubble_radius.gd

func _init() -> void:
	var QuantumNode = load("res://Core/Visualization/QuantumNode.gd")
	var BalanceConfig = load("res://Core/GameMechanics/BalanceConfig.gd")

	var closed: bool = BalanceConfig.is_closed_system()
	print("is_closed_system() = %s" % closed)

	var n = QuantumNode.new()
	# Snapshot with a TINY r_bloch — pre-fix this collapsed the bubble to MIN_RADIUS.
	var snap := {"p0": 0.5, "p1": 0.5, "r_xy": 0.0, "r_bloch": 0.02, "phi": 0.0, "theta": PI/2.0, "purity": 1.0}
	n.apply_quantum_snapshot(snap, false)
	print("MIN_RADIUS=%.1f MAX_RADIUS=%.1f" % [QuantumNode.MIN_RADIUS, QuantumNode.MAX_RADIUS])
	print("radius after low-r_bloch snapshot = %.2f" % n.radius)

	# Footprint (rings) is static at MAX_RADIUS; |r| drives only the inner disc.
	var want_r: float = 1.0 if closed else 0.02
	print("r_bloch = %.2f (want %.2f)" % [n.r_bloch, want_r])
	if is_equal_approx(n.radius, QuantumNode.MAX_RADIUS) and is_equal_approx(n.r_bloch, want_r):
		print("PASS: rings static at MAX_RADIUS; inner disc follows |r|")
		quit(0)
	else:
		print("FAIL: radius=%.2f r_bloch=%.2f" % [n.radius, n.r_bloch])
		quit(1)
