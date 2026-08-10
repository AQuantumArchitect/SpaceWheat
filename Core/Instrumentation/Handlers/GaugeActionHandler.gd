extends RefCounted

## GaugeActionHandler — static instrumentation dispatcher for the fence
## ledger (GaugeField) and the mirror (reference-qubit interference).
##
## Follows the GateActionHandler pattern: static methods, explicit params,
## Dictionary returns {success, ...data, error?, message?}. Callers (the
## QuantumInstrument action_* seam) resolve focus to (biome, qid) first.
##
## All gauge verbs are FREE and touch no ρ — changing local bookkeeping costs
## nothing because nothing physical changes. The mirror compares Berry
## register travel logs — a faithful record comparison (Δγ is the true
## relative geometric phase), never a beam splitter on the density matrix.


## ============================================================================
## COMPASS (Operator 🧭) — the fence ledger
## ============================================================================

static func gauge_flip(biome, qid: int) -> Dictionary:
	# Turn the focused plot's sign convention around (χ = π). The payload
	# carries the Wilson receipt: every closed-loop product before and after,
	# so quests can certify the player watched an invariant survive.
	var ctx := _resolve_gauge(biome, qid)
	if not ctx.get("success", false):
		return ctx
	var gf = ctx["gauge_field"]
	var cycles: Array = gf.fundamental_cycles()
	var before: Array = _wilson_signs(gf, cycles)
	gf.gauge_flip(qid)
	var after: Array = _wilson_signs(gf, cycles)
	return {
		"success": true,
		"biome": ctx["biome_name"],
		"register_id": qid,
		"frame": gf.node_frame(qid),
		"wilson_before": before,
		"wilson_after": after,
		"wilson_unchanged": before == after,
		"read_since_topology_change": bool(gf.inspected),
		"message": "Turned the compass at q%d — %d fence%s flipped; every closed loop held." % [
			qid, gf.degree(qid), "" if gf.degree(qid) == 1 else "s"],
	}


static func wilson_inspect(biome, qid: int) -> Dictionary:
	# The loop card: independent cycles, their Wilson phases/signs, and the
	# focused plot's incident fences. Marks the ledger as read (quests use
	# this to require read → flip → survived, in that order).
	var ctx := _resolve_gauge(biome, qid)
	if not ctx.get("success", false):
		return ctx
	var gf = ctx["gauge_field"]
	gf.inspected = true
	var cycle_cards: Array = []
	for c in gf.fundamental_cycles():
		cycle_cards.append({
			"nodes": c,
			"wilson_phase": gf.wilson_phase(c),
			"wilson_sign": gf.wilson_sign(c),
			"through_here": qid in c,
		})
	var fences: Array = []
	for nb in gf.neighbors(qid):
		fences.append({
			"to": nb,
			"phase": gf.edge_phase(qid, nb),
			"sign": gf.edge_sign(qid, nb),
		})
	var betti: int = gf.betti_1()
	return {
		"success": true,
		"biome": ctx["biome_name"],
		"register_id": qid,
		"betti_1": betti,
		"cycles": cycle_cards,
		"fences": fences,
		"frame": gf.node_frame(qid),
		"message": ("β₁ = %d: %d place%s where an invariant can live. " % [
			betti, betti, "" if betti == 1 else "s"]) + (
			"A tree keeps no books — every fence here can be combed away." if betti == 0
			else "The cycles keep the books no combing can erase."),
	}


static func gauge_fix(biome) -> Dictionary:
	# Comb the ledger flat: every spanning-tree fence to exactly zero. What
	# survives sits on the chords — one number per independent cycle.
	var ctx := _resolve_gauge(biome, 0)
	if not ctx.get("success", false):
		return ctx
	var gf = ctx["gauge_field"]
	var fixed: Dictionary = gf.gauge_fix_tree()
	var residual: Array = fixed.get("residual", [])
	return {
		"success": true,
		"biome": ctx["biome_name"],
		"residual": residual,
		"betti_1": gf.betti_1(),
		"message": ("Combed flat: nothing survived — this graph is a tree, and a tree keeps no books."
			if residual.is_empty()
			else "Combed flat: %d number%s refused to go — the cycles' invariant residue." % [
				residual.size(), "" if residual.size() == 1 else "s"]),
	}


static func gauge_scramble(biome, seed_value: int) -> Dictionary:
	# The red-team move: random χ at every plot. Reads the Wilson receipt
	# before and after so the survival is a certified fact, not an assertion.
	var ctx := _resolve_gauge(biome, 0)
	if not ctx.get("success", false):
		return ctx
	var gf = ctx["gauge_field"]
	var cycles: Array = gf.fundamental_cycles()
	var before: Array = _wilson_signs(gf, cycles)
	gf.random_gauge(seed_value)
	var after: Array = _wilson_signs(gf, cycles)
	return {
		"success": true,
		"biome": ctx["biome_name"],
		"wilson_before": before,
		"wilson_after": after,
		"wilson_unchanged": before == after,
		"message": "Every convention scrambled. %s" % (
			"Every closed loop held." if before == after
			else "A loop moved — report this: it should be impossible."),
	}


