@tool
extends SceneTree

## tests/facade_parity.gd — verify GDScript FactionDensityMatrix and the native
## QuantumMythosEngine produce identical state under a deterministic operation
## sequence. Run as:
##
##   godot --headless -s tests/facade_parity.gd
##
## Regression backstop for the FDM facade. GDScript FDM is the reference
## implementation; the facade forwards everything to the native engine, so
## this test measures the native engine's self-consistency. The exact
## numerical match across both runs indicates the port is correct.


const TOL: float = 1e-9


func _init() -> void:
	print("\n=== FACADE PARITY TEST ===")
	var registry = FactionRegistry.new()
	if registry.get_all().is_empty():
		_fail("FactionRegistry empty — cannot run parity test")
		return

	var fdm = FactionDensityMatrix.new(registry)
	var native = _make_native(registry)
	if native == null:
		_fail("QuantumMythosEngine native class not registered — build native first")
		return

	# Pick a few real faction names that should both exist
	var names: Array = fdm.get_faction_names()
	var n = names.size()
	if n < 4:
		_fail("Need ≥4 factions; have %d" % n)
		return
	var f0 = names[0]
	var f1 = names[1]
	var f2 = names[2]
	var f3 = names[3]
	print("Test factions: %s, %s, %s, %s (of %d)" % [f0, f1, f2, f3, n])

	# Run identical operation sequence on both
	# 1. Pump positive
	fdm.pump(f0, 5.0)
	native.faction_pump(f0, 5.0)

	# 2. Pump another positive
	fdm.pump(f1, 3.0)
	native.faction_pump(f1, 3.0)

	# 3. Negative pump (give back)
	fdm.pump(f0, -1.5)
	native.faction_pump(f0, -1.5)

	# 4. Coherence kicks
	fdm.kick_coherence(f0, f1, 0.3, 0.1)
	native.faction_kick_coherence(f0, f1, 0.3, 0.1)
	fdm.kick_coherence(f2, f3, -0.2, 0.05)
	native.faction_kick_coherence(f2, f3, -0.2, 0.05)

	# 5. Decay
	fdm.apply_lindblad_decay(0.5)
	native.faction_apply_lindblad_decay(0.5, 300.0)

	# 6. Axis bias on axis 0, target bit 1, strength 0.2
	fdm.apply_axis_bias(0, 1, 0.2)
	native.faction_apply_axis_bias(0, 1, 0.2)

	# Compare diagonals
	var max_diag_err: float = 0.0
	var worst_diag_name: String = ""
	for name in names:
		var gd_w: float = fdm.get_weight(name)
		var na_w: float = native.faction_get_weight(name)
		var err: float = absf(gd_w - na_w)
		if err > max_diag_err:
			max_diag_err = err
			worst_diag_name = name

	# Compare a few coherences
	var pairs: Array = [[f0, f1], [f2, f3], [f0, f2], [f1, f3]]
	var max_coh_err: float = 0.0
	var worst_coh: String = ""
	for pair in pairs:
		var gd_c: Vector2 = fdm.get_coherence(pair[0], pair[1])
		var na_c: Vector2 = native.faction_get_coherence(pair[0], pair[1])
		var err: float = (gd_c - na_c).length()
		if err > max_coh_err:
			max_coh_err = err
			worst_coh = "%s ↔ %s" % [pair[0], pair[1]]

	# Compare partial trace on axis 3
	var gd_pt: Dictionary = fdm.partial_trace_axis(3)
	var na_pt: Dictionary = native.faction_partial_trace_axis(3)
	var pt_err_r00: float = absf(float(gd_pt.get("r00", 0.0)) - float(na_pt.get("r00", 0.0)))
	var pt_err_r11: float = absf(float(gd_pt.get("r11", 0.0)) - float(na_pt.get("r11", 0.0)))
	var gd_r01: Vector2 = gd_pt.get("r01", Vector2.ZERO)
	var na_r01: Vector2 = na_pt.get("r01", Vector2.ZERO)
	var pt_err_r01: float = (gd_r01 - na_r01).length()

	# Compare diagonal sum (trace) and purity
	var gd_trace: float = fdm.get_diagonal_sum()
	var na_trace: float = native.faction_diagonal_sum()
	var gd_purity: float = fdm.get_purity()
	var na_purity: float = native.faction_purity()

	print("Max diagonal error: %.10f (worst: %s)" % [max_diag_err, worst_diag_name])
	print("Max coherence error: %.10f (worst: %s)" % [max_coh_err, worst_coh])
	print("Partial trace axis 3:")
	print("  r00 err: %.10f" % pt_err_r00)
	print("  r11 err: %.10f" % pt_err_r11)
	print("  r01 err: %.10f" % pt_err_r01)
	print("Trace: GD=%.6f Native=%.6f Δ=%.10f" % [gd_trace, na_trace, absf(gd_trace - na_trace)])
	print("Purity: GD=%.6f Native=%.6f Δ=%.10f" % [gd_purity, na_purity, absf(gd_purity - na_purity)])

	var pass_test: bool = (
		max_diag_err < TOL
		and max_coh_err < TOL
		and pt_err_r00 < TOL
		and pt_err_r11 < TOL
		and pt_err_r01 < TOL
		and absf(gd_trace - na_trace) < TOL
		and absf(gd_purity - na_purity) < TOL
	)
	if pass_test:
		print("✅ PARITY PASS — GDScript and native engine agree within %.10f" % TOL)
		quit(0)
	else:
		print("❌ PARITY FAIL — divergence above %.10f tolerance" % TOL)
		quit(1)


func _make_native(registry):
	if not ClassDB.class_exists("QuantumMythosEngine"):
		return null
	var engine = ClassDB.instantiate("QuantumMythosEngine")
	if engine == null:
		return null
	# Mirror the same registry into the engine: emojis, factions, then init density.
	# Self-energies derived from icons.json (matches FactionDensityMatrix).
	var IconRegistryCls = load("res://Core/Factions/IconRegistry.gd")
	var lexicon = IconRegistryCls.new()
	var seen_emojis: Dictionary = {}
	for f in registry.get_all():
		var derived_se: Dictionary = lexicon.get_cloud_physics(f.cloud).get("self_energies", {})
		for emoji in f.cloud:
			if seen_emojis.has(emoji):
				continue
			seen_emojis[emoji] = true
			var se: float = float(derived_se.get(emoji, 0.0))
			engine.add_emoji(emoji, se, 0.0)
	for f in registry.get_all():
		var bits := PackedFloat64Array()
		for b in f.bits:
			bits.push_back(float(b))
		var sig := PackedStringArray()
		for e in f.cloud:
			sig.push_back(str(e))
		engine.add_faction(str(f.name), bits, sig)
	engine.faction_initialize_uniform()
	return engine


func _fail(msg: String) -> void:
	push_error("PARITY TEST: %s" % msg)
	print("❌ %s" % msg)
	quit(2)
