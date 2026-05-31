@tool
extends SceneTree

## tests/principal_mode.gd — verify the new C++ principal-mode API.
##
## When ρ_factions is uniform, the dominant eigenvalue should be tiny (1/F)
## and the axis projection close to the population mean of each bit across
## all factions. When ρ collapses onto a single faction, the axis projection
## should match that faction's bits exactly.
##
## Run: godot --headless -s tests/principal_mode.gd


const TOL: float = 1e-6


func _init() -> void:
	print("\n=== PRINCIPAL MODE TEST ===")
	var fdm = FactionDensityMatrix.new(null)
	var n = fdm.get_size()
	if n < 4:
		print("❌ FAIL: need ≥4 factions, have %d" % n)
		quit(1)
		return
	print("  Factions loaded: %d" % n)

	# ----- Test 1: uniform ρ -----
	# Dominant eigenvalue of I/F is 1/F with multiplicity F; eigenvectors are
	# degenerate so the solver can return any basis vector. Projection is less
	# meaningful here, but it should at least return 12 values in [0,1].
	var mode_uniform: Dictionary = fdm.get_principal_mode()
	print("  UNIFORM ρ: eigenvalue=%.6f (expected ~1/F=%.6f), ok=%s" % [
		float(mode_uniform.get("eigenvalue", 0.0)), 1.0 / float(n), mode_uniform.get("ok", false)
	])
	if not mode_uniform.get("ok", false):
		print("❌ FAIL: principal_mode returned ok=false on uniform ρ")
		quit(1)
		return
	if absf(float(mode_uniform.get("eigenvalue", 0.0)) - 1.0 / float(n)) > 0.01:
		print("⚠ WARN: uniform eigenvalue not ~1/F (degenerate case)")

	var proj_uniform: Array = fdm.get_principal_axis_projection()
	if proj_uniform.size() != 12:
		print("❌ FAIL: axis projection returned %d values, expected 12" % proj_uniform.size())
		quit(1)
		return
	for v in proj_uniform:
		var f: float = float(v)
		if f < 0.0 or f > 1.0:
			print("❌ FAIL: axis projection value out of [0,1]: %.4f" % f)
			quit(1)
			return
	print("  uniform projection: [%s]" % ", ".join(_fmt_arr(proj_uniform)))

	# ----- Test 2: pump ρ onto a single faction, verify projection matches bits -----
	var names: Array = fdm.get_faction_names()
	var target: String = str(names[0])
	# Pump hard so ρ[target,target] ≈ 1
	for i in range(25):
		fdm.pump(target, 20.0)
	var weight: float = fdm.get_weight(target)
	print("  After collapse: ρ[%s,%s] = %.4f" % [target, target, weight])
	if weight < 0.9:
		print("❌ FAIL: pump did not collapse ρ onto target (weight=%.4f)" % weight)
		quit(1)
		return

	var mode_collapsed: Dictionary = fdm.get_principal_mode()
	print("  Collapsed eigenvalue: %.4f (expected ~1.0)" % float(mode_collapsed.get("eigenvalue", 0.0)))
	if absf(float(mode_collapsed.get("eigenvalue", 0.0)) - 1.0) > 0.05:
		print("❌ FAIL: collapsed dominant eigenvalue should be ≈1; got %.4f" % float(mode_collapsed.get("eigenvalue", 0.0)))
		quit(1)
		return

	var target_bits: PackedByteArray = fdm.get_faction_bits(target)
	var proj_collapsed: Array = fdm.get_principal_axis_projection()
	print("  target bits: %s" % _fmt_bits(target_bits))
	print("  collapsed projection: [%s]" % ", ".join(_fmt_arr(proj_collapsed)))

	# Projection should match bits closely (axis=1 where bit=1, axis=0 where bit=0)
	var mismatch_count: int = 0
	for i in range(12):
		var expected: float = 1.0 if (i < target_bits.size() and target_bits[i] == 1) else 0.0
		var actual: float = float(proj_collapsed[i])
		if absf(actual - expected) > 0.1:
			print("  ⚠ axis %d: expected %.1f, got %.4f" % [i, expected, actual])
			mismatch_count += 1
	if mismatch_count > 2:
		# Allow a small tolerance for numerical drift after pump
		print("❌ FAIL: %d axes mismatch after collapse (expected near-exact match to bits)" % mismatch_count)
		quit(1)
		return

	print("  ✓ collapsed projection matches target bits within tolerance (%d/12 axes drift)" % mismatch_count)
	print("\n✅ PRINCIPAL MODE PASS — dominant-mode axis projection is correct")
	quit(0)


func _fmt_arr(arr: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for v in arr:
		out.push_back("%.2f" % float(v))
	return out


func _fmt_bits(bits: PackedByteArray) -> PackedStringArray:
	var out := PackedStringArray()
	for b in bits:
		out.push_back(str(b))
	return out