## ============================================================================
## MIRROR (Icon 🪞) — reference-qubit interference
## ============================================================================

static func mark_reference(biome, qid: int) -> Dictionary:
	# Tag the focused qubit as the stay-home reference; a travel log needs a
	# logbook, so tracking starts if it wasn't already.
	if biome == null or biome.quantum_computer == null:
		return {"success": false, "error": "no_biome", "message": "No living biome under this plot."}
	var qc = biome.quantum_computer
	if qid < 0 or qc.register_map == null or qid >= qc.register_map.num_qubits:
		return {"success": false, "error": "no_qubit", "message": "No qubit under this plot to hold home."}
	var reg = qc.berry_register
	var started := false
	if not reg.is_tracked(qid):
		reg.start_tracking(qid)
		started = true
	return {
		"success": true,
		"reference": {"biome_name": str(biome.get_biome_type()), "register_id": qid},
		"started_tracking": started,
		"message": "q%d stays home%s — its log is the zero every traveler is read against." % [
			qid, " (tracking started)" if started else ""],
	}


static func interfere(farm, biome, qid: int, reference: Dictionary) -> Dictionary:
	# Compare the focused qubit's travel log against the reference's:
	# Δγ = γ_traveled − γ_home and the spinor sign product. Non-destructive —
	# ρ is never touched; this is a faithful comparison of Berry records,
	# which is exactly what an interferometric readout would reveal.
	if reference.is_empty():
		return {"success": false, "error": "no_reference",
			"message": "No reference marked. R holds a qubit home first — a phase is only visible in company."}
	if biome == null or biome.quantum_computer == null:
		return {"success": false, "error": "no_biome", "message": "No living biome under this plot."}
	var qc = biome.quantum_computer
	if qid < 0 or qc.register_map == null or qid >= qc.register_map.num_qubits:
		return {"success": false, "error": "no_qubit", "message": "No qubit under this plot to read."}
	var ref_name := str(reference.get("biome_name", ""))
	var ref_biome = farm.grid.get_biome(ref_name) if (farm and farm.grid and farm.grid.has_method("get_biome")) else null
	if ref_biome == null or ref_biome.quantum_computer == null:
		return {"success": false, "error": "reference_lost", "message": "The reference's biome is gone. Mark a new home."}
	var ref_id: int = int(reference.get("register_id", -1))
	var reg_here = qc.berry_register
	var reg_home = ref_biome.quantum_computer.berry_register
	if not reg_here.has_entry(qid):
		return {"success": false, "error": "untracked",
			"message": "q%d keeps no travel log — track it (Icon F) and walk it first." % qid}
	if not reg_home.has_entry(ref_id):
		return {"success": false, "error": "reference_untracked", "message": "The reference lost its log. Mark home again."}
	var gamma_here: float = reg_here.get_fiber_angle(qid)
	var gamma_home: float = reg_home.get_fiber_angle(ref_id)
	var product: int = reg_here.get_spinor_sign(qid) * reg_home.get_spinor_sign(ref_id)
	var delta: float = gamma_here - gamma_home
	var same_plot := (qid == ref_id and str(biome.get_biome_type()) == ref_name)
	return {
		"success": true,
		"biome": str(biome.get_biome_type()),
		"register_id": qid,
		"reference": reference,
		"delta_gamma": delta,
		"spinor_product": product,
		"self_compare": same_plot,
		"message": ("A qubit against itself always reads +1 — bring the traveler to the mirror instead."
			if same_plot
			else "Δγ = %.2f rad · sign product %+d — %s" % [delta, product,
				"the traveler came home OPPOSITE: same point on the sphere, other side of the fiber."
				if product < 0 else "the logs agree: no net turn between them."]),
	}


## ============================================================================
## HELPERS
## ============================================================================

static func _resolve_gauge(biome, qid: int) -> Dictionary:
	if biome == null or biome.quantum_computer == null:
		return {"success": false, "error": "no_biome", "message": "No living biome under this plot."}
	var qc = biome.quantum_computer
	if qid < 0 or qc.register_map == null or qid >= qc.register_map.num_qubits:
		return {"success": false, "error": "no_qubit",
			"message": "No qubit under this plot — the ledger keys on fences between real registers."}
	var gf = qc.get_gauge_field()
	if gf == null or gf.node_count() == 0:
		return {"success": false, "error": "no_gauge_field", "message": "This biome keeps no fence ledger yet."}
	return {
		"success": true,
		"biome_name": str(biome.get_biome_type()),
		"gauge_field": gf,
	}


static func _wilson_signs(gf, cycles: Array) -> Array:
	var out: Array = []
	for c in cycles:
		out.append(gf.wilson_sign(c))
	return out
