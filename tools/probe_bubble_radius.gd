extends SceneTree

## Headless probe for #119: in the closed system, a bubble must render at full
## radius (MAX_RADIUS) even when its per-qubit Bloch radius is small/missing.
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

	var pass_closed: bool = closed and is_equal_approx(n.radius, QuantumNode.MAX_RADIUS)
	if pass_closed:
		print("PASS: closed system → full-size bubble (radius==MAX_RADIUS) despite r_bloch=0.02")
		quit(0)
	else:
		print("FAIL: expected MAX_RADIUS in closed mode, got %.2f" % n.radius)
		quit(1)
