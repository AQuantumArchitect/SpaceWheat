class_name LoopCard
extends RefCounted

## LoopCard — gatherer for the What Turns loop / fiber / Wilson ledger.
## No mutations. Callers render the returned Dictionary.


static func gather(biome, farm = null) -> Dictionary:
	var out := {
		"present": false,
		"biome": "",
		"betti_1": 0,
		"cycles": [],
		"fences": [],
		"inspected": false,
		"loops": [],
		"max_winding": 0,
		"linking": {},
		"lines": [],
	}
	if biome == null or biome.quantum_computer == null:
		return out
	out["present"] = true
	out["biome"] = str(biome.get_biome_type()) if biome.has_method("get_biome_type") else str(biome.get("biome_name", ""))
	var qc = biome.quantum_computer
	var gf = qc.get_gauge_field() if qc.has_method("get_gauge_field") else null
	if gf != null:
		out["betti_1"] = int(gf.betti_1())
		out["inspected"] = bool(gf.inspected)
		var cycle_cards: Array = []
		for c in gf.fundamental_cycles():
			cycle_cards.append({
				"nodes": c,
				"wilson_phase": gf.wilson_phase(c),
				"wilson_sign": gf.wilson_sign(c),
			})
		out["cycles"] = cycle_cards
	var loops: Array = []
	if "berry_register" in qc and qc.berry_register != null:
		loops = qc.berry_register.frozen_loops()
	out["loops"] = loops
	if loops.size() >= 2:
		out["max_winding"] = KnotRegister.max_mutual_winding(loops)
		var closed: Array = KnotRegister.closed_lift_curves(loops)
		if closed.size() >= 2:
			out["linking"] = KnotRegister.linking_report(
				closed[0].get("points"), closed[1].get("points"))
		elif not loops.is_empty():
			out["linking"] = KnotRegister.linking_report(
				loops[0].get("points"), loops[mini(1, loops.size() - 1)].get("points"))
	out["lines"] = format_lines(out)
	return out


static func format_lines(card: Dictionary) -> Array:
	var lines: Array = []
	if not bool(card.get("present", false)):
		return lines
	var betti: int = int(card.get("betti_1", 0))
	lines.append("β₁ = %d — %s" % [betti,
		"a tree keeps no books" if betti == 0 else "%d place%s where an invariant can live" % [
			betti, "" if betti == 1 else "s"]])
	for c in card.get("cycles", []):
		if c is Dictionary:
			lines.append("  W(C) sign %+d  phase %.2f  nodes %s" % [
				int(c.get("wilson_sign", 0)), float(c.get("wilson_phase", 0.0)), str(c.get("nodes", []))])
	var loops: Array = card.get("loops", [])
	if loops.is_empty():
		lines.append("🪢 no frozen loops yet — track a qubit and close a walk")
	else:
		lines.append("🪢 %d frozen loop%s — mutual winding %+d (diagnostic, not invariant)" % [
			loops.size(), "" if loops.size() == 1 else "s", int(card.get("max_winding", 0))])
		var latest: Dictionary = loops[loops.size() - 1]
		lines.append("  latest: Ω=%.2f  γ=%.2f  %s" % [
			float(latest.get("omega", 0.0)),
			float(latest.get("holonomy", 0.0)),
			_lift_phrase(latest)])
	var lk: Dictionary = card.get("linking", {})
	if not lk.is_empty():
		if bool(lk.get("valid", false)):
			lines.append("  linking: valid  Lk ≈ %.2f  (suggestive quadrature; not a quest gate)" % float(lk.get("lk", 0.0)))
		else:
			lines.append("  linking: REFUSED — a lift is still open upstairs (NAN, not failure)")
	return lines


static func format_text(card: Dictionary) -> String:
	return "\n".join(format_lines(card))


static func _lift_phrase(rec: Dictionary) -> String:
	if bool(rec.get("closed_upstairs", false)):
		return "closed upstairs"
	if bool(rec.get("spinor_flip", false)):
		return "SIGN-FLIPPED upstairs — walk it again"
	if rec.has("fiber_defect"):
		return "open upstairs by %.2f rad" % float(rec.get("fiber_defect", 0.0))
	return "lift unknown"
